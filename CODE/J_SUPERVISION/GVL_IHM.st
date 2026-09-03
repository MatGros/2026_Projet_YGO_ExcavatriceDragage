(* ═══════════════════════════════════════════════════════════════
   🎛️ GVL_IHM — Variables globales d'échange pour l'IHM
   ───────────────────────────────────────────────────────────────
   📄 Mise en service et calibration de la machine de dragage.
   💬 Variables volatiles d'échange temps-réel (IHM <-> Automate).
   ═══════════════════════════════════════════════════════════════ *)
VAR_GLOBAL
    M1TreuilRetenue : ST_WinchHMI;  (* 🛗 Variables d'échange IHM Treuil Retenue (M1) *)
    M2TreuilBenne : ST_WinchBenneHMI;  (* 🛞️ Variables d'échange IHM Treuil Benne (M2) — type dédié avec Bucket *)
    M1M2Sync : ST_SyncHMI;  (* ⚖️ Variables d'échange IHM Surveillance de synchro *)
    JOY1Joystick : ST_JoystickHMI; (* 🕹️ Variables d'échange IHM Joystick (noeud CANopen JOY1) *)
    Modes   : ST_ModesHMI;  (* 🎚️ Variables d'échange IHM Modes de marche *)
    Emergency : ST_EmergencyHMI; (* 🛡️ Variables d'échange IHM chaîne AU / sécurité — sorties de Modes *)
    TranslationM3 : ST_TranslationHMI;(* ↔️ Variables d'échange IHM Translation M3 *)
    Cycle   : ST_CycleHMI;    (* 🔄 Commandes, états et diagnostic cycle semi-automatique *)
    CycleMachineHoming : ST_CycleMachineHomingHMI;     (* 🎯 Cycle de référencement machine (FB_MachineHomingCycle) — MAINT_N2 *)
    CycleDiveSearch   : ST_CycleDiveSearchHMI;   (* 🤿 Assistance plongée (DiveSearch) MAINT_N1/N2 *)
    CycleExtraction   : ST_CycleExtractionHMI;   (* ⛏️ Assistance extraction MAINT_N1/N2 *)
    CycleDumpAtTremie : ST_CycleDumpAtTremieHMI; (* 🚚 Vidage à la trémie (legacy) *)
    Banner  : ST_HmiBanner; (* 🖥️ Bandeau : 4 champs de conduite + état position M3 dédié (AF-07 §4) *)
    Network : ST_NetworkDiagHMI;(* 📡 Variables d'échange IHM Diagnostics réseau *)
    Commun  : ST_CommunHMI; (* 🌐 Signaux communs, pas propres à un axe (TopPositionSensorActive, BrakeThermalFault, LimitLegal) *)
    HmiInitDone : BOOL;               (* 🚩 Indicateur d'initialisation IHM depuis PERSISTENT *)
    Permits : ST_PermitVisibilityHMI; (* Tableau lecture seule des permis canoniques, produit par PRG_07 *)
END_VAR

