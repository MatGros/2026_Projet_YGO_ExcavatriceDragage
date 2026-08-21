(* ═══════════════════════════════════════════════════════════════
   🖥️ PRG_07_Supervision — Échanges IHM, Diagnostics et Initialisation Boot
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 7.
   ✅ Regroupe tout le mapping bidirectionnel GVL_IHM / GVL_PERSISTENT.
   ✅ Expose FaultMachineReset_IHM pour tous les programmes du domaine sécurité/métier.
   📄 Docs : DOC/AF/AF_Partie-07_Interface_IHM_v2.1.md
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_07_Supervision

VAR_INPUT
    // === 📥 ENTRÉES PROGRAMME (AUCUNE - LECTURE DES DONNÉES VIA PRG_02 À 06) ===
END_VAR

VAR_OUTPUT
    // === 🚨 ACQUITTEMENT GLOBAL MACHINE ===
    FaultMachineReset_IHM : BOOL; // <-- [CMD] Impulsion d'acquittement defaut globale machine
END_VAR

VAR
    // === ⏱️ SOUS-INSTANCES FB ===
    instBlink1Hz            : BLINK;                          // * [INST] Clignoteur 1 Hz (heartbeat IHM)
    instAckConfigRestored   : R_TRIG;                         // * [INST] Front acquittement config restauree
    instCfgPersistBridgeSync           : FB_CfgPersistBridge_SyncCfg;            // * [INST] Pont persistance config synchro
    instCfgPersistBridgeCycle          : FB_CfgPersistBridge_CycleCfg;            // * [INST] Pont persistance config cycle
    instCfgPersistBridgeDredgingAssist : FB_CfgPersistBridge_DredgingAssistCfg;   // * [INST] Pont persistance config assist dragage
    instCfgPersistBridgeCommun         : FB_CfgPersistBridge_CommunCfg;           // * [INST] Pont persistance config commune
    instCfgPersistBridgeBucket         : FB_CfgPersistBridge_BucketCfg;           // * [INST] Pont persistance config benne
    instCfgPersistBridgeWinchM1        : FB_CfgPersistBridge_WinchCfg;            // * [INST] Pont persistance config treuil M1
    instCfgPersistBridgeWinchM2        : FB_CfgPersistBridge_WinchCfg;            // * [INST] Pont persistance config treuil M2
    instCfgPersistBridgeTranslation    : FB_CfgPersistBridge_TranslationCfg;      // * [INST] Pont persistance config translation
    instDiagCanOpen        : FB_Diag_CanOpen;                 // * [INST] Diagnostic reseau CANopen (joystick)
    instDiagEthercat       : FB_Diag_Ethercat;                // * [INST] Diagnostic reseau EtherCAT (codeurs/variateur)
    instDiagIhmHeartbeat   : FB_Diag_IhmHeartbeat;            // * [INST] Surveillance heartbeat IHM
    instPreflight          : FB_Acquisition_Preflight;        // * [INST] Preflight acquisition avant demarrage
    instHmiBannerFormatter : FB_Hmi_BannerFormatter;          // * [INST] Formatage bandeau IHM (alarmes/etats)
    instTroubleshootingView : FB_TroubleshootingView;         // * [INST] Vue troubleshooting (diagnostic IHM)

    // === 🚦 MÉMOIRE SYNC BYPASS BIDIRECTIONNEL (RETAIN ↔ IHM) ===
    PrevTranslationBypass   : BOOL; // . [LOC] Memoire bypass Translation (sync bidirectionnel)
    PrevM1Bypass            : BOOL; // . [LOC] Memoire bypass M1 (sync bidirectionnel)
    PrevM2Bypass            : BOOL; // . [LOC] Memoire bypass M2 (sync bidirectionnel)
    PrevSyncBypass          : BOOL; // . [LOC] Memoire bypass synchro (sync bidirectionnel)
    PrevCommunBypass        : BOOL; // . [LOC] Memoire bypass commun global (sync bidirectionnel)
    PrevLimitLegal          : BOOL; // . [LOC] Memoire bypass limite legale (sync bidirectionnel)
    PrevTopLimitSwitch      : BOOL; // . [LOC] Memoire bypass fin de course haut (sync bidirectionnel)
    PrevTopLimitSoftware    : BOOL; // . [LOC] Memoire bypass fin de course haut logiciel (sync bidirectionnel)
    PrevCableLimitSwitch    : BOOL; // . [LOC] Memoire bypass limite cable (sync bidirectionnel)
    PrevSlackCable          : BOOL; // . [LOC] Memoire bypass mou de cable (sync bidirectionnel)

    // === 🧪 DÉTECTEURS FRONT SIMULATION BYPASS (pilotage bypass IHM) ===
    SimBypassRise           : R_TRIG; // . [LOC] Front montant SimulationBypassActive
    SimBypassFall           : F_TRIG; // . [LOC] Front descendant SimulationBypassActive
END_VAR

{region "§1 Horloge et reset machine"}
// === 🧩 §1 HORLOGE & RESET MACHINE ===

instBlink1Hz(
    ENABLE   := TRUE,
    TIMEHIGH := _BlinkTimeOn,
    TIMELOW  := _BlinkTimeOff
);
GVL_Global.BlinkClock := instBlink1Hz.OUT;

instDiagCanOpen(
    Enable                 := TRUE,
    Reset                  := GVL_IHM.Modes.Cmd.BtnFaultReset,
    CANbusStateRaw         := PRG_02_Acquisition.HwReal.Operator.CanBusState,
    DeviceJoystickStateRaw := PRG_02_Acquisition.HwReal.Operator.JOY1_DeviceState,
    SimBypassActive        := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimOperatorActive,
    NetworkBypassActive    := GVL_IHM.Network.Bypass.Global
);

instDiagEthercat(
    Enable                   := TRUE,
    Reset                    := GVL_IHM.Modes.Cmd.BtnFaultReset,
    DeviceVariateurStateRaw  := PRG_02_Acquisition.HwReal.Translation.AC600_DeviceState,
    DeviceVariateurSimBypass := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimTranslationActive,
    DeviceEncoderM1StateRaw  := PRG_02_Acquisition.HwReal.Winch.COD1_DeviceState,
    DeviceEncoderM1SimBypass := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive,
    DeviceEncoderM2StateRaw  := PRG_02_Acquisition.HwReal.Winch.COD2_DeviceState,
    DeviceEncoderM2SimBypass := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive,
    NetworkBypassActive      := GVL_IHM.Network.Bypass.Global
);

// 💓 Front heartbeat simulé par le clignotant PLC 1 Hz quand le bypass
// IhmHeartbeat est actif (défaut sécurisé), pour ne jamais latcher un timeout
// artificiel. Repasser le bypass à FALSE côté IHM active la vraie surveillance.
instDiagIhmHeartbeat(
    Enable          := TRUE,
    TglHeartbeatIhm := SEL(GVL_IHM.Network.Bypass.IhmHeartbeat, GVL_IHM.Commun.TglHeartbeatIhm, GVL_Global.BlinkClock)
);

FaultMachineReset_IHM := GVL_IHM.Modes.Cmd.BtnFaultReset
                    OR GVL_IHM.M1TreuilRetenue.Cmd.BtnReset
                    OR GVL_IHM.M2TreuilBenne.Cmd.BtnReset
                    OR GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset;


{endregion}

{region "§2 Persistance et restauration configuration"}
// === 🌉 §2 PERSISTANCE & RESTAURATION CONFIG ===

instCfgPersistBridgeWinchM1(Hmi := GVL_IHM.M1TreuilRetenue.Cfg, Persist := _WinchM1CfgPersist);
IF instCfgPersistBridgeWinchM1.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeWinchM2(Hmi := GVL_IHM.M2TreuilBenne.Cfg, Persist := _WinchM2CfgPersist);
IF instCfgPersistBridgeWinchM2.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeSync(Hmi := GVL_IHM.M1M2Sync.Cfg, Persist := _SyncCfgPersist);
IF instCfgPersistBridgeSync.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeTranslation(Hmi := GVL_IHM.TranslationM3.Cfg, Persist := _TranslationCfgPersist);
IF instCfgPersistBridgeTranslation.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeBucket(Hmi := GVL_IHM.M2TreuilBenne.Bucket.Cfg, Persist := _BucketCfgPersist);
IF instCfgPersistBridgeBucket.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeCommun(Hmi := GVL_IHM.Commun.Cfg, Persist := _CommunCfgPersist);
IF instCfgPersistBridgeCommun.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeCycle(Hmi := GVL_IHM.Cycle.Cfg, Persist := _CycleCfgPersist);
IF instCfgPersistBridgeCycle.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeDredgingAssist(Hmi := GVL_IHM.DredgingAssist.Cfg, Persist := _DredgingAssistCfgPersist);
IF instCfgPersistBridgeDredgingAssist.JustRestored THEN
    GVL_IHM.DredgingAssist.Cmd.TglEnableDiveSearch         := GVL_IHM.DredgingAssist.Cfg.TglEnableDiveSearch;
    GVL_IHM.DredgingAssist.Cmd.TglEnableExtractionSequence := GVL_IHM.DredgingAssist.Cfg.TglEnableExtractionSequence;
    GVL_IHM.DredgingAssist.Cmd.TglEnableDumpAtTremie       := GVL_IHM.DredgingAssist.Cfg.TglEnableDumpAtTremie;
    GVL_IHM.Commun.ConfigRestoredFromPersistent            := TRUE;
ELSE
    GVL_IHM.DredgingAssist.Cfg.TglEnableDiveSearch         := GVL_IHM.DredgingAssist.Cmd.TglEnableDiveSearch;
    GVL_IHM.DredgingAssist.Cfg.TglEnableExtractionSequence := GVL_IHM.DredgingAssist.Cmd.TglEnableExtractionSequence;
    GVL_IHM.DredgingAssist.Cfg.TglEnableDumpAtTremie       := GVL_IHM.DredgingAssist.Cmd.TglEnableDumpAtTremie;
END_IF;

IF NOT GVL_IHM.TranslationM3.Cmd.Initialized THEN
    GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := _TranslationSetFreq_Hz;
    GVL_IHM.TranslationM3.Cmd.Initialized := TRUE;
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;
// Recopie continue (après restauration) : toute consigne changée en session survit au
// prochain boot/reset chaud, pas seulement le défaut d'usine.
_TranslationSetFreq_Hz := GVL_IHM.TranslationM3.Cmd.SetFreq_Hz;

instAckConfigRestored(CLK := GVL_IHM.Commun.BtnAckConfigRestored);
IF instAckConfigRestored.Q THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := FALSE;
END_IF;

IF NOT GVL_IHM.TranslationM3.Bypass.Initialized THEN
    IF BypassTranslationGlobal THEN
        GVL_IHM.TranslationM3.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.TranslationM3.Bypass.Initialized := TRUE;
END_IF;

IF NOT GVL_IHM.M1TreuilRetenue.Bypass.Initialized THEN
    IF BypassWinchM1Global THEN
        GVL_IHM.M1TreuilRetenue.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.M1TreuilRetenue.Bypass.Initialized := TRUE;
END_IF;

IF NOT GVL_IHM.M2TreuilBenne.Bypass.Initialized THEN
    IF BypassWinchM2Global THEN
        GVL_IHM.M2TreuilBenne.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.M2TreuilBenne.Bypass.Initialized := TRUE;
END_IF;

// Restauration boot du bypass synchro (RETAIN), même pattern que les autres domaines.
IF NOT GVL_IHM.M1M2Sync.Bypass.Initialized THEN
    IF BypassSyncGlobal THEN
        GVL_IHM.M1M2Sync.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.M1M2Sync.Bypass.Initialized := TRUE;
END_IF;

IF NOT GVL_IHM.Commun.Bypass.Initialized THEN
    IF BypassCommunGlobal THEN
        GVL_IHM.Commun.Bypass.Global := TRUE;
    END_IF;
    IF BypassLimitLegal THEN
        GVL_IHM.Commun.Bypass.LimitLegal := TRUE;
    END_IF;
    IF BypassTopLimitSwitch THEN
        GVL_IHM.Commun.Bypass.TopLimitSwitch := TRUE;
    END_IF;
    IF BypassTopLimitSoftware THEN
        GVL_IHM.Commun.Bypass.TopLimitSoftware := TRUE;
    END_IF;
    IF BypassCableLimitSwitch THEN
        GVL_IHM.Commun.Bypass.CableLimitSwitch := TRUE;
    END_IF;
    IF BypassSlackCable THEN
        GVL_IHM.Commun.Bypass.SlackCable := TRUE;
    END_IF;
    GVL_IHM.Commun.Bypass.Initialized := TRUE;
END_IF;

// 🔄 SYNC BIDIRECTIONNEL (dernier-écrit-gagne) : si l'IHM a changé → RETAIN ; sinon → IHM := RETAIN.
IF GVL_IHM.TranslationM3.Bypass.Global <> PrevTranslationBypass THEN
    BypassTranslationGlobal := GVL_IHM.TranslationM3.Bypass.Global;
ELSE
    GVL_IHM.TranslationM3.Bypass.Global := BypassTranslationGlobal;
END_IF;
PrevTranslationBypass := GVL_IHM.TranslationM3.Bypass.Global;

IF GVL_IHM.M1TreuilRetenue.Bypass.Global <> PrevM1Bypass THEN
    BypassWinchM1Global := GVL_IHM.M1TreuilRetenue.Bypass.Global;
ELSE
    GVL_IHM.M1TreuilRetenue.Bypass.Global := BypassWinchM1Global;
END_IF;
PrevM1Bypass := GVL_IHM.M1TreuilRetenue.Bypass.Global;

IF GVL_IHM.M2TreuilBenne.Bypass.Global <> PrevM2Bypass THEN
    BypassWinchM2Global := GVL_IHM.M2TreuilBenne.Bypass.Global;
ELSE
    GVL_IHM.M2TreuilBenne.Bypass.Global := BypassWinchM2Global;
END_IF;
PrevM2Bypass := GVL_IHM.M2TreuilBenne.Bypass.Global;

IF GVL_IHM.M1M2Sync.Bypass.Global <> PrevSyncBypass THEN
    BypassSyncGlobal := GVL_IHM.M1M2Sync.Bypass.Global;
ELSE
    GVL_IHM.M1M2Sync.Bypass.Global := BypassSyncGlobal;
END_IF;
PrevSyncBypass := GVL_IHM.M1M2Sync.Bypass.Global;

IF GVL_IHM.Commun.Bypass.Global <> PrevCommunBypass THEN
    BypassCommunGlobal := GVL_IHM.Commun.Bypass.Global;
ELSE
    GVL_IHM.Commun.Bypass.Global := BypassCommunGlobal;
END_IF;
PrevCommunBypass := GVL_IHM.Commun.Bypass.Global;

IF GVL_IHM.Commun.Bypass.LimitLegal <> PrevLimitLegal THEN
    BypassLimitLegal := GVL_IHM.Commun.Bypass.LimitLegal;
ELSE
    GVL_IHM.Commun.Bypass.LimitLegal := BypassLimitLegal;
END_IF;
PrevLimitLegal := GVL_IHM.Commun.Bypass.LimitLegal;

IF GVL_IHM.Commun.Bypass.TopLimitSwitch <> PrevTopLimitSwitch THEN
    BypassTopLimitSwitch := GVL_IHM.Commun.Bypass.TopLimitSwitch;
ELSE
    GVL_IHM.Commun.Bypass.TopLimitSwitch := BypassTopLimitSwitch;
END_IF;
PrevTopLimitSwitch := GVL_IHM.Commun.Bypass.TopLimitSwitch;

IF GVL_IHM.Commun.Bypass.TopLimitSoftware <> PrevTopLimitSoftware THEN
    BypassTopLimitSoftware := GVL_IHM.Commun.Bypass.TopLimitSoftware;
ELSE
    GVL_IHM.Commun.Bypass.TopLimitSoftware := BypassTopLimitSoftware;
END_IF;
PrevTopLimitSoftware := GVL_IHM.Commun.Bypass.TopLimitSoftware;

IF GVL_IHM.Commun.Bypass.CableLimitSwitch <> PrevCableLimitSwitch THEN
    BypassCableLimitSwitch := GVL_IHM.Commun.Bypass.CableLimitSwitch;
ELSE
    GVL_IHM.Commun.Bypass.CableLimitSwitch := BypassCableLimitSwitch;
END_IF;
PrevCableLimitSwitch := GVL_IHM.Commun.Bypass.CableLimitSwitch;

IF GVL_IHM.Commun.Bypass.SlackCable <> PrevSlackCable THEN
    BypassSlackCable := GVL_IHM.Commun.Bypass.SlackCable;
ELSE
    GVL_IHM.Commun.Bypass.SlackCable := BypassSlackCable;
END_IF;
PrevSlackCable := GVL_IHM.Commun.Bypass.SlackCable;

// 🧪 PILOTAGE BYPASS IHM PAR SIMULATION (front montant/descendant)
// La simulation emprunte le chemin IHM : SimulationBypassActive set/reset les bypass IHM
// (TopLimitSwitch / TopLimitSoftware / LimitLegal) au lieu d'un OR direct dans le code.
SimBypassRise(CLK := GVL_Simulation.SimulationBypassActive);
SimBypassFall(CLK := GVL_Simulation.SimulationBypassActive);

IF SimBypassRise.Q THEN
    GVL_IHM.Commun.Bypass.TopLimitSwitch   := TRUE;
    GVL_IHM.Commun.Bypass.TopLimitSoftware := TRUE;
    GVL_IHM.Commun.Bypass.LimitLegal       := TRUE;
    // 🧪 Bypass sim étendu aux tests Meca (Meca A-E via Safety ; NoMovement/
    // OppositeDir via Process) pour travailler sans faux blocage en banc.
    // Reste strictement inert sur machine réelle (SimulationBypassActive gaté MAINT+sim).
    GVL_IHM.M1TreuilRetenue.Bypass.Safety  := TRUE;
    GVL_IHM.M1TreuilRetenue.Bypass.Process := TRUE;
    GVL_IHM.M2TreuilBenne.Bypass.Safety    := TRUE;
    GVL_IHM.M2TreuilBenne.Bypass.Process   := TRUE;
END_IF;
IF SimBypassFall.Q THEN
    GVL_IHM.Commun.Bypass.TopLimitSwitch   := FALSE;
    GVL_IHM.Commun.Bypass.TopLimitSoftware := FALSE;
    GVL_IHM.Commun.Bypass.LimitLegal       := FALSE;
    GVL_IHM.M1TreuilRetenue.Bypass.Safety  := FALSE;
    GVL_IHM.M1TreuilRetenue.Bypass.Process := FALSE;
    GVL_IHM.M2TreuilBenne.Bypass.Safety    := FALSE;
    GVL_IHM.M2TreuilBenne.Bypass.Process   := FALSE;
END_IF;

{endregion}

{region "§3 Projections IHM et mapping"}
// === 📊 §3 PROJECTIONS IHM ET MAPPING ===

GVL_IHM.Commun.LimitLegalReached         := _CommunCfgPersist.LimitLegalEnabled
    AND ((PRG_02_Acquisition.Data.CablePosM1 <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M)
      OR (PRG_02_Acquisition.Data.CablePosM2 <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M));
GVL_IHM.Commun.TopPositionSensorActive   := NOT PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI;
GVL_IHM.Commun.HydraulicThermalFault     := NOT PRG_02_Acquisition.HwIn.Machine.HydraulicThermalOk_DI;
GVL_IHM.Commun.BrakeThermalFault         := NOT PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI;
GVL_IHM.Commun.PhaseRotationFault        := NOT PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI;

// 💓 Publication heartbeat IHM↔PLC
GVL_IHM.Commun.HeartbeatIhmOk            := instDiagIhmHeartbeat.HeartbeatIhmOk;
GVL_IHM.Commun.HeartbeatIhmTimeout       := instDiagIhmHeartbeat.HeartbeatIhmTimeout;
GVL_IHM.Commun.HeartbeatIhmElapsed       := instDiagIhmHeartbeat.TimeSinceIhmEdge;
GVL_IHM.Commun.TglHeartbeatPlc           := instDiagIhmHeartbeat.TglHeartbeatPlc;

// 🩺 Exécution du Preflight Machine à l'arrêt
instPreflight(
    Execute                   := GVL_IHM.Commun.Preflight.BtnRun,
    MachineIsStill            := (PRG_04_Treuils_Benne.Data.WinchM1State.StepNumber = 0)
                                 AND (PRG_04_Treuils_Benne.Data.WinchM2State.StepNumber = 0)
                                 AND (PRG_05_Translation.Data.TranslationState.FBState = E_State.READY),
    M1BrakeApplied            := NOT PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI,
    M2BrakeApplied            := NOT PRG_02_Acquisition.HwIn.Winch.M2_BrakeIsOpen_DI,
    M3BrakeApplied            := TRUE, // Pas de retour frein M3 direct
    M1ContactorsReleased      := PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI,
    M2ContactorsReleased      := PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI,
    M1ThermalOk               := PRG_02_Acquisition.HwIn.Winch.M1_ThermalOk_DI,
    M2ThermalOk               := PRG_02_Acquisition.HwIn.Winch.M2_ThermalOk_DI,
    BrakeThermalOk            := PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI,
    PhaseRotationOk           := PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI,
    SlackCableTensioned       := PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI,
    M3SensorWordIncoherent    := PRG_02_Acquisition.Data.M3_SensorWordIncoherent,
    EmergencyChainClosed      := PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI,
    PowerContactorEngaged     := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    EncoderM1Operational      := instDiagEthercat.DeviceEncoderM1.Operational,
    EncoderM2Operational      := instDiagEthercat.DeviceEncoderM2.Operational,
    HomedM1                   := PRG_04_Treuils_Benne.Data.WinchM1State.Encoder.Homed,
    HomedM2                   := PRG_04_Treuils_Benne.Data.WinchM2State.Encoder.Homed,
    M1PositionInBounds        := NOT PRG_02_Acquisition.Data.M1_EncoderIncoherent,
    M2PositionInBounds        := NOT PRG_02_Acquisition.Data.M2_EncoderIncoherent
);
GVL_IHM.Commun.Preflight.PreflightOk      := instPreflight.PreflightOk;
GVL_IHM.Commun.Preflight.PreflightDone    := instPreflight.PreflightDone;
GVL_IHM.Commun.Preflight.PreflightBusy    := instPreflight.PreflightBusy;
GVL_IHM.Commun.Preflight.PreflightErrorId := instPreflight.PreflightErrorId;

GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback   := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.TranslationM3.Bypass.ContactorFeedback   := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimTranslationActive;
GVL_IHM.Commun.SimSlackCableBypassActive         := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.Commun.SimTopSensorBypassActive          := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.Commun.WinchInputSourceChanged           := PRG_02_Acquisition.Data.WinchInputSourceChanged;

// 📦 Publication des structures d'état & safety vers IHM (recopies directes des bus inter-PRG)
GVL_IHM.M1TreuilRetenue.State := PRG_04_Treuils_Benne.Data.WinchM1State;
GVL_IHM.M2TreuilBenne.State := PRG_04_Treuils_Benne.Data.WinchM2State;
GVL_IHM.M1TreuilRetenue.Safety := PRG_04_Treuils_Benne.Data.WinchM1Safety;
GVL_IHM.M2TreuilBenne.Safety := PRG_04_Treuils_Benne.Data.WinchM2Safety;
GVL_IHM.M1M2Sync.State := PRG_04_Treuils_Benne.Data.SyncState;
GVL_IHM.M2TreuilBenne.Bucket.State := PRG_04_Treuils_Benne.Data.BucketState;
GVL_IHM.TranslationM3.State := PRG_05_Translation.Data.TranslationState;
GVL_IHM.TranslationM3.Safety := PRG_05_Translation.Data.TranslationSafety;

GVL_IHM.Modes.State.CurrentMode := PRG_03_Modes_Cycle.Auth.Mode;
GVL_IHM.Modes.State.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
GVL_IHM.Modes.State.PowerContactorOk := PRG_06_Outputs.EmergencyState.ContactorOk;
GVL_IHM.Modes.State.EmergencyChainOk := PRG_06_Outputs.EmergencyState.ChainOk;
GVL_IHM.Modes.State.EmergencyArmable := PRG_06_Outputs.EmergencyState.Armable;
GVL_IHM.Modes.State.EmergencyArmingBusy := PRG_06_Outputs.EmergencyState.ArmingBusy;
GVL_IHM.Modes.State.RedundancyTestFailed := PRG_06_Outputs.EmergencyDiag.RedundancyTestFailed;
GVL_IHM.Modes.State.EmergencyArmingFailed := PRG_06_Outputs.EmergencyDiag.ArmFailed;
GVL_IHM.Modes.State.AnyFaultActive := PRG_06_Outputs.EmergencyDiag.Error OR PRG_02_Acquisition.Data.InputModuleFault;
GVL_IHM.Modes.State.PowerCutOffActive := PRG_06_Outputs.PowerCutOffActive;

// 🕹️ Publication état Joystick IHM (GVL_IHM.JOY1Joystick.State)
GVL_IHM.JOY1Joystick.State.RawX := PRG_02_Acquisition.HwIn.Operator.JoyXRaw_ANA1;
GVL_IHM.JOY1Joystick.State.RawY := PRG_02_Acquisition.HwIn.Operator.JoyYRaw_ANA2;
GVL_IHM.JOY1Joystick.State.RawButton := PRG_02_Acquisition.HwIn.Operator.JoyBtnRaw;
GVL_IHM.JOY1Joystick.State.AxisCmdX := PRG_02_Acquisition.instJoystick.AxisCmdX;
GVL_IHM.JOY1Joystick.State.AxisCmdY := PRG_02_Acquisition.instJoystick.AxisCmdY;
GVL_IHM.JOY1Joystick.State.NeutralXAct := PRG_02_Acquisition.instJoystick.NeutralXAct;
GVL_IHM.JOY1Joystick.State.NeutralYAct := PRG_02_Acquisition.instJoystick.NeutralYAct;
GVL_IHM.JOY1Joystick.State.DeadmanArmed := PRG_02_Acquisition.Data.JoystickDeadmanArmed;
GVL_IHM.JOY1Joystick.State.AtNeutral := PRG_02_Acquisition.instJoystick.AtNeutral;
GVL_IHM.JOY1Joystick.State.Online := instDiagCanOpen.DeviceJoystick.Online;
GVL_IHM.JOY1Joystick.State.Operational := instDiagCanOpen.DeviceJoystick.Operational;
GVL_IHM.JOY1Joystick.State.Error := instDiagCanOpen.Error;
GVL_IHM.JOY1Joystick.State.ErrorId := instDiagCanOpen.ErrorId;

GVL_IHM.Network.CanError    := instDiagCanOpen.Error;
GVL_IHM.Network.CanErrorId  := instDiagCanOpen.ErrorId;
GVL_IHM.Network.Joystick    := instDiagCanOpen.DeviceJoystick;
GVL_IHM.Network.BusEthercat := instDiagEthercat.DeviceEthercatMaster;
GVL_IHM.Network.EncoderM1   := instDiagEthercat.DeviceEncoderM1;
GVL_IHM.Network.EncoderM2   := instDiagEthercat.DeviceEncoderM2;
GVL_IHM.Network.VariateurM3 := instDiagEthercat.DeviceVariateur;
GVL_IHM.Network.EcatError   := instDiagEthercat.Error;
GVL_IHM.Network.EcatErrorId := instDiagEthercat.ErrorId;

// 🩺 Diagnostic carte des 3 modules DI TOR réelles (AF06 §3bis) — lecture seule, calculé
// dans PRG_02_Acquisition, simple recopie ici pour l'IHM (même patron que Network.*).
GVL_IHM.Network.InputModules.LocalDigitalIoOk := PRG_02_Acquisition.Data.LocalDigitalIoOk;
GVL_IHM.Network.InputModules.Vh0800EndOk      := PRG_02_Acquisition.Data.Vh0800EndOk;
GVL_IHM.Network.InputModules.Vh0808EtpOk      := PRG_02_Acquisition.Data.Vh0808EtpOk;
// 🖥️ Bandeau IHM 4 champs (AF-07 §4)
// Publication des états du cycle semi-auto (lecture seule) — alimente le bandeau
GVL_IHM.Cycle.State.Ready                  := PRG_03_Modes_Cycle.instCycleSemiAuto.Ready;
GVL_IHM.Cycle.State.Busy                   := PRG_03_Modes_Cycle.instCycleSemiAuto.Busy;
GVL_IHM.Cycle.State.Done                   := PRG_03_Modes_Cycle.instCycleSemiAuto.Done;
GVL_IHM.Cycle.State.Error                  := PRG_03_Modes_Cycle.instCycleSemiAuto.Error;
GVL_IHM.Cycle.State.ErrorId                := PRG_03_Modes_Cycle.instCycleSemiAuto.ErrorId;
GVL_IHM.Cycle.State.CycleStep              := PRG_03_Modes_Cycle.instCycleSemiAuto.CycleStep;
GVL_IHM.Cycle.State.CycleStateStr          := PRG_03_Modes_Cycle.instCycleSemiAuto.CycleStateStr;
GVL_IHM.Cycle.State.CycleStepAtError       := PRG_03_Modes_Cycle.instCycleSemiAuto.CycleStepAtError;
GVL_IHM.Cycle.State.SampleCount            := _CycleSampleCount;
GVL_IHM.Cycle.State.SelTarget              := GVL_IHM.TranslationM3.Cmd.SelTarget;
GVL_IHM.Cycle.State.KoboldContactFond      := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI;
GVL_IHM.Cycle.State.KoboldContactorCmd     := PRG_03_Modes_Cycle.instCycleSemiAuto.BucketCmd.KoboldContactorCmd;
GVL_IHM.Cycle.State.LimitLegalReached      := GVL_IHM.Commun.LimitLegalReached;
GVL_IHM.Cycle.State.LimitLegalDepth_M      := _CommunCfgPersist.LimitLegalDepthMinAllowed_M;
GVL_IHM.Cycle.State.WinchSyncError         := PRG_04_Treuils_Benne.instWinchSync.Status.Error;
GVL_IHM.Cycle.State.WinchSyncDelta_M       := PRG_04_Treuils_Benne.instWinchSync.SignedDeltaPosM;
GVL_IHM.Cycle.State.SpeedMismatch_Mps      := PRG_03_Modes_Cycle.instCycleSemiAuto.SpeedMismatchMps;
GVL_IHM.Cycle.State.SpeedMismatchActive    := PRG_03_Modes_Cycle.instCycleSemiAuto.SpeedMismatchActive;
GVL_IHM.Cycle.State.SpeedMismatchConfirmed := PRG_03_Modes_Cycle.instCycleSemiAuto.SpeedMismatchConfirmed;
GVL_IHM.Cycle.State.M1Position_M           := PRG_02_Acquisition.Data.CablePosM1;
GVL_IHM.Cycle.State.M2Position_M           := PRG_02_Acquisition.Data.CablePosM2;
GVL_IHM.Cycle.State.DeadmanArmed           := PRG_02_Acquisition.Data.JoystickDeadmanArmed;
GVL_IHM.Cycle.State.JoystickMotionActive   := NOT PRG_02_Acquisition.instJoystick.AtNeutral;
GVL_IHM.Cycle.State.MotionPermit           := NOT PRG_02_Acquisition.instJoystick.AtNeutral;

instHmiBannerFormatter(
    Enable                := TRUE,
    SimulationModeActive  := GVL_Simulation.SimulationModeActive,
    CurrentMode           := PRG_03_Modes_Cycle.Auth.Mode,
    BothAxesCoupled       := (GVL_IHM.Modes.Cmd.SelJoystickWinch = 0),
    WinchSelected         := GVL_IHM.Modes.Cmd.SelJoystickWinch,
    CycleStep             := GVL_IHM.Cycle.State.CycleStep,
    CycleStateStr         := GVL_IHM.Cycle.State.CycleStateStr,
    CycleErrorId          := PRG_03_Modes_Cycle.instCycleSemiAuto.ErrorId,
    CycleStepAtError      := PRG_03_Modes_Cycle.instCycleSemiAuto.CycleStepAtError,
    DiveState             := GVL_IHM.DredgingAssist.State.DiveState,
    ExtractionState       := GVL_IHM.DredgingAssist.State.ExtractionState,
    HomingActive          := (NOT PRG_04_Treuils_Benne.Data.WinchM1State.Encoder.Homed) OR (NOT PRG_04_Treuils_Benne.Data.WinchM2State.Encoder.Homed),
    HomingStepM1          := SEL(PRG_02_Acquisition.instEncoderM1.Measurement.HomingStatus.Busy, 0, 1),
    HomingStepM2          := SEL(PRG_02_Acquisition.instEncoderM2.Measurement.HomingStatus.Busy, 0, 1),
    BypassGlobalActive    := GVL_IHM.Network.Bypass.Global,
    BypassWinchM1Active   := GVL_IHM.M1TreuilRetenue.Bypass.Global,
    BypassWinchM2Active   := GVL_IHM.M2TreuilBenne.Bypass.Global,
    BypassTranslation     := GVL_IHM.TranslationM3.Bypass.Global,
    BypassSyncActive      := GVL_IHM.M1M2Sync.Bypass.Global,
    SyncDegradedActive    := PRG_04_Treuils_Benne.Data.SyncState.SyncDeviationWarn,
    LegalLimitReached     := GVL_IHM.Commun.LimitLegalReached,
    EmergencyChainClosed  := PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    PowerCutOffActiveAny        := PRG_06_Outputs.PowerCutOffActive,
    SafeStopActive              := GVL_IHM.M1TreuilRetenue.Safety.SafeStop OR GVL_IHM.M2TreuilBenne.Safety.SafeStop,
    DescendPermit               := GVL_IHM.M1TreuilRetenue.Safety.DescendPermit AND GVL_IHM.M2TreuilBenne.Safety.DescendPermit,
    AscentPermit                := GVL_IHM.M1TreuilRetenue.Safety.AscentPermit AND GVL_IHM.M2TreuilBenne.Safety.AscentPermit,
    BucketIsOpen                := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsOpen,
    DiveActive                  := GVL_IHM.DredgingAssist.State.DiveBusy,
    TopLimitReached             := GVL_IHM.M1TreuilRetenue.Safety.CableLimitAscent OR GVL_IHM.M2TreuilBenne.Safety.CableLimitAscent,
    CoupledUserRequestDirection := PRG_04_Treuils_Benne.CoupledUserRequestDirection,
    M1LogicRequestDirection     := PRG_04_Treuils_Benne.M1LogicRequestDirection,
    M2LogicRequestDirection     := PRG_04_Treuils_Benne.M2LogicRequestDirection,
    CycleRequestDirection       := PRG_03_Modes_Cycle.instCycleSemiAuto.WinchM1Cmd.Direction,
    DeadmanArmed                := PRG_02_Acquisition.Data.JoystickDeadmanArmed,
    JoystickAtNeutral           := PRG_02_Acquisition.instJoystick.AtNeutral,
    CycleAutoBusy               := PRG_03_Modes_Cycle.instCycleSemiAuto.Busy,
    WinchM1Safety               := GVL_IHM.M1TreuilRetenue.Safety,
    WinchM2Safety               := GVL_IHM.M2TreuilBenne.Safety,
    TranslationSafety           := GVL_IHM.TranslationM3.Safety,
    BucketErrorId               := GVL_IHM.M2TreuilBenne.Bucket.State.ErrorId,
    SyncErrorId                 := GVL_IHM.M1M2Sync.State.ErrorId,
    DiveErrorId                 := GVL_IHM.DredgingAssist.State.DiveErrorId,
    ExtractionErrorId           := GVL_IHM.DredgingAssist.State.ExtractionErrorId,
    EmergencyErrorId            := PRG_06_Outputs.EmergencyDiag.ErrorId,
    AlarmHoldTime               := T#1s
);
GVL_IHM.Banner := instHmiBannerFormatter.Banner;

{endregion}

{region "§4 Vue depannage lecture seule"}
// === 🕵️♂️ §4 VUE DÉPANNAGE (lecture seule stricte) ===

instTroubleshootingView(
    Enable               := TRUE,
    HwIn                 := PRG_02_Acquisition.HwIn,
    HwReal               := PRG_02_Acquisition.HwReal,
    InputModuleFault     := PRG_02_Acquisition.Data.InputModuleFault,
    LocalDigitalIoOk     := PRG_02_Acquisition.Data.LocalDigitalIoOk,
    Vh0800EndOk          := PRG_02_Acquisition.Data.Vh0800EndOk,
    Vh0808EtpOk          := PRG_02_Acquisition.Data.Vh0808EtpOk,
    Auth                 := PRG_03_Modes_Cycle.Auth,
    M1LogicRequestSpeedRef_Pct := PRG_04_Treuils_Benne.Data.M1LogicRequestSpeedRef_Pct,
    M1LogicRequestDirection := PRG_04_Treuils_Benne.M1LogicRequestDirection,
    M2LogicRequestSpeedRef_Pct := PRG_04_Treuils_Benne.Data.M2LogicRequestSpeedRef_Pct,
    M2LogicRequestDirection := PRG_04_Treuils_Benne.M2LogicRequestDirection,
    CoupledUserRequestDirection := PRG_04_Treuils_Benne.CoupledUserRequestDirection,
    CoupledUserRequestActive := PRG_04_Treuils_Benne.CoupledUserRequestActive,
    CycleAutoBusy := PRG_03_Modes_Cycle.instCycleSemiAuto.Busy,
    CycleM1SpeedRef_Pct := PRG_03_Modes_Cycle.instCycleSemiAuto.WinchM1Cmd.SpeedPct,
    CycleM2SpeedRef_Pct := PRG_03_Modes_Cycle.instCycleSemiAuto.WinchM2Cmd.SpeedPct,
    CycleBucketOpen := PRG_03_Modes_Cycle.instCycleSemiAuto.BucketCmd.Open,
    CycleTargetPosition := PRG_03_Modes_Cycle.instCycleSemiAuto.TranslationCmd.Target,
    SimulationModeActive := GVL_Simulation.SimulationModeActive,
    SimWinchActive       := GVL_Simulation.SimWinchActive,
    SimTranslationActive := GVL_Simulation.SimTranslationActive,
    SimOperatorActive    := GVL_Simulation.SimOperatorActive,
    SimSafetyActive      := GVL_Simulation.SimSafetyActive,
    WinchM1              := GVL_IHM.M1TreuilRetenue,
    WinchM2              := GVL_IHM.M2TreuilBenne,
    Sync                 := GVL_IHM.M1M2Sync,
    Translation          := GVL_IHM.TranslationM3,
    Commun               := GVL_IHM.Commun,
    Network              := GVL_IHM.Network,
    DredgingAssist       := GVL_IHM.DredgingAssist,
    JoystickHMI          := GVL_IHM.JOY1Joystick,
    EmergencyState       := PRG_06_Outputs.EmergencyState,
    EmergencyDiag        := PRG_06_Outputs.EmergencyDiag,
    PowerCutOffActive    := PRG_06_Outputs.PowerCutOffActive,
    ArmingPulseActive    := PRG_06_Outputs.EmergencyArmingPulseActive,
    MaintainAActive      := PRG_06_Outputs.Data.PowerKeepAliveACmd,
    MaintainBActive      := PRG_06_Outputs.Data.PowerKeepAliveBCmd,
    CycleReady           := PRG_03_Modes_Cycle.instCycleSemiAuto.Ready,
    CycleDone            := PRG_03_Modes_Cycle.instCycleSemiAuto.Done,
    CycleError           := PRG_03_Modes_Cycle.instCycleSemiAuto.Error,
    CycleErrorId         := PRG_03_Modes_Cycle.instCycleSemiAuto.ErrorId,
    CycleStep            := PRG_03_Modes_Cycle.instCycleSemiAuto.CycleStep,
    CycleStepStr         := PRG_03_Modes_Cycle.instCycleSemiAuto.CycleStateStr,
    CycleStepAtError     := PRG_03_Modes_Cycle.instCycleSemiAuto.CycleStepAtError,
    CycleStartRequest    := GVL_IHM.Cycle.Cmd.BtnStart,
    CycleAbortRequest    := GVL_IHM.Cycle.Cmd.BtnAbort,
    CycleTargetDepth_M   := GVL_IHM.Cycle.Cfg.SetDepth_M,
    CycleKoboldBottomTouch := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI,
    CycleSpeedMismatchActive := PRG_03_Modes_Cycle.instCycleSemiAuto.SpeedMismatchActive,
    CycleLimitLegalReached := GVL_IHM.Commun.LimitLegalReached,
    CycleWinchSyncError  := PRG_04_Treuils_Benne.instWinchSync.Status.Error,
    JoystickDeadmanArmed := PRG_02_Acquisition.Data.JoystickDeadmanArmed,
    JoystickAtNeutral    := PRG_02_Acquisition.instJoystick.AtNeutral,
    HomedM1              := PRG_02_Acquisition.instEncoderM1.Homed,
    HomedM2              := PRG_02_Acquisition.instEncoderM2.Homed
);

{endregion}
END_PROGRAM
