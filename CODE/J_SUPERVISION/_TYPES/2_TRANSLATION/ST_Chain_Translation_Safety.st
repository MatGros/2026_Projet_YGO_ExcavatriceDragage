TYPE ST_Chain_Translation_Safety :
STRUCT
    Idx301_EmergencyChainClosed  : BOOL; // 1 = Boucle Urgence OK | 0 = Arrêt d'Urgence Appuyé
    Idx302_SafeStopActive        : BOOL; // 0 = Sain (Autorisé) | 1 = Arrêt Rapide Translation
    Idx303_PowerCutOffActive     : BOOL; // 0 = Puissance OK | 1 = Coupure Puissance
    Idx304_LimitSwitchFwdActive  : BOOL; // 0 = Sain | 1 = Fin de Course Extrême Avance
    Idx305_LimitSwitchRevActive  : BOOL; // 0 = Sain | 1 = Fin de Course Extrême Recul
    Idx306_BypassLimitSwitch     : BOOL; // 0 = Fins de course actives | 1 = Shuntés IHM ⚠️
    Idx307_PositionDecoderIncoherent: BOOL; // 0 = Décodage 5 Capteurs OK | 1 = Incohérence Position
    Idx308_HeightInterlockBlocking: BOOL; // : 0 = M1 ET M2 ≥ hauteur mini (ou bypass) | 1 = Translation bloquée (risque collision)
    (* Défauts safety déchiffrés (bits ErrorId) — visibles individuellement à l'IHM *)
    Idx309_ErrorOperatorComm : BOOL; // bit0 Perte communication opérateur (joystick CAN / heartbeat IHM)
    Idx310_ErrorDriveComm    : BOOL; // bit1 Perte communication EtherCAT variateur
    Idx311_ErrorPhaseRotation: BOOL; // bit2 Mauvaise rotation de phases
    Idx312_ErrorBrakeThermal : BOOL; // bit3 Surchauffe thermique frein commun
    Idx313_ErrorMecaB        : BOOL; // bit4 Absence confirmation arrêt
    Idx314_ErrorMecaA        : BOOL; // bit5 Mouvement non commandé
    Idx315_ErrorLimitSwitch  : BOOL; // bit6 Limite extrême atteinte
    Idx316_ErrorSensorIncoherent: BOOL; // bit7 Mot capteurs position incohérent
END_STRUCT
END_TYPE