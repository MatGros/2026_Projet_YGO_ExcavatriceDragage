FUNCTION_BLOCK PUBLIC FB_SafetyValidation
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
    SigHealthyIdle                  : INT := 1;
    SigEmergencyStopOk              : INT := 2;
    SigArmingSeqStep                : INT := 3;
    SigPowerCutOffAny               : INT := 4;
    SigRedundancyFailed             : INT := 5;
    SigEmergencyArmingFailed        : INT := 6;
    SigEmergencyArmingLockoutActive : INT := 7;
    SigStopwatchMs                  : INT := 8;
    SigErrorId                      : INT := 9;
    SigOrderABOk                    : INT := 10; // ✅ Chk gagné #3 (§7.4.2) : canal A coupé avant canal B
    SigEdgeCountOk                  : INT := 11; // ✅ Chk gagné #4 (§7.4.2) : exactement 2 chutes EmergencyChain

    // 🪜 Index des étapes
    StepTc01Setup                   : INT := 10;
    StepTc01Arm                     : INT := 11;
    StepTc01Confirm                 : INT := 14;
    StepTc01Trip                    : INT := 15;
    StepTc01Instant                 : INT := 16;
    StepTc01Latch                   : INT := 17;
    StepTc01Teardown                : INT := 19;

    StepTc02Setup                   : INT := 20;
    StepTc02Redundancy              : INT := 21;
    StepTc02Teardown                : INT := 29;

    StepTc03Setup                   : INT := 30;
    StepTc03LockoutWindow           : INT := 32;
    StepTc03LockoutEnd              : INT := 34;
    StepTc03PostReArm               : INT := 35;
    StepTc03Teardown                : INT := 39;
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

    // 🛠️ Instruments de mesure
    instStopwatch              : FB_TestStopwatch;
    instOrderAB                : FB_TestEventOrder;  // ✅ Chk gagné #3 : canal A avant canal B
    instEdgeCountChain         : FB_TestEdgeCounter;  // ✅ Chk gagné #4 : exactement 2 chutes

    // ⚡ Commandes de stimuli affectées dans le CASE
    ArmRequest                 : BOOL;
    ResetFaults                : BOOL;
END_VAR
// === IMPLEMENTATION ===
// 1. 🛡️ GATE
IF NOT GVL_Simulation.SimulationModeActive THEN
    // Abort interne immédiat
    Sequencer(Start := FALSE, Abort := TRUE, FirstStepId := FirstStepId,
              StepTable := StepTable, CheckTable := CheckTable, CaseTable := CaseTable, InvariantTable := InvariantTable,
              ProbeBool := ProbeBool, ProbeDint := ProbeDint, ProbeReal := ProbeReal, Report := Report);
              
    GVL_PLC_Tests.OverrideChainTrue := FALSE;
    GVL_PLC_Tests.OverrideChainFalse := FALSE;
    GVL_PLC_Tests.OverrideContactorFalse := FALSE;
    ArmRequest := FALSE;
    ResetFaults := FALSE;
    SimGateOk := FALSE;
    RETURN;
END_IF;

// La chaîne d'urgence physique ne doit pas être en mode simulation réelle active (sécurité matérielle)
SimGateOk := NOT GVL_Simulation.EmergencyStopChain_IsReal;

