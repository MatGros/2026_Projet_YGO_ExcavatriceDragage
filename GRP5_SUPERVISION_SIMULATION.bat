@echo off
chcp 65001 >nul
echo =======================================================================
echo 🧪 GROUPE 5 : SUPERVISION, IHM ET SIMULATION
echo    (J_SUPERVISION, L_SIMULATION)
echo =======================================================================
echo.

python TOOLS\TEST_AUTO_CI\run_tests.py --domain J_SUPERVISION L_SIMULATION

echo.
echo =======================================================================
echo 📄 Tableau de bord mis a jour : TOOLS\TEST_AUTO_CI\index.html
echo =======================================================================
pause
