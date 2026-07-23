(* ═══════════════════════════════════════════════════════════════
   🖥️ PRG_09_Supervision — Échanges IHM, Stubs et Initialisation Boot
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 9.
   ✅ Regroupe tout le mapping bidirectionnel GVL_IHM / GVL_PERSISTENT.
   ✅ Expose FaultMachineReset_IHM pour tous les programmes du domaine sécurité/métier.
   🔧 REX 2026-07-07 : séparation des resets — l'ancien MachineReset_IHM (unique, câblé sur
      TOUT y compris FB_Modes/FB_Cycle) est retiré. FaultMachineReset_IHM ne couvre plus que le
      domaine sécurité/métier (Winch, Safety, Encodeurs, Benne, Joystick, Translation) ;
      FB_Modes/FB_Cycle ont chacun leur propre Reset dédié (GVL_IHM.Modes.BtnModeReset côté
      PRG_04_Modes, CmdResetCycle_IHM côté PRG_05_Cycle) — jamais mélangés.
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-07_Interface_IHM_v1.5.md
*)

PROGRAM PRG_09_Supervision
VAR_OUTPUT
    FaultMachineReset_IHM : BOOL; // 🔔 Acquittement défauts domaine sécurité/métier (OR des boutons HMI) — jamais Modes/Cycle
END_VAR
VAR
    instBlink1Hz : BLINK; // 🧩 Réutilisation lib Util (Partie3 §0) — horloge clignotement système
    BypassRestoreDone : BOOL := FALSE; // 🌐 Flag restauration unique des bypass (boot)
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_09_Supervision) ===

// ── 0. HORLOGE CLIGNOTEMENT SYSTÈME (GVL_Global.BlinkClock) ───────────────
// 🧩 Réutilisation lib Util (Partie3 §0) : bloc standard BLINK, pas de TON maison —
// gère nativement un rythme allumé/éteint ASYMÉTRIQUE (TimeHigh ≠ TimeLow), contrairement
// au motif TON manuel de FB_Output.st (symétrique 500/500, propre à l'option relais).
// 🔧 REX 2026-07-16 : durées réglables sans recompiler (GVL_PERSISTENT._BlinkTimeOn/_BlinkTimeOff,
// défaut 1s allumé / 800ms éteint) — un seul rythme partagé pour tous les voyants IHM/diag qui
// clignotent pareil.
// 💡 Un voyant a besoin d'un AUTRE rythme ? Instancier son propre BLINK localement (Util) avec
// ses propres TimeHigh/TimeLow — ne pas détourner ce bit partagé pour un rythme différent.
instBlink1Hz(
    ENABLE   := TRUE,
    TIMEHIGH := _BlinkTimeOn,
    TIMELOW  := _BlinkTimeOff
);
GVL_Global.BlinkClock := instBlink1Hz.OUT;


// ── 1. ACQUISITION DES DEMANDES / BOUTONS DE L'IHM ────────────────────────
GVL_Modes_Stub.ModeRequest_IHM         := GVL_IHM.Modes.SelMode;
GVL_Modes_Stub.SyncEnableRequest_IHM   := GVL_IHM.Sync.SelSyncEnable; // 🔧 REX 2026-07-08 : renommé, polarité inversée
StubTranslationPositionSelect_IHM          := GVL_IHM.TranslationM3.Cmd.SelTarget;

// 🧪 Commandes de test Translation depuis la supervision.
// Verrouillage obligatoire : aucune surcharge IHM ne peut être active hors simulation.
IF GVL_Simulation.SimulationModeActive THEN
    GVL_PLC_Tests.OverrideM3SensorsWordActive := GVL_IHM.TranslationM3.Test.SensorsWordActive;
    GVL_PLC_Tests.OverrideM3SensorsWord       := GVL_IHM.TranslationM3.Test.SensorsWord;
    GVL_PLC_Tests.OverrideM3AtTremie          := GVL_IHM.TranslationM3.Test.AtTremie;
    GVL_PLC_Tests.OverrideM3BrakeStuckOpen    := GVL_IHM.TranslationM3.Test.BrakeStuckOpen;
    GVL_PLC_Tests.OverrideM3PhantomFreq       := GVL_IHM.TranslationM3.Test.PhantomFreq;
ELSE
    GVL_PLC_Tests.OverrideM3SensorsWordActive := FALSE;
    GVL_PLC_Tests.OverrideM3AtTremie          := FALSE;
    GVL_PLC_Tests.OverrideM3BrakeStuckOpen    := FALSE;
    GVL_PLC_Tests.OverrideM3PhantomFreq       := FALSE;
END_IF;

// Signal d'acquittement défauts domaine sécurité/métier — JAMAIS Modes/Cycle (REX 2026-07-07)
FaultMachineReset_IHM := GVL_IHM.Modes.BtnFaultReset
                    OR GVL_IHM.M1TreuilRetenue.Cmd.BtnReset
                    OR GVL_IHM.M2TreuilBenne.Cmd.BtnReset
                    OR GVL_IHM.M2Benne.BtnReset;

// 🔴 REX 2026-07-07 : au moins un défaut actif dans le domaine couvert par FaultMachineReset_IHM
// (même périmètre exact que les 17 blocs alimentés par ce reset — voir bandeau en tête de fichier).
// Sert à savoir, côté IHM, quand un appui sur BtnFaultReset est utile/attendu.
GVL_IHM.Modes.AnyFaultActive :=
       PRG_01_Diagnostics.instDiagCanOpen.Error
    OR PRG_01_Diagnostics.instDiagEthercat.Error
    OR PRG_01_Diagnostics.FB_Joystick_0.Error
    OR (NOT PRG_04_Modes.instModes.InhibitM1 AND (
           PRG_02_Encoders.instEncoderAbsM1.Error
        OR PRG_02_Encoders.instHomingM1.Error
        OR PRG_02_Encoders.instEncoderSafetyM1.Error
        OR PRG_03_Safety.instSafetyWinchM1.Error
        OR PRG_06_WinchControl.instWinchM1.Error
    ))
    OR (NOT PRG_04_Modes.instModes.InhibitM2 AND (
           PRG_02_Encoders.instEncoderAbsM2.Error
        OR PRG_02_Encoders.instHomingM2.Error
        OR PRG_02_Encoders.instEncoderSafetyM2.Error
        OR PRG_03_Safety.instSafetyWinchM2.Error
        OR PRG_06_WinchControl.instWinchM2.Error
    ))
    OR PRG_03_Safety.instSafetyTranslationM3.Error
    OR PRG_06_WinchControl.instWinchSync.Error
    OR PRG_06_WinchControl.instBucket.Error
    OR PRG_07_TranslationControl.instTranslationM3.Error
    OR PRG_10_Outputs.RedundancyTestFailed
    OR PRG_10_Outputs.EmergencyArmingFailed;

// 🧨 REX 2026-07-07 : remontée IHM de la coupure puissance amont — polarité "alarme" (TRUE=
// problème), PAS celle de PowerCutOff_A_RQ (qui est en fail-safe maintenu, TRUE=OK depuis
// l'inversion de polarité). On relit directement les .PowerCutOff sources, pas la sortie physique.
GVL_IHM.Modes.PowerCutOffActive := PRG_03_Safety.instSafetyWinchM1.PowerCutOff
                                 OR PRG_03_Safety.instSafetyWinchM2.PowerCutOff
                                 OR PRG_03_Safety.instSafetyTranslationM3.PowerCutOff
                                 OR GVL_IHM.Modes.BtnEmergencyCutOff;

