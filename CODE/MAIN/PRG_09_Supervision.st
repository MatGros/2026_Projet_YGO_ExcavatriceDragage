(* ═══════════════════════════════════════════════════════════════
   🖥️ PRG_09_Supervision — Échanges IHM, Stubs et Initialisation Boot
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 9.
   ✅ Regroupe tout le mapping bidirectionnel GVL_IHM / GVL_PERSISTENT.
   ✅ Expose FaultMachineReset_IHM pour tous les programmes du domaine sécurité/métier.
   🔧 REX 2026-07-07 : séparation des resets — l'ancien MachineReset_IHM (unique, câblé sur
      TOUT y compris FB_Modes/FB_Cycle) est retiré. FaultMachineReset_IHM ne couvre plus que le
      domaine sécurité/métier (Winch, Safety, Encodeurs, Benne, Joystick, Translation) ;
      FB_Modes/FB_Cycle ont chacun leur propre Reset dédié (GVL_IHM.Modes.Cmd.BtnModeReset côté
      PRG_04_Modes, CmdResetCycle_IHM côté PRG_05_Cycle) — jamais mélangés.
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-07_Interface_IHM_v1.7.md
*)

PROGRAM PRG_09_Supervision
VAR_OUTPUT
    FaultMachineReset_IHM : BOOL; // 🔔 Acquittement défauts domaine sécurité/métier (OR des boutons HMI) — jamais Modes/Cycle
END_VAR
VAR
    instBlink1Hz : BLINK; // 🧩 Réutilisation lib Util (Partie3 §0) — horloge clignotement système
    instAckConfigRestored : R_TRIG; // 🔔 Front acquittement opérateur restauration config PERSISTENT (§2bis)
    instCfgPersistBridgeSync : FB_CfgPersistBridge_SyncCfg; // 🌉 Pont persistance M1M2Sync.Cfg (Lot 3a, pilote)
    instCfgPersistBridgeCycle : FB_CfgPersistBridge_CycleCfg; // 🌉 Pont persistance Cycle.Cfg (Lot 3b)
    instCfgPersistBridgeCommun : FB_CfgPersistBridge_CommunCfg; // 🌉 Pont persistance Commun.Cfg (Lot 3b)
    instCfgPersistBridgeBucket : FB_CfgPersistBridge_BucketCfg; // 🌉 Pont persistance M2TreuilBenne.Bucket.Cfg (Lot 3b)
    instCfgPersistBridgeWinchM1 : FB_CfgPersistBridge_WinchCfg; // 🌉 Pont persistance M1TreuilRetenue.Cfg (Lot 3d-2)
    instCfgPersistBridgeWinchM2 : FB_CfgPersistBridge_WinchCfg; // 🌉 Pont persistance M2TreuilBenne.Cfg (Lot 3d-2)
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
GVL_Modes_Stub.ModeRequest_IHM         := GVL_IHM.Modes.Cmd.SelMode;
GVL_Modes_Stub.SyncEnableRequest_IHM   := GVL_IHM.M1M2Sync.Cmd.SelSyncEnable; // 🔧 REX 2026-07-08 : renommé, polarité inversée
StubTranslationPositionSelect_IHM          := GVL_IHM.TranslationM3.Cmd.SelTarget;

// Signal d'acquittement défauts domaine sécurité/métier — JAMAIS Modes/Cycle (REX 2026-07-07)
FaultMachineReset_IHM := GVL_IHM.Modes.Cmd.BtnFaultReset
                    OR GVL_IHM.M1TreuilRetenue.Cmd.BtnReset
                    OR GVL_IHM.M2TreuilBenne.Cmd.BtnReset
                    OR GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset;