// 2. 📋 TABLES (Remplissage déclaratif unique)
IF NOT TableReady THEN
    Report.Name := 'Safety Validation'; // 🏷️ Identifie la suite (SuiteSafetyValidation) sans ambiguïté

    // Cas de tests
    CaseTable[1].Name := 'TC-01 Armement nominal';
    CaseTable[1].FirstStep := StepTc01Setup;

    CaseTable[2].Name := 'TC-02 Redondance';
    CaseTable[2].FirstStep := StepTc02Setup;

    CaseTable[3].Name := 'TC-03 Lockout temporel';
    CaseTable[3].FirstStep := StepTc03Setup;

    // ─────────────────────────────────────────────────────────────
    // 🛡️ INVARIANT DE NON-RÉGRESSION (§7.5.4) — verrouille le correctif du défaut connu
    // (EmergencyArmingLockoutActive posé aussi sur la branche succès). Armé DÈS la
    // confirmation d'armement TC-01, désarmé à l'entrée de TC-02 (portée = le case TC-01
    // uniquement — TC-03 active volontairement le lockout, il ne doit pas être vu comme
    // une violation, d'où le désarmement avant d'y arriver).
    // ─────────────────────────────────────────────────────────────
    InvariantTable[1].Check.Kind := E_TestCheckKind.BOOL_EQUAL;
    InvariantTable[1].Check.ProbeIdx := SigEmergencyArmingLockoutActive;
    InvariantTable[1].Check.ExpectedBool := FALSE;
    InvariantTable[1].ArmAtStepId := StepTc01Confirm;
    InvariantTable[1].DisarmAtStepId := StepTc02Setup;

    // ─────────────────────────────────────────────────────────────
    // CONFIGURATION DES CHECKS (CheckTable)
    // ─────────────────────────────────────────────────────────────
    // Chk 1: Attente état sain (HealthyIdle = TRUE)
    CheckTable[1].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[1].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[1].ProbeIdx := SigHealthyIdle;
    CheckTable[1].ExpectedBool := TRUE;

    // Chk 2: Attente armement étape 5
    CheckTable[2].Kind := E_TestCheckKind.DINT_EQUAL;
    CheckTable[2].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[2].ProbeIdx := SigArmingSeqStep;
    CheckTable[2].ExpectedDint := 5;

    // Chk 3: Attente front montant de confirmation AU
    CheckTable[3].Kind := E_TestCheckKind.BOOL_RISING;
    CheckTable[3].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL; // Sera déclenché sur front
    CheckTable[3].ProbeIdx := SigEmergencyStopOk;

    // Chk 4: Fin de l'impulsion (étape 0)
    CheckTable[4].Kind := E_TestCheckKind.DINT_EQUAL;
    CheckTable[4].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[4].ProbeIdx := SigArmingSeqStep;
    CheckTable[4].ExpectedDint := 0;

    // Chk 5: Confirmation AU Ok
    CheckTable[5].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[5].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[5].ProbeIdx := SigEmergencyStopOk;
    CheckTable[5].ExpectedBool := TRUE;

    // Chk 6: Coupure franche (PowerCutOff = TRUE)
    CheckTable[6].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[6].Mode := E_TestCheckMode.CHECK_INSTANT;
    CheckTable[6].ProbeIdx := SigPowerCutOffAny;
    CheckTable[6].ExpectedBool := TRUE;

    // Chk 7: AU désactivé
    CheckTable[7].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[7].Mode := E_TestCheckMode.CHECK_INSTANT;
    CheckTable[7].ProbeIdx := SigEmergencyStopOk;
    CheckTable[7].ExpectedBool := FALSE;

    // Chk 8: Maintien de la coupure (Latch) avec stabilité 500ms
    CheckTable[8].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[8].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[8].ProbeIdx := SigPowerCutOffAny;
    CheckTable[8].ExpectedBool := TRUE;
    CheckTable[8].StablePT := T#500ms;

    // Chk 9: Détection défaut de redondance
    CheckTable[9].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[9].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[9].ProbeIdx := SigRedundancyFailed;
    CheckTable[9].ExpectedBool := TRUE;

    // Chk 10: Fin réarmement (étape 0) après défaut
    CheckTable[10].Kind := E_TestCheckKind.DINT_EQUAL;
    CheckTable[10].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[10].ProbeIdx := SigArmingSeqStep;
    CheckTable[10].ExpectedDint := 0;

    // Chk 11: Temps de réaction dans la fenêtre [180ms, 260ms]
    CheckTable[11].Kind := E_TestCheckKind.REAL_IN_RANGE;
    CheckTable[11].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[11].ProbeIdx := SigStopwatchMs;
    CheckTable[11].RealMin := 180.0;
    CheckTable[11].RealMax := 260.0;

    // Chk 12: Pas d'erreur parasite (sauf bit 0)
    CheckTable[12].Kind := E_TestCheckKind.WORD_MASK_NONE;
    CheckTable[12].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[12].ProbeIdx := SigErrorId;
    CheckTable[12].Mask := NOT 16#0001; // Tout sauf bit de redondance

    // Chk 13: Échec armement (EmergencyArmingFailed = TRUE)
    CheckTable[13].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[13].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[13].ProbeIdx := SigEmergencyArmingFailed;
    CheckTable[13].ExpectedBool := TRUE;

    // Chk 14: Verrouillage actif (Lockout = TRUE)
    CheckTable[14].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[14].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[14].ProbeIdx := SigEmergencyArmingLockoutActive;
    CheckTable[14].ExpectedBool := TRUE;

    // Chk 15: Interdiction de démarrer pendant Lockout
    CheckTable[15].Kind := E_TestCheckKind.DINT_NOT_EQUAL;
    CheckTable[15].Mode := E_TestCheckMode.CHECK_NEVER_DURING;
    CheckTable[15].ProbeIdx := SigArmingSeqStep;
    CheckTable[15].ExpectedDint := 0;

    // Chk 16: Fin du verrouillage
    CheckTable[16].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[16].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[16].ProbeIdx := SigEmergencyArmingLockoutActive;
    CheckTable[16].ExpectedBool := FALSE;

    // Chk 17: ✅ Chk gagné #3 (§7.4.2) — canal A coupé AVANT canal B pendant l'auto-test
    CheckTable[17].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[17].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[17].ProbeIdx := SigOrderABOk;
    CheckTable[17].ExpectedBool := TRUE;

    // Chk 18: ✅ Chk gagné #4 (§7.4.2) — exactement 2 chutes d'EmergencyChain (1 par canal testé)
    CheckTable[18].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[18].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[18].ProbeIdx := SigEdgeCountOk;
    CheckTable[18].ExpectedBool := TRUE;

    // ─────────────────────────────────────────────────────────────
    // CONFIGURATION DES ÉTAPES (StepTable)
    // ─────────────────────────────────────────────────────────────
    // --- SCÉNARIO 1 ---
    StepTable[StepTc01Setup].Name := 'TC01 Setup saine';
    StepTable[StepTc01Setup].CaseId := 1;
    StepTable[StepTc01Setup].StimulusId := 1; // Reset défauts
    StepTable[StepTc01Setup].CheckIdx[1] := 1;
    StepTable[StepTc01Setup].TimeoutPT := T#12s;
    StepTable[StepTc01Setup].NextOnPass := StepTc01Arm;
    StepTable[StepTc01Setup].NextOnFail := StepTc01Teardown;
    StepTable[StepTc01Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc01Arm].Name := 'TC01 Armement seq';
    StepTable[StepTc01Arm].CaseId := 1;
    StepTable[StepTc01Arm].StimulusId := 2; // ArmRequest := TRUE
    StepTable[StepTc01Arm].CheckIdx[1] := 2;
    StepTable[StepTc01Arm].CheckIdx[2] := 3;
    StepTable[StepTc01Arm].CheckIdx[3] := 17; // ✅ Chk gagné #3 : ordre A avant B
    StepTable[StepTc01Arm].CheckIdx[4] := 18; // ✅ Chk gagné #4 : exactement 2 chutes
    StepTable[StepTc01Arm].TimeoutPT := T#10s;
    StepTable[StepTc01Arm].NextOnPass := StepTc01Confirm;
    StepTable[StepTc01Arm].NextOnFail := StepTc01Teardown;
    StepTable[StepTc01Arm].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc01Confirm].Name := 'TC01 Confirm armé';
    StepTable[StepTc01Confirm].CaseId := 1;
    StepTable[StepTc01Confirm].StimulusId := 0; // Relâcher bouton
    StepTable[StepTc01Confirm].CheckIdx[1] := 4;
    StepTable[StepTc01Confirm].CheckIdx[2] := 5;
    StepTable[StepTc01Confirm].TimeoutPT := T#10s;
    StepTable[StepTc01Confirm].NextOnPass := StepTc01Trip;
    StepTable[StepTc01Confirm].NextOnFail := StepTc01Teardown;
    StepTable[StepTc01Confirm].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc01Trip].Name := 'TC01 Trip urg AU';
    StepTable[StepTc01Trip].CaseId := 1;
    StepTable[StepTc01Trip].StimulusId := 3; // AU simulé (OverrideChainFalse := TRUE)
    StepTable[StepTc01Trip].CheckIdx[1] := 6;
    StepTable[StepTc01Trip].TimeoutPT := T#10s;
    StepTable[StepTc01Trip].NextOnPass := StepTc01Instant;
    StepTable[StepTc01Trip].NextOnFail := StepTc01Teardown;
    StepTable[StepTc01Trip].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc01Instant].Name := 'TC01 Coupure inst';
    StepTable[StepTc01Instant].CaseId := 1;
    StepTable[StepTc01Instant].StimulusId := 3; // Reste appuyé
    StepTable[StepTc01Instant].CheckIdx[1] := 7;
    StepTable[StepTc01Instant].TimeoutPT := T#10s;
    StepTable[StepTc01Instant].NextOnPass := StepTc01Latch;
    StepTable[StepTc01Instant].NextOnFail := StepTc01Teardown;
    StepTable[StepTc01Instant].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc01Latch].Name := 'TC01 Auto-maintien';
    StepTable[StepTc01Latch].CaseId := 1;
    StepTable[StepTc01Latch].StimulusId := 0; // Relâcher AU
    StepTable[StepTc01Latch].CheckIdx[1] := 8; // Stable 500ms
    StepTable[StepTc01Latch].TimeoutPT := T#10s;
    StepTable[StepTc01Latch].NextOnPass := StepTc02Setup; // Cas suivant
    StepTable[StepTc01Latch].NextOnFail := StepTc01Teardown;
    StepTable[StepTc01Latch].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc01Teardown].Name := 'TC01 Teardown';
    StepTable[StepTc01Teardown].CaseId := 1;
    StepTable[StepTc01Teardown].StimulusId := 1; // Nettoyage & Reset
    StepTable[StepTc01Teardown].CheckIdx[1] := 1;
    StepTable[StepTc01Teardown].TimeoutPT := T#12s;
    StepTable[StepTc01Teardown].NextOnPass := StepTc02Setup;
    StepTable[StepTc01Teardown].NextOnFail := StepTc02Setup;
    StepTable[StepTc01Teardown].FailAction := E_TestFailAction.FAIL_CONTINUE;

    // --- SCÉNARIO 2 ---
    StepTable[StepTc02Setup].Name := 'TC02 Setup saine';
    StepTable[StepTc02Setup].CaseId := 2;
    StepTable[StepTc02Setup].StimulusId := 1;
    StepTable[StepTc02Setup].CheckIdx[1] := 1;
    StepTable[StepTc02Setup].TimeoutPT := T#12s;
    StepTable[StepTc02Setup].NextOnPass := StepTc02Redundancy;
    StepTable[StepTc02Setup].NextOnFail := StepTc02Teardown;
    StepTable[StepTc02Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc02Redundancy].Name := 'TC02 Defaut redond';
    StepTable[StepTc02Redundancy].CaseId := 2;
    StepTable[StepTc02Redundancy].StimulusId := 4; // Contact soudé (OverrideChainTrue := TRUE) + Arm
    StepTable[StepTc02Redundancy].CheckIdx[1] := 9;  // RedundancyFailed := TRUE
    StepTable[StepTc02Redundancy].CheckIdx[2] := 10; // ArmingSeqStep := 0
    StepTable[StepTc02Redundancy].CheckIdx[3] := 11; // Durée dans [180ms, 260ms]
    StepTable[StepTc02Redundancy].CheckIdx[4] := 12; // Pas d'erreur parasite
    StepTable[StepTc02Redundancy].TimeoutPT := T#10s;
    StepTable[StepTc02Redundancy].NextOnPass := StepTc02Teardown;
    StepTable[StepTc02Redundancy].NextOnFail := StepTc02Teardown;
    StepTable[StepTc02Redundancy].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc02Teardown].Name := 'TC02 Teardown';
    StepTable[StepTc02Teardown].CaseId := 2;
    StepTable[StepTc02Teardown].StimulusId := 1;
    StepTable[StepTc02Teardown].CheckIdx[1] := 1;
    StepTable[StepTc02Teardown].TimeoutPT := T#12s;
    StepTable[StepTc02Teardown].NextOnPass := StepTc03Setup;
    StepTable[StepTc02Teardown].NextOnFail := StepTc03Setup;
    StepTable[StepTc02Teardown].FailAction := E_TestFailAction.FAIL_CONTINUE;

    // --- SCÉNARIO 3 ---
    StepTable[StepTc03Setup].Name := 'TC03 Setup lockout';
    StepTable[StepTc03Setup].CaseId := 3;
    StepTable[StepTc03Setup].StimulusId := 5; // Blocage contacteur (OverrideContactorFalse := TRUE) + Arm
    StepTable[StepTc03Setup].CheckIdx[1] := 13; // EmergencyArmingFailed := TRUE
    StepTable[StepTc03Setup].CheckIdx[2] := 14; // LockoutActive := TRUE
    StepTable[StepTc03Setup].TimeoutPT := T#10s;
    StepTable[StepTc03Setup].NextOnPass := StepTc03LockoutWindow;
    StepTable[StepTc03Setup].NextOnFail := StepTc03Teardown;
    StepTable[StepTc03Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc03LockoutWindow].Name := 'TC03 Lockout cmd ign';
    StepTable[StepTc03LockoutWindow].CaseId := 3;
    StepTable[StepTc03LockoutWindow].StimulusId := 6; // Force armement pendant lockout
    StepTable[StepTc03LockoutWindow].CheckIdx[1] := 15; // ArmingSeqStep reste à 0 (NEVER_DURING)
    StepTable[StepTc03LockoutWindow].TimeoutPT := T#4800ms;
    StepTable[StepTc03LockoutWindow].NextOnPass := StepTc03LockoutEnd;
    StepTable[StepTc03LockoutWindow].NextOnFail := StepTc03Teardown;
    StepTable[StepTc03LockoutWindow].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc03LockoutEnd].Name := 'TC03 Attente fin lockout';
    StepTable[StepTc03LockoutEnd].CaseId := 3;
    StepTable[StepTc03LockoutEnd].StimulusId := 7; // Relâcher contacteur
    StepTable[StepTc03LockoutEnd].CheckIdx[1] := 16; // LockoutActive := FALSE
    StepTable[StepTc03LockoutEnd].TimeoutPT := T#2s;
    StepTable[StepTc03LockoutEnd].NextOnPass := StepTc03PostReArm;
    StepTable[StepTc03LockoutEnd].NextOnFail := StepTc03Teardown;
    StepTable[StepTc03LockoutEnd].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc03PostReArm].Name := 'TC03 Re-armement nominal';
    StepTable[StepTc03PostReArm].CaseId := 3;
    StepTable[StepTc03PostReArm].StimulusId := 8; // Armement nominal après fin lockout
    StepTable[StepTc03PostReArm].CheckIdx[1] := 5; // EmergencyStopOk := TRUE
    StepTable[StepTc03PostReArm].TimeoutPT := T#5s;
    StepTable[StepTc03PostReArm].NextOnPass := 0; // Fin de la suite
    StepTable[StepTc03PostReArm].NextOnFail := StepTc03Teardown;
    StepTable[StepTc03PostReArm].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepTc03Teardown].Name := 'TC03 Teardown';
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
ProbeBool[SigHealthyIdle] := NOT PRG_10_Outputs.instSafetyEmergencyManagement.RedundancyTestFailed AND 
                             NOT PRG_10_Outputs.instSafetyEmergencyManagement.EmergencyArmingFailed AND
                             NOT PRG_10_Outputs.instSafetyEmergencyManagement.EmergencyArmingLockoutActive;

