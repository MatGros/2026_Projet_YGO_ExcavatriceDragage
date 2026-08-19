(* ═══════════════════════════════════════════════════════════════
   ST_SyncCfg — Configuration de la synchronisation M1/M2
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SyncCfg :
STRUCT
    CfgSyncTolerance_M : REAL := 0.8;   (* 📐 Tolérance max d'écart (m) — Dégradation Palier 1 dès 0.8m *)
    Initialized        : BOOL := FALSE; (* 🚦 Flag restauration boot (config restaurée depuis GVL_PERSISTENT) *)
END_STRUCT
END_TYPE
