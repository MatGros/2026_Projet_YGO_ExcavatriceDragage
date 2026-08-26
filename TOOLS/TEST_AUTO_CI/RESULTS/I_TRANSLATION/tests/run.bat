@echo off
setlocal
set "SCRIPT_DIR=%~dp0"

echo ========================================================
echo   TEST_AUTO_CI : Domaine I_TRANSLATION
echo   Rapport + Chronogrammes complets
echo ========================================================

python "%SCRIPT_DIR%..\..\..\run_tests.py" --domain I_TRANSLATION %*

echo.
pause
