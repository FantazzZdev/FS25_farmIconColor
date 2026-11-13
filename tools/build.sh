#!/usr/bin/env bash
# Construit dist/FS25_farmIconColor.zip avec modDesc.xml a la racine du ZIP.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$root/dist"
rm -f "$root/dist/FS25_farmIconColor.zip"
(cd "$root/mod" && zip -r -X -q "$root/dist/FS25_farmIconColor.zip" . -x '.*')
echo "ZIP cree : $root/dist/FS25_farmIconColor.zip"
