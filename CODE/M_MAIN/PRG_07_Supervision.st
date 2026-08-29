(* ═══════════════════════════════════════════════════════════════
   🖥️ PRG_07_Supervision — Échanges IHM, Diagnostics et Initialisation Boot
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 7.
   ✅ Regroupe tout le mapping bidirectionnel GVL_IHM / GVL_PERSISTENT.
   ✅ Expose FaultMachineReset_IHM pour tous les programmes du domaine sécurité/métier.
   📄 Docs : DOC/AF/AF_Partie-07_Interface_IHM_v2.2.md
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
    instCfgPersistBridgeJoystick       : FB_CfgPersistBridge_fbJoystick_Cfg;      // * [INST] Pont persistance config joystick
    instCfgPersistBridgeEncoder        : FB_CfgPersistBridge_fbEncoder_Cfg;       // * [INST] Pont persistance config codeur commune M1/M2
    instDiagIhmHeartbeat   : FB_Diag_IhmHeartbeat;            // * [INST] Surveillance heartbeat IHM
    instPreflight          : FB_Acquisition_Preflight;        // * [INST] Preflight acquisition avant demarrage
    instHmiBannerFormatter : FB_Hmi_BannerFormatter;          // * [INST] Formatage bandeau IHM (alarmes/etats)
    instTroubleshootingView : FB_TroubleshootingView;         // * [INST] Vue troubleshooting (diagnostic IHM)
    instMirrorBypassTranslation      : FB_MirrorBypassRetain; // * [INST] Miroir bypass Translation IHM<->RETAIN
    instMirrorBypassM1               : FB_MirrorBypassRetain; // * [INST] Miroir bypass M1 IHM<->RETAIN
    instMirrorBypassM2               : FB_MirrorBypassRetain; // * [INST] Miroir bypass M2 IHM<->RETAIN
    instMirrorBypassSync             : FB_MirrorBypassRetain; // * [INST] Miroir bypass Sync IHM<->RETAIN
    instMirrorBypassCommun           : FB_MirrorBypassRetain; // * [INST] Miroir bypass Commun IHM<->RETAIN
    instMirrorBypassLimitLegal       : FB_MirrorBypassRetain; // * [INST] Miroir bypass LimitLegal IHM<->RETAIN
    instMirrorBypassTopLimitSwitch   : FB_MirrorBypassRetain; // * [INST] Miroir bypass TopLimitSwitch IHM<->RETAIN
    instMirrorBypassTopLimitSoftware : FB_MirrorBypassRetain; // * [INST] Miroir bypass TopLimitSoftware IHM<->RETAIN
    instMirrorBypassCableLimitSwitch : FB_MirrorBypassRetain; // * [INST] Miroir bypass CableLimitSwitch IHM<->RETAIN
    instMirrorBypassSlackCable       : FB_MirrorBypassRetain; // * [INST] Miroir bypass SlackCable IHM<->RETAIN

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

{region "§1 Horloge, heartbeat et reset machine"}
// === 🧩 §1 HORLOGE, HEARTBEAT & RESET MACHINE ===
// Trois fonctions de tête : clignotant global, heartbeat IHM (surveillance lien),
// et acquittement machine (porte d'entrée des reset).

// ---------- §1a. Horloge clignotante ----------
instBlink1Hz(
    ENABLE   := TRUE,
    TIMEHIGH := _BlinkTimeOn,
    TIMELOW  := _BlinkTimeOff
);
GVL_Global.BlinkClock := instBlink1Hz.OUT;

// ---------- §1b. Heartbeat IHM (front simulé) ----------
// 💓 Front heartbeat simulé par le clignotant PLC 1 Hz quand le bypass
// IhmHeartbeat est actif (défaut sécurisé), pour ne jamais latcher un timeout
// artificiel. Repasser le bypass à FALSE côté IHM active la vraie surveillance.
instDiagIhmHeartbeat(
    Enable          := TRUE,
    TglHeartbeatIhm := SEL(GVL_IHM.Network.Bypass.IhmHeartbeat, GVL_IHM.Commun.TglHeartbeatIhm, GVL_Global.BlinkClock)
);

// ---------- §1c. Acquittement global machine (reset) ----------
// 🚨 Acquittement global machine : une impulsion est émise dès que l'opérateur appuie
// sur l'un des boutons de reset IHM (défaut global, treuil M1, treuil M2, ou benne).
// Ce signal est consommé par tous les FB du domaine sécurité/métier pour réarmer
// les défauts (Reset sur front). C'est LA porte d'entrée unique de l'acquittement.
FaultMachineReset_IHM := GVL_IHM.Modes.Cmd.BtnFaultReset
                    OR GVL_IHM.M1TreuilRetenue.Cmd.BtnReset
                    OR GVL_IHM.M2TreuilBenne.Cmd.BtnReset
                    OR GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset;


{endregion}

{region "§2 Persistance, bypass et simulation"}
// === 🌉 §2 PERSISTANCE, RESTAURATION & BYPASS ===
// Quatre responsabilités distinctes : persistance des configs, restauration boot des
// bypass, synchronisation bidirectionnelle IHM↔RETAIN, et pilotage des bypass par simulation.

// ---------- §2a. Persistance des configs (bridges) ----------
// Chaque FB_CfgPersistBridge_* synchronise UNE structure de config entre GVL_IHM (Hmi)
// et GVL_PERSISTENT (Persist) sur le flag `Initialized` :
//   - au 1er cycle (Hmi.Initialized=FALSE) : Hmi := Persist (restaure la config sauvegardée)
//     et JustRestored := TRUE sur ce seul cycle ;
//   - ensuite : Persist := Hmi (la config IHM est sauvegardée en continu).
// Le flag commun GVL_IHM.Commun.ConfigRestoredFromPersistent est levé dès qu'au moins
// un bridge a restauré au boot, pour signaler à l'IHM qu'une config persistante a été rappelée.

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

instCfgPersistBridgeJoystick(Hmi := GVL_IHM.JOY1Joystick.Cfg, Persist := _JoystickCfgPersist);
IF instCfgPersistBridgeJoystick.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeEncoder(Hmi := GVL_IHM.Commun.EncoderCfg, Persist := _EncoderCfgPersist);
IF instCfgPersistBridgeEncoder.JustRestored THEN
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

// Consigne variateur M3 (SetFreq_Hz) : pas de bridge Cfg dédié (c'est une Cmd, pas une
// Cfg) → initialisation manuelle au 1er cycle à partir du persist RETAIN _TranslationSetFreq_Hz.
// Le flag Cmd.Initialized distingue le 1er passage (restaure) des suivants (survit).
IF NOT GVL_IHM.TranslationM3.Cmd.Initialized THEN
    GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := _TranslationSetFreq_Hz;
    GVL_IHM.TranslationM3.Cmd.Initialized := TRUE;
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;
// Recopie continue (après restauration) : toute consigne changée en session survit au
// prochain boot/reset chaud, pas seulement le défaut d'usine.
_TranslationSetFreq_Hz := GVL_IHM.TranslationM3.Cmd.SetFreq_Hz;

// Acquittement du bandeau « config restaurée » par l'opérateur (front) → efface le flag.
instAckConfigRestored(CLK := GVL_IHM.Commun.BtnAckConfigRestored);
IF instAckConfigRestored.Q THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := FALSE;
END_IF;

// ---------- §2b. Restauration boot des bypass (RETAIN → IHM) ----------
// 🎚️ Restauration boot des BYPASS IHM depuis le RETAIN (BypassXxxGlobal) :
// au 1er cycle (Bypass.Initialized=FALSE), si un bypass global RETAIN est actif, on le
// rejoue sur l'IHM, puis on marque Initialized pour ne pas réécraser les actions suivantes
// de l'opérateur. Même pattern pour chaque domaine (Translation / M1 / M2 / Sync / Commun).
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

// ---------- §2c. Synchronisation bidirectionnelle IHM ↔ RETAIN ----------
// 🔄 SYNC BIDIRECTIONNEL (dernier-écrit-gagne), factorisé dans FB_MirrorBypassRetain
// (CODE/A_COMMUN) : si l'IHM a changé → RETAIN ; sinon → IHM := RETAIN.
instMirrorBypassTranslation(Hmi := GVL_IHM.TranslationM3.Bypass.Global, RetainVal := BypassTranslationGlobal, Prev := PrevTranslationBypass);
instMirrorBypassM1(Hmi := GVL_IHM.M1TreuilRetenue.Bypass.Global, RetainVal := BypassWinchM1Global, Prev := PrevM1Bypass);
instMirrorBypassM2(Hmi := GVL_IHM.M2TreuilBenne.Bypass.Global, RetainVal := BypassWinchM2Global, Prev := PrevM2Bypass);
instMirrorBypassSync(Hmi := GVL_IHM.M1M2Sync.Bypass.Global, RetainVal := BypassSyncGlobal, Prev := PrevSyncBypass);
instMirrorBypassCommun(Hmi := GVL_IHM.Commun.Bypass.Global, RetainVal := BypassCommunGlobal, Prev := PrevCommunBypass);
instMirrorBypassLimitLegal(Hmi := GVL_IHM.Commun.Bypass.LimitLegal, RetainVal := BypassLimitLegal, Prev := PrevLimitLegal);
instMirrorBypassTopLimitSwitch(Hmi := GVL_IHM.Commun.Bypass.TopLimitSwitch, RetainVal := BypassTopLimitSwitch, Prev := PrevTopLimitSwitch);
instMirrorBypassTopLimitSoftware(Hmi := GVL_IHM.Commun.Bypass.TopLimitSoftware, RetainVal := BypassTopLimitSoftware, Prev := PrevTopLimitSoftware);
instMirrorBypassCableLimitSwitch(Hmi := GVL_IHM.Commun.Bypass.CableLimitSwitch, RetainVal := BypassCableLimitSwitch, Prev := PrevCableLimitSwitch);
instMirrorBypassSlackCable(Hmi := GVL_IHM.Commun.Bypass.SlackCable, RetainVal := BypassSlackCable, Prev := PrevSlackCable);

// ---------- §2d. Pilotage des bypass par simulation ----------
// 🧪 PILOTAGE BYPASS IHM PAR SIMULATION (front montant/descendant)
// La simulation emprunte le chemin IHM : SimulationBypassActive set/reset les bypass IHM
// (TopLimitSwitch / TopLimitSoftware / LimitLegal) au lieu d'un OR direct dans le code.
SimBypassRise(CLK := GVL_Simulation.SimulationBypassActive);
SimBypassFall(CLK := GVL_Simulation.SimulationBypassActive);

IF SimBypassRise.Q THEN
    // 🧪 Bypass sim étendu aux tests Meca (Meca A-E via Safety ; NoMovement/
    // OppositeDir via Process) pour travailler sans faux blocage en banc.
    // ❗ Les limites réelles (TopLimitSwitch / TopLimitSoftware / LimitLegal) NE sont PAS
    //    bypassées par la simulation : la protection de montée/descente reste active au banc.
    // Reste strictement inerte sur machine réelle (SimulationBypassActive gaté MAINT+sim).
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
// Ensemble des recopies GVL_IHM ← sources inter-PRG. Chaque sous-région est un domaine
// IHM cohérent (faits machine, heartbeat, preflight, bypass, état, réseau, cycle, bandeau).

// ---------- §3a. Faits machine communs (lecture seule) ----------
GVL_IHM.Commun.LimitLegalReached         := _CommunCfgPersist.LimitLegalEnabled
    AND ((PRG_02_Acquisition.Data.Encoders.M1.CablePosM <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M)
      OR (PRG_02_Acquisition.Data.Encoders.M2.CablePosM <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M));
GVL_IHM.Commun.TopPositionSensorActive   := NOT PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI;
GVL_IHM.Commun.HydraulicThermalFault     := NOT PRG_02_Acquisition.HwIn.Machine.HydraulicThermalOk_DI;
GVL_IHM.Commun.BrakeThermalFault         := NOT PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI;
GVL_IHM.Commun.PhaseRotationFault        := NOT PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI;

// ---------- §3b. Heartbeat IHM↔PLC ----------
GVL_IHM.Commun.HeartbeatIhmOk            := instDiagIhmHeartbeat.HeartbeatIhmOk;
GVL_IHM.Commun.HeartbeatIhmTimeout       := instDiagIhmHeartbeat.HeartbeatIhmTimeout;
GVL_IHM.Commun.HeartbeatIhmElapsed       := instDiagIhmHeartbeat.TimeSinceIhmEdge;
GVL_IHM.Commun.TglHeartbeatPlc           := instDiagIhmHeartbeat.TglHeartbeatPlc;

// ---------- §3c. Preflight machine à l'arrêt ----------
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
    M3SensorWordIncoherent    := PRG_05_Translation.Data.M3_SensorWordIncoherent,
    EmergencyChainClosed      := PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI,
    PowerContactorEngaged     := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    EncoderM1Operational      := PRG_02_Acquisition.Data.Network.EncoderM1.Operational,
    EncoderM2Operational      := PRG_02_Acquisition.Data.Network.EncoderM2.Operational,
    HomedM1                   := PRG_04_Treuils_Benne.Data.WinchM1State.Encoder.Homed,
    HomedM2                   := PRG_04_Treuils_Benne.Data.WinchM2State.Encoder.Homed,
    M1PositionInBounds        := NOT PRG_02_Acquisition.Data.Encoders.M1.EncoderIncoherent,
    M2PositionInBounds        := NOT PRG_02_Acquisition.Data.Encoders.M2.EncoderIncoherent
);
GVL_IHM.Commun.Preflight.PreflightOk      := instPreflight.PreflightOk;
GVL_IHM.Commun.Preflight.PreflightDone    := instPreflight.PreflightDone;
GVL_IHM.Commun.Preflight.PreflightBusy    := instPreflight.PreflightBusy;
GVL_IHM.Commun.Preflight.PreflightErrorId := instPreflight.PreflightErrorId;

