(* ═══════════════════════════════════════════════════════════════
   📡 FB_AcquisitionRouter — Sélecteur atomique Réel / Simulé
   ───────────────────────────────────────────────────────────────
   📄 AF06 §2, AF13 §2
   🎯 Reprend strictement le comportement d'aiguillage historique :
      un domaine entier est réel ou simulé, jamais un mélange.
   🛡️ Ce FB ne qualifie ni polarité, ni safety, ni autorisation.
   ═══════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_AcquisitionRouter
VAR_INPUT
    HwReal : ST_HardwareImage;
    HwSim : ST_HardwareImage;
    SimulationModeActive : BOOL;
    SimWinchActive : BOOL;
    SimTranslationActive : BOOL;
    SimOperatorActive : BOOL;
    SimMachineActive : BOOL;
END_VAR
VAR_OUTPUT
    HwIn : ST_HardwareImage;
    WinchInputSourceChanged : BOOL;
END_VAR
VAR
    WinchInputSourceSimulated : BOOL;
    PreviousWinchInputSourceSimulated : BOOL;
    WinchInputSourceInitialized : BOOL;
END_VAR

(* Le premier cycle mémorise la source sans générer de faux front. *)
WinchInputSourceSimulated := SimulationModeActive AND SimWinchActive;
IF NOT WinchInputSourceInitialized THEN
    PreviousWinchInputSourceSimulated := WinchInputSourceSimulated;
    WinchInputSourceInitialized := TRUE;
    WinchInputSourceChanged := FALSE;
ELSE
    WinchInputSourceChanged := WinchInputSourceSimulated <> PreviousWinchInputSourceSimulated;
    PreviousWinchInputSourceSimulated := WinchInputSourceSimulated;
END_IF;

(* Sélection atomique par domaine : aucune fusion réel/simulation. *)
IF WinchInputSourceSimulated THEN
    HwIn.Winch := HwSim.Winch;
ELSE
    HwIn.Winch := HwReal.Winch;
END_IF;

IF SimulationModeActive AND SimTranslationActive THEN
    HwIn.Translation := HwSim.Translation;
ELSE
    HwIn.Translation := HwReal.Translation;
END_IF;

IF SimulationModeActive AND SimOperatorActive THEN
    HwIn.Operator := HwSim.Operator;
ELSE
    HwIn.Operator := HwReal.Operator;
END_IF;

IF SimulationModeActive AND SimMachineActive THEN
    HwIn.Machine := HwSim.Machine;
ELSE
    HwIn.Machine := HwReal.Machine;
END_IF;
