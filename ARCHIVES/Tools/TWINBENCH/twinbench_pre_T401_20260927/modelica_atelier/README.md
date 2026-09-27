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
2. double-cliquer `Atelier` — synoptique 2D principal placé à la racine ;
3. ouvrir l'onglet **Diagramme**, puis cliquer **Simuler** (simulation normale) ;
4. après le calcul, revenir au Diagramme et utiliser **Lecture** ou le curseur temporel du
   navigateur de variables pour rejouer le mouvement 2D ;
5. pour les courbes, ouvrir `Examples > GrabClosureThenHoist` puis **Simuler** ;
6. tracer au minimum `plant.measurements.bucketOpeningAct_Pct`,
   `plant.feedback.bucketIsClosed`, `plant.measurements.m1CablePositionAct_M` et
   `plant.measurements.m2CablePositionAct_M`.

Dans le navigateur de variables, les grandeurs sont maintenant rangées par rôle :
`plant.commands`, `plant.configuration`, `plant.measurements`, `plant.feedback`,
`plant.deviceState` (M3) et `plant.diagnostics`. Les entrées/sorties ne sont donc plus
mélangées dans une liste plate.

Pour la 3D secondaire, utiliser `Atelier3D`, `Examples > AnimatedM3ContractCycle` ou
`Examples > AnimatedGrabClosureThenHoist`, puis **Simuler avec animation**.

Dans OMEdit, désactiver une fois `Tools > Options > Simulation > Switch to plotting perspective
after simulation`. Sinon OMEdit masque automatiquement le Diagramme après le calcul et affiche
uniquement les courbes. Cette option est un réglage d'interface, pas un paramètre du modèle.

## Repère machine

Le repère physique est : `X` le long du rail de Trémie vers Maintenance, `Y` en profondeur
depuis la cabine vers la machine et `Z` vertical vers le haut. Une plongée est en `Z` négatif,
une remontée en `Z` positif. La vue cabine est donc le plan `X-Z`, avec Trémie à gauche et
Maintenance à droite.

La vue principale `Dredge.Atelier` est un synoptique 2D qui respecte directement cette convention.
`Dredge.Atelier3D` reste secondaire : les presets OMEdit sont des caméras génériques et ne
correspondent pas à la vue cabine métier. En particulier, le bouton **Front** d'OMEdit 1.27.1
projette `Z` horizontal et `X` vertical ; il ne faut pas l'interpréter comme la face cabine.
Pour la 3D, utiliser une vue manuelle tournée jusqu'à obtenir le plan X-Z.

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
