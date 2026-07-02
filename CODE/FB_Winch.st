(* ═══════════════════════════════════════════════════════════════
   🪝 FB_Winch — Directeur d'un treuil individuel (M1/M2 — instance par treuil)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie9_Fonction_Winch_v1.0.md
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
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Winch) ===

FUNCTION_BLOCK PUBLIC FB_Winch
VAR_INPUT
    Enable                  : BOOL;        // Active le FB. FALSE = neutralisation totale (sorties coupées)
    Reset                   : BOOL;        // Acquittement défaut (front)
    EmergencyStopOk         : BOOL;        // Chaîne AU réarmée + conditions globales OK
    Mode                    : E_Mode;      // Mode courant (contexte — droits arbitrés en amont par l'appelant)
    StartStop               : BOOL;        // TRUE = rampe accélération, FALSE = rampe décélération NORMALE
    SafeStop                : BOOL;        // Sortie FB_Safety_Winch : TRUE = rampe décélération RAPIDE (Enable maintenu)
    Direction               : INT;         // -1 = Rev, 0 = Neutre, +1 = Fwd (ex. AxisCmdY.Direction)
    SpeedRefPct             : REAL;        // Consigne 0..100 % (ex. AxisCmdY.SpeedRef)
    SpeedStepTable          : ST_SpeedStepTable;  // Table des 5 paliers PROPRE À CE TREUIL
    ContactorFeedbackFwd    : BOOL;        // Retour d'état câblé contacteur sens avant
    ContactorFeedbackRev    : BOOL;        // Retour d'état câblé contacteur sens arrière
    BrakeFeedback           : BOOL;        // Retour d'état câblé bobine frein
    RampAccelRate           : REAL := 50.0;    // %/s — accélération
    RampDecelNormalRate     : REAL := 150.0;   // %/s — décélération normale (StartStop=FALSE)
    RampDecelFastRate       : REAL := 400.0;   // %/s — décélération RAPIDE (SafeStop=TRUE, "plus rapide que l'accel")
    SpeedStepHystMargin     : REAL := 2.0;     // % — marge anti-battement changement de palier
    DirectionInterlockDelay : TIME := T#200ms; // Délai avant d'autoriser un changement de sens à l'arrêt
    ContactorFeedbackTimeout: TIME := T#500ms; // Timeout cohérence commande/retour contacteurs de sens
    BrakeDelayContactClose  : TIME := T#100ms; // Voir FB_Brake
    BrakeDelayMagnetise     : TIME := T#300ms; // Voir FB_Brake
    BrakeDelayMotorDecel    : TIME := T#500ms; // Voir FB_Brake
    BrakeFeedbackTimeout    : TIME := T#1s;    // Voir FB_Brake
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0: Brake.Error ; bit1: contacteur sens Fwd ; bit2: contacteur sens Rev
    State               : E_State;
    StateAtError        : E_State;
    RelayFwd            : BOOL;        // 🔌 Contacteur sens avant (montée) — à mapper en I/O Mapping
    RelayRev            : BOOL;        // 🔌 Contacteur sens arrière (descente) — à mapper en I/O Mapping
    Contactor1          : BOOL;        // 🔌 Contacteur vitesse 1 pour le palier courant (Table.P<n>R1)
    Contactor2          : BOOL;        // 🔌 Contacteur vitesse 2 pour le palier courant (Table.P<n>R2)
    Contactor3          : BOOL;        // 🔌 Contacteur vitesse 3 pour le palier courant (Table.P<n>R3)
    Contactor4          : BOOL;        // 🔌 Contacteur vitesse 4 pour le palier courant (Table.P<n>R4)
    StepNumber          : INT;         // Palier courant (IHM, 0..5)
    BrakeCmd            : BOOL;        // 🔌 Commande bobine frein — TRUE = relâché
    FwdContactorCheck   : ST_ContactorCheck;   // Diag contacteur sens avant (IHM/FB_Safety_Winch)
    RevContactorCheck   : ST_ContactorCheck;   // Diag contacteur sens arrière
    BrakeContactorCheck : ST_ContactorCheck;   // Diag contacteur frein (miroir de FB_Brake)
