(* ═══════════════════════════════════════════════════════════════
   🎮 ST_CycleDiveSearchCmd — Sélections IHM cycle plongée (DiveSearch)
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleDiveSearchCmd :
STRUCT
    TglEnableDiveSearch         : BOOL := FALSE; (* Assistance plongée active *)
    TglBypassDiveSearchSequence : BOOL := FALSE; (* Bypass séquence DiveSearch *)
    TglBucketAtBottomConfirmed  : BOOL := FALSE; (* Attestation manuelle fond *)
END_STRUCT
END_TYPE
