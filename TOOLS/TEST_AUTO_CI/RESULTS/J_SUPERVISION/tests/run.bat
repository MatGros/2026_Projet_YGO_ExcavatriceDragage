@echo off
setlocal
set "SCRIPT_DIR=%~dp0"

echo ========================================================
echo   TEST_AUTO_CI : Domaine J_SUPERVISION
echo   Rapport + Chronogrammes complets
echo ========================================================

python "%SCRIPT_DIR%..\..\..\run_tests.py" --domain J_SUPERVISION %*

echo.
pause
