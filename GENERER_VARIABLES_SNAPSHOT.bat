@echo off
setlocal
cd /d "%~dp0"

echo ============================================================
echo GENERATION LISTE VARIABLES SNAPSHOT TROUBLESHOOTING
echo ============================================================
py -3.13 "TOOLS\PLC_CSV_SNAPSHOT\variable_lists\generate_variable_list_from_code.py" --output "TOOLS\PLC_CSV_SNAPSHOT\variable_lists\troubleshooting_variables.txt"

if errorlevel 1 (
    echo.
    echo ECHEC : la liste n'a pas ete mise a jour.
    pause
    exit /b 1
)

echo.
echo OK : liste generee. Relancer ensuite le snapshot CODESYS.
pause
