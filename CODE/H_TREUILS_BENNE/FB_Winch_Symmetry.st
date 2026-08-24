(* =======================================================================
   ⚖️ FB_Winch_Symmetry — Mesure passive M1/M2
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Observateur de symétrie et de synchronisme des treuils M1/M2
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md
   🔒 Observateur pur : Aucune ecriture de commande, securite ou mouvement
   ======================================================================= *)

FUNCTION_BLOCK FB_Winch_Symmetry
VAR_INPUT
    // === COMMANDES ET CONSIGNES ===
    Reset                           : BOOL;                           // --> [CMD] Reinitialisation des mesures sur front
    M1CommandActive                 : BOOL;                           // --> [CMD] Commande active sur treuil M1
    M2CommandActive                 : BOOL;                           // --> [CMD] Commande active sur treuil M2
    M1Direction                     : INT;                            // --> [CMD] Sens commande M1 (-1/0/+1)
    M2Direction                     : INT;                            // --> [CMD] Sens commande M2 (-1/0/+1)

    // === FEEDBACKS HARWARE ET FREINS ===
    M1BrakeCmd                      : BOOL;                           // --> [HW] Ordre ouverture frein M1
    M2BrakeCmd                      : BOOL;                           // --> [HW] Ordre ouverture frein M2
    M1BrakeApplied                  : BOOL;                           // --> [HW] Etat frein M1 serre
    M2BrakeApplied                  : BOOL;                           // --> [HW] Etat frein M2 serre

    // === MESURES POSITIONS ET VITESSES ===
    M1Position_M                    : REAL;                           // --> [HW] Position mesuree M1 (m)
    M2Position_M                    : REAL;                           // --> [HW] Position mesuree M2 (m)
    M1Speed_Mps                     : REAL;                           // --> [HW] Vitesse mesuree M1 (m/s)
    M2Speed_Mps                     : REAL;                           // --> [HW] Vitesse mesuree M2 (m/s)
    SyncDeviation_M                 : REAL;                           // --> [HW] Ecart instantane synchro (m)

    // === CONFIGURATION ===
    Config                          : ST_Winch_SymmetryCfg;           // --> [CFG] Configuration des seuils de symetrie
END_VAR
VAR_OUTPUT
    // === ETATS IEC ET SYNOPTIQUE ===
    SymmetryOk                      : BOOL;                           // <-- [STAT] Symetrie globale conforme aux criteres
    SymmetryValid                   : BOOL;                           // <-- [STAT] Mesure de symetrie valide et calculee
END_VAR
VAR_IN_OUT
    // === STRUCTURES DE DONNÉES PARTAGÉES ===
    Data                            : ST_Winch_SymmetryData;          // <-> [BUS] Donnees de mesures de symetrie
END_VAR
VAR
    // === SOUS-INSTANCES FB ===
    ResetEdge                       : R_TRIG;                         // * [INST] Detecteur front reinitialisation
    CycleTime                       : FB_CycleTime;                   // * [INST] Calcul du temps de cycle

    // === TIMERS INTERNES ===
    CommandTon                      : TON;                            // . [LOC] Tempo qualification commande stable
    MotionTimer                     : TON;                            // . [LOC] Chronometre de mouvement
    StopTimer                       : TON;                            // . [LOC] Chronometre d'arret

    // === VARIABLES LOCALES CALCULÉES ===
    Comparable                      : BOOL;                           // . [LOC] Conditions de comparaison remplies
    Qualified                       : BOOL;                           // . [LOC] Phase de mesure qualifiee
    PreviousQualified               : BOOL;                           // . [LOC] Etat qualifie cycle precedent
    Stopping                        : BOOL;                           // . [LOC] Phase d'arret en cours
    StartCapturedM1                 : BOOL;                           // . [LOC] Top depart capture M1
    StartCapturedM2                 : BOOL;                           // . [LOC] Top depart capture M2
    StopCapturedM1                  : BOOL;                           // . [LOC] Top arret capture M1
    StopCapturedM2                  : BOOL;                           // . [LOC] Top arret capture M2
    StartMsM1                       : UDINT;                          // . [LOC] Horodatage d'ouverture M1 (ms)
    StartMsM2                       : UDINT;                          // . [LOC] Horodatage d'ouverture M2 (ms)
    ReleaseMsM1                     : UDINT;                          // . [LOC] Temps de desserrage frein M1 (ms)
    ReleaseMsM2                     : UDINT;                          // . [LOC] Temps de desserrage frein M2 (ms)
    ApplyMsM1                       : UDINT;                          // . [LOC] Temps de serrage frein M1 (ms)
    ApplyMsM2                       : UDINT;                          // . [LOC] Temps de serrage frein M2 (ms)
    StopMsM1                        : UDINT;                          // . [LOC] Horodatage d'arret M1 (ms)
    StopMsM2                        : UDINT;                          // . [LOC] Horodatage d'arret M2 (ms)
    StopStartM1_M                   : REAL;                           // . [LOC] Position debut d'arret M1 (m)
    StopStartM2_M                   : REAL;                           // . [LOC] Position debut d'arret M2 (m)
END_VAR

