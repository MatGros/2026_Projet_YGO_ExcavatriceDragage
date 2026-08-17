(* ═══════════════════════════════════════════════════════════════
   🛡️ FB_WinchOutputInterlock_LD — Barrière finale frein / puissance M1 ou M2
   ───────────────────────────────────────────────────────────────
   📥 Commandes métier déjà calculées par FB_Winch.
   📤 Producteur unique des commandes finales vers PRG_06_Outputs_LD.
   🔒 Le retour (`BrakeFeedback`) confirme le contacteur/bobine de desserrage ;
      il ne mesure pas mécaniquement le frein.
   ⏱️ Watchdog fixe 500 ms après demande effective de desserrage.
   🔧 REX 2026-08-05 : Reset du watchdog frein reconstruit en pattern Cause/Ack
      (CODE_QUALITY_STANDARDS §9) — plus jamais conditionné par un état externe
      instantané (audit sécurité M3, même classe que l'incident EmergencyArmingFailed).
   🆕 REX 2026-08-06 (retrait FB_Brake, demande client) : plus de séquence temporisée
      frein — le frein n'est plus qu'un consommateur direct de RelayFwd/RelayRev
      (`BrakeCmd := RelayFwd OR RelayRev`, câblé au grand jour dans PRG_06_Outputs_LD
      à partir des DQ RelayFwd/RelayRev). Aucun risque d'écart frein/mouvement : le
      frein SUIT structurellement le contacteur de sens, il ne peut jamais en diverger
      puisque c'est la MÊME variable qui pilote les deux. `FB_Brake` reste utilisé tel
      quel pour Translation (M3) — non touché par ce lot.
   🔧 REX 2026-08-06bis (review croisée Codex) : le watchdog frein a d'abord été armé sur
      `RequestedRelayFwd OR RequestedRelayRev` (demande BRUTE, disponible tôt dans le scan)
      — bug réel trouvé : cette demande brute passe à TRUE dès l'appui joystick, alors que
      `RelayFwd`/`RelayRev` FINAUX (§5) restent à FALSE jusqu'à T#1000ms (retombée +
      `RestartDelay`, voir §4). Le watchdog (seuil 500ms) se déclenchait donc À TORT sur
      quasiment CHAQUE redémarrage normal. Corrigé : le watchdog est désormais armé sur
      `BrakeCmd` (§6, calculé APRÈS §5 — la valeur réellement et définitivement commandée),
      jamais sur une demande amont non encore autorisée. Conséquence acceptée : le bit0
      `ErrorId` (et donc `Error`) n'est mis à jour qu'après le calcul de `BrakeCmd`, donc lu
      par §3/§5 avec un retard d'UN scan (~10ms) sur une nouvelle occurrence de défaut —
      négligeable face au budget 500ms du watchdog, et strictement nécessaire pour éviter
      les faux déclenchements.
   🔴🔧 REX 2026-08-07 — RestartDelay COMPTAIT SANS ATTENDRE LE FREIN PHYSIQUE (audit croisé,
      demande client) : un lot précédent avait fait démarrer le décompte 1500ms sur `NOT
      MotorRequest` seul (relâchement joystick, instantané), perdant la dépendance à
      `BrakeFeedback` (retombée physique bobine/mâchoires, ~200-300ms mécaniques après la
      commande). Un redémarrage pouvait donc être autorisé alors que le frein n'était pas
      encore réellement fermé au moment où le décompte a commencé. Corrigé (§4) :
      `NOT BrakeFeedback` réintégré en ET avec `NOT MotorRequest` — le décompte ne
      démarre/continue que si les deux conditions (moteur non demandé ET frein physiquement
      fermé) sont vraies. Comportement "purge pendant la pause" conservé.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_WinchOutputInterlock_LD
VAR_INPUT
    Enable                       : BOOL;
    Reset                        : BOOL;
    PowerContactorEngaged              : BOOL;
    SafeStop                     : BOOL; // 🔧 REX 2026-08-05 (audit sécurité) : volontairement non lu ci-dessous —
                                          // SafeStop est une rampe rapide gérée en amont par FB_Winch
                                          // (Enable maintenu, AGENTS.md "SafeStop = rampe rapide"). Cette barrière
                                          // ne coupe qu'après la retombée effective de la demande à zéro, sauf
                                          // gate dur/timeout/défaut final (§5) — couper ici immédiatement sur
                                          // SafeStop dupliquerait la rampe en un arrêt brutal, contraire au
                                          // comportement spécifié. Entrée conservée pour interface standard
                                          // complète (AF_Partie-03 §1bis), pas un oubli.
    BrakeFeedback                : BOOL; // 🆕 2026-08-06 : retour PHYSIQUE brut du contacteur/bobine frein
                                          // (PRG_02_Acquisition.HwIn.Winch.Mx_BrakeIsOpen_DI), câblé DIRECTEMENT
                                          // depuis PRG_04 — remplace BrakeReleaseRequest/BrakeCommandOpenConfirmed
                                          // (FB_Brake retiré du treuil, voir bandeau). TRUE = frein ouvert/relâché.
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
    BrakeCmd                     : BOOL; // 🆕 2026-08-06 : dérivé UNIQUEMENT de RelayFwd OR RelayRev (fin §5) —
                                          // plus de FB_Brake, plus de gate ContactorEngaged/anti-retombée séparée.
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
    // 🔧 REX 2026-08-05 : pattern Cause/Ack (CODE_QUALITY_STANDARDS §9) — voir §6bis ci-dessous
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
    RestartDelay(IN := FALSE, PT := T#1000ms);
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
// 🆕 2026-08-07 (retour terrain) : la temporisation RestartDelay (1500ms) s'arme à
// l'arrêt du mouvement (NOT MotorRequest) et s'écoule pendant la pause à l'arrêt (au lieu
// de repartir de zéro à chaque nouvel appui) — permet un redémarrage instantané si la pause
// dépasse 1.5s.
// 🔧 REX 2026-08-07 (2) (audit croisé, demande client "sécuriser avec l'info frein") : la
// version ci-dessus comptait dès `NOT MotorRequest` (relâchement joystick, INSTANTANÉ) sans
// attendre la retombée PHYSIQUE du frein (`NOT BrakeFeedback` = bobine retombée, mâchoires
// serrées — ~200-300ms mécaniques après la commande). Un nouveau départ pouvait donc être
// autorisé après 1500ms décomptés dès le relâchement, alors que le frein n'était même pas
// encore complètement fermé au début du décompte — la protection perdait son sens (protéger
// le moteur/frein d'un réengagement trop rapide après un arrêt RÉELLEMENT confirmé). Corrigé :
// `NOT BrakeFeedback` réintégré en ET — le décompte ne démarre/continue que si le moteur n'est
// plus demandé ET que le frein est physiquement confirmé fermé. Garde le comportement "purge
// pendant la pause" (RestartRequired ne s'arme qu'à NOT MotorRequest, indépendant de la tempo).
IF NOT MotorRequest THEN
    RestartRequired := TRUE;
END_IF;
RestartDelay(IN := RestartRequired AND NOT MotorRequest AND NOT BrakeFeedback AND NOT RestartInhibit, PT := T#1500ms);
RestartDelayElapsed := RestartDelay.ET;
IF RestartDelay.Q THEN
    RestartRequired := FALSE;
END_IF;

// ── 5. Autorisation moteur ────────────────────────────────────────────────
RelayFwd := FALSE; RelayRev := FALSE;
Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
Busy := FALSE; Done := FALSE; Ready := NOT Error;

IF Error THEN
    StepDelay(IN := FALSE, PT := T#1s250ms);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
    AuthorizedStep := 0;
    State := E_WinchFinalInterlockState.FAULT;
ELSIF RestartInhibit THEN
    StepDelay(IN := FALSE, PT := T#1s250ms);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
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
ELSIF RestartRequired THEN
    StepDelay(IN := FALSE, PT := T#1s250ms);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
    AuthorizedStep := 0;
    State := E_WinchFinalInterlockState.WAIT_RESTART_DELAY;
    Busy := TRUE;
ELSE
    // ⚡ Progression de palier directe : la temporisation (tempo palier) est gérée
    // par le métier (FB_Winch). La barrière finale transmet directement la consigne
    // sans micro-coupure des contacteurs.
    StepDelay(IN := FALSE, PT := T#1s250ms);
    StepDelayElapsed := StepDelay.ET;
    StepDelayTarget := 0;
    AuthorizedStep := RequestedStepClamped;

    IF (AuthorizedStep > 0) OR (RequestedStepClamped > 0) THEN
        RelayFwd := RequestedRelayFwd;
        RelayRev := RequestedRelayRev;
        Contactor1 := RequestedContactor1;
        Contactor2 := RequestedContactor2;
        Contactor3 := RequestedContactor3;
        Contactor4 := RequestedContactor4;
    END_IF;

    IF NOT BrakeFeedback THEN
        State := E_WinchFinalInterlockState.WAIT_BRAKE_COMMAND_CONFIRMATION;
        Busy := TRUE;
    ELSE
        State := E_WinchFinalInterlockState.READY;
    END_IF;
END_IF;

// ── 6. Commande frein — couplage direct (demande client 2026-08-06) ────────
// 🆕 BrakeCmd suit STRUCTURELLEMENT RelayFwd/RelayRev, calculé APRÈS leur
// finalisation ci-dessus (§5) : il hérite donc automatiquement de toutes leurs
// conditions de sécurité (Error, RestartInhibit, RestartRequired, MotorRequest)
// sans avoir à les répéter. Aucun risque d'écart frein/mouvement possible : le
// frein ne PEUT pas être commandé ouvert sans qu'un des deux relais de sens le
// soit aussi, puisque c'est la même expression. PRG_06_Outputs_LD recalcule la
// MÊME expression indépendamment sur les DQ finaux (M1RelayFwd OR M1RelayRev)
// pour piloter physiquement la bobine — ce BrakeCmd ici sert de miroir/diagnostic
// (State, IHM) mais n'est plus câblé sur la sortie physique (voir PRG_06 §2).
BrakeCmd := RelayFwd OR RelayRev;

// ── 6bis. Watchdog frein : uniquement sur la commande RÉELLEMENT FINALE ────
// 🔧 REX 2026-08-06bis (review croisée) : armé sur BrakeCmd (fin §5/§6), JAMAIS sur
// RequestedRelayFwd/Rev (demande amont pas encore autorisée par le state-machine
// §5 — RestartRequired peut la retenir jusqu'à T#1000ms, largement > le seuil 500ms
// ci-dessous, ce qui déclenchait un faux défaut à quasiment CHAQUE redémarrage normal).
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
END_IF;
IF BrakeTimeoutCause OR NOT BrakeTimeoutAck THEN
    ErrorId := ErrorId OR 16#0001;
ELSE
    ErrorId := ErrorId AND 16#FFFE;
END_IF;
