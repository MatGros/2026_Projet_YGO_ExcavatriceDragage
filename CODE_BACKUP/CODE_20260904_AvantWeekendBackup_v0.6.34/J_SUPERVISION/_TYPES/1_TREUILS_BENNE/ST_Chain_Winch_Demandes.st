TYPE ST_Chain_Winch_Demandes :
STRUCT
    Idx201_JoyRawPhysical_ANA    : INT;  // [pts] Bruts convertisseur (-2048 à +2048)
    Idx202_JoyScaledPhysical_Pct : REAL; // [%] Consigne Joystick (-100% à +100%)
    Idx203_HmiManualCmd_BtnAscent : BOOL; // 1 = Appui Bouton Ascending IHM | 0 = Relâché
    Idx204_HmiManualCmd_BtnDescent : BOOL; // 1 = Appui Bouton Descending IHM | 0 = Relâché
    Idx205_CycleAutoCmd_Pct      : REAL; // [%] Consigne auto envoyée par le Cycle
    Idx206_ModeActive            : E_Mode;// Mode courant (MANU_N1, AUTO_N1, MAINT_N2...)
    Idx207_BypassOperatorComm    : BOOL; // 0 = Comm Normale OK | 1 = Bypass Réseau Actif ⚠️
    Idx208_ArbitratedSpeed_Pct   : REAL; // [%] Consigne finale retenue après arbitrage
    Idx209_ArbitratedDirection   : INT;  // +1 = Ascending | 0 = Neutre | -1 = Descending
    Idx210_CoupledUserRequestDirection : INT; // +1 = Ascending | 0 = Neutre | -1 = Descending
    Idx211_CoupledUserRequestActive    : BOOL; // 1 = demande utilisateur couplée active
END_STRUCT
END_TYPE