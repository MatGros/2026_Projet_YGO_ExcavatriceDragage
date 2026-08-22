@echo off
rem Raccourci : lance uniquement les tests du domaine JOYSTICK depuis ce dossier.
rem Equivalent a : python TOOLS/TEST_AUTO_CI/run_tests.py --domain JOYSTICK
python "%~dp0..\..\..\run_tests.py" --domain JOYSTICK %*
