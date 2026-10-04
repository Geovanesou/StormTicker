# ==============================================================================
# StormTicker Standard 1.2.0 - Release Packaging Script
# Builds StormTicker_1.2.0.rmskin + StormTicker_1.2.0.zip (with README.txt)
# ==============================================================================
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ver  = '1.2.0'
$name = 'StormTicker'
$dist = Join-Path (Split-Path -Parent $root) 'dist'
$work = Join-Path $env:TEMP "st-build-$ver"
$skinDest = Join-Path $work "Skins\$name"

if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $skinDest -Force | Out-Null
if (!(Test-Path $dist)) { New-Item -ItemType Directory -Path $dist -Force | Out-Null }

# --- Stage skin files ---
Copy-Item "$root\Box"              "$skinDest\Box"        -Recurse
Copy-Item "$root\Panoramic"        "$skinDest\Panoramic"  -Recurse
Copy-Item "$root\TickerEngine.lua" $skinDest
Copy-Item "$root\LICENSE"          $skinDest -ErrorAction SilentlyContinue
Copy-Item "$root\@Resources"       "$skinDest\@Resources" -Recurse
Copy-Item "$root\Settings"         "$skinDest\Settings"   -Recurse

# --- Sanitize user-state in staged copies (ship factory defaults, keep working tree) ---
$unicode = [System.Text.Encoding]::Unicode
$fixes = @(
    @{ File = "$skinDest\@Resources\Config.inc";           Pattern = '(?m)^FirstRun=.*';   Value = 'FirstRun=1' },
    @{ File = "$skinDest\@Resources\LanguageOverride.inc"; Pattern = '(?m)^Language=.*';   Value = 'Language=English' },
    @{ File = "$skinDest\@Resources\ModeOverride.inc";     Pattern = '(?m)^ViewMode=.*';   Value = 'ViewMode=0' },
    @{ File = "$skinDest\@Resources\ThemeOverride.inc";    Pattern = '(?m)^ThemeName=.*';  Value = 'ThemeName=StormTicker' },
    @{ File = "$skinDest\Settings\Settings.ini";           Pattern = '(?m)^CurrentTab=.*'; Value = 'CurrentTab=0' }
)
foreach ($fix in $fixes) {
    if (Test-Path $fix.File) {
        $txt = [System.IO.File]::ReadAllText($fix.File, $unicode)
        [System.IO.File]::WriteAllText($fix.File, ($txt -replace $fix.Pattern, $fix.Value), $unicode)
    }
}

# --- RMSKIN manifest ---
@"
[rmskin]
Name=$name
Author=Geovane Souza
Version=$ver
LoadType=Skin
Load=StormTicker\Box\Box StormTicker.ini
MinimumRainmeter=4.5.26.3894
MinimumWindows=5.1
"@ | Out-File -FilePath (Join-Path $work 'RMSKIN.ini') -Encoding UTF8

# --- Build .rmskin (Compress-Archive exige .zip; renomeia depois) ---
$rmskin = Join-Path $dist "$name`_$ver.rmskin"
$tmpZip = Join-Path $env:TEMP "st-pkg-$ver.zip"
if (Test-Path $rmskin) { Remove-Item $rmskin -Force }
Compress-Archive -Path "$work\*" -DestinationPath $tmpZip -Force
Move-Item $tmpZip $rmskin -Force

# --- Build distribution .zip (rmskin + README.txt) ---
$readme = Join-Path $work 'README.txt'
@"
StormTicker Standard $ver
=========================
Asynchronous multi-channel news ticker and weather suite for Rainmeter.

NEW IN 1.2.0
- English default UI + first-run onboarding wizard (opens Settings on first boot)
- Settings panel 100% internationalized (EN / PT-BR / ES) - no leftover hardcoded text
- Interactive click-to-open article navigation in Panoramic mode (OpenPanLink)
- SafeUpper: correct uppercase for accented latin chars (PT/ES headlines)
- Right-click Settings shortcut on every Box and Panoramic skin
- 3 hand-crafted themes: StormTicker, Cyberpunk, Stealth
- Open-Meteo Weather utility strip with 3-day forecast rotation
- Panoramic single-line mode (75% news ribbon + 25% utility)

INSTALL: double-click the .rmskin file (Rainmeter 4.5+ required).
CUSTOMIZE: right-click the ticker for theme/language/layout/settings options.
WEATHER: edit WeatherCity/WeatherLatitude/WeatherLongitude in @Resources\Config.inc or via Settings.

Proprietary - Copyright (c) 2026 Geovane Souza. All Rights Reserved.
"@ | Out-File -FilePath $readme -Encoding UTF8

$zip = Join-Path $dist "$name`_$ver.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $rmskin,$readme -DestinationPath $zip -Force

Remove-Item $work -Recurse -Force
Write-Host "OK: $rmskin"
Write-Host "OK: $zip"
