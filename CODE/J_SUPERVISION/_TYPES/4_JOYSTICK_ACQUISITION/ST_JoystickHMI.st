(* ═══════════════════════════════════════════════════════════════
   🕹️ ST_JoystickHMI — Données d'échange IHM pour le Joystick
   ───────────────────────────────────────────────────────────────
   📄 Structuration en Cmd / State / Cfg , homogène avec ST_ModesHMI.
   Cfg = réglages FB_Joystick éditables IHM (deadband, temporisations), pontés vers
   GVL_PERSISTENT via FB_CfgPersistBridge_fbJoystick_Cfg. La calibration du neutre reste
   dans GVL_PERSISTENT (bouton Calibrate). Pas de Bypass (concept absent de ce struct).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_JoystickHMI :
STRUCT
    Cmd   : ST_JoystickCmd;
    State : ST_JoystickState;
    Cfg   : ST_fbJoystick_Cfg;
END_STRUCT
END_TYPE