ProbeBool[SigEmergencyStopOk] := PRG_00_Inputs.EmergencyStopOk;
ProbeDint[SigArmingSeqStep] := PRG_10_Outputs.instSafetyEmergencyManagement.ArmingSeqStep;
ProbeBool[SigPowerCutOffAny] := NOT PRG_00_Inputs.EmergencyStopOk;
ProbeBool[SigRedundancyFailed] := PRG_10_Outputs.instSafetyEmergencyManagement.RedundancyTestFailed;
ProbeBool[SigEmergencyArmingFailed] := PRG_10_Outputs.instSafetyEmergencyManagement.EmergencyArmingFailed;
ProbeBool[SigEmergencyArmingLockoutActive] := PRG_10_Outputs.instSafetyEmergencyManagement.EmergencyArmingLockoutActive;
ProbeReal[SigStopwatchMs] := DINT_TO_REAL(instStopwatch.ElapsedMs);
ProbeDint[SigErrorId] := WORD_TO_DINT(PRG_10_Outputs.instSafetyEmergencyManagement.ErrorId);
ProbeBool[SigOrderABOk] := instOrderAB.OrderOk;
ProbeBool[SigEdgeCountOk] := instEdgeCountChain.InRange;

// Liaison des instruments de mesure
instStopwatch(
    Arm := (Sequencer.ActiveStimulusId = 4),
    StartEvent := (PRG_10_Outputs.instSafetyEmergencyManagement.ArmingSeqStep = 1),
    StopEvent := PRG_10_Outputs.instSafetyEmergencyManagement.RedundancyTestFailed,
    ExpectedMinMs := 180,
    ExpectedMaxMs := 260
);

