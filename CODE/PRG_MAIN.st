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
    instSafety       : FB_Safety;
    instDiagCanOpen  : FB_DiagCanOpen;       // Diagnostic CAN/Joystick
    instDiagEthercat : FB_DiagEthercat;      // Diagnostic EtherCAT (3 devices)

    LocalEmergencyStopTOR  : BOOL := TRUE;
    LocalEthercatOk        : BOOL := FALSE;  // Résumé diagnostic EtherCAT

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

    // 🎯 Stub bouton IHM homing (2026-07-02) — à remplacer par un vrai bouton IHM.
    // Un seul bouton pilote Home sur les 2 instances (flux nominal, Partie10 §1) :
    // bascule TRUE puis FALSE dans la vue instance CODESYS pour simuler l'appui (front).
    StubHomeButton_IHM : BOOL := FALSE;
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

    // 🎯 Cible de homing nominal — paramétrable par treuil (Partie10 §7bis, valeur indicative)
    M1_TopSensorPositionM : REAL := 12.5;
    M2_TopSensorPositionM : REAL := 12.5;
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

// Update local status
LocalEthercatOk := instDiagEthercat.Variateur.Operational AND instDiagEthercat.EncoderM1.Operational AND instDiagEthercat.EncoderM2.Operational;

// 1. ÉVALUATION DE LA SÉCURITÉ TRANSVERSE (existante, inchangée)
instSafety(
    Enable := TRUE,
    EStopArmed := LocalEmergencyStopTOR,
    CanOnline := instDiagCanOpen.Joystick.Online,
    CanOperational := instDiagCanOpen.Joystick.Operational,
    EthercatOk := LocalEthercatOk
);

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
    EmergencyStopOk := GVL_DEBUG.DBG_True,      // ⚠️ DEBUG : remplacer par conditions sécurité OK (renommé, était SafetyOk)
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
    Reset               := FALSE,                          // ⚠️ À câbler : front acquittement défaut IHM
    EmergencyStopOk     := GVL_DEBUG.DBG_True,              // ⚠️ DEBUG : même stub que Joystick/Safety
    Mode                := E_Mode.MAINT_N1,                 // ⚠️ Stub — à remplacer par FB_Modes
    RawPosIn            := COD1_PosValue,                   // 📡 I/O Mapping déjà existant
    AlarmsIn            := COD1_Alarms,                     // 📡 I/O Mapping déjà existant
    WarningsIn          := COD1_Warnings,                   // 📡 I/O Mapping déjà existant
    SlaveOperational    := instDiagEthercat.EncoderM1.Operational,
    InvertDirection     := FALSE,
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
    Reset                := FALSE,                          // ⚠️ À câbler : front acquittement défaut IHM
    EmergencyStopOk      := GVL_DEBUG.DBG_True,              // ⚠️ DEBUG : même stub que Joystick/Safety
    Mode                 := E_Mode.MAINT_N1,                 // ⚠️ Stub — à remplacer par FB_Modes
    Home                 := StubHomeButton_IHM,              // ⚠️ Stub bouton IHM — piloté aussi sur M2 (même bouton)
    ConfirmCoherence     := FALSE,                           // ⚠️ À câbler : bouton IHM dédié
    TopPositionSensor    := M1_M2_TopPositionSensor,         // 📡 I/O Mapping RÉEL — commun M1+M2 (remplace le stub GVL_Homing_Stub, supprimé 2026-07-02)
    TopSensorPositionM   := M1_TopSensorPositionM,           // RETAIN, réglable (§ calibration Partie10 §7bis)
    ContactorFeedbackFwd := M1_ContactorFeedbackFwd,         // 📡 I/O Mapping RÉEL (2026-07-02)
    ContactorFeedbackRev := M1_ContactorFeedbackRev,         // 📡 I/O Mapping RÉEL (2026-07-02)
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
    Reset               := FALSE,                          // ⚠️ À câbler : front acquittement défaut IHM
    EmergencyStopOk     := GVL_DEBUG.DBG_True,              // ⚠️ DEBUG : même stub que Joystick/Safety
    Mode                := E_Mode.MAINT_N1,                 // ⚠️ Stub — à remplacer par FB_Modes
    RawPosIn            := COD2_PosValue,                   // 📡 I/O Mapping (mappé 2026-07-02)
    AlarmsIn            := COD2_Alarms,                     // 📡 I/O Mapping (mappé 2026-07-02)
    WarningsIn          := COD2_Warnings,                   // 📡 I/O Mapping (mappé 2026-07-02)
    SlaveOperational    := instDiagEthercat.EncoderM2.Operational,
    InvertDirection     := FALSE,
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
    Reset                := FALSE,                          // ⚠️ À câbler : front acquittement défaut IHM
    EmergencyStopOk      := GVL_DEBUG.DBG_True,              // ⚠️ DEBUG : même stub que Joystick/Safety
    Mode                 := E_Mode.MAINT_N1,                 // ⚠️ Stub — à remplacer par FB_Modes
    Home                 := StubHomeButton_IHM,              // ⚠️ Même bouton stub que M1 (référencement simultané)
    ConfirmCoherence     := FALSE,                           // ⚠️ À câbler : bouton IHM dédié
    TopPositionSensor    := M1_M2_TopPositionSensor,         // 📡 I/O Mapping RÉEL — commun M1+M2 (remplace le stub GVL_Homing_Stub, supprimé 2026-07-02)
    TopSensorPositionM   := M2_TopSensorPositionM,           // RETAIN, réglable (§ calibration Partie10 §7bis)
    ContactorFeedbackFwd := M2_ContactorFeedbackFwd,         // 📡 I/O Mapping RÉEL (2026-07-02)
    ContactorFeedbackRev := M2_ContactorFeedbackRev,         // 📡 I/O Mapping RÉEL (2026-07-02)
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
    EmergencyStopOk     := GVL_DEBUG.DBG_True,        // ⚠️ DEBUG : même stub que Joystick, à sécuriser ensemble
    Mode                := E_Mode.MAINT_N1,           // ⚠️ Stub Maintenance N1 — à remplacer par FB_Modes
    JoystickOnline      := instDiagCanOpen.Joystick.Online,
    JoystickOperational := instDiagCanOpen.Joystick.Operational,
    EncoderAvailable    := instEncoderAbsM1.EncoderAvailable,
    ThermalFeedback     := M1_ThermalFeedback,        // 📡 I/O Mapping RÉEL (2026-07-02)
    SlackCableDetected  := M1_M2_SlackCableSwitch     // 📡 I/O Mapping RÉEL — commun M1/M2 (même valeur câblée sur instSafetyWinchM2)
);

