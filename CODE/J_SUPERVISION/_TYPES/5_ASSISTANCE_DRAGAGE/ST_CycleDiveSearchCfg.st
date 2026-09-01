(* ═══════════════════════════════════════════════════════════════
   ⚙️ ST_CycleDiveSearchCfg — Réglages persistants cycle plongée (DiveSearch)
   📄 Doc : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md §3ter
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleDiveSearchCfg :
STRUCT
    DiveStartMin_M   : REAL := 1.0;  (* Position mini M1/M2 avant plongée *)
    ImmersionUpper_M : REAL := 0.5;  (* Borne haute fenêtre front immersion *)
    ImmersionLower_M : REAL := -0.5; (* Borne basse fenêtre front immersion *)
    Initialized      : BOOL := FALSE; (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE
