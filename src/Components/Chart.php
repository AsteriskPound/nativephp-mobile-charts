<?php

namespace Asteriskpound\NativePhpMobileCharts\Components;

use Native\Mobile\Edge\Components\Native\NativeBladeComponent;

class Chart extends NativeBladeComponent
{
    protected bool $isSelfClosing = true;

    protected function elementType(): string
    {
        return 'chart';
    }
}
