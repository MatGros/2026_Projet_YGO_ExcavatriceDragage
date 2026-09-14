@echo off
setlocal
set "SCRIPT_DIR=%~dp0"

echo ========================================================
echo   TROUBLESHOOTING : CODEX_T287_M3
echo   Rapport exploratoire (hors CI officiel)
echo ========================================================

python "%SCRIPT_DIR%run.py" %*

echo.
pause
