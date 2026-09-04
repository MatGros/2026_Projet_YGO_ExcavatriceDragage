(* ═══════════════════════════════════════════════════════════════
   🖥️ PRG_07_Supervision — Échanges IHM, Diagnostics et Initialisation Boot
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 7.
   ✅ Regroupe tout le mapping bidirectionnel GVL_IHM / GVL_PERSISTENT.
   ✅ Expose FaultMachineReset_IHM pour tous les programmes du domaine sécurité/métier.
   📄 Docs : DOC/AF/AF_Partie-07_Interface_IHM_v2.3.md
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
    instCfgPersistBridgeCycleMachineHoming  : FB_CfgPersistBridge_CycleMachineHomingCfg;    // * [INST] Pont persistance config cycle homing machine
    instCfgPersistBridgeCycleDiveSearchCfg   : FB_CfgPersistBridge_CycleDiveSearchCfg;   // * [INST] Pont persistance config cycle plongée
    instCfgPersistBridgeCycleExtractionCfg   : FB_CfgPersistBridge_CycleExtractionCfg;   // * [INST] Pont persistance config cycle extraction
    instCfgPersistBridgeCycleDumpAtTremieCfg : FB_CfgPersistBridge_CycleDumpAtTremieCfg; // * [INST] Pont persistance config cycle vidage trémie
    instCfgPersistBridgeCycleAssistToggles  : FB_CfgPersistBridge_CycleAssistToggles;  // * [INST] Pont persistance toggles assistance
    instCfgPersistBridgeCommun         : FB_CfgPersistBridge_CommunCfg;           // * [INST] Pont persistance config commune
    instCfgPersistBridgeBucket         : FB_CfgPersistBridge_BucketCfg;           // * [INST] Pont persistance config benne
    instCfgPersistBridgeWinchM1        : FB_CfgPersistBridge_WinchCfg;            // * [INST] Pont persistance config treuil M1
    instCfgPersistBridgeWinchM2        : FB_CfgPersistBridge_WinchCfg;            // * [INST] Pont persistance config treuil M2
    instCfgPersistBridgeTranslation    : FB_CfgPersistBridge_TranslationCfg;      // * [INST] Pont persistance config translation
    instCfgPersistBridgeJoystick       : FB_CfgPersistBridge_fbJoystick_Cfg;      // * [INST] Pont persistance config joystick
    instCfgPersistBridgeEncoder        : FB_CfgPersistBridge_fbEncoder_Cfg;       // * [INST] Pont persistance config codeur commune M1/M2
    AssistTogglesHmi                   : ST_CycleAssistToggles;                   // . [LOC] Toggles assistance (Hmi du pont toggles, répartis dans les 3 Cmd)
    instDiagIhmHeartbeat   : FB_Diag_IhmHeartbeat;            // * [INST] Surveillance heartbeat IHM
    instPreflight          : FB_Acquisition_Preflight;        // * [INST] Preflight acquisition avant demarrage
    instWinchSymmetry      : FB_Winch_Symmetry;               // * [INST] Diagnostic passif symetrie M1/M2 (observateur strict)
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
    instMirrorBypassNetwork          : FB_MirrorBypassRetain; // * [INST] Miroir bypass Reseau (bus + 5 modules E/S) IHM<->RETAIN

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
    PrevNetworkBypass       : BOOL; // . [LOC] Memoire bypass reseau global (sync bidirectionnel)

    // === 🧪 DÉTECTEURS FRONT SIMULATION BYPASS (pilotage bypass IHM) ===
    SimBypassRise           : R_TRIG; // . [LOC] Front montant SimulationBypassActive
    SimBypassFall           : F_TRIG; // . [LOC] Front descendant SimulationBypassActive
    SimulationBypassEffective : BOOL; // . [LOC] Bypass banc effectif (simulation treuil active uniquement)

    // === 🪜 DIAGNOSTIC % CYCLE (palier→%, borne haute du palier) ===
    CycleM1SpeedTgt_Pct     : REAL;   // . [LOC] Consigne % cycle M1 (StepThreshold_Pct[StepTgt])
    CycleM2SpeedTgt_Pct     : REAL;   // . [LOC] Consigne % cycle M2 (StepThreshold_Pct[StepTgt])

    // === 📊 GEL AFFICHAGE POSITION PENDANT PRESET CODEUR (anti-clignotement IHM) ===
    // Pendant la transaction preset (homing, y compris reference benne fermee), CablePosM
    // transite par une valeur aberrante (compteur qui saute au centre de plage) : les champs
    // Position_M / M2PositionCorrected clignotent a l'ecran. On fige la derniere valeur saine
    // tant que HomingBusy + 2s de stabilisation (AF_Partie-09 §13 : consommateurs de position
    // geles pendant HomingLifecycle.Busy). Affichage seul, aucune decision machine ici.
    M1PosHmiHeld_M          : REAL;   // . [LOC] Position M1 figee (affichage)
    M2PosHmiHeld_M          : REAL;   // . [LOC] Position M2 figee (affichage)
    M2PosCorrectedHmiHeld_M : REAL;   // . [LOC] Position benne corrigee M2 figee (affichage)
    M1HomingDisplaySettle   : TON;    // . [LOC] Prolonge le gel M1 apres retombee HomingBusy
    M2HomingDisplaySettle   : TON;    // . [LOC] Prolonge le gel M2 apres retombee HomingBusy
    M1PosDisplayFrozen      : BOOL;   // . [LOC] Gel affichage position M1 actif
    M2PosDisplayFrozen      : BOOL;   // . [LOC] Gel affichage position M2 actif
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

// M1 = MAITRE pour la position capteur haut : M1 et M2 montent lies au meme capteur,
// on force donc M2 = M1 en continu (IHM + persistant). Regler CfgTopSensorPos_M cote M1
// sur l'IHM ; le champ M2 suit automatiquement et le homing M2 (qui lit
// _WinchM2CfgPersist.CfgTopSensorPos_M) prend la meme valeur. Aucun champ persistant neuf.
GVL_IHM.M2TreuilBenne.Cfg.CfgTopSensorPos_M := GVL_IHM.M1TreuilRetenue.Cfg.CfgTopSensorPos_M;
_WinchM2CfgPersist.CfgTopSensorPos_M       := GVL_IHM.M1TreuilRetenue.Cfg.CfgTopSensorPos_M;

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

instCfgPersistBridgeCycleMachineHoming(Hmi := GVL_IHM.CycleMachineHoming.Cfg, Persist := _CycleMachineHomingCfgPersist);
IF instCfgPersistBridgeCycleMachineHoming.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

// Ponts persistance configs cycle (DiveSearch / Extraction / DumpAtTremie)
instCfgPersistBridgeCycleDiveSearchCfg(Hmi := GVL_IHM.CycleDiveSearch.Cfg, Persist := _CycleDiveSearchCfgPersist);
IF instCfgPersistBridgeCycleDiveSearchCfg.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeCycleExtractionCfg(Hmi := GVL_IHM.CycleExtraction.Cfg, Persist := _CycleExtractionCfgPersist);
IF instCfgPersistBridgeCycleExtractionCfg.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

instCfgPersistBridgeCycleDumpAtTremieCfg(Hmi := GVL_IHM.CycleDumpAtTremie.Cfg, Persist := _CycleDumpAtTremieCfgPersist);
IF instCfgPersistBridgeCycleDumpAtTremieCfg.JustRestored THEN
    GVL_IHM.Commun.ConfigRestoredFromPersistent := TRUE;
END_IF;

// Pont persistance toggles assistance (répartis dans les 3 Cmd, mémorisés via _CycleAssistTogglesPersist)
AssistTogglesHmi.TglEnableDiveSearch         := GVL_IHM.CycleDiveSearch.Cmd.TglEnableDiveSearch;
AssistTogglesHmi.TglEnableExtractionSequence := GVL_IHM.CycleExtraction.Cmd.TglEnableExtractionSequence;
AssistTogglesHmi.TglEnableDumpAtTremie       := GVL_IHM.CycleDumpAtTremie.Cmd.TglEnableDumpAtTremie;
instCfgPersistBridgeCycleAssistToggles(Hmi := AssistTogglesHmi, Persist := _CycleAssistTogglesPersist);
IF instCfgPersistBridgeCycleAssistToggles.JustRestored THEN
    GVL_IHM.CycleDiveSearch.Cmd.TglEnableDiveSearch         := AssistTogglesHmi.TglEnableDiveSearch;
    GVL_IHM.CycleExtraction.Cmd.TglEnableExtractionSequence := AssistTogglesHmi.TglEnableExtractionSequence;
    GVL_IHM.CycleDumpAtTremie.Cmd.TglEnableDumpAtTremie       := AssistTogglesHmi.TglEnableDumpAtTremie;
    GVL_IHM.Commun.ConfigRestoredFromPersistent            := TRUE;
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

// Restauration boot du bypass reseau global (RETAIN), meme pattern que les autres domaines.
// GVL_IHM.Network.Bypass.Global neutralise les diagnostics bus + 5 modules E/S dans
// PRG_02_Acquisition (VH_0008ER, CANopen, EtherCAT). Sans ce relais, BypassNetworkGlobal
// etait orphelin (jamais rejoue vers l'IHM).
IF NOT GVL_IHM.Network.Bypass.Initialized THEN
    IF BypassNetworkGlobal THEN
        GVL_IHM.Network.Bypass.Global := TRUE;
    END_IF;
    GVL_IHM.Network.Bypass.Initialized := TRUE;
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
instMirrorBypassNetwork(Hmi := GVL_IHM.Network.Bypass.Global, RetainVal := BypassNetworkGlobal, Prev := PrevNetworkBypass);

// ---------- §2d. Pilotage des bypass par simulation ----------
// 🧪 PILOTAGE BYPASS IHM PAR SIMULATION (front montant/descendant)
// La simulation emprunte le chemin IHM : le bypass banc ne devient effectif
// que lorsque les trois conditions sont réunies. Sans ce gate, la valeur par
// défaut TRUE de SimulationBypassActive pouvait armer BypassProcess en MAINT_N2
// sur une machine réelle (ou avant l'activation du domaine treuil simulé).
SimulationBypassEffective := GVL_Simulation.SimulationModeActive
                             AND GVL_Simulation.SimWinchActive
                             AND GVL_Simulation.SimulationBypassActive;
SimBypassRise(CLK := SimulationBypassEffective);
SimBypassFall(CLK := SimulationBypassEffective);

IF SimBypassRise.Q THEN
    // 🧪 Bypass sim étendu aux tests Meca (Meca A-E via Safety ; NoMovement/
    // OppositeDir via Process) pour travailler sans faux blocage en banc.
    // Les trois limites banc demandées sont écrites depuis leur producteur unique.
    // Elles restent strictement inertes hors SimulationBypassEffective.
    GVL_IHM.M1TreuilRetenue.Bypass.Safety  := TRUE;
    GVL_IHM.M1TreuilRetenue.Bypass.Process := TRUE;
    GVL_IHM.M2TreuilBenne.Bypass.Safety    := TRUE;
    GVL_IHM.M2TreuilBenne.Bypass.Process   := TRUE;
    GVL_IHM.Commun.Bypass.TopLimitSwitch   := TRUE;
    GVL_IHM.Commun.Bypass.TopLimitSoftware := TRUE;
    GVL_IHM.Commun.Bypass.CableLimitSwitch := TRUE;
END_IF;
IF SimBypassFall.Q THEN
    GVL_IHM.Commun.Bypass.TopLimitSwitch   := FALSE;
    GVL_IHM.Commun.Bypass.TopLimitSoftware := FALSE;
    GVL_IHM.Commun.Bypass.CableLimitSwitch := FALSE;
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
    AND ((PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M)
      OR (PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM <= _CommunCfgPersist.LimitLegalDepthMinAllowed_M));
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
    M1PositionInBounds        := NOT PRG_02_Acquisition.Data.EncoderM1.Measurement.EncoderIncoherent,
    M2PositionInBounds        := NOT PRG_02_Acquisition.Data.EncoderM2.Measurement.EncoderIncoherent
);
GVL_IHM.Commun.Preflight.PreflightOk      := instPreflight.PreflightOk;
GVL_IHM.Commun.Preflight.PreflightDone    := instPreflight.PreflightDone;
GVL_IHM.Commun.Preflight.PreflightBusy    := instPreflight.PreflightBusy;
GVL_IHM.Commun.Preflight.PreflightErrorId := instPreflight.PreflightErrorId;

