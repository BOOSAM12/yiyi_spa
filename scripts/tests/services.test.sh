#!/usr/bin/env bash
# Verifies that this project's development services are up and are the right ones.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

fail() {
    echo "services: FAIL - $*" >&2
    exit 1
}

PG_PORT="${YIYI_PG_PORT:-5418}"
MAILPIT_UI_PORT="${YIYI_MAILPIT_UI_PORT:-8026}"

[ -f docker-compose.yml ] || fail "docker-compose.yml not found"

psql_scalar() {
    docker compose exec -T postgres psql -U yiyi -d yiyi -tAc "$1" 2>/dev/null | tr -d '[:space:]'
}

# 1. PostgreSQL 18 or newer.
pg_version="$(psql_scalar 'show server_version_num')"
[ -n "$pg_version" ] || fail "postgres is not answering"
[ "$pg_version" -ge 180000 ] || fail "server_version_num is $pg_version, expected >= 180000"

# 2. The isolated testing database exists.
[ "$(psql_scalar "select 1 from pg_database where datname = 'yiyi_testing'")" = "1" ] \
    || fail "database yiyi_testing does not exist"

# 3. Redis answers.
[ "$(docker compose exec -T redis redis-cli ping 2>/dev/null | tr -d '[:space:]')" = "PONG" ] \
    || fail "redis does not answer PONG"

# 4. Mailpit API answers on this project's UI port.
curl -fsS "http://127.0.0.1:${MAILPIT_UI_PORT}/api/v1/info" >/dev/null 2>&1 \
    || fail "mailpit API not reachable on port ${MAILPIT_UI_PORT}"

# 5. The PostgreSQL host port is published by this project's container.
published="$(docker compose port postgres 5432 2>/dev/null)"
[ "${published##*:}" = "$PG_PORT" ] || fail "postgres is published on '${published}', expected port ${PG_PORT}"

echo "services: OK"