// ---------- §3d. Bypass simulation (retours simulés vers IHM) ----------
GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback   := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.TranslationM3.Bypass.ContactorFeedback   := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimTranslationActive;
GVL_IHM.Commun.SimSlackCableBypassActive         := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.Commun.SimTopSensorBypassActive          := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.Commun.WinchInputSourceChanged           := PRG_02_Acquisition.Data.WinchInputSourceChanged;

// ---------- §3e. Structures d'état & safety (recopies directes des bus) ----------
GVL_IHM.M1TreuilRetenue.State := PRG_04_Treuils_Benne.Data.WinchM1State;
GVL_IHM.M2TreuilBenne.State := PRG_04_Treuils_Benne.Data.WinchM2State;
GVL_IHM.M1TreuilRetenue.Safety := PRG_04_Treuils_Benne.Data.WinchM1Safety;
GVL_IHM.M2TreuilBenne.Safety := PRG_04_Treuils_Benne.Data.WinchM2Safety;
GVL_IHM.M1M2Sync.State := PRG_04_Treuils_Benne.Data.SyncState;
GVL_IHM.M2TreuilBenne.Bucket.State := PRG_04_Treuils_Benne.Data.BucketState;
GVL_IHM.TranslationM3.State := PRG_05_Translation.Data.TranslationState;
GVL_IHM.TranslationM3.Safety := PRG_05_Translation.Data.TranslationSafety;