// ---------- §3c-bis. Diagnostic passif symétrie M1/M2 (FB_Winch_Symmetry) ----------
// ⚖️ Observateur STRICT (AF-10 §7.3bis) : aucune écriture de commande, de
// sécurité ou de mouvement. Sources : états publics M1/M2 (PRG_04 Data), encodeurs
// (PRG_02), synchro (PRG_04). Config & données persistantes : GVL_PERSISTENT.
instWinchSymmetry(
    Reset           := GVL_IHM.Commun.WinchSymmetry.BtnReset,
    M1CommandActive := PRG_04_Treuils_Benne.Data.WinchM1State.Busy,
    M2CommandActive := PRG_04_Treuils_Benne.Data.WinchM2State.Busy,
    M1Direction     := SEL(PRG_04_Treuils_Benne.Data.WinchM1State.CommandedAscent, SEL(PRG_04_Treuils_Benne.Data.WinchM1State.CommandedDescend, 0, -1), 1),
    M2Direction     := SEL(PRG_04_Treuils_Benne.Data.WinchM2State.CommandedAscent, SEL(PRG_04_Treuils_Benne.Data.WinchM2State.CommandedDescend, 0, -1), 1),
    M1BrakeCmd      := PRG_04_Treuils_Benne.Data.WinchM1State.BrakeCmd,
    M2BrakeCmd      := PRG_04_Treuils_Benne.Data.WinchM2State.BrakeCmd,
    M1BrakeApplied  := NOT PRG_04_Treuils_Benne.Data.WinchM1State.BrakeCommandOpenConfirmed,
    M2BrakeApplied  := NOT PRG_04_Treuils_Benne.Data.WinchM2State.BrakeCommandOpenConfirmed,
    M1Position_M    := PRG_04_Treuils_Benne.Data.WinchM1State.Position_M,
    M2Position_M    := PRG_04_Treuils_Benne.Data.WinchM2State.Position_M,
    M1Speed_Mps     := PRG_04_Treuils_Benne.Data.WinchM1State.MeasuredSpeed_Mps,
    M2Speed_Mps     := PRG_04_Treuils_Benne.Data.WinchM2State.MeasuredSpeed_Mps,
    SyncDeviation_M := ABS(PRG_04_Treuils_Benne.Data.WinchSyncSignedDeltaPosM),
    Config          := _WinchSymmetryCfgPersist,
    Data            := _WinchSymmetryDataPersist
);
// Publication IHM (ST_WinchSymmetryHMI via GVL_IHM.Commun.WinchSymmetry) — lecture seule.
GVL_IHM.Commun.WinchSymmetry.SymmetryOk        := instWinchSymmetry.SymmetryOk;
GVL_IHM.Commun.WinchSymmetry.SymmetryValid     := instWinchSymmetry.SymmetryValid;
GVL_IHM.Commun.WinchSymmetry.DeltaStartDelay_Ms       := _WinchSymmetryDataPersist.DeltaStartDelay_Ms;
GVL_IHM.Commun.WinchSymmetry.DeltaBrakeReleaseTime_Ms := _WinchSymmetryDataPersist.DeltaBrakeReleaseTime_Ms;
GVL_IHM.Commun.WinchSymmetry.DeltaBrakeApplyTime_Ms   := _WinchSymmetryDataPersist.DeltaBrakeApplyTime_Ms;
GVL_IHM.Commun.WinchSymmetry.DeltaStopDistance_M      := UDINT_TO_REAL(_WinchSymmetryDataPersist.DeltaStopDistance_Mm) / 1000.0;
GVL_IHM.Commun.WinchSymmetry.DeltaStopTime_Ms         := _WinchSymmetryDataPersist.DeltaStopTime_Ms;
GVL_IHM.Commun.WinchSymmetry.MaxSyncDeviation_M       := _WinchSymmetryDataPersist.MaxSyncDeviation_M;

