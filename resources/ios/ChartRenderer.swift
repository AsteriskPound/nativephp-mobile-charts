import SwiftUI

/// Renders `<native:chart>` as hand-drawn Canvas geometry — no Swift Charts /
/// third-party charting library — so line, bar, and radar look consistent
/// with each other and with the Android renderer (`ChartRenderer.kt`, kept
/// structurally parallel to this file). Radar in particular has no native
/// framework support on either platform, so a uniform hand-rolled approach
/// avoids a visual mismatch between chart kinds.
///
/// Chrome is deliberately left to the app: titles, legends, and axis labels
/// are ordinary EDGE `native:text`/`native:row` elements composed around the
/// `<native:chart>` tag in Blade — this view only draws the plot area.
struct ChartRenderer: View {
    let node: NativeUINode

    private struct Series {
        let name: String
        let color: Color
        let values: [Double?]
    }

    private static let gridColor = Color(white: 0.53, opacity: 0.12)
    private static let defaultColor = Color(red: 0x1D / 255, green: 0xB9 / 255, blue: 0x54 / 255)

    var body: some View {
        let p = node.props
        let kind = p.getString("kind", default: "line")
        let labels = Self.parseStrings(p.getString("labels", default: "[]"))
        let series = Self.parseSeries(p.getString("series", default: "[]"))
        let explicitMax = Double(p.getFloat("y_max", default: 0))
        let yMax = explicitMax > 0 ? explicitMax : Self.autoMax(series)
        // Line and bar charts can honor a non-zero floor to zoom into the
        // data's value range; radar's center is always 0, or its spokes
        // stop representing magnitude from a common origin.
        let yMin = (kind == "line" || kind == "bar") && p.has("y_min") ? Double(p.getFloat("y_min", default: 0)) : 0

        Canvas { context, size in
            if kind == "line" || kind == "bar" {
                Self.drawValueGrid(context, size, yMin, yMax)
            } else {
                Self.drawGrid(context, size)
            }

            switch kind {
            case "bar":
                Self.drawBars(context, size, series, yMin, yMax)
            case "radar":
                Self.drawRadar(context, size, labels, series, yMax)
            default:
                Self.drawLines(context, size, series, yMin, yMax)
            }
        }
    }

    private static func parseStrings(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }

