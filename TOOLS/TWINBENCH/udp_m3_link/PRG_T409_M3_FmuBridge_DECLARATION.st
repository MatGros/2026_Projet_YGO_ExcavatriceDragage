VAR
    Enable              : BOOL := FALSE;
    Stop                : BOOL := FALSE;
    LinkReady           : BOOL := FALSE;
    LinkInvalid         : BOOL := FALSE;
    Timeout             : BOOL := FALSE;
    SensorWordIncoherent: BOOL := FALSE;
    FmuPosition_M       : REAL := 0.0;
    FmuVelocity_Mps     : REAL := 0.0;
    FmuFrequency_Hz     : REAL := 0.0;
    FmuState            : USINT := 0; // 0=Unknown, 1=AtTremie, 2=Between, 3=AtMaintenance, 4=HardStop
    FmuAge_ms           : UDINT := 0;
    TxCount             : UDINT := 0;
    RxCount             : UDINT := 0;
    RejectCount         : UDINT := 0;
    Sequence            : UDINT := 0;
    LastRxSequence      : UDINT := 0;
    LastRxAgeCycles     : UINT := 0;
    LastResult          : SysTypes.RTS_IEC_RESULT := 0;
    SocketHandle        : SysTypes.RTS_IEC_HANDLE := SysTypes.RTS_INVALID_HANDLE;
    NonBlocking         : DINT := 1;
    Reply               : UDP_REPLY;
    Tx                  : ARRAY [0..31] OF BYTE;
    Rx                  : ARRAY [0..63] OF BYTE;
    Bytes               : __XINT := 0;
    RxSequence          : UDINT := 0;
    RxCommandSequence   : UDINT := 0;
    RxFrequency_x100    : UINT := 0;
    RxVelocity_x1000    : DINT := 0;
    RxPosition_x1000    : DINT := 0;
    RxVelocity_x1000    : DINT := 0;
    RxBrakeOpen         : BOOL := FALSE;
    RxStatusWord        : WORD := WORD#0;
    RxSensors           : ARRAY [0..4] OF BOOL;
    RxHardStop          : BOOL := FALSE;
END_VAR
