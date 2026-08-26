@echo off
echo ============================================================
echo    GENERATION COMPLETE DES RAPPORTS HTML & CHRONOGRAMMES
echo ============================================================
python TOOLS/TEST_AUTO_CI/scripts/run_tests.py --all
echo.
echo ============================================================
echo   Termine ! Dashboard global : TOOLS/TEST_AUTO_CI/index.html
echo ============================================================
