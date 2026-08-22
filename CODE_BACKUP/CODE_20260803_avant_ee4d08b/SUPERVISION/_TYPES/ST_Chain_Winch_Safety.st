TYPE ST_Chain_Winch_Safety :
STRUCT
    Idx301_EmergencyChainClosed  : BOOL; // 1 = Boucle Urgence OK (Armé) | 0 = Arrêt d'Urgence Appuyé 🔴
    Idx302_SafeStopActive        : BOOL; // 0 = Sain (Autorisé) | 1 = Arrêt Rapide Métier Actif 🔴
    Idx303_PowerCutOffActive     : BOOL; // 0 = Puissance OK | 1 = Coupure Puissance Sécurité 🔴
    Idx304_TopSensorPhysical_DI  : BOOL; // 1 = Capteur Haut Libre (Sain) | 0 = Butée Haute Atteinte 🔴
    Idx305_TopSensorBypassActive : BOOL; // 0 = Capteur Actif | 1 = Capteur Haut Shunté IHM ⚠️
    Idx306_ForbidAscentEffective  : BOOL; // 0 = Montée Autorisée | 1 = MONTÉE BLOQUÉE 🔴
    Idx307_SlackCablePhysical_DI : BOOL; // 1 = Câble Tendu (Sain) | 0 = Mou de Câble Détecté 🔴
    Idx308_SlackCableBypassActive: BOOL; // 0 = Capteur Actif | 1 = Mou de Câble Shunté IHM ⚠️
    Idx309_ForbidDescentEffective: BOOL; // 0 = Descente Autorisée | 1 = DESCENTE BLOQUÉE 🔴
    Idx310_MecaFaultMask          : WORD; // 0 = Pas de Défaut | >0 = Bitfield Défauts Méca A-E 🔴
END_STRUCT
END_TYPE