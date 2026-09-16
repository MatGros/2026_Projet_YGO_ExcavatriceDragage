# T300 — Procédure de trace CODESYS M3 / SimBench

Objectif : confronter le profil dynamique simulé aux réactions de la logique M3, sans écrire dans la logique métier ni forcer une image d'entrée hors de `HwSim → HwIn`.

## Préconditions

- Projet CODESYS chargé avec le bundle T300 ; mode simulation uniquement.
- Simulation active ; aucun raccordement aux sorties physiques. Activer `GVL_Simulation.SimulationModeActive` par un front `FALSE -> TRUE` après le démarrage de l'automate : `PRG_02_Acquisition` arme `SimTranslationActive` sur ce front, et un `TRUE` présent dès le boot ne suffit pas. Vérifier ensuite `GVL_Simulation.SimTranslationActive = TRUE` avant d'interpréter les DI.
- Trace déclenchée par une tâche de 10 ms si disponible. À défaut, relever la période réelle : une trace à 100 ms ne peut pas qualifier un délai de frein de 90 ms.
- Archiver avec la trace : révision Git, date, période effective, scénario, vitesse commandée et éventuels réglages de simulation.

Pour exercer spécifiquement les pertes/reprises capteurs, renseigner uniquement en simulation :

```text
GVL_Simulation.SimM3SensorIntermittenceActive  := TRUE
GVL_Simulation.SimM3SensorStabilizationS       := 1.0
GVL_Simulation.SimM3SensorElectricalDelayS     := 0.01
GVL_Simulation.SimM3SensorIntermittencePeriodS := 0.12
GVL_Simulation.SimM3SensorHysteresis_M         := 0.02
GVL_Simulation.SimM3SensorLoadAngleTriggerRad  := 0.01
GVL_Simulation.SimM3SensorScenarioSeed         := 3001
```

`SimM3SensorsWordOverrideActive` doit rester à `FALSE` : l'objectif est de faire traverser les fronts par le modèle mécanique et l'image `HwSim`, pas de court-circuiter la boucle avec un mot forcé.

Les seuils extremes `0,05 m` (Tremie) et `29,95 m` (Maintenance) sont des offsets **synthetiques** avant les butees physiques `0,00 m` et `30,00 m`. Ils garantissent que le mot cumulatif atteint respectivement `11111` et `00000` avant la saturation mecanique. Ils ne representent pas une geometrie terrain calibree.

## Variables de preuve AC4 / AC4bis

La trace doit contenir les deux images et le decodeur : tracer seulement `HwIn` ne prouve pas qu'un front provient du SimBench et non d'une autre ecriture.

| Etage | Variable a tracer | Preuve attendue |
|---|---|---|
| Sortie finale | `PRG_06_Outputs.M3_CommandWord`, `PRG_06_Outputs.M3_SetpointFrequencyHz`, `PRG_06_Outputs.Data.TranslationBrakeCmd` | ordre post-interlock lu par le simulateur |
| Simulation | `PRG_02_Acquisition.HwSim.Translation.M3_PosTremie_DI`, `M3_PosPV_DI`, `M3_PosPVP2_DI`, `M3_PosP1_DI`, `M3_PosMaintenance_DI` | fronts generes par le modele |
| Repere mecanique | `PRG_02_Acquisition.instSimBench.instSimTranslation.PositionTrue_M` et `LoadAngle_Rad` | position/angle internes du modele, pour expliquer le franchissement PV |
| Frontiere | `PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI`, `M3_PosPV_DI`, `M3_PosPVP2_DI`, `M3_PosP1_DI`, `M3_PosMaintenance_DI` | meme front publie a l'image metier |
| Miroir IHM/Trace | `GVL_IHM.IoHw.In.Hardware.Translation.M3_PosTremie_DI` et les 4 autres DI | copie de `HwIn` ; ce chemin est celui a tracer dans l'IHM |
| Decodeur | `PRG_05_Translation.instPosDecoderM3.SensorsWord`, `Incoherent`, `TranslationPosTremie`, `TranslationPosPV`, `TranslationPosP2`, `TranslationPosP1`, `TranslationPosMaintenance` | decodage aval des seules DI HwIn |
| Metier | `PRG_05_Translation.TranslationState.SensorsWord`, `SensorWordIncoherent`, `PositionTremie`, `PositionPV`, `PositionP2`, `PositionP1`, `PositionMaintenance` | memorisation et etat consequents |

Pour un front retenu, verifier sur les cycles successifs : `HwSim` change, `HwIn` reprend exactement la valeur, puis le decodeur et `TranslationState` evoluent. Un ecart ou une ecriture en amont invalide AC4/AC4bis : l'archiver, ne pas le masquer.

## Variables minimales

| Famille | Variable à tracer | Attendu vérifiable |
|---|---|---|
| Commande | `M3_CommandWord` | sens puis retour à 0 |
| Consigne | `M3_SetpointFrequencyHz` | rampe vers 40,00 Hz, ou 10,00 Hz en PV |
| Variateur | `HwIn.Translation.M3_ActualFrequencyHz` | suivi retardé, codage x100 Hz |
| Variateur | `HwIn.Translation.M3_StatusWord` | `16#0087` en mouvement, `16#0080` arrêté |
| Frein | `HwIn.Translation.M3_BrakeIsOpen_DI` | contact après la commande, distinct de celle-ci |
| Capteurs | `HwIn.Translation.M3_PosTremie_DI`, `M3_PosPV_DI`, `M3_PosP2_DI`, `M3_PosP1_DI`, `M3_PosMaintenance_DI` | transitions vues par la logique réelle |
| Métier | `TranslationM3.State.Error`, `TranslationM3.State.ErrorId` | défaut et instant d'apparition éventuel |

Ajouter les variables de mémoire/estimateur M3 déjà utilisées par votre vue diagnostic, si elles sont accessibles. Ne jamais remplacer une mesure par la position interne du simulateur : cette position est un oracle de développement, pas une entrée de l'automate.

## Séquences à exécuter

1. Après activation par front, vérifier `SimTranslationActive`, puis réarmement, départ en sens 2, palier 40 Hz et arrêt normal. Mesurer rampe, écart consigne/retour et ordre → contact frein.
2. Départ en sens 1 avec passage de `M3_PosPV_DI` à l'état actif bas. Vérifier la descente vers 10 Hz, le franchissement puis l'arrêt final.
3. Répéter la séquence 2 trois fois avec un arrêt près d'un seuil. Relever tous les fronts des cinq DI et toute perte/reprise avant stabilisation.
4. Refaire le cas qui reproduisait le défaut 64/65. Conserver la trace, y compris si le défaut ne se reproduit pas.

## Mesures de comparaison initiales

| Grandeur | Cible de départ du modèle | Décision après trace |
|---|---:|---|
| Rampe montée/descente | 20 Hz/s | ajuster uniquement avec mesure horodatée |
| Réponse fréquence | tau = 0,15 s | comparer consigne/retour, conserver l'écart signé |
| Ouverture frein | 0,10 s | mesurer commande → DI ; ne pas inférer au pas de 100 ms |
| Fermeture frein | 0,09 s après vitesse nulle | mesurer fréquence nulle → DI fermé |
| Stabilisation DI | 1,0 s | relever premier et dernier front, puis silence 2 s |

Critère de retour : partager le fichier de trace ou un export horodaté et préciser la période effective. Les valeurs non concordantes deviennent des paramètres à calibrer ; elles ne justifient jamais de relâcher un test pour le faire passer.
