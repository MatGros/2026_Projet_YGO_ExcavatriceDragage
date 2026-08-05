(* ═══════════════════════════════════════════════════════════════
   ↔️ PRG_05_Translation — Pilotage de la Translation M3
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 5 (après PRG_04_Treuils_Benne).
   ✅ Arbitre entre les commandes Manuelles (Joystick) et Automatiques (PRG_03_Modes_Cycle).
   📄 Docs : DOC/AF_Partie-11_Fonction_Translation_v2.1.md
   🛡️ Sécurité : instSafetyTranslationM3 (FB_Safety_Translation) câblée en parallèle
      de instTranslationM3 depuis le 2026-08-05 (lot M4) — SafeStop/PowerCutOff réels.
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_05_Translation

VAR_OUTPUT
    TranslationFinalInterlockRequest : ST_TranslationFinalInterlockRequest;
    TranslationStateHMI : ST_TranslationState;
    TranslationSafetyHMI : ST_SafetyTranslation;
END_VAR

VAR
    instTranslationM3           : FB_Translation;
    instSafetyTranslationM3     : FB_Safety_Translation;

    M3_StartStop_Active     : BOOL;
    M3_Direction_Active     : INT;
    M3_SpeedRef_Active      : REAL;
    M3_PositioningActive    : BOOL;
    M3_PositionSensorTarget : BOOL;

    SelTarget       : INT;
    FreqPct                 : REAL;

    M3_SafeStop_Active      : BOOL; // Cause historique : InputModuleFault (AF06 §3bis)
    M3_SafeStop_Aggregate   : BOOL; // 🛡️ SafeStop réellement appliqué au mouvement = InputModuleFault OR safety M3 (8 mécanismes)
END_VAR

// === 🔀 §1 ARBITRAGE DU SÉLECTEUR DE CIBLE ET DE LA DIRECTION ===

IF PRG_03_Modes_Cycle.Auth.Mode = E_Mode.SEMI_AUTO THEN
    M3_PositioningActive  := TRUE;
    SelTarget    := 0;
    M3_StartStop_Active  := FALSE;
    M3_SpeedRef_Active   := 0.0;

    IF SelTarget = 1 THEN
        M3_Direction_Active := 1;
    ELSE
        M3_Direction_Active := -1;
    END_IF;
ELSIF (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N1)
   OR (PRG_03_Modes_Cycle.Auth.Mode = E_Mode.MAINT_N2) THEN
    M3_PositioningActive := GVL_IHM.TranslationM3.Cmd.SelPositioning;
    SelTarget := 0;

    IF NOT GVL_IHM.TranslationM3.Cmd.TglJoystickMaster AND GVL_IHM.TranslationM3.Cmd.BtnFwd THEN
        M3_Direction_Active := 1;
    ELSIF NOT GVL_IHM.TranslationM3.Cmd.TglJoystickMaster AND GVL_IHM.TranslationM3.Cmd.BtnRev THEN
        M3_Direction_Active := -1;
    ELSIF GVL_IHM.TranslationM3.Cmd.TglJoystickMaster THEN
        M3_Direction_Active := 0;
    ELSE
        M3_Direction_Active := 0;
    END_IF;

    M3_StartStop_Active := (M3_Direction_Active <> 0)
                           AND (GVL_IHM.TranslationM3.Bypass.Global
                                OR NOT GVL_IHM.TranslationM3.Cmd.TglJoystickMaster);

    FreqPct := SEL(GVL_IHM.TranslationM3.Cmd.SetFreq_Hz > 0.0,
                  (GVL_IHM.TranslationM3.Cmd.SetFreq_Hz / _TranslationMaxFreq_Hz) * 100.0,
                  30.0);
    M3_SpeedRef_Active := SEL(GVL_IHM.TranslationM3.Cmd.TglJoystickMaster,
                              FreqPct,
                              0.0);
ELSE
    M3_PositioningActive := FALSE;
    SelTarget    := 0;
    M3_StartStop_Active  := FALSE;
    M3_Direction_Active  := 0;
    M3_SpeedRef_Active   := 0.0;
END_IF;

IF GVL_IHM.TranslationM3.Cmd.InvertDirection THEN
    M3_Direction_Active := M3_Direction_Active * (-1);
END_IF;

M3_SpeedRef_Active := LIMIT(0.0, ABS(M3_SpeedRef_Active), 100.0);

IF (SelTarget = 4) AND NOT PRG_03_Modes_Cycle.Auth.MaintenanceM3TargetEnable THEN
    SelTarget := 0;
END_IF;

// 🩺 InputModuleFault (AF06 §3bis) : un module DI TOR hors service rend indisponibles
// les retours frein/thermique/positions du VH_0808ETP/VH_0800END portant M3 — rampe rapide.
M3_SafeStop_Active := PRG_02_Acquisition.InputModuleFault;

CASE SelTarget OF
    1: M3_PositionSensorTarget := PRG_02_Acquisition.TranslationPosTremie;
    2: M3_PositionSensorTarget := PRG_02_Acquisition.TranslationPosP2;
    3: M3_PositionSensorTarget := PRG_02_Acquisition.TranslationPosP1;
    4: M3_PositionSensorTarget := PRG_02_Acquisition.TranslationPosMaintenance;
ELSE
    M3_PositionSensorTarget := FALSE;
END_CASE;


// === 🛡️ §1bis SÉCURITÉ M3 (FB_Safety_Translation, câblée en parallèle visible) ===
// ⚠️ Ordre d'appel volontaire : la safety lit ici le BrakeReleaseRequest et le
// BrakeCmd du SCAN PRÉCÉDENT d'instTranslationM3 (elle est appelée avant), exactement
// le même retard d'un scan que documenté en AF_Partie-11 §5 alerte 4 pour l'ancien
// code CFC — non éliminé par ce lot (nécessite la fusion CFC complète, lot M4 migration
// 7 POU, hors périmètre). Bénin : BrakeReleaseRequest ne change pas plus vite qu'un
// scan MainTask 10 ms sur une commande frein.
instSafetyTranslationM3(
    Enable                  := (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE),
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := PRG_03_Modes_Cycle.Auth.Mode,
    JoystickOnline          := PRG_07_Supervision.instDiagCanOpen.DeviceJoystick.Online,
    JoystickOperational     := PRG_07_Supervision.instDiagCanOpen.DeviceJoystick.Operational,
    HeartbeatIhmOk          := GVL_IHM.Commun.HeartbeatIhmOk,
    PhaseRotationOk         := PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI,
    BrakeThermalFeedback    := NOT PRG_02_Acquisition.HwIn.Machine.BrakeThermalOk_DI,
    DriveOnline             := PRG_07_Supervision.instDiagEthercat.DeviceVariateur.Online,
    DriveOperational        := PRG_07_Supervision.instDiagEthercat.DeviceVariateur.Operational,
    DriveStatusWord         := PRG_02_Acquisition.M3_StatusWord_Filtered,
    DriveActualFreqHz       := UINT_TO_REAL(PRG_02_Acquisition.M3_ActualFrequencyHz_Filtered) / 100.0,
    BrakeFeedback           := SEL(GVL_IHM.TranslationM3.Bypass.ContactorFeedback OR GVL_IHM.TranslationM3.Bypass.Global, PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI, instTranslationM3.BrakeReleaseRequest),
    BrakeCmd                := instTranslationM3.BrakeReleaseRequest,
    Direction               := M3_Direction_Active,
    LimitSwitchFwd          := PRG_02_Acquisition.M3_LimitSwitchFwd,
    LimitSwitchRev          := PRG_02_Acquisition.M3_LimitSwitchRev,
    SensorWordIncoherent    := PRG_02_Acquisition.M3_SensorWordIncoherent,
    BypassGlobal            := GVL_IHM.TranslationM3.Bypass.Global,
    BypassOperatorComm      := GVL_IHM.TranslationM3.Bypass.OperatorComm,
    BypassDriveComm         := GVL_IHM.TranslationM3.Bypass.DriveComm,
    BypassPhaseRotation     := GVL_IHM.TranslationM3.Bypass.PhaseRotation,
    BypassBrakeThermal      := GVL_IHM.TranslationM3.Bypass.BrakeThermal,
    BypassMecaB             := GVL_IHM.TranslationM3.Bypass.MecaB,
    BypassMecaA             := GVL_IHM.TranslationM3.Bypass.MecaA,
    BypassLimitSwitch       := GVL_IHM.TranslationM3.Bypass.LimitSwitch,
    BypassSensorIncoherent  := GVL_IHM.TranslationM3.Bypass.SensorIncoherent,
    BypassSafety            := GVL_IHM.TranslationM3.Bypass.Safety,
    BypassProcess           := GVL_IHM.TranslationM3.Bypass.Process
);

// SafeStop réellement appliqué au mouvement = agrégat InputModuleFault (historique)
// OR safety M3 (8 mécanismes) — aucune des deux causes ne doit être perdue.
M3_SafeStop_Aggregate := M3_SafeStop_Active OR instSafetyTranslationM3.SafeStop;

// === ⚙️ §2 EXÉCUTION PILOTAGE TRANSLATION M3 ===

instTranslationM3(
    Enable                  := (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE),
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := PRG_03_Modes_Cycle.Auth.Mode,
    StartStop               := M3_StartStop_Active,
    SafeStop                := M3_SafeStop_Aggregate,
    Direction               := M3_Direction_Active,
    SpeedRefPct             := M3_SpeedRef_Active,
    PositionSensorTarget    := M3_PositionSensorTarget,
    SlowdownSensor          := PRG_02_Acquisition.TranslationPosPV,
    LimitSwitchFwd          := PRG_02_Acquisition.M3_LimitSwitchFwd,
    LimitSwitchRev          := PRG_02_Acquisition.M3_LimitSwitchRev,
    DriveStatusWord         := PRG_02_Acquisition.M3_StatusWord_Filtered,
    DriveActualFreqHz       := UINT_TO_REAL(PRG_02_Acquisition.M3_ActualFrequencyHz_Filtered) / 100.0,
    CfgRampAccelRate        := _TranslationRampAccelRate_Pct,
    CfgRampDecelNormalRate  := _TranslationRampDecelNormal_Pct,
    CfgRampDecelFastRate    := _TranslationRampDecelFast_Pct,
    DriveFreqScaleMaxHz     := _TranslationMaxFreq_Hz,
    BrakeFeedback           := SEL(GVL_IHM.TranslationM3.Bypass.ContactorFeedback OR GVL_IHM.TranslationM3.Bypass.Global, PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI, instTranslationM3.BrakeReleaseRequest),
    BypassContactorCheck    := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.ContactorFeedback,
    BypassLimitSwitch       := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.LimitSwitch
);


// === 📤 §3 PUBLICATION DEMANDE BRUTE TRANSLATION ===

TranslationFinalInterlockRequest.Enable := (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE);
TranslationFinalInterlockRequest.Reset := PRG_07_Supervision.FaultMachineReset_IHM;
TranslationFinalInterlockRequest.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
TranslationFinalInterlockRequest.SafeStop := M3_SafeStop_Aggregate;
TranslationFinalInterlockRequest.PowerCutOff := instSafetyTranslationM3.PowerCutOff;
TranslationFinalInterlockRequest.BrakeReleaseRequest := instTranslationM3.BrakeReleaseRequest;
TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed := instTranslationM3.BrakeCommandOpenConfirmed;
TranslationFinalInterlockRequest.RequestedDriveControlWord := instTranslationM3.RequestedDriveControlWord;
TranslationFinalInterlockRequest.RequestedDriveFreqHz := instTranslationM3.RequestedDriveFreqHz;

// === 📤 PUBLICATION ÉTAT TRANSLATION IHM (lecture seule) ===
TranslationStateHMI.FBState := instTranslationM3.State;
TranslationStateHMI.Ready := instTranslationM3.Ready;
TranslationStateHMI.Busy := instTranslationM3.Busy;
TranslationStateHMI.Done := instTranslationM3.Done;
TranslationStateHMI.Error := instTranslationM3.Error;
TranslationStateHMI.ErrorId := instTranslationM3.ErrorId;
TranslationStateHMI.BrakeCmd := instTranslationM3.BrakeReleaseRequest;
TranslationStateHMI.BrakeCommandOpenConfirmed := instTranslationM3.BrakeCommandOpenConfirmed;
TranslationStateHMI.PositionReached := instTranslationM3.TargetReached;
TranslationStateHMI.DriveControlWord := instTranslationM3.RequestedDriveControlWord;
TranslationStateHMI.DriveFreqRef_Hz := instTranslationM3.RequestedDriveFreqHz;
TranslationStateHMI.ActiveDirection := M3_Direction_Active;
TranslationStateHMI.ActiveSpeedRef_Pct := M3_SpeedRef_Active;
TranslationStateHMI.PositionTremie := PRG_02_Acquisition.TranslationPosTremie;
TranslationStateHMI.PositionPV := PRG_02_Acquisition.TranslationPosPV;
TranslationStateHMI.PositionP2 := PRG_02_Acquisition.TranslationPosP2;
TranslationStateHMI.PositionP1 := PRG_02_Acquisition.TranslationPosP1;
TranslationStateHMI.PositionMaintenance := PRG_02_Acquisition.TranslationPosMaintenance;
TranslationStateHMI.SensorsWord := PRG_02_Acquisition.M3_SensorsWord;
TranslationStateHMI.SensorWordIncoherent := PRG_02_Acquisition.M3_SensorWordIncoherent;
TranslationStateHMI.LimitSwitchFwd := PRG_02_Acquisition.M3_LimitSwitchFwd;
TranslationStateHMI.LimitSwitchRev := PRG_02_Acquisition.M3_LimitSwitchRev;
TranslationStateHMI.DriveActualFreq_Hz := TO_REAL(PRG_02_Acquisition.M3_ActualFrequencyHz_Filtered) / 100.0;
TranslationStateHMI.DriveThermalOk := PRG_02_Acquisition.HwIn.Translation.M3_ThermalFeedback_DI;
TranslationStateHMI.JoystickDeflection_Pct := INT_TO_REAL(PRG_02_Acquisition.HwIn.Operator.JoyXRaw_ANA1);
TranslationStateHMI.FinalInterlockState := PRG_06_Outputs_LD.instTranslationOutputInterlockM3.State;
TranslationStateHMI.FinalInterlockReason := PRG_06_Outputs_LD.instTranslationOutputInterlockM3.Reason;
TranslationStateHMI.FinalInterlockError := PRG_06_Outputs_LD.instTranslationOutputInterlockM3.Error;
TranslationStateHMI.FinalInterlockErrorId := PRG_06_Outputs_LD.instTranslationOutputInterlockM3.ErrorId;
TranslationStateHMI.FinalBrakeTimeoutElapsed := PRG_06_Outputs_LD.instTranslationOutputInterlockM3.BrakeTimeoutElapsed;
TranslationStateHMI.DriveCommReady := (PRG_02_Acquisition.M3_StatusWord_Filtered AND 16#0080) <> 0;
TranslationStateHMI.DrivePowerReady := (PRG_02_Acquisition.M3_StatusWord_Filtered AND 16#0001) <> 0;
TranslationStateHMI.MaintenanceTargetEnable := PRG_03_Modes_Cycle.Auth.MaintenanceM3TargetEnable;
TranslationStateHMI.SimulationModeActive := GVL_Simulation.SimulationModeActive;

// 🛡️ Producteur unique (CODE_QUALITY_STANDARDS §5) : la safety M3 (instSafetyTranslationM3)
// est désormais la source de tous les diagnostics de sécurité — ErrorLimitSwitch/
// ErrorSensorIncoherent ne sont plus recalculés ici (ancien calcul ignorait les bypass,
// pouvait afficher un défaut alors qu'il était sciemment bypassé). Les erreurs propres au
// mouvement (frein, variateur AC600) restent sur TranslationStateHMI.ErrorId ci-dessus,
// bitfield différent, jamais mélangé.
TranslationSafetyHMI.SafeStop := M3_SafeStop_Aggregate;
TranslationSafetyHMI.PowerCutOff := instSafetyTranslationM3.PowerCutOff;
TranslationSafetyHMI.Error := instSafetyTranslationM3.Error;
TranslationSafetyHMI.ErrorId := instSafetyTranslationM3.ErrorId;
TranslationSafetyHMI.ErrorOperatorComm := instSafetyTranslationM3.ErrorOperatorComm;
TranslationSafetyHMI.ErrorDriveComm := instSafetyTranslationM3.ErrorDriveComm;
TranslationSafetyHMI.ErrorPhaseRotation := instSafetyTranslationM3.ErrorPhaseRotation;
TranslationSafetyHMI.ErrorBrakeThermal := instSafetyTranslationM3.ErrorBrakeThermal;
TranslationSafetyHMI.ErrorMecaB := instSafetyTranslationM3.ErrorMecaB;
TranslationSafetyHMI.ErrorMecaA := instSafetyTranslationM3.ErrorMecaA;
TranslationSafetyHMI.ErrorLimitSwitch := instSafetyTranslationM3.ErrorLimitSwitch;
TranslationSafetyHMI.ErrorSensorIncoherent := instSafetyTranslationM3.ErrorSensorIncoherent;

END_PROGRAM
