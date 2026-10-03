# ==============================================================================
# StormTicker Standard 1.1.0 - Release Packaging Script
# Builds StormTicker_1.1.0.rmskin + StormTicker_1.1.0.zip (with README.txt)
# ==============================================================================
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ver  = '1.1.0'
$name = 'StormTicker'
$work = Join-Path $env:TEMP "st-build-$ver"
$skinDest = Join-Path $work "Skins\$name"

if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $skinDest -Force | Out-Null

# --- Stage skin files ---
Copy-Item "$root\StormTicker.ini"    $skinDest
Copy-Item "$root\TickerEngine.lua"   $skinDest
Copy-Item "$root\LICENSE"            $skinDest -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$skinDest\@Resources" -Force | Out-Null
Copy-Item "$root\@Resources\Config.inc"            "$skinDest\@Resources"
Copy-Item "$root\@Resources\Feeds.inc"             "$skinDest\@Resources"
Copy-Item "$root\@Resources\ThemeOverride.inc"     "$skinDest\@Resources"
Copy-Item "$root\@Resources\LanguageOverride.inc"  "$skinDest\@Resources"
Copy-Item "$root\@Resources\ModeOverride.inc"      "$skinDest\@Resources"
Copy-Item "$root\@Resources\EditFeed.bat"          "$skinDest\@Resources" -ErrorAction SilentlyContinue
Copy-Item "$root\@Resources\EditFeed.ps1"          "$skinDest\@Resources" -ErrorAction SilentlyContinue
Copy-Item "$root\@Resources\Themes"    "$skinDest\@Resources\Themes"    -Recurse
Copy-Item "$root\@Resources\Languages" "$skinDest\@Resources\Languages" -Recurse
Copy-Item "$root\@Resources\Scripts"   "$skinDest\@Resources\Scripts"   -Recurse
Copy-Item "$root\Settings" "$skinDest\Settings" -Recurse

# --- RMSKIN manifest ---
@"
[Metadata]
Name=$name
Author=Geovane Souza
Version=$ver
License=Proprietary - Copyright (c) 2026 Geovane Souza
Information=Asynchronous Wall Street News Ticker for Rainmeter (Standard Edition) - Themes, i18n, BBC Weather utility strip, Panoramic mode
"@ | Out-File -FilePath (Join-Path $work 'RMSKIN.ini') -Encoding Unicode

# --- Build .rmskin ---
$rmskin = Join-Path $root "$name`_$ver.rmskin"
if (Test-Path $rmskin) { Remove-Item $rmskin -Force }
Compress-Archive -Path "$work\*" -DestinationPath $rmskin -Force

# --- Build distribution .zip (rmskin + README.txt) ---
$readme = Join-Path $work 'README.txt'
@"
StormTicker Standard $ver
=========================
Asynchronous multi-channel news ticker for Rainmeter.

NEW IN 1.1.0
- 3 themes via right-click menu: StormTicker, Cyberpunk, Stealth
- BBC Weather utility strip with split-flap airport transition
- Native i18n: English, Portugues (BR), Espanol
- Panoramic single-line mode (75% news ribbon + 25% utility)
- Context-menu persistence via @Resources\*Override.inc

INSTALL: double-click the .rmskin file (Rainmeter 4.5+ required).
CUSTOMIZE: right-click the ticker for theme/language/layout options.
WEATHER: edit WeatherLocationID in @Resources\Config.inc (BBC location ID).

Proprietary - Copyright (c) 2026 Geovane Souza. All Rights Reserved.
"@ | Out-File -FilePath $readme -Encoding UTF8

$zip = Join-Path $root "$name`_$ver.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $rmskin,$readme -DestinationPath $zip -Force

Remove-Item $work -Recurse -Force
Write-Host "OK: $rmskin"
Write-Host "OK: $zip"
