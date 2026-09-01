(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_CycleExtractionCfg — Réglages persistants cycle extraction
   📄 Doc : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md §3ter
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleExtractionCfg :
STRUCT
    ExtractionControlDistance_M : REAL := 2.0; (* Remontée palier 1 avant accélération *)
    Initialized                 : BOOL := FALSE; (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE
