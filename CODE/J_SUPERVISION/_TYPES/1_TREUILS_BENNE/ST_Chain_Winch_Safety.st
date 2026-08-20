TYPE ST_Chain_Winch_Safety :
STRUCT
    Idx301_EmergencyChainClosed  : BOOL; // 1 = Boucle Urgence OK (Armé) | 0 = Arrêt d'Urgence Appuyé
    Idx302_SafeStopActive        : BOOL; // 0 = Sain (Autorisé) | 1 = Arrêt Rapide Métier Actif
    Idx303_PowerCutOffActive     : BOOL; // 0 = Puissance OK | 1 = Coupure Puissance Sécurité
    Idx304_TopSensorPhysical_DI  : BOOL; // 1 = Capteur Haut Libre (Sain) | 0 = Butée Haute Atteinte
    Idx305_TopSensorBypassActive : BOOL; // 0 = Capteur Actif | 1 = Capteur Haut Shunté IHM ⚠️
    Idx306_AscentPermitEffective  : BOOL; // 1 = Montée Autorisée | 0 = MONTÉE BLOQUÉE
    Idx307_SlackCablePhysical_DI : BOOL; // 1 = Câble Tendu (Sain) | 0 = Mou de Câble Détecté
    Idx308_SlackCableBypassActive: BOOL; // 0 = Capteur Actif | 1 = Mou de Câble Shunté IHM ⚠️
    Idx309_DescendPermitEffective: BOOL; // 1 = Descente Autorisée | 0 = DESCENTE BLOQUÉE
    (* Défauts safety déchiffrés (bits ErrorId) — visibles individuellement à l'IHM *)
    Idx310_ErrorOperatorComm : BOOL; // bit0 Perte communication opérateur (joystick CAN / heartbeat IHM)
    Idx311_ErrorEncoder      : BOOL; // bit1 Perte codeur de ce treuil
    Idx312_ErrorPhaseRotation: BOOL; // bit4 Mauvaise rotation de phases
    Idx313_ErrorMecaA        : BOOL; // bit7 Mouvement non commandé / roue libre
    Idx314_ErrorMecaB        : BOOL; // bit8 Absence confirmation arrêt sans commande
    Idx315_ErrorMecaC        : BOOL; // bit9 Glissement M1 pendant cycle benne
    Idx316_ErrorMecaD        : BOOL; // bit11 Non-arrêt sur capteur haut
    Idx317_ErrorMecaE        : BOOL; // bit12/13 Écart synchro critique M1/M2
    Idx318_ErrorBrakeThermal : BOOL; // bit10 Surchauffe thermique frein commun
    Idx319_ErrorOppositeDir  : BOOL; // bit14 Sens réel opposé au sens commandé
    Idx320_ErrorNoMovement   : BOOL; // bit15 Absence de mouvement malgré commande
END_STRUCT
END_TYPE