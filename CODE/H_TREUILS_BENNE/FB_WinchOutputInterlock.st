(* =======================================================================
   🛡️ FB_WinchOutputInterlock — Barrière finale frein / puissance M1 ou M2
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Barrière de sécurité finale pour frein et contacteurs M1/M2
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 Interface : Interlock de sortie (entre FB_Winch et PRG_06_Outputs)
   🧩 Défaut homogénéisé (AF-03 §3) : Fault:ST_Fault via FB_FaultCore (bit0 = timeout frein).
   🔒 Sécurité : Surveillance feedback frein, temporisation d'inversion et ordre de relâchement contacteurs
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_WinchOutputInterlock
VAR_INPUT
    // === COMMANDES ET ETATS GENERAL ===
    Enable                          : BOOL;                           // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    Reset                           : BOOL;                           // --> [CMD] Acquittement defaut sur front
    SafeStop                        : BOOL;                           // --> [SAFE] Entree securite pour interface standard
    AscentPermit                    : BOOL;                           // --> [SAFE] Permis final sens montee (TRUE = autorise)
    DescendPermit                   : BOOL;                           // --> [SAFE] Permis final sens descente (TRUE = autorise)

    // === HARDWARE ET FEEDBACKS ===
    PowerContactorEngaged           : BOOL;                           // --> [SAFE] Chaine AU rearmee et puissance OK
    BrakeFeedback                   : BOOL;                           // --> [HW] Feedback physique ouverture frein (NC)
    FwdRevSpeedFeedbackOff          : BOOL;                           // --> [HW] Feedback retombe tous contacteurs sens/vitesse

    // === DEMANDES DE COMMANDE AMONT ===
    RequestedRelayFwd               : BOOL;                           // --> [CMD] Demande contacteur sens montee
    RequestedRelayRev               : BOOL;                           // --> [CMD] Demande contacteur sens descente
    RequestedContactor1             : BOOL;                           // --> [CMD] Demande contacteur vitesse palier 1
    RequestedContactor2             : BOOL;                           // --> [CMD] Demande contacteur vitesse palier 2
    RequestedContactor3             : BOOL;                           // --> [CMD] Demande contacteur vitesse palier 3
    RequestedContactor4             : BOOL;                           // --> [CMD] Demande contacteur vitesse palier 4
    RequestedStep                   : INT;                            // --> [CMD] Palier de vitesse demande

    // === TEMPS MORT DIRECTIONNEL (TC-P10-021/022) ===
    DeadTimeSameDir                 : TIME := T#1s;                  // --> [CFG] Temps mort redemarrage meme sens apres arret
    DeadTimeOppositeDir             : TIME := T#1s;                  // --> [CFG] Temps mort redemarrage inversion sens apres arret

    // === MAINTIEN BORNÉ DU CONTACTEUR DE SENS (§3bis / AC6-AC8) ===
    // Paramètres DÉDIÉS, distincts de DeadTimeSameDir/OppositeDir et de tout délai
    // d'interlock direction (ne pas réutiliser ni recouvrir D10). Ordre garanti :
    // DropConfirmDelay (100 ms) < MaxSenseHoldTime (1 s), les 2 modifiables (AC8).
    DropConfirmDelay                : TIME := T#100ms;               // --> [CFG] Debounce confirmation retombee contacteurs (AC7)
    MaxSenseHoldTime                : TIME := T#1s;                  // --> [CFG] T_max : borne superieure du maintien §3bis (AC7)

    // === ORDRE DE RELACHEMENT CONTACTEURS (vitesse avant direction) ===
    ReleaseOrderDelay               : TIME := T#100ms;               // --> [CFG] Decalage relachement direction apres vitesse (>= 100ms)
END_VAR
VAR_OUTPUT
    // === ETATS IEC ET SYNOPTIQUE ===
    Ready                           : BOOL;                           // <-- [STAT] FB pret a fonctionner
    Busy                            : BOOL;                           // <-- [STAT] Interlock actif
    Done                            : BOOL;                           // <-- [STAT] Action terminee
    Fault                           : ST_Fault;                       // <-- [DIAG] Defaut transverse standard (socle FB_FaultCore, bit0: timeout frein)
    State                           : E_WinchFinalInterlockState;     // <-- [STAT] Etat courant machine d'etat interlock
    StateAtError                    : E_WinchFinalInterlockState;     // <-- [DIAG] Etat memorise lors du dernier defaut
    Reason                          : E_WinchFinalInterlockReason;    // <-- [DIAG] Cause de neutralisation ou blocage

    // === ORDRES ACTIONNEURS VALIDES ===
    AuthorizedStep                  : INT;                            // <-- [ACT] Palier de vitesse autorise
    RelayFwd                        : BOOL;                           // <-- [ACT] Ordre contacteur sens montee valide
    RelayRev                        : BOOL;                           // <-- [ACT] Ordre contacteur sens descente valide
    Contactor1                      : BOOL;                           // <-- [ACT] Ordre contacteur vitesse palier 1 valide
    Contactor2                      : BOOL;                           // <-- [ACT] Ordre contacteur vitesse palier 2 valide
    Contactor3                      : BOOL;                           // <-- [ACT] Ordre contacteur vitesse palier 3 valide
    Contactor4                      : BOOL;                           // <-- [ACT] Ordre contacteur vitesse palier 4 valide
    BrakeCmd                        : BOOL;                           // <-- [ACT] Ordre ouverture frein valide

    // === DIAGNOSTICS ET TEMPORISATIONS ===
    BrakeTimeoutElapsed             : TIME;                           // <-- [DIAG] Ecoule temporisation watchdog frein
    RestartInhibit                  : BOOL;                           // <-- [DIAG] Inhibition redemarrage actif
    RestartDelayElapsed             : TIME;                           // <-- [DIAG] Ecoule temporisation anti-court-cycle
    DeadTimeElapsed                 : TIME;                           // <-- [DIAG] Ecoule temps mort directionnel
    StepDelayElapsed                : TIME;                           // <-- [DIAG] Ecoule temporisation palier

    // === DIAGNOSTICS MAINTIEN §3bis (AC6/AC7) ===
    SenseHoldActive                 : BOOL;                           // <-- [DIAG] Maintien du contacteur de sens en cours
    ContactorStuck                  : BOOL;                           // <-- [DIAG] Latch T_max depasse sans confirmation retombee (AC7)
    SenseHoldElapsed                : TIME;                           // <-- [DIAG] Ecoule temporisation T_max maintien §3bis

    // === DIAGNOSTICS ORDRE DE RELACHEMENT (AC1/AC2) ===
    ReleaseOrderElapsed             : TIME;                           // <-- [DIAG] Ecoule temporisation ordre de relachement

    // === DISPONIBILITE MOUVEMENT (consomme par la disponibilite d'armement, PRG_04) ===
    MovementInhibited              : BOOL;                            // <-- [STAT] TRUE = une tempo idle / inhibition interdit reellement de bouger maintenant (FB non pret, anti-court-cycle, temps mort directionnel, contacteur colle). N'arrete rien : retire la disponibilite.
END_VAR
VAR
    PermitFinalBlocked              : BOOL;                           // . [LOC] Demande directionnelle refusee au dernier niveau
    // === DETECTEURS ET TIMERS INTERNES ===
    ResetEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Reset
    ErrorEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Erreur
    BrakeTimeoutCauseEdge           : R_TRIG;                         // . [LOC] Detecteur front cause timeout frein
    BrakeTimeout                    : TON;                            // . [LOC] Temporisation watchdog frein
    StepDelay                       : TON;                            // . [LOC] Temporisation changement de palier
    RestartDelay                    : TON;                            // . [LOC] Temporisation anti-court-cycle redemarrage
    DeadTime                        : TON;                            // . [LOC] Temporisation temps mort directionnel
    SenseHoldTimer                  : TON;                            // . [LOC] Temporisation T_max maintien §3bis (AC7)
    SenseHoldFeedbackTimer          : TON;                            // . [LOC] Debounce DropConfirmDelay retombee contacteurs (AC7)
    ReleaseOrderTimer               : TON;                            // . [LOC] Temporisation ordre de relachement (vitesse avant direction)
    ReleaseOrderActive              : BOOL;                           // . [LOC] Ordre de relachement en cours (direction tenue)
    ReleaseOrderDone                : BOOL;                           // . [LOC] One-shot ordre de relachement effectue (anti-bouclage)

    // === VARIABLES LOCALES CALCULÉES ===
    RestartRequired                 : BOOL;                           // . [LOC] Exigence de retour au neutre pour redemarrage
    ResetRequired                   : BOOL;                           // . [LOC] Exigence d'acquittement Reset conscient
    NeutralRequestSeen              : BOOL;                           // . [LOC] Observation passage consigne au neutre
    RequestedStepClamped            : INT;                            // . [LOC] Palier demande borne dans [0..5]
    StepDelayTarget                 : INT;                            // . [LOC] Cible palier memorisee
    MotorRequest                    : BOOL;                           // . [LOC] Demande mouvement moteur active
    BrakeTimeoutCause               : BOOL;                           // . [LOC] Cause timeout frein presente
    BrakeTimeoutAck                 : BOOL := TRUE;                  // . [LOC] Acquittement cause timeout frein
    LastDirection                   : INT;                            // . [LOC] Dernier sens commande (1 montee / -1 descente)
    DeadTimePending                 : BOOL;                           // . [LOC] Temps mort directionnel en attente
    NewDirection                    : INT;                            // . [LOC] Sens de la nouvelle demande
    RequiredDeadTime                : TIME;                           // . [LOC] Temps mort requis selon sens de la demande
    SenseHoldRequested              : BOOL;                           // . [LOC] Condition §3bis demandee (palier 0 + sens commande)
    SenseHoldDone                   : BOOL;                           // . [LOC] One-shot maintien effectue (anti-bouclage)
    ContactorStuckLatched           : BOOL;                           // . [LOC] Latch interne T_max depasse sans confirmation retombee

    // === ÉTAT DÉFAUT INTERNE (gate machine) ===
    // Gate interne PRÉSERVÉE à l'identique → sorties Error/ErrorId déplacées du scope
    // VAR_OUTPUT vers locaux retenus : lecture en §2bis/§5 et écriture en §6bis inchangées,
    // SEULE la publication est homogénéisée sur Fault:ST_Fault (§6bis2).
    Error                           : BOOL;                           // . [LOC] Synthese defaut (gate interne, = ErrorId <> 0)
    ErrorId                         : WORD;                           // . [LOC] Code erreur (bit0: timeout frein) — gate interne

    // === SOCLE DEFAUT (transverse standard AF-03 §3) ===
    instFault                       : FB_FaultCore;                  // * [INST] Socle defaut (vue live + latchee)
    instCauses                      : ARRAY[0..15] OF ST_FaultCause; // . [LOC] Causes en clair pour le socle defaut
END_VAR

VAR CONSTANT
    // Plancher DUR de cadence de montee de palier a la barriere finale, INDEPENDANT
    // de FB_WinchStepShaper (metier). Choisi PLUS COURT que la cadence nominale du
    // shaper (1 s en montee) : en exploitation le shaper reste le rythme primaire,
    // ce plancher n'ajoute qu'un leger retard borne par cran. Il ne devient decisif
    // QUE si le shaper deraille (rampe a 0 -> palier 5 instantane, decodage inverse) :
    // la barriere ramene alors la montee a +1 cran / ce delai. Descente non limitee.
    CST_StepRampFloorDelay          : TIME := T#700ms;
END_VAR

// ── 1. FRONT RESET AVANT GATE ───────────────────────────────────────────
// Le front est échantillonné même pendant Enable/AU faux : un Reset maintenu
// pendant une gate ne devient jamais un faux acquittement au retour.
ResetEdge(CLK := Reset);

// ── 2. GATE : neutralisation sûre ───────────────────────────────────────
// ErrorId, RestartInhibit et ResetRequired ne sont jamais effacés par une perte
// Enable/AU : celle-ci coupe uniquement les sorties. Le retour exige toujours un
// acquittement conscient puis une nouvelle demande opérateur.
IF NOT Enable OR NOT PowerContactorEngaged THEN
    BrakeTimeout(IN := FALSE, PT := T#500ms);
    StepDelay(IN := FALSE, PT := CST_StepRampFloorDelay);
    RestartDelay(IN := FALSE, PT := T#1000ms);
    DeadTime(IN := FALSE);
    DeadTimePending := FALSE;
    DeadTimeElapsed := T#0ms;
    // 🔒 Transitoires §3bis neutralisés à la gate (latches de sûreté conservés ci-dessous).
    SenseHoldActive := FALSE; SenseHoldDone := FALSE;
    SenseHoldTimer(IN := FALSE); SenseHoldFeedbackTimer(IN := FALSE);
    SenseHoldElapsed := T#0ms;
    ContactorStuck := ContactorStuckLatched;
    ReleaseOrderActive := FALSE; ReleaseOrderDone := FALSE;
    ReleaseOrderTimer(IN := FALSE, PT := ReleaseOrderDelay);
    ReleaseOrderElapsed := T#0ms;
    RelayFwd := FALSE; RelayRev := FALSE;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    BrakeCmd := FALSE; AuthorizedStep := 0;
    BrakeTimeoutElapsed := T#0ms; RestartDelayElapsed := T#0ms; StepDelayElapsed := T#0ms;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    Error := (ErrorId <> 16#0000);
    State := E_WinchFinalInterlockState.DISABLED;
    RestartRequired := TRUE;
    MovementInhibited := TRUE;   // FB neutralise -> aucun mouvement possible, disponibilite retiree
    // 🔒 Sorties de diagnostic et latches de sûreté VOLONTAIREMENT conservés hors Enable (AC3 / §9) :
    // - ErrorId & RestartInhibit : latches défaut et anti-redémarrage auto (doivent survivre à la perte d'Enable, acquittement conscient requis)
    // - StateAtError & Reason : snapshot d'état et cause de blocage préservés pour diagnostic IHM
    RETURN;
END_IF;

RequestedStepClamped := LIMIT(0, RequestedStep, 5);
// 🛡️ SafeStop : coupure dure à la barrière finale (défense en profondeur).
// SafeStop est consommé en §5 : quand TRUE, RelayFwd/Rev, contacteurs et frein
// sont coupés indépendamment de FB_Winch. Enable reste actif (≠ neutralisation) ;
// SafeStop n'est pas un défaut (pas de FAULT, pas de latch, pas de Reset requis).
MotorRequest := (RequestedStepClamped > 0) AND (RequestedRelayFwd XOR RequestedRelayRev);
// Defense en profondeur : le meme permis directionnel que celui applique en amont
// doit encore autoriser la sortie finale. Aucun latch ni defaut n'est cree ici :
// la demande est simplement neutralisee tant que le permis est FALSE.
PermitFinalBlocked := (RequestedRelayFwd AND NOT AscentPermit)
                   OR (RequestedRelayRev AND NOT DescendPermit);

// ── 2bis. Arbitrage Error/ErrorId AVANT §3/§5 ────────────────────────────
// ErrorId bit0 (défaut frein) est mis à jour en FIN de scan (§6bis, après BrakeCmd) —
// la valeur lue ici est donc celle de la fin du scan PRÉCÉDENT (retard d'un scan sur une
// nouvelle occurrence, ~10ms, négligeable face au budget 500ms du watchdog). Voir bandeau.
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

// ── 3. Réarmement anti-redémarrage automatique ──────────────────────────
// Après timeout : cause disparue + front Reset, puis demande moteur à zéro,
// puis nouvelle demande distincte. La retombée + T#1000ms sera ensuite refaite.
IF RestartInhibit AND NOT Error AND NOT ResetRequired AND NOT ResetEdge.Q THEN
    IF NOT MotorRequest THEN
        NeutralRequestSeen := TRUE;
        RestartRequired := TRUE;
    ELSIF NeutralRequestSeen AND MotorRequest THEN
        RestartInhibit := FALSE;
        NeutralRequestSeen := FALSE;
        RestartRequired := TRUE;
        Reason := E_WinchFinalInterlockReason.NONE;
    END_IF;
END_IF;

// ── 4. Mémorisation de l'arrêt : temporisation d'anti-redémarrage chaud ──────────
// La temporisation RestartDelay (1500ms) s'arme à l'arrêt du mouvement (NOT MotorRequest) et
// s'écoule pendant la pause à l'arrêt (au lieu de repartir de zéro à chaque nouvel appui) —
// permet un redémarrage instantané si la pause dépasse 1.5s. Le décompte ne démarre/continue que
// si le moteur n'est plus demandé ET que le frein est physiquement confirmé fermé
// (NOT BrakeFeedback = bobine retombée, mâchoires serrées). Garde le comportement "purge pendant
// la pause" (RestartRequired ne s'arme qu'à NOT MotorRequest, indépendant de la tempo).
IF NOT MotorRequest THEN
    RestartRequired := TRUE;
END_IF;
RestartDelay(IN := RestartRequired AND NOT MotorRequest AND NOT BrakeFeedback AND NOT RestartInhibit, PT := T#1500ms);
RestartDelayElapsed := RestartDelay.ET;
IF RestartDelay.Q THEN
    RestartRequired := FALSE;
END_IF;

// ── 4bis. Temps mort directionnel (TC-P10-021/022) ─────────────────────────────
// Distinct du RestartDelay (anti-court-cycle uniforme) : temps mort de redémarrage
// après arrêt, dépendant du sens de la nouvelle demande. Même sens → DeadTimeSameDir ;
// inversion → DeadTimeOppositeDir. Neutre↔sens = immédiat (pas de temps mort à l'armement).
// Le décompte se fait pendant la pause ET pendant l'attente après nouvelle demande
// (purge pendant la pause, comme RestartDelay). PT = DeadTimeOppositeDir (le plus long) ;
// à la nouvelle demande, on vérifie si le temps mort requis pour le sens réel est déjà
// écoulé (cas même sens, plus court).
IF MotorRequest THEN
    IF RequestedRelayFwd THEN
        LastDirection := 1;
    ELSE
        LastDirection := -1;
    END_IF;
END_IF;

IF NOT MotorRequest THEN
    DeadTimePending := TRUE;
END_IF;

DeadTime(IN := DeadTimePending AND NOT BrakeFeedback AND NOT RestartInhibit, PT := DeadTimeOppositeDir);
DeadTimeElapsed := DeadTime.ET;
IF DeadTime.Q THEN
    DeadTimePending := FALSE;
END_IF;

IF MotorRequest AND DeadTimePending THEN
    IF RequestedRelayFwd THEN
        NewDirection := 1;
    ELSE
        NewDirection := -1;
    END_IF;
    IF NewDirection = LastDirection THEN
        RequiredDeadTime := DeadTimeSameDir;
    ELSE
        RequiredDeadTime := DeadTimeOppositeDir;
    END_IF;
    IF DeadTime.ET >= RequiredDeadTime THEN
        DeadTimePending := FALSE;
    END_IF;
END_IF;

// ── 4ter. Maintien borné du contacteur de sens (§3bis) — AC6/AC7/AC8 ─────────
// Règle §3bis : quand RequestedStep retombe à 0 mais RequestedRelayFwd/Rev reste
// TRUE (demande transitoire de chute de palier portée par FB_Winch), la barrière NE
// force PLUS RelayFwd/Rev à FALSE immédiatement — elle TIENT le contacteur de sens
// (jamais relâché avant les contacteurs de vitesse) jusqu'à :
//   - FwdRevSpeedFeedbackOff confirmé, debounced par DropConfirmDelay (AC7 : pas
//     d'ouverture du sens sur retour simple voie seul) ; OU
//   - T_max (MaxSenseHoldTime) écoulé -> chute du sens FORCÉE + latch ContactorStuck.
// Le maintien indéfini du stator sous tension est INTERDIT (AC7). Les coupures dures
// (NOT Enable / PowerContactorEngaged=FALSE / Error / RestartInhibit) ne passent
// JAMAIS par ce maintien (AC9) : elles coupent RelayFwd/Rev immédiatement.
SenseHoldRequested := (RequestedStepClamped = 0) AND (RequestedRelayFwd OR RequestedRelayRev)
                      AND NOT Error AND NOT RestartInhibit AND NOT ContactorStuckLatched;

IF NOT Enable OR NOT PowerContactorEngaged THEN
    // 🔒 Gate dur : pas de maintien possible (les sorties sont déjà coupées §2).
    SenseHoldActive := FALSE; SenseHoldDone := FALSE;
    SenseHoldTimer(IN := FALSE, PT := MaxSenseHoldTime);
    SenseHoldFeedbackTimer(IN := FALSE, PT := DropConfirmDelay);
ELSIF Error OR RestartInhibit THEN
    // Coupure par défaut : le maintien ne survit pas à un défaut (AC9).
    SenseHoldActive := FALSE; SenseHoldDone := FALSE;
    SenseHoldTimer(IN := FALSE); SenseHoldFeedbackTimer(IN := FALSE);
ELSE
    IF MotorRequest THEN
        SenseHoldDone := FALSE;
        SenseHoldActive := FALSE;               // vraie nouvelle demande interrompt le maintien transitoire
    END_IF;
    IF NOT (RequestedRelayFwd OR RequestedRelayRev) THEN
        SenseHoldDone := FALSE;
        SenseHoldActive := FALSE;               // retour au neutre complet : plus rien a tenir
    END_IF;
    IF SenseHoldRequested AND NOT SenseHoldActive AND NOT SenseHoldDone THEN
        SenseHoldActive := TRUE;              // entrée en maintien §3bis
        SenseHoldTimer(IN := FALSE, PT := MaxSenseHoldTime);        // T_max arme au scan suivant
        SenseHoldFeedbackTimer(IN := FALSE, PT := DropConfirmDelay);
    ELSIF SenseHoldActive THEN
        SenseHoldFeedbackTimer(IN := FwdRevSpeedFeedbackOff, PT := DropConfirmDelay);
        SenseHoldTimer(IN := NOT FwdRevSpeedFeedbackOff, PT := MaxSenseHoldTime);
        IF SenseHoldFeedbackTimer.Q THEN
            // Retombée contacteurs CONFIRMÉE -> chute normale du sens (one-shot).
            SenseHoldActive := FALSE; SenseHoldDone := TRUE;
        ELSIF SenseHoldTimer.Q THEN
            // T_max sans confirmation -> chute du sens FORCÉE + latch à acquitter (AC7).
            SenseHoldActive := FALSE;
            ContactorStuckLatched := TRUE;
        END_IF;
    ELSE
        SenseHoldTimer(IN := FALSE); SenseHoldFeedbackTimer(IN := FALSE);
    END_IF;
END_IF;
SenseHoldElapsed := SenseHoldTimer.ET;
ContactorStuck := ContactorStuckLatched;

// ── 4quater. Ordre de relâchement contacteurs (vitesse avant direction) ──
// Quand le mouvement s'arrête (NOT MotorRequest ou SafeStop), les contacteurs
// de VITESSE (Contactor1-4) sont relâchés immédiatement, puis le contacteur de
// DIRECTION (RelayFwd/Rev) après ReleaseOrderDelay (>= 100ms). Protège le moteur :
// on ne coupe jamais la direction pendant que la vitesse est encore engagée.
// Les coupures dures (NOT Enable / PowerContactorEngaged / Error / RestartInhibit)
// restent immédiates (AC9) — l'ordre ne s'applique qu'à l'arrêt commandé.
// Le maintien transitoire §3bis (SenseHold) garde la priorité : quand il est actif,
// c'est lui qui tient la direction (jusqu'à confirmation retombée), pas cet ordre.
IF MotorRequest AND NOT SafeStop THEN
    // Nouvelle demande de mouvement : l'ordre de relâchement est réarmé.
    ReleaseOrderActive := FALSE;
    ReleaseOrderDone := FALSE;
    ReleaseOrderTimer(IN := FALSE, PT := ReleaseOrderDelay);
ELSIF (NOT MotorRequest OR SafeStop) AND NOT ReleaseOrderActive AND NOT ReleaseOrderDone
      AND (RequestedRelayFwd OR RequestedRelayRev) AND NOT SenseHoldActive THEN
    // Arrêt commandé : entrée en ordre de relâchement (vitesse relâchée, direction tenue).
    ReleaseOrderActive := TRUE;
END_IF;

// ── 5. Autorisation moteur ────────────────────────────────────────────────
RelayFwd := FALSE; RelayRev := FALSE;
Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
Busy := FALSE; Done := FALSE; Ready := NOT Error AND NOT ContactorStuckLatched;

IF Error THEN
    StepDelay(IN := FALSE, PT := CST_StepRampFloorDelay);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
    AuthorizedStep := 0;
    State := E_WinchFinalInterlockState.FAULT;
ELSIF RestartInhibit THEN
    StepDelay(IN := FALSE, PT := CST_StepRampFloorDelay);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
    AuthorizedStep := 0;
    Reason := E_WinchFinalInterlockReason.RESTART_INHIBITED;
    State := E_WinchFinalInterlockState.FAULT;
ELSIF ContactorStuckLatched THEN
    // AC7 : T_max §3bis dépassé sans confirmation retombée -> chute du sens FORCÉE.
    // RelayFwd/Rev et BrakeCmd (= RelayFwd OR RelayRev) retombent à FALSE ci-dessus.
    // Latch à acquittement conscient (ResetEdge) — jamais de redémarrage auto.
    StepDelay(IN := FALSE, PT := CST_StepRampFloorDelay);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
    AuthorizedStep := 0;
    Reason := E_WinchFinalInterlockReason.SENSE_DROP_TIMEOUT;
    State := E_WinchFinalInterlockState.FAULT;
ELSIF ReleaseOrderActive AND NOT PermitFinalBlocked THEN
    // Ordre de relâchement : vitesse relâchée immédiatement, direction tenue
    // jusqu'à ReleaseOrderDelay, puis direction relâchée (AC1/AC2).
    StepDelay(IN := FALSE, PT := CST_StepRampFloorDelay);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
    AuthorizedStep := 0;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    IF RequestedRelayFwd THEN RelayFwd := TRUE; END_IF;
    IF RequestedRelayRev THEN RelayRev := TRUE; END_IF;
    ReleaseOrderTimer(IN := TRUE, PT := ReleaseOrderDelay);
    ReleaseOrderElapsed := ReleaseOrderTimer.ET;
    IF ReleaseOrderTimer.Q THEN
        ReleaseOrderActive := FALSE;
        ReleaseOrderDone := TRUE;
        RelayFwd := FALSE; RelayRev := FALSE;
    END_IF;
    State := E_WinchFinalInterlockState.READY;
    Busy := TRUE;
ELSIF SafeStop OR PermitFinalBlocked THEN
    // 🛡️ SafeStop ou permis directionnel refusé : coupure dure indépendante de FB_Winch.
    // SafeStop n'est PAS un défaut : pas de FAULT, pas de latch, pas de Reset requis.
    // Les sorties sont coupées tant que l'une des causes est TRUE ; retour nominal dès sa retombée.
    // BrakeCmd (= RelayFwd OR RelayRev, §6) retombe à FALSE automatiquement.
    StepDelay(IN := FALSE, PT := CST_StepRampFloorDelay);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
    AuthorizedStep := 0;
    RelayFwd := FALSE; RelayRev := FALSE;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    State := E_WinchFinalInterlockState.READY;
ELSIF SenseHoldActive THEN
    // §3bis : RequestedStep retombé à 0 mais sens encore commandé -> on TIENT le
    // contacteur de sens jusqu'à FwdRevSpeedFeedbackOff (debounced DropConfirmDelay)
    // OU T_max. AuthorizedStep=0 (aucun contacteur de vitesse), seul le sens est tenu.
    StepDelay(IN := FALSE, PT := CST_StepRampFloorDelay);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
    AuthorizedStep := 0;
    IF RequestedRelayFwd THEN RelayFwd := TRUE; END_IF;
    IF RequestedRelayRev THEN RelayRev := TRUE; END_IF;
    State := E_WinchFinalInterlockState.WAIT_SENSE_DROP_CONFIRM;
    Busy := TRUE;
ELSIF NOT MotorRequest THEN
    // Toute annulation de demande annule la temporisation de hausse en cours.
    StepDelay(IN := FALSE, PT := CST_StepRampFloorDelay);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
    AuthorizedStep := 0;
    State := E_WinchFinalInterlockState.READY;
ELSIF RestartRequired OR DeadTimePending THEN
    StepDelay(IN := FALSE, PT := CST_StepRampFloorDelay);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
    AuthorizedStep := 0;
    State := E_WinchFinalInterlockState.WAIT_RESTART_DELAY;
    Busy := TRUE;
ELSE
    // ⚡ Progression de palier : la cadence NOMINALE est faite par le métier
    // (FB_WinchStepShaper). La barrière finale ajoute un PLANCHER DUR indépendant :
    // AuthorizedStep ne monte jamais de plus de +1 cran / CST_StepRampFloorDelay,
    // quelle que soit la consigne amont. Descente immédiate. 1er cran immédiat
    // (frein + sens). Si le shaper déraille (rampe à 0 -> palier 5 instantané),
    // l'interlock ramène quand même la montée en crans (défense en profondeur).
    // NOT StepDelay.Q : un TON garde .Q TRUE tant que IN est TRUE (pas d'impulsion).
    // Sans ce terme, une fois PT ecoule le +1 ci-dessous s'appliquerait a CHAQUE scan
    // (1 -> 5 en quelques scans, contacteurs relaches d'un coup). Ici le timer se re-arme
    // apres chaque cran -> les contacteurs de vitesse s'enclenchent EN CASCADE, 1 / PT.
    StepDelay(IN := (RequestedStepClamped > AuthorizedStep) AND (AuthorizedStep > 0) AND NOT StepDelay.Q,
              PT := CST_StepRampFloorDelay);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := RequestedStepClamped;

    IF RequestedStepClamped = 0 THEN
        AuthorizedStep := 0;
    ELSIF RequestedStepClamped < AuthorizedStep THEN
        AuthorizedStep := RequestedStepClamped;        // descente : immédiate
    ELSIF AuthorizedStep = 0 THEN
        AuthorizedStep := 1;                           // 1er cran immédiat
    ELSIF StepDelay.Q THEN
        AuthorizedStep := AuthorizedStep + 1;          // +1 cran par CST_StepRampFloorDelay
    END_IF;

    IF (AuthorizedStep > 0) OR (RequestedStepClamped > 0) THEN
        RelayFwd := RequestedRelayFwd;
        RelayRev := RequestedRelayRev;
        // Contacteurs de vitesse MASQUÉS par AuthorizedStep (table cumulative :
        // P1={} P2={K1} P3={K1,K2} P4={K1,K2,K3} P5={K1,K2,K3,K4}). La barrière ne
        // laisse jamais fermer plus de contacteurs que son propre palier autorisé.
        Contactor1 := RequestedContactor1 AND (AuthorizedStep >= 2);
        Contactor2 := RequestedContactor2 AND (AuthorizedStep >= 3);
        Contactor3 := RequestedContactor3 AND (AuthorizedStep >= 4);
        Contactor4 := RequestedContactor4 AND (AuthorizedStep >= 5);
    END_IF;

    IF NOT BrakeFeedback THEN
        State := E_WinchFinalInterlockState.WAIT_BRAKE_COMMAND_CONFIRMATION;
        Busy := TRUE;
    ELSE
        State := E_WinchFinalInterlockState.READY;
    END_IF;
END_IF;

// ── 6. Commande frein — couplage direct ────────────────────────────────
// BrakeCmd suit STRUCTURELLEMENT RelayFwd/RelayRev, calculé APRÈS leur
// finalisation ci-dessus (§5) : il hérite donc automatiquement de toutes leurs
// conditions de sécurité (Error, RestartInhibit, RestartRequired, MotorRequest)
// sans avoir à les répéter. Aucun risque d'écart frein/mouvement possible : le
// frein ne PEUT pas être commandé ouvert sans qu'un des deux relais de sens le
// soit aussi, puisque c'est la même expression. PRG_06_Outputs recalcule la
// MÊME expression indépendamment sur les DQ finaux (M1RelayFwd OR M1RelayRev)
// pour piloter physiquement la bobine — ce BrakeCmd ici sert de miroir/diagnostic
// (State, IHM) mais n'est plus câblé sur la sortie physique (voir PRG_06 §2).
BrakeCmd := RelayFwd OR RelayRev;

// ── 6bis. Watchdog frein : uniquement sur la commande RÉELLEMENT FINALE ────
// Watchdog armé sur BrakeCmd (fin §5/§6), JAMAIS sur RequestedRelayFwd/Rev (demande amont pas
// encore autorisée par le state-machine §5 — RestartRequired peut la retenir jusqu'à T#1000ms,
// largement > le seuil 500ms ci-dessous, ce qui déclencherait un faux défaut à chaque redémarrage
// normal).
BrakeTimeout(IN := BrakeCmd AND NOT BrakeFeedback AND NOT RestartInhibit, PT := T#500ms);
BrakeTimeoutElapsed := BrakeTimeout.ET;
IF BrakeTimeout.Q THEN
    BrakeTimeoutCause := TRUE;
ELSIF BrakeFeedback THEN
    BrakeTimeoutCause := FALSE;   // cause réellement disparue (retour desserrage confirmé)
END_IF;
BrakeTimeoutCauseEdge(CLK := BrakeTimeoutCause);
IF BrakeTimeoutCauseEdge.Q THEN
    BrakeTimeoutAck := FALSE;    // nouvelle occurrence -> ré-alarme, ack remis à zéro
    RestartInhibit := TRUE;
    ResetRequired := TRUE;
    NeutralRequestSeen := FALSE;
    RestartRequired := TRUE;
    Reason := E_WinchFinalInterlockReason.BRAKE_COMMAND_NOT_CONFIRMED;
END_IF;
IF ResetEdge.Q THEN
    BrakeTimeoutAck := TRUE;     // toujours effectif, sans condition externe
    ResetRequired := FALSE;
    ContactorStuckLatched := FALSE;   // acquittement conscient du latch T_max §3bis (AC7)
END_IF;
IF BrakeTimeoutCause OR NOT BrakeTimeoutAck THEN
    ErrorId := ErrorId OR 16#0001;
ELSE
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// ── 6bis2. Publication Fault transverse (socle FB_FaultCore) ──────────────
// 🧩 Homogénéisation interface (AF-03 §3) : le défaut est exposé sous la forme
// standard Fault:ST_Fault (comme FB_TranslationOutputInterlock) au lieu du plat
// Error/ErrorId. La cause unique bit0 = timeout frein, strictement identique à la
// gate interne (ErrorId) ; Latching reproduit le latch existant restitué au front
// Reset (jamais de re-armement auto). La gate interne (Error/ErrorId) reste
// inchangée — la publication n'ajoute ni ne modifie aucune coupure.
instCauses[0].Active   := ((ErrorId AND 16#0001) <> 16#0000);
instCauses[0].Latching := TRUE;
instCauses[0].Texte    := 'Timeout confirmation ouverture frein treuil';
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;

// ── 6ter. Synchronisation defaut frein en fin de scan (TC-P10-012/013/020) ──
// ErrorId bit0 (defaut frein) est pose en §6bis, APRES la machine d'etat §5.
// Sans ce bloc, la synthese Error et l'etat FAULT accusaient un retard d'un scan
// (~10 ms) sur le watchdog frein. On resynchronise Error/State et on coupe les
// sorties le MEME scan que l'apparition du defaut : c'est un defaut FINAL, coupure
// immediate (jamais un maintien ordonne §3bis).
Error := (ErrorId <> 16#0000);
IF Error THEN
    RelayFwd := FALSE; RelayRev := FALSE;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    BrakeCmd := FALSE;
    AuthorizedStep := 0;
    Busy := FALSE; Done := FALSE; Ready := FALSE;
    State := E_WinchFinalInterlockState.FAULT;
END_IF;

// ── 6quater. Disponibilite mouvement ──
// TRUE tant que l'etat autoritaire du FB interdit REELLEMENT une nouvelle demande
// de mouvement ce scan : WAIT_RESTART_DELAY (anti-court-cycle RestartDelay 1,5 s
// + temps mort directionnel, RestartDelayElapsed s'ecoule dans cet etat) ou FAULT,
// plus les latches RestartInhibit / ContactorStuck et le FB non pret. L'etat se
// purge seul des le retour au neutre 1,5 s. WAIT_STEP_DELAY EXCLU : il bride la
// hausse de palier, il n'interdit pas de partir. Aucune coupure ajoutee : signal
// de disponibilite uniquement (consomme par la dispo d'armement PRG_04).
MovementInhibited := NOT Ready
                     OR RestartInhibit
                     OR ContactorStuck
                     OR (State = E_WinchFinalInterlockState.WAIT_RESTART_DELAY)
                     OR (State = E_WinchFinalInterlockState.FAULT);
