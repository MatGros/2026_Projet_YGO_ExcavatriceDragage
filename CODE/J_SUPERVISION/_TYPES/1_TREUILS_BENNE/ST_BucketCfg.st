(* ═══════════════════════════════════════════════════════════════
   ST_BucketCfg — Configuration de la benne (M2)
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_BucketCfg :
STRUCT
    Config              : ST_fbBucket_Config; (* Offsets Open/Close/Coherence *)
    CfgTimeoutDuration  : TIME := T#30s;    (* ⏱️ Temps max pour l'ouverture/fermeture *)
    Initialized         : BOOL := FALSE;   (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE
