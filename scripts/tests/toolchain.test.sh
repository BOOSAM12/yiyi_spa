#!/usr/bin/env bash
# Verifies that the project toolchain resolves to the versions the plan requires.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

fail() {
    echo "toolchain: FAIL - $*" >&2
    exit 1
}

# 1. Sourcing the resolver succeeds and yields PHP >= 8.4.
# shellcheck source=../lib/toolchain.sh
source scripts/lib/toolchain.sh || fail "scripts/lib/toolchain.sh could not be sourced"
[ -n "${PHP:-}" ] || fail "PHP is not exported"
php_id="$("$PHP" -r 'echo PHP_VERSION_ID;')"
[ "$php_id" -ge 80400 ] || fail "PHP_VERSION_ID is $php_id, expected >= 80400"

# 2. Required PHP extensions.
php_modules="$("$PHP" -m)"
for ext in pdo_pgsql intl mbstring; do
    grep -qix "$ext" <<<"$php_modules" || fail "PHP extension '$ext' is missing"
done

# 3. Composer runs.
composer --no-ansi --version 2>/dev/null | grep -q 'Composer version 2\.' || fail "composer does not report version 2"

# 4. An older PHP is rejected with a message that names the required version.
if [ -f "C:/xampp2/php/php.exe" ]; then
    out="$(YIYI_PHP=C:/xampp2/php/php.exe bash -c 'source scripts/lib/toolchain.sh' 2>&1)"
    status=$?
    [ "$status" -ne 0 ] || fail "PHP 8.3 was accepted"
    grep -q '8\.4' <<<"$out" || fail "rejection message does not mention 8.4: $out"
fi

# 5. Node >= 24 and pnpm.
node_major="$(node -p 'process.versions.node.split(".")[0]')"
[ "$node_major" -ge 24 ] || fail "Node major is $node_major, expected >= 24"
pnpm -v >/dev/null 2>&1 || fail "pnpm is not available"

# 6. No CRLF line endings in shell scripts.
# The CR must live in a variable: MSYS bash 5.2 expands $'\r' inside "$(...)" to an
# empty string, and an empty pattern matches every file. -U stops MSYS grep from
# stripping the CR at end of line before matching.
cr=$'\r'
crlf_files="$(grep -rlIU "$cr" scripts --include='*.sh' || true)"
[ -z "$crlf_files" ] || fail "CRLF line endings in: $crlf_files"

echo "toolchain: OK"
