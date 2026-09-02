(* ═══════════════════════════════════════════════════════════════
   🚦 ST_CycleDiveSearchState — États publics cycle plongée (DiveSearch)
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleDiveSearchState :
STRUCT
    DiveReady             : BOOL;
    DiveBusy              : BOOL;
    DiveDone              : BOOL;
    DiveError             : BOOL;
    DiveErrorId           : WORD;
    DiveState             : E_DiveSearchState;
    DiveStepAtFault       : E_DiveSearchState;
    BottomTouchConfirmed  : BOOL;
    BypassDiveActive      : BOOL; (* TglBypassDiveSearchSequence armé (descente couplée en cours) *)
    BypassKoboldBottomTouched : BOOL; (* Fond confirmé par le bypass (front montant Kobold en descente) *)
    OperatorActionId         : WORD;       (* Une seule consigne conduite, arbitré en PRG_03 *)
    OperatorAction           : STRING(120); (* Texte de secours ; IHM peut mapper l'identifiant *)
END_STRUCT
END_TYPE