// 🔴 REX 2026-07-07 : au moins un défaut actif dans le domaine couvert par FaultMachineReset_IHM
// (même périmètre exact que les 17 blocs alimentés par ce reset — voir bandeau en tête de fichier).
// Sert à savoir, côté IHM, quand un appui sur BtnFaultReset est utile/attendu.
GVL_IHM.Modes.State.AnyFaultActive :=
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
GVL_IHM.Modes.State.PowerCutOffActive := PRG_03_Safety.instSafetyWinchM1.PowerCutOff
                                 OR PRG_03_Safety.instSafetyWinchM2.PowerCutOff
                                 OR PRG_03_Safety.instSafetyTranslationM3.PowerCutOff
                                 OR GVL_IHM.Modes.Cmd.BtnEmergencyCutOff;

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
GVL_IHM.Modes.State.EmergencyChainOk    := PRG_00_Inputs.EmergencyChain;
GVL_IHM.Modes.State.PowerContactorOk    := PRG_00_Inputs.EmergencyStopOk;
GVL_IHM.Modes.State.EmergencyArmingBusy := (PRG_10_Outputs.ArmingSeqStep <> 0) OR PRG_10_Outputs.EmergencyArmingLockoutActive;
GVL_IHM.Modes.State.EmergencyArmable    := PRG_00_Inputs.EmergencyChain
                                    AND (PRG_10_Outputs.ArmingSeqStep = 0)
                                    AND NOT PRG_10_Outputs.EmergencyArmingLockoutActive
                                    AND NOT PRG_10_Outputs.RedundancyTestFailed;
GVL_IHM.Modes.State.RedundancyTestFailed := PRG_10_Outputs.RedundancyTestFailed;
GVL_IHM.Modes.State.EmergencyArmingFailed := PRG_10_Outputs.EmergencyArmingFailed;

// 🔧 REX 2026-07-07 : ancien pont IF/ELSIF vers GVL_Encoder_Stub supprimé (bugué — ne pouvait
// homer qu'un seul treuil à la fois). GVL_IHM.M1TreuilRetenue/M2.BtnHome sont désormais câblés
// directement dans PRG_02_Encoders.st (instHomingM1/M2.Home) — homing simultané possible.

// ℹ️ BtnCalibrate joystick : lu directement depuis GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate dans PRG_01_Diagnostics (ligne 48)


// ── 2. INITIALISATION IHM DEPUIS GVL_PERSISTENT (Boot) ───────────────────
// 🐛 FIX 2026-07-23 : sentinelles `= 0.0` remplacées par un flag `Initialized`/`CfgInitialized`
// dédié (défaut FALSE non ambigu). L'ancienne sentinelle `CfgTopSensorPos_M = 0.0` ne se
// déclenchait JAMAIS (défaut struct réel = 8.5, ST_WinchCfg.st) → ce bloc M1/M2 ne s'exécutait
// plus après un reset RETAIN (ex. changement de struct ST_*HMI, comme lors de cette session) et
// TOUTE la config (paliers, rampes, limites câble, synchro...) retombait au défaut struct brut
// sans jamais se resynchroniser depuis le vrai PERSISTENT. Idem pour `Sync.CfgSyncTolerance_M`
// (défaut réel 0.25, piège documenté REX 2026-07-08 (5) ci-dessous, désormais clos).
// 📄 Voir DOC/AF_Partie-07_Interface_IHM_v1.8.md.
instCfgPersistBridgeWinchM1(Hmi := GVL_IHM.M1TreuilRetenue.Cfg, Persist := _WinchM1CfgPersist);
IF instCfgPersistBridgeWinchM1.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeWinchM2(Hmi := GVL_IHM.M2TreuilBenne.Cfg, Persist := _WinchM2CfgPersist);
IF instCfgPersistBridgeWinchM2.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeSync(Hmi := GVL_IHM.M1M2Sync.Cfg, Persist := _SyncCfgPersist);
IF instCfgPersistBridgeSync.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeBucket(Hmi := GVL_IHM.M2TreuilBenne.Bucket.Cfg, Persist := _BucketCfgPersist);
IF instCfgPersistBridgeBucket.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeCommun(Hmi := GVL_IHM.Commun.Cfg, Persist := _CommunCfgPersist);
IF instCfgPersistBridgeCommun.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeCycle(Hmi := GVL_IHM.Cycle.Cfg, Persist := _CycleCfgPersist);
IF instCfgPersistBridgeCycle.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

