(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_Joystick — Simulation des entrées brutes joystick (bus CAN hors ligne)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-13_Fonction_Simulation_v1.4.md
   🧩 Brique réduite (Partie3 §1bis) : outil de banc, pas du métier machine.
   🎯 Rôle : remplace l'ancien bypass homme-mort codé en dur dans `FB_Joystick`
      (`GVL_DEBUG.DBG_DeadmanBypass_TEST`, qui forçait `DeadmanArmed` en
      permanence — un vrai contournement de sécurité). Ici, on simule les
      ENTRÉES BRUTES du capteur (`RawX`/`RawY`/`RawButton`) : le homme-mort réel
      de `FB_Joystick` reste pleinement actif et doit toujours être "actionné"
      (forcer `RawButton` en instance CODESYS) pour armer — comportement
      métier testé pour de vrai, pas contourné.
   📥 Enable        : simulation active (SimulationModeActive AND NOT BusJoystickSignalIsReal) — 🔧 REX
      2026-07-08 : granularité séparée du bus CANopen (BusJoystickIsReal, voir GVL_Simulation)
   📥 NeutralRaw    : valeur brute simulée au repos (voir GVL_Simulation.TstJoystickForceNeutralRaw)
   📥 MaxRaw        : valeur brute simulée à fond (voir GVL_Simulation.TstJoystickForceMaxRaw)
   📤 RawX/RawY     : forçables en instance CODESYS (par défaut = NeutralRaw, repos)
   📤 RawButton     : forçable en instance CODESYS (par défaut = FALSE, relâché)
   💡 Note d'application : en vue instance CODESYS, forcer `RawX`/`RawY` à `MaxRaw` (ou une
      valeur intermédiaire) pour simuler un débattement, et `RawButton` à `TRUE` pour simuler
      l'appui homme-mort — exactement comme on forcerait le vrai capteur.
   🆕 REX 2026-07-19 : `TestOverrideActive` — pilotage programmatique par la suite PLC_TESTS
      (GVL_PLC_Tests), en complément du forçage manuel en instance CODESYS ci-dessus (les deux
      mécanismes coexistent, le Force IDE restant prioritaire de toute façon s'il est posé).
      Nécessaire car un Force CODESYS ne peut pas être déclenché depuis du code ST.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Sim_Joystick) ===

FUNCTION_BLOCK PUBLIC FB_Sim_Joystick
VAR_INPUT
    Enable      : BOOL;
    NeutralRaw  : INT := 5000;
    MaxRaw      : INT := 10000;
    TestOverrideActive   : BOOL; // 🆕 TRUE = RawX/Y/Button pilotés par TestOverrideRaw* (suite PLC_TESTS)
    TestOverrideRawX     : INT;
    TestOverrideRawY     : INT;
    TestOverrideRawButton : BOOL;
END_VAR
VAR_OUTPUT
    RawX        : INT;   // 🔧 Forçable en instance CODESYS (repos = NeutralRaw)
    RawY        : INT;   // 🔧 Forçable en instance CODESYS (repos = NeutralRaw)
    RawButton   : BOOL;  // 🔧 Forçable en instance CODESYS (repos = FALSE)
END_VAR
VAR
    FirstCycle  : BOOL := TRUE;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Sim_Joystick) ===

// 🔑 Initialise au neutre au premier cycle uniquement — ensuite RawX/RawY/RawButton
// restent forçables librement en instance CODESYS (un Force n'est jamais écrasé par TRUE,
// mais une simple écriture cyclique l'écraserait — donc pas de ré-assignation continue ici).
IF NOT Enable THEN
    FirstCycle := TRUE;
    RETURN;
END_IF;

IF TestOverrideActive THEN
    // 🆕 REX 2026-07-19 : suite PLC_TESTS — écriture CYCLIQUE volontaire (pas de FirstCycle),
    // contrairement au forçage manuel, pour permettre un pilotage dynamique scan par scan.
    RawX := TestOverrideRawX;
    RawY := TestOverrideRawY;
    RawButton := TestOverrideRawButton;
    FirstCycle := FALSE;
ELSIF FirstCycle THEN
    RawX := NeutralRaw;
    RawY := NeutralRaw;
    RawButton := FALSE;
    FirstCycle := FALSE;
END_IF;
