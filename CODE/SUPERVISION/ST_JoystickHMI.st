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
    CmdX        : ST_AxisCmd; (* ⚙️ Consigne d'axe X normalisée *)
    CmdY        : ST_AxisCmd; (* ⚙️ Consigne d'axe Y normalisée *)
    Online      : BOOL;       (* 📡 Liaison CAN joystick active *)
    Operational : BOOL;       (* 🟢 Joystick opérationnel *)
    Calibrate   : BOOL;       (* 🎯 Demande de recalage au neutre *)
END_STRUCT
END_TYPE
