(* ═══════════════════════════════════════════════════════════════
   ↔️ FB_Translation — Directeur de l'axe transversal M3 (variateur AC600)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : ARCHIVES/Doc/AF_Partie-11_Fonction_Translation_v2.0.md
   🔌 FB DE MOUVEMENT : porte StartStop + SafeStop en plus de l'interface
      standard. Précédence Enable > SafeStop > StartStop.
   📡 Pilotage exclusivement ETHERCAT nominal (mot de commande, consigne fréquence).
   🧩 Compose FB_Brake (réutilisé TEL QUEL depuis COMMUN).
   ⚠️ CORRECTIF (retour terrain 2026-08-05) : une inversion de sens PLUS RAPIDE que le
      temps de décélération réel bloquait indéfiniment `CommandedDirection` (la translation
      ne s'arrêtait jamais, continuait dans l'ancien sens) — la cible de rampe suivait la
      magnitude joystick en continu, sans garantie de croiser le seuil d'arrêt qui
      autorise l'interlock changement de sens (§5). Même bug déjà corrigé sur `FB_Winch`
      (REX 2026-07-02), jamais porté ici. Corrigé : `DirectionChangePending` FORCE
      désormais la cible à 0.0 dès qu'un changement de sens est en attente, de façon
      déterministe et indépendante du joystick (voir §4 dans le corps ST).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Translation
VAR_INPUT
    Enable                      : BOOL;        // Active le FB. FALSE = neutralisation totale (sorties coupées)
    Reset                       : BOOL;        // Acquittement défaut (front)
    PowerContactorEngaged             : BOOL;        // Chaîne AU réarmée + conditions globales OK
    Mode                        : E_Mode;      // Mode courant
    StartStop                   : BOOL;        // TRUE = rampe accélération, FALSE = rampe décélération NORMALE
    SafeStop                    : BOOL;        // Sortie FB_Safety_Translation : TRUE = rampe décélération RAPIDE (Enable maintenu)
    Direction                   : INT;         // -1 = Rev, 0 = Neutre, +1 = Fwd (source d'autorité du sens)
    SpeedRefPct                 : REAL;        // Magnitude de la consigne (de 0 à 100%)
    PositionSensorTarget        : BOOL;        // Capteur position cible courante
    // 🆕 2026-08-06 : 3 capteurs déclencheurs de ralentissement, un cran avant chaque cible
    // (même principe que PV→Trémie, généralisé — voir §4bis dans le corps ST)
    SlowdownSensorTremie         : BOOL;        // Capteur PV — ralentissement avant Trémie (Direction=1)
    SlowdownSensorMaintenance    : BOOL;        // Capteur P1 — ralentissement avant Maintenance (Direction=-1)
    SlowdownSensorP1             : BOOL;        // Capteur P2 — ralentissement avant P1 (Direction=-1, arrêt propre pour travail)
    LimitSwitchFwd              : BOOL;        // Fin de course extrême avant
    LimitSwitchRev              : BOOL;        // Fin de course extrême arrière

    // 🔌 Spécifique ETHERCAT (image process EtherCAT, rafraîchie par EtherCatTask 4ms)
    DriveStatusWord              : WORD;       // Mot d'état AC600 lu depuis l'image d'entrée EtherCAT
    DriveActualFreqHz            : REAL;       // Fréquence réelle mesurée (Hz)

    BypassContactorCheck         : BOOL;       // 🧪 TRUE = désactive StuckClosed/StuckOpen pour le frein (simulation)
    BypassLimitSwitch            : BOOL;       // 🚧 TRUE = ignore les fins de course extrêmes
    BrakeFeedback                : BOOL;       // Retour physique direct : TRUE = frein OUVERT (desserré)

    // Réglages rampe (RETAIN)
    CfgRampAccelRate                : REAL := 20.0;    // %/s — accélération
    CfgRampDecelNormalRate          : REAL := 40.0;    // %/s — décélération normale
    CfgRampDecelFastRate            : REAL := 100.0;   // %/s — décélération RAPIDE
    DirectionInterlockDelay      : TIME := T#200ms; // Délai avant d'autoriser un changement de sens à l'arrêt

    // Réglages ETHERCAT uniquement (RETAIN)
    ApproachSpeedTremieHz        : REAL := 10.0;    // Vitesse réduite d'approche Trémie en Hz (piloté par SlowdownSensorTremie)
    ApproachSpeedMaintenanceHz   : REAL := 10.0;    // Vitesse réduite d'approche Maintenance en Hz (piloté par SlowdownSensorMaintenance)
    ApproachSpeedP1Hz            : REAL := 10.0;    // Vitesse réduite d'approche P1 en Hz (piloté par SlowdownSensorP1)
    DriveFreqScaleMaxHz          : REAL := 60.0;    // Échelle 0..100 % → MaxHz (câblé depuis _TranslationMaxFreq_Hz par PRG_07 — defaut 60.0 si non raccordé)

    // Réglages communs
    CaptorDebounce                : TIME := T#100ms; // Filtrage capteur de position cible
    BrakeDelayContactClose        : TIME := T#100ms; // Voir FB_Brake
    BrakeDelayMagnetise           : TIME := T#300ms; // Voir FB_Brake
    BrakeDelayMotorDecel          : TIME := T#500ms; // Voir FB_Brake
    BrakeFeedbackTimeout          : TIME := T#300ms; // Strictement sous watchdog final 500 ms
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0: "Défaut frein Translation" - Brake.Error ; bit3: "Défaut variateur AC600" - défaut variateur (DriveStatusWord.4) ; bit6: "Limite extrême Translation atteinte" - Fdc extrême atteint
    State               : E_State;
    StateAtError        : E_State;
    TargetReached        : BOOL;       // Capteur position cible
    RequestedDriveControlWord : WORD; // Demande métier AC600, arbitrée par FB_TranslationOutputInterlock_LD
    RequestedDriveFreqHz      : REAL; // Demande métier fréquence, arbitrée par FB_TranslationOutputInterlock_LD
    BrakeReleaseRequest       : BOOL; // Demande métier desserrage, issue de FB_Brake
    BrakeCommandOpenConfirmed : BOOL; // TRUE = frein ouvert = commande ouverture confirmée (depuis FB_Brake)
    BrakeContactorCheck  : ST_ContactorCheck; // Diag contacteur frein
END_VAR
VAR
    Brake                : FB_Brake;       // Séquence frein
    CycleTimeCalc        : FB_CycleTime;
    SpeedRamp             : FB_Ramp;       // Rampe de vitesse logicielle (PLC)
    ResetEdge            : R_TRIG;
    ErrorEdge            : R_TRIG;
    DirectionChangeDelay : TON;            // Interlock changement de sens
    CommandedDirection   : INT;            // Sens réellement appliqué
    DirectionChangePending : BOOL;         // 🆕 2026-08-05 : force la rampe à 0 pendant une inversion de sens en attente
    RampTargetPct        : REAL;
    CaptorDebounceTon     : TON;
    ArrivalEdge            : R_TRIG;
    DirectionAtArrival     : INT;
    ArrivalLock             : BOOL;        // Arrêt exact sur capteur cible
    MovementRequested      : BOOL;         // Pilote FB_Brake
    FirstScanDone          : BOOL;
END_VAR

// === IMPLEMENTATION ===

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

    State := E_State.DISABLED;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    RETURN;
END_IF;

// 🧹 Initialisation au premier scan : purge des résidus RAM d'un Online Change / Warm Start et évitement des alarmes transitoires
IF NOT FirstScanDone THEN
    FirstScanDone := TRUE;
    ErrorId := 16#0000;
    RETURN;
END_IF;

Ready := TRUE;
CycleTimeCalc(DefaultValueS := 0.010);   // MainTask = 10 ms

// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 📡 3. CAPTEUR POSITION CIBLE (debounce)
CaptorDebounceTon(IN := PositionSensorTarget, PT := CaptorDebounce);
TargetReached := CaptorDebounceTon.Q;

// ⚙️ 4. CORE — arbitrage rampe : Enable > SafeStop > StartStop
// 🆕 2026-08-05 : DirectionChangePending FORCE la cible à 0.0 dès qu'une inversion de
// sens est en attente — sans ça, la cible suit la magnitude joystick en continu et ne
// croise jamais le seuil d'arrêt (0.1%) qui autorise l'interlock §5 à basculer
// CommandedDirection. Une inversion plus rapide que la décélération réelle bloquait donc
// indéfiniment le mouvement dans l'ancien sens (même bug que FB_Winch, REX 2026-07-02).
DirectionChangePending := (Direction <> CommandedDirection) AND (CommandedDirection <> 0);

RampTargetPct := 0.0;
IF NOT SafeStop AND StartStop AND NOT DirectionChangePending THEN
    // Si butée fin de course extrême atteinte dans le sens de marche demandé, consigne forcée à 0
    // 🌐 BypassLimitSwitch = TRUE → ignore cette protection
    IF NOT BypassLimitSwitch AND ((Direction = 1 AND LimitSwitchFwd) OR (Direction = -1 AND LimitSwitchRev)) THEN
        RampTargetPct := 0.0;
    ELSE
        RampTargetPct := ABS(SpeedRefPct);
    END_IF;
END_IF;

// ⏱️ 4bis. RALENTISSEMENT AUTO À L'APPROCHE (piloté par capteur, remplace le timer)
// 🔧 REX 2026-07-18 : ApproachTime (timer générique, toute direction confondue) remplacé par un
// capteur dédié qui ne déclenche le ralentissement QU'à l'approche de sa cible, jamais l'inverse.
// 🆕 2026-08-06 : généralisé à 3 paires capteur/cible indépendantes — chaque capteur "un cran
// avant" la cible finale déclenche SA propre vitesse réduite, dans SON sens de marche uniquement :
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
// 🆕 2026-08-06 (retour terrain + revue) : élargi à P1 (arrêt travail), pas seulement les 2
// extrémités. Dès qu'on touche un capteur d'arrêt (TargetReached, débounce 100ms) OU un fin de
// course dur (LimitSwitchFwd/Rev, §5bis — immédiat, non débounce, mais toute activation même
// brève arme le même verrou), le sens d'arrivée (DirectionAtArrival) est MÉMORISÉ et BLOQUÉ.
// 🔧 REX 2026-08-06 (revue) : LimitSwitchFwd/Rev ne passaient PAS par ce verrou — un Fdc qui
// s'ouvre quelques ms pendant le freinage laissait le §5bis relâcher SA coupure directe sans que
// rien ne prenne le relais, la rampe (encore haute en interne) revenait en sortie -> ré-accélération.
// Désormais toute activation, même un instant, arme DirectionAtArrival comme un TargetReached.
ArrivalEdge(CLK := TargetReached
                 OR (LimitSwitchFwd AND (CommandedDirection = 1))
                 OR (LimitSwitchRev AND (CommandedDirection = -1)));
IF ArrivalEdge.Q THEN
    DirectionAtArrival := CommandedDirection;
END_IF;

// 🔧 REX 2026-08-06 (revue) : un retour au neutre, même SOUTENU (>100ms), ne doit JAMAIS lever
// le verrou — seul un vrai changement de sens (dégagement volontaire, sans ambiguïté) le fait.
// Sinon : neutre 100ms+ puis réappui dans le MÊME sens (le capteur/Fdc étant resté au niveau
// haut en continu, TargetReached ne montre plus de front) contournait le verrou et M3 repartait
// vers la butée. Conforme à la demande d'origine : "on doit repartir dans l'AUTRE sens", jamais
// juste relâcher-réappuyer pareil. Instantané, jamais retardé (le dégagement doit rester rapide).
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

MovementRequested := (CommandedDirection <> 0) AND (ABS(SpeedRamp.Current) > 0.1);

// 🔀 5bis. SORTIE PHYSIQUE (ETHERCAT)
RequestedDriveFreqHz := (ABS(SpeedRamp.Current) / 100.0) * DriveFreqScaleMaxHz;

// Pilotage nominal Given Command 1 (0x3101) :
// 0: None, 1: Forward, 2: Reverse, 7: Reset
IF Reset THEN
    RequestedDriveControlWord := 7; // Reset défaut variateur
ELSIF Error THEN
    RequestedDriveControlWord := 0; // Arrêt sur défaut
ELSIF MovementRequested THEN
    IF CommandedDirection = 1 THEN
        RequestedDriveControlWord := 1; // Marche avant
    ELSIF CommandedDirection = -1 THEN
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
// FB_TranslationOutputInterlock_LD ne doit jamais transformer SafeStop en coupure sèche.

// 🧾 7. ERRORID (bitfield, cumul)
IF Brake.Error THEN
    ErrorId := ErrorId OR 16#0001;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// Défaut variateur (bit3) : lu via EtherCAT (DriveStatusWord.4)
IF DriveStatusWord.4 THEN
    ErrorId := ErrorId OR 16#0008;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFF7;
END_IF;

// 🚧 Défaut fin de course extrême (bit6) — si bypassé, on NETTOIE le bit résiduel
IF BypassLimitSwitch THEN
    ErrorId := ErrorId AND 16#FFBF;   // Nettoie le bit 6 (évite résidu d'avant activation)
ELSE
    // Activé UNIQUEMENT en cas de tentative d'avancer DANS la butée active (libéré si dégagement en sens inverse)
    IF (CommandedDirection = 1 AND LimitSwitchFwd) OR (CommandedDirection = -1 AND LimitSwitchRev) THEN
        ErrorId := ErrorId OR 16#0040;
    ELSE
        ErrorId := ErrorId AND 16#FFBF;
    END_IF;
END_IF;

Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

// 🚦 8. STATE MACHINE (phase)
IF (NOT StartStop OR SafeStop) AND ABS(SpeedRamp.Current) > 0.1 THEN
    State := E_State.STOPPING;
ELSIF ABS(SpeedRamp.Current) > 0.1 THEN
    State := E_State.BUSY;
ELSE
    State := E_State.READY;
END_IF;

Busy := (State = E_State.BUSY) OR (State = E_State.STOPPING);
Done := FALSE;

// 🛡️ 9. SORTIE SÛRE SUR DÉFAUT
IF Error THEN
    RequestedDriveControlWord := 0; RequestedDriveFreqHz := 0.0;
    BrakeReleaseRequest := FALSE;
END_IF;
