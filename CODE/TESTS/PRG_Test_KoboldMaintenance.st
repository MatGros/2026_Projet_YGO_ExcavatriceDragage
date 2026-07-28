(* ═══════════════════════════════════════════════════════════════
   🧪 PRG_Test_KoboldMaintenance — Tests PLC isolés T81/T82
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-04_Cycle_Sequenceur_v1.5.md §3ter
   ⚠️ Programme de qualification MANUELLE : non appelé par MainTask.
      L'opérateur l'appelle temporairement dans une tâche de test, pose TestEnable,
      puis lit Passed/Failed. Aucun accès E/S, aucun ordre machine.
   ═══════════════════════════════════════════════════════════════ *)
PROGRAM PRG_Test_KoboldMaintenance
VAR_INPUT
    TestEnable : BOOL;
    ResetTests : BOOL;
END_VAR
VAR_OUTPUT
    Busy       : BOOL;
    Passed     : BOOL;
    Failed     : BOOL;
    ErrorId    : WORD; (* bit0 Dive valide, bit1 Dive invalide, bit2 Extraction, bit3 défaut extraction *)
END_VAR
VAR
    ResetEdge        : R_TRIG;
    DiveValid        : FB_DiveSearch;
    DiveInvalid      : FB_DiveSearch;
    ExtractionValid  : FB_ExtractionSequence;
    ExtractionInvalid: FB_ExtractionSequence;
    DiveValidStep    : INT;
    DiveInvalidStep  : INT;
    ExtractionStep   : INT;
    DiveKobold       : BOOL;
    DiveMotion       : BOOL;
    DivePosition_M   : REAL;
    InvalidKobold    : BOOL;
    InvalidMotion    : BOOL;
    InvalidPosition_M: REAL;
    ExtractionMotion : BOOL;
    ExtractionClosed : BOOL;
    ExtractionBusy   : BOOL;
    ExtractionPos_M  : REAL;
END_VAR

ResetEdge(CLK := ResetTests);
IF ResetEdge.Q OR NOT TestEnable THEN
    Busy := FALSE; Passed := FALSE; Failed := FALSE; ErrorId := 16#0000;
    DiveValidStep := 0; DiveInvalidStep := 0; ExtractionStep := 0;
    DiveKobold := FALSE; DiveMotion := FALSE; DivePosition_M := 1.0;
    InvalidKobold := FALSE; InvalidMotion := FALSE; InvalidPosition_M := 1.0;
    ExtractionMotion := FALSE; ExtractionClosed := FALSE; ExtractionBusy := FALSE; ExtractionPos_M := 0.0;
ELSE
    Busy := NOT Passed AND NOT Failed;

    (* TC-KM-01 : Kobold hors eau 0 → immersion 1 dans fenêtre → fond 0. *)
    CASE DiveValidStep OF
        0: DiveMotion := FALSE; DiveKobold := FALSE; DivePosition_M := 1.0; DiveValidStep := 1;
        1: DiveMotion := FALSE; DiveKobold := FALSE; DivePosition_M := 1.0; DiveValidStep := 2;
        2: DiveMotion := TRUE;  DiveKobold := FALSE; DivePosition_M := 0.4; DiveValidStep := 3;
        3: DiveMotion := TRUE;  DiveKobold := TRUE;  DivePosition_M := 0.0; DiveValidStep := 4;
        4: DiveMotion := TRUE;  DiveKobold := TRUE;  DivePosition_M := -0.1; DiveValidStep := 5;
        5: DiveMotion := TRUE;  DiveKobold := FALSE; DivePosition_M := -0.2; DiveValidStep := 6;
    END_CASE;

    (* TC-KM-02 : front immersion hors fenêtre → T82 / ErrorId bit1. *)
    CASE DiveInvalidStep OF
        0: InvalidMotion := FALSE; InvalidKobold := FALSE; InvalidPosition_M := 1.0; DiveInvalidStep := 1;
        1: InvalidMotion := FALSE; InvalidKobold := FALSE; InvalidPosition_M := 1.0; DiveInvalidStep := 2;
        2: InvalidMotion := TRUE;  InvalidKobold := FALSE; InvalidPosition_M := 0.4; DiveInvalidStep := 3;
        3: InvalidMotion := TRUE;  InvalidKobold := TRUE;  InvalidPosition_M := 0.7; DiveInvalidStep := 4;
    END_CASE;

    (* TC-KM-03 : fond → fermeture → palier 1 sur 2 m → montée nominale. *)
    CASE ExtractionStep OF
        0: ExtractionMotion := FALSE; ExtractionClosed := FALSE; ExtractionBusy := FALSE; ExtractionPos_M := 0.0; ExtractionStep := 1;
        1: ExtractionMotion := FALSE; ExtractionStep := 2;
        2: ExtractionMotion := TRUE;  ExtractionStep := 3;
        3: ExtractionMotion := TRUE;  ExtractionClosed := FALSE; ExtractionBusy := TRUE; ExtractionStep := 4;
        4: ExtractionMotion := TRUE;  ExtractionClosed := TRUE;  ExtractionBusy := FALSE; ExtractionPos_M := 0.0; ExtractionStep := 5;
        5: ExtractionMotion := TRUE;  ExtractionPos_M := 0.0; ExtractionStep := 6;
        6: ExtractionMotion := TRUE;  ExtractionPos_M := 2.0; ExtractionStep := 7;
    END_CASE;
