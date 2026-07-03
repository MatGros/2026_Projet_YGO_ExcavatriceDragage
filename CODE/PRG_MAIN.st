(* ═══════════════════════════════════════════════════════════════
   🧠 PRG_MAIN — Orchestration séquentielle (diag → sécurité → métier)
   ───────────────────────────────────────────────────────────────
   📄 Contient : Joystick (axe Y) → FB_Safety_Winch(M1/M2) → FB_Winch
      (M1 + M2, consigne dupliquée sur le même axe) → relais, le
      pipeline codeur M1/M2 (FB_Encoder_Abs → FB_Encoder_Scale →
      FB_Encoder_Homing, flux nominal), et Joystick (axe X) →
      FB_Safety_Chariot → FB_Chariot (M3, mode DEGRADED_IO
      figé — intégré 2026-07-02, Partie11).
   🔧 CORRECTIF (2026-07-02, nouvel export Device.export — I/O réel) :
      1. Renommage métier Translation→Chariot (demande utilisateur),
         préfixe I/O physique M3 inchangé.
      2. RelayFwd/Rev, Contactor1..4 (→SpeedContactor_1..4), BrakeCmd,
         ContactorFeedbackFwd/Rev M1/M2 sont désormais câblés en I/O
         Mapping RÉEL (GVL_Winch_M1/M2_Stub réduits à BrakeFeedback
         seul). Capteur position haute réel : `M1_M2_TopPositionSensor`
         (remplace le stub `GVL_Homing_Stub`, supprimé).
      3. Nouveau : `M1_M2_SlackCableSwitch` (mou de câble, commun M1/M2)
         → `FB_Safety_Winch.ForbidDescent` (interdit UNIQUEMENT la
         descente) ; `M1/M2_ThermalFeedback` → `SafeStop` (arrêt total).
      4. Nouveau : sélecteur STUB maintenance pour les 4 capteurs
         position réels du chariot (Fosse1/Fosse2/Maintenance/Trémie),
         en attendant FB_Cycle — voir GVL_Chariot_M3_Stub.
   🔧 CORRECTIF (2026-07-03, retour terrain) :
      1. `EmergencyStopOk` est désormais un **I/O réel** (retour contacteur
         puissance géré par l'AU, résout Partie3/AUDIT Q11) — câblé d'abord
         sur les FB codeur/homing (Abs/Homing M1/M2) ce lot-ci.
      2. `Reset` des FB codeur/homing câblé sur `GVL_Encoder_Stub`
         (`M1/M2_Reset_IHM`, un bouton par codeur, acquitte Abs+Homing) —
         n'était câblé nulle part avant (`FALSE` figé = alarmes jamais
         acquittables).
      3. Nouveau `CODE/GVL_Encoder_Stub.st` : centralise tout ce qui doit
         être mappé IHM/réglé pour le pipeline codeur (Reset,
         ConfirmCoherence, Home, TopSensorPositionM) — déplacé depuis
         PRG_MAIN (`StubHomeButton_IHM`, `M1/M2_TopSensorPositionM`).
   🔧 CORRECTIF (2026-07-03bis, AUDIT D34/D35 — Q11 close) :
      `EmergencyStopOk` généralisé à TOUS les FB métier (Joystick/Safety_Winch/
      Winch/Safety_Chariot/Chariot), plus de `GVL_DEBUG.DBG_True` pour ce
      signal. Passe par `instIoMachine : FB_IO_Machine` (§1 ci-dessous) →
      `EmergencyStopOkCond`, seule variable câblée partout — permet de
      forcer/inverser (`InvertLogic`) en mise en service sans toucher au câblage.
   🔧 CORRECTIF (2026-07-03ter, Plan FB_IO final) : TOUT le conditionnement I/O réel
      de la machine (Commun/Winch M1/Winch M2/Chariot M3, entrées+sorties) regroupé
      dans UNE SEULE FB `FB_IO_Machine`, 1 SEULE instance `instIoMachine`, appelée
      2× par cycle (entrées tôt, sorties tard) — voir en-tête `FB_IO_Machine.st`.
   ⚠️ M2 ACTIF DÈS CE LOT (choix acté 2026-07-02) : dupliqué sur l'axe Y
      comme M1, SANS sélecteur ni FB_WinchSync réel (codeur pas encore
      exploité pour une synchro — voir DOC/AF_Partie9 §9).
   🎯 HOMING (2026-07-02) : ordre d'appel PAR TREUIL = Abs → Scale →
      Homing. `PresetRequest`/`PresetValue` (Homing → Abs) et
      `HomingRefRaw` (Homing → Scale) sont donc consommés avec **1 cycle
      de retard** (10 ms) — standard et sans conséquence (dépendance
      croisée assumée, cf. Partie10 §9bis).
   🔴 `PRG_COD1` (legacy, orphelin, jamais appelé dans aucune tâche) :
      À SUPPRIMER MANUELLEMENT dans CODESYS (clic droit → Delete) — sa
      logique est remplacée par les instances ci-dessous, câblées
      directement ici (principe 1 seul POU, Partie2 §0).
   🔴 CORRECTIF (2026-07-03bis) : `instSafety` (FB_Safety) retiré de PRG_MAIN — sorties
      (SafetyOk/SafeStop) jamais consommées, `LocalEmergencyStopTOR` était un stub jamais
      câblé. `FB_Safety` devient orphelin dans CODESYS (comme PRG_COD1) — à supprimer
      manuellement si aucun usage futur n'est prévu.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU PRG_MAIN) ===

PROGRAM PRG_MAIN
VAR_INPUT
END_VAR
VAR_OUTPUT
END_VAR

VAR_IN_OUT
END_VAR

VAR
    instDiagCanOpen  : FB_DiagCanOpen;       // Diagnostic CAN/Joystick
    instDiagEthercat : FB_DiagEthercat;      // Diagnostic EtherCAT (3 devices)

    // 🧰 FB_IO_MACHINE — conditionnement I/O réel de TOUTE la machine, 1 SEULE instance
    // (Commun/Winch M1/Winch M2/Chariot M3, entrées+sorties). Voir en-tête FB_IO_Machine.st :
    // APPELÉE 2× PAR CYCLE (1er appel entrées, plus bas avant Joystick/Homing/Safety/Winch/
    // Chariot ; 2e appel sorties, tout en bas après FB_Winch M1/M2 ET FB_Chariot).
    instIoMachine : FB_IO_Machine;

    // 📤 Sorties conditionnées (entrées) consommées par Homing/Safety_Winch/Winch/Chariot
    EmergencyStopOkCond         : BOOL;
    M1_M2_SlackCableSwitchCond  : BOOL;
    M1_M2_TopPositionSensorCond : BOOL;
    M1_ContactorFeedbackFwdCond : BOOL;
    M1_ContactorFeedbackRevCond : BOOL;
    M1_ThermalFeedbackCond      : BOOL;
    M2_ContactorFeedbackFwdCond : BOOL;
    M2_ContactorFeedbackRevCond : BOOL;
    M2_ThermalFeedbackCond      : BOOL;
    ChariotPosFosse1Cond        : BOOL;
    ChariotPosFosse2Cond        : BOOL;
    ChariotPosMaintenanceCond   : BOOL;
    ChariotPosTremieCond        : BOOL;

    // 🕹️ Instance unique du traitement joystick (pipeline calib/filtre/rampe)
    FB_Joystick_0 : FB_Joystick;

    // 🧲 CODEUR — acquisition + mise à l'échelle + homing (flux nominal), 1 instance par treuil
    instEncoderAbsM1   : FB_Encoder_Abs;
    instEncoderScaleM1 : FB_Encoder_Scale;
    instHomingM1       : FB_Encoder_Homing;   // ✅ 2026-07-02 — possède Calib (RETAIN) en interne
    instEncoderAbsM2   : FB_Encoder_Abs;
    instEncoderScaleM2 : FB_Encoder_Scale;
    instHomingM2       : FB_Encoder_Homing;

    // 🔌 SAFETY — bloc safety métier du domaine treuil, 1 instance par treuil
    // (même TYPE FB_Safety_Winch, 2 instances — Partie10 §7)
    instSafetyWinchM1 : FB_Safety_Winch;
    instSafetyWinchM2 : FB_Safety_Winch;

    // 🪝 WINCH — M1 et M2 (consigne dupliquée sur l'axe Y, Maintenance N1, choix 2026-07-02)
    instWinchM1 : FB_Winch;
    instWinchM2 : FB_Winch;

    // ↔️ CHARIOT — M3, axe X joystick (intégré 2026-07-02, mode DEGRADED_IO figé — Partie11 §7)
    instSafetyChariotM3 : FB_Safety_Chariot;
    instChariotM3       : FB_Chariot;

    // 🎚️ Stub Maintenance N1 pour ce lot (pas de FB_Modes) — à remplacer dès que
    // FB_Modes existera (source légitime Enable/Mode par bloc métier)
    StubWinchEnableN1 : BOOL := TRUE;
END_VAR

// ⚠️ CORRECTIF (2026-07-02) : les tables paliers étaient déclarées en VAR simple malgré le
// commentaire "RETAIN" — ne persistaient PAS réellement entre coupures/téléchargements.
// Corrigé : bloc VAR RETAIN dédié, comme le nécessitent aussi les paramètres de homing.
VAR RETAIN
    // 🪜 Table paliers M1 — réglable sans recompiler (Partie1 §Paliers)
    // ⚠️ Valeurs par défaut indicatives (cumulatives P1→P5) : À AJUSTER un par un
    //    selon le câblage réel des 4 contacteurs de vitesse M1 pendant la mise
    //    en service (chaque P<palier>R<relais> est modifiable en direct dans la
    //    vue instance CODESYS), et les seuils souhaités (%).
    M1_SpeedStepTable : ST_SpeedStepTable := (
        P1R1 := TRUE,  P1R2 := FALSE, P1R3 := FALSE, P1R4 := FALSE,
        P2R1 := TRUE,  P2R2 := TRUE,  P2R3 := FALSE, P2R4 := FALSE,
        P3R1 := TRUE,  P3R2 := TRUE,  P3R3 := TRUE,  P3R4 := FALSE,
        P4R1 := TRUE,  P4R2 := TRUE,  P4R3 := TRUE,  P4R4 := TRUE,
        P5R1 := TRUE,  P5R2 := TRUE,  P5R3 := TRUE,  P5R4 := TRUE,
        StepThreshold_Pct := [20.0, 40.0, 60.0, 80.0, 100.0]
    );

    // 🪜 Table paliers M2 — INDÉPENDANTE de M1 (Partie1 §Paliers : "table
    // indépendante par treuil"), mêmes valeurs par défaut indicatives à ajuster.
    M2_SpeedStepTable : ST_SpeedStepTable := (
        P1R1 := TRUE,  P1R2 := FALSE, P1R3 := FALSE, P1R4 := FALSE,
        P2R1 := TRUE,  P2R2 := TRUE,  P2R3 := FALSE, P2R4 := FALSE,
        P3R1 := TRUE,  P3R2 := TRUE,  P3R3 := TRUE,  P3R4 := FALSE,
        P4R1 := TRUE,  P4R2 := TRUE,  P4R3 := TRUE,  P4R4 := TRUE,
        P5R1 := TRUE,  P5R2 := TRUE,  P5R3 := TRUE,  P5R4 := TRUE,
        StepThreshold_Pct := [20.0, 40.0, 60.0, 80.0, 100.0]
    );
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU PRG_MAIN) ===

