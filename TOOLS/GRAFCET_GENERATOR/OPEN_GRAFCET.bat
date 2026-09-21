@echo off
chcp 65001 >nul
title Grafcet Generator & Cockpit Séquenceur - Excavatrice Dragage

echo ============================================================
echo 🧭 GRAFCET GENERATOR -- OUVERTURE DU COCKPIT SEQUENCEUR
echo ============================================================
echo.
echo [1/2] Generation / Rafraichissement de la vue HTML...
python "%~dp0generate_grafcet.py" --cycle data_homing.json --output index.html

if %ERRORLEVEL% NEQ 0 (
    echo [ERREUR] Echec lors de la generation du Grafcet HTML.
    pause
    exit /b 1
)

echo.
echo [2/2] Lancement du navigateur par defaut...
start "" "%~dp0index.html"

echo.
echo ============================================================
echo [OK] Page ouverte dans le navigateur.
echo ============================================================
timeout /t 3 >nul
