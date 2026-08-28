(* =======================================================================
   📊 ST_SequencePublicState — État public et synoptique de la séquence
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Expose l'état, l'étape, le cycle de vie et les attentes opérateur du séquenceur
   📄 Référentiel : DOC/WFLOW/CONTRACTS/INTERPRG_CONTRACT_PRG03_MODES_CYCLE_v1.0.md
   ======================================================================= *)
TYPE ST_SequencePublicState :
STRUCT
    Ready               : BOOL;             // Séquenceur disponible
    Lifecycle           : ST_Lifecycle;     // Cycle de vie IEC 61131-3 (Busy, Done)
    Fault               : ST_Fault;         // Défaut transverse (Error, ErrorId)
    SequenceId          : E_ProgramSequence;// Identifiant séquence active
    Step                : E_CycleStep;      // Étape active du Grafcet
    StepAtFault         : E_CycleStep;      // Étape mémorisée au défaut
    OperatorActionId    : UINT;             // Identifiant action opérateur requise
    OperatorAction      : STRING(120);      // Message explicatif pour l'IHM
    ExpectedAxis        : E_OperatorAxis;   // Organe joystick/bouton attendu
    ExpectedDirection   : INT;              // Sens attendu (-1, 0, +1)
    WaitingForOperator  : BOOL;             // En attente action opérateur
    WaitingForProcess   : BOOL;             // En attente condition procédé
    RequestActive       : BOOL;             // Demande de mouvement active
    StepStr             : STRING(80);       // Libellé en clair de l'étape
    SpeedMismatchMps    : REAL;             // Écart absolu vitesse M1/M2 (m/s)
    SpeedMismatchActive : BOOL;             // Seuil vitesse dépassé
    SpeedMismatchConfirmed : BOOL;          // Écart vitesse confirmé pendant timeout

    // === 🤿 ÉTATS ASSISTANTS DE DRAGAGE (CENTRALISÉS PRG_03) ===
    DiveReady                   : BOOL;                    // Assistance plongée prête
    DiveBusy                    : BOOL;                    // Assistance plongée active
    DiveDone                    : BOOL;                    // Assistance plongée terminée
    DiveError                   : BOOL;                    // Défaut assistance plongée
    DiveErrorId                 : WORD;                    // Code défaut plongée
    DiveState                   : E_DiveSearchState;       // Phase interne de recherche fond Kobold
    DiveStepAtFault             : E_DiveSearchState;       // Phase interne mémorisée au défaut plongée
    BottomTouchConfirmed        : BOOL;                    // Contact fond Kobold confirmé
    ExtractionReady             : BOOL;                    // Assistance extraction prête
    ExtractionBusy              : BOOL;                    // Assistance extraction active
    ExtractionDone              : BOOL;                    // Assistance extraction terminée
    ExtractionError             : BOOL;                    // Défaut assistance extraction
    ExtractionErrorId           : WORD;                    // Code défaut extraction
    ExtractionState             : E_ExtractionSequenceState;// Phase interne séquence extraction
    ExtractionStepAtFault       : E_ExtractionSequenceState;// Phase interne mémorisée au défaut extraction
    DumpAtTremieArmed           : BOOL;                    // Option vidage trémie armée IHM
    DumpAtTremieAssistActive    : BOOL;                    // Assistance vidage trémie active
    DumpAtTremieAtTremie        : BOOL;                    // Chariot M3 positionné à la trémie
    DumpAtTremieBucketOpenArmed : BOOL;                    // Commande ouverture benne à la trémie
    DumpAtTremieDescentLocked   : BOOL;                    // Descente treuil verrouillée à la trémie
    BypassDiveActive            : BOOL;                    // Bypass séquence plongée armé
    BypassKoboldBottomTouched   : BOOL;                    // Fond touché sous bypass
END_STRUCT
END_TYPE
