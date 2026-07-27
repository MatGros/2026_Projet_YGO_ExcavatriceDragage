TYPE ST_Chain_Translation_Control :
STRUCT
    Idx401_MotionAllowed         : BOOL; // 1 = Mouvement Translation Autorisé | 0 = Bloqué
    Idx402_SetpointFreq_Hz       : REAL; // [Hz] Consigne Fréquence Calculée
    Idx403_DriveControlWord      : WORD; // Mot de Commande Calculé Variateur AC600
END_STRUCT
END_TYPE