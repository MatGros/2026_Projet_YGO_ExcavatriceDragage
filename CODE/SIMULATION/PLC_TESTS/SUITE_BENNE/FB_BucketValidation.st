(* ═══════════════════════════════════════════════════════════════
   🧪 FB_BucketValidation — Suite de test Bucket (Séquenceur)
   ───────────────────────────────────────────────────────────────
   🎯 Valide la sécurité mécanique (Méca C), les timeouts et le
      référencement du bucket selon AF Partie 12 & 14.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_BucketValidation
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
    // 🏷️ Index des sondes (Sémantique AF P14 §7.2)
    SigHealthyIdle              : INT := 1;
    SigBucketBusy               : INT := 2;
    SigBucketDone               : INT := 3;
    SigBucketError              : INT := 4;
    SigM1SlipDetected           : INT := 5;
    SigM1SafeStop               : INT := 6;
    SigM1PowerCutOff            : INT := 7;
    SigBucketIsOpen             : INT := 8;
    SigBucketIsClosed           : INT := 9;
    SigM2StartStop              : INT := 10;
    SigM2ForceSlowSpeed         : INT := 11;

    SigBucketErrorId            : INT := 1;
    SigM2Direction              : INT := 2;
    SigSafetyM1ErrorId          : INT := 3;

    SigActiveOffsetM            : INT := 1;
    SigRemainingTravelM         : INT := 2;
    SigM2CablePos               : INT := 3;
    SigM2TopLimit               : INT := 4;

    // 🪜 Index des étapes (Séquenceur)
    // TC-B1 : Glissement Modéré
    StepB1Setup                 : INT := 10;
    StepB1Trigger               : INT := 11;
    StepB1Slip                   : INT := 12;
    StepB1Teardown               : INT := 19;

    // TC-B2 : Glissement Critique
    StepB2Setup                 : INT := 20;
    StepB2Trigger               : INT := 21;
    StepB2CriticalSlip           : INT := 22;
    StepB2Teardown               : INT := 29;

    // TC-B3 : Butée Haute Dynamique
    StepB3Setup                 : INT := 30;
    StepB3CheckOpenLimit         : INT := 31;
    StepB3CloseAction            : INT := 32;
    StepB3CheckClosedLimit       : INT := 33;
    StepB3Teardown               : INT := 39;

    // TC-B4 : Cohérence Boot
    StepB4Setup                 : INT := 40;
    StepB4BootIncoherent         : INT := 41;
    StepB4Recalage               : INT := 42;
    StepB4Teardown               : INT := 49;

    // TC-B5 : Homing & Inhibition
    StepB5Setup                 : INT := 50;
    StepB5LostHoming             : INT := 51;
    StepB5RestoreHoming          : INT := 52;
    StepB5InhibitM1              : INT := 53;
    StepB5Teardown               : INT := 59;

    // TC-B6 : Homme-Mort & Recul
    StepB6Setup                 : INT := 60;
    StepB6StartMove              : INT := 61;
    StepB6ReleaseJoy             : INT := 62;
    StepB6ReverseJoy             : INT := 63;
    StepB6Teardown               : INT := 69;
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

    // ⚡ Commandes de stimuli internes
    CmdOpen_IHM                : BOOL;
    CmdClose_IHM               : BOOL;
    JoystickY_StartStop        : BOOL;
    JoystickY_Direction        : INT;
    ConfirmOpenPosition        : BOOL;
    HomedM1                    : BOOL := TRUE;
    InhibitM1                  : BOOL;
END_VAR

// === IMPLEMENTATION ===

// 1. 🛡️ GATE
IF NOT GVL_Simulation.SimulationModeActive THEN
    Sequencer(Start := FALSE, Abort := TRUE, FirstStepId := FirstStepId,
              StepTable := StepTable, CheckTable := CheckTable, CaseTable := CaseTable, InvariantTable := InvariantTable,
              ProbeBool := ProbeBool, ProbeDint := ProbeDint, ProbeReal := ProbeReal, Report := Report);

    SimGateOk := FALSE;
    RETURN;
END_IF;

// Gate spécifique Bucket : refuse si M1 ou M2 sont en simulation réelle (Sûreté)
SimGateOk := NOT GVL_Simulation.EncoderM1_IsReal AND NOT GVL_Simulation.EncoderM2_IsReal;

// 2. 📋 TABLES
IF NOT TableReady THEN
    Report.Name := 'Bucket Validation';

    // Cas de tests
    CaseTable[1].Name := 'TC-B1 Glissement Modéré';
    CaseTable[1].FirstStep := StepB1Setup;

    CaseTable[2].Name := 'TC-B2 Glissement Critique';
    CaseTable[2].FirstStep := StepB2Setup;

    CaseTable[3].Name := 'TC-B3 Butée Haute Dynamique';
    CaseTable[3].FirstStep := StepB3Setup;

    CaseTable[4].Name := 'TC-B4 Cohérence Boot';
    CaseTable[4].FirstStep := StepB4Setup;

    CaseTable[5].Name := 'TC-B5 Homing & Inhibition';
    CaseTable[5].FirstStep := StepB5Setup;

    CaseTable[6].Name := 'TC-B6 Homme-Mort & Recul';
    CaseTable[6].FirstStep := StepB6Setup;

    // ─────────────────────────────────────────────────────────────
    // CONFIGURATION DES CHECKS
    // ─────────────────────────────────────────────────────────────
    // Chk 1: Attente état sain
    CheckTable[1].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[1].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[1].ProbeIdx := SigHealthyIdle;
    CheckTable[1].ExpectedBool := TRUE;

    // Chk 2: Bucket Busy
    CheckTable[2].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[2].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[2].ProbeIdx := SigBucketBusy;
    CheckTable[2].ExpectedBool := TRUE;

    // Chk 3: Glissement M1 détecté
    CheckTable[3].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[3].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[3].ProbeIdx := SigM1SlipDetected;
    CheckTable[3].ExpectedBool := TRUE;

    // Chk 4: Bit ErrorId 4 levé (16#0010)
    CheckTable[4].Kind := E_TestCheckKind.WORD_MASK_ALL;
    CheckTable[4].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[4].ProbeIdx := SigBucketErrorId;
    CheckTable[4].Mask := 16#0010;

    // Chk 5: Coupure immédiate M2
    CheckTable[5].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[5].Mode := E_TestCheckMode.CHECK_INSTANT;
    CheckTable[5].ProbeIdx := SigM2StartStop;
    CheckTable[5].ExpectedBool := FALSE;

    // Chk 6: SafeStop M1 activé
    CheckTable[6].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[6].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[6].ProbeIdx := SigM1SafeStop;
    CheckTable[6].ExpectedBool := TRUE;

    // Chk 7: PowerCutOff M1 NON activé (Couche 1 seulement)
    CheckTable[7].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[7].Mode := E_TestCheckMode.CHECK_INSTANT;
    CheckTable[7].ProbeIdx := SigM1PowerCutOff;
    CheckTable[7].ExpectedBool := FALSE;

    // Chk 8: PowerCutOff M1 activé (Couche 2)
    CheckTable[8].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[8].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[8].ProbeIdx := SigM1PowerCutOff;
    CheckTable[8].ExpectedBool := TRUE;

    // Chk 9: Défaut Safety M1 Bit 9 (16#0200)
    CheckTable[9].Kind := E_TestCheckKind.WORD_MASK_ALL;
    CheckTable[9].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[9].ProbeIdx := SigSafetyM1ErrorId;
    CheckTable[9].Mask := 16#0200;

    // Chk 10: Limite haute standard (12m)
    CheckTable[10].Kind := E_TestCheckKind.REAL_IN_RANGE;
    CheckTable[10].Mode := E_TestCheckMode.CHECK_INSTANT;
    CheckTable[10].ProbeIdx := SigM2TopLimit;
    CheckTable[10].RealMin := 12.0;
    CheckTable[10].RealMax := 12.1;

    // Chk 11: Bucket fermé mémorisé
    CheckTable[11].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[11].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[11].ProbeIdx := SigBucketIsClosed;
    CheckTable[11].ExpectedBool := TRUE;

    // Chk 12: Limite haute décalée (+10m -> 22m)
    CheckTable[12].Kind := E_TestCheckKind.REAL_IN_RANGE;
    CheckTable[12].Mode := E_TestCheckMode.CHECK_INSTANT;
    CheckTable[12].ProbeIdx := SigM2TopLimit;
    CheckTable[12].RealMin := 22.0;
    CheckTable[12].RealMax := 22.1;

    // Chk 13: Erreur Bucket active
    CheckTable[13].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[13].Mode := E_TestCheckMode.CHECK_INSTANT;
    CheckTable[13].ProbeIdx := SigBucketError;
    CheckTable[13].ExpectedBool := TRUE;

    // Chk 14: Bit ErrorId 1 levé (Incohérence boot)
    CheckTable[14].Kind := E_TestCheckKind.WORD_MASK_ALL;
    CheckTable[14].Mode := E_TestCheckMode.CHECK_INSTANT;
    CheckTable[14].ProbeIdx := SigBucketErrorId;
    CheckTable[14].Mask := 16#0002;

    // Chk 15: États mémorisés forcés à FALSE
    CheckTable[15].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[15].Mode := E_TestCheckMode.CHECK_INSTANT;
    CheckTable[15].ProbeIdx := SigBucketIsOpen;
    CheckTable[15].ExpectedBool := FALSE;

    // Chk 16: Idem pour IsClosed
    CheckTable[16].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[16].Mode := E_TestCheckMode.CHECK_INSTANT;
    CheckTable[16].ProbeIdx := SigBucketIsClosed;
    CheckTable[16].ExpectedBool := FALSE;

    // Chk 17: Bucket ouvert mémorisé après recalage
    CheckTable[17].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[17].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[17].ProbeIdx := SigBucketIsOpen;
    CheckTable[17].ExpectedBool := TRUE;

    // Chk 18: Bit ErrorId 3 levé (Non référencé)
    CheckTable[18].Kind := E_TestCheckKind.WORD_MASK_ALL;
    CheckTable[18].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[18].ProbeIdx := SigBucketErrorId;
    CheckTable[18].Mask := 16#0008;

    // Chk 19: Bucket non opérationnel
    CheckTable[19].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[19].Mode := E_TestCheckMode.CHECK_INSTANT;
    CheckTable[19].ProbeIdx := SigHealthyIdle;
    CheckTable[19].ExpectedBool := FALSE;

    // Chk 20: Glissement M1 ignoré pendant inhibition
    CheckTable[20].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[20].Mode := E_TestCheckMode.CHECK_NEVER_DURING;
    CheckTable[20].ProbeIdx := SigM1SlipDetected;
    CheckTable[20].ExpectedBool := TRUE;

    // Chk 21: Mouvement terminé
    CheckTable[21].Kind := E_TestCheckKind.BOOL_EQUAL;
    CheckTable[21].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[21].ProbeIdx := SigBucketDone;
    CheckTable[21].ExpectedBool := TRUE;

    // Chk 22: Direction M2 = -1 (Déroulage)
    CheckTable[22].Kind := E_TestCheckKind.DINT_EQUAL;
    CheckTable[22].Mode := E_TestCheckMode.CHECK_WAIT_UNTIL;
    CheckTable[22].ProbeIdx := SigM2Direction;
    CheckTable[22].ExpectedDint := -1;

    // Chk 23: M2 ne dépasse pas la position de départ (Sonde Real)
    CheckTable[23].Kind := E_TestCheckKind.REAL_IN_RANGE;
    CheckTable[23].Mode := E_TestCheckMode.CHECK_NEVER_DURING;
    CheckTable[23].ProbeIdx := SigM2CablePos;
    CheckTable[23].RealMin := 0.0; // Valeur relative simulée ici
    CheckTable[23].RealMax := 0.1;

    // ─────────────────────────────────────────────────────────────
    // CONFIGURATION DES ÉTAPES (StepTable)
    // ─────────────────────────────────────────────────────────────
    // TC-B1 : Glissement Modéré
    StepTable[StepB1Setup].Name := 'Tcb1 Setup saine';
    StepTable[StepB1Setup].CaseId := 1;
    StepTable[StepB1Setup].StimulusId := 1;
    StepTable[StepB1Setup].CheckIdx[1] := 1;
    StepTable[StepB1Setup].TimeoutPT := T#12s;
    StepTable[StepB1Setup].NextOnPass := StepB1Trigger;
    StepTable[StepB1Setup].NextOnFail := StepB1Teardown;
    StepTable[StepB1Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB1Trigger].Name := 'Tcb1 Trigger fermeture';
    StepTable[StepB1Trigger].CaseId := 1;
    StepTable[StepB1Trigger].StimulusId := 2;
    StepTable[StepB1Trigger].CheckIdx[1] := 2;
    StepTable[StepB1Trigger].TimeoutPT := T#5s;
    StepTable[StepB1Trigger].NextOnPass := StepB1Slip;
    StepTable[StepB1Trigger].NextOnFail := StepB1Teardown;
    StepTable[StepB1Trigger].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB1Slip].Name := 'Tcb1 Detection glissement';
    StepTable[StepB1Slip].CaseId := 1;
    StepTable[StepB1Slip].StimulusId := 3;
    StepTable[StepB1Slip].CheckIdx[1] := 3;
    StepTable[StepB1Slip].CheckIdx[2] := 5;
    StepTable[StepB1Slip].CheckIdx[3] := 6;
    StepTable[StepB1Slip].CheckIdx[4] := 7;
    StepTable[StepB1Slip].TimeoutPT := T#2s;
    StepTable[StepB1Slip].NextOnPass := StepB1Teardown;
    StepTable[StepB1Slip].NextOnFail := StepB1Teardown;
    StepTable[StepB1Slip].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB1Teardown].Name := 'Tcb1 Teardown';
    StepTable[StepB1Teardown].CaseId := 1;
    StepTable[StepB1Teardown].StimulusId := 1;
    StepTable[StepB1Teardown].CheckIdx[1] := 1;
    StepTable[StepB1Teardown].TimeoutPT := T#12s;
    StepTable[StepB1Teardown].NextOnPass := StepB2Setup;
    StepTable[StepB1Teardown].NextOnFail := StepB2Setup;
    StepTable[StepB1Teardown].FailAction := E_TestFailAction.FAIL_CONTINUE;

    // TC-B2 : Glissement Critique
    StepTable[StepB2Setup].Name := 'Tcb2 Setup saine';
    StepTable[StepB2Setup].CaseId := 2;
    StepTable[StepB2Setup].StimulusId := 1;
    StepTable[StepB2Setup].CheckIdx[1] := 1;
    StepTable[StepB2Setup].TimeoutPT := T#12s;
    StepTable[StepB2Setup].NextOnPass := StepB2Trigger;
    StepTable[StepB2Setup].NextOnFail := StepB2Teardown;
    StepTable[StepB2Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB2Trigger].Name := 'Tcb2 Trigger fermeture';
    StepTable[StepB2Trigger].CaseId := 2;
    StepTable[StepB2Trigger].StimulusId := 2;
    StepTable[StepB2Trigger].CheckIdx[1] := 2;
    StepTable[StepB2Trigger].TimeoutPT := T#5s;
    StepTable[StepB2Trigger].NextOnPass := StepB2CriticalSlip;
    StepTable[StepB2Trigger].NextOnFail := StepB2Teardown;
    StepTable[StepB2Trigger].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB2CriticalSlip].Name := 'Tcb2 Escalade PowerCutOff';
    StepTable[StepB2CriticalSlip].CaseId := 2;
    StepTable[StepB2CriticalSlip].StimulusId := 4;
    StepTable[StepB2CriticalSlip].CheckIdx[1] := 3;
    StepTable[StepB2CriticalSlip].CheckIdx[2] := 8;
    StepTable[StepB2CriticalSlip].CheckIdx[3] := 9;
    StepTable[StepB2CriticalSlip].TimeoutPT := T#2s;
    StepTable[StepB2CriticalSlip].NextOnPass := StepB2Teardown;
    StepTable[StepB2CriticalSlip].NextOnFail := StepB2Teardown;
    StepTable[StepB2CriticalSlip].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB2Teardown].Name := 'Tcb2 Teardown';
    StepTable[StepB2Teardown].CaseId := 2;
    StepTable[StepB2Teardown].StimulusId := 1;
    StepTable[StepB2Teardown].CheckIdx[1] := 1;
    StepTable[StepB2Teardown].TimeoutPT := T#12s;
    StepTable[StepB2Teardown].NextOnPass := StepB3Setup;
    StepTable[StepB2Teardown].NextOnFail := StepB3Setup;
    StepTable[StepB2Teardown].FailAction := E_TestFailAction.FAIL_CONTINUE;

    // TC-B3 : Butée Haute Dynamique
    StepTable[StepB3Setup].Name := 'Tcb3 Setup saine';
    StepTable[StepB3Setup].CaseId := 3;
    StepTable[StepB3Setup].StimulusId := 1;
    StepTable[StepB3Setup].CheckIdx[1] := 1;
    StepTable[StepB3Setup].TimeoutPT := T#12s;
    StepTable[StepB3Setup].NextOnPass := StepB3CheckOpenLimit;
    StepTable[StepB3Setup].NextOnFail := StepB3Teardown;
    StepTable[StepB3Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB3CheckOpenLimit].Name := 'Tcb3 Verif Limite Standard';
    StepTable[StepB3CheckOpenLimit].CaseId := 3;
    StepTable[StepB3CheckOpenLimit].StimulusId := 0;
    StepTable[StepB3CheckOpenLimit].CheckIdx[1] := 10;
    StepTable[StepB3CheckOpenLimit].TimeoutPT := T#1s;
    StepTable[StepB3CheckOpenLimit].NextOnPass := StepB3CloseAction;
    StepTable[StepB3CheckOpenLimit].NextOnFail := StepB3Teardown;
    StepTable[StepB3CheckOpenLimit].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB3CloseAction].Name := 'Tcb3 Mouvement Fermeture';
    StepTable[StepB3CloseAction].CaseId := 3;
    StepTable[StepB3CloseAction].StimulusId := 5;
    StepTable[StepB3CloseAction].CheckIdx[1] := 11;
    StepTable[StepB3CloseAction].TimeoutPT := T#15s;
    StepTable[StepB3CloseAction].NextOnPass := StepB3CheckClosedLimit;
    StepTable[StepB3CloseAction].NextOnFail := StepB3Teardown;
    StepTable[StepB3CloseAction].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB3CheckClosedLimit].Name := 'Tcb3 Verif Limite Decalee';
    StepTable[StepB3CheckClosedLimit].CaseId := 3;
    StepTable[StepB3CheckClosedLimit].StimulusId := 0;
    StepTable[StepB3CheckClosedLimit].CheckIdx[1] := 12;
    StepTable[StepB3CheckClosedLimit].TimeoutPT := T#1s;
    StepTable[StepB3CheckClosedLimit].NextOnPass := StepB3Teardown;
    StepTable[StepB3CheckClosedLimit].NextOnFail := StepB3Teardown;
    StepTable[StepB3CheckClosedLimit].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB3Teardown].Name := 'Tcb3 Teardown';
    StepTable[StepB3Teardown].CaseId := 3;
    StepTable[StepB3Teardown].StimulusId := 1;
    StepTable[StepB3Teardown].CheckIdx[1] := 1;
    StepTable[StepB3Teardown].TimeoutPT := T#12s;
    StepTable[StepB3Teardown].NextOnPass := StepB4Setup;
    StepTable[StepB3Teardown].NextOnFail := StepB4Setup;
    StepTable[StepB3Teardown].FailAction := E_TestFailAction.FAIL_CONTINUE;

    // TC-B4 : Cohérence Boot
    StepTable[StepB4Setup].Name := 'Tcb4 Setup saine';
    StepTable[StepB4Setup].CaseId := 4;
    StepTable[StepB4Setup].StimulusId := 1;
    StepTable[StepB4Setup].CheckIdx[1] := 1;
    StepTable[StepB4Setup].TimeoutPT := T#12s;
    StepTable[StepB4Setup].NextOnPass := StepB4BootIncoherent;
    StepTable[StepB4Setup].NextOnFail := StepB4Teardown;
    StepTable[StepB4Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB4BootIncoherent].Name := 'Tcb4 Injection Drift Boot';
    StepTable[StepB4BootIncoherent].CaseId := 4;
    StepTable[StepB4BootIncoherent].StimulusId := 6;
    StepTable[StepB4BootIncoherent].CheckIdx[1] := 13;
    StepTable[StepB4BootIncoherent].CheckIdx[2] := 14;
    StepTable[StepB4BootIncoherent].CheckIdx[3] := 15;
    StepTable[StepB4BootIncoherent].CheckIdx[4] := 16;
    StepTable[StepB4BootIncoherent].TimeoutPT := T#2s;
    StepTable[StepB4BootIncoherent].NextOnPass := StepB4Recalage;
    StepTable[StepB4BootIncoherent].NextOnFail := StepB4Teardown;
    StepTable[StepB4BootIncoherent].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB4Recalage].Name := 'Tcb4 Recalage Manuel';
    StepTable[StepB4Recalage].CaseId := 4;
    StepTable[StepB4Recalage].StimulusId := 7;
    StepTable[StepB4Recalage].CheckIdx[1] := 17;
    StepTable[StepB4Recalage].CheckIdx[2] := 1;
    StepTable[StepB4Recalage].TimeoutPT := T#2s;
    StepTable[StepB4Recalage].NextOnPass := StepB4Teardown;
    StepTable[StepB4Recalage].NextOnFail := StepB4Teardown;
    StepTable[StepB4Recalage].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB4Teardown].Name := 'Tcb4 Teardown';
    StepTable[StepB4Teardown].CaseId := 4;
    StepTable[StepB4Teardown].StimulusId := 1;
    StepTable[StepB4Teardown].CheckIdx[1] := 1;
    StepTable[StepB4Teardown].TimeoutPT := T#12s;
    StepTable[StepB4Teardown].NextOnPass := StepB5Setup;
    StepTable[StepB4Teardown].NextOnFail := StepB5Setup;
    StepTable[StepB4Teardown].FailAction := E_TestFailAction.FAIL_CONTINUE;

    // TC-B5 : Homing & Inhibition
    StepTable[StepB5Setup].Name := 'Tcb5 Setup saine';
    StepTable[StepB5Setup].CaseId := 5;
    StepTable[StepB5Setup].StimulusId := 1;
    StepTable[StepB5Setup].CheckIdx[1] := 1;
    StepTable[StepB5Setup].TimeoutPT := T#12s;
    StepTable[StepB5Setup].NextOnPass := StepB5LostHoming;
    StepTable[StepB5Setup].NextOnFail := StepB5Teardown;
    StepTable[StepB5Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB5LostHoming].Name := 'Tcb5 Perte Homing';
    StepTable[StepB5LostHoming].CaseId := 5;
    StepTable[StepB5LostHoming].StimulusId := 8;
    StepTable[StepB5LostHoming].CheckIdx[1] := 18;
    StepTable[StepB5LostHoming].CheckIdx[2] := 19;
    StepTable[StepB5LostHoming].TimeoutPT := T#2s;
    StepTable[StepB5LostHoming].NextOnPass := StepB5RestoreHoming;
    StepTable[StepB5LostHoming].NextOnFail := StepB5Teardown;
    StepTable[StepB5LostHoming].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB5RestoreHoming].Name := 'Tcb5 Rétablissement Homing';
    StepTable[StepB5RestoreHoming].CaseId := 5;
    StepTable[StepB5RestoreHoming].StimulusId := 1; // (Force HomedM1 := TRUE via Reset/Saine)
    StepTable[StepB5RestoreHoming].CheckIdx[1] := 1;
    StepTable[StepB5RestoreHoming].TimeoutPT := T#12s;
    StepTable[StepB5RestoreHoming].NextOnPass := StepB5InhibitM1;
    StepTable[StepB5RestoreHoming].NextOnFail := StepB5Teardown;
    StepTable[StepB5RestoreHoming].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB5InhibitM1].Name := 'Tcb5 Inhibition M1';
    StepTable[StepB5InhibitM1].CaseId := 5;
    StepTable[StepB5InhibitM1].StimulusId := 9;
    StepTable[StepB5InhibitM1].CheckIdx[1] := 20;
    StepTable[StepB5InhibitM1].CheckIdx[2] := 21;
    StepTable[StepB5InhibitM1].TimeoutPT := T#15s;
    StepTable[StepB5InhibitM1].NextOnPass := StepB5Teardown;
    StepTable[StepB5InhibitM1].NextOnFail := StepB5Teardown;
    StepTable[StepB5InhibitM1].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB5Teardown].Name := 'Tcb5 Teardown';
    StepTable[StepB5Teardown].CaseId := 5;
    StepTable[StepB5Teardown].StimulusId := 1;
    StepTable[StepB5Teardown].CheckIdx[1] := 1;
    StepTable[StepB5Teardown].TimeoutPT := T#12s;
    StepTable[StepB5Teardown].NextOnPass := StepB6Setup;
    StepTable[StepB5Teardown].NextOnFail := StepB6Setup;
    StepTable[StepB5Teardown].FailAction := E_TestFailAction.FAIL_CONTINUE;

    // TC-B6 : Homme-Mort & Recul
    StepTable[StepB6Setup].Name := 'Tcb6 Setup saine';
    StepTable[StepB6Setup].CaseId := 6;
    StepTable[StepB6Setup].StimulusId := 1;
    StepTable[StepB6Setup].CheckIdx[1] := 1;
    StepTable[StepB6Setup].TimeoutPT := T#12s;
    StepTable[StepB6Setup].NextOnPass := StepB6StartMove;
    StepTable[StepB6Setup].NextOnFail := StepB6Teardown;
    StepTable[StepB6Setup].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB6StartMove].Name := 'Tcb6 Lancement Mouvement';
    StepTable[StepB6StartMove].CaseId := 6;
    StepTable[StepB6StartMove].StimulusId := 2;
    StepTable[StepB6StartMove].CheckIdx[1] := 2;
    StepTable[StepB6StartMove].TimeoutPT := T#5s;
    StepTable[StepB6StartMove].NextOnPass := StepB6ReleaseJoy;
    StepTable[StepB6StartMove].NextOnFail := StepB6Teardown;
    StepTable[StepB6StartMove].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB6ReleaseJoy].Name := 'Tcb6 Relâchement Homme-Mort';
    StepTable[StepB6ReleaseJoy].CaseId := 6;
    StepTable[StepB6ReleaseJoy].StimulusId := 10;
    StepTable[StepB6ReleaseJoy].CheckIdx[1] := 5;
    StepTable[StepB6ReleaseJoy].TimeoutPT := T#1s;
    StepTable[StepB6ReleaseJoy].NextOnPass := StepB6ReverseJoy;
    StepTable[StepB6ReleaseJoy].NextOnFail := StepB6Teardown;
    StepTable[StepB6ReleaseJoy].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB6ReverseJoy].Name := 'Tcb6 Commande Opposée';
    StepTable[StepB6ReverseJoy].CaseId := 6;
    StepTable[StepB6ReverseJoy].StimulusId := 11;
    StepTable[StepB6ReverseJoy].CheckIdx[1] := 22;
    StepTable[StepB6ReverseJoy].CheckIdx[2] := 23;
    StepTable[StepB6ReverseJoy].TimeoutPT := T#5s;
    StepTable[StepB6ReverseJoy].NextOnPass := StepB6Teardown;
    StepTable[StepB6ReverseJoy].NextOnFail := StepB6Teardown;
    StepTable[StepB6ReverseJoy].FailAction := E_TestFailAction.FAIL_CONTINUE;

    StepTable[StepB6Teardown].Name := 'Tcb6 Teardown';
    StepTable[StepB6Teardown].CaseId := 6;
    StepTable[StepB6Teardown].StimulusId := 1;
    StepTable[StepB6Teardown].CheckIdx[1] := 1;
    StepTable[StepB6Teardown].TimeoutPT := T#12s;
    StepTable[StepB6Teardown].NextOnPass := 0;
    StepTable[StepB6Teardown].NextOnFail := 0;
    StepTable[StepB6Teardown].FailAction := E_TestFailAction.FAIL_CONTINUE;

    TableReady := TRUE;
