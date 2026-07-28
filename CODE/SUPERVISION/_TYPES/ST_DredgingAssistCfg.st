(* ═══════════════════════════════════════════════════════════════
   🔧 ST_DredgingAssistCfg — Réglages persistants assistants prélèvement
   📄 Doc : DOC/AF_Partie-04_Cycle_Sequenceur_v1.5.md §3ter
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_DredgingAssistCfg :
STRUCT
    DiveStartMin_M              : REAL := 1.0;  (* Position mini M1/M2 avant plongée *)
    ImmersionUpper_M            : REAL := 0.5;  (* Borne haute fenêtre front immersion *)
    ImmersionLower_M            : REAL := -0.5; (* Borne basse fenêtre front immersion *)
    ExtractionControlDistance_M : REAL := 2.0;  (* Remontée palier 1 avant accélération *)
    Initialized                 : BOOL := FALSE; (* Pont persistance/IHM initialisé *)
END_STRUCT
END_TYPE
