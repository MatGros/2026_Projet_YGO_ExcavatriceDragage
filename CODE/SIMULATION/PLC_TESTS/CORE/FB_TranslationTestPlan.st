// ═══════════════════════════════════════════════════════════════
// 🧪 FB_TranslationTestPlan — Plan de validation Translation M3
// ───────────────────────────────────────────────────────────────
// 🎯 Responsabilité UNIQUE : construire (une seule fois) et auto-valider
//    les tables déclaratives (StepTable/CheckTable/CaseTable) de la
//    suite Translation, puis exposer un refus explicite ConfigError si
//    la table est incohérente. Ne pilote AUCUNE exécution (voir
//    FB_TranslationStepExecutor) et n'écrit AUCUNE variable GVL.
// 🆕 Tranche verticale NEUVE Translation (2026-07-22) — moteur dédié,
//    n'instancie NI FB_TestSequencer NI les anciennes BRICKS
//    (FB_TestCheck/FB_Timeout...). Voir DOC/AUDITS/TEST_FRAMEWORK_AUDIT_v1.0.md.
// 📌 Périmètre volontairement restreint (audit §"strictement nécessaires") :
//    seuls les Kind/Mode réellement utilisés par les 6 TC Translation
//    sont acceptés — BOOL_EQUAL/WORD_MASK_NONE/REAL_IN_RANGE,
//    CHECK_INSTANT/CHECK_WAIT_UNTIL. Tout autre Kind/Mode -> ConfigError.
// 🔑 Index des sondes (Sig*) : PLUS possédés ici. Le fichier suite
//    (SUITE_TRANSLATION/FB_TranslationValidation.st) les déclare comme
//    SES PROPRES VAR CONSTANT et les transmet en VAR_INPUT à chaque appel
//    -- aucun accès croisé "instPlan.SigXxx" depuis l'extérieur. Le Plan
//    ne fait que les recopier dans CheckTable[].ProbeIdx à la construction.
// ═══════════════════════════════════════════════════════════════

FUNCTION_BLOCK PUBLIC FB_TranslationTestPlan
VAR_INPUT
    // 🏷️ Index des sondes — fournis par l'appelant (source de vérité :
    //    VAR CONSTANT de FB_TranslationValidation), jamais lus en retour.
    SigHealthyIdle          : INT;
    SigLimitSwitchError     : INT;
    SigPowerCutOff          : INT;
    SigErrorIdT1NoParasite  : INT;
    SigMecaBError            : INT;
    SigErrorIdT2NoParasite  : INT;
    SigMecaAError            : INT;
    SigErrorIdT3NoParasite  : INT;
    SigDecoderIncoherent     : INT;
    SigLimitFwd              : INT;
    SigLimitRev              : INT;
    SigSensorIncoherentErr  : INT;
    SigErrorIdT5NoParasite  : INT; // DINT
    SigSlowdownFreqHz        : INT; // REAL
END_VAR
VAR_OUTPUT
    Ready               : BOOL;   // Tables construites + validées
    ConfigError          : BOOL;  // 🔒 Table invalide -> aucun Start ne doit être honoré
    ConfigErrorStepId    : INT;
    ConfigErrorCheckIdx  : INT;
    ConfigErrorMessage   : STRING(160);
END_VAR
VAR_IN_OUT
    StepTable  : ARRAY[1..GVL_PLC_Tests_Const.MaxSteps]      OF ST_TestStepConfig;
    CheckTable : ARRAY[1..GVL_PLC_Tests_Const.MaxChecks]     OF ST_TestCheckConfig;
    CaseTable  : ARRAY[1..GVL_PLC_Tests_Const.MaxTestCases]  OF ST_TestCaseConfig;
