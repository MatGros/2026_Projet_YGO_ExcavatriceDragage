@echo off
chcp 65001 >nul
echo =======================================================================
echo 🧪 LANCEMENT COMPLET DU BANC DE TESTS CI (AVEC RAPPORTS HTML & INDEX)
echo =======================================================================
echo.

python TOOLS\TEST_AUTO_CI\run_tests.py --all

echo.
echo =======================================================================
echo 📄 Tableau de bord genere : TOOLS\TEST_AUTO_CI\index.html
echo =======================================================================
pause
