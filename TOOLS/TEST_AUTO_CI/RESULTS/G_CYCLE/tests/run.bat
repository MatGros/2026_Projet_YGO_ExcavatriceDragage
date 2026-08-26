@echo off
setlocal
set "SCRIPT_DIR=%~dp0"

echo ========================================================
echo   TEST_AUTO_CI : Domaine G_CYCLE
echo   Rapport + Chronogrammes complets
echo ========================================================

python "%SCRIPT_DIR%..\..\..\run_tests.py" --domain G_CYCLE %*

echo.
pause