GVL_IHM.Modes.State.CurrentMode := PRG_03_Modes_Cycle.Data.Auth.Mode;
GVL_IHM.Modes.State.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
GVL_IHM.Modes.State.PowerContactorOk := PRG_06_Outputs.EmergencyState.ContactorOk;
GVL_IHM.Modes.State.EmergencyChainOk := PRG_06_Outputs.EmergencyState.ChainOk;
GVL_IHM.Modes.State.EmergencyArmable := PRG_06_Outputs.EmergencyState.Armable;
GVL_IHM.Modes.State.EmergencyArmingBusy := PRG_06_Outputs.EmergencyState.ArmingBusy;
GVL_IHM.Modes.State.RedundancyTestFailed := PRG_06_Outputs.EmergencyDiag.RedundancyTestFailed;
GVL_IHM.Modes.State.EmergencyArmingFailed := PRG_06_Outputs.EmergencyDiag.ArmFailed;
// OR avec les défauts d'arbitrage de mode (refus Semi-Auto, bascule de mode refusée) —
// publiés par PRG_03 : sans eux ces refus restaient silencieux pour l'opérateur.
GVL_IHM.Modes.State.AnyFaultActive := PRG_06_Outputs.EmergencyDiag.Error
                                      OR PRG_02_Acquisition.Data.InputModuleFault
                                      OR PRG_03_Modes_Cycle.Data.ModesFault.Error
                                      OR PRG_03_Modes_Cycle.Data.ModesFault.Latched;
