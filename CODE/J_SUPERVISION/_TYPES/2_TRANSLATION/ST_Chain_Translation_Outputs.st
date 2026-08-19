TYPE ST_Chain_Translation_Outputs :
STRUCT
    Idx501_CmdDriveControlWord   : WORD; // Mot de Commande Transmis EtherCAT AC600
    Idx502_CmdDriveFreq_Hz       : UINT; // [0.01Hz] Consigne Fréquence Transmise EtherCAT
    Idx503_CmdBrakeRelease_RQ    : BOOL; // 1 = Bobine Frein Translation Alimentée (Ouvert)
END_STRUCT
END_TYPE