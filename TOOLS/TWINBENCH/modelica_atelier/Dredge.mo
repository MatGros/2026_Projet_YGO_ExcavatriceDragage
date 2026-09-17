within ;
package Dredge "Plante hors ligne de dragage : aucune logique PLC ni safety"
  model TranslationM3Plant "M3 : contrat commandes finales -> image capteurs"
    input Real reqTremie=0 "Commande finale vers Trémie, 0/1";
    input Real reqMaintenance=0 "Commande finale vers Maintenance, 0/1";
    input Real speedCmdPct=0 "Consigne finale PLC, 0..100 %";
    input Real brakeReleaseCmd=0 "Commande finale frein ouvert, 0/1";
    parameter Real travelM=30 "Course Trémie à Maintenance";
    parameter Real fullTravelTimeS=8 "Temps SimBench historique à 100 %";
    parameter Real nominalFrequencyHz=40 "Référence SimBench historique, à calibrer";
    parameter Real brakeOpenDelayS=.10 "Hypothèse SimBench, à mesurer";
    parameter Real brakeCloseDelayS=.09 "Hypothèse SimBench, à mesurer";
    parameter Real sensorHysteresisM=.02 "Hypothèse SimBench, à mesurer";
    output Real positionM "Position M3 bornée, 0=Trémie";
    output Real velocityMps(start=0, fixed=true);
    output Real actualFrequencyHz;
    output Real brakeIsOpenDI "Retour capteur frein ouvert, 0/1";
    output Real posTremieDI "DI position Trémie, 0/1";
    output Real posPVDI "DI position PV, 0/1";
    output Real posP2DI "DI position P2, 0/1";
    output Real posP1DI "DI position P1, 0/1";
    output Real posMaintenanceDI "DI position Maintenance, 0/1";
    output Real statusWord "Image AC600 SimBench : 128 arrêt, 135 mouvement";
    output Real commandConflict "Deux directions finales actives";
    output Real hardStopTremie;
    output Real hardStopMaintenance;
  protected
    Real rawPosition(start=20, fixed=true) "Etat intégré avant projection sur course mécanique";
    Real brakeOpen(start=0, fixed=true);
    Real direction;
    Real targetVelocity;
    Real speedMps;
  equation
    // La plante applique seulement les commandes finales; elle ne calcule aucune permission.
    commandConflict = if reqTremie > .5 and reqMaintenance > .5 then 1 else 0;
    direction = if reqTremie > .5 and reqMaintenance <= .5 then -1 else
                if reqMaintenance > .5 and reqTremie <= .5 then 1 else 0;
    actualFrequencyHz = if direction <> 0 and not
                          ((positionM <= 0 and direction < 0) or
                           (positionM >= travelM and direction > 0))
                        then min(nominalFrequencyHz,
                          max(0, speedCmdPct)*nominalFrequencyHz/100) else 0;
    der(brakeOpen) = ((if brakeReleaseCmd > .5 then 1 else 0) - brakeOpen) /
                     (if brakeReleaseCmd > .5 then brakeOpenDelayS else brakeCloseDelayS);
    brakeIsOpenDI = if brakeOpen > .95 then 1 else 0;
    speedMps = travelM / max(.1, fullTravelTimeS) * actualFrequencyHz / nominalFrequencyHz;
    // La projection protège l'image capteurs des surcourses numériques au franchissement d'un pas FMU.
    positionM = min(travelM, max(0, rawPosition));
    targetVelocity = if brakeIsOpenDI > .5 and not
                        ((positionM <= 0 and direction < 0) or
                         (positionM >= travelM and direction > 0))
                     then direction*speedMps else 0;
    der(velocityMps) = (targetVelocity - velocityMps)/.15;
    // Butées physiques : l'état ne poursuit pas hors course et la position publiée reste bornée.
    der(rawPosition) = if (rawPosition <= 0 and velocityMps < 0) or
                           (rawPosition >= travelM and velocityMps > 0) then 0 else velocityMps;
    hardStopTremie = if positionM <= 0 and direction < 0 then 1 else 0;
    hardStopMaintenance = if positionM >= travelM and direction > 0 then 1 else 0;
    // Les sorties capteurs sont délibérément observables et versionnées; les cotes restent à relever.
    posTremieDI = if positionM <= .05 + sensorHysteresisM then 1 else 0;
    posPVDI = if positionM <= 5 + sensorHysteresisM then 1 else 0;
    posP2DI = if positionM <= 15 + sensorHysteresisM then 1 else 0;
    posP1DI = if positionM <= 20 + sensorHysteresisM then 1 else 0;
    posMaintenanceDI = if positionM >= travelM - .05 - sensorHysteresisM then 1 else 0;
    statusWord = if abs(velocityMps) > .01 then 135 else 128;
    annotation(experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=.01),
      Documentation(info="<html><p>Fondation L1 de migration SimBench : le modèle reçoit les commandes finales M3 et publie uniquement des faits capteurs simulés. Le PLC demeure propriétaire des autorisations, PowerCutOff, AU et aiguillage HwSim/HwIn.</p><p>Les constantes reprennent temporairement le SimBench historique et doivent être calibrées avant toute comparaison terrain.</p></html>"));
  end TranslationM3Plant;

  model WinchesM1M2Plant "M1/M2 : relais finaux -> codeurs, freins et cinématique de benne"
    input Real m1RelayFwd=0;
    input Real m1RelayRev=0;
    input Real m1StepNumber=0 "Palier PLC 0..5";
    input Real m1BrakeReleaseCmd=0 "TRUE = frein desserré";
    input Real m1SpeedContactor1=0;
    input Real m1SpeedContactor2=0;
    input Real m1SpeedContactor3=0;
    input Real m1SpeedContactor4=0;
    input Real m2RelayFwd=0;
    input Real m2RelayRev=0;
    input Real m2StepNumber=0;
    input Real m2BrakeReleaseCmd=0;
    input Real m2SpeedContactor1=0;
    input Real m2SpeedContactor2=0;
    input Real m2SpeedContactor3=0;
    input Real m2SpeedContactor4=0;
    parameter Real minSpeedMps=1 "Hypothèse SimBench palier 1";
    parameter Real maxSpeedMps=2 "Hypothèse SimBench palier 5";
    parameter Real cableMPerRev=2 "A confirmer sur tambours machine";
    parameter Real pointsPerRev=8192 "Codeur actuel";
    parameter Real initialRawM1=1000000;
    parameter Real initialRawM2=1100000;
    parameter Real brakeOpenDelayS=.10 "A mesurer";
    parameter Real brakeCloseDelayS=.10 "A mesurer";
    parameter Real coastTimeS=.35 "Equivalent provisoire roulis SimBench";
    parameter Real bucketClosedDeltaM=15 "A calibrer avec mouflage/benne";
    output Real m1CablePositionM(start=0, fixed=true);
    output Real m2CablePositionM(start=0, fixed=true);
    output Real m1VelocityMps;
    output Real m2VelocityMps;
    output Real cod1PosRaw;
    output Real cod2PosRaw;
    output Real cod1SpeedRaw "0.1 rpm, convention EtherCAT";
    output Real cod2SpeedRaw;
    output Real m1BrakeIsOpenDI;
    output Real m2BrakeIsOpenDI;
    output Real m1ContactorsReleasedDI;
    output Real m2ContactorsReleasedDI;
    output Real m1DirectionConflict;
    output Real m2DirectionConflict;
    output Real bucketDeltaM "M2 - M1";
    output Real bucketOpeningPct;
    output Real bucketOpenDI;
    output Real bucketClosedDI;
    output Real m2TensionedCableDI;
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
    m1DirectionConflict = if m1RelayFwd > .5 and m1RelayRev > .5 then 1 else 0;
    m2DirectionConflict = if m2RelayFwd > .5 and m2RelayRev > .5 then 1 else 0;
    m1Direction = if m1RelayFwd > .5 and m1RelayRev <= .5 then 1 else if m1RelayRev > .5 and m1RelayFwd <= .5 then -1 else 0;
    m2Direction = if m2RelayFwd > .5 and m2RelayRev <= .5 then 1 else if m2RelayRev > .5 and m2RelayFwd <= .5 then -1 else 0;
    der(m1BrakeOpen) = ((if m1BrakeReleaseCmd > .5 then 1 else 0) - m1BrakeOpen) /
                       (if m1BrakeReleaseCmd > .5 then brakeOpenDelayS else brakeCloseDelayS);
    der(m2BrakeOpen) = ((if m2BrakeReleaseCmd > .5 then 1 else 0) - m2BrakeOpen) /
                       (if m2BrakeReleaseCmd > .5 then brakeOpenDelayS else brakeCloseDelayS);
    m1BrakeIsOpenDI = if m1BrakeOpen > .95 then 1 else 0;
    m2BrakeIsOpenDI = if m2BrakeOpen > .95 then 1 else 0;
    m1Speed = minSpeedMps + max(0, min(5, m1StepNumber) - 1)*(maxSpeedMps-minSpeedMps)/4;
    m2Speed = minSpeedMps + max(0, min(5, m2StepNumber) - 1)*(maxSpeedMps-minSpeedMps)/4;
    m1TargetVelocity = if m1BrakeIsOpenDI > .5 then m1Direction*m1Speed else 0;
    m2TargetVelocity = if m2BrakeIsOpenDI > .5 then m2Direction*m2Speed else 0;
    der(m1VelocityMps) = (m1TargetVelocity-m1VelocityMps)/max(.02, coastTimeS);
    der(m2VelocityMps) = (m2TargetVelocity-m2VelocityMps)/max(.02, coastTimeS);
    der(m1CablePositionM) = m1VelocityMps;
    der(m2CablePositionM) = m2VelocityMps;
    cod1PosRaw = initialRawM1 + m1CablePositionM*pointsPerRev/cableMPerRev;
    cod2PosRaw = initialRawM2 + m2CablePositionM*pointsPerRev/cableMPerRev;
    cod1SpeedRaw = m1VelocityMps*60/(.1*cableMPerRev);
    cod2SpeedRaw = m2VelocityMps*60/(.1*cableMPerRev);
    m1ContactorsReleasedDI = if m1RelayFwd <= .5 and m1RelayRev <= .5 and m1SpeedContactor1 <= .5 and m1SpeedContactor2 <= .5 and m1SpeedContactor3 <= .5 and m1SpeedContactor4 <= .5 then 1 else 0;
    m2ContactorsReleasedDI = if m2RelayFwd <= .5 and m2RelayRev <= .5 and m2SpeedContactor1 <= .5 and m2SpeedContactor2 <= .5 and m2SpeedContactor3 <= .5 and m2SpeedContactor4 <= .5 then 1 else 0;
    bucketDeltaM = m2CablePositionM-m1CablePositionM;
    bucketOpeningPct = min(100, max(0, 100*(1-bucketDeltaM/max(.01,bucketClosedDeltaM))));
    bucketOpenDI = if bucketOpeningPct >= 95 then 1 else 0;
    bucketClosedDI = if bucketOpeningPct <= 5 then 1 else 0;
    m2TensionedCableDI = if bucketDeltaM >= -.2 then 1 else 0;
    annotation(experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=.01),
      Documentation(info="<html><p>L2 provisoire. Cette plante ne remplace aucun FB PLC : elle transforme les relais finaux, paliers et freins en retour codeurs/freins/contacteurs. Le développement tambour, l'inertie, les charges, le mouflage et les cotes benne sont à mesurer.</p></html>"));
  end WinchesM1M2Plant;

  package Examples
    model M3ContractCycle "Exemple de commandes finales M3 pour OMEdit"
      TranslationM3Plant plant(
        reqMaintenance=if time >= 1 and time < 5 then 1 else 0,
        reqTremie=if time >= 7 and time < 11 then 1 else 0,
        speedCmdPct=if time >= 1 and time < 5 then 70 else if time >= 7 and time < 11 then 55 else 0,
        brakeReleaseCmd=if (time >= 1 and time < 5) or (time >= 7 and time < 11) then 1 else 0);
      annotation(experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=.01));
    end M3ContractCycle;

    model M1M2BucketCycle "Exemple treuils : levage conjoint puis fermeture M2"
      WinchesM1M2Plant plant(
        m1RelayFwd=if time >= 1 and time < 4 then 1 else 0,
        m2RelayFwd=if (time >= 1 and time < 4) or (time >= 6 and time < 10) then 1 else 0,
        m1RelayRev=if time >= 6 and time < 10 then 1 else 0,
        m1StepNumber=if time >= 1 and time < 4 then 3 else if time >= 6 and time < 10 then 2 else 0,
        m2StepNumber=if time >= 1 and time < 4 then 3 else if time >= 6 and time < 10 then 2 else 0,
        m1BrakeReleaseCmd=if (time >= 1 and time < 4) or (time >= 6 and time < 10) then 1 else 0,
        m2BrakeReleaseCmd=if (time >= 1 and time < 4) or (time >= 6 and time < 10) then 1 else 0);
      annotation(experiment(StartTime=0, StopTime=12, Tolerance=1e-6, Interval=.01));
    end M1M2BucketCycle;
  end Examples;
  annotation(uses(Modelica(version="4.0.0")));
end Dredge;
