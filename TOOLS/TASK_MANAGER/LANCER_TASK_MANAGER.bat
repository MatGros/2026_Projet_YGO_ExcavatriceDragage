@echo off
chcp 65001 >nul
title TASK MANAGER — Visualiseur & Synchronisation TASKS.yaml

echo ============================================================
echo 📋 LANCEMENT DU TASK MANAGER (SERVEUR LOCAL)
echo ============================================================
echo.

cd /d "%~dp0"
python task_server.py

pause