// 🆕 REX 2026-07-08 : thermique frein commun M1/M2/M3 — signal UNIQUE (1 seul fil, pas de sens à
// le dupliquer par axe), remonté une seule fois au niveau global GVL_IHM (même principe que
// TopPositionSensorActive ci-dessus, PAS dans WinchM1/WinchM2/Translation).
GVL_IHM.Commun.BrakeThermalFault := NOT PRG_00_Inputs.BrakeThermalFeedback;
GVL_IHM.Commun.PhaseRotationFault := NOT PRG_00_Inputs.PhaseRotationOk; // 🆕 REX 2026-07-08 — commun M1/M2/M3, invisible IHM avant
GVL_IHM.Commun.HydraulicThermalFault := NOT PRG_08_AuxiliaryControl.HydraulicFaultOk; // 🆕 REX 2026-07-18 — diagnostic seul, aucune commande PLC

// 💓 Heartbeat IHM↔PLC — le toggle IHM est lu directement en PRG_01 ; ici, on publie
// les diagnostics calculés au même scan pour l'affichage et l'historisation IHM.
GVL_IHM.Commun.TglHeartbeatPlc  := PRG_01_Diagnostics.instIhmHeartbeat.TglHeartbeatPlc;
GVL_IHM.Commun.HeartbeatIhmOk      := PRG_01_Diagnostics.instIhmHeartbeat.HeartbeatIhmOk;
GVL_IHM.Commun.HeartbeatIhmTimeout := PRG_01_Diagnostics.instIhmHeartbeat.HeartbeatIhmTimeout;
GVL_IHM.Commun.HeartbeatIhmElapsed := PRG_01_Diagnostics.instIhmHeartbeat.TimeSinceIhmEdge;

// 🔧 REX 2026-07-07 — Séquence réarmement AU (voir DOC/AF_Partie-01_Analyse_Fonctionnelle_v1.6.md §Sécurité électrique)
// EmergencyArmingBusy couvre TOUTE la séquence (auto-test A/B + pulse + confirmation + verrouillage),
// pas seulement le pulse — ArmingSeqStep<>0 englobe déjà tout sauf le verrouillage final.
GVL_IHM.Modes.EmergencyChainOk    := PRG_00_Inputs.EmergencyChain;
GVL_IHM.Modes.PowerContactorOk    := PRG_00_Inputs.EmergencyStopOk;
GVL_IHM.Modes.EmergencyArmingBusy := (PRG_10_Outputs.ArmingSeqStep <> 0) OR PRG_10_Outputs.EmergencyArmingLockoutActive;
GVL_IHM.Modes.EmergencyArmable    := PRG_00_Inputs.EmergencyChain
                                    AND (PRG_10_Outputs.ArmingSeqStep = 0)
                                    AND NOT PRG_10_Outputs.EmergencyArmingLockoutActive
                                    AND NOT PRG_10_Outputs.RedundancyTestFailed;
GVL_IHM.Modes.RedundancyTestFailed := PRG_10_Outputs.RedundancyTestFailed;
GVL_IHM.Modes.EmergencyArmingFailed := PRG_10_Outputs.EmergencyArmingFailed;

// 🔧 REX 2026-07-07 : ancien pont IF/ELSIF vers GVL_Encoder_Stub supprimé (bugué — ne pouvait
// homer qu'un seul treuil à la fois). GVL_IHM.M1TreuilRetenue/M2.BtnHome sont désormais câblés
// directement dans PRG_02_Encoders.st (instHomingM1/M2.Home) — homing simultané possible.

// ℹ️ BtnCalibrate joystick : lu directement depuis GVL_IHM.JOY1Joystick.BtnCalibrate dans PRG_01_Diagnostics (ligne 48)


// ── 2. INITIALISATION IHM DEPUIS GVL_PERSISTENT (Boot) ───────────────────
IF GVL_IHM.M1TreuilRetenue.Cfg.CfgTopSensorPos_M = 0.0 THEN
    GVL_IHM.M1TreuilRetenue.Cfg.CfgTopSensorPos_M  := _HomingTargetM1_M;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgHomingTarget_M       := _HomingUnitaryTargetM1_M;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepDescente     := _WinchMaxStepDescent; // 🔧 REX 2026-07-08 : commun M1/M2
    GVL_IHM.M1TreuilRetenue.Cfg.CfgRampAccelRate       := _WinchM1RampAccelRate_Pct;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgRampDecelNormalRate := _WinchM1RampDecelNormal_Pct;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgRampDecelFastRate   := _WinchM1RampDecelFast_Pct;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitDescent_M  := _CableLimitM1Descent_M;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitAscent_M   := _CableLimitM1Ascent_M;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowdownDistance_M   := _WinchSlowdownDistance_M;
    GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowSpeed_Pct        := _WinchSlowSpeed_Pct;
END_IF;

IF GVL_IHM.M2TreuilBenne.Cfg.CfgTopSensorPos_M = 0.0 THEN
    GVL_IHM.M2TreuilBenne.Cfg.CfgTopSensorPos_M  := _HomingTargetM2_M;
    GVL_IHM.M2TreuilBenne.Cfg.CfgHomingTarget_M       := _HomingUnitaryTargetM2_M;
    GVL_IHM.M2TreuilBenne.Cfg.CfgMaxStepDescente     := _WinchMaxStepDescent; // 🔧 REX 2026-07-08 : commun M1/M2
    GVL_IHM.M2TreuilBenne.Cfg.CfgRampAccelRate       := _WinchM2RampAccelRate_Pct;
    GVL_IHM.M2TreuilBenne.Cfg.CfgRampDecelNormalRate := _WinchM2RampDecelNormal_Pct;
    GVL_IHM.M2TreuilBenne.Cfg.CfgRampDecelFastRate   := _WinchM2RampDecelFast_Pct;
    GVL_IHM.M2TreuilBenne.Cfg.CfgCableLimitDescent_M  := _CableLimitM2Descent_M;
    GVL_IHM.M2TreuilBenne.Cfg.CfgCableLimitAscent_M   := _CableLimitM2Ascent_M;
    GVL_IHM.M2TreuilBenne.Cfg.CfgSlowdownDistance_M   := _WinchSlowdownDistance_M;
    GVL_IHM.M2TreuilBenne.Cfg.CfgSlowSpeed_Pct        := _WinchSlowSpeed_Pct;
END_IF;

IF GVL_IHM.Sync.CfgSyncTolerance_M = 0.0 THEN
    GVL_IHM.Sync.CfgSyncTolerance_M          := _WinchSyncTolerance_M;
END_IF;

IF GVL_IHM.M2Benne.Config.OffsetOpenM = 0.0 AND GVL_IHM.M2Benne.Config.OffsetCloseM = 0.0 THEN
    GVL_IHM.M2Benne.Config := _BucketConfig;
    GVL_IHM.M2Benne.CfgTimeoutDuration := T#30s;
END_IF;

IF GVL_IHM.Commun.LimitLegalDepthMinAllowed_M = 0.0 THEN
    GVL_IHM.Commun.LimitLegalDepthMinAllowed_M := _LimitLegalDepthMinAllowed_M;
    GVL_IHM.Commun.LimitLegalEnabled         := _LimitLegalEnabled;
