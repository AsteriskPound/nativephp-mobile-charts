<?php

namespace Asteriskpound\NativePhpMobileCharts\Elements;

use Native\Mobile\Edge\CallbackRegistry;
use Native\Mobile\Edge\Element;
use Traversable;

/**
 * A hand-drawn line/bar/radar chart — see `ChartRenderer.kt`/`.swift` for the
 * actual Canvas drawing. This element only normalizes props onto the wire;
 * `labels`/`series` are JSON-encoded since the wire format has no typed
 * list-of-floats prop accessor today.
 */
class Chart extends Element
{
    protected string $type = 'chart';

    protected array $componentProps = [
        'kind' => 'line',
    ];

    public static function make(): static
    {
        return new static;
    }

    public function kind(string $kind): static
    {
        $this->componentProps['kind'] = $kind;

        return $this;
    }

    /**
     * @param  array<int, string>  $labels
     */
    public function labels(array $labels): static
    {
        $this->componentProps['labels'] = json_encode(array_values($labels));

        return $this;
    }

    /**
     * @param  array<int, array{name: string, color?: string, values: array<int, float|null>}>  $series
     */
    public function series(array $series): static
    {
        $this->componentProps['series'] = json_encode(array_values($series));

        return $this;
    }

    /**
     * Normalization ceiling for the value axis (radar's spoke length, bar's
     * full height, line's plot-area top). Needed whenever series don't share
     * a natural 0..max range on their own — e.g. a caption breakdown mixing
     * captions with different max possible scores. Falls back to the
     * largest value across all series when omitted.
     */
    public function yMax(float $max): static
    {
        $this->componentProps['y_max'] = $max;

        return $this;
    }

    public function applyAttributes(array $attrs): void
    {
        if (isset($attrs['kind'])) {
            $this->kind((string) $attrs['kind']);
        }

        if (($labels = $attrs['labels'] ?? null) !== null) {
            $this->labels($this->normalizeList($labels));
        }

        if (($series = $attrs['series'] ?? null) !== null) {
            $this->series($this->normalizeList($series));
        }

        if (($yMax = $attrs['y-max'] ?? $attrs['y_max'] ?? null) !== null) {
            $this->yMax((float) $yMax);
        }
    }

    /**
     * `:labels="..."`/`:series="..."` most often hand over a plain PHP array
     * or an Arrayable straight from the component's own computed data; a
     * pre-encoded JSON string is also accepted for programmatic
     * `Chart::make()` use.
     */
    private function normalizeList(mixed $value): array
    {
        if (is_string($value)) {
            return json_decode($value, true) ?? [];
        }

        if ($value instanceof Traversable) {
            return iterator_to_array($value);
        }

        if (is_object($value) && method_exists($value, 'toArray')) {
            return $value->toArray();
        }

        return (array) $value;
    }

    protected function resolveProps(CallbackRegistry $registry): array
    {
        return $this->componentProps;
    }
}
