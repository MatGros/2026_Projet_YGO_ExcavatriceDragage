(* ═══════════════════════════════════════════════════════════════
   🧲 ST_Encoder_Calib — Calibration & référence codeur (1 par treuil, RETAIN)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-09_Fonction_Encoder_v2.1.md
                   DOC/AF_Partie-03_Contrats_Composants_v2.1.md
   🎛️ Une instance RETAIN par treuil (M1_EncoderCalib / M2_EncoderCalib).
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_Encoder_Calib :
STRUCT
    HomingRefRaw                  : UDINT;   // Valeur brute figée au dernier homing réussi
    LastKnownRawPos                : UDINT;   // Dernier point brut valide connu (§3.7, continu)
    RestartCoherenceTolerancePts    : UDINT := 1000;  // Tolérance redémarrage (~12% PointsPerRev 8192)
    Homed                          : BOOL;    // TRUE dès qu'un référencement a réussi
    HomingSuspect                  : BOOL;    // TRUE si incohérence détectée au redémarrage (§3.7)
END_STRUCT
END_TYPE
