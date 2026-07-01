(* ═══════════════════════════════════════════════════════════════
   🪜 FB_SpeedStep — Décodeur palier → masque 4 bits (1 par treuil)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie9_Fonction_Winch_v1.0.md
   📥 SpeedRefPct    : consigne 0..100 % (déjà rampée en amont, ABS)
   📥 Table          : ST_SpeedStepTable propre AU TREUIL appelant
                       (M1 et M2 ont chacune la leur — pas de table globale)
   📤 StepMask       : masque 4 bits actif (bit0..bit3 = contacteurs 1..4)
   📤 StepNumber     : n° palier courant (0 = arrêt, 1..5)
   🧩 Réutilisation lib Util (Partie3 §0) : HYSTERESIS pour la sélection
      de palier anti-battement — AUCUN seuil "maison" recalculé.
   ⚠️ Brique réduite (Partie3 §1bis) : pas d'Enable/Reset/Error au sens
      "FB métier" — c'est un décodeur pur, composé À L'INTÉRIEUR de
      FB_Winch, qui porte lui la sécurité/le contrat complet.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_SpeedStep) ===

FUNCTION_BLOCK PUBLIC FB_SpeedStep
VAR_INPUT
    Enable      : BOOL;               // Piloté par FB_Winch : FALSE = treuil à l'arrêt (palier 0)
    SpeedRefPct : REAL;                // Consigne vitesse 0..100 % (déjà rampée par FB_Winch)
    Table       : ST_SpeedStepTable;   // Table des 5 paliers (masques + seuils), propre à CE treuil
    HystMargin  : REAL := 2.0;         // Marge anti-battement (%) entre 2 changements de palier
END_VAR
VAR_OUTPUT
    StepMask    : BYTE;   // Masque 4 bits actif (bit0..bit3 = contacteurs 1..4), 0 si Enable=FALSE
    StepNumber  : INT;    // N° palier courant (0 = arrêt, 1..5)
END_VAR
VAR
    Hyst1       : HYSTERESIS;   // 🧱 Lib Util — transition palier 1→2
    Hyst2       : HYSTERESIS;   // 🧱 Lib Util — transition palier 2→3
    Hyst3       : HYSTERESIS;   // 🧱 Lib Util — transition palier 3→4
    Hyst4       : HYSTERESIS;   // 🧱 Lib Util — transition palier 4→5
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_SpeedStep) ===

// 🛑 1. GATE — pas de mouvement demandé = palier 0, masque à 0
IF NOT Enable THEN
    StepMask := 0;
    StepNumber := 0;
    RETURN;
END_IF;

// 🪜 2. SÉLECTION DU PALIER (HYSTERESIS anti-battement, seuils = données de la table)
Hyst1(XIN1 := SpeedRefPct, XIN2 := Table.StepThreshold_Pct[1], EPSILON := HystMargin);
Hyst2(XIN1 := SpeedRefPct, XIN2 := Table.StepThreshold_Pct[2], EPSILON := HystMargin);
Hyst3(XIN1 := SpeedRefPct, XIN2 := Table.StepThreshold_Pct[3], EPSILON := HystMargin);
Hyst4(XIN1 := SpeedRefPct, XIN2 := Table.StepThreshold_Pct[4], EPSILON := HystMargin);

StepNumber := 1;                       // Palier mini dès qu'Enable est actif
IF Hyst1.Q THEN StepNumber := 2; END_IF;
IF Hyst2.Q THEN StepNumber := 3; END_IF;
IF Hyst3.Q THEN StepNumber := 4; END_IF;
IF Hyst4.Q THEN StepNumber := 5; END_IF;

// 📤 3. MASQUE — lu dans la table (donnée, jamais codé en dur)
StepMask := Table.StepMask[StepNumber];
