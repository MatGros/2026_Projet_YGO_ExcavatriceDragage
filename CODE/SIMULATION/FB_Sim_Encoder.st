(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_Encoder — Simulation physique d'un codeur absolu de treuil
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-13/AF_Partie-13_Fonction_Simulation_v2.0.md
   🧩 Brique réduite (Partie3 §1bis, "briques E/S & diagnostics") : pas de contrat
      Enable/Reset/Error complet, pas de StartStop/SafeStop — outil de banc, pas
      du métier machine.
   🎯 Rôle : fait "compter" un codeur absolu comme si le treuil tournait
      réellement, à partir des relais de sens commandés et de la vitesse rampée
      courante. Extraction PURE de la logique déjà en place dans
      `PRG_02_Encoders.st` (bloc "SIMULATION SUR BANC DE TEST") — aucun
      changement de comportement, juste la dissociation en FB dédié.
   📥 Enable      : simulation active (SimulationModeActive AND NOT BusEncoderMxIsReal)
   📥 RelayFwd/RelayRev : sens commandé (contacteurs de sens du treuil)
   📥 SpeedRefPct : vitesse rampée courante (magnitude, %) — ex. instWinchM1.SpeedRamp.Current
   📥 PresetCmd   : TRUE le cycle où un preset (homing) doit être appliqué (PresettTrigCmd = 2)
   📥 PresetValue : valeur brute à charger lors du preset
   📥 SpeedScaleFactor : 🔧 REX 2026-07-07 — multiplicateur de vitesse simulation (confort de test
      banc uniquement, sans rapport avec une calibration réelle). Défaut 1.0 = comportement
      d'origine. Câblé sur GVL_Simulation.TstEncoderSpeedFactor (réglable à chaud, sans recompiler).
   📤 RawPosOut   : position brute simulée (UDINT), à aiguiller à la place de la valeur
      EtherCAT réelle quand le device n'est pas Operational (voir PRG_02_Encoders.st)
   🔧 REX 2026-07-08 : `RawPos` déplacé en `VAR_IN_OUT`, référencé depuis `GVL_PERSISTENT`
      (même pattern que `Calib` dans `FB_Encoder_Homing`) — `PERSISTENT` n'est valide que sur du
      `VAR_GLOBAL` en CODESYS, pas sur une variable locale de FB (tenté en `VAR RETAIN` puis
      `VAR PERSISTENT RETAIN` locaux, aucun des deux ne convient). Un vrai codeur absolu physique
      conserve son comptage brut même à travers un reset FROID (indépendant de l'automate) —
      il fallait donc bien du PERSISTENT RETAIN réel, regroupé avec le reste dans GVL_PERSISTENT.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Sim_Encoder) ===

FUNCTION_BLOCK PUBLIC FB_Sim_Encoder
VAR_INPUT
    Enable           : BOOL;
    RelayFwd         : BOOL;
    RelayRev         : BOOL;
    SpeedRefPct      : REAL;
    PresetCmd        : BOOL;
    PresetValue      : UDINT;
    SpeedScaleFactor : REAL := 1.0;   // 🔧 REX 2026-07-07 — confort de test, voir bandeau ci-dessus
    TestOffsetCmd    : BOOL;          // 🆕 REX 2026-07-08 (4) — front montant = applique TestOffsetPts (test banc)
    TestOffsetPts    : DINT := 0;     // 🆕 REX 2026-07-08 (4) — décalage signé à appliquer (points bruts)
END_VAR
VAR_OUTPUT
    RawPosOut   : UDINT;
END_VAR
VAR_IN_OUT
    RawPos      : UDINT;   // 🔧 REX 2026-07-08 : référence _SimEncoderRawPosM1/M2 (survit au reset froid)
END_VAR
VAR
    Increment      : UDINT;              // 🔧 REX 2026-07-07 — évite de dupliquer le calcul 2x
    TestOffsetEdge : R_TRIG;             // 🆕 REX 2026-07-08 (4)
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Sim_Encoder) ===

IF NOT Enable THEN
    RawPosOut := RawPos;
    RETURN;
END_IF;

// 🆕 REX 2026-07-08 (4) — injection test banc : VRAI saut de position (comme un glissement réel),
// pour tester Concept 1 / Méca E ET le rattrapage joystick (voir GVL_Simulation bandeau).
TestOffsetEdge(CLK := TestOffsetCmd);
IF TestOffsetEdge.Q THEN
    RawPos := DINT_TO_UDINT(UDINT_TO_DINT(RawPos) + TestOffsetPts);
END_IF;

Increment := REAL_TO_UDINT(SpeedRefPct * 0.1 * SpeedScaleFactor);

IF PresetCmd THEN
    RawPos := PresetValue;
ELSIF RelayFwd THEN
    RawPos := RawPos + Increment;
ELSIF RelayRev THEN
    IF RawPos >= Increment THEN
        RawPos := RawPos - Increment;
    ELSE
        RawPos := 0;
    END_IF;
END_IF;

RawPosOut := RawPos;
