(* ═══════════════════════════════════════════════════════════════
   📏 FB_Encoder_Scale — Mise à l'échelle points → mètres (1 par treuil)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-09_Fonction_Encoder_v2.1.md §2/§3.1
                   DOC/AF_Partie-03_Contrats_Composants_v2.1.md
   🎯 Formule : CablePosM = (RawPos - HomingRefRaw) × (CableM_PerRev / PointsPerRev)
   🧮 Arithmétique signée sûre : conversion en DINT avant la soustraction.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Encoder_Scale) ===

FUNCTION_BLOCK PUBLIC FB_Encoder_Scale
VAR_INPUT
    RawPos          : UDINT;       // Position brute (sortie FB_Encoder_Abs, déjà gelée sur doute)
    HomingRefRaw    : UDINT;       // Référence brute figée au dernier homing (ST_Encoder_Calib)
    CableM_PerRev   : REAL := 2.0; // Câble déroulé par tour (périmètre tambour confirmé 2026-07-02, réglable site)
    PointsPerRev    : UDINT := 8192; // Résolution codeur confirmée (Partie10 §3.3)
END_VAR
VAR_OUTPUT
    CablePosM       : REAL;        // Position câble en mètres, signée (+ enroulé, − sous l'eau)
END_VAR
VAR
    RawDiff         : DINT;        // Écart signé RawPos - HomingRefRaw (§3.1)
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Encoder_Scale) ===

// 🧮 Écart signé sûr : conversion DINT AVANT soustraction (§3.1) — jamais l'inverse
RawDiff := UDINT_TO_DINT(RawPos) - UDINT_TO_DINT(HomingRefRaw);

// 📏 Formule fixe points → mètres (Partie10 §2)
IF PointsPerRev > 0 THEN
    CablePosM := DINT_TO_REAL(RawDiff) * (CableM_PerRev / UDINT_TO_REAL(PointsPerRev));
ELSE
    CablePosM := 0.0;   // Garde division par zéro (PointsPerRev mal configuré)
END_IF;