// 0. DIAGNOSTIC CAN (Joystick)
// TODO: Wire CanOnline/CanOperational from CAN task
instDiagCanOpen(
    Enable := TRUE,
    Reset := FALSE,
    CanOnline := TRUE,         // TBD: from CAN task
    CanOperational := TRUE     // TBD: from CAN task
);

// 0. DIAGNOSTIC ETHERCAT (Variateur, EncoderM1, EncoderM2)
// TODO: Wire WcState/SlaveState from EtherCAT task
instDiagEthercat(
    Enable := TRUE,
    Reset := FALSE,
    VariateurWcState := FALSE,         // TBD: from EtherCAT master
    VariateurSlaveState := 8,          // TBD: from EtherCAT master
    EncoderM1WcState := FALSE,         // TBD: from EtherCAT master
    EncoderM1SlaveState := 8,          // TBD: from EtherCAT master
    EncoderM2WcState := FALSE,         // TBD: from EtherCAT master
    EncoderM2SlaveState := 8           // TBD: from EtherCAT master
);

(* ═══════════════════════════════════════════════════════════════
   🧰 1. FB_IO_MACHINE — conditionnement I/O réel, 1er appel/2 (ENTRÉES)
   ───────────────────────────────────────────────────────────────
   TOUT le conditionnement d'entrées réelles de la machine (Commun + Winch M1 + Winch M2
   + Chariot M3) en UN SEUL appel, AVANT tout FB métier — clôt Q11/D32 (AUDIT) et
   généralise le principe (anti-rebond + `InvertLogic` forçable en mise en service sans
   toucher au câblage). 2e appel (sorties) plus bas, après FB_Winch/FB_Chariot — voir
   en-tête FB_IO_Machine.st.
   ═══════════════════════════════════════════════════════════════ *)

instIoMachine(
    EmergencyStopOkRaw        := EmergencyStopOk OR GVL_DEBUG.DBG_EmergencyStopOkBypass_TEST,  // 📡 I/O Mapping réel ⚠️ OR bypass TEST banc (GVL_DEBUG) — TOUJOURS FALSE avant essai réel
    SlackCableSwitchRaw       := M1_M2_SlackCableSwitch,    // 📡 I/O Mapping réel
    TopPositionSensorRaw      := M1_M2_TopPositionSensor OR GVL_DEBUG.DBG_TopPositionSensorBypass_TEST,  // 📡 I/O Mapping réel ⚠️ OR bypass TEST banc (GVL_DEBUG) — TOUJOURS FALSE avant essai réel
    M1ContactorFeedbackFwdRaw := M1_ContactorFeedbackFwd,   // 📡 I/O Mapping réel
    M1ContactorFeedbackRevRaw := M1_ContactorFeedbackRev,   // 📡 I/O Mapping réel
    M1ThermalFeedbackRaw      := M1_ThermalFeedback,        // 📡 I/O Mapping réel
    M2ContactorFeedbackFwdRaw := M2_ContactorFeedbackFwd,   // 📡 I/O Mapping réel
    M2ContactorFeedbackRevRaw := M2_ContactorFeedbackRev,   // 📡 I/O Mapping réel
    M2ThermalFeedbackRaw      := M2_ThermalFeedback,        // 📡 I/O Mapping réel
    ChariotPosFosse1Raw       := PosFosse1,                 // 📡 I/O Mapping réel
    ChariotPosFosse2Raw       := PosFosse2,                 // 📡 I/O Mapping réel
    ChariotPosMaintenanceRaw  := PosMaintenance,             // 📡 I/O Mapping réel
    ChariotPosTremieRaw       := PosTremie                  // 📡 I/O Mapping réel
);
EmergencyStopOkCond         := instIoMachine.EmergencyStopOkCond;
M1_M2_SlackCableSwitchCond  := instIoMachine.SlackCableSwitchCond;
M1_M2_TopPositionSensorCond := instIoMachine.TopPositionSensorCond;
M1_ContactorFeedbackFwdCond := instIoMachine.M1ContactorFeedbackFwdCond;
M1_ContactorFeedbackRevCond := instIoMachine.M1ContactorFeedbackRevCond;
M1_ThermalFeedbackCond      := instIoMachine.M1ThermalFeedbackCond;
M2_ContactorFeedbackFwdCond := instIoMachine.M2ContactorFeedbackFwdCond;
M2_ContactorFeedbackRevCond := instIoMachine.M2ContactorFeedbackRevCond;
M2_ThermalFeedbackCond      := instIoMachine.M2ThermalFeedbackCond;
ChariotPosFosse1Cond        := instIoMachine.ChariotPosFosse1Cond;
ChariotPosFosse2Cond        := instIoMachine.ChariotPosFosse2Cond;
ChariotPosMaintenanceCond   := instIoMachine.ChariotPosMaintenanceCond;
ChariotPosTremieCond        := instIoMachine.ChariotPosTremieCond;

