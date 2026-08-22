TYPE ST_Winch_SymmetryCfg :
STRUCT
    DeltaStartDelay_Ms : UDINT := 100;
    DeltaBrakeReleaseTime_Ms : UDINT := 100;
    DeltaBrakeApplyTime_Ms : UDINT := 100;
    DeltaStopDistance_Mm : UDINT := 100;
    DeltaStopTime_Ms : UDINT := 200;
    MinimumCommandTime_Ms : UDINT := 1000;
    MinimumSpeed_Mps : REAL := 0.05;
END_STRUCT
END_TYPE
