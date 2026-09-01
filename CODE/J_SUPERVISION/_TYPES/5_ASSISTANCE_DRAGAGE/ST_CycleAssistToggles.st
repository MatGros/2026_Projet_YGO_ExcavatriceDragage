(* ═══════════════════════════════════════════════════════════════
   🎛️ ST_CycleAssistToggles — Toggles assistance mémorisés au boot
   📄 Doc : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md §3ter
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleAssistToggles :
STRUCT
    TglEnableDiveSearch         : BOOL := FALSE; (* Mode assistance plongée mémorisé *)
    TglEnableExtractionSequence : BOOL := FALSE; (* Mode assistance extraction mémorisé *)
    TglEnableDumpAtTremie       : BOOL := FALSE; (* Mode assistance vidage trémie mémorisé *)
    Initialized                 : BOOL := FALSE; (* 🚦 flag restauration boot *)
END_STRUCT
END_TYPE
