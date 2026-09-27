@echo off
setlocal
chcp 65001 >nul
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0TwinBench_ControlWin.ps1"
if errorlevel 1 (
  echo.
  echo [ERREUR] Le lanceur s'est termine avec une erreur.
)
echo.
pause

