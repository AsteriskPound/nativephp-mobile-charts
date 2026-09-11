<?php

use Asteriskpound\NativePhpMobileCharts\Elements\Chart;
use Native\Mobile\Edge\CallbackRegistry;

function chartProps(Chart $chart): array
{
    return $chart->getResolvedProps(new CallbackRegistry);
}

test('defaults to a line chart with no labels or series', function () {
    $props = chartProps(Chart::make());

    expect($props['kind'])->toBe('line');
    expect($props)->not->toHaveKey('labels');
    expect($props)->not->toHaveKey('series');
});

test('fluent labels/series/yMax encode to JSON on the wire', function () {
    $props = chartProps(
        Chart::make()
            ->kind('bar')
            ->labels(['7/1', '7/8'])
            ->series([
                ['name' => 'Bluecoats', 'color' => '#1DB954', 'values' => [92.5, null]],
            ])
            ->yMax(100.0)
    );

    expect($props['kind'])->toBe('bar');
    expect(json_decode($props['labels'], true))->toBe(['7/1', '7/8']);
    expect(json_decode($props['series'], true))->toBe([
        ['name' => 'Bluecoats', 'color' => '#1DB954', 'values' => [92.5, null]],
    ]);
    expect($props['y_max'])->toBe(100.0);
});

test('applyAttributes normalizes a plain array from a Blade :labels/:series binding', function () {
    $chart = Chart::make();
    $chart->applyAttributes([
        'kind' => 'radar',
        'labels' => ['GE', 'Visual', 'Music'],
        'series' => [['name' => 'A', 'values' => [80.0, 70.0, 90.0]]],
        'y-max' => '100',
    ]);

    $props = chartProps($chart);

    expect($props['kind'])->toBe('radar');
    expect(json_decode($props['labels'], true))->toBe(['GE', 'Visual', 'Music']);
    expect($props['y_max'])->toBe(100.0);
});

test('applyAttributes accepts a pre-encoded JSON string for labels/series', function () {
    $chart = Chart::make();
    $chart->applyAttributes([
        'labels' => '["7/1","7/8"]',
        'series' => '[{"name":"A","values":[1,2]}]',
    ]);

    $props = chartProps($chart);

    expect(json_decode($props['labels'], true))->toBe(['7/1', '7/8']);
    expect(json_decode($props['series'], true))->toBe([['name' => 'A', 'values' => [1, 2]]]);
});
