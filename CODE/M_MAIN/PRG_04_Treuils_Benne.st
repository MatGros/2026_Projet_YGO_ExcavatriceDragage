(* ═══════════════════════════════════════════════════════════════
   🪝 PRG_04_Treuils_Benne — Commande des Treuils M1 (moteur de retenue) / M2 (moteur Benne), Synchro et Benne
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 4 (après PRG_03_Modes_Cycle).
   ✅ Arbitre entre les commandes Manuelles (Joystick) et Automatiques (PRG_03_Modes_Cycle).
   📄 Docs : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md ; DOC/AF/AF_Partie-10_Fonction_Winch/FB_Bucket_v1.0.md
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_04_Treuils_Benne

VAR_INPUT
    // === 📥 ENTRÉES PROGRAMME (AUCUNE - PILOTÉ VIA PRG_02 & PRG_03) ===
END_VAR

VAR_OUTPUT
    // === 🚌 BUS INTER-PRG (producteur unique) ===
    Data : ST_WinchInterPrg; // <-- [BUS] Demandes finales, états, sécurités, synchro, benne
END_VAR

VAR
    instWinchSync : FB_WinchSync;
    instBucket   : FB_Bucket;
    instSafetyWinchM1 : FB_Safety_Winch;   // Sécurité treuil M1 (SafeStop / permits / PowerCutOff)
    instSafetyWinchM2 : FB_Safety_Winch;
    instWinchM1   : FB_Winch;
    instWinchM2   : FB_Winch;
    // Projection lecture seule des états IHM treuils () : décharge la §8
    // (~250 lignes d'assignations pures) en un FB. Recopie bit-identique des
    // sources → WinchM1State/WinchM2State/WinchM1Safety/WinchM2Safety/CableLimitAscent.
    instWinchStateProjection : FB_WinchStateProjection;
    // Estimateurs bande vitesse réelle : alimentent le garde-fou palier FB_Winch
    // via MeasuredSpeedBand, 1 instance par treuil, mêmes sources que FB_Safety_Winch.
    instWinchLoadEstimatorM1 : FB_WinchLoadEstimator;
    instWinchLoadEstimatorM2 : FB_WinchLoadEstimator;

    // Collecteurs passifs d'apprentissage vitesse par palier : 1 par treuil,
    // écrivent la table RETAIN _WinchSpeedLearnTable {axe x sens x charge/vide x palier}.
    // STRICTEMENT PASSIFS : aucune commande moteur, aucune surveillance survitesse.
    instWinchSpeedLearningM1 : FB_WinchSpeedLearning;
    instWinchSpeedLearningM2 : FB_WinchSpeedLearning;
    // Dérivations des entrées de collecte (charge présente / conditions stables) — voir §6.
    LoadPresentM1 : BOOL;
    LoadPresentM2 : BOOL;
    StableForLearnM1 : BOOL;
    StableForLearnM2 : BOOL;

    // === FB D'ARBITRAGE DE COMMANDE (POO) ===
    instArbM1 : FB_WinchCmdArbitrationM1;  // * [INST] Arbitrage commande treuil M1
    instArbM2 : FB_WinchCmdArbitrationM2;  // * [INST] Arbitrage commande treuil M2
    instArbBucket : FB_BucketCmdArbitration;  // * [INST] Arbitrage commande benne (POO §5)

    // === REQUETES D'AXE ASSEMBLEES AVANT APPEL FB_WINCH ===
    // CODESYS n'accepte pas l'initialiseur de struct anonyme en parametre d'appel :
    // les structs WinchRequest / Sensors / Config sont remplies champ par champ ici.
    ReqM1Winch                   : ST_fbWinch_Req;             // . [LOC] Requête axe M1 (ordre, palier, bornes)
    ReqM2Winch                   : ST_fbWinch_Req;             // . [LOC] Requête axe M2 (ordre, palier, bornes)
    M1WinchSensors               : ST_fbWinch_Sensors;        // . [LOC] Mesures et feedbacks M1
    M2WinchSensors               : ST_fbWinch_Sensors;        // . [LOC] Mesures et feedbacks M2
    M1WinchCfg                   : ST_fbWinch_Cfg;            // . [LOC] Config statique M1 (table paliers, ralentissement)
    M2WinchCfg                   : ST_fbWinch_Cfg;            // . [LOC] Config statique M2 (table paliers, ralentissement)

    // === 📊 STRUCTS INTERNES (publiés via Data) ===
    WinchM1FinalInterlockRequest : ST_WinchFinalInterlockRequest; // . [LOC] Demande finale et interlocks treuil M1
    WinchM2FinalInterlockRequest : ST_WinchFinalInterlockRequest; // . [LOC] Demande finale et interlocks treuil M2
    KoboldContactorCmdArbitrated : BOOL;                         // . [LOC] Ordre contacteur capteur fond Kobold
    WinchM1State                 : ST_WinchState;                // . [LOC] Etat public treuil Retenue M1
    WinchM2State                 : ST_WinchState;                // . [LOC] Etat public treuil Benne M2
    WinchM1Safety                : ST_SafetyWinch;               // . [LOC] Diagnostic et securites treuil M1
    WinchM2Safety                : ST_SafetyWinch;               // . [LOC] Diagnostic et securites treuil M2
    SyncState                    : ST_SyncState;                 // . [LOC] Etat synchronisation treuils M1/M2
    BucketState                  : ST_BucketHMIState;            // . [LOC] Etat de fonctionnement benne
    Benne_IsRoughlyClosed        : BOOL;                         // . [LOC] Benne consideree fermee
    ArmingPermit                 : BOOL;                         // . [LOC] Permission d'armement homme-mort (combiné interlock benne, Option B)

    WinchBothMotionActive : BOOL;
    WinchBothReqAscent           : BOOL;
    WinchBothReqDescend          : BOOL;
    ManualBottomPositionConfirmed  : BOOL;
    BottomPositionConfirmed        : BOOL;
    CmdBucketCloseArbitrated       : BOOL;

    // Séquencement automatique benne en pilotage both normal --
    // descente uniquement benne ouverte, montée uniquement benne
    // fermée. Distinct de DumpAtTremie/DiveSearch/ExtractionAssist (fonctionnement normal,
    // pas une assistance MAINT_N1/N2 dédiée). Réutilise WinchBothMotionActive/
    // WinchBothMotionDirection (§1 ci-dessus) : déjà exactement "mouvement both
    // demandé" dans les 2 modes (joystick Select=0, ou BtnWinchBothAscent/Descent) — mêmes variables
    // déjà utilisées par instBucket/instDiveSearch/instExtractionAssist.
    WinchBothDiveBucketOpenArmed     : BOOL;  // CmdOpen_IHM déclenché par ce mécanisme (diagnostic IHM)
    WinchBothMotionBlockedByBucket   : BOOL;  // Garde-fou direct -- voir §3
    WinchBothAscentBucketCloseArmed  : BOOL;  // CmdClose_IHM déclenché par ce mécanisme (diagnostic IHM)
    BucketBusyRiseEdge             : R_TRIG; // Détecte le début d'une action benne (Busy monté)
    BucketBusyFallEdge             : F_TRIG; // Détecte la fin d'une action benne (Busy retombé)
    ControlAscentArmedForThisClose : BOOL;   // Mémorise si LA fermeture en cours a été armée par ce mécanisme
    ExtractionControlActive        : BOOL;   // Phase vitesse contrôlée en cours (diagnostic IHM)
    ControlAscentStartM1PosM       : REAL;
    ControlAscentStartM2PosM       : REAL;

    // === ACTION BENNE M2 (bits directionnels, câblés au FB d'arbitrage) ===
    BucketM2ReqAscent  : BOOL;
    BucketM2ReqDescend : BOOL;
    M2AscentPermitApplied : BOOL;
    M2DescendPermitApplied : BOOL;

    // === STRUCTS D'ARBITRAGE (remplis champ par champ, CODESYS refuse l'init anonyme en appel) ===
    ArbIHM     : ST_fbWinchCmdArbitration_IHM;      // . [LOC] Entrées IHM FB d'arbitrage (partagé M1/M2)
    ArbContext : ST_fbWinchCmdArbitration_Context;  // . [LOC] Contexte gating FB d'arbitrage (partagé M1/M2)
    ArbM1Cfg   : ST_fbWinchCmdArbitration_Cfg;      // . [LOC] Config M1 (palier boutons/both)
    ArbM2Cfg   : ST_fbWinchCmdArbitration_Cfg;      // . [LOC] Config M2 (palier boutons/both + override benne)
    ArbBucketIHM     : ST_fbBucketCmdArbitration_IHM;      // . [LOC] Entrées IHM FB d'arbitrage benne
    ArbBucketContext : ST_fbBucketCmdArbitration_Context;  // . [LOC] Contexte gating FB d'arbitrage benne

    M1LogicRunRequest            : BOOL;
    M1LogicReqAscent             : BOOL;
    M1LogicReqDescend            : BOOL;
    M1LogicRequestStepTgt       : INT;   // Palier arbitré M1 (1..5, 0 = arrêt) — consommé par FB_Winch
    M1LogicRequestSpeedCmd_Pct  : REAL;  // Diagnostic % M1 (palier→%, IHM / simu)

    M2LogicRunRequest            : BOOL;
    M2LogicReqAscent             : BOOL;
    M2LogicReqDescend            : BOOL;
    M2LogicRequestStepTgt       : INT;   // Palier arbitré M2 (1..5, 0 = arrêt) — consommé par FB_Winch
    M2LogicRequestSpeedCmd_Pct  : REAL;  // Diagnostic % M2 (palier→%, IHM / simu)

    BottomLimitM1_Active    : REAL;
    BottomLimitM2_Active    : REAL;

    CableLimitAscentM1Reached : BOOL;
    CableLimitAscentM2Reached : BOOL;

    SafeStopM1_Raw          : BOOL;
    SafeStopM2_Raw          : BOOL;
    WinchContactorMismatchLvl1 : BOOL;   // . [LOC] niveau 1 : discordance contacteurs M1/M2 confirmee (amont OU vecteurs finaux) -> SafeStop
    SafeStopM1_Active       : BOOL;
    SafeStopM2_Active       : BOOL;
    // Disponibilité de mouvement par axe/sens + conditions de base ArmingPermit
    ArmM1AscentAvail        : BOOL;
    ArmM1DescendAvail       : BOOL;
    ArmM2AscentAvail        : BOOL;
    ArmM2DescendAvail       : BOOL;
    ArmM3TremieAvail        : BOOL;
    ArmM3MaintenanceAvail   : BOOL;
    ArmAnyAxisAvail         : BOOL;
    ArmBucketBusy           : BOOL;
    ArmModeDisabled         : BOOL;
    ArmContactorOff         : BOOL;
    ArmPowerCutOff          : BOOL;
    // Taxonomie permit (D-P1 à D-P11) : SafetyPermit (safety pure), ProcessPermit (process pur),
    // ProcessAndSafetyPermit (= Safety AND Process), EffectivePermit (= couplage synchro).
    SafetyPermitM1_Descend   : BOOL;
    SafetyPermitM2_Descend   : BOOL;
    SafetyPermitM1_Ascent    : BOOL;
    SafetyPermitM2_Ascent    : BOOL;
    ProcessPermitM1_Descend  : BOOL;
    ProcessPermitM2_Descend  : BOOL;
    ProcessPermitM1_Ascent   : BOOL;
    ProcessPermitM2_Ascent   : BOOL;
    ProcessAndSafetyPermitM1_Descend : BOOL;
    ProcessAndSafetyPermitM2_Descend : BOOL;
    ProcessAndSafetyPermitM1_Ascent  : BOOL;
    ProcessAndSafetyPermitM2_Ascent  : BOOL;
    EffectivePermitM1_Descend : BOOL;
    EffectivePermitM2_Descend : BOOL;
    EffectivePermitM1_Ascent  : BOOL;
    EffectivePermitM2_Ascent  : BOOL;
    EffectivePermitBucket_Open  : BOOL;
    EffectivePermitBucket_Close : BOOL;

    // === 🔗 ATOMICITÉ BOTH — états agrégés explicites ===
    // CoupledBoth := couplage atomique M1/M2 indépendant de SyncEnable : actif en
    // synchro classique (anti-télescopage) OU dès qu'un mouvement both est demandé
    // (même si SyncEnable=FALSE en MAINT_N2). Une permission ou un SafeStop d'un
    // treuil bloque alors l'autre : départ jamais isolé.
    CoupledBoth             : BOOL;
    // Diagnostic IHM : Both bloqué + cause priorisée (voir §5).
    BothBlocked             : BOOL;
    BothBlockReason         : E_WinchTraceBlockReason;

    BenneBusyFallEdge     : F_TRIG;

    // Arrêt auto descente sur détection fond Kobold (pilotage normal)
    KoboldAutoStopRiseEdge  : R_TRIG;
    KoboldAutoStopFallEdge  : F_TRIG;
    KoboldImmersionConfirmed: BOOL;
    KoboldBottomTouchLatched: BOOL;
    DescendPermitDiveBucketOpen : BOOL; // mode Dive actif + benne ouverte = descente permise
    // pilotage unitaire M2 "sécurisé" -- bornes ouvert/fermé + palier 1
    ManualBucketLimitsActive : BOOL;
    ManualBucketJogActive    : BOOL; // WinchSel=2 + MAINT : jog benne unitaire M2 (ouv/ferm), indépendant du toggle bornes
    M2JogApproachOpen        : BOOL; // M2 dans la zone de ralentissement avant l'arrêt ouverture (palier 1)
    M2JogApproachClose       : BOOL; // M2 dans la zone de ralentissement avant l'arrêt fermeture (palier 1)
    SlackCableAscentCapStep1    : BOOL; // mou de câble en récupération -- bride la montée au Palier 1
    BucketNotClosedAscentCapStep1 : BOOL; // benne non fermée à 100% à la montée -- bride la montée au Palier 1

    // Bypass simplifié séquence FB_DiveSearch -- front montant
    // Kobold pendant une descente couplée confirme directement le fond, sans passer par les
    // préconditions strictes de FB_DiveSearch (benne ouverte, DiveStartMin_M, fenêtre immersion).
    // FB_DiveSearch continue de tourner en parallèle (KoboldMeasureEnable toujours câblé
    // dessus) -- ce bypass est un chemin ADDITIONNEL, pas un remplacement.
    BypassKoboldFallEdge       : F_TRIG; // front descendant Kobold
    BypassKoboldBottomTouched  : BOOL;

    SyncMinorDeviation      : BOOL;
    SyncMinorDeviationBlocksUp   : BOOL;
    SyncMinorDeviationBlocksDown : BOOL;
    M2_LimitShift                : REAL;

    EffectiveMaxStepAscent    : INT;
    EffectiveMaxStepDescent  : INT;

    // Agrégateur de clamp de palier — bornes communes M1=M2 puis M2-propre
    CommonMaxStepAscent   : INT;
    CommonMaxStepDescent : INT;
    CommonMinStepUp   : INT;
    CommonMinStepDown : INT;
    M2MaxStepUp       : INT;
    M2MaxStepDown     : INT;
    M2MinStepUp       : INT;
    M2MinStepDown     : INT;

    // Mémoire scan précédent pour SpeedDelta_Mps (IHM)
    M1_PrevSpeed_Mps : REAL;
    M2_PrevSpeed_Mps : REAL;

    // === MATRICE DE MAINTENANCE N1/N2 (AF-05 §4bis) ===
    // PRG_04 est le producteur unique du bypass EFFECTIF de son axe : FB_Safety_Winch / FB_Winch /
    // FB_Bucket ne connaissent que des booléens déjà gatés, jamais le mode (encapsulation AF03 §2).
    MaintN1 : BOOL;   // . [LOC] Mode MAINT_N1 arbitré (override FDC logiciel momentané)
    ExtractionAssistActive : BOOL; // . [LOC] Séquence d'extraction active (mode MAINT + toggle) — gate permis de montée assistée

    // Override du FDC haut LOGICIEL — MAINT_N1, bouton IHM MAINTENU (jamais latché).
    // Le FDC haut CAPTEUR (TopPositionSensor ≈ 8,5 m) n'est JAMAIS ouvert par cet override.
    OverrideTopSoftwareN1M1 : BOOL;
    OverrideTopSoftwareN1M2 : BOOL;

    // Limite haute logicielle active (m) : 7,5 m nominal ➔ 8,5 m (capteur homing haut) sous override.
    TopLimitM1_M : REAL;
    TopLimitM2_M : REAL;

    // Bypass EFFECTIFS de la famille position (= bypass IHM armé, tous modes — dérogation MES 2026).
    // Servent au câblage ET à l'armement du re-homing obligatoire publié vers PRG_03 (PositionLimitOverriddenM1/M2).
    BypassM1TopLimitSwitchEff   : BOOL;
    BypassM1TopLimitSoftwareEff : BOOL;
    BypassM1CableLimitSwitchEff : BOOL;
    BypassM1LimitLegalEff       : BOOL;
    BypassM1MecaDEff            : BOOL;
    BypassM2TopLimitSwitchEff   : BOOL;
    BypassM2TopLimitSoftwareEff : BOOL;
    BypassM2CableLimitSwitchEff : BOOL;
    BypassM2LimitLegalEff       : BOOL;
    BypassM2MecaDEff            : BOOL;

    // Usage effectif d'un override/bypass de position -> arme le re-homing obligatoire (PRG_03).
    PositionLimitOverriddenM1 : BOOL;
    PositionLimitOverriddenM2 : BOOL;

    // 🕵️ Trace de blocage terrain (§8bis) — publiée via Data.TraceM1/M2, consommée FB_TroubleshootingView
    TraceM1               : ST_TraceWinch;        // . [LOC] Trace blocage treuil M1
    TraceM2               : ST_TraceWinch;        // . [LOC] Trace blocage treuil M2
    TraceM1_PrevReason    : E_WinchTraceBlockReason; // . [LOC] Cause précédente M1 (détection de changement)
    TraceM2_PrevReason    : E_WinchTraceBlockReason; // . [LOC] Cause précédente M2 (détection de changement)
END_VAR

{region "🎯 §1 Intention & assistants"}
// === 🪨 §1 INTENTION MAINTENANCE & ASSISTANTS ===

// Consommation de l'intention both continue opérateur (source unique PRG_03, tous modes)
WinchBothMotionActive    := PRG_03_Modes_Cycle.Data.WinchBothIntent.Active;
WinchBothReqAscent  := PRG_03_Modes_Cycle.Data.WinchBothIntent.ReqAscent;
WinchBothReqDescend := PRG_03_Modes_Cycle.Data.WinchBothIntent.ReqDescend;

// Récupération de l'état fond synthétisé par PRG_03
BottomPositionConfirmed := PRG_03_Modes_Cycle.Data.SequenceState.BottomTouchConfirmed;

// MODES DE MAINTENANCE (calculés en tête de scan : consommés dès §2 par instBucket)
// 🚨 DEROGATION MES septembre 2026 (AF-05 §4bis) : les bypass sécurité treuil M1/M2 + benne
// NE SONT PLUS conditionnés au mode. Un bypass IHM armé est effectif dans TOUS les modes
// (y compris SEMI_AUTO / AUTO). Choix opérateur assumé, tracé — voir AF-05 §4bis.
// MAINT_N1 reste utilisé pour l'override momentané du FDC haut logiciel (§5) et l'assistance extraction.
MaintN1 := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N1);
// Séquence d'extraction active (mode MAINT + toggle) : gate le permis de montée assistée (§5).
// Le permis lui-même (AscentPermit) est produit par FB_ExtractionAssist et consommé via le contrat benne.
ExtractionAssistActive := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2)
                          AND GVL_IHM.CycleExtraction.Cmd.TglEnableExtractionSequence;

