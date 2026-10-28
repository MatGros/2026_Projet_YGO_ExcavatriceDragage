(* DOC: DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md
   Modele dynamique M3 confine au SimBench. *)
FUNCTION_BLOCK PUBLIC FB_Sim_Translation
VAR_INPUT
    Enable : BOOL;
    ReqTremie : BOOL;
    ReqMaintenance : BOOL;
    SpeedTgt_Pct : REAL;
    (* T301/L1 — SOURCE UNIQUE : le banc ne porte AUCUNE position ni echelle propre.
       Positions capteurs = reglages machine (GVL_PERSISTENT._TranslationPos*_M) et gain =
       gain EFFECTIVEMENT consomme par l'estimateur (PRG_05 FB_Translation_OdometryGain.GainActive),
       passes par PRG_02 -> FB_SimBench. Vitesse chariot = sens x gain x frequence.
       Historique : l'ancienne echelle en dur (30 m / FullTravelTimeS / 40 Hz) a diverge du gain
       reel (T360/T361, sauts de 4 a 9 m) — doublon supprime, gate G518 anti-retour. *)
    PosTremie_M        : REAL := 0.0;   (* --> [CFG] Position capteur Tremie (m) *)
    PosPV_M            : REAL := 1.5;   (* --> [CFG] Position capteur PV (m) *)
    PosP2_M            : REAL := 3.5;   (* --> [CFG] Position capteur P2 (m) *)
    PosP1_M            : REAL := 5.0;   (* --> [CFG] Position capteur P1 (m) *)
    PosMaintenance_M   : REAL := 10.0;  (* --> [CFG] Position capteur Maintenance (m) *)
    GainMetersPerHzSec : REAL := 0.02;  (* --> [CFG] Gain odometrique effectif, m/(Hz.s) *)
    (* Distance capteur extreme -> butee mecanique (seule donnee propre au banc : physique du rail).
       Bornee a CST_MinEndStopMargin_M pour que le capteur extreme reste franchissable. *)
    EndStopMargin_M    : REAL := 0.5;
    BrakeReleaseCmd : BOOL := TRUE;
    (* ECHELLE DE LA CONSIGNE. PRG_02 envoie SpeedCmd_Pct = f / 50 Hz x 100 : le simulateur reconvertit
       avec le MEME maximum, sinon 20 Hz reels (40 %) deviendraient 16 Hz simules.
       Maximum = GVL_PERSISTENT._TranslationMaxFreq_Hz (50 Hz), passe par FB_SimBench (CST_M3MaxFreq_Hz,
       egalite verifiee par G518). Ne pas confondre avec l'ancienne echelle (40 Hz) : echelle
       ODOMETRIQUE (gain 0,02 m/(Hz.s)). *)
    MaxFreq_Hz : REAL := 50.0;
    (* ACCELERATION DU BANC (confort d'essai). Le chariot avance SpeedFactor fois plus vite ET la
       frequence RETOURNEE au PLC est multipliee d'autant : l'estimateur (f x gain) suit exactement
       le chariot, sans saut de recalage, et le ratio publie reste 0,02 m/(Hz.s) (G518).
       Borne 1..5. 1,0 = dynamique reelle. Le frein et la memoire de sens restent sur la frequence
       physique du variateur simule. *)
    SpeedFactor : REAL := 1.0;
    AccelRate_HzPerS : REAL := 20.0;
    DecelRate_HzPerS : REAL := 25.0; // pente d'arret relevee sur trace reelle (rampe variateur / rampe PLC)
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
    SpeedFactorApplied : REAL := 1.0;
    CycleTimeS : REAL;
    EndStopTremie_M : REAL;       (* butee mecanique cote Tremie = capteur Tremie - marge *)
    EndStopMaintenance_M : REAL;  (* butee mecanique cote Maintenance = capteur Maintenance + marge *)
    VelocityTarget_Mps : REAL;
    CartAcceleration_Mps2 : REAL;
    PreviousVelocity_Mps : REAL;
    PositionCandidate_M : REAL;
    (* Recul de butee ECRETE a la course : une valeur d'entree aberrante ne peut pas
       autoriser une position hors des butees (revue du 2026-09-20, F8). *)
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
    (* Marge mini capteur extreme -> butee : au-dela de l'hysteresis capteur, sinon le mot
       11111 / 00000 ne pourrait jamais etre produit (capteur colle a la butee). *)
    CST_MinEndStopMargin_M : REAL := 0.05;
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

(* Butees mecaniques derivees des capteurs extremes (reglages machine) + marge du rail. *)
EndStopTremie_M := PosTremie_M - MAX(EndStopMargin_M, CST_MinEndStopMargin_M);
EndStopMaintenance_M := PosMaintenance_M + MAX(EndStopMargin_M, CST_MinEndStopMargin_M);

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
    PositionTrue_M := PosP1_M;
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
    PositionTrue_M := PosP1_M;
    TravelDirection := 0.0;
END_IF;

IF Enable THEN
    DirectionSign := 0.0;
    IF ReqTremie AND NOT ReqMaintenance THEN
        DirectionSign := -1.0;
    ELSIF ReqMaintenance AND NOT ReqTremie THEN
        DirectionSign := 1.0;
    END_IF;

    FrequencyTarget_Hz := LIMIT(0.0, ABS(SpeedTgt_Pct) * MaxFreq_Hz / 100.0, MaxFreq_Hz);
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
    SpeedFactorApplied := LIMIT(1.0, SpeedFactor, 5.0);
    ActualFrequency_Hz := instDrive.ActualFrequency_Hz * SpeedFactorApplied;
    instBrake(Enable := TRUE, ReleaseCmd := BrakeReleaseCmd,
        ActualFrequency_Hz := instDrive.ActualFrequency_Hz, OpenDelay_S := BrakeOpenDelayS,
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
    ELSIF ABS(instDrive.ActualFrequency_Hz) <= CST_StopFrequency_Hz THEN
        TravelDirection := 0.0;
    END_IF;

    PreviousVelocity_Mps := VelocityTrue_Mps;
    IF BrakeMechanicallyOpen THEN
        (* Source unique : meme gain que l'estimateur machine (vitesse = gain x frequence). *)
        VelocityTarget_Mps := TravelDirection * MAX(0.0, GainMetersPerHzSec) * ActualFrequency_Hz;
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
    IF PositionCandidate_M < EndStopTremie_M THEN
        PositionTrue_M := EndStopTremie_M;
        VelocityTrue_Mps := 0.0;
        HardStopTremieActive := TRUE;
    ELSIF PositionCandidate_M > EndStopMaintenance_M THEN
        PositionTrue_M := EndStopMaintenance_M;
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
        RecoilMax_M := MIN(MAX(0.0, EndStopRecoilMax_M), EndStopMaintenance_M - EndStopTremie_M);
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
                PositionCandidate_M := LIMIT(EndStopTremie_M,
                    PositionTrue_M + VelocityTrue_Mps * CycleTimeS,
                    EndStopTremie_M + RecoilMax_M);
            ELSE
                VelocityTrue_Mps := MIN(0.0, VelocityTrue_Mps);
                PositionCandidate_M := LIMIT(EndStopMaintenance_M - RecoilMax_M,
                    PositionTrue_M + VelocityTrue_Mps * CycleTimeS,
                    EndStopMaintenance_M);
            END_IF;
            PositionTrue_M := PositionCandidate_M;
        ELSE
            VelocityTrue_Mps := 0.0;
        END_IF;
    ELSE
        VelocityTrue_Mps := VelocityTrue_Mps + instSuspendedLoad.VelocityReaction_Mps;
        PositionCandidate_M := PositionTrue_M + VelocityTrue_Mps * CycleTimeS;
        IF PositionCandidate_M < EndStopTremie_M THEN
            PositionTrue_M := EndStopTremie_M;
            VelocityTrue_Mps := 0.0;
            HardStopTremieActive := TRUE;
        ELSIF PositionCandidate_M > EndStopMaintenance_M THEN
            PositionTrue_M := EndStopMaintenance_M;
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
    Threshold_M := PosTremie_M, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 11,
    BlipTransitions := SensorBlipTransitions, BlipDurationS := SensorBlipDurationS,
    CycleTimeS := CycleTimeS);
instSensorPV(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := PosPV_M, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 23,
    BlipTransitions := SensorBlipTransitions, BlipDurationS := SensorBlipDurationS,
    CycleTimeS := CycleTimeS);
instSensorP2(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := PosP2_M, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 37,
    BlipTransitions := SensorBlipTransitions, BlipDurationS := SensorBlipDurationS,
    CycleTimeS := CycleTimeS);
instSensorP1(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := PosP1_M, Hysteresis_M := SensorHysteresis_M,
    ElectricalDelayS := SensorElectricalDelayS, IntermittenceActive := SensorIntermittenceActive
        AND (ABS(LoadAngle_Rad) >= SensorLoadAngleTriggerRad),
    IntermittenceDurationS := SensorStabilizationS, IntermittencePeriodS := SensorIntermittencePeriodS,
    ScenarioSeed := SensorScenarioSeed + 53,
    BlipTransitions := SensorBlipTransitions, BlipDurationS := SensorBlipDurationS,
    CycleTimeS := CycleTimeS);
instSensorMaintenance(Enable := Enable, Position_M := SensorPosition_M,
    Threshold_M := PosMaintenance_M, Hysteresis_M := SensorHysteresis_M,
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