GVL_IHM.Modes.State.PowerCutOffActive := PRG_06_Outputs.PowerCutOffActive;
// Miroir IHM des états de maintenance (AF-05 §4bis, producteur FB_Modes via PRG_03)
GVL_IHM.Modes.State.ModeChangePendingBlocked := PRG_03_Modes_Cycle.Data.Auth.ModeChangePendingBlocked;
GVL_IHM.Modes.State.HomingRequiredM1 := PRG_03_Modes_Cycle.Data.Auth.HomingRequiredM1;
GVL_IHM.Modes.State.HomingRequiredM2 := PRG_03_Modes_Cycle.Data.Auth.HomingRequiredM2;

// ---------- §3f. État joystick & réseau (diagnostic bus) ----------
GVL_IHM.JOY1Joystick.State.RawX := PRG_02_Acquisition.HwIn.Operator.JoyXRaw_ANA1;
GVL_IHM.JOY1Joystick.State.RawY := PRG_02_Acquisition.HwIn.Operator.JoyYRaw_ANA2;
GVL_IHM.JOY1Joystick.State.RawButton := PRG_02_Acquisition.HwIn.Operator.JoyBtnRaw;
GVL_IHM.JOY1Joystick.State.AxisCmdX := PRG_02_Acquisition.Data.Joystick.AxisX;
GVL_IHM.JOY1Joystick.State.AxisCmdY := PRG_02_Acquisition.Data.Joystick.AxisY;
GVL_IHM.JOY1Joystick.State.NeutralXAct := PRG_02_Acquisition.Data.Joystick.NeutralXAct;
GVL_IHM.JOY1Joystick.State.NeutralYAct := PRG_02_Acquisition.Data.Joystick.NeutralYAct;
GVL_IHM.JOY1Joystick.State.DeadmanArmed := PRG_02_Acquisition.Data.JoystickDeadmanArmed;
GVL_IHM.JOY1Joystick.State.AtNeutral := PRG_02_Acquisition.Data.Joystick.AtNeutralXY;
GVL_IHM.JOY1Joystick.State.Online := PRG_02_Acquisition.Data.Network.Joystick.Online;
GVL_IHM.JOY1Joystick.State.Operational := PRG_02_Acquisition.Data.Network.Joystick.Operational;
// 🕹️ Le défaut fonctionnel du joystick (calibration bit0, capteur hors plage bit1, perte
// bus bit2) vient du FB lui-même, pas du diagnostic bus. Le diagnostic CAN reste exposé
// séparément (GVL_IHM.Network.CanError) — ici on remonte l'erreur du FB joystick.
GVL_IHM.JOY1Joystick.State.Error := PRG_02_Acquisition.Data.Joystick.Fault.Error;
GVL_IHM.JOY1Joystick.State.ErrorId := PRG_02_Acquisition.Data.Joystick.Fault.ErrorId;

