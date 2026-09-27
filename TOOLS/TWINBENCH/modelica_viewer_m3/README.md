# TwinBench M3 — WebApp + Modelica

Atelier hors ligne pour l'axe de translation M3. `CODE/` reste la vérité machine.

## 🌐 Interface principale : TwinBench Web

Ouvrir directement :

`TOOLS/TWINBENCH/modelica_viewer_m3/web/index.html`

Aucun serveur, Python ou OpenModelica requis pour le mode autonome navigateur.

Fonctions actuelles :
- Play / Pause / Step / Reset ;
- contrat AC600 : CommandWord, consigne Hz x100, StatusWord, fréquence réelle x100 ;
- commande/retour frein ;
- 5 capteurs TOR Trémie/PV/P2/P1/Maintenance ;
- animation de la translation ;
- courbes position/fréquence ;
- injection défaut thermique hors ligne ;
- vue blocs ;
- éditeur `.mo` local.

La frontière est alignée sur `CODE/` :

PLC -> Twin :
- `M3_CommandWord` : `0=stop`, `1=Trémie`, `2=Maintenance` ;
- `M3_SetpointFrequencyHz` : fréquence codée x100 ;
- `M3_BrakeRelease_RQ`.

Twin -> PLC / viewer :
- `M3_StatusWord` ;
- `M3_ActualFrequencyHz` codée x100 ;
- `M3_BrakeIsOpen_DI` ;
- cinq TOR cumulés : Trémie, PV, P2 (`M3_PosPVP2_DI`), P1, Maintenance.

Le mot capteurs respecte `FB_Translation_PositionDecoder` :

`11111 -> 01111 -> 00111 -> 00011 -> 00001 -> 00000`

## ⚙️ Moteur autonome Python

Le moteur de référence testable reste également disponible :

`Lancer_M3Autonome.bat`

Tests :

```powershell
cd TOOLS/TWINBENCH/modelica_viewer_m3
python -m unittest -v test_m3_native.py
```

## 🧩 OpenModelica

`Lancer_M3Viewer.bat`

Le viewer `.mo` historique est conservé. OpenModelica/`omc.exe` reste le backend de référence pour les modèles Modelica complets et les futures comparaisons de résultats.

## 🔒 Sûreté / périmètre

- outil strictement hors ligne ;
- aucune connexion PLC ni écriture E/S machine ;
- aucune logique safety/interlock PLC recopiée dans la plante ;
- la position continue du Twin est une vérité de simulation, pas un capteur PLC ajouté ;
- constantes dynamiques actuelles = paramètres de banc, non métrologie terrain ;
- les futures briques physiques détaillées doivent être traçables vers les méthodes/composants officiels Modelica Standard Library ;
- un composant non supporté doit basculer vers OpenModelica plutôt qu'être approximé silencieusement.
