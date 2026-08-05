(* ═══════════════════════════════════════════════════════════════
   🛡️ FB_WinchOutputInterlock_LD — Barrière finale frein / puissance M1 ou M2
   ───────────────────────────────────────────────────────────────
   📥 Commandes métier déjà calculées par FB_Winch.
   📤 Producteur unique des commandes finales vers PRG_10_Outputs_LD.
   🔒 Le retour confirme le contacteur/bobine de desserrage ; il ne mesure
      pas mécaniquement le frein. Pré-magnétisation : FB_Brake uniquement.
   ⏱️ Watchdog fixe 500 ms après demande effective de desserrage.
   🔧 REX 2026-08-05 : Reset du watchdog frein reconstruit en pattern Cause/Ack
      (CODE_QUALITY_STANDARDS §9) — plus jamais conditionné par un état externe
      instantané (audit sécurité M3, même classe que l'incident EmergencyArmingFailed).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_WinchOutputInterlock_LD
VAR_INPUT
    Enable                       : BOOL;
    Reset                        : BOOL;
    PowerContactorEngaged              : BOOL;
    SafeStop                     : BOOL;
    BrakeReleaseRequest          : BOOL;
    BrakeCommandOpenConfirmed    : BOOL;
    FwdRevSpeedFeedbackOff       : BOOL;
    RequestedRelayFwd            : BOOL;
    RequestedRelayRev            : BOOL;
    RequestedContactor1          : BOOL; // Mapping métier FB_Winch / SpeedStepTable
    RequestedContactor2          : BOOL; // Mapping métier FB_Winch / SpeedStepTable
    RequestedContactor3          : BOOL; // Mapping métier FB_Winch / SpeedStepTable
    RequestedContactor4          : BOOL; // Mapping métier FB_Winch / SpeedStepTable
    RequestedStep                : INT;
END_VAR
VAR_OUTPUT
    Ready                        : BOOL;
    Busy                         : BOOL;
    Done                         : BOOL;
    Error                        : BOOL;
    ErrorId                      : WORD; // bit0 : absence confirmation contacteur desserrage > 500 ms
    State                        : E_WinchFinalInterlockState;
    StateAtError                 : E_WinchFinalInterlockState;
    Reason                       : E_WinchFinalInterlockReason;
    AuthorizedStep               : INT;
    RelayFwd                     : BOOL;
    RelayRev                     : BOOL;
    Contactor1                   : BOOL;
    Contactor2                   : BOOL;
    Contactor3                   : BOOL;
    Contactor4                   : BOOL;
    BrakeCmd                     : BOOL;
    BrakeTimeoutElapsed          : TIME;
    RestartInhibit               : BOOL; // TRUE : timeout acquitté mais neutre/nouvelle demande exigés
    RestartDelayElapsed          : TIME;
    StepDelayElapsed             : TIME;
END_VAR
VAR
    ResetEdge                    : R_TRIG;
    ErrorEdge                    : R_TRIG;
    BrakeTimeout                 : TON;
    StepDelay                    : TON;
    RestartDelay                 : TON;
    RestartRequired              : BOOL;
    ResetRequired                : BOOL; // Timeout : front Reset conscient obligatoire
    NeutralRequestSeen           : BOOL; // Demande moteur zéro observée après acquittement
    RequestedStepClamped         : INT;
    StepDelayTarget              : INT;  // Cible mémorisée : tout changement annule le temps en cours
    MotorRequest                 : BOOL;
    // 🔧 REX 2026-08-05 : pattern Cause/Ack (CODE_QUALITY_STANDARDS §9) — voir §2 ci-dessous
    BrakeTimeoutCause             : BOOL;
    BrakeTimeoutAck               : BOOL := TRUE;
    BrakeTimeoutCauseEdge         : R_TRIG;
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
    StepDelay(IN := FALSE, PT := T#1s250ms);
    RestartDelay(IN := FALSE, PT := T#900ms);
    RelayFwd := FALSE; RelayRev := FALSE;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    BrakeCmd := FALSE; AuthorizedStep := 0;
    BrakeTimeoutElapsed := T#0ms; RestartDelayElapsed := T#0ms; StepDelayElapsed := T#0ms;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    Error := (ErrorId <> 16#0000);
    State := E_WinchFinalInterlockState.DISABLED;
    RestartRequired := TRUE;
    RETURN;
END_IF;

RequestedStepClamped := LIMIT(0, RequestedStep, 5);
// SafeStop reste une rampe rapide du FB_Winch (Enable maintenu, Partie 3 §1bis).
// La demande métier reste donc autorisée ici pendant la décélération ; l'interlock
// ne coupe qu'après sa retombée effective à zéro, sauf gate dur ou défaut final.
MotorRequest := (RequestedStepClamped > 0) AND (RequestedRelayFwd XOR RequestedRelayRev);

// ── 2. Watchdog final : uniquement après ordre effectif de desserrage ───
// Pendant l'inhibition post-timeout, BrakeCmd reste coupé : aucune nouvelle faute
// en boucle ne peut être créée par une demande métier encore maintenue.
// 🔧 REX 2026-08-05 : pattern Cause/Ack (CODE_QUALITY_STANDARDS §9) — l'ancien
// "ELSIF ResetEdge.Q AND BrakeCommandOpenConfirmed" pouvait perdre silencieusement
// un front Reset si BrakeCommandOpenConfirmed rebondissait à FALSE exactement au
// scan du Reset (même classe que l'incident EmergencyArmingFailed). Le Reset est
// désormais TOUJOURS effectif sur l'acquittement (BrakeTimeoutAck) ; l'interlock de
// sécurité (RestartInhibit, §3) reste basé sur la cause brute (BrakeTimeoutCause /
// Error), jamais sur l'acquittement seul — l'acquittement n'ouvre jamais l'interlock.
BrakeTimeout(IN := BrakeReleaseRequest AND NOT BrakeCommandOpenConfirmed
               AND NOT RestartInhibit, PT := T#500ms);
BrakeTimeoutElapsed := BrakeTimeout.ET;
IF BrakeTimeout.Q THEN
    BrakeTimeoutCause := TRUE;
ELSIF BrakeCommandOpenConfirmed THEN
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
END_IF;
IF BrakeTimeoutCause OR NOT BrakeTimeoutAck THEN
    ErrorId := ErrorId OR 16#0001;
ELSE
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

// ── 3. Réarmement anti-redémarrage automatique ──────────────────────────
// Après timeout : cause disparue + front Reset, puis demande moteur à zéro,
// puis nouvelle demande distincte. La retombée + T#900ms sera ensuite refaite.
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

// Le frein garde la demande métier, y compris durant la rampe SafeStop ;
// FB_Brake le serre uniquement après la retombée effective du mouvement.
BrakeCmd := BrakeReleaseRequest AND NOT Error AND NOT RestartInhibit;

// ── 4. Mémorisation de l'arrêt : le prochain départ attend la retombée + 900 ms ──
IF NOT MotorRequest THEN
    RestartRequired := TRUE;
END_IF;
RestartDelay(IN := RestartRequired AND FwdRevSpeedFeedbackOff AND NOT RestartInhibit, PT := T#900ms);
RestartDelayElapsed := RestartDelay.ET;
IF RestartDelay.Q THEN
    RestartRequired := FALSE;
END_IF;

// ── 5. Autorisation moteur : zéro puissance tant que frein non confirmé ──
RelayFwd := FALSE; RelayRev := FALSE;
Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
Busy := FALSE; Done := FALSE; Ready := NOT Error;

IF Error THEN
    StepDelay(IN := FALSE, PT := T#1s250ms);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
    BrakeCmd := FALSE;
    AuthorizedStep := 0;
    State := E_WinchFinalInterlockState.FAULT;
ELSIF RestartInhibit THEN
    StepDelay(IN := FALSE, PT := T#1s250ms);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
    BrakeCmd := FALSE;
    AuthorizedStep := 0;
    Reason := E_WinchFinalInterlockReason.RESTART_INHIBITED;
    State := E_WinchFinalInterlockState.FAULT;
ELSIF NOT MotorRequest THEN
    // Toute annulation de demande annule la temporisation de hausse en cours.
    StepDelay(IN := FALSE, PT := T#1s250ms);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
    AuthorizedStep := 0;
    State := E_WinchFinalInterlockState.READY;
ELSIF NOT BrakeCommandOpenConfirmed THEN
    StepDelay(IN := FALSE, PT := T#1s250ms);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
    AuthorizedStep := 0;
    State := E_WinchFinalInterlockState.WAIT_BRAKE_COMMAND_CONFIRMATION;
    Busy := TRUE;
ELSIF RestartRequired THEN
    StepDelay(IN := FALSE, PT := T#1s250ms);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
    AuthorizedStep := 0;
    State := E_WinchFinalInterlockState.WAIT_RESTART_DELAY;
    Busy := TRUE;
ELSE
    // Hausses adjacentes seulement ; le délai est le dernier recours derrière le métier.
    IF RequestedStepClamped > AuthorizedStep THEN
        // Toute modification de cible, y compris un abaissement restant supérieur
        // au palier autorisé, invalide le temps déjà accumulé.
        IF StepDelayTarget <> RequestedStepClamped THEN
            StepDelay(IN := FALSE, PT := T#1s250ms);
            StepDelayElapsed := StepDelay.ET;
            StepDelayTarget := RequestedStepClamped;
        ELSE
            StepDelay(IN := TRUE, PT := T#1s250ms);
            StepDelayElapsed := StepDelay.ET;
            IF StepDelay.Q THEN
                AuthorizedStep := AuthorizedStep + 1;
                StepDelayTarget := 0;
                // Conserve T#1s250ms durant ce scan : test/diagnostic de transition exact.
                StepDelayElapsed := StepDelay.ET;
                StepDelay(IN := FALSE, PT := T#1s250ms);
            END_IF;
        END_IF;
        State := E_WinchFinalInterlockState.WAIT_STEP_DELAY;
        Busy := TRUE;
    ELSE
        // Palier identique ou abaissé : aucun temps résiduel ne peut être réutilisé.
        StepDelay(IN := FALSE, PT := T#1s250ms);
        StepDelayElapsed := StepDelay.ET;
        StepDelayTarget := 0;
        AuthorizedStep := RequestedStepClamped;
        State := E_WinchFinalInterlockState.READY;
    END_IF;

    // Le palier autorisé est un contrôle de temporalité, PAS un nouveau mapping.
    // FB_Winch/FB_SpeedStep reste l'unique propriétaire de SpeedStepTable, notamment
    // pour les tables dynamiques M2 Benne. Une hausse inattendue est masquée jusqu'à
    // ce que AuthorizedStep rejoigne exactement la demande ; aucune combinaison C1..C4
    // n'est reconstruite ou synthétisée dans cette frontière finale.
    IF (AuthorizedStep > 0) AND (AuthorizedStep = RequestedStepClamped) THEN
        RelayFwd := RequestedRelayFwd;
        RelayRev := RequestedRelayRev;
        Contactor1 := RequestedContactor1;
        Contactor2 := RequestedContactor2;
        Contactor3 := RequestedContactor3;
        Contactor4 := RequestedContactor4;
    END_IF;
END_IF;
