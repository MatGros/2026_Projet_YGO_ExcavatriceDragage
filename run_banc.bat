@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cd /d "%~dp0"

title Banc de test interactif FB_Cycle - T173

echo ============================================================
echo   BANC DE TEST INTERACTIF FB_Cycle - binaire compile
echo   Pilotage joystick : tu conduis les transitions
echo ============================================================
echo.

REM --- 0) Trouver Python - fallbacks ---
set "PYTHON="
where python >nul 2>&1 && set "PYTHON=python"
if not defined PYTHON where py >nul 2>&1 && set "PYTHON=py -3"
if not defined PYTHON if exist "C:\Python314\python.exe" set "PYTHON=C:\Python314\python.exe"
if not defined PYTHON if exist "C:\Python313\python.exe" set "PYTHON=C:\Python313\python.exe"
if not defined PYTHON if exist "C:\Python312\python.exe" set "PYTHON=C:\Python312\python.exe"

if not defined PYTHON (
    echo [ERREUR] Python introuvable.
    echo          Ouvre ce .bat et fixe la ligne:  set "PYTHON=C:\Python314\python.exe"
    pause
    exit /b 1
)
echo [Python] %PYTHON%
echo.

REM --- 1) Moteur : ne recompile que s'il manque ---
if not exist "TOOLS\TEST_AUTO_CI\engine\cycle_engine.exe" (
    echo [1/2] Compilation du moteur FB_Cycle - WORKING_COPY, jamais CODE...
    %PYTHON% "TOOLS\TEST_AUTO_CI\anim_bench\build_cycle_engine.py"
    if errorlevel 1 (
        echo.
        echo [ERREUR] Echec de la compilation du moteur.
        pause
        exit /b 1
    )
) else (
    echo [1/2] Moteur deja compile - cycle_engine.exe - OK
)

REM --- 2) Serveur + ouverture auto navigateur ---
echo [2/2] Demarrage du banc web - le navigateur va s'ouvrir automatiquement...
echo        Garde cette fenetre OUVERTE - Ctrl+C pour arreter le serveur.
echo.
%PYTHON% "TOOLS\TEST_AUTO_CI\anim_bench\cycle_bench_server.py"

echo.
echo Le serveur est arrete.
pause
