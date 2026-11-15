# Mission 4 — Oracles Experts & Cadrage Sandbox Phase 2 (Anti-Faux Verts)

Tu es un collège d'Experts (Automatisme CODESYS, Cinématique/Mécanique, QA/Test).
Règle absolue : Zéro "faux vert". Le test doit prouver le phénomène physique réel (franchissement de la butée électrique en petite vitesse 5–10 Hz jusqu'au choc mécanique à EndStopMargin = 0,50 m), sans tricher sur les paramètres géométriques de la machine.

## Constats Phase 1 vérifiés
1. Modèle actuel (`FB_Sim_Translation*`) :
   - Distance d'arrêt à 5 Hz = 0,0080 m ; à 10 Hz = 0,0217 m.
   - `EndStopMargin_M = 0,50 m` (capteur électrique à 0,0 m, butée mécanique à -0,50 m).
   - `VelocityTrue_Mps := VelocityTarget_Mps` quand frein ouvert → zéro inertie/glissement tant que variateur alimenté, puis annulation nette à 0,5 Hz (`FB_Sim_TranslationDrive.st:57-61`).
   - `ObsCartFree` inhibé lors d'une coupure normale en butée.
2. Chaîne automate réelle (`PRG_06_Outputs.st:431-451`, `FB_Translation.st:137-141`, `FB_Safety_Translation.st:200-204`) :
   - `M3_TremieHardStopActive := M3_PosTremie_DI AND ReqTremieSemantic` (désarmable si `ReqTremieSemantic` retombe).
   - Aucun latch post-FDC : si `M3_PosTremie_DI` retombe à 0 (came étroite / dépassement / `CamDropoutActive`), `HardStop` et `EffectivePermitM3_Tremie` se ré-ouvrent immédiatement.
   - `TonLimitSwitchOverrun` (Cause 6) exige 1,5 s continues de `LimitSwitch * Commanded`.
   - Asymétrie Maintenance : pas de `HardStop` ni de `AND NOT DI` brut sur `EffectivePermitM3_Maintenance` (`PRG_06_Outputs.st:441`).

## Registre d'hypothèses à tester
- H1 : Perte de came (`CamDropoutActive` / `M3_PosTremie_DI` 1→0) pendant le roulis + maintien ou reprise ordre marche.
- H2 : Retard fermeture frein (`BrakeCloseDelay_S`) + couple freinage réel dégradé (`BrakeDecel_Mps2`).
- H3 : Inertie chariot / glissement rail (découplage `VelocityTrue_Mps` vs `VelocityTarget_Mps`).
- H4 : Latence capteur / debounce / +1 scan.
- H5 : Relâchement/reprise homme-mort en Manu pendant l'inertie.
- H6 : Approche côté Maintenance (absence de HardStop).

## Livrable attendu (concis, exploitable directement pour coder un banc sandbox)
1. **3 à 4 scénarios discriminants** (Petite vitesse 5 Hz et 10 Hz, Trémie et Maintenance, Manu et SEMI_AUTO) avec conditions initiales, stimuli exacts et hypothèses activées (`H1..H6`).
2. **Oracles stricts `PASS` / `FAIL`** pour chaque scénario : grandeurs physiques exactes à mesurer (`PositionTrue_M`, `ObsEndStopHitCount`, `ObsEndStopImpactSpeed_Mps`, `M3_PosTremie_DI`, `BrakeReleaseRequest`, `DriveFreqCmd_Hz`) et seuils qui prouvent la reproduction du bug (ex. dépassement > 0,50 m = choc mécanique, ou ré-ouverture de permis après perte DI).
3. **Critères anti-faux verts** (ce qui disqualifie immédiatement un test sandbox).
