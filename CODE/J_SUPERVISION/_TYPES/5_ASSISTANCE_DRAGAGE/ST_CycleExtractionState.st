(* ═══════════════════════════════════════════════════════════════
   🚦 ST_CycleExtractionState — États publics cycle extraction
   ═══════════════════════════════════════════════════════════════ *)
TYPE ST_CycleExtractionState :
STRUCT
    ExtractionReady       : BOOL;
    ExtractionBusy        : BOOL;
    ExtractionDone        : BOOL;
    ExtractionError       : BOOL;
    ExtractionErrorId     : WORD;
    ExtractionState       : E_ExtractionAssistState;
    ExtractionStepAtFault : E_ExtractionAssistState;
END_STRUCT
END_TYPE
