@echo off
setlocal
cd /d "%~dp0modelica_atelier\rumoca_poc"
title TwinBench - Atelier interactif
echo ============================================================
echo TwinBench - Atelier interactif hors ligne
echo ============================================================
echo.
echo Demarrage de la plante OpenModelica M3 + M1/M2...
echo Le navigateur va s'ouvrir sur http://127.0.0.1:8777
echo.
py -3.13 interactive_server.py
echo.
echo TwinBench est arrete. Appuyez sur une touche pour fermer.
pause >nul
