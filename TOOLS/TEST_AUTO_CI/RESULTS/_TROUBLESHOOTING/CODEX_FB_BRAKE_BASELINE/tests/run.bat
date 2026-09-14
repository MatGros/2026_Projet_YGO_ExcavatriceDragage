@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
echo ========================================================
echo   TROUBLESHOOTING : CODEX_FB_BRAKE_BASELINE
echo   Chronogramme FB_Brake — deux etapes
echo ========================================================
python "%SCRIPT_DIR%run.py" %*
echo.
pause
