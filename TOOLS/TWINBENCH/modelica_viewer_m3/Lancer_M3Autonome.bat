@echo off
setlocal
cd /d "%~dp0"
python m3_native_viewer.py
if errorlevel 1 pause