// 2. ACQUISITION DU GESTE OPÉRATEUR SÉCURISÉ

(* ═══════════════════════════════════════════════════════════════
   🕹️ Appel du traitement joystick (version ST)
   ───────────────────────────────────────────────────────────────
   Câble les E/S physiques sur le FB, qui réalise en interne :
   calibration ➜ filtrage ➜ rampe ➜ % .
   📤 Résultat exploitable : FB_Joystick_0.AxisCmdX / .AxisCmdY
   📄 Doc métier : DOC/AF_Partie8_Fonction_Joystick_v1.1.md
   ═══════════════════════════════════════════════════════════════ *)

FB_Joystick_0(
    // 🟢 --- Autorisations & sécurité ---
    Enable          := GVL_DEBUG.DBG_True,      // ⚠️ DEBUG : remplacer par autorisation réelle
    EmergencyStopOk := EmergencyStopOkCond,      // 🛑 Conditionné FB_Input_Digital (D32/Q11 close)
    SafeStop        := GVL_DEBUG.DBG_False,     // ⚠️ DEBUG : vestige non conforme (Partie8 §6bis), hors périmètre de ce lot
    Reset           := FALSE,                   // ⚠️ À câbler : front acquittement défaut IHM

    // 🔌 --- État du bus CANopen (joystick) ---
    BusCanOpenOP    := instDiagCanOpen.busCanOpen,        // 📡 nœud CAN présent
    JoystickOP      := instDiagCanOpen.Joystick,          // 📡 esclave en mode opérationnel

    // 📥 --- Entrées brutes joystick ---
    RawX            := JoyXRaw_ANA1,            // 🕹️ axe X brut (0..10000)
    RawY            := JoyYRaw_ANA2,            // 🕹️ axe Y brut (0..10000)
    RawButton       := JoyBtnRaw,               // 🔘 bouton brut

    // 🎯 --- Calibration ---
    Calibrate       := FALSE,                   // ⚠️ À câbler : bouton recalage neutre (front)

    // 🎛️ --- Paramètres de traitement ---
    InvertX         := FALSE,
    InvertY         := FALSE,
    Deadband        := 10.0,                    // 🔧 2026-07-02 (demande utilisateur) : 5.0 → 10.0 %
    FilterTime      := TIME#100ms,
    AccelRate       := 50.0,
    DecelRate       := 150.0
);

(* ═══════════════════════════════════════════════════════════════
   🧲 3. CODEUR — Acquisition + mise à l'échelle + homing (M1=COD1, M2=COD2)
   ───────────────────────────────────────────────────────────────
   ✅ Canaux COD1_* ET COD2_* câblés en I/O Mapping (matériel réel,
      COD2 mappé 2026-07-02 — plus de stub `GVL_Encoder_M2_Stub`, retiré).
   🎯 Ordre d'appel PAR TREUIL : Abs → Scale → Homing (voir en-tête
      fichier — dépendance croisée Abs↔Homing assumée à 1 cycle près).
   ═══════════════════════════════════════════════════════════════ *)

instEncoderAbsM1(
    Enable              := TRUE,
    Reset               := M1_Reset_IHM,                    // 🖥️ GVL_Encoder_Stub — acquittement COD1
    EmergencyStopOk     := EmergencyStopOkCond,                 // 📡 I/O Mapping RÉEL (2026-07-03) — retour contacteur puissance/AU
    Mode                := E_Mode.MAINT_N1,                 // ⚠️ Stub — à remplacer par FB_Modes
    RawPosIn            := COD1_PosValue,                   // 📡 I/O Mapping déjà existant
    AlarmsIn            := COD1_Alarms,                     // 📡 I/O Mapping déjà existant
    WarningsIn          := COD1_Warnings,                   // 📡 I/O Mapping déjà existant
    SlaveOperational    := instDiagEthercat.EncoderM1.Operational,
    PresetRequest       := instHomingM1.PresetRequest,      // ✅ 2026-07-02 (1 cycle de retard, voir en-tête)
    PresetValue         := instHomingM1.PresetValue         // ✅ 2026-07-02
);
// 📤 Sorties preset → RxPDO réels (I/O Mapping déjà existant, canaux COD1)
COD1_PresettTrigCmd := instEncoderAbsM1.PresetTriggerCmd;
COD1_CodeSeqTrigCmd := instEncoderAbsM1.CodeSeqTriggerCmd;
COD1_PresetValue    := instEncoderAbsM1.PresetValueOut;

instEncoderScaleM1(
    RawPos          := instEncoderAbsM1.RawPos,
    HomingRefRaw    := instHomingM1.HomingRefRaw,           // ✅ 2026-07-02 (1 cycle de retard, voir en-tête)
    CableM_PerRev   := 2.0,  // Périmètre tambour confirmé 2026-07-02 (était 1.5 provisoire)
    PointsPerRev    := 8192
);

