(* =======================================================================
   ST_fbDiveSearch_Outputs - Bus de sortie du cycle FB_DiveSearch
   ======================================================================= *)
TYPE ST_fbDiveSearch_Outputs :
STRUCT
    // === ETAT DU CYCLE ===
    StepState              : E_DiveSearchState; // Etape courante
    StepAtFault            : E_DiveSearchState; // Etape figee au defaut

    // === PERMIS & ORDRES ASSISTES ===
    DescendPermit          : BOOL;          // Autorisation de descente assistee
    KoboldContactorCmd     : BOOL;          // Commande alimentation Kobold (fail-safe, coupe au front de fond)
    BottomTouchConfirmed   : BOOL;          // Fond confirme
    MinStepDown            : INT;           // Plancher palier descente

    // === DIAGNOSTIC OPERATEUR ===
    OperatorActionId       : WORD;          // Identifiant numerique de l'action
    OperatorAction          : STRING(120);  // Consigne operateur ASCII
END_STRUCT
END_TYPE
