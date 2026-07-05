(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_Encoder — Simulation physique d'un codeur absolu de treuil
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie13_Fonction_Simulation_v1.0.md
   🧩 Brique réduite (Partie3 §1bis, "briques E/S & diagnostics") : pas de contrat
      Enable/Reset/Error complet, pas de StartStop/SafeStop — outil de banc, pas
      du métier machine.
   🎯 Rôle : fait "compter" un codeur absolu comme si le treuil tournait
      réellement, à partir des relais de sens commandés et de la vitesse rampée
      courante. Extraction PURE de la logique déjà en place dans
      `PRG_02_Encoders.st` (bloc "SIMULATION SUR BANC DE TEST") — aucun
      changement de comportement, juste la dissociation en FB dédié.
   📥 Enable      : simulation active (SimulationModeActive AND NOT EncoderMx_IsReal)
   📥 RelayFwd/RelayRev : sens commandé (contacteurs de sens du treuil)
   📥 SpeedRefPct : vitesse rampée courante (magnitude, %) — ex. instWinchM1.SpeedRamp.Current
   📥 PresetCmd   : TRUE le cycle où un preset (homing) doit être appliqué (PresettTrigCmd = 2)
   📥 PresetValue : valeur brute à charger lors du preset
   📤 RawPosOut   : position brute simulée (UDINT), à aiguiller à la place de la valeur
      EtherCAT réelle quand le device n'est pas Operational (voir PRG_02_Encoders.st)
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Sim_Encoder) ===

FUNCTION_BLOCK PUBLIC FB_Sim_Encoder
VAR_INPUT
    Enable      : BOOL;
    RelayFwd    : BOOL;
    RelayRev    : BOOL;
    SpeedRefPct : REAL;
    PresetCmd   : BOOL;
    PresetValue : UDINT;
END_VAR
VAR_OUTPUT
    RawPosOut   : UDINT;
END_VAR
VAR
    RawPos      : UDINT := 1000000;   // Valeur médiane arbitraire (même défaut que l'ancien SimulatedMxRaw)
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Sim_Encoder) ===

IF NOT Enable THEN
    RawPosOut := RawPos;
    RETURN;
END_IF;

IF PresetCmd THEN
    RawPos := PresetValue;
ELSIF RelayFwd THEN
    RawPos := RawPos + REAL_TO_UDINT(SpeedRefPct * 0.1);
ELSIF RelayRev THEN
    IF RawPos >= REAL_TO_UDINT(SpeedRefPct * 0.1) THEN
        RawPos := RawPos - REAL_TO_UDINT(SpeedRefPct * 0.1);
    ELSE
        RawPos := 0;
    END_IF;
END_IF;

RawPosOut := RawPos;