// 🎯 Translation M3 : persistance ciblée du seul réglage SetFreq_Hz.
// Aucun pont struct complet : BtnFwd/BtnRev restent impérativement non persistants.
IF NOT GVL_IHM.TranslationM3.Cmd.Initialized THEN
    GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := _TranslationSetFreq_Hz;
    GVL_IHM.TranslationM3.Cmd.Initialized := TRUE;
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

// ── 2bis. ACQUITTEMENT RESTAURATION CONFIG (front, doctrine reset=front) ───
// 🐛 FIX 2026-07-23 : `ConfigRestoredFromPersistent` ne doit JAMAIS disparaître tout seul —
// même doctrine que les défauts métier (cause disparue + appui reset conscient pour effacer).
// Tant que l'opérateur n'a pas vérifié/acquitté, le bit reste visible à l'IHM.
instAckConfigRestored(CLK := GVL_IHM.Commun.BtnAckConfigRestored);
IF instAckConfigRestored.Q THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := FALSE;
END_IF;

// 🌐 Restauration des bypass RETAIN au boot UNIQUEMENT — co-localisation flag Initialized
// Après ça, seule la sauvegarde IHM→RETAIN fonctionne (jamais l'inverse).
// Évite le bug où une écriture IHM était écrasée par la restauration.
IF NOT GVL_IHM.TranslationM3.Bypass.Initialized THEN
    IF BypassTranslationGlobal THEN
        GVL_IHM.TranslationM3.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.TranslationM3.Bypass.Initialized := TRUE;
END_IF;

IF NOT GVL_IHM.M1TreuilRetenue.Bypass.Initialized THEN
    IF BypassWinchM1Global THEN
        GVL_IHM.M1TreuilRetenue.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.M1TreuilRetenue.Bypass.Initialized := TRUE;
END_IF;

IF NOT GVL_IHM.M2TreuilBenne.Bypass.Initialized THEN
    IF BypassWinchM2Global THEN
        GVL_IHM.M2TreuilBenne.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.M2TreuilBenne.Bypass.Initialized := TRUE;
END_IF;

IF NOT GVL_IHM.Network.Bypass.Initialized THEN
    IF BypassNetworkGlobal THEN
        GVL_IHM.Network.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.Network.Bypass.Initialized := TRUE;
END_IF;

IF NOT GVL_IHM.M1M2Sync.Bypass.Initialized THEN
    IF BypassSyncGlobal THEN
        GVL_IHM.M1M2Sync.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.M1M2Sync.Bypass.Initialized := TRUE;
END_IF;

IF NOT GVL_IHM.M2TreuilBenne.Bucket.Bypass.Initialized THEN
    IF BypassBucketGlobal THEN
        GVL_IHM.M2TreuilBenne.Bucket.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.M2TreuilBenne.Bucket.Bypass.Initialized := TRUE;
END_IF;


// ── 3. PROPAGATION DES RÉGLAGES IHM → PERSISTANCE ───────────────────────
// 🐛 FIX 2026-07-23 : chaque bloc ci-dessous est désormais gardé par le flag `Cfg.Initialized`/
// `Sync.CfgInitialized` posé en §2 — défense en profondeur : même si l'ordre du fichier changeait
// un jour, on ne peut plus écraser le vrai PERSISTENT avec une valeur GVL_IHM fraîchement
// resettée au défaut struct AVANT que la restauration (§2) ait eu lieu. Revue sécurité 2026-07-23.
// 🌐 Sauvegarde des bypass RETAIN (survit au warm restart / download)
BypassTranslationGlobal     := GVL_IHM.TranslationM3.Bypass.Global;
BypassWinchM1Global         := GVL_IHM.M1TreuilRetenue.Bypass.Global;
BypassWinchM2Global         := GVL_IHM.M2TreuilBenne.Bypass.Global;
BypassSyncGlobal            := GVL_IHM.M1M2Sync.Bypass.Global;
BypassNetworkGlobal         := GVL_IHM.Network.Bypass.Global;
BypassBucketGlobal          := GVL_IHM.M2TreuilBenne.Bucket.Bypass.Global;

