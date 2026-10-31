# shellcheck shell=bash
# Resolves the project toolchain without touching the system PATH.
#
# Usage: source scripts/lib/toolchain.sh
#   Exports PHP (a PHP >= 8.4 binary) and defines the `composer` function,
#   which runs Composer with that PHP. Returns non-zero with a Spanish
#   message when something is missing.
#
# Overrides: YIYI_PHP (PHP binary), YIYI_COMPOSER_PHAR (composer.phar path).

_yiyi_toolchain_fail() {
    echo "toolchain: $*" >&2
    return 1
}

_yiyi_toolchain_init() {
    local candidate
    if [ -n "${YIYI_PHP:-}" ]; then
        candidate="$YIYI_PHP"
    elif [ -f "C:/xampp3/php/php.exe" ]; then
        candidate="C:/xampp3/php/php.exe"
    else
        candidate="$(command -v php || true)"
    fi
    [ -n "$candidate" ] || { _yiyi_toolchain_fail "no se encontró PHP; se requiere PHP 8.4"; return 1; }

    local version_id version
    version_id="$("$candidate" -r 'echo PHP_VERSION_ID;' 2>/dev/null)" \
        || { _yiyi_toolchain_fail "no se pudo ejecutar '$candidate'; se requiere PHP 8.4"; return 1; }
    version="$("$candidate" -r 'echo PHP_VERSION;')"
    if [ "$version_id" -lt 80400 ]; then
        _yiyi_toolchain_fail "'$candidate' es PHP $version; se requiere PHP 8.4 (define YIYI_PHP para usar otro binario)"
        return 1
    fi

    local modules missing="" ext
    modules="$("$candidate" -m)"
    for ext in pdo_pgsql intl mbstring; do
        grep -qix "$ext" <<<"$modules" || missing="$missing $ext"
    done
    if [ -n "$missing" ]; then
        _yiyi_toolchain_fail "a '$candidate' (PHP $version) le faltan las extensiones:$missing"
        return 1
    fi

    local node_major
    node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
    if [ "$node_major" -lt 24 ]; then
        _yiyi_toolchain_fail "se requiere Node 24 o superior (encontrado: ${node_major})"
        return 1
    fi
    command -v pnpm >/dev/null 2>&1 || { _yiyi_toolchain_fail "no se encontró pnpm"; return 1; }

    export PHP="$candidate"
}

composer() {
    local phar="${YIYI_COMPOSER_PHAR:-C:/ProgramData/ComposerSetup/bin/composer.phar}"
    if [ -f "$phar" ]; then
        "$PHP" "$phar" "$@"
    else
        command composer "$@"
    fi
}

_yiyi_toolchain_init || return 1 2>/dev/null || exit 1
