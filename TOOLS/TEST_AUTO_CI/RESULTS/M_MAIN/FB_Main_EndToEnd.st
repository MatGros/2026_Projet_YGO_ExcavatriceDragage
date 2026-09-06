(* =======================================================================
   🏰 FB_Main_EndToEnd : Mégabloc Machine d'Intégration Globale (v2 — T181-00)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Instancie et chaîne en boucle fermée les 6 programmes de l'automate :
             PRG_02 (Acquisition) -> PRG_03 (Modes & Cycle) -> PRG_04 (Treuils/Benne)
             -> PRG_05 (Translation) -> PRG_06 (Outputs) -> PRG_07 (Supervision).
   🔄 Intègre également le rebouclage physique vers PRG_02 (SimBench).
   🆕 v2 (T181-00) :
      - Entrées opérateur étendues : boutons IHM M1/M2/Both, commande benne,
        confirmations benne, contexte plongée Kobold, toggles IHM (AC3).
      - Bus séquenceur injectables : SeqReqWinchM1/M2, SeqReqBucket, intention
        couplée, état séquence (producteur réel PRG_03 = raccordement T181-01).
      - MODÈLE PHYSIQUE MINIMAL paire M1/M2 (AC4) : CablePosM += v_palier(StepNumber,
        Direction) * dt ; v_palier = ModelStepSpeedMps[palier] (table fournie par la
        suite de test) ; aucune dynamique moteur ni rampe hydraulique (FB_Winch
        fournit les temporisations réelles). Le modèle écrit les codeurs (CODx_PosValue),
        le retour frein (BrakeFeedback := RelayFwd OR RelayRev) et le retour contacteurs
        (FwdRevSpeedFeedbackOff retardé de ContactorFeedbackTimeout).
      - Diag exposés : positions/paliers modèle, SyncDeviationM_Model,
        FinalInterlockGoverned M1/M2 (demande non traversée par la barrière PRG_06).
      - InjectRateBypassFbWinch : injection de cadence HORS instance FB_Winch
        (vecteur HARN-51 — autorité de la barrière PRG_06).
   ⚠️ Doctrine lag 1 scan (tolérée, homogène PRG_04/production) : les feedbacks
      physiques consommés au cycle N proviennent des sorties du cycle N-1.
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Main_EndToEnd
VAR_INPUT
    // === 🕹️ Entrées Physiques Opérateur & Machine ===
    JoyRawX                 : INT := 0;
    JoyRawY                 : INT := 0;
    JoyDeadmanBtn           : BOOL := FALSE;
    BtnResetMachine         : BOOL := FALSE;

    // Commandes Modes IHM
    CmdMode                 : E_Mode := E_Mode.MAINT_N1;
    CmdWinchSelect          : INT := 0; // 0=Couplé, 1=M1, 2=M2

    // Conditions de Sécurité Châssis / Puissance
    EmergencyChainClosed    : BOOL := TRUE;
    PowerContactorEngaged   : BOOL := TRUE;

    // === 🎛️ Boutons IHM Treuils M1/M2 (AC3 — [MIROIR] GVL_IHM via harnais PRG_04) ===
    BtnWinchM1Up            : BOOL := FALSE;
    BtnWinchM1Down          : BOOL := FALSE;
    BtnWinchM2Up            : BOOL := FALSE;
    BtnWinchM2Down          : BOOL := FALSE;
    BtnWinchBothUp          : BOOL := FALSE;
    BtnWinchBothDown        : BOOL := FALSE;
    TglJoystickMaster       : BOOL := FALSE;

    // === 🪣 Commande Benne (AC3) ===
    BucketCmdOpen           : BOOL := FALSE;
    BucketCmdClose          : BOOL := FALSE;
    BucketConfirmOpenPos    : BOOL := FALSE;
    BucketConfirmClosePos   : BOOL := FALSE;
    TglManualBucketLimits   : BOOL := FALSE;
    BucketSeedOpen          : BOOL := TRUE;   // état benne au boot (miroir NVRAM)

    // === 🌊 Contexte Plongée Kobold (AC3) ===
    KoboldImmersed          : BOOL := FALSE;  // capteur toucher fond M1_M2_KoboldBottomTouch_DI
    TglEnableKoboldAutoStopDescent : BOOL := FALSE;
    ImmersionLowerM         : REAL := 0.0;
    ImmersionUpperM         : REAL := 0.0;
    ExtractionControlDistanceM : REAL := 0.0;

    // === 🧪 Bus Séquenceur Injectables (producteur réel = PRG_03, raccordement T181-01) ===
    SeqReqWinchM1           : ST_ProgramWinchRequest;
    SeqReqWinchM2           : ST_ProgramWinchRequest;
    SeqReqBucket            : ST_ProgramBucketRequest;
    CoupledIntentActive     : BOOL := FALSE;
    CoupledIntentDirection  : INT := 0;
    SeqBottomTouchConfirmed : BOOL := FALSE;

    // === ⚙️ Configuration Treuils/Sync/Benne (0/0.0 = à fournir par la suite de test) ===
    SpeedTable              : ST_SpeedStepTable;
    CfgMaxStepAscent        : INT := 0;
    MaxStepDescent          : INT := 0;
    CfgAscentLimitM         : REAL := 0.0;    // cote capteur haut / limite logicielle haute
    CfgDescentLimitM1       : REAL := 0.0;
    CfgDescentLimitM2       : REAL := 0.0;
    SlowdownDistanceM       : REAL := 0.0;
    SlowdownMaxStep         : INT := 0;
    SyncToleranceM          : REAL := 0.0;
    SyncCriticalToleranceM  : REAL := 0.0;
    SyncSoftStopEnable      : BOOL := TRUE;
    LimitLegalEnabled       : BOOL := FALSE;
    LimitLegalDepthMinAllowedM : REAL := 0.0;
    LimitLegalReached       : BOOL := FALSE;
    BucketOffsetOpenM       : REAL := 0.0;
    BucketOffsetCloseM      : REAL := 0.0;
    BucketCoherenceLimitM   : REAL := 0.0;
    BucketOpenAnticipationM : REAL := 0.0;
    BucketCloseAnticipationM : REAL := 0.0;
    BucketCfgTimeoutDuration : TIME := T#60s;
    TglEnableCoupledBucketSequencing : BOOL := FALSE;
    HeartbeatIhmOk          : BOOL := TRUE;
    CanBusOperational       : BOOL := TRUE;    // Réseau joystick CAN simulé sain par défaut
    JoyOperational          : BOOL := TRUE;    // Joystick simulé opérationnel par défaut

    // === 🧩 Bypass maintenance (miroir GVL_IHM.Bypass) ===
    BypassM1                : ST_BypassWinch;
    BypassM2                : ST_BypassWinch;
    BypassCommun            : ST_BypassCommun;
    BypassSync              : ST_BypassSync;

    // === 🧪 Modèle physique minimal paire (AC4) ===
    ModelStepSpeedMps       : ARRAY[0..5] OF REAL; // vitesse m/s par palier (table de la suite)
    ModelSeedPosM1          : REAL := 2.0;         // position de départ M1 (cohérente COD défaut)
    ModelSeedPosM2          : REAL := 2.0;
    ModelMachineHomed : BOOL := TRUE;     // qualification de référence du modèle de banc
    ContactorFeedbackTimeout : TIME := T#500ms;

    // === 🧪 Injections modèle (doctrine SPEC §2.1 : capteurs pilotés depuis la suite) ===
    ModelM2SpeedFactor      : REAL := 1.0;   // biaise la vitesse-palier de M2 (SPEC §3.6 HARN-60/61)
    ModelReloadPositions    : BOOL := FALSE; // front entretenu : re-seed positions depuis ModelSeedPosMx
    ModelBrakeFeedbackFaultM1 : BOOL := FALSE; // TRUE = retour frein M1 jamais ouvert (HARN-72)
    ModelBrakeFeedbackFaultM2 : BOOL := FALSE;
    ModelContactorsReleaseFaultM1 : BOOL := FALSE; // TRUE = contacteurs M1 "retombés" en marche (HARN-80 CAS-001)
    ModelContactorsReleaseFaultM2 : BOOL := FALSE;

    // === 🧪 Injection cadence hors instance FB_Winch (HARN-51) ===
    InjectRateBypassFbWinch : BOOL := FALSE;       // force une demande RelayFwd entre PRG_04 et PRG_06
    InjectRateStep          : INT := 1;            // palier forcé par l'injection (valeur de test)
END_VAR

VAR_OUTPUT
    // === 🚌 Bus Publics Inter-PRG Produits ===
    BusAcq                  : ST_AcquisitionInterPrg;
    BusModes                : ST_Modes_Autorisations;
    BusWinch                : ST_WinchInterPrg;
    BusTranslation          : ST_TranslationInterPrg;
    BusOutputs              : ST_OutputsInterPrg;
    BusBanner               : ST_HmiBanner;

    // === 📊 Diag modèle physique & barrière (AC3/AC4) ===
    M1_CablePosM_Model      : REAL;
    M2_CablePosM_Model      : REAL;
    M1_StepNumber           : INT;
    M2_StepNumber           : INT;
    SyncDeviationM_Model    : REAL;
    FinalInterlockGovernedM1 : BOOL;
    FinalInterlockGovernedM2 : BOOL;

    // === 📤 Faits publics Kobold (miroir GVL_IHM.Commun) ===
    KoboldImmersionConfirmed : BOOL;
    KoboldBottomTouchLatched : BOOL;

    // === 🔄 Observation Séquenceur Cycle (miroir FB_TestHarness_PRG_03) ===
    // Sorties de DIAG uniquement (aucun impact sur la chaîne) : exposent l'état du
    // séquenceur FB_CycleSemiAuto pour les scénarios e2e homme-mort / timeout (T169-A S3/S4).
    CycleStep               : E_AutoCycleStep;
    CycleBusy               : BOOL;
    CycleError              : BOOL;
    CycleStateStr           : STRING(80);
END_VAR

VAR
    // Harnais des 6 sous-programmes
    prg02                   : FB_TestHarness_PRG_02;
    prg03                   : FB_TestHarness_PRG_03;
    prg04                   : FB_TestHarness_PRG_04;
    prg05                   : FB_TestHarness_PRG_05;
    prg06                   : FB_TestHarness_PRG_06;
    prg07                   : FB_TestHarness_PRG_07;

    // === Modèle physique paire (internes) ===
    firstScan               : BOOL := TRUE;
    m1PosModel              : REAL;
    m2PosModel              : REAL;
    v1Model                 : REAL;
    v2Model                 : REAL;
    v1New                   : REAL;
    v2New                   : REAL;
    iStepM1                 : INT;
    iStepM2                 : INT;
    codRawM1                : UDINT;
    codRawM2                : UDINT;
    m1ContactorsEngagedLatch : BOOL := FALSE;    // 1ère commande contacteurs M1 mémorisée
    m2ContactorsEngagedLatch : BOOL := FALSE;
    m1ContactorsReleasedModel : BOOL := TRUE;    // feedback contacteurs M1 (retardé)
    m2ContactorsReleasedModel : BOOL := TRUE;
    m1BrakeFeedbackModel    : BOOL := FALSE;     // retour frein M1 (RelayFwd OR RelayRev)
    m2BrakeFeedbackModel    : BOOL := FALSE;
    tonContactorsDroppedM1  : TON;               // retombée contacteurs M1 retardée
    tonContactorsDroppedM2  : TON;
    m1AnyRequested          : BOOL;
    m2AnyRequested          : BOOL;

    // Bus séquenceur assemblés (miroir PRG_03.Data.ReqProgram / .SequenceState)
    reqProgramLocal         : ST_ProgramRequest;
    seqStateLocal           : ST_SequencePublicState;
    bucketPersistLocal      : ST_fbBucket_Config;
    mechStateLocal          : ST_fbBucket_State;
END_VAR

VAR CONSTANT
    // Fixtures codeur du harnais PRG_02 (valeurs de FIXTURE test, pas des config métier) :
    // FB_TestHarness_PRG_02 initialise calibMx.HomingRefRaw := 1000000, 8192 pts/révol, 2.0 m/révol.
    CST_FIXTURE_HOMING_REF_RAW : UDINT := 1000000;
    CST_FIXTURE_PTS_PER_REV    : REAL := 8192.0;
    CST_FIXTURE_M_PER_REV      : REAL := 2.0;
    CST_FIXTURE_CYCLE_S        : REAL := 0.010; // config.yaml cycle_time_ms = 10
END_VAR

{region "0. Modèle physique : état initial + seeds config (fixtures si non fournis)"}
IF firstScan THEN
    m1PosModel := ModelSeedPosM1;
    m2PosModel := ModelSeedPosM2;
    m1ContactorsEngagedLatch := FALSE;
    m2ContactorsEngagedLatch := FALSE;
    firstScan := FALSE;
END_IF;

// Seeds "si non fourni" : la suite test_winch_integ.st fournit TOUTES les configs
// explicitement ; ces valeurs de repli = défauts internes des FB réels (FB_Winch
// TopLimitM:=8.5 / BottomLimitM:=-20.0 / CfgSlowdownDistanceM:=1.0 / CfgSlowdownMaxStep:=1,
// FB_WinchSync CfgSyncToleranceM:=0.10 / CfgSyncCriticalToleranceM:=0.50) et table de
// seuils production (précédent §1 de l'ancien stub) — elles garantissent que les 2
// scénarios MAIN_Global existants (qui ne fixent aucune config) restent verts sans
// toucher au code produit. Aucune de ces valeurs n'est greppable MaxStep:=5 / TopLimit:=7.5.
IF SpeedTable.StepThreshold_Pct[1] <= 0.0 THEN
    SpeedTable.StepThreshold_Pct[1] := 10.0;
    SpeedTable.StepThreshold_Pct[2] := 30.0;
    SpeedTable.StepThreshold_Pct[3] := 50.0;
    SpeedTable.StepThreshold_Pct[4] := 70.0;
    SpeedTable.StepThreshold_Pct[5] := 90.0;
END_IF;
IF SpeedTable.P1R1 = FALSE AND SpeedTable.P2R1 = FALSE AND SpeedTable.P3R1 = FALSE
   AND SpeedTable.P4R1 = FALSE AND SpeedTable.P5R1 = FALSE THEN
    SpeedTable.P1R1 := TRUE;
    SpeedTable.P2R1 := TRUE;
    SpeedTable.P3R1 := TRUE;
    SpeedTable.P4R1 := TRUE;
    SpeedTable.P5R1 := TRUE;
END_IF;
IF CfgAscentLimitM <= 0.0 THEN
    CfgAscentLimitM := 8.5;
END_IF;
IF CfgDescentLimitM1 >= 0.0 THEN
    CfgDescentLimitM1 := -20.0;
END_IF;
IF CfgDescentLimitM2 >= 0.0 THEN
    CfgDescentLimitM2 := -20.0;
END_IF;
IF SlowdownDistanceM <= 0.0 THEN
    SlowdownDistanceM := 1.0;
END_IF;
IF SlowdownMaxStep <= 0 THEN
    SlowdownMaxStep := 1;
END_IF;
// Le dialecte STruCpp remet les VAR_INPUT omises a zero entre deux appels
// machine(). La table suivante est un PARAMETRAGE DE MODELE de banc (pas une
// constante metier PLC) : elle conserve une physique coherente dans les scans
// de convergence qui ne changent aucune vitesse. Les vecteurs gardent la
// possibilite de fournir explicitement leur propre table.
IF ModelStepSpeedMps[1] <= 0.0 THEN
    ModelStepSpeedMps[0] := 0.0;
    ModelStepSpeedMps[1] := 0.2;
    ModelStepSpeedMps[2] := 0.5;
    ModelStepSpeedMps[3] := 0.9;
    ModelStepSpeedMps[4] := 1.4;
    ModelStepSpeedMps[5] := 2.0;
END_IF;
IF SyncToleranceM <= 0.0 THEN
    SyncToleranceM := 0.10;
END_IF;
IF SyncCriticalToleranceM <= 0.0 THEN
    SyncCriticalToleranceM := 0.50;
END_IF;
IF BucketOffsetCloseM <= BucketOffsetOpenM THEN
    BucketOffsetOpenM := 0.0;
    BucketOffsetCloseM := 15.0;
    BucketCoherenceLimitM := 1.0;
    BucketOpenAnticipationM := 0.2;
    BucketCloseAnticipationM := 0.2;
END_IF;
IF ImmersionUpperM <= ImmersionLowerM THEN
    ImmersionLowerM := -4.0;
    ImmersionUpperM := -1.0;
END_IF;
IF ExtractionControlDistanceM <= 0.0 THEN
    ExtractionControlDistanceM := 0.5;
END_IF;
IF InjectRateStep <= 0 THEN
    InjectRateStep := 1;
END_IF;

// Câblage codeurs : position modèle -> valeur brute COD (mêmes fixtures que FB_TestHarness_PRG_02)
codRawM1 := CST_FIXTURE_HOMING_REF_RAW + REAL_TO_UDINT(m1PosModel * (CST_FIXTURE_PTS_PER_REV / CST_FIXTURE_M_PER_REV));
codRawM2 := CST_FIXTURE_HOMING_REF_RAW + REAL_TO_UDINT(m2PosModel * (CST_FIXTURE_PTS_PER_REV / CST_FIXTURE_M_PER_REV));

// Re-seed positions sur demande de la suite (pulse 1 cycle) — permet à chaque vecteur
// de repartir d'une cote connue (ex. HARN-12 zone de ralentissement haute).
IF ModelReloadPositions THEN
    m1PosModel := ModelSeedPosM1;
    m2PosModel := ModelSeedPosM2;
    m1ContactorsEngagedLatch := FALSE;
    m2ContactorsEngagedLatch := FALSE;
    v1Model := 0.0;
    v2Model := 0.0;
END_IF;
{endregion}

{region "Exécution séquentielle cyclique du Mégabloc Machine"}

// ── 1. PRG_02 : Acquisition des entrées et qualification joystick ──
prg02(
    JoyRawX                 := JoyRawX,
    JoyRawY                 := JoyRawY,
    JoyBtnRaw               := JoyDeadmanBtn,
    COD1_PosValue           := codRawM1,
    COD2_PosValue           := codRawM2,
    M1_ContactorsReleased   := m1ContactorsReleasedModel,
    M2_ContactorsReleased   := m2ContactorsReleasedModel,
    M1_BrakeCmd             := m1BrakeFeedbackModel,
    M2_BrakeCmd             := m2BrakeFeedbackModel,
    PowerContactorEngaged   := PowerContactorEngaged,
    EmergencyChainClosed    := EmergencyChainClosed,
    CanBusOperational       := CanBusOperational,
    JoyOperational          := JoyOperational
);
BusAcq := prg02.Data;

// ── 1bis. Modèle physique = source de vérité des capteurs treuils (override déterministe) ──
// Le harnais PRG_02 dérive les positions des valeurs brutes COD ; le modèle les écrase avec
// ses valeurs intégrées exactes et qualifie codeurs homés/opérationnels + vitesse signée.
BusAcq.EncoderM1.Measurement.CablePosM    := m1PosModel;
BusAcq.EncoderM1.Measurement.Speed_Mps    := ABS(v1Model);
BusAcq.EncoderM1.Measurement.SignedSpeed_Mps := v1Model;
BusAcq.EncoderM1.Measurement.SpeedValid   := TRUE;
BusAcq.EncoderM2.Measurement.CablePosM    := m2PosModel;
BusAcq.EncoderM2.Measurement.Speed_Mps    := ABS(v2Model);
BusAcq.EncoderM2.Measurement.SignedSpeed_Mps := v2Model;
BusAcq.EncoderM2.Measurement.SpeedValid   := TRUE;
BusAcq.EncoderM1.Homed          := TRUE;
BusAcq.EncoderM1.HomingSuspect  := FALSE;
BusAcq.EncoderM1.Measurement.EncoderAvailable := TRUE;
BusAcq.EncoderM1.Measurement.HomingLifecycle.Busy := FALSE;
BusAcq.EncoderM1.HomedAndReliable      := TRUE;
BusAcq.EncoderM2.Homed          := TRUE;
BusAcq.EncoderM2.HomingSuspect  := FALSE;
BusAcq.EncoderM2.Measurement.EncoderAvailable := TRUE;
BusAcq.EncoderM2.Measurement.HomingLifecycle.Busy := FALSE;
BusAcq.EncoderM2.HomedAndReliable      := TRUE;
BusAcq.Network.EncoderM1.Operational := TRUE;
BusAcq.Network.EncoderM2.Operational := TRUE;

// ── 2. PRG_03 : Arbitrage des Modes et Séquenceur de Cycle ──
prg03(
    SelMode                 := CmdMode,
    SelJoystickWinch        := CmdWinchSelect,
    MachineHomed   := ModelMachineHomed,
    PowerContactorEngaged   := PowerContactorEngaged,
    DeadmanArmed            := BusAcq.Joystick.DeadmanArmed,
    JoystickDeflected       := NOT BusAcq.Joystick.AtNeutralXY,
    BtnModeReset            := BtnResetMachine
);
BusModes := prg03.Auth;
CycleStep     := prg03.CycleStep;
CycleBusy     := prg03.CycleBusy;
CycleError    := prg03.CycleError;
CycleStateStr := prg03.CycleStateStr;

// ── 3. PRG_04 (MIROIR T181-00) : Contrôle Treuils M1/M2 et Benne ──
reqProgramLocal.ReqWinchM1 := SeqReqWinchM1;
reqProgramLocal.ReqWinchM2 := SeqReqWinchM2;
reqProgramLocal.ReqBucket := SeqReqBucket;
seqStateLocal.BottomTouchConfirmed := SeqBottomTouchConfirmed;
bucketPersistLocal.OffsetOpenM := BucketOffsetOpenM;
bucketPersistLocal.OffsetCloseM := BucketOffsetCloseM;
bucketPersistLocal.CoherenceLimitM := BucketCoherenceLimitM;
bucketPersistLocal.OpenAnticipationM := BucketOpenAnticipationM;
bucketPersistLocal.CloseAnticipationM := BucketCloseAnticipationM;

prg04(
    BucketMech              := mechStateLocal,
    AcqData                 := BusAcq,
    ModesAuth               := BusModes,
    BtnWinchM1Up            := BtnWinchM1Up,
    BtnWinchM1Down          := BtnWinchM1Down,
    BtnWinchM2Up            := BtnWinchM2Up,
    BtnWinchM2Down          := BtnWinchM2Down,
    BtnWinchBothUp          := BtnWinchBothUp,
    BtnWinchBothDown        := BtnWinchBothDown,
    BucketBtnOpen           := BucketCmdOpen,
    BucketBtnClose          := BucketCmdClose,
    PowerContactorEngaged   := PowerContactorEngaged,
    M1_ContactorsReleased   := m1ContactorsReleasedModel,
    M2_ContactorsReleased   := m2ContactorsReleasedModel,
    M1_BrakeFeedbackOpen    := m1BrakeFeedbackModel,
    M2_BrakeFeedbackOpen    := m2BrakeFeedbackModel,
    FaultMachineResetIHM    := BtnResetMachine,
    CfgCableLimitAscentM    := CfgAscentLimitM,
    CfgCableLimitDescentM1  := CfgDescentLimitM1,
    CfgCableLimitDescentM2  := CfgDescentLimitM2,
    WinchSlowdownDistanceM  := SlowdownDistanceM,
    WinchSlowdownMaxStep    := SlowdownMaxStep,
    SpeedStepTable          := SpeedTable,
    BucketPersistConfig     := bucketPersistLocal
);
BusWinch := prg04.Data;
KoboldImmersionConfirmed := FALSE;
KoboldBottomTouchLatched := FALSE;

// ── 4. PRG_05 : Contrôle Translation M3 ──
prg05(
    AcqData                 := BusAcq,
    ModesAuth               := BusModes,
    WinchM1CablePosM        := m1PosModel,
    WinchM2CablePosM        := m2PosModel,
    PowerContactorEngaged   := PowerContactorEngaged,
    EmergencyChainClosed    := EmergencyChainClosed,
    BrakeFeedbackOpen       := FALSE,
    DriveOnline             := TRUE,
    DriveOperational        := TRUE,
    BtnReset                := BtnResetMachine,
    BtnTranslationFwd       := FALSE,
    BtnTranslationRev       := FALSE
);
BusTranslation := prg05.Data;

// ── 5. PRG_06 : Barrières Finales et Génération des Sorties ──
prg06(
    WinchData               := BusWinch,
    TranslationData         := BusTranslation,
    FaultReset              := BtnResetMachine
);
BusOutputs := prg06.Data;

// ── 5bis. Injection cadence HORS instance FB_Winch (HARN-51, cible T181-01) ──
// Simule une cadence forcée appliquée en aval de FB_Winch : la barrière PRG_06 doit couper.
IF InjectRateBypassFbWinch THEN
    BusWinch.WinchM1FinalInterlockRequest.RequestedRelayFwd := TRUE;
    BusWinch.WinchM1FinalInterlockRequest.RequestedStep := InjectRateStep;
    prg06(
        WinchData               := BusWinch,
        TranslationData         := BusTranslation,
        FaultReset              := BtnResetMachine
    );
    BusOutputs := prg06.Data;
END_IF;

// ── 5ter. Diag FinalInterlockGoverned : la barrière a-t-elle coupé une demande ? ──
m1AnyRequested := BusWinch.WinchM1FinalInterlockRequest.RequestedRelayFwd
                  OR BusWinch.WinchM1FinalInterlockRequest.RequestedRelayRev
                  OR BusWinch.WinchM1FinalInterlockRequest.RequestedContactor1
                  OR BusWinch.WinchM1FinalInterlockRequest.RequestedContactor2
                  OR BusWinch.WinchM1FinalInterlockRequest.RequestedContactor3
                  OR BusWinch.WinchM1FinalInterlockRequest.RequestedContactor4;
FinalInterlockGovernedM1 := m1AnyRequested AND (
       (BusWinch.WinchM1FinalInterlockRequest.RequestedRelayFwd  <> BusOutputs.M1RelayFwd)
    OR (BusWinch.WinchM1FinalInterlockRequest.RequestedRelayRev  <> BusOutputs.M1RelayRev)
    OR (BusWinch.WinchM1FinalInterlockRequest.RequestedContactor1 <> BusOutputs.M1SpeedContactor1)
    OR (BusWinch.WinchM1FinalInterlockRequest.RequestedContactor2 <> BusOutputs.M1SpeedContactor2)
    OR (BusWinch.WinchM1FinalInterlockRequest.RequestedContactor3 <> BusOutputs.M1SpeedContactor3)
    OR (BusWinch.WinchM1FinalInterlockRequest.RequestedContactor4 <> BusOutputs.M1SpeedContactor4));
m2AnyRequested := BusWinch.WinchM2FinalInterlockRequest.RequestedRelayFwd
                  OR BusWinch.WinchM2FinalInterlockRequest.RequestedRelayRev
                  OR BusWinch.WinchM2FinalInterlockRequest.RequestedContactor1
                  OR BusWinch.WinchM2FinalInterlockRequest.RequestedContactor2
                  OR BusWinch.WinchM2FinalInterlockRequest.RequestedContactor3
                  OR BusWinch.WinchM2FinalInterlockRequest.RequestedContactor4;
FinalInterlockGovernedM2 := m2AnyRequested AND (
       (BusWinch.WinchM2FinalInterlockRequest.RequestedRelayFwd  <> BusOutputs.M2RelayFwd)
    OR (BusWinch.WinchM2FinalInterlockRequest.RequestedRelayRev  <> BusOutputs.M2RelayRev)
    OR (BusWinch.WinchM2FinalInterlockRequest.RequestedContactor1 <> BusOutputs.M2SpeedContactor1)
    OR (BusWinch.WinchM2FinalInterlockRequest.RequestedContactor2 <> BusOutputs.M2SpeedContactor2)
    OR (BusWinch.WinchM2FinalInterlockRequest.RequestedContactor3 <> BusOutputs.M2SpeedContactor3)
    OR (BusWinch.WinchM2FinalInterlockRequest.RequestedContactor4 <> BusOutputs.M2SpeedContactor4));

// ── 6. PRG_07 : Supervision et Formatage du Bandeau IHM ──
prg07(
    AcqData                 := BusAcq,
    ModesAuth               := BusModes,
    WinchData               := BusWinch,
    TranslationData         := BusTranslation,
    EmergencyChainClosed    := EmergencyChainClosed,
    PowerContactorEngaged   := PowerContactorEngaged,
    PowerCutOffActive       := FALSE,
    BtnResetMachine         := BtnResetMachine
);
BusBanner := prg07.Banner;

// ── 7. Modèle physique minimal paire (AC4) — intègre les sorties de CE cycle ──
// v_palier(StepNumber, Direction) * dt ; aucune dynamique moteur (limite documentée au plan de tir).
iStepM1 := BusWinch.WinchM1State.StepNumber;
IF iStepM1 > 5 THEN iStepM1 := 5; END_IF;
IF iStepM1 < 0 THEN iStepM1 := 0; END_IF;
iStepM2 := BusWinch.WinchM2State.StepNumber;
IF iStepM2 > 5 THEN iStepM2 := 5; END_IF;
IF iStepM2 < 0 THEN iStepM2 := 0; END_IF;

IF BusOutputs.M1RelayFwd THEN
    v1New := ModelStepSpeedMps[iStepM1];
ELSIF BusOutputs.M1RelayRev THEN
    v1New := -ModelStepSpeedMps[iStepM1];
ELSE
    v1New := 0.0;
END_IF;
// Biais M2 (SPEC §3.6 : « modèle biaise M2 ») pour exercer la déviation sync paire.
IF BusOutputs.M2RelayFwd THEN
    v2New := ModelStepSpeedMps[iStepM2] * ModelM2SpeedFactor;
ELSIF BusOutputs.M2RelayRev THEN
    v2New := -ModelStepSpeedMps[iStepM2] * ModelM2SpeedFactor;
ELSE
    v2New := 0.0;
END_IF;

// Coast-down minimal (HARN-74 / T178) : tant que les contacteurs ne sont pas retombés
// (fenêtre ContactorFeedbackTimeout), le câble continue de dériver à la vitesse courante.
// Pas de dynamique moteur : v retombe à 0 dès la retombée confirmée des contacteurs.
IF (v1New = 0.0) AND (v1Model <> 0.0) AND (NOT m1ContactorsReleasedModel) THEN
    (* coast M1 : conserve la vitesse du scan précédent *)
ELSE
    v1Model := v1New;
END_IF;
IF (v2New = 0.0) AND (v2Model <> 0.0) AND (NOT m2ContactorsReleasedModel) THEN
    (* coast M2 : conserve la vitesse du scan précédent *)
ELSE
    v2Model := v2New;
END_IF;

m1PosModel := m1PosModel + v1Model * CST_FIXTURE_CYCLE_S;
m2PosModel := m2PosModel + v2Model * CST_FIXTURE_CYCLE_S;

// Retour frein : frein ouvert tant qu'un sens est commandé (AC4, direct).
// Injection HARN-72 : défaut retour frein (ne s'ouvre jamais).
m1BrakeFeedbackModel := (BusOutputs.M1RelayFwd OR BusOutputs.M1RelayRev) AND NOT ModelBrakeFeedbackFaultM1;
m2BrakeFeedbackModel := (BusOutputs.M2RelayFwd OR BusOutputs.M2RelayRev) AND NOT ModelBrakeFeedbackFaultM2;

// Retour contacteurs : retombés (FwdRevSpeedFeedbackOff=TRUE) retardé de
// ContactorFeedbackTimeout après la retombée des commandes (AC4).
// Injection HARN-80 (CAS-001) : contacteurs déclarés "retombés" ALORS qu'un sens est commandé.
IF BusOutputs.M1RelayFwd OR BusOutputs.M1RelayRev
   OR BusOutputs.M1SpeedContactor1 OR BusOutputs.M1SpeedContactor2
   OR BusOutputs.M1SpeedContactor3 OR BusOutputs.M1SpeedContactor4 THEN
    m1ContactorsEngagedLatch := TRUE;
END_IF;
tonContactorsDroppedM1(IN := NOT (BusOutputs.M1RelayFwd OR BusOutputs.M1RelayRev
                                 OR BusOutputs.M1SpeedContactor1 OR BusOutputs.M1SpeedContactor2
                                 OR BusOutputs.M1SpeedContactor3 OR BusOutputs.M1SpeedContactor4),
                       PT := ContactorFeedbackTimeout);
m1ContactorsReleasedModel := ((NOT m1ContactorsEngagedLatch) OR tonContactorsDroppedM1.Q) OR ModelContactorsReleaseFaultM1;

IF BusOutputs.M2RelayFwd OR BusOutputs.M2RelayRev
   OR BusOutputs.M2SpeedContactor1 OR BusOutputs.M2SpeedContactor2
   OR BusOutputs.M2SpeedContactor3 OR BusOutputs.M2SpeedContactor4 THEN
    m2ContactorsEngagedLatch := TRUE;
END_IF;
tonContactorsDroppedM2(IN := NOT (BusOutputs.M2RelayFwd OR BusOutputs.M2RelayRev
                                 OR BusOutputs.M2SpeedContactor1 OR BusOutputs.M2SpeedContactor2
                                 OR BusOutputs.M2SpeedContactor3 OR BusOutputs.M2SpeedContactor4),
                       PT := ContactorFeedbackTimeout);
m2ContactorsReleasedModel := ((NOT m2ContactorsEngagedLatch) OR tonContactorsDroppedM2.Q) OR ModelContactorsReleaseFaultM2;

// ── 8. Diag publics modèle ──
M1_CablePosM_Model   := m1PosModel;
M2_CablePosM_Model   := m2PosModel;
M1_StepNumber        := BusWinch.WinchM1State.StepNumber;
M2_StepNumber        := BusWinch.WinchM2State.StepNumber;
SyncDeviationM_Model := ABS(m1PosModel - m2PosModel);

{endregion}
END_FUNCTION_BLOCK
