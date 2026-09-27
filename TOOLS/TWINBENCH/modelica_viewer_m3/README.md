# TwinBench M3 — Viewer Modelica + simulateur autonome

Atelier hors ligne pour l'axe de translation M3.

## Deux moteurs, une même frontière machine

### 1. Viewer OpenModelica

`Lancer_M3Viewer.bat`

- ouvre/édite les `.mo` ;
- visualise classes, ports, composants et connexions ;
- `checkModel()` et simulation via `omc.exe` ;
- lit et trace les résultats CSV.

OpenModelica reste le moteur de référence pour Modelica complet.

### 2. TwinBench M3 autonome

`Lancer_M3Autonome.bat`

Aucune installation OpenModelica requise. Le moteur Python ne remplace pas Modelica : il fournit un équipement virtuel M3 limité, déterministe et testable.

La frontière est alignée sur `CODE/`, qui est la vérité machine :

PLC -> Twin :
- `M3_CommandWord` : `0=stop`, `1=Trémie`, `2=Maintenance` ;
- `M3_SetpointFrequencyHz` : fréquence codée x100 ;
- `M3_BrakeRelease_RQ` ;
- état thermique/device pour injection de défaut hors ligne.

Twin -> PLC / viewer :
- `M3_StatusWord` ;
- `M3_ActualFrequencyHz` codée x100 ;
- `M3_BrakeIsOpen_DI` ;
- cinq capteurs TOR cumulés : Trémie, PV, P2 (`M3_PosPVP2_DI` dans l'image matérielle), P1, Maintenance ;
- position/vitesse physiques internes au jumeau pour diagnostic et comparaison.

Le mot capteurs respecte le contrat actif de `FB_Translation_PositionDecoder` :

`11111 -> 01111 -> 00111 -> 00011 -> 00001 -> 00000`

Toute autre combinaison est signalée incohérente.

## Lancement

Depuis la racine du dépôt :

```bat
TOOLS\TWINBENCH\modelica_viewer_m3\Lancer_M3Autonome.bat
```

ou :

```powershell
python TOOLS/TWINBENCH/modelica_viewer_m3/m3_native_viewer.py
```

Tests :

```powershell
cd TOOLS/TWINBENCH/modelica_viewer_m3
python -m unittest -v test_m3_native.py
```

## Règles de sûreté

- outil strictement hors ligne ;
- aucune connexion PLC ni écriture E/S machine ;
- aucune logique safety/interlock PLC recopiée dans la plante ;
- les commandes consommées sont les commandes finales post-interlock ;
- la position continue du Twin est une vérité de simulation, pas un capteur ajouté artificiellement au PLC.

## Paramètres physiques

Les positions et constantes dynamiques du moteur autonome sont des paramètres de simulation éditables. Elles ne sont pas présentées comme métrologie machine tant qu'elles ne sont pas confirmées terrain. Les futures briques physiques détaillées doivent rester traçables vers les composants/méthodes officiels Modelica Standard Library ; un composant non supporté doit basculer vers OpenModelica plutôt qu'être approximé silencieusement.
