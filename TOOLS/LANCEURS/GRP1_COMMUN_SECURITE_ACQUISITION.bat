@echo off
cd /d "%~dp0\..\.."
chcp 65001 >nul
echo =======================================================================
echo 🧪 GROUPE 1 : COMMUN, AU/SECURITE, DIAGNOSTICS, JOYSTICK, CODEURS
echo    (A_COMMUN, B_AU_SECURITE, C_DIAG_RESEAUX, D_JOYSTICK, E_CODEURS)
echo =======================================================================
echo.

python TOOLS\TEST_AUTO_CI\run_tests.py --domain A_COMMUN B_AU_SECURITE C_DIAG_RESEAUX D_JOYSTICK E_CODEURS

echo.
echo =======================================================================
echo 📄 Tableau de bord mis a jour : TOOLS\TEST_AUTO_CI\index.html
echo =======================================================================
pause
