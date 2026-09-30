@echo off
setlocal
cd /d "%~dp0..\..\.."
python "%~dp0modelica_viewer_m3.py"
if errorlevel 1 pause
