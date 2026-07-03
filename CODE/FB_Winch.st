(* ═══════════════════════════════════════════════════════════════
   🪝 FB_Winch — Directeur d'un treuil individuel (M1/M2 — instance par treuil)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie9_Fonction_Winch_v1.1.md
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
      uniquement pour l'instant — voir CODE/FB_Safety_Winch.st).
   🆕 AJOUT (2026-07-02, retour terrain — détecteur mou de câble) : nouvelle
      entrée `ForbidDescent` (sortie dédiée FB_Safety_Winch, DISTINCTE de
      `SafeStop`) — masque UNIQUEMENT `RelayRev` (descente), `RelayFwd`
      (montée) reste piloté normalement. Permet à l'opérateur de remonter
      pour vérifier le câblage sans être bloqué par un `SafeStop` classique
      qui aurait arrêté les 2 sens. Voir DOC/AF_Partie9 §4ter.
   🆕 AJOUT (2026-07-03quinquies, retour terrain — limitation couple en descente) :
      nouveau paramètre `MaxStepDescente` (défaut 2). En descente
      (`CommandedDirection = -1`), le palier atteignable par `FB_SpeedStep` est
      plafonné à cette valeur MÊME à consigne joystick 100% — la charge est
      entraînante en descente (image de couple, pas besoin d'aller vite). En
      montée, les 5 paliers normaux restent inchangés (`MaxStepNumber := 5`).
      Ne change PAS la logique de décodage (voir FB_SpeedStep.st), juste le
      plafond fourni selon le sens.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Winch
VAR_INPUT
    Enable                  : BOOL;
    Reset                   : BOOL;
    EmergencyStopOk         : BOOL;
    Mode                    : E_Mode;
    StartStop               : BOOL;
    SafeStop                : BOOL;
    ForbidDescent           : BOOL;
    Direction               : INT;
    SpeedRefPct             : REAL;
    SpeedStepTable          : ST_SpeedStepTable;
    MaxStepDescente         : INT := 2;    // 🆕 Plafond palier en descente (CommandedDirection=-1) — couple, pas vitesse
    ContactorFeedbackFwd    : BOOL;
    ContactorFeedbackRev    : BOOL;
    BrakeFeedback           : BOOL;
    RampAccelRate           : REAL := 50.0;
    RampDecelNormalRate     : REAL := 150.0;
    RampDecelFastRate       : REAL := 400.0;
    SpeedStepHystMargin     : REAL := 2.0;
    DirectionInterlockDelay : TIME := T#200ms;
    ContactorFeedbackTimeout: TIME := T#500ms;
    BrakeDelayContactClose  : TIME := T#100ms;
    BrakeDelayMagnetise     : TIME := T#300ms;
    BrakeDelayMotorDecel    : TIME := T#500ms;
    BrakeFeedbackTimeout    : TIME := T#1s;
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;
    State               : E_State;
    StateAtError        : E_State;
    RelayFwd            : BOOL;
    RelayRev            : BOOL;
    Contactor1          : BOOL;
    Contactor2          : BOOL;
    Contactor3          : BOOL;
    Contactor4          : BOOL;
    StepNumber          : INT;
    BrakeCmd            : BOOL;
    FwdContactorCheck   : ST_ContactorCheck;
    RevContactorCheck   : ST_ContactorCheck;
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
    TonFwdFeedback      : TON;
    TonRevFeedback      : TON;
    RampTargetPct       : REAL;
    DirectionChangePending : BOOL;
END_VAR

IF NOT Enable OR NOT EmergencyStopOk THEN
    RelayFwd := FALSE; RelayRev := FALSE;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    SpeedStep(Enable := FALSE, SpeedRefPct := 0.0, Table := SpeedStepTable, HystMargin := SpeedStepHystMargin);
    StepNumber := SpeedStep.StepNumber;
    Brake(Enable := FALSE, Reset := FALSE, MovementRequested := FALSE, ContactorFeedback := BrakeFeedback,
          DelayContactClose := BrakeDelayContactClose, DelayMagnetise := BrakeDelayMagnetise,
          DelayMotorDecel := BrakeDelayMotorDecel, FeedbackTimeout := BrakeFeedbackTimeout);
    BrakeCmd := Brake.BrakeCmd;
    BrakeContactorCheck := Brake.ContactorCheck;
    CommandedDirection := 0;
    DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
    SpeedRamp(Target := 0.0, AccelRate := RampAccelRate, DecelRate := RampDecelFastRate, CycleTimeS := CycleTimeCalc.CycleTimeS);
    State := E_State.DISABLED;
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
CycleTimeCalc(DefaultValueS := 0.010);

ResetEdge(CLK := Reset);

DirectionChangePending := (Direction <> CommandedDirection) AND (CommandedDirection <> 0);

RampTargetPct := 0.0;
IF NOT SafeStop AND StartStop AND NOT DirectionChangePending THEN
    RampTargetPct := ABS(SpeedRefPct);
END_IF;

SpeedRamp(Target := RampTargetPct,
          AccelRate := RampAccelRate,
          DecelRate := SEL(SafeStop, RampDecelNormalRate, RampDecelFastRate),
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

// 🆕 Plafond palier descente (couple, pas vitesse) : 5 = inchangé en montée/neutre,
// MaxStepDescente uniquement si CommandedDirection = -1 (Rev)
SpeedStep(Enable := (ABS(SpeedRamp.Current) > 0.1), SpeedRefPct := ABS(SpeedRamp.Current),
          Table := SpeedStepTable, HystMargin := SpeedStepHystMargin,
          MaxStepNumber := SEL(CommandedDirection = -1, 5, MaxStepDescente));
StepNumber := SpeedStep.StepNumber;
Contactor1 := SpeedStep.Contactor1;
Contactor2 := SpeedStep.Contactor2;
Contactor3 := SpeedStep.Contactor3;
Contactor4 := SpeedStep.Contactor4;

RelayFwd := (CommandedDirection = 1) AND (StepNumber > 0);
RelayRev := (CommandedDirection = -1) AND (StepNumber > 0);

IF ForbidDescent THEN
    RelayRev := FALSE;
END_IF;

Brake(Enable := TRUE, Reset := Reset, MovementRequested := (RelayFwd OR RelayRev),
      ContactorFeedback := BrakeFeedback,
      DelayContactClose := BrakeDelayContactClose, DelayMagnetise := BrakeDelayMagnetise,
      DelayMotorDecel := BrakeDelayMotorDecel, FeedbackTimeout := BrakeFeedbackTimeout);
BrakeCmd := Brake.BrakeCmd;
BrakeContactorCheck := Brake.ContactorCheck;

FwdContactorCheck.Command := RelayFwd;
FwdContactorCheck.Feedback := ContactorFeedbackFwd;
TonFwdFeedback(IN := (RelayFwd <> ContactorFeedbackFwd), PT := ContactorFeedbackTimeout);
IF TonFwdFeedback.Q THEN
    FwdContactorCheck.StuckClosed := (NOT RelayFwd AND ContactorFeedbackFwd);
    FwdContactorCheck.StuckOpen   := (RelayFwd AND NOT ContactorFeedbackFwd);
ELSIF ResetEdge.Q THEN
    FwdContactorCheck.StuckClosed := FALSE; FwdContactorCheck.StuckOpen := FALSE;
END_IF;

RevContactorCheck.Command := RelayRev;
RevContactorCheck.Feedback := ContactorFeedbackRev;
TonRevFeedback(IN := (RelayRev <> ContactorFeedbackRev), PT := ContactorFeedbackTimeout);
IF TonRevFeedback.Q THEN
    RevContactorCheck.StuckClosed := (NOT RelayRev AND ContactorFeedbackRev);
    RevContactorCheck.StuckOpen   := (RelayRev AND NOT ContactorFeedbackRev);
ELSIF ResetEdge.Q THEN
    RevContactorCheck.StuckClosed := FALSE; RevContactorCheck.StuckOpen := FALSE;
END_IF;

IF Brake.Error THEN
    ErrorId := ErrorId OR 16#0001;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

IF FwdContactorCheck.StuckClosed OR FwdContactorCheck.StuckOpen THEN
    ErrorId := ErrorId OR 16#0002;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFD;
END_IF;

IF RevContactorCheck.StuckClosed OR RevContactorCheck.StuckOpen THEN
    ErrorId := ErrorId OR 16#0004;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFB;
END_IF;

Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

IF (NOT StartStop OR SafeStop OR DirectionChangePending) AND ABS(SpeedRamp.Current) > 0.1 THEN
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
