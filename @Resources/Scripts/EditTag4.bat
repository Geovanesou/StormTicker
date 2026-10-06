@echo off
start "" /wait powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "%~dp0..\EditFeed.ps1" -Index 4 -FType tag -FeedsPath "%~dp0..\Feeds.inc"
if not "%~1"=="" "%~1Rainmeter.exe" !RefreshApp