// ---------- §3d. Bypass simulation (retours simulés vers IHM) ----------
GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback   := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive;
GVL_IHM.TranslationM3.Bypass.ContactorFeedback   := GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimTranslationActive;
// Ces deux indicateurs ne décrivent PAS le domaine simulation : ils publient
// l'état des bypasss réellement consommés par FB_Safety_Winch.
GVL_IHM.Commun.SimSlackCableBypassActive         := GVL_IHM.Commun.Bypass.SlackCable;
GVL_IHM.Commun.SimTopSensorBypassActive          := GVL_IHM.Commun.Bypass.TopLimitSwitch;
GVL_IHM.Commun.WinchInputSourceChanged           := PRG_02_Acquisition.Data.InputSource.WinchInputSourceChanged;

// ---------- §3e. Structures d'état & safety (recopies directes des bus) ----------
GVL_IHM.M1TreuilRetenue.State := PRG_04_Treuils_Benne.Data.WinchM1State;
GVL_IHM.M2TreuilBenne.State := PRG_04_Treuils_Benne.Data.WinchM2State;
GVL_IHM.M1TreuilRetenue.Safety := PRG_04_Treuils_Benne.Data.WinchM1Safety;
GVL_IHM.M2TreuilBenne.Safety := PRG_04_Treuils_Benne.Data.WinchM2Safety;
GVL_IHM.M1M2Sync.State := PRG_04_Treuils_Benne.Data.SyncState;
GVL_IHM.M2TreuilBenne.Bucket.State := PRG_04_Treuils_Benne.Data.BucketState;
GVL_IHM.TranslationM3.State := PRG_05_Translation.Data.TranslationState;

