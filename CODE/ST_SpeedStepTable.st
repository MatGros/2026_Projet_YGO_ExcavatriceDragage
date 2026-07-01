(* ═══════════════════════════════════════════════════════════════
   🪜 ST_SpeedStepTable — Table des paliers de vitesse (1 par treuil)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie9_Fonction_Winch_v1.0.md
   🎛️ Table INDÉPENDANTE par treuil (M1 et M2 ont chacun la leur).
   ⚠️ ÉVOLUTION (retour terrain 2026-07-01, remplace le masque BYTE
      packé de la 1ère version) : chaque contacteur de vitesse de
      chaque palier est un BOOL nommé individuellement
      `P<palier>R<relais>` (ex. `P1R1`, `P3R2`) — paramétrable un par
      un pendant la mise en service (visible/modifiable directement
      dans la vue instance CODESYS), sans manipuler un masque binaire
      packé. `P` = Palier, `R` = Relais (contacteur de vitesse 1..4).
   L'ordre d'actionnement n'est pas implicite : il est défini ICI,
   dans les données, pas codé en dur dans la logique (FB_SpeedStep).
   ═══════════════════════════════════════════════════════════════ *)

TYPE ST_SpeedStepTable :
STRUCT
    // Palier 1 (vitesse la plus faible)
    P1R1 : BOOL;
    P1R2 : BOOL;
    P1R3 : BOOL;
    P1R4 : BOOL;
    // Palier 2
    P2R1 : BOOL;
    P2R2 : BOOL;
    P2R3 : BOOL;
    P2R4 : BOOL;
    // Palier 3
    P3R1 : BOOL;
    P3R2 : BOOL;
    P3R3 : BOOL;
    P3R4 : BOOL;
    // Palier 4
    P4R1 : BOOL;
    P4R2 : BOOL;
    P4R3 : BOOL;
    P4R4 : BOOL;
    // Palier 5 (vitesse la plus élevée)
    P5R1 : BOOL;
    P5R2 : BOOL;
    P5R3 : BOOL;
    P5R4 : BOOL;
    // Seuils de changement de palier (%), utilisés par paires successives (HYSTERESIS)
    // Seul StepThreshold_Pct[1..4] est consommé par FB_SpeedStep (transitions palier1→2..4→5)
    StepThreshold_Pct : ARRAY[1..5] OF REAL;
END_STRUCT
END_TYPE
