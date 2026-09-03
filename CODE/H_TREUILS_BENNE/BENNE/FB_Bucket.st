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
    ReqAscent                       : BOOL;                           // --> [CMD] Demande montee arbitree
    ReqDescend                      : BOOL;                           // --> [CMD] Demande descente arbitree
    EffectivePermitBucket_Open      : BOOL;                           // --> [SAFE] Ouverture benne autorisee
    EffectivePermitBucket_Close     : BOOL;                           // --> [SAFE] Fermeture benne autorisee
    MachineHomingCommitOpen             : BOOL;                           // --> [CMD] Commit atomique reference benne ouverte
    MachineHomingCommitClose            : BOOL;                           // --> [CMD] Commit atomique reference benne fermee
    MachineHomed           : BOOL;                           // --> [STAT] Qualification conjointe M1/M2/benne
    MachineHomingActive      : BOOL;                           // --> [STAT] Homing conjoint en cours
    ConfirmOpenPosition             : BOOL;                           // --> [CMD] Confirmation visuelle IHM : benne ouverte
    ConfirmClosePosition            : BOOL;                           // --> [CMD] Confirmation visuelle IHM : benne fermee

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
    ManualJogM2Active               : BOOL;                           // --> [CMD] Pilotage unitaire benne M2 (WinchSel=2, MAINT) : detection passive d'etat sur position

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
    M2_RunRequest                   : BOOL;                           // <-- [ACT] Ordre marche vers Winch M2
    M2_ReqAscent                    : BOOL;                           // <-- [ACT] Ordre montee vers Winch M2
    M2_ReqDescend                   : BOOL;                           // <-- [ACT] Ordre descente vers Winch M2
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
    ConfirmOpenEdge                 : R_TRIG;                         // . [LOC] Detecteur front confirmation ouverture IHM
    ConfirmCloseEdge                : R_TRIG;                         // . [LOC] Detecteur front confirmation fermeture IHM
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
    MotionRequestActive             : BOOL;                           // . [LOC] Demande valide : un seul sens
    MotionRequestConflict           : BOOL;                           // . [LOC] Deux sens = arrêt sûr

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
    M2_RunRequest := FALSE;
    M2_ReqAscent := FALSE;
    M2_ReqDescend := FALSE;
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
    // Une seule position doit être qualifiée au démarrage : ni l'une ni l'autre
    // ou les deux simultanément signifient que la mémorisation n'est pas fiable.
    IF (BucketState.IsOpen AND BucketState.IsClosed)
       OR (NOT BucketState.IsOpen AND NOT BucketState.IsClosed) THEN
        BucketState.StateIncoherent := TRUE;
    END_IF;
END_IF;

// Les confirmations IHM restent les commandes fonctionnelles de référence
// benne, indépendantes du cycle global. Elles ne sont acceptées qu'à l'arrêt
// en maintenance : un front qualifie l'observation visuelle opérateur.
ConfirmOpenEdge(CLK := ConfirmOpenPosition);
IF ConfirmOpenEdge.Q
   AND (Mode = E_Mode.MAINT_N2)
   AND NOT Lifecycle.Busy AND NOT M1_Busy AND NOT M2_Busy THEN
    BucketState.IsOpen := TRUE;
    BucketState.IsClosed := FALSE;
    BucketState.LastPosM2Open := CablePosM2;
    BucketState.StateIncoherent := FALSE;
END_IF;

ConfirmCloseEdge(CLK := ConfirmClosePosition);
IF ConfirmCloseEdge.Q
   AND (Mode = E_Mode.MAINT_N2)
   AND NOT Lifecycle.Busy AND NOT M1_Busy AND NOT M2_Busy THEN
    BucketState.IsOpen := FALSE;
    BucketState.IsClosed := TRUE;
    BucketState.LastPosM2Close := CablePosM2;
    BucketState.StateIncoherent := FALSE;
END_IF;