GVL_IHM.Network.BusCanOpen  := PRG_02_Acquisition.Data.Network.CanOpenMaster;
GVL_IHM.Network.Joystick    := PRG_02_Acquisition.Data.Network.Joystick;
GVL_IHM.Network.CanError    := GVL_IHM.Network.BusCanOpen.Error OR GVL_IHM.Network.Joystick.Error;
GVL_IHM.Network.CanErrorId  := GVL_IHM.Network.BusCanOpen.ErrorId OR GVL_IHM.Network.Joystick.ErrorId;

GVL_IHM.Network.BusEthercat := PRG_02_Acquisition.Data.Network.EthercatMaster;
GVL_IHM.Network.EncoderM1   := PRG_02_Acquisition.Data.Network.EncoderM1;
GVL_IHM.Network.EncoderM2   := PRG_02_Acquisition.Data.Network.EncoderM2;
GVL_IHM.Network.VariateurM3 := PRG_02_Acquisition.Data.Network.DriveM3;
GVL_IHM.Network.EcatError   := GVL_IHM.Network.BusEthercat.Error OR GVL_IHM.Network.EncoderM1.Error OR GVL_IHM.Network.EncoderM2.Error OR GVL_IHM.Network.VariateurM3.Error;
GVL_IHM.Network.EcatErrorId := GVL_IHM.Network.BusEthercat.ErrorId OR GVL_IHM.Network.EncoderM1.ErrorId OR GVL_IHM.Network.EncoderM2.ErrorId OR GVL_IHM.Network.VariateurM3.ErrorId;

// 🩺 Diagnostic carte des 5 modules d'E/S physiques (AF06 §3bis) — lecture seule, calculé
// dans PRG_02_Acquisition, simple recopie ici pour l'IHM (même patron que Network.*).
GVL_IHM.Network.InputModules.LocalDigitalIoOk := PRG_02_Acquisition.Data.LocalDigitalIoOk;
GVL_IHM.Network.InputModules.Vh0800EndOk      := PRG_02_Acquisition.Data.Vh0800EndOk;
GVL_IHM.Network.InputModules.Vh0808EtpOk      := PRG_02_Acquisition.Data.Vh0808EtpOk;
GVL_IHM.Network.InputModules.Vh0008ErOk       := PRG_02_Acquisition.Data.Vh0008ErOk;
GVL_IHM.Network.InputModules.Vh0008Er1Ok      := PRG_02_Acquisition.Data.Vh0008Er1Ok;
GVL_IHM.Network.InputModules.Fault            := PRG_02_Acquisition.Data.InputModuleFault;

