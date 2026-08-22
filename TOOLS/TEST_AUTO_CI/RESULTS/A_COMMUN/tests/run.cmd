@echo off
rem Raccourci : lance uniquement les tests du domaine A_COMMUN depuis ce dossier
rem (4 FB independants, une seule fiche de rapport groupee -- cf. registry.yaml "report_group").
rem Equivalent a : python TOOLS/TEST_AUTO_CI/run_tests.py --domain A_COMMUN
python "%~dp0..\..\..\run_tests.py" --domain A_COMMUN %*
