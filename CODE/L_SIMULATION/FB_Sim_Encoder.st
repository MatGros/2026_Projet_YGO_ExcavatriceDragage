(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_Encoder — Simulation physique d'un codeur absolu de treuil
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-13_Fonction_Simulation_v2.3.md
   🧩 Brique réduite (Partie3 §1bis, "briques E/S & diagnostics") : pas de contrat
      Enable/Reset/Error complet, pas de StartStop/SafeStop — outil de banc, pas
      du métier machine.
   🎯 Rôle : fait "compter" un codeur absolu comme si le treuil tournait
      réellement, à partir des relais de sens commandés et de la vitesse rampée
      courante.
   📥 Enable      : simulation active (SimulationModeActive AND NOT BusEncoderMxIsReal)
   📥 RelayFwd/RelayRev : sens commandé (contacteurs de sens du treuil)
   📥 SpeedRefPct : vitesse rampée courante (magnitude, %) — ex. instWinchM1.SpeedRamp.Current
   📥 PresetCmd   : TRUE le cycle où un preset (homing) doit être appliqué (PresettTrigCmd = 2)
   📥 PresetValue : valeur brute à charger lors du preset
   📥 SpeedScaleFactor : multiplicateur de vitesse simulation (confort de test
      banc uniquement, sans rapport avec une calibration réelle). Défaut 1.0 = comportement
      d'origine. Câblé sur GVL_Simulation.TstEncoderSpeedFactor (réglable à chaud, sans recompiler).
   📤 RawPosOut   : position brute simulée (UDINT), à aiguiller à la place de la valeur
      EtherCAT réelle quand le device n'est pas Operational (voir PRG_02_Encoders.st)
   `RawPos` en `VAR_IN_OUT`, référencé depuis `GVL_PERSISTENT`
      (même pattern que `Calib` dans `FB_Encoder_Homing`) — `PERSISTENT` n'est valide que sur du
      `VAR_GLOBAL` en CODESYS, pas sur une variable locale de FB. Un vrai codeur absolu physique
      conserve son comptage brut même à travers un reset FROID (indépendant de l'automate).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Sim_Encoder) ===

FUNCTION_BLOCK PUBLIC FB_Sim_Encoder
VAR_INPUT
    Enable           : BOOL;   (* --> [CMD] Active la simulation *)
    RelayFwd         : BOOL;   (* --> [HW] Sens commandé avant *)
    RelayRev         : BOOL;   (* --> [HW] Sens commandé arrière *)
    SpeedRefPct      : REAL;   (* --> [CMD] Vitesse rampée courante (%) *)
    PresetCmd        : BOOL;   (* --> [CMD] Applique un preset (homing) *)
    PresetValue      : UDINT;   (* --> [CFG] Valeur brute à charger au preset *)
    SpeedScaleFactor : REAL := 1.0;   (* --> [CFG] Confort de test, voir bandeau ci-dessus *)
    TestOffsetCmd    : BOOL;          (* --> [TST] Front montant = applique TestOffsetPts (test banc) *)
    TestOffsetPts    : DINT := 0;     (* --> [TST] Décalage signé à appliquer (points bruts) *)
END_VAR
VAR_OUTPUT
    RawPosOut   : UDINT;   (* <-- [DIAG] Position brute simulée *)
END_VAR
VAR_IN_OUT
    RawPos      : UDINT;   (* <-> [BUS] Référence _SimEncoderRawPosM1/M2 (survit au reset froid) *)
END_VAR
VAR
    Increment      : UDINT;              (* . [LOC] Évite de dupliquer le calcul 2x *)
    TestOffsetEdge : R_TRIG;             (* . [LOC] Front TestOffsetCmd *)
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Sim_Encoder) ===

{region "§1 Gate"}
IF NOT Enable THEN
    RawPosOut := RawPos;
    RETURN;
END_IF;
{endregion}

{region "§2 Injection test"}
// Injection test banc : VRAI saut de position (comme un glissement réel),
// pour tester Concept 1 / Méca E ET le rattrapage joystick (voir GVL_Simulation bandeau).
TestOffsetEdge(CLK := TestOffsetCmd);
IF TestOffsetEdge.Q THEN
    RawPos := DINT_TO_UDINT(UDINT_TO_DINT(RawPos) + TestOffsetPts);
END_IF;
{endregion}

{region "§3 Comptage"}
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
{endregion}

{region "§4 Sortie"}
RawPosOut := RawPos;
{endregion}
