(* ═══════════════════════════════════════════════════════════════
   🖥️ PRG_09_Supervision — Échanges IHM, Stubs et Initialisation Boot
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 9.
   ✅ Regroupe tout le mapping bidirectionnel GVL_IHM / GVL_PERSISTENT.
   ✅ Expose FaultMachineReset_IHM pour tous les programmes du domaine sécurité/métier.
   🔧 REX 2026-07-07 : séparation des resets — l'ancien MachineReset_IHM (unique, câblé sur
      TOUT y compris FB_Modes/FB_Cycle) est retiré. FaultMachineReset_IHM ne couvre plus que le
      domaine sécurité/métier (Winch, Safety, Encodeurs, Grappin, Joystick, Chariot) ;
      FB_Modes/FB_Cycle ont chacun leur propre Reset dédié (GVL_IHM.Modes.ModeReset côté
      PRG_04_Modes, CmdResetCycle_IHM côté PRG_05_Cycle) — jamais mélangés.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_09_Supervision
VAR_OUTPUT
    FaultMachineReset_IHM : BOOL; // 🔔 Acquittement défauts domaine sécurité/métier (OR des boutons HMI) — jamais Modes/Cycle
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_09_Supervision) ===

// ── 1. ACQUISITION DES DEMANDES / BOUTONS DE L'IHM ────────────────────────
GVL_Modes_Stub.ModeRequest_IHM         := GVL_IHM.Modes.ModeRequest;
GVL_Modes_Stub.SyncEnableRequest_IHM   := GVL_IHM.Sync.SyncEnableRequest; // 🔧 REX 2026-07-08 : renommé, polarité inversée
StubChariotPositionSelect_IHM          := GVL_IHM.Chariot.SelectedTargetNum;

// Signal d'acquittement défauts domaine sécurité/métier — JAMAIS Modes/Cycle (REX 2026-07-07)
FaultMachineReset_IHM := GVL_IHM.Modes.FaultMachineReset
                    OR GVL_IHM.WinchM1.CmdReset
                    OR GVL_IHM.WinchM2.CmdReset
                    OR GVL_IHM.Grappin.CmdReset;

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
    OR PRG_03_Safety.instSafetyChariotM3.Error
    OR PRG_06_WinchControl.instWinchSync.Error
    OR PRG_06_WinchControl.instGrappin.Error
    OR PRG_07_ChariotControl.instChariotM3.Error
    OR PRG_10_Outputs.RedundancyTestFailed
    OR PRG_10_Outputs.EmergencyArmingFailed;

// 🧨 REX 2026-07-07 : remontée IHM de la coupure puissance amont — polarité "alarme" (TRUE=
// problème), PAS celle de PowerCutOff_A_RQ (qui est en fail-safe maintenu, TRUE=OK depuis
// l'inversion de polarité). On relit directement les .PowerCutOff sources, pas la sortie physique.
GVL_IHM.Modes.PowerCutOffActive := PRG_03_Safety.instSafetyWinchM1.PowerCutOff
                                 OR PRG_03_Safety.instSafetyWinchM2.PowerCutOff
                                 OR PRG_03_Safety.instSafetyChariotM3.PowerCutOff
                                 OR GVL_IHM.Modes.CmdEmergencyCutOff;

// 🆕 REX 2026-07-08 : thermique frein commun M1/M2/M3 — signal UNIQUE (1 seul fil, pas de sens à
// le dupliquer par axe), remonté une seule fois au niveau global GVL_IHM (même principe que
// TopPositionSensorActive ci-dessus, PAS dans WinchM1/WinchM2/Chariot).
GVL_IHM.Common.BrakeThermalFault := NOT PRG_00_Inputs.BrakeThermalFeedback;
GVL_IHM.Common.PhaseRotationFault := NOT PRG_00_Inputs.PhaseRotationOk; // 🆕 REX 2026-07-08 — commun M1/M2/M3, invisible IHM avant

// 🔧 REX 2026-07-07 — Séquence réarmement AU (voir DOC/AF_Partie1 v1.5 §Sécurité électrique)
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
// homer qu'un seul treuil à la fois). GVL_IHM.WinchM1/M2.CmdHome sont désormais câblés
// directement dans PRG_02_Encoders.st (instHomingM1/M2.Home) — homing simultané possible.

