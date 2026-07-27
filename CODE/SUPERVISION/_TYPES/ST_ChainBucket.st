TYPE ST_ChainBucket :
STRUCT
    Idx101_BucketIsOpen          : BOOL; // 1 = Benne Mécaniquement Ouvert | 0 = Non Confirmé
    Idx102_BucketIsClosed        : BOOL; // 1 = Benne Mécaniquement Fermé | 0 = Non Confirmé
    Idx103_OffsetPos_M           : REAL; // [mètres] Écart d'Ouverture Câble M1/M2

    Idx201_HmiCmd_BtnOpen        : BOOL; // 1 = Demande Ouverture IHM | 0 = Relâché
    Idx202_HmiCmd_BtnClose       : BOOL; // 1 = Demande Fermeture IHM | 0 = Relâché
    Idx203_CycleCmd_Open         : BOOL; // 1 = Demande Ouverture par le Cycle Auto

    Idx301_EmergencyChainClosed  : BOOL; // 1 = Boucle Urgence OK | 0 = AU Appuyé 🔴
    Idx302_BucketFaultActive     : BOOL; // 0 = Sain | 1 = Défaut Mouvement Benne 🔴

    Idx401_BucketBusy            : BOOL; // 1 = Mouvement Mâchoires en cours | 0 = Repos
    Idx402_BucketDone            : BOOL; // 1 = Position Cible Atteinte | 0 = En cours

    Idx501_M2_CmdRev_DQ          : BOOL; // 1 = Relais Action Benne M2 ON
END_STRUCT
END_TYPE