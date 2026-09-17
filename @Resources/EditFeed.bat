@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "%~dp0EditFeed.ps1" -Index %1 -FType %2 -FeedsPath "%~dp0Feeds.inc"
