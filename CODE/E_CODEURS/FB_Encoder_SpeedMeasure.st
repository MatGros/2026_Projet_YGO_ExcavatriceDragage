(* =======================================================================
   ⚙️ FB_Encoder_SpeedMeasure — Mesure de vitesse câble horodatée
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Calcul de la vitesse câble double mesure (Brute instantanée + Filtrée)
   ⚙️ Différenciation : ΔPosition / dt réel issu de FB_CycleTime
   🌊 Lissage : Filtre PT1 (FB_Filter) pour la sortie standard lissée
   🛡️ Sans bornage : zéro clamping artificiel
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Encoder_SpeedMeasure
VAR_INPUT
    // === COMMANDES & AUTORISATIONS ===
    Enable              : BOOL;        // --> [CMD] Autorisation generale FB (TRUE=Autorise)
    Reset               : BOOL;        // --> [CMD] Purge immediate de l'historique (front montant)

    // === MESURE SURES EN ENTREE ===
    Position_M          : REAL;        // --> [HW]  Position cable sure en metres (FB_Encoder_Safety)
    PositionValid       : BOOL;        // --> [SAFE] Validite de la chaine codeur
    FilterTimeConst     : TIME := T#100MS; // --> [CFG] Constante de temps du filtre PT1
END_VAR
VAR_OUTPUT
    // === VITESSE PRINCIPALE (FILTRÉE) ===
    Speed_Mps           : REAL;        // <-- [DIAG] Vitesse absolue filtree PT1 (m/s)
    SignedSpeed_Mps     : REAL;        // <-- [DIAG] Vitesse signee filtree PT1 (+ montee, - descente) (m/s)
    Valid               : BOOL;        // <-- [STAT] Validite mesure (TRUE si codeur operationnel et premier cycle passe)

    // === VITESSE BRUTE INSTANTANÉE (SCAN-PAR-SCAN, SANS FILTRE, NON BORNÉE) ===
    RawSpeed_Mps        : REAL;        // <-- [DIAG] Vitesse absolue instantanee brute (m/s)
    RawSignedSpeed_Mps  : REAL;        // <-- [DIAG] Vitesse signee instantanee brute (m/s)
END_VAR
VAR
    // === SOUS-INSTANCES ===
    instCycleTime       : FB_CycleTime; // * [INST] Mesure du dt reel par scan (tache 20ms)
    instFilter          : FB_Filter;    // * [INST] Filtre PT1 pour la mesure lissée

    // === MEMOIRES & DETECTEURS ===
    PrevPosition_M      : REAL;         // . [LOC] Position du scan precedent
    FirstScanDone       : BOOL;         // . [LOC] Drapeau d'initialisation premier cycle
    ResetEdge           : R_TRIG;       // . [LOC] Detecteur front montant Reset
END_VAR

{region "§1 Gestion du temps & Gate de neutralisation"}
ResetEdge(CLK := Reset);
instCycleTime(DefaultValueS := 0.020); // Tache PRG_02_Acquisition = 20ms

// Purge immediate sur perte de confiance ou Reset
IF NOT Enable OR ResetEdge.Q OR NOT PositionValid THEN
    Speed_Mps          := 0.0;
    SignedSpeed_Mps    := 0.0;
    RawSpeed_Mps       := 0.0;
    RawSignedSpeed_Mps := 0.0;
    Valid              := FALSE;
    FirstScanDone      := FALSE;
    PrevPosition_M     := Position_M;
    RETURN;
END_IF;
{endregion}

{region "§2 Initialisation premier scan"}
IF NOT FirstScanDone THEN
    PrevPosition_M := Position_M;
    FirstScanDone  := TRUE;
    Valid          := FALSE;
    Speed_Mps          := 0.0;
    SignedSpeed_Mps    := 0.0;
    RawSpeed_Mps       := 0.0;
    RawSignedSpeed_Mps := 0.0;
    RETURN;
END_IF;
{endregion}

{region "§3 Calcul vitesse brute instantanee"}
IF instCycleTime.CycleTimeS > 0.0 THEN
    RawSignedSpeed_Mps := (Position_M - PrevPosition_M) / instCycleTime.CycleTimeS;
    RawSpeed_Mps       := ABS(RawSignedSpeed_Mps);
    Valid              := TRUE;
END_IF;
PrevPosition_M := Position_M;
{endregion}

{region "§4 Filtrage PT1 pour sortie lissée"}
instFilter(
    ValueIn    := RawSignedSpeed_Mps,
    TimeConst  := FilterTimeConst,
    CycleTimeS := instCycleTime.CycleTimeS
);

SignedSpeed_Mps := instFilter.ValueOut;
Speed_Mps       := ABS(SignedSpeed_Mps);
{endregion}
