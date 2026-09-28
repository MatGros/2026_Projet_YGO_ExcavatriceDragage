within ;
package M3_POC "POC graphique de translation M3 — sans logique PLC"

  record M3Commands "Commandes finales appliquées à la plante"
    Boolean cmdMoveToTremie "Commande vers Trémie";
    Boolean cmdMoveToMaintenance "Commande vers Maintenance";
    Boolean cmdBrakeRelease "TRUE = demande de desserrage du frein";
    Real cmdFrequency_Hz "Consigne variateur";
  end M3Commands;

  record M3Configuration "Paramètres physiques et hypothèses du POC"
    Real frequencyMax_Hz=50 "[CODE PLC] Fréquence maximale";
    Real gain_MpsPerHz=0.02 "[HYPOTHESE] 50 Hz = 1 m/s";
    Real acceleration_HzPerS=20 "[CODE PLC] Rampe montée 40 %/s";
    Real deceleration_HzPerS=25 "[CODE PLC] Rampe descente 50 %/s";
    Real brakeOpenTime_S=0.20 "[SIMPLIFIE] 100 ms contacteur + 100 ms magnétisation";
    Real brakeCloseTime_S=0.10 "[HYPOTHESE] À mesurer";
    Real tremieSensor_M=0 "[CODE PLC] Capteur Trémie";
    Real pvSensor_M=5 "[CODE PLC] Capteur PV";
    Real p2Sensor_M=15 "[CODE PLC] Capteur P2";
    Real p1Sensor_M=20 "[CODE PLC] Capteur P1";
    Real maintenanceSensor_M=30 "[CODE PLC] Capteur Maintenance";
    Real tremieMechanicalStop_M=-0.30 "[HYPOTHESE] Butée 30 cm après capteur";
    Real maintenanceMechanicalStop_M=30.30 "[HYPOTHESE] Butée 30 cm après capteur";
    Real initialPosition_M=20 "[CONFIG] Position initiale FMU ; doit être référencée par le scénario";
  end M3Configuration;

  record M3Measurements "Mesures analogiques de la plante"
    Real positionAct_M "Position vraie : 0 m = capteur Trémie";
    Real velocityAct_Mps "Vitesse linéaire";
    Real frequencyCmd_Hz "Consigne Hz bornée";
    Real frequencyAct_Hz "Fréquence variateur simulée";
  end M3Measurements;

  record M3DiscreteFeedback "Retours discrets simulés"
    Boolean brakeIsOpen "Frein ouvert";
    Boolean tremiePositionIsActive "Capteur Trémie";
    Boolean pvPositionIsActive "Capteur PV";
    Boolean p2PositionIsActive "Capteur P2";
    Boolean p1PositionIsActive "Capteur P1";
    Boolean maintenancePositionIsActive "Capteur Maintenance";
  end M3DiscreteFeedback;

  record M3DeviceState "États bruts des équipements simulés"
    Integer driveStatusWord "StatusWord AC600 simplifié";
    Integer sensorsWord "Mot capteurs 11111 vers 00000";
  end M3DeviceState;

  record M3Diagnostics "Diagnostics sans autorité de commande"
    Boolean commandConflict "Deux sens demandés simultanément";
    Boolean hardStopTremieActive "Commande contre butée Trémie";
    Boolean hardStopMaintenanceActive "Commande contre butée Maintenance";
  end M3Diagnostics;

  record M3LoopConfiguration "Réglages du banc autonome en boucle locale"
    Boolean enabled=true "Active la génération autonome des commandes";
    Real frequency_Hz=40 "Fréquence demandée pendant les déplacements";
    Real pauseAtTremie_S=1 "Pause après détection Trémie";
    Real pauseAtMaintenance_S=1 "Pause après détection Maintenance";
    Integer cycleCount=0 "0 = boucle illimitée, sinon nombre d'allers-retours";
  end M3LoopConfiguration;

  record M3LoopState "État observable du contrôleur de banc"
    Integer phaseCode "0 arrêt, 1 vers Maintenance, 2 pause Maintenance, 3 vers Trémie, 4 pause Trémie, 5 terminé";
    Integer completedCycles "Nombre d'allers-retours terminés";
    Boolean loopActive "Boucle autonome en cours";
    Real phaseElapsed_S "Temps écoulé dans la phase courante";
  end M3LoopState;

  block BrakeActuator "Actionneur de frein simplifié à temps ouverture/fermeture distincts"
    parameter Real openTime_S=0.20;
    parameter Real closeTime_S=0.10;
    Modelica.Blocks.Interfaces.BooleanInput releaseRequest;
    Modelica.Blocks.Interfaces.BooleanOutput isOpen;
  protected
    Real openingRatio(start=0, fixed=true);
  equation
    der(openingRatio) = ((if releaseRequest then 1 else 0) - openingRatio) /
      (if releaseRequest then openTime_S else closeTime_S);
    isOpen = openingRatio >= 0.95;
    annotation(
      Icon(graphics={Rectangle(extent={{-100,100},{100,-100}}, lineColor={80,80,80}, fillColor={230,230,230}, fillPattern=FillPattern.Solid), Ellipse(extent={{-55,55},{55,-55}}, lineColor={160,60,20}, lineThickness=1), Text(extent={{-90,25},{90,-25}}, textString="FREIN")}),
      Documentation(info="<html><p>Modèle physique simplifié, sans logique PLC. Les délais sont visibles et paramétrables.</p></html>"));
  end BrakeActuator;

  block SensorBank "Cinq capteurs de position cumulatifs"
    parameter Real tremie_M=0;
    parameter Real pv_M=5;
    parameter Real p2_M=15;
    parameter Real p1_M=20;
    parameter Real maintenance_M=30;
    Modelica.Blocks.Interfaces.RealInput position_M;
    Modelica.Blocks.Interfaces.BooleanOutput tremie;
    Modelica.Blocks.Interfaces.BooleanOutput pv;
    Modelica.Blocks.Interfaces.BooleanOutput p2;
    Modelica.Blocks.Interfaces.BooleanOutput p1;
    Modelica.Blocks.Interfaces.BooleanOutput maintenance;
    output Integer sensorsWord;
  equation
    tremie = position_M <= tremie_M;
    pv = position_M <= pv_M;
    p2 = position_M <= p2_M;
    p1 = position_M <= p1_M;
    maintenance = position_M < maintenance_M;
    sensorsWord = (if tremie then 16 else 0) + (if pv then 8 else 0) +
      (if p2 then 4 else 0) + (if p1 then 2 else 0) + (if maintenance then 1 else 0);
    annotation(
      Icon(graphics={Rectangle(extent={{-100,100},{100,-100}}, lineColor={80,80,80}, fillColor={235,245,235}, fillPattern=FillPattern.Solid), Text(extent={{-90,25},{90,-25}}, textString="CAPTEURS")}),
      Documentation(info="<html><p>Encode la chaîne cumulative terrain en mot 11111 → 00000.</p></html>"));
  end SensorBank;

  block LocalLoopController
    "Générateur de stimuli fermé sur les capteurs — banc uniquement, aucune logique PLC"
    parameter M3LoopConfiguration configuration;
    input M3DiscreteFeedback feedback;
    output M3Commands commands;
    output M3LoopState state;
  protected
    discrete Integer phaseCode(start=1, fixed=true);
    discrete Integer completedCycles(start=0, fixed=true);
    discrete Real phaseStartedAt_S(start=0, fixed=true);
  equation
    assert(configuration.frequency_Hz >= 0,
      "M3 loop: frequency_Hz doit être positive ou nulle");
    assert(configuration.initialPosition_M >= configuration.tremieMechanicalStop_M and
      configuration.initialPosition_M <= configuration.maintenanceMechanicalStop_M,
      "M3: initialPosition_M hors des butées mécaniques");
    assert(configuration.pauseAtTremie_S >= 0 and configuration.pauseAtMaintenance_S >= 0,
      "M3 loop: les pauses doivent être positives ou nulles");
    assert(configuration.cycleCount >= 0,
      "M3 loop: cycleCount doit être positif ou nul (0 = illimité)");

    commands.cmdMoveToMaintenance = configuration.enabled and phaseCode == 1;
    commands.cmdMoveToTremie = configuration.enabled and phaseCode == 3;
    commands.cmdBrakeRelease = commands.cmdMoveToMaintenance or commands.cmdMoveToTremie;
    commands.cmdFrequency_Hz = if commands.cmdBrakeRelease then configuration.frequency_Hz else 0;
    state.phaseCode = phaseCode;
    state.completedCycles = completedCycles;
    state.loopActive = configuration.enabled and phaseCode >= 1 and phaseCode <= 4;
    state.phaseElapsed_S = time - phaseStartedAt_S;

  algorithm
    when initial() then
      phaseCode := 1;
      completedCycles := 0;
      phaseStartedAt_S := time;
    elsewhen pre(phaseCode) == 1 and not feedback.maintenancePositionIsActive then
      phaseCode := 2;
      phaseStartedAt_S := time;
    elsewhen pre(phaseCode) == 2 and
        time >= pre(phaseStartedAt_S) + configuration.pauseAtMaintenance_S then
      phaseCode := 3;
      phaseStartedAt_S := time;
    elsewhen pre(phaseCode) == 3 and feedback.tremiePositionIsActive then
      phaseCode := 4;
      phaseStartedAt_S := time;
    elsewhen pre(phaseCode) == 4 and
        time >= pre(phaseStartedAt_S) + configuration.pauseAtTremie_S then
      completedCycles := pre(completedCycles) + 1;
      if configuration.cycleCount > 0 and
          pre(completedCycles) + 1 >= configuration.cycleCount then
        phaseCode := 5;
      else
        phaseCode := 1;
      end if;
      phaseStartedAt_S := time;
    end when;

    annotation(
      Icon(graphics={Rectangle(extent={{-100,100},{100,-100}}, lineColor={55,90,140}, fillColor={235,242,250}, fillPattern=FillPattern.Solid), Text(extent={{-92,28},{92,-28}}, textString="BOUCLE M3")} ),
      Documentation(info="<html><p>Contrôleur de <b>banc d'essai</b> autonome. Il produit seulement des stimuli pour la plante et ne représente pas le PLC. Il inverse le sens sur les retours capteurs Trémie/Maintenance et peut boucler sans limite lorsque <code>cycleCount=0</code>.</p></html>"));
  end LocalLoopController;

  model TranslationM3 "Chaîne M3 visible dans la vue Diagramme OMEdit"
    input M3Commands commands;
    parameter M3Configuration configuration;
    output M3Measurements measurements;
    output M3DiscreteFeedback feedback;
    output M3DeviceState deviceState;
    output M3Diagnostics diagnostics;

  protected
    Modelica.Blocks.Sources.RealExpression direction(
      y=if commands.cmdMoveToTremie and not commands.cmdMoveToMaintenance then -1 else
        if commands.cmdMoveToMaintenance and not commands.cmdMoveToTremie then 1 else 0)
      annotation(Placement(transformation(extent={{-90,48},{-70,68}})));
    Modelica.Blocks.Sources.RealExpression requestedFrequency(
      y=if abs(direction.y) > 0.5 then commands.cmdFrequency_Hz else 0)
      annotation(Placement(transformation(extent={{-90,10},{-70,30}})));
    Modelica.Blocks.Nonlinear.Limiter frequencyLimiter(
      uMax=configuration.frequencyMax_Hz, uMin=0)
      annotation(Placement(transformation(extent={{-60,10},{-40,30}})));
    Modelica.Blocks.Nonlinear.SlewRateLimiter driveRamp(
      Rising=configuration.acceleration_HzPerS,
      Falling=-configuration.deceleration_HzPerS,
      initType=Modelica.Blocks.Types.Init.InitialOutput,
      y_start=0)
      annotation(Placement(transformation(extent={{-30,10},{-10,30}})));
    Modelica.Blocks.Math.Product signedFrequency
      annotation(Placement(transformation(extent={{5,32},{25,52}})));
    Modelica.Blocks.Math.Gain frequencyToVelocity(k=configuration.gain_MpsPerHz)
      annotation(Placement(transformation(extent={{35,32},{55,52}})));
    Modelica.Blocks.Sources.BooleanExpression brakeRequest(y=commands.cmdBrakeRelease)
      annotation(Placement(transformation(extent={{-90,-35},{-70,-15}})));
    BrakeActuator brake(
      openTime_S=configuration.brakeOpenTime_S,
      closeTime_S=configuration.brakeCloseTime_S)
      annotation(Placement(transformation(extent={{-55,-40},{-35,-20}})));
    Modelica.Blocks.Math.BooleanToReal brakeGate(realTrue=1, realFalse=0)
      annotation(Placement(transformation(extent={{-22,-40},{-2,-20}})));
    Modelica.Blocks.Math.Product gatedVelocity
      annotation(Placement(transformation(extent={{65,15},{85,35}})));
    Modelica.Blocks.Continuous.LimIntegrator carriagePosition(
      k=1,
      outMin=configuration.tremieMechanicalStop_M,
      outMax=configuration.maintenanceMechanicalStop_M,
      initType=Modelica.Blocks.Types.Init.InitialOutput,
      y_start=configuration.initialPosition_M)
      annotation(Placement(transformation(extent={{45,-35},{65,-15}})));
    SensorBank sensors(
      tremie_M=configuration.tremieSensor_M,
      pv_M=configuration.pvSensor_M,
      p2_M=configuration.p2Sensor_M,
      p1_M=configuration.p1Sensor_M,
      maintenance_M=configuration.maintenanceSensor_M)
      annotation(Placement(transformation(extent={{75,-55},{95,-35}})));

  equation
    connect(requestedFrequency.y, frequencyLimiter.u)
      annotation(Line(points={{-69,20},{-62,20}}, color={0,0,127}));
    connect(frequencyLimiter.y, driveRamp.u)
      annotation(Line(points={{-39,20},{-32,20}}, color={0,0,127}));
    connect(driveRamp.y, signedFrequency.u1)
      annotation(Line(points={{-9,20},{-2,20},{-2,48},{3,48}}, color={0,0,127}));
    connect(direction.y, signedFrequency.u2)
      annotation(Line(points={{-69,58},{-5,58},{-5,36},{3,36}}, color={0,0,127}));
    connect(signedFrequency.y, frequencyToVelocity.u)
      annotation(Line(points={{26,42},{33,42}}, color={0,0,127}));
    connect(brakeRequest.y, brake.releaseRequest)
      annotation(Line(points={{-69,-25},{-57,-25}}, color={255,0,255}));
    connect(brake.isOpen, brakeGate.u)
      annotation(Line(points={{-34,-30},{-24,-30}}, color={255,0,255}));
    connect(frequencyToVelocity.y, gatedVelocity.u1)
      annotation(Line(points={{56,42},{60,42},{60,31},{63,31}}, color={0,0,127}));
    connect(brakeGate.y, gatedVelocity.u2)
      annotation(Line(points={{-1,-30},{55,-30},{55,19},{63,19}}, color={0,0,127}));
    connect(gatedVelocity.y, carriagePosition.u)
      annotation(Line(points={{86,25},{90,25},{90,-5},{35,-5},{35,-25},{43,-25}}, color={0,0,127}));
    connect(carriagePosition.y, sensors.position_M)
      annotation(Line(points={{66,-25},{70,-25},{70,-45},{73,-45}}, color={0,0,127}));

    measurements.frequencyCmd_Hz = frequencyLimiter.y;
    measurements.frequencyAct_Hz = driveRamp.y;
    measurements.velocityAct_Mps = gatedVelocity.y;
    measurements.positionAct_M = carriagePosition.y;
    feedback.brakeIsOpen = brake.isOpen;
    feedback.tremiePositionIsActive = sensors.tremie;
    feedback.pvPositionIsActive = sensors.pv;
    feedback.p2PositionIsActive = sensors.p2;
    feedback.p1PositionIsActive = sensors.p1;
    feedback.maintenancePositionIsActive = sensors.maintenance;
    deviceState.sensorsWord = sensors.sensorsWord;
    deviceState.driveStatusWord = if abs(driveRamp.y) > 0.5 and brake.isOpen then 135 else 128;
    diagnostics.commandConflict = commands.cmdMoveToTremie and commands.cmdMoveToMaintenance;
    diagnostics.hardStopTremieActive = carriagePosition.y <= configuration.tremieMechanicalStop_M + 0.0001 and direction.y < 0;
    diagnostics.hardStopMaintenanceActive = carriagePosition.y >= configuration.maintenanceMechanicalStop_M - 0.0001 and direction.y > 0;

    annotation(
      Diagram(coordinateSystem(extent={{-100,-70},{100,80}}, preserveAspectRatio=false), graphics={
        Text(extent={{-94,76},{-50,70}}, textString="COMMANDES & VARIATEUR", textColor={70,70,70}),
        Text(extent={{-57,-52},{-5,-58}}, textString="FREIN PHYSIQUE SIMPLIFIÉ", textColor={70,70,70}),
        Text(extent={{36,-58},{98,-64}}, textString="MOUVEMENT, BUTÉES & CAPTEURS", textColor={70,70,70})}),
      Documentation(info="<html><p><b>POC graphique.</b> Ouvrir l'onglet Diagramme : les blocs standards Modelica montrent la chaîne de calcul. Le frein et la banque de capteurs sont des composants M3 dédiés. Aucune permission ni logique PLC n'est modélisée ici.</p></html>"));
  end TranslationM3;

  package Examples "Scénarios prêts à simuler dans OMEdit"
    model AllerRetour "Scénario historique : Maintenance puis Trémie"
      parameter Real commandFrequency_Hz=40 "Consigne de test";
      TranslationM3 plant;
    equation
      plant.commands.cmdMoveToMaintenance = time >= 1 and time < 18;
      plant.commands.cmdMoveToTremie = time >= 21 and time < 65;
      plant.commands.cmdBrakeRelease = plant.commands.cmdMoveToMaintenance or
        plant.commands.cmdMoveToTremie;
      plant.commands.cmdFrequency_Hz = if plant.commands.cmdBrakeRelease then
        commandFrequency_Hz else 0;
      annotation(
        experiment(StartTime=0, StopTime=70, Tolerance=1e-6, Interval=0.01),
        Documentation(info="<html><p>Scénario déterministe restauré pour vérifier la non-régression du POC.</p></html>"));
    end AllerRetour;

    model BoucleLocale
      "Banc autonome : les commandes rebouclent sur les capteurs simulés"
      parameter Boolean loopEnabled=true "Active le contrôleur local";
      parameter Real loopFrequency_Hz=40 "Consigne appliquée en mouvement";
      parameter Real pauseAtTremie_S=1 "Pause côté Trémie";
      parameter Real pauseAtMaintenance_S=1 "Pause côté Maintenance";
      parameter Integer cycleCount=0 "0 = boucle jusqu'au StopTime";
      parameter M3LoopConfiguration loopConfiguration(
        enabled=loopEnabled,
        frequency_Hz=loopFrequency_Hz,
        pauseAtTremie_S=pauseAtTremie_S,
        pauseAtMaintenance_S=pauseAtMaintenance_S,
        cycleCount=cycleCount);
      LocalLoopController controller(configuration=loopConfiguration);
      TranslationM3 plant;
      output Integer completedCycles=controller.state.completedCycles;
      output Integer phaseCode=controller.state.phaseCode;
      output Boolean loopActive=controller.state.loopActive;
    equation
      controller.feedback = plant.feedback;
      plant.commands = controller.commands;
      annotation(
        experiment(StartTime=0, StopTime=120, Tolerance=1e-6, Interval=0.01),
        Documentation(info="<html><p>Modifier les paramètres dans OMEdit puis relancer la simulation. <code>cycleCount=0</code> boucle jusqu'au StopTime ; une valeur positive arrête le contrôleur après ce nombre d'allers-retours.</p></html>"));
    end BoucleLocale;
  end Examples;

  annotation(
    uses(Modelica(version="4.1.0")),
    Documentation(info="<html><p>POC M3 T401. Points d'entrée : <b>M3_POC.Examples.AllerRetour</b> et <b>M3_POC.Examples.BoucleLocale</b>.</p></html>"));
end M3_POC;
