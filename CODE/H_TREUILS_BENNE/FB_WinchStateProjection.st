(* =======================================================================
   📊 FB_WinchStateProjection — Projection lecture seule des états IHM treuils
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Décharger PRG_04 de la §8 « Publication états IHM » (~250 lignes
      d'assignations pures) en un FB de projection. Recopie bit-identique des
      sources → structs d'état publics (WinchM1State/WinchM2State/
      WinchM1Safety/WinchM2Safety/CableLimitAscent).
   🧬 Responsabilité (1 FB = 1 responsabilité) :
      - Projection pure : recopie de sources → structs d'état publics.
        Aucune logique de commande, aucun calcul de sécurité.
      - Producteur unique : les structs d'état restent produits par PRG_04
        (via ce FB), consommés par PRG_07/IHM.
   🔒 Non-régression : chaque assignation de la §8 de PRG_04 est déplacée
      telle quelle (bit-identique, aucune logique modifiée).
   📄 Doc : DOC/WFLOW/AUDITS/FB_WinchStateProjection_DESIGN.md 
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_WinchStateProjection
VAR_IN_OUT
    // === SOURCES (références lecture seule — le FB ne commande rien) ===
    EncoderM1        : ST_AcquisitionEncoderQualified; // 🧲 Façade codeur M1 (PRG_02_Acquisition.Data.EncoderM1)
    EncoderM2        : ST_AcquisitionEncoderQualified; // 🧲 Façade codeur M2 (PRG_02_Acquisition.Data.EncoderM2)
    WinchM1Ref       : FB_Winch;                       // 🪝 FB_Winch M1 (instWinchM1)
    WinchM2Ref       : FB_Winch;                       // 🪝 FB_Winch M2 (instWinchM2)
    SafetyM1         : FB_Safety_Winch;                // 🛡️ FB_Safety_Winch M1 (instSafetyWinchM1)
    SafetyM2         : FB_Safety_Winch;                // 🛡️ FB_Safety_Winch M2 (instSafetyWinchM2)
    InterlockM1      : FB_WinchOutputInterlock;        // 🛡️ Barrière finale M1 (PRG_06_Outputs.instWinchOutputInterlockM1)
    InterlockM2      : FB_WinchOutputInterlock;        // 🛡️ Barrière finale M2 (PRG_06_Outputs.instWinchOutputInterlockM2)
    Auth             : ST_Modes_Autorisations;         // 🎛️ Autorisations mode (PRG_03_Modes_Cycle.Data.Auth)
    HwInWinch        : ST_HwWinch;                     // 🏗️ Image matérielle arbitrée (PRG_02_Acquisition.HwIn.Winch)
    HwRealWinch      : ST_HwWinch;                     // 🏗️ Image matérielle réelle (PRG_02_Acquisition.HwReal.Winch)
    // Mémoire scan précédent pour SpeedDelta_Mps (delta vitesse entre 2 scans)
    M1_PrevSpeed_Mps : REAL;
    M2_PrevSpeed_Mps : REAL;
END_VAR
VAR_INPUT
    // === LOCAUX / DIAGNOSTICS ===
    M1LogicRequestSpeedCmd_Pct : REAL;  // 📈 Diagnostic % M1 (palier→%, IHM / simu)
    M2LogicRequestSpeedCmd_Pct : REAL;  // 📈 Diagnostic % M2 (palier→%, IHM / simu)
    BottomLimitM1_Active       : REAL;  // 📏 Limite basse active M1 (m)
    BottomLimitM2_Active       : REAL;  // 📏 Limite basse active M2 (m)
    SafeStopM1_Active          : BOOL;  // 🟧 Arrêt rapide M1 actif
    SafeStopM2_Active          : BOOL;  // 🟧 Arrêt rapide M2 actif
    EffectivePermitM1_Ascent   : BOOL;  // 🟢 Permis effectif montée M1
    EffectivePermitM1_Descend  : BOOL;  // 🟢 Permis effectif descente M1
    EffectivePermitM2_Ascent   : BOOL;  // 🟢 Permis effectif montée M2
    EffectivePermitM2_Descend  : BOOL;  // 🟢 Permis effectif descente M2
    M2_LimitShift              : REAL;  // 📐 Décalage benne M2 (m)

    // === CONFIG ===
    CfgCableLimitAscent_M      : REAL;  // ⛔ Limite haute exploitation normale (m)
    CfgCableLimitDescentM1_M   : REAL;  // ⛔ Limite basse câble M1 (m)
    CfgCableLimitDescentM2_M   : REAL;  // ⛔ Limite basse câble M2 (m)

    // === RÉSEAU / DIAGNOSTICS ===
    EncoderM1_Operational      : BOOL;  // 🧲 Esclave EtherCAT COD1 opérationnel
    EncoderM2_Operational      : BOOL;  // 🧲 Esclave EtherCAT COD2 opérationnel
    M1PowerCutOffSafetyInfo    : BOOL;  // 🧨 Sécurités M1 coupant la puissance
    M1SafeStopSafetyInfo       : BOOL;  // 🛡️ Sécurités M1 SafeStop
    M1BlockedBySafetyInfo      : BOOL;  // 🚫 M1 bloqué par sécurité
    M2PowerCutOffSafetyInfo    : BOOL;  // 🧨 Sécurités M2 coupant la puissance
    M2SafeStopSafetyInfo       : BOOL;  // 🛡️ Sécurités M2 SafeStop
    M2BlockedBySafetyInfo      : BOOL;  // 🚫 M2 bloqué par sécurité
END_VAR
VAR_OUTPUT
    // === STRUCTS D'ÉTAT PUBLICS (remplis, produits par PRG_04 via ce FB) ===
    WinchM1State               : ST_WinchState;   // 🚦 État public treuil Retenue M1
    WinchM2State               : ST_WinchState;   // 🚦 État public treuil Benne M2
    WinchM1Safety              : ST_SafetyWinch;  // 🛡️ Diagnostic et sécurités treuil M1
    WinchM2Safety              : ST_SafetyWinch;  // 🛡️ Diagnostic et sécurités treuil M2
    CableLimitAscentM1Reached  : BOOL;             // ⛔ Limite haute M1 atteinte (fait pur)
    CableLimitAscentM2Reached  : BOOL;             // ⛔ Limite haute M2 atteinte (fait pur)
END_VAR

// ═══════════════════════════════════════════════════════════════════════════
// 📊 PROJECTION ÉTATS IHM (recopie bit-identique de la §8 de PRG_04)
// ═══════════════════════════════════════════════════════════════════════════

// ── M1 : état public ────────────────────────────────────────────────────────
// SpeedDelta_Mps = variation de vitesse ENTRE DEUX SCANS (ST_WinchState.st),
// pas un écart M1/M2 (qui existe via SyncStateHMI.DeltaPos_M/instWinchSync).
// Delta temporel via mémoire scan précédent.
WinchM1State.MeasuredSpeed_Mps := EncoderM1.Measurement.Speed_Mps;
WinchM1State.SpeedDelta_Mps    := EncoderM1.Measurement.Speed_Mps - M1_PrevSpeed_Mps;
M1_PrevSpeed_Mps := EncoderM1.Measurement.Speed_Mps;

WinchM1State.Position_M := EncoderM1.Measurement.CablePosM;
WinchM1State.SpeedCmd_Pct := M1LogicRequestSpeedCmd_Pct;
WinchM1State.StepNumber := WinchM1Ref.StepNumber;
IF WinchM1Ref.Fault.Error THEN
    WinchM1State.FBState := E_State.ERROR;
ELSIF WinchM1Ref.StepNumber > 0 THEN
    WinchM1State.FBState := E_State.BUSY;
ELSE
    WinchM1State.FBState := E_State.READY;
END_IF;
WinchM1State.Ready := WinchM1Ref.Ready;
WinchM1State.Busy := (WinchM1Ref.StepNumber > 0);
WinchM1State.Done := FALSE;
WinchM1State.Error := WinchM1Ref.Fault.Error;
WinchM1State.ErrorId := WinchM1Ref.Fault.ErrorId;
WinchM1State.RelayFwd := WinchM1Ref.RelayFwd;
WinchM1State.RelayRev := WinchM1Ref.RelayRev;
WinchM1State.Contactor1 := WinchM1Ref.Contactor1;
WinchM1State.Contactor2 := WinchM1Ref.Contactor2;
WinchM1State.Contactor3 := WinchM1Ref.Contactor3;
WinchM1State.Contactor4 := WinchM1Ref.Contactor4;
WinchM1State.BrakeCmd := InterlockM1.BrakeCmd;
WinchM1State.BrakeCommandOpenConfirmed := HwInWinch.M1_BrakeIsOpen_DI;
WinchM1State.FinalAuthorizedStep := WinchM1Ref.RequestedStep;
WinchM1State.ContactorsCheck := WinchM1Ref.ContactorsCheck;
WinchM1State.FinalInterlockState := InterlockM1.State;
WinchM1State.FinalInterlockReason := InterlockM1.Reason;
WinchM1State.FinalInterlockError := InterlockM1.Fault.Error;
WinchM1State.FinalInterlockErrorId := InterlockM1.Fault.ErrorId;
WinchM1State.FinalRestartInhibit := InterlockM1.RestartInhibit;
WinchM1State.FinalBrakeTimeoutElapsed := InterlockM1.BrakeTimeoutElapsed;
WinchM1State.FinalRestartDelayElapsed := InterlockM1.RestartDelayElapsed;
WinchM1State.FinalStepDelayElapsed := InterlockM1.StepDelayElapsed;
WinchM1State.Encoder.RawPos := EncoderM1.Measurement.RawPos;
WinchM1State.Encoder.Alarms := HwRealWinch.COD1_Alarms;
WinchM1State.Encoder.Warnings := HwRealWinch.COD1_Warnings;
WinchM1State.Encoder.SlaveOperational := EncoderM1_Operational;
WinchM1State.Encoder.PresetTriggerCmd := EncoderM1.HwOut.PresetTriggerCmd;
WinchM1State.Encoder.PresetValueOut := EncoderM1.HwOut.PresetValueOut;
WinchM1State.Encoder.Error := EncoderM1.Measurement.AbsFault.Error;
WinchM1State.Encoder.ErrorId := EncoderM1.Measurement.AbsFault.ErrorId;
WinchM1State.Encoder.Homed := EncoderM1.Homed;
WinchM1State.Encoder.HomingBusy := EncoderM1.Measurement.HomingLifecycle.Busy;
WinchM1State.Encoder.HomingDone := EncoderM1.Measurement.HomingLifecycle.Done;
WinchM1State.Encoder.HomingError := EncoderM1.Measurement.HomingFault.Error;
WinchM1State.Encoder.HomingErrorId := EncoderM1.Measurement.HomingFault.ErrorId;
WinchM1State.Encoder.HomingState := E_State.READY;
WinchM1State.Encoder.HomingStateAtError := E_State.DISABLED;
WinchM1State.Encoder.HomingSuspect := EncoderM1.HomingSuspect;
WinchM1State.Encoder.HomingRefRaw := EncoderM1.Measurement.HomingRefRaw;
WinchM1State.InhibitActive := Auth.InhibitM1;
WinchM1State.BottomLimitActiveM := BottomLimitM1_Active;
WinchM1State.InTopSlowdownZone := WinchM1Ref.InTopSlowdownZone;
WinchM1State.InBottomSlowdownZone := WinchM1Ref.InBottomSlowdownZone;
WinchM1State.CommandedDirection := WinchM1Ref.CommandedDirection;
WinchM1State.DirectionChangeDelayElapsed := WinchM1Ref.DirectionChangeDelayElapsed;
WinchM1State.DirectionChangePending := WinchM1Ref.DirectionChangePending;

// ── M2 : état public (voir bandeau M1 ci-dessus) ────────────────────────────
WinchM2State.MeasuredSpeed_Mps := EncoderM2.Measurement.Speed_Mps;
WinchM2State.SpeedDelta_Mps    := EncoderM2.Measurement.Speed_Mps - M2_PrevSpeed_Mps;
M2_PrevSpeed_Mps := EncoderM2.Measurement.Speed_Mps;

WinchM2State.Position_M := EncoderM2.Measurement.CablePosM;
WinchM2State.SpeedCmd_Pct := M2LogicRequestSpeedCmd_Pct;
WinchM2State.StepNumber := WinchM2Ref.StepNumber;
IF WinchM2Ref.Fault.Error THEN
    WinchM2State.FBState := E_State.ERROR;
ELSIF WinchM2Ref.StepNumber > 0 THEN
    WinchM2State.FBState := E_State.BUSY;
ELSE
    WinchM2State.FBState := E_State.READY;
END_IF;
WinchM2State.Ready := WinchM2Ref.Ready;
WinchM2State.Busy := (WinchM2Ref.StepNumber > 0);
WinchM2State.Done := FALSE;
WinchM2State.Error := WinchM2Ref.Fault.Error;
WinchM2State.ErrorId := WinchM2Ref.Fault.ErrorId;
WinchM2State.RelayFwd := WinchM2Ref.RelayFwd;
WinchM2State.RelayRev := WinchM2Ref.RelayRev;
WinchM2State.Contactor1 := WinchM2Ref.Contactor1;
WinchM2State.Contactor2 := WinchM2Ref.Contactor2;
WinchM2State.Contactor3 := WinchM2Ref.Contactor3;
WinchM2State.Contactor4 := WinchM2Ref.Contactor4;
WinchM2State.BrakeCmd := InterlockM2.BrakeCmd;
WinchM2State.BrakeCommandOpenConfirmed := HwInWinch.M2_BrakeIsOpen_DI;
WinchM2State.FinalAuthorizedStep := WinchM2Ref.RequestedStep;
WinchM2State.ContactorsCheck := WinchM2Ref.ContactorsCheck;
WinchM2State.FinalInterlockState := InterlockM2.State;
WinchM2State.FinalInterlockReason := InterlockM2.Reason;
WinchM2State.FinalInterlockError := InterlockM2.Fault.Error;
WinchM2State.FinalInterlockErrorId := InterlockM2.Fault.ErrorId;
WinchM2State.FinalRestartInhibit := InterlockM2.RestartInhibit;
WinchM2State.FinalBrakeTimeoutElapsed := InterlockM2.BrakeTimeoutElapsed;
WinchM2State.FinalRestartDelayElapsed := InterlockM2.RestartDelayElapsed;
WinchM2State.FinalStepDelayElapsed := InterlockM2.StepDelayElapsed;
WinchM2State.Encoder.RawPos := EncoderM2.Measurement.RawPos;
WinchM2State.Encoder.Alarms := HwRealWinch.COD2_Alarms;
WinchM2State.Encoder.Warnings := HwRealWinch.COD2_Warnings;
WinchM2State.Encoder.SlaveOperational := EncoderM2_Operational;
WinchM2State.Encoder.PresetTriggerCmd := EncoderM2.HwOut.PresetTriggerCmd;
WinchM2State.Encoder.PresetValueOut := EncoderM2.HwOut.PresetValueOut;
WinchM2State.Encoder.Error := EncoderM2.Measurement.AbsFault.Error;
WinchM2State.Encoder.ErrorId := EncoderM2.Measurement.AbsFault.ErrorId;
WinchM2State.Encoder.Homed := EncoderM2.Homed;
WinchM2State.Encoder.HomingBusy := EncoderM2.Measurement.HomingLifecycle.Busy;
WinchM2State.Encoder.HomingDone := EncoderM2.Measurement.HomingLifecycle.Done;
WinchM2State.Encoder.HomingError := EncoderM2.Measurement.HomingFault.Error;
WinchM2State.Encoder.HomingErrorId := EncoderM2.Measurement.HomingFault.ErrorId;
WinchM2State.Encoder.HomingState := E_State.READY;
WinchM2State.Encoder.HomingStateAtError := E_State.DISABLED;
WinchM2State.Encoder.HomingSuspect := EncoderM2.HomingSuspect;
WinchM2State.Encoder.HomingRefRaw := EncoderM2.Measurement.HomingRefRaw;
WinchM2State.InhibitActive := Auth.InhibitM2;
WinchM2State.BottomLimitActiveM := BottomLimitM2_Active;
WinchM2State.InTopSlowdownZone := WinchM2Ref.InTopSlowdownZone;
WinchM2State.InBottomSlowdownZone := WinchM2Ref.InBottomSlowdownZone;
WinchM2State.CommandedDirection := WinchM2Ref.CommandedDirection;
WinchM2State.DirectionChangeDelayElapsed := WinchM2Ref.DirectionChangeDelayElapsed;
WinchM2State.DirectionChangePending := WinchM2Ref.DirectionChangePending;

// ── Limite haute atteinte (fait public) ──────────────────────────────────────
// ⛔️ Miroir de la butée logicielle de AscentPermit (Homed, hors homing, non
// suspect, position >= limite). Fait pur "Reached", sans bypass.
CableLimitAscentM1Reached := EncoderM1.Homed
    AND NOT EncoderM1.HomingSuspect
    AND NOT EncoderM1.Measurement.HomingLifecycle.Busy
    AND (EncoderM1.Measurement.CablePosM >= CfgCableLimitAscent_M);
CableLimitAscentM2Reached := EncoderM2.Homed
    AND NOT EncoderM2.HomingSuspect
    AND NOT EncoderM2.Measurement.HomingLifecycle.Busy
    AND (EncoderM2.Measurement.CablePosM >= (CfgCableLimitAscent_M + M2_LimitShift));

// ── M1 : sécurités publiques ────────────────────────────────────────────────
WinchM1Safety.CableLimitAscent := CableLimitAscentM1Reached;
WinchM1Safety.CableLimitDescent := (EncoderM1.Measurement.CablePosM <= CfgCableLimitDescentM1_M);
WinchM1Safety.SafeStop := SafeStopM1_Active;
WinchM1Safety.AscentPermit := EffectivePermitM1_Ascent;
WinchM1Safety.DescendPermit := EffectivePermitM1_Descend;
WinchM1Safety.ThermalFault := NOT HwInWinch.M1_ThermalOk_DI;
WinchM1Safety.PowerCutOff := SafetyM1.PowerCutOff;
WinchM1Safety.Error := WinchM1Ref.Fault.Error OR SafetyM1.Fault.Error;
WinchM1Safety.ErrorId := SafetyM1.Fault.ErrorId;
WinchM1Safety.LatchedId := SafetyM1.Fault.LatchedId;
WinchM1Safety.ErrorOperatorComm  := (SafetyM1.Fault.ErrorId AND 16#0001) <> 0;
WinchM1Safety.ErrorEncoder       := (SafetyM1.Fault.ErrorId AND 16#0002) <> 0;
WinchM1Safety.ErrorPhaseRotation := (SafetyM1.Fault.ErrorId AND 16#0010) <> 0;
WinchM1Safety.ErrorBrakeThermal  := (SafetyM1.Fault.ErrorId AND 16#0400) <> 0;
WinchM1Safety.ErrorMecaA         := (SafetyM1.Fault.ErrorId AND 16#0080) <> 0;
WinchM1Safety.ErrorMecaB         := (SafetyM1.Fault.ErrorId AND 16#0100) <> 0;
WinchM1Safety.ErrorMecaC         := (SafetyM1.Fault.ErrorId AND 16#0200) <> 0;
WinchM1Safety.ErrorMecaD         := (SafetyM1.Fault.ErrorId AND 16#0800) <> 0;
WinchM1Safety.ErrorMecaE         := (SafetyM1.Fault.ErrorId AND 16#3000) <> 0;
WinchM1Safety.ErrorOppositeDir   := (SafetyM1.Fault.ErrorId AND 16#4000) <> 0;
WinchM1Safety.ErrorNoMovement    := (SafetyM1.Fault.ErrorId AND 16#8000) <> 0;
WinchM1Safety.PowerCutOffSafety  := M1PowerCutOffSafetyInfo;
WinchM1Safety.SafeStopSafety     := M1SafeStopSafetyInfo;
WinchM1Safety.BlockedBySafety    := M1BlockedBySafetyInfo;

// ── M2 : sécurités publiques ───────────────────────────────────────────────
WinchM2Safety.CableLimitAscent := CableLimitAscentM2Reached;
WinchM2Safety.CableLimitDescent := (EncoderM2.Measurement.CablePosM <= CfgCableLimitDescentM2_M);
WinchM2Safety.SafeStop := SafeStopM2_Active;
WinchM2Safety.AscentPermit := EffectivePermitM2_Ascent;
WinchM2Safety.DescendPermit := EffectivePermitM2_Descend;
WinchM2Safety.SlackCable := NOT HwInWinch.M2_TensionedCable_DI;
WinchM2Safety.ThermalFault := NOT HwInWinch.M2_ThermalOk_DI;
WinchM2Safety.PowerCutOff := SafetyM2.PowerCutOff;
WinchM2Safety.Error := WinchM2Ref.Fault.Error OR SafetyM2.Fault.Error;
WinchM2Safety.ErrorId := SafetyM2.Fault.ErrorId;
WinchM2Safety.LatchedId := SafetyM2.Fault.LatchedId;
WinchM2Safety.ErrorOperatorComm  := (SafetyM2.Fault.ErrorId AND 16#0001) <> 0;
WinchM2Safety.ErrorEncoder       := (SafetyM2.Fault.ErrorId AND 16#0002) <> 0;
WinchM2Safety.ErrorPhaseRotation := (SafetyM2.Fault.ErrorId AND 16#0010) <> 0;
WinchM2Safety.ErrorBrakeThermal  := (SafetyM2.Fault.ErrorId AND 16#0400) <> 0;
WinchM2Safety.ErrorMecaA         := (SafetyM2.Fault.ErrorId AND 16#0080) <> 0;
WinchM2Safety.ErrorMecaB         := (SafetyM2.Fault.ErrorId AND 16#0100) <> 0;
WinchM2Safety.ErrorMecaC         := (SafetyM2.Fault.ErrorId AND 16#0200) <> 0;
WinchM2Safety.ErrorMecaD         := (SafetyM2.Fault.ErrorId AND 16#0800) <> 0;
WinchM2Safety.ErrorMecaE         := (SafetyM2.Fault.ErrorId AND 16#3000) <> 0;
WinchM2Safety.ErrorOppositeDir   := (SafetyM2.Fault.ErrorId AND 16#4000) <> 0;
WinchM2Safety.ErrorNoMovement    := (SafetyM2.Fault.ErrorId AND 16#8000) <> 0;
WinchM2Safety.PowerCutOffSafety  := M2PowerCutOffSafetyInfo;
WinchM2Safety.SafeStopSafety     := M2SafeStopSafetyInfo;
WinchM2Safety.BlockedBySafety    := M2BlockedBySafetyInfo;
