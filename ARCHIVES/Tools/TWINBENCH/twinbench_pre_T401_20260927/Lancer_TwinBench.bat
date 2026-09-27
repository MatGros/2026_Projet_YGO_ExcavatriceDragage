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

echo Ouverture de TwinBench dans OMEdit...
echo Point d'entree : Dredge ^> Atelier ^(double-clic^), onglet Diagramme, puis Simuler.
start "" "%OMEDIT%" "%~dp0modelica_atelier\Dredge.mo"
