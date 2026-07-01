(* ═══════════════════════════════════════════════════════════════
   🪜 FB_SpeedStep — Décodeur palier → 4 contacteurs (1 par treuil)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie9_Fonction_Winch_v1.0.md
   📥 SpeedRefPct    : consigne 0..100 % (déjà rampée en amont, ABS)
   📥 Table          : ST_SpeedStepTable propre AU TREUIL appelant
                       (M1 et M2 ont chacune la leur — pas de table globale)
   📤 Contactor1..4  : état de chaque contacteur de vitesse (BOOL individuel,
                       lu directement dans `Table.P<palier>R<relais>`)
   📤 StepNumber     : n° palier courant (0 = arrêt, 1..5)
   🧩 Réutilisation lib Util (Partie3 §0) : HYSTERESIS pour la sélection
      de palier anti-battement — AUCUN seuil "maison" recalculé.
   ⚠️ CORRECTIF interface HYSTERESIS (2026-07-01) : `Util` 3.5.19.0 expose
      `HYSTERESIS(IN, HIGH, LOW : INT → OUT : BOOL)` (TRUE si IN < LOW,
      FALSE si IN > HIGH, maintien entre les deux) — `SpeedRefPct` (REAL)
      est converti en INT (`REAL_TO_INT`) avant appel.
   ⚠️ ÉVOLUTION (retour terrain 2026-07-01) : `StepMask` (BYTE packé) est
      remplacé par 4 sorties BOOL individuelles, lues directement dans la
      table (`P<palier>R<relais>`) — plus de bit-extraction côté FB_Winch,
      paramétrage un contacteur à la fois pendant la mise en service.
   ⚠️ Brique réduite (Partie3 §1bis) : pas d'Enable/Reset/Error au sens
      "FB métier" — c'est un décodeur pur, composé À L'INTÉRIEUR de
      FB_Winch, qui porte lui la sécurité/le contrat complet.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_SpeedStep) ===

FUNCTION_BLOCK PUBLIC FB_SpeedStep
VAR_INPUT
    Enable      : BOOL;               // Piloté par FB_Winch : FALSE = treuil à l'arrêt (palier 0)
    SpeedRefPct : REAL;                // Consigne vitesse 0..100 % (déjà rampée par FB_Winch)
    Table       : ST_SpeedStepTable;   // Table des 5 paliers (contacteurs + seuils), propre à CE treuil
    HystMargin  : REAL := 2.0;         // Marge anti-battement (%) autour de chaque seuil
END_VAR
VAR_OUTPUT
    Contactor1  : BOOL;   // Contacteur de vitesse 1 pour le palier courant
    Contactor2  : BOOL;   // Contacteur de vitesse 2 pour le palier courant
    Contactor3  : BOOL;   // Contacteur de vitesse 3 pour le palier courant
    Contactor4  : BOOL;   // Contacteur de vitesse 4 pour le palier courant
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

// 🛑 1. GATE — pas de mouvement demandé = palier 0, tous contacteurs à FALSE
IF NOT Enable THEN
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
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

// 📤 3. CONTACTEURS — lus dans la table (donnée, jamais codé en dur)
CASE StepNumber OF
    1: Contactor1 := Table.P1R1; Contactor2 := Table.P1R2; Contactor3 := Table.P1R3; Contactor4 := Table.P1R4;
    2: Contactor1 := Table.P2R1; Contactor2 := Table.P2R2; Contactor3 := Table.P2R3; Contactor4 := Table.P2R4;
    3: Contactor1 := Table.P3R1; Contactor2 := Table.P3R2; Contactor3 := Table.P3R3; Contactor4 := Table.P3R4;
    4: Contactor1 := Table.P4R1; Contactor2 := Table.P4R2; Contactor3 := Table.P4R3; Contactor4 := Table.P4R4;
    5: Contactor1 := Table.P5R1; Contactor2 := Table.P5R2; Contactor3 := Table.P5R3; Contactor4 := Table.P5R4;
END_CASE;
