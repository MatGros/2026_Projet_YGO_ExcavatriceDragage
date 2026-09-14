@echo off
rem Fichier volontairement ASCII pur
chcp 65001 >nul
title OMNIDIAG - Re-scan ST et Regeneration

echo ============================================================
echo   OMNIDIAG - RE-SCAN DU CODE SOURCE ST ET REGENERATION
echo ============================================================
echo.

cd /d "%~dp0"

python "%~dp0build_omnidiag.py"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERREUR] Echec lors du scan ST.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [OK] Code ST re-scanne avec succes.
echo [OK] Fichiers Excel, CSV et Viewer HTML mis a jour dans EXPORTS\
echo.
ping 127.0.0.1 -n 2 >nul
