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
    HoldAscentP1AfterClose          : BOOL := FALSE;                  // --> [CMD] AX10B : maintient M2 en montee P1 apres fermeture, jusqu'au transfert atomique
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
    WinchSelBucket                  : BOOL := TRUE;                   // --> [CMD] Contexte de pilotage benne actif (WinchSel=2) ; FALSE hors contexte -> abandon d'une open/close restee Busy
    ProgramBucketDriveActive        : BOOL := FALSE;                  // --> [CMD] Une demande benne PROGRAMME est active (DumpAtTremie / ExtractionAssist / homing) -> NE PAS abandonner l'open/close
    M1_Busy                         : BOOL;                           // --> [HW] Treuil M1 en mouvement (Busy)
    M2_Busy                         : BOOL;                           // --> [HW] Treuil M2 en mouvement (Busy)
    BucketJogActive                 : BOOL := FALSE;                  // --> [CMD] Jog benne unitaire M2 en cours (WinchSel=2) : OffsetTargetM suit le Delta mesure live comme en Lifecycle.Busy (pas de figeage). ActiveOffsetM converge a pente bornee (jamais de PAS au basculement de mode). En WinchSel=2 : sync/MecaE deja OFF.
    InhibitM1                       : BOOL;                           // --> [HW] Treuil M1 inhibe
    InhibitM2                       : BOOL;                           // --> [HW] Treuil M2 inhibe

    // === REGLAGES ET CONFIGURATION ===
    Config                          : ST_fbBucket_Config;                // --> [CFG] Configuration parametres benne
    CfgTimeoutDuration              : TIME := T#60s;                  // --> [CFG] Timeout de mouvement configurable
    M1SlipToleranceM                : REAL := 1.0;                    // --> [CFG] Tolerance glissement M1 pendant Busy (m)
    // 🎛️ Seuil d'ouverture benne déclarant la fin de fermeture atteinte.
    // Ouverture benne RESTANTE (%) au-delà de laquelle la fermeture est considérée terminée.
    // ⚠️ La branche correspondante est AJOUTÉE en disjonction à la condition d'arrivée de
    // fermeture ci-dessous : celle-ci garde sa valeur et son rôle de filet anti-blocage.
    // ⛔ 0 = branche INACTIVE : critère d'arrivée seul.
    CloseReachedOpening_Pct         : INT := 0;                       // --> [CFG] Ouverture restante [0..50 %] déclarant la fermeture atteinte ; 0 = critère d'arrivée seul

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
    CloseReached                    : BOOL;                           // <-- [STAT] Fermeture atteinte, maintien AX10B eventuel en cours

    // === DIAGNOSTICS ET MESURES ===
    M1SlipDetected                  : BOOL;                           // <-- [DIAG] Glissement M1 detecte
    ActiveOffsetM                   : REAL;                           // <-- [DIAG] Decalage cible pour FB_WinchSync — PENTE BORNEE (securite : SyncDeviation, MecaE cross-check)
    OffsetTargetM                   : REAL;                           // <-- [DIAG] Cible d'offset INSTANTANEE (avant pente) — reference de convergence ActiveOffsetM + ecart corrige DeltaPositionCorrected_M, jamais pour la logique de securite
    DisplayOffsetM                  : REAL;                           // <-- [DIAG] Offset d'affichage continu T291-B (M2PositionCorrected) : LIMIT(OffsetOpenM, DeltaPosition_M, OffsetCloseM) — continu pour affichage IHM/traces, sans saut à la transition
    DeltaPosition_M                 : REAL;                           // <-- [DIAG] Ecart reel signe M2 - M1 (m) — MESURE brute, alimente l'etat benne (NearClosed/NearOpen, %, sync)
    DeltaPositionCorrected_M        : REAL;                           // <-- [DIAG] Ecart M1/M2 CORRIGE de la geometrie benne : DeltaPosition_M - OffsetTargetM. ~0 = treuils synchro ; != 0 = derive treuil ou benne pas a l'etat memorise. Pour l'operateur (pas la logique d'etat).
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
    TofReferencePreset              : TOF;                            // . [LOC] Fenetre de grace suivi immediat ActiveOffsetM apres preset IHM (1.5 s)
    ReferencePresetActive           : BOOL;                           // . [LOC] TRUE pendant la fenetre de grace post-confirmation
    TonTimeout                      : TON;                            // . [LOC] Temporisateur timeout de mouvement
    TimeoutEngaged                  : BOOL;                           // . [LOC] Commande operateur REELLEMENT engagee pendant la manoeuvre benne
    TimeoutRestart                  : BOOL;                           // . [LOC] Segment TON neuf force un scan (rearmement conscient sur Reset)
    TimeoutAccumTime                : TIME;                           // . [LOC] Temps de commande engagee deja consomme, GELE hors engagement (segments precedents)
    TimeoutSegmentTime              : TIME;                           // . [LOC] ET du segment de commande en cours (reporte dans le cumul au relachement)
    TimeoutRemainingTime            : TIME;                           // . [LOC] Budget restant consomme par le TON (CfgTimeoutDuration - cumul)
    TonBandClosed                   : TON;                            // . [LOC] Debounce court bande "fermee" -> cible offset (anti-chatter au bord de bande)
    TonBandOpen                     : TON;                            // . [LOC] Debounce court bande "ouverte" -> cible offset
    TonRecoilLimit                  : TON;                            // . [LOC] Anti-chatter de la limite de recul benne (meme base de temps que TonBand*)
    RecoilLimitReachedNow           : BOOL;                           // . [LOC] Recul au bord de la frontiere PHYSIQUE benne ce scan (instantane, non confirme)
    RecoilLimitActive               : BOOL;                           // . [LOC] Limite de recul ACTIVE (confirmee CST_BandStableTime)
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
    OffsetMaxViolNow                : BOOL;                           // . [LOC] Ecart M2-M1 hors plage plausible ce scan
    HomingPositionValid             : BOOL;
    HomingMotionWithoutReference    : BOOL;

    // === VARIABLES LOCALES CALCULÉES ===
    FirstCycle                      : BOOL := TRUE;                  // . [LOC] Drapeau de premier cycle API
    SevereError                     : BOOL;                           // . [LOC] Erreur grave necessitant arret
    MaxAllowedOffset                : REAL;                           // . [LOC] Borne haute plausible M2-M1 (offset ferme + marge)
    MinAllowedOffset                : REAL;                           // . [LOC] Borne basse plausible M2-M1 (offset ouvert - tolerance coherence)
    M1RefPosM                       : REAL;                           // . [LOC] Position M1 memorisee a l'entree Busy
    HoldOffsetM                     : REAL;                           // . [LOC] Ecart reel mémorise (gel en position intermediaire)
    MotionRequestActive             : BOOL;                           // . [LOC] Demande valide : un seul sens
    MotionRequestConflict           : BOOL;                           // . [LOC] Deux sens = arrêt sûr

    // Latches défauts
    CfgFaultLatched                 : BOOL;
    OffsetMaxFaultLatched           : BOOL;
    TimeoutFaultLatched             : BOOL;
    M1SlipFaultLatched              : BOOL;

    // Socle défaut
    instFault                       : FB_FaultCore;                   // * [INST] Socle défaut transverse
    instCauses                      : ARRAY[0..15] OF ST_FaultCause;  // . [LOC] Table des causes nommées

    // Seuil de fermeture : FB PUR (aucun état) qui dérive le réglage en distance et en
    // signal qualifié. Appelé au scan même dans la branche d'arrivée de fermeture, sur la
    // MESURE de ce scan (§4a).
    instCloseThreshold              : FB_BucketCloseThreshold;         // * [INST] Seuil d'ouverture benne déclarant la fermeture atteinte
    ThresholdMeasureValid           : BOOL;                           // . [LOC] Qualification de la mesure pour la branche seuil (références, défauts, référence benne)
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

