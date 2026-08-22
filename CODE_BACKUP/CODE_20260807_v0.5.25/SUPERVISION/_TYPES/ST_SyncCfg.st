(* ═══════════════════════════════════════════════════════════════
   🔧 ST_SyncCfg — Configuration de la synchronisation M1/M2
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SyncCfg :
STRUCT
    CfgSyncTolerance_M : REAL := 0.25;  (* 📐 Tolérance max d'écart (m) *)
    Initialized        : BOOL := FALSE; (* 🚦 flag restauration boot, ex-CfgInitialized renommé pour cohérence avec ST_WinchCfg *)
END_STRUCT
END_TYPE