(* 🎯 Homing M1 (flux nominal) — bouton IHM (stub) + capteur position haute (stub GVL_Homing_Stub, commun M1+M2) *)
instHomingM1(
    Enable               := TRUE,
    Reset                := M1_Reset_IHM,                    // 🖥️ GVL_Encoder_Stub — acquittement COD1 (même bouton que instEncoderAbsM1)
    EmergencyStopOk      := EmergencyStopOkCond,                 // 📡 I/O Mapping RÉEL (2026-07-03) — retour contacteur puissance/AU
    Mode                 := E_Mode.MAINT_N1,                 // ⚠️ Stub — à remplacer par FB_Modes
    Home                 := (StubHomeButton_IHM AND ((HomingMode_IHM = 1) OR (HomingMode_IHM = 3))),  // 🖥️ GVL_Encoder_Stub — mode homing (1=M1seul, 2=M2seul, 3=Both)
    ConfirmCoherence     := M1_ConfirmCoherence_IHM,          // 🖥️ GVL_Encoder_Stub
    TopPositionSensor    := M1_M2_TopPositionSensorCond,     // 📡 Conditionné FB_IO_Machine
    TopSensorPositionM   := M1_TopSensorPositionM,           // RETAIN, réglable (§ calibration Partie10 §7bis)
    ContactorFeedbackFwd := M1_ContactorFeedbackFwdCond,     // 📡 Conditionné FB_IO_Machine
    ContactorFeedbackRev := M1_ContactorFeedbackRevCond,     // 📡 Conditionné FB_IO_Machine
    BrakeFeedback        := M1_BrakeFeedback,                // 🧪 STUB GVL_Winch_M1_Stub (seul signal encore non câblé)
    RawPos               := instEncoderAbsM1.RawPos,
    EncoderAvailable     := instEncoderAbsM1.EncoderAvailable,
    PresetAck            := instEncoderAbsM1.PresetAck,
    PresetNak            := instEncoderAbsM1.PresetNak,
    PointsPerRev         := 8192,
    MultiTurnRevsMax     := 4096,
    CableM_PerRev        := 2.0
);

instEncoderAbsM2(
    Enable              := TRUE,
    Reset               := M2_Reset_IHM,                    // 🖥️ GVL_Encoder_Stub — acquittement COD2
    EmergencyStopOk     := EmergencyStopOkCond,                 // 📡 I/O Mapping RÉEL (2026-07-03) — retour contacteur puissance/AU
    Mode                := E_Mode.MAINT_N1,                 // ⚠️ Stub — à remplacer par FB_Modes
    RawPosIn            := COD2_PosValue,                   // 📡 I/O Mapping (mappé 2026-07-02)
    AlarmsIn            := COD2_Alarms,                     // 📡 I/O Mapping (mappé 2026-07-02)
    WarningsIn          := COD2_Warnings,                   // 📡 I/O Mapping (mappé 2026-07-02)
    SlaveOperational    := instDiagEthercat.EncoderM2.Operational,
    PresetRequest       := instHomingM2.PresetRequest,      // ✅ 2026-07-02 (1 cycle de retard, voir en-tête)
    PresetValue         := instHomingM2.PresetValue         // ✅ 2026-07-02
);
// 📤 Sorties preset → RxPDO réels (I/O Mapping mappé 2026-07-02, comme COD1_PresettTrigCmd)
COD2_PresettTrigCmd := instEncoderAbsM2.PresetTriggerCmd;
COD2_CodeSeqTrigCmd := instEncoderAbsM2.CodeSeqTriggerCmd;
COD2_PresetValue    := instEncoderAbsM2.PresetValueOut;

instEncoderScaleM2(
    RawPos          := instEncoderAbsM2.RawPos,
    HomingRefRaw    := instHomingM2.HomingRefRaw,           // ✅ 2026-07-02 (1 cycle de retard, voir en-tête)
    CableM_PerRev   := 2.0,  // Périmètre tambour confirmé 2026-07-02 (était 1.5 provisoire)
    PointsPerRev    := 8192
);

(* 🎯 Homing M2 (flux nominal) — MÊME bouton IHM que M1 (référencement simultané, Partie10 §1) *)
instHomingM2(
    Enable               := TRUE,
    Reset                := M2_Reset_IHM,                    // 🖥️ GVL_Encoder_Stub — acquittement COD2 (même bouton que instEncoderAbsM2)
    EmergencyStopOk      := EmergencyStopOkCond,                 // 📡 I/O Mapping RÉEL (2026-07-03) — retour contacteur puissance/AU
    Mode                 := E_Mode.MAINT_N1,                 // ⚠️ Stub — à remplacer par FB_Modes
    Home                 := (StubHomeButton_IHM AND ((HomingMode_IHM = 2) OR (HomingMode_IHM = 3))),  // 🖥️ GVL_Encoder_Stub — mode homing (1=M1seul, 2=M2seul, 3=Both)
    ConfirmCoherence     := M2_ConfirmCoherence_IHM,          // 🖥️ GVL_Encoder_Stub
    TopPositionSensor    := M1_M2_TopPositionSensorCond,     // 📡 Conditionné FB_IO_Machine
    TopSensorPositionM   := M2_TopSensorPositionM,           // RETAIN, réglable (§ calibration Partie10 §7bis)
    ContactorFeedbackFwd := M2_ContactorFeedbackFwdCond,     // 📡 Conditionné FB_IO_Machine
    ContactorFeedbackRev := M2_ContactorFeedbackRevCond,     // 📡 Conditionné FB_IO_Machine
    BrakeFeedback        := M2_BrakeFeedback,                // 🧪 STUB GVL_Winch_M2_Stub (seul signal encore non câblé)
    RawPos               := instEncoderAbsM2.RawPos,
    EncoderAvailable     := instEncoderAbsM2.EncoderAvailable,
    PresetAck            := instEncoderAbsM2.PresetAck,
    PresetNak            := instEncoderAbsM2.PresetNak,
    PointsPerRev         := 8192,
    MultiTurnRevsMax     := 4096,
    CableM_PerRev        := 2.0
);

