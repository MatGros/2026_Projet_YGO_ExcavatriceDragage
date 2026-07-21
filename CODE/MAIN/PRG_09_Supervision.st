(* ═══════════════════════════════════════════════════════════════
   🖥️ PRG_09_Supervision — Échanges IHM, Stubs et Initialisation Boot
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 9.
   ✅ Regroupe tout le mapping bidirectionnel GVL_IHM / GVL_PERSISTENT.
   ✅ Expose FaultMachineReset_IHM pour tous les programmes du domaine sécurité/métier.
   🔧 REX 2026-07-07 : séparation des resets — l'ancien MachineReset_IHM (unique, câblé sur
      TOUT y compris FB_Modes/FB_Cycle) est retiré. FaultMachineReset_IHM ne couvre plus que le
      domaine sécurité/métier (Winch, Safety, Encodeurs, Benne, Joystick, Translation) ;
      FB_Modes/FB_Cycle ont chacun leur propre Reset dédié (GVL_IHM.Modes.ModeReset côté
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
GVL_Modes_Stub.ModeRequest_IHM         := GVL_IHM.Modes.ModeRequest;
GVL_Modes_Stub.SyncEnableRequest_IHM   := GVL_IHM.Sync.SyncEnableRequest; // 🔧 REX 2026-07-08 : renommé, polarité inversée
StubTranslationPositionSelect_IHM          := GVL_IHM.TranslationM3.SelectedTargetNum;

// 🧪 Commandes de test Translation depuis la supervision.
// Verrouillage obligatoire : aucune surcharge IHM ne peut être active hors simulation.
IF GVL_Simulation.SimulationModeActive THEN
    GVL_PLC_Tests.OverrideM3SensorsWordActive := GVL_IHM.TranslationM3.TestSensorsWordActive;
    GVL_PLC_Tests.OverrideM3SensorsWord       := GVL_IHM.TranslationM3.TestSensorsWord;
    GVL_PLC_Tests.OverrideM3AtTremie          := GVL_IHM.TranslationM3.TestAtTremie;
    GVL_PLC_Tests.OverrideM3BrakeStuckOpen    := GVL_IHM.TranslationM3.TestBrakeStuckOpen;
    GVL_PLC_Tests.OverrideM3PhantomFreq       := GVL_IHM.TranslationM3.TestPhantomFreq;
ELSE
    GVL_PLC_Tests.OverrideM3SensorsWordActive := FALSE;
    GVL_PLC_Tests.OverrideM3AtTremie          := FALSE;
    GVL_PLC_Tests.OverrideM3BrakeStuckOpen    := FALSE;
    GVL_PLC_Tests.OverrideM3PhantomFreq       := FALSE;
END_IF;

// Signal d'acquittement défauts domaine sécurité/métier — JAMAIS Modes/Cycle (REX 2026-07-07)
FaultMachineReset_IHM := GVL_IHM.Modes.FaultMachineReset
                    OR GVL_IHM.M1TreuilRetenue.CmdReset
                    OR GVL_IHM.M2TreuilBucket.CmdReset
                    OR GVL_IHM.Bucket.CmdReset;

// 🔴 REX 2026-07-07 : au moins un défaut actif dans le domaine couvert par FaultMachineReset_IHM
// (même périmètre exact que les 17 blocs alimentés par ce reset — voir bandeau en tête de fichier).
// Sert à savoir, côté IHM, quand un appui sur FaultMachineReset est utile/attendu.
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
                                 OR GVL_IHM.Modes.CmdEmergencyCutOff;

// 🆕 REX 2026-07-08 : thermique frein commun M1/M2/M3 — signal UNIQUE (1 seul fil, pas de sens à
// le dupliquer par axe), remonté une seule fois au niveau global GVL_IHM (même principe que
// TopPositionSensorActive ci-dessus, PAS dans WinchM1/WinchM2/Translation).
GVL_IHM.Commun.BrakeThermalFault := NOT PRG_00_Inputs.BrakeThermalFeedback;
GVL_IHM.Commun.PhaseRotationFault := NOT PRG_00_Inputs.PhaseRotationOk; // 🆕 REX 2026-07-08 — commun M1/M2/M3, invisible IHM avant
GVL_IHM.Commun.HydraulicThermalFault := NOT PRG_08_AuxiliaryControl.HydraulicFaultOk; // 🆕 REX 2026-07-18 — diagnostic seul, aucune commande PLC

// 💓 Heartbeat IHM↔PLC — le toggle IHM est lu directement en PRG_01 ; ici, on publie
// les diagnostics calculés au même scan pour l'affichage et l'historisation IHM.
GVL_IHM.Commun.HeartbeatPlcToggle  := PRG_01_Diagnostics.instIhmHeartbeat.HeartbeatPlcToggle;
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
// homer qu'un seul treuil à la fois). GVL_IHM.M1TreuilRetenue/M2.CmdHome sont désormais câblés
// directement dans PRG_02_Encoders.st (instHomingM1/M2.Home) — homing simultané possible.

// ℹ️ Calibrate joystick : lu directement depuis GVL_IHM.JoystickJOY1.Calibrate dans PRG_01_Diagnostics (ligne 48)
// PRG_01_Diagnostics.FB_Joystick_0.Calibrate := GVL_IHM.JoystickJOY1.Calibrate;  // ❌ supprimé : VAR locale non accessible en écriture (C0037)


// ── 2. INITIALISATION IHM DEPUIS GVL_PERSISTENT (Boot) ───────────────────
IF GVL_IHM.M1TreuilRetenue.TopSensorPositionM = 0.0 THEN
    GVL_IHM.M1TreuilRetenue.TopSensorPositionM  := _HomingTargetM1_M;
    GVL_IHM.M1TreuilRetenue.HomingTargetM       := _HomingUnitaryTargetM1_M;
    GVL_IHM.M1TreuilRetenue.MaxStepDescente     := _WinchMaxStepDescent; // 🔧 REX 2026-07-08 : commun M1/M2
    GVL_IHM.M1TreuilRetenue.RampAccelRate       := _WinchM1RampAccelRate_Pct;
    GVL_IHM.M1TreuilRetenue.RampDecelNormalRate := _WinchM1RampDecelNormal_Pct;
    GVL_IHM.M1TreuilRetenue.RampDecelFastRate   := _WinchM1RampDecelFast_Pct;
    GVL_IHM.M1TreuilRetenue.CableLimitDescentM  := _CableLimitM1Descent_M;
    GVL_IHM.M1TreuilRetenue.CableLimitAscentM   := _CableLimitM1Ascent_M; // 🆕 REX 2026-07-15 (6)
    GVL_IHM.M1TreuilRetenue.SlowdownDistanceM   := _WinchSlowdownDistance_M;
    GVL_IHM.M1TreuilRetenue.SlowSpeedPct        := _WinchSlowSpeed_Pct;
END_IF;

IF GVL_IHM.M2TreuilBucket.TopSensorPositionM = 0.0 THEN
    GVL_IHM.M2TreuilBucket.TopSensorPositionM  := _HomingTargetM2_M;
    GVL_IHM.M2TreuilBucket.HomingTargetM       := _HomingUnitaryTargetM2_M;
    GVL_IHM.M2TreuilBucket.MaxStepDescente     := _WinchMaxStepDescent; // 🔧 REX 2026-07-08 : commun M1/M2
    GVL_IHM.M2TreuilBucket.RampAccelRate       := _WinchM2RampAccelRate_Pct;
    GVL_IHM.M2TreuilBucket.RampDecelNormalRate := _WinchM2RampDecelNormal_Pct;
    GVL_IHM.M2TreuilBucket.RampDecelFastRate   := _WinchM2RampDecelFast_Pct;
    GVL_IHM.M2TreuilBucket.CableLimitDescentM  := _CableLimitM2Descent_M;
    GVL_IHM.M2TreuilBucket.CableLimitAscentM   := _CableLimitM2Ascent_M; // 🆕 REX 2026-07-15 (6)
    GVL_IHM.M2TreuilBucket.SlowdownDistanceM   := _WinchSlowdownDistance_M;
    GVL_IHM.M2TreuilBucket.SlowSpeedPct        := _WinchSlowSpeed_Pct;
END_IF;

IF GVL_IHM.Sync.SyncToleranceM = 0.0 THEN
    GVL_IHM.Sync.SyncToleranceM         := _WinchSyncTolerance_M;
END_IF;

IF GVL_IHM.Bucket.Config.OffsetOpenM = 0.0 AND GVL_IHM.Bucket.Config.OffsetCloseM = 0.0 THEN
    GVL_IHM.Bucket.Config := _BucketConfig;
    GVL_IHM.Bucket.TimeoutDuration := T#30s;
END_IF;

IF GVL_IHM.Commun.LimitLegalDepthMinAllowed = 0.0 THEN
    GVL_IHM.Commun.LimitLegalDepthMinAllowed := _LimitLegalDepthMinAllowed_M;
    GVL_IHM.Commun.LimitLegalEnabled         := _LimitLegalEnabled;
END_IF;

// 🔧 REX 2026-07-19 : ex-boot-init WinchMaxStepFwd/Rev (essais progressifs IHM_MANU, TEMPORAIRE)
// retiré avec IHM_MANU — PRG_06_WinchControl applique désormais un plafond fixe (5 montée /
// _WinchMaxStepDescent descente), identique Auto et Manuel, plus de réglage IHM à initialiser.

IF GVL_IHM.Modes.ModeRequest = E_Mode.DISABLE THEN
    GVL_IHM.Modes.ModeRequest := E_Mode.MAINT_N1;
END_IF;


// ── 3. PROPAGATION DES RÉGLAGES IHM → PERSISTANCE ───────────────────────
_HomingTargetM1_M           := GVL_IHM.M1TreuilRetenue.TopSensorPositionM;
_HomingTargetM2_M           := GVL_IHM.M2TreuilBucket.TopSensorPositionM;
_HomingUnitaryTargetM1_M    := GVL_IHM.M1TreuilRetenue.HomingTargetM;
_HomingUnitaryTargetM2_M    := GVL_IHM.M2TreuilBucket.HomingTargetM;
// 🔧 REX 2026-07-08 : MaxStepDescente désormais commun M1/M2 — voir bloc miroir bidirectionnel
// ci-dessous (même pattern que CableLimitDescentM/SlowdownDistanceM/SlowSpeedPct), plus de
// propagation à sens unique séparée par treuil ici.
_WinchM1RampAccelRate_Pct   := GVL_IHM.M1TreuilRetenue.RampAccelRate;
_WinchM1RampDecelNormal_Pct := GVL_IHM.M1TreuilRetenue.RampDecelNormalRate;
_WinchM1RampDecelFast_Pct   := GVL_IHM.M1TreuilRetenue.RampDecelFastRate;
_WinchM2RampAccelRate_Pct   := GVL_IHM.M2TreuilBucket.RampAccelRate;
_WinchM2RampDecelNormal_Pct := GVL_IHM.M2TreuilBucket.RampDecelNormalRate;
_WinchM2RampDecelFast_Pct   := GVL_IHM.M2TreuilBucket.RampDecelFastRate;
// ⚠️ REX 2026-07-08 (5) — PIÈGE pont IHM→PERSISTENT découvert lors de l'audit : cette ligne
// écrase _WinchSyncTolerance_M avec GVL_IHM.Sync.SyncToleranceM À CHAQUE SCAN.
// Si on change UNIQUEMENT la valeur par défaut dans GVL_PERSISTENT.st (ou ST_SyncHMI.st), ça ne
// suffit pas : la valeur restaurée au boot (bloc §2 ci-dessus, `IF ... = 0.0 THEN`) ne s'applique
// que si le RETAIN IHM est à 0.0 (premier démarrage) — sinon l'ancienne valeur IHM re-propage ici
// et écrase silencieusement toute nouvelle valeur par défaut au scan suivant.
_WinchSyncTolerance_M       := GVL_IHM.Sync.SyncToleranceM;
_BucketConfig              := GVL_IHM.Bucket.Config;

// 🔧 REX 2026-07-08 (demande utilisateur) : MaxStepDescente commun M1/M2 — même profil de
// déplacement des 2 treuils, même pattern miroir que CableLimitDescentM ci-dessous.
IF GVL_IHM.M1TreuilRetenue.MaxStepDescente <> _WinchMaxStepDescent THEN
    _WinchMaxStepDescent := GVL_IHM.M1TreuilRetenue.MaxStepDescente;
ELSIF GVL_IHM.M2TreuilBucket.MaxStepDescente <> _WinchMaxStepDescent THEN
    _WinchMaxStepDescent := GVL_IHM.M2TreuilBucket.MaxStepDescente;
END_IF;
GVL_IHM.M1TreuilRetenue.MaxStepDescente := _WinchMaxStepDescent;
GVL_IHM.M2TreuilBucket.MaxStepDescente := _WinchMaxStepDescent;

IF GVL_IHM.M1TreuilRetenue.CableLimitDescentM <> _CableLimitM1Descent_M THEN
    _CableLimitM1Descent_M := GVL_IHM.M1TreuilRetenue.CableLimitDescentM;
END_IF;
GVL_IHM.M1TreuilRetenue.CableLimitDescentM := _CableLimitM1Descent_M;

IF GVL_IHM.M2TreuilBucket.CableLimitDescentM <> _CableLimitM2Descent_M THEN
    _CableLimitM2Descent_M := GVL_IHM.M2TreuilBucket.CableLimitDescentM;
END_IF;
GVL_IHM.M2TreuilBucket.CableLimitDescentM := _CableLimitM2Descent_M;

// 🆕 REX 2026-07-15 (6) — même pattern miroir bidirectionnel que CableLimitDescentM ci-dessus.
IF GVL_IHM.M1TreuilRetenue.CableLimitAscentM <> _CableLimitM1Ascent_M THEN
    _CableLimitM1Ascent_M := GVL_IHM.M1TreuilRetenue.CableLimitAscentM;
END_IF;
GVL_IHM.M1TreuilRetenue.CableLimitAscentM := _CableLimitM1Ascent_M;

IF GVL_IHM.M2TreuilBucket.CableLimitAscentM <> _CableLimitM2Ascent_M THEN
    _CableLimitM2Ascent_M := GVL_IHM.M2TreuilBucket.CableLimitAscentM;
END_IF;
GVL_IHM.M2TreuilBucket.CableLimitAscentM := _CableLimitM2Ascent_M;

IF GVL_IHM.M1TreuilRetenue.SlowdownDistanceM <> _WinchSlowdownDistance_M THEN
    _WinchSlowdownDistance_M := GVL_IHM.M1TreuilRetenue.SlowdownDistanceM;
ELSIF GVL_IHM.M2TreuilBucket.SlowdownDistanceM <> _WinchSlowdownDistance_M THEN
    _WinchSlowdownDistance_M := GVL_IHM.M2TreuilBucket.SlowdownDistanceM;
END_IF;
GVL_IHM.M1TreuilRetenue.SlowdownDistanceM := _WinchSlowdownDistance_M;
GVL_IHM.M2TreuilBucket.SlowdownDistanceM := _WinchSlowdownDistance_M;

IF GVL_IHM.M1TreuilRetenue.SlowSpeedPct <> _WinchSlowSpeed_Pct THEN
    _WinchSlowSpeed_Pct := GVL_IHM.M1TreuilRetenue.SlowSpeedPct;
ELSIF GVL_IHM.M2TreuilBucket.SlowSpeedPct <> _WinchSlowSpeed_Pct THEN
    _WinchSlowSpeed_Pct := GVL_IHM.M2TreuilBucket.SlowSpeedPct;
END_IF;
GVL_IHM.M1TreuilRetenue.SlowSpeedPct := _WinchSlowSpeed_Pct;
GVL_IHM.M2TreuilBucket.SlowSpeedPct := _WinchSlowSpeed_Pct;

_LimitLegalDepthMinAllowed_M := GVL_IHM.Commun.LimitLegalDepthMinAllowed;
_LimitLegalEnabled         := GVL_IHM.Commun.LimitLegalEnabled;
// 🔧 REX 2026-07-07 : plus de garde Mode=SEMI_AUTO, cohérent avec PRG_06_WinchControl.st §5
// (la limite légale s'applique désormais dans tous les modes dès qu'elle est activée).
GVL_IHM.Commun.LimitLegalReached         := _LimitLegalEnabled
                                            AND ((NOT PRG_04_Modes.instModes.InhibitM1 AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM <= _LimitLegalDepthMinAllowed_M))
                                                 OR (NOT PRG_04_Modes.instModes.InhibitM2 AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM <= _LimitLegalDepthMinAllowed_M)));