END_IF;

// 3. 📥 ACQUIRE
ProbeBool[SigHealthyIdle] := NOT PRG_06_WinchControl.instBucket.Error
                             AND NOT _BucketState.StateIncoherent;

ProbeBool[SigBucketBusy]   := PRG_06_WinchControl.instBucket.Busy;
ProbeBool[SigBucketDone]    := PRG_06_WinchControl.instBucket.Done;
ProbeBool[SigBucketError]   := PRG_06_WinchControl.instBucket.Error;
ProbeBool[SigM1SlipDetected] := PRG_06_WinchControl.instBucket.M1SlipDetected;
ProbeBool[SigM1SafeStop]    := PRG_03_Safety.instSafetyWinchM1.SafeStop;
ProbeBool[SigM1PowerCutOff] := PRG_03_Safety.instSafetyWinchM1.PowerCutOff;
ProbeBool[SigBucketIsOpen]  := _BucketState.IsOpen;
ProbeBool[SigBucketIsClosed] := _BucketState.IsClosed;
ProbeBool[SigM2StartStop]   := PRG_06_WinchControl.instBucket.M2_StartStop;
ProbeBool[SigM2ForceSlowSpeed] := PRG_06_WinchControl.instBucket.M2_ForceSlowSpeed;

ProbeDint[SigBucketErrorId] := WORD_TO_DINT(PRG_06_WinchControl.instBucket.ErrorId);
ProbeDint[SigM2Direction]   := INT_TO_DINT(PRG_06_WinchControl.instBucket.M2_Direction);
ProbeDint[SigSafetyM1ErrorId] := WORD_TO_DINT(PRG_03_Safety.instSafetyWinchM1.ErrorId);

