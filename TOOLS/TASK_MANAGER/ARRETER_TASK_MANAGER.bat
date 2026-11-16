@echo off
rem Fichier volontairement ASCII pur : le parseur cmd deforme les emojis UTF-8
rem R29 (demande exploitant 2026-11-16) : arret TOTAL des serveurs locaux, verifie et trace.
title ARRET TASK MANAGER + SUPERVISEUR

echo.
echo  ARRET DES SERVEURS LOCAUX (Task Manager 8081 + Superviseur 8082)
echo.

powershell -NoProfile -Command "foreach ($port in 8081,8082) { $conn = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue; if ($conn) { Write-Host ('Port ' + $port + ' : arret de l instance PID ' + $conn.OwningProcess); Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue } else { Write-Host ('Port ' + $port + ' : deja libre') } }; Start-Sleep 1; foreach ($port in 8081,8082) { $rest = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue; if ($rest) { Write-Host ('VERDICT port ' + $port + ' : ENCORE OCCUPE') } else { Write-Host ('VERDICT port ' + $port + ' : libere') } }"

echo.
echo  Tout est arrete. Journal complet : %%LOCALAPPDATA%%\ExcavatriceDragage\agent-supervisor-server.log
