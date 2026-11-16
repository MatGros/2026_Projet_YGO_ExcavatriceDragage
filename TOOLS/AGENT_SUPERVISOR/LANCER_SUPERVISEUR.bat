@echo off
rem Fichier volontairement ASCII pur (le parseur cmd deforme les caracteres UTF-8)
rem R29 - architecture un-python-par-service : le Superviseur a SON lanceur.
title SUPERVISEUR (port 8082)

echo.
echo  LANCEMENT DU SUPERVISEUR (port 8082)
echo.

cd /d "%~dp0..\AGENT_SUPERVISOR\scripts"
python supervisor_server.py