END_IF;

DiveValid(
    Enable := TestEnable, Reset := FALSE, EmergencyStopOk := TRUE, Mode := E_Mode.MAINT_N1,
    MotionRequestActive := DiveMotion, MotionDirection := -1, BucketIsOpen := TRUE,
    KoboldImmersed := DiveKobold, M1Position_M := DivePosition_M, M2Position_M := DivePosition_M,
    PositionsValid := TRUE, DiveStartMin_M := 1.0, ImmersionUpper_M := 0.5, ImmersionLower_M := -0.5
);
DiveInvalid(
    Enable := TestEnable, Reset := FALSE, EmergencyStopOk := TRUE, Mode := E_Mode.MAINT_N1,
    MotionRequestActive := InvalidMotion, MotionDirection := -1, BucketIsOpen := TRUE,
    KoboldImmersed := InvalidKobold, M1Position_M := InvalidPosition_M, M2Position_M := InvalidPosition_M,
    PositionsValid := TRUE, DiveStartMin_M := 1.0, ImmersionUpper_M := 0.5, ImmersionLower_M := -0.5
);
ExtractionValid(
    Enable := TestEnable, Reset := FALSE, EmergencyStopOk := TRUE, Mode := E_Mode.MAINT_N1,
    MotionRequestActive := ExtractionMotion, MotionDirection := 1, BottomPositionConfirmed := TRUE,
    BucketIsClosed := ExtractionClosed, BucketBusy := ExtractionBusy, BucketError := FALSE,
    WinchSyncError := FALSE, M1Position_M := ExtractionPos_M, M2Position_M := ExtractionPos_M,
    M1MeasuredSpeedValid := TRUE, M2MeasuredSpeedValid := TRUE, PositionsValid := TRUE,
    ControlAscentDistance_M := 2.0
);
ExtractionInvalid(
    Enable := TestEnable, Reset := FALSE, EmergencyStopOk := TRUE, Mode := E_Mode.MAINT_N1,
    MotionRequestActive := FALSE, MotionDirection := 0, BottomPositionConfirmed := FALSE,
    BucketIsClosed := FALSE, BucketBusy := FALSE, BucketError := FALSE, WinchSyncError := FALSE,
    M1Position_M := 0.0, M2Position_M := 0.0, M1MeasuredSpeedValid := TRUE,
    M2MeasuredSpeedValid := TRUE, PositionsValid := TRUE, ControlAscentDistance_M := 0.0
);

IF DiveValid.BottomTouchConfirmed THEN ErrorId := ErrorId OR 16#0001; END_IF;
IF DiveInvalid.Error AND ((DiveInvalid.ErrorId AND 16#0002) <> 16#0000) THEN ErrorId := ErrorId OR 16#0002; END_IF;
IF (ExtractionValid.ExtractionState = E_ExtractionSequenceState.CONTROL_ASCENT)
   AND ExtractionValid.ForceMinSpeedStep THEN ErrorId := ErrorId OR 16#0004; END_IF;
IF ExtractionValid.ExtractionState = E_ExtractionSequenceState.NOMINAL_ASCENT
   AND ExtractionValid.AscentPermit THEN ErrorId := ErrorId OR 16#0004; END_IF;
IF ExtractionInvalid.Error AND ((ExtractionInvalid.ErrorId AND 16#0008) <> 16#0000) THEN ErrorId := ErrorId OR 16#0008; END_IF;

IF (ErrorId AND 16#000F) = 16#000F THEN
    Passed := TRUE;
    Busy := FALSE;
END_IF;
