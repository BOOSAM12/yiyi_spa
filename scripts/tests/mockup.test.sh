#!/usr/bin/env bash
# Verifies that docs/mockup/ holds a complete, consistent export of the design mockup.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

fail() {
    echo "mockup: FAIL - $*" >&2
    exit 1
}

DIR="docs/mockup"

# 1. Index and tokens exist and are valid JSON.
for f in canvas.json tokens.json; do
    [ -f "$DIR/$f" ] || fail "$DIR/$f not found"
    node -e "JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'))" "$DIR/$f" 2>/dev/null \
        || fail "$DIR/$f is not valid JSON"
done

# 2 and 3. Every board listed in canvas.json has its file, and no unlisted board exists.
check="$(node -e '
const fs = require("fs");
const dir = process.argv[1];
const boards = Object.keys(JSON.parse(fs.readFileSync(dir + "/canvas.json", "utf8")).boards);
const files = fs.readdirSync(dir).filter((f) => f.endsWith(".dc.html"));
const missing = boards.filter((b) => !files.includes(b));
const extra = files.filter((f) => !boards.includes(f));
if (missing.length) { console.log("missing: " + missing.join(", ")); process.exit(1); }
if (extra.length) { console.log("not listed in canvas.json: " + extra.join(", ")); process.exit(1); }
console.log(boards.length);
' "$DIR")" || fail "$check"
count="$check"

# 4. Tokens are the YiYi Spa design system with the colors the frontend relies on.
node -e '
const t = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
if (t.name !== "YiYi Spa") { console.error("name is " + t.name); process.exit(1); }
const names = t.color.tokens.map((c) => c.name);
const required = ["surface", "ink", "rose", "rose-strong", "lavender-strong", "danger-strong"];
const absent = required.filter((n) => !names.includes(n));
if (absent.length) { console.error("missing color tokens: " + absent.join(", ")); process.exit(1); }
' "$DIR/tokens.json" || fail "tokens.json is not the expected design system"

echo "mockup: OK ($count artboards)"