// 🎯 Sauvegarde ciblée Translation M3 : uniquement SetFreq_Hz, jamais les commandes IHM.
IF GVL_IHM.TranslationM3.Cmd.Initialized THEN
    _TranslationSetFreq_Hz := GVL_IHM.TranslationM3.Cmd.SetFreq_Hz;
END_IF;

// 🔧 REX 2026-07-07 : plus de garde Mode=SEMI_AUTO, cohérent avec PRG_06_WinchControl.st §5
// (la limite légale s'applique désormais dans tous les modes dès qu'elle est activée).
GVL_IHM.Commun.LimitLegalReached         := _CommunCfgPersist.LimitLegalEnabled
                                            AND ((NOT PRG_04_Modes.instModes.InhibitM1 AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M))
                                                 OR (NOT PRG_04_Modes.instModes.InhibitM2 AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M)));

GVL_IHM.Commun.TopPositionSensorActive   := NOT PRG_00_Inputs.TopPositionSensor;


// ── 4. BYPASS DE SIMULATION POUR L'IHM (état effectif par device, voir DOC/AF_Partie-13_Fonction_Simulation_v1.4.md) ──────
// 🔧 REX (session Bypass) : structs Bypass dedies par metier (voir REGISTRE_ACTIONS_Bypass_v1.0 (archive))
// — ContactorFeedback reste par axe (materiel propre a chaque treuil/translation), SlackCable et
// TopPositionSensor passent dans Commun.Bypass (capteur physique UNIQUE partage M1/M2, plus de duplication).
GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback := FALSE;
GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback := FALSE;
GVL_IHM.TranslationM3.Bypass.ContactorFeedback := FALSE;
GVL_IHM.Commun.Bypass.SlackCable        := FALSE;
GVL_IHM.Commun.Bypass.TopPositionSensor := FALSE;


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
GVL_IHM.M1TreuilRetenue.Safety.EncoderFault      := (NOT PRG_02_Encoders.instEncoderAbsM1.EncoderAvailable OR PRG_02_Encoders.instEncoderSafetyM1.EncoderIncoherent)
                                                    AND NOT GVL_IHM.M1TreuilRetenue.Bypass.Global
                                                    AND NOT GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault;
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
GVL_IHM.M2TreuilBenne.Safety.EncoderFault      := (NOT PRG_02_Encoders.instEncoderAbsM2.EncoderAvailable OR PRG_02_Encoders.instEncoderSafetyM2.EncoderIncoherent)
                                                  AND NOT GVL_IHM.M2TreuilBenne.Bypass.Global
                                                  AND NOT GVL_IHM.M2TreuilBenne.Bypass.EncoderFault;
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
GVL_IHM.M2TreuilBenne.Bucket.State.FBState          := PRG_06_WinchControl.instBucket.State;
GVL_IHM.M2TreuilBenne.Bucket.State.ActiveOffset_M   := PRG_06_WinchControl.instBucket.ActiveOffsetM;
GVL_IHM.M2TreuilBenne.Bucket.State.M2StartStop      := PRG_06_WinchControl.instBucket.M2_StartStop;
GVL_IHM.M2TreuilBenne.Bucket.State.M2Direction      := PRG_06_WinchControl.instBucket.M2_Direction;
GVL_IHM.M2TreuilBenne.Bucket.State.M2ForceSlowSpeed := PRG_06_WinchControl.instBucket.M2_ForceSlowSpeed;
GVL_IHM.M2TreuilBenne.Bucket.State.Ready            := PRG_06_WinchControl.instBucket.Ready;
GVL_IHM.M2TreuilBenne.Bucket.State.Busy             := PRG_06_WinchControl.instBucket.Busy;
GVL_IHM.M2TreuilBenne.Bucket.State.Done             := PRG_06_WinchControl.instBucket.Done;
GVL_IHM.M2TreuilBenne.Bucket.State.Error            := PRG_06_WinchControl.instBucket.Error;
GVL_IHM.M2TreuilBenne.Bucket.State.ErrorId          := PRG_06_WinchControl.instBucket.ErrorId;
GVL_IHM.M2TreuilBenne.Bucket.State.RemainingTravel_M:= PRG_06_WinchControl.instBucket.RemainingTravelM;
GVL_IHM.M2TreuilBenne.Bucket.State.CloseActive      := PRG_06_WinchControl.instBucket.CloseReq; // 🆕 REX 2026-07-08
GVL_IHM.M2TreuilBenne.Bucket.State.OpenActive       := PRG_06_WinchControl.instBucket.OpenReq;  // 🆕 REX 2026-07-08
// 📊 REX 2026-07-07 : position M2 corrigée de l'offset actif — affichage bargraphe uniquement,
// doit être égale à GVL_IHM.M1TreuilRetenue.Position_M quand tout est nominal (voir bandeau ST_BucketHMI).
GVL_IHM.M2TreuilBenne.Bucket.State.M2PositionCorrected := PRG_02_Encoders.instEncoderScaleM2.CablePosM - PRG_06_WinchControl.instBucket.ActiveOffsetM;
GVL_IHM.M2TreuilBenne.Bucket.State.MechState        := _BucketState;


