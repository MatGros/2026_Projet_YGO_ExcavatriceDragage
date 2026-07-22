(* 🔄 Interface IHM du cycle semi-automatique.
   Les commandes Cmd* sont des impulsions acquittées par le PLC. *)
TYPE ST_CycleHMI :
STRUCT
    CmdStart             : BOOL;
    CmdPause             : BOOL;
    CmdAbort             : BOOL;
    CmdReset             : BOOL;
    SetDepthM          : REAL := -12.5;
    SetOffsetM         : REAL := 1.5;
    Ready                : BOOL;
    Busy                 : BOOL;
    Done                 : BOOL;
    Error                : BOOL;
    ErrorId              : WORD;
    CycleStep            : E_CycleStep;
    CycleStateStr        : STRING(80);
    SelTarget    : INT;
    KoboldContactFond    : BOOL;
    KoboldContactorCmd   : BOOL;
    LimitLegalReached    : BOOL;
    LimitLegalDepthM      : REAL;
    WinchSyncError       : BOOL;
    WinchSyncDeltaM       : REAL;
    SpeedMismatchMps      : REAL;
    SpeedMismatchActive  : BOOL;
    SpeedMismatchConfirmed : BOOL;
    M1PositionM           : REAL;
    M2PositionM           : REAL;
    DeadmanArmed         : BOOL;
    JoystickMotionActive : BOOL;
    MotionPermit         : BOOL;
    TstKoboldContactFond : BOOL;
END_STRUCT
END_TYPE
