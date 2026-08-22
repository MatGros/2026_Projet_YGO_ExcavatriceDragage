(* ═══════════════════════════════════════════════════════════════
   ⚙️ FB_Translation — Directeur de l'axe transversal M3 (variateur AC600)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-11_Fonction_Translation_v2.2.md
   🔌 FB DE MOUVEMENT : porte StartStop + SafeStop en plus de l'interface
      standard. Précédence Enable > SafeStop > StartStop.
   Pilotage exclusivement ETHERCAT nominal (mot de commande, consigne fréquence).
   🧩 Compose FB_Brake (réutilisé TEL QUEL depuis COMMUN).
   🎯 Invariant : toute inversion de sens force la cible de rampe à 0.0 tant que le
      changement de sens est en attente, pour garantir le croisement du seuil d'arrêt
      qui autorise l'interlock de changement de sens (§5).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Translation
VAR_INPUT
    Enable                      : BOOL;        // --> [CMD] Active le FB. FALSE = neutralisation totale (sorties coupées)
    Reset                       : BOOL;        // --> [CMD] Acquittement défaut (front)
    PowerContactorEngaged             : BOOL;        // --> [SAFE] Chaîne AU réarmée + conditions globales OK
    Mode                        : E_Mode;      // --> [CMD] Mode courant
    StartStop                   : BOOL;        // --> [CMD] TRUE = rampe accélération, FALSE = rampe décélération NORMALE
    SafeStop                    : BOOL;        // --> [SAFE] Sortie FB_Safety_Translation : TRUE = rampe décélération RAPIDE (Enable maintenu)
    Direction                   : INT;         // --> [CMD] -1 = Rev, 0 = Neutre, +1 = Fwd (source d'autorité du sens)
    SpeedRefPct                 : REAL;        // --> [CMD] Magnitude de la consigne (de 0 à 100%)
    PositionSensorTarget        : BOOL;        // --> [HW] Capteur position cible courante
    // 3 capteurs déclencheurs de ralentissement, un cran avant chaque cible
    // (même principe que PV→Trémie, généralisé — voir §4bis dans le corps ST)
    SlowdownSensorTremie         : BOOL;        // --> [HW] Capteur PV — ralentissement avant Trémie (Direction=1)
    SlowdownSensorMaintenance    : BOOL;        // --> [HW] Capteur P1 — ralentissement avant Maintenance (Direction=-1)
    SlowdownSensorP1             : BOOL;        // --> [HW] Capteur P2 — ralentissement avant P1 (Direction=-1, arrêt propre pour travail)
    LimitSwitchFwd              : BOOL;        // --> [HW] Fin de course extrême avant
    LimitSwitchRev              : BOOL;        // --> [HW] Fin de course extrême arrière

    // 🔌 Spécifique ETHERCAT (image process EtherCAT, rafraîchie par EtherCatTask 4ms)
    DriveStatusWord              : WORD;       // --> [HW] Mot d'état AC600 lu depuis l'image d'entrée EtherCAT
    DriveActualFreqHz            : REAL;       // --> [HW] Fréquence réelle mesurée (Hz)

    BypassContactorCheck         : BOOL;       // --> [TST] TRUE = désactive StuckClosed/StuckOpen pour le frein (simulation)
    BypassLimitSwitch            : BOOL;       // --> [TST] TRUE = ignore les fins de course extrêmes
    BrakeFeedback                : BOOL;       // --> [HW] Retour physique direct : TRUE = frein OUVERT (desserré)
    // Compense le câblage moteur (U/V inversés) — UNIQUEMENT sur le mot de commande variateur
    // en sortie (§5bis). Direction/CommandedDirection reste partout ailleurs le sens SÉMANTIQUE
    // réel (+1 = physiquement vers Trémie), pour rester apparié aux vrais capteurs
    // (LimitSwitchFwd/Rev, SlowdownSensorXxx) quel que soit le câblage.
    InvertDriveDirection          : BOOL;

    // Réglages rampe (RETAIN)
    CfgRampAccelRate                : REAL := 20.0;    // --> [CFG] %/s — accélération
    CfgRampDecelNormalRate          : REAL := 40.0;    // --> [CFG] %/s — décélération normale
    CfgRampDecelFastRate            : REAL := 100.0;   // --> [CFG] %/s — décélération RAPIDE
    DirectionInterlockDelay      : TIME := T#200ms; // --> [CFG] Délai avant d'autoriser un changement de sens à l'arrêt

    // Réglages ETHERCAT uniquement (RETAIN)
    ApproachSpeedTremieHz        : REAL := 10.0;    // --> [CFG] Vitesse réduite d'approche Trémie en Hz (piloté par SlowdownSensorTremie)
    ApproachSpeedMaintenanceHz   : REAL := 10.0;    // --> [CFG] Vitesse réduite d'approche Maintenance en Hz (piloté par SlowdownSensorMaintenance)
    ApproachSpeedP1Hz            : REAL := 10.0;    // --> [CFG] Vitesse réduite d'approche P1 en Hz (piloté par SlowdownSensorP1)
    DriveFreqScaleMaxHz          : REAL := 60.0;    // --> [CFG] Échelle 0..100 % → MaxHz (câblé depuis _TranslationMaxFreq_Hz par PRG_07 — defaut 60.0 si non raccordé)

    // Réglages communs
    CaptorDebounce                : TIME := T#100ms; // --> [CFG] Filtrage capteur de position cible
    BrakeDelayContactClose        : TIME := T#100ms; // --> [CFG] Voir FB_Brake
    BrakeDelayMagnetise           : TIME := T#300ms; // --> [CFG] Voir FB_Brake
    BrakeDelayMotorDecel          : TIME := T#500ms; // --> [CFG] Voir FB_Brake
    BrakeFeedbackTimeout          : TIME := T#300ms; // --> [CFG] Strictement sous watchdog final 500 ms
END_VAR
VAR_OUTPUT
    Ready               : BOOL;   // <-- [STAT] FB prêt (sortie libre, hors ST_FbStatus)
    // 🧩 Statut transverse (forme cible) — regroupe Busy/Done/Error/ErrorId/State/StateAtError.
    // ErrorId bit0: "Défaut frein Translation" ; bit3: "Défaut variateur AC600" ; bit6: "Limite extrême".
    Status              : ST_FbStatus;
    TargetReached        : BOOL;       // <-- [STAT] Capteur position cible
    RequestedDriveControlWord : WORD; // <-- [ACT] Demande métier AC600, arbitrée par FB_TranslationOutputInterlock
    RequestedDriveFreqHz      : REAL; // <-- [ACT] Demande métier fréquence, arbitrée par FB_TranslationOutputInterlock
    BrakeReleaseRequest       : BOOL; // <-- [ACT] Demande métier desserrage, issue de FB_Brake
    BrakeCommandOpenConfirmed : BOOL; // <-- [STAT] TRUE = frein ouvert = commande ouverture confirmée (depuis FB_Brake)
    BrakeContactorCheck  : ST_ContactorCheck; // <-- [DIAG] Diag contacteur frein
END_VAR
VAR
    Brake                : FB_Brake;       // * [INST] Séquence frein
    CycleTimeCalc        : FB_CycleTime;   // * [INST] Mesure temps de cycle
    SpeedRamp             : FB_Ramp;       // * [INST] Rampe de vitesse logicielle (PLC)
    ResetEdge            : R_TRIG;   // . [LOC] Front Reset
    ErrorEdge            : R_TRIG;   // . [LOC] Front Erreur
    DirectionChangeDelay : TON;            // . [LOC] Interlock changement de sens
    CommandedDirection   : INT;            // . [LOC] Sens réellement appliqué
    DirectionChangePending : BOOL;         // . [LOC] Force la rampe à 0 pendant une inversion de sens en attente
    PhysicalDriveDirection : INT;          // . [LOC] CommandedDirection compensé câblage (InvertDriveDirection) — UNIQUEMENT pour le mot de commande variateur, jamais pour l'appariement capteur
    RampTargetPct        : REAL;   // . [LOC] Cible rampe en %
    CaptorDebounceTon     : TON;    // . [LOC] Debounce capteur cible
    ArrivalEdge            : R_TRIG;   // . [LOC] Front arrivée sur capteur
    DirectionAtArrival     : INT;    // . [LOC] Sens d'arrivée mémorisé
    ArrivalLock             : BOOL;        // . [LOC] Arrêt exact sur capteur cible
    MovementRequested      : BOOL;         // . [LOC] Pilote FB_Brake
    FirstScanDone          : BOOL;   // . [LOC] Initialisation premier scan
    // Garde-fou watchdog : DriveActualFreqHz est un passthrough EtherCAT sans contrôle de fraîcheur.
    // Si la communication variateur se fige sur une dernière valeur ≥1.0 Hz, plus rien ne referme
    // le frein tant que ce garde-fou n'existe pas — même si SafeStop a déjà ramené la rampe théorique
    // à 0. Force le relâchement du frein 2s après la fin de la rampe théorique, quoi que dise
    // DriveActualFreqHz.
    TonBrakeRealFreqTimeout : TON;
END_VAR

// === IMPLEMENTATION ===

{region "§1 Gate et initialisation"}
// 🛑 1. GATE (Enable / PowerContactorEngaged) — neutralisation totale, sorties sûres
IF NOT Enable OR NOT PowerContactorEngaged THEN
    RequestedDriveControlWord := 0; RequestedDriveFreqHz := 0.0;

    Brake(Enable := FALSE, Reset := FALSE, MovementRequested := FALSE, ContactorFeedback := BrakeFeedback,
          DelayContactClose := BrakeDelayContactClose, DelayMagnetise := BrakeDelayMagnetise,
          DelayMotorDecel := BrakeDelayMotorDecel, FeedbackTimeout := BrakeFeedbackTimeout);
    BrakeReleaseRequest := Brake.BrakeCmd;
    BrakeCommandOpenConfirmed := Brake.BrakeCommandOpenConfirmed;
    BrakeContactorCheck := Brake.ContactorCheck;

    CommandedDirection := 0;
    DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
    SpeedRamp(Target := 0.0, AccelRate := CfgRampAccelRate, DecelRate := CfgRampDecelFastRate, CycleTimeS := CycleTimeCalc.CycleTimeS);

    ArrivalLock := FALSE;

    Status.State := E_State.DISABLED;
    Ready := FALSE; Status.Busy := FALSE; Status.Done := FALSE;
    RETURN;
END_IF;

// 🧹 Initialisation au premier scan : purge des résidus RAM d'un Online Change / Warm Start et évitement des alarmes transitoires
IF NOT FirstScanDone THEN
    FirstScanDone := TRUE;
    Status.ErrorId := 16#0000;
    RETURN;
END_IF;

{endregion}

{region "§2 Acquisition commandes et position cible"}
Ready := TRUE;
CycleTimeCalc(DefaultValueS := 0.010);   // MainTask = 10 ms

// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 📡 3. CAPTEUR POSITION CIBLE (debounce)
CaptorDebounceTon(IN := PositionSensorTarget, PT := CaptorDebounce);
TargetReached := CaptorDebounceTon.Q;

{endregion}

{region "§4 Consigne vitesse ralentissement verrou arrivee"}
// ⚙️ 4. CORE — arbitrage rampe : Enable > SafeStop > StartStop
// DirectionChangePending FORCE la cible à 0.0 dès qu'une inversion de sens est en attente —
// sans cela, la cible suit la magnitude joystick en continu et ne croise jamais le seuil
// d'arrêt (0.1%) qui autorise l'interlock §5 à basculer CommandedDirection. Une inversion
// plus rapide que la décélération réelle bloquerait indéfiniment le mouvement dans l'ancien sens.
DirectionChangePending := (Direction <> CommandedDirection) AND (CommandedDirection <> 0);

RampTargetPct := 0.0;
IF NOT SafeStop AND StartStop AND NOT DirectionChangePending THEN
    // Si butée fin de course extrême atteinte dans le sens de marche demandé, consigne forcée à 0
    // 🌐 BypassLimitSwitch = TRUE → ignore cette protection
    IF NOT BypassLimitSwitch AND ((Direction = 1 AND LimitSwitchFwd) OR (Direction = -1 AND LimitSwitchRev)) THEN
        RampTargetPct := 0.0;
    ELSE
        RampTargetPct := ABS(SpeedRefPct);
        // 🎚️ Consigne minimale joystick (1.0 Hz) : si un mouvement est demandé (SpeedRefPct > 0.0), la consigne est au moins égale à 1.0 Hz
        IF RampTargetPct > 0.0 THEN
            RampTargetPct := MAX(RampTargetPct, (1.0 / SEL(DriveFreqScaleMaxHz > 0.0, 60.0, DriveFreqScaleMaxHz)) * 100.0);
        END_IF;
    END_IF;
END_IF;

// ⏱️ 4bis. RALENTISSEMENT AUTO À L'APPROCHE (piloté par capteur)
// Chaque capteur "un cran avant" la cible finale déclenche SA propre vitesse réduite, dans SON
// sens de marche uniquement — le ralentissement ne se déclenche qu'à l'approche de sa cible :
//   PV       + Direction=1  → approche Trémie
//   P1       + Direction=-1 → approche Maintenance
//   P2       + Direction=-1 → approche P1 (arrêt propre pour travail)
IF (Direction = 1) AND SlowdownSensorTremie THEN
    RampTargetPct := LIMIT(0.0, RampTargetPct, (ApproachSpeedTremieHz / SEL(DriveFreqScaleMaxHz > 0.0, 60.0, DriveFreqScaleMaxHz)) * 100.0);
END_IF;
IF (Direction = -1) AND SlowdownSensorMaintenance THEN
    RampTargetPct := LIMIT(0.0, RampTargetPct, (ApproachSpeedMaintenanceHz / SEL(DriveFreqScaleMaxHz > 0.0, 60.0, DriveFreqScaleMaxHz)) * 100.0);
END_IF;
IF (Direction = -1) AND SlowdownSensorP1 THEN
    RampTargetPct := LIMIT(0.0, RampTargetPct, (ApproachSpeedP1Hz / SEL(DriveFreqScaleMaxHz > 0.0, 60.0, DriveFreqScaleMaxHz)) * 100.0);
END_IF;

// 🎯 4ter. VERROUILLAGE ANTI-REBONDS SENS EN BUTÉE (Trémie, P1, Maintenance, Fdc extrêmes)
// Dès qu'on touche un capteur d'arrêt (TargetReached, débounce 100ms) OU un fin de course dur
// (LimitSwitchFwd/Rev, §5bis — immédiat, non débounce, mais toute activation même brève arme le
// même verrou), le sens d'arrivée (DirectionAtArrival) est MÉMORISÉ et BLOQUÉ. Toute activation,
// même un instant, arme DirectionAtArrival comme un TargetReached — un Fdc qui s'ouvre quelques ms
// pendant le freinage ne doit pas laisser la rampe (encore haute en interne) revenir en sortie.
ArrivalEdge(CLK := TargetReached
                 OR (LimitSwitchFwd AND (CommandedDirection = 1))
                 OR (LimitSwitchRev AND (CommandedDirection = -1)));
IF ArrivalEdge.Q THEN
    DirectionAtArrival := CommandedDirection;
END_IF;

// Un retour au neutre, même SOUTENU (>100ms), ne doit JAMAIS lever le verrou — seul un vrai
// changement de sens (dégagement volontaire, sans ambiguïté) le fait. Sinon, un neutre 100ms+
// puis un réappui dans le MÊME sens (le capteur/Fdc restant au niveau haut en continu,
// TargetReached ne montre plus de front) contournerait le verrou et M3 repartirait vers la butée.
// On doit repartir dans l'AUTRE sens, jamais juste relâcher-réappuyer pareil. Instantané, jamais
// retardé (le dégagement doit rester rapide).
IF (Direction = DirectionAtArrival * (-1)) OR ResetEdge.Q OR (NOT TargetReached AND NOT LimitSwitchFwd AND NOT LimitSwitchRev) THEN
    DirectionAtArrival := 0;
END_IF;

// Bloque la consigne à 0 tant que l'ordre demande d'insister dans le sens d'arrivée verrouillé
ArrivalLock := (DirectionAtArrival <> 0) AND (Direction = DirectionAtArrival);
IF ArrivalLock THEN
    RampTargetPct := 0.0;
END_IF;

SpeedRamp(Target := RampTargetPct,
          AccelRate := CfgRampAccelRate,
          DecelRate := SEL(SafeStop, CfgRampDecelNormalRate, CfgRampDecelFastRate),
          CycleTimeS := CycleTimeCalc.CycleTimeS);

{endregion}

{region "§5 Interlock changement sens"}
// 🔒 5. INTERLOCK CHANGEMENT DE SENS — jamais Fwd+Rev simultanés (vitesse confirmée nulle)
IF Direction <> CommandedDirection THEN
    IF CommandedDirection = 0 AND Direction <> 0 THEN
        CommandedDirection := Direction;
        DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
    ELSIF ABS(SpeedRamp.Current) < 0.1 THEN
        DirectionChangeDelay(IN := TRUE, PT := DirectionInterlockDelay);
        IF DirectionChangeDelay.Q THEN
            CommandedDirection := Direction;
            DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
        END_IF;
    ELSE
        DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
    END_IF;
ELSE
    DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
END_IF;

{endregion}

{region "§5bis Commande variateur et protections fin course"}
// 🛑 Pilotage du frein : le mouvement est considéré actif tant que la consigne est supérieure à 0.1%
// OU que la fréquence réelle mesurée du variateur M3 est >= 1.0 Hz.
// Le frein de parking ne serre QUE lorsque la fréquence réelle variateur chute sous 1.0 Hz !
// Borné par un garde-fou 2s — DriveActualFreqHz n'a aucun contrôle de fraîcheur EtherCAT ; si la
// communication se fige sur une valeur ≥1.0 Hz (perte réseau en mouvement), rien d'autre en aval
// ne referme le frein (FB_TranslationOutputInterlock ignore volontairement SafeStop par
// conception). Le garde-fou force la fermeture du frein 2s après la fin de la rampe THÉORIQUE, quoi
// que dise la mesure réelle — combine attente réelle (évite un serrage sur arbre encore tournant)
// et certitude de fermeture (n'attend jamais indéfiniment).
TonBrakeRealFreqTimeout(IN := NOT ((CommandedDirection <> 0) AND (ABS(SpeedRamp.Current) > 0.1)), PT := T#2s);
MovementRequested := ((CommandedDirection <> 0) AND (ABS(SpeedRamp.Current) > 0.1))
                     OR (ABS(DriveActualFreqHz) >= 1.0 AND NOT TonBrakeRealFreqTimeout.Q);

// 🔀 5bis. SORTIE PHYSIQUE (ETHERCAT)
RequestedDriveFreqHz := (ABS(SpeedRamp.Current) / 100.0) * DriveFreqScaleMaxHz;

// Compensation câblage moteur appliquée ICI SEULEMENT, sur le mot de commande —
// CommandedDirection (sécurité/capteurs juste au-dessus, §4/§4bis/§4ter) reste le sens réel.
PhysicalDriveDirection := SEL(InvertDriveDirection, CommandedDirection, CommandedDirection * (-1));

// Pilotage nominal Given Command 1 (0x3101) :
// 0: None, 1: Forward, 2: Reverse, 7: Reset
IF Reset THEN
    RequestedDriveControlWord := 7; // Reset défaut variateur
ELSIF Status.Error THEN
    RequestedDriveControlWord := 0; // Arrêt sur défaut
ELSIF MovementRequested THEN
    IF PhysicalDriveDirection = 1 THEN
        RequestedDriveControlWord := 1; // Marche avant
    ELSIF PhysicalDriveDirection = -1 THEN
        RequestedDriveControlWord := 2; // Marche arrière
    ELSE
        RequestedDriveControlWord := 0;
    END_IF;
ELSE
    RequestedDriveControlWord := 0;
END_IF;

// Sécurité : si Fdc extrême atteint dans le sens de marche, coupure commande immédiate (sans rampe ni couple)
// 🌐 BypassLimitSwitch = TRUE → ignore cette protection (test/mise en service)
IF NOT BypassLimitSwitch AND ((CommandedDirection = 1 AND LimitSwitchFwd) OR (CommandedDirection = -1 AND LimitSwitchRev)) THEN
    RequestedDriveControlWord := 0;
    RequestedDriveFreqHz := 0.0;
    SpeedRamp(Target := 0.0, AccelRate := 0.0, DecelRate := 100000.0, CycleTimeS := 1.0);
END_IF;

{endregion}

{region "§6 Commande frein"}
// 🛑 6. FREIN (composé, réutilisé tel quel)
Brake(Enable := TRUE, Reset := Reset, MovementRequested := MovementRequested,
      ContactorFeedback := BrakeFeedback,
      DelayContactClose := BrakeDelayContactClose, DelayMagnetise := BrakeDelayMagnetise,
      DelayMotorDecel := BrakeDelayMotorDecel, FeedbackTimeout := BrakeFeedbackTimeout,
      BypassContactorCheck := BypassContactorCheck);
BrakeReleaseRequest := Brake.BrakeCmd;
BrakeCommandOpenConfirmed := Brake.BrakeCommandOpenConfirmed;
BrakeContactorCheck := Brake.ContactorCheck;

// 🛡️ FB_Translation ne décide plus la frontière finale : il expose uniquement
// ses demandes métier. SafeStop est déjà appliqué dans la rampe rapide §4 : tant que
// la vitesse ne vaut pas zéro, la demande et le desserrage suivent la décélération.
// FB_TranslationOutputInterlock ne doit jamais transformer SafeStop en coupure sèche.

{endregion}

{region "§7 Diagnostic etat et repli defaut"}
// 🧾 7. ERRORID (bitfield, cumul)
IF Brake.Status.Error THEN
    Status.ErrorId := Status.ErrorId OR 16#0001;
ELSIF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#FFFE;
END_IF;

// Défaut variateur (bit3) : lu via EtherCAT (DriveStatusWord.4)
IF DriveStatusWord.4 THEN
    Status.ErrorId := Status.ErrorId OR 16#0008;
ELSIF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#FFF7;
END_IF;

// 🚧 Défaut fin de course extrême (bit6) — si bypassé, on NETTOIE le bit résiduel
IF BypassLimitSwitch THEN
    Status.ErrorId := Status.ErrorId AND 16#FFBF;   // Nettoie le bit 6 (évite résidu d'avant activation)
ELSE
    // Activé UNIQUEMENT en cas de tentative d'avancer vers la butée active (libéré si dégagement en sens inverse)
    IF (CommandedDirection = 1 AND LimitSwitchFwd) OR (CommandedDirection = -1 AND LimitSwitchRev) THEN
        Status.ErrorId := Status.ErrorId OR 16#0040;
    ELSE
        Status.ErrorId := Status.ErrorId AND 16#FFBF;
    END_IF;
END_IF;

Status.Error := (Status.ErrorId <> 16#0000);
ErrorEdge(CLK := Status.Error);
IF ErrorEdge.Q THEN
    Status.StateAtError := Status.State;
END_IF;

// 🚦 8. STATE MACHINE (phase)
IF (NOT StartStop OR SafeStop) AND ABS(SpeedRamp.Current) > 0.1 THEN
    Status.State := E_State.STOPPING;
ELSIF ABS(SpeedRamp.Current) > 0.1 THEN
    Status.State := E_State.BUSY;
ELSE
    Status.State := E_State.READY;
END_IF;

Status.Busy := (Status.State = E_State.BUSY) OR (Status.State = E_State.STOPPING);
Status.Done := FALSE;

// 🛡️ 9. SORTIE SÛRE SUR DÉFAUT
IF Status.Error THEN
    RequestedDriveControlWord := 0; RequestedDriveFreqHz := 0.0;
    BrakeReleaseRequest := FALSE;
END_IF;

{endregion}
