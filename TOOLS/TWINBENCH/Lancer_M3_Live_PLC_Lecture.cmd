@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0modelica_poc_m3\live_poc\Start_M3_Live.ps1" -PlcReadonly
if errorlevel 1 (
  echo.
  echo [ERREUR] Le mode PLC lecture ne s'est pas lance.
  pause
)
endlocal
