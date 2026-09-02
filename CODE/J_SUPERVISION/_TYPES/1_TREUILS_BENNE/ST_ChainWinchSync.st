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

    // === Discordance contacteurs M1/M2 (FB_SyncContactor sur vecteurs finaux PRG_06) ===
    Idx310_ContactorMismatch          : BOOL; // 1 = discordance confirmee (debounce 500 ms) -> SafeStop des 2 treuils
    Idx311_ContactorMismatchEscalated : BOOL; // 1 = discordance persistante -> escalade PowerCutOff
    Idx312_ContactorMismatchLevel     : INT;  // 0 aucun / 1 confirme (SafeStop) / 2 escalade (PowerCutOff)
    Idx313_Mismatch_RelayFwd          : BOOL; // 1 = relais montee M1 <> M2
    Idx314_Mismatch_RelayRev          : BOOL; // 1 = relais descente M1 <> M2
    Idx315_Mismatch_SpeedContactor1   : BOOL; // 1 = contacteur palier 1 M1 <> M2
    Idx316_Mismatch_SpeedContactor2   : BOOL; // 1 = contacteur palier 2 M1 <> M2
    Idx317_Mismatch_SpeedContactor3   : BOOL; // 1 = contacteur palier 3 M1 <> M2
    Idx318_Mismatch_SpeedContactor4   : BOOL; // 1 = contacteur palier 4 M1 <> M2
END_STRUCT
END_TYPE