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
    HomedAndReliableM1              : BOOL;                           // --> [HW] Codeur M1 reference ET fiable (hors suspect / incoherent)
    HomedAndReliableM2              : BOOL;                           // --> [HW] Codeur M2 reference ET fiable (hors suspect / incoherent)
    HomingSuspectM1                 : BOOL;                           // --> [HW] Datum M1 explicitement suspect (perd la reference benne persistante)
    HomingSuspectM2                 : BOOL;                           // --> [HW] Datum M2 explicitement suspect (perd la reference benne persistante)
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
    M2_RunRequest                   : BOOL;                           // <-- [ACT] Ordre marche vers Winch M2
    M2_ReqAscent                    : BOOL;                           // <-- [ACT] Ordre montee vers Winch M2
    M2_ReqDescend                   : BOOL;                           // <-- [ACT] Ordre descente vers Winch M2
    M2_BucketJogLimit               : BOOL;                           // <-- [ACT] Plafond palier 1 du jog benne M2

    // === DIAGNOSTICS ET MESURES ===
    M1SlipDetected                  : BOOL;                           // <-- [DIAG] Glissement M1 detecte
    ActiveOffsetM                   : REAL;                           // <-- [DIAG] Decalage cible pour FB_WinchSync
    DeltaPosition_M                 : REAL;                           // <-- [DIAG] Ecart reel signe M2 - M1 (m)
    RemainingTravelM                : REAL;                           // <-- [DIAG] Distance restante avant cible (m)
    BucketOpening_Pct               : REAL;                           // <-- [DIAG] Ouverture benne 0..100 % (0 % = fermee a OffsetCloseM, 100 % = ouverte a OffsetOpenM) ; calcul continu sur l'ecart M2-M1 mesure
    OffsetStateMismatchWarn         : BOOL;                           // <-- [DIAG] Avertissement : ecart mesure M2-M1 incoherent avec l'offset de l'etat memorise (non bloquant)
    ActiveOffsetSettled             : BOOL;                           // <-- [STAT] ActiveOffsetM stabilise sur sa cible ET concordance etat/bande -> synchro autorisable (consomme par PRG_04)
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
    TonBandClosed                   : TON;                            // . [LOC] Debounce court bande "fermee" -> cible offset (anti-chatter au bord de bande)
    TonBandOpen                     : TON;                            // . [LOC] Debounce court bande "ouverte" -> cible offset
    TonOffsetResettle               : TON;                            // . [LOC] Stabilisation apres recalage de ActiveOffsetM (synchro re-autorisee)
    TonOffsetMismatch               : TON;                            // . [LOC] Persistance avant avertissement incoherence offset/mesure
    TonOffsetMaxViol                : TON;                            // . [LOC] Persistance avant latch OffsetMax (anti-pic bruit codeur)
    TonDatumUnreliable              : TON;                            // . [LOC] Debounce datum M1/M2 suspect avant effacement de BucketReferenced (anti-transitoire boot/EtherCAT)
    BucketRefRequest                : BOOL;                            // . [LOC] Demande de referencement benne latchee (bouton N2 / commit homing) en attente que M1+M2 soient fiables
    ClassCanRun                     : BOOL;                           // . [LOC] Conditions reunies pour classer l'etat sur la mesure (tout arrete + reference + hors homing)
    NearClosed                      : BOOL;                           // . [LOC] Mesure dans la bande "fermee" (instantane)
    NearOpen                        : BOOL;                           // . [LOC] Mesure dans la bande "ouverte" (instantane)
    NearClosedStable                : BOOL;                           // . [LOC] Bande "fermee" confirmee CST_BandStableTime (cible offset)
    NearOpenStable                  : BOOL;                           // . [LOC] Bande "ouverte" confirmee CST_BandStableTime
    BandLatchConcord                : BOOL;                           // . [LOC] Etat latche ET bande mesuree concordent -> offset benne fiable
    OffsetTargetM                   : REAL;                           // . [LOC] Cible de ActiveOffsetM avant limitation de pente
    StateOffsetM                    : REAL;                           // . [LOC] Offset issu de l'ETAT LATCHE seul (reference du filet §5a, independant du recalage)
    OffsetMaxViolNow                : BOOL;                           // . [LOC] Ecart M2-M1 hors plage plausible ce scan

    // === VARIABLES LOCALES CALCULÉES ===
    FirstCycle                      : BOOL := TRUE;                  // . [LOC] Drapeau de premier cycle API
    SevereError                     : BOOL;                           // . [LOC] Erreur grave necessitant arret
    MaxAllowedOffset                : REAL;                           // . [LOC] Borne haute plausible M2-M1 (offset ferme + marge)
    MinAllowedOffset                : REAL;                           // . [LOC] Borne basse plausible M2-M1 (offset ouvert - tolerance coherence)
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
VAR CONSTANT
    CST_BandStableTime      : TIME := T#200ms;   // Confirmation de bande avant recalage de la cible offset (anti-chatter au bord)
    CST_OffsetSlewMPerScan  : REAL := 0.08;      // Pente max de ActiveOffsetM (m/scan) : < seuil FB_Safety_Winch (0.5 m) -> pas de faux "saut de preset"
    CST_OffsetStepThresholdM : REAL := 0.10;     // Ecart cible/valeur en-dessous duquel l'offset est considere "arrive"
    CST_OffsetResettleTime  : TIME := T#1s;      // Attente supplementaire apres recalage avant de re-declarer l'offset fiable (synchro)
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
    // Cause 0 : Configuration géométrie benne.
    // Ordre ouvert < ferme obligatoire. Offset ouvert legerement negatif tolere
    // (M2 un cheveu sous M1 a l'ouverture pleine, recalibration MES) -> seuil -2 m.
    IF (Config.OffsetOpenM >= Config.OffsetCloseM)
       OR (Config.OffsetOpenM < -2.0) THEN
        CfgFaultLatched := TRUE;
    END_IF;
    instCauses[0].Active   := CfgFaultLatched;
    instCauses[0].Latching := TRUE;
    instCauses[0].Texte    := 'Configuration geometrie benne invalide';

    // Cause 1 : Depassement ecart max (plage physique plausible M2 - M1).
    // Borne haute : offset ferme + 2 m de marge inertie. Borne basse : offset ouvert
    // MOINS la tolerance de coherence (bruit codeur / leger sur-jog a l'ouverture) ->
    // ne latche plus un defaut pour quelques cm de M2 sous M1.
    MaxAllowedOffset := Config.OffsetCloseM + 2.0;
    MinAllowedOffset := Config.OffsetOpenM - Config.CoherenceLimitM;
    OffsetMaxViolNow := (CablePosM2 > (CablePosM1 + MaxAllowedOffset))
                     OR (CablePosM2 < (CablePosM1 + MinAllowedOffset));
    // Anti-pic : ne latche que si l'ecart reste hors plage > 500 ms (bruit codeur / glitch).
    TonOffsetMaxViol(IN := OffsetMaxViolNow, PT := T#500ms);
    IF TonOffsetMaxViol.Q THEN
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
    ActiveOffsetSettled := FALSE;
    ActiveOffsetM := 0.0;
    HoldOffsetM := 0.0;          // R8 : ne pas ressortir un HOLD d'avant la coupure a la reprise
    DeltaPosition_M := 0.0;
    RemainingTravelM := 0.0;
    BucketOpening_Pct := 0.0;
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
    BucketState.StateIncoherent := FALSE;
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

// --- Reference benne PERSISTANTE (RETAIN via GVL_PERSISTENT._BucketState) --------------
// Decouple la "reference benne" (position franche confirmee + datum M1/M2 fiables lors de
// la confirmation) de la validite LIVE (puissance). Survit a une coupure puissance :
// codeurs absolus M1/M2 -> Delta = M2-M1 reste connu au retour, aucune re-calibration.
//
// SET en 2 temps (anti-race, challenge Q7) : on LATCHE la demande (bouton N2 a l'arret,
// ou impulsion commit homing machine), puis on pose BucketReferenced des que M1 ET M2
// sont fiables. La demande ne survit pas a un reboot (intention transitoire) et est
// purgee sur Reset ou hors maintenance.
IF (ConfirmOpenEdge.Q OR ConfirmCloseEdge.Q)
   AND (Mode = E_Mode.MAINT_N2)
   AND NOT Lifecycle.Busy AND NOT M1_Busy AND NOT M2_Busy THEN
    BucketRefRequest := TRUE;
END_IF;
IF MachineHomingCommitOpen OR MachineHomingCommitClose THEN
    BucketRefRequest := TRUE;
END_IF;
IF ResetEdge.Q
   OR NOT ((Mode = E_Mode.MAINT_N1) OR (Mode = E_Mode.MAINT_N2)) THEN
    BucketRefRequest := FALSE;
END_IF;
IF BucketRefRequest AND NOT CfgFaultLatched
   AND HomedAndReliableM1 AND HomedAndReliableM2 THEN
    BucketState.BucketReferenced := TRUE;
    BucketRefRequest := FALSE;
END_IF;
//
// RESET : UNIQUEMENT sur cause dure = datum M1/M2 explicitement SUSPECT, confirme >=2 s.
//  - PAS sur NOT HomedAndReliable seul (peut n'etre qu'un bus EtherCAT down au boot ;
//    le blocage SEMI_AUTO "M2 suspect" est deja assure par BothAxesHomed cote cycle homing).
//  - PAS sur CfgFault (challenge Q2) : une config persistante momentanement invalide au
//    chargement effacerait la ref a tort ; CfgFault bloque deja ActiveOffsetValid LIVE.
//  - HomingSuspect n'est pose qu'apres le controle de coherence au demarrage (bus up) ->
//    pas de faux positif pendant l'enum EtherCAT. Aucun redemarrage auto : re-confirmer.
TonDatumUnreliable(IN := HomingSuspectM1 OR HomingSuspectM2, PT := T#2s);
IF TonDatumUnreliable.Q THEN
    BucketState.BucketReferenced := FALSE;
END_IF;
{endregion}

{region "§4 Séquencement mouvement benne"}
SevereError := Fault.Error;

// --- §4a Classification continue de l'etat benne sur la MESURE physique -----------------
// L'etat benne reflete directement la cinematique reelle Delta = M2 - M1.
// Tant que M1 et M2 sont references, la position relative de la benne est connue en continu.
DeltaPosition_M := CablePosM2 - CablePosM1;

ClassCanRun := HomedM1 AND HomedM2
               AND NOT SevereError;

NearClosed := ClassCanRun AND (ABS(DeltaPosition_M - Config.OffsetCloseM) <= Config.CoherenceLimitM);
NearOpen   := ClassCanRun AND (ABS(DeltaPosition_M - Config.OffsetOpenM)  <= Config.CoherenceLimitM);

// Classification continue instantanee (publiee en direct sur BucketState) :
IF ClassCanRun THEN
    BucketState.IsClosed       := NearClosed;
    BucketState.IsOpen         := NearOpen;
    BucketState.IsIntermediate := NOT NearClosed AND NOT NearOpen
                                  AND (DeltaPosition_M >= (Config.OffsetOpenM - Config.CoherenceLimitM))
                                  AND (DeltaPosition_M <= (Config.OffsetCloseM + Config.CoherenceLimitM));
    BucketState.TooOpen        := DeltaPosition_M <  (Config.OffsetOpenM  - Config.CoherenceLimitM);
    BucketState.TooClosed      := DeltaPosition_M >  (Config.OffsetCloseM + Config.CoherenceLimitM);
    BucketState.StateIncoherent := FALSE;
    IF NearClosed THEN
        BucketState.LastPosM2Close := CablePosM2;
    ELSIF NearOpen THEN
        BucketState.LastPosM2Open  := CablePosM2;
    END_IF;
ELSE
    BucketState.IsClosed       := FALSE;
    BucketState.IsOpen         := FALSE;
    BucketState.IsIntermediate := FALSE;
    BucketState.TooOpen        := FALSE;
    BucketState.TooClosed      := FALSE;
END_IF;

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
        // Position intermediaire (post-T247 : IsOpen/IsClosed temps reel, tous deux FALSE
        // des la sortie de bande). Le "reste a parcourir" reste utile en jog unitaire M2 :
        // on decompte vers la cible donnee par le sens du jog, sinon vers la plus proche.
        IF ReqAscent AND NOT ReqDescend THEN
            RemainingTravelM := MAX(0.0, (CablePosM1 + Config.OffsetCloseM) - CablePosM2);
        ELSIF ReqDescend AND NOT ReqAscent THEN
            RemainingTravelM := MAX(0.0, CablePosM2 - (CablePosM1 + Config.OffsetOpenM));
        ELSIF DeltaPosition_M > (0.5 * (Config.OffsetOpenM + Config.OffsetCloseM)) THEN
            RemainingTravelM := MAX(0.0, (CablePosM1 + Config.OffsetCloseM) - CablePosM2);
        ELSE
            RemainingTravelM := MAX(0.0, CablePosM2 - (CablePosM1 + Config.OffsetOpenM));
        END_IF;
    END_IF;
END_IF;

// --- Ouverture benne en % (0..100), calcul CONTINU sur l'ecart mesure ------------------
// 0 % = benne fermee (Delta ~ OffsetCloseM), 100 % = benne ouverte (Delta ~ OffsetOpenM).
// Independant de l'etat latche : donne toujours la position reelle, meme mi-course / non
// confirme. Borne [0..100]. (Config invalide OffsetOpenM >= OffsetCloseM -> deja CfgFault.)
IF (Config.OffsetCloseM - Config.OffsetOpenM) > 0.001 THEN
    BucketOpening_Pct := LIMIT(0.0,
        100.0 * (Config.OffsetCloseM - DeltaPosition_M)
              / (Config.OffsetCloseM - Config.OffsetOpenM),
        100.0);
ELSE
    BucketOpening_Pct := 0.0;
END_IF;

{endregion}

{region "§5 Offset actif et validite"}
// DeltaPosition_M deja calcule en §4a (classification etat).

// --- Cible d'offset OffsetTargetM (avant limitation de pente) ---------------------------
// Priorite : (1) manoeuvre en cours = ecart reel live ; (2) recalage sur la bande mesuree
// CONFIRMEE CST_BandStableTime (anti-chatter au bord de bande, R3) ; (3) etat memorise /
// demande ; (4) sinon dernier connu.
TonBandClosed(IN := NearClosed, PT := CST_BandStableTime);
TonBandOpen(IN := NearOpen,   PT := CST_BandStableTime);
NearClosedStable := TonBandClosed.Q;
NearOpenStable   := TonBandOpen.Q;

IF Lifecycle.Busy THEN
    OffsetTargetM := CablePosM2 - CablePosM1;
ELSIF NearClosedStable THEN
    OffsetTargetM := Config.OffsetCloseM;
ELSIF NearOpenStable THEN
    OffsetTargetM := Config.OffsetOpenM;
ELSIF CloseReq OR BucketState.IsClosed THEN
    OffsetTargetM := Config.OffsetCloseM;
ELSIF OpenReq OR BucketState.IsOpen THEN
    OffsetTargetM := Config.OffsetOpenM;
ELSE
    // Etat indetermine (latch efface par A, ou jamais latche) : on GELE le dernier offset
    // franc connu (HoldOffsetM). Ne PAS suivre l'ecart mesure ici -> sinon
    // ExpectedOtherWinchPosM (FB_Safety_Winch) suivrait la mesure et rendrait la
    // surveillance d'ecart croise M1/M2 aveugle en mouvement couple (challenge 2026-09-04).
    // L'incoherence est signalee par OffsetStateMismatchWarn (§5a).
    OffsetTargetM := HoldOffsetM;
END_IF;

// --- ActiveOffsetM : suivi de la cible A PENTE LIMITEE (R2/R3) --------------------------
// Un pas brut de 0 <-> OffsetCloseM (~15 m) en un scan faisait : latcher SyncDeviationWarn
// (FB_SyncDeviation, seuil 0.10 m, RAZ sur Reset seulement) et sauter PosStepDetected
// (FB_Safety_Winch, 0.5 m) -> RAZ + inhibition MecaA/MecaE. On converge donc a pente
// bornee ; pendant la convergence l'offset n'est pas "fiable" (voir ActiveOffsetSettled)
// et la synchro est inhibee cote PRG_04.
IF Lifecycle.Busy THEN
    ActiveOffsetM := OffsetTargetM;                                   // suit l'ecart reel (deplacement lent du treuil, aucun pas)
ELSE
    ActiveOffsetM := ActiveOffsetM
                     + LIMIT(-CST_OffsetSlewMPerScan,
                              OffsetTargetM - ActiveOffsetM,
                              CST_OffsetSlewMPerScan);
END_IF;
HoldOffsetM := ActiveOffsetM;

// --- ActiveOffsetSettled : ActiveOffsetM n'est PAS en cours de recalage --------------
// Vrai des que la valeur colle a sa cible depuis CST_OffsetResettleTime. Reste vrai en
// mouvement couple nominal (cible == valeur, aucun pas). Retombe UNIQUEMENT quand un
// nouveau recalage est engage (sortie de manoeuvre, re-latch d'etat apres correction).
// -> c'est CE flag qui autorise la synchro (PRG_04) : elle n'est coupee que pendant le
//    transitoire de recalage, pas en fonctionnement couple.
TonOffsetResettle(IN := (ABS(OffsetTargetM - ActiveOffsetM) <= CST_OffsetStepThresholdM),
                  PT := CST_OffsetResettleTime);
ActiveOffsetSettled := TonOffsetResettle.Q;

// --- ActiveOffsetValid : validite LIVE de l'offset (consommateur synchro PRG_04) -------
// = reference benne PERSISTANTE + conditions du moment (bloc actif, puissance, pas de
// defaut, etat coherent). Retombe a la coupure puissance ; la REFERENCE (BucketReferenced)
// est ce qui persiste et alimente le cycle homing. L'etat intermediaire n'invalide rien.
ActiveOffsetValid := Enable AND PowerContactorEngaged
                     AND BucketState.BucketReferenced
                     AND NOT BucketState.StateIncoherent
                     AND (Fault.ErrorId = 0);
BucketState.ActiveOffsetValid := ActiveOffsetValid;

// --- §5a Filet : avertissement incoherence geometrique benne (R1) -----------------
// Avertit si l'ecart mesure depasse les bornes plausibles [OffsetOpen - Coherence .. OffsetClose + Coherence]
TonOffsetMismatch(
    IN := ClassCanRun
          AND (BucketState.TooOpen OR BucketState.TooClosed),
    PT := T#2s);
OffsetStateMismatchWarn := TonOffsetMismatch.Q;
{endregion}

END_FUNCTION_BLOCK
