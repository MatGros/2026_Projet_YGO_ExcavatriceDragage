(* =========================================================================
   FB_T216Prg04GateProbe - Sonde unitaire des expressions T216 de PRG_04 (TEST ONLY)
   -------------------------------------------------------------------------
   Replique a l'identique les expressions d'atomicite Both ajoutees a
   COD: CODE/M_MAIN/PRG_04_Treuils_Benne.st (§2 soft-stop, §5 CoupledBoth,
   §5 agregats Both, §5/depart coupe, §6 routage). Ne fait PAS partie du
   programme de production. Sert de preuve dynamique pour :
     #4 soft-stop : en Both + ecart mineur + soft-stop -> AUCUN drapeau sync
        (pas de rattrapage unilateral) ; hors Both, le drapeau est calcule.
     #5 depart couple : Both + barriere finale M1 non prete -> les DEUX treuils
        ne demarrent pas ; routage : en Both, M1/M2 consomment l'agregat.
   Chaque affectation reproduit mot pour mot PRG_04 afin de rester un miroir
   representatif (meme discipline que FB_TestHarness_PRG_04, echelle reduite).
   ========================================================================= *)

FUNCTION_BLOCK FB_T216Prg04GateProbe
VAR_INPUT
    // --- Entrees miroir PRG_04 ---
    WinchBothMotionActive : BOOL;
    instWinchSync_SyncActive : BOOL;
    EffectivePermitM1_Ascent  : BOOL;
    EffectivePermitM1_Descend : BOOL;
    EffectivePermitM2_Ascent  : BOOL;
    EffectivePermitM2_Descend : BOOL;
    SyncSoftStopEnable        : BOOL;
    SyncMinorDeviation        : BOOL;
    SignedDeltaPosM           : REAL;
    M1InterlockReady          : BOOL;
    M1InterlockRestartInhibit : BOOL;
    M2InterlockReady          : BOOL;
    M2InterlockRestartInhibit : BOOL;
    // --- commandes (miroir M1LogicRequestStartStop/M2LogicRequestStartStop) ---
    M1LogicStartStop : BOOL;
    M2LogicStartStop : BOOL;
END_VAR
VAR_OUTPUT
    CoupledBoth          : BOOL;
    BothAscentPermit     : BOOL;
    BothDescendPermit    : BOOL;
    BothBlocked          : BOOL;
    BothFinalInterlockReady : BOOL;
    SyncMinorDeviationBlocksUp   : BOOL;
    SyncMinorDeviationBlocksDown : BOOL;
    M1StartStop_Coupled  : BOOL;
    M2StartStop_Coupled  : BOOL;
    M1AscentPermitUse    : BOOL;
    M1DescendPermitUse   : BOOL;
    M2AscentPermitUse    : BOOL;
    M2DescendPermitUse   : BOOL;
END_VAR

// === §5 : CoupledBoth atomique, independant de SyncEnable ===
CoupledBoth := instWinchSync_SyncActive OR WinchBothMotionActive;

// === §5 : agregats Both (AND des 4 permits effectifs) ===
BothAscentPermit  := EffectivePermitM1_Ascent  AND EffectivePermitM2_Ascent;
BothDescendPermit := EffectivePermitM1_Descend AND EffectivePermitM2_Descend;

// === §2 : soft-stop gated par AND NOT WinchBothMotionActive (decision 5) ===
SyncMinorDeviationBlocksUp   := SyncSoftStopEnable AND SyncMinorDeviation AND (SignedDeltaPosM > 0.0) AND NOT WinchBothMotionActive;
SyncMinorDeviationBlocksDown := SyncSoftStopEnable AND SyncMinorDeviation AND (SignedDeltaPosM < 0.0) AND NOT WinchBothMotionActive;

// === §5/depart : barriere finale couplee (depart coupe T216) ===
BothFinalInterlockReady := M1InterlockReady AND NOT M1InterlockRestartInhibit
                           AND M2InterlockReady AND NOT M2InterlockRestartInhibit;
IF WinchBothMotionActive AND NOT BothFinalInterlockReady THEN
    M1StartStop_Coupled := FALSE;
    M2StartStop_Coupled := FALSE;
ELSE
    M1StartStop_Coupled := M1LogicStartStop;
    M2StartStop_Coupled := M2LogicStartStop;
END_IF;

// === §6 : routage des permis vers FB_Winch (both = agregat, unitaire = individuel) ===
M1AscentPermitUse  := SEL(WinchBothMotionActive, EffectivePermitM1_Ascent,  BothAscentPermit);
M1DescendPermitUse := SEL(WinchBothMotionActive, EffectivePermitM1_Descend, BothDescendPermit);
M2AscentPermitUse  := SEL(WinchBothMotionActive, EffectivePermitM2_Ascent,  BothAscentPermit);
M2DescendPermitUse := SEL(WinchBothMotionActive, EffectivePermitM2_Descend, BothDescendPermit);

// === §5 : diagnostic Both ===
IF NOT WinchBothMotionActive THEN
    BothBlocked := FALSE;
ELSIF NOT (BothAscentPermit OR BothDescendPermit) THEN
    BothBlocked := TRUE;
ELSIF NOT BothFinalInterlockReady THEN
    BothBlocked := TRUE;
ELSE
    BothBlocked := FALSE;
END_IF;

END_FUNCTION_BLOCK
