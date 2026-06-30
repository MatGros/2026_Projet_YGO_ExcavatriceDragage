PROGRAM PRG_JOY1
VAR
    // 🕹️ Instance unique du traitement joystick (pipeline calib/filtre/rampe)
    FB_Joystick_0 : FB_Joystick;
END_VAR

(* ═══════════════════════════════════════════════════════════════
   🕹️ PRG_JOY1 — Appel du traitement joystick (version ST)
   ───────────────────────────────────────────────────────────────
   Remplace l'ancien réseau CFC. Câble les E/S physiques sur le FB,
   qui réalise en interne : calibration ➜ filtrage ➜ rampe ➜ % .
   📤 Résultat exploitable : FB_Joystick_0.AxisCmdX / .AxisCmdY
   📄 Doc métier : DOC/AF_Partie4_Fonction_Joystick_v1.0.md
   ═══════════════════════════════════════════════════════════════ *)

FB_Joystick_0(
    // 🟢 --- Autorisations & sécurité ---
    Enable          := GVL_DEBUG.DBG_True,      // ⚠️ DEBUG : remplacer par autorisation réelle
    SafetyOk        := GVL_DEBUG.DBG_True,      // ⚠️ DEBUG : remplacer par conditions sécurité OK
    SafeStop        := GVL_DEBUG.DBG_False,     // ⚠️ DEBUG : remplacer par SafeStop global (FB_Safety)
    Reset           := FALSE,                   // ⚠️ À câbler : front acquittement défaut IHM

    // 🔌 --- État du bus CANopen (joystick) ---
    CanOnline       := diagCAN.IsOnline,        // 📡 nœud CAN présent
    CanOperational  := diagCAN.IsOperational,   // 📡 esclave en mode opérationnel

    // 📥 --- Entrées brutes joystick ---
    RawX            := JoyXRaw_ANA1,            // 🕹️ axe X brut (0..10000)
    RawY            := JoyYRaw_ANA2,            // 🕹️ axe Y brut (0..10000)
    RawButton       := JoyBtnRaw,               // 🔘 bouton brut

    // 🎯 --- Calibration ---
    Calibrate       := FALSE,                   // ⚠️ À câbler : bouton recalage neutre (front)

    // 🎛️ --- Paramètres de traitement (valeurs par défaut conservées) ---
    InvertX         := FALSE,                   // ↔️ inversion sens axe X si besoin
    InvertY         := FALSE,                   // ↕️ inversion sens axe Y si besoin
    Deadband        := 5.0,                     // 🛑 zone morte ±5 %
    FilterTime      := TIME#100ms,              // 〰️ constante de temps filtre PT1
    AccelRate       := 50.0,                    // 📈 accélération 50 %/s
    DecelRate       := 150.0                    // 📉 décélération 150 %/s (retour zéro plus rapide)
);

(* 📤 SORTIES DISPONIBLES (lecture seule, à consommer en aval) :
   ───────────────────────────────────────────────────────────────
   FB_Joystick_0.AxisCmdX.SpeedRef    : REAL  // 🚀 vitesse X 0..100 %
   FB_Joystick_0.AxisCmdX.Direction   : INT   // ➡️ -1 / 0 / +1
   FB_Joystick_0.AxisCmdY.SpeedRef    : REAL  // 🚀 vitesse Y 0..100 %
   FB_Joystick_0.AxisCmdY.Direction   : INT   // ⬆️ -1 / 0 / +1
   FB_Joystick_0.Button               : BOOL  // 🔘 bouton filtré
   FB_Joystick_0.NeutralXAct/.NeutralYAct : INT  // 🎯 neutres calibrés (IHM)
   FB_Joystick_0.Ready/.Busy/.Done    : BOOL  // 🚦 état FB
   FB_Joystick_0.Error/.ErrorId       : BOOL/WORD // 🧾 défaut (ErrorId 16#0003 = calib hors plage)
   ─────────────────────────────────────────────────────────────── *)
