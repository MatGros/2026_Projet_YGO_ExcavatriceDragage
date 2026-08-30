@echo off
rem Fichier volontairement ASCII pur : le parseur cmd deforme les emojis UTF-8 et le "&" du title
chcp 65001 >nul
title TASK MANAGER - Visualiseur et synchronisation TASKS.yaml

echo ============================================================
echo  LANCEMENT DU TASK MANAGER (SERVEUR LOCAL)
echo ============================================================
echo.

cd /d "%~dp0"
echo Arret de toute instance precedente sur le port 8081...
powershell -NoProfile -Command "$connections = Get-NetTCPConnection -State Listen -LocalPort 8081 -ErrorAction SilentlyContinue; foreach ($connection in $connections) { Stop-Process -Id $connection.OwningProcess -Force -ErrorAction SilentlyContinue; Write-Host ('  Instance arretee (PID ' + $connection.OwningProcess + ')') }"
timeout /t 1 /nobreak >nul
python task_server.py
