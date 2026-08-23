@echo off
setlocal
echo ===================================================
echo   TEST_AUTO_CI : Execution Globale (12 Threads CPU)
echo ===================================================
python "%~dp0run_tests.py" --all -j 12 %*
echo.
pause
