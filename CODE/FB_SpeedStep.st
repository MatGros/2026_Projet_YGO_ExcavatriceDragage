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
   ⚠️ CORRECTIF (erreur compilation 2026-07-01) : l'interface réelle de
      HYSTERESIS (lib Util 3.5.19.0) est `IN/HIGH/LOW : INT` →
      `OUT : BOOL` (TRUE si IN < LOW, FALSE si IN > HIGH, maintien entre
      les deux) — PAS `XIN1/XIN2/EPSILON → Q` comme dans la 1ère version.
      `SpeedRefPct` (REAL) est donc converti en INT (`REAL_TO_INT`) avant
      appel ; perte de précision infra-1 % acceptable pour un sélecteur
      à 5 paliers grossiers.
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
    HystMargin  : REAL := 2.0;         // Marge anti-battement (%) autour de chaque seuil
END_VAR
VAR_OUTPUT
    StepMask    : BYTE;   // Masque 4 bits actif (bit0..bit3 = contacteurs 1..4), 0 si Enable=FALSE
    StepNumber  : INT;    // N° palier courant (0 = arrêt, 1..5)
END_VAR
VAR
    SpeedRefInt : INT;          // Consigne convertie en INT (interface HYSTERESIS)
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

// 🪜 2. SÉLECTION DU PALIER (HYSTERESIS lib Util : IN/HIGH/LOW → OUT)
//    OUT = TRUE tant que IN < LOW (régime "bas") ; OUT bascule à FALSE une fois
//    IN > HIGH (régime "haut" confirmé) ; maintien entre LOW et HIGH (anti-battement).
//    => NOT Hyst_n.OUT = "on a franchi le seuil n vers le haut" (palier n+1 atteint).
SpeedRefInt := REAL_TO_INT(SpeedRefPct);

Hyst1(IN := SpeedRefInt, HIGH := REAL_TO_INT(Table.StepThreshold_Pct[1] + HystMargin), LOW := REAL_TO_INT(Table.StepThreshold_Pct[1] - HystMargin));
Hyst2(IN := SpeedRefInt, HIGH := REAL_TO_INT(Table.StepThreshold_Pct[2] + HystMargin), LOW := REAL_TO_INT(Table.StepThreshold_Pct[2] - HystMargin));
Hyst3(IN := SpeedRefInt, HIGH := REAL_TO_INT(Table.StepThreshold_Pct[3] + HystMargin), LOW := REAL_TO_INT(Table.StepThreshold_Pct[3] - HystMargin));
Hyst4(IN := SpeedRefInt, HIGH := REAL_TO_INT(Table.StepThreshold_Pct[4] + HystMargin), LOW := REAL_TO_INT(Table.StepThreshold_Pct[4] - HystMargin));

StepNumber := 1;                          // Palier mini dès qu'Enable est actif
IF NOT Hyst1.OUT THEN StepNumber := 2; END_IF;
IF NOT Hyst2.OUT THEN StepNumber := 3; END_IF;
IF NOT Hyst3.OUT THEN StepNumber := 4; END_IF;
IF NOT Hyst4.OUT THEN StepNumber := 5; END_IF;

// 📤 3. MASQUE — lu dans la table (donnée, jamais codé en dur)
StepMask := Table.StepMask[StepNumber];
