(* ═══════════════════════════════════════════════════════════════
   🧠 PRG_MAIN — Orchestration séquentielle (diag → sécurité → métier)
   ───────────────────────────────────────────────────────────────
   📄 Contient désormais la chaîne : Joystick (axe Y) → FB_Safety_Winch
      → FB_Winch (M1) → relais sens/vitesse/frein.
   ⚠️ Stubs debug conservés à l'identique pour Joystick (GVL_DEBUG) —
      NON étendus à Winch : Enable/Mode de FB_Winch sont câblés sur un
      stub Maintenance N1 dédié, clairement marqué, en l'absence de
      FB_Modes (à venir).
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

    // 🔌 SAFETY — bloc safety métier du domaine treuil (SafeStop propre au métier)
    instSafetyWinch : FB_Safety_Winch;

    // 🪝 WINCH — treuil M1 (test chaîne joystick→relais, Maintenance N1, sans codeur)
    instWinchM1 : FB_Winch;

    // 🪜 Table paliers M1 — RETAIN, réglable sans recompiler (Partie1 §Paliers)
    // ⚠️ Valeurs par défaut indicatives : À AJUSTER selon le câblage réel des
    //    4 contacteurs de vitesse M1 (masques) et les seuils souhaités (%).
    M1_SpeedStepTable : ST_SpeedStepTable := (
        StepMask := [2#0001, 2#0011, 2#0111, 2#1111, 2#1111],
        StepThreshold_Pct := [20.0, 40.0, 60.0, 80.0, 100.0]
    );

    // 🎚️ Stub Maintenance N1 pour ce lot (pas de FB_Modes) — à remplacer dès que
    // FB_Modes existera (source légitime Enable/Mode par bloc métier)
    StubWinchEnableN1 : BOOL := TRUE;
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
    joystickOP      := instDiagCanOpen.Joystick,          // 📡 esclave en mode opérationnel

    // 📥 --- Entrées brutes joystick ---
    RawX            := JoyXRaw_ANA1,            // 🕹️ axe X brut (0..10000)
    RawY            := JoyYRaw_ANA2,            // 🕹️ axe Y brut (0..10000)
    RawButton       := JoyBtnRaw,               // 🔘 bouton brut

    // 🎯 --- Calibration ---
    Calibrate       := FALSE,                   // ⚠️ À câbler : bouton recalage neutre (front)

    // 🎛️ --- Paramètres de traitement (valeurs par défaut conservées) ---
    InvertX         := FALSE,
    InvertY         := FALSE,
    Deadband        := 5.0,
    FilterTime      := TIME#100ms,
    AccelRate       := 50.0,
    DecelRate       := 150.0
);

(* ═══════════════════════════════════════════════════════════════
   🔌 3. SÉCURITÉ MÉTIER TREUIL — FB_Safety_Winch
   ───────────────────────────────────────────────────────────────
   Périmètre de ce lot : perte joystick/CAN uniquement (codeur TBD,
   voir CODE/FB_Safety_Winch.st). SafeStop consommé par instWinchM1.
   ═══════════════════════════════════════════════════════════════ *)

instSafetyWinch(
    Enable              := TRUE,
    Reset               := FALSE,                    // ⚠️ À câbler : front acquittement défaut IHM
    EmergencyStopOk     := GVL_DEBUG.DBG_True,        // ⚠️ DEBUG : même stub que Joystick, à sécuriser ensemble
    Mode                := E_Mode.MAINT_N1,           // ⚠️ Stub Maintenance N1 — à remplacer par FB_Modes
    JoystickOnline      := instDiagCanOpen.Joystick.Online,
    JoystickOperational := instDiagCanOpen.Joystick.Operational
);

(* ═══════════════════════════════════════════════════════════════
   🪝 4. TREUIL M1 — FB_Winch (test chaîne Joystick→Relais, Maint N1)
   ───────────────────────────────────────────────────────────────
   Axe Y du joystick pilote Plongée/Extraction (M1 seul pour ce lot).
   📤 Sorties à câbler en I/O Mapping (voir note d'application) :
      M1_RelayFwd, M1_RelayRev, M1_Contactor1..4, M1_BrakeCmd
   📥 Entrées à câbler en I/O Mapping (retours contacteurs physiques) :
      M1_ContactorFeedbackFwd, M1_ContactorFeedbackRev, M1_BrakeFeedback
   ═══════════════════════════════════════════════════════════════ *)

instWinchM1(
    Enable                  := StubWinchEnableN1,           // ⚠️ Stub Maint N1 — à remplacer par FB_Modes
    Reset                   := FALSE,                        // ⚠️ À câbler : front acquittement défaut IHM
    EmergencyStopOk         := GVL_DEBUG.DBG_True,           // ⚠️ DEBUG : même stub que Joystick/Safety
    Mode                    := E_Mode.MAINT_N1,              // ⚠️ Stub Maintenance N1 — à remplacer par FB_Modes
    StartStop               := FB_Joystick_0.AxisCmdY.StartStop,
    SafeStop                := instSafetyWinch.SafeStop,
    Direction               := FB_Joystick_0.AxisCmdY.Direction,
    SpeedRefPct             := FB_Joystick_0.AxisCmdY.SpeedRef,
    SpeedStepTable          := M1_SpeedStepTable,
    ContactorFeedbackFwd    := M1_ContactorFeedbackFwd,      // 🔌 À créer en I/O Mapping (entrée)
    ContactorFeedbackRev    := M1_ContactorFeedbackRev,      // 🔌 À créer en I/O Mapping (entrée)
    BrakeFeedback           := M1_BrakeFeedback              // 🔌 À créer en I/O Mapping (entrée)
);

// 📤 Sorties treuil M1 → variables à mapper en I/O Mapping (sorties physiques)
M1_RelayFwd  := instWinchM1.RelayFwd;
M1_RelayRev  := instWinchM1.RelayRev;
M1_Contactor1 := instWinchM1.Contactor1;
M1_Contactor2 := instWinchM1.Contactor2;
M1_Contactor3 := instWinchM1.Contactor3;
M1_Contactor4 := instWinchM1.Contactor4;
M1_BrakeCmd  := instWinchM1.BrakeCmd;
