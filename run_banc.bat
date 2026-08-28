@echo off
chcp 65001 >nul
title Banc de test interactif FB_Cycle (T173)
cd /d "%~dp0"

echo ============================================================
echo   BANC DE TEST INTERACTIF FB_Cycle (binaire compile)
echo   Pilotage joystick : tu conduis les transitions
echo ============================================================
echo.

:: 1) Moteur : ne recompile QUE s'il manque (sinon on garde le binaire courant)
if not exist "TOOLS\TEST_AUTO_CI\engine\cycle_engine.exe" (
    echo [1/2] Compilation du moteur FB_Cycle (WORKING_COPY, jamais CODE/)...
    python "TOOLS\TEST_AUTO_CI\anim_bench\build_cycle_engine.py"
    if errorlevel 1 (
        echo.
        echo [ERREUR] Echec de la compilation du moteur.
        echo.
        pause
        exit /b 1
    )
) else (
    echo [1/2] Moteur deja compile (cycle_engine.exe) - OK
)

:: 2) Serveur + ouverture auto du navigateur
echo [2/2] Demarrage du banc web - le navigateur va s'ouvrir automatiquement...
echo        (Ctrl+C dans cette fenetre pour arreter)
echo.
python "TOOLS\TEST_AUTO_CI\anim_bench\cycle_bench_server.py"

echo.
echo Le serveur est arrete.
pause
