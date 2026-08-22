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
END_STRUCT
END_TYPE
