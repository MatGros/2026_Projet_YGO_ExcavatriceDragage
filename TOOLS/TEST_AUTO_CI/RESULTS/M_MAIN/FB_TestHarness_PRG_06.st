(* =======================================================================
   🧱 FB_TestHarness_PRG_06 : Banc d'essai unitaire pour PRG_06_Outputs
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Isole PRG_06_Outputs, consomme les bus de données de
             PRG_04 (ST_WinchInterPrg) et PRG_05 (ST_TranslationInterPrg),
             exécute les barrières finales FB_WinchOutputInterlock (M1, M2)
             et FB_TranslationOutputInterlock (M3), et publie ST_OutputsInterPrg.
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_TestHarness_PRG_06
VAR_INPUT
    // === 📥 Bus d'Entrée issus de PRG_04 (Treuils M1/M2) ===
    WinchData                        : ST_WinchInterPrg;
    
    // === 📥 Bus d'Entrée issus de PRG_05 (Translation M3) ===
    TranslationData                  : ST_TranslationInterPrg;
    
    // === 🛡️ Entrées Supervision / Reset ===
    FaultReset                       : BOOL := FALSE;
END_VAR

VAR_OUTPUT
    // === 🚌 Bus Inter-PRG produit vers PRG_02/SimBench ===
    Data                             : ST_OutputsInterPrg;
    
    // Diagnostic
    M1InterlockEnable                : BOOL;
    M2InterlockEnable                : BOOL;
    M3InterlockEnable                : BOOL;
END_VAR

VAR
    instWinchOutputInterlockM1       : FB_WinchOutputInterlock;
    instWinchOutputInterlockM2       : FB_WinchOutputInterlock;
    instTranslationOutputInterlockM3 : FB_TranslationOutputInterlock;
END_VAR

{region "Corps d'exécution PRG_06 encapsulé"}
// 1. Barrière M1
M1InterlockEnable := WinchData.WinchM1FinalInterlockRequest.Enable
                     AND NOT WinchData.WinchM1FinalInterlockRequest.PowerCutOff;

instWinchOutputInterlockM1(
    Enable                     := M1InterlockEnable,
    Reset                      := FaultReset,
    PowerContactorEngaged      := WinchData.WinchM1FinalInterlockRequest.PowerContactorEngaged,
    SafeStop                   := WinchData.WinchM1FinalInterlockRequest.SafeStop,
    AscentPermit               := WinchData.WinchM1FinalInterlockRequest.AscentPermit,
    DescendPermit              := WinchData.WinchM1FinalInterlockRequest.DescendPermit,
    BrakeFeedback              := WinchData.WinchM1FinalInterlockRequest.BrakeFeedback,
    FwdRevSpeedFeedbackOff     := WinchData.WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff,
    RequestedRelayFwd          := WinchData.WinchM1FinalInterlockRequest.RequestedRelayFwd,
    RequestedRelayRev          := WinchData.WinchM1FinalInterlockRequest.RequestedRelayRev,
    RequestedContactor1        := WinchData.WinchM1FinalInterlockRequest.RequestedContactor1,
    RequestedContactor2        := WinchData.WinchM1FinalInterlockRequest.RequestedContactor2,
    RequestedContactor3        := WinchData.WinchM1FinalInterlockRequest.RequestedContactor3,
    RequestedContactor4        := WinchData.WinchM1FinalInterlockRequest.RequestedContactor4,
    RequestedStep              := WinchData.WinchM1FinalInterlockRequest.RequestedStep
);

Data.M1RelayFwd        := instWinchOutputInterlockM1.RelayFwd;
Data.M1RelayRev        := instWinchOutputInterlockM1.RelayRev;
Data.M1SpeedContactor1 := instWinchOutputInterlockM1.Contactor1;
Data.M1SpeedContactor2 := instWinchOutputInterlockM1.Contactor2;
Data.M1SpeedContactor3 := instWinchOutputInterlockM1.Contactor3;
Data.M1SpeedContactor4 := instWinchOutputInterlockM1.Contactor4;
Data.M1BrakeCmd        := Data.M1RelayFwd OR Data.M1RelayRev;

// 2. Barrière M2
M2InterlockEnable := WinchData.WinchM2FinalInterlockRequest.Enable
                     AND NOT WinchData.WinchM2FinalInterlockRequest.PowerCutOff;

instWinchOutputInterlockM2(
    Enable                     := M2InterlockEnable,
    Reset                      := FaultReset,
    PowerContactorEngaged      := WinchData.WinchM2FinalInterlockRequest.PowerContactorEngaged,
    SafeStop                   := WinchData.WinchM2FinalInterlockRequest.SafeStop,
    AscentPermit               := WinchData.WinchM2FinalInterlockRequest.AscentPermit,
    DescendPermit              := WinchData.WinchM2FinalInterlockRequest.DescendPermit,
    BrakeFeedback              := WinchData.WinchM2FinalInterlockRequest.BrakeFeedback,
    FwdRevSpeedFeedbackOff     := WinchData.WinchM2FinalInterlockRequest.FwdRevSpeedFeedbackOff,
    RequestedRelayFwd          := WinchData.WinchM2FinalInterlockRequest.RequestedRelayFwd,
    RequestedRelayRev          := WinchData.WinchM2FinalInterlockRequest.RequestedRelayRev,
    RequestedContactor1        := WinchData.WinchM2FinalInterlockRequest.RequestedContactor1,
    RequestedContactor2        := WinchData.WinchM2FinalInterlockRequest.RequestedContactor2,
    RequestedContactor3        := WinchData.WinchM2FinalInterlockRequest.RequestedContactor3,
    RequestedContactor4        := WinchData.WinchM2FinalInterlockRequest.RequestedContactor4,
    RequestedStep              := WinchData.WinchM2FinalInterlockRequest.RequestedStep
);

Data.M2RelayFwd        := instWinchOutputInterlockM2.RelayFwd;
Data.M2RelayRev        := instWinchOutputInterlockM2.RelayRev;
Data.M2SpeedContactor1 := instWinchOutputInterlockM2.Contactor1;
Data.M2SpeedContactor2 := instWinchOutputInterlockM2.Contactor2;
Data.M2SpeedContactor3 := instWinchOutputInterlockM2.Contactor3;
Data.M2SpeedContactor4 := instWinchOutputInterlockM2.Contactor4;
Data.M2BrakeCmd        := Data.M2RelayFwd OR Data.M2RelayRev;

// 3. Barrière M3
M3InterlockEnable := TranslationData.TranslationFinalInterlockRequest.Enable
                     AND NOT TranslationData.TranslationFinalInterlockRequest.PowerCutOff;

instTranslationOutputInterlockM3(
    Enable                     := M3InterlockEnable,
    Reset                      := FaultReset,
    PowerContactorEngaged      := TranslationData.TranslationFinalInterlockRequest.PowerContactorEngaged,
    SafeStop                   := TranslationData.TranslationFinalInterlockRequest.SafeStop,
    BrakeCommandOpenConfirmed  := TranslationData.TranslationFinalInterlockRequest.BrakeCommandOpenConfirmed,
    BrakeReleaseRequest        := TranslationData.TranslationFinalInterlockRequest.BrakeReleaseRequest,
    RequestedDriveControlWord  := TranslationData.TranslationFinalInterlockRequest.RequestedDriveControlWord,
    RequestedDriveFreqHz       := TranslationData.TranslationFinalInterlockRequest.RequestedDriveFreqHz
);

Data.TranslationBrakeCmd := instTranslationOutputInterlockM3.BrakeCmd;

{endregion}
END_FUNCTION_BLOCK
