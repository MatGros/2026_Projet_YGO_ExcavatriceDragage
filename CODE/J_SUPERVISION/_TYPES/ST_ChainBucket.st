TYPE ST_ChainBucket :
STRUCT
    Idx101_BucketIsOpen          : BOOL; // 1 = Benne Mécaniquement Ouvert | 0 = Non Confirmé
    Idx102_BucketIsClosed        : BOOL; // 1 = Benne Mécaniquement Fermé | 0 = Non Confirmé
    Idx103_OffsetPos_M           : REAL; // [mètres] Écart d'Ouverture Câble M1/M2
    Idx104_AutoSeqActive         : BOOL; // : 1 = Séquencement auto (ouverture/fermeture armée par mouvement couplé) en cours
    Idx105_StateIncoherent       : BOOL; // : 1 = État ouvert/fermé INCONNU (ni IsOpen ni IsClosed fiable) -- cause fréquente de blocage
    Idx106_FBState               : E_State; // : État machine FB_Bucket (READY/BUSY/DONE/DISABLED)
    Idx107_LastPosM2Open_M       : REAL; // : Dernière position M2 mémorisée "ouvert"
    Idx108_LastPosM2Close_M      : REAL; // : Dernière position M2 mémorisée "fermé"
    Idx109_BucketTooOpen         : BOOL; // ⚠️ Dépassement ouverture : Delta < OffsetOpen - Tolerance (Enrouler M2)
    Idx110_BucketTooClosed       : BOOL; // ⚠️ Dépassement fermeture : Delta > OffsetClose + Tolerance (Dérouler M2)
    Idx111_BucketIsIntermediate  : BOOL; // ↔️ Position intermédiaire (entrebâillée entre ouvert et fermé)
    Idx112_DeltaPosition_M       : REAL; // 📏 Écart réel signé M2 - M1 (mètres) en direct

    Idx201_HmiCmd_BtnOpen        : BOOL; // 1 = Demande Ouverture IHM | 0 = Relâché
    Idx202_HmiCmd_BtnClose       : BOOL; // 1 = Demande Fermeture IHM | 0 = Relâché
    Idx203_CycleCmd_Open         : BOOL; // 1 = Demande Ouverture par le Cycle Auto
    Idx204_CoupledDiveOpenArmed   : BOOL; // : 1 = Ouverture auto armée (descente couplée demandée, benne pas ouverte)
    Idx205_CoupledAscentCloseArmed: BOOL; // : 1 = Fermeture auto armée (montée couplée demandée, benne pas fermée)
    Idx206_CloseReqActive        : BOOL; // : 1 = Fermeture mémorisée/en cours (instBucket.CloseReq -- reste à 1 si recul partiel non terminé)
    Idx207_OpenReqActive         : BOOL; // : 1 = Ouverture mémorisée/en cours (instBucket.OpenReq -- idem)
    Idx208_MotionBlockedByBucket : BOOL; // : 1 = Mouvement couplé BLOQUÉ (auto-séquencement armé mais benne pas Busy -- vérifier Idx306_ErrorIdRaw)

    Idx301_EmergencyChainClosed  : BOOL; // 1 = Boucle Urgence OK | 0 = AU Appuyé
    Idx302_BucketFaultActive     : BOOL; // 0 = Sain | 1 = Défaut Mouvement Benne
    Idx303_KoboldAutoStopEnabled       : BOOL; // 1 = Toggle IHM arrêt auto descente actif
    Idx304_KoboldImmersionConfirmed    : BOOL; // : 1 = Immersion confirmée (front Kobold dans la fenêtre)
    Idx305_KoboldBottomTouchLatched    : BOOL; // : 1 = Fond détecté, descente bloquée (DescendPermitM1/M2_Raw)
    Idx306_ErrorIdRaw             : WORD; // : bitfield brut FB_Bucket (bit0 timeout, bit1 incohérence, bit2 limites, bit3 codeur non référencé, bit4 glissement M1)

    Idx401_BucketBusy            : BOOL; // 1 = Mouvement Mâchoires en cours | 0 = Repos
    Idx402_BucketDone            : BOOL; // 1 = Position Cible Atteinte | 0 = En cours
    Idx403_ControlAscentActive   : BOOL; // : 1 = Phase vitesse contrôlée montée en cours (post-fermeture auto)

    Idx501_M2_CmdRev_DQ          : BOOL; // 1 = Relais Action Benne M2 ON
END_STRUCT
END_TYPE