{region "§1 Reset et qualification"}
CycleTime(DefaultValueS := 0.010); ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN Data.DeltaStartDelay_Ms:=0; Data.DeltaBrakeReleaseTime_Ms:=0; Data.DeltaBrakeApplyTime_Ms:=0; Data.DeltaStopDistance_Mm:=0; Data.DeltaStopTime_Ms:=0; Data.MaxSyncDeviation_M:=0.0; END_IF;
Comparable := M1CommandActive AND M2CommandActive AND (M1Direction = M2Direction) AND (M1Direction <> 0);
CommandTon(IN := Comparable, PT := UDINT_TO_TIME(Config.MinimumCommandTime_Ms));
Qualified := CommandTon.Q AND (M1Speed_Mps >= Config.MinimumSpeed_Mps) AND (M2Speed_Mps >= Config.MinimumSpeed_Mps);
MotionTimer(IN := Comparable, PT := T#1h);
StopTimer(IN := Stopping, PT := T#1h);
IF NOT Comparable THEN StartCapturedM1:=FALSE; StartCapturedM2:=FALSE; ReleaseMsM1:=0; ReleaseMsM2:=0; ApplyMsM1:=0; ApplyMsM2:=0; END_IF;
IF Comparable AND (M1Speed_Mps >= Config.MinimumSpeed_Mps) AND NOT StartCapturedM1 THEN StartMsM1:=TIME_TO_UDINT(MotionTimer.ET); StartCapturedM1:=TRUE; END_IF;
IF Comparable AND (M2Speed_Mps >= Config.MinimumSpeed_Mps) AND NOT StartCapturedM2 THEN StartMsM2:=TIME_TO_UDINT(MotionTimer.ET); StartCapturedM2:=TRUE; END_IF;
{endregion}

{region "§2 Mesure symétrie"}
IF Qualified THEN
    IF M1BrakeCmd AND M1BrakeApplied THEN ReleaseMsM1 := ReleaseMsM1 + REAL_TO_UDINT(CycleTime.CycleTimeS * 1000.0); END_IF;
    IF M2BrakeCmd AND M2BrakeApplied THEN ReleaseMsM2 := ReleaseMsM2 + REAL_TO_UDINT(CycleTime.CycleTimeS * 1000.0); END_IF;
    IF NOT M1BrakeCmd AND NOT M1BrakeApplied THEN ApplyMsM1 := ApplyMsM1 + REAL_TO_UDINT(CycleTime.CycleTimeS * 1000.0); END_IF;
    IF NOT M2BrakeCmd AND NOT M2BrakeApplied THEN ApplyMsM2 := ApplyMsM2 + REAL_TO_UDINT(CycleTime.CycleTimeS * 1000.0); END_IF;
    IF SyncDeviation_M > Data.MaxSyncDeviation_M THEN Data.MaxSyncDeviation_M := SyncDeviation_M; END_IF;
END_IF;
IF PreviousQualified AND NOT Comparable THEN Stopping:=TRUE; StopCapturedM1:=FALSE; StopCapturedM2:=FALSE; StopStartM1_M:=M1Position_M; StopStartM2_M:=M2Position_M; END_IF;
IF Stopping THEN
    IF (M1Speed_Mps < Config.MinimumSpeed_Mps) AND NOT StopCapturedM1 THEN StopMsM1:=TIME_TO_UDINT(StopTimer.ET); StopCapturedM1:=TRUE; END_IF;
    IF (M2Speed_Mps < Config.MinimumSpeed_Mps) AND NOT StopCapturedM2 THEN StopMsM2:=TIME_TO_UDINT(StopTimer.ET); StopCapturedM2:=TRUE; END_IF;
    IF StopCapturedM1 AND StopCapturedM2 THEN
        Data.DeltaStartDelay_Ms := DINT_TO_UDINT(ABS(UDINT_TO_DINT(StartMsM1) - UDINT_TO_DINT(StartMsM2)));
        Data.DeltaBrakeReleaseTime_Ms := DINT_TO_UDINT(ABS(UDINT_TO_DINT(ReleaseMsM1) - UDINT_TO_DINT(ReleaseMsM2)));
        Data.DeltaBrakeApplyTime_Ms := DINT_TO_UDINT(ABS(UDINT_TO_DINT(ApplyMsM1) - UDINT_TO_DINT(ApplyMsM2)));
        Data.DeltaStopDistance_Mm := REAL_TO_UDINT(ABS(ABS(M1Position_M - StopStartM1_M) - ABS(M2Position_M - StopStartM2_M)) * 1000.0);
        Data.DeltaStopTime_Ms := DINT_TO_UDINT(ABS(UDINT_TO_DINT(StopMsM1) - UDINT_TO_DINT(StopMsM2))); Stopping := FALSE; SymmetryValid := TRUE;
    END_IF;
END_IF;
{endregion}

{region "§3 Sortie"}
SymmetryOk := SymmetryValid AND (Data.DeltaStartDelay_Ms<=Config.DeltaStartDelay_Ms) AND (Data.DeltaBrakeReleaseTime_Ms<=Config.DeltaBrakeReleaseTime_Ms) AND (Data.DeltaBrakeApplyTime_Ms<=Config.DeltaBrakeApplyTime_Ms) AND (Data.DeltaStopDistance_Mm<=Config.DeltaStopDistance_Mm) AND (Data.DeltaStopTime_Ms<=Config.DeltaStopTime_Ms);
PreviousQualified := Qualified;
{endregion}
