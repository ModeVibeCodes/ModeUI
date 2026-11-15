# Builds the probe addons (probes/) into droppable folders and zips under
# dist/probes/: each probe folder gets the shared ProbeKit.lua and the LICENSE,
# then one zip per probe plus ModeUI_Probes_All.zip with every probe.
# Run from anywhere:  powershell -ExecutionPolicy Bypass -File tools/build_probes.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root "probes"
$out = Join-Path $root "dist\probes"
$stage = Join-Path $out "stage"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force $stage | Out-Null

$probes = Get-ChildItem -Directory $source | Where-Object { $_.Name -like "ModeUI_Probe*" }
foreach ($probe in $probes) {
    $target = Join-Path $stage $probe.Name
    Copy-Item -Recurse $probe.FullName $target
    Copy-Item (Join-Path $source "Kit\ProbeKit.lua") $target
    Copy-Item (Join-Path $root "LICENSE") $target
    $zip = Join-Path $out ($probe.Name + ".zip")
    if (Test-Path $zip) { Remove-Item -Force $zip }
    Compress-Archive -Path $target -DestinationPath $zip
    Write-Output ("built " + $zip)
}
$all = Join-Path $out "ModeUI_Probes_All.zip"
if (Test-Path $all) { Remove-Item -Force $all }
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $all
Write-Output ("built " + $all)
