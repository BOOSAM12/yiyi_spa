<?php

declare(strict_types=1);

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\DB;
use RuntimeException;

abstract class TestCase extends BaseTestCase
{
    private const TESTING_DATABASE = 'yiyi_testing';

    /**
     * Runs before RefreshDatabase migrates: never wipe anything but the testing database.
     */
    protected function beforeRefreshingDatabase(): void
    {
        $this->ensureSafeTestingDatabase();
    }

    protected function ensureSafeTestingDatabase(): void
    {
        $connection = DB::connection();
        $driver = $connection->getDriverName();
        $database = $connection->getDatabaseName();

        if ($driver !== 'pgsql' || $database !== self::TESTING_DATABASE) {
            throw new RuntimeException(sprintf(
                'Refusing to touch database "%s" (%s): tests only run against %s on PostgreSQL. '
                .'Is a cached config (bootstrap/cache/config.php) overriding phpunit.xml?',
                $database,
                $driver,
                self::TESTING_DATABASE,
            ));
        }
    }
}
