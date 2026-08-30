(* =======================================================================
   FB_ReferenceCycle -- qualification guidee de reference M1/M2/benne
   Producteur unique des demandes de homing conjoint et du commit benne.
   Aucun mouvement n'est commande par ce FB.
   ======================================================================= *)
FUNCTION_BLOCK PUBLIC FB_ReferenceCycle
VAR_INPUT
    Enable                  : BOOL;
    Reset                   : BOOL;
    Mode                    : E_Mode;
    TopPositionActive       : BOOL;
    WinchesMechanicallyStopped : BOOL;
    M1HomedAndReliable      : BOOL;
    M2HomedAndReliable      : BOOL;
    M1HomingBusy            : BOOL;
    M2HomingBusy            : BOOL;
    M1HomingDone            : BOOL;
    M2HomingDone            : BOOL;
    M1HomingError           : BOOL;
    M2HomingError           : BOOL;
    BucketOffsetValid       : BOOL;
    ConfirmOpenPosition     : BOOL;
    ConfirmClosePosition    : BOOL;
    CfgTopHomingTargetM     : REAL;
    CfgOffsetOpenM          : REAL;
    CfgOffsetCloseM         : REAL;
END_VAR
VAR_OUTPUT
    MachineReferenceReady   : BOOL;
    ReferenceStep           : INT;
    ReferenceInstruction    : STRING(120);
    HomingRequestM1         : BOOL;
    HomingRequestM2         : BOOL;
    M2DynamicTargetM        : REAL;
    M2UseDynamicTarget      : BOOL;
    CommitOpenPosition      : BOOL;
    CommitClosePosition     : BOOL;
    ReferenceFailed         : BOOL;
    ReferenceTransactionActive : BOOL;
    ReferenceLossSafeStop    : BOOL;
END_VAR
VAR
    ResetEdge                : R_TRIG;
    ConfirmOpenEdge          : R_TRIG;
    ConfirmCloseEdge         : R_TRIG;
    PendingOpen              : BOOL;
    PendingClose             : BOOL;
    HomingStarted            : BOOL;
    HomingBusyObserved       : BOOL;
    CommitPublished          : BOOL;
    ReferenceWasReady        : BOOL;
    ReferenceLossLatched     : BOOL;
END_VAR

ResetEdge(CLK := Reset);
ConfirmOpenEdge(CLK := ConfirmOpenPosition);
ConfirmCloseEdge(CLK := ConfirmClosePosition);

HomingRequestM1 := FALSE;
HomingRequestM2 := FALSE;
CommitOpenPosition := FALSE;
CommitClosePosition := FALSE;
M2UseDynamicTarget := PendingOpen OR PendingClose;
IF PendingClose THEN
    M2DynamicTargetM := CfgTopHomingTargetM + CfgOffsetCloseM;
ELSE
    M2DynamicTargetM := CfgTopHomingTargetM + CfgOffsetOpenM;
END_IF;

IF ResetEdge.Q THEN
    PendingOpen := FALSE;
    PendingClose := FALSE;
    HomingStarted := FALSE;
    HomingBusyObserved := FALSE;
    CommitPublished := FALSE;
    ReferenceFailed := FALSE;
    ReferenceWasReady := FALSE;
    ReferenceLossLatched := FALSE;
END_IF;

(* Une reference precedemment committee reste exploitable tant que les deux
   codeurs restent fiables. Toute perte de fiabilite requalifie le guide. *)
MachineReferenceReady := M1HomedAndReliable AND M2HomedAndReliable
                         AND (CommitPublished OR BucketOffsetValid) AND NOT ReferenceFailed;
ReferenceTransactionActive := HomingStarted;

(* Perte d'une reference auparavant valide en mouvement : SafeStop demande
   jusqu'a l'arret mecanique. Une absence de reference deja arretee au boot
   va directement au guide et ne declenche jamais cette demande. *)
IF MachineReferenceReady THEN
    ReferenceWasReady := TRUE;
END_IF;
IF ReferenceWasReady AND NOT MachineReferenceReady AND NOT WinchesMechanicallyStopped THEN
    ReferenceLossLatched := TRUE;
END_IF;
IF NOT MachineReferenceReady AND WinchesMechanicallyStopped THEN
    ReferenceWasReady := FALSE;
END_IF;
IF ReferenceLossLatched AND WinchesMechanicallyStopped THEN
    ReferenceLossLatched := FALSE;
END_IF;
ReferenceLossSafeStop := ReferenceLossLatched;

IF NOT Enable THEN
    ReferenceStep := 0;
    ReferenceInstruction := 'Referencement indisponible';
    MachineReferenceReady := FALSE;
    RETURN;
END_IF;

(* Demande visuelle acceptee uniquement dans la fenetre mecanique sure. *)
IF (ConfirmOpenEdge.Q OR ConfirmCloseEdge.Q) AND NOT HomingStarted THEN
    IF (Mode = E_Mode.MAINT_N2) AND TopPositionActive AND WinchesMechanicallyStopped THEN
        PendingOpen := ConfirmOpenEdge.Q;
        PendingClose := ConfirmCloseEdge.Q;
        HomingStarted := TRUE;
        HomingBusyObserved := FALSE;
        CommitPublished := FALSE;
        ReferenceFailed := FALSE;
        HomingRequestM1 := TRUE;
        HomingRequestM2 := TRUE;
        M2UseDynamicTarget := TRUE;
        IF PendingClose THEN
            M2DynamicTargetM := CfgTopHomingTargetM + CfgOffsetCloseM;
        ELSE
            M2DynamicTargetM := CfgTopHomingTargetM + CfgOffsetOpenM;
        END_IF;
    END_IF;
END_IF;

(* Pendant la transaction, la perte de butee ou un mouvement est un abandon
   fail-safe. Le commit n'est jamais realise partiellement. *)
IF HomingStarted THEN
    M2UseDynamicTarget := TRUE;
    IF PendingClose THEN
        M2DynamicTargetM := CfgTopHomingTargetM + CfgOffsetCloseM;
    ELSE
        M2DynamicTargetM := CfgTopHomingTargetM + CfgOffsetOpenM;
    END_IF;

    IF (NOT TopPositionActive) OR (NOT WinchesMechanicallyStopped)
       OR M1HomingError OR M2HomingError THEN
        ReferenceFailed := TRUE;
        HomingStarted := FALSE;
        PendingOpen := FALSE;
        PendingClose := FALSE;
    ELSIF M1HomingBusy OR M2HomingBusy THEN
        HomingBusyObserved := TRUE;
    ELSIF HomingBusyObserved AND M1HomedAndReliable AND M2HomedAndReliable
          AND M1HomingDone AND M2HomingDone THEN
        (* Publication atomique : les deux etats benne sont ecrits par FB_Bucket
           dans le meme scan, uniquement apres les deux succes observes. *)
        CommitOpenPosition := PendingOpen;
        CommitClosePosition := PendingClose;
        CommitPublished := TRUE;
        HomingStarted := FALSE;
        PendingOpen := FALSE;
        PendingClose := FALSE;
    END_IF;
END_IF;

MachineReferenceReady := M1HomedAndReliable AND M2HomedAndReliable
                         AND (CommitPublished OR BucketOffsetValid) AND NOT ReferenceFailed;
ReferenceTransactionActive := HomingStarted;

IF ReferenceFailed THEN
    ReferenceStep := 70;
    ReferenceInstruction := 'Referencement incomplet : rester en N2 et recommencer';
ELSIF ReferenceLossSafeStop THEN
    ReferenceStep := 5;
    ReferenceInstruction := 'Reference perdue en mouvement : arret controle en cours';
ELSIF HomingStarted OR M1HomingBusy OR M2HomingBusy THEN
    ReferenceStep := 50;
    ReferenceInstruction := 'Referencement conjoint M1/M2 en cours : ne pas manoeuvrer';
ELSIF NOT M1HomedAndReliable AND NOT M2HomedAndReliable THEN
    ReferenceStep := 10;
    ReferenceInstruction := 'Codeurs M1 et M2 non references : passer en maintenance N2';
ELSIF NOT M1HomedAndReliable THEN
    ReferenceStep := 11;
    ReferenceInstruction := 'Codeur M1 non reference ou mesure douteuse : homer M1';
ELSIF NOT M2HomedAndReliable THEN
    ReferenceStep := 12;
    ReferenceInstruction := 'Codeur M2 non reference ou mesure douteuse : homer M2';
ELSIF NOT (CommitPublished OR BucketOffsetValid) THEN
    IF Mode <> E_Mode.MAINT_N2 THEN
        ReferenceStep := 20;
        ReferenceInstruction := 'Offset benne inconnu : passer en maintenance N2';
    ELSIF NOT TopPositionActive THEN
        ReferenceStep := 30;
        ReferenceInstruction := 'Monter Both a vitesse lente jusqu au capteur haut';
    ELSIF NOT WinchesMechanicallyStopped THEN
        ReferenceStep := 40;
        ReferenceInstruction := 'Capteur haut atteint : relacher la commande et attendre l arret';
    ELSE
        ReferenceStep := 45;
        ReferenceInstruction := 'Confirmer visuellement la benne : Fermee ou Ouverte';
    END_IF;
ELSE
    ReferenceStep := 60;
    ReferenceInstruction := 'Referencement machine valide : mode nominal disponible';
END_IF;

END_FUNCTION_BLOCK