END_VAR
VAR
    SpeedStep           : FB_SpeedStep;    // 🧩 Composé — décodage palier
    Brake               : FB_Brake;        // 🧩 Composé — séquence frein
    CycleTimeCalc       : FB_CycleTime;    // Base de temps pour la rampe interne
    SpeedRamp           : FB_Ramp;         // Rampe interne (arbitrage SafeStop/StartStop)
    ResetEdge           : R_TRIG;
    ErrorEdge           : R_TRIG;
    DirectionChangeDelay: TON;             // Interlock changement de sens
    CommandedDirection  : INT;             // Sens réellement appliqué (figé pendant le mouvement)
    TonFwdFeedback      : TON;
    TonRevFeedback      : TON;
    RampTargetPct       : REAL;
    DirectionChangePending : BOOL;  // 🔧 AJOUT (retour terrain 2026-07-02) — voir §3
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Winch) ===

// 🛑 1. GATE (Enable / EmergencyStopOk) — neutralisation totale, sorties sûres
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
CycleTimeCalc(DefaultValueS := 0.010);   // MainTask = 10 ms (valeur de secours si delta temps invalide)

// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// ⚙️ 3. CORE — arbitrage rampe : Enable > SafeStop > StartStop
// 🔧 CORRECTIF (retour terrain 2026-07-02) : un changement de sens en attente FORCE la cible
// de rampe à 0.0, INDÉPENDAMMENT de ce que redemande le joystick entre-temps. Avant ce
// correctif, la cible suivait en continu SpeedRefPct (magnitude joystick) ; lors d'une
// inversion plus rapide que le temps de décélération réel, rien ne garantissait que cette
// magnitude "croise" un instant sous le seuil 0,1 % (deux rampes en cascade avancent par pas
// discrets, la magnitude peut sauter par-dessus la fenêtre sans jamais y entrer) — le treuil
// ne s'arrêtait jamais tant que l'opérateur ne laissait pas le joystick se stabiliser au
// neutre. Désormais : dès qu'un sens différent est demandé (hors 1er engagement depuis
// neutre), on force l'arrêt réel et déterministe avant d'envisager quoi que ce soit d'autre.
DirectionChangePending := (Direction <> CommandedDirection) AND (CommandedDirection <> 0);

RampTargetPct := 0.0;
IF NOT SafeStop AND StartStop AND NOT DirectionChangePending THEN
    RampTargetPct := SpeedRefPct;
END_IF;

SpeedRamp(Target := RampTargetPct,
          AccelRate := RampAccelRate,
          DecelRate := SEL(SafeStop, RampDecelNormalRate, RampDecelFastRate),
          CycleTimeS := CycleTimeCalc.CycleTimeS);

// 🔒 3bis. INTERLOCK CHANGEMENT DE SENS — jamais Fwd+Rev simultanés
// ⚠️ CORRECTIF 1 (retour terrain 2026-07-01) : l'ancienne version exigeait 200 ms à vitesse
// confirmée nulle AVANT de figer CommandedDirection, y compris pour le tout premier
// engagement (neutre → un sens) — or la rampe quitte le seuil de 0.1 % en ~2 ms dès qu'une
// consigne existe (AccelRate 50 %/s), donc la fenêtre se refermait avant que le délai de
// 200 ms n'ait pu s'écouler : CommandedDirection restait bloqué à 0 en permanence (aucun
// RelayFwd/RelayRev jamais activé, alors que les paliers de vitesse évoluaient normalement).
// ⚠️ CORRECTIF 2 (revue de code 2026-07-01) : le correctif 1 traitait "un sens → neutre"
// comme immédiat au même titre que "neutre → un sens" — or RelayFwd/RelayRev suivent
// CommandedDirection, alors que Contactor1..4 suit SpeedRamp.Current (rampe interne
// indépendante) : un arrêt demandé (Direction:=0) coupait le contacteur de sens
// INSTANTANÉMENT, alors que le palier de vitesse et le frein (MovementRequested) restaient
// actifs pendant encore toute la durée de la rampe de décélération — perte de couple moteur
// non contrôlée, frein encore ouvert. Non conforme Partie3 §9 ("SafeStop ne coupe pas les
// sorties : elles restent actives le temps de la décélération").
// ⚠️ CORRECTIF 3 (retour terrain 2026-07-02) : les correctifs 1/2 supposaient que
// ABS(SpeedRamp.Current) finirait par croiser le seuil 0,1 % naturellement — faux en cas
// d'inversion plus rapide que le temps de décélération réel (voir §3, DirectionChangePending
// force maintenant la cible à 0 de façon déterministe, donc ce test ci-dessous devient
// fiable dans tous les cas, y compris les inversions rapides/répétées).
// Correction définitive : SEUL neutre → un sens (engagement initial) est immédiat (rien à
// interrompre). "un sens → neutre" (arrêt) ET une inversion directe Fwd↔Rev exigent tous
// les deux la vitesse rampée confirmée nulle avant de lâcher/changer CommandedDirection.
IF Direction <> CommandedDirection THEN
    IF CommandedDirection = 0 AND Direction <> 0 THEN
        // Engagement initial neutre → un sens : immédiat (rien à inverser brutalement)
        CommandedDirection := Direction;
        DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelay);
    ELSIF ABS(SpeedRamp.Current) < 0.1 THEN
        // Arrêt (un sens → neutre) ou inversion directe Fwd↔Rev : vitesse confirmée nulle requise
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

