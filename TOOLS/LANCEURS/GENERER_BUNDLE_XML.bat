@echo off
chcp 65001 >nul
title BUNDLE XML — Generation du bundle PLCopenXML

echo ============================================================
echo 📦 GENERATION DU BUNDLE PLCopenXML
echo ============================================================
echo.

cd /d "%~dp0\..\.."
python TOOLS\AGENT_WORKFLOW\scripts\generate_codesys_bundle.py .
set _RC=%ERRORLEVEL%

echo.
echo ============================================================
if "%_RC%"=="0" (
    echo ✅ BUNDLE EXPORTE : CODE_XML\CODE_Bundle.xml
) else (
    echo ❌ BUNDLE : ECHEC ^(code %_RC%^)
)
echo ============================================================
echo.
pause
exit /b %_RC%
