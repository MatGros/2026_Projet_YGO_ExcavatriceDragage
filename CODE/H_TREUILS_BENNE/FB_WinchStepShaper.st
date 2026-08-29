(* =======================================================================
   ⚙️ FB_WinchStepShaper — Cadencement de palier (montee cadencee)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Cadence la montee de palier (+1 cran / StepRampDelay),
             descente immediate a 0 (aucune rampe descendante)
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 Interface : Brique technique (contrat light, pas de defaut)
   🔒 Sécurité : D10 — StepRampDelay dedie, decouple des delais direction
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_WinchStepShaper
VAR_INPUT
    Enable        : BOOL;   // --> [CMD] Autorisation FB (TRUE = actif)
    TargetStep    : INT;    // --> [CMD] Palier cible demande
    StepRampDelay : TIME;   // --> [CFG] Delai de cadence montee de palier
END_VAR
VAR_OUTPUT
    ShapedStep       : INT;   // <-- [DIAG] Palier metier temporise actif
    StepDelayElapsed : TIME;  // <-- [DIAG] Ecoule tempo metier palier
END_VAR
VAR
    StepDelay : TON;          // . [LOC] Temporisation hausse de palier
END_VAR

// === IMPLEMENTATION ===

IF NOT Enable THEN
    ShapedStep := 0;
    StepDelay(IN := FALSE);
    StepDelayElapsed := T#0s;
    RETURN;
END_IF;

// Temporisation : compte quand la cible est au-dessus du palier courant
StepDelay(
    IN := (TargetStep > ShapedStep) AND (ShapedStep > 0),
    PT := StepRampDelay
);
StepDelayElapsed := StepDelay.ET;

// Cadencement asymetrique : montee +1 cran / StepRampDelay, descente immediate
IF TargetStep = 0 THEN
    ShapedStep := 0;
ELSIF TargetStep < ShapedStep THEN
    ShapedStep := TargetStep;
ELSIF TargetStep > ShapedStep THEN
    IF ShapedStep = 0 THEN
        ShapedStep := 1;
    ELSIF StepDelay.Q THEN
        ShapedStep := ShapedStep + 1;
    END_IF;
END_IF;

END_FUNCTION_BLOCK
