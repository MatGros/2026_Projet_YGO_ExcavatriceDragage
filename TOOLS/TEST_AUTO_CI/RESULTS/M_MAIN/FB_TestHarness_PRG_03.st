(* =======================================================================
   🧱 FB_TestHarness_PRG_03 : Banc d'essai unitaire pour PRG_03_Modes_Cycle
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Isole PRG_03, injecte les sélections de modes et commandes cycle,
             exécute FB_Modes et FB_Cycle, et expose le bus ST_fbModes_Autorisations.
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_TestHarness_PRG_03
VAR_INPUT
    // === 🎚️ Sélections IHM Modes ===
    SelMode                 : E_Mode := E_Mode.MAINT_N1;
    BtnModeReset            : BOOL;
    SelSyncEnable           : BOOL := TRUE;
    InhibitM1Request        : BOOL := FALSE;
    InhibitM2Request        : BOOL := FALSE;
    SelHomingApproachEnable : BOOL := FALSE;
    SelJoystickWinch        : INT := 1; // 1 = M1, 2 = M2, 0 = Both
    TglMaintenanceZoneAccess: BOOL := FALSE;
    
    // === 🛡️ Sécurités Machine ===
    PowerContactorEngaged   : BOOL := TRUE;
    EncoderFaultPresent     : BOOL := FALSE;
    
    // === 🔄 Commandes Cycle Semi-Auto ===
    BtnStartCycle           : BOOL;
    BtnAbortCycle           : BOOL;
    BtnCycleReset           : BOOL;
    DeadmanArmed            : BOOL := TRUE;
    JoystickDeflected       : BOOL := TRUE;
    HeartbeatIhmOk          : BOOL := TRUE;
    
    // === 📏 Données mesurées / retours treuils ===
    M1_CablePosM            : REAL := 5.0;
    M2_CablePosM            : REAL := 5.0;
    M1_SpeedMps             : REAL := 0.0;
    M2_SpeedMps             : REAL := 0.0;
    Benne_IsClosed          : BOOL := TRUE;
    Benne_IsOpen            : BOOL := FALSE;
    Benne_IsRoughlyClosed   : BOOL := TRUE;
    HomedM1                 : BOOL := TRUE;
    HomedM2                 : BOOL := TRUE;
END_VAR

VAR_OUTPUT
    // === 🎚️ Bus d'Autorisations Produit vers PRG_04/05/06/07 ===
    Auth                    : ST_fbModes_Autorisations;
    
    // === 🔄 Séquenceur de Cycle Semi-Auto ===
    CycleStep               : E_CycleStep;
    CycleBusy               : BOOL;
    CycleDone               : BOOL;
    CycleError              : BOOL;
    CycleStateStr           : STRING(80);
END_VAR

VAR
    instModes               : FB_Modes;
    instCycleSemiAuto       : FB_Cycle;
    countMem                : INT := 0;
END_VAR

{region "Corps d'exécution PRG_03 encapsulé"}
// 1. Arbitrage des Modes Machine
instModes(
    Enable                  := TRUE,
    Reset                   := BtnModeReset,
    PowerContactorEngaged   := PowerContactorEngaged,
    SelMode                 := SelMode,
    SelSyncEnable           := SelSyncEnable,
    InhibitM1Request        := InhibitM1Request,
    InhibitM2Request        := InhibitM2Request,
    SelHomingApproachEnable := SelHomingApproachEnable,
    EncoderFaultPresent     := EncoderFaultPresent,
    JoystickWinchSelectRequest := SelJoystickWinch,
    SelMaintenanceZoneAccess := TglMaintenanceZoneAccess
);

Auth := instModes.Auth;

// 2. Séquenceur de Cycle Semi-Automatique
instCycleSemiAuto(
    Enable                  := (Auth.Mode = E_Mode.SEMI_AUTO),
    Reset                   := BtnCycleReset,
    PowerContactorEngaged   := PowerContactorEngaged,
    Mode                    := Auth.Mode,
    CycleMotionPermit       := JoystickDeflected,
    DeadmanArmed            := DeadmanArmed,
    HeartbeatIhmOk          := HeartbeatIhmOk,
    StartCycle              := BtnStartCycle,
    AbortCycle              := BtnAbortCycle,
    SelTarget               := 1,
    SetDepthM               := -12.0,
    SetOffsetM              := 1.5,
    KoboldContactFond       := FALSE,
    LimitLegalReached       := FALSE,
    LimitLegalDepthM        := -15.0,
    WinchSyncError          := FALSE,
    WinchSyncDeltaM         := 0.0,
    M1_CablePosM            := M1_CablePosM,
    M2_CablePosM            := M2_CablePosM,
    M1_MeasuredSpeedMps     := M1_SpeedMps,
    M2_MeasuredSpeedMps     := M2_SpeedMps,
    SpeedMismatchThresholdMps := 1.5,
    SpeedMismatchTimeout    := T#500ms,
    CableLimitM1AscentM     := 7.5,
    Translation_At_P1       := FALSE,
    Translation_At_Tremie   := TRUE,
    Translation_At_Maintenance := FALSE,
    Translation_Busy        := FALSE,
    Translation_Done        := TRUE,
    Benne_Busy              := FALSE,
    Benne_Done              := TRUE,
    Benne_IsOpen            := Benne_IsOpen,
    Benne_IsClosed          := Benne_IsClosed,
    Benne_IsRoughlyClosed   := Benne_IsRoughlyClosed,
    HomedM1                 := HomedM1,
    HomedM2                 := HomedM2,
    TopPositionSensor       := FALSE,
    HomingRequest           := FALSE,
    SampleCount             := countMem
);

CycleStep     := instCycleSemiAuto.CycleStep;
CycleBusy     := instCycleSemiAuto.Lifecycle.Busy;
CycleDone     := instCycleSemiAuto.Lifecycle.Done;
CycleError    := instCycleSemiAuto.Fault.Error;
CycleStateStr := instCycleSemiAuto.CycleStateStr;

{endregion}
END_FUNCTION_BLOCK