instSafetyWinchM2(
    Enable              := TRUE,
    Reset               := FALSE,                    // ⚠️ À câbler : front acquittement défaut IHM
    EmergencyStopOk     := GVL_DEBUG.DBG_True,        // ⚠️ DEBUG : même stub que Joystick, à sécuriser ensemble
    Mode                := E_Mode.MAINT_N1,           // ⚠️ Stub Maintenance N1 — à remplacer par FB_Modes
    JoystickOnline      := instDiagCanOpen.Joystick.Online,
    JoystickOperational := instDiagCanOpen.Joystick.Operational,
    EncoderAvailable    := instEncoderAbsM2.EncoderAvailable,
    ThermalFeedback     := M2_ThermalFeedback,        // 📡 I/O Mapping RÉEL (2026-07-02)
    SlackCableDetected  := M1_M2_SlackCableSwitch     // 📡 I/O Mapping RÉEL — commun M1/M2 (même valeur câblée sur instSafetyWinchM1)
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
    EmergencyStopOk         := GVL_DEBUG.DBG_True,           // ⚠️ DEBUG : même stub que Joystick/Safety
    Mode                    := E_Mode.MAINT_N1,              // ⚠️ Stub Maintenance N1 — à remplacer par FB_Modes
    StartStop               := FB_Joystick_0.AxisCmdY.StartStop,
    SafeStop                := instSafetyWinchM1.SafeStop,
    ForbidDescent           := instSafetyWinchM1.ForbidDescent,  // 🆕 Mou de câble — masque UNIQUEMENT RelayRev
    Direction               := FB_Joystick_0.AxisCmdY.Direction,
    SpeedRefPct             := FB_Joystick_0.AxisCmdY.SpeedRef,
    SpeedStepTable          := M1_SpeedStepTable,
    ContactorFeedbackFwd    := M1_ContactorFeedbackFwd,      // 📡 I/O Mapping RÉEL (2026-07-02)
    ContactorFeedbackRev    := M1_ContactorFeedbackRev,      // 📡 I/O Mapping RÉEL (2026-07-02)
    BrakeFeedback           := M1_BrakeFeedback              // 🧪 STUB GVL_Winch_M1_Stub (seul signal encore non câblé)
);

// 📤 Sorties treuil M1 → I/O Mapping RÉEL (2026-07-02, RelayFwd/Rev/BrakeCmd/SpeedContactor_1..4)
M1_RelayFwd         := instWinchM1.RelayFwd;
M1_RelayRev         := instWinchM1.RelayRev;
M1_SpeedContactor_1 := instWinchM1.Contactor1;
M1_SpeedContactor_2 := instWinchM1.Contactor2;
M1_SpeedContactor_3 := instWinchM1.Contactor3;
M1_SpeedContactor_4 := instWinchM1.Contactor4;
M1_BrakeCmd         := instWinchM1.BrakeCmd;

// 🧪 SIMULATION (stub GVL_Winch_M1_Stub) — SEUL le retour frein reste non câblé côté device :
// miroir de la commande (contacteur "idéal", 1 cycle de retard). RelayFwd/Rev/ContactorFeedback
// sont désormais des retours RÉELS câblés en I/O Mapping (plus de miroir logiciel — écrire dans
// une variable d'entrée réelle serait écrasé par le bus à chaque cycle, donc supprimé).
M1_BrakeFeedback := M1_BrakeCmd;

