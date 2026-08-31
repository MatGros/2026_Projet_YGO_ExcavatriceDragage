(* ═══════════════════════════════════════════════════════════════
   🎮 ST_TranslationCmd — Commandes IHM pour la Translation M3
   ───────────────────────────────────────────────────────────────
   🎨 Destiné au pilotage de la translation M3 depuis l'IHM.
   📄 : Initialized protège SetFreq_Hz (seul réglage à survivre au reboot),
      sans pont générique pour ne jamais persister BtnTremie/BtnMaintenance.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_TranslationCmd :
STRUCT
    SelPositioning     : BOOL;    (* 🎯 TRUE = positionneur sur SelTarget ; FALSE = jog libre *)
    SelTarget          : INT;     (* 🔢 Numéro de la cible de position sélectionnée *)
    BtnTremie         : BOOL;    (* ↔️ Requête marche vers Trémie (ex-BtnFwd), pilotage IHM exclusif *)
    BtnMaintenance    : BOOL;    (* ↔️ Requête marche vers Maintenance (ex-BtnRev), pilotage IHM exclusif *)
    SetFreq_Hz         : REAL;    (* 🎯 Consigne fréquence manuelle [Hz], limitée par PRG_06_Outputs *)
    // 🔀 Switch machine unique : GVL_IHM.Modes.Cmd.TglJoystickMaster (ST_ModesCmd), applicable à M1/M2 ET M3.
    InvertDirection    : BOOL;    (* 🔄 TRUE = inverse Fwd→Maintenance / Rev→Trémie (mise en service) *)
    TglMaintenanceZoneAccess : BOOL; (* : autorisation CONSCIENTE zone Maintenance, EN PLUS de MAINT_N2 (Auth.MaintenanceM3TargetEnable) *)
    Initialized        : BOOL := FALSE; (* 🚦 TRUE = SetFreq_Hz restauré depuis GVL_PERSISTENT ce boot *)
END_STRUCT
END_TYPE
