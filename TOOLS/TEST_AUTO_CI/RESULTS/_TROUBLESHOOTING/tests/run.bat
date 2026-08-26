@echo off
setlocal
set "SCRIPT_DIR=%~dp0"

echo ========================================================
echo   TEST_AUTO_CI : Domaine _TROUBLESHOOTING
echo   Rapport + Chronogrammes complets
echo ========================================================

python "%SCRIPT_DIR%..\..\..\run_tests.py" --domain _TROUBLESHOOTING %*

echo.
pause
