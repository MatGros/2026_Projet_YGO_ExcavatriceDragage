(* ═══════════════════════════════════════════════════════════════
   🚦 ST_JoystickState — États et diagnostics IHM du Joystick
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_JoystickState :
STRUCT
    RawX         : INT;        (* 🕹️ Axe X brut du joystick (0..10000) *)
    RawY         : INT;        (* 🕹️ Axe Y brut du joystick (0..10000) *)
    RawButton    : BOOL;       (* 🔘 Bouton homme-mort brut *)
    AxisCmdX     : ST_Joystick_AxisCmd; (* ⚙️ Consigne d'axe X normalisée (sortie FB_Joystick) *)
    AxisCmdY     : ST_Joystick_AxisCmd; (* ⚙️ Consigne d'axe Y normalisée (sortie FB_Joystick) *)
    NeutralXAct  : INT;        (* 🎯 Neutre X calibré actuel (lecture seule) *)
    NeutralYAct  : INT;        (* 🎯 Neutre Y calibré actuel (lecture seule) *)
    DeadmanArmed : BOOL;       (* 🔫 Geste homme-mort armé (FB_Joystick.DeadmanArmed) *)
    AtNeutral    : BOOL;       (* 🆕 2026-08-07 : TRUE si les 2 axes sont en zone morte (position centrale) *)
    Online       : BOOL;       (* 📡 Liaison CAN joystick active *)
    Operational  : BOOL;       (* 🟢 Joystick opérationnel *)
    Error        : BOOL;       (* 🔴 Joystick en défaut *)
    ErrorId      : WORD;       (* ❌ Code défaut joystick *)
END_STRUCT
END_TYPE
