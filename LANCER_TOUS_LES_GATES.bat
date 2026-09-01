@echo off
chcp 65001 >nul
title TOUS LES GATES — Suite complete de validation mecanique

echo ============================================================
echo 🚦 LANCEMENT DE TOUS LES GATES
echo ============================================================
echo.

cd /d "%~dp0"
python TOOLS\AGENT_WORKFLOW\scripts\run_all_gates.py %*
set _RC=%ERRORLEVEL%

echo.
echo ============================================================
if "%_RC%"=="0" (
    echo ✅ GATES : PASS
) else (
    echo ❌ GATES : ECHEC ^(code %_RC%^)
)
echo ============================================================
echo.
pause
exit /b %_RC%