END_IF;

// 🌐 Restauration des bypass RETAIN au boot UNIQUEMENT (premier scan)
// Après ça, seule la sauvegarde IHM→RETAIN fonctionne (jamais l'inverse).
// Évite le bug où une écriture IHM était écrasée par la restauration.
IF NOT BypassRestoreDone THEN
    IF BypassTranslationGlobal AND GVL_IHM.TranslationM3.Bypass.Global = FALSE THEN
        GVL_IHM.TranslationM3.Bypass.Global := TRUE;
    END_IF;
    IF BypassWinchM1Global AND GVL_IHM.M1TreuilRetenue.Bypass.Global = FALSE THEN
        GVL_IHM.M1TreuilRetenue.Bypass.Global := TRUE;
    END_IF;
    IF BypassWinchM2Global AND GVL_IHM.M2TreuilBenne.Bypass.Global = FALSE THEN
        GVL_IHM.M2TreuilBenne.Bypass.Global := TRUE;
    END_IF;
    IF BypassSyncGlobal AND GVL_IHM.Sync.BypassGlobal = FALSE THEN
        GVL_IHM.Sync.BypassGlobal := TRUE;
    END_IF;
    IF BypassNetworkGlobal AND GVL_IHM.Network.Bypass.Global = FALSE THEN
        GVL_IHM.Network.Bypass.Global := TRUE;
    END_IF;
    IF BypassBucketGlobal AND GVL_IHM.M2Benne.BypassGlobal = FALSE THEN
        GVL_IHM.M2Benne.BypassGlobal := TRUE;
    END_IF;
    BypassRestoreDone := TRUE;
END_IF;


// ── 3. PROPAGATION DES RÉGLAGES IHM → PERSISTANCE ───────────────────────
// ── 3. PROPAGATION DES RÉGLAGES IHM → PERSISTANCE ───────────────────────
_HomingTargetM1_M            := GVL_IHM.M1TreuilRetenue.Cfg.CfgTopSensorPos_M;
_HomingTargetM2_M            := GVL_IHM.M2TreuilBenne.Cfg.CfgTopSensorPos_M;
_HomingUnitaryTargetM1_M     := GVL_IHM.M1TreuilRetenue.Cfg.CfgHomingTarget_M;
_HomingUnitaryTargetM2_M     := GVL_IHM.M2TreuilBenne.Cfg.CfgHomingTarget_M;
// 🔧 REX 2026-07-08 : CfgMaxStepDescente désormais commun M1/M2 — voir bloc miroir bidirectionnel
// ci-dessous (même pattern que CableLimitDescent_M/SlowdownDistance_M/SlowSpeed_Pct), plus de
// propagation à sens unique séparée par treuil ici.
_WinchM1RampAccelRate_Pct   := GVL_IHM.M1TreuilRetenue.Cfg.CfgRampAccelRate;
_WinchM1RampDecelNormal_Pct := GVL_IHM.M1TreuilRetenue.Cfg.CfgRampDecelNormalRate;
_WinchM1RampDecelFast_Pct   := GVL_IHM.M1TreuilRetenue.Cfg.CfgRampDecelFastRate;
_WinchM2RampAccelRate_Pct   := GVL_IHM.M2TreuilBenne.Cfg.CfgRampAccelRate;
_WinchM2RampDecelNormal_Pct := GVL_IHM.M2TreuilBenne.Cfg.CfgRampDecelNormalRate;
_WinchM2RampDecelFast_Pct   := GVL_IHM.M2TreuilBenne.Cfg.CfgRampDecelFastRate;
// ⚠️ REX 2026-07-08 (5) — PIÈGE pont IHM→PERSISTENT découvert lors de l'audit : cette ligne
// écrase _WinchSyncTolerance_M avec GVL_IHM.Sync.SyncTolerance_M À CHAQUE SCAN.
// Si on change UNIQUEMENT la valeur par défaut dans GVL_PERSISTENT.st (ou ST_SyncHMI.st), ça ne
// suffit pas : la valeur restaurée au boot (bloc §2 ci-dessus, `IF ... = 0.0 THEN`) ne s'applique
// que si le RETAIN IHM est à 0.0 (premier démarrage) — sinon l'ancienne valeur IHM re-propage ici
// et écrase silencieusement toute nouvelle valeur par défaut au scan suivant.
_WinchSyncTolerance_M       := GVL_IHM.Sync.CfgSyncTolerance_M;
_BucketConfig              := GVL_IHM.M2Benne.Config;

// 🔧 REX 2026-07-08 (demande utilisateur) : CfgMaxStepDescente commun M1/M2 — même profil de
// déplacement des 2 treuils, même pattern miroir que CableLimitDescent_M ci-dessous.
IF GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepDescente <> _WinchMaxStepDescent THEN
    _WinchMaxStepDescent := GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepDescente;
ELSIF GVL_IHM.M2TreuilBenne.Cfg.CfgMaxStepDescente <> _WinchMaxStepDescent THEN
    _WinchMaxStepDescent := GVL_IHM.M2TreuilBenne.Cfg.CfgMaxStepDescente;
END_IF;
GVL_IHM.M1TreuilRetenue.Cfg.CfgMaxStepDescente := _WinchMaxStepDescent;
GVL_IHM.M2TreuilBenne.Cfg.CfgMaxStepDescente := _WinchMaxStepDescent;

IF GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitDescent_M <> _CableLimitM1Descent_M THEN
    _CableLimitM1Descent_M := GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitDescent_M;
END_IF;
GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitDescent_M := _CableLimitM1Descent_M;

IF GVL_IHM.M2TreuilBenne.Cfg.CfgCableLimitDescent_M <> _CableLimitM2Descent_M THEN
    _CableLimitM2Descent_M := GVL_IHM.M2TreuilBenne.Cfg.CfgCableLimitDescent_M;
END_IF;
GVL_IHM.M2TreuilBenne.Cfg.CfgCableLimitDescent_M := _CableLimitM2Descent_M;

// 🆕 REX 2026-07-15 (6) — même pattern miroir bidirectionnel que CableLimitDescent_M ci-dessus.
IF GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitAscent_M <> _CableLimitM1Ascent_M THEN
    _CableLimitM1Ascent_M := GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitAscent_M;
END_IF;
GVL_IHM.M1TreuilRetenue.Cfg.CfgCableLimitAscent_M := _CableLimitM1Ascent_M;

IF GVL_IHM.M2TreuilBenne.Cfg.CfgCableLimitAscent_M <> _CableLimitM2Ascent_M THEN
    _CableLimitM2Ascent_M := GVL_IHM.M2TreuilBenne.Cfg.CfgCableLimitAscent_M;
END_IF;
GVL_IHM.M2TreuilBenne.Cfg.CfgCableLimitAscent_M := _CableLimitM2Ascent_M;

IF GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowdownDistance_M <> _WinchSlowdownDistance_M THEN
    _WinchSlowdownDistance_M := GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowdownDistance_M;
ELSIF GVL_IHM.M2TreuilBenne.Cfg.CfgSlowdownDistance_M <> _WinchSlowdownDistance_M THEN
    _WinchSlowdownDistance_M := GVL_IHM.M2TreuilBenne.Cfg.CfgSlowdownDistance_M;