// Jog benne unitaire M2 : joystick dédié M2 (WinchSel=2) en maintenance. Autorise
// l'ouverture (descente M2) hors mode Dive + active la détection passive d'état benne
// dans FB_Bucket. Indépendant du toggle bornes (TglManualBucketLimits).
ManualBucketJogActive := (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated = 2)
    AND (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N1 OR PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2);

// Règle absolue en pilotage both normal --
// descente autorisée UNIQUEMENT benne ouverte, montée UNIQUEMENT benne fermée.
// Décision déléguée à FB_BucketCmdArbitration (POO §5) : flags armés + commandes
// arbitrées (ouverture, fermeture, contacteur Kobold). Bit-identique PRG_04 §1/§2.
ArbBucketIHM.BtnOpen  := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnOpen;
ArbBucketIHM.BtnClose := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnClose;

ArbBucketContext.TglEnableCoupledBucketSequencing := GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing;
ArbBucketContext.MotionActive   := WinchBothMotionActive;
ArbBucketContext.ReqAscent      := WinchBothReqAscent;
ArbBucketContext.ReqDescend     := WinchBothReqDescend;
ArbBucketContext.BucketIsOpen   := _BucketState.IsOpen;
ArbBucketContext.BucketIsClosed := _BucketState.IsClosed;

instArbBucket(
    Enable    := TRUE,
    Auth      := PRG_03_Modes_Cycle.Data.Auth,
    ReqBucket := PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket,
    IHM       := ArbBucketIHM,
    Context   := ArbBucketContext
);
WinchBothDiveBucketOpenArmed    := instArbBucket.WinchBothDiveBucketOpenArmed;
WinchBothAscentBucketCloseArmed := instArbBucket.WinchBothAscentBucketCloseArmed;
CmdBucketCloseArbitrated        := instArbBucket.CmdClose_IHM;
KoboldContactorCmdArbitrated    := instArbBucket.KoboldContactorCmdArbitrated;

{endregion}

{region "🪣 §2 Commande benne"}
// === 🏗️ §2 COMMANDE DU BENNE (FB_Bucket) ===

instBucket(
    Enable              := NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM2,
    Reset               := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged     := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                := PRG_03_Modes_Cycle.Data.Auth.Mode,
    CmdOpen_IHM         := instArbBucket.CmdOpen_IHM,
    CmdClose_IHM        := CmdBucketCloseArbitrated,
    ReqAscent           := WinchBothReqAscent,
    ReqDescend          := WinchBothReqDescend,
    EffectivePermitBucket_Open := EffectivePermitBucket_Open,
    EffectivePermitBucket_Close := EffectivePermitBucket_Close,
    CablePosM1          := PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM,
    CablePosM2          := PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM,
    HomedM1             := PRG_02_Acquisition.Data.EncoderM1.Homed,
    HomedM2             := PRG_02_Acquisition.Data.EncoderM2.Homed,
    M1_Busy             := (instWinchM1.StepNumber > 0),
    M2_Busy             := (instWinchM2.StepNumber > 0),
    // Confirmations visuelles N2 : publication et offset benne. Le preset
    // materiel M2 associe est produit independamment dans PRG_02.
    ConfirmOpenPosition  := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmOpenPos,
    ConfirmClosePosition := GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnConfirmClosePos,
    MachineHomingCommitOpen  := PRG_02_Acquisition.Data.MachineHoming.SetPosBucketOpen,
    MachineHomingCommitClose := PRG_02_Acquisition.Data.MachineHoming.SetPosBucketClose,
    MachineHomed := PRG_02_Acquisition.Data.MachineHoming.Homed,
    MachineHomingActive := PRG_02_Acquisition.Data.MachineHoming.Active,
    Config              := _BucketCfgPersist.Config,
    CfgTimeoutDuration     := GVL_IHM.M2TreuilBenne.Bucket.Cfg.CfgTimeoutDuration,
    BucketState        := _BucketState,
    InhibitM1           := PRG_03_Modes_Cycle.Data.Auth.InhibitM1,
    InhibitM2           := PRG_03_Modes_Cycle.Data.Auth.InhibitM2,
    // Bypass benne (n°25 de la matrice) — effectif tous modes si armé (dérogation MES 2026, AF-05 §4bis)
    BypassGlobal        := GVL_IHM.M2TreuilBenne.Bucket.Bypass.Global
);

// Auto-séquencement benne & Dégradation Palier 1
// Si la benne est en cours de fermeture/ouverture (instBucket.Busy), le mouvement couplé attend.
// Si la benne n'est pas fermée (NOT IsClosed) et que instBucket n'est plus occupé (Busy=FALSE),
// toute demande de montée est automatiquement dégradée au Palier 1 (Vitesse lente, voir instWinchM1/M2),
// protégeant ainsi la mécanique même en pilotage unitaire ou si l'auto-séquencement est désactivé.
// 📌 Note d'architecture (lag 1 scan) : M1/M2LogicRequestDirection est consommé ici avant son calcul arbitré
// en §3 (lag d'un cycle automate nominal, toléré et homogène avec les arbitrages Translation/Modes).
WinchBothMotionBlockedByBucket := WinchBothDiveBucketOpenArmed AND NOT instBucket.Lifecycle.Busy;
BucketNotClosedAscentCapStep1 := (M1LogicReqAscent OR M2LogicReqAscent) AND NOT instBucket.Lifecycle.Busy AND NOT _BucketState.IsClosed;

