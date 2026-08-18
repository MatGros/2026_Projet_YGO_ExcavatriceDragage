(* =======================================================================
   ⚙️ FB_Encoder_Scale — Mise à l'échelle points → mètres (1 par treuil)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Calcul de la position câble en mètres par conversion arithmétique signée
   🔒 Polarité : CablePosM signée (+ enroulé, - sous l'eau)
   🔌 Architecture : Convertisseur de mesure unitaire par treuil
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.1.md
   ======================================================================= *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Encoder_Scale) ===

FUNCTION_BLOCK PUBLIC FB_Encoder_Scale
VAR_INPUT
    // === DONNEES ENTREE & REFERENCES BRUTES ===
    RawPos          : UDINT;       // --> [HW]  Position brute codeur (sortie FB_Encoder_Abs, gelee sur doute)
    HomingRefRaw    : UDINT;       // --> [CFG] Reference brute figee au dernier homing (ST_Encoder_Calib)

    // === PARAMETRES & RATIOS DE CONVERSION ===
    CableM_PerRev   : REAL := 2.0; // --> [CFG] Developpement cable par tour tambour (m/tour)
    PointsPerRev    : UDINT := 8192;// --> [CFG] Resolution codeur (pts/tour)
END_VAR
VAR_OUTPUT
    // === MESURE CONVERTIE ===
    CablePosM       : REAL;        // <-- [DIAG] Position cable en metres (+ enroule, - sous l'eau)
END_VAR
VAR
    // === CALCULS INTERNES ===
    RawDiff         : DINT;        // . [LOC] Ecart signe RawPos - HomingRefRaw
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
