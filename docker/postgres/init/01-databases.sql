CREATE DATABASE yiyi_testing OWNER yiyi;

-- The testing database deliberately runs in a non-UTC zone so that tests prove
-- the application pins its PostgreSQL session to UTC instead of relying on the
-- server default.
ALTER DATABASE yiyi_testing SET timezone TO 'America/Bogota';
