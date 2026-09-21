@echo off
chcp 65001 >nul
title Grafcet Cycle Homing Double Vue & Zoom Capteur - Excavatrice Dragage

echo ============================================================
echo 🧭 GRAFCET HOMING -- DOUBLE VUE & ZOOM CAPTEUR HAUT
echo ============================================================
echo.
echo Ouverture de la vue interactive...
start "" "%~dp0cycle_homing_lumineux.html"

echo.
echo ============================================================
echo [OK] Page ouverte dans le navigateur.
echo ============================================================
timeout /t 3 >nul
