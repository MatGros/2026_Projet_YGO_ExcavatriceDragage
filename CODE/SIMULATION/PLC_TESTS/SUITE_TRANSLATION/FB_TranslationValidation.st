// ═══════════════════════════════════════════════════════════════
// 🧪 FB_TranslationValidation — Suite de test Translation M3
// ───────────────────────────────────────────────────────────────
// 📄 Doc métier : DOC/AF_Partie-11_Fonction_Translation_v1.8.md
// 🎯 Valide les surveillances de sécurité de FB_Safety_Translation :
//    TC-T1 Fin de course extrême, TC-T2 Méca B (incohérence à l'arrêt),
//    TC-T3 Méca A (mouvement non commandé). Même moteur générique
//    FB_TestSequencer que FB_SafetyValidation (AF_Partie-14 §7).
// 🆕 REX 2026-07-18 (AF_Partie-02 v2.12 §3bis, 5 capteurs Trémie/PV/P2/P1/Maintenance) :
//    TC-T4 les 6 mots valides + limites extrêmes, TC-T5 incohérence mot capteurs
//    (SafeStop+PowerCutOff), TC-T6 ralentissement PV (instance FB_Translation isolée).
// ⚠️ Hors périmètre (non testé ici, nécessiterait des overrides
//    supplémentaires sur les diagnostics bus) : bit0 (perte Joystick
//    CANopen), bit1 (perte com EtherCAT variateur), bit2 (rotation
//    de phases), bit3 (thermique frein commun) — voir rapport de
//    livraison de cette suite pour le détail.
// ═══════════════════════════════════════════════════════════════

FUNCTION_BLOCK PUBLIC FB_TranslationValidation
VAR_INPUT
    Start                      : BOOL;        // Commande de démarrage des tests
    Abort                      : BOOL;        // Commande d'abandon
    FirstStepId                : INT;         // Première étape à exécuter
END_VAR
VAR_OUTPUT
    Busy                       : BOOL;
    Done                       : BOOL;
    AnyFailed                  : BOOL;
    SimGateOk                  : BOOL;        // Indique si la simulation est autorisée
    ActiveStimulusId           : INT;
    StepElapsed                : TIME;
    Report                     : ST_TestSuiteReport;
    TerminalState              : E_TestTerminalState;
    ConfigError                : BOOL;
    ConfigErrorStepId          : INT;
    ConfigErrorCheckIdx        : INT;
    ErrorCode                  : INT;
    ErrorMessage               : STRING(160);
END_VAR
VAR CONSTANT
    // 🏷️ Index des sondes
    SigHealthyIdle              : INT := 1;
    SigLimitSwitchError         : INT := 2;
    SigPowerCutOff              : INT := 3;
    SigErrorIdT1NoParasite      : INT := 4;
    SigMecaBError                : INT := 5;
    SigErrorIdT2NoParasite      : INT := 6;
    SigMecaAError                : INT := 7;
    SigErrorIdT3NoParasite      : INT := 8;
    // 🆕 REX 2026-07-18 : sondes TC-T4/T5/T6 (5 capteurs position, AF_Partie-02 v2.12 §3bis)
    SigDecoderIncoherent         : INT := 9;
    SigLimitFwd                  : INT := 10;
    SigLimitRev                  : INT := 11;
    SigSensorIncoherentErr       : INT := 12;
    SigErrorIdT5NoParasite       : INT := 13; // DINT
    SigSlowdownFreqHz            : INT := 14; // REAL

    // 🪜 Index des étapes
    StepTc01Setup                : INT := 10;
    StepTc01Trigger              : INT := 11;
    StepTc01Teardown             : INT := 19;

    StepTc02Setup                : INT := 20;
    StepTc02Trigger              : INT := 21;
    StepTc02Teardown             : INT := 29;

    StepTc03Setup                : INT := 30;
    StepTc03Trigger              : INT := 31;
    StepTc03Teardown             : INT := 39;

    // 🆕 TC-T4 : les 6 mots valides + limites extrêmes (AF_Partie-02 v2.12 §3bis)
    StepTc04Setup                : INT := 40;
    StepTc04Word1Tremie          : INT := 41; // 11111
    StepTc04Word2                : INT := 42; // 01111
    StepTc04Word3                : INT := 43; // 00111
    StepTc04Word4                : INT := 44; // 00011
    StepTc04Word5                : INT := 45; // 00001
    StepTc04Word6Maintenance     : INT := 46; // 00000
    StepTc04Teardown             : INT := 49;

    // 🆕 TC-T5 : combinaison incohérente
    StepTc05Setup                : INT := 50;
    StepTc05Trigger              : INT := 51;
    StepTc05Teardown             : INT := 59;

    // 🆕 TC-T6 : ralentissement PV (instance isolée FB_Translation)
    StepTc06Setup                : INT := 60;
    StepTc06FullSpeed            : INT := 61;
    StepTc06Slowdown             : INT := 62;
    StepTc06Teardown             : INT := 63;
