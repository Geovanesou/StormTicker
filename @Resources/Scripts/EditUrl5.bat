@echo off
start "" powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "%~dp0..\EditFeed.ps1" -Index 5 -FType url -FeedsPath "%~dp0..\Feeds.inc"
