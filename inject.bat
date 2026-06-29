@echo off
cd /d "%~dp0"
python tools\inject.py %*
