@echo off
setlocal
set "SCRIPT_DIR=%~dp0"

if "%~1"=="" (
    echo ========================================================
    echo   TEST_AUTO_CI : Testeur de FB specifique
    echo ========================================================
    echo Usage:
    echo   run_fb.bat ^<Nom_du_FB^> [options]
    echo.
    echo Exemples:
    echo   run_fb.bat FB_Joystick
    echo   run_fb.bat FB_Safety_EmergencyManagement
    echo   run_fb.bat FB_Modes --debug
    echo ========================================================
    set /p FB_NAME="Entrez le nom du FB a tester : "
) else (
    set "FB_NAME=%~1"
    shift
)

if "%FB_NAME%"=="" (
    echo Nom de FB non specifie. Annulation.
    pause
    exit /b 1
)

echo ========================================================
echo   Lancement du test pour %FB_NAME% (avec chronogrammes)
echo ========================================================
python "%SCRIPT_DIR%run_tests.py" --fb %FB_NAME% %1 %2 %3 %4 %5 %6 %7 %8 %9
echo.
pause
