(* ═══════════════════════════════════════════════════════════════
   🕹️ ST_JoystickHMI — Données d'échange IHM pour le Joystick
   ───────────────────────────────────────────────────────────────
   📄 Structuration en Cmd / State , homogène avec ST_ModesHMI.
   Pas de Cfg (les vrais réglages de calibration vivent dans GVL_PERSISTENT, pas ici) ni de
   Bypass (concept absent de ce struct).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_JoystickHMI :
STRUCT
    Cmd   : ST_JoystickCmd;
    State : ST_JoystickState;
END_STRUCT
END_TYPE
