(* ═══════════════════════════════════════════════════════════════
   🕹️ ST_JoystickHMI — Données d'échange IHM pour le Joystick
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage et au contrôle du joystick depuis l'IHM.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_JoystickHMI :
STRUCT
    RawX        : INT;        (* 🕹️ Axe X brut du joystick (0..10000) *)
    RawY        : INT;        (* 🕹️ Axe Y brut du joystick (0..10000) *)
    RawButton   : BOOL;       (* 🔘 Bouton homme-mort brut *)
    AxisCmdX    : ST_AxisCmd; (* ⚙️ Consigne d'axe X normalisée (sortie FB_Joystick) *)
    AxisCmdY    : ST_AxisCmd; (* ⚙️ Consigne d'axe Y normalisée (sortie FB_Joystick) *)
    NeutralXAct : INT;        (* 🎯 Neutre X calibré actuel (lecture seule) *)
    NeutralYAct : INT;        (* 🎯 Neutre Y calibré actuel (lecture seule) *)
    DeadmanArmed : BOOL;      (* 🔫 Geste homme-mort armé (FB_Joystick.DeadmanArmed) *)
    Online      : BOOL;       (* 📡 Liaison CAN joystick active *)
    Operational : BOOL;       (* 🟢 Joystick opérationnel *)
    BtnCalibrate   : BOOL;       (* 🎯 Demande de recalage au neutre *)
    Error       : BOOL;       (* 🔴 Joystick en défaut *)
    ErrorId     : WORD;       (* ❌ Code défaut joystick *)
END_STRUCT
END_TYPE
