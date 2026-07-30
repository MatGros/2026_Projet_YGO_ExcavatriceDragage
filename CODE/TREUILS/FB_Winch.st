(* ═══════════════════════════════════════════════════════════════
   🪝 FB_Winch — Directeur d'un treuil individuel (M1: moteur de retenue / M2: moteur Benne — instance par treuil)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-09_Fonction_Winch_v2.0.md
   🔌 FB DE MOUVEMENT (Partie3 §1bis) : porte StartStop + SafeStop en
      plus de l'interface standard. Précédence Enable > SafeStop > StartStop.
   🧩 Compose FB_SpeedStep (décodage palier) + FB_Brake (séquence frein).
   📤 Sorties physiques : RelayFwd/RelayRev (contacteurs de sens),
      Contactor1..4 (contacteurs de vitesse), BrakeCmd (bobine frein) —
      à câbler manuellement sur les canaux Q réels (I/O Mapping CODESYS).
   🔒 Interlock changement de sens : jamais Fwd et Rev simultanément.
      ⚠️ CORRECTIF (retour terrain 2026-07-01) : neutre↔un sens = immédiat ;
      seule une inversion DIRECTE Fwd↔Rev exige la vitesse confirmée nulle
      (l'ancienne version exigeait l'arrêt confirmé même pour le tout
      premier engagement, ce qui bloquait `CommandedDirection` à 0 en
      permanence — voir §3bis dans le corps ST pour le détail).
   ⚠️ ÉVOLUTION (retour terrain 2026-07-01) : `Contactor1..4` sont désormais
      lus directement dans `FB_SpeedStep` (table `P<palier>R<relais>`),
      plus de masque `BYTE` intermédiaire ni de bit-extraction ici.
   ⚠️ CORRECTIF (retour terrain 2026-07-02) : une inversion de sens PLUS
      RAPIDE que le temps de décélération réel pouvait bloquer
      indéfiniment `CommandedDirection` (le treuil ne s'arrêtait jamais,
      continuait dans l'ancien sens) — la cible de rampe suivait la
      magnitude joystick en continu, sans garantie de croiser le seuil
      d'arrêt. Corrigé : `DirectionChangePending` FORCE désormais la
      cible à 0.0 dès qu'un changement de sens est en attente, de façon
      déterministe et indépendante du joystick (voir §3 dans le corps ST).
   🔴 Ce lot (M1 seul, Maintenance N1, test banc) : pas de dépendance
      codeur. SafeStop vient de FB_Safety_Winch (perte joystick/CAN
      uniquement pour l'instant — voir CODE/TREUILS/FB_Safety_Winch.st).
   🆕 AJOUT (2026-07-02, retour terrain — détecteur mou de câble) : nouvelle
      entrée `ForbidDescent` (sortie dédiée FB_Safety_Winch, DISTINCTE de
      `SafeStop`). ⚠️ ÉVOLUTION D72 (2026-07-03vicies, voir plus bas) :
      `RelayFwd` (montée) toujours piloté normalement, mais `ForbidDescent`
      déclenche maintenant une vraie décélération rapide dès qu'on n'est PAS
      en train de remonter — voir DOC/AF_Partie-09_Fonction_Winch_v2.0.md §4ter pour le contexte
      d'origine, et l'entrée D72 ci-dessous pour le comportement actuel.
   🆕 AJOUT (2026-07-03quinquies, retour terrain — limitation couple en descente) :
      nouveau paramètre `CfgMaxStepDescente` (défaut 2). En descente
      (`CommandedDirection = -1`), le palier atteignable par `FB_SpeedStep` est
      plafonné à cette valeur MÊME à consigne joystick 100% — la charge est
      entraînante en descente (image de couple, pas besoin d'aller vite). En
      montée, les 5 paliers normaux restent inchangés (`MaxStepNumber := 5`).
      Ne change PAS la logique de décodage (voir FB_SpeedStep.st), juste le
      plafond fourni selon le sens.
   🔧 CORRECTIF (2026-07-03vicies, demande utilisateur, AUDIT D72) : `ForbidDescent`
      (mou de câble) intègre désormais une VRAIE décélération rapide (comme `SafeStop`)
      via `EffectiveSafeStop`, au lieu d'un simple masquage brut de `RelayRev`. INHIBÉ
      quand `CommandedDirection = 1` (montée/enroulement en cours) : l'opérateur peut
      librement remonter pour reprendre le mou, sans déclencher de décélération. Le
      masquage `RelayRev := FALSE` sur `ForbidDescent` reste EN PLUS, inconditionnel
      (filet de sécurité direct, indépendant de la rampe).
   🔴🔧 REX 2026-07-07 : NOUVELLE DONNÉE TERRAIN — `ContactorFeedbackFwd`/`ContactorFeedbackRev`
      (retour individuel par sens) SUPPRIMÉS côté matériel, remplacés par UN SEUL retour par
      treuil (`FwdRevSpeedFeedbackOff` = "tous contacteurs sens+vitesse retombés"). Conséquences :
      - `FwdContactorCheck`/`RevContactorCheck` (2 diagnostics séparés) fusionnés en UN seul
        `ContactorsCheck` (`ST_ContactorCheck`) — on ne sait plus DIRE lequel est resté collé.
      - Détection **StuckClosed uniquement**, vérifiée **seulement à l'arrêt commandé** (tous
        relais/contacteurs à FALSE) : si `FwdRevSpeedFeedbackOff` ne repasse pas à `TRUE` dans le
        délai `ContactorFeedbackTimeout`, défaut "contacteur(s) collé(s)" global (bit1 `ErrorId`).
      - `StuckOpen` n'a plus de sens (pas de confirmation individuelle par sens quand un
        mouvement est commandé) — `ContactorsCheck.StuckOpen` reste toujours `FALSE`, gardé
        uniquement pour la compatibilité de type `ST_ContactorCheck` (partagé avec `BrakeContactorCheck`).
      - Bit2 `ErrorId` (ex-RevContactorCheck) est désormais **libre/inutilisé**.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Winch
VAR_INPUT
    Enable                  : BOOL;
    Reset                   : BOOL;
    PowerContactorEngaged         : BOOL;
    Mode                    : E_Mode;
    StartStop               : BOOL;
    SafeStop                : BOOL;
    ForbidDescent           : BOOL;
    ForbidAscent            : BOOL;
    Direction               : INT;
    SpeedRefPct             : REAL;
    SpeedStepTable          : ST_SpeedStepTable;
    CfgMaxStepDescente         : INT := 3;    // 🆕 Plafond palier en descente (CommandedDirection=-1) — couple, pas vitesse — 🔧 REX 2026-07-08 : défaut relevé à 3
    MaxStepAscent           : INT := 5;    // 🆕 REX 2026-07-15 (9) : Plafond palier en montée (CommandedDirection=1) — 5 = pas de restriction
                                             // (valeur fixe Auto ET Manuel, voir PRG_06_WinchControl).
    HomingApproachActive    : BOOL;        // 🆕 REX 2026-07-08 : Limite la vitesse au palier 1 en montée (approche capteur haut)
    FwdRevSpeedFeedbackOff  : BOOL;   // 🔧 REX 2026-07-07 : retour unique "tous contacteurs sens+vitesse
                                       // retombés" (remplace ContactorFeedbackFwd/Rev)
    BrakeFeedback           : BOOL;
    BypassContactorCheck    : BOOL;   // 🧪 TRUE = désactive StuckClosed (axe simulé,
                                       // voir GVL_Simulation.SensorMxContactorFeedbackIsReal — TOUJOURS FALSE réel)
    BypassGlobal            : BOOL;   // 🌐 TRUE = force ErrorId=0, ignore toutes les erreurs du FB
    CfgRampAccelRate           : REAL := 50.0;
    CfgRampDecelNormalRate     : REAL := 150.0;
    CfgRampDecelFastRate       : REAL := 400.0;
    SpeedStepHystMargin     : REAL := 2.0;
    DirectionInterlockDelay : TIME := T#200ms;
    ContactorFeedbackTimeout: TIME := T#500ms;
    BrakeDelayContactClose  : TIME := T#100ms;
    BrakeDelayMagnetise     : TIME := T#300ms;
    BrakeDelayMotorDecel    : TIME := T#500ms;
    BrakeFeedbackTimeout    : TIME := T#300ms; // Strictement sous watchdog final 500 ms
    Homed                   : BOOL;             // 🆕 État de référencement du treuil
    HomingSuspect           : BOOL;             // 🆕 REX 2026-07-08 : Incertitude/doute sur le référencement (§3.7)
    CablePosM               : REAL;             // 🆕 Position actuelle du câble en mètres
    TopLimitM               : REAL := 8.5;      // 🆕 Position limite haute active (cible homing, m) — ancre le ralentissement
    BottomLimitM            : REAL := -20.0;    // 🆕 Position limite basse active (m)
    CfgSlowdownDistanceM       : REAL := 1.0;      // 🆕 Distance d'approche avant limite pour ralentir (m)
    CfgSlowSpeedPct            : REAL := 15.0;     // 🆕 Consigne de vitesse lente dans la zone de ralentissement (%)
    MeasuredSpeedBand       : INT := 0;         // 🛡️ Bande vitesse réelle validée
    SpeedGuardEnable        : BOOL := FALSE;   // 🛡️ Activation garde-fou changement de palier
    SpeedGuardReady         : BOOL := FALSE;   // 🟢 Conditions de stabilité validées
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD; // bit0: frein ; bit1: contacteur(s) collé(s) ; bit2: configuration FB_SpeedStep invalide
    State               : E_State;
    StateAtError        : E_State;
    RelayFwd            : BOOL;
    RelayRev            : BOOL;
    Contactor1          : BOOL;
    Contactor2          : BOOL;
    Contactor3          : BOOL;
    Contactor4          : BOOL;
    RequestedStep       : INT;             // Palier brut calculé par FB_SpeedStep avant tempo métier
    StepNumber          : INT;             // Palier métier temporisé, transmis à l'interlock final
    BusinessStepDelayElapsed : TIME;       // Écoulé de la tempo métier fixe T#1s500ms
    SpeedGuardLimited   : BOOL;
    BrakeCmd            : BOOL;
    ContactorsCheck     : ST_ContactorCheck;  // 🔧 REX 2026-07-07 : fusion Fwd+Rev (StuckOpen toujours FALSE, voir bandeau)
    BrakeContactorCheck : ST_ContactorCheck;
END_VAR
VAR
    SpeedStep           : FB_SpeedStep;
    Brake               : FB_Brake;
    CycleTimeCalc       : FB_CycleTime;
    SpeedRamp           : FB_Ramp;
    ResetEdge           : R_TRIG;
    ErrorEdge           : R_TRIG;
    DirectionChangeDelay: TON;
    CommandedDirection  : INT;
    TonContactorsDropped: TON;   // 🔧 REX 2026-07-07 : remplace TonFwdFeedback/TonRevFeedback
    BusinessStepDelay    : TON;   // 🪜 Tempo métier nominale entre hausses de palier
    AllContactorsCommandedOff : BOOL; // 🔧 REX 2026-07-07
    RampTargetPct       : REAL;
    DirectionChangePending : BOOL;
    EffectiveSafeStop   : BOOL;   // 🆕 2026-07-03vicies — SafeStop réel OU (ForbidDescent hors montée)
    ActiveMaxStep       : INT;    // 🆕 REX 2026-07-08 : Limite dynamique du pas de vitesse
    BrakeSafetyOk       : BOOL;   // 🛡️ REX 2026-07-24 : Interlock anti-échauffement frein
    FirstScanDone       : BOOL;
END_VAR

IF NOT Enable OR NOT PowerContactorEngaged THEN
    RelayFwd := FALSE; RelayRev := FALSE;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    SpeedStep(Enable := FALSE, SpeedRefPct := 0.0, Table := SpeedStepTable, HystMargin := SpeedStepHystMargin);
    RequestedStep := SpeedStep.StepNumber;
    StepNumber := 0;
    BusinessStepDelay(IN := FALSE, PT := T#1s500ms);
    BusinessStepDelayElapsed := T#0ms;
    Brake(Enable := FALSE, Reset := FALSE, MovementRequested := FALSE, ContactorFeedback := BrakeFeedback,
          DelayContactClose := BrakeDelayContactClose, DelayMagnetise := BrakeDelayMagnetise,
          DelayMotorDecel := BrakeDelayMotorDecel, FeedbackTimeout := BrakeFeedbackTimeout);
    BrakeCmd := Brake.BrakeCmd;
    BrakeContactorCheck := Brake.ContactorCheck;
    CommandedDirection := 0;
    DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
    SpeedRamp(Target := 0.0, AccelRate := CfgRampAccelRate, DecelRate := CfgRampDecelFastRate, CycleTimeS := CycleTimeCalc.CycleTimeS);
    State := E_State.DISABLED;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    Error := FALSE;
    ErrorId := 16#0000;
    RETURN;
END_IF;

// 🧹 Initialisation au premier scan : purge des résidus RAM d'un Online Change / Warm Start et évitement des alarmes transitoires
IF NOT FirstScanDone THEN
    FirstScanDone := TRUE;
    ErrorId := 16#0000;
    StepNumber := 0;
    RequestedStep := 0;
    BusinessStepDelay(IN := FALSE, PT := T#1s500ms);
    BusinessStepDelayElapsed := T#0ms;
    RETURN;
END_IF;

Ready := TRUE;
CycleTimeCalc(DefaultValueS := 0.010);

ResetEdge(CLK := Reset);

DirectionChangePending := (Direction <> CommandedDirection) AND (CommandedDirection <> 0);

// 🆕 Mou de câble (ForbidDescent) et Fin de course haut (ForbidAscent) intégrés à une VRAIE
// décélération rapide (comme SafeStop) :
// - ForbidDescent est INHIBÉ si CommandedDirection = 1 (montée libre pour reprendre le mou)
// - ForbidAscent est INHIBÉ si CommandedDirection = -1 (descente libre pour dégager le câble)
EffectiveSafeStop := SafeStop 
                     OR (ForbidDescent AND (CommandedDirection <> 1))
                     OR (ForbidAscent AND (CommandedDirection <> -1));

RampTargetPct := 0.0;
IF NOT EffectiveSafeStop AND StartStop AND NOT DirectionChangePending THEN
    RampTargetPct := ABS(SpeedRefPct);
    
    // 🆕 RALENTISSEMENT AUTOMATIQUE SUR BORDURES (si référencé et non suspect)
    // Permet d'approcher les fins de course / limites en vitesse lente de façon progressive
    IF Homed AND NOT HomingSuspect THEN
        // En montée (engagement ou mouvement actif), ralentit à l'approche de la limite haute
        IF ((CommandedDirection = 1) OR (Direction = 1)) AND (CablePosM >= (TopLimitM - CfgSlowdownDistanceM)) THEN
            RampTargetPct := MIN(RampTargetPct, CfgSlowSpeedPct);
        END_IF;
        
        // En descente (engagement ou mouvement actif), ralentit à l'approche de la limite basse
        IF ((CommandedDirection = -1) OR (Direction = -1)) AND (CablePosM <= (BottomLimitM + CfgSlowdownDistanceM)) THEN
            RampTargetPct := MIN(RampTargetPct, CfgSlowSpeedPct);
        END_IF;
    END_IF;
END_IF;

SpeedRamp(Target := RampTargetPct,
          AccelRate := CfgRampAccelRate,
          DecelRate := SEL(EffectiveSafeStop, CfgRampDecelNormalRate, CfgRampDecelFastRate),
          CycleTimeS := CycleTimeCalc.CycleTimeS);

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

// 🆕 Plafond dynamique de palier (CfgMaxStepDescente en descente, Palier 1 si non référencé ou douteux,
// Palier 1 en approche homing, MaxStepAscent en montée normale — 🔧 REX 2026-07-15 (9))
IF NOT Homed OR HomingSuspect THEN
    // 🆕 Bypass.Global = TRUE → pas de limitation, on applique la règle normale
    IF BypassGlobal THEN
        ActiveMaxStep := SEL(CommandedDirection = -1, MaxStepAscent, CfgMaxStepDescente);
    ELSE
        ActiveMaxStep := 1;
    END_IF;
ELSIF CommandedDirection = -1 THEN
    ActiveMaxStep := CfgMaxStepDescente;
ELSIF (CommandedDirection = 1) AND HomingApproachActive THEN
    ActiveMaxStep := 1;
ELSIF CommandedDirection = 1 THEN
    ActiveMaxStep := MaxStepAscent;
ELSE
    ActiveMaxStep := 5;
END_IF;

SpeedStep(Enable := (ABS(SpeedRamp.Current) > 0.1), SpeedRefPct := ABS(SpeedRamp.Current),
          Table := SpeedStepTable, HystMargin := SpeedStepHystMargin,
          MaxStepNumber := ActiveMaxStep,
          MeasuredSpeedBand := MeasuredSpeedBand,
          SpeedGuardEnable := SpeedGuardEnable,
          SpeedGuardReady := SpeedGuardReady);
// 🪜 Tempo métier nominale : toute hausse exige T#1s500ms et progresse par pas
// adjacents. Toute baisse reste immédiate pour ne jamais retarder un arrêt/safety.
RequestedStep := SpeedStep.StepNumber;
IF RequestedStep > StepNumber THEN
    BusinessStepDelay(IN := TRUE, PT := T#1s500ms);
    BusinessStepDelayElapsed := BusinessStepDelay.ET;
    IF BusinessStepDelay.Q THEN
        StepNumber := StepNumber + 1;
        BusinessStepDelay(IN := FALSE, PT := T#1s500ms);
    END_IF;
ELSE
    BusinessStepDelay(IN := FALSE, PT := T#1s500ms);
    BusinessStepDelayElapsed := BusinessStepDelay.ET;
    StepNumber := RequestedStep;
END_IF;
SpeedGuardLimited := SpeedStep.SpeedGuardLimited;

// Les sorties métier suivent le palier temporisé. FB_Winch/SpeedStepTable reste
// propriétaire unique des combinaisons, y compris les mappings M2 Benne dynamiques.
// FB_WinchOutputInterlock_LD ne fait qu'autoriser ou masquer ces quatre demandes.
CASE StepNumber OF
    1:
        Contactor1 := SpeedStepTable.P1R1; Contactor2 := SpeedStepTable.P1R2;
        Contactor3 := SpeedStepTable.P1R3; Contactor4 := SpeedStepTable.P1R4;
    2:
        Contactor1 := SpeedStepTable.P2R1; Contactor2 := SpeedStepTable.P2R2;
        Contactor3 := SpeedStepTable.P2R3; Contactor4 := SpeedStepTable.P2R4;
    3:
        Contactor1 := SpeedStepTable.P3R1; Contactor2 := SpeedStepTable.P3R2;
        Contactor3 := SpeedStepTable.P3R3; Contactor4 := SpeedStepTable.P3R4;
    4:
        Contactor1 := SpeedStepTable.P4R1; Contactor2 := SpeedStepTable.P4R2;
        Contactor3 := SpeedStepTable.P4R3; Contactor4 := SpeedStepTable.P4R4;
    5:
        Contactor1 := SpeedStepTable.P5R1; Contactor2 := SpeedStepTable.P5R2;
        Contactor3 := SpeedStepTable.P5R3; Contactor4 := SpeedStepTable.P5R4;
ELSE
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
END_CASE;

// 🛑 Interlock de sécurité frein : magnétisation normale autorisée, mais coupure stricte des relais si FB_Brake est en ERREUR
BrakeSafetyOk := NOT Brake.Error OR BypassContactorCheck;

// Le sens et la pré-magnétisation suivent la demande brute ; le palier métier
// temporisé reste seul transmis à l'interlock final pour autoriser la puissance.
RelayFwd := (CommandedDirection = 1) AND (RequestedStep > 0) AND BrakeSafetyOk;
RelayRev := (CommandedDirection = -1) AND (RequestedStep > 0) AND BrakeSafetyOk;

IF ForbidDescent THEN
    RelayRev := FALSE;
END_IF;

IF ForbidAscent THEN
    RelayFwd := FALSE;
END_IF;

Brake(Enable := TRUE, Reset := Reset, MovementRequested := (RelayFwd OR RelayRev),
      ContactorFeedback := BrakeFeedback,
      DelayContactClose := BrakeDelayContactClose, DelayMagnetise := BrakeDelayMagnetise,
      DelayMotorDecel := BrakeDelayMotorDecel, FeedbackTimeout := BrakeFeedbackTimeout,
      BypassContactorCheck := BypassContactorCheck);
BrakeCmd := Brake.BrakeCmd;
BrakeContactorCheck := Brake.ContactorCheck;

// 🔧 REX 2026-07-07 : vérification UNIQUEMENT à l'arrêt commandé (plus de détail par sens —
// voir bandeau en-tête). AllContactorsCommandedOff = tout ce que FB_Winch commande est à FALSE.
AllContactorsCommandedOff := (NOT RelayFwd) AND (NOT RelayRev)
                             AND (NOT Contactor1) AND (NOT Contactor2) AND (NOT Contactor3) AND (NOT Contactor4);

ContactorsCheck.Command  := NOT AllContactorsCommandedOff;   // TRUE = au moins un contacteur commandé
ContactorsCheck.Feedback := NOT FwdRevSpeedFeedbackOff;      // TRUE = au moins un contacteur pas retombé
TonContactorsDropped(IN := AllContactorsCommandedOff AND NOT FwdRevSpeedFeedbackOff, PT := ContactorFeedbackTimeout);
IF TonContactorsDropped.Q THEN
    ContactorsCheck.StuckClosed := TRUE;
ELSIF ResetEdge.Q THEN
    ContactorsCheck.StuckClosed := FALSE;
END_IF;
ContactorsCheck.StuckOpen := FALSE; // Non applicable avec ce retour (pas de confirmation par sens, voir bandeau)

// 🌐 BYPASS GLOBAL : force ErrorId = 0 et saute toute la logique d'erreur
IF BypassGlobal THEN
    ErrorId := 16#0000;
END_IF;

IF NOT BypassGlobal THEN
    IF Brake.Error THEN
    ErrorId := ErrorId OR 16#0001;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 🧪 Simulation (GVL_Simulation.SensorMxContactorFeedbackIsReal, passé par l'appelant via
// BypassContactorCheck) — sans contacteurs réels câblés/cohérents en essai, StuckClosed
// se déclenche à tort et bloque RelayFwd/RelayRev (voir Error plus bas).
// 🔧 REX 2026-07-07 : bit2 (ex-RevContactorCheck) libre/inutilisé, fusionné dans bit1.
IF NOT BypassContactorCheck THEN
    IF ContactorsCheck.StuckClosed THEN
        ErrorId := ErrorId OR 16#0002;
    ELSIF ResetEdge.Q THEN
        ErrorId := ErrorId AND 16#FFFD;
    END_IF;
ELSE
    ErrorId := ErrorId AND 16#FFFD;   // Bypass actif : efface/maintient à 0 le bit1
END_IF;

// 🪜 WINCH-CORE-01 : remonte le défaut de configuration interne de FB_SpeedStep.
// Le bit reste mémorisé après correction de la table ; cause disparue + nouveau front Reset
// sont obligatoires avant de rendre le treuil disponible, conformément à Partie 3 §5.
IF SpeedStep.ConfigError THEN
    ErrorId := ErrorId OR 16#0004;    // bit2 = table/plafond/hystérésis invalide
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFB;
END_IF;

END_IF; // fin IF NOT BypassGlobal

Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

IF (NOT StartStop OR EffectiveSafeStop OR DirectionChangePending) AND ABS(SpeedRamp.Current) > 0.1 THEN
    State := E_State.STOPPING;
ELSIF ABS(SpeedRamp.Current) > 0.1 THEN
    State := E_State.BUSY;
ELSE
    State := E_State.READY;
END_IF;

Busy := (State = E_State.BUSY) OR (State = E_State.STOPPING);
Done := FALSE;

IF Error THEN
    RelayFwd := FALSE;
    RelayRev := FALSE;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    BrakeCmd := FALSE;
END_IF;
