TYPE ST_Chain_Winch_Inputs :
STRUCT
    Idx101_EncoderRawPos         : DINT; // [Valeur brutes pts] Codeur connecté
    Idx102_CablePos_M            : REAL; // [mètres] Position calculée du câble
    Idx103_ContactorsReleased_DI : BOOL; // 1 = OK (Tous contacteurs retombés à l'arrêt) | 0 = Contacteur collé 🔴
    Idx104_BrakeApplied          : BOOL; // TRUE = frein SERRÉ (NOT BrakeFeedback — IHM garde le sens serré)
    Idx105_ThermalOk_DI          : BOOL; // 1 = Température OK (Sain) | 0 = Surchauffe Moteur M1 🔴
END_STRUCT
END_TYPE
