within ;
package M3_POC "POC graphique de translation M3 — sans logique PLC"

  record M3Commands "Commandes finales appliquées à la plante"
    Boolean cmdMoveToTremie "Commande vers Trémie";
    Boolean cmdMoveToMaintenance "Commande vers Maintenance";
    Boolean cmdBrakeRelease "TRUE = demande de desserrage du frein";
    Real cmdFrequency_Hz "Consigne variateur";
  end M3Commands;

  record M3Configuration
    "Paramètres de la plante — PARITÉ avec FB_Sim_Translation (CODE/L_SIMULATION)"
    Real samplePeriod_S=0.01 "[PARITE] Pas discret = cycle du modèle ST";
    Real frequencyMax_Hz=50 "[CODE PLC] Fréquence maximale (consigne PLC réelle, Q2)";
    Real gain_MpsPerHz=0.02 "[PARITE] 30 m / (40 Hz x 37,5 s) = estimateur PLC";
    Real acceleration_HzPerS=20 "[PARITE] FB_Sim_Translation.AccelRate_HzPerS";
    Real deceleration_HzPerS=20 "[PARITE] FB_Sim_Translation.DecelRate_HzPerS";
    Real driveTimeConstant_S=0.15 "[PARITE] Réponse variateur 1er ordre";
    Real brakeOpenTime_S=0.10 "[PARITE] Délai mécanique d'ouverture";
    Real brakeCloseTime_S=0.09 "[PARITE] Délai mécanique de fermeture";
    Real brakeContactDelay_S=0.01 "[PARITE] Contact auxiliaire après la mécanique";
    Real brakeStopFrequency_Hz=0.5 "[PARITE] Le frein ne retombe que sous ce seuil";
    Real tremieSensor_M=0.05 "[PARITE] Came Trémie avant butée";
    Real pvSensor_M=5 "[CODE PLC] Capteur PV";
    Real p2Sensor_M=15 "[CODE PLC] Capteur P2";
    Real p1Sensor_M=20 "[CODE PLC] Capteur P1";
    Real maintenanceSensor_M=29.95 "[PARITE] Came Maintenance avant butée";
    Real sensorHysteresis_M=0.02 "[PARITE] Hystérésis des cames";
    Real sensorElectricalDelay_S=0.01 "[PARITE] Retard électrique DI";
    Real tremieMechanicalStop_M=0 "[PARITE] Butée Trémie";
    Real maintenanceMechanicalStop_M=30 "[PARITE] Butée Maintenance";
    Real initialPosition_M=20 "[PARITE] Départ en P1 (mot 00011)";
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

  record M3PlantState "État interne discret de la plante (non publié)"
    Real frequencyCmd_Hz "Sortie de rampe";
    Real electricalFrequency_Hz;
    Real actualFrequency_Hz;
    Real travelDirection "Sens mémorisé pendant la décélération";
    Real velocity_Mps;
    Real position_M;
    Boolean brakeMechanicallyOpen;
    Boolean brakeContactOpen;
    Real brakeTimer_S;
    Real contactTimer_S;
    Boolean hardStopTremie;
    Boolean hardStopMaintenance;
    Boolean rawTremie;
    Boolean outTremie "Came Tremie (DI vers le PLC)";
    Real timerTremie_S;
    Boolean rawPv;
    Boolean outPv "Came Pv (DI vers le PLC)";
    Real timerPv_S;
    Boolean rawP2;
    Boolean outP2 "Came P2 (DI vers le PLC)";
    Real timerP2_S;
    Boolean rawP1;
    Boolean outP1 "Came P1 (DI vers le PLC)";
    Real timerP1_S;
    Boolean rawMaintenance;
    Boolean outMaintenance "Came Maintenance (DI vers le PLC)";
    Real timerMaintenance_S;
  end M3PlantState;

  function camStep "Une came cumulative : hystérésis puis retard électrique (FB_Sim_PositionSensor)"
    input Boolean rawPrev;
    input Boolean outPrev;
    input Real timerPrev_S;
    input Real position_M;
    input Real threshold_M;
    input Real hysteresis_M;
    input Real delay_S;
    input Real ts;
    output Boolean raw;
    output Boolean out;
    output Real timer_S;
  algorithm
    raw := if rawPrev then position_M <= threshold_M + hysteresis_M
      else position_M <= threshold_M - hysteresis_M;
    out := outPrev;
    timer_S := timerPrev_S;
    if out <> raw then
      timer_S := timer_S + ts;
      if timer_S >= delay_S - 1e-6 then
        out := raw;
        timer_S := 0;
      end if;
    else
      timer_S := 0;
    end if;
  end camStep;

  function plantStep
    "Un pas de 10 ms, même ordre que FB_Sim_Translation : variateur, frein, sens, mouvement, cames"
    input M3Commands cmd;
    input M3Configuration c;
    input M3PlantState p "État au pas précédent";
    output M3PlantState s;
  protected
    Real ts = c.samplePeriod_S;
    Real alpha = c.samplePeriod_S / (c.driveTimeConstant_S + c.samplePeriod_S)
      "Identique à FB_Sim_TranslationDrive.ResponseAlpha";
    Real direction;
    Real frequencyTarget_Hz;
    Real frequencyDelta_Hz;
    Real frequencyStep_Hz;
    Real velocityTarget_Mps;
    Real positionCandidate_M;
  algorithm
    s := p;
    // 1. Variateur : rampe puis réponse 1er ordre (FB_Sim_TranslationDrive).
    direction := if cmd.cmdMoveToTremie and not cmd.cmdMoveToMaintenance then -1
      elseif cmd.cmdMoveToMaintenance and not cmd.cmdMoveToTremie then 1 else 0;
    frequencyTarget_Hz := if abs(direction) > 0.5 then
      min(max(cmd.cmdFrequency_Hz, 0), c.frequencyMax_Hz) else 0;
    frequencyDelta_Hz := frequencyTarget_Hz - s.frequencyCmd_Hz;
    frequencyStep_Hz := (if frequencyDelta_Hz >= 0 then c.acceleration_HzPerS
      else c.deceleration_HzPerS) * ts;
    s.frequencyCmd_Hz := s.frequencyCmd_Hz + min(max(frequencyDelta_Hz, -frequencyStep_Hz), frequencyStep_Hz);
    s.electricalFrequency_Hz := s.electricalFrequency_Hz + alpha * (s.frequencyCmd_Hz - s.electricalFrequency_Hz);
    s.actualFrequency_Hz := if s.electricalFrequency_Hz < 0.005 then 0 else s.electricalFrequency_Hz;

    // 2. Frein (FB_Sim_TranslationBrake) : il ne retombe que sous le seuil d'arrêt.
    if cmd.cmdBrakeRelease then
      if not s.brakeMechanicallyOpen then
        s.brakeTimer_S := s.brakeTimer_S + ts;
        if s.brakeTimer_S >= c.brakeOpenTime_S - 1e-6 then
          s.brakeMechanicallyOpen := true;
          s.brakeTimer_S := 0;
        end if;
      else
        s.brakeTimer_S := 0;
      end if;
    elseif s.actualFrequency_Hz <= c.brakeStopFrequency_Hz then
      if s.brakeMechanicallyOpen then
        s.brakeTimer_S := s.brakeTimer_S + ts;
        if s.brakeTimer_S >= c.brakeCloseTime_S - 1e-6 then
          s.brakeMechanicallyOpen := false;
          s.brakeTimer_S := 0;
        end if;
      else
        s.brakeTimer_S := 0;
      end if;
    else
      s.brakeTimer_S := 0;
    end if;
    if s.brakeMechanicallyOpen <> s.brakeContactOpen then
      s.contactTimer_S := s.contactTimer_S + ts;
      if s.contactTimer_S >= c.brakeContactDelay_S - 1e-6 then
        s.brakeContactOpen := s.brakeMechanicallyOpen;
        s.contactTimer_S := 0;
      end if;
    else
      s.contactTimer_S := 0;
    end if;

    // 3. Sens mémorisé : conservé pendant la décélération libre, purgé à l'arrêt.
    if abs(direction) > 0.5 then
      s.travelDirection := direction;
    elseif cmd.cmdMoveToTremie and cmd.cmdMoveToMaintenance then
      s.travelDirection := 0;
    elseif s.actualFrequency_Hz <= c.brakeStopFrequency_Hz then
      s.travelDirection := 0;
    end if;

    // 4. Mouvement : frein serré = vitesse nulle ; butées rigides.
    velocityTarget_Mps := if s.brakeMechanicallyOpen then
      s.travelDirection * c.gain_MpsPerHz * s.actualFrequency_Hz else 0;
    s.velocity_Mps := s.velocity_Mps + alpha * (velocityTarget_Mps - s.velocity_Mps);
    if not s.brakeMechanicallyOpen then
      s.velocity_Mps := 0;
    end if;
    positionCandidate_M := s.position_M + s.velocity_Mps * ts;
    s.hardStopTremie := false;
    s.hardStopMaintenance := false;
    if positionCandidate_M < c.tremieMechanicalStop_M then
      s.position_M := c.tremieMechanicalStop_M;
      s.velocity_Mps := 0;
      s.hardStopTremie := true;
    elseif positionCandidate_M > c.maintenanceMechanicalStop_M then
      s.position_M := c.maintenanceMechanicalStop_M;
      s.velocity_Mps := 0;
      s.hardStopMaintenance := true;
    else
      s.position_M := positionCandidate_M;
    end if;

    // 5. Cames cumulatives (FB_Sim_PositionSensor).
    (s.rawTremie, s.outTremie, s.timerTremie_S) := camStep(s.rawTremie, s.outTremie, s.timerTremie_S,
      s.position_M, c.tremieSensor_M, c.sensorHysteresis_M, c.sensorElectricalDelay_S, ts);
    (s.rawPv, s.outPv, s.timerPv_S) := camStep(s.rawPv, s.outPv, s.timerPv_S,
      s.position_M, c.pvSensor_M, c.sensorHysteresis_M, c.sensorElectricalDelay_S, ts);
    (s.rawP2, s.outP2, s.timerP2_S) := camStep(s.rawP2, s.outP2, s.timerP2_S,
      s.position_M, c.p2Sensor_M, c.sensorHysteresis_M, c.sensorElectricalDelay_S, ts);
    (s.rawP1, s.outP1, s.timerP1_S) := camStep(s.rawP1, s.outP1, s.timerP1_S,
      s.position_M, c.p1Sensor_M, c.sensorHysteresis_M, c.sensorElectricalDelay_S, ts);
    (s.rawMaintenance, s.outMaintenance, s.timerMaintenance_S) := camStep(s.rawMaintenance, s.outMaintenance, s.timerMaintenance_S,
      s.position_M, c.maintenanceSensor_M, c.sensorHysteresis_M, c.sensorElectricalDelay_S, ts);
  end plantStep;

  constant Integer stateSize = 27 "Taille de l'état empaqueté";

  function packState "Record -> vecteur Real (contournement export FMU OpenModelica 1.27)"
    input M3PlantState s;
    output Real x[stateSize];
  algorithm
    x := {s.frequencyCmd_Hz,
      s.electricalFrequency_Hz,
      s.actualFrequency_Hz,
      s.travelDirection,
      s.velocity_Mps,
      s.position_M,
      if s.brakeMechanicallyOpen then 1 else 0,
      if s.brakeContactOpen then 1 else 0,
      s.brakeTimer_S,
      s.contactTimer_S,
      if s.hardStopTremie then 1 else 0,
      if s.hardStopMaintenance then 1 else 0,
      if s.rawTremie then 1 else 0,
      if s.outTremie then 1 else 0,
      s.timerTremie_S,
      if s.rawPv then 1 else 0,
      if s.outPv then 1 else 0,
      s.timerPv_S,
      if s.rawP2 then 1 else 0,
      if s.outP2 then 1 else 0,
      s.timerP2_S,
      if s.rawP1 then 1 else 0,
      if s.outP1 then 1 else 0,
      s.timerP1_S,
      if s.rawMaintenance then 1 else 0,
      if s.outMaintenance then 1 else 0,
      s.timerMaintenance_S};
  end packState;

  function unpackState "Vecteur Real -> record"
    input Real x[stateSize];
    output M3PlantState s;
  algorithm
    s.frequencyCmd_Hz := x[1];
    s.electricalFrequency_Hz := x[2];
    s.actualFrequency_Hz := x[3];
    s.travelDirection := x[4];
    s.velocity_Mps := x[5];
    s.position_M := x[6];
    s.brakeMechanicallyOpen := x[7] > 0.5;
    s.brakeContactOpen := x[8] > 0.5;
    s.brakeTimer_S := x[9];
    s.contactTimer_S := x[10];
    s.hardStopTremie := x[11] > 0.5;
    s.hardStopMaintenance := x[12] > 0.5;
    s.rawTremie := x[13] > 0.5;
    s.outTremie := x[14] > 0.5;
    s.timerTremie_S := x[15];
    s.rawPv := x[16] > 0.5;
    s.outPv := x[17] > 0.5;
    s.timerPv_S := x[18];
    s.rawP2 := x[19] > 0.5;
    s.outP2 := x[20] > 0.5;
    s.timerP2_S := x[21];
    s.rawP1 := x[22] > 0.5;
    s.outP1 := x[23] > 0.5;
    s.timerP1_S := x[24];
    s.rawMaintenance := x[25] > 0.5;
    s.outMaintenance := x[26] > 0.5;
    s.timerMaintenance_S := x[27];
  end unpackState;

  function initialState "Démarrage : chariot immobile, frein serré, cames calculées à la position initiale"
    input M3Configuration c;
    output Real x[stateSize];
  protected
    M3PlantState s;
  algorithm
    s.frequencyCmd_Hz := 0;
    s.electricalFrequency_Hz := 0;
    s.actualFrequency_Hz := 0;
    s.travelDirection := 0;
    s.velocity_Mps := 0;
    s.position_M := c.initialPosition_M;
    s.brakeMechanicallyOpen := false;
    s.brakeContactOpen := false;
    s.brakeTimer_S := 0;
    s.contactTimer_S := 0;
    s.hardStopTremie := false;
    s.hardStopMaintenance := false;
    s.rawTremie := c.initialPosition_M <= c.tremieSensor_M;
    s.outTremie := s.rawTremie;
    s.timerTremie_S := 0;
    s.rawPv := c.initialPosition_M <= c.pvSensor_M;
    s.outPv := s.rawPv;
    s.timerPv_S := 0;
    s.rawP2 := c.initialPosition_M <= c.p2Sensor_M;
    s.outP2 := s.rawP2;
    s.timerP2_S := 0;
    s.rawP1 := c.initialPosition_M <= c.p1Sensor_M;
    s.outP1 := s.rawP1;
    s.timerP1_S := 0;
    s.rawMaintenance := c.initialPosition_M <= c.maintenanceSensor_M;
    s.outMaintenance := s.rawMaintenance;
    s.timerMaintenance_S := 0;
    x := packState(s);
  end initialState;

  function plantStepPacked "Pas de plante sur l'état empaqueté"
    input M3Commands cmd;
    input M3Configuration c;
    input Real p[stateSize];
    output Real x[stateSize];
  algorithm
    x := packState(plantStep(cmd, c, unpackState(p)));
  end plantStepPacked;

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

  model TranslationM3
    "Plante M3 discrète (10 ms) — transposition du chemin nominal de FB_Sim_Translation"
    input M3Commands commands;
    parameter M3Configuration configuration;
    output M3Measurements measurements;
    output M3DiscreteFeedback feedback;
    output M3DeviceState deviceState;
    output M3Diagnostics diagnostics;

  protected
    // Calcul dans des fonctions appelées par une équation when : OpenModelica 1.27
    // n'exporte pas en FMU un algorithme when qui affecte des Real (bug reproduit).
    discrete Real stateVector[stateSize](start=initialState(configuration), each fixed=true);

  equation
    assert(configuration.initialPosition_M >= configuration.tremieMechanicalStop_M and
      configuration.initialPosition_M <= configuration.maintenanceMechanicalStop_M,
      "M3: initialPosition_M hors des butées mécaniques");
    when sample(0, configuration.samplePeriod_S) then
      // pre() casse la boucle commande <-> capteurs du banc autonome ; en FMU les entrées
      // sont figées pendant le pas, pre(commande) = commande appliquée.
      stateVector = plantStepPacked(M3Commands(
        cmdMoveToTremie=pre(commands.cmdMoveToTremie),
        cmdMoveToMaintenance=pre(commands.cmdMoveToMaintenance),
        cmdBrakeRelease=pre(commands.cmdBrakeRelease),
        cmdFrequency_Hz=pre(commands.cmdFrequency_Hz)), configuration, pre(stateVector));
    end when;

    measurements.frequencyCmd_Hz = stateVector[1];
    measurements.frequencyAct_Hz = stateVector[3];
    measurements.velocityAct_Mps = stateVector[5];
    measurements.positionAct_M = stateVector[6];
    // Retour vers le PLC = contact auxiliaire, comme M3_BrakeIsOpen_DI du SimBench interne.
    feedback.brakeIsOpen = (stateVector[8] > 0.5);
    feedback.tremiePositionIsActive = (stateVector[14] > 0.5);
    feedback.pvPositionIsActive = (stateVector[17] > 0.5);
    feedback.p2PositionIsActive = (stateVector[20] > 0.5);
    feedback.p1PositionIsActive = (stateVector[23] > 0.5);
    feedback.maintenancePositionIsActive = (stateVector[26] > 0.5);
    deviceState.sensorsWord = (if (stateVector[14] > 0.5) then 16 else 0) + (if (stateVector[17] > 0.5) then 8 else 0)
      + (if (stateVector[20] > 0.5) then 4 else 0) + (if (stateVector[23] > 0.5) then 2 else 0)
      + (if (stateVector[26] > 0.5) then 1 else 0);
    // Même règle que FB_SimBench : 16#87 dès que le variateur tourne, 16#80 à l'arrêt.
    deviceState.driveStatusWord = if stateVector[3] > 0.5 then 135 else 128;
    diagnostics.commandConflict = commands.cmdMoveToTremie and commands.cmdMoveToMaintenance;
    diagnostics.hardStopTremieActive = (stateVector[11] > 0.5);
    diagnostics.hardStopMaintenanceActive = (stateVector[12] > 0.5);

    annotation(
      Documentation(info="<html><p><b>Plante M3 en parité avec FB_Sim_Translation</b> (chemin nominal : pas de charge suspendue, ni bruit, ni intermittence capteur). Modèle discret au pas <code>samplePeriod_S</code>, même ordre de calcul que le ST : variateur, frein, sens mémorisé, mouvement/butées, cames. Aucune permission ni logique PLC.</p></html>"));
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
