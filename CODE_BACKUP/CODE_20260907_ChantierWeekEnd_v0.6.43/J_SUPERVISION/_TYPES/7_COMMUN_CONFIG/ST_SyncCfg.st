(* ═══════════════════════════════════════════════════════════════
   ST_SyncCfg — Configuration de la synchronisation M1/M2
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SyncCfg :
STRUCT
    CfgSyncTolerance_M : REAL := 3.0;   (* 📐 Tolérance max d'écart (m) — Dégradation Palier 1 dès 3.0m *)
    CfgSyncCriticalTolerance_M : REAL := 6.0; (* 🔴 Seuil 2 critique (m) — blocage synchro ; doit être > CfgSyncTolerance_M *)
    Initialized        : BOOL := FALSE; (* 🚦 Flag restauration boot (config restaurée depuis GVL_PERSISTENT) *)
END_STRUCT
END_TYPE
