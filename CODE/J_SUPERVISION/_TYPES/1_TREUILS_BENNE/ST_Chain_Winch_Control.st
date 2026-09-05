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
    (* 🔎 Diagnostic anti-redémarrage — "commande active mais rien ne tourne" *)
    Idx415_MotorRequest          : BOOL; // 1 = demande moteur active (palier>0 ET un seul sens) | 0 = pas de demande vue par la barrière
    Idx416_RestartRequired       : BOOL; // 1 = purge anti-redémarrage armée, AuthorizedStep force a 0 tant que non purgee
    Idx417_RestartInhibit        : BOOL; // 1 = verrou latché (frein non confirmé), exige Reset conscient — distinct de Idx416
    Idx418_NeutralRequestSeen    : BOOL; // 1 = passage au neutre observé pendant un RestartInhibit (réarmement en cours)
END_STRUCT
END_TYPE