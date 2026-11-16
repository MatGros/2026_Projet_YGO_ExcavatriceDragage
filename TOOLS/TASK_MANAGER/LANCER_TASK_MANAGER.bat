@echo off
rem Fichier volontairement ASCII pur : le parseur cmd deforme les emojis UTF-8 et le "&" du title
chcp 65001 >nul
title TASK MANAGER - Visualiseur et synchronisation TASKS.yaml

echo.
echo  LANCEMENT DU TASK MANAGER (SERVEUR LOCAL)
echo.
echo.

echo Script lance : TOOLS\TASK_MANAGER\task_server.py
rem R29 - un python par service : ce lanceur ne gere QUE le port 8081.
echo   - Task Manager : port 8081 (TASK_VIEWER.html)
echo   - Superviseur  : a lancer separement avec TOOLS\AGENT_SUPERVISOR\LANCER_SUPERVISEUR.bat

rem R29 : on VERIFIE avant de decrire un arret. Message seulement si une instance existe vraiment.
powershell -NoProfile -Command "$connections = Get-NetTCPConnection -State Listen -LocalPort 8081 -ErrorAction SilentlyContinue; if ($connections) { Write-Host 'Arret de l instance precedente sur le port 8081...'; foreach ($connection in $connections) { Stop-Process -Id $connection.OwningProcess -Force -ErrorAction SilentlyContinue; Write-Host ('  Instance arretee (PID ' + $connection.OwningProcess + ')') }; Start-Sleep 1; $rest = Get-NetTCPConnection -State Listen -LocalPort 8081 -ErrorAction SilentlyContinue; if ($rest) { Write-Host '  VERDICT port 8081 : ENCORE OCCUPE' } else { Write-Host '  VERDICT port 8081 : libere' } } else { Write-Host 'Port 8081 : deja libre' }"

cd /d "%~dp0"
timeout /t 1 /nobreak >nul
python task_server.py %*
