@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0modelica_poc_m3\live_poc\Start_M3_Live.ps1"
if errorlevel 1 (
  echo.
  echo [ERREUR] Le POC M3 live ne s'est pas lance. Voir le message ci-dessus.
  pause
)
endlocal
