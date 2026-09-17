# Atelier OpenModelica — Dredge

Ce dossier actif est volontairement minimal : **un modèle Modelica et ce guide**.
Les anciens POC web, Python, FMU et Rumoca sont archivés sous
`ARCHIVES/Tools/TWINBENCH/modelica_atelier_pre_T314_20260917/`.

## Ouvrir

Double-cliquer `TOOLS/TWINBENCH/Lancer_TwinBench.bat`.

Le lanceur charge le paquet dans OMEdit. OMEdit ne fournit pas d'option de ligne de commande
pour sélectionner automatiquement une classe interne. Dans l'arborescence, il reste donc
**un seul double-clic** à faire :

1. développer `Dredge` ;
2. double-cliquer `Atelier` — point d'entrée treuil/benne placé à la racine ;
3. cliquer **Simuler avec animation** ;
4. pour les courbes, ouvrir `Examples > GrabClosureThenHoist` puis **Simuler** ;
5. tracer au minimum `plant.measurements.bucketOpeningAct_Pct`,
   `plant.feedback.bucketIsClosed`, `plant.measurements.m1CablePositionAct_M` et
   `plant.measurements.m2CablePositionAct_M`.

Dans le navigateur de variables, les grandeurs sont maintenant rangées par rôle :
`plant.commands`, `plant.configuration`, `plant.measurements`, `plant.feedback`,
`plant.deviceState` (M3) et `plant.diagnostics`. Les entrées/sorties ne sont donc plus
mélangées dans une liste plate.

Pour M3, utiliser `Examples > AnimatedM3ContractCycle` (animation) ou
`Examples > M3ContractCycle` (courbes).

## Repère animation OMEdit 1.27.1

Le repère cabine est : `X` vers la cabine, `Y` vertical, `Z` le long du rail. La position
métier croît de Trémie vers Maintenance et est affichée sur `-Z`. Le bouton affiché **Front**
doit donc montrer **Trémie à gauche** et **Maintenance à droite**.

OMEdit 1.27.1 inverse dans son sélecteur les actions internes **Front** et **Top**. Le modèle
compense volontairement ce défaut connu de cette version ; ce n'est pas une convention physique
à recopier dans les calculs métier.

## Modifier soi-même

Les paramètres sont visibles dans `TranslationM3Plant` et `WinchesM1M2Plant`.
Modifier une valeur dans OMEdit, sauvegarder `Dredge.mo`, puis relancer la simulation.
Les constantes marquées « à mesurer » ne sont pas validées terrain : elles seront calibrées
à partir de traces réelles M1/M2/M3.

Pour calibrer, conserver si possible un CSV horodaté avec : commandes finales M1/M2/M3,
fréquence, commandes et retours freins, positions/vitesses codeurs, retours benne ouverte/fermée,
capteurs Trémie/PV/P2/P1/Maintenance et étape AX10/AX11. Le rejeu « actuel mesuré » puis
« modèle modifié » sera construit à partir de ces colonnes ; ne pas ajuster la dynamique à l'œil.

Le modèle est strictement hors ligne : aucune connexion PLC, aucune sortie physique et aucune
implémentation des autorisations de sécurité machine.
