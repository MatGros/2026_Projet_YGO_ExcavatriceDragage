(* ═══════════════════════════════════════════════════════════════
   🛠️ ST_MaintenanceN2HMI — Données d'échange IHM pour la maintenance N2
   ───────────────────────────────────────────────────────────────
   📄 Structuration canonique Cmd / State pour la maintenance experte N2.
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_MaintenanceN2HMI :
STRUCT
    Cmd   : ST_MaintenanceN2Cmd;
    State : ST_MaintenanceN2State;
END_STRUCT
END_TYPE