// ---------- §3g. État cycle semi-auto & bandeau ----------
GVL_IHM.Cycle.State.Ready                  := PRG_03_Modes_Cycle.Data.SequenceState.Ready;
GVL_IHM.Cycle.State.Busy                   := PRG_03_Modes_Cycle.Data.SequenceState.Lifecycle.Busy;
GVL_IHM.Cycle.State.Done                   := PRG_03_Modes_Cycle.Data.SequenceState.Lifecycle.Done;
GVL_IHM.Cycle.State.Error                  := PRG_03_Modes_Cycle.Data.SequenceState.Fault.Error;
GVL_IHM.Cycle.State.ErrorId                := PRG_03_Modes_Cycle.Data.SequenceState.Fault.ErrorId;
GVL_IHM.Cycle.State.CycleStep              := PRG_03_Modes_Cycle.Data.SequenceState.Step;
GVL_IHM.Cycle.State.CycleStateStr          := PRG_03_Modes_Cycle.Data.SequenceState.StepStr;
GVL_IHM.Cycle.State.CycleStepAtError       := PRG_03_Modes_Cycle.Data.SequenceState.StepAtFault;
GVL_IHM.Cycle.State.SampleCount            := _CycleSampleCount;
GVL_IHM.Cycle.State.SelTarget              := GVL_IHM.TranslationM3.Cmd.SelTarget;
GVL_IHM.Cycle.State.KoboldContactFond      := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI;
GVL_IHM.Cycle.State.KoboldContactorCmd     := PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ReqKoboldMeasureEnable;
GVL_IHM.Cycle.State.LimitLegalReached      := GVL_IHM.Commun.LimitLegalReached;
GVL_IHM.Cycle.State.LimitLegalDepth_M      := _CommunCfgPersist.LimitLegalDepthMinAllowed_M;
GVL_IHM.Cycle.State.WinchSyncError         := PRG_04_Treuils_Benne.Data.WinchSyncError;
GVL_IHM.Cycle.State.WinchSyncDelta_M       := PRG_04_Treuils_Benne.Data.WinchSyncSignedDeltaPosM;
GVL_IHM.Cycle.State.SpeedMismatch_Mps      := PRG_03_Modes_Cycle.Data.SequenceState.SpeedMismatchMps;
GVL_IHM.Cycle.State.SpeedMismatchActive    := PRG_03_Modes_Cycle.Data.SequenceState.SpeedMismatchActive;
GVL_IHM.Cycle.State.SpeedMismatchConfirmed := PRG_03_Modes_Cycle.Data.SequenceState.SpeedMismatchConfirmed;
GVL_IHM.Cycle.State.M1Position_M           := PRG_02_Acquisition.Data.Encoders.M1.CablePosM;
GVL_IHM.Cycle.State.M2Position_M           := PRG_02_Acquisition.Data.Encoders.M2.CablePosM;
GVL_IHM.Cycle.State.DeadmanArmed           := PRG_02_Acquisition.Data.JoystickDeadmanArmed;
GVL_IHM.Cycle.State.JoystickMotionActive   := NOT PRG_02_Acquisition.Data.Joystick.AtNeutralXY;
GVL_IHM.Cycle.State.MotionPermit           := NOT PRG_02_Acquisition.Data.Joystick.AtNeutralXY;

// Projection Assistance Dragage (DredgingAssist.State)
GVL_IHM.DredgingAssist.State.DiveReady                  := PRG_03_Modes_Cycle.Data.SequenceState.DiveReady;
GVL_IHM.DredgingAssist.State.DiveBusy                   := PRG_03_Modes_Cycle.Data.SequenceState.DiveBusy;
GVL_IHM.DredgingAssist.State.DiveDone                   := PRG_03_Modes_Cycle.Data.SequenceState.DiveDone;
GVL_IHM.DredgingAssist.State.DiveError                  := PRG_03_Modes_Cycle.Data.SequenceState.DiveError;
GVL_IHM.DredgingAssist.State.DiveErrorId                := PRG_03_Modes_Cycle.Data.SequenceState.DiveErrorId;
GVL_IHM.DredgingAssist.State.DiveState                  := PRG_03_Modes_Cycle.Data.SequenceState.DiveState;
GVL_IHM.DredgingAssist.State.DiveStepAtFault            := PRG_03_Modes_Cycle.Data.SequenceState.DiveStepAtFault;
GVL_IHM.DredgingAssist.State.BottomTouchConfirmed       := PRG_03_Modes_Cycle.Data.SequenceState.BottomTouchConfirmed;
GVL_IHM.DredgingAssist.State.ExtractionReady             := PRG_03_Modes_Cycle.Data.SequenceState.ExtractionReady;
GVL_IHM.DredgingAssist.State.ExtractionBusy              := PRG_03_Modes_Cycle.Data.SequenceState.ExtractionBusy;
GVL_IHM.DredgingAssist.State.ExtractionDone              := PRG_03_Modes_Cycle.Data.SequenceState.ExtractionDone;
GVL_IHM.DredgingAssist.State.ExtractionError             := PRG_03_Modes_Cycle.Data.SequenceState.ExtractionError;
GVL_IHM.DredgingAssist.State.ExtractionErrorId           := PRG_03_Modes_Cycle.Data.SequenceState.ExtractionErrorId;
GVL_IHM.DredgingAssist.State.ExtractionState             := PRG_03_Modes_Cycle.Data.SequenceState.ExtractionState;
GVL_IHM.DredgingAssist.State.ExtractionStepAtFault       := PRG_03_Modes_Cycle.Data.SequenceState.ExtractionStepAtFault;
GVL_IHM.DredgingAssist.State.OperatorActionId           := PRG_03_Modes_Cycle.Data.SequenceState.OperatorActionId;
GVL_IHM.DredgingAssist.State.OperatorAction             := PRG_03_Modes_Cycle.Data.SequenceState.OperatorAction;
GVL_IHM.DredgingAssist.State.DumpAtTremieArmed           := PRG_03_Modes_Cycle.Data.SequenceState.DumpAtTremieArmed;
GVL_IHM.DredgingAssist.State.DumpAtTremieAssistActive      := PRG_03_Modes_Cycle.Data.SequenceState.DumpAtTremieAssistActive;
GVL_IHM.DredgingAssist.State.DumpAtTremieAtTremie          := PRG_03_Modes_Cycle.Data.SequenceState.DumpAtTremieAtTremie;
GVL_IHM.DredgingAssist.State.DumpAtTremieBucketOpenArmed   := PRG_03_Modes_Cycle.Data.SequenceState.DumpAtTremieBucketOpenArmed;
GVL_IHM.DredgingAssist.State.DumpAtTremieDescentLocked     := PRG_03_Modes_Cycle.Data.SequenceState.DumpAtTremieDescentLocked;
GVL_IHM.DredgingAssist.State.BypassDiveActive            := PRG_03_Modes_Cycle.Data.SequenceState.BypassDiveActive;
GVL_IHM.DredgingAssist.State.BypassKoboldBottomTouched   := PRG_03_Modes_Cycle.Data.SequenceState.BypassKoboldBottomTouched;

