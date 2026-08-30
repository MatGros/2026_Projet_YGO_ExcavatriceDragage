(* =======================================================================
   💾 ST_Encoder_Calib — Calibration & référence codeur (1 par treuil, RETAIN)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Structure de calibration RETAIN par treuil (M1_EncoderCalib / M2_EncoderCalib)
   💾 Données : Références brutes, état homed et contrôle de cohérence redémarrage
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md
   ======================================================================= *)

TYPE ST_Encoder_Calib :
STRUCT
    // === DONNEES DE REFERENCE BRUTE (RETAIN) ===
    HomingRefRaw                 : UDINT;         // Valeur brute figee au dernier homing reussi
    LastKnownRawPos               : UDINT;         // Dernier point brut valide connu (continu)

    // === CONFIGURATION & REGLAGES TOLERANCE ===
    RestartCoherenceTolerancePts   : UDINT := 1000; // Tolerance redemarrage (pts, ~12% de 8192)

    // === ETATS DE CALIBRATION & SECURITE ===
    Homed                         : BOOL;          // TRUE des qu'un referencement a reussi
    HomingSuspect                 : BOOL;          // TRUE si incoherence detectee au redemarrage
END_STRUCT
END_TYPE