END_VAR
VAR
    // 🪜 Index des étapes (usage interne uniquement — assemblage des tables)
    StepTc01Setup     : INT := 10;
    StepTc01Trigger   : INT := 11;
    StepTc01Teardown  : INT := 19;

    StepTc02Setup     : INT := 20;
    StepTc02Trigger   : INT := 21;
    StepTc02Teardown  : INT := 29;

    StepTc03Setup     : INT := 30;
    StepTc03Trigger   : INT := 31;
    StepTc03Teardown  : INT := 39;

    StepTc04Setup            : INT := 40;
    StepTc04Word1Tremie      : INT := 41;
    StepTc04Word2            : INT := 42;
    StepTc04Word3            : INT := 43;
    StepTc04Word4            : INT := 44;
    StepTc04Word5             : INT := 45;
    StepTc04Word6Maintenance : INT := 46;
    StepTc04Teardown          : INT := 49;

    StepTc05Setup     : INT := 50;
    StepTc05Trigger   : INT := 51;
    StepTc05Teardown  : INT := 59;

    StepTc06Setup      : INT := 60;
    StepTc06FullSpeed  : INT := 61;
    StepTc06Slowdown   : INT := 62;
    StepTc06Teardown   : INT := 63;

    Built  : BOOL;
    Idx    : INT;
    Jdx    : INT;
    Kdx       : INT;
    WalkIdx   : INT;
    WalkStep  : INT;
    HasCheck  : BOOL;
END_VAR
// === IMPLEMENTATION ===

