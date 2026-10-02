@echo off
setlocal
chcp 65001 >nul
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0TwinBench_ControlWin.ps1"
if errorlevel 1 (
  echo.
  echo [ERROR] The Control Win project workflow stopped with an error.
)
echo.
exit /b %errorlevel%
