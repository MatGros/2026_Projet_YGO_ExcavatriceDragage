// ═══════════════════════════════════════════════════════════════
// 🧪 FB_TranslationValidation — Suite de test Translation M3
// ───────────────────────────────────────────────────────────────
// 📄 Doc métier : DOC/AF_Partie-11_Fonction_Translation_v1.6.md
// 🎯 Valide les surveillances de sécurité de FB_Safety_Translation :
//    TC-T1 Fin de course extrême, TC-T2 Méca B (incohérence à l'arrêt),
//    TC-T3 Méca A (mouvement non commandé). Même moteur générique
//    FB_TestSequencer que FB_SafetyValidation (AF_Partie-14 §7).
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

// 🔒 Refuse si un des capteurs simulés est déjà recâblé réel, ou si le bypass
// IHM_MANU neutralise FB_Safety_Translation (Enable forcé FALSE dans ce cas —
// voir PRG_03_Safety.st "Conditional Bypass Doctrine" REX 2026-07-14) : le test
// tournerait "à vide" (aucun défaut jamais détectable) sans le signaler.
SimGateOk := NOT GVL_Simulation.TranslationPosition_IsReal
         AND NOT GVL_Simulation.ContactorFeedbackM3_IsReal
         AND NOT GVL_Simulation.VariateurM3_IsReal
         AND NOT PRG_10_Outputs.ManuActive;

// 2. 📋 TABLES (Remplissage déclaratif unique)
IF NOT TableReady THEN
    Report.Name := 'Translation Validation';

    // Cas de tests
    CaseTable[1].Name := 'TC-T1 Fin de course extreme';
    CaseTable[1].FirstStep := StepTc01Setup;

    CaseTable[2].Name := 'TC-T2 Meca B incoherence arret';
    CaseTable[2].FirstStep := StepTc02Setup;

    CaseTable[3].Name := 'TC-T3 Meca A mouvement non commande';
    CaseTable[3].FirstStep := StepTc03Setup;

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
    StepTable[StepTc03Teardown].NextOnPass := 0;
    StepTable[StepTc03Teardown].NextOnFail := 0;
    StepTable[StepTc03Teardown].FailAction := E_TestFailAction.FAIL_CONTINUE;

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
    ActiveStimulusId => ActiveStimulusId,
    StepElapsed => StepElapsed
);

// 5. ⚡ STIMULI
CASE ActiveStimulusId OF
    0: // 🔓 Neutre (tout relâché) — garanti sur Done/Abort par le moteur
        GVL_PLC_Tests.OverrideM3AtTremie := FALSE;
        GVL_PLC_Tests.OverrideM3BrakeStuckOpen := FALSE;
        GVL_PLC_Tests.OverrideM3PhantomFreq := FALSE;
        ResetFaults := FALSE;

    1: // Reset défauts, attente saine (Setup & Teardown)
        GVL_PLC_Tests.OverrideM3AtTremie := FALSE;
        GVL_PLC_Tests.OverrideM3BrakeStuckOpen := FALSE;
        GVL_PLC_Tests.OverrideM3PhantomFreq := FALSE;
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
END_CASE;

// Recopie IHM/métier — reset partagé avec la suite Safety (même domaine
// "sécurité/métier", voir PRG_09_Supervision.FaultMachineReset_IHM), sans
// conflit car les suites s'exécutent toujours de façon mutuellement exclusive
// (FB_PLC_Tests_Management n'active qu'une suite à la fois).
IF Busy THEN
    GVL_IHM.Modes.FaultMachineReset := ResetFaults;
END_IF;
