(* =======================================================================
   🪣 FB_Bucket — Commande d'ouverture et de fermeture du benne
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Pilotage synchrone et séquencement d'ouverture/fermeture benne
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 Interface : FB standard (Partie3 §1bis)
   🔒 Sécurité : Surveillance du glissement M1 et interlocks de mouvement
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Bucket
VAR_INPUT
    // === COMMANDES ET ETATS GENERAL ===
    Enable                          : BOOL;                           // --> [CMD] Autorisation generale FB
    Reset                           : BOOL;                           // --> [CMD] Acquittement defauts sur front
    Mode                            : E_Mode;                         // --> [CMD] Mode de marche machine
    CmdOpen_IHM                     : BOOL;                           // --> [CMD] Demande ouverture depuis IHM
    CmdClose_IHM                    : BOOL;                           // --> [CMD] Demande fermeture depuis IHM
    MotionRequestActive             : BOOL;                           // --> [CMD] Intention mouvement arbitree
    MotionDirection                 : INT;                            // --> [CMD] Sens arbitre (1: montee, -1: descente)
    ReferenceCommitOpen             : BOOL;                           // --> [CMD] Commit atomique reference benne ouverte
    ReferenceCommitClose            : BOOL;                           // --> [CMD] Commit atomique reference benne fermee
    MachineReferenceReady           : BOOL;                           // --> [STAT] Qualification conjointe M1/M2/benne
    ReferenceTransactionActive      : BOOL;                           // --> [STAT] Homing conjoint en cours
    ConfirmOpenPosition             : BOOL;                           // --> [CMD] Legacy IHM, ignore : front traite par FB_ReferenceCycle
    ConfirmClosePosition            : BOOL;                           // --> [CMD] Legacy IHM, ignore : front traite par FB_ReferenceCycle

    // === SECOURS ET HARDWARE ===
    PowerContactorEngaged           : BOOL;                           // --> [SAFE] Condition d'arret d'urgence / puissance
    CablePosM1                      : REAL;                           // --> [HW] Position reelle cable treuil M1 (m)
    CablePosM2                      : REAL;                           // --> [HW] Position reelle cable treuil M2 (m)
    HomedM1                         : BOOL;                           // --> [HW] Codeur M1 reference
    HomedM2                         : BOOL;                           // --> [HW] Codeur M2 reference
    M1_Busy                         : BOOL;                           // --> [HW] Treuil M1 en mouvement (Busy)
    M2_Busy                         : BOOL;                           // --> [HW] Treuil M2 en mouvement (Busy)
    InhibitM1                       : BOOL;                           // --> [HW] Treuil M1 inhibe
    InhibitM2                       : BOOL;                           // --> [HW] Treuil M2 inhibe

    // === REGLAGES ET CONFIGURATION ===
    Config                          : ST_fbBucket_Config;                // --> [CFG] Configuration parametres benne
    CfgTimeoutDuration              : TIME := T#60s;                  // --> [CFG] Timeout de mouvement configurable
    M1SlipToleranceM                : REAL := 1.0;                    // --> [CFG] Tolerance glissement M1 pendant Busy (m)

    // === BYPASSES ET SIMULATION ===
    BypassGlobal                    : BOOL := FALSE;                  // --> [TST] Force ErrorId=0 global
END_VAR
VAR_OUTPUT
    // === ETATS IEC ET SYNOPTIQUE ===
    Ready                           : BOOL;                           // <-- [STAT] FB pret a fonctionner
    ActiveOffsetValid               : BOOL;                           // <-- [STAT] Validite offset actif calcule a jour
    // 🧩 Statut transverse (forme cible ST_Fault + ST_Lifecycle)
    Fault                           : ST_Fault;
    Lifecycle                       : ST_Lifecycle;

    // === DEMANDES ET ORDRES ACTIONNEURS ===
    CloseReq                        : BOOL;                           // <-- [STAT] Demande de fermeture memorisee
    OpenReq                         : BOOL;                           // <-- [STAT] Demande d'ouverture memorisee
    M2_StartStop                    : BOOL;                           // <-- [ACT] Ordre StartStop vers Winch M2
    M2_Direction                    : INT;                            // <-- [ACT] Ordre Direction vers Winch M2
    M2_BucketJogLimit               : BOOL;                           // <-- [ACT] Plafond palier 1 du jog benne M2

    // === DIAGNOSTICS ET MESURES ===
    M1SlipDetected                  : BOOL;                           // <-- [DIAG] Glissement M1 detecte
    ActiveOffsetM                   : REAL;                           // <-- [DIAG] Decalage cible pour FB_WinchSync
    DeltaPosition_M                 : REAL;                           // <-- [DIAG] Ecart reel signe M2 - M1 (m)
    RemainingTravelM                : REAL;                           // <-- [DIAG] Distance restante avant cible (m)
END_VAR
VAR_IN_OUT
    // === STRUCTURES DE DONNÉES PARTAGÉES ===
    BucketState                     : ST_fbBucket_State;                 // <-> [BUS] Etat physique memorise du benne
END_VAR
VAR
    // === DETECTEURS ET TIMERS INTERNES ===
    ResetEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Reset
    BusyEdge                        : R_TRIG;                         // . [LOC] Detecteur entree en etat Busy
    TonTimeout                      : TON;                            // . [LOC] Temporisateur timeout de mouvement

    // === VARIABLES LOCALES CALCULÉES ===
    FirstCycle                      : BOOL := TRUE;                  // . [LOC] Drapeau de premier cycle API
    SevereError                     : BOOL;                           // . [LOC] Erreur grave necessitant arret
    MaxAllowedOffset                : REAL;                           // . [LOC] Offset max calcule dynamiquement
    M1RefPosM                       : REAL;                           // . [LOC] Position M1 memorisee a l'entree Busy
    M2StartPosM                     : REAL;                           // . [LOC] Position M2 memorisee a l'entree Busy
    WasOpenAtStart                  : BOOL;                           // . [LOC] Etat IsOpen memorise a l'entree Busy
    WasClosedAtStart                : BOOL;                           // . [LOC] Etat IsClosed memorise a l'entree Busy
    LeftStartSinceArm               : BOOL;                           // . [LOC] Quitte position de depart
    HoldOffsetM                     : REAL;                           // . [LOC] Ecart reel mémorise (gel en position intermediaire)

    // Latches défauts
    CfgFaultLatched                 : BOOL;
    OffsetMaxFaultLatched           : BOOL;
    TimeoutFaultLatched             : BOOL;
    M1SlipFaultLatched              : BOOL;
    HomingFaultLatched              : BOOL;

    // Socle défaut
    instFault                       : FB_FaultCore;                   // * [INST] Socle défaut transverse
    instCauses                      : ARRAY[0..15] OF ST_FaultCause;  // . [LOC] Table des causes nommées
END_VAR

// === IMPLEMENTATION ===

{region "§1 Causes & Socle Défaut (évalué en continu)"}
// 🔑 1. FRONTS & REARMEMENT
ResetEdge(CLK := Reset);

IF ResetEdge.Q OR BypassGlobal THEN
    CfgFaultLatched       := FALSE;
    OffsetMaxFaultLatched := FALSE;
    TimeoutFaultLatched   := FALSE;
    M1SlipFaultLatched    := FALSE;
    HomingFaultLatched    := FALSE;
END_IF;

IF NOT BypassGlobal THEN
    // Cause 0 : Configuration géométrie benne
    IF (Config.OffsetOpenM >= Config.OffsetCloseM)
       OR (Config.OffsetOpenM < 0.0) THEN
        CfgFaultLatched := TRUE;
    END_IF;
    instCauses[0].Active   := CfgFaultLatched;
    instCauses[0].Latching := TRUE;
    instCauses[0].Texte    := 'Configuration geometrie benne invalide';

    // Cause 1 : Dépassement écart max
    MaxAllowedOffset := Config.OffsetCloseM + 2.0;
    IF (CablePosM2 > (CablePosM1 + MaxAllowedOffset)) OR (CablePosM2 < CablePosM1) THEN
        OffsetMaxFaultLatched := TRUE;
    END_IF;
    instCauses[1].Active   := OffsetMaxFaultLatched;
    instCauses[1].Latching := TRUE;
    instCauses[1].Texte    := 'Depassement ecart maximum autorise benne';

    // Cause 2 : Timeout
    TonTimeout(IN := Lifecycle.Busy, PT := CfgTimeoutDuration);
    IF TonTimeout.Q THEN
        TimeoutFaultLatched := TRUE;
    END_IF;
    instCauses[2].Active   := TimeoutFaultLatched;
    instCauses[2].Latching := TRUE;
    instCauses[2].Texte    := 'Timeout commande deplacement benne';

    // Cause 3 : Glissement M1
    M1SlipDetected := Lifecycle.Busy AND (ABS(CablePosM1 - M1RefPosM) > M1SlipToleranceM);
    IF M1SlipDetected THEN
        M1SlipFaultLatched := TRUE;
    END_IF;
    instCauses[3].Active   := M1SlipFaultLatched;
    instCauses[3].Latching := TRUE;
    instCauses[3].Texte    := 'Glissement treuil M1 pendant manoeuvre benne';

    // Cause 4 : Non référencé
    IF NOT HomedM1 OR NOT HomedM2 THEN
        HomingFaultLatched := TRUE;
    END_IF;
    instCauses[4].Active   := HomingFaultLatched;
    instCauses[4].Latching := TRUE;
    instCauses[4].Texte    := 'Codeurs treuils non references pour sequence benne';
ELSE
    TonTimeout(IN := FALSE);
    M1SlipDetected := FALSE;
    instCauses[0].Active := FALSE;
    instCauses[1].Active := FALSE;
    instCauses[2].Active := FALSE;
    instCauses[3].Active := FALSE;
    instCauses[4].Active := FALSE;
END_IF;

// Appel du socle de défaut
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;
{endregion}

{region "§2 Gate securite"}
// 🛑 2. GATE
IF NOT Enable OR NOT PowerContactorEngaged THEN
    IF Lifecycle.Busy OR CloseReq OR OpenReq THEN
        BucketState.StateIncoherent := TRUE;
    END_IF;
    Ready := FALSE;
    ActiveOffsetValid := FALSE;
    ActiveOffsetM := 0.0;
    DeltaPosition_M := 0.0;
    RemainingTravelM := 0.0;
    Lifecycle.Busy := FALSE;
    Lifecycle.Done := FALSE;
    M2_StartStop := FALSE;
    M2_Direction := 0;
    M2_BucketJogLimit := FALSE;
    CloseReq := FALSE;
    OpenReq := FALSE;
    RETURN;
END_IF;

Ready := Enable AND NOT Fault.Latched;
{endregion}

{region "§3 Premier cycle & recalage boutons IHM"}
IF FirstCycle THEN
    FirstCycle := FALSE;
    IF NOT BucketState.IsOpen AND NOT BucketState.IsClosed THEN
        BucketState.StateIncoherent := TRUE;
    END_IF;
END_IF;

IF ReferenceCommitOpen AND NOT Lifecycle.Busy THEN
    BucketState.IsOpen := TRUE;
    BucketState.IsClosed := FALSE;
    BucketState.LastPosM2Open := CablePosM2;
    BucketState.StateIncoherent := FALSE;
END_IF;

IF ReferenceCommitClose AND NOT Lifecycle.Busy THEN
    BucketState.IsOpen := FALSE;
    BucketState.IsClosed := TRUE;
    BucketState.LastPosM2Close := CablePosM2;
    BucketState.StateIncoherent := FALSE;
END_IF;
{endregion}

{region "§4 Séquencement mouvement benne"}
SevereError := Fault.Error;

IF SevereError THEN
    M2_StartStop := FALSE;
    M2_Direction := 0;
    M2_BucketJogLimit := FALSE;
    CloseReq := FALSE;
    OpenReq := FALSE;
    Lifecycle.Busy := FALSE;
    Lifecycle.Done := FALSE;
ELSE
    // Prise en compte des demandes IHM — anti-traversée (TC-P10-025) :
    // demande benne refusée si un treuil agit (M1_Busy OR M2_Busy) à l'entrée READY.
    IF CmdOpen_IHM AND NOT Lifecycle.Busy AND NOT M1_Busy AND NOT M2_Busy THEN
        OpenReq := TRUE;
        CloseReq := FALSE;
    ELSIF CmdClose_IHM AND NOT Lifecycle.Busy AND NOT M1_Busy AND NOT M2_Busy THEN
        CloseReq := TRUE;
        OpenReq := FALSE;
    END_IF;

    BusyEdge(CLK := (CloseReq OR OpenReq) AND MotionRequestActive);

    IF BusyEdge.Q THEN
        M1RefPosM := CablePosM1;
        M2StartPosM := CablePosM2;
        WasOpenAtStart := BucketState.IsOpen;
        WasClosedAtStart := BucketState.IsClosed;
        LeftStartSinceArm := FALSE;
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
    END_IF;

    IF Lifecycle.Busy THEN
        IF CloseReq THEN
            RemainingTravelM := MAX(0.0, (CablePosM1 + Config.OffsetCloseM) - CablePosM2);
            M2_BucketJogLimit := TRUE;
            IF MotionRequestActive AND (MotionDirection = 1) THEN
                M2_StartStop := TRUE;
                M2_Direction := 1;
            ELSIF MotionRequestActive AND (MotionDirection = -1) THEN
                M2_StartStop := TRUE;
                M2_Direction := -1;
            ELSE
                M2_StartStop := FALSE;
                M2_Direction := 0;
            END_IF;
        ELSIF OpenReq THEN
            RemainingTravelM := MAX(0.0, CablePosM2 - (CablePosM1 + Config.OffsetOpenM));
            M2_BucketJogLimit := TRUE;
            IF MotionRequestActive AND (MotionDirection = -1) THEN
                M2_StartStop := TRUE;
                M2_Direction := -1;
            ELSIF MotionRequestActive AND (MotionDirection = 1) THEN
                M2_StartStop := TRUE;
                M2_Direction := 1;
            ELSE
                M2_StartStop := FALSE;
                M2_Direction := 0;
            END_IF;
        ELSE
            M2_StartStop := FALSE;
            M2_Direction := 0;
            M2_BucketJogLimit := FALSE;
        END_IF;

        IF (CloseReq AND (CablePosM2 > M2StartPosM)) OR (OpenReq AND (CablePosM2 < M2StartPosM)) THEN
            LeftStartSinceArm := TRUE;
        END_IF;

        // Arrêt fermeture
        IF CloseReq THEN
            IF CablePosM2 >= (CablePosM1 + Config.OffsetCloseM - Config.CloseAnticipationM) THEN
                M2_StartStop := FALSE;
                M2_Direction := 0;
                BucketState.IsOpen := FALSE;
                BucketState.IsClosed := TRUE;
                BucketState.LastPosM2Close := CablePosM2;
                BucketState.StateIncoherent := FALSE;
                CloseReq := FALSE;
                Lifecycle.Busy := FALSE;
                Lifecycle.Done := TRUE;
            ELSIF LeftStartSinceArm AND (CablePosM2 <= M2StartPosM) THEN
                M2_StartStop := FALSE;
                M2_Direction := 0;
                BucketState.IsOpen := WasOpenAtStart;
                BucketState.IsClosed := WasClosedAtStart;
                CloseReq := FALSE;
                Lifecycle.Busy := FALSE;
                Lifecycle.Done := TRUE;
            END_IF;
        END_IF;

        // Arrêt ouverture
        IF OpenReq THEN
            IF CablePosM2 <= (CablePosM1 + Config.OffsetOpenM + Config.OpenAnticipationM) THEN
                M2_StartStop := FALSE;
                M2_Direction := 0;
                BucketState.IsOpen := TRUE;
                BucketState.IsClosed := FALSE;
                BucketState.LastPosM2Open := CablePosM2;
                BucketState.StateIncoherent := FALSE;
                OpenReq := FALSE;
                Lifecycle.Busy := FALSE;
                Lifecycle.Done := TRUE;
            ELSIF LeftStartSinceArm AND (CablePosM2 >= M2StartPosM) THEN
                M2_StartStop := FALSE;
                M2_Direction := 0;
                BucketState.IsOpen := WasOpenAtStart;
                BucketState.IsClosed := WasClosedAtStart;
                OpenReq := FALSE;
                Lifecycle.Busy := FALSE;
                Lifecycle.Done := TRUE;
            END_IF;
        END_IF;
    ELSIF Lifecycle.Done THEN
        M2_StartStop := FALSE;
        M2_Direction := 0;
        M2_BucketJogLimit := FALSE;
        RemainingTravelM := 0.0;
        IF NOT MotionRequestActive THEN
            Lifecycle.Done := FALSE;
        END_IF;
    END_IF;
END_IF;
{endregion}

{region "§5 Offset actif et validite"}
DeltaPosition_M := CablePosM2 - CablePosM1;

IF Lifecycle.Busy THEN
    ActiveOffsetM := CablePosM2 - CablePosM1;
    HoldOffsetM := ActiveOffsetM;
ELSIF CloseReq OR BucketState.IsClosed THEN
    ActiveOffsetM := Config.OffsetCloseM;
    HoldOffsetM := ActiveOffsetM;
ELSIF OpenReq OR BucketState.IsOpen THEN
    ActiveOffsetM := Config.OffsetOpenM;
    HoldOffsetM := ActiveOffsetM;
ELSE
    ActiveOffsetM := HoldOffsetM;
END_IF;

ActiveOffsetValid := Enable AND PowerContactorEngaged
                     AND NOT BucketState.StateIncoherent
                     AND (Fault.ErrorId = 16#0000)
                     AND (MachineReferenceReady OR (BucketState.IsOpen XOR BucketState.IsClosed))
                     AND NOT ReferenceTransactionActive;
BucketState.ActiveOffsetValid := ActiveOffsetValid;
{endregion}

END_FUNCTION_BLOCK
