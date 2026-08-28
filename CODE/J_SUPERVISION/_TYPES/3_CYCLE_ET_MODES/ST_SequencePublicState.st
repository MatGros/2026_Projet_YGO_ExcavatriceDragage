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
END_STRUCT
END_TYPE
