(* ═══════════════════════════════════════════════════════════════
   🚦 ST_DredgingAssistState — États publics assistance prélèvement
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_DredgingAssistState :
STRUCT
    DiveReady                  : BOOL;
    DiveBusy                   : BOOL;
    DiveDone                   : BOOL;
    DiveError                  : BOOL;
    DiveErrorId                : WORD;
    DiveState                  : E_DiveSearchState;
    BottomTouchConfirmed       : BOOL;
    ExtractionReady            : BOOL;
    ExtractionBusy             : BOOL;
    ExtractionDone             : BOOL;
    ExtractionError            : BOOL;
    ExtractionErrorId          : WORD;
    ExtractionState            : E_ExtractionSequenceState;
    OperatorActionId           : WORD;       (* Une seule consigne conduite, arbitré en PRG_09 *)
    OperatorAction             : STRING(120); (* Texte de secours ; IHM peut mapper l'identifiant *)
    // : mode vidage à la trémie (pas de FB dédié, logique combinatoire PRG_04)
    DumpAtTremieArmed          : BOOL; (* TglEnableDumpAtTremie (bit IHM brut) *)
    DumpAtTremieAssistActive   : BOOL; (* Armé ET Mode MAINT_N1/N2 (mode réellement actif) *)
    DumpAtTremieAtTremie       : BOOL; (* M3_AtTremieStable *)
    DumpAtTremieBucketOpenArmed: BOOL; (* CmdOpen_IHM déclenché par ce mode *)
    DumpAtTremieDescentLocked  : BOOL; (* DescendPermit M1/M2 forcé par ce mode (hors P1/Maintenance) *)
    // Diagnostic bypass séquence DiveSearch
    BypassDiveActive           : BOOL; (* TglBypassDiveSearchSequence armé (descente couplée en cours) *)
    BypassKoboldBottomTouched  : BOOL; (* Fond confirmé par le bypass (front montant Kobold en descente) *)
END_STRUCT
END_TYPE
