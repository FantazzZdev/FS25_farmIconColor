# Construit FS25_farmIconColor.zip (modDesc.xml a la racine du ZIP).
# Usage (PowerShell, depuis la racine du depot) :
#   ./tools/build.ps1                 -> dist/FS25_farmIconColor.zip
#   ./tools/build.ps1 -Install        -> copie aussi le ZIP dans le dossier mods de FS25
param([switch]$Install)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root "mod"
$dist = Join-Path $root "dist"
$zip  = Join-Path $dist "FS25_farmIconColor.zip"

New-Item -ItemType Directory -Force -Path $dist | Out-Null
if (Test-Path $zip) { Remove-Item $zip }

Compress-Archive -Path (Join-Path $src "*") -DestinationPath $zip
Write-Host "ZIP cree : $zip"

if ($Install) {
    $mods = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "My Games\FarmingSimulator2025\mods"
    Copy-Item $zip -Destination $mods -Force
    Write-Host "Copie dans : $mods"
}
