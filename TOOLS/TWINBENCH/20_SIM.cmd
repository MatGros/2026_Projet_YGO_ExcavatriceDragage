@echo off
setlocal

:menu
cls
echo ========================================
echo TWINBENCH - LOCAL M3 SIMULATION
echo ========================================
echo This simulation runs locally and does not use the Control Win project.
echo.
echo 1. Open the Modelica model in OMEdit
echo 2. Run the live M3 FMU simulation
echo 0. Back
echo.
set "TB_SIM_CHOICE="
set /p "TB_SIM_CHOICE=Select a mode (1, 2 or 0): "
if "%TB_SIM_CHOICE%"=="0" exit /b 0
if "%TB_SIM_CHOICE%"=="1" goto modelica
if "%TB_SIM_CHOICE%"=="2" goto live
echo Invalid choice. Type 1, 2 or 0, then press Enter.
timeout /t 2 /nobreak >nul
goto menu

:modelica
call "%~dp0.\02_SIM\modelica\Open_M3_Model.cmd"
goto menu

:live
call "%~dp0.\02_SIM\modelica\Start_M3_Live.cmd"
goto menu
