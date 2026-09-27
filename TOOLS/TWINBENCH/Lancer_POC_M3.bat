@echo off
setlocal
set "OMEDIT="

if defined OPENMODELICAHOME if exist "%OPENMODELICAHOME%\bin\OMEdit.exe" set "OMEDIT=%OPENMODELICAHOME%\bin\OMEdit.exe"
if not defined OMEDIT if exist "C:\Program Files\OpenModelica1.27.1-64bit\bin\OMEdit.exe" set "OMEDIT=C:\Program Files\OpenModelica1.27.1-64bit\bin\OMEdit.exe"
if not defined OMEDIT if exist "C:\Program Files\OpenModelica\bin\OMEdit.exe" set "OMEDIT=C:\Program Files\OpenModelica\bin\OMEdit.exe"

if not defined OMEDIT (
  echo OpenModelica / OMEdit introuvable.
  echo Definir OPENMODELICAHOME puis relancer.
  pause
  exit /b 1
)

echo Ouverture du POC M3 dans OMEdit...
echo Diagramme : M3_POC ^> TranslationM3 ^> vue Diagramme.
echo Point d'entree : M3_POC ^> Examples ^> AllerRetour ^> Simuler.
start "" "%OMEDIT%" "%~dp0modelica_poc_m3\M3_POC.mo"