// En mode récupération (SyncEnable=FALSE), si un mou de câble est détecté (bit3 ErrorId),
// la montée/enroulement est autorisée mais bridée au Palier 1 pour retendre le tambour en sécurité.
// 📌 Note d'architecture (lag 1 scan) : instSafetyWinchM1/M2.ErrorId est consommé ici avant l'exécution du FB
// au §5bis (lag d'un cycle automate nominal, sécurisé en amont par la lecture directe de M2_TensionedCable_DI).
SlackCableAscentCapStep1 := NOT GVL_IHM.Commun.Bypass.SlackCable
    AND NOT PRG_03_Modes_Cycle.Data.Auth.SyncEnable AND (
    ((instSafetyWinchM1.Fault.ErrorId AND 16#0008) <> 16#0000) OR
    ((instSafetyWinchM2.Fault.ErrorId AND 16#0008) <> 16#0000) OR
    (NOT PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI)
);

SyncMinorDeviation := (instWinchSync.Fault.ErrorId AND 16#0001) <> 16#0000;
// 🛡️ Soft-stop synchro : rattrapage directionnel volontaire UNIQUEMENT en
// commande unitaire. En commande BOTH (WinchBothMotionActive), l'écart mineur ne doit
// JAMAIS produire de rattrapage unilatéral d'un seul treuil — il est géré par le clamp
// palier §5ter (les 2 treuils sont bridés à 1) et le seuil critique (SafeStop des 2,
// §5). Donc les drapeaux sync sont coupés dès qu'un mouvement both est demandé.
SyncMinorDeviationBlocksUp   := _SyncSoftStopEnable AND SyncMinorDeviation AND (instWinchSync.SignedDeltaPosM > 0.0) AND NOT WinchBothMotionActive;
SyncMinorDeviationBlocksDown := _SyncSoftStopEnable AND SyncMinorDeviation AND (instWinchSync.SignedDeltaPosM < 0.0) AND NOT WinchBothMotionActive;

IF _CommunCfgPersist.WinchMaxStepAscent <= 0 THEN
    EffectiveMaxStepAscent := 5;
ELSE
    EffectiveMaxStepAscent := _CommunCfgPersist.WinchMaxStepAscent;
END_IF;

IF _CommunCfgPersist.WinchMaxStepDescent <= 0 THEN
    EffectiveMaxStepDescent := 5;
ELSE
    EffectiveMaxStepDescent := _CommunCfgPersist.WinchMaxStepDescent;
END_IF;


{endregion}

{region "🔀 §3 Arbitrage M1/M2"}
// === 🔀 §3 ARBITRAGE CONSIGNES M1 / M2 ===

// ── Arbitrage M1/M2 (FB_WinchCmdArbitrationM1/M2) ──
// Dérivation des bits d'action benne M2 (consommés par les 2 FB d'arbitrage)
BucketM2ReqAscent  := instBucket.M2_ReqAscent;
BucketM2ReqDescend := instBucket.M2_ReqDescend;

// Remplissage des structs d'arbitrage (champ par champ, CODESYS 3.5 refuse l'init anonyme en appel)
ArbIHM.BtnAscentM1           := GVL_IHM.M1TreuilRetenue.Cmd.BtnAscent;
ArbIHM.BtnDescentM1         := GVL_IHM.M1TreuilRetenue.Cmd.BtnDescent;
ArbIHM.BtnAscentM2           := GVL_IHM.M2TreuilBenne.Cmd.BtnAscent;
ArbIHM.BtnDescentM2         := GVL_IHM.M2TreuilBenne.Cmd.BtnDescent;
ArbIHM.BtnWinchBothAscent    := GVL_IHM.Commun.BtnWinchBothAscent;
ArbIHM.BtnWinchBothDescent  := GVL_IHM.Commun.BtnWinchBothDescent;

ArbContext.BucketBusy                     := instBucket.Lifecycle.Busy;
ArbContext.BucketM2RunRequest             := instBucket.M2_RunRequest;
ArbContext.BucketM2ReqAscent              := BucketM2ReqAscent;
ArbContext.BucketM2ReqDescend             := BucketM2ReqDescend;
ArbContext.WinchBothMotionBlockedByBucket := WinchBothMotionBlockedByBucket;
ArbContext.SyncBlocksAscent                   := SyncMinorDeviationBlocksUp;
ArbContext.SyncBlocksDescent                 := SyncMinorDeviationBlocksDown;
// 🔗 Atomicité Both : agrégats consommés par la commande both (§5 calcule
// Both*Permit APRÈS §3 → lag 1 scan assumé au gate d'arbitre, documenté comme les
// autres gates lag-1 de PRG_04 ; l'enforcement même-scan est assuré par le routage
// §6 vers FB_Winch).
ArbContext.M1AscentAllowed  := EffectivePermitM1_Ascent;
ArbContext.M1DescendAllowed := EffectivePermitM1_Descend;
ArbContext.M2AscentAllowed  := EffectivePermitM2_Ascent;
ArbContext.M2DescendAllowed := EffectivePermitM2_Descend;
ArbContext.BothBlock         := BothBlocked;

ArbM1Cfg.BtnStepTgt := 5;
ArbM2Cfg.BtnStepTgt := 5;
ArbM2Cfg.BucketOverrideStepTgt := 1;

// ── Arbitrage M1 (FB_WinchCmdArbitrationM1) ──
instArbM1(
    Enable     := TRUE,
    Joystick   := PRG_02_Acquisition.Data.Joystick,
    Auth       := PRG_03_Modes_Cycle.Data.Auth,
    ReqWinch   := PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM1,
    BothIntent := PRG_03_Modes_Cycle.Data.WinchBothIntent,
    IHM        := ArbIHM,
    TglJoystickMaster := GVL_IHM.Modes.Cmd.TglJoystickMaster,
    Context    := ArbContext,
    Cfg        := ArbM1Cfg
);
M1LogicRunRequest := instArbM1.RunRequest;
M1LogicReqAscent  := instArbM1.ReqAscent;
M1LogicReqDescend := instArbM1.ReqDescend;
M1LogicRequestStepTgt := instArbM1.StepTgt;
// Diagnostic % (palier→%) pour IHM / simu — borne haute du palier arbitré.
IF (M1LogicRequestStepTgt >= 1) AND (M1LogicRequestStepTgt <= 5) THEN
    M1LogicRequestSpeedCmd_Pct := _WinchSpeedStepTable.StepThreshold_Pct[M1LogicRequestStepTgt];
ELSE
    M1LogicRequestSpeedCmd_Pct := 0.0;
END_IF;

// ── Arbitrage M2 (FB_WinchCmdArbitrationM2) ──
instArbM2(
    Enable     := TRUE,
    Joystick   := PRG_02_Acquisition.Data.Joystick,
    Auth       := PRG_03_Modes_Cycle.Data.Auth,
    ReqWinch   := PRG_03_Modes_Cycle.Data.ReqProgram.ReqWinchM2,
    BothIntent := PRG_03_Modes_Cycle.Data.WinchBothIntent,
    IHM        := ArbIHM,
    TglJoystickMaster := GVL_IHM.Modes.Cmd.TglJoystickMaster,
    Context    := ArbContext,
    Cfg        := ArbM2Cfg
);
M2LogicRunRequest := instArbM2.RunRequest;
M2LogicReqAscent  := instArbM2.ReqAscent;
M2LogicReqDescend := instArbM2.ReqDescend;
M2LogicRequestStepTgt := instArbM2.StepTgt;
// Diagnostic % (palier→%) pour IHM / simu — borne haute du palier arbitré.
IF (M2LogicRequestStepTgt >= 1) AND (M2LogicRequestStepTgt <= 5) THEN
    M2LogicRequestSpeedCmd_Pct := _WinchSpeedStepTable.StepThreshold_Pct[M2LogicRequestStepTgt];
ELSE
    M2LogicRequestSpeedCmd_Pct := 0.0;
END_IF;

// Front de fin d'action benne (F_TRIG conservé pour §3bis ArmingPermit et extraction control).
// L'arrêt forcé de fin d'action benne est désormais géré en interne par les FB d'arbitrage.
BenneBusyFallEdge(CLK := instBucket.Lifecycle.Busy);

// Après une fermeture benne armée PAR CE mécanisme
// (pas ExtractionAssist, qui a déjà sa propre phase CONTROL_ASCENT), la montée couplée qui
// enchaîne démarre en vitesse contrôlée (palier 1) sur ExtractionControlDistance_M avant de
// repasser en paliers normaux.
BucketBusyRiseEdge(CLK := instBucket.Lifecycle.Busy);
IF BucketBusyRiseEdge.Q THEN
    ControlAscentArmedForThisClose := WinchBothAscentBucketCloseArmed;
END_IF;
IF BucketBusyFallEdge.Q AND ControlAscentArmedForThisClose THEN
    ExtractionControlActive := TRUE;
    ControlAscentStartM1PosM := PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM;
    ControlAscentStartM2PosM := PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM;
END_IF;
IF ExtractionControlActive THEN
    IF (ABS(PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM - ControlAscentStartM1PosM) >= GVL_IHM.CycleExtraction.Cfg.ExtractionControlDistance_M)
       AND (ABS(PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM - ControlAscentStartM2PosM) >= GVL_IHM.CycleExtraction.Cfg.ExtractionControlDistance_M) THEN
        ExtractionControlActive := FALSE;         // Distance de contrôle parcourue : paliers normaux
    ELSIF NOT (WinchBothMotionActive AND WinchBothReqAscent) THEN
        ExtractionControlActive := FALSE;         // Ascending relâchée/interrompue : annule la phase
    END_IF;
END_IF;


{endregion}

{region "🛡️ §3bis ArmingPermit"}
// === 🛡️ §3bis ARMINGPERMIT (général — permis de mouvement) ===
// ArmingPermit = permission d'armement homme-mort (entrée FB_Joystick, consommée PRG_02).
// Règle générale : on ne peut armer QUE si au moins un axe (treuil M1/M2 ou translation M3)
// a un permis de mouvement effectif. Sinon, aucun mouvement n'est possible → armement inutile
// et trompeur (l'opérateur croit pouvoir bouger alors que tout est bloqué).
// Calcul déplacé après §5bis (où EffectivePermitM1/M2_Ascent/Descend sont disponibles).
// Combiné interlock benne conservé : interdit l'armement pendant une action benne
// (instBucket.Lifecycle.Busy) et 1 scan après (BenneBusyFallEdge.Q).
// Polarité positive (NC-100) : TRUE = armement autorisé.
{endregion}

{region "🔄 §4 Synchro M1/M2"}
// === 🔄 §4 SYNCHRONISATION M1 / M2 ===

instWinchSync(
    // Surveillance synchro (ecart position + concordance contacteurs) UNIQUEMENT en
    // pilotage couple. En unitaire M1 ou M2 (JoystickWinchSelectArbitrated <> 0) les
    // deux treuils sont volontairement independants : comparer M1/M2 declencherait un
    // faux ContactorMismatch (M2 commande seul, M1 non) -> SafeStop.
    Enable          := PRG_03_Modes_Cycle.Data.Auth.SyncEnable AND NOT instBucket.Lifecycle.Busy
                        AND (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated = 0)
                        AND NOT PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Busy
                        AND NOT PRG_02_Acquisition.Data.EncoderM2.Measurement.HomingLifecycle.Busy
                        AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM1 AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM2,
    Reset           := PRG_07_Supervision.FaultMachineReset_IHM,
    Mode            := PRG_03_Modes_Cycle.Data.Auth.Mode,
    CablePosM1      := PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM,
    CablePosM2      := PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM,
    HomedAndReliableM1 := PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable,
    HomedAndReliableM2 := PRG_02_Acquisition.Data.EncoderM2.HomedAndReliable,
    SyncEnable      := PRG_03_Modes_Cycle.Data.Auth.SyncEnable,
    CfgSyncToleranceM  := _SyncCfgPersist.CfgSyncTolerance_M,
    CfgSyncCriticalToleranceM := _SyncCfgPersist.CfgSyncCriticalTolerance_M,
    ActiveOffsetM   := instBucket.ActiveOffsetM,
    RelayFwdM1      := instWinchM1.RelayFwd,
    RelayFwdM2      := instWinchM2.RelayFwd,
    RelayRevM1      := instWinchM1.RelayRev,
    RelayRevM2      := instWinchM2.RelayRev,
    Contactor1_M1   := instWinchM1.Contactor1,
    Contactor1_M2   := instWinchM2.Contactor1,
    Contactor2_M1   := instWinchM1.Contactor2,
    Contactor2_M2   := instWinchM2.Contactor2,
    Contactor3_M1   := instWinchM1.Contactor3,
    Contactor3_M2   := instWinchM2.Contactor3,
    Contactor4_M1   := instWinchM1.Contactor4,
    Contactor4_M2   := instWinchM2.Contactor4,
    BypassGlobal    := GVL_IHM.M1M2Sync.Bypass.Global
);

// Pas de reconstruction de table M2 : le clamp §5ter (M2MaxStep* := 1) suffit
// — StepNumber ≤ 1 → seuls les états P1 sont commandés.
// M2 consomme directement _WinchSpeedStepTable (table normale).


{endregion}

{region "🔗 §5 Couplage & sécurités"}
// === 🛑 §5 COUPLAGE CROISÉ & SÉCURITÉS ===

// La limite légale (profondeur min. autorisée) doit elle aussi
// bénéficier du ralentissement progressif avant arrêt (comme la limite câble physique), pas juste
// un arrêt sec (DescendPermit). Comme les 2 limites bornent la même
// direction (descente), on alimente FB_Winch.BottomLimitM avec la PLUS RESTRICTIVE des deux
// (MAX de 2 valeurs négatives = celle la moins profonde = atteinte en premier) : le ralentissement
// (FB_Winch §"RALENTISSEMENT AUTOMATIQUE SUR BORDURES") s'enclenche alors sur la bonne limite,
// légale ou câble, sans dupliquer le mécanisme.
IF _CommunCfgPersist.LimitLegalEnabled THEN
    BottomLimitM1_Active := MAX(_WinchM1CfgPersist.CfgCableLimitDescent_M, _CommunCfgPersist.LimitLegalDepthMinAllowed_M);
    BottomLimitM2_Active := MAX(_WinchM2CfgPersist.CfgCableLimitDescent_M, _CommunCfgPersist.LimitLegalDepthMinAllowed_M);
ELSE
    BottomLimitM1_Active := _WinchM1CfgPersist.CfgCableLimitDescent_M;
    BottomLimitM2_Active := _WinchM2CfgPersist.CfgCableLimitDescent_M;
END_IF;

// 🩺 InputModuleFault (AF06 §3bis) : un module DI TOR hors service rend indisponibles
// les retours frein/thermique/contacteurs/fin de course des DEUX treuils (VH_0800END,
// Local_Digital_IO) — pas de granularité par treuil possible, donc SafeStop des DEUX.
// Perte d'une reference auparavant valide en mouvement : arret controle des
// deux treuils, sans PowerCutOff additionnel. Le cycle libere la demande
// seulement apres le composite d'arret mecanique confirme.
// Discordance contacteurs M1/M2 = niveau 1 (SafeStop) sans masque hexa.
//   - instWinchSync.ContactorMismatch : sur les requetes amont (FB_Winch).
//   - PRG_06_Outputs.Data.ContactorMismatch : sur les vecteurs PHYSIQUES finaux
//     (scan N-1, PRG_06 s'execute apres PRG_04). Escalade -> ExternalSyncEscalation ci-dessous.
WinchContactorMismatchLvl1 := instWinchSync.ContactorMismatch OR PRG_06_Outputs.Data.ContactorMismatch;
SafeStopM1_Raw      := WinchContactorMismatchLvl1 OR instBucket.M1SlipDetected OR PRG_02_Acquisition.Data.InputModules.Fault
                       OR PRG_02_Acquisition.Data.MachineHoming.HomingLoss;
SafeStopM2_Raw      := WinchContactorMismatchLvl1 OR PRG_02_Acquisition.Data.InputModules.Fault
                       OR PRG_02_Acquisition.Data.MachineHoming.HomingLoss;

// Surveillance Kobold descente normale (hors FB_DiveSearch)
// : signal HwIn.Machine.M1_M2_KoboldBottomTouch_DI (même que instDiveSearch §1).
KoboldAutoStopRiseEdge(CLK := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI);
KoboldAutoStopFallEdge(CLK := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI);

// Levée du verrou au neutre du joystick/boutons ou si toggle désactivé
IF PRG_02_Acquisition.Data.Joystick.AtNeutralXY OR NOT GVL_IHM.Commun.Cfg.TglEnableKoboldAutoStopDescent THEN
    KoboldImmersionConfirmed := FALSE;
    KoboldBottomTouchLatched := FALSE;
END_IF;

// WinchBothMotionActive requis : cette surveillance ne s'arme qu'en pilotage
// BOTH (Select=0), pas en pilotage unitaire M1 (où WinchBothMotionDirection reflète
// quand même l'axe joystick brut).
// Qualification immersion : front montant Kobold dans la fenêtre [ImmersionLower_M..ImmersionUpper_M]
IF GVL_IHM.Commun.Cfg.TglEnableKoboldAutoStopDescent
   AND WinchBothMotionActive
   AND WinchBothReqDescend
   AND _BucketState.IsOpen
   AND KoboldAutoStopRiseEdge.Q THEN
    IF (PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM <= _CycleDiveSearchCfgPersist.ImmersionUpper_M)
       AND (PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM >= _CycleDiveSearchCfgPersist.ImmersionLower_M)
       AND (PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM <= _CycleDiveSearchCfgPersist.ImmersionUpper_M)
       AND (PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM >= _CycleDiveSearchCfgPersist.ImmersionLower_M) THEN
        KoboldImmersionConfirmed := TRUE;
    END_IF;
END_IF;

// Détection fond : front descendant Kobold APRÈS immersion confirmée
IF KoboldAutoStopFallEdge.Q AND KoboldImmersionConfirmed THEN
    KoboldBottomTouchLatched := TRUE;
    KoboldImmersionConfirmed := FALSE;
END_IF;

// Autorisation directe et explicite issue de PRG_03 (DiveSearch / Cycle)
DescendPermitDiveBucketOpen := PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.DescendPermitDiveBucketOpen;

// Le bypass arrête aussi la descente instantanément, même doctrine que le mécanisme
// KoboldBottomTouchLatched.
// Mode "pilotage unitaire M2 sécurisé"
// (SelJoystickWinch=2 + toggle IHM). Ne passe PAS par instBucket (pas de CloseReq/OpenReq
// mémorisé, jogging libre) -- bornes directes ouvert/fermé (mêmes offsets que FB_Bucket,
// relatifs à la position réelle de M1) + palier 1 (voir instWinchM2 §6 plus bas).
ManualBucketLimitsActive := GVL_IHM.M2TreuilBenne.Bucket.Cmd.TglManualBucketLimits
    AND (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated = 2);

ProcessPermitM1_Descend := NOT (KoboldBottomTouchLatched OR BypassKoboldBottomTouched) AND DescendPermitDiveBucketOpen;
// Ce chemin (pilotage unitaire M2, hors instBucket) applique l'anticipation d'inertie
// OpenAnticipationM/CloseAnticipationM (mêmes que FB_Bucket, réglables IHM) pour couvrir
// aussi le jog unitaire. L'ouverture benne (descente M2) est permise soit par le mode Dive
// (DescendPermitDiveBucketOpen), soit par le jog benne unitaire en maintenance
// (ManualBucketJogActive) — sinon la benne ne pourrait plus s'ouvrir en WinchSel=2.
ProcessPermitM2_Descend := NOT (KoboldBottomTouchLatched OR BypassKoboldBottomTouched)
    AND (DescendPermitDiveBucketOpen OR ManualBucketJogActive)
    AND NOT (ManualBucketLimitsActive AND (PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM <= (PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM + _BucketCfgPersist.Config.OffsetOpenM + _BucketCfgPersist.Config.OpenAnticipationM)));

// Permis process de montee : contrat extraction commun aux deux axes.
// M2 conserve l'anticipation de fermeture du pilotage benne unitaire, deja appliquee
// historiquement dans ProcessAndSafetyPermitM2_Ascent (refactor sans changement fonctionnel).
ProcessPermitM1_Ascent := NOT ExtractionAssistActive
    OR PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.AscentPermit;
ProcessPermitM2_Ascent := (NOT ExtractionAssistActive
    OR PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.AscentPermit)
    AND NOT (ManualBucketLimitsActive AND (PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM >= (PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM + _BucketCfgPersist.Config.OffsetCloseM - _BucketCfgPersist.Config.CloseAnticipationM)));

// Zone de ralentissement jog unitaire M2 : palier 1 forcé dans les JogSlowdownZoneM
// derniers mètres AVANT le point d'arrêt anticipé (Offset ± Anticipation). Le "1 m d'avant"
// est donc calculé sur la cible anticipée, pas sur l'offset brut, et suit tout réglage IHM.
M2JogApproachOpen := ManualBucketJogActive
    AND (PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM
         <= (PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM
             + _BucketCfgPersist.Config.OffsetOpenM
             + _BucketCfgPersist.Config.OpenAnticipationM
             + _BucketCfgPersist.Config.JogSlowdownZoneM));
M2JogApproachClose := ManualBucketJogActive
    AND (PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM
         >= (PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM
             + _BucketCfgPersist.Config.OffsetCloseM
             - _BucketCfgPersist.Config.CloseAnticipationM
             - _BucketCfgPersist.Config.JogSlowdownZoneM));

M2_LimitShift := SEL(_BucketState.IsClosed OR instBucket.CloseReq OR (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated = 2),
                      0.0,
                      (PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM + _BucketCfgPersist.Config.OffsetCloseM + 0.5)
                      - _CommunCfgPersist.CfgCableLimitAscent_M);

{endregion}

{region "🧮 §5-0 Matrice N1/N2"}
// === 🛡️ §5-0 MATRICE DE MAINTENANCE (AF-05 §4bis) ===
// 🚨 DEROGATION MES septembre 2026 : bypass_effectif := bypass_IHM (armé) — SANS conditionnement
// de mode. Un bypass IHM armé est effectif dans TOUS les modes, SEMI_AUTO et AUTO inclus.
// Écart assumé (Directive Machines / ISO 13849) : traçabilité IHM + doc AF-05 §4bis.
// L'override du FDC haut logiciel reste momentané et propre à MAINT_N1 (§ ci-dessous).

// --- Override FDC haut LOGICIEL (décision Q8) ---------------------------------------------
// MAINT_N1 + bouton IHM MAINTENU ➔ la limite logicielle passe de 7,5 m à la position du capteur
// de homing haut (8,5 m). Relâché ➔ retour à 7,5 m au cycle suivant (aucune mémorisation).
// ⛔ Cet override n'ouvre PAS BypassTopLimitSwitch : le capteur physique haut reste la butée
// dure — si TopPositionSensor retombe, AscentPermit tombe (FB_Safety_Winch §3) ➔ arrêt matériel.
// ⛔ Conditionné à Homed ET NON HomingSuspect : sans référence de position fiable, la butée
// logicielle de FB_Safety_Winch (§3) ET la zone de ralentissement de FB_Winch (§3) sont
// neutralisées — relever la limite dans ce cas ne laisserait QUE le capteur physique comme
// protection, approché à pleine vitesse. Sans référence, il n'y a pas de « dépassement
// contrôlé » : l'override est refusé, seul reste le bypass N2 (acte conscient, tracé).
OverrideTopSoftwareN1M1 := MaintN1
                           AND PRG_02_Acquisition.Data.EncoderM1.Homed
                           AND NOT PRG_02_Acquisition.Data.EncoderM1.HomingSuspect
                           AND GVL_IHM.M1TreuilRetenue.Cmd.BtnOverrideTopSoftware;
OverrideTopSoftwareN1M2 := MaintN1
                           AND PRG_02_Acquisition.Data.EncoderM2.Homed
                           AND NOT PRG_02_Acquisition.Data.EncoderM2.HomingSuspect
                           AND GVL_IHM.M2TreuilBenne.Cmd.BtnOverrideTopSoftware;

// --- Bypass EFFECTIFS de la famille position (individuel OR commun, SANS gate de mode — dérogation MES 2026) ---
BypassM1TopLimitSwitchEff   := (GVL_IHM.M1TreuilRetenue.Bypass.TopLimitSwitch   OR GVL_IHM.Commun.Bypass.TopLimitSwitch);
BypassM1TopLimitSoftwareEff := (GVL_IHM.M1TreuilRetenue.Bypass.TopLimitSoftware OR GVL_IHM.Commun.Bypass.TopLimitSoftware);
BypassM1CableLimitSwitchEff := (GVL_IHM.M1TreuilRetenue.Bypass.CableLimitSwitch OR GVL_IHM.Commun.Bypass.CableLimitSwitch);
BypassM1LimitLegalEff       := (GVL_IHM.M1TreuilRetenue.Bypass.LimitLegal       OR GVL_IHM.Commun.Bypass.LimitLegal);
BypassM1MecaDEff            := GVL_IHM.M1TreuilRetenue.Bypass.MecaD;
BypassM2TopLimitSwitchEff   := (GVL_IHM.M2TreuilBenne.Bypass.TopLimitSwitch      OR GVL_IHM.Commun.Bypass.TopLimitSwitch);
BypassM2TopLimitSoftwareEff := (GVL_IHM.M2TreuilBenne.Bypass.TopLimitSoftware    OR GVL_IHM.Commun.Bypass.TopLimitSoftware);
BypassM2CableLimitSwitchEff := (GVL_IHM.M2TreuilBenne.Bypass.CableLimitSwitch    OR GVL_IHM.Commun.Bypass.CableLimitSwitch);
BypassM2LimitLegalEff       := (GVL_IHM.M2TreuilBenne.Bypass.LimitLegal          OR GVL_IHM.Commun.Bypass.LimitLegal);
BypassM2MecaDEff            := GVL_IHM.M2TreuilBenne.Bypass.MecaD;

// --- Limite haute logicielle active -------------------------------------------------------
// Nominal 7,5 m (CfgCableLimitAscent_M) ; 8,5 m (CfgTopSensorPos_M) sous override N1 momentané
// ou bypass N2 latché du FDC logiciel. M2 conserve son décalage benne (M2_LimitShift) dans les
// deux cas : l'override ne modifie que l'assiette de référence, pas la géométrie M1/M2.
// Le seuil haut nominal est un arrêt immédiat (distance de ralentissement = 0 m).
// En override/bypass MAINT, seul le FDC haut matériel définit la borne : il reste non-bypassable.
TopLimitM1_M := SEL(OverrideTopSoftwareN1M1 OR BypassM1TopLimitSoftwareEff,
                    _CommunCfgPersist.CfgCableLimitAscent_M,
                    _WinchM1CfgPersist.CfgTopSensorPos_M);
TopLimitM2_M := SEL(OverrideTopSoftwareN1M2 OR BypassM2TopLimitSoftwareEff,
                    _CommunCfgPersist.CfgCableLimitAscent_M + M2_LimitShift,
                    _WinchM2CfgPersist.CfgTopSensorPos_M + M2_LimitShift);

// --- Usage effectif d'un override/bypass de position → re-homing obligatoire ---------------
// Publié vers PRG_03 (rang 03) ➔ FB_Modes arme HomingRequiredMx à la sortie du mode maintenance.
// Famille position : TopLimitSwitch, TopLimitSoftware, CableLimitSwitch, LimitLegal, MecaD
// (+ l'override N1 momentané).
PositionLimitOverriddenM1 := OverrideTopSoftwareN1M1 OR BypassM1TopLimitSwitchEff
                             OR BypassM1TopLimitSoftwareEff OR BypassM1CableLimitSwitchEff
                             OR BypassM1LimitLegalEff OR BypassM1MecaDEff;
PositionLimitOverriddenM2 := OverrideTopSoftwareN1M2 OR BypassM2TopLimitSwitchEff
                             OR BypassM2TopLimitSoftwareEff OR BypassM2CableLimitSwitchEff
                             OR BypassM2LimitLegalEff OR BypassM2MecaDEff;
{endregion}

{region "🛡️ §5bis Sécurité M1/M2"}

// FB_Safety_Winch M1/M2.
// Instancié avant instWinchM1/M2 : MovementCommanded lit RelayFwd/RelayRev du scan précédent
// (même lag 1 scan accepté que M4/Translation, jamais sur Reset/SafeStop/PowerCutOff/sortie finale).
instSafetyWinchM1(
    Enable                 := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM1,
    Reset                  := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged  := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                   := PRG_03_Modes_Cycle.Data.Auth.Mode,
    SyncEnable             := PRG_03_Modes_Cycle.Data.Auth.SyncEnable,
    JoystickOnline         := PRG_02_Acquisition.Data.Network.Joystick.Online,
    JoystickOperational    := PRG_02_Acquisition.Data.Network.Joystick.Operational,
    HeartbeatIhmOk         := GVL_IHM.Commun.HeartbeatIhmOk,
    EncoderAvailable       := PRG_02_Acquisition.Data.EncoderM1.Measurement.EncoderAvailable,
    EncoderFaultBypass     := GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault,
    ThermalFeedback        := NOT PRG_02_Acquisition.HwIn.Winch.M1_ThermalOk_DI,
    BrakeThermalFeedback   := NOT PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI,
    SlackCableDetected     := NOT PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI,
    PhaseRotationOk        := PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI,
    TopPositionSensor      := PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI,
    InReferencingMode      := PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Busy,
    CablePosM              := PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM,
    CfgCableLimitDescentM  := _WinchM1CfgPersist.CfgCableLimitDescent_M,
    LimitLegalReached      := GVL_IHM.Commun.LimitLegalReached,
    ReqAscent              := M1LogicReqAscent,
    ReqDescend             := M1LogicReqDescend,
    MovementCommanded      := instWinchM1.RelayFwd OR instWinchM1.RelayRev,
    Homed                  := PRG_02_Acquisition.Data.EncoderM1.Homed,
    HomingSuspect          := PRG_02_Acquisition.Data.EncoderM1.HomingSuspect,
    TopLimitM              := TopLimitM1_M,
    FwdRevSpeedFeedbackOff := PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI,
    BrakeFeedback          := PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI,
    JoystickYNeutral       := (PRG_02_Acquisition.Data.Joystick.AxisY.Direction = 0),
    BenneHoldStillActive   := instBucket.Lifecycle.Busy,
    ExpectedOtherWinchPosM := PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM - instBucket.ActiveOffsetM,
    BenneBusy              := instBucket.Lifecycle.Busy,
    OtherWinchInhibited    := PRG_03_Modes_Cycle.Data.Auth.InhibitM2,
    MeasuredSpeedMps       := PRG_02_Acquisition.Data.EncoderM1.Measurement.Speed_Mps,
    MeasuredSpeedSignedMps := PRG_02_Acquisition.Data.EncoderM1.Measurement.SignedSpeed_Mps,
    MeasuredSpeedValid     := PRG_02_Acquisition.Data.EncoderM1.Measurement.SpeedValid,
    SpeedBandMaxMps        := _WinchSpeedConfig.SpeedBandMaxMps[5],
    // Matrice AF-05 §4bis : bypass transmis SANS gate de mode (dérogation MES 2026, tous modes).
    // Le bypass commun reste en OR avec l'individuel (pilotage "both") — câblage d'origine inchangé.
    BypassGlobal           := GVL_IHM.M1TreuilRetenue.Bypass.Global,
    BypassSafety           := GVL_IHM.M1TreuilRetenue.Bypass.Safety,
    BypassProcess          := (GVL_IHM.M1TreuilRetenue.Bypass.Process
                              OR GVL_IHM.Commun.Bypass.SlackCable),
    // OR avec le bypass commun (Commun.Bypass) -- leve la
    // protection sur les 2 treuils simultanement pour le pilotage "both", sans retirer le
    // bypass individuel pour le pilotage a l'unite.
    BypassTopLimitSwitch   := BypassM1TopLimitSwitchEff,
    BypassTopLimitSoftware := BypassM1TopLimitSoftwareEff,
    BypassCableLimitSwitch := BypassM1CableLimitSwitchEff,
    BypassLimitLegal       := BypassM1LimitLegalEff,
    BypassOperatorComm     := GVL_IHM.M1TreuilRetenue.Bypass.OperatorComm,
    BypassPhaseRotation    := GVL_IHM.M1TreuilRetenue.Bypass.PhaseRotation,
    BypassBrakeThermal     := GVL_IHM.M1TreuilRetenue.Bypass.BrakeThermal,
    BypassMotorThermal     := GVL_IHM.M1TreuilRetenue.Bypass.MotorThermal,
    BypassMecaA            := GVL_IHM.M1TreuilRetenue.Bypass.MecaA,
    BypassMecaB            := GVL_IHM.M1TreuilRetenue.Bypass.MecaB,
    BypassMecaC            := GVL_IHM.M1TreuilRetenue.Bypass.MecaC,
    BypassMecaD            := BypassM1MecaDEff,
    BypassMecaE            := GVL_IHM.M1TreuilRetenue.Bypass.MecaE,
    ExternalSyncEscalation := PRG_06_Outputs.Data.ContactorMismatchEscalated
);

instSafetyWinchM2(
    Enable                 := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM2,
    Reset                  := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged  := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                   := PRG_03_Modes_Cycle.Data.Auth.Mode,
    SyncEnable             := PRG_03_Modes_Cycle.Data.Auth.SyncEnable,
    JoystickOnline         := PRG_02_Acquisition.Data.Network.Joystick.Online,
    JoystickOperational    := PRG_02_Acquisition.Data.Network.Joystick.Operational,
    HeartbeatIhmOk         := GVL_IHM.Commun.HeartbeatIhmOk,
    EncoderAvailable       := PRG_02_Acquisition.Data.EncoderM2.Measurement.EncoderAvailable,
    EncoderFaultBypass     := GVL_IHM.M2TreuilBenne.Bypass.EncoderFault,
    ThermalFeedback        := NOT PRG_02_Acquisition.HwIn.Winch.M2_ThermalOk_DI,
    BrakeThermalFeedback   := NOT PRG_02_Acquisition.HwIn.Machine.M1_M2_M3_BrakeThermalOk_DI,
    SlackCableDetected     := NOT PRG_02_Acquisition.HwIn.Winch.M2_TensionedCable_DI,
    PhaseRotationOk        := PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI,
    TopPositionSensor      := PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI,
    InReferencingMode      := PRG_02_Acquisition.Data.EncoderM2.Measurement.HomingLifecycle.Busy,
    CablePosM              := PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM,
    CfgCableLimitDescentM  := _WinchM2CfgPersist.CfgCableLimitDescent_M,
    LimitLegalReached      := GVL_IHM.Commun.LimitLegalReached,
    ReqAscent              := M2LogicReqAscent,
    ReqDescend             := M2LogicReqDescend,
    MovementCommanded      := instWinchM2.RelayFwd OR instWinchM2.RelayRev,
    Homed                  := PRG_02_Acquisition.Data.EncoderM2.Homed,
    HomingSuspect          := PRG_02_Acquisition.Data.EncoderM2.HomingSuspect,
    TopLimitM              := TopLimitM2_M,
    FwdRevSpeedFeedbackOff := PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI,
    BrakeFeedback          := PRG_02_Acquisition.HwIn.Winch.M2_BrakeIsOpen_DI,
    JoystickYNeutral       := (PRG_02_Acquisition.Data.Joystick.AxisY.Direction = 0),
    BenneHoldStillActive   := FALSE,
    ExpectedOtherWinchPosM := PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM + instBucket.ActiveOffsetM,
    BenneBusy              := instBucket.Lifecycle.Busy,
    OtherWinchInhibited    := PRG_03_Modes_Cycle.Data.Auth.InhibitM1,
    MeasuredSpeedMps       := PRG_02_Acquisition.Data.EncoderM2.Measurement.Speed_Mps,
    MeasuredSpeedSignedMps := PRG_02_Acquisition.Data.EncoderM2.Measurement.SignedSpeed_Mps,
    MeasuredSpeedValid     := PRG_02_Acquisition.Data.EncoderM2.Measurement.SpeedValid,
    SpeedBandMaxMps        := _WinchSpeedConfig.SpeedBandMaxMps[5],
    // Matrice AF-05 §4bis (identique à M1 ci-dessus)
    BypassGlobal           := GVL_IHM.M2TreuilBenne.Bypass.Global,
    BypassSafety           := GVL_IHM.M2TreuilBenne.Bypass.Safety,
    BypassProcess          := (GVL_IHM.M2TreuilBenne.Bypass.Process
                              OR GVL_IHM.Commun.Bypass.SlackCable),
    // OR avec le bypass commun (Commun.Bypass) -- voir M1 ci-dessus
    BypassTopLimitSwitch   := BypassM2TopLimitSwitchEff,
    BypassTopLimitSoftware := BypassM2TopLimitSoftwareEff,
    BypassCableLimitSwitch := BypassM2CableLimitSwitchEff,
    BypassLimitLegal       := BypassM2LimitLegalEff,
    BypassOperatorComm     := GVL_IHM.M2TreuilBenne.Bypass.OperatorComm,
    BypassPhaseRotation    := GVL_IHM.M2TreuilBenne.Bypass.PhaseRotation,
    BypassBrakeThermal     := GVL_IHM.M2TreuilBenne.Bypass.BrakeThermal,
    BypassMotorThermal     := GVL_IHM.M2TreuilBenne.Bypass.MotorThermal,
    BypassMecaA            := GVL_IHM.M2TreuilBenne.Bypass.MecaA,
    BypassMecaB            := GVL_IHM.M2TreuilBenne.Bypass.MecaB,
    BypassMecaC            := GVL_IHM.M2TreuilBenne.Bypass.MecaC,
    BypassMecaD            := BypassM2MecaDEff,
    BypassMecaE            := GVL_IHM.M2TreuilBenne.Bypass.MecaE,
    ExternalSyncEscalation := PRG_06_Outputs.Data.ContactorMismatchEscalated
);

SafeStopM1_Raw := SafeStopM1_Raw OR instSafetyWinchM1.SafeStop;
SafeStopM2_Raw := SafeStopM2_Raw OR instSafetyWinchM2.SafeStop;
// SafetyPermit = sorties FB_Safety_Winch (safety pure)
SafetyPermitM1_Descend := instSafetyWinchM1.DescendPermit;
SafetyPermitM2_Descend := instSafetyWinchM2.DescendPermit;
SafetyPermitM1_Ascent  := instSafetyWinchM1.AscentPermit;
SafetyPermitM2_Ascent  := instSafetyWinchM2.AscentPermit;
// ProcessAndSafetyPermit = Safety AND Process (ex _Raw)
ProcessAndSafetyPermitM1_Descend := ProcessPermitM1_Descend AND SafetyPermitM1_Descend;
ProcessAndSafetyPermitM2_Descend := ProcessPermitM2_Descend AND SafetyPermitM2_Descend;

// Mode "vidage à la trémie" : descente M1 ET M2 interdite tant
// que M3 n'est pas à P1 (travail) ou en position Maintenance -- verrouille la séquence
// descente-treuil / translation pour se rapprocher d'un enchaînement automatique sûr.
// Décision et calcul centralisés dans PRG_03_Modes_Cycle.Data.SequenceState.DumpAtTremieDescentLocked
IF PRG_03_Modes_Cycle.Data.SequenceState.DumpAtTremieDescentLocked THEN
    ProcessAndSafetyPermitM1_Descend := FALSE;
    ProcessAndSafetyPermitM2_Descend := FALSE;
END_IF;
// Permis de montée assistée : consommé depuis FB_ExtractionAssist (via le contrat benne).
// Hors extraction (NOT ExtractionAssistActive), la montée reste libre ; pendant l'extraction,
// la montée n'est autorisée que si l'assistant la délivre (AscentPermit, qui intègre les
// conditions process AscentControlSafe/AscentNominalSafe). Polarité fail-safe (TRUE = autorisé).
ProcessAndSafetyPermitM1_Ascent := ProcessPermitM1_Ascent AND SafetyPermitM1_Ascent;
ProcessAndSafetyPermitM2_Ascent := ProcessPermitM2_Ascent AND SafetyPermitM2_Ascent;

// 🔗 Couplage atomique M1/M2 : indépendant de SyncEnable. Actif en synchro
// classique (anti-télescopage) OU dès qu'un mouvement both est demandé — même si
// SyncEnable=FALSE (ex. MAINT_N2). Permet qu'une permission ou un SafeStop d'un
// treuil bloque l'autre : départ jamais isolé. WinchBothMotionActive est défini en
// §1 (disponible avant §5).
CoupledBoth := instWinchSync.SyncActive OR WinchBothMotionActive;

SafeStopM1_Active := SafeStopM1_Raw OR (CoupledBoth AND SafeStopM2_Raw);
SafeStopM2_Active := SafeStopM2_Raw OR (CoupledBoth AND SafeStopM1_Raw);
// EffectivePermit = ProcessAndSafetyPermit combine au couplage synchro (anti-télescopage)
// ET gaté par NOT SafeStop (défauts thermique/phase/codeur/méca) : le permit reflète « prêt à
// fonctionner », aligné sur M3 (PRG_05 §1ter). SafeStopM1/M2_Active agrège déjà le couplage
// synchro (SafeStop de l'autre treuil pendant SyncActive) — cohérent avec l'anti-télescopage.
EffectivePermitM1_Descend := ProcessAndSafetyPermitM1_Descend AND NOT SafeStopM1_Active AND (NOT CoupledBoth OR ProcessAndSafetyPermitM2_Descend);
EffectivePermitM2_Descend := ProcessAndSafetyPermitM2_Descend AND NOT SafeStopM2_Active AND (NOT CoupledBoth OR ProcessAndSafetyPermitM1_Descend);
EffectivePermitM1_Ascent  := ProcessAndSafetyPermitM1_Ascent  AND NOT SafeStopM1_Active AND (NOT CoupledBoth OR ProcessAndSafetyPermitM2_Ascent);
EffectivePermitM2_Ascent  := ProcessAndSafetyPermitM2_Ascent  AND NOT SafeStopM2_Active AND (NOT CoupledBoth OR ProcessAndSafetyPermitM1_Ascent);

// Permis canoniques benne : ouverture = M2 vers le bas, fermeture = M2 vers le haut.
// Les fins de course benne restent des faits fonctionnels distincts des limites treuil.
EffectivePermitBucket_Open := EffectivePermitM2_Descend
    AND PRG_02_Acquisition.Data.EncoderM1.Homed
    AND PRG_02_Acquisition.Data.EncoderM2.Homed
    AND (instBucket.Lifecycle.Busy OR NOT _BucketState.IsOpen)
    AND NOT instBucket.Fault.Error;
EffectivePermitBucket_Close := EffectivePermitM2_Ascent
    AND PRG_02_Acquisition.Data.EncoderM1.Homed
    AND PRG_02_Acquisition.Data.EncoderM2.Homed
    AND (instBucket.Lifecycle.Busy OR NOT _BucketState.IsClosed)
    AND NOT instBucket.Fault.Error;

// Défense en profondeur benne : le permis directionnel benne est appliqué au
// même scan aux deux niveaux M2, uniquement lorsque FB_Bucket est producteur.
M2AscentPermitApplied := EffectivePermitM2_Ascent
    AND (NOT instBucket.M2_RunRequest OR EffectivePermitBucket_Close);
M2DescendPermitApplied := EffectivePermitM2_Descend
    AND (NOT instBucket.M2_RunRequest OR EffectivePermitBucket_Open);

// 🔗 Agrégats Both : permis communs consommés par la commande both.
// = AND des 4 permits effectifs. Chaque axe garde sa vérité propre
// (EffectivePermitM*_*) ; en commande both, seul l'agrégat est consommé (§6),
// garantissant "les 2 treuils partent ensemble, ou aucun".

// 📉 Diagnostic IHM — cause priorisée du blocage Both (lecture seule, NC-100).
// N'a AUCUN effet de conduite : l'arrêt est porté par Both*Permit (§6, consommé par les
// 2 FB_Winch) et la défense en profondeur par la barrière finale (FB_WinchOutputInterlock,
// coupe par PermitFinalBlocked). Ordre : cause la plus grave gagne.
IF NOT WinchBothMotionActive THEN
    BothBlocked             := FALSE;
    BothBlockReason         := E_WinchTraceBlockReason.NONE;
ELSIF NOT ((WinchBothReqAscent AND EffectivePermitM1_Ascent AND EffectivePermitM2_Ascent)
        OR (WinchBothReqDescend AND EffectivePermitM1_Descend AND EffectivePermitM2_Descend)) THEN
    BothBlocked             := TRUE;
    BothBlockReason         := E_WinchTraceBlockReason.COUPLING_BLOCKED;
ELSE
    BothBlocked             := FALSE;
    BothBlockReason         := E_WinchTraceBlockReason.NONE;
END_IF;

// 🛡️ ArmingPermit : armer HONNETEMENT, seulement si au moins une action
// selectionnee peut REELLEMENT partir. Disponibilite par axe x sens + motif de
// blocage decode pour l'IHM / troubleshooting. Reprise apres perte = nouveau front
// homme-mort global (FB_Joystick : IF NOT ArmingPermit -> desarme le geste entier).
// EffectivePermitM*_* couvre deja process + safety + NOT SafeStop de cet axe +
// verif couplage ; on ajoute NOT Fault.Latched (faute finale) et, pour M3, le
// permis effectif directionnel + SafeStop/PowerCutOff M3 (bus PRG_05, lag 1 scan).
ArmM1AscentAvail  := EffectivePermitM1_Ascent  AND NOT instSafetyWinchM1.Fault.Latched;
ArmM1DescendAvail := EffectivePermitM1_Descend AND NOT instSafetyWinchM1.Fault.Latched;
ArmM2AscentAvail  := EffectivePermitM2_Ascent  AND NOT instSafetyWinchM2.Fault.Latched;
ArmM2DescendAvail := EffectivePermitM2_Descend AND NOT instSafetyWinchM2.Fault.Latched;
ArmM3TremieAvail  := PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Tremie
                     AND NOT PRG_05_Translation.Data.TranslationSafety.SafeStop
                     AND NOT PRG_05_Translation.Data.TranslationSafety.PowerCutOff;
ArmM3MaintenanceAvail := PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Maintenance
                     AND NOT PRG_05_Translation.Data.TranslationSafety.SafeStop
                     AND NOT PRG_05_Translation.Data.TranslationSafety.PowerCutOff;

ArmAnyAxisAvail := ArmM1AscentAvail OR ArmM1DescendAvail
               OR ArmM2AscentAvail OR ArmM2DescendAvail
               OR ArmM3TremieAvail OR ArmM3MaintenanceAvail;

// Conditions de base (AC1) — priorite decroissante pour le motif.
ArmBucketBusy := instBucket.Lifecycle.Busy OR BenneBusyFallEdge.Q;
ArmModeDisabled := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.DISABLE);
ArmContactorOff := NOT PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
ArmPowerCutOff := instSafetyWinchM1.PowerCutOff OR instSafetyWinchM2.PowerCutOff
               OR PRG_05_Translation.Data.TranslationSafety.PowerCutOff;

IF ArmModeDisabled THEN
    Data.ArmingAvailability.BlockedReason := E_ArmingBlockReason.MODE_DISABLE;
ELSIF ArmContactorOff THEN
    Data.ArmingAvailability.BlockedReason := E_ArmingBlockReason.CONTACTOR_OFF;
ELSIF ArmPowerCutOff THEN
    Data.ArmingAvailability.BlockedReason := E_ArmingBlockReason.POWER_CUTOFF;
ELSIF ArmBucketBusy THEN
    Data.ArmingAvailability.BlockedReason := E_ArmingBlockReason.BUCKET_BUSY;
ELSIF NOT ArmAnyAxisAvail THEN
    Data.ArmingAvailability.BlockedReason := E_ArmingBlockReason.ALL_AXES_BLOCKED;
ELSE
    Data.ArmingAvailability.BlockedReason := E_ArmingBlockReason.NONE;
END_IF;

ArmingPermit := NOT ArmModeDisabled AND NOT ArmContactorOff AND NOT ArmPowerCutOff
             AND NOT ArmBucketBusy AND ArmAnyAxisAvail;

Data.ArmingAvailability.M1AscentAvail      := ArmM1AscentAvail;
Data.ArmingAvailability.M1DescendAvail     := ArmM1DescendAvail;
Data.ArmingAvailability.M2AscentAvail      := ArmM2AscentAvail;
Data.ArmingAvailability.M2DescendAvail     := ArmM2DescendAvail;
Data.ArmingAvailability.M3TremieAvail      := ArmM3TremieAvail;
Data.ArmingAvailability.M3MaintenanceAvail := ArmM3MaintenanceAvail;
Data.ArmingAvailability.AnyAxisAvail       := ArmAnyAxisAvail;


{endregion}

{region "📐 §5ter Clamp palier"}
// === 🧮 §5ter AGRÉGATEUR DE CLAMP DE PALIER ===
// Bornes communes identiques M1=M2, puis M2 applique ses limites benne propres.
// Plafond = MIN des sources plafond ; plancher = MAX des sources plancher ; plafond gagne.
// Synchro (instWinchSync) calculée en §4, en amont : SyncDeviationWarn réduit les DEUX treuils.

// --- Sources communes (M1 = M2) ---
CommonMaxStepAscent   := EffectiveMaxStepAscent;
CommonMaxStepDescent := EffectiveMaxStepDescent;

// SECURITE ISO 13849 - posture fail-safe : bridage vitesse hors homing.
// Codeurs non references => position non fiable => plafond palier 1 sur M1 ET M2,
// montee ET descente. Symetrique (aucun vecteur contacteur M1<>M2). Sans ce garde-fou,
// palier 5 accessible non reference : les caps de position (SlowdownMaxStep,
// SyncDeviationWarn) sont eux-memes inactifs sans reference fiable. Debridage assume
// plus tard sur capteur haut actif (position redevenue connue).
IF NOT (PRG_02_Acquisition.Data.EncoderM1.HomedAndReliable
        AND PRG_02_Acquisition.Data.EncoderM2.HomedAndReliable) THEN
    CommonMaxStepAscent  := 1;
    CommonMaxStepDescent := 1;
END_IF;

IF instWinchSync.SyncDeviationWarn THEN
    CommonMaxStepAscent   := 1;
    CommonMaxStepDescent := 1;
END_IF;
IF PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ExtractionControlActive OR ExtractionControlActive THEN
    CommonMaxStepAscent := 1;
END_IF;
// Benne non fermee (ou mou de cable) EN PILOTAGE COUPLE : les DEUX treuils a palier 1.
// Brider M2 seul (bloc M2-propre ci-dessous) laisserait M1 monter plus vite -> vecteurs
// contacteurs M1<>M2 -> FB_SyncContactor (PRG_06) -> ContactorMismatch -> SafeStop.
// En couple les 2 treuils sont lies : la limite benne s'applique aux 2.
IF CoupledBoth AND (BucketNotClosedAscentCapStep1 OR SlackCableAscentCapStep1) THEN
    CommonMaxStepAscent := 1;
END_IF;

// Planchers communs : 1 (neutre) en montée ; en descente, 0 hors plongée.
// MinStepDown=0 signifie explicitement « aucun plancher » : seul FB_DiveSearch
// peut imposer un palier de plongée. Ne jamais réintroduire un minimum à 1 ici,
// sinon une inversion de sens ne peut plus atteindre StepNumber=0.
// Règle de l'agrégateur : plancher = MAX des sources plancher ; si plancher > plafond,
// LE PLAFOND GAGNE — le clamp final (consommation FB_Winch, lot aval) borne au plafond,
// on ne force donc jamais ici un palier au-delà de CommonMaxStepDescent.
CommonMinStepUp   := 1;
CommonMinStepDown := MAX(0, PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.MinStepDown);

// --- M2-propre (jamais vu par M1) ---
M2MaxStepUp   := CommonMaxStepAscent;
M2MaxStepDown := CommonMaxStepDescent;
// Auto-séquencement benne (FB_Bucket) : palier 1 sur toute la manœuvre.
IF instBucket.M2_BucketJogLimit THEN
    M2MaxStepUp   := 1;
    M2MaxStepDown := 1;
END_IF;
// Jog unitaire M2 : palier libre en course, palier 1 uniquement dans la zone de
// ralentissement (JogSlowdownZoneM avant le point d'arrêt anticipé — cf. §5). Montée M2
// = fermeture, descente M2 = ouverture. Les zones sont calculées sur la position :
// si M1/M2 ne sont pas référencés, la position n'a pas de sens → repli palier 1 partout.
IF ManualBucketJogActive THEN
    IF NOT (PRG_02_Acquisition.Data.EncoderM1.Homed AND PRG_02_Acquisition.Data.EncoderM2.Homed) THEN
        M2MaxStepUp   := 1;
        M2MaxStepDown := 1;
    ELSE
        IF M2JogApproachClose THEN
            M2MaxStepUp := 1;
        END_IF;
        IF M2JogApproachOpen THEN
            M2MaxStepDown := 1;
        END_IF;
    END_IF;
END_IF;
IF BucketNotClosedAscentCapStep1 OR SlackCableAscentCapStep1 THEN
    M2MaxStepUp := 1;
END_IF;
M2MinStepUp   := CommonMinStepUp;
M2MinStepDown := CommonMinStepDown;
{endregion}

{region "⚙️ §6 Exécution M1/M2"}
// === ⚙️ §6 EXÉCUTION FB_Winch (M1 & M2) ===

// Estimateurs de bande vitesse réelle appelés AVANT instWinchM1/M2 : leur sortie
// SpeedBand alimente MeasuredSpeedBand (2e étage du garde-fou FB_Winch) sur le même
// scan. Sources vitesse identiques à FB_Safety_Winch (§5bis).
instWinchLoadEstimatorM1(
    Enable                  := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM1,
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    Mode                    := PRG_03_Modes_Cycle.Data.Auth.Mode,
    ActiveSpeedStep         := instWinchM1.StepNumber,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    MeasuredSpeedMps        := PRG_02_Acquisition.Data.EncoderM1.Measurement.Speed_Mps,
    MeasuredSpeedSignedMps  := PRG_02_Acquisition.Data.EncoderM1.Measurement.SignedSpeed_Mps,
    SpeedConfig             := _WinchSpeedConfig,
    LoadTable               := _WinchLoadEstimateTable
);

instWinchLoadEstimatorM2(
    Enable                  := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM2,
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    Mode                    := PRG_03_Modes_Cycle.Data.Auth.Mode,
    ActiveSpeedStep         := instWinchM2.StepNumber,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    MeasuredSpeedMps        := PRG_02_Acquisition.Data.EncoderM2.Measurement.Speed_Mps,
    MeasuredSpeedSignedMps  := PRG_02_Acquisition.Data.EncoderM2.Measurement.SignedSpeed_Mps,
    SpeedConfig             := _WinchSpeedConfig,
    LoadTable               := _WinchLoadEstimateTable
);

// --- M1 : assemblage des structs (CODESYS refuse l'initialiseur inline en appel) ---
// 🔗 Routage permit both : en commande both (WinchBothMotionActive=TRUE), les
// Chaque treuil consomme directement son permis directionnel canonique ; Both est
// validé par l'AND des deux axes dans l'arbitrage.
// jamais les permits individuels directement. En unitaire (M1 seul / M2 seul / benne M2),
// chacun consomme son permit effectif propre (comportement inchangé). SEL(a, b, c) := a ? c : b.
ReqM1Winch.RunRequest               := M1LogicRunRequest;
ReqM1Winch.ReqAscent                := M1LogicReqAscent;
ReqM1Winch.ReqDescend               := M1LogicReqDescend;
ReqM1Winch.SpeedStepReq             := M1LogicRequestStepTgt;
ReqM1Winch.MaxStepUp                := CommonMaxStepAscent;
ReqM1Winch.MaxStepDown              := CommonMaxStepDescent;
// Plancher palier descente plongée Kobold : plancher plongée agrégé en §5ter, injecté
// sur la cible (jamais sur StepNumber). Aucun effet si StartStop=FALSE.
ReqM1Winch.MinStepDown              := CommonMinStepDown;
ReqM1Winch.HomingApproachActive     := PRG_03_Modes_Cycle.Data.Auth.HomingApproachEnable;
// Même limite haute active que FB_Safety_Winch (7,5 m / 8,5 m sous override).
ReqM1Winch.TopLimitM                := TopLimitM1_M;
ReqM1Winch.BottomLimitM             := BottomLimitM1_Active;
ReqM1Winch.SyncCoupled              := instWinchSync.SyncActive;

M1WinchSensors.CablePosM          := PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM;
M1WinchSensors.Homed              := PRG_02_Acquisition.Data.EncoderM1.Homed;
M1WinchSensors.HomingSuspect      := PRG_02_Acquisition.Data.EncoderM1.HomingSuspect;
M1WinchSensors.ContactorsAllOff   := PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI;
M1WinchSensors.MeasuredSpeedBand  := instWinchLoadEstimatorM1.SpeedBand;
// Garde-fou vitesse mesuree : DESACTIVE par defaut (AF_Partie-10 §9bis, FB_Winch_v2.1 /
// FB_SpeedStep_v1.0 SpeedGuardEnable := FALSE). Le TRUE code en dur etait un reste de
// mise en service : il rendait la capacite de palier otage de instWinchSync (tout ecart
// sync -> SpeedGuardReady=FALSE -> clamp palier 1, y compris en montee).
// ⚠️ DETTE SAFETY -S5 : le garde-fou vitesse mesuree est HORS SERVICE. Le FB de
// gouvernance nominale annonce (FB_WinchRateInterlock) n'existe PAS dans CODE/.
// Decision : risque ACTE et documente — la surveillance survitesse reelle est portee par
// FB_Safety_Winch (gelee : harnais VAR_IN_OUT indisponible). Ne PAS armer une
// survitesse sur une table non prouvee. A re-trancher a la livraison .
// ⚠️ tache est BLOQUE (contrat C4 TASK_CONTRACT_AUTORITE_2_INTERLOCKS.yaml,
// ARRET VALIDATION HUMAINE requis : autorite, T_max/DropConfirmDelay, classification
// Fault.Error, argument PLr ; prerequis// non livres). Ne PAS creer
// FB_WinchRateInterlock hors de ce contrat — la logique de garde-fou existe deja dans
// FB_Winch §5 et reste volontairement desactivee (SpeedGuardEnable := FALSE) tant que la
// table SpeedBandMaxMps n'est pas validee en charge reelle (AF-10 §7.3 TBD).
M1WinchSensors.SpeedGuardEnable   := FALSE;
M1WinchSensors.SpeedGuardReady    := NOT instWinchSync.Fault.Error;

M1WinchCfg.SpeedStepTable         := _WinchSpeedStepTable;
M1WinchCfg.SlowdownDistanceTop_M  := _CommunCfgPersist.WinchSlowdownDistanceTop_M;
M1WinchCfg.SlowdownDistanceBottom_M := _CommunCfgPersist.WinchSlowdownDistanceBottom_M;
M1WinchCfg.SlowdownMaxStep        := _CommunCfgPersist.WinchSlowdownMaxStep;
// Cadence de rampe palier (FB_WinchStepShaper) : montee +1 cran / delai, descente immediate.
// Champs non portes par la persistante -> assignes explicitement (le defaut de type n'est
// pas applique au runtime pour ce VAR local de struct). 1 s montee / 0,5 s descente.
M1WinchCfg.StepRampDelayAscent    := T#1000ms;
M1WinchCfg.StepRampDelayDescent   := T#500ms;

instWinchM1(
    Enable                  := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM1,
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    SafeStop                := SafeStopM1_Active,
    DescendPermit           := EffectivePermitM1_Descend,
    AscentPermit            := EffectivePermitM1_Ascent,
    WinchRequest            := ReqM1Winch,
    Sensors                 := M1WinchSensors,
    Config                  := M1WinchCfg,
    // ContactorFeedback (n°3 de la matrice) et Global — sans gate de mode (dérogation MES 2026).
    BypassContactorCheck    := (GVL_IHM.M1TreuilRetenue.Bypass.Global OR GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback),
    BypassGlobal            := GVL_IHM.M1TreuilRetenue.Bypass.Global
);

// --- M2 : assemblage des structs ---
ReqM2Winch.RunRequest               := M2LogicRunRequest;
ReqM2Winch.ReqAscent                := M2LogicReqAscent;
ReqM2Winch.ReqDescend               := M2LogicReqDescend;
ReqM2Winch.SpeedStepReq             := M2LogicRequestStepTgt;
// Clamp de palier agrégé en §5ter : bornes communes M1=M2 (CommonMaxStep*) puis
// M2-propre (M2MaxStep*) — M2_BucketJogLimit / ManualBucketLimitsActive ne réduisent
// jamais M1 (pilotage unitaire M2). BucketNotClosedAscentCapStep1 /
// SlackCableAscentCapStep1 : réduisent M1 aussi UNIQUEMENT en pilotage couplé
// (CoupledBoth) — les 2 treuils liés doivent rester au même palier.
// D13 : reconstruction de table M2 supprimée — le clamp M2MaxStep* := 1 suffit
// (StepNumber ≤ 1 → seuls les états P1 sont commandés).
ReqM2Winch.MaxStepUp                := M2MaxStepUp;
ReqM2Winch.MaxStepDown              := M2MaxStepDown;
// Plancher palier descente plongée Kobold : plancher M2-propre agrégé en §5ter, injecté
// sur la cible (jamais sur StepNumber). Aucun effet si StartStop=FALSE.
ReqM2Winch.MinStepDown              := M2MinStepDown;
ReqM2Winch.HomingApproachActive     := PRG_03_Modes_Cycle.Data.Auth.HomingApproachEnable;
// Même limite haute active que FB_Safety_Winch (M2_LimitShift conservé).
ReqM2Winch.TopLimitM                := TopLimitM2_M;
ReqM2Winch.BottomLimitM             := BottomLimitM2_Active;
ReqM2Winch.SyncCoupled              := instWinchSync.SyncActive;

M2WinchSensors.CablePosM          := PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM;
M2WinchSensors.Homed              := PRG_02_Acquisition.Data.EncoderM2.Homed;
M2WinchSensors.HomingSuspect      := PRG_02_Acquisition.Data.EncoderM2.HomingSuspect;
M2WinchSensors.ContactorsAllOff   := PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI;
M2WinchSensors.MeasuredSpeedBand  := instWinchLoadEstimatorM2.SpeedBand;
// Garde-fou vitesse mesuree : DESACTIVE par defaut (idem M1 ci-dessus, AF_Partie-10 §9bis).
M2WinchSensors.SpeedGuardEnable   := FALSE;
M2WinchSensors.SpeedGuardReady    := NOT instWinchSync.Fault.Error;

M2WinchCfg.SpeedStepTable         := _WinchSpeedStepTable;
M2WinchCfg.SlowdownDistanceTop_M  := _CommunCfgPersist.WinchSlowdownDistanceTop_M;
M2WinchCfg.SlowdownDistanceBottom_M := _CommunCfgPersist.WinchSlowdownDistanceBottom_M;
M2WinchCfg.SlowdownMaxStep        := _CommunCfgPersist.WinchSlowdownMaxStep;
// Cadence de rampe palier (FB_WinchStepShaper) : montee +1 cran / delai, descente immediate.
M2WinchCfg.StepRampDelayAscent    := T#1000ms;
M2WinchCfg.StepRampDelayDescent   := T#500ms;

instWinchM2(
    Enable                  := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM2,
    Reset                   := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    SafeStop                := SafeStopM2_Active,
    DescendPermit           := M2DescendPermitApplied,
    AscentPermit            := M2AscentPermitApplied,
    WinchRequest            := ReqM2Winch,
    Sensors                 := M2WinchSensors,
    Config                  := M2WinchCfg,
    // Idem M1 ci-dessus
    BypassContactorCheck    := (GVL_IHM.M2TreuilBenne.Bypass.Global OR GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback),
    BypassGlobal            := GVL_IHM.M2TreuilBenne.Bypass.Global
);

// ── Collecteurs passifs d'apprentissage vitesse par palier ──
// Appelés APRÈS instWinchM1/M2 : StepNumber lu = palier courant du scan (pas de lag).
// Dérivations des entrées de collecte :
//   • LoadPresent : charge présente si l'estimateur de charge (même source vitesse) estime
//     une charge >= 50 % (seuil de mise en service, à confirmer sur site).
//   • StableForLearn : treuil commandé (palier > 0) et sans défaut — conditions stables.
// Collecteur STRICTEMENT PASSIF : aucune commande moteur, aucune surveillance survitesse
// (la survitesse reste, gelée — voir bandeau §6 M1/M2 SpeedGuardEnable).
LoadPresentM1 := (instWinchLoadEstimatorM1.EstimatedLoadPct >= 50.0);
LoadPresentM2 := (instWinchLoadEstimatorM2.EstimatedLoadPct >= 50.0);
StableForLearnM1 := (instWinchM1.StepNumber > 0) AND NOT instWinchM1.Fault.Error;
StableForLearnM2 := (instWinchM2.StepNumber > 0) AND NOT instWinchM2.Fault.Error;

instWinchSpeedLearningM1(
    Enable              := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM1,
    LearnStart          := GVL_IHM.M1TreuilRetenue.Cmd.BtnLearnSpeed,
    WinchId             := 1,
    ReqAscent          := M1LogicReqAscent,
    ReqDescend         := M1LogicReqDescend,
    StepNumber          := instWinchM1.StepNumber,
    MeasuredSpeedMps    := PRG_02_Acquisition.Data.EncoderM1.Measurement.Speed_Mps,
    MeasuredSpeedValid  := PRG_02_Acquisition.Data.EncoderM1.Measurement.SpeedValid,
    LoadPresent         := LoadPresentM1,
    StableForLearn      := StableForLearnM1,
    Config              := _WinchSpeedLearnCfg,
    Table               := _WinchSpeedLearnTable
);

instWinchSpeedLearningM2(
    Enable              := (PRG_03_Modes_Cycle.Data.Auth.Mode <> E_Mode.DISABLE) AND NOT PRG_03_Modes_Cycle.Data.Auth.InhibitM2,
    LearnStart          := GVL_IHM.M2TreuilBenne.Cmd.BtnLearnSpeed,
    WinchId             := 2,
    ReqAscent          := M2LogicReqAscent,
    ReqDescend         := M2LogicReqDescend,
    StepNumber          := instWinchM2.StepNumber,
    MeasuredSpeedMps    := PRG_02_Acquisition.Data.EncoderM2.Measurement.Speed_Mps,
    MeasuredSpeedValid  := PRG_02_Acquisition.Data.EncoderM2.Measurement.SpeedValid,
    LoadPresent         := LoadPresentM2,
    StableForLearn      := StableForLearnM2,
    Config              := _WinchSpeedLearnCfg,
    Table               := _WinchSpeedLearnTable
);


{endregion}

{region "📤 §7 Publication demandes"}
// === 📤 §7 PUBLICATION DEMANDES BRUTES (WinchM1/M2FinalInterlockRequest) ===

WinchM1FinalInterlockRequest.Enable := TRUE;
WinchM1FinalInterlockRequest.Reset := PRG_07_Supervision.FaultMachineReset_IHM;
WinchM1FinalInterlockRequest.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
WinchM1FinalInterlockRequest.SafeStop := SafeStopM1_Active;
// Plus de BrakeReleaseRequest/
// BrakeCommandOpenConfirmed calcules par FB_Winch — la barriere finale
// (FB_WinchOutputInterlock) recoit le retour PHYSIQUE brut directement,
// et calcule elle-meme BrakeCmd := RelayFwd OR RelayRev (voir bandeau de ce FB).
WinchM1FinalInterlockRequest.BrakeFeedback := PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI;
WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff := PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI;
WinchM1FinalInterlockRequest.RequestedRelayFwd := instWinchM1.RelayFwd;
WinchM1FinalInterlockRequest.RequestedRelayRev := instWinchM1.RelayRev;
WinchM1FinalInterlockRequest.RequestedContactor1 := instWinchM1.Contactor1;
WinchM1FinalInterlockRequest.RequestedContactor2 := instWinchM1.Contactor2;
WinchM1FinalInterlockRequest.RequestedContactor3 := instWinchM1.Contactor3;
WinchM1FinalInterlockRequest.RequestedContactor4 := instWinchM1.Contactor4;
WinchM1FinalInterlockRequest.RequestedStep := instWinchM1.StepNumber;
WinchM1FinalInterlockRequest.PowerCutOff := instSafetyWinchM1.PowerCutOff;
WinchM1FinalInterlockRequest.AscentPermit := EffectivePermitM1_Ascent;
WinchM1FinalInterlockRequest.DescendPermit := EffectivePermitM1_Descend;

WinchM2FinalInterlockRequest.Enable := TRUE;
WinchM2FinalInterlockRequest.Reset := PRG_07_Supervision.FaultMachineReset_IHM;
WinchM2FinalInterlockRequest.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
WinchM2FinalInterlockRequest.SafeStop := SafeStopM2_Active;
WinchM2FinalInterlockRequest.BrakeFeedback := PRG_02_Acquisition.HwIn.Winch.M2_BrakeIsOpen_DI;
WinchM2FinalInterlockRequest.FwdRevSpeedFeedbackOff := PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI;
WinchM2FinalInterlockRequest.RequestedRelayFwd := instWinchM2.RelayFwd;
WinchM2FinalInterlockRequest.RequestedRelayRev := instWinchM2.RelayRev;
WinchM2FinalInterlockRequest.RequestedContactor1 := instWinchM2.Contactor1;
WinchM2FinalInterlockRequest.RequestedContactor2 := instWinchM2.Contactor2;
WinchM2FinalInterlockRequest.RequestedContactor3 := instWinchM2.Contactor3;
WinchM2FinalInterlockRequest.RequestedContactor4 := instWinchM2.Contactor4;
WinchM2FinalInterlockRequest.RequestedStep := instWinchM2.StepNumber;
WinchM2FinalInterlockRequest.PowerCutOff := instSafetyWinchM2.PowerCutOff;
WinchM2FinalInterlockRequest.AscentPermit := M2AscentPermitApplied;
WinchM2FinalInterlockRequest.DescendPermit := M2DescendPermitApplied;

{endregion}

{region "📊 §8 Publication états IHM"}
// === 📤 §8 PUBLICATION ÉTATS IHM (faits publics, lecture seule) ===
// Projection déléguée à FB_WinchStateProjection () : recopie bit-identique
// des sources → WinchM1State/WinchM2State/WinchM1Safety/WinchM2Safety/CableLimitAscent.
// Aucune logique de commande modifiée (non-régression). SyncState/BucketState/
// Benne_IsRoughlyClosed/GLV_IHM restent ici (hors scope du FB).
instWinchStateProjection(
    EncoderM1 := PRG_02_Acquisition.Data.EncoderM1,
    EncoderM2 := PRG_02_Acquisition.Data.EncoderM2,
    WinchM1Ref := instWinchM1,
    WinchM2Ref := instWinchM2,
    SafetyM1 := instSafetyWinchM1,
    SafetyM2 := instSafetyWinchM2,
    InterlockM1 := PRG_06_Outputs.instWinchOutputInterlockM1,
    InterlockM2 := PRG_06_Outputs.instWinchOutputInterlockM2,
    Auth := PRG_03_Modes_Cycle.Data.Auth,
    HwInWinch := PRG_02_Acquisition.HwIn.Winch,
    HwRealWinch := PRG_02_Acquisition.HwReal.Winch,
    M1_PrevSpeed_Mps := M1_PrevSpeed_Mps,
    M2_PrevSpeed_Mps := M2_PrevSpeed_Mps,
    M1LogicRequestSpeedCmd_Pct := M1LogicRequestSpeedCmd_Pct,
    M2LogicRequestSpeedCmd_Pct := M2LogicRequestSpeedCmd_Pct,
    BottomLimitM1_Active := BottomLimitM1_Active,
    BottomLimitM2_Active := BottomLimitM2_Active,
    SafeStopM1_Active := SafeStopM1_Active,
    SafeStopM2_Active := SafeStopM2_Active,
    EffectivePermitM1_Ascent := EffectivePermitM1_Ascent,
    EffectivePermitM1_Descend := EffectivePermitM1_Descend,
    EffectivePermitM2_Ascent := EffectivePermitM2_Ascent,
    EffectivePermitM2_Descend := EffectivePermitM2_Descend,
    M2_LimitShift := M2_LimitShift,
    CfgCableLimitAscent_M := _CommunCfgPersist.CfgCableLimitAscent_M,
    CfgCableLimitDescentM1_M := _WinchM1CfgPersist.CfgCableLimitDescent_M,
    CfgCableLimitDescentM2_M := _WinchM2CfgPersist.CfgCableLimitDescent_M,
    EncoderM1_Operational := PRG_02_Acquisition.Data.Network.EncoderM1.Operational,
    EncoderM2_Operational := PRG_02_Acquisition.Data.Network.EncoderM2.Operational,
    M1PowerCutOffSafetyInfo := PRG_06_Outputs.M1PowerCutOffSafetyInfo,
    M1SafeStopSafetyInfo := PRG_06_Outputs.M1SafeStopSafetyInfo,
    M1BlockedBySafetyInfo := PRG_06_Outputs.M1BlockedBySafetyInfo,
    M2PowerCutOffSafetyInfo := PRG_06_Outputs.M2PowerCutOffSafetyInfo,
    M2SafeStopSafetyInfo := PRG_06_Outputs.M2SafeStopSafetyInfo,
    M2BlockedBySafetyInfo := PRG_06_Outputs.M2BlockedBySafetyInfo
);
WinchM1State := instWinchStateProjection.WinchM1State;
WinchM2State := instWinchStateProjection.WinchM2State;
WinchM1Safety := instWinchStateProjection.WinchM1Safety;
WinchM2Safety := instWinchStateProjection.WinchM2Safety;
CableLimitAscentM1Reached := instWinchStateProjection.CableLimitAscentM1Reached;
CableLimitAscentM2Reached := instWinchStateProjection.CableLimitAscentM2Reached;

SyncState.DeltaPos_M := instWinchSync.SignedDeltaPosM;
SyncState.SyncActive := instWinchSync.SyncActive;
SyncState.SyncWarn := instWinchSync.SyncWarn;
SyncState.SyncDeviationWarn := instWinchSync.SyncDeviationWarn;
SyncState.Ready := instWinchSync.Ready;
SyncState.Error := instWinchSync.Fault.Error;
SyncState.ErrorId := instWinchSync.Fault.ErrorId;
IF instWinchSync.Fault.Error THEN
    SyncState.FBState := E_State.ERROR;
ELSIF instWinchSync.SyncActive THEN
    SyncState.FBState := E_State.BUSY;
ELSE
    SyncState.FBState := E_State.READY;
END_IF;

BucketState.MechState := _BucketState;
BucketState.MechState.ActiveOffsetValid := instBucket.ActiveOffsetValid;
IF instBucket.Fault.Error THEN
    BucketState.FBState := E_State.ERROR;
ELSIF instBucket.Lifecycle.Busy THEN
    BucketState.FBState := E_State.BUSY;
ELSE
    BucketState.FBState := E_State.READY;
END_IF;
BucketState.ActiveOffset_M := instBucket.ActiveOffsetM;
BucketState.M2RunRequest := instBucket.M2_RunRequest;
BucketState.M2ReqAscent := instBucket.M2_ReqAscent;
BucketState.M2ReqDescend := instBucket.M2_ReqDescend;
BucketState.M2BucketJogLimit := instBucket.M2_BucketJogLimit;
BucketState.ManualBucketLimitsActive := ManualBucketLimitsActive;
BucketState.OffsetStateMismatchWarn := instBucket.OffsetStateMismatchWarn;
BucketState.M2PositionCorrected := PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM - instBucket.ActiveOffsetM;
BucketState.Ready := instBucket.Ready;
BucketState.Busy := instBucket.Lifecycle.Busy;
BucketState.Done := instBucket.Lifecycle.Done;
BucketState.Error := instBucket.Fault.Error;
BucketState.ErrorId := instBucket.Fault.ErrorId;
BucketState.RemainingTravel_M := instBucket.RemainingTravelM;
BucketState.DeltaPosition_M := instBucket.DeltaPosition_M;
BucketState.CloseActive := instBucket.CloseReq;
BucketState.OpenActive := instBucket.OpenReq;
// Reflète le séquencement auto : occupé sur une ouverture/fermeture qu'IL a armée, ou en phase
// vitesse contrôlée post-fermeture.
BucketState.AutoBucketSeqActive := (instBucket.Lifecycle.Busy AND (WinchBothDiveBucketOpenArmed OR WinchBothAscentBucketCloseArmed)) OR ExtractionControlActive;
BucketState.CoupledDiveOpenArmed := WinchBothDiveBucketOpenArmed;
BucketState.CoupledAscentCloseArmed := WinchBothAscentBucketCloseArmed;
BucketState.MachineHomed := PRG_02_Acquisition.Data.MachineHoming.Homed;
BucketState.MachineHomingStep := PRG_02_Acquisition.Data.MachineHoming.Step;
BucketState.MachineHomingInstruction := PRG_02_Acquisition.Data.MachineHoming.Instruction;
BucketState.MachineHomingFailed := PRG_02_Acquisition.Data.MachineHoming.Failed;
BucketState.MachineHomingActive := PRG_02_Acquisition.Data.MachineHoming.Active;
BucketState.MachineHomingLossSafeStop := PRG_02_Acquisition.Data.MachineHoming.HomingLoss;
BucketState.ExtractionControlActive := ExtractionControlActive;
BucketState.CoupledMotionBlockedByBucket := WinchBothMotionBlockedByBucket;
GVL_IHM.Commun.KoboldImmersionConfirmed := KoboldImmersionConfirmed;
GVL_IHM.Commun.KoboldBottomTouchLatched := KoboldBottomTouchLatched;

// Tolérance matière benne : « à peu près fermée » = fermée OU
// intermédiaire proche de l'offset fermé (tolérance 2 m). Évite le blocage au fond sur
// matière dense (galets) qui ne ferme jamais à 100% de la consigne fine.
Benne_IsRoughlyClosed := _BucketState.IsClosed
    OR (_BucketState.IsIntermediate
        AND (instBucket.DeltaPosition_M >= (_BucketCfgPersist.Config.OffsetCloseM - 2.0)));

{region "🕵️ §8bis Trace blocage"}
// === 🕵️ §8bis TRACE DE BLOCAGE TERRAIN (cause priorisée + horodatage) ===
// Diagnostic lecture seule, publié via Data.TraceM1/M2 et consommé par FB_TroubleshootingView.
// L'ordre IF/ELSIF EST l'ordre de priorité (cf. E_WinchTraceBlockReason) : la cause la plus
// grave gagne. BlockReasonTimestamp est latched au premier scan du changement (1 scan, mémoire).
// Aucune action de conduite ne dépend de ces champs.

// --- M1 ---
TraceM1.DescendPermitEffective := EffectivePermitM1_Descend;
TraceM1.AscentPermitEffective  := EffectivePermitM1_Ascent;
TraceM1.AscentPermitApplied     := EffectivePermitM1_Ascent;
TraceM1.DescendPermitApplied    := EffectivePermitM1_Descend;
TraceM1.FinalPermitBlocked      := (ReqM1Winch.RunRequest AND ReqM1Winch.ReqAscent AND NOT EffectivePermitM1_Ascent)
                               OR (ReqM1Winch.RunRequest AND ReqM1Winch.ReqDescend AND NOT EffectivePermitM1_Descend);
TraceM1.SafeStopActive         := SafeStopM1_Active;
TraceM1.SafeStopSourceSafety   := instSafetyWinchM1.SafeStop;
TraceM1.SafeStopSourceInput    := PRG_02_Acquisition.Data.InputModules.Fault
                                  OR PRG_02_Acquisition.Data.MachineHoming.HomingLoss
                                  OR instBucket.M1SlipDetected;
TraceM1.SafeStopSourceSync     := ((instWinchSync.Fault.ErrorId AND 16#0002) <> 16#0000)
                                  OR (instWinchSync.SyncActive AND SafeStopM2_Raw);
TraceM1.PowerCutOffActive      := instSafetyWinchM1.PowerCutOff;
TraceM1.Inhibited              := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.DISABLE)
                                  OR PRG_03_Modes_Cycle.Data.Auth.InhibitM1;
TraceM1.FinalInterlockError    := WinchM1State.FinalInterlockError;
TraceM1.FinalInterlockReason   := WinchM1State.FinalInterlockReason;
TraceM1.StepNumber             := WinchM1State.StepNumber;

IF instSafetyWinchM1.PowerCutOff THEN
    TraceM1.BlockReason := E_WinchTraceBlockReason.POWER_CUTOFF;
ELSIF TraceM1.Inhibited THEN
    TraceM1.BlockReason := E_WinchTraceBlockReason.AXIS_DISABLED;
ELSIF SafeStopM1_Active THEN
    TraceM1.BlockReason := E_WinchTraceBlockReason.SAFESTOP;
ELSIF instSafetyWinchM1.Fault.Error THEN
    TraceM1.BlockReason := E_WinchTraceBlockReason.SAFETY_FAULT;
ELSIF NOT (SafetyPermitM1_Ascent OR SafetyPermitM1_Descend) THEN
    TraceM1.BlockReason := E_WinchTraceBlockReason.SAFETY_PERMIT_MISSING;
ELSIF NOT (ProcessPermitM1_Ascent OR ProcessPermitM1_Descend) THEN
    TraceM1.BlockReason := E_WinchTraceBlockReason.PROCESS_PERMIT_MISSING;
ELSIF NOT (EffectivePermitM1_Ascent OR EffectivePermitM1_Descend) THEN
    TraceM1.BlockReason := E_WinchTraceBlockReason.COUPLING_BLOCKED;
ELSIF instWinchM1.Fault.Error THEN
    TraceM1.BlockReason := E_WinchTraceBlockReason.WINCH_FAULT;
ELSIF WinchM1State.FinalInterlockError THEN
    TraceM1.BlockReason := E_WinchTraceBlockReason.FINAL_INTERLOCK_BLOCKED;
ELSE
    TraceM1.BlockReason := E_WinchTraceBlockReason.NONE;
END_IF;
IF TraceM1.BlockReason <> TraceM1_PrevReason THEN
    TraceM1.BlockReasonTimestamp := TIME_TO_UDINT(TIME());
END_IF;
TraceM1_PrevReason := TraceM1.BlockReason;

// --- M2 ---
TraceM2.DescendPermitEffective := EffectivePermitM2_Descend;
TraceM2.AscentPermitEffective  := EffectivePermitM2_Ascent;
TraceM2.AscentPermitApplied     := M2AscentPermitApplied;
TraceM2.DescendPermitApplied    := M2DescendPermitApplied;
TraceM2.FinalPermitBlocked      := (ReqM2Winch.RunRequest AND ReqM2Winch.ReqAscent AND NOT EffectivePermitM2_Ascent)
                               OR (ReqM2Winch.RunRequest AND ReqM2Winch.ReqDescend AND NOT EffectivePermitM2_Descend);
TraceM2.SafeStopActive         := SafeStopM2_Active;
TraceM2.SafeStopSourceSafety   := instSafetyWinchM2.SafeStop;
TraceM2.SafeStopSourceInput    := PRG_02_Acquisition.Data.InputModules.Fault
                                  OR PRG_02_Acquisition.Data.MachineHoming.HomingLoss;
TraceM2.SafeStopSourceSync     := ((instWinchSync.Fault.ErrorId AND 16#0002) <> 16#0000)
                                  OR (instWinchSync.SyncActive AND SafeStopM1_Raw);
TraceM2.PowerCutOffActive      := instSafetyWinchM2.PowerCutOff;
TraceM2.Inhibited              := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.DISABLE)
                                  OR PRG_03_Modes_Cycle.Data.Auth.InhibitM2;
TraceM2.FinalInterlockError    := WinchM2State.FinalInterlockError;
TraceM2.FinalInterlockReason   := WinchM2State.FinalInterlockReason;
TraceM2.StepNumber             := WinchM2State.StepNumber;

IF instSafetyWinchM2.PowerCutOff THEN
    TraceM2.BlockReason := E_WinchTraceBlockReason.POWER_CUTOFF;
ELSIF TraceM2.Inhibited THEN
    TraceM2.BlockReason := E_WinchTraceBlockReason.AXIS_DISABLED;
ELSIF SafeStopM2_Active THEN
    TraceM2.BlockReason := E_WinchTraceBlockReason.SAFESTOP;
ELSIF instSafetyWinchM2.Fault.Error THEN
    TraceM2.BlockReason := E_WinchTraceBlockReason.SAFETY_FAULT;
ELSIF NOT (SafetyPermitM2_Ascent OR SafetyPermitM2_Descend) THEN
    TraceM2.BlockReason := E_WinchTraceBlockReason.SAFETY_PERMIT_MISSING;
ELSIF NOT (ProcessPermitM2_Ascent OR ProcessPermitM2_Descend) THEN
    TraceM2.BlockReason := E_WinchTraceBlockReason.PROCESS_PERMIT_MISSING;
ELSIF NOT (EffectivePermitM2_Ascent OR EffectivePermitM2_Descend) THEN
    TraceM2.BlockReason := E_WinchTraceBlockReason.COUPLING_BLOCKED;
ELSIF instWinchM2.Fault.Error THEN
    TraceM2.BlockReason := E_WinchTraceBlockReason.WINCH_FAULT;
ELSIF WinchM2State.FinalInterlockError THEN
    TraceM2.BlockReason := E_WinchTraceBlockReason.FINAL_INTERLOCK_BLOCKED;
ELSE
    TraceM2.BlockReason := E_WinchTraceBlockReason.NONE;
END_IF;
IF TraceM2.BlockReason <> TraceM2_PrevReason THEN
    TraceM2.BlockReasonTimestamp := TIME_TO_UDINT(TIME());
END_IF;
TraceM2_PrevReason := TraceM2.BlockReason;

{endregion}

// 🧩 Cause de blocage priorisée sur l'état public IHM (miroir de la trace terrain §8bis)
WinchM1State.AxisBlockReason := TraceM1.BlockReason;
WinchM2State.AxisBlockReason := TraceM2.BlockReason;

// === 🔌 PUBLICATION BUS INTER-PRG (Data : ST_WinchInterPrg) ===
// Copie des structs internes vers le bus de sortie (producteur unique).
Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;
Data.WinchM2FinalInterlockRequest := WinchM2FinalInterlockRequest;
Data.M1LogicRequestSpeedCmd_Pct   := M1LogicRequestSpeedCmd_Pct;
Data.M2LogicRequestSpeedCmd_Pct   := M2LogicRequestSpeedCmd_Pct;
Data.KoboldContactorCmdArbitrated := KoboldContactorCmdArbitrated;
Data.WinchM1State                 := WinchM1State;
Data.WinchM2State                 := WinchM2State;
Data.WinchM1Safety                := WinchM1Safety;
Data.WinchM2Safety                := WinchM2Safety;
Data.SyncState                    := SyncState;
Data.WinchSyncError               := instWinchSync.Fault.Error;
Data.WinchSyncSignedDeltaPosM     := instWinchSync.SignedDeltaPosM;
Data.BucketState                  := BucketState;
Data.Benne_IsRoughlyClosed        := Benne_IsRoughlyClosed;
Data.BucketBusy                   := instBucket.Lifecycle.Busy;
Data.BucketDone                   := instBucket.Lifecycle.Done;
Data.BucketError                  := instBucket.Fault.Error;
Data.EffectivePermitBucket_Open   := EffectivePermitBucket_Open;
Data.EffectivePermitBucket_Close  := EffectivePermitBucket_Close;
Data.ArmingPermit                 := ArmingPermit;
Data.ProcessPermitM1_Ascent       := ProcessPermitM1_Ascent;
Data.ProcessPermitM1_Descend      := ProcessPermitM1_Descend;
Data.ProcessPermitM2_Ascent       := ProcessPermitM2_Ascent;
Data.ProcessPermitM2_Descend      := ProcessPermitM2_Descend;
Data.DescendPermitDiveBucketOpen  := DescendPermitDiveBucketOpen;
Data.ExtractionAssistActive       := ExtractionAssistActive;
Data.ExtractionAscentPermit       := PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.AscentPermit;
// Usage effectif d'un override/bypass de position (consommé PRG_03 → FB_Modes)
Data.PositionLimitOverriddenM1    := PositionLimitOverriddenM1;
Data.PositionLimitOverriddenM2    := PositionLimitOverriddenM2;
// 🕵️ Trace de blocage terrain (consommée FB_TroubleshootingView)
Data.TraceM1                      := TraceM1;
Data.TraceM2                      := TraceM2;
// 🔗 ATOMICITÉ BOTH : diagnostic IHM lecture seule
Data.BothActive                   := WinchBothMotionActive;
Data.BothBlocked                  := BothBlocked;
Data.BothBlockReason              := BothBlockReason;

{endregion}
END_PROGRAM