// ℹ️ Calibrate joystick : lu directement depuis GVL_IHM.Joystick.Calibrate dans PRG_01_Diagnostics (ligne 48)
// PRG_01_Diagnostics.FB_Joystick_0.Calibrate := GVL_IHM.Joystick.Calibrate;  // ❌ supprimé : VAR locale non accessible en écriture (C0037)


// ── 2. INITIALISATION IHM DEPUIS GVL_PERSISTENT (Boot) ───────────────────
IF GVL_IHM.WinchM1.TopSensorPositionM = 0.0 THEN
    GVL_IHM.WinchM1.TopSensorPositionM  := GVL_PERSISTENT.HomingTargetM1_M;
    GVL_IHM.WinchM1.MaxStepDescente     := GVL_PERSISTENT.WinchMaxStepDescente; // 🔧 REX 2026-07-08 : commun M1/M2
    GVL_IHM.WinchM1.RampAccelRate       := GVL_PERSISTENT.WinchM1RampAccelRate_Pct;
    GVL_IHM.WinchM1.RampDecelNormalRate := GVL_PERSISTENT.WinchM1RampDecelNormal_Pct;
    GVL_IHM.WinchM1.RampDecelFastRate   := GVL_PERSISTENT.WinchM1RampDecelFast_Pct;
    GVL_IHM.WinchM1.CableLimitDescentM  := GVL_PERSISTENT.CableLimitDescentM1_M;
    GVL_IHM.WinchM1.SlowdownDistanceM   := GVL_PERSISTENT.WinchSlowdownDistance_M;
    GVL_IHM.WinchM1.SlowSpeedPct        := GVL_PERSISTENT.WinchSlowSpeedPct;
END_IF;

IF GVL_IHM.WinchM2.TopSensorPositionM = 0.0 THEN
    GVL_IHM.WinchM2.TopSensorPositionM  := GVL_PERSISTENT.HomingTargetM2_M;
    GVL_IHM.WinchM2.MaxStepDescente     := GVL_PERSISTENT.WinchMaxStepDescente; // 🔧 REX 2026-07-08 : commun M1/M2
    GVL_IHM.WinchM2.RampAccelRate       := GVL_PERSISTENT.WinchM2RampAccelRate_Pct;
    GVL_IHM.WinchM2.RampDecelNormalRate := GVL_PERSISTENT.WinchM2RampDecelNormal_Pct;
    GVL_IHM.WinchM2.RampDecelFastRate   := GVL_PERSISTENT.WinchM2RampDecelFast_Pct;
    GVL_IHM.WinchM2.CableLimitDescentM  := GVL_PERSISTENT.CableLimitDescentM2_M;
    GVL_IHM.WinchM2.SlowdownDistanceM   := GVL_PERSISTENT.WinchSlowdownDistance_M;
    GVL_IHM.WinchM2.SlowSpeedPct        := GVL_PERSISTENT.WinchSlowSpeedPct;
END_IF;

IF GVL_IHM.Sync.SyncToleranceM = 0.0 THEN
    GVL_IHM.Sync.SyncToleranceM         := GVL_PERSISTENT.WinchSyncTolerance_M;
END_IF;

IF GVL_IHM.Grappin.Config.OffsetOpenM = 0.0 AND GVL_IHM.Grappin.Config.OffsetCloseM = 0.0 THEN
    GVL_IHM.Grappin.Config := GVL_PERSISTENT.GrappinConfig;
    GVL_IHM.Grappin.TimeoutDuration := T#30s;
END_IF;

IF GVL_IHM.Common.LimitLegalDepthMinAllowed = 0.0 THEN
    GVL_IHM.Common.LimitLegalDepthMinAllowed := GVL_PERSISTENT.LimitLegalDepthMinAllowed;
    GVL_IHM.Common.LimitLegalEnabled         := GVL_PERSISTENT.LimitLegalEnabled;
END_IF;

IF GVL_IHM.Modes.ModeRequest = E_Mode.DISABLE THEN
    GVL_IHM.Modes.ModeRequest := E_Mode.MAINT_N1;
END_IF;


