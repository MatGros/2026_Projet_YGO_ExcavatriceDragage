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
      `SafeStop`). ⚠️ ÉVOLUTION D72 (2026-07-03vicies, voir plus bas) :
      `RelayFwd` (montée) toujours piloté normalement, mais `ForbidDescent`
      déclenche maintenant une vraie décélération rapide dès qu'on n'est PAS
      en train de remonter — voir DOC/AF_Partie9 §4ter pour le contexte
      d'origine, et l'entrée D72 ci-dessous pour le comportement actuel.
   🆕 AJOUT (2026-07-03quinquies, retour terrain — limitation couple en descente) :
      nouveau paramètre `MaxStepDescente` (défaut 2). En descente
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
    ForbidAscent            : BOOL;
    Direction               : INT;
    SpeedRefPct             : REAL;
    SpeedStepTable          : ST_SpeedStepTable;
    MaxStepDescente         : INT := 2;    // 🆕 Plafond palier en descente (CommandedDirection=-1) — couple, pas vitesse
    ContactorFeedbackFwd    : BOOL;
    ContactorFeedbackRev    : BOOL;
    BrakeFeedback           : BOOL;
    BypassContactorCheck    : BOOL;   // 🧪 TRUE = désactive StuckClosed/StuckOpen (axe simulé,
                                       // voir GVL_Simulation.ContactorFeedbackMx_IsReal — TOUJOURS FALSE réel)
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
    Homed                   : BOOL;             // 🆕 État de référencement du treuil
    CablePosM               : REAL;             // 🆕 Position actuelle du câble en mètres
    TopLimitM               : REAL := 12.5;     // 🆕 Position limite haute active (cible homing, m)
    BottomLimitM            : REAL := -20.0;    // 🆕 Position limite basse active (m)
    SlowdownDistanceM       : REAL := 1.0;      // 🆕 Distance d'approche avant limite pour ralentir (m)
    SlowSpeedPct            : REAL := 15.0;     // 🆕 Consigne de vitesse lente dans la zone de ralentissement (%)
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
    EffectiveSafeStop   : BOOL;   // 🆕 2026-07-03vicies — SafeStop réel OU (ForbidDescent hors montée)
END_VAR