END_VAR
VAR
    // ⚙️ Moteur unique
    Sequencer                  : FB_TestSequencer;

    // 📋 Tables de configuration
    StepTable                  : ARRAY[1..GVL_PLC_Tests_Const.MaxSteps]      OF ST_TestStepConfig;
    CheckTable                 : ARRAY[1..GVL_PLC_Tests_Const.MaxChecks]     OF ST_TestCheckConfig;
    CaseTable                  : ARRAY[1..GVL_PLC_Tests_Const.MaxTestCases]  OF ST_TestCaseConfig;
    InvariantTable             : ARRAY[1..GVL_PLC_Tests_Const.MaxInvariants] OF ST_TestInvariantConfig;

    // 📥 Banque de sondes
    ProbeBool                  : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeBool]  OF BOOL;
    ProbeDint                  : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeDint]  OF DINT;
    ProbeReal                  : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeReal]  OF REAL;

    // 🛠️ Configuration initialisée
    TableReady                 : BOOL := FALSE;

    // ⚡ Commande de stimulus affectée dans le CASE
    ResetFaults                : BOOL;

    // 🆕 REX 2026-07-18 : TC-T6 — instance ISOLÉE de FB_Translation (pas l'instance machine réelle
    // instTranslationM3) pour tester le ralentissement PV en pilotant Direction/StartStop/SpeedRefPct
    // directement, sans dépendre de l'arbitrage Mode de PRG_07_TranslationControl.
    instTranslationUnderTest   : FB_Translation;
    UnderTestDirection         : INT;
    UnderTestStartStop         : BOOL;
    UnderTestSlowdownSensor    : BOOL;
END_VAR
// === IMPLEMENTATION ===
// 1. 🛡️ GATE
IF NOT GVL_Simulation.SimulationModeActive THEN
    // Abort interne immédiat
    Sequencer(Start := FALSE, Abort := TRUE, FirstStepId := FirstStepId,
              StepTable := StepTable, CheckTable := CheckTable, CaseTable := CaseTable, InvariantTable := InvariantTable,
              ProbeBool := ProbeBool, ProbeDint := ProbeDint, ProbeReal := ProbeReal, Report := Report);

    GVL_PLC_Tests.OverrideM3AtTremie := FALSE;
    GVL_PLC_Tests.OverrideM3BrakeStuckOpen := FALSE;
    GVL_PLC_Tests.OverrideM3PhantomFreq := FALSE;
    ResetFaults := FALSE;
    SimGateOk := FALSE;
    RETURN;
END_IF;

// 🔒 Refuse si un des équipements M3 est déjà recâblé réel.
// IHM_MANU ne bloque plus la suite : FB_Safety_Translation est active
// indépendamment du mode, conformément à la migration IHM_MANU.
SimGateOk := NOT GVL_Simulation.TranslationPosition_IsReal
         AND NOT GVL_Simulation.ContactorFeedbackM3_IsReal
         AND NOT GVL_Simulation.VariateurM3_IsReal;

