(* ═══════════════════════════════════════════════════════════════
   ST_SyncCfg — Configuration de la synchronisation M1/M2
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SyncCfg :
STRUCT
    CfgSyncTolerance_M : REAL := 0.8;   (* 📐 Tolérance max d'écart (m) — Dégradation Palier 1 dès 0.8m *)
    CfgSyncCriticalTolerance_M : REAL := 2.0; (* 🔴 Seuil 2 critique (m) — blocage synchro ; doit être > CfgSyncTolerance_M *)
    Initialized        : BOOL := FALSE; (* 🚦 Flag restauration boot (config restaurée depuis GVL_PERSISTENT) *)
END_STRUCT
END_TYPE
