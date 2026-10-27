<?php

declare(strict_types=1);

use Illuminate\Support\Facades\DB;

it('never loads a cached application config during tests', function (): void {
    // A cached config (artisan config:cache / optimize) would bypass phpunit.xml and
    // point the suite at the development database.
    expect(app()->getCachedConfigPath())->toEndWith('config.testing.php');
});

it('refuses to refresh any database other than yiyi_testing', function (): void {
    config(['database.connections.pgsql.database' => 'yiyi']);
    DB::purge('pgsql');

    expect(fn () => $this->ensureSafeTestingDatabase())
        ->toThrow(RuntimeException::class, 'yiyi_testing');
});

it('accepts the isolated testing database', function (): void {
    $this->ensureSafeTestingDatabase();

    expect(DB::connection()->getDatabaseName())->toBe('yiyi_testing');
});