(* ═══════════════════════════════════════════════════════════════
   🔌 4. SÉCURITÉ MÉTIER TREUIL — FB_Safety_Winch (1 instance par treuil)
   ───────────────────────────────────────────────────────────────
   Périmètre : perte joystick/CAN (partagée) + perte codeur DE CE
   TREUIL (câblé, lot Codeur). SafeStop consommé par le FB_Winch du
   MÊME treuil (Partie10 §7 : split M1/M2 par composition, 2 instances).
   ═══════════════════════════════════════════════════════════════ *)

instSafetyWinchM1(
    Enable              := TRUE,
    Reset               := FALSE,                    // ⚠️ À câbler : front acquittement défaut IHM
    EmergencyStopOk     := EmergencyStopOkCond,        // 🛑 Conditionné FB_Input_Digital (D32/Q11 close)
    Mode                := E_Mode.MAINT_N1,           // ⚠️ Stub Maintenance N1 — à remplacer par FB_Modes
    JoystickOnline      := instDiagCanOpen.Joystick.Online,
    JoystickOperational := instDiagCanOpen.Joystick.Operational,
    EncoderAvailable    := instEncoderAbsM1.EncoderAvailable,
    ThermalFeedback     := M1_ThermalFeedbackCond,    // 📡 Conditionné FB_IO_Machine
    SlackCableDetected  := M1_M2_SlackCableSwitchCond // 📡 Conditionné FB_IO_Machine
);

instSafetyWinchM2(
    Enable              := TRUE,
    Reset               := FALSE,                    // ⚠️ À câbler : front acquittement défaut IHM
    EmergencyStopOk     := EmergencyStopOkCond,        // 🛑 Conditionné FB_Input_Digital (D32/Q11 close)
    Mode                := E_Mode.MAINT_N1,           // ⚠️ Stub Maintenance N1 — à remplacer par FB_Modes
    JoystickOnline      := instDiagCanOpen.Joystick.Online,
    JoystickOperational := instDiagCanOpen.Joystick.Operational,
    EncoderAvailable    := instEncoderAbsM2.EncoderAvailable,
    ThermalFeedback     := M2_ThermalFeedbackCond,    // 📡 Conditionné FB_IO_Machine
    SlackCableDetected  := M1_M2_SlackCableSwitchCond // 📡 Conditionné FB_IO_Machine
);

