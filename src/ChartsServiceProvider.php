<?php

namespace Asteriskpound\NativePhpMobileCharts;

use Illuminate\Support\ServiceProvider;

/**
 * The `chart` element is registered declaratively from `nativephp.json`'s
 * `components` array (an app's `NativeServiceProvider::plugins()` lists this
 * provider so the native build compiler discovers that manifest) — nothing
 * needs registering here.
 */
class ChartsServiceProvider extends ServiceProvider {}
