@echo off
chcp 65001 >nul
echo =======================================================================
echo 🧪 GROUPE 2 : MODES ET CYCLES D'AUTOMATISME
echo    (F_MODES, G_CYCLE)
echo =======================================================================
echo.

python TOOLS\TEST_AUTO_CI\run_tests.py --domain F_MODES G_CYCLE

echo.
echo =======================================================================
echo 📄 Tableau de bord mis a jour : TOOLS\TEST_AUTO_CI\index.html
echo =======================================================================
pause