(* ═══════════════════════════════════════════════════════════════
   🪝 5. TREUILS M1 + M2 — FB_Winch (Maint N1, consigne dupliquée axe Y)
   ───────────────────────────────────────────────────────────────
   ⚠️ M2 dupliqué sur le MÊME axe Y que M1 (choix acté 2026-07-02) :
      les deux treuils reçoivent la même consigne, SANS FB_WinchSync
      réel (le codeur sert à la mesure/sécurité de ce lot, pas encore
      à une régulation d'écart M1/M2 — voir DOC/AF_Partie9 §9).
   🧪 M1_*/M2_* déclarées dans GVL_Winch_M1_Stub.st/GVL_Winch_M2_Stub.st
      (STUB logiciel). Quand le matériel sera prêt : SUPPRIMER le GVL
      concerné et saisir les mêmes noms en I/O Mapping (DOC §7 Étape 9bis).
   ═══════════════════════════════════════════════════════════════ *)

instWinchM1(
    Enable                  := StubWinchEnableN1,           // ⚠️ Stub Maint N1 — à remplacer par FB_Modes
    Reset                   := FALSE,                        // ⚠️ À câbler : front acquittement défaut IHM
    EmergencyStopOk         := EmergencyStopOkCond,           // 🛑 Conditionné FB_Input_Digital (D32/Q11 close)
    Mode                    := E_Mode.MAINT_N1,              // ⚠️ Stub Maintenance N1 — à remplacer par FB_Modes
    StartStop               := FB_Joystick_0.AxisCmdY.StartStop,
    SafeStop                := instSafetyWinchM1.SafeStop,
    ForbidDescent           := instSafetyWinchM1.ForbidDescent,  // 🆕 Mou de câble — masque UNIQUEMENT RelayRev
    Direction               := FB_Joystick_0.AxisCmdY.Direction,
    SpeedRefPct             := FB_Joystick_0.AxisCmdY.SpeedRef,
    SpeedStepTable          := M1_SpeedStepTable,
    ContactorFeedbackFwd    := M1_ContactorFeedbackFwdCond,  // 📡 Conditionné FB_IO_Machine
    ContactorFeedbackRev    := M1_ContactorFeedbackRevCond,  // 📡 Conditionné FB_IO_Machine
    BrakeFeedback           := M1_BrakeFeedback              // 🧪 STUB GVL_Winch_M1_Stub (seul signal encore non câblé)
);

instWinchM2(
    Enable                  := StubWinchEnableN1,           // ⚠️ Même stub Maint N1 que M1 — à remplacer par FB_Modes
    Reset                   := FALSE,                        // ⚠️ À câbler : front acquittement défaut IHM
    EmergencyStopOk         := EmergencyStopOkCond,           // 🛑 Conditionné FB_Input_Digital (D32/Q11 close)
    Mode                    := E_Mode.MAINT_N1,              // ⚠️ Stub Maintenance N1 — à remplacer par FB_Modes
    StartStop               := FB_Joystick_0.AxisCmdY.StartStop,   // ⚠️ Même consigne que M1 (dupliquée, pas de sélecteur)
    SafeStop                := instSafetyWinchM2.SafeStop,
    ForbidDescent           := instSafetyWinchM2.ForbidDescent,  // 🆕 Mou de câble — masque UNIQUEMENT RelayRev
    Direction               := FB_Joystick_0.AxisCmdY.Direction,   // ⚠️ Même consigne que M1
    SpeedRefPct             := FB_Joystick_0.AxisCmdY.SpeedRef,    // ⚠️ Même consigne que M1
    SpeedStepTable          := M2_SpeedStepTable,
    ContactorFeedbackFwd    := M2_ContactorFeedbackFwdCond,  // 📡 Conditionné FB_IO_Machine
    ContactorFeedbackRev    := M2_ContactorFeedbackRevCond,  // 📡 Conditionné FB_IO_Machine
    BrakeFeedback           := M2_BrakeFeedback              // 🧪 STUB GVL_Winch_M2_Stub (seul signal encore non câblé)
);

(* ═══════════════════════════════════════════════════════════════
   ↔️ 6. CHARIOT M3 — FB_Chariot (axe X, mode DEGRADED_IO figé)
   ───────────────────────────────────────────────────────────────
   Intégré 2026-07-02 (Partie11 §7, recommandation "option 1") : mode
   ETHERCAT non câblé (TBD protocole AC600, voir Partie11 §4) — CommMode
   figé DEGRADED_IO (relais sens + PV/GV), stubs neutres sur les entrées
   ETHERCAT (jamais utilisées tant que CommMode ne bascule pas).
   🔧 2026-07-02 : renommage métier Translation→Chariot (préfixe I/O
   physique M3 inchangé). `M3_BrakeCmd` désormais câblé en I/O Mapping
   RÉEL (retiré de GVL_Chariot_M3_Stub, reste sinon STUB logiciel).
   ⚠️ AVANT tout essai réel : Partie11 §4bis (paramétrage AC600,
   verrouillage source de commande Terminal) impératif.
   ═══════════════════════════════════════════════════════════════ *)

instSafetyChariotM3(
    Enable              := TRUE,
    Reset               := FALSE,                    // ⚠️ À câbler : front acquittement défaut IHM
    EmergencyStopOk     := EmergencyStopOkCond,        // 🛑 Conditionné FB_Input_Digital (D32/Q11 close)
    Mode                := E_Mode.MAINT_N1,           // ⚠️ Stub Maintenance N1 — à remplacer par FB_Modes
    JoystickOnline      := instDiagCanOpen.Joystick.Online,
    JoystickOperational := instDiagCanOpen.Joystick.Operational
);

// 🎯 SÉLECTEUR STUB MAINTENANCE (2026-07-02, demande utilisateur) — arbitre M3_PositionSensorTarget
// parmi les 4 capteurs position RÉELS du chariot, en attendant FB_Cycle (pas encore codé, qui
// fera cette sélection en exploitation normale — Partie11 §9bis). PosFosse1/PosFosse2/
// PosMaintenance/PosTremie : noms exacts I/O Mapping (Device.export).
CASE StubChariotPositionSelect_IHM OF
    1: M3_PositionSensorTarget := ChariotPosFosse1Cond;       // 📡 Conditionné FB_IO_Machine
    2: M3_PositionSensorTarget := ChariotPosFosse2Cond;       // 📡 Conditionné FB_IO_Machine
    3: M3_PositionSensorTarget := ChariotPosMaintenanceCond;  // 📡 Conditionné FB_IO_Machine
    4: M3_PositionSensorTarget := ChariotPosTremieCond;       // 📡 Conditionné FB_IO_Machine
ELSE
    M3_PositionSensorTarget := FALSE;   // 0 ou valeur hors plage = aucun capteur sélectionné
END_CASE;

instChariotM3(
    Enable                  := StubWinchEnableN1,           // ⚠️ Même stub Maint N1 que Winch — à remplacer par FB_Modes
    Reset                   := FALSE,                        // ⚠️ À câbler : front acquittement défaut IHM
    EmergencyStopOk         := EmergencyStopOkCond,           // 🛑 Conditionné FB_Input_Digital (D32/Q11 close)
    Mode                    := E_Mode.MAINT_N1,              // ⚠️ Stub Maintenance N1 — à remplacer par FB_Modes
    StartStop               := FB_Joystick_0.AxisCmdX.StartStop,
    SafeStop                := instSafetyChariotM3.SafeStop,
    CommMode                := E_ChariotCommMode.DEGRADED_IO,  // ⚠️ Figé (EtherCAT AC600 TBD, Partie11 §4/§7)
    Direction               := FB_Joystick_0.AxisCmdX.Direction,
    SpeedRefPct             := FB_Joystick_0.AxisCmdX.SpeedRef,
    PositionSensorTarget    := M3_PositionSensorTarget,      // 🎯 Arbitré par le sélecteur STUB ci-dessus
    DriveStatusWord         := 0,                            // 🔴 TBD ETHERCAT (Partie11 §4) — inerte en DEGRADED_IO
    DriveActualFreqHz       := 0.0,                          // 🔴 TBD ETHERCAT — inerte en DEGRADED_IO
    ContactorFeedbackFwd    := M3_ContactorFeedbackFwd,      // 🧪 STUB GVL_Chariot_M3_Stub
    ContactorFeedbackRev    := M3_ContactorFeedbackRev,      // 🧪 STUB GVL_Chariot_M3_Stub
    DriveFaultFeedback      := M3_DriveFaultFeedback,        // 🧪 STUB GVL_Chariot_M3_Stub (toujours FALSE, non câblé)
    BrakeFeedback           := M3_BrakeFeedback              // 🧪 STUB GVL_Chariot_M3_Stub
);

// 📤 Sorties chariot M3 STUB (GVL_Chariot_M3_Stub, pas de matériel réel — pas conditionnées,
// voir en-tête FB_IO_Machine.st) : RelayFwd/Rev/RelaySpeedGv
M3_RelayFwd     := instChariotM3.RelayFwd;
M3_RelayRev     := instChariotM3.RelayRev;
M3_RelaySpeedGv := instChariotM3.RelaySpeedGv;

// 🧪 SIMULATION (stub GVL_Chariot_M3_Stub) — voir note Winch M1 ci-dessus.
M3_ContactorFeedbackFwd := M3_RelayFwd;
M3_ContactorFeedbackRev := M3_RelayRev;

(* ═══════════════════════════════════════════════════════════════
   🧰 7. FB_IO_MACHINE — conditionnement I/O réel, 2e appel/2 (SORTIES)
   ───────────────────────────────────────────────────────────────
   TOUTES les sorties réelles de la machine (Winch M1 + Winch M2 + Chariot M3 BrakeCmd)
   en UN SEUL appel, APRÈS tous les FB métier (Command dispo seulement ici). Les
   entrées (*Raw/Invert*) sont omises : mêmes valeurs que le 1er appel, déjà traitées
   (voir en-tête FB_IO_Machine.st — instance retient ses VAR_INPUT entre les 2 appels).
   ═══════════════════════════════════════════════════════════════ *)

instIoMachine(
    M1RelayFwdCmd        := instWinchM1.RelayFwd,
    M1RelayRevCmd        := instWinchM1.RelayRev,
    M1SpeedContactor1Cmd := instWinchM1.Contactor1,
    M1SpeedContactor2Cmd := instWinchM1.Contactor2,
    M1SpeedContactor3Cmd := instWinchM1.Contactor3,
    M1SpeedContactor4Cmd := instWinchM1.Contactor4,
    M1BrakeCmdCmd        := instWinchM1.BrakeCmd,
    M2RelayFwdCmd        := instWinchM2.RelayFwd,
    M2RelayRevCmd        := instWinchM2.RelayRev,
    M2SpeedContactor1Cmd := instWinchM2.Contactor1,
    M2SpeedContactor2Cmd := instWinchM2.Contactor2,
    M2SpeedContactor3Cmd := instWinchM2.Contactor3,
    M2SpeedContactor4Cmd := instWinchM2.Contactor4,
    M2BrakeCmdCmd        := instWinchM2.BrakeCmd,
    ChariotBrakeCmdCmd   := instChariotM3.BrakeCmd
);

// 📤 Sorties treuil M1 → I/O Mapping RÉEL
M1_RelayFwd         := instIoMachine.M1RelayFwdOut;
M1_RelayRev         := instIoMachine.M1RelayRevOut;
M1_SpeedContactor_1 := instIoMachine.M1SpeedContactor1Out;
M1_SpeedContactor_2 := instIoMachine.M1SpeedContactor2Out;
M1_SpeedContactor_3 := instIoMachine.M1SpeedContactor3Out;
M1_SpeedContactor_4 := instIoMachine.M1SpeedContactor4Out;
M1_BrakeCmd         := instIoMachine.M1BrakeCmdOut;

// 🧪 SIMULATION (stub GVL_Winch_M1_Stub) — SEUL le retour frein reste non câblé côté device :
// miroir de la commande (contacteur "idéal"). RelayFwd/Rev/ContactorFeedback sont désormais
// des retours RÉELS câblés en I/O Mapping (plus de miroir logiciel).
M1_BrakeFeedback := M1_BrakeCmd;

// 📤 Sorties treuil M2 → I/O Mapping RÉEL
M2_RelayFwd         := instIoMachine.M2RelayFwdOut;
M2_RelayRev         := instIoMachine.M2RelayRevOut;
M2_SpeedContactor_1 := instIoMachine.M2SpeedContactor1Out;
M2_SpeedContactor_2 := instIoMachine.M2SpeedContactor2Out;
M2_SpeedContactor_3 := instIoMachine.M2SpeedContactor3Out;
M2_SpeedContactor_4 := instIoMachine.M2SpeedContactor4Out;
M2_BrakeCmd         := instIoMachine.M2BrakeCmdOut;

// 🧪 SIMULATION (stub GVL_Winch_M2_Stub) — voir note M1 ci-dessus (seul le retour frein reste stub)
M2_BrakeFeedback := M2_BrakeCmd;

// 📤 Sortie chariot M3 → I/O Mapping RÉEL (seul BrakeCmd est réel, voir en-tête FB_IO_Machine.st)
M3_BrakeCmd := instIoMachine.ChariotBrakeCmdOut;

// 🧪 SIMULATION (stub GVL_Chariot_M3_Stub) — BrakeCmd étant réel, seul le miroir BrakeFeedback
// reste légitime (retour frein encore non câblé).
M3_BrakeFeedback := M3_BrakeCmd;
