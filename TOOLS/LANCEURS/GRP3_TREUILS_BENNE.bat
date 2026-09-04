@echo off
cd /d "%~dp0\..\.."
chcp 65001 >nul
echo =======================================================================
echo 🧪 GROUPE 3 : TREUILS ET BENNE
echo    (H_TREUILS_BENNE)
echo =======================================================================
echo.

python TOOLS\TEST_AUTO_CI\run_tests.py --domain H_TREUILS_BENNE

echo.
echo =======================================================================
echo 📄 Tableau de bord mis a jour : TOOLS\TEST_AUTO_CI\index.html
echo =======================================================================
pause
