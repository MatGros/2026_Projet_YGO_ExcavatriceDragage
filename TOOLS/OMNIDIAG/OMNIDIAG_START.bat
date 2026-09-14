@echo off
rem Fichier volontairement ASCII pur : le parseur cmd deforme les emojis UTF-8 et le "&" du title
chcp 65001 >nul
title OMNIDIAG - Explorateur de Diagnostics et Alarmes

echo ============================================================
echo   OMNIDIAG - EXPLORATEUR DE DIAGNOSTICS ET ALARMES
echo ============================================================
echo.

cd /d "%~dp0"

if "%1"=="-r" (
    echo Regeneration demandee...
    python "%~dp0build_omnidiag.py"
    echo.
)
if "%1"=="--rebuild" (
    echo Regeneration demandee...
    python "%~dp0build_omnidiag.py"
    echo.
)

if not exist "%~dp0EXPORTS\omnidiag_viewer.html" (
    echo Generation initiale des diagnostics depuis le code source...
    python "%~dp0build_omnidiag.py"
    echo.
)

rem Lancement du serveur en arriere-plan s'il n'est pas deja actif
start /b "" python "%~dp0..\TASK_MANAGER\task_server.py" 8081 >nul 2>&1

rem Attente courte pour initialisation
ping 127.0.0.1 -n 2 >nul

echo Ouverture de l'explorateur interactif...
start "" "http://127.0.0.1:8081/omnidiag"

echo.
echo [OK] OMNIDIAG ouvert sur http://127.0.0.1:8081/omnidiag
echo [INFO] Le bouton 'Re-scanner le code ST' est operationnel en direct !
echo.
