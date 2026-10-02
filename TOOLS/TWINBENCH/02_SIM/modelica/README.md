# POC OpenModelica — Translation M3

Objectif : vérifier rapidement la chaîne **ouvrir → simuler → tracer**. Ce POC n'est pas une
preuve de fidélité mécanique et ne communique pas avec le PLC.

1. From the master menu, select `Run the local M3 simulation` → `Open the Modelica model in OMEdit`.
2. In OMEdit, expand `M3_POC > Examples`.
3. Double-click `TranslationM3` and open **Diagram** to inspect the connected blocks.
4. Choose a scenario and its parameters:
   - `Examples > AllerRetour` : test déterministe historique ;
   - `Examples > BoucleLocale` : trajet répété piloté par les retours capteurs.
   In `BoucleLocale`, adjust `loopFrequency_Hz`, the two pauses, and `cycleCount`
   (`0` = loop until the stop time), then click **Simulate**.
5. Plot `plant.measurements.positionAct_M`, `plant.measurements.velocityAct_Mps`,
   `plant.measurements.frequencyCmd_Hz`, `plant.measurements.frequencyAct_Hz`,
   `plant.feedback.brakeIsOpen`, `controller.state.phaseCode`,
   `controller.state.completedCycles` et `plant.deviceState.sensorsWord`.

`LocalLoopController` is a separate test stimulus generator. It does not represent PLC logic
and does not communicate with external equipment.

Reference values: sensors at 0/5/15/20/30 m; hypothetical mechanical stops at -0.30/30.30 m;
provisional gain 0.02 m/(Hz·s), equivalent to 1 m/s at 50 Hz.