// 2. 📋 TABLES (Remplissage déclaratif unique)
IF NOT TableReady THEN
    Report.Name := 'Translation Validation';

    // Cas de tests
    CaseTable[1].Name := 'TC-T1 Fin de course extreme';
    CaseTable[1].FirstStep := StepTc01Setup;

    CaseTable[2].Name := 'TC-T2 Meca B incoherence arret';
    CaseTable[2].FirstStep := StepTc02Setup;

    CaseTable[3].Name := 'TC-T3 Meca A mvt non commande';
    CaseTable[3].FirstStep := StepTc03Setup;

    // 🆕 REX 2026-07-18 (AF_Partie-02 v2.12 §3bis)
    CaseTable[4].Name := 'TC-T4 Mots valides + limites';
    CaseTable[4].FirstStep := StepTc04Setup;

    CaseTable[5].Name := 'TC-T5 Incoherence mot capteurs';
    CaseTable[5].FirstStep := StepTc05Setup;

    CaseTable[6].Name := 'TC-T6 Ralentissement PV';
    CaseTable[6].FirstStep := StepTc06Setup;

    // ─────────────────────────────────────────────────────────────
    // CONFIGURATION DES CHECKS (CheckTable)
    // ─────────────────────────────────────────────────────────────
    // Chk 1: Attente état sain (aucun défaut Safety_Translation)
    CheckTable[1].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[1].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[1].ProbeIdx := SigHealthyIdle;
    CheckTable[1].ExpectedBool := TRUE;

    // Chk 2: TC-T1 — défaut Fdc extrême détecté
    CheckTable[2].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[2].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[2].ProbeIdx := SigLimitSwitchError;
    CheckTable[2].ExpectedBool := TRUE;

    // Chk 3: PowerCutOff déclenché (partagé T1/T2/T3)
    CheckTable[3].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[3].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[3].ProbeIdx := SigPowerCutOff;
    CheckTable[3].ExpectedBool := TRUE;

    // Chk 4: TC-T1 — aucun bit parasite (seul bit6 attendu)
    CheckTable[4].Kind := E_TestCheckKind.WORD_MASK_NONE;
    CheckTable[4].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[4].ProbeIdx := SigErrorIdT1NoParasite;
    CheckTable[4].Mask := NOT 16#0040;

    // Chk 5: TC-T2 — Méca B détecté (incohérence à l'arrêt, fenêtre 3s)
    CheckTable[5].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[5].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[5].ProbeIdx := SigMecaBError;
    CheckTable[5].ExpectedBool := TRUE;

    // Chk 6: TC-T2 — aucun bit parasite (seul bit4 attendu)
    CheckTable[6].Kind := E_TestCheckKind.WORD_MASK_NONE;
    CheckTable[6].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[6].ProbeIdx := SigErrorIdT2NoParasite;
    CheckTable[6].Mask := NOT 16#0010;

    // Chk 7: TC-T3 — Méca A détecté (mouvement non commandé, fenêtre 1s)
    CheckTable[7].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[7].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[7].ProbeIdx := SigMecaAError;
    CheckTable[7].ExpectedBool := TRUE;

    // Chk 8: TC-T3 — aucun bit parasite (seul bit5 attendu)
    CheckTable[8].Kind := E_TestCheckKind.WORD_MASK_NONE;
    CheckTable[8].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[8].ProbeIdx := SigErrorIdT3NoParasite;
    CheckTable[8].Mask := NOT 16#0020;

    // 🆕 REX 2026-07-18 — TC-T4/T5/T6 (AF_Partie-02 v2.12 §3bis)
    // Chk 9: TC-T4 — mot capteurs valide (utilisé sur les 6 mots)
    CheckTable[9].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[9].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[9].ProbeIdx := SigDecoderIncoherent;
    CheckTable[9].ExpectedBool := FALSE;

    // Chk 10: TC-T4 — limite extrême Trémie confirmée (mot 11111 uniquement)
    CheckTable[10].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[10].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[10].ProbeIdx := SigLimitFwd;
    CheckTable[10].ExpectedBool := TRUE;

    // Chk 11: TC-T4 — pas de limite Rev simultanée (mot 11111)
    // 🔧 REX 2026-07-18 : CHECK_WAIT_UNTIL (pas CHECK_INSTANT) — même bug de décalage d'1 scan
    // que TC-01 (FB_SafetyValidation.st Chk6) : le override du mot de test s'applique APRÈS
    // instTestsManagement() dans PRG_00_Inputs.st, donc invisible au scan d'entrée de l'étape.
    CheckTable[11].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[11].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[11].ProbeIdx := SigLimitRev;
    CheckTable[11].ExpectedBool := FALSE;

    // Chk 12: TC-T4 — limite extrême Maintenance confirmée (mot 00000 uniquement)
    CheckTable[12].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[12].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[12].ProbeIdx := SigLimitRev;
    CheckTable[12].ExpectedBool := TRUE;

    // Chk 13: TC-T4 — pas de limite Fwd simultanée (mot 00000)
    CheckTable[13].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[13].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[13].ProbeIdx := SigLimitFwd;
    CheckTable[13].ExpectedBool := FALSE;

    // Chk 14/15: TC-T4 — mot intermédiaire (00111) : ni l'une ni l'autre limite
    CheckTable[14].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[14].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[14].ProbeIdx := SigLimitFwd;
    CheckTable[14].ExpectedBool := FALSE;

    CheckTable[15].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[15].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[15].ProbeIdx := SigLimitRev;
    CheckTable[15].ExpectedBool := FALSE;

    // Chk 16: TC-T5 — mot incohérent détecté par le décodeur
    CheckTable[16].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[16].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[16].ProbeIdx := SigDecoderIncoherent;
    CheckTable[16].ExpectedBool := TRUE;

    // Chk 17: TC-T5 — défaut safety (bit7) remonté
    CheckTable[17].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[17].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[17].ProbeIdx := SigSensorIncoherentErr;
    CheckTable[17].ExpectedBool := TRUE;

    // Chk 18: TC-T5 — aucun bit parasite (seul bit7 attendu)
    CheckTable[18].Kind := E_TestCheckKind.WORD_MASK_NONE;
    CheckTable[18].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[18].ProbeIdx := SigErrorIdT5NoParasite;
    CheckTable[18].Mask := NOT 16#0080;

    // Chk 19: TC-T6 — pleine vitesse atteinte sans PV (proche de DriveFreqScaleMaxHz=60Hz)
    CheckTable[19].Kind := E_TestCheckKind.REAL_IN_RANGE;
    CheckTable[19].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[19].ProbeIdx := SigSlowdownFreqHz;
    CheckTable[19].RealMin := 30.0;
    CheckTable[19].RealMax := 60.0;

    // Chk 20: TC-T6 — vitesse limitée par PV (ApproachSpeedPct=20% de 60Hz = 12Hz)
    CheckTable[20].Kind := E_TestCheckKind.REAL_IN_RANGE;
    CheckTable[20].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[20].ProbeIdx := SigSlowdownFreqHz;
    CheckTable[20].RealMin := 8.0;
    CheckTable[20].RealMax := 14.0;

    // ─────────────────────────────────────────────────────────────
    // CONFIGURATION DES ÉTAPES (StepTable)
    // ─────────────────────────────────────────────────────────────
    // --- TC-T1 : Fin de course extrême (Trémie) ---
    StepTable[StepTc01Setup].Name := 'TCT1 Setup saine';
    StepTable[StepTc01Setup].CaseId := 1;
    StepTable[StepTc01Setup].StimulusId := 1; // Reset défauts, overrides relâchés
    StepTable[StepTc01Setup].CheckIdx[1] := 1;
    StepTable[StepTc01Setup].TimeoutPT := T#12s;
    StepTable[StepTc01Setup].NextOnPass := StepTc01Trigger;
    StepTable[StepTc01Setup].NextOnFail := StepTc01Teardown;
    StepTable[StepTc01Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc01Trigger].Name := 'TCT1 Fdc Tremie force';
    StepTable[StepTc01Trigger].CaseId := 1;
    StepTable[StepTc01Trigger].StimulusId := 2; // OverrideM3AtTremie := TRUE
    StepTable[StepTc01Trigger].CheckIdx[1] := 2;
    StepTable[StepTc01Trigger].CheckIdx[2] := 3;
    StepTable[StepTc01Trigger].CheckIdx[3] := 4;
    StepTable[StepTc01Trigger].TimeoutPT := T#5s;
    StepTable[StepTc01Trigger].NextOnPass := StepTc01Teardown;
    StepTable[StepTc01Trigger].NextOnFail := StepTc01Teardown;
    StepTable[StepTc01Trigger].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc01Teardown].Name := 'TCT1 Teardown';
    StepTable[StepTc01Teardown].CaseId := 1;
    StepTable[StepTc01Teardown].StimulusId := 1;
    StepTable[StepTc01Teardown].CheckIdx[1] := 1;
    StepTable[StepTc01Teardown].TimeoutPT := T#12s;
    StepTable[StepTc01Teardown].NextOnPass := StepTc02Setup;
    StepTable[StepTc01Teardown].NextOnFail := StepTc02Setup;
    StepTable[StepTc01Teardown].FailAction := E_TestFailAction.FAIL_CONTINUE;

    // --- TC-T2 : Méca B (incohérence à l'arrêt, fenêtre 3s) ---
    StepTable[StepTc02Setup].Name := 'TCT2 Setup saine';
    StepTable[StepTc02Setup].CaseId := 2;
    StepTable[StepTc02Setup].StimulusId := 1;
    StepTable[StepTc02Setup].CheckIdx[1] := 1;
    StepTable[StepTc02Setup].TimeoutPT := T#12s;
    StepTable[StepTc02Setup].NextOnPass := StepTc02Trigger;
    StepTable[StepTc02Setup].NextOnFail := StepTc02Teardown;
    StepTable[StepTc02Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc02Trigger].Name := 'TCT2 Frein bloque ouvert';
    StepTable[StepTc02Trigger].CaseId := 2;
    StepTable[StepTc02Trigger].StimulusId := 3; // OverrideM3BrakeStuckOpen := TRUE
    StepTable[StepTc02Trigger].CheckIdx[1] := 5;
    StepTable[StepTc02Trigger].CheckIdx[2] := 3;
    StepTable[StepTc02Trigger].CheckIdx[3] := 6;
    StepTable[StepTc02Trigger].TimeoutPT := T#6s; // Marge sur PostRampTimeout (3s)
    StepTable[StepTc02Trigger].NextOnPass := StepTc02Teardown;
    StepTable[StepTc02Trigger].NextOnFail := StepTc02Teardown;
    StepTable[StepTc02Trigger].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc02Teardown].Name := 'TCT2 Teardown';
    StepTable[StepTc02Teardown].CaseId := 2;
    StepTable[StepTc02Teardown].StimulusId := 1;
    StepTable[StepTc02Teardown].CheckIdx[1] := 1;
    StepTable[StepTc02Teardown].TimeoutPT := T#12s;
    StepTable[StepTc02Teardown].NextOnPass := StepTc03Setup;
    StepTable[StepTc02Teardown].NextOnFail := StepTc03Setup;
    StepTable[StepTc02Teardown].FailAction := E_TestFailAction.FAIL_CONTINUE;

    // --- TC-T3 : Méca A (mouvement non commandé, fenêtre 1s) ---
    StepTable[StepTc03Setup].Name := 'TCT3 Setup saine';
    StepTable[StepTc03Setup].CaseId := 3;
    StepTable[StepTc03Setup].StimulusId := 1;
    StepTable[StepTc03Setup].CheckIdx[1] := 1;
    StepTable[StepTc03Setup].TimeoutPT := T#12s;
    StepTable[StepTc03Setup].NextOnPass := StepTc03Trigger;
    StepTable[StepTc03Setup].NextOnFail := StepTc03Teardown;
    StepTable[StepTc03Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc03Trigger].Name := 'TCT3 Frequence fantome';
    StepTable[StepTc03Trigger].CaseId := 3;
    StepTable[StepTc03Trigger].StimulusId := 4; // OverrideM3PhantomFreq := TRUE
    StepTable[StepTc03Trigger].CheckIdx[1] := 7;
    StepTable[StepTc03Trigger].CheckIdx[2] := 3;
    StepTable[StepTc03Trigger].CheckIdx[3] := 8;
    StepTable[StepTc03Trigger].TimeoutPT := T#4s; // Marge sur seuil 1s
    StepTable[StepTc03Trigger].NextOnPass := StepTc03Teardown;
    StepTable[StepTc03Trigger].NextOnFail := StepTc03Teardown;
    StepTable[StepTc03Trigger].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc03Teardown].Name := 'TCT3 Teardown';
    StepTable[StepTc03Teardown].CaseId := 3;
    StepTable[StepTc03Teardown].StimulusId := 1;
    StepTable[StepTc03Teardown].CheckIdx[1] := 1;
    StepTable[StepTc03Teardown].TimeoutPT := T#12s;
    StepTable[StepTc03Teardown].NextOnPass := StepTc04Setup;
    StepTable[StepTc03Teardown].NextOnFail := StepTc04Setup;
    StepTable[StepTc03Teardown].FailAction := E_TestFailAction.FAIL_CONTINUE;

    // --- TC-T4 : Les 6 mots valides + limites extrêmes (AF_Partie-02 v2.12 §3bis) ---
    StepTable[StepTc04Setup].Name := 'TCT4 Setup saine';
    StepTable[StepTc04Setup].CaseId := 4;
    StepTable[StepTc04Setup].StimulusId := 1;
    StepTable[StepTc04Setup].CheckIdx[1] := 1;
    StepTable[StepTc04Setup].TimeoutPT := T#12s;
    StepTable[StepTc04Setup].NextOnPass := StepTc04Word1Tremie;
    StepTable[StepTc04Setup].NextOnFail := StepTc04Teardown;
    StepTable[StepTc04Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc04Word1Tremie].Name := 'TCT4 Mot 11111 Tremie';
    StepTable[StepTc04Word1Tremie].CaseId := 4;
    StepTable[StepTc04Word1Tremie].StimulusId := 5;
    StepTable[StepTc04Word1Tremie].CheckIdx[1] := 9;
    StepTable[StepTc04Word1Tremie].CheckIdx[2] := 10;
    StepTable[StepTc04Word1Tremie].CheckIdx[3] := 11;
    StepTable[StepTc04Word1Tremie].TimeoutPT := T#3s;
    StepTable[StepTc04Word1Tremie].NextOnPass := StepTc04Word2;
    StepTable[StepTc04Word1Tremie].NextOnFail := StepTc04Teardown;
    StepTable[StepTc04Word1Tremie].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc04Word2].Name := 'TCT4 Mot 01111';
    StepTable[StepTc04Word2].CaseId := 4;
    StepTable[StepTc04Word2].StimulusId := 6;
    StepTable[StepTc04Word2].CheckIdx[1] := 9;
    StepTable[StepTc04Word2].TimeoutPT := T#3s;
    StepTable[StepTc04Word2].NextOnPass := StepTc04Word3;
    StepTable[StepTc04Word2].NextOnFail := StepTc04Teardown;
    StepTable[StepTc04Word2].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc04Word3].Name := 'TCT4 Mot 00111';
    StepTable[StepTc04Word3].CaseId := 4;
    StepTable[StepTc04Word3].StimulusId := 7;
    StepTable[StepTc04Word3].CheckIdx[1] := 9;
    StepTable[StepTc04Word3].CheckIdx[2] := 14;
    StepTable[StepTc04Word3].CheckIdx[3] := 15;
    StepTable[StepTc04Word3].TimeoutPT := T#3s;
    StepTable[StepTc04Word3].NextOnPass := StepTc04Word4;
    StepTable[StepTc04Word3].NextOnFail := StepTc04Teardown;
    StepTable[StepTc04Word3].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc04Word4].Name := 'TCT4 Mot 00011';
    StepTable[StepTc04Word4].CaseId := 4;
    StepTable[StepTc04Word4].StimulusId := 8;
    StepTable[StepTc04Word4].CheckIdx[1] := 9;
    StepTable[StepTc04Word4].TimeoutPT := T#3s;
    StepTable[StepTc04Word4].NextOnPass := StepTc04Word5;
    StepTable[StepTc04Word4].NextOnFail := StepTc04Teardown;
    StepTable[StepTc04Word4].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc04Word5].Name := 'TCT4 Mot 00001';
    StepTable[StepTc04Word5].CaseId := 4;
    StepTable[StepTc04Word5].StimulusId := 9;
    StepTable[StepTc04Word5].CheckIdx[1] := 9;
    StepTable[StepTc04Word5].TimeoutPT := T#3s;
    StepTable[StepTc04Word5].NextOnPass := StepTc04Word6Maintenance;
    StepTable[StepTc04Word5].NextOnFail := StepTc04Teardown;
    StepTable[StepTc04Word5].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc04Word6Maintenance].Name := 'TCT4 Mot 00000 Maintenance';
    StepTable[StepTc04Word6Maintenance].CaseId := 4;
    StepTable[StepTc04Word6Maintenance].StimulusId := 10;
    StepTable[StepTc04Word6Maintenance].CheckIdx[1] := 9;
    StepTable[StepTc04Word6Maintenance].CheckIdx[2] := 12;
    StepTable[StepTc04Word6Maintenance].CheckIdx[3] := 13;
    StepTable[StepTc04Word6Maintenance].TimeoutPT := T#3s;
    StepTable[StepTc04Word6Maintenance].NextOnPass := StepTc04Teardown;
    StepTable[StepTc04Word6Maintenance].NextOnFail := StepTc04Teardown;
    StepTable[StepTc04Word6Maintenance].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc04Teardown].Name := 'TCT4 Teardown';
    StepTable[StepTc04Teardown].CaseId := 4;
    StepTable[StepTc04Teardown].StimulusId := 1;
    StepTable[StepTc04Teardown].CheckIdx[1] := 1;
    StepTable[StepTc04Teardown].TimeoutPT := T#12s;
    StepTable[StepTc04Teardown].NextOnPass := StepTc05Setup;
    StepTable[StepTc04Teardown].NextOnFail := StepTc05Setup;
    StepTable[StepTc04Teardown].FailAction := E_TestFailAction.FAIL_CONTINUE;

    // --- TC-T5 : Combinaison incohérente (capteur collé/HS) ---
    StepTable[StepTc05Setup].Name := 'TCT5 Setup saine';
    StepTable[StepTc05Setup].CaseId := 5;
    StepTable[StepTc05Setup].StimulusId := 1;
    StepTable[StepTc05Setup].CheckIdx[1] := 1;
    StepTable[StepTc05Setup].TimeoutPT := T#12s;
    StepTable[StepTc05Setup].NextOnPass := StepTc05Trigger;
    StepTable[StepTc05Setup].NextOnFail := StepTc05Teardown;
    StepTable[StepTc05Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc05Trigger].Name := 'TCT5 Mot incoherent force';
    StepTable[StepTc05Trigger].CaseId := 5;
    StepTable[StepTc05Trigger].StimulusId := 11; // Mot 10101 (progression non monotone)
    StepTable[StepTc05Trigger].CheckIdx[1] := 3;  // PowerCutOff (sonde partagée T1/T2/T3)
    StepTable[StepTc05Trigger].CheckIdx[2] := 16;
    StepTable[StepTc05Trigger].CheckIdx[3] := 17;
    StepTable[StepTc05Trigger].CheckIdx[4] := 18;
    StepTable[StepTc05Trigger].TimeoutPT := T#5s;
    StepTable[StepTc05Trigger].NextOnPass := StepTc05Teardown;
    StepTable[StepTc05Trigger].NextOnFail := StepTc05Teardown;
    StepTable[StepTc05Trigger].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc05Teardown].Name := 'TCT5 Teardown';
    StepTable[StepTc05Teardown].CaseId := 5;
    StepTable[StepTc05Teardown].StimulusId := 1;
    StepTable[StepTc05Teardown].CheckIdx[1] := 1;
    StepTable[StepTc05Teardown].TimeoutPT := T#12s;
    StepTable[StepTc05Teardown].NextOnPass := StepTc06Setup;
    StepTable[StepTc05Teardown].NextOnFail := StepTc06Setup;
    StepTable[StepTc05Teardown].FailAction := E_TestFailAction.FAIL_CONTINUE;

    // --- TC-T6 : Ralentissement PV (instance isolée FB_Translation) ---
    StepTable[StepTc06Setup].Name := 'TCT6 Setup saine';
    StepTable[StepTc06Setup].CaseId := 6;
    StepTable[StepTc06Setup].StimulusId := 1;
    StepTable[StepTc06Setup].CheckIdx[1] := 1;
    StepTable[StepTc06Setup].TimeoutPT := T#12s;
    StepTable[StepTc06Setup].NextOnPass := StepTc06FullSpeed;
    StepTable[StepTc06Setup].NextOnFail := StepTc06Teardown;
    StepTable[StepTc06Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc06FullSpeed].Name := 'TCT6 Pleine vitesse sans PV';
    StepTable[StepTc06FullSpeed].CaseId := 6;
    StepTable[StepTc06FullSpeed].StimulusId := 12;
    StepTable[StepTc06FullSpeed].CheckIdx[1] := 19;
    StepTable[StepTc06FullSpeed].TimeoutPT := T#8s;
    StepTable[StepTc06FullSpeed].NextOnPass := StepTc06Slowdown;
    StepTable[StepTc06FullSpeed].NextOnFail := StepTc06Teardown;
    StepTable[StepTc06FullSpeed].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc06Slowdown].Name := 'TCT6 Ralenti PV actif';
    StepTable[StepTc06Slowdown].CaseId := 6;
    StepTable[StepTc06Slowdown].StimulusId := 13;
    StepTable[StepTc06Slowdown].CheckIdx[1] := 20;
    StepTable[StepTc06Slowdown].TimeoutPT := T#8s;
    StepTable[StepTc06Slowdown].NextOnPass := StepTc06Teardown;
    StepTable[StepTc06Slowdown].NextOnFail := StepTc06Teardown;
    StepTable[StepTc06Slowdown].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc06Teardown].Name := 'TCT6 Teardown';
    StepTable[StepTc06Teardown].CaseId := 6;
    StepTable[StepTc06Teardown].StimulusId := 1;
    StepTable[StepTc06Teardown].CheckIdx[1] := 1;
    StepTable[StepTc06Teardown].TimeoutPT := T#12s;
    StepTable[StepTc06Teardown].NextOnPass := 0;
    StepTable[StepTc06Teardown].NextOnFail := 0;
    StepTable[StepTc06Teardown].FailAction := E_TestFailAction.FAIL_CONTINUE;

    TableReady := TRUE;
