TYPE ST_ChainBucket :
STRUCT
    Idx101_BucketIsOpen          : BOOL; // 1 = Benne Mécaniquement Ouvert | 0 = Non Confirmé
    Idx102_BucketIsClosed        : BOOL; // 1 = Benne Mécaniquement Fermé | 0 = Non Confirmé
    Idx103_OffsetPos_M           : REAL; // [mètres] Écart d'Ouverture Câble M1/M2
    Idx104_AutoSeqActive         : BOOL; // 🆕 2026-08-07 : 1 = Séquencement auto (ouverture/fermeture armée par mouvement couplé) en cours

    Idx201_HmiCmd_BtnOpen        : BOOL; // 1 = Demande Ouverture IHM | 0 = Relâché
    Idx202_HmiCmd_BtnClose       : BOOL; // 1 = Demande Fermeture IHM | 0 = Relâché
    Idx203_CycleCmd_Open         : BOOL; // 1 = Demande Ouverture par le Cycle Auto
    Idx204_CoupledDiveOpenArmed   : BOOL; // 🆕 2026-08-07 : 1 = Ouverture auto armée (descente couplée demandée, benne pas ouverte)
    Idx205_CoupledAscentCloseArmed: BOOL; // 🆕 2026-08-07 : 1 = Fermeture auto armée (montée couplée demandée, benne pas fermée)

    Idx301_EmergencyChainClosed  : BOOL; // 1 = Boucle Urgence OK | 0 = AU Appuyé 🔴
    Idx302_BucketFaultActive     : BOOL; // 0 = Sain | 1 = Défaut Mouvement Benne 🔴
    Idx303_KoboldAutoStopEnabled       : BOOL; // 🆕 2026-08-07 (Fiche 05) : 1 = Toggle IHM arrêt auto descente actif
    Idx304_KoboldImmersionConfirmed    : BOOL; // 🆕 2026-08-07 : 1 = Immersion confirmée (front Kobold dans la fenêtre)
    Idx305_KoboldBottomTouchLatched    : BOOL; // 🆕 2026-08-07 : 1 = Fond détecté, descente bloquée (ForbidDescentM1/M2_Raw)

    Idx401_BucketBusy            : BOOL; // 1 = Mouvement Mâchoires en cours | 0 = Repos
    Idx402_BucketDone            : BOOL; // 1 = Position Cible Atteinte | 0 = En cours
    Idx403_ControlAscentActive   : BOOL; // 🆕 2026-08-07 : 1 = Phase vitesse contrôlée montée en cours (post-fermeture auto)

    Idx501_M2_CmdRev_DQ          : BOOL; // 1 = Relais Action Benne M2 ON
END_STRUCT
END_TYPE