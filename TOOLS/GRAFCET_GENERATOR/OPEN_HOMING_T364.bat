@echo off
chcp 65001 >nul
title Grafcet Cycle Homing T364 (FB_CycleMachineHoming) - Excavatrice Dragage

echo ============================================================
echo 🧭 GRAFCET HOMING OFFICIEL T364 (FB_CycleMachineHoming)
echo ============================================================
echo.
echo Ouverture du GRAFCET interactif conforme au code ST...
start "" "%~dp0cycle_homing_t364.html"

echo.
echo ============================================================
echo [OK] Page ouverte dans le navigateur par defaut.
echo ============================================================
timeout /t 3 >nul
