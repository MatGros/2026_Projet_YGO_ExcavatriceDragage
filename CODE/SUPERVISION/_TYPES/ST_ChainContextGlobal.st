TYPE ST_ChainContextGlobal :
STRUCT
    Idx101_ModeActive             : E_Mode; // Mode de marche actif (MANUEL, SEMI_AUTO, MAINT_N1, MAINT_N2)
    Idx102_SimulationEnabled      : BOOL;   // 0 = Matériel Réel (Nominal) | 1 = SIMULATION ACTIVE ⚠️
    Idx103_JoystickCommOk         : BOOL;   // 1 = Comm CANopen Joystick OK (Sain) | 0 = Perte Comm CAN 🔴

    Idx201_JoystickSelected       : BOOL;   // 1 = Pilotage par Joystick Hall | 0 = Pilotage par Boutons IHM
    Idx202_BypassNetworkGlobal    : BOOL;   // 0 = Comm Réseau OK | 1 = BYPASS RÉSEAU ACTIF ⚠️
    Idx203_BypassSensorsGlobal    : BOOL;   // 0 = Capteurs Actifs | 1 = AU MOINS 1 CAPTEUR SHUNTÉ ⚠️

    Idx301_EmergencyChainClosed   : BOOL;   // 1 = Boucle AU Matérielle Fermée (OK) | 0 = AU APPUYÉ 🔴
    Idx302_EmergencyStopOk        : BOOL;   // 1 = Puissance Armée | 0 = Puissance Coupée 🔴
    Idx303_SafeStopActiveAny      : BOOL;   // 0 = Sain | 1 = AU MOINS UN SAFESTOP MÉTIER ACTIF 🔴
    Idx304_PowerCutOffActiveAny   : BOOL;   // 0 = Sain | 1 = COUPURE GENERAL COLLAGE ACTIVEE 🔴

    Idx401_HmiHeartbeatOk         : BOOL;   // 1 = Liaison IHM Active | 0 = Perte Liaison IHM 🔴
    Idx402_CycleAutoBusy          : BOOL;   // 1 = Séquenceur Auto en Cours | 0 = Repos
END_STRUCT
END_TYPE