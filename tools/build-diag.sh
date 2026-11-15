#!/usr/bin/env bash
# TEST build only: the normal mod + tools/dev/farmIconColorDiag.lua ([FIC-DIAG] lines in log.txt).
# Never upload this ZIP to ModHub.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
cp -r "$root/mod/." "$work/"
mkdir -p "$work/scripts/dev"
cp "$root/tools/dev/farmIconColorDiag.lua" "$work/scripts/dev/"
python3 - "$work/modDesc.xml" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
a = '<sourceFile filename="scripts/logoPicker.lua" />'
assert a in s
s = s.replace(a, a + '\n        <sourceFile filename="scripts/dev/farmIconColorDiag.lua" />', 1)
open(p, "w", encoding="utf-8").write(s)
PY
mkdir -p "$root/dist/diag"
rm -f "$root/dist/diag/FS25_farmIconColor.zip"
(cd "$work" && zip -r -X -q "$root/dist/diag/FS25_farmIconColor.zip" . -x '.*')
rm -rf "$work"
echo "ZIP de TEST : $root/dist/diag/FS25_farmIconColor.zip (ne pas publier)"