END_IF;

// 3. 📥 ACQUIRE
ProbeBool[SigHealthyIdle]      := NOT PRG_03_Safety.instSafetyTranslationM3.Error;
ProbeBool[SigLimitSwitchError] := PRG_03_Safety.instSafetyTranslationM3.ErrorLimitSwitch;
ProbeBool[SigPowerCutOff]      := PRG_03_Safety.instSafetyTranslationM3.PowerCutOff;
ProbeDint[SigErrorIdT1NoParasite] := WORD_TO_DINT(PRG_03_Safety.instSafetyTranslationM3.ErrorId);
ProbeBool[SigMecaBError]       := PRG_03_Safety.instSafetyTranslationM3.ErrorMecaB;
ProbeDint[SigErrorIdT2NoParasite] := WORD_TO_DINT(PRG_03_Safety.instSafetyTranslationM3.ErrorId);
ProbeBool[SigMecaAError]       := PRG_03_Safety.instSafetyTranslationM3.ErrorMecaA;
ProbeDint[SigErrorIdT3NoParasite] := WORD_TO_DINT(PRG_03_Safety.instSafetyTranslationM3.ErrorId);

// 🆕 REX 2026-07-18 : sondes TC-T4/T5 (décodeur réel, via PRG_07_TranslationControl)
ProbeBool[SigDecoderIncoherent]   := PRG_07_TranslationControl.instPositionDecoder.Incoherent;
ProbeBool[SigLimitFwd]            := PRG_07_TranslationControl.instPositionDecoder.LimitSwitchFwd;
ProbeBool[SigLimitRev]            := PRG_07_TranslationControl.instPositionDecoder.LimitSwitchRev;
ProbeBool[SigSensorIncoherentErr] := PRG_03_Safety.instSafetyTranslationM3.ErrorSensorIncoherent;
ProbeDint[SigErrorIdT5NoParasite] := WORD_TO_DINT(PRG_03_Safety.instSafetyTranslationM3.ErrorId);

