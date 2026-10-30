(* Test-only mirror of the retired external-M3 link payload.
   Production code no longer ships the OpenModelica link; FB_SimBench CI still
   requires its interface because MOCK_FB_Sim_Translation_ExtLink exposes it. *)
TYPE ST_fbSim_Translation_ExtLink_Echo :
STRUCT
    Mode                    : E_Mode;
    FBState                 : E_State;
    AxisBlockReason         : E_TranslationTraceBlockReason;
    MaintenanceTargetEnable : BOOL;
    MaintenanceZoneAccess   : BOOL;
    SafeStop                : BOOL;
    PowerCutOff             : BOOL;
    LimitSwitchTremie       : BOOL;
    LimitSwitchMaintenance  : BOOL;
    PositionReached         : BOOL;
    ActiveTremie            : BOOL;
    ActiveMaintenance       : BOOL;
    AtTremie                : BOOL;
    AtPV                    : BOOL;
    AtP2                    : BOOL;
    AtP1                    : BOOL;
    AtMaintenance           : BOOL;
    SensorWordIncoherent    : BOOL;
    EstimatedPos_M          : REAL;
    SafetyErrorId           : WORD;
END_STRUCT
END_TYPE
