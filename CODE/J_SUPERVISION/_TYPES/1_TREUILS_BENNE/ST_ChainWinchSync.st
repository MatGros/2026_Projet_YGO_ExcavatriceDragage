TYPE ST_ChainWinchSync :
STRUCT
    Idx101_M1_CablePos_M         : REAL; // [mètres] Position Câble M1 Retenue
    Idx102_M2_CablePos_M         : REAL; // [mètres] Position Câble M2 Benne
    Idx103_SyncDelta_M           : REAL; // [mètres] Écart Relatif M1 - M2

    Idx201_JoyYRaw_Pct           : REAL; // [%] Consigne Joystick Axe Y (-100% à +100%)
    Idx202_SyncEnabled_IHM       : BOOL; // 1 = Couplage Synchro Actif (Nominal) | 0 = Découplé ⚠️
    Idx203_ArbitratedSpeed_Pct   : REAL; // [%] Consigne Vitesse Synchro Arbitrée

    Idx301_EmergencyChainClosed  : BOOL; // 1 = Boucle Urgence OK | 0 = Arrêt Urgence
    Idx302_SyncFaultActive       : BOOL; // 0 = Synchro OK | 1 = Écart Synchro Bloquant
    Idx303_M1_AscentPermit       : BOOL; // 1 = Ascending M1 Autorisée | 0 = Bloquée (Fdc/Safety)
    Idx304_M2_AscentPermit       : BOOL; // 1 = Ascending M2 Autorisée | 0 = Bloquée (Fdc/Safety)

    Idx401_SyncMotionAllowed     : BOOL; // 1 = Mouvement Synchro Autorisé | 0 = Bloqué
    Idx402_M1_SetpointSpeed_Pct  : REAL; // [%] Consigne Vitesse Calculée M1
    Idx403_M2_SetpointSpeed_Pct  : REAL; // [%] Consigne Vitesse Calculée M2

    Idx501_M1_CmdRelayFwd_DQ     : BOOL; // 1 = Ascending M1 ON | 0 = OFF
    Idx502_M2_CmdRelayFwd_DQ     : BOOL; // 1 = Ascending M2 ON | 0 = OFF
END_STRUCT
END_TYPE