# T409 — liaison FMU M3 / Control Win

## Vérifier le socle FMU local

```powershell
& 'C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\TWINBENCH\udp_m3_link\Run_T409_Verification.ps1'
```

Cette commande n’utilise ni CODESYS ni PLC. Elle vérifie le protocole, la cinématique, le frein, les six mots capteurs, les butées, le transport 10 ms et la reprise de séquence.

## Lancer la passerelle pour Control Win

```powershell
& 'C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\TWINBENCH\udp_m3_link\Start_T409_FmuGateway.ps1'
```

La passerelle est limitée à `127.0.0.1:29061`. Elle refuse les doubles instances et crée automatiquement un journal et une trace CSV dans `%LOCALAPPDATA%\TwinBenchT409`.

## Ordre Control Win

1. Ouvrir uniquement la copie TwinBench Control Win.
2. Se connecter à Control Win local, jamais au PLC réel.
3. Vérifier `SimulationModeActive=TRUE` et `SimM3OpenModelicaActive=TRUE`.
4. Activer le POU `PRG_T409_M3_FmuBridge`.
5. Surveiller `LinkReady`, `Timeout`, `LinkInvalid`, `FmuPosition_M`, `FmuVelocity_Mps`, `FmuFrequency_Hz` et les cinq DI M3.
6. Exécuter la recette `T409_CONTROLWIN_TEST_RECIPE.md`.

## Sécurité

La passerelle n’écrit jamais dans le PLC. Le POU n’écrit que `GVL_Simulation.SimM3OpenModelica`, sous les deux verrous de simulation. Si un verrou est faux, l’image FMU est neutralisée.
