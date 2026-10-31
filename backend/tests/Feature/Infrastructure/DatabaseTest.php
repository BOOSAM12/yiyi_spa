<?php

declare(strict_types=1);

use Illuminate\Support\Facades\DB;

it('runs against PostgreSQL, never SQLite', function (): void {
    expect(DB::connection()->getDriverName())->toBe('pgsql');
});

it('uses the isolated testing database', function (): void {
    expect(DB::connection()->getDatabaseName())->toBe('yiyi_testing');
});

it('pins the PostgreSQL session time zone to UTC', function (): void {
    expect(DB::scalar('show timezone'))->toBe('UTC');
});

it('runs on PostgreSQL 18 or newer', function (): void {
    expect((int) DB::scalar('show server_version_num'))->toBeGreaterThanOrEqual(180000);
});
