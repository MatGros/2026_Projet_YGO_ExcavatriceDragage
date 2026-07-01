(* ═══════════════════════════════════════════════════════════════
   🪜 ST_SpeedStepTable — Table des paliers de vitesse (masque 4 bits)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie2_Architecture_Programme_v2.5.md §8
   🎛️ Table INDÉPENDANTE par treuil (M1 et M2 ont chacun la leur).
   L'ordre d'actionnement n'est pas implicite : il est défini ICI,
   dans les données (StepMask), pas codé en dur dans la logique.
   🧩 Consommée par FB_SpeedStep (décodage % → masque 4 bits).
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_SpeedStepTable :
STRUCT
    // 5 paliers ; chaque palier = masque 4 bits (bit0..bit3 = contacteurs 1..4)
    StepMask          : ARRAY[1..5] OF BYTE;   // ex: StepMask[1] := 2#0001
    // Seuils de changement de palier (%), utilisés par paires successives (HYSTERESIS)
    // Seul StepThreshold_Pct[1..4] est consommé par FB_SpeedStep (transitions palier1→2..4→5)
    StepThreshold_Pct : ARRAY[1..5] OF REAL;
END_STRUCT
END_TYPE
