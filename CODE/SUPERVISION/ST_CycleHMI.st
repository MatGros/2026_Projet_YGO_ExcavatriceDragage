(* 🔄 Interface IHM du cycle semi-automatique.
   Les commandes Cmd* sont des impulsions acquittées par le PLC. *)
TYPE ST_CycleHMI :
STRUCT
    CmdStart             : BOOL;
    CmdPause             : BOOL;
    CmdAbort             : BOOL;
    CmdReset             : BOOL;
    TargetDepth_M         : REAL := -12.5;
    TargetOffset_M        : REAL := 1.5;
    Ready                : BOOL;
    Busy                 : BOOL;
    Done                 : BOOL;
    Error                : BOOL;
    ErrorId              : WORD;
    CycleStep            : E_CycleStep;
    CycleStateStr        : STRING(80);
    SelectedTargetNum    : INT;
    KoboldContactFond    : BOOL;
    KoboldContactorCmd   : BOOL;
    LimitLegalReached    : BOOL;
    LimitLegalDepth_M     : REAL;
    WinchSyncError       : BOOL;
    WinchSyncDelta_M      : REAL;
    SpeedMismatch_Mps     : REAL;
    SpeedMismatchActive  : BOOL;
    SpeedMismatchConfirmed : BOOL;
    M1Position_M          : REAL;
    M2Position_M          : REAL;
    DeadmanArmed         : BOOL;
    JoystickMotionActive : BOOL;
    MotionPermit         : BOOL;
    SimKoboldContactFond : BOOL;
END_STRUCT
END_TYPE