// 1. 📋 CONSTRUCTION (une seule fois, données pures)
IF NOT Built THEN

    // --- Cas de tests ---
    CaseTable[1].Name := 'TC-T1 Fin de course extreme';
    CaseTable[1].FirstStep := StepTc01Setup;
    CaseTable[2].Name := 'TC-T2 Meca B incoherence arret';
    CaseTable[2].FirstStep := StepTc02Setup;
    CaseTable[3].Name := 'TC-T3 Meca A mvt non commande';
    CaseTable[3].FirstStep := StepTc03Setup;
    CaseTable[4].Name := 'TC-T4 Mots valides + limites';
    CaseTable[4].FirstStep := StepTc04Setup;
    CaseTable[5].Name := 'TC-T5 Incoherence mot capteurs';
    CaseTable[5].FirstStep := StepTc05Setup;
    CaseTable[6].Name := 'TC-T6 Ralentissement PV';
    CaseTable[6].FirstStep := StepTc06Setup;

    // --- Checks ---
    CheckTable[1].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[1].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[1].ProbeIdx := SigHealthyIdle;
    CheckTable[1].ExpectedBool := TRUE;

    CheckTable[2].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[2].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[2].ProbeIdx := SigLimitSwitchError;
    CheckTable[2].ExpectedBool := TRUE;

    CheckTable[3].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[3].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[3].ProbeIdx := SigPowerCutOff;
    CheckTable[3].ExpectedBool := TRUE;

    CheckTable[4].Kind := E_TestCheckKind.WORD_MASK_NONE;
    CheckTable[4].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[4].ProbeIdx := SigErrorIdT1NoParasite;
    CheckTable[4].Mask := NOT 16#0040;

    CheckTable[5].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[5].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[5].ProbeIdx := SigMecaBError;
    CheckTable[5].ExpectedBool := TRUE;

    CheckTable[6].Kind := E_TestCheckKind.WORD_MASK_NONE;
    CheckTable[6].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[6].ProbeIdx := SigErrorIdT2NoParasite;
    CheckTable[6].Mask := NOT 16#0010;

    CheckTable[7].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[7].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[7].ProbeIdx := SigMecaAError;
    CheckTable[7].ExpectedBool := TRUE;

    CheckTable[8].Kind := E_TestCheckKind.WORD_MASK_NONE;
    CheckTable[8].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[8].ProbeIdx := SigErrorIdT3NoParasite;
    CheckTable[8].Mask := NOT 16#0020;

    CheckTable[9].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[9].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[9].ProbeIdx := SigDecoderIncoherent;
    CheckTable[9].ExpectedBool := FALSE;

    CheckTable[10].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[10].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[10].ProbeIdx := SigLimitFwd;
    CheckTable[10].ExpectedBool := TRUE;

    CheckTable[11].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[11].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[11].ProbeIdx := SigLimitRev;
    CheckTable[11].ExpectedBool := FALSE;

    CheckTable[12].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[12].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[12].ProbeIdx := SigLimitRev;
    CheckTable[12].ExpectedBool := TRUE;

    CheckTable[13].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[13].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[13].ProbeIdx := SigLimitFwd;
    CheckTable[13].ExpectedBool := FALSE;

    CheckTable[14].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[14].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[14].ProbeIdx := SigLimitFwd;
    CheckTable[14].ExpectedBool := FALSE;

    CheckTable[15].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[15].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[15].ProbeIdx := SigLimitRev;
    CheckTable[15].ExpectedBool := FALSE;

    CheckTable[16].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[16].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[16].ProbeIdx := SigDecoderIncoherent;
    CheckTable[16].ExpectedBool := TRUE;

    CheckTable[17].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[17].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[17].ProbeIdx := SigSensorIncoherentErr;
    CheckTable[17].ExpectedBool := TRUE;

    CheckTable[18].Kind := E_TestCheckKind.WORD_MASK_NONE;
    CheckTable[18].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[18].ProbeIdx := SigErrorIdT5NoParasite;
    CheckTable[18].Mask := NOT 16#0080;

    CheckTable[19].Kind := E_TestCheckKind.REAL_IN_RANGE;
    CheckTable[19].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[19].ProbeIdx := SigSlowdownFreqHz;
    CheckTable[19].RealMin := 30.0;
    CheckTable[19].RealMax := 60.0;

    CheckTable[20].Kind := E_TestCheckKind.REAL_IN_RANGE;
    CheckTable[20].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[20].ProbeIdx := SigSlowdownFreqHz;
    CheckTable[20].RealMin := 8.0;
    CheckTable[20].RealMax := 14.0;

    // --- TC-T1 ---
    StepTable[StepTc01Setup].Name := 'TCT1 Setup saine';
    StepTable[StepTc01Setup].CaseId := 1;
    StepTable[StepTc01Setup].StimulusId := 1;
    StepTable[StepTc01Setup].CheckIdx[1] := 1;
    StepTable[StepTc01Setup].TimeoutPT := T#12s;
    StepTable[StepTc01Setup].NextOnPass := StepTc01Trigger;
    StepTable[StepTc01Setup].NextOnFail := StepTc01Teardown;
    StepTable[StepTc01Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc01Trigger].Name := 'TCT1 Fdc Tremie force';
    StepTable[StepTc01Trigger].CaseId := 1;
    StepTable[StepTc01Trigger].StimulusId := 2;
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

    // --- TC-T2 ---
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
    StepTable[StepTc02Trigger].StimulusId := 3;
    StepTable[StepTc02Trigger].CheckIdx[1] := 5;
    StepTable[StepTc02Trigger].CheckIdx[2] := 3;
    StepTable[StepTc02Trigger].CheckIdx[3] := 6;
    StepTable[StepTc02Trigger].TimeoutPT := T#6s;
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

    // --- TC-T3 ---
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
    StepTable[StepTc03Trigger].StimulusId := 4;
    StepTable[StepTc03Trigger].CheckIdx[1] := 7;
    StepTable[StepTc03Trigger].CheckIdx[2] := 3;
    StepTable[StepTc03Trigger].CheckIdx[3] := 8;
    StepTable[StepTc03Trigger].TimeoutPT := T#4s;
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

    // --- TC-T4 ---
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

    // --- TC-T5 ---
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
    StepTable[StepTc05Trigger].StimulusId := 11;
    StepTable[StepTc05Trigger].CheckIdx[1] := 3;
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

    // --- TC-T6 (instance isolée FB_Translation, voir fichier suite) ---
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

    // 2. 🔒 VALIDATION — jouée UNE SEULE FOIS ici (les tables sont figées après
    //    construction, revalider chaque scan serait un coût inutile — 128 étapes max)
    ConfigError := FALSE;
ConfigErrorStepId := 0;
ConfigErrorCheckIdx := 0;
ConfigErrorMessage := '';

