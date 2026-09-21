@echo off
chcp 65001 >nul
title Grafcet Cycle Auto Lumineux & Anime - Excavatrice Dragage

echo ============================================================
echo ✨ GRAFCET CYCLE AUTO LUMINEUX & ANIME
echo ============================================================
echo.
echo [1/2] Compilation / Verification des donnees Cycle Auto...
python "%~dp0generate_cycle_auto.py"

if %ERRORLEVEL% NEQ 0 (
    echo [ERREUR] Echec lors de la generation de la vue lumineuse.
    pause
    exit /b 1
)

echo.
echo [2/2] Ouverture de la vue lumineuse et animee...
start "" "%~dp0cycle_auto_lumineux.html"

echo.
echo ============================================================
echo [OK] Page lumineuse ouverte dans le navigateur.
echo ============================================================
timeout /t 3 >nul
