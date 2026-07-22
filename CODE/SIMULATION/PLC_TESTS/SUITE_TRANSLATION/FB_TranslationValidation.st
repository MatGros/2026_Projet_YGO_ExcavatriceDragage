// ═══════════════════════════════════════════════════════════════
// 🧪 FB_TranslationValidation — Suite de test Translation M3
// ───────────────────────────────────────────────────────────────
// 📄 Doc métier : DOC/AF_Partie-11_Fonction_Translation_v1.9.md
// 🎯 Valide les surveillances de sécurité de FB_Safety_Translation :
//    TC-T1 Fin de course extrême, TC-T2 Méca B (incohérence à l'arrêt),
//    TC-T3 Méca A (mouvement non commandé), TC-T4 les 6 mots valides +
//    limites extrêmes, TC-T5 incohérence mot capteurs (SafeStop+PowerCutOff),
//    TC-T6 ralentissement PV (instance FB_Translation isolée).
// 🆕 Tranche verticale NEUVE (2026-07-22, audit DOC/AUDITS/TEST_FRAMEWORK_AUDIT_v1.0.md) :
//    moteur dédié, composé d'objets à responsabilité unique sous CORE/ —
//    N'INSTANCIE NI FB_TestSequencer NI les anciennes BRICKS
//    (FB_TestCheck/FB_Timeout/FB_TestStimulus/...). Les autres suites
//    (Safety/Bucket/Encoder/Modes/Heartbeat) restent inchangées sur
//    l'ancien moteur générique.
//      - FB_TranslationTestPlan          : tables déclaratives + validation
//      - FB_TranslationStepExecutor      : exécution étape/check + cantonnement de cas
//      - FB_TranslationTestRuntime       : cycle de vie (Start -> Fixture -> Executor -> Finalize)
//      - FB_TranslationTestFixture       : précondition (gate Niveau 1/2, PRECONDITION_FAILED explicite)
//      - FB_TranslationTestCleanup       : neutralité (source de vérité unique)
//      - FB_TranslationReportFinalizer   : rapport existant (ST_TestSuiteReport) + résultat plat (ST_TranslationTestResult)
// 🔒 API publique : Start / Abort / CaseId (0=toutes les cases, 1..6=case
//    ciblée) — JAMAIS de FirstStepId exposé (audit v1.0 C2).
// 🔑 Les index de sondes (Sig*) sont possédés ICI (ce fichier), transmis en
//    VAR_INPUT à FB_TranslationTestPlan à chaque appel — aucun accès
//    croisé "instPlan.SigXxx" en retour.
// ⚠️ Hors périmètre (non testé ici, nécessiterait des overrides
//    supplémentaires sur les diagnostics bus) : bit0 (perte Joystick
//    CANopen), bit1 (perte com EtherCAT variateur), bit2 (rotation
//    de phases), bit3 (thermique frein commun).
// ═══════════════════════════════════════════════════════════════

FUNCTION_BLOCK PUBLIC FB_TranslationValidation
VAR_INPUT
    Start   : BOOL; // Commande de démarrage
    Abort   : BOOL; // Commande d'abandon
    CaseId  : INT;  // 0 = toutes les cases (1..6) ; 1..6 = case ciblée uniquement
END_VAR
VAR_OUTPUT
    Busy                : BOOL;
    Done                : BOOL;
    AnyFailed           : BOOL;
    SimGateOk           : BOOL;        // Indique si la simulation est autorisée (Niveau 1/2)
    ActiveStimulusId    : INT;
    StepElapsed         : TIME;
    Report              : ST_TestSuiteReport;      // 📊 Rapport existant — compat GVL_PLC_Tests/IHM/manager
    Result              : ST_TranslationTestResult; // 📋 Résultat plat clair — nouveau
    TerminalState       : E_TestTerminalState;
    ConfigError         : BOOL;
    ConfigErrorStepId   : INT;
    ConfigErrorCheckIdx : INT;
    ErrorCode           : INT;
    ErrorMessage        : STRING(160);
END_VAR
VAR CONSTANT
    // 🏷️ Index des sondes — source de vérité UNIQUE, transmis à instPlan
    // en VAR_INPUT (jamais lus en retour via une instance).
    SigHealthyIdle          : INT := 1;
    SigLimitSwitchError     : INT := 2;
    SigPowerCutOff          : INT := 3;
    SigErrorIdT1NoParasite  : INT := 4;
    SigMecaBError           : INT := 5;
    SigErrorIdT2NoParasite  : INT := 6;
    SigMecaAError           : INT := 7;
    SigErrorIdT3NoParasite  : INT := 8;
    SigDecoderIncoherent    : INT := 9;
    SigLimitFwd             : INT := 10;
    SigLimitRev             : INT := 11;
    SigSensorIncoherentErr  : INT := 12;
    SigErrorIdT5NoParasite  : INT := 13; // DINT
    SigSlowdownFreqHz       : INT := 14; // REAL
