(* ═══════════════════════════════════════════════════════════════
   🚦 ST_CycleDumpAtTremieState — États publics cycle vidage trémie (legacy)
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleDumpAtTremieState :
STRUCT
    DumpAtTremieArmed           : BOOL; (* TglEnableDumpAtTremie (bit IHM brut) *)
    DumpAtTremieAssistActive    : BOOL; (* Armé ET Mode MAINT_N1/N2 (mode réellement actif) *)
    DumpAtTremieAtTremie        : BOOL; (* M3_AtTremieStable *)
    DumpAtTremieBucketOpenArmed : BOOL; (* CmdOpen_IHM déclenché par ce mode *)
    DumpAtTremieDescentLocked   : BOOL; (* DescendPermit M1/M2 forcé par ce mode (hors P1/Maintenance) *)
END_STRUCT
END_TYPE
