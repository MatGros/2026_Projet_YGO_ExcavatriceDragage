(* ═══════════════════════════════════════════════════════════════
   ⚖️ FB_Diag_WinchSymmetry — Mesure passive MES-008 M1/M2
   📄 Doc : ARCHIVES/Doc/AUDITS/PreLivraison/TASKS/TASK_D1_Preflight_et_Symetrie_Winch_v1.0.md
   🔒 Observateur pur : aucune écriture de commande, sécurité ou mouvement.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_Diag_WinchSymmetry
VAR_INPUT
    Reset : BOOL;
    M1CommandActive : BOOL;
    M2CommandActive : BOOL;
    M1Direction : INT;
    M2Direction : INT;
    M1BrakeCmd, M2BrakeCmd, M1BrakeApplied, M2BrakeApplied : BOOL;
    M1Position_M, M2Position_M, M1Speed_Mps, M2Speed_Mps, SyncDeviation_M : REAL;
    Config : ST_Diag_Winch_SymmetryCfg;
END_VAR
VAR_IN_OUT
    Data : ST_Diag_Winch_SymmetryData;
END_VAR
VAR_OUTPUT
    SymmetryOk : BOOL;
    SymmetryValid : BOOL;
END_VAR
VAR
    ResetEdge : R_TRIG;
    CycleTime : FB_CycleTime;
    CommandTon : TON;
    Comparable, Qualified, PreviousQualified, Stopping, StartCapturedM1, StartCapturedM2, StopCapturedM1, StopCapturedM2 : BOOL;
    StartMsM1, StartMsM2, ReleaseMsM1, ReleaseMsM2, ApplyMsM1, ApplyMsM2, StopMsM1, StopMsM2 : UDINT;
    MotionTimer, StopTimer : TON;
    StopStartM1_M, StopStartM2_M : REAL;
END_VAR

CycleTime(DefaultValueS := 0.010); ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN Data.DeltaStartDelay_Ms:=0; Data.DeltaBrakeReleaseTime_Ms:=0; Data.DeltaBrakeApplyTime_Ms:=0; Data.DeltaStopDistance_Mm:=0; Data.DeltaStopTime_Ms:=0; Data.MaxSyncDeviation_M:=0.0; END_IF;
Comparable := M1CommandActive AND M2CommandActive AND (M1Direction = M2Direction) AND (M1Direction <> 0);
CommandTon(IN := Comparable, PT := UDINT_TO_TIME(Config.MinimumCommandTime_Ms));
Qualified := CommandTon.Q AND (M1Speed_Mps >= Config.MinimumSpeed_Mps) AND (M2Speed_Mps >= Config.MinimumSpeed_Mps);
MotionTimer(IN := Comparable, PT := T#1h);
StopTimer(IN := Stopping, PT := T#1h);
IF NOT Comparable THEN StartCapturedM1:=FALSE; StartCapturedM2:=FALSE; ReleaseMsM1:=0; ReleaseMsM2:=0; ApplyMsM1:=0; ApplyMsM2:=0; END_IF;
IF Comparable AND (M1Speed_Mps >= Config.MinimumSpeed_Mps) AND NOT StartCapturedM1 THEN StartMsM1:=TIME_TO_UDINT(MotionTimer.ET); StartCapturedM1:=TRUE; END_IF;
IF Comparable AND (M2Speed_Mps >= Config.MinimumSpeed_Mps) AND NOT StartCapturedM2 THEN StartMsM2:=TIME_TO_UDINT(MotionTimer.ET); StartCapturedM2:=TRUE; END_IF;
IF Qualified THEN
    IF M1BrakeCmd AND M1BrakeApplied THEN ReleaseMsM1 := ReleaseMsM1 + REAL_TO_UDINT(CycleTime.CycleTimeS * 1000.0); END_IF;
    IF M2BrakeCmd AND M2BrakeApplied THEN ReleaseMsM2 := ReleaseMsM2 + REAL_TO_UDINT(CycleTime.CycleTimeS * 1000.0); END_IF;
    IF NOT M1BrakeCmd AND NOT M1BrakeApplied THEN ApplyMsM1 := ApplyMsM1 + REAL_TO_UDINT(CycleTime.CycleTimeS * 1000.0); END_IF;
    IF NOT M2BrakeCmd AND NOT M2BrakeApplied THEN ApplyMsM2 := ApplyMsM2 + REAL_TO_UDINT(CycleTime.CycleTimeS * 1000.0); END_IF;
    IF SyncDeviation_M > Data.MaxSyncDeviation_M THEN Data.MaxSyncDeviation_M := SyncDeviation_M; END_IF;
END_IF;
IF PreviousQualified AND NOT Comparable THEN Stopping:=TRUE; StopCapturedM1:=FALSE; StopCapturedM2:=FALSE; StopStartM1_M:=M1Position_M; StopStartM2_M:=M2Position_M; END_IF;
IF Stopping THEN
    IF (M1Speed_Mps < Config.MinimumSpeed_Mps) AND NOT StopCapturedM1 THEN StopMsM1:=TIME_TO_UDINT(StopTimer.ET); StopCapturedM1:=TRUE; END_IF;
    IF (M2Speed_Mps < Config.MinimumSpeed_Mps) AND NOT StopCapturedM2 THEN StopMsM2:=TIME_TO_UDINT(StopTimer.ET); StopCapturedM2:=TRUE; END_IF;
    IF StopCapturedM1 AND StopCapturedM2 THEN
        Data.DeltaStartDelay_Ms := ABS(UDINT_TO_DINT(StartMsM1)-UDINT_TO_DINT(StartMsM2));
        Data.DeltaBrakeReleaseTime_Ms := ABS(UDINT_TO_DINT(ReleaseMsM1)-UDINT_TO_DINT(ReleaseMsM2));
        Data.DeltaBrakeApplyTime_Ms := ABS(UDINT_TO_DINT(ApplyMsM1)-UDINT_TO_DINT(ApplyMsM2));
        Data.DeltaStopDistance_Mm := REAL_TO_UDINT(ABS(ABS(M1Position_M-StopStartM1_M)-ABS(M2Position_M-StopStartM2_M))*1000.0);
        Data.DeltaStopTime_Ms := ABS(UDINT_TO_DINT(StopMsM1)-UDINT_TO_DINT(StopMsM2)); Stopping:=FALSE; SymmetryValid:=TRUE;
    END_IF;
END_IF;
SymmetryOk := SymmetryValid AND (Data.DeltaStartDelay_Ms<=Config.DeltaStartDelay_Ms) AND (Data.DeltaBrakeReleaseTime_Ms<=Config.DeltaBrakeReleaseTime_Ms) AND (Data.DeltaBrakeApplyTime_Ms<=Config.DeltaBrakeApplyTime_Ms) AND (Data.DeltaStopDistance_Mm<=Config.DeltaStopDistance_Mm) AND (Data.DeltaStopTime_Ms<=Config.DeltaStopTime_Ms);
PreviousQualified := Qualified;