IF MachineHomingCommitOpen AND NOT Lifecycle.Busy THEN
    BucketState.IsOpen := TRUE;
    BucketState.IsClosed := FALSE;
    BucketState.LastPosM2Open := CablePosM2;
    BucketState.StateIncoherent := FALSE;
END_IF;

IF MachineHomingCommitClose AND NOT Lifecycle.Busy THEN
    BucketState.IsOpen := FALSE;
    BucketState.IsClosed := TRUE;
    BucketState.LastPosM2Close := CablePosM2;
    BucketState.StateIncoherent := FALSE;
END_IF;
{endregion}

{region "§4 Séquencement mouvement benne"}
SevereError := Fault.Error;
MotionRequestConflict := ReqAscent AND ReqDescend;
MotionRequestActive := (ReqAscent OR ReqDescend) AND NOT MotionRequestConflict;

IF SevereError THEN
    M2_RunRequest := FALSE;
    M2_ReqAscent := FALSE;
    M2_ReqDescend := FALSE;
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
            IF MotionRequestActive AND ReqAscent AND EffectivePermitBucket_Close THEN
                M2_RunRequest := TRUE;
                M2_ReqAscent := TRUE;
                M2_ReqDescend := FALSE;
            ELSIF MotionRequestActive AND ReqDescend AND EffectivePermitBucket_Open THEN
                M2_RunRequest := TRUE;
                M2_ReqAscent := FALSE;
                M2_ReqDescend := TRUE;
            ELSE
                M2_RunRequest := FALSE;
                M2_ReqAscent := FALSE;
                M2_ReqDescend := FALSE;
            END_IF;
        ELSIF OpenReq THEN
            RemainingTravelM := MAX(0.0, CablePosM2 - (CablePosM1 + Config.OffsetOpenM));
            M2_BucketJogLimit := TRUE;
            IF MotionRequestActive AND ReqDescend AND EffectivePermitBucket_Open THEN
                M2_RunRequest := TRUE;
                M2_ReqAscent := FALSE;
                M2_ReqDescend := TRUE;
            ELSIF MotionRequestActive AND ReqAscent AND EffectivePermitBucket_Close THEN
                M2_RunRequest := TRUE;
                M2_ReqAscent := TRUE;
                M2_ReqDescend := FALSE;
            ELSE
                M2_RunRequest := FALSE;
                M2_ReqAscent := FALSE;
                M2_ReqDescend := FALSE;
            END_IF;
        ELSE
            M2_RunRequest := FALSE;
            M2_ReqAscent := FALSE;
            M2_ReqDescend := FALSE;
            M2_BucketJogLimit := FALSE;
        END_IF;

        IF (CloseReq AND (CablePosM2 > M2StartPosM)) OR (OpenReq AND (CablePosM2 < M2StartPosM)) THEN
            LeftStartSinceArm := TRUE;
        END_IF;

        // Arrêt fermeture
        IF CloseReq THEN
            IF CablePosM2 >= (CablePosM1 + Config.OffsetCloseM - Config.CloseAnticipationM) THEN
                M2_RunRequest := FALSE;
                M2_ReqAscent := FALSE;
                M2_ReqDescend := FALSE;
                BucketState.IsOpen := FALSE;
                BucketState.IsClosed := TRUE;
                BucketState.LastPosM2Close := CablePosM2;
                BucketState.StateIncoherent := FALSE;
                CloseReq := FALSE;
                Lifecycle.Busy := FALSE;
                Lifecycle.Done := TRUE;
            ELSIF LeftStartSinceArm AND (CablePosM2 <= M2StartPosM) THEN
                M2_RunRequest := FALSE;
                M2_ReqAscent := FALSE;
                M2_ReqDescend := FALSE;
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
                M2_RunRequest := FALSE;
                M2_ReqAscent := FALSE;
                M2_ReqDescend := FALSE;
                BucketState.IsOpen := TRUE;
                BucketState.IsClosed := FALSE;
                BucketState.LastPosM2Open := CablePosM2;
                BucketState.StateIncoherent := FALSE;
                OpenReq := FALSE;
                Lifecycle.Busy := FALSE;
                Lifecycle.Done := TRUE;
            ELSIF LeftStartSinceArm AND (CablePosM2 >= M2StartPosM) THEN
                M2_RunRequest := FALSE;
                M2_ReqAscent := FALSE;
                M2_ReqDescend := FALSE;
                BucketState.IsOpen := WasOpenAtStart;
                BucketState.IsClosed := WasClosedAtStart;
                OpenReq := FALSE;
                Lifecycle.Busy := FALSE;
                Lifecycle.Done := TRUE;
            END_IF;
        END_IF;
    ELSIF Lifecycle.Done THEN
        M2_RunRequest := FALSE;
        M2_ReqAscent := FALSE;
        M2_ReqDescend := FALSE;
        M2_BucketJogLimit := FALSE;
        RemainingTravelM := 0.0;
        IF NOT MotionRequestActive THEN
            Lifecycle.Done := FALSE;
        END_IF;
    END_IF;