// ✅ Chk gagné #3 : canal A coupé avant canal B (armé pendant tout l'auto-test TC-01,
// stimulus 2 = demande d'armement). EventA/B = front montant de "NOT PowerCutOff_X_RQ",
// c'est-à-dire le moment où le canal RETOMBE (auto-test ForceTestA/B de la Logic).
instOrderAB(
    Arm := (Sequencer.ActiveStimulusId = 2),
    EventA := NOT PowerCutOff_A_RQ,
    EventB := NOT PowerCutOff_B_RQ,
    TimeoutPT := T#10s
);

// ✅ Chk gagné #4 : exactement 2 chutes d'EmergencyChain pendant le même auto-test
// (1 pour le test canal A, 1 pour le test canal B — 3 = rebond, 1 = canal non testé)
instEdgeCountChain(
    Arm := (Sequencer.ActiveStimulusId = 2),
    Signal := PRG_00_Inputs.EmergencyChain,
    CountRising := FALSE,
    ExpectedMin := 2,
    ExpectedMax := 2
);

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
    0: // 🔓 Neutre (tout relâché)
        GVL_PLC_Tests.OverrideChainTrue := FALSE;
        GVL_PLC_Tests.OverrideChainFalse := FALSE;
        GVL_PLC_Tests.OverrideContactorFalse := FALSE;
        ArmRequest := FALSE;
        ResetFaults := FALSE;

    1: // Reset défauts, attente saine
        GVL_PLC_Tests.OverrideChainTrue := FALSE;
        GVL_PLC_Tests.OverrideChainFalse := FALSE;
        GVL_PLC_Tests.OverrideContactorFalse := FALSE;
        ArmRequest := FALSE;
        ResetFaults := TRUE;

    2: // TC-01 : Demande d'armement nominal
        GVL_PLC_Tests.OverrideChainTrue := FALSE;
        GVL_PLC_Tests.OverrideChainFalse := FALSE;
        GVL_PLC_Tests.OverrideContactorFalse := FALSE;
        ArmRequest := TRUE;
        ResetFaults := FALSE;

    3: // TC-01 : Coupure franche (AU pressé)
        GVL_PLC_Tests.OverrideChainTrue := FALSE;
        GVL_PLC_Tests.OverrideChainFalse := TRUE;
        // 🔧 REX 2026-07-16 : OverrideChainFalse seul a 1 scan de retard (instSimSafety lu
        // AVANT instTestsManagement() dans PRG_00_Inputs.st) — incompatible avec le check 6
        // en CHECK_INSTANT. OverrideContactorFalse force EmergencyStopOk directement et
        // tardivement (après instTestsManagement()) → effet le même scan.
        GVL_PLC_Tests.OverrideContactorFalse := TRUE;
        ArmRequest := FALSE;
        ResetFaults := FALSE;

    4: // TC-02 : Contact soudé canal A (OverrideChainTrue) + Armement
        GVL_PLC_Tests.OverrideChainTrue := TRUE;
        GVL_PLC_Tests.OverrideChainFalse := FALSE;
        GVL_PLC_Tests.OverrideContactorFalse := FALSE;
        ArmRequest := TRUE;
        ResetFaults := FALSE;

    5: // TC-03 : Contacteur puissance bloqué ouvert (OverrideContactorFalse) + Armement
        GVL_PLC_Tests.OverrideChainTrue := FALSE;
        GVL_PLC_Tests.OverrideChainFalse := FALSE;
        GVL_PLC_Tests.OverrideContactorFalse := TRUE;
        ArmRequest := TRUE;
        ResetFaults := TRUE;

    6: // TC-03 : Tentative armement pendant lockout
        GVL_PLC_Tests.OverrideChainTrue := FALSE;
        GVL_PLC_Tests.OverrideChainFalse := FALSE;
        GVL_PLC_Tests.OverrideContactorFalse := TRUE;
        ArmRequest := TRUE;
        ResetFaults := FALSE;

    7: // TC-03 : Relâchement contacteur bloqueur + reset
        GVL_PLC_Tests.OverrideChainTrue := FALSE;
        GVL_PLC_Tests.OverrideChainFalse := FALSE;
        GVL_PLC_Tests.OverrideContactorFalse := FALSE;
        ArmRequest := FALSE;
        ResetFaults := TRUE;

    8: // TC-03 : Réarmement nominal post-lockout
        GVL_PLC_Tests.OverrideChainTrue := FALSE;
        GVL_PLC_Tests.OverrideChainFalse := FALSE;
        GVL_PLC_Tests.OverrideContactorFalse := FALSE;
        ArmRequest := TRUE;
        ResetFaults := FALSE;
END_CASE;

// Recopie IHM/métier
IF Busy THEN
    GVL_IHM.Modes.CmdEmergencyArming := ArmRequest;
    GVL_IHM.Modes.FaultMachineReset  := ResetFaults;
END_IF;
