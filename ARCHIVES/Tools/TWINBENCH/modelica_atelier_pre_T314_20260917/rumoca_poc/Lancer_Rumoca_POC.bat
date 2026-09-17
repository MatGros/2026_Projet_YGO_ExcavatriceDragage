@echo off
setlocal
cd /d "%~dp0"
echo.
echo ============================================================
echo  TwinBench - POC Rumoca
echo ============================================================
echo  1. Cycle M3
echo  2. Fermeture benne puis remontee image
echo  3. M3 - rebonds capteurs, frein, zone PV 50/15 Hz
echo.
set /p choice=Choisir un scenario [1-3] :

if "%choice%"=="1" set scenario=M3
if "%choice%"=="2" set scenario=Grab
if "%choice%"=="3" set scenario=M3Faults
if not defined scenario (
  echo Choix invalide.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run_Rumoca_M3_POC.ps1" -Scenario %scenario%
if errorlevel 1 (
  echo.
  echo Le POC a echoue. La console reste ouverte pour lire le diagnostic.
  pause
  exit /b 1
)

echo.
echo Rapport ouvert dans le navigateur. Appuyez sur une touche pour fermer cette fenetre.
pause >nul
