(* ═══════════════════════════════════════════════════════════════
   🎮 ST_SyncCmd — Commandes IHM pour la synchronisation M1/M2
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_SyncCmd :
STRUCT
    SelSyncEnable : BOOL := TRUE; (* ☑️ coché = synchro voulue (MAINT_N1/N2), ex-OverrideSync inversé *)
END_STRUCT
END_TYPE
