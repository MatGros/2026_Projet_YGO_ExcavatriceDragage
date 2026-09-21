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
    Step                : E_AutoCycleStep;      // Étape active du Grafcet
    StepAtFault         : E_AutoCycleStep;      // Étape mémorisée au défaut
    OperatorActionId    : WORD;             // Identifiant action opérateur requise
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
    CurrentCycleElapsed_Min : INT;          // Minutes écoulées du cycle SEMI_AUTO en cours
    CurrentCycleElapsed_S   : INT;          // Secondes écoulées du cycle SEMI_AUTO en cours (0..59)
    LastCycleDuration_Min   : INT;          // Minutes du dernier cycle SEMI_AUTO achevé (figées à X13)
    LastCycleDuration_S     : INT;          // Secondes du dernier cycle SEMI_AUTO achevé (figées à X13, 0..59)
    DrainTimeRemaining  : TIME;             // Temps restant en AX13 ; remis a zero hors AX13
    CycleChecksInhibited: BOOL;             // Mode essai : controles procede inhibes
    IgnoredCycleCheckId : WORD;             // Causes procede actives mais ignorees
    ForceStepAccepted   : BOOL;             // Impulsion : consigne de forcage appliquee (saut d'etape effectif)
    ForceStepRejected   : BOOL;             // Impulsion : consigne ecartee (cible hors plage enum, ou cycle inactif)
    ForceStepResult     : STRING(120);      // Motif de rejet de la derniere consigne (vide apres une consigne appliquee)
    BottomTouchConfirmed        : BOOL;                    // Fond confirmé (Kobold ou consigne)
    BottomStopByKobold          : BOOL;                    // Fond confirmé par contact Kobold
    BottomStopBySetpoint        : BOOL;                    // Fond confirmé par limite de travail/consigne
    WinchDescentAuth_M3         : BOOL;                    // Autorisation positive descente treuil selon position M3 (P1/Maintenance) — PRG_04 §5
    ResumeAfterFaultAvailable : BOOL;     // Reprise AX_STAB disponible apres disparition de la cause
    M1SpeedStepAtFault  : INT;              // Palier vitesse M1 applique, fige a l'instant du defaut (0..5)
    M2SpeedStepAtFault  : INT;              // Palier vitesse M2 applique, fige a l'instant du defaut (0..5)
END_STRUCT
END_TYPE
