#!/usr/bin/env bash
# Construit dist/FS25_farmIconColor.zip avec modDesc.xml a la racine du ZIP.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/dist"
rm -f "$root/dist/FS25_farmIconColor.zip"
(cd "$root/mod" && zip -r -X -q "$root/dist/FS25_farmIconColor.zip" . -x '.*')
echo "ZIP cree : $root/dist/FS25_farmIconColor.zip"

# Standalone converter page (one HTML file, dds-core.js inlined), committed in
# converter/ so players can download it from GitHub (no web hosting needed).
python3 - "$root" <<'PY'
import os, sys
root = sys.argv[1]
html = open(root + "/tools/logo-converter/index.html", encoding="utf-8").read()
core = open(root + "/tools/logo-converter/dds-core.js", encoding="utf-8").read()
tag = '<script src="dds-core.js"></script>'
assert tag in html
page = html.replace(tag, "<script>\n" + core + "\n</script>")
os.makedirs(root + "/converter", exist_ok=True)
for path in (root + "/dist/FarmIconColor-LogoConverter.html", root + "/converter/FarmIconColor-LogoConverter.html"):
    open(path, "w", encoding="utf-8", newline="\n").write(page)
PY
echo "Convertisseur : $root/converter/FarmIconColor-LogoConverter.html"
