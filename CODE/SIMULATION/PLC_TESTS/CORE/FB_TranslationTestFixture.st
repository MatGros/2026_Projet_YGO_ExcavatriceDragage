// ═══════════════════════════════════════════════════════════════
// 🧪 FB_TranslationTestFixture — Précondition Translation M3
// ───────────────────────────────────────────────────────────────
// 🎯 Responsabilité UNIQUE : décider si un Start est recevable
//    (Niveaux 1/2 de la défense en profondeur, AF_Partie-14 §7.3.3) :
//    simulation active + aucune E/S M3 recâblée réelle. Ne fait AUCUNE
//    attente d'état sain (ça reste la responsabilité de l'étape SETUP
//    de chaque cas, via FB_TranslationStepExecutor — §7.3.5).
// 🔒 Un refus ici est TOUJOURS explicite (PRECONDITION_FAILED),
//    jamais un silence (audit v1.0 C3).
// ═══════════════════════════════════════════════════════════════

FUNCTION_BLOCK PUBLIC FB_TranslationTestFixture
VAR_INPUT
    CheckRequested        : BOOL; // Front : nouvelle vérification demandée (sur Start suite)
    SimulationModeActive  : BOOL;
    SimGateOk             : BOOL; // Niveau 2 : aucune E/S M3 (_IsReal) incompatible
END_VAR
VAR_OUTPUT
    FixturePassed  : BOOL;
    FixtureFailed  : BOOL;
    FailReason     : STRING(120);
END_VAR
VAR
    CheckTrig : R_TRIG;
END_VAR
// === IMPLEMENTATION ===
CheckTrig(CLK := CheckRequested);

IF CheckTrig.Q THEN
    IF NOT SimulationModeActive THEN
        FixturePassed := FALSE;
        FixtureFailed := TRUE;
        FailReason := 'Simulation non active (GVL_Simulation.SimulationModeActive=FALSE)';
    ELSIF NOT SimGateOk THEN
        FixturePassed := FALSE;
        FixtureFailed := TRUE;
        FailReason := 'E/S M3 recablees reelles (_IsReal) incompatibles avec le banc de test';
    ELSE
        FixturePassed := TRUE;
        FixtureFailed := FALSE;
        FailReason := '';
    END_IF;
END_IF;
