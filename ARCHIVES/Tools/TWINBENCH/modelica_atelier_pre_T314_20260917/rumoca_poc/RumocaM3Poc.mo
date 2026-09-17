within ;
package RumocaM3Poc "POC Rumoca autonome : même cycle M3, sans MSL"
  model ContractCycle "Cycle M3 déterministe pour comparaison de runtime"
    parameter Real travelM=30 "Course Trémie -> Maintenance";
    parameter Real nominalFrequencyHz=40;
    parameter Real fullTravelTimeS=8;
    output Real positionM(start=20, fixed=true) "0=Trémie, 30=Maintenance";
    output Real velocityMps(start=0, fixed=true);
    output Real actualFrequencyHz;
    output Real brakeIsOpenDI;
    output Real posTremieDI;
    output Real posMaintenanceDI;
    output Real commandConflict;
  protected
    Real brakeOpen(start=0, fixed=true);
    Real direction;
    Real commandSpeedPct;
    Real targetVelocity;
  equation
    // Même profil que Dredge.Examples.M3ContractCycle : Maintenance puis Trémie.
    direction = if time >= 1 and time < 5 then 1 else if time >= 7 and time < 11 then -1 else 0;
    commandSpeedPct = if time >= 1 and time < 5 then 70 else if time >= 7 and time < 11 then 55 else 0;
    commandConflict = 0;
    der(brakeOpen) = ((if abs(direction) > 0.5 then 1 else 0) - brakeOpen) / 0.1;
    brakeIsOpenDI = if brakeOpen > 0.95 then 1 else 0;
    actualFrequencyHz = if abs(direction) > 0.5 and
      not ((positionM <= 0 and direction < 0) or (positionM >= travelM and direction > 0))
      then commandSpeedPct * nominalFrequencyHz / 100 else 0;
    targetVelocity = if brakeIsOpenDI > 0.5 then direction * travelM / fullTravelTimeS * actualFrequencyHz / nominalFrequencyHz else 0;
    der(velocityMps) = (targetVelocity - velocityMps) / 0.15;
    der(positionM) = if (positionM <= 0 and velocityMps < 0) or
      (positionM >= travelM and velocityMps > 0) then 0 else velocityMps;
    posTremieDI = if positionM <= 0.07 then 1 else 0;
    posMaintenanceDI = if positionM >= 29.93 then 1 else 0;
    annotation(experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=0.02));
  end ContractCycle;

  model GrabClosureThenHoist "POC séquentiel : fermeture observée avant remontée"
    parameter Real closureStrokeM=3 "Course relative fictive de fermeture, à remplacer par cinématique réelle";
    parameter Real closingSpeedMps=1.3 "Hypothèse POC, pas une donnée machine";
    parameter Real hoistSpeedMps=1.2 "Hypothèse POC, pas une donnée machine";
    output Real m1CableM(start=20, fixed=true) "Longueur câble M1 image";
    output Real m2CableM(start=20, fixed=true) "Longueur câble M2 image";
    output Real bucketClosurePct;
    output Real bucketClosedDI;
    output Real closureCommand;
    output Real hoistRequest;
    output Real hoistActive "La simulation ne l'autorise que si fermeture observée";
    output Real hoistBlockedByOpenBucket;
  equation
    // 1..3.5 s : M2 crée l'écart de câble ; 4..9 s : les deux câbles remontent ensemble.
    closureCommand = if time >= 1 and time < 3.5 then 1 else 0;
    hoistRequest = if time >= 4 and time < 9 then 1 else 0;
    bucketClosurePct = min(100, max(0, 100 * (m2CableM - m1CableM) / closureStrokeM));
    bucketClosedDI = if bucketClosurePct >= 95 then 1 else 0;
    hoistActive = if hoistRequest > 0.5 and bucketClosedDI > 0.5 then 1 else 0;
    hoistBlockedByOpenBucket = if hoistRequest > 0.5 and bucketClosedDI <= 0.5 then 1 else 0;
    der(m1CableM) = if hoistActive > 0.5 then -hoistSpeedMps else 0;
    der(m2CableM) = if closureCommand > 0.5 then closingSpeedMps else
      if hoistActive > 0.5 then -hoistSpeedMps else 0;
    annotation(experiment(StartTime=0, StopTime=10, Tolerance=1e-6, Interval=0.02),
      Documentation(info="<html><p>Recette IHM Rumoca uniquement : la remontée image démarre après le retour fermeture image. Les longueurs, la course et les vitesses sont des hypothèses de POC ; ce modèle n'est pas le contrat M1/M2 PLC et ne représente aucune fonction de sécurité machine.</p></html>"));
  end GrabClosureThenHoist;

  model M3FaultsAndPvZone "POC T287/T296 : rebonds, frein et fréquence PV"
    parameter Real pvPositionM=5 "Position PV provisoire, à confirmer";
    parameter Real pvHalfWidthM=0.7 "Demi-largeur zone PV provisoire";
    parameter Real p1PositionM=20 "Position P1 provisoire, à confirmer";
    parameter Real normalFrequencyHz=50 "Fréquence hors PV demandée";
    parameter Real pvFrequencyHz=15 "Fréquence demandée en zone PV";
    output Real positionM(start=0, fixed=true);
    output Real velocityMps(start=0, fixed=true);
    output Real frequencyTargetHz;
    output Real pvZoneDI;
    output Real tremieIdealDI;
    output Real tremieRawDI "Image capteur avec rebond injecté";
    output Real p1IdealDI;
    output Real p1RawDI "Image capteur avec rebond injecté";
    output Real brakeReleaseCmd;
    output Real brakeFeedbackDI "Retour frein : défaut collé à 10 s";
    output Real brakeStuckFaultDI;
    output Real sensorBounceFaultDI;
  protected
    Real direction;
    Real brakeOpen(start=0, fixed=true);
    Real targetVelocity;
  equation
    // Aller vers Maintenance, puis retour Trémie : profil déterministe pour visualisation des défauts.
    direction = if time >= 1 and time < 10 then 1 else if time >= 11 and time < 20 then -1 else 0;
    brakeReleaseCmd = if abs(direction) > 0.5 then 1 else 0;
    der(brakeOpen) = ((if brakeReleaseCmd > 0.5 then 1 else 0) - brakeOpen) / 0.10;
    // Injection : le frein peut rester fermé malgré la commande de desserrage.
    brakeStuckFaultDI = if time >= 13 and time < 14.5 then 1 else 0;
    brakeFeedbackDI = if brakeStuckFaultDI > 0.5 then 0 else if brakeOpen > 0.95 then 1 else 0;
    pvZoneDI = if positionM >= pvPositionM-pvHalfWidthM and positionM <= pvPositionM+pvHalfWidthM then 1 else 0;
    frequencyTargetHz = if abs(direction) < 0.5 then 0 else if pvZoneDI > 0.5 then pvFrequencyHz else normalFrequencyHz;
    targetVelocity = if brakeFeedbackDI > 0.5 then direction * frequencyTargetHz / normalFrequencyHz * 3 else 0;
    der(velocityMps) = (targetVelocity - velocityMps) / 0.12;
    der(positionM) = if (positionM <= 0 and velocityMps < 0) or (positionM >= 30 and velocityMps > 0) then 0 else velocityMps;
    tremieIdealDI = if positionM <= 0.07 then 1 else 0;
    p1IdealDI = if positionM >= p1PositionM-0.07 and positionM <= p1PositionM+0.07 then 1 else 0;
    // Rebond déterministe autour du passage Trémie/P1 ; le PLC doit qualifier cette image.
    sensorBounceFaultDI = if (time >= 1 and time < 1.08) or
      (positionM >= p1PositionM-0.10 and positionM <= p1PositionM+0.10) then 1 else 0;
    tremieRawDI = if time >= 1 and time < 1.08 then if sin(300*time) > 0 then tremieIdealDI else 1-tremieIdealDI else tremieIdealDI;
    p1RawDI = if positionM >= p1PositionM-0.10 and positionM <= p1PositionM+0.10 then
      if sin(300*time) > 0 then p1IdealDI else 1-p1IdealDI else p1IdealDI;
    annotation(experiment(StartTime=0, StopTime=21, Tolerance=1e-6, Interval=0.02),
      Documentation(info="<html><p>POC Rumoca dédié aux sujets T287/T296. Les rebonds, la zone PV et le défaut frein sont des injections de recette. Ils ne modifient aucune logique PLC ; le PLC reste responsable de qualifier les DI, d'arbitrer les défauts et de décider l'arrêt.</p></html>"));
  end M3FaultsAndPvZone;
end RumocaM3Poc;
