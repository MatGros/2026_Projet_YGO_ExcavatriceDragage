within;
model M3_LiveFMU
  "Façade scalaire FMI du POC M3 — banc local uniquement"

  parameter Real communicationStep_S=0.01
    "Pas de communication visé par le banc live";

  input Real directionCmd(min=-1, max=1)=0
    "-1 vers Trémie, 0 arrêt, +1 vers Maintenance";
  input Real frequencyCmd_Hz(min=0, max=50)=0
    "Consigne fréquence appliquée lorsque la direction est non nulle";
  input Boolean brakeReleaseCmd=false
    "TRUE = demande de desserrage du frein";

  output Real simulationTime_S=time;
  output Integer scanCounter(start=0, fixed=true)
    "Compteur des événements discrets de 10 ms";
  output Boolean sampleToggle(start=false, fixed=true)
    "Change d'état à chaque événement de 10 ms";
  output Real positionAct_M;
  output Real velocityAct_Mps;
  output Real frequencyCmdApplied_Hz;
  output Real frequencyAct_Hz;
  output Boolean brakeIsOpen;
  output Boolean tremiePositionIsActive;
  output Boolean pvPositionIsActive;
  output Boolean p2PositionIsActive;
  output Boolean p1PositionIsActive;
  output Boolean maintenancePositionIsActive;
  output Integer sensorsWord;
  output Integer driveStatusWord;
  output Boolean commandConflict;
  output Boolean hardStopTremieActive;
  output Boolean hardStopMaintenanceActive;

  M3_POC.TranslationM3 plant
    annotation(Placement(transformation(extent={{-10,-10},{10,10}})));

equation
  plant.commands.cmdMoveToTremie = directionCmd < -0.05;
  plant.commands.cmdMoveToMaintenance = directionCmd > 0.05;
  plant.commands.cmdBrakeRelease = brakeReleaseCmd;
  plant.commands.cmdFrequency_Hz = if abs(directionCmd) > 0.05 then
    min(max(frequencyCmd_Hz, 0), plant.configuration.frequencyMax_Hz) else 0;

  positionAct_M = plant.measurements.positionAct_M;
  velocityAct_Mps = plant.measurements.velocityAct_Mps;
  frequencyCmdApplied_Hz = plant.measurements.frequencyCmd_Hz;
  frequencyAct_Hz = plant.measurements.frequencyAct_Hz;
  brakeIsOpen = plant.feedback.brakeIsOpen;
  tremiePositionIsActive = plant.feedback.tremiePositionIsActive;
  pvPositionIsActive = plant.feedback.pvPositionIsActive;
  p2PositionIsActive = plant.feedback.p2PositionIsActive;
  p1PositionIsActive = plant.feedback.p1PositionIsActive;
  maintenancePositionIsActive = plant.feedback.maintenancePositionIsActive;
  sensorsWord = plant.deviceState.sensorsWord;
  driveStatusWord = plant.deviceState.driveStatusWord;
  commandConflict = plant.diagnostics.commandConflict;
  hardStopTremieActive = plant.diagnostics.hardStopTremieActive;
  hardStopMaintenanceActive = plant.diagnostics.hardStopMaintenanceActive;

algorithm
  when sample(0, communicationStep_S) then
    scanCounter := pre(scanCounter) + 1;
    sampleToggle := not pre(sampleToggle);
  end when;

  annotation(
    experiment(StartTime=0, StopTime=120, Tolerance=1e-6, Interval=0.01),
    Documentation(info="<html><p>Façade exclusivement destinée au POC live T405. Elle ne contient aucune logique PLC et ne communique avec aucune machine.</p></html>"));
end M3_LiveFMU;