// ── 8. MAPPING ÉTATS SYNCHRONISATION → IHM ─────────────────────────────────
GVL_IHM.M1M2Sync.State.DeltaPos_M   := PRG_06_WinchControl.instWinchSync.DeltaPosM;
GVL_IHM.M1M2Sync.State.SyncActive := PRG_06_WinchControl.instWinchSync.SyncActive;
GVL_IHM.M1M2Sync.State.SyncWarn   := PRG_06_WinchControl.instWinchSync.SyncWarn;
GVL_IHM.M1M2Sync.State.Ready      := PRG_06_WinchControl.instWinchSync.Ready;
GVL_IHM.M1M2Sync.State.Error      := PRG_06_WinchControl.instWinchSync.Error;
GVL_IHM.M1M2Sync.State.ErrorId    := PRG_06_WinchControl.instWinchSync.ErrorId;
GVL_IHM.M1M2Sync.State.FBState    := PRG_06_WinchControl.instWinchSync.State;


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
GVL_IHM.TranslationM3.State.DriveCommReady       := PRG_00_Inputs.M3_StatusWord_Filtered.7;
GVL_IHM.TranslationM3.State.DrivePowerReady      := PRG_00_Inputs.M3_StatusWord_Filtered.0;
// 🔧 Source unique (PRG_00_Inputs), valable Auto ET Manu — remplace l'ex-doublon IHM_MANU.M3_FreqActual
GVL_IHM.TranslationM3.State.DriveActualFreq_Hz     := UINT_TO_REAL(PRG_00_Inputs.M3_ActualFrequencyHz_Filtered) / 100.0;
GVL_IHM.TranslationM3.State.DriveFreqRef_Hz        := PRG_07_TranslationControl.instTranslationM3.DriveFreqRefHz;
GVL_IHM.TranslationM3.State.ActiveDirection      := PRG_07_TranslationControl.M3_Direction_Active;
GVL_IHM.TranslationM3.State.ActiveSpeedRef_Pct     := PRG_07_TranslationControl.M3_SpeedRef_Active;

