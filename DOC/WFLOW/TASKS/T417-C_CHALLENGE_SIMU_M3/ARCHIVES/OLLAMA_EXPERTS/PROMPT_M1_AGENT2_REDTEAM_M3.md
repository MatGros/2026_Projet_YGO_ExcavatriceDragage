# MISSION AGENT 2 — CHALLENGER RED TEAM (CHALLENGE B) SUR L'ARRÊT M3 AU 1er TROU

## Contexte
On cherche à bloquer le mouvement M3 en `SEMI_AUTO` dès le 1er trou capteur (`M3_PosTremie_DI` et `M3_PosP1_DI`) exactement comme en `MANU`, via 3 approches candidates :
- **S1 (`FB_CycleSemiAuto.st`) :** Maintenir `TranslationCmd.PositionTgt` (`1` en AX14, `3` en AX2) pendant que `TranslationStopTimer` tourne (ne mettre que `ReqStart := FALSE`).
- **S2 (`FB_Translation.st`) :** Dès que `PositionSensorTarget` (qui est déjà alimenté par le bistable `M3_AtTremieStable` / `M3_AtP1Stable` de `PRG_05`) passe à `TRUE` dans le sens du mouvement (`LastMoveDirection`), armer `ArrivalLock := TRUE` immédiatement, utiliser `CfgRampDecelFastRate` si `ArrivalLock` est actif, et couper `MovementRequested := FALSE` dès que `ArrivalLock` (ou `LimitSwitchTremie` / `LimitSwitchMaintenance`) est atteint dans le sens commandé.
- **S3 (`PRG_06_Outputs.st`) :** Maintenir `M3_TremieHardStopActive` tant que `M3_TremieHardStopLatched` est vrai et qu'aucun mouvement inverse (`ReqMaintenanceSemantic`) n'est demandé (ou tant que l'axe n'est pas arrêté).

## Objectif Évaluable (4 Cas Pièges Obligatoires)
Analyser et challenger S1, S2, S3 face à :
1. **Piège 1 (Trou mécanique dans le rail `1 -> 0 -> 1`) :** Le capteur passe à 1 au début du trou, puis tombe à 0 dans le trou, puis repasse à 1 après. Que fait chaque solution ?
2. **Piège 2 (Dégagement sens opposé `AX18 -> AX2` vers P1 ou `AX2` vers Trémie) :** La solution risque-t-elle de bloquer le départ dans le sens opposé ?
3. **Piège 3 (Défauts `ErrorId=16` Méca B ou `ErrorId=64` ou `FB_Brake` ContactorCheck) :** Couper `MovementRequested` ou `BrakeReleaseRequest` dès le 1er trou à 20 Hz déclenche-t-il un défaut dans `FB_Safety_Translation` (`CauseMecaB`, `PostRampTimeout = 3s`) ou dans `FB_Brake` ?
4. **Verdict B :** Quelle combinaison exacte de S1 / S2 / S3 est 100 % sûre et sans effet de bord ?
