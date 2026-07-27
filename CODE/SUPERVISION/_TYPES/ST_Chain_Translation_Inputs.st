TYPE ST_Chain_Translation_Inputs :
STRUCT
    Idx101_PosTremie_DI          : BOOL; // 1 = Position Trémie Atteinte | 0 = Absent
    Idx102_PosPV_DI              : BOOL; // 1 = Zone Ralentissement PV Atteinte | 0 = Absent
    Idx103_PosP2_DI              : BOOL; // 1 = Position Fosse P2 Atteinte | 0 = Absent
    Idx104_PosP1_DI              : BOOL; // 1 = Position Fosse P1 Atteinte | 0 = Absent
    Idx105_PosMaintenance_DI     : BOOL; // 1 = Position Service Maintenance Atteinte | 0 = Absent
    Idx106_DriveActualFreq_Hz    : REAL; // [Hz] Fréquence Réelle Mesurée Variateur
    Idx107_DriveStatusWord       : WORD; // Mot d'état Brut Variateur AC600
    Idx108_BrakeApplied          : BOOL; // TRUE = frein SERRÉ normalisé (PRG_00 après BrakeFeedbackInvertLogic)
END_STRUCT
END_TYPE
