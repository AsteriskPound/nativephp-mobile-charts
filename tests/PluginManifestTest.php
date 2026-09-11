<?php

test('nativephp.json is valid and declares the chart component with both renderers', function () {
    $manifest = json_decode(file_get_contents(__DIR__.'/../nativephp.json'), associative: true, flags: JSON_THROW_ON_ERROR);

    expect($manifest['namespace'])->toBe('Charts');
    expect($manifest['components'])->toHaveCount(1);

    $chart = $manifest['components'][0];

    expect($chart['type'])->toBe('chart');
    expect($chart)->toHaveKeys(['type', 'element', 'blade', 'android_renderer', 'ios_renderer', 'self_closing']);
    expect($chart['self_closing'])->toBeTrue();
    expect(class_exists($chart['element']))->toBeTrue("Missing element class: {$chart['element']}");
    expect(class_exists($chart['blade']))->toBeTrue("Missing blade component class: {$chart['blade']}");
});

test('composer.json name matches the PSR-4 namespace used by the manifest classes', function () {
    $composer = json_decode(file_get_contents(__DIR__.'/../composer.json'), associative: true, flags: JSON_THROW_ON_ERROR);

    expect($composer['name'])->toBe('asteriskpound/nativephp-mobile-charts');
    expect($composer['type'])->toBe('nativephp-plugin');
    expect($composer['autoload']['psr-4'])->toHaveKey('Asteriskpound\\NativePhpMobileCharts\\');
});
