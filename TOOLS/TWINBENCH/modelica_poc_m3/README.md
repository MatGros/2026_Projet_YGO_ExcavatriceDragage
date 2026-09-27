# POC OpenModelica — Translation M3

Objectif : vérifier rapidement la chaîne **ouvrir → simuler → tracer**. Ce POC n'est pas une
preuve de fidélité mécanique et ne communique pas avec le PLC.

1. Double-cliquer `TOOLS/TWINBENCH/Lancer_POC_M3.bat`.
2. Dans OMEdit, développer `M3_POC > Examples`.
3. Double-cliquer `TranslationM3` et ouvrir **Diagramme** pour voir les blocs reliés.
4. Choisir un scénario et ses paramètres :
   - `Examples > AllerRetour` : test déterministe historique ;
   - `Examples > BoucleLocale` : trajet répété piloté par les retours capteurs.
   Dans `BoucleLocale`, modifier si besoin `loopFrequency_Hz`, les deux pauses et
   `cycleCount` (`0` = boucle jusqu'au temps de fin), puis cliquer **Simuler**.
5. Tracer `plant.measurements.positionAct_M`, `plant.measurements.velocityAct_Mps`,
   `plant.measurements.frequencyCmd_Hz`, `plant.measurements.frequencyAct_Hz`,
   `plant.feedback.brakeIsOpen`, `controller.state.phaseCode`,
   `controller.state.completedCycles` et `plant.deviceState.sensorsWord`.

`LocalLoopController` est un générateur de stimuli de banc séparé. Il ne représente pas la
logique PLC et ne communique avec aucun équipement externe.

Repères : capteurs à 0/5/15/20/30 m ; butées hypothétiques à -0,30/30,30 m ; gain provisoire
0,02 m/(Hz·s), soit 1 m/s à 50 Hz.
