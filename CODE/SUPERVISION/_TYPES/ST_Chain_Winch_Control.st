TYPE ST_Chain_Winch_Control :
STRUCT
    Idx401_MotionAllowed         : BOOL; // 1 = Prêt / Mouvement Autorisé | 0 = Bloqué
    Idx402_SpeedStepCalculated   : INT;  // Palier Vitesse Calculé (0, 1, 2, 3, 4)
    Idx403_SpeedRamp_Pct         : REAL; // [%] Consigne Vitesse après Rampe
    Idx404_BrakeReleaseAuthorized: BOOL; // 1 = Ordre Ouverture Frein | 0 = Ordre Serrage
END_STRUCT
END_TYPE