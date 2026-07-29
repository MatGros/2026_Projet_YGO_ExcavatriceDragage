(* ═══════════════════════════════════════════════════════════════════════════════
   📊 FB_WinchLoadEstimator — Estimation empirique de charge treuil
   ═══════════════════════════════════════════════════════════════════════════════
   🧩 Brique de diagnostic/information, sans commande moteur et sans SafeStop.
   🎯 Croise le palier commandé et la bande de vitesse mesurée pour lire une
      estimation dans ST_WinchLoadEstimateTable.
   ⚠️ La table doit être explicitement marquée IsConfigured : sinon la sortie
      reste à 0 % et Configured reste FALSE.
   ═══════════════════════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-09_Fonction_Winch_v1.14.md
*)

FUNCTION_BLOCK PUBLIC FB_WinchLoadEstimator
VAR_INPUT
    Enable             : BOOL;
    Reset              : BOOL;
    EmergencyStopOk    : BOOL;
    Mode               : E_Mode;
    ActiveSpeedStep    : INT;                       // Palier commandé 0..5
    MeasuredSpeedMps   : REAL;                      // Vitesse câble absolue
    MeasuredSpeedSignedMps : REAL;                  // Vitesse signée : positive = montée, négative = descente
    SpeedConfig        : ST_WinchSpeedConfig;       // Plages vitesse mesurée
    LoadTable          : ST_WinchLoadEstimateTable;// Table empirique 5x5
END_VAR
VAR_OUTPUT
    Ready              : BOOL;
    Busy               : BOOL;
    Done               : BOOL;
    Error              : BOOL;
    ErrorId            : WORD;                     // bit0 : entrée/table invalide
    State              : E_State;
    StateAtError       : E_State;
    SpeedBand          : INT;                      // Bande vitesse courante 0..5
    EstimatedLoadPct   : REAL;                     // Estimation informative 0..100 %
    Configured         : BOOL;                     // TRUE si table explicitement validée
    Ascending          : BOOL;                     // TRUE uniquement pendant une montée mesurée
END_VAR
VAR
    ResetEdge          : R_TRIG;
    ErrorEdge          : R_TRIG;
    PreviousSpeedBand  : INT;
    HasPreviousBand    : BOOL;
    SelectedLoadPct    : REAL;
END_VAR

// 🛑 1. GATE — aucune estimation lorsque le bloc est désactivé ou l'AU absent.
IF NOT Enable OR NOT EmergencyStopOk THEN
    Ready := FALSE;
    Busy := FALSE;
    Done := FALSE;
    Error := FALSE;
    ErrorId := 16#0000;
    State := E_State.DISABLED;
    SpeedBand := 0;
    EstimatedLoadPct := 0.0;
    Configured := FALSE;
    Ascending := FALSE;
    HasPreviousBand := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
Busy := FALSE;
Done := FALSE;
State := E_State.READY;
ResetEdge(CLK := Reset);
Configured := LoadTable.IsConfigured;
// 📈 WINCH-CORE-01 : l'estimation de charge n'a de sens qu'en montée.
// La bande de vitesse reste calculée pour le diagnostic et le garde-fou de palier,
// mais EstimatedLoadPct est forcée à zéro à l'arrêt et en descente.
Ascending := (MeasuredSpeedSignedMps > 0.0);

// 📏 2. CLASSEMENT DE LA VITESSE — hystérésis autour des 4 frontières.
IF (MeasuredSpeedMps < 0.0) OR (SpeedConfig.MaxMeasuredSpeedMps <= 0.0) THEN
    ErrorId := ErrorId OR 16#0001;
    SpeedBand := 0;
ELSIF NOT HasPreviousBand THEN
    IF MeasuredSpeedMps <= SpeedConfig.SpeedBandMaxMps[1] THEN
        PreviousSpeedBand := 1;
    ELSIF MeasuredSpeedMps <= SpeedConfig.SpeedBandMaxMps[2] THEN
        PreviousSpeedBand := 2;
    ELSIF MeasuredSpeedMps <= SpeedConfig.SpeedBandMaxMps[3] THEN
        PreviousSpeedBand := 3;
    ELSIF MeasuredSpeedMps <= SpeedConfig.SpeedBandMaxMps[4] THEN
        PreviousSpeedBand := 4;
    ELSE
        PreviousSpeedBand := 5;
    END_IF;
    HasPreviousBand := TRUE;
    SpeedBand := PreviousSpeedBand;
ELSE
    // 🔒 Valider l'état mémorisé avant toute indexation dynamique.
    IF PreviousSpeedBand < 1 OR PreviousSpeedBand > 5 THEN
        PreviousSpeedBand := 1;
        ErrorId := ErrorId OR 16#0001;
    END_IF;

    // CODESYS ne garantit pas le court-circuit des expressions AND :
    // chaque borne est donc testée dans une branche séparée avant accès.
    IF PreviousSpeedBand < 5 THEN
        IF MeasuredSpeedMps > (SpeedConfig.SpeedBandMaxMps[PreviousSpeedBand]
                               + SpeedConfig.SpeedBandHysteresisMps) THEN
            PreviousSpeedBand := PreviousSpeedBand + 1;
        END_IF;
    END_IF;
    IF PreviousSpeedBand > 1 THEN
        IF MeasuredSpeedMps < (SpeedConfig.SpeedBandMaxMps[PreviousSpeedBand - 1]
                               - SpeedConfig.SpeedBandHysteresisMps) THEN
            PreviousSpeedBand := PreviousSpeedBand - 1;
        END_IF;
    END_IF;
    SpeedBand := PreviousSpeedBand;
END_IF;

// 📊 3. LECTURE TABLE — bornes séparées avant l'accès au tableau 5x5.
EstimatedLoadPct := 0.0;
IF Configured THEN
    IF Ascending THEN
        IF ActiveSpeedStep >= 1 THEN
            IF ActiveSpeedStep <= 5 THEN
                IF SpeedBand >= 1 THEN
                    IF SpeedBand <= 5 THEN
                        SelectedLoadPct := LoadTable.LoadPctByStepAndSpeedBand[ActiveSpeedStep][SpeedBand];
                        IF (SelectedLoadPct < 0.0) OR (SelectedLoadPct > 100.0) THEN
                            ErrorId := ErrorId OR 16#0001;
                        ELSE
                            EstimatedLoadPct := SelectedLoadPct;
                        END_IF;
                    END_IF;
                END_IF;
            END_IF;
        END_IF;
    END_IF;
END_IF;

// 📤 4. SORTIES D'ÉTAT ET ACQUITTEMENT.
IF ResetEdge.Q AND (ErrorId <> 16#0000) AND (MeasuredSpeedMps >= 0.0) THEN
    ErrorId := 16#0000;
END_IF;
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;