instHmiBannerFormatter(
    Enable                := TRUE,
    SimulationModeActive  := GVL_Simulation.SimulationModeActive,
    CurrentMode           := PRG_03_Modes_Cycle.Data.Auth.Mode,
    BothAxesCoupled       := (GVL_IHM.Modes.Cmd.SelJoystickWinch = 0),
    WinchSelected         := GVL_IHM.Modes.Cmd.SelJoystickWinch,
    CycleStep             := GVL_IHM.Cycle.State.CycleStep,
    CycleStateStr         := GVL_IHM.Cycle.State.CycleStateStr,
    CycleErrorId          := PRG_03_Modes_Cycle.Data.SequenceState.Fault.ErrorId,
    CycleStepAtError      := PRG_03_Modes_Cycle.Data.SequenceState.StepAtFault,
    DiveState             := GVL_IHM.DredgingAssist.State.DiveState,
    ExtractionState       := GVL_IHM.DredgingAssist.State.ExtractionState,
    HomingActive          := (NOT PRG_04_Treuils_Benne.Data.WinchM1State.Encoder.Homed) OR (NOT PRG_04_Treuils_Benne.Data.WinchM2State.Encoder.Homed),
    HomingStepM1          := SEL(PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Busy, 0, 1),
    HomingStepM2          := SEL(PRG_02_Acquisition.Data.EncoderM2.Measurement.HomingLifecycle.Busy, 0, 1),
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
    BucketIsClosed              := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsClosed,
    DiveActive                  := GVL_IHM.DredgingAssist.State.DiveBusy,
    TopLimitReached             := GVL_IHM.M1TreuilRetenue.Safety.CableLimitAscent OR GVL_IHM.M2TreuilBenne.Safety.CableLimitAscent,
    CoupledUserRequestDirection := PRG_04_Treuils_Benne.CoupledUserRequestDirection,
    M1LogicRequestDirection     := PRG_04_Treuils_Benne.M1LogicRequestDirection,
    M2LogicRequestDirection     := PRG_04_Treuils_Benne.M2LogicRequestDirection,
    CycleRequestDirection       := PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.ReqDirection,
    DeadmanArmed                := PRG_02_Acquisition.Data.JoystickDeadmanArmed,
    JoystickAtNeutral           := PRG_02_Acquisition.Data.Joystick.AtNeutralXY,
    CycleAutoBusy               := PRG_03_Modes_Cycle.Data.SequenceState.Lifecycle.Busy,
    WinchM1Safety               := GVL_IHM.M1TreuilRetenue.Safety,
    WinchM2Safety               := GVL_IHM.M2TreuilBenne.Safety,
    TranslationSafety           := GVL_IHM.TranslationM3.Safety,
    BucketErrorId               := GVL_IHM.M2TreuilBenne.Bucket.State.ErrorId,
    SyncErrorId                 := GVL_IHM.M1M2Sync.State.ErrorId,
    DiveErrorId                 := GVL_IHM.DredgingAssist.State.DiveErrorId,
    ExtractionErrorId           := GVL_IHM.DredgingAssist.State.ExtractionErrorId,
    EmergencyErrorId            := PRG_06_Outputs.EmergencyDiag.ErrorId,
    RedundancyTestFailed         := PRG_06_Outputs.EmergencyDiag.RedundancyTestFailed,
    EmergencyArmingFailed        := PRG_06_Outputs.EmergencyDiag.ArmFailed,
    AlarmHoldTime               := T#1s,
    Network                     := GVL_IHM.Network
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
    Auth                 := PRG_03_Modes_Cycle.Data.Auth,
    M1LogicRequestSpeedCmd_Pct := PRG_04_Treuils_Benne.Data.M1LogicRequestSpeedCmd_Pct,
    M1LogicRequestDirection := PRG_04_Treuils_Benne.M1LogicRequestDirection,
    M2LogicRequestSpeedCmd_Pct := PRG_04_Treuils_Benne.Data.M2LogicRequestSpeedCmd_Pct,
    M2LogicRequestDirection := PRG_04_Treuils_Benne.M2LogicRequestDirection,
    CoupledUserRequestDirection := PRG_04_Treuils_Benne.CoupledUserRequestDirection,
    CoupledUserRequestActive := PRG_04_Treuils_Benne.CoupledUserRequestActive,
    CycleAutoBusy := PRG_03_Modes_Cycle.Data.SequenceState.Lifecycle.Busy,
    CycleM1SpeedTgt_Pct := PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.SpeedTgtPct,
    CycleM2SpeedTgt_Pct := PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM2.SpeedTgtPct,
    CycleBucketOpen := PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ReqOpen,
    CycleTargetPosition := PRG_03_Modes_Cycle.Data.ReqProgram.ReqTranslation.PositionTgt,
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
    CycleReady           := PRG_03_Modes_Cycle.Data.SequenceState.Ready,
    CycleDone            := PRG_03_Modes_Cycle.Data.SequenceState.Lifecycle.Done,
    CycleError           := PRG_03_Modes_Cycle.Data.SequenceState.Fault.Error,
    CycleErrorId         := PRG_03_Modes_Cycle.Data.SequenceState.Fault.ErrorId,
    CycleStep            := PRG_03_Modes_Cycle.Data.SequenceState.Step,
    CycleStepStr         := PRG_03_Modes_Cycle.Data.SequenceState.StepStr,
    CycleStepAtError     := PRG_03_Modes_Cycle.Data.SequenceState.StepAtFault,
    CycleWaitingForOperator := PRG_03_Modes_Cycle.Data.SequenceState.WaitingForOperator,
    CycleWaitingForProcess := PRG_03_Modes_Cycle.Data.SequenceState.WaitingForProcess,
    CycleOperatorActionId := PRG_03_Modes_Cycle.Data.SequenceState.OperatorActionId,
    CycleOperatorAction := PRG_03_Modes_Cycle.Data.SequenceState.OperatorAction,
    CycleExpectedAxis := PRG_03_Modes_Cycle.Data.SequenceState.ExpectedAxis,
    CycleExpectedDirection := PRG_03_Modes_Cycle.Data.SequenceState.ExpectedDirection,
    CycleStartRequest    := GVL_IHM.Cycle.Cmd.BtnStart,
    CycleAbortRequest    := GVL_IHM.Cycle.Cmd.BtnAbort,
    CycleTargetDepth_M   := GVL_IHM.Cycle.Cfg.SetDepth_M,
    CycleKoboldBottomTouch := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI,
    CycleSpeedMismatchActive := PRG_03_Modes_Cycle.Data.SequenceState.SpeedMismatchActive,
    CycleLimitLegalReached := GVL_IHM.Commun.LimitLegalReached,
    CycleWinchSyncError  := PRG_04_Treuils_Benne.instWinchSync.Fault.Error,
    JoystickDeadmanArmed := PRG_02_Acquisition.Data.JoystickDeadmanArmed,
    JoystickAtNeutral    := PRG_02_Acquisition.Data.Joystick.AtNeutralXY,
    HomedM1              := PRG_02_Acquisition.Data.EncoderM1.Homed,
    HomedM2              := PRG_02_Acquisition.Data.EncoderM2.Homed,
    CfgTopLimitM         := _CommunCfgPersist.CfgCableLimitAscent_M
);

{endregion}
END_PROGRAM