// 🪜 4. PALIER DE VITESSE (composé, table propre à ce treuil)
SpeedStep(Enable := (ABS(SpeedRamp.Current) > 0.1), SpeedRefPct := ABS(SpeedRamp.Current),
          Table := SpeedStepTable, HystMargin := SpeedStepHystMargin);
StepNumber := SpeedStep.StepNumber;
Contactor1 := SpeedStep.Contactor1;
Contactor2 := SpeedStep.Contactor2;
Contactor3 := SpeedStep.Contactor3;
Contactor4 := SpeedStep.Contactor4;

// ➡️⬅️ 5. CONTACTEURS DE SENS
RelayFwd := (CommandedDirection = 1) AND (StepNumber > 0);
RelayRev := (CommandedDirection = -1) AND (StepNumber > 0);

// 🛑 6. FREIN (composé) — ne relâche qu'après la séquence temporisée interne
Brake(Enable := TRUE, Reset := Reset, MovementRequested := (RelayFwd OR RelayRev),
      ContactorFeedback := BrakeFeedback,
      DelayContactClose := BrakeDelayContactClose, DelayMagnetise := BrakeDelayMagnetise,
      DelayMotorDecel := BrakeDelayMotorDecel, FeedbackTimeout := BrakeFeedbackTimeout);
BrakeCmd := Brake.BrakeCmd;
BrakeContactorCheck := Brake.ContactorCheck;

// 🔍 7. DOUBLE VÉRIFICATION CONTACTEURS DE SENS (ST_ContactorCheck)
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

// 🧾 8. ERRORID (bitfield, cumul — effacé bit à bit si cause disparue + reset front)
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

// 🚦 9. STATE MACHINE (phase — orthogonale à Error, Partie3 §2)
// 🔧 AJOUT DirectionChangePending (2026-07-02) : décélération forcée par un changement de
// sens en attente = aussi un STOPPING pour l'IHM (cohérent avec le §3 ci-dessus).
IF (NOT StartStop OR SafeStop OR DirectionChangePending) AND ABS(SpeedRamp.Current) > 0.1 THEN
    State := E_State.STOPPING;      // Décélération en cours (arrêt demandé, défaut process, ou changement de sens en attente)
ELSIF ABS(SpeedRamp.Current) > 0.1 THEN
    State := E_State.BUSY;          // Mouvement en cours
ELSE
    State := E_State.READY;         // À l'arrêt, prêt
END_IF;

Busy := (State = E_State.BUSY) OR (State = E_State.STOPPING);
Done := FALSE;   // Pas de notion de "terminé" ponctuel sans FB_Cycle — présent pour conformité

// 🛡️ 10. SORTIE SÛRE SUR DÉFAUT (Partie3 §9 étape 7 : "sorties coupées si Error / NOT Enable")
// ⚠️ AJOUT (revue de code 2026-07-01) : un contacteur de sens incohérent (collé/absent) ou un
// défaut frein ne neutralisait auparavant QUE le diagnostic (ErrorId), sans couper les sorties
// physiques — le treuil restait commandé normalement malgré un défaut détecté. Coupure directe
// (pas de rampe) : on ne peut plus se fier au contacteur suspect pour un arrêt maîtrisé, comme
// pour l'AU physique (Partie2 §6 — coupure brutale, frein collé brutalement, cas distinct du
// SafeStop process qui reste géré en douceur ci-dessus).
IF Error THEN
    RelayFwd := FALSE;
    RelayRev := FALSE;
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
    BrakeCmd := FALSE;   // Frein collé — position sûre par défaut
END_IF;
