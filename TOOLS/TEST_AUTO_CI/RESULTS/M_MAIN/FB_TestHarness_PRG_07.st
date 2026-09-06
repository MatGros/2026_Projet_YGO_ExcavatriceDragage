(* =======================================================================
   🧱 FB_TestHarness_PRG_07 : Banc d'essai unitaire pour PRG_07_Supervision
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Isole PRG_07_Supervision, consomme les bus de données
             de PRG_02 (Joystick/E-S), PRG_03 (Modes/Cycle), PRG_04 (Treuils/Benne)
             et PRG_05 (Translation), exécute le formateur de bandeau
             FB_Hmi_BannerFormatter et publie le bandeau IHM ST_HmiBanner.
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_TestHarness_PRG_07
VAR_INPUT
    // === 📥 Bus d'Entrée issus de PRG_02 (Acquisition) ===
    AcqData                 : ST_AcquisitionInterPrg;
    
    // === 📥 Bus d'Entrée issus de PRG_03 (Modes & Cycle) ===
    ModesAuth               : ST_Modes_Autorisations;
    
    // === 📥 Bus d'Entrée issus de PRG_04 (Treuils & Benne) ===
    WinchData               : ST_WinchInterPrg;
    
    // === 📥 Bus d'Entrée issus de PRG_05 (Translation M3) ===
    TranslationData         : ST_TranslationInterPrg;
    
    // === 🛡️ Hardware & Sécurité Machine ===
    EmergencyChainClosed    : BOOL := TRUE;
    PowerContactorEngaged   : BOOL := TRUE;
    PowerCutOffActive       : BOOL := FALSE;
    BtnResetMachine         : BOOL := FALSE;
END_VAR

VAR_OUTPUT
    // === 🖥️ Bandeau IHM Produit ===
    Banner                  : ST_HmiBanner;
    FaultMachineReset_IHM   : BOOL;
END_VAR

VAR
    instHmiBannerFormatter  : FB_Hmi_BannerFormatter;
END_VAR

{region "Corps d'exécution PRG_07 encapsulé"}
// 1. Gestion Reset Machine
FaultMachineReset_IHM := BtnResetMachine;

// 2. Formatage Bandeau IHM
instHmiBannerFormatter(
    Enable                := TRUE,
    SimulationModeActive  := FALSE,
    CurrentMode           := ModesAuth.Mode,
    BothAxesCoupled       := (ModesAuth.JoystickWinchSelectArbitrated = 0),
    WinchSelected         := ModesAuth.JoystickWinchSelectArbitrated,
    CycleStep             := E_AutoCycleStep.AX0_REPOS,
    CycleStateStr         := 'X0_PREPARATION',
    CycleErrorId          := 16#0000,
    CycleStepAtError      := E_AutoCycleStep.AX0_REPOS,
    MachineHomingStep     := 0,
    MachineHomingInstruction := '',

    
    BypassGlobalActive    := FALSE,
    BypassWinchM1Active   := FALSE,
    BypassWinchM2Active   := FALSE,
    BypassTranslation     := FALSE,
    BypassSyncActive      := FALSE,
    SyncDegradedActive    := FALSE,
    LegalLimitReached     := FALSE,
    EmergencyChainClosed  := EmergencyChainClosed,
    PowerContactorEngaged := PowerContactorEngaged,
    PowerCutOffActiveAny  := PowerCutOffActive,
    SafeStopActive        := WinchData.WinchM1Safety.SafeStop OR WinchData.WinchM2Safety.SafeStop,
    DescendPermit         := WinchData.WinchM1Safety.DescendPermit AND WinchData.WinchM2Safety.DescendPermit,
    AscentPermit          := WinchData.WinchM1Safety.AscentPermit AND WinchData.WinchM2Safety.AscentPermit,
    BucketIsOpen          := WinchData.BucketState.MechState.IsOpen,
    BucketIsClosed        := WinchData.BucketState.MechState.IsClosed,
    DiveActive            := FALSE,
    TopLimitReached       := FALSE,
    WinchBothMotionDirection := 0,
    M1LogicRequestDirection     := 0,
    M2LogicRequestDirection     := 0,
    CycleRequestDirection       := 0,
    DeadmanArmed          := AcqData.Joystick.DeadmanArmed,
    JoystickAtNeutral     := AcqData.Joystick.AtNeutralXY,
    CycleAutoBusy         := FALSE,
    WinchM1Safety         := WinchData.WinchM1Safety,
    WinchM2Safety         := WinchData.WinchM2Safety,
    TranslationSafety     := TranslationData.TranslationSafety,
    BucketErrorId         := 16#0000,
    SyncErrorId           := 16#0000,
    DiveErrorId           := 16#0000,
    ExtractionErrorId     := 16#0000,
    EmergencyErrorId      := 16#0000,
    RedundancyTestFailed  := FALSE,
    EmergencyArmingFailed := FALSE,
    AlarmHoldTime         := T#1s
);

Banner := instHmiBannerFormatter.Banner;
{endregion}
END_FUNCTION_BLOCK
