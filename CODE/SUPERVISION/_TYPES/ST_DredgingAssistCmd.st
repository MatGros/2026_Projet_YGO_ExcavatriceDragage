(* ═══════════════════════════════════════════════════════════════
   🎮 ST_DredgingAssistCmd — Sélections IHM assistance prélèvement
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_DredgingAssistCmd :
STRUCT
    TglEnableDiveSearch         : BOOL := TRUE;  (* Assistance plongée active *)
    TglEnableExtractionSequence : BOOL := TRUE;  (* Assistance extraction active *)
    TglBucketAtBottomConfirmed  : BOOL := FALSE; (* Attestation manuelle temporaire du fond *)
END_STRUCT
END_TYPE
