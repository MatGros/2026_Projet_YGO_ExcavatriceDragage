TYPE ST_Chain_Winch_Control :
STRUCT
    Idx401_MotionAllowed         : BOOL; // 1 = Prêt / Mouvement Autorisé | 0 = Bloqué
    Idx402_SpeedStepCalculated   : INT;  // Palier Vitesse Calculé (0, 1, 2, 3, 4)
    Idx403_SpeedRamp_Pct         : REAL; // [%] Consigne Vitesse après Rampe
    Idx404_BrakeReleaseAuthorized: BOOL; // 1 = Ordre Ouverture Frein | 0 = Ordre Serrage
    Idx405_FinalInterlockState   : E_WinchFinalInterlockState; // 🛡️ État frontière
    Idx406_FinalInterlockReason  : E_WinchFinalInterlockReason; // 🛡️ Cause mémorisée
    Idx407_FinalAuthorizedStep   : INT;  // 🪜 Palier réellement autorisé
    Idx408_BrakeCommandOpenConfirmed : BOOL; // 🔌 Contacteur/bobine, pas frein mécanique
    Idx409_BrakeTimeoutElapsed   : TIME; // ⏱️ Watchdog 500ms écoulé
    Idx410_RestartDelayElapsed   : TIME; // ⏱️ Verrou 900ms écoulé
    Idx411_StepDelayElapsed      : TIME; // ⏱️ Délai palier 1s250 écoulé
    Idx412_InTopSlowdownZone     : BOOL; // 🐢 Palier plafonné à 1, approche limite haute
    Idx413_InBottomSlowdownZone  : BOOL; // 🐢 Palier plafonné à 1, approche limite basse (câble ou légale)
    Idx414_BottomLimitActiveM    : REAL; // : Limite basse active (m) — câble physique OU légale, la plus restrictive
END_STRUCT
END_TYPE