@echo off
setlocal
pushd "%~dp0..\.."
echo ============================================================
echo    GENERATION COMPLETE DES RAPPORTS HTML & CHRONOGRAMMES
echo ============================================================
python "%~dp0scripts\run_tests.py" --all
if errorlevel 1 (
    echo.
    echo [ATTENTION] Certains tests ou rapports ont rencontre un defaut.
)
echo.
echo ============================================================
echo   Termine ! Dashboard global : TOOLS/TEST_AUTO_CI/index.html
echo ============================================================
popd

