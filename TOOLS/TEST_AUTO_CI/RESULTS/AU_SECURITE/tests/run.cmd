@echo off
rem Raccourci : lance uniquement les tests du domaine AU_SECURITE depuis ce dossier.
rem Equivalent a : python TOOLS/TEST_AUTO_CI/run_tests.py --domain AU_SECURITE
python "%~dp0..\..\..\run_tests.py" --domain AU_SECURITE %*