// ── 3. PROPAGATION DES RÉGLAGES IHM → PERSISTANCE ───────────────────────
GVL_PERSISTENT.HomingTargetM1_M           := GVL_IHM.WinchM1.TopSensorPositionM;
GVL_PERSISTENT.HomingTargetM2_M           := GVL_IHM.WinchM2.TopSensorPositionM;
// 🔧 REX 2026-07-08 : MaxStepDescente désormais commun M1/M2 — voir bloc miroir bidirectionnel
// ci-dessous (même pattern que CableLimitDescentM/SlowdownDistanceM/SlowSpeedPct), plus de
// propagation à sens unique séparée par treuil ici.
GVL_PERSISTENT.WinchM1RampAccelRate_Pct   := GVL_IHM.WinchM1.RampAccelRate;
GVL_PERSISTENT.WinchM1RampDecelNormal_Pct := GVL_IHM.WinchM1.RampDecelNormalRate;
GVL_PERSISTENT.WinchM1RampDecelFast_Pct   := GVL_IHM.WinchM1.RampDecelFastRate;
GVL_PERSISTENT.WinchM2RampAccelRate_Pct   := GVL_IHM.WinchM2.RampAccelRate;
GVL_PERSISTENT.WinchM2RampDecelNormal_Pct := GVL_IHM.WinchM2.RampDecelNormalRate;
GVL_PERSISTENT.WinchM2RampDecelFast_Pct   := GVL_IHM.WinchM2.RampDecelFastRate;
// ⚠️ REX 2026-07-08 (5) — PIÈGE pont IHM→PERSISTENT découvert lors de l'audit : cette ligne
// écrase GVL_PERSISTENT.WinchSyncTolerance_M avec GVL_IHM.Sync.SyncToleranceM À CHAQUE SCAN.
// Si on change UNIQUEMENT la valeur par défaut dans GVL_PERSISTENT.st (ou ST_SyncHMI.st), ça ne
// suffit pas : la valeur restaurée au boot (bloc §2 ci-dessus, `IF ... = 0.0 THEN`) ne s'applique
// que si le RETAIN IHM est à 0.0 (premier démarrage) — sinon l'ancienne valeur IHM re-propage ici
// et écrase silencieusement toute nouvelle valeur par défaut au scan suivant.
GVL_PERSISTENT.WinchSyncTolerance_M       := GVL_IHM.Sync.SyncToleranceM;
GVL_PERSISTENT.GrappinConfig              := GVL_IHM.Grappin.Config;

// 🔧 REX 2026-07-08 (demande utilisateur) : MaxStepDescente commun M1/M2 — même profil de
// déplacement des 2 treuils, même pattern miroir que CableLimitDescentM ci-dessous.
IF GVL_IHM.WinchM1.MaxStepDescente <> GVL_PERSISTENT.WinchMaxStepDescente THEN
    GVL_PERSISTENT.WinchMaxStepDescente := GVL_IHM.WinchM1.MaxStepDescente;
ELSIF GVL_IHM.WinchM2.MaxStepDescente <> GVL_PERSISTENT.WinchMaxStepDescente THEN
    GVL_PERSISTENT.WinchMaxStepDescente := GVL_IHM.WinchM2.MaxStepDescente;
END_IF;
GVL_IHM.WinchM1.MaxStepDescente := GVL_PERSISTENT.WinchMaxStepDescente;
GVL_IHM.WinchM2.MaxStepDescente := GVL_PERSISTENT.WinchMaxStepDescente;

IF GVL_IHM.WinchM1.CableLimitDescentM <> GVL_PERSISTENT.CableLimitDescentM1_M THEN
    GVL_PERSISTENT.CableLimitDescentM1_M := GVL_IHM.WinchM1.CableLimitDescentM;
END_IF;
GVL_IHM.WinchM1.CableLimitDescentM := GVL_PERSISTENT.CableLimitDescentM1_M;

IF GVL_IHM.WinchM2.CableLimitDescentM <> GVL_PERSISTENT.CableLimitDescentM2_M THEN
    GVL_PERSISTENT.CableLimitDescentM2_M := GVL_IHM.WinchM2.CableLimitDescentM;
END_IF;
GVL_IHM.WinchM2.CableLimitDescentM := GVL_PERSISTENT.CableLimitDescentM2_M;

IF GVL_IHM.WinchM1.SlowdownDistanceM <> GVL_PERSISTENT.WinchSlowdownDistance_M THEN
    GVL_PERSISTENT.WinchSlowdownDistance_M := GVL_IHM.WinchM1.SlowdownDistanceM;
