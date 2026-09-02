@echo off
echo ============================================================
echo 🧪 EXECUTION DES TESTS CI UNITAIRES MES (BATCH LOCAL)
echo ============================================================
python TOOLS/TEST_AUTO_CI/run_tests.py --fb FB_WinchStepShaper
python TOOLS/TEST_AUTO_CI/run_tests.py --fb FB_SyncContactor
python TOOLS/TEST_AUTO_CI/run_tests.py --fb FB_WinchSync
python TOOLS/TEST_AUTO_CI/run_tests.py --fb FB_Joystick
echo ============================================================
echo ✅ FIN D'EXECUTION DES TESTS
echo ============================================================
pause