END_VAR
VAR
    // 🧩 Objets CORE — composition, responsabilité unique chacun
    instPlan    : FB_TranslationTestPlan;
    instRuntime : FB_TranslationTestRuntime;
    instCleanup : FB_TranslationTestCleanup;

    // 📋 Tables déclaratives — possédées ici, construites par instPlan
    StepTable  : ARRAY[1..GVL_PLC_Tests_Const.MaxSteps]      OF ST_TestStepConfig;
    CheckTable : ARRAY[1..GVL_PLC_Tests_Const.MaxChecks]     OF ST_TestCheckConfig;
    CaseTable  : ARRAY[1..GVL_PLC_Tests_Const.MaxTestCases]  OF ST_TestCaseConfig;

    // 📥 Banque de sondes
    ProbeBool : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeBool] OF BOOL;
    ProbeDint : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeDint] OF DINT;
    ProbeReal : ARRAY[1..GVL_PLC_Tests_Const.MaxProbeReal] OF REAL;

    // 🆕 TC-T6 — instance ISOLÉE de FB_Translation (pas l'instance machine réelle
    // instTranslationM3) pour tester le ralentissement PV en pilotant Direction/StartStop/SpeedRefPct
    // directement, sans dépendre de l'arbitrage Mode de PRG_07_TranslationControl.
    instTranslationUnderTest : FB_Translation;
    UnderTestDirection       : INT;
    UnderTestStartStop       : BOOL;
    UnderTestSlowdownSensor  : BOOL;
    ResetFaults              : BOOL;
    NeutralConfirmedPrevious : BOOL; // Retour cleanup du scan précédent vers le runtime
END_VAR
// === IMPLEMENTATION ===

// 1. 🛡️ GATE Niveau 1/2 — calculé en continu (lu par le manager Niveau 3, même hors Busy)
// Refuse si un des équipements M3 est déjà recâblé réel.
SimGateOk := NOT GVL_Simulation.SensorTranslationPositionIsReal
         AND NOT GVL_Simulation.SensorM3ContactorFeedbackIsReal
         AND NOT GVL_Simulation.BusVariateurM3IsReal;

// 2. 📋 PLAN — construction (une fois) + validation ; les index de sondes
//    sont transmis ICI, jamais relus depuis l'instance.
instPlan(
    SigHealthyIdle := SigHealthyIdle, SigLimitSwitchError := SigLimitSwitchError,
    SigPowerCutOff := SigPowerCutOff, SigErrorIdT1NoParasite := SigErrorIdT1NoParasite,
    SigMecaBError := SigMecaBError, SigErrorIdT2NoParasite := SigErrorIdT2NoParasite,
    SigMecaAError := SigMecaAError, SigErrorIdT3NoParasite := SigErrorIdT3NoParasite,
    SigDecoderIncoherent := SigDecoderIncoherent, SigLimitFwd := SigLimitFwd,
    SigLimitRev := SigLimitRev, SigSensorIncoherentErr := SigSensorIncoherentErr,
    SigErrorIdT5NoParasite := SigErrorIdT5NoParasite, SigSlowdownFreqHz := SigSlowdownFreqHz,
    StepTable := StepTable, CheckTable := CheckTable, CaseTable := CaseTable
);

// 3. 📥 ACQUIRE — sondes réelles + instance isolée TC-T6 (pilotée par le
//    stimulus décidé au scan précédent, cf. §5 STIMULI)
ProbeBool[SigHealthyIdle]      := NOT PRG_03_Safety.instSafetyTranslationM3.Error;
ProbeBool[SigLimitSwitchError] := PRG_03_Safety.instSafetyTranslationM3.ErrorLimitSwitch;
ProbeBool[SigPowerCutOff]      := PRG_03_Safety.instSafetyTranslationM3.PowerCutOff;
ProbeDint[SigErrorIdT1NoParasite] := WORD_TO_DINT(PRG_03_Safety.instSafetyTranslationM3.ErrorId);
ProbeBool[SigMecaBError]       := PRG_03_Safety.instSafetyTranslationM3.ErrorMecaB;
ProbeDint[SigErrorIdT2NoParasite] := WORD_TO_DINT(PRG_03_Safety.instSafetyTranslationM3.ErrorId);
ProbeBool[SigMecaAError]       := PRG_03_Safety.instSafetyTranslationM3.ErrorMecaA;
ProbeDint[SigErrorIdT3NoParasite] := WORD_TO_DINT(PRG_03_Safety.instSafetyTranslationM3.ErrorId);
ProbeBool[SigDecoderIncoherent]   := PRG_00_Inputs.instPositionDecoder.Incoherent;
ProbeBool[SigLimitFwd]            := PRG_00_Inputs.instPositionDecoder.LimitSwitchFwd;
ProbeBool[SigLimitRev]            := PRG_00_Inputs.instPositionDecoder.LimitSwitchRev;
ProbeBool[SigSensorIncoherentErr] := PRG_03_Safety.instSafetyTranslationM3.ErrorSensorIncoherent;
ProbeDint[SigErrorIdT5NoParasite] := WORD_TO_DINT(PRG_03_Safety.instSafetyTranslationM3.ErrorId);

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