END_IF;

// --- Distance restante publiee en PERMANENCE (auto ET jog manuel M2) -----------------
// Hors sequence commandee (Lifecycle.Busy, qui calcule deja RemainingTravelM au plus
// juste), on publie la distance geometrique vers la cible OPPOSEE a l'etat courant :
// benne fermee -> reste a parcourir pour ouvrir ; benne ouverte -> reste pour fermer.
// Permet l'affichage IHM du "reste a faire" meme en pilotage unitaire M2 (WinchSel=2).
IF NOT Lifecycle.Busy AND NOT SevereError THEN
    IF BucketState.IsClosed AND NOT BucketState.IsOpen THEN
        RemainingTravelM := MAX(0.0, CablePosM2 - (CablePosM1 + Config.OffsetOpenM));
    ELSIF BucketState.IsOpen AND NOT BucketState.IsClosed THEN
        RemainingTravelM := MAX(0.0, (CablePosM1 + Config.OffsetCloseM) - CablePosM2);
    ELSE
        RemainingTravelM := 0.0;
    END_IF;
END_IF;

// --- Detection passive d'etat benne sur position (jog unitaire M2, hors sequence auto) --
// En pilotage unitaire benne (WinchSel=2), FB_Bucket ne pilote pas l'ouverture/fermeture
// mais l'etat memorise doit suivre la position : on accepte "ouvert" / "ferme" au meme
// seuil que l'arret jog (Offset +/- Anticipation, tous deux reglables IHM). Le point
// d'arret du jog = l'etat accepte. Zone intermediaire : etat inchange (memorise).
// Uniquement M1 ET M2 references : sinon CablePosM1/M2 (donc le delta) sont sans valeur.
IF ManualJogM2Active AND HomedM1 AND HomedM2 AND NOT Lifecycle.Busy AND NOT SevereError THEN
    IF CablePosM2 <= (CablePosM1 + Config.OffsetOpenM + Config.OpenAnticipationM) THEN
        BucketState.IsOpen        := TRUE;
        BucketState.IsClosed      := FALSE;
        BucketState.StateIncoherent := FALSE;
    ELSIF CablePosM2 >= (CablePosM1 + Config.OffsetCloseM - Config.CloseAnticipationM) THEN
        BucketState.IsClosed      := TRUE;
        BucketState.IsOpen        := FALSE;
        BucketState.StateIncoherent := FALSE;
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
                     AND (Fault.ErrorId = 0)
                     AND (MachineHomed OR (BucketState.IsOpen XOR BucketState.IsClosed))
                     AND NOT MachineHomingActive;
BucketState.ActiveOffsetValid := ActiveOffsetValid;
{endregion}

END_FUNCTION_BLOCK
