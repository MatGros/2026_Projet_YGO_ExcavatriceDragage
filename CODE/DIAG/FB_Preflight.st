(* ═══════════════════════════════════════════════════════════════
   🩺 FB_Preflight — Verdict passif machine arrêtée
   📄 Doc : ARCHIVES/Doc/AUDITS/PreLivraison/TASKS/TASK_D1_Preflight_et_Symetrie_Winch_v1.0.md
   🔒 Observateur pur : aucun SafeStop, PowerCutOff ou ordre machine.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_Preflight
VAR_INPUT
    Execute : BOOL;
    MachineIsStill : BOOL;
    M1BrakeApplied, M2BrakeApplied, M3BrakeApplied : BOOL;
    M1ContactorsReleased, M2ContactorsReleased, M1ThermalOk, M2ThermalOk : BOOL;
    BrakeThermalOk, PhaseRotationOk, SlackCableTensioned, M3SensorWordIncoherent : BOOL;
    EmergencyChainClosed, PowerContactorEngaged, EncoderM1Operational, EncoderM2Operational : BOOL;
    HomedM1, HomedM2, M1PositionInBounds, M2PositionInBounds : BOOL;
END_VAR
VAR_OUTPUT
    PreflightOk : BOOL;
    PreflightDone : BOOL;
    PreflightBusy : BOOL;
    PreflightErrorId : WORD;
END_VAR
VAR
    ExecuteEdge : R_TRIG;
    BootPending : BOOL := TRUE;
    RequestPending : BOOL;
END_VAR

ExecuteEdge(CLK := Execute);
RequestPending := RequestPending OR ExecuteEdge.Q OR BootPending;
PreflightBusy := RequestPending AND NOT MachineIsStill;
IF NOT MachineIsStill THEN PreflightDone := FALSE; RETURN; END_IF;
IF NOT RequestPending THEN RETURN; END_IF;

PreflightErrorId := 0;
(* bit0..2 frein M1/M2/M3 serré; bit3..4 contacteurs M1/M2 retombés;
   bit5..6 thermique M1/M2 OK; bit7 thermique frein OK; bit8 phases OK;
   bit9 câble M2 tendu; bit10 mot M3 cohérent; bit11 contacteur sans chaîne;
   bit12..13 codeur M1/M2 opérationnel; bit14..15 homé et position bornée M1/M2. *)
IF NOT M1BrakeApplied THEN PreflightErrorId := PreflightErrorId OR 16#0001; END_IF;
IF NOT M2BrakeApplied THEN PreflightErrorId := PreflightErrorId OR 16#0002; END_IF;
IF NOT M3BrakeApplied THEN PreflightErrorId := PreflightErrorId OR 16#0004; END_IF;
IF NOT M1ContactorsReleased THEN PreflightErrorId := PreflightErrorId OR 16#0008; END_IF;
IF NOT M2ContactorsReleased THEN PreflightErrorId := PreflightErrorId OR 16#0010; END_IF;
IF NOT M1ThermalOk THEN PreflightErrorId := PreflightErrorId OR 16#0020; END_IF;
IF NOT M2ThermalOk THEN PreflightErrorId := PreflightErrorId OR 16#0040; END_IF;
IF NOT BrakeThermalOk THEN PreflightErrorId := PreflightErrorId OR 16#0080; END_IF;
IF NOT PhaseRotationOk THEN PreflightErrorId := PreflightErrorId OR 16#0100; END_IF;
IF NOT SlackCableTensioned THEN PreflightErrorId := PreflightErrorId OR 16#0200; END_IF;
IF M3SensorWordIncoherent THEN PreflightErrorId := PreflightErrorId OR 16#0400; END_IF;
IF PowerContactorEngaged AND NOT EmergencyChainClosed THEN PreflightErrorId := PreflightErrorId OR 16#0800; END_IF;
IF NOT EncoderM1Operational THEN PreflightErrorId := PreflightErrorId OR 16#1000; END_IF;
IF NOT EncoderM2Operational THEN PreflightErrorId := PreflightErrorId OR 16#2000; END_IF;
IF NOT HomedM1 OR NOT M1PositionInBounds THEN PreflightErrorId := PreflightErrorId OR 16#4000; END_IF;
IF NOT HomedM2 OR NOT M2PositionInBounds THEN PreflightErrorId := PreflightErrorId OR 16#8000; END_IF;
PreflightOk := (PreflightErrorId = 0); PreflightDone := TRUE; BootPending := FALSE; RequestPending := FALSE;