// ---------- §3e-bis. Gel affichage position pendant transaction preset codeur (anti-clignotement, voir VAR) ----------
M1HomingDisplaySettle(IN := NOT GVL_IHM.M1TreuilRetenue.State.Encoder.HomingBusy, PT := T#2s);
M2HomingDisplaySettle(IN := NOT GVL_IHM.M2TreuilBenne.State.Encoder.HomingBusy, PT := T#2s);
M1PosDisplayFrozen := GVL_IHM.M1TreuilRetenue.State.Encoder.HomingBusy OR NOT M1HomingDisplaySettle.Q;
M2PosDisplayFrozen := GVL_IHM.M2TreuilBenne.State.Encoder.HomingBusy OR NOT M2HomingDisplaySettle.Q;

IF M1PosDisplayFrozen THEN
    GVL_IHM.M1TreuilRetenue.State.Position_M := M1PosHmiHeld_M;
ELSE
    M1PosHmiHeld_M := GVL_IHM.M1TreuilRetenue.State.Position_M;
END_IF;

IF M2PosDisplayFrozen THEN
    GVL_IHM.M2TreuilBenne.State.Position_M                 := M2PosHmiHeld_M;
    GVL_IHM.M2TreuilBenne.Bucket.State.M2PositionCorrected := M2PosCorrectedHmiHeld_M;
ELSE
    M2PosHmiHeld_M          := GVL_IHM.M2TreuilBenne.State.Position_M;
    M2PosCorrectedHmiHeld_M := GVL_IHM.M2TreuilBenne.Bucket.State.M2PositionCorrected;
END_IF;
GVL_IHM.TranslationM3.Safety := PRG_05_Translation.Data.TranslationSafety;

GVL_IHM.Modes.State.CurrentMode := PRG_03_Modes_Cycle.Data.Auth.Mode;
// — Chaîne AU / sécurité : sortie de Modes.State vers GVL_IHM.Emergency —
// Point de vue IHM : Cmd = boutons (produits par l'IHM), State = état AU
// (champs plats) + cmd FB AU (MaintainA/B_Cmd, ArmPulse_Cmd) + Diag interne.
GVL_IHM.Emergency.State.ChainOk     := PRG_06_Outputs.EmergencyState.ChainOk;
GVL_IHM.Emergency.State.ContactorOk := PRG_06_Outputs.EmergencyState.ContactorOk;
GVL_IHM.Emergency.State.Step        := PRG_06_Outputs.EmergencyState.Step;
GVL_IHM.Emergency.State.Armable     := PRG_06_Outputs.EmergencyState.Armable;
GVL_IHM.Emergency.State.ArmingBusy  := PRG_06_Outputs.EmergencyState.ArmingBusy;
GVL_IHM.Emergency.State.MaintainA_Cmd := PRG_06_Outputs.PowerKeepAliveACmd;
GVL_IHM.Emergency.State.MaintainB_Cmd := PRG_06_Outputs.PowerKeepAliveBCmd;
GVL_IHM.Emergency.State.ArmPulse_Cmd  := PRG_06_Outputs.EmergencyArmingCmd;
GVL_IHM.Emergency.State.Diag := PRG_06_Outputs.EmergencyDiag;
// États publics FB AU (Ready/Done/Fault/OperatorMessage) — miroir Status du FB
// (produits par PRG_06). Busy non exposé : redondant avec ArmingBusy (déjà câblé).
GVL_IHM.Emergency.State.Ready := PRG_06_Outputs.EmergencyReady;
GVL_IHM.Emergency.State.Done := PRG_06_Outputs.EmergencyDone;
GVL_IHM.Emergency.State.Fault := PRG_06_Outputs.EmergencyFault;
GVL_IHM.Emergency.State.OperatorMessage := PRG_06_Outputs.EmergencyOperatorMessage;
// OR avec les défauts d'arbitrage de mode (refus Semi-Auto, bascule de mode refusée) —
// publiés par PRG_03 : sans eux ces refus restaient silencieux pour l'opérateur.
GVL_IHM.Modes.State.AnyFaultActive := PRG_06_Outputs.EmergencyDiag.Error
                                      OR PRG_02_Acquisition.Data.InputModules.Fault
                                      OR PRG_03_Modes_Cycle.Data.ModesFault.Error
                                      OR PRG_03_Modes_Cycle.Data.ModesFault.Latched
                                      OR GVL_IHM.M1TreuilRetenue.Safety.Error
                                      OR GVL_IHM.M2TreuilBenne.Safety.Error
                                      OR GVL_IHM.TranslationM3.Safety.Error
                                      OR GVL_IHM.M1M2Sync.State.Error
                                      OR GVL_IHM.M2TreuilBenne.Bucket.State.Error
                                      OR GVL_IHM.Cycle.State.Error
                                      OR GVL_IHM.JOY1Joystick.State.Error;
// Miroir IHM des états de maintenance (AF-05 §4bis, producteur FB_Modes via PRG_03)
GVL_IHM.Modes.State.ModeChangePendingBlocked := PRG_03_Modes_Cycle.Data.Auth.ModeChangePendingBlocked;
GVL_IHM.Modes.State.ModeChangeBlockReason := PRG_03_Modes_Cycle.Data.Auth.ModeChangeBlockReason;
GVL_IHM.Modes.State.M1ContactorsReleased := PRG_03_Modes_Cycle.Data.Auth.M1ContactorsReleased;
GVL_IHM.Modes.State.M1BrakeApplied := PRG_03_Modes_Cycle.Data.Auth.M1BrakeApplied;
GVL_IHM.Modes.State.M1SpeedLow := PRG_03_Modes_Cycle.Data.Auth.M1SpeedLow;
GVL_IHM.Modes.State.M2ContactorsReleased := PRG_03_Modes_Cycle.Data.Auth.M2ContactorsReleased;
GVL_IHM.Modes.State.M2BrakeApplied := PRG_03_Modes_Cycle.Data.Auth.M2BrakeApplied;
GVL_IHM.Modes.State.M2SpeedLow := PRG_03_Modes_Cycle.Data.Auth.M2SpeedLow;
GVL_IHM.Modes.State.HomingRequiredM1 := PRG_03_Modes_Cycle.Data.Auth.HomingRequiredM1;
GVL_IHM.Modes.State.HomingRequiredM2 := PRG_03_Modes_Cycle.Data.Auth.HomingRequiredM2;
// Etat publie du cycle de referencement machine (visu IHM) - recopie whole-struct.
GVL_IHM.CycleMachineHoming.State := PRG_02_Acquisition.Data.MachineHoming;

// ---------- §3f. État joystick & réseau (diagnostic bus) ----------
GVL_IHM.JOY1Joystick.State.RawX := PRG_02_Acquisition.HwIn.Operator.JoyXRaw_ANA1;
GVL_IHM.JOY1Joystick.State.RawY := PRG_02_Acquisition.HwIn.Operator.JoyYRaw_ANA2;
GVL_IHM.JOY1Joystick.State.RawButton := PRG_02_Acquisition.HwIn.Operator.JoyBtnRaw;
GVL_IHM.JOY1Joystick.State.AxisCmdX := PRG_02_Acquisition.Data.Joystick.AxisX;
GVL_IHM.JOY1Joystick.State.AxisCmdY := PRG_02_Acquisition.Data.Joystick.AxisY;
GVL_IHM.JOY1Joystick.State.NeutralXAct := PRG_02_Acquisition.Data.Joystick.NeutralXAct;
GVL_IHM.JOY1Joystick.State.NeutralYAct := PRG_02_Acquisition.Data.Joystick.NeutralYAct;
GVL_IHM.JOY1Joystick.State.DeadmanArmed := PRG_02_Acquisition.Data.Joystick.DeadmanArmed;
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
GVL_IHM.Network.InputModules.LocalDigitalIoOk := PRG_02_Acquisition.Data.InputModules.LocalDigitalIoOk;
GVL_IHM.Network.InputModules.Vh0800EndOk      := PRG_02_Acquisition.Data.InputModules.Vh0800EndOk;
GVL_IHM.Network.InputModules.Vh0808EtpOk      := PRG_02_Acquisition.Data.InputModules.Vh0808EtpOk;
GVL_IHM.Network.InputModules.Vh0008ErOk       := PRG_02_Acquisition.Data.InputModules.Vh0008ErOk;
GVL_IHM.Network.InputModules.Vh0008Er1Ok      := PRG_02_Acquisition.Data.InputModules.Vh0008Er1Ok;
GVL_IHM.Network.InputModules.Fault            := PRG_02_Acquisition.Data.InputModules.Fault;

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
GVL_IHM.Cycle.State.CurrentCycleElapsed    := PRG_03_Modes_Cycle.Data.SequenceState.CurrentCycleElapsed;
GVL_IHM.Cycle.State.LastCycleDuration      := PRG_03_Modes_Cycle.Data.SequenceState.LastCycleDuration;
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
// Position cycle : meme gel affichage que M1TreuilRetenue/M2TreuilBenne pendant le preset codeur.
GVL_IHM.Cycle.State.M1Position_M           := SEL(M1PosDisplayFrozen, PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM, M1PosHmiHeld_M);
GVL_IHM.Cycle.State.M2Position_M           := SEL(M2PosDisplayFrozen, PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM, M2PosHmiHeld_M);
GVL_IHM.Cycle.State.DeadmanArmed           := PRG_02_Acquisition.Data.Joystick.DeadmanArmed;
// 🕹️ JoystickDeflected = déflexion joystick seule (SANS homme-mort) — même signal que
// JoystickDeflected (FB_CycleSemiAuto, alimenté par PRG_03) = NOT AtNeutralXY. Un seul signal
// « joystick défléchi » est projeté à l'IHM.
GVL_IHM.Cycle.State.JoystickDeflected   := NOT PRG_02_Acquisition.Data.Joystick.AtNeutralXY;

// Projection Assistance Dragage (CycleDiveSearch / CycleExtraction / CycleDumpAtTremie)
GVL_IHM.CycleDiveSearch.State.DiveReady                  := PRG_03_Modes_Cycle.Data.SequenceState.DiveReady;
GVL_IHM.CycleDiveSearch.State.DiveBusy                   := PRG_03_Modes_Cycle.Data.SequenceState.DiveBusy;
GVL_IHM.CycleDiveSearch.State.DiveDone                   := PRG_03_Modes_Cycle.Data.SequenceState.DiveDone;
GVL_IHM.CycleDiveSearch.State.DiveError                  := PRG_03_Modes_Cycle.Data.SequenceState.DiveError;
GVL_IHM.CycleDiveSearch.State.DiveErrorId                := PRG_03_Modes_Cycle.Data.SequenceState.DiveErrorId;
GVL_IHM.CycleDiveSearch.State.DiveState                  := PRG_03_Modes_Cycle.Data.SequenceState.DiveState;
GVL_IHM.CycleDiveSearch.State.DiveStepAtFault            := PRG_03_Modes_Cycle.Data.SequenceState.DiveStepAtFault;
GVL_IHM.CycleDiveSearch.State.BottomTouchConfirmed       := PRG_03_Modes_Cycle.Data.SequenceState.BottomTouchConfirmed;
GVL_IHM.CycleExtraction.State.ExtractionReady             := PRG_03_Modes_Cycle.Data.SequenceState.ExtractionReady;
GVL_IHM.CycleExtraction.State.ExtractionBusy              := PRG_03_Modes_Cycle.Data.SequenceState.ExtractionBusy;
GVL_IHM.CycleExtraction.State.ExtractionDone              := PRG_03_Modes_Cycle.Data.SequenceState.ExtractionDone;
GVL_IHM.CycleExtraction.State.ExtractionError             := PRG_03_Modes_Cycle.Data.SequenceState.ExtractionError;
GVL_IHM.CycleExtraction.State.ExtractionErrorId           := PRG_03_Modes_Cycle.Data.SequenceState.ExtractionErrorId;
GVL_IHM.CycleExtraction.State.ExtractionState             := PRG_03_Modes_Cycle.Data.SequenceState.ExtractionState;
GVL_IHM.CycleExtraction.State.ExtractionStepAtFault       := PRG_03_Modes_Cycle.Data.SequenceState.ExtractionStepAtFault;
GVL_IHM.CycleDiveSearch.State.OperatorActionId           := PRG_03_Modes_Cycle.Data.SequenceState.OperatorActionId;
GVL_IHM.CycleDiveSearch.State.OperatorAction             := PRG_03_Modes_Cycle.Data.SequenceState.OperatorAction;
GVL_IHM.CycleDumpAtTremie.State.DumpAtTremieArmed           := PRG_03_Modes_Cycle.Data.SequenceState.DumpAtTremieArmed;
GVL_IHM.CycleDumpAtTremie.State.DumpAtTremieAssistActive      := PRG_03_Modes_Cycle.Data.SequenceState.DumpAtTremieAssistActive;
GVL_IHM.CycleDumpAtTremie.State.DumpAtTremieAtTremie          := PRG_03_Modes_Cycle.Data.SequenceState.DumpAtTremieAtTremie;
GVL_IHM.CycleDumpAtTremie.State.DumpAtTremieBucketOpenArmed   := PRG_03_Modes_Cycle.Data.SequenceState.DumpAtTremieBucketOpenArmed;
GVL_IHM.CycleDumpAtTremie.State.DumpAtTremieDescentLocked     := PRG_03_Modes_Cycle.Data.SequenceState.DumpAtTremieDescentLocked;
GVL_IHM.CycleDiveSearch.State.BypassDiveActive            := PRG_03_Modes_Cycle.Data.SequenceState.BypassDiveActive;
GVL_IHM.CycleDiveSearch.State.BypassKoboldBottomTouched   := PRG_03_Modes_Cycle.Data.SequenceState.BypassKoboldBottomTouched;

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
    DiveState             := GVL_IHM.CycleDiveSearch.State.DiveState,
    ExtractionState       := GVL_IHM.CycleExtraction.State.ExtractionState,
    MachineHomingStep        := PRG_02_Acquisition.Data.MachineHoming.Step,
    MachineHomingInstruction := PRG_02_Acquisition.Data.MachineHoming.Instruction,
    BypassGlobalActive    := GVL_IHM.Network.Bypass.Global,
    BypassWinchM1Active   := GVL_IHM.M1TreuilRetenue.Bypass.Global,
    BypassWinchM2Active   := GVL_IHM.M2TreuilBenne.Bypass.Global,
    BypassTranslation     := GVL_IHM.TranslationM3.Bypass.Global,
    BypassSyncActive      := GVL_IHM.M1M2Sync.Bypass.Global,
    SyncDegradedActive    := PRG_04_Treuils_Benne.Data.SyncState.SyncDeviationWarn,
    LegalLimitReached     := GVL_IHM.Commun.LimitLegalReached,
    ModeChangePendingBlocked := PRG_03_Modes_Cycle.Data.Auth.ModeChangePendingBlocked,
    ModeChangeBlockReason    := PRG_03_Modes_Cycle.Data.Auth.ModeChangeBlockReason,
    EmergencyChainClosed  := PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    PowerCutOffActiveAny        := PRG_06_Outputs.PowerCutOffActive,
    SafeStopActive              := GVL_IHM.M1TreuilRetenue.Safety.SafeStop OR GVL_IHM.M2TreuilBenne.Safety.SafeStop,
    DescendPermit               := GVL_IHM.M1TreuilRetenue.Safety.DescendPermit AND GVL_IHM.M2TreuilBenne.Safety.DescendPermit,
    AscentPermit                := GVL_IHM.M1TreuilRetenue.Safety.AscentPermit AND GVL_IHM.M2TreuilBenne.Safety.AscentPermit,
    BucketIsOpen                := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsOpen,
    BucketIsClosed              := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsClosed,
    DiveActive                  := GVL_IHM.CycleDiveSearch.State.DiveBusy,
    TopLimitReached             := GVL_IHM.M1TreuilRetenue.Safety.CableLimitAscent OR GVL_IHM.M2TreuilBenne.Safety.CableLimitAscent,
    WinchBothMotionDirection := SEL(PRG_03_Modes_Cycle.Data.WinchBothIntent.ReqAscent, SEL(PRG_03_Modes_Cycle.Data.WinchBothIntent.ReqDescend, 0, -1), 1),
    M1LogicRequestDirection := SEL(PRG_04_Treuils_Benne.Data.WinchM1State.CommandedAscent, SEL(PRG_04_Treuils_Benne.Data.WinchM1State.CommandedDescend, 0, -1), 1),
    M2LogicRequestDirection := SEL(PRG_04_Treuils_Benne.Data.WinchM2State.CommandedAscent, SEL(PRG_04_Treuils_Benne.Data.WinchM2State.CommandedDescend, 0, -1), 1),
    CycleRequestDirection := SEL(PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.ReqAscent, SEL(PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.ReqDescend, 0, -1), 1),
    DeadmanArmed                := PRG_02_Acquisition.Data.Joystick.DeadmanArmed,
    JoystickAtNeutral           := PRG_02_Acquisition.Data.Joystick.AtNeutralXY,
    CycleAutoBusy               := PRG_03_Modes_Cycle.Data.SequenceState.Lifecycle.Busy,
    M3AtP1                      := GVL_IHM.TranslationM3.State.AtP1,
    M3StatusText                := GVL_IHM.TranslationM3.State.M3StatusText,
    TranslationMotionErrorId    := GVL_IHM.TranslationM3.State.ErrorId,
    TranslationFinalInterlockErrorId := GVL_IHM.TranslationM3.State.FinalInterlockErrorId,
    WinchDescentLockedByM3 := PRG_03_Modes_Cycle.Data.SequenceState.DumpAtTremieDescentLocked,
    WinchM1Safety               := GVL_IHM.M1TreuilRetenue.Safety,
    WinchM2Safety               := GVL_IHM.M2TreuilBenne.Safety,
    TranslationSafety           := GVL_IHM.TranslationM3.Safety,
    BucketErrorId               := GVL_IHM.M2TreuilBenne.Bucket.State.ErrorId,
    SyncErrorId                 := GVL_IHM.M1M2Sync.State.ErrorId,
    SyncContactorDiag           := PRG_06_Outputs.Data.SyncContactorDiag,
    DiveErrorId                 := GVL_IHM.CycleDiveSearch.State.DiveErrorId,
    ExtractionErrorId           := GVL_IHM.CycleExtraction.State.ExtractionErrorId,
    EmergencyErrorId            := PRG_06_Outputs.EmergencyDiag.ErrorId,
    RedundancyTestFailed         := PRG_06_Outputs.EmergencyDiag.RedundancyTestFailed,
    EmergencyArmingFailed        := PRG_06_Outputs.EmergencyDiag.ArmFailed,
    ArmingSeqStep                := PRG_06_Outputs.EmergencyState.Step,
    LastAbortCause               := PRG_06_Outputs.EmergencyDiag.LastAbortCause,
    Reset                        := FaultMachineReset_IHM,
    AlarmHoldTime               := T#1s,
    Network                     := GVL_IHM.Network
);
GVL_IHM.Banner := instHmiBannerFormatter.Banner;

{endregion}

{region "§4 Vue depannage lecture seule"}
// === 🕵️♂️ §4 VUE DÉPANNAGE (lecture seule stricte) ===

// 🪜 Diagnostic % cycle (palier→%, borne haute du palier) — même patron que PRG_04
// (M1LogicRequestSpeedCmd_Pct). StepTgt=0 (arrêt) → 0.0 (hors bornes du tableau 1..5).
IF (PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.StepTgt >= 1) AND (PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.StepTgt <= 5) THEN
    CycleM1SpeedTgt_Pct := _WinchSpeedStepTable.StepThreshold_Pct[PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1.StepTgt];
ELSE
    CycleM1SpeedTgt_Pct := 0.0;
END_IF;
IF (PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM2.StepTgt >= 1) AND (PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM2.StepTgt <= 5) THEN
    CycleM2SpeedTgt_Pct := _WinchSpeedStepTable.StepThreshold_Pct[PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM2.StepTgt];
ELSE
    CycleM2SpeedTgt_Pct := 0.0;
END_IF;

// Vue unique lecture seule : les champs recopies sont les permis reellement produits/consommes.
// Aucun mouvement ne lit GVL_IHM.Permits ; elle sert uniquement a l'IHM et au troubleshooting.
GVL_IHM.Permits.ArmingPermit := PRG_04_Treuils_Benne.Data.ArmingPermit;
GVL_IHM.Permits.M1SafetyAscentPermit := PRG_04_Treuils_Benne.Data.WinchM1Safety.AscentPermit;
GVL_IHM.Permits.M1SafetyDescendPermit := PRG_04_Treuils_Benne.Data.WinchM1Safety.DescendPermit;
GVL_IHM.Permits.M1ProcessAscentPermit := PRG_04_Treuils_Benne.Data.ProcessPermitM1_Ascent;
GVL_IHM.Permits.M1ProcessDescendPermit := PRG_04_Treuils_Benne.Data.ProcessPermitM1_Descend;
GVL_IHM.Permits.EffectivePermitM1_Ascent := PRG_04_Treuils_Benne.Data.TraceM1.AscentPermitEffective;
GVL_IHM.Permits.EffectivePermitM1_Descend := PRG_04_Treuils_Benne.Data.TraceM1.DescendPermitEffective;
GVL_IHM.Permits.AppliedPermitM1_Ascent := PRG_04_Treuils_Benne.Data.TraceM1.AscentPermitApplied;
GVL_IHM.Permits.AppliedPermitM1_Descend := PRG_04_Treuils_Benne.Data.TraceM1.DescendPermitApplied;
GVL_IHM.Permits.M1FinalPermitBlocked := PRG_04_Treuils_Benne.Data.TraceM1.FinalPermitBlocked;
GVL_IHM.Permits.M2SafetyAscentPermit := PRG_04_Treuils_Benne.Data.WinchM2Safety.AscentPermit;
GVL_IHM.Permits.M2SafetyDescendPermit := PRG_04_Treuils_Benne.Data.WinchM2Safety.DescendPermit;
GVL_IHM.Permits.M2ProcessAscentPermit := PRG_04_Treuils_Benne.Data.ProcessPermitM2_Ascent;
GVL_IHM.Permits.M2ProcessDescendPermit := PRG_04_Treuils_Benne.Data.ProcessPermitM2_Descend;
GVL_IHM.Permits.EffectivePermitM2_Ascent := PRG_04_Treuils_Benne.Data.TraceM2.AscentPermitEffective;
GVL_IHM.Permits.EffectivePermitM2_Descend := PRG_04_Treuils_Benne.Data.TraceM2.DescendPermitEffective;
GVL_IHM.Permits.AppliedPermitM2_Ascent := PRG_04_Treuils_Benne.Data.TraceM2.AscentPermitApplied;
GVL_IHM.Permits.AppliedPermitM2_Descend := PRG_04_Treuils_Benne.Data.TraceM2.DescendPermitApplied;
GVL_IHM.Permits.M2FinalPermitBlocked := PRG_04_Treuils_Benne.Data.TraceM2.FinalPermitBlocked;
GVL_IHM.Permits.BothActive := PRG_04_Treuils_Benne.Data.BothActive;
GVL_IHM.Permits.BothBlocked := PRG_04_Treuils_Benne.Data.BothBlocked;
GVL_IHM.Permits.BothBlockReason := PRG_04_Treuils_Benne.Data.BothBlockReason;
GVL_IHM.Permits.EffectivePermitM3_Tremie := PRG_05_Translation.Data.TranslationTrace.EffectivePermitM3_Tremie;
GVL_IHM.Permits.EffectivePermitM3_Maintenance := PRG_05_Translation.Data.TranslationTrace.EffectivePermitM3_Maintenance;
GVL_IHM.Permits.M3MotionPermitEffective := PRG_05_Translation.Data.TranslationTrace.MotionPermitEffective;
GVL_IHM.Permits.DiveDescendPermit := PRG_04_Treuils_Benne.Data.DescendPermitDiveBucketOpen;
GVL_IHM.Permits.ExtractionAscentPermit := PRG_04_Treuils_Benne.Data.ExtractionAscentPermit;
GVL_IHM.Permits.ExtractionAssistActive := PRG_04_Treuils_Benne.Data.ExtractionAssistActive;
GVL_IHM.Permits.BucketOpenRequestActive := PRG_04_Treuils_Benne.Data.BucketState.OpenActive;
GVL_IHM.Permits.BucketCloseRequestActive := PRG_04_Treuils_Benne.Data.BucketState.CloseActive;
GVL_IHM.Permits.BucketMotionBlocked := PRG_04_Treuils_Benne.Data.BucketState.CoupledMotionBlockedByBucket;
GVL_IHM.Permits.EffectivePermitBucket_Open := PRG_04_Treuils_Benne.Data.EffectivePermitBucket_Open;
GVL_IHM.Permits.EffectivePermitBucket_Close := PRG_04_Treuils_Benne.Data.EffectivePermitBucket_Close;

instTroubleshootingView(
    Enable               := TRUE,
    HwIn                 := PRG_02_Acquisition.HwIn,
    HwReal               := PRG_02_Acquisition.HwReal,
    InputModuleFault     := PRG_02_Acquisition.Data.InputModules.Fault,
    LocalDigitalIoOk     := PRG_02_Acquisition.Data.InputModules.LocalDigitalIoOk,
    Vh0800EndOk          := PRG_02_Acquisition.Data.InputModules.Vh0800EndOk,
    Vh0808EtpOk          := PRG_02_Acquisition.Data.InputModules.Vh0808EtpOk,
    Auth                 := PRG_03_Modes_Cycle.Data.Auth,
    M1LogicRequestSpeedCmd_Pct := PRG_04_Treuils_Benne.Data.M1LogicRequestSpeedCmd_Pct,
    M1LogicRequestDirection := SEL(PRG_04_Treuils_Benne.Data.WinchM1State.CommandedAscent, SEL(PRG_04_Treuils_Benne.Data.WinchM1State.CommandedDescend, 0, -1), 1),
    M2LogicRequestSpeedCmd_Pct := PRG_04_Treuils_Benne.Data.M2LogicRequestSpeedCmd_Pct,
    M2LogicRequestDirection := SEL(PRG_04_Treuils_Benne.Data.WinchM2State.CommandedAscent, SEL(PRG_04_Treuils_Benne.Data.WinchM2State.CommandedDescend, 0, -1), 1),
    WinchBothMotionDirection := SEL(PRG_03_Modes_Cycle.Data.WinchBothIntent.ReqAscent, SEL(PRG_03_Modes_Cycle.Data.WinchBothIntent.ReqDescend, 0, -1), 1),
    WinchBothMotionActive := PRG_04_Treuils_Benne.WinchBothMotionActive,
    CycleAutoBusy := PRG_03_Modes_Cycle.Data.SequenceState.Lifecycle.Busy,
    CycleM1SpeedTgt_Pct := CycleM1SpeedTgt_Pct,
    CycleM2SpeedTgt_Pct := CycleM2SpeedTgt_Pct,
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
    CycleDiveSearch      := GVL_IHM.CycleDiveSearch,
    CycleExtraction      := GVL_IHM.CycleExtraction,
    CycleDumpAtTremie    := GVL_IHM.CycleDumpAtTremie,
    JoystickHMI          := GVL_IHM.JOY1Joystick,
    Permits              := GVL_IHM.Permits,
    EmergencyState       := PRG_06_Outputs.EmergencyState,
    EmergencyDiag        := PRG_06_Outputs.EmergencyDiag,
    PowerCutOffActive    := PRG_06_Outputs.PowerCutOffActive,
    ArmingPulseActive    := PRG_06_Outputs.Data.EmergencyArmingCmd,
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
    JoystickDeadmanArmed := PRG_02_Acquisition.Data.Joystick.DeadmanArmed,
    JoystickAtNeutral    := PRG_02_Acquisition.Data.Joystick.AtNeutralXY,
    HomedM1              := PRG_02_Acquisition.Data.EncoderM1.Homed,
    HomedM2              := PRG_02_Acquisition.Data.EncoderM2.Homed,
    CfgTopLimitM         := _CommunCfgPersist.CfgCableLimitAscent_M,
    WinchM1Trace         := PRG_04_Treuils_Benne.Data.TraceM1,
    WinchM2Trace         := PRG_04_Treuils_Benne.Data.TraceM2,
    TranslationTrace     := PRG_05_Translation.Data.TranslationTrace
);

{endregion}
END_PROGRAM
