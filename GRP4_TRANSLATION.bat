@echo off
chcp 65001 >nul
echo =======================================================================
echo 🧪 GROUPE 4 : TRANSLATION PONT M3
echo    (I_TRANSLATION)
echo =======================================================================
echo.

python TOOLS\TEST_AUTO_CI\run_tests.py --domain I_TRANSLATION

echo.
echo =======================================================================
echo 📄 Tableau de bord mis a jour : TOOLS\TEST_AUTO_CI\index.html
echo =======================================================================
pause
