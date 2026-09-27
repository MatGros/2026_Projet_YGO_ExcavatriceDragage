# POC M3 live — T405

Responsabilité unique : piloter localement la plante `M3_POC.TranslationM3` sous forme de FMU,
par pas de communication de 10 ms, puis présenter ses entrées/sorties dans une interface QML.

## Limites

- banc logiciel Windows non temps réel ;
- aucune communication PLC/CODESYS ;
- aucune sortie machine ou réseau ;
- hypothèses physiques identiques au POC T401 ;
- la cadence d'affichage ne modifie pas la cadence FMI.

## Test moteur sans interface

```powershell
python test_headless.py
```

La FMU et les résultats temporaires sont générés hors dépôt dans
`%LOCALAPPDATA%\TwinBenchM3Live`.

## Lancement utilisateur

Double-cliquer sur `TOOLS\TWINBENCH\Lancer_POC_M3_Live.bat`.

Au premier lancement seulement, le script crée un environnement Python isolé dans
`%LOCALAPPDATA%\TwinBenchM3Live\Python` et y installe PySide6. Aucun paquet Python global
n'est modifié.
