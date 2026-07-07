(* ═══════════════════════════════════════════════════════════════
   🎚️ ST_ModesHMI — Données d'échange IHM pour les modes de marche
   ───────────────────────────────────────────────────────────────
   🎨 Destiné à l'affichage et à la commande des modes sur l'IHM.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_ModesHMI :
STRUCT
    CurrentMode     : E_Mode; (* 🎚️ Mode de marche actuellement actif *)
    ModeRequest     : E_Mode := E_Mode.MAINT_N1; (* 🖥️ Demande de changement de mode de marche — accès N2 filtré côté IHM (REX 2026-07-07) *)
    EmergencyStopOk    : BOOL;   (* 🛡️ État de la chaîne d'arrêt d'urgence *)
    FaultMachineReset  : BOOL;   (* 🔔 Acquittement défauts/alarmes domaine sécurité/métier — JAMAIS Modes/Cycle (REX 2026-07-07, ex-MachineReset) *)
    ModeReset          : BOOL;   (* 🔁 Acquittement défaut FB_Modes uniquement (REX 2026-07-07) *)
    AnyFaultActive     : BOOL;   (* 🔴 REX 2026-07-07 : au moins un défaut/alarme actif dans le domaine
                                     sécurité/métier — s'éteint seul quand la cause disparaît ET que
                                     FaultMachineReset a été pressé (OR de tous les .Error du domaine,
                                     même périmètre que FaultMachineReset) *)
    PowerCutOffActive  : BOOL;   (* 🧨 REX 2026-07-07 : miroir de PowerCutOff_A_RQ (coupure puissance
                                     amont, canal A — B toujours identique/redondant) — TOUJOURS FALSE
                                     tant que la détection contacteur collé n'est pas câblée (TBD,
                                     voir FB_Safety_Winch/FB_Safety_Chariot.PowerCutOff) *)
END_STRUCT
END_TYPE
