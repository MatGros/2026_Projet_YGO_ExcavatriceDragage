(* ═══════════════════════════════════════════════════════════════
   🎯 FB_Translation_OdometryGain — Coefficient odométrique M3 réglable sur site (T301)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-11_Fonction_Translation_v2.4.md §4 (cotes & ratio odométrique, T301)
      Procédure site : DOC/WFLOW/CONTRACTS/PROCEDURE_CALIBRATION_ODOMETRIE_M3_T301.md
   🎯 Rôle :
      1. GAIN ACTIF = |PosP2 - PosPV| / (CalibFreq × CalibTime), réglages saisis par l'exploitant.
         Réglage absent, incohérent ou hors plage plausible -> REPLI sur FallbackGain
         (CalibValid = FALSE indique quelle source est active).
      2. MESURE PROPOSÉE (jamais appliquée) : entre le 1er front P2 et le 1er front PV, dans les
         deux sens, le FB mesure le temps, la fréquence moyenne, l'écart min/max de fréquence et le
         gain qui en résulterait. L'exploitant recopie LUI-MÊME temps et fréquence dans les réglages.
   🛡️ Sécurité : aucune. Diagnostic/estimation uniquement — la position estimée ne pilote aucun arrêt.
   🧩 Dépendances : FB_CycleTime. Consommateur : FB_Translation_PositionEstimator (PRG_05).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Translation_OdometryGain
VAR_INPUT
    Enable                : BOOL;          // --> [CMD] Active la mesure proposée (le gain actif est toujours calculé)
    SensorPV              : BOOL;          // --> [HW]  Capteur PV (mot thermomètre : TRUE côté Trémie)
    SensorP2              : BOOL;          // --> [HW]  Capteur P2 (mot thermomètre : TRUE côté Trémie)
    DriveActualFreq_Hz    : REAL;          // --> [HW]  Fréquence de sortie réelle du variateur (Hz)
    PosPV_M               : REAL := 1.5;   // --> [CFG] Position capteur PV (m)
    PosP2_M               : REAL := 3.5;   // --> [CFG] Position capteur P2 (m)
    CalibFreq_Hz          : REAL := 50.0;  // --> [CFG] Fréquence stable pendant la mesure saisie (Hz)
    CalibTime_S           : REAL := 2.0;   // --> [CFG] Temps P2 <-> PV saisi (s) — 2,0 = défaut cohérent avec 0,02 ; 0 -> repli
    FallbackGain          : REAL := 0.02;  // --> [CFG] Gain de repli, m/(Hz.s)
END_VAR
VAR_OUTPUT
    GainActive            : REAL;          // <-- [STAT] Gain consommé par l'estimateur, m/(Hz.s)
    CalibValid            : BOOL;          // <-- [STAT] TRUE = gain calculé depuis le réglage Calib* (défaut compris) ; FALSE = repli actif
    MeasureActive         : BOOL;          // <-- [DIAG] Mesure P2 <-> PV en cours
    MeasuredTime_S        : REAL;          // <-- [DIAG] Dernier temps mesuré entre les 2 fronts (s)
    MeasuredFreqAvg_Hz    : REAL;          // <-- [DIAG] Fréquence moyenne pendant la dernière mesure (Hz)
    MeasuredFreqSpread_Hz : REAL;          // <-- [DIAG] Écart max - min de fréquence (stabilité de la mesure)
    MeasuredGain          : REAL;          // <-- [DIAG] Gain que donnerait la dernière mesure, m/(Hz.s) — proposé, jamais appliqué
    MeasureCount          : UDINT;         // <-- [DIAG] Nombre de mesures abouties depuis le démarrage
END_VAR
VAR
    CycleTimeCalc         : FB_CycleTime;  // * [INST] Mesure temps de cycle
    EdgeUpP2              : R_TRIG;        // . [LOC] Front montant P2 (départ vers Trémie)
    EdgeDnP2              : F_TRIG;        // . [LOC] Front descendant P2 (fin vers Maintenance)
    EdgeUpPV              : R_TRIG;        // . [LOC] Front montant PV (fin vers Trémie)
    EdgeDnPV              : F_TRIG;        // . [LOC] Front descendant PV (départ vers Maintenance)
    DistanceP2PV_M        : REAL;          // . [LOC] Distance P2 - PV (m), > 0 si positions ordonnées
    CalibGain             : REAL;          // . [LOC] Gain calculé depuis le réglage site
    MeasureTowardTremie   : BOOL;          // . [LOC] Sens de la mesure en cours (TRUE = départ P2 montant)
    ElapsedS              : REAL;          // . [LOC] Temps écoulé de la mesure en cours (s)
    FreqIntegral_HzS      : REAL;          // . [LOC] Somme fréquence × temps de la mesure en cours (Hz.s)
    FreqMin_Hz            : REAL;          // . [LOC] Fréquence mini pendant la mesure en cours
    FreqMax_Hz            : REAL;          // . [LOC] Fréquence maxi pendant la mesure en cours
    FreqSample_Hz         : REAL;          // . [LOC] Fréquence bornée du scan courant
    MeasureEnd            : BOOL;          // . [LOC] Front de fin attendu observé ce scan
END_VAR
VAR CONSTANT
    CST_GainMin           : REAL := 0.005; // Plage plausible du gain (m/(Hz.s)) : hors plage -> repli
    CST_GainMax           : REAL := 0.05;
    CST_MeasureMinFreq_Hz : REAL := 1.0;   // Sous ce seuil la mesure est abandonnée (arrêt en cours de mesure)
    CST_MeasureTimeout_S  : REAL := 60.0;  // Au-delà la mesure est abandonnée
    CST_FreqMax_Hz        : REAL := 600.0; // Borne de la fréquence lue
END_VAR

// === IMPLEMENTATION ===

{region "§1 Gain actif (toujours calculé — réglage pur, indépendant d'Enable)"}
DistanceP2PV_M := PosP2_M - PosPV_M;
IF (DistanceP2PV_M > 0.0) AND (CalibFreq_Hz > 0.0) AND (CalibTime_S > 0.0) THEN
    CalibGain := DistanceP2PV_M / (CalibFreq_Hz * CalibTime_S);
    CalibValid := (CalibGain >= CST_GainMin) AND (CalibGain <= CST_GainMax);
ELSE
    CalibGain := 0.0;
    CalibValid := FALSE;
END_IF;

IF CalibValid THEN
    GainActive := CalibGain;
ELSE
    // Repli borné : un repli nul/aberrant figerait l'estimateur (et le chariot simulé).
    GainActive := LIMIT(CST_GainMin, FallbackGain, CST_GainMax);
END_IF;
{endregion}

{region "§2 Gate mesure"}
// Fronts évalués à chaque scan, y compris hors Enable : aucun front périmé à la réactivation.
EdgeUpP2(CLK := SensorP2);   EdgeDnP2(CLK := SensorP2);
EdgeUpPV(CLK := SensorPV);   EdgeDnPV(CLK := SensorPV);

IF NOT Enable THEN
    MeasureActive := FALSE;
    RETURN;
END_IF;

CycleTimeCalc(DefaultValueS := 0.010);
FreqSample_Hz := LIMIT(0.0, DriveActualFreq_Hz, CST_FreqMax_Hz);
{endregion}

{region "§3 Mesure proposée P2 <-> PV (jamais appliquée)"}
// Mot thermomètre (TRUE si position <= cote) :
//   vers la Trémie      : P2 monte puis PV monte ;
//   vers la Maintenance : PV descend puis P2 descend.
// Seul le 1er front compte : les rebonds du capteur de départ (vu -> perdu -> retrouvé) sont
// ignorés une fois la mesure lancée ; la mesure ne se termine que sur le front ATTENDU.
IF NOT MeasureActive THEN
    IF EdgeUpP2.Q OR EdgeDnPV.Q THEN
        MeasureActive := TRUE;
        MeasureTowardTremie := EdgeUpP2.Q;
        ElapsedS := 0.0;
        FreqIntegral_HzS := 0.0;
        FreqMin_Hz := FreqSample_Hz;
        FreqMax_Hz := FreqSample_Hz;
    END_IF;
ELSE
    ElapsedS := ElapsedS + CycleTimeCalc.CycleTimeS;
    FreqIntegral_HzS := FreqIntegral_HzS + FreqSample_Hz * CycleTimeCalc.CycleTimeS;
    FreqMin_Hz := MIN(FreqMin_Hz, FreqSample_Hz);
    FreqMax_Hz := MAX(FreqMax_Hz, FreqSample_Hz);

    MeasureEnd := (MeasureTowardTremie AND EdgeUpPV.Q) OR (NOT MeasureTowardTremie AND EdgeDnP2.Q);

    IF MeasureEnd THEN
        MeasureActive := FALSE;
        MeasuredTime_S := ElapsedS;
        MeasuredFreqSpread_Hz := FreqMax_Hz - FreqMin_Hz;
        IF ElapsedS > 0.0 THEN
            MeasuredFreqAvg_Hz := FreqIntegral_HzS / ElapsedS;
        ELSE
            MeasuredFreqAvg_Hz := 0.0;
        END_IF;
        IF (FreqIntegral_HzS > 0.0) AND (DistanceP2PV_M > 0.0) THEN
            MeasuredGain := DistanceP2PV_M / FreqIntegral_HzS;
        ELSE
            MeasuredGain := 0.0;
        END_IF;
        MeasureCount := MeasureCount + 1;
    ELSIF (FreqSample_Hz < CST_MeasureMinFreq_Hz) OR (ElapsedS > CST_MeasureTimeout_S) THEN
        // Arrêt ou trajet interrompu : mesure abandonnée, dernier résultat publié conservé.
        MeasureActive := FALSE;
    END_IF;
END_IF;
{endregion}

END_FUNCTION_BLOCK