ProbeReal[SigActiveOffsetM]   := PRG_06_WinchControl.instBucket.ActiveOffsetM;
ProbeReal[SigRemainingTravelM] := PRG_06_WinchControl.instBucket.RemainingTravelM;
ProbeReal[SigM2CablePos]      := PRG_02_Encoders.instEncoderScaleM2.CablePosM;
ProbeReal[SigM2TopLimit]       := PRG_06_WinchControl.instWinchM2.TopLimitM;

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
    0: // 🔓 Neutre
        CmdOpen_IHM := FALSE;
        CmdClose_IHM := FALSE;
        JoystickY_StartStop := FALSE;
        JoystickY_Direction := 0;
        ConfirmOpenPosition := FALSE;
        HomedM1 := TRUE;
        InhibitM1 := FALSE;
        GVL_PLC_Tests.OverrideM1Slip := FALSE;
        GVL_PLC_Tests.OverrideM1SlipCritical := FALSE;
        GVL_PLC_Tests.OverrideM2Stuck := FALSE;
        GVL_PLC_Tests.OverrideM2BootDrift := FALSE;

    1: // Reset & Saine
        CmdOpen_IHM := FALSE;
        CmdClose_IHM := FALSE;
        JoystickY_StartStop := FALSE;
        ConfirmOpenPosition := TRUE; // Forcer état sain
        HomedM1 := TRUE;
        InhibitM1 := FALSE;
        GVL_PLC_Tests.OverrideM1Slip := FALSE;
        GVL_PLC_Tests.OverrideM1SlipCritical := FALSE;
        GVL_PLC_Tests.OverrideM2Stuck := FALSE;
        GVL_PLC_Tests.OverrideM2BootDrift := FALSE;

    2: // Fermeture Nominale
        CmdClose_IHM := TRUE;
        JoystickY_StartStop := TRUE;
        JoystickY_Direction := 1;
        ConfirmOpenPosition := FALSE;
        HomedM1 := TRUE;

    3: // Glissement Modéré M1
        CmdClose_IHM := TRUE;
        JoystickY_StartStop := TRUE;
        JoystickY_Direction := 1;
        GVL_PLC_Tests.OverrideM1Slip := TRUE;

    4: // Glissement Critique M1
        CmdClose_IHM := TRUE;
        JoystickY_StartStop := TRUE;
        JoystickY_Direction := 1;
        GVL_PLC_Tests.OverrideM1SlipCritical := TRUE;

    5: // Fermeture nominale (TC-B3)
        CmdClose_IHM := TRUE;
        JoystickY_StartStop := TRUE;
        JoystickY_Direction := 1;
        ConfirmOpenPosition := FALSE;

    6: // Boot Incohérent
        GVL_PLC_Tests.OverrideM2BootDrift := TRUE;
        CmdOpen_IHM := FALSE;
        CmdClose_IHM := FALSE;
        JoystickY_StartStop := FALSE;

    7: // Recalage manuel
        ConfirmOpenPosition := TRUE;
        CmdOpen_IHM := FALSE;
        CmdClose_IHM := FALSE;
        JoystickY_StartStop := FALSE;

    8: // Perte Homing
        HomedM1 := FALSE;
        CmdClose_IHM := FALSE;
        CmdOpen_IHM := FALSE;

    9: // Inhibition M1 + Mouvement
        InhibitM1 := TRUE;
        CmdClose_IHM := TRUE;
        JoystickY_StartStop := TRUE;
        JoystickY_Direction := 1;
        GVL_PLC_Tests.OverrideM1Slip := TRUE;

    10: // Relâchement Homme-Mort
        CmdClose_IHM := TRUE;
        JoystickY_StartStop := FALSE;
        JoystickY_Direction := 1;

    11: // Commande opposée
        CmdClose_IHM := TRUE;
        JoystickY_StartStop := TRUE;
        JoystickY_Direction := -1;
END_CASE;

// Liaison IHM / Métier
IF Busy THEN
    PRG_06_WinchControl.instBucket.CmdOpen_IHM := CmdOpen_IHM;
    PRG_06_WinchControl.instBucket.CmdClose_IHM := CmdClose_IHM;
    PRG_06_WinchControl.instBucket.JoystickY_StartStop := JoystickY_StartStop;
    PRG_06_WinchControl.instBucket.JoystickY_Direction := JoystickY_Direction;
    PRG_06_WinchControl.instBucket.ConfirmOpenPosition := ConfirmOpenPosition;
    PRG_06_WinchControl.instBucket.HomedM1 := HomedM1;
    PRG_06_WinchControl.instBucket.InhibitM1 := InhibitM1;
END_IF;
