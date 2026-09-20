@echo off
setlocal
set "SCRIPT_DIR=%~dp0"

echo ========================================================
echo   TROUBLESHOOTING : DSH01_T255D_FDC_BAS
echo   Reproduction exploratoire (hors CI officiel)
echo ========================================================

python "%SCRIPT_DIR%run.py" %*

echo.
pause
