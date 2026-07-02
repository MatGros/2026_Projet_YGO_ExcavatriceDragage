(* ═══════════════════════════════════════════════════════════════
   📏 FB_Encoder_Scale — Mise à l'échelle points → mètres (1 par treuil)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie10_Fonction_Encoder_Homing_v1.2.md §2/§3.1
   ⚠️ RÉÉCRITURE (remplace la version legacy) : formule FIXE
      `CablePosM = (RawPos − HomingRefRaw) × (CableM_PerRev/PointsPerRev)`
      — retire le mode `Teach` auto-calibré (`EnableTeach`/`StartTeachPos`/
      `EndTeachPos`/`RealDistMeters`) : `CableM_PerRev` est un paramètre
      RETAIN fixe (site), pas recalculé dynamiquement (Partie10 §2).
   🧮 Arithmétique signée sûre (§3.1) : conversion en DINT AVANT la
      soustraction (jamais soustraire deux UDINT directement — un
      résultat négatif reboucle silencieusement vers ~2³²).
   🧩 Brique de calcul pure — pas de gel/bornage ici : `RawPos` en
      entrée est déjà gelé par `FB_Encoder_Abs` (§6) ; le bornage
      physique absolu [-99;+99] m est la responsabilité de
      `FB_Encoder_Safety` (§3.6, pas dans ce lot), pas de celle-ci.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Encoder_Scale) ===

FUNCTION_BLOCK PUBLIC FB_Encoder_Scale
VAR_INPUT
    RawPos          : UDINT;       // Position brute (sortie FB_Encoder_Abs, déjà gelée sur doute)
    HomingRefRaw    : UDINT;       // Référence brute figée au dernier homing (ST_EncoderCalib)
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
