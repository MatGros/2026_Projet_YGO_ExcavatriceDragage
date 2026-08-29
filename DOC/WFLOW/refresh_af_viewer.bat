@echo off
REM Rafraichit les donnees de AF_VIEWER.html (sans serveur). Double-clic ou: refresh_af_viewer.bat
setlocal
cd /d "%~dp0..\.."
echo [1/3] check_fb_cartouche_sync...
python TOOLS\AGENT_WORKFLOW\scripts\check_fb_cartouche_sync.py || goto :err
echo [2/3] extract_functions_matrix...
python TOOLS\AGENT_WORKFLOW\scripts\extract_functions_matrix.py || goto :err
echo [3/3] generate_af_viewer...
python TOOLS\AGENT_WORKFLOW\scripts\generate_af_viewer.py || goto :err
echo.
echo OK - rouvre DOC\WFLOW\AF_VIEWER.html
pause
exit /b 0
:err
echo.
echo ECHEC - voir le message ci-dessus
pause
exit /b 1
