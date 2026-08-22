TYPE ST_Chain_Translation_Control :
STRUCT
    Idx401_MotionAllowed         : BOOL; // 1 = Mouvement Translation Autorisé | 0 = Bloqué
    Idx402_SetpointFreq_Hz       : REAL; // [Hz] Consigne Fréquence Calculée
    Idx403_DriveControlWord      : WORD; // Mot de Commande Calculé Variateur AC600
    Idx404_FinalInterlockState   : E_State; // 🛡️ État frontière _LD
    Idx405_FinalInterlockReason  : E_TranslationFinalInterlockReason; // 🛡️ Cause mémorisée
    Idx406_BrakeCommandOpenConfirmed : BOOL; // 🔌 Contacteur/bobine, pas frein mécanique
    Idx407_BrakeTimeoutElapsed   : TIME; // ⏱️ Watchdog 500ms écoulé
END_STRUCT
END_TYPE