(* ═══════════════════════════════════════════════════════════════
   🎮 ST_TranslationCmd — Commandes IHM pour la Translation M3
   ───────────────────────────────────────────────────────────────
   🎨 Destiné au pilotage de la translation M3 depuis l'IHM.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_TranslationCmd :
STRUCT
    SelPositioning     : BOOL;    (* 🎯 TRUE = positionneur sur SelTarget ; FALSE = jog libre *)
    SelTarget          : INT;     (* 🔢 Numéro de la cible de position sélectionnée *)
    BtnFwd             : BOOL;    (* ↔️ Requête marche avant manuelle (bouton IHM, pas encore arbitrée) *)
    BtnRev             : BOOL;    (* ↔️ Requête marche arrière manuelle (bouton IHM, pas encore arbitrée) *)
    SetFreq_Hz         : REAL;    (* 🎯 Consigne fréquence manuelle [Hz], limitée par PRG_10_Outputs *)
    TglJoystickMaster  : BOOL;    (* 🕹️ TRUE = joystick, FALSE = boutons BtnFwd/BtnRev *)
END_STRUCT
END_TYPE
