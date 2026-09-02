@echo off
chcp 65001 >nul
echo =======================================================================
echo ⚡ LANCEMENT RAPIDE DU BANC DE TESTS CI (ASSERTIONS SEULES SANS HTML)
echo =======================================================================
echo.

python TOOLS\TEST_AUTO_CI\run_tests.py --all --fast

echo.
echo =======================================================================
echo ✅ Execution rapide terminee.
echo =======================================================================
pause
