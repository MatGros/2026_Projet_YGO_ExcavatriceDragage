(* ═══════════════════════════════════════════════════════════════
   🎚️ ST_ModesHMI — Données d'échange IHM pour les modes de marche
   ───────────────────────────────────────────────────────────────
   📄 Structuration en Cmd / State (2026-07-24), homogène avec ST_WinchHMI/ST_SyncHMI/ST_BucketHMI.
   Pas de Cfg (aucun réglage numérique dans ce domaine) ni de Bypass (concept absent de Modes).
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_ModesHMI :
STRUCT
    Cmd   : ST_ModesCmd;
    State : ST_ModesState;
END_STRUCT
END_TYPE
