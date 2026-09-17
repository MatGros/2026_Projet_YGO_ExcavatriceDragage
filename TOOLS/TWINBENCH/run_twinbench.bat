@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title TwinBench - Jumeau Numerique ^& Simulateur 2D

echo ============================================================
echo   TWINBENCH - SIMULATEUR ELECTROMECANIQUE ^& VUE 2D
echo ============================================================
echo.

:: 1. Verification de Python
where python >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERREUR] Python est introuvable dans le PATH.
    echo Veuillez installer Python 3.11+ et vous assurer qu'il est dans le PATH.
    pause
    exit /b 1
)

:: 2. Verification de PyYAML
python -c "import yaml" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [INFO] PyYAML n'est pas installe. Tentative d'installation...
    pip install pyyaml
    if %ERRORLEVEL% neq 0 (
        echo [ERREUR] Echec de l'installation de PyYAML via pip.
        pause
        exit /b 1
    )
)

set "TB_DIR=%~dp0"
set "OUT_HTML=%TB_DIR%out\twinbench.html"

echo [1/4] Simulation scenario NOMINAL (seed 4172)...
python "%TB_DIR%cli.py" run --scenario nominal --seed 4172
if %ERRORLEVEL% neq 0 (
    echo [ERREUR] Echec sur le scenario nominal.
    pause
    exit /b 1
)
echo.

echo [2/4] Simulation scenario CAME_HS (came Maintenance bloquee stuck_high)...
python "%TB_DIR%cli.py" run --scenario came_hs --seed 4172 --fault SensorMaintenance=stuck_high
if %ERRORLEVEL% neq 0 (
    echo [ERREUR] Echec sur le scenario came_hs.
    pause
    exit /b 1
)
echo.

echo [3/4] Compactage des traces pour la vue 2D...
python "%TB_DIR%ui\pack_traces.py"
if %ERRORLEVEL% neq 0 (
    echo [ERREUR] Echec du compactage des traces.
    pause
    exit /b 1
)
echo.

echo [4/4] Assemblage de la vue autonome out\twinbench.html...
python "%TB_DIR%ui\build.py"
if %ERRORLEVEL% neq 0 (
    echo [ERREUR] Echec de l'assemblage HTML.
    pause
    exit /b 1
)
echo.

echo ============================================================
echo   VUE ASSEMBLEE AVEC SUCCES :
echo   %OUT_HTML%
echo ============================================================
echo.
echo Ouverture dans le navigateur par defaut...
start "" "%OUT_HTML%"

echo.
echo Termine. Appuyez sur une touche pour quitter.
pause >nul
