@echo off
setlocal
set "SCRIPT_DIR=%~dp0"

echo ========================================================
echo   TEST_AUTO_CI : Domaine C_DIAG_RESEAUX
echo   Rapport + Chronogrammes complets
echo ========================================================

python "%SCRIPT_DIR%..\..\..\run_tests.py" --domain C_DIAG_RESEAUX %*

echo.
pause
