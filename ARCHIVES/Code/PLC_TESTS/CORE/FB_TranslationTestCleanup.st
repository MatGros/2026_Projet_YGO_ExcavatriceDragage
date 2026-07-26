// ═══════════════════════════════════════════════════════════════
// 🧪 FB_TranslationTestCleanup — Neutralité Translation M3
// ───────────────────────────────────────────────────────────────
// 🎯 Responsabilité UNIQUE : porter le vecteur d'état NEUTRE complet
//    (tous les overrides M3 relâchés, instance isolée FB_Translation
//    au repos). Source de vérité UNIQUE de "neutre" — appelée depuis
//    le fichier suite (SUITE_TRANSLATION/FB_TranslationValidation.st)
//    à la fois dans le CASE stimulus (StimulusId=0) ET, en garantie
//    structurelle indépendante, sur tout chemin où la suite n'est pas
//    Busy (ceinture + bretelles, AF_Partie-14 §7.3.2).
// 🚫 Ne force JAMAIS une sortie de commande calculée — uniquement les
//    surcharges capteurs amont (GVL_PLC_Tests.OverrideM3*) et les
//    entrées de l'instance de test isolée.
// ═══════════════════════════════════════════════════════════════

FUNCTION_BLOCK PUBLIC FB_TranslationTestCleanup
VAR_INPUT
    Apply : BOOL; // TRUE = force la neutralité maintenant
END_VAR
VAR_OUTPUT
    OverrideAtTremie          : BOOL;
    OverrideBrakeStuckOpen    : BOOL;
    OverridePhantomFreq       : BOOL;
    OverrideSensorsWordActive : BOOL;
    UnderTestDirection        : INT;
    UnderTestStartStop        : BOOL;
    UnderTestSlowdownSensor   : BOOL;
    NeutralConfirmed          : BOOL; // TRUE dès que la neutralité a été appliquée ce scan
END_VAR
// === IMPLEMENTATION ===
IF Apply THEN
    OverrideAtTremie := FALSE;
    OverrideBrakeStuckOpen := FALSE;
    OverridePhantomFreq := FALSE;
    OverrideSensorsWordActive := FALSE;
    UnderTestDirection := 0;
    UnderTestStartStop := FALSE;
    UnderTestSlowdownSensor := FALSE;
    NeutralConfirmed := TRUE;
ELSE
    NeutralConfirmed := FALSE;
END_IF;
