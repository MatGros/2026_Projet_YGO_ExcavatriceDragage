(* 🔄 Interface IHM du cycle semi-automatique.
   Les commandes Cmd* sont des impulsions acquittées par le PLC. *)
TYPE ST_CycleHMI :
STRUCT
    CmdStart             : BOOL;
    CmdPause             : BOOL;
    CmdAbort             : BOOL;
    CmdReset             : BOOL;
    TargetDepthM         : REAL := -12.5;
    TargetOffsetM        : REAL := 1.5;
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
    LimitLegalDepthM     : REAL;
    WinchSyncError       : BOOL;
    WinchSyncDeltaM      : REAL;
    M1PositionM          : REAL;
    M2PositionM          : REAL;
    DeadmanArmed         : BOOL;
    JoystickMotionActive : BOOL;
    MotionPermit         : BOOL;
    SimKoboldContactFond : BOOL;
END_STRUCT
END_TYPE