instWinchM2(
    Enable                  := StubWinchEnableN1,           // ⚠️ Même stub Maint N1 que M1 — à remplacer par FB_Modes
    Reset                   := FALSE,                        // ⚠️ À câbler : front acquittement défaut IHM
    EmergencyStopOk         := GVL_DEBUG.DBG_True,           // ⚠️ DEBUG : même stub que Joystick/Safety
    Mode                    := E_Mode.MAINT_N1,              // ⚠️ Stub Maintenance N1 — à remplacer par FB_Modes
    StartStop               := FB_Joystick_0.AxisCmdY.StartStop,   // ⚠️ Même consigne que M1 (dupliquée, pas de sélecteur)
    SafeStop                := instSafetyWinchM2.SafeStop,
    ForbidDescent           := instSafetyWinchM2.ForbidDescent,  // 🆕 Mou de câble — masque UNIQUEMENT RelayRev
    Direction               := FB_Joystick_0.AxisCmdY.Direction,   // ⚠️ Même consigne que M1
    SpeedRefPct             := FB_Joystick_0.AxisCmdY.SpeedRef,    // ⚠️ Même consigne que M1
    SpeedStepTable          := M2_SpeedStepTable,
    ContactorFeedbackFwd    := M2_ContactorFeedbackFwd,      // 📡 I/O Mapping RÉEL (2026-07-02)
    ContactorFeedbackRev    := M2_ContactorFeedbackRev,      // 📡 I/O Mapping RÉEL (2026-07-02)
    BrakeFeedback           := M2_BrakeFeedback              // 🧪 STUB GVL_Winch_M2_Stub (seul signal encore non câblé)
);

// 📤 Sorties treuil M2 → I/O Mapping RÉEL (2026-07-02, RelayFwd/Rev/BrakeCmd/SpeedContactor_1..4)
M2_RelayFwd         := instWinchM2.RelayFwd;
M2_RelayRev         := instWinchM2.RelayRev;
M2_SpeedContactor_1 := instWinchM2.Contactor1;
M2_SpeedContactor_2 := instWinchM2.Contactor2;
M2_SpeedContactor_3 := instWinchM2.Contactor3;
M2_SpeedContactor_4 := instWinchM2.Contactor4;
M2_BrakeCmd         := instWinchM2.BrakeCmd;

// 🧪 SIMULATION (stub GVL_Winch_M2_Stub) — voir note M1 ci-dessus (seul le retour frein reste stub)
M2_BrakeFeedback := M2_BrakeCmd;

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
    EmergencyStopOk     := GVL_DEBUG.DBG_True,        // ⚠️ DEBUG : même stub que Joystick/Safety
    Mode                := E_Mode.MAINT_N1,           // ⚠️ Stub Maintenance N1 — à remplacer par FB_Modes
    JoystickOnline      := instDiagCanOpen.Joystick.Online,
    JoystickOperational := instDiagCanOpen.Joystick.Operational
);

// 🎯 SÉLECTEUR STUB MAINTENANCE (2026-07-02, demande utilisateur) — arbitre M3_PositionSensorTarget
// parmi les 4 capteurs position RÉELS du chariot, en attendant FB_Cycle (pas encore codé, qui
// fera cette sélection en exploitation normale — Partie11 §9bis). PosiFosse1/PosFosse2/
// PosMaintenance/PosTremie : noms exacts I/O Mapping (Device.export).
CASE StubChariotPositionSelect_IHM OF
    1: M3_PositionSensorTarget := PosiFosse1;
    2: M3_PositionSensorTarget := PosFosse2;
    3: M3_PositionSensorTarget := PosMaintenance;
    4: M3_PositionSensorTarget := PosTremie;
ELSE
    M3_PositionSensorTarget := FALSE;   // 0 ou valeur hors plage = aucun capteur sélectionné
END_CASE;

instChariotM3(
    Enable                  := StubWinchEnableN1,           // ⚠️ Même stub Maint N1 que Winch — à remplacer par FB_Modes
    Reset                   := FALSE,                        // ⚠️ À câbler : front acquittement défaut IHM
    EmergencyStopOk         := GVL_DEBUG.DBG_True,           // ⚠️ DEBUG : même stub que Joystick/Safety
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

// 📤 Sorties chariot M3 → RelayFwd/Rev/RelaySpeedGv (STUB GVL_Chariot_M3_Stub), BrakeCmd (I/O réel)
M3_RelayFwd     := instChariotM3.RelayFwd;
M3_RelayRev     := instChariotM3.RelayRev;
M3_RelaySpeedGv := instChariotM3.RelaySpeedGv;
M3_BrakeCmd     := instChariotM3.BrakeCmd;

// 🧪 SIMULATION (stub GVL_Chariot_M3_Stub) — voir note Winch M1 ci-dessus. BrakeCmd étant
// désormais réel, seul le miroir BrakeFeedback reste légitime (retour frein encore non câblé).
M3_ContactorFeedbackFwd := M3_RelayFwd;
M3_ContactorFeedbackRev := M3_RelayRev;
M3_BrakeFeedback        := M3_BrakeCmd;
