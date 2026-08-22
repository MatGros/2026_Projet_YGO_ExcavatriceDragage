(* ═══════════════════════════════════════════════════════════════
   🎮 ST_TranslationCmd — Commandes IHM pour la Translation M3
   ───────────────────────────────────────────────────────────────
   🎨 Destiné au pilotage de la translation M3 depuis l'IHM.
   📄 2026-07-24 : Initialized protège SetFreq_Hz (seul réglage à survivre au reboot),
      sans pont générique pour ne jamais persister BtnFwd/BtnRev.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_TranslationCmd :
STRUCT
    SelPositioning     : BOOL;    (* 🎯 TRUE = positionneur sur SelTarget ; FALSE = jog libre *)
    SelTarget          : INT;     (* 🔢 Numéro de la cible de position sélectionnée *)
    BtnFwd             : BOOL;    (* ↔️ Requête marche avant (→ Trémie), pilotage IHM exclusif *)
    BtnRev             : BOOL;    (* ↔️ Requête marche arrière (→ Maintenance), pilotage IHM exclusif *)
    SetFreq_Hz         : REAL;    (* 🎯 Consigne fréquence manuelle [Hz], limitée par PRG_10_Outputs_LD *)
    TglJoystickMaster  : BOOL;    (* 🕹️ TRUE = joystick, FALSE = boutons BtnFwd/BtnRev *)
    InvertDirection    : BOOL;    (* 🔄 TRUE = inverse Fwd→Maintenance / Rev→Trémie (mise en service) *)
    Initialized        : BOOL := FALSE; (* 🚦 TRUE = SetFreq_Hz restauré depuis GVL_PERSISTENT ce boot *)
END_STRUCT
END_TYPE
