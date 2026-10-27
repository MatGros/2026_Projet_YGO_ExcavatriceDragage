(* DOC: DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
   Modele dynamique M3 confine au SimBench. *)
FUNCTION_BLOCK PUBLIC FB_Sim_Translation
VAR_INPUT
    Enable : BOOL;
    ReqTremie : BOOL;
    ReqMaintenance : BOOL;
    SpeedTgt_Pct : REAL;
    (* T361 — ECHELLE ODOMETRIQUE DU BANC, ALIGNEE SUR L'ESTIMATEUR REEL.
       Le modele integre VelocityTarget = (CST_PositionAtMaintenance / FullTravelTimeS) x f / 40.
       Le ratio simule vaut donc 30 / (40 x FullTravelTimeS) m/(Hz.s) et DOIT etre egal au gain
       consomme par FB_Translation_PositionEstimator (GainMetersPerHzSec, cable sur
       GVL_PERSISTENT._TranslationGainMetersPerHzSec = 0,02 m/(Hz.s), soit 1 m/s a 50 Hz).
       => 30 / (40 x 37,5) = 0,02 m/(Hz.s). La valeur historique 8,0 s donnait 0,09375 m/(Hz.s),
       soit 4,7 fois l'echelle reelle : l'estimateur prenait un retard constant et chaque
       franchissement de capteur produisait un saut de recalage de plusieurs metres
       (AUDIT_T360_TRACE_RATIO_ESTIMATEUR_M3_20260921.md, trace Suivi_74 : sauts de 4,53 a 9,12 m).
       ⚠️ Toute evolution de _TranslationGainMetersPerHzSec exige de recalculer cette constante :
       le gate G518 echoue si les deux echelles divergent. *)
    FullTravelTimeS : REAL := 37.5;
    BrakeReleaseCmd : BOOL := TRUE;
    AccelRate_HzPerS : REAL := 20.0;
    DecelRate_HzPerS : REAL := 20.0;
    DriveTimeConstantS : REAL := 0.15;
    BrakeOpenDelayS : REAL := 0.10;
    BrakeCloseDelayS : REAL := 0.09;
    BrakeContactDelayS : REAL := 0.01;
    (* FAUTE EXPLICITE frein M3 — defaut FALSE : reproduit le defaut terrain « frein ferme
       alors que le variateur retourne encore 10,00 Hz » (trace 2026-09-04, 26,437 s,
       State.ErrorId=64). La garde nominale 0,5 Hz du frein n'est pas modifiee. *)
    BrakeFaultCloseWhileRunning : BOOL := FALSE;
    BrakeFaultCloseDelay_S : REAL := 0.0;
    SuspendedLoadLength_M : REAL := 1.5;
    SuspendedLoadDamping : REAL := 0.35;
    LoadReactionGain_Mps2 : REAL := 0.20;
    (* BUTEE MECANIQUE — recul borne apres arret serre.
       0.0 (defaut) conserve EXACTEMENT le comportement historique : position ET vitesse
       figees a la butee (decision de review tracee, correctif « contact rigide »).
       > 0 : l'inertie du chariot reste absorbee par la butee, MAIS la reaction de la charge
       peut ressortir le chariot de la zone capteur — comportement observe sur la trace
       terrain du 2026-09-04 a 26,437 s (Tremie actif 1 echantillon puis perdu
       definitivement). Valeur SYNTHETIQUE, en attente de mesure terrain. *)
    EndStopRecoilMax_M : REAL := 0.0;
    LoadFrequencyDroopGain_Hz : REAL := 0.50;
    SensorJitterAmplitude_M : REAL := 0.01;
    SensorStabilizationS : REAL := 1.0;
    SensorElectricalDelayS : REAL := 0.01;
    SensorIntermittenceActive : BOOL := FALSE;
    SensorLoadAngleTriggerRad : REAL := 0.01;
    SensorScenarioSeed : UDINT := 3001;
    SensorHysteresis_M : REAL := 0.02;
    SensorIntermittencePeriodS : REAL := 0.12;
    (* BLIP COURT — second profil capteur, independant du train ~1 s ci-dessus.
       BlipTransitions = 0 (defaut) : profil historique strictement inchange.
       Valeurs de trace : Tremie 1 excursion de 0,2 s (2 echantillons a 100 ms),
       PV 1 excursion de 0,1 s (1 echantillon).
       ⚠️ LIMITE CONNUE (revue 2026-09-20, F11) : UNE SEULE largeur globale est appliquee aux
       cinq capteurs. Les deux signatures de la trace (Tremie 0,200 s et PV 0,100 s) ne sont
       donc PAS rejouables dans la meme passe : il faut deux executions avec des valeurs
       differentes de SensorBlipDurationS. Une largeur par capteur exigerait un
       ARRAY[1..5] OF REAL, non retenu dans ce lot. *)
    SensorBlipTransitions : UDINT := 0;
    SensorBlipDurationS : REAL := 0.2;
END_VAR
VAR_OUTPUT
    PosTremie : BOOL;
    PosPV : BOOL;
    PosP2 : BOOL;
    PosP1 : BOOL;
    PosMaintenance : BOOL;
    FrequencyCmd_Hz : REAL;
    ElectricalFrequency_Hz : REAL;
    ActualFrequency_Hz : REAL;
    BrakeCoilEnergized : BOOL;
    BrakeMechanicallyOpen : BOOL;
    BrakeContactOpen : BOOL;
    BrakeFaultCloseActive : BOOL;
    PositionTrue_M : REAL;
    VelocityTrue_Mps : REAL;
    LoadAngle_Rad : REAL;
    SensorPosition_M : REAL;
    SensorTransitionCount : UDINT;
    SensorBlipActive : BOOL;
    HardStopTremieActive : BOOL;
    HardStopMaintenanceActive : BOOL;
END_VAR
VAR
    instCycleTime : FB_CycleTime;
    Initialized : BOOL;
    DirectionSign : REAL;
    (* Sens de deplacement MEMORISE. La commande peut etre retiree AVANT l'arret physique
       (deceleration libre du variateur) : le sens du dernier ordre valide est conserve tant
       que le variateur retourne de la vitesse, puis purge a l'arret. Sans cette memoire, la
       vitesse du chariot s'effondrait au scan de retrait de commande alors que la frequence
       retournee decroit encore.
       ⚠️ ORDRE DE GRANDEUR NON MESURE : la trace terrain ne contient AUCUNE variable de
       position (15 TraceVariable : DI, frequences, mots d'etat, erreurs). La distance de
       roue libre de la fenetre 14,67 -> 16,16 s est donc une ESTIMATION dependante du modele
       d'echelle, qui vaut approximativement 1,1 a 1,3 m selon la methode d'integration
       retenue (gain audit 0,0551 m/(Hz.s)). A ne pas citer comme une mesure. *)
    TravelDirection : REAL;
    FrequencyTarget_Hz : REAL;
    CycleTimeS : REAL;
    SpeedAt40Hz_Mps : REAL;
    VelocityTarget_Mps : REAL;
    CartAcceleration_Mps2 : REAL;
    PreviousVelocity_Mps : REAL;
    PositionCandidate_M : REAL;
    (* Recul de butee ECRETE a la course : une valeur d'entree aberrante ne peut pas
       autoriser une position hors de [0 ; 30] m (revue du 2026-09-20, F8). *)
    RecoilMax_M : REAL;
    SensorNoiseState : REAL := 0.371;
    SensorNoise_M : REAL;
    instSensorTremie : FB_Sim_PositionSensor;
    instSensorPV : FB_Sim_PositionSensor;
    instSensorP2 : FB_Sim_PositionSensor;
    instSensorP1 : FB_Sim_PositionSensor;
    instSensorMaintenance : FB_Sim_PositionSensor;
    instDrive : FB_Sim_TranslationDrive;
    instBrake : FB_Sim_TranslationBrake;
    instSuspendedLoad : FB_Sim_SuspendedLoad;
END_VAR
VAR CONSTANT
    CST_PositionAtTremie : REAL := 0.0;
    (* Meme principe a Tremie : le seuil DI est legerement avant la butee afin
       que l'hysteresis puisse commuter sans depassement numerique de course. *)
    CST_PositionAtTremieSensor_M : REAL := 0.05;
    CST_PositionAtPV : REAL := 5.0;
    CST_PositionAtP2 : REAL := 15.0;
    CST_PositionAtP1 : REAL := 20.0;
    CST_PositionAtMaintenance : REAL := 30.0;
    (* Le capteur cumulatif Maintenance doit commuter avant la butee mecanique,
       sinon un modele borne a 30 m ne peut jamais produire le mot 00000. Cette
       position est SYNTHETIQUE en attente de la mesure de la came reelle. *)
    CST_PositionAtMaintenanceSensor_M : REAL := 29.95;
    CST_NominalFrequency_Hz : REAL := 40.0;
    CST_MinTimeS : REAL := 0.001;
    (* Meme seuil d'arret que FB_Sim_TranslationBrake.CST_StopFrequency_Hz (0,5 Hz).
       Valide par la trace terrain du 2026-09-04 : frein ouvert a 0,60 Hz, ferme a 0,00 Hz. *)
    CST_StopFrequency_Hz : REAL := 0.5;
END_VAR

instCycleTime(DefaultValueS := 0.010);
(* Le modele mono-pas suit le temps de cycle reel jusqu'a 100 ms. Cette borne
   evite de ralentir artificiellement la dynamique lorsque la trace est executee
   dans VISU_TASK (environ 100 ms), tout en restant stable pour le pendule reduit.
   Au-dela, FB_CycleTime fournit deja son temps de secours et aucun saut aberrant
   n'est accepte. La qualification des delais sub-100 ms exige toutefois une tache
   de trace plus rapide que 100 ms. *)
CycleTimeS := LIMIT(0.001, instCycleTime.CycleTimeS, 0.100);

IF NOT Enable THEN
    Initialized := FALSE;
    instDrive(Enable := FALSE);
    instBrake(Enable := FALSE);
    instSuspendedLoad(Enable := FALSE);
    FrequencyCmd_Hz := 0.0;
    ElectricalFrequency_Hz := 0.0;
    ActualFrequency_Hz := 0.0;
    BrakeMechanicallyOpen := FALSE;
    BrakeContactOpen := FALSE;
    BrakeCoilEnergized := FALSE;
    BrakeFaultCloseActive := FALSE;
    PositionTrue_M := CST_PositionAtP1;
    VelocityTrue_Mps := 0.0;
    PreviousVelocity_Mps := 0.0;
    TravelDirection := 0.0;
    LoadAngle_Rad := 0.0;
    SensorTransitionCount := 0;
    SensorBlipActive := FALSE;
    HardStopTremieActive := FALSE;
    HardStopMaintenanceActive := FALSE;
    (* Repli deterministe compatible avec le mot thermometre P1 = 00011. *)
    PosTremie := FALSE;
    PosPV := FALSE;
    PosP2 := FALSE;
    PosP1 := TRUE;
    PosMaintenance := TRUE;
    instSensorTremie(Enable := FALSE);
    instSensorPV(Enable := FALSE);
    instSensorP2(Enable := FALSE);
    instSensorP1(Enable := FALSE);
    instSensorMaintenance(Enable := FALSE);
    RETURN;
ELSIF NOT Initialized THEN
    Initialized := TRUE;
    PositionTrue_M := CST_PositionAtP1;
    TravelDirection := 0.0;
END_IF;

IF Enable THEN
    DirectionSign := 0.0;
    IF ReqTremie AND NOT ReqMaintenance THEN
        DirectionSign := -1.0;
    ELSIF ReqMaintenance AND NOT ReqTremie THEN
        DirectionSign := 1.0;
    END_IF;

    FrequencyTarget_Hz := LIMIT(0.0, ABS(SpeedTgt_Pct) * 0.4, CST_NominalFrequency_Hz);
    IF DirectionSign = 0.0 THEN
        FrequencyTarget_Hz := 0.0;
    END_IF;
    instDrive(Enable := TRUE, FrequencyTgt_Hz := FrequencyTarget_Hz,
        AccelRate_HzPerS := AccelRate_HzPerS, DecelRate_HzPerS := DecelRate_HzPerS,
        TimeConstant_S := DriveTimeConstantS,
        LoadAngularVelocity_RadPerS := instSuspendedLoad.AngularVelocity_RadPerS,
        LoadFrequencyDroopGain_Hz := LoadFrequencyDroopGain_Hz, CycleTime_S := CycleTimeS);
    FrequencyCmd_Hz := instDrive.FrequencyCmd_Hz;
    ElectricalFrequency_Hz := instDrive.ElectricalFrequency_Hz;
    ActualFrequency_Hz := instDrive.ActualFrequency_Hz;
    instBrake(Enable := TRUE, ReleaseCmd := BrakeReleaseCmd,
        ActualFrequency_Hz := ActualFrequency_Hz, OpenDelay_S := BrakeOpenDelayS,
        CloseDelay_S := BrakeCloseDelayS, ContactDelay_S := BrakeContactDelayS,
        CycleTime_S := CycleTimeS,
        FaultCloseWhileRunning := BrakeFaultCloseWhileRunning,
        FaultCloseDelay_S := BrakeFaultCloseDelay_S);
    BrakeCoilEnergized := instBrake.CoilEnergized;
    BrakeMechanicallyOpen := instBrake.MechanicallyOpen;
    BrakeContactOpen := instBrake.ContactOpen;
    BrakeFaultCloseActive := instBrake.FaultCloseActive;

    (* Sens memorise (C3). Regles, dans cet ordre :
       1. un ordre simple valide (re)memorise le sens ;
       2. deux ordres contradictoires neutralisent immediatement le sens — aucune
          excitation inventee (preserve TC-T300-MEC-030) ;
       3. commande retiree : le sens est CONSERVE tant que le variateur retourne de la
          vitesse (deceleration libre), puis purge des que la vitesse est nulle. *)
    IF ReqTremie AND NOT ReqMaintenance THEN
        TravelDirection := -1.0;
    ELSIF ReqMaintenance AND NOT ReqTremie THEN
        TravelDirection := 1.0;
    ELSIF ReqTremie AND ReqMaintenance THEN
        TravelDirection := 0.0;
    ELSIF ABS(ActualFrequency_Hz) <= CST_StopFrequency_Hz THEN
        TravelDirection := 0.0;
    END_IF;

    PreviousVelocity_Mps := VelocityTrue_Mps;
    IF (FullTravelTimeS > CST_MinTimeS) AND BrakeMechanicallyOpen THEN
        SpeedAt40Hz_Mps := CST_PositionAtMaintenance / FullTravelTimeS;
        VelocityTarget_Mps := TravelDirection * SpeedAt40Hz_Mps * ActualFrequency_Hz / CST_NominalFrequency_Hz;
    ELSE
        VelocityTarget_Mps := 0.0;
    END_IF;
    VelocityTrue_Mps := VelocityTrue_Mps + instDrive.ResponseAlpha * (VelocityTarget_Mps - VelocityTrue_Mps);
    IF NOT BrakeMechanicallyOpen THEN
        VelocityTrue_Mps := 0.0;
    END_IF;
    HardStopTremieActive := FALSE;
    HardStopMaintenanceActive := FALSE;
    PositionCandidate_M := PositionTrue_M + VelocityTrue_Mps * CycleTimeS;
    IF PositionCandidate_M < CST_PositionAtTremie THEN
        PositionTrue_M := CST_PositionAtTremie;
        VelocityTrue_Mps := 0.0;
        HardStopTremieActive := TRUE;
    ELSIF PositionCandidate_M > CST_PositionAtMaintenance THEN
        PositionTrue_M := CST_PositionAtMaintenance;
        VelocityTrue_Mps := 0.0;
        HardStopMaintenanceActive := TRUE;
    END_IF;
    CartAcceleration_Mps2 := (VelocityTrue_Mps - PreviousVelocity_Mps) / CycleTimeS;
    instSuspendedLoad(Enable := TRUE, BrakeMechanicallyOpen := BrakeMechanicallyOpen,
        CartAcceleration_Mps2 := CartAcceleration_Mps2, Length_M := SuspendedLoadLength_M,
        Damping := SuspendedLoadDamping, ReactionGain_Mps2 := LoadReactionGain_Mps2,
        CycleTime_S := CycleTimeS);
    LoadAngle_Rad := instSuspendedLoad.Angle_Rad;
    IF HardStopTremieActive OR HardStopMaintenanceActive THEN
        RecoilMax_M := MIN(MAX(0.0, EndStopRecoilMax_M), CST_PositionAtMaintenance);
        IF (RecoilMax_M > 0.0) AND BrakeMechanicallyOpen THEN
            (* Recul autorise UNIQUEMENT en s'eloignant de la butee touchee, borne par
               EndStopRecoilMax_M : jamais plus loin dans la butee, jamais de saut cache. *)
            VelocityTrue_Mps := VelocityTrue_Mps + instSuspendedLoad.VelocityReaction_Mps;
            (* Contre une butee, l'entrainement DECROCHE : il ne maintient pas une consigne de
               vitesse dans l'obstacle. Sans cette purge, la consigne de vitesse ecrasait en
               permanence la reaction de charge et le chariot ne pouvait jamais ressortir de
               la zone capteur (recul alors impossible, quelle que soit la charge). *)
            TravelDirection := 0.0;
            IF HardStopTremieActive THEN
                VelocityTrue_Mps := MAX(0.0, VelocityTrue_Mps);
                PositionCandidate_M := LIMIT(CST_PositionAtTremie,
                    PositionTrue_M + VelocityTrue_Mps * CycleTimeS,
                    CST_PositionAtTremie + RecoilMax_M);
            ELSE
                VelocityTrue_Mps := MIN(0.0, VelocityTrue_Mps);
                PositionCandidate_M := LIMIT(CST_PositionAtMaintenance - RecoilMax_M,
                    PositionTrue_M + VelocityTrue_Mps * CycleTimeS,
                    CST_PositionAtMaintenance);
            END_IF;
            PositionTrue_M := PositionCandidate_M;
        ELSE
            VelocityTrue_Mps := 0.0;
        END_IF;
    ELSE
        VelocityTrue_Mps := VelocityTrue_Mps + instSuspendedLoad.VelocityReaction_Mps;
        PositionCandidate_M := PositionTrue_M + VelocityTrue_Mps * CycleTimeS;
        IF PositionCandidate_M < CST_PositionAtTremie THEN
            PositionTrue_M := CST_PositionAtTremie;
            VelocityTrue_Mps := 0.0;
            HardStopTremieActive := TRUE;
        ELSIF PositionCandidate_M > CST_PositionAtMaintenance THEN
            PositionTrue_M := CST_PositionAtMaintenance;
            VelocityTrue_Mps := 0.0;
            HardStopMaintenanceActive := TRUE;
        ELSE
            PositionTrue_M := PositionCandidate_M;
        END_IF;
    END_IF;
END_IF;

IF Enable AND (ABS(LoadAngle_Rad) > 0.0001) THEN
    SensorNoiseState := 3.91 * SensorNoiseState * (1.0 - SensorNoiseState);
    SensorNoise_M := (2.0 * SensorNoiseState - 1.0) * SensorJitterAmplitude_M;
ELSE
    SensorNoise_M := 0.0;
END_IF;
(* Les capteurs sont fixes au rail et observent le chariot. Le balancier agit
   seulement par la reaction mecanique sur PositionTrue_M et conditionne un
   episode electrique ; aucune deflexion de godet n'est injectee directement. *)
SensorPosition_M := PositionTrue_M + SensorNoise_M;
(* Les capteurs M3 sont volontairement cumulatifs : 11111 -> 00000. Chaque
   brique garde son hysteresis et son episode propres ; aucun timer partage ne
   peut masquer un front d'un autre capteur. *)
instSensorTremie(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := CST_PositionAtTremieSensor_M, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 11,
    BlipTransitions := SensorBlipTransitions, BlipDurationS := SensorBlipDurationS,
    CycleTimeS := CycleTimeS);
instSensorPV(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := CST_PositionAtPV, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 23,
    BlipTransitions := SensorBlipTransitions, BlipDurationS := SensorBlipDurationS,
    CycleTimeS := CycleTimeS);
instSensorP2(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := CST_PositionAtP2, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 37,
    BlipTransitions := SensorBlipTransitions, BlipDurationS := SensorBlipDurationS,
    CycleTimeS := CycleTimeS);
instSensorP1(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := CST_PositionAtP1, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 53,
    BlipTransitions := SensorBlipTransitions, BlipDurationS := SensorBlipDurationS,
    CycleTimeS := CycleTimeS);
instSensorMaintenance(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := CST_PositionAtMaintenanceSensor_M, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 71,
    BlipTransitions := SensorBlipTransitions, BlipDurationS := SensorBlipDurationS,
    CycleTimeS := CycleTimeS);

PosTremie := instSensorTremie.ElectricalOutput;
PosPV := instSensorPV.ElectricalOutput;
PosP2 := instSensorP2.ElectricalOutput;
PosP1 := instSensorP1.ElectricalOutput;
PosMaintenance := instSensorMaintenance.ElectricalOutput;
SensorTransitionCount := instSensorTremie.TransitionCount + instSensorPV.TransitionCount
    + instSensorP2.TransitionCount + instSensorP1.TransitionCount
    + instSensorMaintenance.TransitionCount;
SensorBlipActive := instSensorTremie.BlipActive OR instSensorPV.BlipActive
    OR instSensorP2.BlipActive OR instSensorP1.BlipActive
    OR instSensorMaintenance.BlipActive;
