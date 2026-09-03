@echo off
chcp 65001 >nul
echo =======================================================================
echo 🧪 GROUPE 6 : PROGRAMMES PRINCIPAUX PRG_02..PRG_07 ET MAIN GLOBAL E2E
echo    (M_MAIN)
echo =======================================================================
echo.

python TOOLS\TEST_AUTO_CI\run_tests.py --domain M_MAIN

echo.
echo =======================================================================
echo 📄 Tableau de bord mis a jour : TOOLS\TEST_AUTO_CI\index.html
echo =======================================================================
pause
