(* ═══════════════════════════════════════════════════════════════
   📏 ST_LimitLegal — Configuration de la limite légale de dragage
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie5_Modes_Maintenance_v1.2.md §3
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_LimitLegal :
STRUCT
    DepthMinAllowed : REAL := -15.0;  (* 📐 Cote min autorisée (mètres, négatif sous le plan d'eau) *)
    Enabled         : BOOL := TRUE;   (* 🟢 Active en cycle automatique / SEMI_AUTO *)
END_STRUCT
END_TYPE