GVL_IHM.Commun.TopPositionSensorActive   := NOT PRG_00_Inputs.TopPositionSensor;


// ── 4. BYPASS DE SIMULATION POUR L'IHM (état effectif par device, voir DOC/AF_Partie-13_Fonction_Simulation_v1.2.md) ──────
GVL_IHM.M1TreuilRetenue.BypassContactorFeedback := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM1_IsReal;
GVL_IHM.M2TreuilBucket.BypassContactorFeedback := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM2_IsReal;
GVL_IHM.TranslationM3.BypassContactorFeedback := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM3_IsReal;
GVL_IHM.M1TreuilRetenue.BypassSlackCable        := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SlackCableSwitch_IsReal;
GVL_IHM.M2TreuilBucket.BypassSlackCable        := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SlackCableSwitch_IsReal;
GVL_IHM.M1TreuilRetenue.BypassTopPositionSensor := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.TopPositionSensor_IsReal;
GVL_IHM.M2TreuilBucket.BypassTopPositionSensor := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.TopPositionSensor_IsReal;


// ── 5. MAPPING ÉTATS TREUIL M1 → IHM ─────────────────────────────────────
GVL_IHM.M1TreuilRetenue.PositionM                := PRG_02_Encoders.instEncoderScaleM1.CablePosM;
GVL_IHM.M1TreuilRetenue.MeasuredSpeedMps         := PRG_03_Safety.instSafetyWinchM1.MeasuredSpeedMps;
GVL_IHM.M1TreuilRetenue.SpeedDeltaMps            := PRG_03_Safety.instSpeedMonitorM1.SpeedDeltaMps;
GVL_IHM.M1TreuilRetenue.SpeedVariationDetected   := PRG_03_Safety.instSpeedMonitorM1.SpeedVariationDetected;
GVL_IHM.M1TreuilRetenue.SpeedVariationConfirmed  := PRG_03_Safety.instSpeedMonitorM1.SpeedVariationConfirmed;
GVL_IHM.M1TreuilRetenue.SpeedStable             := PRG_03_Safety.instSpeedMonitorM1.SpeedStable;
GVL_IHM.M1TreuilRetenue.SpeedMonitorError        := PRG_03_Safety.instSpeedMonitorM1.Error;
GVL_IHM.M1TreuilRetenue.SpeedMonitorErrorId      := PRG_03_Safety.instSpeedMonitorM1.ErrorId;
GVL_IHM.M1TreuilRetenue.EstimatedLoadPct         := PRG_03_Safety.instLoadEstimatorM1.EstimatedLoadPct;
GVL_IHM.M1TreuilRetenue.LoadEstimateConfigured   := PRG_03_Safety.instLoadEstimatorM1.Configured;
GVL_IHM.M1TreuilRetenue.SpeedGuardLimited        := PRG_06_WinchControl.instWinchM1.SpeedGuardLimited;
GVL_IHM.M1TreuilRetenue.SpeedRefPct              := PRG_06_WinchControl.instWinchM1.SpeedRamp.Current;
GVL_IHM.M1TreuilRetenue.StepNumber               := PRG_06_WinchControl.instWinchM1.StepNumber;
GVL_IHM.M1TreuilRetenue.FBState                  := PRG_06_WinchControl.instWinchM1.State;
GVL_IHM.M1TreuilRetenue.Ready                    := PRG_06_WinchControl.instWinchM1.Ready;
GVL_IHM.M1TreuilRetenue.Busy                     := PRG_06_WinchControl.instWinchM1.Busy;
GVL_IHM.M1TreuilRetenue.Done                     := PRG_06_WinchControl.instWinchM1.Done;
GVL_IHM.M1TreuilRetenue.Error                    := PRG_06_WinchControl.instWinchM1.Error;
GVL_IHM.M1TreuilRetenue.ErrorId                  := PRG_06_WinchControl.instWinchM1.ErrorId;
GVL_IHM.M1TreuilRetenue.RelayFwd                 := PRG_06_WinchControl.instWinchM1.RelayFwd;
GVL_IHM.M1TreuilRetenue.RelayRev                 := PRG_06_WinchControl.instWinchM1.RelayRev;
GVL_IHM.M1TreuilRetenue.Contactor1               := PRG_06_WinchControl.instWinchM1.Contactor1;
GVL_IHM.M1TreuilRetenue.Contactor2               := PRG_06_WinchControl.instWinchM1.Contactor2;
GVL_IHM.M1TreuilRetenue.Contactor3               := PRG_06_WinchControl.instWinchM1.Contactor3;
GVL_IHM.M1TreuilRetenue.Contactor4               := PRG_06_WinchControl.instWinchM1.Contactor4;
GVL_IHM.M1TreuilRetenue.BrakeCmd                 := PRG_06_WinchControl.instWinchM1.BrakeCmd;
GVL_IHM.M1TreuilRetenue.Homed                    := PRG_02_Encoders.instHomingM1.Homed;
GVL_IHM.M1TreuilRetenue.HomingBusy              := PRG_02_Encoders.instHomingM1.Busy;
GVL_IHM.M1TreuilRetenue.HomingDone              := PRG_02_Encoders.instHomingM1.Done;
GVL_IHM.M1TreuilRetenue.HomingError             := PRG_02_Encoders.instHomingM1.Error;
GVL_IHM.M1TreuilRetenue.HomingErrorId           := PRG_02_Encoders.instHomingM1.ErrorId;
GVL_IHM.M1TreuilRetenue.HomingState             := PRG_02_Encoders.instHomingM1.State;
GVL_IHM.M1TreuilRetenue.HomingStateAtError      := PRG_02_Encoders.instHomingM1.StateAtError;
GVL_IHM.M1TreuilRetenue.HomingSuspect            := PRG_02_Encoders.instHomingM1.HomingSuspect;
GVL_IHM.M1TreuilRetenue.HomingRefRaw             := PRG_02_Encoders.instHomingM1.HomingRefRaw;
GVL_IHM.M1TreuilRetenue.SafeStopActive           := PRG_03_Safety.instSafetyWinchM1.SafeStop;
GVL_IHM.M1TreuilRetenue.ForbidDescentActive      := PRG_06_WinchControl.ForbidDescentM1_Active;
GVL_IHM.M1TreuilRetenue.ForbidAscentActive       := PRG_03_Safety.instSafetyWinchM1.ForbidAscent;
GVL_IHM.M1TreuilRetenue.SlackCableDetected       := NOT PRG_00_Inputs.SlackCableSwitch;
GVL_IHM.M1TreuilRetenue.ThermalFault             := NOT PRG_00_Inputs.M1ThermalFeedback;
GVL_IHM.M1TreuilRetenue.EncoderFault             := NOT PRG_02_Encoders.instEncoderAbsM1.EncoderAvailable OR PRG_02_Encoders.instEncoderSafetyM1.EncoderIncoherent;
GVL_IHM.M1TreuilRetenue.CableLimitDescentReached := (PRG_03_Safety.instSafetyWinchM1.ErrorId AND 16#0040) <> 16#0000;
GVL_IHM.M1TreuilRetenue.CableLimitAscentReached  := PRG_06_WinchControl.CableLimitAscentM1Reached; // 🆕 REX 2026-07-15 (8)
GVL_IHM.M1TreuilRetenue.ContactorsCheck          := PRG_06_WinchControl.instWinchM1.ContactorsCheck; // 🔧 REX 2026-07-07
GVL_IHM.M1TreuilRetenue.BrakeContactorCheck      := PRG_06_WinchControl.instWinchM1.BrakeContactorCheck;

GVL_IHM.M1TreuilRetenue.Encoder.RawPos           := PRG_02_Encoders.instEncoderAbsM1.RawPos;
GVL_IHM.M1TreuilRetenue.Encoder.Alarms           := PRG_02_Encoders.instEncoderAbsM1.AlarmsIn;
GVL_IHM.M1TreuilRetenue.Encoder.Warnings         := PRG_02_Encoders.instEncoderAbsM1.WarningsIn;
GVL_IHM.M1TreuilRetenue.Encoder.SlaveOperational := PRG_02_Encoders.instEncoderAbsM1.SlaveOperational;
GVL_IHM.M1TreuilRetenue.Encoder.PresetTriggerCmd := PRG_02_Encoders.instEncoderAbsM1.PresetTriggerCmd;
GVL_IHM.M1TreuilRetenue.Encoder.PresetValueOut   := PRG_02_Encoders.instEncoderAbsM1.PresetValueOut;
GVL_IHM.M1TreuilRetenue.Encoder.Error            := PRG_02_Encoders.instEncoderAbsM1.Error;
GVL_IHM.M1TreuilRetenue.Encoder.ErrorId          := PRG_02_Encoders.instEncoderAbsM1.ErrorId;
GVL_IHM.M1TreuilRetenue.SafetyError              := PRG_03_Safety.instSafetyWinchM1.Error;
GVL_IHM.M1TreuilRetenue.SafetyErrorId            := PRG_03_Safety.instSafetyWinchM1.ErrorId;
GVL_IHM.M1TreuilRetenue.MecaADriftM              := PRG_03_Safety.instSafetyWinchM1.MecaADriftM;      // 🆕 REX 2026-07-08
GVL_IHM.M1TreuilRetenue.MecaCDriftM              := PRG_03_Safety.instSafetyWinchM1.MecaCDriftM;      // 🆕 REX 2026-07-08
GVL_IHM.M1TreuilRetenue.MecaBElapsedTime         := PRG_03_Safety.instSafetyWinchM1.MecaBElapsedTime; // 🆕 REX 2026-07-08
GVL_IHM.M1TreuilRetenue.InhibitActive            := PRG_04_Modes.instModes.InhibitM1; // 🆕 REX 2026-07-08


// ── 6. MAPPING ÉTATS TREUIL M2 → IHM ─────────────────────────────────────
GVL_IHM.M2TreuilBucket.PositionM                := PRG_02_Encoders.instEncoderScaleM2.CablePosM;
GVL_IHM.M2TreuilBucket.MeasuredSpeedMps         := PRG_03_Safety.instSafetyWinchM2.MeasuredSpeedMps;
GVL_IHM.M2TreuilBucket.SpeedDeltaMps            := PRG_03_Safety.instSpeedMonitorM2.SpeedDeltaMps;
GVL_IHM.M2TreuilBucket.SpeedVariationDetected   := PRG_03_Safety.instSpeedMonitorM2.SpeedVariationDetected;
GVL_IHM.M2TreuilBucket.SpeedVariationConfirmed  := PRG_03_Safety.instSpeedMonitorM2.SpeedVariationConfirmed;
GVL_IHM.M2TreuilBucket.SpeedStable             := PRG_03_Safety.instSpeedMonitorM2.SpeedStable;
GVL_IHM.M2TreuilBucket.SpeedMonitorError        := PRG_03_Safety.instSpeedMonitorM2.Error;
GVL_IHM.M2TreuilBucket.SpeedMonitorErrorId      := PRG_03_Safety.instSpeedMonitorM2.ErrorId;
GVL_IHM.M2TreuilBucket.EstimatedLoadPct         := PRG_03_Safety.instLoadEstimatorM2.EstimatedLoadPct;
GVL_IHM.M2TreuilBucket.LoadEstimateConfigured   := PRG_03_Safety.instLoadEstimatorM2.Configured;
GVL_IHM.M2TreuilBucket.SpeedGuardLimited        := PRG_06_WinchControl.instWinchM2.SpeedGuardLimited;
GVL_IHM.M2TreuilBucket.SpeedRefPct              := PRG_06_WinchControl.instWinchM2.SpeedRamp.Current;
GVL_IHM.M2TreuilBucket.StepNumber               := PRG_06_WinchControl.instWinchM2.StepNumber;
GVL_IHM.M2TreuilBucket.FBState                  := PRG_06_WinchControl.instWinchM2.State;
GVL_IHM.M2TreuilBucket.Ready                    := PRG_06_WinchControl.instWinchM2.Ready;
GVL_IHM.M2TreuilBucket.Busy                     := PRG_06_WinchControl.instWinchM2.Busy;
GVL_IHM.M2TreuilBucket.Done                     := PRG_06_WinchControl.instWinchM2.Done;
GVL_IHM.M2TreuilBucket.Error                    := PRG_06_WinchControl.instWinchM2.Error;
GVL_IHM.M2TreuilBucket.ErrorId                  := PRG_06_WinchControl.instWinchM2.ErrorId;
GVL_IHM.M2TreuilBucket.RelayFwd                 := PRG_06_WinchControl.instWinchM2.RelayFwd;
GVL_IHM.M2TreuilBucket.RelayRev                 := PRG_06_WinchControl.instWinchM2.RelayRev;
GVL_IHM.M2TreuilBucket.Contactor1               := PRG_06_WinchControl.instWinchM2.Contactor1;
GVL_IHM.M2TreuilBucket.Contactor2               := PRG_06_WinchControl.instWinchM2.Contactor2;
GVL_IHM.M2TreuilBucket.Contactor3               := PRG_06_WinchControl.instWinchM2.Contactor3;
GVL_IHM.M2TreuilBucket.Contactor4               := PRG_06_WinchControl.instWinchM2.Contactor4;
GVL_IHM.M2TreuilBucket.BrakeCmd                 := PRG_06_WinchControl.instWinchM2.BrakeCmd;
GVL_IHM.M2TreuilBucket.Homed                    := PRG_02_Encoders.instHomingM2.Homed;
GVL_IHM.M2TreuilBucket.HomingBusy              := PRG_02_Encoders.instHomingM2.Busy;
GVL_IHM.M2TreuilBucket.HomingDone              := PRG_02_Encoders.instHomingM2.Done;
GVL_IHM.M2TreuilBucket.HomingError             := PRG_02_Encoders.instHomingM2.Error;
GVL_IHM.M2TreuilBucket.HomingErrorId           := PRG_02_Encoders.instHomingM2.ErrorId;
GVL_IHM.M2TreuilBucket.HomingState             := PRG_02_Encoders.instHomingM2.State;
GVL_IHM.M2TreuilBucket.HomingStateAtError      := PRG_02_Encoders.instHomingM2.StateAtError;
GVL_IHM.M2TreuilBucket.HomingSuspect            := PRG_02_Encoders.instHomingM2.HomingSuspect;
GVL_IHM.M2TreuilBucket.HomingRefRaw             := PRG_02_Encoders.instHomingM2.HomingRefRaw;
GVL_IHM.M2TreuilBucket.SafeStopActive           := PRG_03_Safety.instSafetyWinchM2.SafeStop;
GVL_IHM.M2TreuilBucket.ForbidDescentActive      := PRG_06_WinchControl.ForbidDescentM2_Active;
GVL_IHM.M2TreuilBucket.ForbidAscentActive       := PRG_03_Safety.instSafetyWinchM2.ForbidAscent;
GVL_IHM.M2TreuilBucket.SlackCableDetected       := NOT PRG_00_Inputs.SlackCableSwitch;
GVL_IHM.M2TreuilBucket.ThermalFault             := NOT PRG_00_Inputs.M2ThermalFeedback;
GVL_IHM.M2TreuilBucket.EncoderFault             := NOT PRG_02_Encoders.instEncoderAbsM2.EncoderAvailable OR PRG_02_Encoders.instEncoderSafetyM2.EncoderIncoherent;
GVL_IHM.M2TreuilBucket.CableLimitDescentReached := (PRG_03_Safety.instSafetyWinchM2.ErrorId AND 16#0040) <> 16#0000;
GVL_IHM.M2TreuilBucket.CableLimitAscentReached  := PRG_06_WinchControl.CableLimitAscentM2Reached; // 🆕 REX 2026-07-15 (8)
GVL_IHM.M2TreuilBucket.ContactorsCheck          := PRG_06_WinchControl.instWinchM2.ContactorsCheck; // 🔧 REX 2026-07-07
GVL_IHM.M2TreuilBucket.BrakeContactorCheck      := PRG_06_WinchControl.instWinchM2.BrakeContactorCheck;

GVL_IHM.M2TreuilBucket.Encoder.RawPos           := PRG_02_Encoders.instEncoderAbsM2.RawPos;
GVL_IHM.M2TreuilBucket.Encoder.Alarms           := PRG_02_Encoders.instEncoderAbsM2.AlarmsIn;
GVL_IHM.M2TreuilBucket.Encoder.Warnings         := PRG_02_Encoders.instEncoderAbsM2.WarningsIn;
GVL_IHM.M2TreuilBucket.Encoder.SlaveOperational := PRG_02_Encoders.instEncoderAbsM2.SlaveOperational;
GVL_IHM.M2TreuilBucket.Encoder.PresetTriggerCmd := PRG_02_Encoders.instEncoderAbsM2.PresetTriggerCmd;
GVL_IHM.M2TreuilBucket.Encoder.PresetValueOut   := PRG_02_Encoders.instEncoderAbsM2.PresetValueOut;
GVL_IHM.M2TreuilBucket.Encoder.Error            := PRG_02_Encoders.instEncoderAbsM2.Error;
GVL_IHM.M2TreuilBucket.Encoder.ErrorId          := PRG_02_Encoders.instEncoderAbsM2.ErrorId;
GVL_IHM.M2TreuilBucket.SafetyError              := PRG_03_Safety.instSafetyWinchM2.Error;
GVL_IHM.M2TreuilBucket.SafetyErrorId            := PRG_03_Safety.instSafetyWinchM2.ErrorId;
GVL_IHM.M2TreuilBucket.MecaADriftM              := PRG_03_Safety.instSafetyWinchM2.MecaADriftM;      // 🆕 REX 2026-07-08
GVL_IHM.M2TreuilBucket.MecaCDriftM              := PRG_03_Safety.instSafetyWinchM2.MecaCDriftM;      // 🆕 REX 2026-07-08
GVL_IHM.M2TreuilBucket.MecaBElapsedTime         := PRG_03_Safety.instSafetyWinchM2.MecaBElapsedTime; // 🆕 REX 2026-07-08
GVL_IHM.M2TreuilBucket.InhibitActive            := PRG_04_Modes.instModes.InhibitM2; // 🆕 REX 2026-07-08


// ── 7. MAPPING ÉTATS BENNE → IHM ───────────────────────────────────────
GVL_IHM.Bucket.FBState          := PRG_06_WinchControl.instBucket.State;
GVL_IHM.Bucket.ActiveOffsetM    := PRG_06_WinchControl.instBucket.ActiveOffsetM;
GVL_IHM.Bucket.M2StartStop      := PRG_06_WinchControl.instBucket.M2_StartStop;
GVL_IHM.Bucket.M2Direction      := PRG_06_WinchControl.instBucket.M2_Direction;
GVL_IHM.Bucket.M2ForceSlowSpeed := PRG_06_WinchControl.instBucket.M2_ForceSlowSpeed;
GVL_IHM.Bucket.Ready            := PRG_06_WinchControl.instBucket.Ready;
GVL_IHM.Bucket.Busy             := PRG_06_WinchControl.instBucket.Busy;
GVL_IHM.Bucket.Done             := PRG_06_WinchControl.instBucket.Done;
GVL_IHM.Bucket.Error            := PRG_06_WinchControl.instBucket.Error;
GVL_IHM.Bucket.ErrorId          := PRG_06_WinchControl.instBucket.ErrorId;
GVL_IHM.Bucket.RemainingTravelM := PRG_06_WinchControl.instBucket.RemainingTravelM; // 🔧 REX 2026-07-07
GVL_IHM.Bucket.CloseReq         := PRG_06_WinchControl.instBucket.CloseReq; // 🆕 REX 2026-07-08
GVL_IHM.Bucket.OpenReq          := PRG_06_WinchControl.instBucket.OpenReq;  // 🆕 REX 2026-07-08
// 📊 REX 2026-07-07 : position M2 corrigée de l'offset actif — affichage bargraphe uniquement,
// doit être égale à GVL_IHM.M1TreuilRetenue.PositionM quand tout est nominal (voir bandeau ST_BucketHMI).
GVL_IHM.Bucket.M2PositionCorrected := PRG_02_Encoders.instEncoderScaleM2.CablePosM - PRG_06_WinchControl.instBucket.ActiveOffsetM;
GVL_IHM.Bucket.State            := _BucketState;


// ── 8. MAPPING ÉTATS SYNCHRONISATION → IHM ─────────────────────────────────
GVL_IHM.Sync.DeltaPosM  := PRG_06_WinchControl.instWinchSync.DeltaPosM;
GVL_IHM.Sync.SyncActive := PRG_06_WinchControl.instWinchSync.SyncActive;
GVL_IHM.Sync.SyncWarn   := PRG_06_WinchControl.instWinchSync.SyncWarn;
GVL_IHM.Sync.Ready      := PRG_06_WinchControl.instWinchSync.Ready;
GVL_IHM.Sync.Error      := PRG_06_WinchControl.instWinchSync.Error;
GVL_IHM.Sync.ErrorId    := PRG_06_WinchControl.instWinchSync.ErrorId;
GVL_IHM.Sync.State      := PRG_06_WinchControl.instWinchSync.State;


// ── 9. MAPPING ÉTATS TRANSLATION M3 → IHM ────────────────────────────────────
GVL_IHM.TranslationM3.FBState              := PRG_07_TranslationControl.instTranslationM3.State;
GVL_IHM.TranslationM3.Ready                := PRG_07_TranslationControl.instTranslationM3.Ready;
GVL_IHM.TranslationM3.Busy                 := PRG_07_TranslationControl.instTranslationM3.Busy;
GVL_IHM.TranslationM3.Done                 := PRG_07_TranslationControl.instTranslationM3.Done;
GVL_IHM.TranslationM3.Error                := PRG_07_TranslationControl.instTranslationM3.Error;
GVL_IHM.TranslationM3.ErrorId              := PRG_07_TranslationControl.instTranslationM3.ErrorId;
GVL_IHM.TranslationM3.BrakeCmd             := PRG_07_TranslationControl.instTranslationM3.BrakeCmd;
GVL_IHM.TranslationM3.BrakeFeedback        := PRG_00_Inputs.M3BrakeFeedback;
GVL_IHM.TranslationM3.PositionSensorTarget := PRG_07_TranslationControl.M3_PositionSensorTarget;
GVL_IHM.TranslationM3.PositionTremie      := PRG_00_Inputs.TranslationPosTremie;
GVL_IHM.TranslationM3.PositionPV          := PRG_00_Inputs.TranslationPosPV;
GVL_IHM.TranslationM3.PositionP2          := PRG_00_Inputs.TranslationPosP2;
GVL_IHM.TranslationM3.PositionP1          := PRG_00_Inputs.TranslationPosP1;
GVL_IHM.TranslationM3.PositionMaintenance := PRG_00_Inputs.TranslationPosMaintenance;
GVL_IHM.TranslationM3.SensorsWord         := PRG_07_TranslationControl.instPositionDecoder.SensorsWord;
GVL_IHM.TranslationM3.SensorWordIncoherent:= PRG_07_TranslationControl.instPositionDecoder.Incoherent;
GVL_IHM.TranslationM3.LimitSwitchFwd     := PRG_07_TranslationControl.instPositionDecoder.LimitSwitchFwd;
GVL_IHM.TranslationM3.LimitSwitchRev     := PRG_07_TranslationControl.instPositionDecoder.LimitSwitchRev;
GVL_IHM.TranslationM3.MaintenanceTargetEnable := PRG_04_Modes.instModes.MaintenanceM3TargetEnable;
GVL_IHM.TranslationM3.SimulationModeActive := GVL_Simulation.SimulationModeActive;
// 🔧 Diag variateur décodé (pas de bit-masking côté IHM) — StatusWord bit7=CommReady, bit0=PowerReady
GVL_IHM.TranslationM3.DriveCommReady       := PRG_00_Inputs.M3_StatusWord_Filtered.7 OR GVL_Simulation.SimulationModeActive;
GVL_IHM.TranslationM3.DrivePowerReady      := PRG_00_Inputs.M3_StatusWord_Filtered.0 OR GVL_Simulation.SimulationModeActive;
// 🔧 Source unique (PRG_00_Inputs), valable Auto ET Manu — remplace l'ex-doublon IHM_MANU.M3_FreqActual
GVL_IHM.TranslationM3.DriveActualFreqHz    := UINT_TO_REAL(PRG_00_Inputs.M3_ActualFrequencyHz_Filtered) / 100.0;
GVL_IHM.TranslationM3.SafetyError          := PRG_03_Safety.instSafetyTranslationM3.Error;
GVL_IHM.TranslationM3.SafetyErrorId        := PRG_03_Safety.instSafetyTranslationM3.ErrorId;
GVL_IHM.TranslationM3.SafetyErrorOperatorComm := PRG_03_Safety.instSafetyTranslationM3.ErrorOperatorComm;
GVL_IHM.TranslationM3.SafetyErrorDriveComm    := PRG_03_Safety.instSafetyTranslationM3.ErrorDriveComm;
GVL_IHM.TranslationM3.SafetyErrorPhaseRotation:= PRG_03_Safety.instSafetyTranslationM3.ErrorPhaseRotation;
GVL_IHM.TranslationM3.SafetyErrorBrakeThermal := PRG_03_Safety.instSafetyTranslationM3.ErrorBrakeThermal;
GVL_IHM.TranslationM3.SafetyErrorMecaB        := PRG_03_Safety.instSafetyTranslationM3.ErrorMecaB;
GVL_IHM.TranslationM3.SafetyErrorMecaA        := PRG_03_Safety.instSafetyTranslationM3.ErrorMecaA;
GVL_IHM.TranslationM3.SafetyErrorLimitSwitch  := PRG_03_Safety.instSafetyTranslationM3.ErrorLimitSwitch;
GVL_IHM.TranslationM3.SafetyErrorSensorIncoherent := PRG_03_Safety.instSafetyTranslationM3.ErrorSensorIncoherent;
GVL_IHM.TranslationM3.SafetySafeStop       := PRG_03_Safety.instSafetyTranslationM3.SafeStop;
GVL_IHM.TranslationM3.SafetyPowerCutOff    := PRG_03_Safety.instSafetyTranslationM3.PowerCutOff;
GVL_IHM.TranslationM3.DriveControlWord     := PRG_07_TranslationControl.instTranslationM3.DriveControlWord;
GVL_IHM.TranslationM3.DriveFreqRefHz       := PRG_07_TranslationControl.instTranslationM3.DriveFreqRefHz;
GVL_IHM.TranslationM3.ActiveDirection      := PRG_07_TranslationControl.M3_Direction_Active;
GVL_IHM.TranslationM3.ActiveSpeedRefPct    := PRG_07_TranslationControl.M3_SpeedRef_Active;

// ── 9bis. MAPPING CYCLE SEMI-AUTOMATIQUE → IHM ──────────────────────────────
GVL_IHM.Cycle.Ready                := PRG_05_Cycle.instCycle.Ready;
GVL_IHM.Cycle.Busy                 := PRG_05_Cycle.instCycle.Busy;
GVL_IHM.Cycle.Done                 := PRG_05_Cycle.instCycle.Done;
GVL_IHM.Cycle.Error                := PRG_05_Cycle.instCycle.Error;
GVL_IHM.Cycle.ErrorId              := PRG_05_Cycle.instCycle.ErrorId;
GVL_IHM.Cycle.CycleStep            := PRG_05_Cycle.instCycle.CycleStep;
GVL_IHM.Cycle.CycleStateStr        := PRG_05_Cycle.instCycle.CycleStateStr;
GVL_IHM.Cycle.SelectedTargetNum    := GVL_IHM.TranslationM3.SelectedTargetNum;
GVL_IHM.Cycle.KoboldContactFond    := PRG_00_Inputs.KoboldContactFond;
GVL_IHM.Cycle.KoboldContactorCmd   := PRG_05_Cycle.instCycle.KoboldContactorCmd;
GVL_IHM.Cycle.LimitLegalReached    := GVL_IHM.Commun.LimitLegalReached;
GVL_IHM.Cycle.LimitLegalDepthM     := GVL_IHM.Commun.LimitLegalDepthMinAllowed;
GVL_IHM.Cycle.WinchSyncError       := PRG_06_WinchControl.instWinchSync.Error;
GVL_IHM.Cycle.WinchSyncDeltaM      := PRG_06_WinchControl.instWinchSync.DeltaPosM;
GVL_IHM.Cycle.M1PositionM          := PRG_02_Encoders.instEncoderScaleM1.CablePosM;
GVL_IHM.Cycle.M2PositionM          := PRG_02_Encoders.instEncoderScaleM2.CablePosM;
GVL_IHM.Cycle.DeadmanArmed         := PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed;
GVL_IHM.Cycle.JoystickMotionActive := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop;
GVL_IHM.Cycle.MotionPermit         := PRG_05_Cycle.CycleMotionPermit;


// ── 10. MAPPING ÉTATS JOYSTICK → IHM ─────────────────────────────────────
GVL_IHM.JoystickJOY1.RawX       := JoyXRaw_ANA1;
GVL_IHM.JoystickJOY1.RawY       := JoyYRaw_ANA2;
GVL_IHM.JoystickJOY1.RawButton  := JoyBtnRaw;
GVL_IHM.JoystickJOY1.CmdX       := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX;
GVL_IHM.JoystickJOY1.CmdY       := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY;
GVL_IHM.JoystickJOY1.Online     := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Online;
GVL_IHM.JoystickJOY1.Operational := PRG_01_Diagnostics.instDiagCanOpen.DeviceJoystick.Operational;
GVL_IHM.JoystickJOY1.Error       := PRG_01_Diagnostics.FB_Joystick_0.Error;
GVL_IHM.JoystickJOY1.ErrorId     := PRG_01_Diagnostics.FB_Joystick_0.ErrorId;


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
