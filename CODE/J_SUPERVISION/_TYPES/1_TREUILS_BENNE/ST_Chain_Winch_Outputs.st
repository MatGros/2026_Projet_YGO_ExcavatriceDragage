TYPE ST_Chain_Winch_Outputs :
STRUCT
    Idx501_CmdRelayFwd_Up_DQ     : BOOL; // 1 = Relais Ascending ON | 0 = OFF
    Idx502_CmdRelayRev_Down_DQ   : BOOL; // 1 = Relais Descending ON | 0 = OFF
    Idx503_CmdSpeedContactor1_DQ : BOOL; // 1 = Contacteur Vitesse 1 ON | 0 = OFF
    Idx504_CmdSpeedContactor4_DQ : BOOL; // 1 = Contacteur Vitesse 4 ON (Plein Gaz) | 0 = OFF
    Idx505_CmdBrakeRelease_RQ    : BOOL; // 1 = Bobine Frein Alimentée (Ouvert) | 0 = Non Alimentée (Serré)
END_STRUCT
END_TYPE