(* ═══════════════════════════════════════════════════════════════
   🧲 ST_EncoderCalib — Calibration/référence codeur (1 par treuil, RETAIN)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie10_Fonction_Encoder_Homing_v1.2.md §9
   🎛️ Une instance RETAIN par treuil (M1_EncoderCalib / M2_EncoderCalib).
   ⚠️ Ce lot (acquisition + mise à l'échelle) : `HomingRefRaw` reste
      modifiable MANUELLEMENT (RETAIN, valeur de test) tant que
      `FB_Encoder_Homing` (qui l'écrit normalement, §5) n'est pas codé —
      même principe que le stub GVL du lot Winch.
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_EncoderCalib :
STRUCT
    HomingRefRaw                  : UDINT;   // Valeur brute figée au dernier homing réussi
    LastKnownRawPos                : UDINT;   // Dernier point brut valide connu (§3.7, continu)
    RestartCoherenceTolerancePts    : UDINT := 1000;  // Tolérance redémarrage (~12% PointsPerRev 8192)
    Homed                          : BOOL;    // TRUE dès qu'un référencement a réussi
    HomingSuspect                  : BOOL;    // TRUE si incohérence détectée au redémarrage (§3.7)
END_STRUCT
END_TYPE