// 4. ♻️ RUNTIME — cycle de vie complet (Fixture -> Executor -> Finalize)
instRuntime(
    Start := Start, Abort := Abort, CaseId := CaseId,
    PlanConfigError := instPlan.ConfigError,
    PlanConfigErrorStepId := instPlan.ConfigErrorStepId,
    PlanConfigErrorCheckIdx := instPlan.ConfigErrorCheckIdx,
    PlanConfigErrorMessage := instPlan.ConfigErrorMessage,
    SimulationModeActive := GVL_Simulation.SimulationModeActive,
    SimGateOk := SimGateOk,
    NeutralConfirmed := NeutralConfirmedPrevious,
    StepTable := StepTable, CheckTable := CheckTable, CaseTable := CaseTable,
    ProbeBool := ProbeBool, ProbeDint := ProbeDint, ProbeReal := ProbeReal,
    Report := Report, Result := Result,
    Busy => Busy, Done => Done, AnyFailed => AnyFailed,
    ActiveStimulusId => ActiveStimulusId, StepElapsed => StepElapsed,
    TerminalState => TerminalState, ConfigError => ConfigError,
    ConfigErrorStepId => ConfigErrorStepId, ConfigErrorCheckIdx => ConfigErrorCheckIdx,
    ErrorCode => ErrorCode, ErrorMessage => ErrorMessage
);

// 5. ⚡ STIMULI — vecteur complet : neutre d'abord, surcharge ensuite.
//    Aucun champ ne dépend de la branche ou du scan précédent.
GVL_PLC_Tests.OverrideM3AtTremie := FALSE;
GVL_PLC_Tests.OverrideM3BrakeStuckOpen := FALSE;
GVL_PLC_Tests.OverrideM3PhantomFreq := FALSE;
GVL_PLC_Tests.OverrideM3SensorsWordActive := FALSE;
GVL_PLC_Tests.OverrideM3SensorsWord := 0;
UnderTestDirection := 0;
UnderTestStartStop := FALSE;
UnderTestSlowdownSensor := FALSE;
ResetFaults := FALSE;

IF NOT instRuntime.CleanupRequest THEN
    CASE ActiveStimulusId OF
        1: ResetFaults := TRUE; // Setup/teardown : reset sur front externe conditionné
        2: GVL_PLC_Tests.OverrideM3AtTremie := TRUE;
        3: GVL_PLC_Tests.OverrideM3BrakeStuckOpen := TRUE;
        4: GVL_PLC_Tests.OverrideM3PhantomFreq := TRUE;
        5: GVL_PLC_Tests.OverrideM3SensorsWordActive := TRUE; GVL_PLC_Tests.OverrideM3SensorsWord := 2#11111;
        6: GVL_PLC_Tests.OverrideM3SensorsWordActive := TRUE; GVL_PLC_Tests.OverrideM3SensorsWord := 2#01111;
        7: GVL_PLC_Tests.OverrideM3SensorsWordActive := TRUE; GVL_PLC_Tests.OverrideM3SensorsWord := 2#00111;
        8: GVL_PLC_Tests.OverrideM3SensorsWordActive := TRUE; GVL_PLC_Tests.OverrideM3SensorsWord := 2#00011;
        9: GVL_PLC_Tests.OverrideM3SensorsWordActive := TRUE; GVL_PLC_Tests.OverrideM3SensorsWord := 2#00001;
        10: GVL_PLC_Tests.OverrideM3SensorsWordActive := TRUE; GVL_PLC_Tests.OverrideM3SensorsWord := 2#00000;
        11: GVL_PLC_Tests.OverrideM3SensorsWordActive := TRUE; GVL_PLC_Tests.OverrideM3SensorsWord := 2#10101;
        12: UnderTestDirection := 1; UnderTestStartStop := TRUE;
        13: UnderTestDirection := 1; UnderTestStartStop := TRUE; UnderTestSlowdownSensor := TRUE;
    END_CASE;
END_IF;

// 🧹 Confirmation calculée APRÈS écriture du vecteur neutre ; consommée
// par le runtime au scan suivant pour garantir la propagation cyclique.
instCleanup(Apply := instRuntime.CleanupRequest);
NeutralConfirmedPrevious := instCleanup.NeutralConfirmed
    AND NOT GVL_PLC_Tests.OverrideM3AtTremie
    AND NOT GVL_PLC_Tests.OverrideM3BrakeStuckOpen
    AND NOT GVL_PLC_Tests.OverrideM3PhantomFreq
    AND NOT GVL_PLC_Tests.OverrideM3SensorsWordActive
    AND (GVL_PLC_Tests.OverrideM3SensorsWord = 0)
    AND (UnderTestDirection = 0)
    AND NOT UnderTestStartStop
    AND NOT UnderTestSlowdownSensor
    AND NOT ResetFaults;

// Recopie IHM/métier — reset partagé avec la suite Safety (même domaine
// "sécurité/métier", voir PRG_09_Supervision.FaultMachineReset_IHM), sans
// conflit car les suites s'exécutent toujours de façon mutuellement exclusive
// (FB_PLC_Tests_Management n'active qu'une suite à la fois).
IF Busy THEN
    GVL_IHM.Modes.BtnFaultReset := ResetFaults;
END_IF;