// 🎯 Signal d'engagement benne — calcule AVANT le watchdog de timeout (§1 Cause 2) pour que le
// relachement de l'operateur soit pris en compte AU SCAN MEME : un TON arme sur un signal lu avec
// un scan de retard compterait la pause entiere. Meme calcul qu'auparavant (ReqAscent et
// ReqDescend sont des VAR_INPUT, jamais reecrites) : seul l'instant de calcul avance en tete de §1.
MotionRequestConflict := ReqAscent AND ReqDescend;
MotionRequestActive := (ReqAscent OR ReqDescend) AND NOT MotionRequestConflict;

IF ResetEdge.Q OR BypassGlobal THEN
    CfgFaultLatched       := FALSE;
    OffsetMaxFaultLatched := FALSE;
    TimeoutFaultLatched   := FALSE;
    M1SlipFaultLatched    := FALSE;
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
    // (REVERT 2026-09-04 : le MIN(...,-0.5) + NOT MachineHomingActive introduits plus tot
    // compensaient OffsetOpenM=2.25, une valeur ERRONEE. OffsetOpenM=0.0 / CoherenceLimitM=1.0
    // sont les vraies valeurs physiques, confirmees operateur, ne doivent plus changer.
    // Avec ces valeurs MinAllowedOffset=-1.0 -> Delta=0 au preset homing n'a jamais ete un
    // probleme -> plus besoin de ce contournement.)
    MaxAllowedOffset := Config.OffsetCloseM + 2.0;
    MinAllowedOffset := Config.OffsetOpenM - Config.CoherenceLimitM;
    HomingPositionValid := HomedAndReliableM1
                         AND HomedAndReliableM2
                         AND NOT MachineHomingActive;
    OffsetMaxViolNow := HomingPositionValid
                     AND ((CablePosM2 > (CablePosM1 + MaxAllowedOffset))
                          OR (CablePosM2 < (CablePosM1 + MinAllowedOffset)));
    // Anti-pic : ne latche que si l'ecart reste hors plage > 500 ms (bruit codeur / glitch).
    TonOffsetMaxViol(IN := OffsetMaxViolNow, PT := T#500ms);
    IF TonOffsetMaxViol.Q THEN
        OffsetMaxFaultLatched := TRUE;
    END_IF;
    instCauses[1].Active   := OffsetMaxFaultLatched;
    instCauses[1].Latching := TRUE;
    instCauses[1].Texte    := 'Depassement ecart maximum autorise benne';

    // Cause 2 : Timeout de manoeuvre benne — budget SUSPENDU hors commande engagee.
    // ⏱️ Le budget ne se consomme QUE pendant une commande operateur REELLEMENT engagee
    // (Lifecycle.Busy ET MotionRequestActive). Hors engagement le compteur est GELE — il n'est
    // PAS remis a zero — et il reprend/se CUMULE a la commande suivante : une pause operateur
    // legitime (relachement du joystick en AX3_OPEN_BUCKET / AX15B_DUMP_OPEN, cf.
    // WaitingForOperator FB_CycleSemiAuto.st:1430) ne peut donc plus produire un faux
    // [BENNE] ErrorID:03, alors qu'un mouvement bloque SOUS COMMANDE CONTINUE latche toujours
    // en CfgTimeoutDuration (non-neutralisation). Remise a zero du cumul : fin de manoeuvre
    // (Lifecycle.Busy retombe) et Reset sur front (rearmement conscient).
    // Signal d'engagement : MotionRequestActive (calcule en tete de §1) — CloseReq/OpenReq sont
    // des LATCHES (restent TRUE pendant toute la pause) et seraient ici INOPERANTS.
    TimeoutEngaged := Lifecycle.Busy AND MotionRequestActive;

    // Rearmement conscient : budget complet ET segment TON neuf. Un TON IEC ne retombe PAS quand
    // PT augmente (ET cloue a PT, Q fige) : sans cette coupure d'un scan, un Reset pendant une
    // commande encore engagee re-latcherait le defaut au scan suivant.
    IF ResetEdge.Q THEN
        TimeoutAccumTime   := T#0s;
        TimeoutSegmentTime := T#0s;
        TimeoutRestart     := TRUE;
    END_IF;

    // Relachement operateur : le segment courant est reporte dans le cumul (GEL, jamais une RAZ).
    IF NOT TimeoutEngaged THEN
        TimeoutAccumTime   := TimeoutAccumTime + TimeoutSegmentTime;
        TimeoutSegmentTime := T#0s;
    END_IF;

    // Budget restant -> PT du TON (borne a T#0s : un cumul >= PT latche des le premier scan engage).
    TimeoutRemainingTime := CfgTimeoutDuration - TimeoutAccumTime;
    IF TimeoutRemainingTime < T#0s THEN
        TimeoutRemainingTime := T#0s;
    END_IF;

    TonTimeout(IN := TimeoutEngaged AND NOT TimeoutRestart, PT := TimeoutRemainingTime);
    TimeoutRestart := FALSE;   // coupure d'un seul scan -> le TON repart d'un segment a ET=0

    IF TimeoutEngaged THEN
        TimeoutSegmentTime := TonTimeout.ET;
    END_IF;

    IF TonTimeout.Q THEN
        TimeoutFaultLatched := TRUE;
    END_IF;

    // Fin de manoeuvre : cumul remis a zero (la manoeuvre suivante repart d'un budget neuf).
    IF NOT Lifecycle.Busy THEN
        TimeoutAccumTime   := T#0s;
        TimeoutSegmentTime := T#0s;
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
    HomingMotionWithoutReference := (ReqAscent OR ReqDescend OR CmdOpen_IHM OR CmdClose_IHM OR ProgramBucketDriveActive)
                                  AND NOT MachineHomingActive
                                  AND NOT (HomedM1 AND HomedM2);
    instCauses[4].Active   := HomingMotionWithoutReference;
    instCauses[4].Latching := FALSE;
    instCauses[4].Texte    := 'Codeurs treuils non references pour sequence benne';
ELSE
    TonTimeout(IN := FALSE);
    TimeoutEngaged      := FALSE;   // bypass global : watchdog neutralise ET cumul remis a zero
    TimeoutAccumTime    := T#0s;
    TimeoutSegmentTime  := T#0s;
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
    DeltaPositionCorrected_M := 0.0;
    DisplayOffsetM := Config.OffsetCloseM;    // repli nominal (jamais 0 -> pas d'affichage aberrant)
    Lifecycle.Busy := FALSE;
    Lifecycle.Done := FALSE;
    M2_RunRequest := FALSE;
    M2_ReqAscent := FALSE;
    M2_ReqDescend := FALSE;
    M2_BucketJogLimit := FALSE;
    CloseReached := FALSE;
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
    DisplayOffsetM := Config.OffsetCloseM;    // valeur de depart avant 1er classement d'etat franc
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

// MotionRequestConflict / MotionRequestActive sont calcules en tete de §1 : le watchdog de timeout
// doit voir le relachement de l'operateur au scan meme (aucun lag d'un scan).

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
    // ⚠️ SÉCURITÉ : abandon propre si une open/close est restée Busy HORS de tout contexte
    // de pilotage benne (opérateur a quitté WinchSel=2 sans que le mouvement soit fini,
    // hors cycle AUTO/SEMI_AUTO, hors homing machine). Sinon M2 continue de suivre la benne
    // pendant un pilotage COUPLÉ WinchSel=0 -> désynchro des câbles (REX MES 2026-09-04).
    IF Lifecycle.Busy
       AND NOT WinchSelBucket
       AND NOT ProgramBucketDriveActive
       AND NOT MachineHomingActive
       AND NOT (Mode = E_Mode.SEMI_AUTO) THEN
        M2_RunRequest := FALSE;
        M2_ReqAscent := FALSE;
        M2_ReqDescend := FALSE;
        M2_BucketJogLimit := FALSE;
        CloseReq := FALSE;
        OpenReq := FALSE;
        Lifecycle.Busy := FALSE;
        Lifecycle.Done := FALSE;
    END_IF;

    // Prise en compte des demandes IHM — anti-traversée (TC-P10-025) :
    // demande benne refusée si un treuil agit (M1_Busy OR M2_Busy) à l'entrée READY.
    IF CmdOpen_IHM AND NOT Lifecycle.Busy AND NOT M1_Busy AND NOT M2_Busy THEN
        OpenReq := TRUE;
        CloseReq := FALSE;
        CloseReached := FALSE;
    ELSIF CmdClose_IHM AND NOT Lifecycle.Busy AND NOT M1_Busy AND NOT M2_Busy THEN
        CloseReq := TRUE;
        OpenReq := FALSE;
        CloseReached := FALSE;
    END_IF;

    // Armement de la manoeuvre : uniquement HORS manoeuvre deja engagee.
    // M1RefPosM est la reference de la detection de glissement M1 (§1, cause 3). La recapturer en
    // cours de manoeuvre re-baselinerait cette reference a chaque relachement puis repompage du
    // joystick, ce qui rendrait un glissement reel indetectable (derive decoupee en tranches sous
    // la tolerance). Le front d'armement est preserve : Lifecycle.Busy est pose plus bas dans ce
    // meme scan, il vaut donc encore FALSE au scan d'armement.
    BusyEdge(CLK := (CloseReq OR OpenReq) AND MotionRequestActive AND NOT Lifecycle.Busy);

    IF BusyEdge.Q THEN
        M1RefPosM := CablePosM1;
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
    END_IF;

    IF Lifecycle.Busy AND CloseReached AND NOT HoldAscentP1AfterClose THEN
        // AX10B relache explicitement la benne : le cycle prend M1+M2 P1 au meme scan.
        M2_RunRequest := FALSE;
        M2_ReqAscent := FALSE;
        M2_ReqDescend := FALSE;
        M2_BucketJogLimit := FALSE;
        Lifecycle.Busy := FALSE;
        Lifecycle.Done := TRUE;
    ELSIF Lifecycle.Busy AND CloseReached AND HoldAscentP1AfterClose THEN
        // Raccordement AX10B : M2 continue en montee, palier impose par l'arbitre a P1.
        M2_BucketJogLimit := TRUE;
        M2_RunRequest := MotionRequestActive AND ReqAscent AND EffectivePermitBucket_Close;
        M2_ReqAscent := M2_RunRequest;
        M2_ReqDescend := FALSE;
    ELSIF Lifecycle.Busy THEN
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

        // --- Limite de recul : frontiere PHYSIQUE benne, directionnelle ---------------------------
        // Sous une commande engagee, un recul (sens OPPOSE a la manoeuvre) ne peut pas franchir la
        // frontiere physique de la benne : bord de la zone "trop ouvert" pour une fermeture
        // (Delta <= OffsetOpenM - CoherenceLimitM), bord de la zone "trop ferme" pour une ouverture
        // (Delta >= OffsetCloseM + CoherenceLimitM). C'est la MEME frontiere que TooOpen/TooClosed
        // (§4a), MinAllowedOffset et la cause 1 (OffsetMaxViolNow) : aucune constante nouvelle.
        // Sans cette limite, un recul soutenu franchit la frontiere puis latche la cause 1 en 500 ms
        // (arret + Reset) ; ici le recul est simplement inhibe, proprement, sans defaut.
        // Anti-chatter : frontiere FIXE (independante du geste operateur) + confirmation
        // CST_BandStableTime, la temporisation "anti-chatter au bord" deja utilisee par les bandes.
        // DIRECTIONNEL : seule la direction de RECUL est inhibee ; le sens allant VERS LA CIBLE reste
        // servi (HoldAscentP1AfterClose force deja M2_ReqDescend a FALSE : non affecte).
        // ClassCanRun gate la mesure : sans datum M1/M2 la position relative n'a pas de sens (le
        // mouvement sans reference est deja couvert par la cause 4, HomingMotionWithoutReference).
        // CloseReq / OpenReq, Lifecycle et BucketState ne sont PAS touches : la reprise se fait au
        // joystick sans reappui IHM, et aucun etat n'est falsifie.
        RecoilLimitReachedNow := ClassCanRun
                                 AND ((CloseReq AND (DeltaPosition_M <= (Config.OffsetOpenM - Config.CoherenceLimitM)))
                                      OR (OpenReq AND (DeltaPosition_M >= (Config.OffsetCloseM + Config.CoherenceLimitM))));
        TonRecoilLimit(IN := RecoilLimitReachedNow, PT := CST_BandStableTime);
        RecoilLimitActive := TonRecoilLimit.Q;

        IF RecoilLimitActive THEN
            IF CloseReq THEN
                M2_ReqDescend := FALSE;                          // recul vers l'ouverture interdit
            ELSE
                M2_ReqAscent := FALSE;                           // recul vers la fermeture interdit
            END_IF;
            M2_RunRequest := M2_ReqAscent OR M2_ReqDescend;       // le sens VERS LA CIBLE reste servi
        END_IF;

        // Arrêt fermeture
        IF CloseReq THEN
            // 🎛️ Branche AJOUTÉE, jamais substitutive : la condition d'arrivée ci-dessous
            // (Config.CloseAnticipationM) conserve sa valeur et son rôle de filet
            // anti-blocage sur matière dense ; la disjonction permet d'atteindre la même
            // conclusion avec une ouverture benne restante plus grande, sur une mesure
            // QUALIFIÉE.
            // Qualification : références M1/M2, absence de défaut latché (géométrie benne
            // invalide incluse) et référence benne persistante. Le gate d'entrée §2
            // garantit déjà Enable ET PowerContactorEngaged (RETURN en tête de bloc).
            ThresholdMeasureValid := ClassCanRun
                                     AND BucketState.BucketReferenced
                                     AND NOT Fault.Error;
            instCloseThreshold(
                ThresholdPct    := CloseReachedOpening_Pct,
                OffsetOpenM     := Config.OffsetOpenM,
                OffsetCloseM    := Config.OffsetCloseM,
                DeltaPosition_M := DeltaPosition_M,
                MeasureValid    := ThresholdMeasureValid,
                IsIntermediate  := BucketState.IsIntermediate
            );

            IF CablePosM2 >= (CablePosM1 + Config.OffsetCloseM - Config.CloseAnticipationM)
               OR instCloseThreshold.Reached THEN
                M2_RunRequest := MotionRequestActive AND ReqAscent AND EffectivePermitBucket_Close;
                M2_ReqAscent := M2_RunRequest;
                M2_ReqDescend := FALSE;
                M2_BucketJogLimit := TRUE;
                BucketState.IsOpen := FALSE;
                BucketState.IsClosed := TRUE;
                BucketState.LastPosM2Close := CablePosM2;
                BucketState.StateIncoherent := FALSE;
                CloseReq := FALSE;
                CloseReached := TRUE;
                IF HoldAscentP1AfterClose THEN
                    Lifecycle.Busy := TRUE;
                    Lifecycle.Done := FALSE;
                ELSE
                    M2_RunRequest := FALSE;
                    M2_ReqAscent := FALSE;
                    M2_BucketJogLimit := FALSE;
                    Lifecycle.Busy := FALSE;
                    Lifecycle.Done := TRUE;
                END_IF;
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

// --- Ouverture benne en % (mise a l'echelle 0..100), calcul CONTINU sur l'ecart mesure -
// 0 % = benne fermee (Delta = OffsetCloseM), 100 % = benne ouverte (Delta = OffsetOpenM).
// Mise a l'echelle non bornee volontairement : une valeur negative ou superieure a 100
// signale un sur-fermeture ou un sur-ouverture reelle (Delta hors [OffsetOpenM..OffsetCloseM])
// -- l'ecraser a 0/100 masquerait cette information de diagnostic. Independant de l'etat
// latche : donne toujours la position reelle, meme mi-course / non confirme. (Config invalide
// OffsetOpenM >= OffsetCloseM -> deja CfgFault.)
IF (Config.OffsetCloseM - Config.OffsetOpenM) > 0.001 THEN
    BucketOpening_Pct := 100.0 * (Config.OffsetCloseM - DeltaPosition_M)
                                / (Config.OffsetCloseM - Config.OffsetOpenM);
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

// Fenetre de grace apres une CONFIRMATION IHM (preset benne, §3) : CablePosM2 vient
// d'etre reecrit INSTANTANEMENT par le preset (PRG_02, encodeur M2 := M1 + Offset).
// Contrairement a un mouvement physique (Busy/Jog), ce n'est pas une position qui glisse
// lentement -> ActiveOffsetM doit suivre le saut IMMEDIATEMENT, sinon SyncDeviation ET
// MecaE cross-check (tous deux bases sur ActiveOffsetM) voient un ecart transitoire faux
// pendant la convergence a pente bornee (REX MES 2026-09-04 : [SYNC] ErrorID:01 juste
// apres homing benne open, meme sync desactive -> MecaE reste actif independamment).
TofReferencePreset(IN := ConfirmOpenEdge.Q OR ConfirmCloseEdge.Q, PT := T#1s500ms);
ReferencePresetActive := TofReferencePreset.Q;

IF Lifecycle.Busy OR BucketJogActive OR ReferencePresetActive THEN
    // Sequence auto OU jog unitaire M2 OU fenetre de grace preset : l'offset suit
    // l'ecart reel (mouvement physique lent, ou saut preset qu'il faut refleter tout de suite).
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
// REVISION 2026-09-04 : suivi IMMEDIAT (pas de pente) pendant toute manoeuvre PHYSIQUE
// reelle (Lifecycle.Busy / jog M2 / preset IHM). Historique : la pente etait generalisee
// a TOUT (y compris en jog) pour eviter un PAS visuel sur l'affichage benne au
// basculement de mode -> mais ActiveOffsetM alimente aussi des CONSOMMATEURS SECURITE
// (SyncDeviation, MecaE cross-check, ET la compensation de limite haute M2 -
// M2_LimitShift, PRG_04) : en pente pendant un jog reel, ces surveillances retardent
// derriere la vraie position -> faux "[TREUIL] Montee interdite - limite haute" en
// fermant la benne en jog (REX MES 2026-09-04). Le probleme d'affichage est desormais
// regle AUTREMENT (DeltaPositionCorrected_M/M2PositionCorrected lisent OffsetTargetM,
// pas ActiveOffsetM, voir plus bas) -> on peut donc suivre ActiveOffsetM en direct
// pendant le mouvement reel SANS reintroduire le PAS visuel. La pente ne reste utile
// QUE pour les transitions SANS mouvement physique (reclassification d'etat franc,
// basculement de mode a l'arret) -> cas non couvert par Busy/Jog/ReferencePresetActive.
IF Lifecycle.Busy OR BucketJogActive OR ReferencePresetActive THEN
    ActiveOffsetM := OffsetTargetM;
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

// --- Offset continu d'affichage (M2PositionCorrected, PRG_04) --------------------------
// T291-B : Calcul continu de l'offset géométrique d'affichage (OffsetOpenM .. OffsetCloseM).
// Supprime le saut discontinu de 15 m aux franchissements d'états francs pour l'IHM et les traces.
// Attention : en position intermédiaire, la mesure absorbe la dérive propre de M2 ;
// elle n'est donc PAS qualifiée pour un usage de sécurité (M2PositionCorrectedValid reste FALSE).
IF (Config.OffsetCloseM - Config.OffsetOpenM) > 0.001 THEN
    DisplayOffsetM := LIMIT(Config.OffsetOpenM, DeltaPosition_M, Config.OffsetCloseM);
ELSE
    // Configuration invalide (OffsetOpenM >= OffsetCloseM) -> repli neutre sans masquage
    DisplayOffsetM := 0.0;
END_IF;

// --- Ecart M1/M2 CORRIGE de la geometrie benne (operateur, lecture seule) --------------
// = Delta mesure - offset benne attendu. ~0 : treuils synchro. != 0 : derive d'un treuil,
// OU benne pas a l'etat memorise. AFFICHAGE OPERATEUR SEUL (la logique de securite SYNC/MecaE
// lit ActiveOffsetM directement) : on utilise la cible INSTANTANEE OffsetTargetM, pas
// ActiveOffsetM (pente bornee) -> reste ~0 quand M1/M2 sont synchro meme benne en manoeuvre.
DeltaPositionCorrected_M := DeltaPosition_M - OffsetTargetM;
{endregion}

END_FUNCTION_BLOCK
