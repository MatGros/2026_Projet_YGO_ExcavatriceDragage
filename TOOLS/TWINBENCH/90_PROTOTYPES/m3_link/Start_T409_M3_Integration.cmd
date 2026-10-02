@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start_T409_M3_Integration.ps1"
if errorlevel 1 pause
