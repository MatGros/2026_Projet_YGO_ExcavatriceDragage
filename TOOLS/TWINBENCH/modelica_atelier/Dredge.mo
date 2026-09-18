within ;
package Dredge "Plante hors ligne de dragage : aucune logique PLC ni safety"
  record M3Commands "Commandes finales PLC vers la plante M3 [CMD]"
    Boolean cmdMoveToTremie "Commande finale vers Trémie";
    Boolean cmdMoveToMaintenance "Commande finale vers Maintenance";
    Real cmdSpeed_Pct "Commande finale de vitesse, 0..100 %";
    Boolean cmdBrakeRelease "Commande finale de desserrage du frein";
  end M3Commands;

  record M3Configuration "Paramètres de construction/calibration M3 [CFG]"
    Real travel_M=30 "Course Trémie à Maintenance";
    Real fullTravelTime_S=8 "Temps SimBench historique à 100 %";
    Real nominalFrequency_Hz=40 "Référence SimBench historique, à calibrer";
    Real brakeOpenDelay_S=.10 "Hypothèse SimBench, à mesurer";
    Real brakeCloseDelay_S=.09 "Hypothèse SimBench, à mesurer";
    Real sensorHysteresis_M=.02 "Hypothèse SimBench, à mesurer";
  end M3Configuration;

  record M3Measurements "Grandeurs physiques calculées M3 [HW/Measurement]"
    Real positionAct_M "Position chariot, 0=Trémie";
    Real velocityAct_Mps(start=0, fixed=true) "Vitesse chariot";
    Real frequencyAct_Hz "Fréquence effective simulée";
  end M3Measurements;

  record M3DiscreteFeedback "Images TOR simulées M3 [HW/DiscreteFeedback]"
    Boolean brakeIsOpen "TRUE = frein physiquement ouvert";
    Boolean tremiePositionIsActive "TRUE = capteur Trémie actif";
    Boolean pvPositionIsActive "TRUE = capteur PV actif";
    Boolean p2PositionIsActive "TRUE = capteur P2 actif";
    Boolean p1PositionIsActive "TRUE = capteur P1 actif";
    Boolean maintenancePositionIsActive "TRUE = capteur Maintenance actif";
  end M3DiscreteFeedback;

  record M3DeviceState "Etat du variateur M3 [HW/DeviceState]"
    Integer driveStatusWord "Image AC600 : 128 arrêt, 135 mouvement";
  end M3DeviceState;

  record M3Diagnostics "Diagnostics M3 non autorisants [DIAG]"
    Boolean commandConflict "Deux directions finales actives";
    Boolean hardStopTremie "Commande vers butée Trémie";
    Boolean hardStopMaintenance "Commande vers butée Maintenance";
  end M3Diagnostics;

  record WinchCommands "Commandes finales M1/M2 vers la plante [CMD]"
    Boolean cmdM1Forward;
    Boolean cmdM1Reverse;
    Integer cmdM1SpeedStep "Palier PLC 0..5";
    Boolean cmdM1BrakeRelease;
    Boolean cmdM1SpeedContactor1;
    Boolean cmdM1SpeedContactor2;
    Boolean cmdM1SpeedContactor3;
    Boolean cmdM1SpeedContactor4;
    Boolean cmdM2Forward;
    Boolean cmdM2Reverse;
    Integer cmdM2SpeedStep "Palier PLC 0..5";
    Boolean cmdM2BrakeRelease;
    Boolean cmdM2SpeedContactor1;
    Boolean cmdM2SpeedContactor2;
    Boolean cmdM2SpeedContactor3;
    Boolean cmdM2SpeedContactor4;
  end WinchCommands;

  record WinchConfiguration "Paramètres de construction/calibration M1/M2 [CFG]"
    Real minSpeed_Mps=1 "Hypothèse SimBench palier 1";
    Real maxSpeed_Mps=2 "Hypothèse SimBench palier 5";
    Real cablePerRevolution_M=2 "A confirmer sur tambours machine";
    Real encoderPointsPerRevolution=8192 "Codeur actuel";
    Real encoderM1InitialRaw=1000000;
    Real encoderM2InitialRaw=1100000;
    Real brakeOpenDelay_S=.10 "A mesurer";
    Real brakeCloseDelay_S=.10 "A mesurer";
    Real coastTime_S=.35 "Equivalent provisoire roulis SimBench";
    Real bucketClosedDelta_M=15 "A calibrer avec mouflage/benne";
  end WinchConfiguration;

  record WinchMeasurements "Grandeurs physiques calculées M1/M2 [HW/Measurement]"
    Real m1CablePositionAct_M(start=0, fixed=true);
    Real m2CablePositionAct_M(start=0, fixed=true);
    Real m1VelocityAct_Mps(start=0, fixed=true);
    Real m2VelocityAct_Mps(start=0, fixed=true);
    Real encoderM1PositionRaw;
    Real encoderM2PositionRaw;
    Real encoderM1SpeedRaw "0.1 rpm, convention EtherCAT";
    Real encoderM2SpeedRaw;
    Real bucketDeltaAct_M "M2 - M1";
    Real bucketOpeningAct_Pct;
  end WinchMeasurements;

  record WinchDiscreteFeedback "Images TOR simulées M1/M2/benne [HW/DiscreteFeedback]"
    Boolean m1BrakeIsOpen;
    Boolean m2BrakeIsOpen;
    Boolean m1ContactorsAreReleased;
    Boolean m2ContactorsAreReleased;
    Boolean bucketIsOpen;
    Boolean bucketIsClosed;
    Boolean m2CableIsTensioned;
  end WinchDiscreteFeedback;

  record WinchDiagnostics "Diagnostics M1/M2 non autorisants [DIAG]"
    Boolean m1DirectionConflict;
    Boolean m2DirectionConflict;
  end WinchDiagnostics;

  model TranslationM3Plant "M3 : contrat commandes finales -> image capteurs"
    input M3Commands commands "Commandes finales [CMD]";
    parameter M3Configuration configuration "Configuration [CFG]";
    output M3Measurements measurements "Mesures [HW]";
    output M3DiscreteFeedback feedback "Retours TOR [HW]";
    output M3DeviceState deviceState "Etat device [HW]";
    output M3Diagnostics diagnostics "Diagnostics [DIAG]";
  protected
    Real rawPosition(start=20, fixed=true) "Etat intégré avant projection";
    Real brakeOpen(start=0, fixed=true);
    Real direction;
    Real targetVelocity;
    Real speedMps;
  equation
    // La plante applique seulement les commandes finales; elle ne calcule aucune permission.
    diagnostics.commandConflict = commands.cmdMoveToTremie and commands.cmdMoveToMaintenance;
    direction = if commands.cmdMoveToTremie and not commands.cmdMoveToMaintenance then -1 else
                if commands.cmdMoveToMaintenance and not commands.cmdMoveToTremie then 1 else 0;
    measurements.frequencyAct_Hz = if abs(direction) > .5 and not
                          ((measurements.positionAct_M <= 0 and direction < 0) or
                           (measurements.positionAct_M >= configuration.travel_M and direction > 0))
                        then min(configuration.nominalFrequency_Hz,
                          max(0, commands.cmdSpeed_Pct)*configuration.nominalFrequency_Hz/100) else 0;
    der(brakeOpen) = ((if commands.cmdBrakeRelease then 1 else 0) - brakeOpen) /
                     (if commands.cmdBrakeRelease then configuration.brakeOpenDelay_S else configuration.brakeCloseDelay_S);
    feedback.brakeIsOpen = brakeOpen > .95;
    speedMps = configuration.travel_M / max(.1, configuration.fullTravelTime_S) *
               measurements.frequencyAct_Hz / configuration.nominalFrequency_Hz;
    // La projection protège l'image capteurs des surcourses numériques au franchissement d'un pas FMU.
    measurements.positionAct_M = min(configuration.travel_M, max(0, rawPosition));
    targetVelocity = if feedback.brakeIsOpen and not
                        ((measurements.positionAct_M <= 0 and direction < 0) or
                         (measurements.positionAct_M >= configuration.travel_M and direction > 0))
                     then direction*speedMps else 0;
    der(measurements.velocityAct_Mps) = (targetVelocity - measurements.velocityAct_Mps)/.15;
    // Butées physiques : l'état ne poursuit pas hors course et la position publiée reste bornée.
    der(rawPosition) = if (rawPosition <= 0 and measurements.velocityAct_Mps < 0) or
                           (rawPosition >= configuration.travel_M and measurements.velocityAct_Mps > 0)
                       then 0 else measurements.velocityAct_Mps;
    diagnostics.hardStopTremie = measurements.positionAct_M <= 0 and direction < 0;
    diagnostics.hardStopMaintenance = measurements.positionAct_M >= configuration.travel_M and direction > 0;
    // Les sorties capteurs sont délibérément observables et versionnées; les cotes restent à relever.
    feedback.tremiePositionIsActive = measurements.positionAct_M <= .05 + configuration.sensorHysteresis_M;
    feedback.pvPositionIsActive = measurements.positionAct_M <= 5 + configuration.sensorHysteresis_M;
    feedback.p2PositionIsActive = measurements.positionAct_M <= 15 + configuration.sensorHysteresis_M;
    feedback.p1PositionIsActive = measurements.positionAct_M <= 20 + configuration.sensorHysteresis_M;
    feedback.maintenancePositionIsActive = measurements.positionAct_M >= configuration.travel_M - .05 - configuration.sensorHysteresis_M;
    deviceState.driveStatusWord = if abs(measurements.velocityAct_Mps) > .01 then 135 else 128;
    annotation(experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=.01),
      Documentation(info="<html><p>Fondation L1 de migration SimBench : le modèle reçoit les commandes finales M3 et publie uniquement des faits capteurs simulés. Le PLC demeure propriétaire des autorisations, PowerCutOff, AU et aiguillage HwSim/HwIn.</p><p>Les constantes reprennent temporairement le SimBench historique et doivent être calibrées avant toute comparaison terrain.</p></html>"));
  end TranslationM3Plant;

  model WinchesM1M2Plant "M1/M2 : relais finaux -> codeurs, freins et cinématique de benne"
    input WinchCommands commands "Commandes finales [CMD]";
    parameter WinchConfiguration configuration "Configuration [CFG]";
    output WinchMeasurements measurements "Mesures [HW]";
    output WinchDiscreteFeedback feedback "Retours TOR [HW]";
    output WinchDiagnostics diagnostics "Diagnostics [DIAG]";
  protected
    Real m1BrakeOpen(start=0, fixed=true);
    Real m2BrakeOpen(start=0, fixed=true);
    Real m1Direction;
    Real m2Direction;
    Real m1TargetVelocity;
    Real m2TargetVelocity;
    Real m1Speed;
    Real m2Speed;
  equation
    diagnostics.m1DirectionConflict = commands.cmdM1Forward and commands.cmdM1Reverse;
    diagnostics.m2DirectionConflict = commands.cmdM2Forward and commands.cmdM2Reverse;
    m1Direction = if commands.cmdM1Forward and not commands.cmdM1Reverse then 1 else if commands.cmdM1Reverse and not commands.cmdM1Forward then -1 else 0;
    m2Direction = if commands.cmdM2Forward and not commands.cmdM2Reverse then 1 else if commands.cmdM2Reverse and not commands.cmdM2Forward then -1 else 0;
    der(m1BrakeOpen) = ((if commands.cmdM1BrakeRelease then 1 else 0) - m1BrakeOpen) /
                       (if commands.cmdM1BrakeRelease then configuration.brakeOpenDelay_S else configuration.brakeCloseDelay_S);
    der(m2BrakeOpen) = ((if commands.cmdM2BrakeRelease then 1 else 0) - m2BrakeOpen) /
                       (if commands.cmdM2BrakeRelease then configuration.brakeOpenDelay_S else configuration.brakeCloseDelay_S);
    feedback.m1BrakeIsOpen = m1BrakeOpen > .95;
    feedback.m2BrakeIsOpen = m2BrakeOpen > .95;
    m1Speed = configuration.minSpeed_Mps + max(0, min(5, commands.cmdM1SpeedStep) - 1)*(configuration.maxSpeed_Mps-configuration.minSpeed_Mps)/4;
    m2Speed = configuration.minSpeed_Mps + max(0, min(5, commands.cmdM2SpeedStep) - 1)*(configuration.maxSpeed_Mps-configuration.minSpeed_Mps)/4;
    m1TargetVelocity = if feedback.m1BrakeIsOpen then m1Direction*m1Speed else 0;
    m2TargetVelocity = if feedback.m2BrakeIsOpen then m2Direction*m2Speed else 0;
    der(measurements.m1VelocityAct_Mps) = (m1TargetVelocity-measurements.m1VelocityAct_Mps)/max(.02, configuration.coastTime_S);
    der(measurements.m2VelocityAct_Mps) = (m2TargetVelocity-measurements.m2VelocityAct_Mps)/max(.02, configuration.coastTime_S);
    der(measurements.m1CablePositionAct_M) = measurements.m1VelocityAct_Mps;
    der(measurements.m2CablePositionAct_M) = measurements.m2VelocityAct_Mps;
    measurements.encoderM1PositionRaw = configuration.encoderM1InitialRaw + measurements.m1CablePositionAct_M*configuration.encoderPointsPerRevolution/configuration.cablePerRevolution_M;
    measurements.encoderM2PositionRaw = configuration.encoderM2InitialRaw + measurements.m2CablePositionAct_M*configuration.encoderPointsPerRevolution/configuration.cablePerRevolution_M;
    measurements.encoderM1SpeedRaw = measurements.m1VelocityAct_Mps*60/(.1*configuration.cablePerRevolution_M);
    measurements.encoderM2SpeedRaw = measurements.m2VelocityAct_Mps*60/(.1*configuration.cablePerRevolution_M);
    feedback.m1ContactorsAreReleased = not commands.cmdM1Forward and not commands.cmdM1Reverse and not commands.cmdM1SpeedContactor1 and not commands.cmdM1SpeedContactor2 and not commands.cmdM1SpeedContactor3 and not commands.cmdM1SpeedContactor4;
    feedback.m2ContactorsAreReleased = not commands.cmdM2Forward and not commands.cmdM2Reverse and not commands.cmdM2SpeedContactor1 and not commands.cmdM2SpeedContactor2 and not commands.cmdM2SpeedContactor3 and not commands.cmdM2SpeedContactor4;
    measurements.bucketDeltaAct_M = measurements.m2CablePositionAct_M-measurements.m1CablePositionAct_M;
    measurements.bucketOpeningAct_Pct = min(100, max(0, 100*(1-measurements.bucketDeltaAct_M/max(.01, configuration.bucketClosedDelta_M))));
    feedback.bucketIsOpen = measurements.bucketOpeningAct_Pct >= 95;
    feedback.bucketIsClosed = measurements.bucketOpeningAct_Pct <= 5;
    feedback.m2CableIsTensioned = measurements.bucketDeltaAct_M >= -.2;
    annotation(experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=.01),
      Documentation(info="<html><p>L2 provisoire. Cette plante ne remplace aucun FB PLC : elle transforme les relais finaux, paliers et freins en retour codeurs/freins/contacteurs. Le développement tambour, l'inertie, les charges, le mouflage et les cotes benne sont à mesurer.</p></html>"));
  end WinchesM1M2Plant;

  block ClosureHoistValidation
    "Validation continue du retour benne fermée avant autorisation de remontée"
    parameter Real holdTimeS=.30 "Durée continue minimale du retour fermé";
    input Boolean bucketClosed "Retour benne fermée observé";
    output Boolean validated "Retour fermé stable pendant holdTimeS";
    output Real stableForS "Durée continue courante du retour fermé";
    output Real validatedAtS "Instant de validation, -1 si non validé";
  protected
    discrete Real startedAtS(start=-1, fixed=true);
  equation
    stableForS = if startedAtS >= 0 then max(0, time-startedAtS) else 0;
    validated = startedAtS >= 0 and time >= startedAtS + holdTimeS;
    validatedAtS = if validated then startedAtS + holdTimeS else -1;
  algorithm
    when bucketClosed then
      startedAtS := time;
    elsewhen not bucketClosed then
      startedAtS := -1;
    end when;
  end ClosureHoistValidation;

  package Examples
    model M3ContractCycle "Exemple de commandes finales M3 pour OMEdit"
      TranslationM3Plant plant;
    equation
      plant.commands.cmdMoveToMaintenance = time >= 1 and time < 5;
      plant.commands.cmdMoveToTremie = time >= 7 and time < 11;
      plant.commands.cmdSpeed_Pct = if time >= 1 and time < 5 then 70 else if time >= 7 and time < 11 then 55 else 0;
      plant.commands.cmdBrakeRelease = (time >= 1 and time < 5) or (time >= 7 and time < 11);
      annotation(
        experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=.01),
        __OpenModelica_simulationFlags(
          variableFilter="plant\\.(commands|measurements|feedback|deviceState|diagnostics)\\..*"));
    end M3ContractCycle;

    model AnimatedM3ContractCycle "Vue 3D M3 liée à la même plante que les chronogrammes"
      extends M3ContractCycle;
      import Shape = Modelica.Mechanics.MultiBody.Visualizers.Advanced.Shape;

      Shape water(
        shapeType="box", r={-2,-4,0}, lengthDirection={1,0,0}, widthDirection={0,1,0},
        length=34, width=8, height=.15,
        color={25,110,165});
      Shape bridgeRail(
        shapeType="box", r={-1,-.6,12}, lengthDirection={1,0,0}, widthDirection={0,1,0},
        length=32, width=1.2, height=.55,
        color={70,80,90});
      Shape tremieStop(
        shapeType="box", r={-.15,-1,11.2}, lengthDirection={1,0,0}, widthDirection={0,1,0},
        length=.3, width=2, height=1.8,
        color={185,65,45});
      Shape maintenanceStop(
        shapeType="box", r={29.85,-1,11.2}, lengthDirection={1,0,0}, widthDirection={0,1,0},
        length=.3, width=2, height=1.8,
        color={55,150,80});
      Shape carriage(
        shapeType="box", r={plant.measurements.positionAct_M-.9,-1.1,11.3},
        lengthDirection={1,0,0}, widthDirection={0,1,0}, length=1.8, width=2.2, height=.9,
        color={225,155,35});
      Shape driveCabinet(
        shapeType="box", r={plant.measurements.positionAct_M-.575,-.6,12.1},
        lengthDirection={1,0,0}, widthDirection={0,1,0}, length=1.15, width=1.2, height=.65,
        color={52,57,63});
      Shape leftWheel(
        shapeType="cylinder", r={plant.measurements.positionAct_M-.65,-.84,10.7},
        lengthDirection={0,1,0}, widthDirection={1,0,0},
        length=.24, width=.42, height=.42, color={30,30,35});
      Shape rightWheel(
        shapeType="cylinder", r={plant.measurements.positionAct_M+.41,.60,10.7},
        lengthDirection={0,1,0}, widthDirection={1,0,0},
        length=.24, width=.42, height=.42, color={30,30,35});
      annotation(
        experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=.01),
        Documentation(info="<html><p>Animation M3 liée à <code>plant.measurements.positionAct_M</code>. Repère physique : <b>X</b> de Trémie vers Maintenance, <b>Y</b> de la cabine vers la machine, <b>Z</b> vertical vers le haut. La vue cabine est le plan X-Z.</p><p>La vue 2D <code>Dredge.Atelier</code> est la référence opérateur. Cette 3D est une vue secondaire ; les presets de caméra d'OMEdit 1.27.1 ne définissent jamais le repère physique.</p></html>"));
    end AnimatedM3ContractCycle;

    model M1M2BucketCycle "Exemple treuils : levage conjoint puis fermeture M2"
      WinchesM1M2Plant plant;
    equation
      plant.commands.cmdM1Forward = time >= 1 and time < 4;
      plant.commands.cmdM1Reverse = time >= 6 and time < 10;
      plant.commands.cmdM1SpeedStep = if time >= 1 and time < 4 then 3 else if time >= 6 and time < 10 then 2 else 0;
      plant.commands.cmdM1BrakeRelease = (time >= 1 and time < 4) or (time >= 6 and time < 10);
      plant.commands.cmdM1SpeedContactor1 = false;
      plant.commands.cmdM1SpeedContactor2 = false;
      plant.commands.cmdM1SpeedContactor3 = false;
      plant.commands.cmdM1SpeedContactor4 = false;
      plant.commands.cmdM2Forward = (time >= 1 and time < 4) or (time >= 6 and time < 10);
      plant.commands.cmdM2Reverse = false;
      plant.commands.cmdM2SpeedStep = if time >= 1 and time < 4 then 3 else if time >= 6 and time < 10 then 2 else 0;
      plant.commands.cmdM2BrakeRelease = (time >= 1 and time < 4) or (time >= 6 and time < 10);
      plant.commands.cmdM2SpeedContactor1 = false;
      plant.commands.cmdM2SpeedContactor2 = false;
      plant.commands.cmdM2SpeedContactor3 = false;
      plant.commands.cmdM2SpeedContactor4 = false;
      annotation(
        experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=.01),
        __OpenModelica_simulationFlags(
          variableFilter="plant\\.(commands|measurements|feedback|diagnostics)\\..*"));
    end M1M2BucketCycle;

    model GrabClosureThenHoist
      "Fermer la benne, valider le retour fermé 300 ms, puis remonter M1 et M2"
      Boolean closureCmd "Commande de fermeture M2";
      Boolean hoistCmd "Commande de remontée conjointe M1/M2";
      ClosureHoistValidation closureValidation(holdTimeS=.30);
      WinchesM1M2Plant plant;
    equation
      plant.commands.cmdM1Forward = false;
      plant.commands.cmdM1Reverse = hoistCmd;
      plant.commands.cmdM1SpeedStep = if hoistCmd then 3 else 0;
      plant.commands.cmdM1BrakeRelease = hoistCmd;
      plant.commands.cmdM1SpeedContactor1 = false;
      plant.commands.cmdM1SpeedContactor2 = false;
      plant.commands.cmdM1SpeedContactor3 = false;
      plant.commands.cmdM1SpeedContactor4 = false;
      plant.commands.cmdM2Forward = closureCmd;
      plant.commands.cmdM2Reverse = hoistCmd;
      plant.commands.cmdM2SpeedStep = if closureCmd or hoistCmd then 3 else 0;
      plant.commands.cmdM2BrakeRelease = closureCmd or hoistCmd;
      plant.commands.cmdM2SpeedContactor1 = false;
      plant.commands.cmdM2SpeedContactor2 = false;
      plant.commands.cmdM2SpeedContactor3 = false;
      plant.commands.cmdM2SpeedContactor4 = false;
      closureValidation.bucketClosed = plant.feedback.bucketIsClosed;
      closureCmd = time >= 1 and not closureValidation.bucketClosed;
      hoistCmd = closureValidation.validated and
                 time < closureValidation.validatedAtS + 5;
      annotation(
        experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=.01),
        __OpenModelica_simulationFlags(
          variableFilter="closureCmd|hoistCmd|closureValidation\\..*|plant\\.(commands|measurements|feedback|diagnostics)\\..*"),
        Documentation(info="<html><p>Scénario de mise au point AX10 vers AX11 : M2 ferme la benne jusqu'au retour <code>plant.feedback.bucketIsClosed</code>. Le retour doit rester continuellement actif pendant 300 ms avant d'autoriser la remontée conjointe M1/M2 ; toute retombée réinitialise la validation et interdit la remontée. Il s'agit d'une séquence de simulation hors ligne, pas du séquenceur PLC.</p><p>À tracer : <code>closureCmd</code>, <code>plant.feedback.bucketIsClosed</code>, <code>hoistCmd</code>, <code>plant.measurements.m1CablePositionAct_M</code> et <code>plant.measurements.m2CablePositionAct_M</code>.</p></html>"));
    end GrabClosureThenHoist;

    model ClosureValidationBounceTest
      "Garde-fou : un rebond avant 300 ms ne valide jamais la remontée"
      Boolean syntheticBucketClosed;
      ClosureHoistValidation validation(holdTimeS=.30);
    equation
      // Front 150 ms, retombée 100 ms, puis retour stable : seul le second front peut valider.
      syntheticBucketClosed = (time >= 1 and time < 1.15) or time >= 1.25;
      validation.bucketClosed = syntheticBucketClosed;
    algorithm
      when time >= 1.20 then
        assert(not validation.validated,
          "ECHEC : le rebond court a validé la remontée");
      end when;
      when time >= 1.56 then
        assert(validation.validated,
          "ECHEC : le retour stable 300 ms n'a pas été validé");
      end when;
      annotation(
        experiment(StartTime=0, StopTime=2, Tolerance=1e-6, Interval=.001),
        Documentation(info="<html><p>Test de non-régression Modelica : un premier front de 150 ms retombe avant la temporisation, puis le second front reste stable. Toute remontée autorisée avant 1,55 s est une régression.</p></html>"));
    end ClosureValidationBounceTest;

    model AnimatedGrabClosureThenHoist
      "Animation OMEdit X-Z du scénario fermeture puis remontée"
      extends GrabClosureThenHoist;
      import Shape = Modelica.Mechanics.MultiBody.Visualizers.Advanced.Shape;

      Real bucketZ "Hauteur schématique de la benne";
      Real jawOffset "Ecartement schématique des coquilles";
      Shape water(
        shapeType="box", r={-2,-4,0}, lengthDirection={1,0,0}, widthDirection={0,1,0},
        length=34, width=8, height=.15,
        color={25,110,165});
      Shape bridge(
        shapeType="box", r={-1,-.6,12}, lengthDirection={1,0,0}, widthDirection={0,1,0},
        length=32, width=1.2, height=.55,
        color={70,80,90});
      Shape trolley(
        shapeType="box", r={13.8,-1.1,11.4}, lengthDirection={1,0,0}, widthDirection={0,1,0},
        length=2.4, width=2.2, height=.9,
        color={225,155,35});
      Shape cableM1(
        shapeType="cylinder", r={14.5,-.55,bucketZ},
        lengthDirection={0,0,1}, widthDirection={1,0,0},
        length=max(.1,11.4-bucketZ), width=.08, height=.08,
        color={215,215,205});
      Shape cableM2(
        shapeType="cylinder", r={15.5,.55,bucketZ},
        lengthDirection={0,0,1}, widthDirection={1,0,0},
        length=max(.1,11.4-bucketZ), width=.08, height=.08,
        color={230,185,105});
      Shape spreader(
        shapeType="box", r={13.9,-.6,bucketZ}, lengthDirection={1,0,0}, widthDirection={0,1,0},
        length=2.2, width=1.2, height=.35,
        color={105,85,65});
      Shape leftJaw(
        shapeType="box", r={15-jawOffset-max(.45,jawOffset)/2,-.85,bucketZ-1},
        lengthDirection={1,0,0}, widthDirection={0,1,0},
        length=max(.45,jawOffset), width=1.7, height=1.7,
        color={125,75,50});
      Shape rightJaw(
        shapeType="box", r={15+jawOffset-max(.45,jawOffset)/2,-.85,bucketZ-1},
        lengthDirection={1,0,0}, widthDirection={0,1,0},
        length=max(.45,jawOffset), width=1.7, height=1.7,
        color={125,75,50});
    equation
      // Projection X-Z volontairement schématique : les cotes réelles seront calibrées par traces.
      bucketZ = max(1.5, min(10.5, 5 - .30*plant.measurements.m1CablePositionAct_M));
      jawOffset = .35 + 2.2*plant.measurements.bucketOpeningAct_Pct/100;
      annotation(
        experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=.01),
        Documentation(info="<html><p>Repère physique inchangé : <b>X</b> le long du rail de Trémie vers Maintenance, <b>Y</b> de la cabine vers la machine, <b>Z</b> vertical. La plongée est en Z négatif et la remontée en Z positif. La fermeture suit <code>plant.measurements.bucketOpeningAct_Pct</code>.</p><p>La vue 2D <code>Dredge.Atelier</code> est la référence face cabine. Les boutons Front/Top d'OMEdit sont des projections génériques et ne redéfinissent pas ce repère.</p></html>"));
    end AnimatedGrabClosureThenHoist;
  end Examples;

  model Atelier3D
    "Vue 3D secondaire - fermeture benne puis remontee M1/M2"
    extends Examples.AnimatedGrabClosureThenHoist;
    annotation(
      preferredView="diagram",
      Documentation(info="<html><h2>Vue 3D secondaire</h2><p>Utiliser seulement pour contrôler la géométrie volumique. L'atelier principal opérateur est <code>Dredge.Atelier</code> en 2D.</p></html>"));
  end Atelier3D;

  model Atelier
    "POINT D'ENTREE - synoptique 2D de face M3 + M1/M2 + benne"
    Examples.M3ContractCycle m3 "Translation du chariot";
    Examples.GrabClosureThenHoist winches "Fermeture puis remontée";
    Real carriageX "Position écran du chariot, gauche=-80, droite=80";
    Real bucketY "Hauteur écran de la benne";
    Real jawGap "Demi-écartement écran des coquilles";
  equation
    carriageX = -80 + 160*m3.plant.measurements.positionAct_M/
      max(.1, m3.plant.configuration.travel_M);
    // M1 porte la hauteur ; le différentiel M2-M1 ferme les coquilles.
    bucketY = max(-58, min(42, 5 - 3*winches.plant.measurements.m1CablePositionAct_M));
    jawGap = 4 + 14*winches.plant.measurements.bucketOpeningAct_Pct/100;
    annotation(
      preferredView="diagram",
      experiment(StartTime=0, StopTime=20, Tolerance=1e-6, Interval=.01),
      __OpenModelica_simulationFlags(
        variableFilter="carriageX|bucketY|jawGap|m3\\.plant\\.(commands|measurements|feedback|deviceState|diagnostics)\\..*|winches\\.(closureCmd|hoistCmd|closureValidation\\..*|plant\\.(commands|measurements|feedback|diagnostics)\\..*)"),
      Diagram(coordinateSystem(preserveAspectRatio=true, extent={{-110,-110},{110,110}}), graphics={
        Rectangle(extent={{-108,-108},{108,108}}, lineColor={70,80,90}, fillColor={242,246,248}, fillPattern=FillPattern.Solid),
        Text(extent={{-105,92},{105,106}}, textString="TWINBENCH — VUE CABINE", textColor={35,45,55}, textStyle={TextStyle.Bold}),
        Line(points={{-92,70},{92,70}}, color={55,60,65}, thickness=4),
        Rectangle(extent={{-96,-100},{96,-70}}, lineColor={25,110,165}, fillColor={60,155,205}, fillPattern=FillPattern.Solid),
        Line(points={{-80,66},{-80,75}}, color={190,55,45}, thickness=3),
        Line(points={{80,66},{80,75}}, color={45,145,75}, thickness=3),
        Text(extent={{-103,76},{-56,88}}, textString="TRÉMIE", textColor={190,55,45}, textStyle={TextStyle.Bold}),
        Text(extent={{48,76},{105,88}}, textString="MAINTENANCE", textColor={45,145,75}, textStyle={TextStyle.Bold}),
        Rectangle(
          extent=DynamicSelect({{-10,54},{10,69}}, {{carriageX-10,54},{carriageX+10,69}}),
          lineColor={85,75,45}, fillColor={235,165,40}, fillPattern=FillPattern.Solid),
        Line(
          points=DynamicSelect({{0,54},{0,5}}, {{carriageX,54},{carriageX,bucketY+8}}),
          color={70,70,70}, thickness=1.5),
        Rectangle(
          extent=DynamicSelect({{-9,3},{9,9}}, {{carriageX-9,bucketY+2},{carriageX+9,bucketY+8}}),
          lineColor={95,75,55}, fillColor={125,95,65}, fillPattern=FillPattern.Solid),
        Polygon(
          points=DynamicSelect({{-4,3},{-18,-18},{-3,-12},{0,0},{-4,3}},
            {{carriageX-4,bucketY+3},{carriageX-jawGap,bucketY-18},{carriageX-3,bucketY-12},{carriageX,bucketY},{carriageX-4,bucketY+3}}),
          lineColor={105,60,40}, fillColor={150,90,55}, fillPattern=FillPattern.Solid),
        Polygon(
          points=DynamicSelect({{4,3},{18,-18},{3,-12},{0,0},{4,3}},
            {{carriageX+4,bucketY+3},{carriageX+jawGap,bucketY-18},{carriageX+3,bucketY-12},{carriageX,bucketY},{carriageX+4,bucketY+3}}),
          lineColor={105,60,40}, fillColor={150,90,55}, fillPattern=FillPattern.Solid),
        Ellipse(extent={{-104,48},{-94,58}}, lineColor={60,70,75},
          fillColor=DynamicSelect({180,180,180}, if winches.closureCmd then {245,170,35} else {180,180,180}),
          fillPattern=FillPattern.Solid),
        Text(extent={{-92,47},{-48,59}}, textString="FERMETURE", horizontalAlignment=TextAlignment.Left),
        Ellipse(extent={{-104,32},{-94,42}}, lineColor={60,70,75},
          fillColor=DynamicSelect({180,180,180}, if winches.hoistCmd then {45,185,90} else {180,180,180}),
          fillPattern=FillPattern.Solid),
        Text(extent={{-92,31},{-48,43}}, textString="REMONTÉE", horizontalAlignment=TextAlignment.Left),
        Text(extent={{-105,-66},{105,-54}}, textString=DynamicSelect("Position M3", "Position M3 = " + String(m3.plant.measurements.positionAct_M, significantDigits=3) + " m"), textColor={35,45,55})}),
      Documentation(info="<html><h2>Atelier TwinBench 2D</h2><p><b>Vue principale opérateur.</b> Simuler normalement, revenir sur l'onglet <i>Diagramme</i>, puis utiliser Lecture ou le curseur temporel du navigateur de variables. Le chariot se déplace horizontalement de Trémie à gauche vers Maintenance à droite. La benne se ferme puis remonte sous le chariot.</p><p>La vue 3D reste disponible dans <code>Dredge.Atelier3D</code>, uniquement comme contrôle secondaire.</p></html>"));
  end Atelier;

  annotation(uses(Modelica(version="4.1.0")),
    Documentation(info="<html><p><b>POC hors ligne non calibré — interdit pour validation ou commande machine.</b></p><p>Les paramètres mécaniques, temporisations, cotes capteurs et géométries sont des hypothèses à identifier sur traces réelles avant toute comparaison au comportement terrain.</p></html>"));
end Dredge;
