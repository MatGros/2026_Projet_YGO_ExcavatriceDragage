(* ═══════════════════════════════════════════════════════════════
   🪝 FB_Winch — Directeur d'un treuil individuel (M1: moteur de retenue / M2: moteur Benne — instance par treuil)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md
   🔌 FB DE MOUVEMENT (Partie3 §1bis) : porte StartStop + SafeStop en
      plus de l'interface standard. Précédence Enable > SafeStop > StartStop.
   🧩 Compose FB_SpeedStep (décodage palier). 🆕 2026-08-06 (retrait FB_Brake, demande
      client) : le frein n'est plus géré ici — FB_Winch ne produit plus aucune sortie
      frein. La commande frein est désormais un couplage DIRECT sur RelayFwd/RelayRev,
      calculé dans FB_WinchOutputInterlock_LD puis câblé au grand jour dans
      PRG_06_Outputs_LD (voir bandeaux de ces deux fichiers). FB_Brake reste utilisé
      tel quel pour Translation (M3), non touché par ce lot.
   📤 Sorties physiques : RelayFwd/RelayRev (contacteurs de sens),
      Contactor1..4 (contacteurs de vitesse) — à câbler manuellement sur les
      canaux Q réels (I/O Mapping CODESYS). Le frein n'est plus une sortie de ce FB.
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
      en train de remonter — voir DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md §4ter pour le contexte
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
                                             // (valeur fixe Auto ET Manuel, voir PRG_TREUILS_CFC).
    HomingApproachActive    : BOOL;        // 🆕 REX 2026-07-08 : Limite la vitesse au palier 1 en montée (approche capteur haut)
    FwdRevSpeedFeedbackOff  : BOOL;   // 🔧 REX 2026-07-07 : retour unique "tous contacteurs sens+vitesse
                                       // retombés" (remplace ContactorFeedbackFwd/Rev)
    BypassContactorCheck    : BOOL;   // 🧪 TRUE = désactive StuckClosed (axe simulé,
                                       // voir GVL_Simulation.SensorMxContactorFeedbackIsReal — TOUJOURS FALSE réel)
    BypassGlobal            : BOOL;   // 🌐 TRUE = force ErrorId=0, ignore toutes les erreurs du FB
    SpeedStepHystMargin     : REAL := 2.0;
    // 🆕 2026-08-06 (décision validée, retour terrain) : rampe %/s (CfgRampAccelRate/
    // DecelNormalRate/DecelFastRate, FB_Ramp) RETIRÉE — remplacée par une temporisation FIXE
    // par palier, asymétrique montée/descente. Cible documentée
    // DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md §6.2 (montée en charge = plus prudente, descente
    // sans effort = plus rapide).
    // 🆕 2026-08-06 (simplification demandée) : interlock changement de sens asymétrique —
    // descente sans effort (pas de charge résistante, réengagement rapide), montée = charge en
    // traction (délai plus long). La temporisation par palier se DÉDUIT de cet interlock
    // (+100ms) plutôt que d'être un réglage séparé — garantit par construction qu'elle reste
    // toujours au-dessus, jamais besoin de les tenir synchronisés à la main.
    DirectionInterlockDelayDescent : TIME := T#400ms;  // Réengagement en descente (CommandedDirection=-1)
    DirectionInterlockDelayAscent  : TIME := T#900ms;  // Réengagement en montée (CommandedDirection=1)
    ContactorFeedbackTimeout: TIME := T#500ms;
    Homed                   : BOOL;             // 🆕 État de référencement du treuil
    HomingSuspect           : BOOL;             // 🆕 REX 2026-07-08 : Incertitude/doute sur le référencement (§3.7)
    CablePosM               : REAL;             // 🆕 Position actuelle du câble en mètres
    TopLimitM               : REAL := 8.5;      // 🆕 Position limite haute active (cible homing, m) — ancre le ralentissement
    BottomLimitM            : REAL := -20.0;    // 🆕 Position limite basse active (m)
    CfgSlowdownDistanceM       : REAL := 1.0;      // 🆕 Distance d'approche avant limite pour ralentir (m)
    CfgSlowdownMaxStep         : INT := 1;         // 🆕 2026-08-07 : Plafond palier dans la zone de ralentissement (1..5, défaut 1 = vitesse mini)
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
    BusinessStepDelayElapsed : TIME;       // Écoulé de la tempo métier (EffectiveStepDelay, asymétrique montée/descente)
    SpeedGuardLimited   : BOOL;
    ContactorsCheck     : ST_ContactorCheck;  // 🔧 REX 2026-07-07 : fusion Fwd+Rev (StuckOpen toujours FALSE, voir bandeau)
    InTopSlowdownZone    : BOOL;   // 🆕 2026-08-07 : diagnostic — palier plafonné à 1 (approche limite haute)
    InBottomSlowdownZone : BOOL;   // 🆕 2026-08-07 : diagnostic — palier plafonné à 1 (approche limite basse)
    CommandedDirection  : INT;     // 🆕 2026-08-07 : diagnostic — sens interne mémorisé (déclaration déplacée depuis VAR, aucun changement de logique)
    DirectionChangeDelayElapsed : TIME; // 🆕 2026-08-07 : diagnostic — écoulé de DirectionChangeDelay (miroir, retour terrain délai montée)
    DirectionChangePending : BOOL; // 🆕 2026-08-07 : diagnostic — déclaration déplacée depuis VAR (GATE 2sexies : doit accompagner CommandedDirection), aucun changement de logique
END_VAR
VAR
    SpeedStep           : FB_SpeedStep;
    CycleTimeCalc       : FB_CycleTime;
    // 🆕 2026-08-06 : SpeedRamp (FB_Ramp) retiré — RampTargetPct alimente directement
    // FB_SpeedStep, la progressivité vient de la temporisation par palier (StepDelay ci-dessous).
    ResetEdge           : R_TRIG;
    ErrorEdge           : R_TRIG;
    DirectionChangeDelay: TON;
    EffectiveDirectionInterlockDelay : TIME; // 🆕 2026-08-06 : DirectionInterlockDelayDescent/Ascent selon le sens ENTRANT (Direction)
    EffectiveStepDelay  : TIME; // 🆕 2026-08-06 : déduit d'EffectiveDirectionInterlockDelay + T#100ms
    TonContactorsDropped: TON;   // 🔧 REX 2026-07-07 : remplace TonFwdFeedback/TonRevFeedback
    BusinessStepDelay    : TON;   // 🪜 Tempo métier nominale entre hausses de palier
    AllContactorsCommandedOff : BOOL; // 🔧 REX 2026-07-07
    RampTargetPct       : REAL;
    EffectiveSafeStop   : BOOL;   // 🆕 2026-07-03vicies — SafeStop réel OU (ForbidDescent hors montée)
    ActiveMaxStep       : INT;    // 🆕 REX 2026-07-08 : Limite dynamique du pas de vitesse
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
    CommandedDirection := 0;
    DirectionChangeDelay(IN := FALSE, PT := DirectionInterlockDelayAscent);
    DirectionChangeDelayElapsed := T#0ms;
    InTopSlowdownZone := FALSE;
    InBottomSlowdownZone := FALSE;
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
END_IF;

// 🆕 RALENTISSEMENT AUTOMATIQUE SUR BORDURES (si référencé et non suspect) — permet d'approcher
// les fins de course / limites en vitesse lente de façon progressive.
// 🔧 2026-08-07 (demande client) : ancien plafond RampTargetPct en % (CfgSlowSpeedPct) remplacé
// par un plafond palier direct (ActiveMaxStep := 1, ci-dessous, même mécanisme que
// CfgMaxStepDescente/MaxStepAscent) — un treuil ne connaît que 5 paliers de contacteurs, pas une
// vitesse continue ; palier 1 = tous contacteurs de vitesse relâchés = vitesse minimale, sans
// dépendre d'un % qui doit rester sous le 1er seuil de la table pour produire le même effet.
InTopSlowdownZone := Homed AND NOT HomingSuspect
                      AND ((CommandedDirection = 1) OR (Direction = 1))
                      AND (CablePosM >= (TopLimitM - CfgSlowdownDistanceM));
InBottomSlowdownZone := Homed AND NOT HomingSuspect
                         AND ((CommandedDirection = -1) OR (Direction = -1))
                         AND (CablePosM <= (BottomLimitM + CfgSlowdownDistanceM));

// 🆕 2026-08-06 : délai asymétrique selon le sens ENTRANT (Direction) — descente sans effort
// (câble mou/gravité favorable) réengage plus vite que montée (charge en traction). La tempo
// palier se DÉDUIT de cet interlock (+100ms) : jamais besoin de resynchroniser deux réglages.
IF Direction = -1 THEN
    EffectiveDirectionInterlockDelay := DirectionInterlockDelayDescent;
ELSE
    EffectiveDirectionInterlockDelay := DirectionInterlockDelayAscent;
END_IF;
EffectiveStepDelay := EffectiveDirectionInterlockDelay + T#100ms;

IF Direction <> CommandedDirection THEN
    // 🆕 2026-08-07 (retour terrain) : démarrage depuis le neutre/arrêt (CommandedDirection = 0)
    // prise en compte IMMÉDIATE (0ms), pas de tempo interlock.
    // L'interlock DirectionChangeDelay (400ms descente / 900ms montée) ne s'applique QU'EN CAS
    // d'inversion active de sens en mouvement (ex: de -1 vers +1 direct).
    IF CommandedDirection = 0 THEN
        CommandedDirection := Direction;
        DirectionChangeDelay(IN := FALSE, PT := EffectiveDirectionInterlockDelay);
    ELSIF StepNumber = 0 THEN
        DirectionChangeDelay(IN := TRUE, PT := EffectiveDirectionInterlockDelay);
        IF DirectionChangeDelay.Q THEN
            CommandedDirection := Direction;
            DirectionChangeDelay(IN := FALSE, PT := EffectiveDirectionInterlockDelay);
        END_IF;
    ELSE
        DirectionChangeDelay(IN := FALSE, PT := EffectiveDirectionInterlockDelay);
    END_IF;
ELSE
    DirectionChangeDelay(IN := FALSE, PT := EffectiveDirectionInterlockDelay);
END_IF;
DirectionChangeDelayElapsed := DirectionChangeDelay.ET; // 🆕 2026-08-07 : diagnostic, miroir pur

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

// 🆕 2026-08-07 : ralentissement sur bordure (voir plus haut) — remplace l'ancien plafond en %
// par un plafond palier direct (CfgSlowdownMaxStep, défaut 1 = vitesse mini, réglable IHM),
// appliqué APRÈS le calcul normal ci-dessus via MIN (ne peut qu'abaisser, jamais relever le
// plafond déjà décidé par ailleurs — ex. CfgMaxStepDescente déjà plus restrictif).
IF InTopSlowdownZone OR InBottomSlowdownZone THEN
    ActiveMaxStep := MIN(ActiveMaxStep, CfgSlowdownMaxStep);
END_IF;

SpeedStep(Enable := (RampTargetPct > 0.1), SpeedRefPct := RampTargetPct,
          Table := SpeedStepTable, HystMargin := SpeedStepHystMargin,
          MaxStepNumber := ActiveMaxStep,
          MeasuredSpeedBand := MeasuredSpeedBand,
          SpeedGuardEnable := SpeedGuardEnable,
          SpeedGuardReady := SpeedGuardReady);
// 🪜 Tempo métier nominale : le décollage initial de StepNumber=0 vers 1 est IMMÉDIAT (0ms).
// Toute hausse ultérieure (1->2->3) exige EffectiveStepDelay (interlock + 100ms) et progresse par pas adjacents.
// Toute baisse reste immédiate pour ne jamais retarder un arrêt/safety.
RequestedStep := SpeedStep.StepNumber;
IF RequestedStep > StepNumber THEN
    IF StepNumber = 0 THEN
        StepNumber := 1;
        BusinessStepDelay(IN := FALSE, PT := EffectiveStepDelay);
        BusinessStepDelayElapsed := T#0ms;
    ELSE
        BusinessStepDelay(IN := TRUE, PT := EffectiveStepDelay);
        BusinessStepDelayElapsed := BusinessStepDelay.ET;
        IF BusinessStepDelay.Q THEN
            StepNumber := StepNumber + 1;
            BusinessStepDelay(IN := FALSE, PT := EffectiveStepDelay);
        END_IF;
    END_IF;
ELSE
    BusinessStepDelay(IN := FALSE, PT := EffectiveStepDelay);
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

// 🆕 2026-08-06 (retour terrain) : coupure INSTANTANÉE de tous les contacteurs de vitesse dès
// que l'opérateur relâche le joystick (Direction=0) — ne pas attendre la fin de la rampe de
// décélération. Avant ce correctif, StepNumber suivait la rampe (décélération progressive),
// gardant les contacteurs de vitesse engagés plusieurs secondes après l'ordre d'arrêt.
IF Direction = 0 THEN
    Contactor1 := FALSE; Contactor2 := FALSE; Contactor3 := FALSE; Contactor4 := FALSE;
END_IF;

// Le sens et la pré-magnétisation suivent la demande brute ; le palier métier
// temporisé reste seul transmis à l'interlock final pour autoriser la puissance.
// 🆕 2026-08-06 (retour terrain) : ET Direction=1/-1 (demande OPÉRATEUR brute, pas
// CommandedDirection qui reste au dernier sens jusqu'à la retombée de la rampe) — coupure
// instantanée du contacteur de sens dès le relâchement du joystick, même sécurité que ci-dessus.
// 🆕 2026-08-06 (retrait FB_Brake, demande client) : plus de terme BrakeSafetyOk — le frein
// n'est plus une condition d'engagement des relais de sens, c'est l'inverse (voir
// FB_WinchOutputInterlock_LD §6 : BrakeCmd := RelayFwd OR RelayRev, calculé APRÈS ces relais).
RelayFwd := (Direction = 1) AND (CommandedDirection = 1) AND (RequestedStep > 0);
RelayRev := (Direction = -1) AND (CommandedDirection = -1) AND (RequestedStep > 0);

IF ForbidDescent THEN
    RelayRev := FALSE;
END_IF;

IF ForbidAscent THEN
    RelayFwd := FALSE;
END_IF;

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
// 🆕 2026-08-06 (retrait FB_Brake) : bit0 ErrorId libre — le frein n'est plus surveillé
// ici, sa cohérence commande/retour vit désormais dans FB_WinchOutputInterlock_LD (BrakeFeedback).

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

IF (NOT StartStop OR EffectiveSafeStop OR DirectionChangePending) AND StepNumber > 0 THEN
    State := E_State.STOPPING;
ELSIF StepNumber > 0 THEN
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
END_IF;
