# Mission 6 — Challenge & Contre-Argumentaire des Hypothèses M3

Tu es un Expert Senior en Automatisme Industriel, Cinématique et Simulation.
Objectif : Challenger 3 hypothèses candidates expliquant le dépassement de butée électrique à petite vitesse (5-10 Hz) jusqu'au choc mécanique (0,50 m), alors que le simulateur actuel s'arrête proprement.

## Données vérifiées dans notre banc paramétrique et dans le code réel
1. **Simulateur actuel (`FB_Sim_Translation*`, `GVL_Simulation.st`)** :
   - `Gain = 0,02 m/(Hz.s)` -> 5 Hz = 0,10 m/s, 10 Hz = 0,20 m/s.
   - Arrêt nominal : 0,008 m (5 Hz) et 0,0217 m (10 Hz), contre `EndStopMargin_M = 0,50 m`.
   - `FB_Sim_PositionSensor.st` modélise une came infinie vers `-inf` avec seulement un trou de 4 cm (`CamDropoutWidth = 0,04 m`).
   - Résultat banc sur modèle actuel (10 Hz, `CamDropout = 0,04 m`, `operator_holds_cmd=True`) : pénètre à `0,0836 m` (1 ré-énergisation dans le trou de came) puis s'arrête.
2. **Trace terrain 27 (2026-09-04, 10 Hz)** :
   - 26438 ms : `Tremie=1`, `Cmd 1->0`, `ContactFrein 1->0`, `ErrorId=64`.
   - 26553 ms (+115 ms) : `Tremie=0` (capteur perdu !) alors que `Freq=913` (9,13 Hz).

## Les 3 Hypothèses à challenger (avec Argumentaire + Contre-Argumentaire)

### Hypothèse H1 : Came de fin de course de largeur finie / perte capteur post-passage + absence de verrou (latch) dans `PRG_06_Outputs.st:431-450`
- Constat banc : avec came finie `0,04 m` + inertie découplée + frein retardé `0,25 s` / `0,8 m/s²` + ordre maintenu (`10 Hz`), le chariot glisse de `4,86 cm`, sort de la came, `PRG_06` ré-ouvre le permis, le moteur ré-accélère -> **choc à 0,50 m à 0,20 m/s**.
- Contre-épreuve banc : avec un latch dans `PRG_06`, arrêt propre à `0,0486 m`.

### Hypothèse H2 : Vitesse réelle sous-estimée (`Gain` réel > 0,02) + inertie/glissement sur rail humide + frein dégradé
- Constat code : `FB_Sim_Translation.st:156` mentionne un `gain audit 0,0551 m/(Hz.s)` (vs `0,02` par défaut, max `0,05` dans `FB_Translation_OdometryGain.st:57`).
- Constat banc : à `10 Hz`, `gain = 0,045`, frein humide (`0,30 s`, `0,35 m/s²`), le chariot glisse à `0,3797 m` sans même perdre le capteur (et dépasse `0,50 m` si `gain = 0,055` ou légère pente).

### Hypothèse H3 : Asymétrie de protection côté Maintenance (`PRG_06_Outputs.st:441`)
- Constat code : pas de `HardStop` ni de `AND NOT M3_PosMaintenance_DI` sur `EffectivePermitM3_Maintenance` (contrairement au côté Trémie).

## Livrable attendu (concis, structuré pour décision exploitant)
Pour chaque hypothèse (H1, H2, H3) :
1. **Force de l'argumentaire** (pourquoi c'est physiquement et logiquement réaliste sur cette machine).
2. **Contre-argumentaire strict** (ce qui peut invalider l'hypothèse sur le terrain ou dans le code, ex. `ErrorId=64` qui bloque une reprise, type de capteur réel sur rail, etc.).
3. **Paramètre(s) exact(s) à exposer/rendre réglables dans le simulateur** pour que l'exploitant puisse tester l'hypothèse lui-même.
