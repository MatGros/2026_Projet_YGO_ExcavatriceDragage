(* ═══════════════════════════════════════════════════════════════
   🧪 FB_Sim_Encoder — Simulation physique d'un codeur absolu de treuil
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
   🧩 Brique réduite (Partie3 §1bis, "briques E/S & diagnostics") : pas de contrat
      Enable/Reset/Error complet, pas de StartStop/SafeStop — outil de banc, pas
      du métier machine.
   🎯 Rôle : fait "compter" un codeur absolu comme si le treuil tournait
      réellement, à partir des relais de sens commandés et du palier de vitesse courant.
   📥 Enable      : simulation active (SimulationModeActive AND NOT BusEncoderMxIsReal)
   📥 RelayFwd/RelayRev : sens commandé (contacteurs de sens du treuil)
   📥 StepNumber  : palier vitesse courant (1..5) — ex. instWinchM1.StepNumber
      Vitesse = interpolation linéaire : palier 1 → MinSpeedMps (1 m/s), palier 5 → MaxSpeedMps (2 m/s).
   📥 PresetCmd   : TRUE le cycle où un preset (homing) doit être appliqué (PresettTrigCmd = 2)
   📥 PresetValue : valeur brute à charger lors du preset
   📥 SpeedScaleFactor : facteur fin de confort (réglable à chaud, sans recompiler). Défaut 1.0 = vitesse
      réelle telle que définie par MinSpeedMps/MaxSpeedMps/PointsPerRev/CableM_PerRev/CycleTimeS.
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
    StepNumber       : INT;    (* --> [CMD] Palier vitesse courant (1..5, 0 = arrêt) *)
    PresetCmd        : BOOL;   (* --> [CMD] Applique un preset (homing) *)
    PresetValue      : UDINT;   (* --> [CFG] Valeur brute à charger au preset *)
    SpeedScaleFactor : REAL := 1.0;   (* --> [CFG] Facteur fin de confort (défaut 1.0) *)
    CoastDistanceM   : REAL := 0.0;   (* --> [CFG] Distance de roulis inertiel apres coupure des relais (m). 0 = arret net (defaut). >0 = le treuil continue a vitesse palier 1 dans le dernier sens sur CoastDistanceM metres -> modelise l'anticipation d'arret mecanique (ex. benne). *)
    PresetLatencyCycles : INT := 3;   (* --> [CFG] Nb cycles automate avant application du preset (referencement non instantane) *)
    TestOffsetCmd    : BOOL;          (* --> [TST] Front montant = applique TestOffsetPts (test banc) *)
    TestOffsetPts    : DINT := 0;     (* --> [TST] Décalage signé à appliquer (points bruts) *)
    // 📐 Paramètres physiques du treuil (mêmes valeurs que FB_Encoder_Scale) + vitesse réelle.
    // Vitesse simulée = interpolation linéaire du palier : palier 1 → MinSpeedMps, palier 5 → MaxSpeedMps.
    MinSpeedMps      : REAL := 1.0;    (* --> [CFG] Vitesse palier 1 (m/s) *)
    MaxSpeedMps      : REAL := 2.0;    (* --> [CFG] Vitesse palier 5 (m/s) *)
    PointsPerRev     : UDINT := 8192;  (* --> [CFG] Résolution codeur (pts/tour) *)
    CableM_PerRev    : REAL := 2.0;    (* --> [CFG] Développement câble (m/tour) *)
    CycleTimeS       : REAL := 0.010;  (* --> [CFG] Période tâche PLC (s) — MainTask 10 ms *)
END_VAR
VAR_OUTPUT
    RawPosOut   : UDINT;   (* <-- [DIAG] Position brute simulée *)
END_VAR
VAR_IN_OUT
    RawPos      : UDINT;   (* <-> [BUS] Référence _SimEncoderRawPosM1/M2 (survit au reset froid) *)
END_VAR
VAR
    Increment      : UDINT;              (* . [LOC] Points ajoutés par cycle *)
    EffStep        : INT;               (* . [LOC] Pas borné (>= 1) *)
    SpeedMps       : REAL;              (* . [LOC] Vitesse simulée (m/s) *)
    TestOffsetEdge : R_TRIG;             (* . [LOC] Front TestOffsetCmd *)
    PresetEdge     : R_TRIG;             (* . [LOC] Front montant PresetCmd *)
    PresetPending  : BOOL;               (* . [LOC] Preset en attente d'application (latence) *)
    PresetCount    : INT;                (* . [LOC] Compteur cycles de latence restants *)
    IncrStep1      : UDINT;              (* . [LOC] Increment par cycle a vitesse palier 1 (pour le roulis) *)
    MovingDir      : INT;                (* . [LOC] Dernier sens actif : +1 avant, -1 arriere, 0 arret *)
    CoastPtsLeft   : REAL;               (* . [LOC] Roulis inertiel restant (points bruts) *)
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
// 🎚️ Vitesse simulée = interpolation linéaire du palier (palier 1 → MinSpeedMps, palier 5 → MaxSpeedMps),
// pas par pas de (Max−Min)/4. Palier 0 (arrêt) ramène au palier 1 mais aucun mouvement n'est
// appliqué tant que RelayFwd/RelayRev = FALSE (section plus bas).
EffStep  := MAX(StepNumber, 1);
SpeedMps := MinSpeedMps + (INT_TO_REAL(EffStep) - 1.0) * ((MaxSpeedMps - MinSpeedMps) / 4.0);
// Points par cycle = vitesse (m/s) × points par mètre × période tâche (s) × facteur confort.
Increment := REAL_TO_UDINT(SpeedMps * (UDINT_TO_REAL(PointsPerRev) / CableM_PerRev) * CycleTimeS * SpeedScaleFactor);
// Increment "lent" (palier 1) : vitesse du roulis inertiel apres coupure des relais.
IncrStep1 := REAL_TO_UDINT(MinSpeedMps * (UDINT_TO_REAL(PointsPerRev) / CableM_PerRev) * CycleTimeS * SpeedScaleFactor);

// Front du preset : lance la latence de referencement (le codeur réel n'est pas
// instantane — il met PresetLatencyCycles cycles a se re-referencer apres le front).
PresetEdge(CLK := PresetCmd);
IF PresetEdge.Q THEN
    PresetPending := TRUE;
    PresetCount := PresetLatencyCycles;
END_IF;

// Pendant l'attente, la position brute est conservee (le codeur n'a pas encore re-reference).
// Le mouvement est gelé pendant la latence, comme un codeur réel en cours de referencement.
IF PresetPending THEN
    IF PresetCount > 0 THEN
        PresetCount := PresetCount - 1;
    ELSE
        // Latence écoulée : applique la valeur cible du preset.
        RawPos := PresetValue;
        PresetPending := FALSE;
    END_IF;
ELSIF RelayFwd THEN
    RawPos := RawPos + Increment;
    MovingDir := 1;
    CoastPtsLeft := CoastDistanceM * (UDINT_TO_REAL(PointsPerRev) / CableM_PerRev);
ELSIF RelayRev THEN
    IF RawPos >= Increment THEN
        RawPos := RawPos - Increment;
    ELSE
        RawPos := 0;
    END_IF;
    MovingDir := -1;
    CoastPtsLeft := CoastDistanceM * (UDINT_TO_REAL(PointsPerRev) / CableM_PerRev);
ELSE
    // Relais coupes : roulis inertiel (anticipation d'arret mecanique). Le treuil
    // continue a vitesse palier 1 dans le dernier sens jusqu'a epuisement de CoastPtsLeft.
    IF (CoastPtsLeft >= 1.0) AND (MovingDir <> 0) THEN
        IF MovingDir = 1 THEN
            RawPos := RawPos + IncrStep1;
        ELSIF RawPos >= IncrStep1 THEN
            RawPos := RawPos - IncrStep1;
        ELSE
            RawPos := 0;
        END_IF;
        CoastPtsLeft := CoastPtsLeft - UDINT_TO_REAL(IncrStep1);
    ELSE
        MovingDir := 0;
        CoastPtsLeft := 0.0;
    END_IF;
END_IF;
{endregion}

{region "§4 Sortie"}
RawPosOut := RawPos;
{endregion}
