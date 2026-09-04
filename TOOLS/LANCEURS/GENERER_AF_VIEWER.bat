@echo off
chcp 65001 >nul
title AF VIEWER — Generation ^& Synchronisation Spec AF

echo ============================================================
echo 📋 GENERATION ^& SYNCHRONISATION DU VISUALISEUR AF
echo ============================================================
echo.

cd /d "%~dp0\..\.."

echo [1/3] 🔍 Synchronisation cartouches FB (check_fb_cartouche_sync)...
python TOOLS\AGENT_WORKFLOW\scripts\check_fb_cartouche_sync.py
set _RC=%ERRORLEVEL%
if not "%_RC%"=="0" goto :err

echo.
echo [2/3] 🎯 Extraction matrice fonctions AF (extract_functions_matrix)...
python TOOLS\AGENT_WORKFLOW\scripts\extract_functions_matrix.py
set _RC=%ERRORLEVEL%
if not "%_RC%"=="0" goto :err

echo.
echo [3/3] 🌐 Generation du visualiseur HTML (generate_af_viewer)...
python TOOLS\AGENT_WORKFLOW\scripts\generate_af_viewer.py
set _RC=%ERRORLEVEL%
if not "%_RC%"=="0" goto :err

echo.
echo ============================================================
echo ✅ SUCCES : DOC\WFLOW\AF_VIEWER.html genere et synchronise !
echo ============================================================
echo.
pause
exit /b 0

:err
echo.
echo ============================================================
echo ❌ ECHEC de generation AF_VIEWER (code %_RC%)
echo ============================================================
echo.
pause
exit /b %_RC%