(* ═══════════════════════════════════════════════════════════════
   ↔️ PRG_05_Translation — Pilotage de la Translation M3
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 5 (après PRG_04_Treuils_Benne).
   ✅ Arbitre entre les commandes Manuelles (Joystick) et Automatiques (PRG_03_Modes_Cycle).
   📄 Docs : DOC/AF_Partie-11_Fonction_Translation_v2.0.md
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_05_Translation

VAR_OUTPUT
    TranslationFinalInterlockRequest : ST_TranslationFinalInterlockRequest;
END_VAR

VAR
    instTranslationM3           : FB_Translation;

    M3_StartStop_Active     : BOOL;
    M3_Direction_Active     : INT;
    M3_SpeedRef_Active      : REAL;
    M3_PositioningActive    : BOOL;
    M3_PositionSensorTarget : BOOL;

    SelTarget       : INT;
    FreqPct                 : REAL;

    M3_SafeStop_Active      : BOOL;
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


// === ⚙️ §2 EXÉCUTION PILOTAGE TRANSLATION M3 ===

instTranslationM3(
    Enable                  := (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE),
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := PRG_03_Modes_Cycle.Auth.Mode,
    StartStop               := M3_StartStop_Active,
    SafeStop                := M3_SafeStop_Active,
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
    BypassContactorCheck    := GVL_IHM.TranslationM3.Bypass.Global,
    BypassLimitSwitch       := GVL_IHM.TranslationM3.Bypass.Global OR GVL_IHM.TranslationM3.Bypass.LimitSwitch
);


// === 📤 §3 PUBLICATION DEMANDE BRUTE TRANSLATION ===

TranslationFinalInterlockRequest.Enable := (PRG_03_Modes_Cycle.Auth.Mode <> E_Mode.DISABLE);
TranslationFinalInterlockRequest.Reset := PRG_07_Supervision.FaultMachineReset_IHM;
TranslationFinalInterlockRequest.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
TranslationFinalInterlockRequest.SafeStop := M3_SafeStop_Active;
TranslationFinalInterlockRequest.BrakeReleaseRequest := instTranslationM3.BrakeReleaseRequest;
TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed := instTranslationM3.BrakeCommandOpenConfirmed;
TranslationFinalInterlockRequest.RequestedDriveControlWord := instTranslationM3.RequestedDriveControlWord;
TranslationFinalInterlockRequest.RequestedDriveFreqHz := instTranslationM3.RequestedDriveFreqHz;

END_PROGRAM
