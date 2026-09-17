# Atelier OpenModelica — Dredge

Ce dossier actif est volontairement minimal : **un modèle Modelica, un lanceur, ce guide**.
Les anciens POC web, Python, FMU et Rumoca sont archivés sous
`ARCHIVES/Tools/TWINBENCH/modelica_atelier_pre_T314_20260917/`.

## Ouvrir

Double-cliquer `Ouvrir_Dredge_OMEdit.bat`.

Dans l'arborescence OMEdit :

1. développer `Dredge` puis `Examples` ;
2. choisir `AnimatedGrabClosureThenHoist` pour le treuil et la benne ;
3. cliquer **Simuler avec animation** ;
4. choisir `GrabClosureThenHoist` puis **Simuler** pour tracer les variables ;
5. tracer au minimum `plant.bucketOpeningPct`, `plant.bucketClosedDI`,
   `plant.m1CablePositionM` et `plant.m2CablePositionM`.

Pour M3, utiliser `AnimatedM3ContractCycle` (animation) ou `M3ContractCycle` (courbes).

## Modifier soi-même

Les paramètres sont visibles dans `TranslationM3Plant` et `WinchesM1M2Plant`.
Modifier une valeur dans OMEdit, sauvegarder `Dredge.mo`, puis relancer la simulation.
Les constantes marquées « à mesurer » ne sont pas validées terrain : elles seront calibrées
à partir de traces réelles M1/M2/M3.

Le modèle est strictement hors ligne : aucune connexion PLC, aucune sortie physique et aucune
implémentation des autorisations de sécurité machine.
