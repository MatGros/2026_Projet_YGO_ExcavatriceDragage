# T409 — liaison FMU M3 / Control Win

## Vérifier le socle FMU local

```powershell
& 'C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\TWINBENCH\90_PROTOTYPES\m3_link\Run_T409_Verification.ps1'
```

Cette commande n’utilise ni CODESYS ni PLC. Elle vérifie le protocole, la cinématique, le frein, les six mots capteurs, les butées, le transport 10 ms et la reprise de séquence.

## Lancer la passerelle pour Control Win

Pour lancer la passerelle et ouvrir directement la vue M3 connectée, double-cliquer sur :

```text
TOOLS\TWINBENCH\90_PROTOTYPES\m3_link\Start_T409_M3_Integration.cmd
```

La vue est en lecture seule et déjà active à l'ouverture ; aucun bouton Start n'est à presser.
La passerelle copie vers la vue la même réponse FMU qu'elle renvoie déjà à Control Win :
aucun login CODESYS ni script Tools > Scripting n'est requis pour voir l'animation.
Sans première trame valide, l'écran indique « en attente » et ne place pas le chariot à 0 m.
Le lanceur d'intégration redémarre uniquement la passerelle T409 identifiée afin de repartir
de son état initial P1 (20 m, capteurs `00011`) ; si le port appartient à un autre programme,
il valide d'abord tous les PID, l'exécutable Python et les arguments de la passerelle (y compris
les anciennes instances qui utilisaient le port par défaut), puis refuse d'arrêter quoi que ce
soit si un propriétaire ne correspond pas.
Le POU pont est activé par défaut et prend automatiquement la propriété du sélecteur M3 OM.
Dans la logique PLC, la seule activation de simulation manuelle reste
`GVL_Simulation.SimulationModeActive=TRUE`. Lancer le miroir ne commande rien au PLC.

Après une perte de communication, l'image OM est neutralisée. La vue masque la position comme
valeur actuelle, marque la dernière connue comme périmée, puis reprend à la réception d'une
nouvelle trame. Le pont PLC reprend à la première réponse FMU valide.

Pour lancer uniquement la passerelle :

```powershell
& 'C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\TWINBENCH\90_PROTOTYPES\m3_link\Start_T409_FmuGateway.ps1'
```

La passerelle est limitée à `127.0.0.1:29061`. Elle refuse les doubles instances et crée automatiquement un journal et une trace CSV dans `%LOCALAPPDATA%\TwinBenchT409`.

## Ordre Control Win

1. Ouvrir uniquement la copie TwinBench Control Win.
2. Se connecter à Control Win local, jamais au PLC réel.
3. Mettre uniquement `SimulationModeActive=TRUE` dans la copie isolée.
4. Le POU `PRG_T409_M3_FmuBridge` et le sélecteur `SimM3OpenModelicaActive` s'activent seuls.
5. Surveiller `LinkReady`, `Timeout`, `LinkInvalid`, `FmuPosition_M`, `FmuVelocity_Mps`, `FmuFrequency_Hz` et les cinq DI M3.
6. Exécuter la recette `T409_CONTROLWIN_TEST_RECIPE.md`.

## Sécurité

La passerelle n’écrit jamais dans le PLC. Le POU n’écrit que `GVL_Simulation.SimM3OpenModelica`
et pilote son propre sélecteur `SimM3OpenModelicaActive` dans le POC Control Win. Le bit maître
reste requis ; `Enable` du POU démarre à TRUE. Aucun changement n'est apporté au code principal.