// 🆕 REX 2026-07-18 : TC-T6 — instance isolée pilotée directement par les stimuli (voir §5 CASE),
// jamais l'instance machine réelle instTranslationM3 (évite de perturber le pilotage arbitré).
instTranslationUnderTest(
    Enable := TRUE, Reset := ResetFaults, EmergencyStopOk := TRUE, Mode := E_Mode.MAINT_N1,
    StartStop := UnderTestStartStop, SafeStop := FALSE,
    Direction := UnderTestDirection, SpeedRefPct := 100.0,
    PositionSensorTarget := FALSE, SlowdownSensor := UnderTestSlowdownSensor,
    LimitSwitchFwd := FALSE, LimitSwitchRev := FALSE,
    DriveStatusWord := 0, DriveActualFreqHz := 0.0,
    BypassContactorCheck := TRUE, BrakeFeedback := FALSE
);
ProbeReal[SigSlowdownFreqHz] := instTranslationUnderTest.DriveFreqRefHz;

// 4. ⚙️ MOTEUR
Sequencer(
    Start := Start,
    Abort := Abort,
    FirstStepId := FirstStepId,
    StepTable := StepTable,
    CheckTable := CheckTable,
    CaseTable := CaseTable,
    InvariantTable := InvariantTable,
    ProbeBool := ProbeBool,
    ProbeDint := ProbeDint,
    ProbeReal := ProbeReal,
    Report := Report,
    Busy => Busy,
    Done => Done,
    AnyFailed => AnyFailed,
    TerminalState => TerminalState,
    ConfigError => ConfigError,
    ConfigErrorStepId => ConfigErrorStepId,
    ConfigErrorCheckIdx => ConfigErrorCheckIdx,
    ErrorCode => ErrorCode,
    ErrorMessage => ErrorMessage,
    ActiveStimulusId => ActiveStimulusId,
    StepElapsed => StepElapsed
);

