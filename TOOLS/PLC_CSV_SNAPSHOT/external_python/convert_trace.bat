@echo off
setlocal
REM Lanceur double-clic / glisser-deposer pour les traces CODESYS.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0select_trace_and_export.ps1" "%~1"
if errorlevel 1 (
  echo.
  echo Echec de la conversion.
  pause
)
endlocal
