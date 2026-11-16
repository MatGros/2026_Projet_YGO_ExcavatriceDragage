# MISSION AGENT 1 — AUDIT CHAÎNE D'ARRÊT M3 AU 1er TROU (MANU vs SEMI_AUTO) & 3 SOLUTIONS ST

## Contexte Code Vérifié
1. En `MANU` (`MAINT_N1`), l'opérateur pousse le joystick (`M3_ReqTremie_Active = TRUE`). Au 1er trou capteur (`M3_PosTremie_DI = TRUE` ou `M3_PosP1_DI`), l'opérateur maintient encore le joystick ~0,3-0,5 s :
   - Dans `FB_Translation.st:291` : `EffectiveSafeStop := SafeStop OR (ReqTremie AND NOT EffectivePermitM3_Tremie) ...` reste `TRUE` -> `SpeedRamp` décélère sur `CfgRampDecelFastRate` (rampe rapide).
   - Dans `PRG_06_Outputs.st:438` : `M3_TremieHardStopActive := M3_TremieHardStopLatched AND ReqTremieSemantic` reste `TRUE` -> coupe immédiatement `DriveControlWord := 0` et `BrakeRelease_RQ := FALSE`.
   - Dans `PRG_05_Translation.st:439` : `M3_TargetCodeSel` reste actif -> `CaptorDebounceTon` (100 ms) dans `FB_Translation.st:192` aboutit et arme `ArrivalLock := TRUE`.
2. En `SEMI_AUTO` (`FB_CycleSemiAuto.st:985` AX2 et `:1490` AX14) :
   - Dès que `Translation_At_P1` (`M3_AtP1Stable`) ou `Translation_At_Tremie` (`M3_AtTremieStable`) passe à `TRUE`, au scan suivant (+10 ms) `FB_CycleSemiAuto` écrit :
     `TranslationCmd.ReqStart := FALSE; TranslationCmd.PositionTgt := 0;`
   - Conséquence dès +10 ms :
     a) `M3_ReqTremie_Active` (`ReqTremieSemantic`) tombe à `FALSE`.
     b) `EffectiveSafeStop` retombe à `FALSE` -> `SpeedRamp` décélère sur `CfgRampDecelNormalRate` (rampe lente).
     c) `M3_TremieHardStopActive` dans `PRG_06` retombe à `FALSE` après 10 ms -> le frein ne tombe plus par `PRG_06`, mais attend `FB_Translation.Brake` (`SpeedRamp.Current <= 0.1` + `DelayMotorDecel`).
     d) En `AX2` (`P1`), `PositionTgt := 0` fait tomber `M3_PositionSensorTarget` après 10 ms avant la fin du `CaptorDebounceTon` (100 ms) -> `ArrivalLock` ne s'arme jamais !

## Objectif Évaluable
1. Dresser la chronologie exacte Scan N / Scan N+1 / Scan N+2..N+50 entre `MANU` et `SEMI_AUTO`.
2. Proposer **3 solutions ST distinctes (S1, S2, S3)** (ou leur combinaison optimale) pour que `SEMI_AUTO` bloque et freine dès le 1er trou exactement comme `MANU` (sur Trémie ET sur P1).
3. Fournir les snippets ST exacts pour chaque solution.