// 5. ⚡ STIMULI
CASE ActiveStimulusId OF
    0: // 🔓 Neutre (tout relâché) — garanti sur Done/Abort par le moteur
        GVL_PLC_Tests.OverrideM3AtTremie := FALSE;
        GVL_PLC_Tests.OverrideM3BrakeStuckOpen := FALSE;
        GVL_PLC_Tests.OverrideM3PhantomFreq := FALSE;
        GVL_PLC_Tests.OverrideM3SensorsWordActive := FALSE;
        UnderTestStartStop := FALSE;
        UnderTestDirection := 0;
        UnderTestSlowdownSensor := FALSE;
        ResetFaults := FALSE;

    1: // Reset défauts, attente saine (Setup & Teardown)
        GVL_PLC_Tests.OverrideM3AtTremie := FALSE;
        GVL_PLC_Tests.OverrideM3BrakeStuckOpen := FALSE;
        GVL_PLC_Tests.OverrideM3PhantomFreq := FALSE;
        GVL_PLC_Tests.OverrideM3SensorsWordActive := FALSE;
        UnderTestStartStop := FALSE;
        UnderTestDirection := 0;
        UnderTestSlowdownSensor := FALSE;
        ResetFaults := TRUE;

    2: // TC-T1 : Force le capteur Fdc extrême Trémie
        GVL_PLC_Tests.OverrideM3AtTremie := TRUE;
        GVL_PLC_Tests.OverrideM3BrakeStuckOpen := FALSE;
        GVL_PLC_Tests.OverrideM3PhantomFreq := FALSE;
        ResetFaults := FALSE;

    3: // TC-T2 : Force le retour frein resté ouvert (Méca B)
        GVL_PLC_Tests.OverrideM3AtTremie := FALSE;
        GVL_PLC_Tests.OverrideM3BrakeStuckOpen := TRUE;
        GVL_PLC_Tests.OverrideM3PhantomFreq := FALSE;
        ResetFaults := FALSE;

    4: // TC-T3 : Force une fréquence mesurée fantôme (Méca A)
        GVL_PLC_Tests.OverrideM3AtTremie := FALSE;
        GVL_PLC_Tests.OverrideM3BrakeStuckOpen := FALSE;
        GVL_PLC_Tests.OverrideM3PhantomFreq := TRUE;
        ResetFaults := FALSE;

    // 🆕 REX 2026-07-18 — TC-T4 : les 6 mots valides (AF_Partie-02 v2.12 §3bis)
    5: // Mot 11111 (extrême Trémie)
        GVL_PLC_Tests.OverrideM3SensorsWordActive := TRUE;
        GVL_PLC_Tests.OverrideM3SensorsWord := 2#11111;
    6: // Mot 01111
        GVL_PLC_Tests.OverrideM3SensorsWordActive := TRUE;
        GVL_PLC_Tests.OverrideM3SensorsWord := 2#01111;
    7: // Mot 00111
        GVL_PLC_Tests.OverrideM3SensorsWordActive := TRUE;
        GVL_PLC_Tests.OverrideM3SensorsWord := 2#00111;
    8: // Mot 00011
        GVL_PLC_Tests.OverrideM3SensorsWordActive := TRUE;
        GVL_PLC_Tests.OverrideM3SensorsWord := 2#00011;
    9: // Mot 00001
        GVL_PLC_Tests.OverrideM3SensorsWordActive := TRUE;
        GVL_PLC_Tests.OverrideM3SensorsWord := 2#00001;
    10: // Mot 00000 (extrême Maintenance)
        GVL_PLC_Tests.OverrideM3SensorsWordActive := TRUE;
        GVL_PLC_Tests.OverrideM3SensorsWord := 2#00000;

    // 🆕 TC-T5 : mot incohérent (progression non monotone — capteur collé/HS simulé)
    11:
        GVL_PLC_Tests.OverrideM3SensorsWordActive := TRUE;
        GVL_PLC_Tests.OverrideM3SensorsWord := 2#10101;

    // 🆕 TC-T6 : ralentissement PV (instance isolée, voir §3 ACQUIRE)
    12: // Pleine vitesse, sans PV
        UnderTestDirection := 1;
        UnderTestStartStop := TRUE;
        UnderTestSlowdownSensor := FALSE;
    13: // Même mouvement, PV actif -> vitesse limitée
        UnderTestDirection := 1;
        UnderTestStartStop := TRUE;
        UnderTestSlowdownSensor := TRUE;
END_CASE;

// Recopie IHM/métier — reset partagé avec la suite Safety (même domaine
// "sécurité/métier", voir PRG_09_Supervision.FaultMachineReset_IHM), sans
// conflit car les suites s'exécutent toujours de façon mutuellement exclusive
// (FB_PLC_Tests_Management n'active qu'une suite à la fois).
IF Busy THEN
    GVL_IHM.Modes.FaultMachineReset := ResetFaults;
END_IF;