// ── 9bis. MAPPING CYCLE SEMI-AUTOMATIQUE → IHM ──────────────────────────────
GVL_IHM.Cycle.State.Ready                := PRG_05_Cycle.instCycle.Ready;
GVL_IHM.Cycle.State.Busy                 := PRG_05_Cycle.instCycle.Busy;
GVL_IHM.Cycle.State.Done                 := PRG_05_Cycle.instCycle.Done;
GVL_IHM.Cycle.State.Error                := PRG_05_Cycle.instCycle.Error;
GVL_IHM.Cycle.State.ErrorId              := PRG_05_Cycle.instCycle.ErrorId;
GVL_IHM.Cycle.State.CycleStep            := PRG_05_Cycle.instCycle.CycleStep;
GVL_IHM.Cycle.State.CycleStateStr        := PRG_05_Cycle.instCycle.CycleStateStr;
GVL_IHM.Cycle.State.SelTarget            := GVL_IHM.TranslationM3.Cmd.SelTarget;
GVL_IHM.Cycle.State.KoboldContactFond    := PRG_00_Inputs.KoboldContactFond;
GVL_IHM.Cycle.State.KoboldContactorCmd   := PRG_05_Cycle.instCycle.KoboldContactorCmd;
GVL_IHM.Cycle.State.LimitLegalReached    := GVL_IHM.Commun.LimitLegalReached;
GVL_IHM.Cycle.State.LimitLegalDepth_M    := GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M;
GVL_IHM.Cycle.State.WinchSyncError       := PRG_06_WinchControl.instWinchSync.Error;
GVL_IHM.Cycle.State.WinchSyncDelta_M     := PRG_06_WinchControl.instWinchSync.DeltaPosM;
GVL_IHM.Cycle.State.M1Position_M         := PRG_02_Encoders.instEncoderScaleM1.CablePosM;
GVL_IHM.Cycle.State.M2Position_M         := PRG_02_Encoders.instEncoderScaleM2.CablePosM;
GVL_IHM.Cycle.State.DeadmanArmed         := PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed;
GVL_IHM.Cycle.State.JoystickMotionActive := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop;
GVL_IHM.Cycle.State.MotionPermit         := PRG_05_Cycle.CycleMotionPermit;


// ── 10. MAPPING ÉTATS JOYSTICK → IHM ─────────────────────────────────────
GVL_IHM.JOY1Joystick.State.RawX         := PRG_01_Diagnostics.FB_Joystick_0.RawX;
GVL_IHM.JOY1Joystick.State.RawY         := PRG_01_Diagnostics.FB_Joystick_0.RawY;
GVL_IHM.JOY1Joystick.State.RawButton    := PRG_01_Diagnostics.FB_Joystick_0.RawButton;
GVL_IHM.JOY1Joystick.State.AxisCmdX     := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX;
GVL_IHM.JOY1Joystick.State.AxisCmdY     := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY;
GVL_IHM.JOY1Joystick.State.NeutralXAct  := PRG_01_Diagnostics.FB_Joystick_0.NeutralXAct;
GVL_IHM.JOY1Joystick.State.NeutralYAct  := PRG_01_Diagnostics.FB_Joystick_0.NeutralYAct;
GVL_IHM.JOY1Joystick.State.DeadmanArmed := PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed;
GVL_IHM.JOY1Joystick.State.Online       := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Online;
GVL_IHM.JOY1Joystick.State.Operational  := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Operational;
GVL_IHM.JOY1Joystick.State.Error        := PRG_01_Diagnostics.FB_Joystick_0.Error;
GVL_IHM.JOY1Joystick.State.ErrorId      := PRG_01_Diagnostics.FB_Joystick_0.ErrorId;


// ── 11. MAPPING SYSTEM / MODE → IHM ──────────────────────────────────────
GVL_IHM.Modes.State.CurrentMode     := PRG_04_Modes.instModes.Mode;
GVL_IHM.Modes.State.EmergencyStopOk := PRG_00_Inputs.EmergencyStopOk;


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
