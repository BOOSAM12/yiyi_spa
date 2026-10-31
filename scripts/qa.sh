#!/usr/bin/env bash
# The project's single verification command. CI and the swarm gates run the same blocks.
#
# Usage: bash scripts/qa.sh [--e2e]
#   Runs, in order and stopping at the first failure: toolchain, mockup, backend
#   (composer qa) and frontend (pnpm qa). --e2e adds the Playwright smoke tests.
#   The backend block needs the Docker services running (docker compose up -d --wait).
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

with_e2e=false
for arg in "$@"; do
    case "$arg" in
        --e2e) with_e2e=true ;;
        *) echo "qa: unknown option '$arg' (usage: bash scripts/qa.sh [--e2e])" >&2; exit 2 ;;
    esac
done

# shellcheck source=lib/toolchain.sh
source scripts/lib/toolchain.sh || exit 1

summary=()

print_summary() {
    echo
    echo "== QA summary =="
    printf '%s\n' "${summary[@]}"
}

run_block() {
    local name="$1"
    shift
    echo "== $name =="
    if "$@"; then
        summary+=("$(printf '%-10s OK' "$name")")
    else
        summary+=("$(printf '%-10s FAIL' "$name")")
        print_summary
        exit 1
    fi
}

# Subshells keep the cd local; composer() from toolchain.sh is visible to them.
backend_qa() { (cd backend && composer qa --no-ansi </dev/null); }
frontend_qa() { (cd frontend && pnpm qa </dev/null); }
frontend_e2e() { (cd frontend && pnpm e2e </dev/null); }

run_block toolchain bash scripts/tests/toolchain.test.sh
run_block mockup bash scripts/tests/mockup.test.sh
run_block backend backend_qa
run_block frontend frontend_qa
if [ "$with_e2e" = true ]; then
    run_block e2e frontend_e2e
fi

print_summary