END_IF;
GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowdownDistance_M := _WinchSlowdownDistance_M;
GVL_IHM.M2TreuilBenne.Cfg.CfgSlowdownDistance_M := _WinchSlowdownDistance_M;

IF GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowSpeed_Pct <> _WinchSlowSpeed_Pct THEN
    _WinchSlowSpeed_Pct := GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowSpeed_Pct;
ELSIF GVL_IHM.M2TreuilBenne.Cfg.CfgSlowSpeed_Pct <> _WinchSlowSpeed_Pct THEN
    _WinchSlowSpeed_Pct := GVL_IHM.M2TreuilBenne.Cfg.CfgSlowSpeed_Pct;
END_IF;
GVL_IHM.M1TreuilRetenue.Cfg.CfgSlowSpeed_Pct := _WinchSlowSpeed_Pct;
GVL_IHM.M2TreuilBenne.Cfg.CfgSlowSpeed_Pct := _WinchSlowSpeed_Pct;

_LimitLegalDepthMinAllowed_M := GVL_IHM.Commun.LimitLegalDepthMinAllowed_M;
_LimitLegalEnabled         := GVL_IHM.Commun.LimitLegalEnabled;

// 🌐 Sauvegarde des bypass RETAIN (survit au warm restart / download)
BypassTranslationGlobal     := GVL_IHM.TranslationM3.Bypass.Global;
BypassWinchM1Global         := GVL_IHM.M1TreuilRetenue.Bypass.Global;
BypassWinchM2Global         := GVL_IHM.M2TreuilBenne.Bypass.Global;
BypassSyncGlobal            := GVL_IHM.Sync.BypassGlobal;
BypassNetworkGlobal         := GVL_IHM.Network.Bypass.Global;
BypassBucketGlobal          := GVL_IHM.M2Benne.BypassGlobal;
// 🔧 REX 2026-07-07 : plus de garde Mode=SEMI_AUTO, cohérent avec PRG_06_WinchControl.st §5
// (la limite légale s'applique désormais dans tous les modes dès qu'elle est activée).
GVL_IHM.Commun.LimitLegalReached         := _LimitLegalEnabled
                                            AND ((NOT PRG_04_Modes.instModes.InhibitM1 AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM <= _LimitLegalDepthMinAllowed_M))
                                                 OR (NOT PRG_04_Modes.instModes.InhibitM2 AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM <= _LimitLegalDepthMinAllowed_M)));

GVL_IHM.Commun.TopPositionSensorActive   := NOT PRG_00_Inputs.TopPositionSensor;


// ── 4. BYPASS DE SIMULATION POUR L'IHM (état effectif par device, voir DOC/AF_Partie-13_Fonction_Simulation_v1.2.md) ──────
// 🔧 REX (session Bypass) : structs Bypass dedies par metier (voir DOC/AUDITS/Bypass/REGISTRE_ACTIONS_Bypass_v1.0.md)
// — ContactorFeedback reste par axe (materiel propre a chaque treuil/translation), SlackCable et
// TopPositionSensor passent dans Commun.Bypass (capteur physique UNIQUE partage M1/M2, plus de duplication).
GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SensorM1ContactorFeedbackIsReal;
GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SensorM2ContactorFeedbackIsReal;
GVL_IHM.TranslationM3.Bypass.ContactorFeedback := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SensorM3ContactorFeedbackIsReal;
GVL_IHM.Commun.Bypass.SlackCable        := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SensorSlackCableIsReal;
GVL_IHM.Commun.Bypass.TopPositionSensor := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SensorTopPositionIsReal;


// ── 5. MAPPING ÉTATS TREUIL M1 → IHM ─────────────────────────────────────
GVL_IHM.M1TreuilRetenue.State.Position_M                 := PRG_02_Encoders.instEncoderScaleM1.CablePosM;
GVL_IHM.M1TreuilRetenue.State.MeasuredSpeed_Mps          := PRG_03_Safety.instSafetyWinchM1.MeasuredSpeedMps;
GVL_IHM.M1TreuilRetenue.State.SpeedDelta_Mps             := PRG_03_Safety.instSpeedMonitorM1.SpeedDeltaMps;
GVL_IHM.M1TreuilRetenue.State.SpeedVariationDetected   := PRG_03_Safety.instSpeedMonitorM1.SpeedVariationDetected;
GVL_IHM.M1TreuilRetenue.State.SpeedVariationConfirmed  := PRG_03_Safety.instSpeedMonitorM1.SpeedVariationConfirmed;
GVL_IHM.M1TreuilRetenue.State.SpeedStable             := PRG_03_Safety.instSpeedMonitorM1.SpeedStable;
GVL_IHM.M1TreuilRetenue.State.SpeedMonitorError        := PRG_03_Safety.instSpeedMonitorM1.Error;
GVL_IHM.M1TreuilRetenue.State.SpeedMonitorErrorId      := PRG_03_Safety.instSpeedMonitorM1.ErrorId;
GVL_IHM.M1TreuilRetenue.State.EstimatedLoadPct          := PRG_03_Safety.instLoadEstimatorM1.EstimatedLoadPct;
GVL_IHM.M1TreuilRetenue.State.LoadEstimateConfigured   := PRG_03_Safety.instLoadEstimatorM1.Configured;
GVL_IHM.M1TreuilRetenue.State.SpeedGuardLimited        := PRG_06_WinchControl.instWinchM1.SpeedGuardLimited;
GVL_IHM.M1TreuilRetenue.State.SpeedRef_Pct               := PRG_06_WinchControl.instWinchM1.SpeedRamp.Current;
GVL_IHM.M1TreuilRetenue.State.StepNumber               := PRG_06_WinchControl.instWinchM1.StepNumber;
GVL_IHM.M1TreuilRetenue.State.FBState                  := PRG_06_WinchControl.instWinchM1.State;
GVL_IHM.M1TreuilRetenue.State.Ready                    := PRG_06_WinchControl.instWinchM1.Ready;
GVL_IHM.M1TreuilRetenue.State.Busy                     := PRG_06_WinchControl.instWinchM1.Busy;
GVL_IHM.M1TreuilRetenue.State.Done                     := PRG_06_WinchControl.instWinchM1.Done;
GVL_IHM.M1TreuilRetenue.State.Error                    := PRG_06_WinchControl.instWinchM1.Error;
GVL_IHM.M1TreuilRetenue.State.ErrorId                  := PRG_06_WinchControl.instWinchM1.ErrorId;
GVL_IHM.M1TreuilRetenue.State.RelayFwd                 := PRG_06_WinchControl.instWinchM1.RelayFwd;
GVL_IHM.M1TreuilRetenue.State.RelayRev                 := PRG_06_WinchControl.instWinchM1.RelayRev;
GVL_IHM.M1TreuilRetenue.State.Contactor1               := PRG_06_WinchControl.instWinchM1.Contactor1;
GVL_IHM.M1TreuilRetenue.State.Contactor2               := PRG_06_WinchControl.instWinchM1.Contactor2;
GVL_IHM.M1TreuilRetenue.State.Contactor3               := PRG_06_WinchControl.instWinchM1.Contactor3;
GVL_IHM.M1TreuilRetenue.State.Contactor4               := PRG_06_WinchControl.instWinchM1.Contactor4;
GVL_IHM.M1TreuilRetenue.State.BrakeCmd                 := PRG_06_WinchControl.instWinchM1.BrakeCmd;
GVL_IHM.M1TreuilRetenue.State.Homed                    := PRG_02_Encoders.instHomingM1.Homed;
GVL_IHM.M1TreuilRetenue.State.HomingBusy              := PRG_02_Encoders.instHomingM1.Busy;
GVL_IHM.M1TreuilRetenue.State.HomingDone              := PRG_02_Encoders.instHomingM1.Done;
GVL_IHM.M1TreuilRetenue.State.HomingError             := PRG_02_Encoders.instHomingM1.Error;
GVL_IHM.M1TreuilRetenue.State.HomingErrorId           := PRG_02_Encoders.instHomingM1.ErrorId;
GVL_IHM.M1TreuilRetenue.State.HomingState             := PRG_02_Encoders.instHomingM1.State;
GVL_IHM.M1TreuilRetenue.State.HomingStateAtError      := PRG_02_Encoders.instHomingM1.StateAtError;
GVL_IHM.M1TreuilRetenue.State.HomingSuspect            := PRG_02_Encoders.instHomingM1.HomingSuspect;
GVL_IHM.M1TreuilRetenue.State.HomingRefRaw             := PRG_02_Encoders.instHomingM1.HomingRefRaw;
GVL_IHM.M1TreuilRetenue.Safety.SafeStop          := PRG_03_Safety.instSafetyWinchM1.SafeStop;
GVL_IHM.M1TreuilRetenue.Safety.ForbidDescent     := PRG_06_WinchControl.ForbidDescentM1_Active;
GVL_IHM.M1TreuilRetenue.Safety.ForbidAscent      := PRG_03_Safety.instSafetyWinchM1.ForbidAscent;
GVL_IHM.M1TreuilRetenue.Safety.SlackCable        := NOT PRG_00_Inputs.SlackCableSwitch;
GVL_IHM.M1TreuilRetenue.Safety.ThermalFault      := NOT PRG_00_Inputs.M1ThermalFeedback;
GVL_IHM.M1TreuilRetenue.Safety.EncoderFault      := NOT PRG_02_Encoders.instEncoderAbsM1.EncoderAvailable OR PRG_02_Encoders.instEncoderSafetyM1.EncoderIncoherent;
GVL_IHM.M1TreuilRetenue.Safety.BypassActive      := GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault
                                                     AND (PRG_04_Modes.instModes.Mode = E_Mode.MAINT_N2);
