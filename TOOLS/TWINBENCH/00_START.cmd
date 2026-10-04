@echo off
setlocal
cd /d "%~dp0"

:menu
cls
echo ========================================
echo TWINBENCH - MASTER LAUNCHER
echo ========================================
echo.
echo 1. Select or prepare a Control Win project copy
echo 2. Run the local M3 simulation
echo 3. Run the M3 simulation LINKED TO THE PLC (Control Win)
echo 0. Exit
echo.
set "TB_CHOICE="
set /p "TB_CHOICE=Select an action (1, 2, 3 or 0): "
if "%TB_CHOICE%"=="0" exit /b 0
if "%TB_CHOICE%"=="1" goto project
if "%TB_CHOICE%"=="2" goto simulation
if "%TB_CHOICE%"=="3" goto linked
echo Invalid choice. Type 1, 2, 3 or 0, then press Enter.
timeout /t 2 /nobreak >nul
goto menu

:project
call "%~dp0.\10_PROJECT.cmd"
goto menu

:simulation
call "%~dp0.\20_SIM.cmd"
goto menu

:linked
rem Passerelle FMU (plante remise a P1) + vue M3 en lecture du PLC Control Win.
call "%~dp0.\90_PROTOTYPES\m3_link\Start_T409_M3_Integration.cmd"
goto menu