FOR Idx := 1 TO GVL_PLC_Tests_Const.MaxSteps DO
    IF StepTable[Idx].CaseId > 0 AND NOT ConfigError THEN
        IF StepTable[Idx].NextOnPass < 0 OR StepTable[Idx].NextOnPass > GVL_PLC_Tests_Const.MaxSteps THEN
            ConfigError := TRUE;
            ConfigErrorStepId := Idx;
            ConfigErrorMessage := 'NextOnPass hors limites';
        ELSIF StepTable[Idx].NextOnFail < 0 OR StepTable[Idx].NextOnFail > GVL_PLC_Tests_Const.MaxSteps THEN
            ConfigError := TRUE;
            ConfigErrorStepId := Idx;
            ConfigErrorMessage := 'NextOnFail hors limites';
        ELSIF StepTable[Idx].TimeoutPT <= T#0s THEN
            ConfigError := TRUE;
            ConfigErrorStepId := Idx;
            ConfigErrorMessage := 'TimeoutPT requis (> 0s)';
        ELSE
            FOR Jdx := 1 TO GVL_PLC_Tests_Const.MaxChecksPerStep DO
                Kdx := StepTable[Idx].CheckIdx[Jdx];
                IF Kdx > 0 AND NOT ConfigError THEN
                    IF Kdx > GVL_PLC_Tests_Const.MaxChecks THEN
                        ConfigError := TRUE;
                        ConfigErrorStepId := Idx;
                        ConfigErrorCheckIdx := Kdx;
                        ConfigErrorMessage := 'CheckIdx hors limites';
                    ELSE
                        // 📌 Périmètre restreint : seuls ces 3 Kind / 2 Mode sont supportés
                        CASE CheckTable[Kdx].Kind OF
                            E_TestCheckKind.BOOL_EQUAL:
                                IF CheckTable[Kdx].ProbeIdx < 1 OR CheckTable[Kdx].ProbeIdx > GVL_PLC_Tests_Const.MaxProbeBool THEN
                                    ConfigError := TRUE;
                                    ConfigErrorStepId := Idx;
                                    ConfigErrorCheckIdx := Kdx;
                                    ConfigErrorMessage := 'ProbeIdx BOOL hors limites';
                                END_IF;
                            E_TestCheckKind.WORD_MASK_NONE:
                                IF CheckTable[Kdx].ProbeIdx < 1 OR CheckTable[Kdx].ProbeIdx > GVL_PLC_Tests_Const.MaxProbeDint THEN
                                    ConfigError := TRUE;
                                    ConfigErrorStepId := Idx;
                                    ConfigErrorCheckIdx := Kdx;
                                    ConfigErrorMessage := 'ProbeIdx DINT hors limites';
                                END_IF;
                            E_TestCheckKind.REAL_IN_RANGE:
                                IF CheckTable[Kdx].ProbeIdx < 1 OR CheckTable[Kdx].ProbeIdx > GVL_PLC_Tests_Const.MaxProbeReal THEN
                                    ConfigError := TRUE;
                                    ConfigErrorStepId := Idx;
                                    ConfigErrorCheckIdx := Kdx;
                                    ConfigErrorMessage := 'ProbeIdx REAL hors limites';
                                END_IF;
                        ELSE
                            ConfigError := TRUE;
                            ConfigErrorStepId := Idx;
                            ConfigErrorCheckIdx := Kdx;
                            ConfigErrorMessage := 'Kind non supporte par ce moteur dedie';
                        END_CASE;

                        IF NOT ConfigError THEN
                            IF CheckTable[Kdx].Mode <> E_TestCheckMode.CHECK_WAIT_UNTIL AND CheckTable[Kdx].Mode <> E_TestCheckMode.CHECK_INSTANT THEN
                                ConfigError := TRUE;
                                ConfigErrorStepId := Idx;
                                ConfigErrorCheckIdx := Kdx;
                                ConfigErrorMessage := 'Mode non supporte par ce moteur dedie';
                            END_IF;
                        END_IF;
                    END_IF;
                END_IF;
            END_FOR;
        END_IF;
    END_IF;
END_FOR;

// Cohérence CaseTable[1..6] <-> StepTable (chaque case doit démarrer sur SON setup)
IF NOT ConfigError THEN
    FOR Idx := 1 TO 6 DO
        IF CaseTable[Idx].FirstStep < 1 OR CaseTable[Idx].FirstStep > GVL_PLC_Tests_Const.MaxSteps THEN
            ConfigError := TRUE;
            ConfigErrorStepId := CaseTable[Idx].FirstStep;
            ConfigErrorMessage := 'CaseTable.FirstStep hors limites';
        ELSIF StepTable[CaseTable[Idx].FirstStep].CaseId <> Idx THEN
            ConfigError := TRUE;
            ConfigErrorStepId := CaseTable[Idx].FirstStep;
            ConfigErrorMessage := 'CaseTable.FirstStep ne pointe pas vers SON case';
        END_IF;
    END_FOR;
