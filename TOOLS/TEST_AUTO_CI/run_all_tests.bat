@echo off
setlocal
pushd "%~dp0..\.."
echo ===================================================
echo   TEST_AUTO_CI : Execution Globale (12 Threads CPU)
echo ===================================================
python "%~dp0scripts\run_tests.py" --all --cleanup-scratch -j 12 %*
echo.
popd
pause

