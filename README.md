# NativePHP Mobile Charts

A `<native:chart>` EDGE element for [NativePHP Mobile v4](https://nativephp.com/docs/mobile/4) — line, bar, and
radar charts, hand-drawn on real `Canvas` views (SwiftUI `Canvas` on iOS, Jetpack Compose `Canvas` on Android).
No Swift Charts, no third-party Compose charting library — a uniform hand-rolled renderer keeps all three chart
kinds visually consistent cross-platform, which matters most for radar: neither platform's native charting
framework supports it, so borrowing one framework's radar and another's line chart would look mismatched.

Community plugin, not affiliated with the NativePHP core team.

## Installation

```shell
composer require asteriskpound/nativephp-mobile-charts
php artisan vendor:publish --tag=nativephp-plugins-provider  # once, if not already published
php artisan native:plugin:register asteriskpound/nativephp-mobile-charts
php artisan native:plugin:list  # verify it shows as registered
```

Then rebuild the native app (`php artisan native:run ios|android`) — the renderers are native code and only
compile in at build time.

## Usage

```blade
<native:chart
    kind="line"
    :labels="['7/1', '7/8', '7/15']"
    :series="[
        ['name' => 'Bluecoats', 'color' => '#1DB954', 'values' => [92.5, 93.1, 94.0]],
        ['name' => 'Blue Devils', 'color' => '#3B82F6', 'values' => [93.0, 92.8, 94.5]],
    ]"
    class="w-full h-56 rounded-2xl bg-theme-surface"
/>
```

- `kind` — `line` (default), `bar`, or `radar`.
- `labels` — category / x-axis labels. For `radar` these are the axis names (GE, Visual, Music, …); for
  `line`/`bar` they're the x-axis positions and only need to line up in count with each series' `values`.
- `series` — an array of `{name, color?, values}`. `values` are aligned to `labels`; `null` marks a gap (e.g. a
  corps that sat out a show) rather than a zero.
- `y-max` — optional normalization ceiling. Needed whenever series don't share a natural 0..max range on their
  own (e.g. comparing captions with different max possible scores); defaults to the largest value present.

Titles, legends, and axis labels are **not** drawn by this element — compose them as ordinary `native:text` /
`native:row` elements around the `<native:chart>` tag. This element only draws the plot area, which is the one
part that genuinely needs native code; everything else EDGE already renders fine.

## Testing

```shell
composer install
vendor/bin/pest
```

PHP-side tests cover the manifest and the `Chart` element's prop resolution. The `Canvas` renderers themselves
are native code and need a device/simulator to verify visually — see NativePHP's
[UI Component Plugins](https://nativephp.com/docs/mobile/4/plugins/ui-components) docs.