END_IF;

// 🔒 Validation structurelle complémentaire : stimulus connu, étape utile,
// cibles configurées et changement de case réservé au teardown (Pass=Fail).
IF NOT ConfigError THEN
    FOR Idx := 1 TO GVL_PLC_Tests_Const.MaxSteps DO
        IF StepTable[Idx].CaseId > 0 AND NOT ConfigError THEN
            IF StepTable[Idx].StimulusId < 0 OR StepTable[Idx].StimulusId > 13 THEN
                ConfigError := TRUE; ConfigErrorStepId := Idx;
                ConfigErrorMessage := 'StimulusId hors plage Translation 0..13';
            END_IF;
            HasCheck := FALSE;
            FOR Jdx := 1 TO GVL_PLC_Tests_Const.MaxChecksPerStep DO
                HasCheck := HasCheck OR (StepTable[Idx].CheckIdx[Jdx] > 0);
            END_FOR;
            IF NOT HasCheck AND StepTable[Idx].DwellPT <= T#0s THEN
                ConfigError := TRUE; ConfigErrorStepId := Idx;
                ConfigErrorMessage := 'Etape sans check ni dwell explicite';
            END_IF;
            // 🔒 Branches imbriquées : aucun StepTable[0], sans supposer AND court-circuité.
            IF StepTable[Idx].NextOnPass > 0 THEN
                Kdx := StepTable[Idx].NextOnPass;
                IF StepTable[Kdx].CaseId = 0 THEN
                    ConfigError := TRUE; ConfigErrorStepId := Idx;
                    ConfigErrorMessage := 'NextOnPass vise une etape non configuree';
                END_IF;
            END_IF;
            IF StepTable[Idx].NextOnFail > 0 AND NOT ConfigError THEN
                Kdx := StepTable[Idx].NextOnFail;
                IF StepTable[Kdx].CaseId = 0 THEN
                    ConfigError := TRUE; ConfigErrorStepId := Idx;
                    ConfigErrorMessage := 'NextOnFail vise une etape non configuree';
                ELSIF StepTable[Kdx].CaseId <> StepTable[Idx].CaseId THEN
                    IF StepTable[Idx].NextOnPass <> StepTable[Idx].NextOnFail THEN
                        ConfigError := TRUE; ConfigErrorStepId := Idx;
                        ConfigErrorMessage := 'Echec quitte le case sans teardown commun';
                    END_IF;
                END_IF;
            END_IF;
        END_IF;
    END_FOR;
END_IF;

// 🔁 Chaque chemin nominal Case→fin doit sortir en <= MaxSteps transitions.
IF NOT ConfigError THEN
    FOR Idx := 1 TO 6 DO
        WalkStep := CaseTable[Idx].FirstStep;
        FOR WalkIdx := 1 TO GVL_PLC_Tests_Const.MaxSteps DO
            IF WalkStep = 0 THEN EXIT; END_IF;
            // 🔒 Valider la borne avant de déréférencer WalkStep.
            IF WalkStep < 1 OR WalkStep > GVL_PLC_Tests_Const.MaxSteps THEN
                ConfigError := TRUE; ConfigErrorStepId := WalkStep;
                ConfigErrorMessage := 'Chemin nominal hors limites';
                EXIT;
            END_IF;
            IF StepTable[WalkStep].CaseId = 0 THEN
                ConfigError := TRUE; ConfigErrorStepId := WalkStep;
                ConfigErrorMessage := 'Chemin nominal non configure';
                EXIT;
            END_IF;
            WalkStep := StepTable[WalkStep].NextOnPass;
        END_FOR;
        IF WalkStep <> 0 AND NOT ConfigError THEN
            ConfigError := TRUE; ConfigErrorStepId := WalkStep;
            ConfigErrorMessage := 'Cycle nominal ou chemin sans sortie';
        END_IF;
    END_FOR;
END_IF;

    Ready := NOT ConfigError;
    Built := TRUE;
END_IF;
