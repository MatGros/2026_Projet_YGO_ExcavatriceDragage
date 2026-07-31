TYPE ST_Winch_Symmetry_Data :
STRUCT
    DeltaStartDelay_Ms, DeltaBrakeReleaseTime_Ms, DeltaBrakeApplyTime_Ms : UDINT;
    DeltaStopDistance_Mm, DeltaStopTime_Ms : UDINT;
    MaxSyncDeviation_M : REAL;
END_STRUCT
END_TYPE
