TYPE ST_Chain_Translation_Demandes :
STRUCT
    Idx201_JoyXRaw_ANA           : INT;  // [pts] Bruts Joystick Axe X
    Idx202_JoyXScaled_Pct        : REAL; // [%] Consigne Joystick Axe X (-100% à +100%)
    Idx203_HmiCmd_BtnTremie : BOOL; // 1 = Bouton vers Trémie IHM | 0 = Relâché (ex-Idx203_HmiCmd_BtnFwd)
    Idx204_HmiCmd_BtnMaintenance : BOOL; // 1 = Bouton vers Maintenance IHM | 0 = Relâché (ex-Idx204_HmiCmd_BtnRev)
    Idx205_HmiTargetPosition     : INT;  // Cible Sélectionnée IHM (1=Trémie, 2=P2, 3=P1)
    Idx206_CycleTargetPosition   : INT;  // Cible Sélectionnée par le Cycle Auto
    Idx207_ModeActive            : E_Mode;// Mode courant (MANU_N1, AUTO_N1...)
    Idx208_BypassNetworkActive   : BOOL; // 0 = Comm Variateur OK | 1 = Bypass Réseau Actif ⚠️
    Idx209_ArbitratedSpeed_Pct   : REAL; // [%] Consigne finale Vitesse Translation
END_STRUCT
END_TYPE