GVL_IHM.M1TreuilRetenue.Safety.CableLimitDescent := (PRG_03_Safety.instSafetyWinchM1.ErrorId AND 16#0040) <> 16#0000;
GVL_IHM.M1TreuilRetenue.Safety.CableLimitAscent  := PRG_06_WinchControl.CableLimitAscentM1Reached;
GVL_IHM.M1TreuilRetenue.State.ContactorsCheck          := PRG_06_WinchControl.instWinchM1.ContactorsCheck;
GVL_IHM.M1TreuilRetenue.State.BrakeContactorCheck      := PRG_06_WinchControl.instWinchM1.BrakeContactorCheck;

GVL_IHM.M1TreuilRetenue.State.Encoder.RawPos           := PRG_02_Encoders.instEncoderAbsM1.RawPos;
GVL_IHM.M1TreuilRetenue.State.Encoder.Alarms           := PRG_02_Encoders.instEncoderAbsM1.AlarmsIn;
GVL_IHM.M1TreuilRetenue.State.Encoder.Warnings         := PRG_02_Encoders.instEncoderAbsM1.WarningsIn;
GVL_IHM.M1TreuilRetenue.State.Encoder.SlaveOperational := PRG_02_Encoders.instEncoderAbsM1.SlaveOperational;
GVL_IHM.M1TreuilRetenue.State.Encoder.PresetTriggerCmd := PRG_02_Encoders.instEncoderAbsM1.PresetTriggerCmd;
GVL_IHM.M1TreuilRetenue.State.Encoder.PresetValueOut   := PRG_02_Encoders.instEncoderAbsM1.PresetValueOut;
GVL_IHM.M1TreuilRetenue.State.Encoder.Error            := PRG_02_Encoders.instEncoderAbsM1.Error;
GVL_IHM.M1TreuilRetenue.State.Encoder.ErrorId          := PRG_02_Encoders.instEncoderAbsM1.ErrorId;
GVL_IHM.M1TreuilRetenue.Safety.Error             := PRG_03_Safety.instSafetyWinchM1.Error;
GVL_IHM.M1TreuilRetenue.Safety.ErrorId           := PRG_03_Safety.instSafetyWinchM1.ErrorId;
GVL_IHM.M1TreuilRetenue.Safety.MecaADrift_M      := PRG_03_Safety.instSafetyWinchM1.MecaADriftM;
GVL_IHM.M1TreuilRetenue.Safety.MecaCDrift_M      := PRG_03_Safety.instSafetyWinchM1.MecaCDriftM;
GVL_IHM.M1TreuilRetenue.Safety.MecaBElapsedTime  := PRG_03_Safety.instSafetyWinchM1.MecaBElapsedTime;
GVL_IHM.M1TreuilRetenue.State.InhibitActive            := PRG_04_Modes.instModes.InhibitM1; // 🆕 REX 2026-07-08


// ── 6. MAPPING ÉTATS TREUIL M2 → IHM ─────────────────────────────────────
GVL_IHM.M2TreuilBenne.State.Position_M                 := PRG_02_Encoders.instEncoderScaleM2.CablePosM;
GVL_IHM.M2TreuilBenne.State.MeasuredSpeed_Mps          := PRG_03_Safety.instSafetyWinchM2.MeasuredSpeedMps;
GVL_IHM.M2TreuilBenne.State.SpeedDelta_Mps             := PRG_03_Safety.instSpeedMonitorM2.SpeedDeltaMps;
GVL_IHM.M2TreuilBenne.State.SpeedVariationDetected   := PRG_03_Safety.instSpeedMonitorM2.SpeedVariationDetected;
GVL_IHM.M2TreuilBenne.State.SpeedVariationConfirmed  := PRG_03_Safety.instSpeedMonitorM2.SpeedVariationConfirmed;
GVL_IHM.M2TreuilBenne.State.SpeedStable             := PRG_03_Safety.instSpeedMonitorM2.SpeedStable;
GVL_IHM.M2TreuilBenne.State.SpeedMonitorError        := PRG_03_Safety.instSpeedMonitorM2.Error;
GVL_IHM.M2TreuilBenne.State.SpeedMonitorErrorId      := PRG_03_Safety.instSpeedMonitorM2.ErrorId;
GVL_IHM.M2TreuilBenne.State.EstimatedLoadPct          := PRG_03_Safety.instLoadEstimatorM2.EstimatedLoadPct;
GVL_IHM.M2TreuilBenne.State.LoadEstimateConfigured   := PRG_03_Safety.instLoadEstimatorM2.Configured;
GVL_IHM.M2TreuilBenne.State.SpeedGuardLimited        := PRG_06_WinchControl.instWinchM2.SpeedGuardLimited;
GVL_IHM.M2TreuilBenne.State.SpeedRef_Pct               := PRG_06_WinchControl.instWinchM2.SpeedRamp.Current;
GVL_IHM.M2TreuilBenne.State.StepNumber               := PRG_06_WinchControl.instWinchM2.StepNumber;
GVL_IHM.M2TreuilBenne.State.FBState                  := PRG_06_WinchControl.instWinchM2.State;
GVL_IHM.M2TreuilBenne.State.Ready                    := PRG_06_WinchControl.instWinchM2.Ready;
GVL_IHM.M2TreuilBenne.State.Busy                     := PRG_06_WinchControl.instWinchM2.Busy;
GVL_IHM.M2TreuilBenne.State.Done                     := PRG_06_WinchControl.instWinchM2.Done;
GVL_IHM.M2TreuilBenne.State.Error                    := PRG_06_WinchControl.instWinchM2.Error;
GVL_IHM.M2TreuilBenne.State.ErrorId                  := PRG_06_WinchControl.instWinchM2.ErrorId;
GVL_IHM.M2TreuilBenne.State.RelayFwd                 := PRG_06_WinchControl.instWinchM2.RelayFwd;
GVL_IHM.M2TreuilBenne.State.RelayRev                 := PRG_06_WinchControl.instWinchM2.RelayRev;
GVL_IHM.M2TreuilBenne.State.Contactor1               := PRG_06_WinchControl.instWinchM2.Contactor1;
GVL_IHM.M2TreuilBenne.State.Contactor2               := PRG_06_WinchControl.instWinchM2.Contactor2;
GVL_IHM.M2TreuilBenne.State.Contactor3               := PRG_06_WinchControl.instWinchM2.Contactor3;
GVL_IHM.M2TreuilBenne.State.Contactor4               := PRG_06_WinchControl.instWinchM2.Contactor4;
GVL_IHM.M2TreuilBenne.State.BrakeCmd                 := PRG_06_WinchControl.instWinchM2.BrakeCmd;
GVL_IHM.M2TreuilBenne.State.Homed                    := PRG_02_Encoders.instHomingM2.Homed;
GVL_IHM.M2TreuilBenne.State.HomingBusy              := PRG_02_Encoders.instHomingM2.Busy;
GVL_IHM.M2TreuilBenne.State.HomingDone              := PRG_02_Encoders.instHomingM2.Done;
GVL_IHM.M2TreuilBenne.State.HomingError             := PRG_02_Encoders.instHomingM2.Error;
GVL_IHM.M2TreuilBenne.State.HomingErrorId           := PRG_02_Encoders.instHomingM2.ErrorId;
GVL_IHM.M2TreuilBenne.State.HomingState             := PRG_02_Encoders.instHomingM2.State;
GVL_IHM.M2TreuilBenne.State.HomingStateAtError      := PRG_02_Encoders.instHomingM2.StateAtError;
GVL_IHM.M2TreuilBenne.State.HomingSuspect            := PRG_02_Encoders.instHomingM2.HomingSuspect;
GVL_IHM.M2TreuilBenne.State.HomingRefRaw             := PRG_02_Encoders.instHomingM2.HomingRefRaw;
GVL_IHM.M2TreuilBenne.Safety.SafeStop          := PRG_03_Safety.instSafetyWinchM2.SafeStop;
GVL_IHM.M2TreuilBenne.Safety.ForbidDescent     := PRG_06_WinchControl.ForbidDescentM2_Active;
GVL_IHM.M2TreuilBenne.Safety.ForbidAscent      := PRG_03_Safety.instSafetyWinchM2.ForbidAscent;
GVL_IHM.M2TreuilBenne.Safety.SlackCable        := NOT PRG_00_Inputs.SlackCableSwitch;
GVL_IHM.M2TreuilBenne.Safety.ThermalFault      := NOT PRG_00_Inputs.M2ThermalFeedback;
GVL_IHM.M2TreuilBenne.Safety.EncoderFault      := NOT PRG_02_Encoders.instEncoderAbsM2.EncoderAvailable OR PRG_02_Encoders.instEncoderSafetyM2.EncoderIncoherent;
GVL_IHM.M2TreuilBenne.Safety.BypassActive      := GVL_IHM.M2TreuilBenne.Bypass.EncoderFault
                                                     AND (PRG_04_Modes.instModes.Mode = E_Mode.MAINT_N2);
GVL_IHM.M2TreuilBenne.Safety.CableLimitDescent := (PRG_03_Safety.instSafetyWinchM2.ErrorId AND 16#0040) <> 16#0000;
GVL_IHM.M2TreuilBenne.Safety.CableLimitAscent  := PRG_06_WinchControl.CableLimitAscentM2Reached;
GVL_IHM.M2TreuilBenne.State.ContactorsCheck          := PRG_06_WinchControl.instWinchM2.ContactorsCheck;
GVL_IHM.M2TreuilBenne.State.BrakeContactorCheck      := PRG_06_WinchControl.instWinchM2.BrakeContactorCheck;

GVL_IHM.M2TreuilBenne.State.Encoder.RawPos           := PRG_02_Encoders.instEncoderAbsM2.RawPos;
GVL_IHM.M2TreuilBenne.State.Encoder.Alarms           := PRG_02_Encoders.instEncoderAbsM2.AlarmsIn;
GVL_IHM.M2TreuilBenne.State.Encoder.Warnings         := PRG_02_Encoders.instEncoderAbsM2.WarningsIn;
GVL_IHM.M2TreuilBenne.State.Encoder.SlaveOperational := PRG_02_Encoders.instEncoderAbsM2.SlaveOperational;
GVL_IHM.M2TreuilBenne.State.Encoder.PresetTriggerCmd := PRG_02_Encoders.instEncoderAbsM2.PresetTriggerCmd;
GVL_IHM.M2TreuilBenne.State.Encoder.PresetValueOut   := PRG_02_Encoders.instEncoderAbsM2.PresetValueOut;
GVL_IHM.M2TreuilBenne.State.Encoder.Error            := PRG_02_Encoders.instEncoderAbsM2.Error;
GVL_IHM.M2TreuilBenne.State.Encoder.ErrorId          := PRG_02_Encoders.instEncoderAbsM2.ErrorId;
GVL_IHM.M2TreuilBenne.Safety.Error             := PRG_03_Safety.instSafetyWinchM2.Error;
GVL_IHM.M2TreuilBenne.Safety.ErrorId           := PRG_03_Safety.instSafetyWinchM2.ErrorId;
GVL_IHM.M2TreuilBenne.Safety.MecaADrift_M      := PRG_03_Safety.instSafetyWinchM2.MecaADriftM;
GVL_IHM.M2TreuilBenne.Safety.MecaCDrift_M      := PRG_03_Safety.instSafetyWinchM2.MecaCDriftM;
GVL_IHM.M2TreuilBenne.Safety.MecaBElapsedTime  := PRG_03_Safety.instSafetyWinchM2.MecaBElapsedTime;
GVL_IHM.M2TreuilBenne.State.InhibitActive            := PRG_04_Modes.instModes.InhibitM2; // 🆕 REX 2026-07-08


// ── 7. MAPPING ÉTATS BENNE → IHM ───────────────────────────────────────
GVL_IHM.M2Benne.FBState          := PRG_06_WinchControl.instBucket.State;
GVL_IHM.M2Benne.ActiveOffset_M     := PRG_06_WinchControl.instBucket.ActiveOffsetM;
GVL_IHM.M2Benne.M2StartStop      := PRG_06_WinchControl.instBucket.M2_StartStop;
GVL_IHM.M2Benne.M2Direction      := PRG_06_WinchControl.instBucket.M2_Direction;
GVL_IHM.M2Benne.M2ForceSlowSpeed := PRG_06_WinchControl.instBucket.M2_ForceSlowSpeed;
GVL_IHM.M2Benne.Ready            := PRG_06_WinchControl.instBucket.Ready;
GVL_IHM.M2Benne.Busy             := PRG_06_WinchControl.instBucket.Busy;
GVL_IHM.M2Benne.Done             := PRG_06_WinchControl.instBucket.Done;
GVL_IHM.M2Benne.Error            := PRG_06_WinchControl.instBucket.Error;
GVL_IHM.M2Benne.ErrorId          := PRG_06_WinchControl.instBucket.ErrorId;
GVL_IHM.M2Benne.RemainingTravel_M  := PRG_06_WinchControl.instBucket.RemainingTravelM;
GVL_IHM.M2Benne.CloseActive         := PRG_06_WinchControl.instBucket.CloseReq; // 🆕 REX 2026-07-08
GVL_IHM.M2Benne.OpenActive          := PRG_06_WinchControl.instBucket.OpenReq;  // 🆕 REX 2026-07-08
// 📊 REX 2026-07-07 : position M2 corrigée de l'offset actif — affichage bargraphe uniquement,
// doit être égale à GVL_IHM.M1TreuilRetenue.Position_M quand tout est nominal (voir bandeau ST_BucketHMI).
GVL_IHM.M2Benne.M2PositionCorrected := PRG_02_Encoders.instEncoderScaleM2.CablePosM - PRG_06_WinchControl.instBucket.ActiveOffsetM;
GVL_IHM.M2Benne.State            := _BucketState;


// ── 8. MAPPING ÉTATS SYNCHRONISATION → IHM ─────────────────────────────────
GVL_IHM.Sync.DeltaPos_M   := PRG_06_WinchControl.instWinchSync.DeltaPosM;
GVL_IHM.Sync.SyncActive := PRG_06_WinchControl.instWinchSync.SyncActive;
GVL_IHM.Sync.SyncWarn   := PRG_06_WinchControl.instWinchSync.SyncWarn;
GVL_IHM.Sync.Ready      := PRG_06_WinchControl.instWinchSync.Ready;
GVL_IHM.Sync.Error      := PRG_06_WinchControl.instWinchSync.Error;
GVL_IHM.Sync.ErrorId    := PRG_06_WinchControl.instWinchSync.ErrorId;
GVL_IHM.Sync.State      := PRG_06_WinchControl.instWinchSync.State;


// ── 9. MAPPING ÉTATS TRANSLATION M3 → IHM ────────────────────────────────────
GVL_IHM.TranslationM3.State.FBState              := PRG_07_TranslationControl.instTranslationM3.State;
GVL_IHM.TranslationM3.State.Ready                := PRG_07_TranslationControl.instTranslationM3.Ready;
GVL_IHM.TranslationM3.State.Busy                 := PRG_07_TranslationControl.instTranslationM3.Busy;
GVL_IHM.TranslationM3.State.Done                 := PRG_07_TranslationControl.instTranslationM3.Done;
GVL_IHM.TranslationM3.State.Error                := PRG_07_TranslationControl.instTranslationM3.Error;
GVL_IHM.TranslationM3.State.ErrorId              := PRG_07_TranslationControl.instTranslationM3.ErrorId;
GVL_IHM.TranslationM3.State.BrakeCmd             := PRG_07_TranslationControl.instTranslationM3.BrakeCmd;
GVL_IHM.TranslationM3.State.BrakeFeedback        := PRG_00_Inputs.M3BrakeFeedback;
GVL_IHM.TranslationM3.State.PositionSensorTarget := PRG_07_TranslationControl.M3_PositionSensorTarget;
GVL_IHM.TranslationM3.State.PositionReached      := PRG_07_TranslationControl.M3_PositioningActive
                                                AND PRG_07_TranslationControl.instTranslationM3.TargetReached;
GVL_IHM.TranslationM3.State.JoystickDeflection_Pct := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.SpeedRef;
// 🧭 Position validée IHM : masquée (forcée à FALSE) si le mot capteurs est incohérent (position indéterminée)
IF PRG_00_Inputs.instPositionDecoder.Incoherent THEN
    GVL_IHM.TranslationM3.State.PositionTremie      := FALSE;
    GVL_IHM.TranslationM3.State.PositionPV          := FALSE;
    GVL_IHM.TranslationM3.State.PositionP2          := FALSE;
    GVL_IHM.TranslationM3.State.PositionP1          := FALSE;
    GVL_IHM.TranslationM3.State.PositionMaintenance := FALSE;
ELSE
    GVL_IHM.TranslationM3.State.PositionTremie      := PRG_00_Inputs.TranslationPosTremie;
    GVL_IHM.TranslationM3.State.PositionPV          := PRG_00_Inputs.TranslationPosPV;
    GVL_IHM.TranslationM3.State.PositionP2          := PRG_00_Inputs.TranslationPosP2;
    GVL_IHM.TranslationM3.State.PositionP1          := PRG_00_Inputs.TranslationPosP1;
    GVL_IHM.TranslationM3.State.PositionMaintenance := PRG_00_Inputs.TranslationPosMaintenance;
END_IF;
GVL_IHM.TranslationM3.State.SensorsWord         := PRG_00_Inputs.instPositionDecoder.SensorsWord;
GVL_IHM.TranslationM3.State.SensorWordIncoherent:= PRG_00_Inputs.instPositionDecoder.Incoherent;
GVL_IHM.TranslationM3.State.LimitSwitchFwd     := PRG_00_Inputs.instPositionDecoder.LimitSwitchFwd;
GVL_IHM.TranslationM3.State.LimitSwitchRev     := PRG_00_Inputs.instPositionDecoder.LimitSwitchRev;
GVL_IHM.TranslationM3.State.MaintenanceTargetEnable := PRG_04_Modes.instModes.MaintenanceM3TargetEnable;
GVL_IHM.TranslationM3.State.SimulationModeActive := GVL_Simulation.SimulationModeActive;

GVL_IHM.TranslationM3.Safety.Error             := PRG_03_Safety.instSafetyTranslationM3.Error;
GVL_IHM.TranslationM3.Safety.ErrorId           := PRG_03_Safety.instSafetyTranslationM3.ErrorId;
GVL_IHM.TranslationM3.Safety.ErrorOperatorComm := PRG_03_Safety.instSafetyTranslationM3.ErrorOperatorComm;
GVL_IHM.TranslationM3.Safety.ErrorDriveComm      := PRG_03_Safety.instSafetyTranslationM3.ErrorDriveComm;
GVL_IHM.TranslationM3.Safety.ErrorPhaseRotation  := PRG_03_Safety.instSafetyTranslationM3.ErrorPhaseRotation;
GVL_IHM.TranslationM3.Safety.ErrorBrakeThermal   := PRG_03_Safety.instSafetyTranslationM3.ErrorBrakeThermal;
GVL_IHM.TranslationM3.Safety.ErrorMecaB          := PRG_03_Safety.instSafetyTranslationM3.ErrorMecaB;
GVL_IHM.TranslationM3.Safety.ErrorMecaA          := PRG_03_Safety.instSafetyTranslationM3.ErrorMecaA;
GVL_IHM.TranslationM3.Safety.ErrorLimitSwitch    := PRG_03_Safety.instSafetyTranslationM3.ErrorLimitSwitch;
GVL_IHM.TranslationM3.Safety.ErrorSensorIncoherent:= PRG_03_Safety.instSafetyTranslationM3.ErrorSensorIncoherent;
GVL_IHM.TranslationM3.Safety.SafeStop          := PRG_03_Safety.instSafetyTranslationM3.SafeStop;
GVL_IHM.TranslationM3.Safety.PowerCutOff       := PRG_03_Safety.instSafetyTranslationM3.PowerCutOff;
// 🔧 Diag variateur décodé (pas de bit-masking côté IHM) — StatusWord bit7=CommReady, bit0=PowerReady
GVL_IHM.TranslationM3.State.DriveCommReady       := PRG_00_Inputs.M3_StatusWord_Filtered.7 OR GVL_Simulation.SimulationModeActive;
GVL_IHM.TranslationM3.State.DrivePowerReady      := PRG_00_Inputs.M3_StatusWord_Filtered.0 OR GVL_Simulation.SimulationModeActive;
// 🔧 Source unique (PRG_00_Inputs), valable Auto ET Manu — remplace l'ex-doublon IHM_MANU.M3_FreqActual
GVL_IHM.TranslationM3.State.DriveActualFreq_Hz     := UINT_TO_REAL(PRG_00_Inputs.M3_ActualFrequencyHz_Filtered) / 100.0;
GVL_IHM.TranslationM3.State.DriveFreqRef_Hz        := PRG_07_TranslationControl.instTranslationM3.DriveFreqRefHz;
GVL_IHM.TranslationM3.State.ActiveDirection      := PRG_07_TranslationControl.M3_Direction_Active;
GVL_IHM.TranslationM3.State.ActiveSpeedRef_Pct     := PRG_07_TranslationControl.M3_SpeedRef_Active;

// ── 9bis. MAPPING CYCLE SEMI-AUTOMATIQUE → IHM ──────────────────────────────
GVL_IHM.Cycle.Ready                := PRG_05_Cycle.instCycle.Ready;
GVL_IHM.Cycle.Busy                 := PRG_05_Cycle.instCycle.Busy;
GVL_IHM.Cycle.Done                 := PRG_05_Cycle.instCycle.Done;
GVL_IHM.Cycle.Error                := PRG_05_Cycle.instCycle.Error;
GVL_IHM.Cycle.ErrorId              := PRG_05_Cycle.instCycle.ErrorId;
GVL_IHM.Cycle.CycleStep            := PRG_05_Cycle.instCycle.CycleStep;
GVL_IHM.Cycle.CycleStateStr        := PRG_05_Cycle.instCycle.CycleStateStr;
GVL_IHM.Cycle.SelTarget    := GVL_IHM.TranslationM3.Cmd.SelTarget;
GVL_IHM.Cycle.KoboldContactFond    := PRG_00_Inputs.KoboldContactFond;
GVL_IHM.Cycle.KoboldContactorCmd   := PRG_05_Cycle.instCycle.KoboldContactorCmd;
GVL_IHM.Cycle.LimitLegalReached    := GVL_IHM.Commun.LimitLegalReached;
GVL_IHM.Cycle.LimitLegalDepth_M      := GVL_IHM.Commun.LimitLegalDepthMinAllowed_M;
GVL_IHM.Cycle.WinchSyncError       := PRG_06_WinchControl.instWinchSync.Error;
GVL_IHM.Cycle.WinchSyncDelta_M       := PRG_06_WinchControl.instWinchSync.DeltaPosM;
GVL_IHM.Cycle.M1Position_M           := PRG_02_Encoders.instEncoderScaleM1.CablePosM;
GVL_IHM.Cycle.M2Position_M           := PRG_02_Encoders.instEncoderScaleM2.CablePosM;
GVL_IHM.Cycle.DeadmanArmed         := PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed;
GVL_IHM.Cycle.JoystickMotionActive := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop;
GVL_IHM.Cycle.MotionPermit         := PRG_05_Cycle.CycleMotionPermit;


// ── 10. MAPPING ÉTATS JOYSTICK → IHM ─────────────────────────────────────
GVL_IHM.JOY1Joystick.RawX       := PRG_01_Diagnostics.FB_Joystick_0.RawX;
GVL_IHM.JOY1Joystick.RawY       := PRG_01_Diagnostics.FB_Joystick_0.RawY;
GVL_IHM.JOY1Joystick.RawButton  := PRG_01_Diagnostics.FB_Joystick_0.RawButton;
GVL_IHM.JOY1Joystick.AxisCmdX        := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX;
GVL_IHM.JOY1Joystick.AxisCmdY        := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY;
GVL_IHM.JOY1Joystick.NeutralXAct := PRG_01_Diagnostics.FB_Joystick_0.NeutralXAct;
GVL_IHM.JOY1Joystick.NeutralYAct := PRG_01_Diagnostics.FB_Joystick_0.NeutralYAct;
GVL_IHM.JOY1Joystick.DeadmanArmed := PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed;
GVL_IHM.JOY1Joystick.Online     := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Online;
GVL_IHM.JOY1Joystick.Operational := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Operational;
GVL_IHM.JOY1Joystick.Error       := PRG_01_Diagnostics.FB_Joystick_0.Error;
GVL_IHM.JOY1Joystick.ErrorId     := PRG_01_Diagnostics.FB_Joystick_0.ErrorId;


// ── 11. MAPPING SYSTEM / MODE → IHM ──────────────────────────────────────
GVL_IHM.Modes.CurrentMode     := PRG_04_Modes.instModes.Mode;
GVL_IHM.Modes.EmergencyStopOk := PRG_00_Inputs.EmergencyStopOk;


// ── 12. MAPPING DIAGNOSTICS BUS → IHM ────────────────────────────────────
GVL_IHM.Network.BusCanOpen  := PRG_01_Diagnostics.instDiagCanOpen.DeviceCanOpenMaster;
GVL_IHM.Network.Joystick    := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick;
GVL_IHM.Network.CanError    := PRG_01_Diagnostics.instDiagCanOpen.Error;
GVL_IHM.Network.CanErrorId  := PRG_01_Diagnostics.instDiagCanOpen.ErrorId;

GVL_IHM.Network.BusEthercat := PRG_01_Diagnostics.instDiagEthercat.DeviceEthercatMaster;
GVL_IHM.Network.EncoderM1   := PRG_01_Diagnostics.instDiagEthercat.DeviceEncoderM1;
GVL_IHM.Network.EncoderM2   := PRG_01_Diagnostics.instDiagEthercat.DeviceEncoderM2;
GVL_IHM.Network.VariateurM3 := PRG_01_Diagnostics.instDiagEthercat.DeviceVariateur;
GVL_IHM.Network.EcatError   := PRG_01_Diagnostics.instDiagEthercat.Error;
GVL_IHM.Network.EcatErrorId := PRG_01_Diagnostics.instDiagEthercat.ErrorId;
