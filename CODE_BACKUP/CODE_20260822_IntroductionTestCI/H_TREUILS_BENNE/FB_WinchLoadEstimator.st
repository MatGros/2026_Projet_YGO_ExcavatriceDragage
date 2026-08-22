(* =======================================================================
   📊 FB_WinchLoadEstimator — Estimation empirique de charge treuil
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Estimation informative de la charge par croisement palier/vitesse
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md
   🔌 Interface : Brique de diagnostic/mesure (1 instance par treuil)
   🔒 Sécurité : Aucune commande moteur ni action sur SafeStop (information IHM)
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_WinchLoadEstimator
VAR_INPUT
    // === COMMANDES ET CONSIGNES ===
    Enable                          : BOOL;                           // --> [CMD] Autorisation generale FB
    Reset                           : BOOL;                           // --> [CMD] Acquittement defaut sur front
    Mode                            : E_Mode;                         // --> [CMD] Mode d'exploitation actif
    ActiveSpeedStep                 : INT;                            // --> [CMD] Palier commande actif (0..5)

    // === SECOURS ET HARDWARE ===
    PowerContactorEngaged           : BOOL;                           // --> [SAFE] Chaine AU rearmee et puissance OK
    MeasuredSpeedMps                : REAL;                           // --> [HW] Vitesse cable absolue (m/s)
    MeasuredSpeedSignedMps          : REAL;                           // --> [HW] Vitesse signee (+: montee, -: descente) (m/s)

    // === REGLAGES ET TABLES ===
    SpeedConfig                     : ST_WinchSpeedConfig;            // --> [CFG] Configuration des plages de vitesse
    LoadTable                       : ST_WinchLoadEstimateTable;      // --> [CFG] Table empirique d'estimation 5x5
END_VAR
VAR_OUTPUT
    // === ETATS IEC ET SYNOPTIQUE ===
    Ready                           : BOOL;                           // <-- [STAT] FB pret a fonctionner
    // 🧩 Statut transverse (forme cible) — regroupe Busy/Done/Error/ErrorId/State/StateAtError.
    // ErrorId bit0: "entrée/table invalide".
    Status                          : ST_FbStatus;

    // === DIAGNOSTICS ET ESTIMATIONS ===
    SpeedBand                       : INT;                            // <-- [DIAG] Bande de vitesse courante (0..5)
    EstimatedLoadPct                : REAL;                           // <-- [DIAG] Estimation de charge (0..100%)
    Configured                      : BOOL;                           // <-- [STAT] Table explicitement validee
    Ascending                       : BOOL;                           // <-- [STAT] Montee effective mesuree en cours
END_VAR
VAR
    // === DETECTEURS ET TIMERS INTERNES ===
    ResetEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Reset
    ErrorEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Erreur

    // === VARIABLES LOCALES CALCULÉES ===
    PreviousSpeedBand               : INT;                            // . [LOC] Memoire bande de vitesse cycle precedent
    HasPreviousBand                 : BOOL;                           // . [LOC] Indicateur premiere bande memorisee
    SelectedLoadPct                 : REAL;                           // . [LOC] Valeur de charge extraite de la table
END_VAR

{region "§1 Gate"}
// 🛑 1. GATE — aucune estimation lorsque le bloc est désactivé ou l'AU absent.
IF NOT Enable OR NOT PowerContactorEngaged THEN
    Ready := FALSE;
    Status.Busy := FALSE;
    Status.Done := FALSE;
    Status.Error := FALSE;
    Status.ErrorId := 16#0000;
    Status.State := E_State.DISABLED;
    SpeedBand := 0;
    EstimatedLoadPct := 0.0;
    Configured := FALSE;
    Ascending := FALSE;
    HasPreviousBand := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
Status.Busy := FALSE;
Status.Done := FALSE;
Status.State := E_State.READY;
ResetEdge(CLK := Reset);
Configured := LoadTable.IsConfigured;
// 📈 L'estimation de charge n'a de sens qu'en montée.
// La bande de vitesse reste calculée pour le diagnostic et le garde-fou de palier,
// mais EstimatedLoadPct est forcée à zéro à l'arrêt et en descente.
Ascending := (MeasuredSpeedSignedMps > 0.0);
{endregion}

{region "§2 Classement vitesse"}
// 📏 2. CLASSEMENT DE LA VITESSE — hystérésis autour des 4 frontières.
IF (MeasuredSpeedMps < 0.0) OR (SpeedConfig.MaxMeasuredSpeedMps <= 0.0) THEN
    Status.ErrorId := Status.ErrorId OR 16#0001;
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
        Status.ErrorId := Status.ErrorId OR 16#0001;
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
{endregion}

{region "§3 Lecture table"}
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
                            Status.ErrorId := Status.ErrorId OR 16#0001;
                        ELSE
                            EstimatedLoadPct := SelectedLoadPct;
                        END_IF;
                    END_IF;
                END_IF;
            END_IF;
        END_IF;
    END_IF;
END_IF;
{endregion}

{region "§4 Sorties et acquittement"}
// 📤 4. SORTIES D'ÉTAT ET ACQUITTEMENT.
IF ResetEdge.Q AND (Status.ErrorId <> 16#0000) AND (MeasuredSpeedMps >= 0.0) THEN
    Status.ErrorId := 16#0000;
END_IF;
Status.Error := (Status.ErrorId <> 16#0000);
ErrorEdge(CLK := Status.Error);
IF ErrorEdge.Q THEN
    Status.StateAtError := Status.State;
END_IF;
{endregion}