ELSIF GVL_IHM.WinchM2.SlowdownDistanceM <> GVL_PERSISTENT.WinchSlowdownDistance_M THEN
    GVL_PERSISTENT.WinchSlowdownDistance_M := GVL_IHM.WinchM2.SlowdownDistanceM;
END_IF;
GVL_IHM.WinchM1.SlowdownDistanceM := GVL_PERSISTENT.WinchSlowdownDistance_M;
GVL_IHM.WinchM2.SlowdownDistanceM := GVL_PERSISTENT.WinchSlowdownDistance_M;

IF GVL_IHM.WinchM1.SlowSpeedPct <> GVL_PERSISTENT.WinchSlowSpeedPct THEN
    GVL_PERSISTENT.WinchSlowSpeedPct := GVL_IHM.WinchM1.SlowSpeedPct;
ELSIF GVL_IHM.WinchM2.SlowSpeedPct <> GVL_PERSISTENT.WinchSlowSpeedPct THEN
    GVL_PERSISTENT.WinchSlowSpeedPct := GVL_IHM.WinchM2.SlowSpeedPct;
END_IF;
GVL_IHM.WinchM1.SlowSpeedPct := GVL_PERSISTENT.WinchSlowSpeedPct;
GVL_IHM.WinchM2.SlowSpeedPct := GVL_PERSISTENT.WinchSlowSpeedPct;

GVL_PERSISTENT.LimitLegalDepthMinAllowed := GVL_IHM.Common.LimitLegalDepthMinAllowed;
GVL_PERSISTENT.LimitLegalEnabled         := GVL_IHM.Common.LimitLegalEnabled;
// 🔧 REX 2026-07-07 : plus de garde Mode=SEMI_AUTO, cohérent avec PRG_06_WinchControl.st §5
// (la limite légale s'applique désormais dans tous les modes dès qu'elle est activée).
GVL_IHM.Common.LimitLegalReached         := GVL_PERSISTENT.LimitLegalEnabled
                                            AND ((NOT PRG_04_Modes.instModes.InhibitM1 AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM <= GVL_PERSISTENT.LimitLegalDepthMinAllowed))
                                                 OR (NOT PRG_04_Modes.instModes.InhibitM2 AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM <= GVL_PERSISTENT.LimitLegalDepthMinAllowed)));

GVL_IHM.Common.TopPositionSensorActive   := NOT PRG_00_Inputs.TopPositionSensor;


// ── 4. BYPASS DE SIMULATION POUR L'IHM (état effectif par device, voir AF_Partie13) ──────
GVL_IHM.WinchM1.BypassContactorFeedback := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM1_IsReal;
GVL_IHM.WinchM2.BypassContactorFeedback := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM2_IsReal;
GVL_IHM.Chariot.BypassContactorFeedback := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM3_IsReal;
GVL_IHM.WinchM1.BypassSlackCable        := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SlackCableSwitch_IsReal;
GVL_IHM.WinchM2.BypassSlackCable        := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.SlackCableSwitch_IsReal;
GVL_IHM.WinchM1.BypassTopPositionSensor := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.TopPositionSensor_IsReal;
GVL_IHM.WinchM2.BypassTopPositionSensor := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.TopPositionSensor_IsReal;


