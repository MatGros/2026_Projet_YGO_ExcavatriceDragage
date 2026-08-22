TYPE ST_WinchSymmetryHMI :
STRUCT
    BtnReset : BOOL;
    SymmetryOk : BOOL;
    SymmetryValid : BOOL;
    DeltaStartDelay_Ms : UDINT;
    DeltaBrakeReleaseTime_Ms : UDINT;
    DeltaBrakeApplyTime_Ms : UDINT;
    DeltaStopDistance_M : REAL;
    DeltaStopTime_Ms : UDINT;
    MaxSyncDeviation_M : REAL;
END_STRUCT
END_TYPE
