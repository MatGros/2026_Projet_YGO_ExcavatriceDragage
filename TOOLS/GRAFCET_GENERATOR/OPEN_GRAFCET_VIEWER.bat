@echo off
chcp 65001 > nul
title Cockpit GRAFCET Automatique (Parseur ST)
echo ============================================================
echo 🧭 PARSEUR ST DE GRAFCET - EXTRACTION SANS LLM
echo ============================================================
echo Generation des diagrammes et mise a jour du visualiseur...
echo.

python "%~dp0generate_grafcet_from_st.py"

if %ERRORLEVEL% equ 0 (
    echo.
    echo Ouverture du visualiseur dans le navigateur...
    start "" "%~dp0GRAFCET_VIEWER.html"
) else (
    echo.
    echo [ERREUR] La generation a echoue.
    pause
)
