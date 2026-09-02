(* =======================================================================
   ⚙️ ST_fbWinchLoadEstimator_SpeedCfg — Configuration des plages de vitesse linéaire
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Caractérisation des plages de vitesse mesurée par palier (m/s)
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   ======================================================================= *)
TYPE ST_fbWinchLoadEstimator_SpeedCfg :
STRUCT
    MaxMeasuredSpeedMps    : REAL;                                    // Vitesse maximale mesuree de reference (m/s)
    SpeedBandMaxMps        : ARRAY[1..5] OF REAL;                    // Plafonds vitesse mesuree par palier (m/s)
    SpeedBandHysteresisMps : REAL;                                    // Hysteresis anti-battement classement vitesse (m/s)
END_STRUCT
END_TYPE