// ── 5. MAPPING ÉTATS TREUIL M1 → IHM ─────────────────────────────────────
GVL_IHM.WinchM1.PositionM                := PRG_02_Encoders.instEncoderScaleM1.CablePosM;
GVL_IHM.WinchM1.SpeedRefPct              := PRG_06_WinchControl.instWinchM1.SpeedRamp.Current;
GVL_IHM.WinchM1.StepNumber               := PRG_06_WinchControl.instWinchM1.StepNumber;
GVL_IHM.WinchM1.FBState                  := PRG_06_WinchControl.instWinchM1.State;
GVL_IHM.WinchM1.Ready                    := PRG_06_WinchControl.instWinchM1.Ready;
GVL_IHM.WinchM1.Busy                     := PRG_06_WinchControl.instWinchM1.Busy;
GVL_IHM.WinchM1.Done                     := PRG_06_WinchControl.instWinchM1.Done;
GVL_IHM.WinchM1.Error                    := PRG_06_WinchControl.instWinchM1.Error;
GVL_IHM.WinchM1.ErrorId                  := PRG_06_WinchControl.instWinchM1.ErrorId;
GVL_IHM.WinchM1.RelayFwd                 := PRG_06_WinchControl.instWinchM1.RelayFwd;
GVL_IHM.WinchM1.RelayRev                 := PRG_06_WinchControl.instWinchM1.RelayRev;
GVL_IHM.WinchM1.Contactor1               := PRG_06_WinchControl.instWinchM1.Contactor1;
GVL_IHM.WinchM1.Contactor2               := PRG_06_WinchControl.instWinchM1.Contactor2;
GVL_IHM.WinchM1.Contactor3               := PRG_06_WinchControl.instWinchM1.Contactor3;
GVL_IHM.WinchM1.Contactor4               := PRG_06_WinchControl.instWinchM1.Contactor4;
GVL_IHM.WinchM1.BrakeCmd                 := PRG_06_WinchControl.instWinchM1.BrakeCmd;
GVL_IHM.WinchM1.Homed                    := PRG_02_Encoders.instHomingM1.Homed;
GVL_IHM.WinchM1.SafeStopActive           := PRG_03_Safety.instSafetyWinchM1.SafeStop;
GVL_IHM.WinchM1.ForbidDescentActive      := PRG_06_WinchControl.ForbidDescentM1_Active;
GVL_IHM.WinchM1.ForbidAscentActive       := PRG_03_Safety.instSafetyWinchM1.ForbidAscent;
GVL_IHM.WinchM1.SlackCableDetected       := NOT PRG_00_Inputs.SlackCableSwitch;
GVL_IHM.WinchM1.ThermalFault             := NOT PRG_00_Inputs.M1ThermalFeedback;
GVL_IHM.WinchM1.EncoderFault             := NOT PRG_02_Encoders.instEncoderAbsM1.EncoderAvailable OR PRG_02_Encoders.instEncoderSafetyM1.EncoderIncoherent;
GVL_IHM.WinchM1.CableLimitDescentReached := (PRG_03_Safety.instSafetyWinchM1.ErrorId AND 16#0040) <> 16#0000;
GVL_IHM.WinchM1.ContactorsCheck          := PRG_06_WinchControl.instWinchM1.ContactorsCheck; // 🔧 REX 2026-07-07
GVL_IHM.WinchM1.BrakeContactorCheck      := PRG_06_WinchControl.instWinchM1.BrakeContactorCheck;

GVL_IHM.WinchM1.Encoder.RawPos           := PRG_02_Encoders.instEncoderAbsM1.RawPos;
GVL_IHM.WinchM1.Encoder.Alarms           := PRG_02_Encoders.instEncoderAbsM1.AlarmsIn;
GVL_IHM.WinchM1.Encoder.Warnings         := PRG_02_Encoders.instEncoderAbsM1.WarningsIn;
GVL_IHM.WinchM1.Encoder.SlaveOperational := PRG_02_Encoders.instEncoderAbsM1.SlaveOperational;
GVL_IHM.WinchM1.Encoder.PresetTriggerCmd := PRG_02_Encoders.instEncoderAbsM1.PresetTriggerCmd;
GVL_IHM.WinchM1.Encoder.PresetValueOut   := PRG_02_Encoders.instEncoderAbsM1.PresetValueOut;
GVL_IHM.WinchM1.Encoder.Error            := PRG_02_Encoders.instEncoderAbsM1.Error;
GVL_IHM.WinchM1.Encoder.ErrorId          := PRG_02_Encoders.instEncoderAbsM1.ErrorId;
GVL_IHM.WinchM1.SafetyError              := PRG_03_Safety.instSafetyWinchM1.Error;
GVL_IHM.WinchM1.SafetyErrorId            := PRG_03_Safety.instSafetyWinchM1.ErrorId;
GVL_IHM.WinchM1.MecaADriftM              := PRG_03_Safety.instSafetyWinchM1.MecaADriftM;      // 🆕 REX 2026-07-08
GVL_IHM.WinchM1.MecaCDriftM              := PRG_03_Safety.instSafetyWinchM1.MecaCDriftM;      // 🆕 REX 2026-07-08
GVL_IHM.WinchM1.MecaBElapsedTime         := PRG_03_Safety.instSafetyWinchM1.MecaBElapsedTime; // 🆕 REX 2026-07-08
GVL_IHM.WinchM1.InhibitActive            := PRG_04_Modes.instModes.InhibitM1; // 🆕 REX 2026-07-08


// ── 6. MAPPING ÉTATS TREUIL M2 → IHM ─────────────────────────────────────
GVL_IHM.WinchM2.PositionM                := PRG_02_Encoders.instEncoderScaleM2.CablePosM;
GVL_IHM.WinchM2.SpeedRefPct              := PRG_06_WinchControl.instWinchM2.SpeedRamp.Current;
GVL_IHM.WinchM2.StepNumber               := PRG_06_WinchControl.instWinchM2.StepNumber;
GVL_IHM.WinchM2.FBState                  := PRG_06_WinchControl.instWinchM2.State;
GVL_IHM.WinchM2.Ready                    := PRG_06_WinchControl.instWinchM2.Ready;
GVL_IHM.WinchM2.Busy                     := PRG_06_WinchControl.instWinchM2.Busy;
GVL_IHM.WinchM2.Done                     := PRG_06_WinchControl.instWinchM2.Done;
GVL_IHM.WinchM2.Error                    := PRG_06_WinchControl.instWinchM2.Error;
GVL_IHM.WinchM2.ErrorId                  := PRG_06_WinchControl.instWinchM2.ErrorId;
GVL_IHM.WinchM2.RelayFwd                 := PRG_06_WinchControl.instWinchM2.RelayFwd;
GVL_IHM.WinchM2.RelayRev                 := PRG_06_WinchControl.instWinchM2.RelayRev;
GVL_IHM.WinchM2.Contactor1               := PRG_06_WinchControl.instWinchM2.Contactor1;
GVL_IHM.WinchM2.Contactor2               := PRG_06_WinchControl.instWinchM2.Contactor2;
GVL_IHM.WinchM2.Contactor3               := PRG_06_WinchControl.instWinchM2.Contactor3;
GVL_IHM.WinchM2.Contactor4               := PRG_06_WinchControl.instWinchM2.Contactor4;
GVL_IHM.WinchM2.BrakeCmd                 := PRG_06_WinchControl.instWinchM2.BrakeCmd;
GVL_IHM.WinchM2.Homed                    := PRG_02_Encoders.instHomingM2.Homed;
GVL_IHM.WinchM2.SafeStopActive           := PRG_03_Safety.instSafetyWinchM2.SafeStop;
GVL_IHM.WinchM2.ForbidDescentActive      := PRG_06_WinchControl.ForbidDescentM2_Active;
GVL_IHM.WinchM2.ForbidAscentActive       := PRG_03_Safety.instSafetyWinchM2.ForbidAscent;
GVL_IHM.WinchM2.SlackCableDetected       := NOT PRG_00_Inputs.SlackCableSwitch;
GVL_IHM.WinchM2.ThermalFault             := NOT PRG_00_Inputs.M2ThermalFeedback;
GVL_IHM.WinchM2.EncoderFault             := NOT PRG_02_Encoders.instEncoderAbsM2.EncoderAvailable OR PRG_02_Encoders.instEncoderSafetyM2.EncoderIncoherent;
GVL_IHM.WinchM2.CableLimitDescentReached := (PRG_03_Safety.instSafetyWinchM2.ErrorId AND 16#0040) <> 16#0000;
GVL_IHM.WinchM2.ContactorsCheck          := PRG_06_WinchControl.instWinchM2.ContactorsCheck; // 🔧 REX 2026-07-07
GVL_IHM.WinchM2.BrakeContactorCheck      := PRG_06_WinchControl.instWinchM2.BrakeContactorCheck;

GVL_IHM.WinchM2.Encoder.RawPos           := PRG_02_Encoders.instEncoderAbsM2.RawPos;
GVL_IHM.WinchM2.Encoder.Alarms           := PRG_02_Encoders.instEncoderAbsM2.AlarmsIn;
GVL_IHM.WinchM2.Encoder.Warnings         := PRG_02_Encoders.instEncoderAbsM2.WarningsIn;
GVL_IHM.WinchM2.Encoder.SlaveOperational := PRG_02_Encoders.instEncoderAbsM2.SlaveOperational;
GVL_IHM.WinchM2.Encoder.PresetTriggerCmd := PRG_02_Encoders.instEncoderAbsM2.PresetTriggerCmd;
GVL_IHM.WinchM2.Encoder.PresetValueOut   := PRG_02_Encoders.instEncoderAbsM2.PresetValueOut;
GVL_IHM.WinchM2.Encoder.Error            := PRG_02_Encoders.instEncoderAbsM2.Error;
GVL_IHM.WinchM2.Encoder.ErrorId          := PRG_02_Encoders.instEncoderAbsM2.ErrorId;
GVL_IHM.WinchM2.SafetyError              := PRG_03_Safety.instSafetyWinchM2.Error;
GVL_IHM.WinchM2.SafetyErrorId            := PRG_03_Safety.instSafetyWinchM2.ErrorId;
GVL_IHM.WinchM2.MecaADriftM              := PRG_03_Safety.instSafetyWinchM2.MecaADriftM;      // 🆕 REX 2026-07-08
GVL_IHM.WinchM2.MecaCDriftM              := PRG_03_Safety.instSafetyWinchM2.MecaCDriftM;      // 🆕 REX 2026-07-08
GVL_IHM.WinchM2.MecaBElapsedTime         := PRG_03_Safety.instSafetyWinchM2.MecaBElapsedTime; // 🆕 REX 2026-07-08
GVL_IHM.WinchM2.InhibitActive            := PRG_04_Modes.instModes.InhibitM2; // 🆕 REX 2026-07-08


// ── 7. MAPPING ÉTATS GRAPPIN → IHM ───────────────────────────────────────
GVL_IHM.Grappin.FBState          := PRG_06_WinchControl.instGrappin.State;
GVL_IHM.Grappin.ActiveOffsetM    := PRG_06_WinchControl.instGrappin.ActiveOffsetM;
GVL_IHM.Grappin.M2StartStop      := PRG_06_WinchControl.instGrappin.M2_StartStop;
GVL_IHM.Grappin.M2Direction      := PRG_06_WinchControl.instGrappin.M2_Direction;
GVL_IHM.Grappin.M2ForceSlowSpeed := PRG_06_WinchControl.instGrappin.M2_ForceSlowSpeed;
GVL_IHM.Grappin.Ready            := PRG_06_WinchControl.instGrappin.Ready;
GVL_IHM.Grappin.Busy             := PRG_06_WinchControl.instGrappin.Busy;
GVL_IHM.Grappin.Done             := PRG_06_WinchControl.instGrappin.Done;
GVL_IHM.Grappin.Error            := PRG_06_WinchControl.instGrappin.Error;
GVL_IHM.Grappin.ErrorId          := PRG_06_WinchControl.instGrappin.ErrorId;
GVL_IHM.Grappin.RemainingTravelM := PRG_06_WinchControl.instGrappin.RemainingTravelM; // 🔧 REX 2026-07-07
GVL_IHM.Grappin.CloseReq         := PRG_06_WinchControl.instGrappin.CloseReq; // 🆕 REX 2026-07-08
GVL_IHM.Grappin.OpenReq          := PRG_06_WinchControl.instGrappin.OpenReq;  // 🆕 REX 2026-07-08
// 📊 REX 2026-07-07 : position M2 corrigée de l'offset actif — affichage bargraphe uniquement,
// doit être égale à GVL_IHM.WinchM1.PositionM quand tout est nominal (voir bandeau ST_GrappinHMI).
GVL_IHM.Grappin.M2PositionCorrected := PRG_02_Encoders.instEncoderScaleM2.CablePosM - PRG_06_WinchControl.instGrappin.ActiveOffsetM;
GVL_IHM.Grappin.State            := GVL_PERSISTENT.GrappinState;


// ── 8. MAPPING ÉTATS SYNCHRONISATION → IHM ─────────────────────────────────
GVL_IHM.Sync.DeltaPosM  := PRG_06_WinchControl.instWinchSync.DeltaPosM;
GVL_IHM.Sync.SyncActive := PRG_06_WinchControl.instWinchSync.SyncActive;
GVL_IHM.Sync.SyncWarn   := PRG_06_WinchControl.instWinchSync.SyncWarn;
GVL_IHM.Sync.Ready      := PRG_06_WinchControl.instWinchSync.Ready;
GVL_IHM.Sync.Error      := PRG_06_WinchControl.instWinchSync.Error;
GVL_IHM.Sync.ErrorId    := PRG_06_WinchControl.instWinchSync.ErrorId;
GVL_IHM.Sync.State      := PRG_06_WinchControl.instWinchSync.State;


// ── 9. MAPPING ÉTATS CHARIOT M3 → IHM ────────────────────────────────────
GVL_IHM.Chariot.FBState              := PRG_07_ChariotControl.instChariotM3.State;
GVL_IHM.Chariot.Ready                := PRG_07_ChariotControl.instChariotM3.Ready;
GVL_IHM.Chariot.Busy                 := PRG_07_ChariotControl.instChariotM3.Busy;
GVL_IHM.Chariot.Done                 := PRG_07_ChariotControl.instChariotM3.Done;
GVL_IHM.Chariot.Error                := PRG_07_ChariotControl.instChariotM3.Error;
GVL_IHM.Chariot.ErrorId              := PRG_07_ChariotControl.instChariotM3.ErrorId;
GVL_IHM.Chariot.RelayFwd             := PRG_07_ChariotControl.instChariotM3.RelayFwd;
GVL_IHM.Chariot.RelayRev             := PRG_07_ChariotControl.instChariotM3.RelayRev;
GVL_IHM.Chariot.RelaySpeedGv         := PRG_07_ChariotControl.instChariotM3.RelaySpeedGv;
GVL_IHM.Chariot.BrakeCmd             := PRG_07_ChariotControl.instChariotM3.BrakeCmd;
GVL_IHM.Chariot.BrakeFeedback        := PRG_00_Inputs.M3BrakeFeedback;
GVL_IHM.Chariot.PositionSensorTarget := PRG_07_ChariotControl.M3_PositionSensorTarget;
GVL_IHM.Chariot.DriveStatusWord      := PRG_07_ChariotControl.instChariotM3.DriveStatusWord;
GVL_IHM.Chariot.DriveActualFreqHz    := PRG_07_ChariotControl.instChariotM3.DriveActualFreqHz;
GVL_IHM.Chariot.SafetyError          := PRG_03_Safety.instSafetyChariotM3.Error;
GVL_IHM.Chariot.SafetyErrorId        := PRG_03_Safety.instSafetyChariotM3.ErrorId;


// ── 10. MAPPING ÉTATS JOYSTICK → IHM ─────────────────────────────────────
GVL_IHM.Joystick.RawX       := JoyXRaw_ANA1;
GVL_IHM.Joystick.RawY       := JoyYRaw_ANA2;
GVL_IHM.Joystick.RawButton  := JoyBtnRaw;
GVL_IHM.Joystick.CmdX       := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX;
GVL_IHM.Joystick.CmdY       := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY;
GVL_IHM.Joystick.Online     := PRG_01_Diagnostics.instDiagCanOpen.Joystick.Online;
GVL_IHM.Joystick.Operational := PRG_01_Diagnostics.instDiagCanOpen.Joystick.Operational;
GVL_IHM.Joystick.Error       := PRG_01_Diagnostics.FB_Joystick_0.Error;
GVL_IHM.Joystick.ErrorId     := PRG_01_Diagnostics.FB_Joystick_0.ErrorId;


// ── 11. MAPPING SYSTEM / MODE → IHM ──────────────────────────────────────
GVL_IHM.Modes.CurrentMode     := PRG_04_Modes.instModes.Mode;
GVL_IHM.Modes.EmergencyStopOk := PRG_00_Inputs.EmergencyStopOk;


// ── 12. MAPPING DIAGNOSTICS BUS → IHM ────────────────────────────────────
GVL_IHM.Network.BusCanOpen  := PRG_01_Diagnostics.instDiagCanOpen.busCanOpen;
GVL_IHM.Network.Joystick    := PRG_01_Diagnostics.instDiagCanOpen.Joystick;
GVL_IHM.Network.CanError    := PRG_01_Diagnostics.instDiagCanOpen.Error;
GVL_IHM.Network.CanErrorId  := PRG_01_Diagnostics.instDiagCanOpen.ErrorId;

GVL_IHM.Network.BusEthercat := PRG_01_Diagnostics.instDiagEthercat.BusEthercat;
GVL_IHM.Network.EncoderM1   := PRG_01_Diagnostics.instDiagEthercat.EncoderM1;
GVL_IHM.Network.EncoderM2   := PRG_01_Diagnostics.instDiagEthercat.EncoderM2;
GVL_IHM.Network.VariateurM3 := PRG_01_Diagnostics.instDiagEthercat.Variateur;
GVL_IHM.Network.EcatError   := PRG_01_Diagnostics.instDiagEthercat.Error;
GVL_IHM.Network.EcatErrorId := PRG_01_Diagnostics.instDiagEthercat.ErrorId;