        return array
    }

    private static func parseSeries(_ json: String) -> [Series] {
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return array.map { entry in
            let rawValues = entry["values"] as? [Any] ?? []

            return Series(
                name: entry["name"] as? String ?? "",
                color: parseColor(entry["color"] as? String),
                values: rawValues.map { $0 as? Double }
            )
        }
    }

    private static func parseColor(_ hex: String?) -> Color {
        guard let hex, hex.hasPrefix("#"), hex.count == 7,
              let value = Int(hex.dropFirst(), radix: 16) else {
            return defaultColor
        }

        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    private static func autoMax(_ series: [Series]) -> Double {
        let max = series.flatMap { $0.values }.compactMap { $0 }.max() ?? 1
        return max <= 0 ? 1 : max
    }

    private static func drawGrid(_ context: GraphicsContext, _ size: CGSize) {
        let steps = 4
        for i in 0...steps {
            let y = size.height * CGFloat(i) / CGFloat(steps)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(gridColor), lineWidth: 1)
        }
    }

    /// Line-chart grid: reference lines land on multiples of 5 (or 10 for a
    /// wide spread) rather than dividing the canvas into a fixed number of
    /// equal bands, so every line can carry a label the app draws alongside
    /// it (see the `dciscores-app` `PerformerCompare::axisStep()`/
    /// `seasonChartData()`, which this mirrors — `yMin`/`yMax` are already
    /// rounded to that same step's multiples by convention before they
    /// reach here, so the topmost/bottommost lines land exactly on them).
    private static func drawValueGrid(_ context: GraphicsContext, _ size: CGSize, _ yMin: Double, _ yMax: Double) {
        let range = yMax - yMin
        guard range > 0 else {
            drawGrid(context, size)
            return
        }

        let step = gridStep(range)
        var value = yMin
        while value <= yMax + 0.001 {
            let y = size.height * (1 - CGFloat((value - yMin) / range))
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(gridColor), lineWidth: 1)
            value += step
        }
    }

    /// Mirrors `PerformerCompare::axisStep()` — see `drawValueGrid`'s doc.
    private static func gridStep(_ range: Double) -> Double {
        range > 50 ? 10 : 5
    }

    private static func drawLines(_ context: GraphicsContext, _ size: CGSize, _ series: [Series], _ yMin: Double, _ yMax: Double) {
        let range = (yMax - yMin) != 0 ? (yMax - yMin) : 1

        for s in series {
            let count = s.values.count
            guard count >= 2 else { continue }

            let stepX = size.width / CGFloat(count - 1)
            // A nil value ends the current segment (a gap in the data — the
            // corps sat out that show); the next non-nil value starts a new
            // one, so a stroked path never bridges over a missing point.
            var path: Path?

            for (i, value) in s.values.enumerated() {
                guard let value else {
                    if let livePath = path {
                        context.stroke(livePath, with: .color(s.color), lineWidth: 3)
                    }
                    path = nil
                    continue
                }

                let point = CGPoint(x: CGFloat(i) * stepX, y: size.height * (1 - CGFloat((value - yMin) / range)))

                if path == nil {
                    path = Path()
                    path?.move(to: point)
                } else {
                    path?.addLine(to: point)
                }

                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
                    with: .color(s.color)
                )
            }

            if let livePath = path {
                context.stroke(livePath, with: .color(s.color), lineWidth: 3)
            }
        }
    }

    private static func drawBars(_ context: GraphicsContext, _ size: CGSize, _ series: [Series], _ yMin: Double, _ yMax: Double) {
        let groupCount = series.map(\.values.count).max() ?? 0
        guard groupCount > 0 else { return }

        let range = (yMax - yMin) != 0 ? (yMax - yMin) : 1
        let groupWidth = size.width / CGFloat(groupCount)
        let barWidth = groupWidth / CGFloat(series.count + 1)

        for (seriesIndex, s) in series.enumerated() {
            for (i, value) in s.values.enumerated() {
                guard let value else { continue }

                // Clamped defensively — a value outside [yMin, yMax] (a
                // stale or mismatched upstream max) shortens/caps the bar
                // instead of drawing it past the canvas into whatever UI
                // sits above the chart.
                let clamped = min(max(value, yMin), yMax)
                let barHeight = size.height * CGFloat((clamped - yMin) / range)
                let x = CGFloat(i) * groupWidth + barWidth * (CGFloat(seriesIndex) + 0.5)

                let rect = CGRect(x: x, y: size.height - barHeight, width: barWidth * 0.8, height: barHeight)
                context.fill(Path(rect), with: .color(s.color))
            }
        }
    }

    private static func drawRadar(
        _ context: GraphicsContext,
        _ size: CGSize,
        _ labels: [String],
        _ series: [Series],
        _ yMax: Double
    ) {
        let axisCount = labels.count
        guard axisCount >= 3 else { return }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 * 0.85

        // Axis spokes, starting straight up and going clockwise.
        for i in 0..<axisCount {
            let angle = -Double.pi / 2 + Double(i) * (2 * .pi / Double(axisCount))
            let end = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )

            var spoke = Path()
            spoke.move(to: center)
            spoke.addLine(to: end)
            context.stroke(spoke, with: .color(gridColor), lineWidth: 1)
        }

        for s in series {
            var path = Path()

            for i in 0..<axisCount {
                let raw = i < s.values.count ? s.values[i] : nil
                let value = min(max(raw ?? 0, 0), yMax)
                let angle = -Double.pi / 2 + Double(i) * (2 * .pi / Double(axisCount))
                let r = radius * CGFloat(value / yMax)
                let point = CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))

                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            path.closeSubpath()
            context.fill(path, with: .color(s.color.opacity(0.25)))
            context.stroke(path, with: .color(s.color), lineWidth: 2)
        }
    }
}
