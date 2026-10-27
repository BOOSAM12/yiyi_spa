<?php

declare(strict_types=1);

arch()->preset()->php();

arch()->preset()->security();

arch('shared kernel depends on no module')
    ->expect('App\Shared')
    ->not->toUse(['App\Modules', 'App\Platform']);

arch('modules never depend on the platform layer')
    ->expect('App\Modules')
    ->not->toUse('App\Platform');

arch('strict types everywhere')
    ->expect('App')
    ->toUseStrictTypes();
