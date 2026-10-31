# -*- coding: utf-8 -*-
"""T423_UTIL_rearm_emergency — Diagnostic et Réarmement AU / Puissance / Homing.

A exécuter dans CODESYS : Tools > Scripting > Execute Script File...
"""

import os
import time

ENGINE_PATH = os.path.join(os.path.dirname(__file__), "T423_engine.py")
with open(ENGINE_PATH, "rb") as f:
    exec(compile(f.read(), ENGINE_PATH, "exec"), globals(), globals())

DIAG_PATHS = (
    "GVL_Simulation.SimulationModeActive",
    "GVL_Simulation.SimSafetyActive",
    "GVL_Simulation.SimChainOk",
    "PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI",
    "PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI",
    "PRG_06_Outputs.PowerCutOffReq",
    "PRG_06_Outputs.PowerCutOffActive",
    "PRG_06_Outputs.EmergencyState.Step",
    "PRG_06_Outputs.EmergencyState.Armable",
    "PRG_06_Outputs.EmergencyDiag.LastAbortCause",
    "PRG_06_Outputs.EmergencyDiag.RedundancyTestFailed",
    "PRG_06_Outputs.EmergencyDiag.ArmFailed",
    "PRG_02_Acquisition.Data.MachineHoming.Step",
    "PRG_02_Acquisition.Data.MachineHoming.Homed",
    "PRG_03_Modes_Cycle.Data.Auth.Mode",
)


def _read_diag(online_app):
    vals = list(online_app.read_values(tuple(DIAG_PATHS)))
    return dict(zip(DIAG_PATHS, vals))


def _print_diag(d):
    print("\n--- DIAGNOSTIC SÉCURITÉ & HOMING MACHINE ---")
    print("  SimulationModeActive       : " + str(d.get("GVL_Simulation.SimulationModeActive", "")))
    print("  SimSafetyActive            : " + str(d.get("GVL_Simulation.SimSafetyActive", "")))
    print("  SimChainOk                 : " + str(d.get("GVL_Simulation.SimChainOk", "")))
    print("  EmergencyChainClosed_DI    : " + str(d.get("PRG_02_Acquisition.HwIn.Machine.EmergencyChainClosed_DI", "")))
    print("  PowerContactorEngaged_DI   : " + str(d.get("PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI", "")))
    print("  PowerCutOffReq (Blocage)   : " + str(d.get("PRG_06_Outputs.PowerCutOffReq", "")))
    print("  AU Armable                 : " + str(d.get("PRG_06_Outputs.EmergencyState.Armable", "")))
    print("  AU Sequence Step           : " + str(d.get("PRG_06_Outputs.EmergencyState.Step", "")))
    print("  AU LastAbortCause          : " + str(d.get("PRG_06_Outputs.EmergencyDiag.LastAbortCause", "")))
    print("  Machine Homing Step        : " + str(d.get("PRG_02_Acquisition.Data.MachineHoming.Step", "")) + " (60 = Homed)")
    print("  Machine Homed              : " + str(d.get("PRG_02_Acquisition.Data.MachineHoming.Homed", "")))
    print("  Mode Actif                 : " + str(d.get("PRG_03_Modes_Cycle.Data.Auth.Mode", "")))
    print("-" * 50)


online_app = get_online_app()
if online_app is not None:
    with online_app:
        print("\n>>> Demarrage T423_UTIL_rearm_emergency (Diagnostic & Action) ...")
        
        d_init = _read_diag(online_app)
        _print_diag(d_init)

        # 1. Mise en place des drapeaux de simulation nécessaires
        print("1. Armement des drapeaux de simulation securite...")
        write_var(online_app, "GVL_Simulation.SimulationModeActive", "TRUE")
        write_var(online_app, "GVL_Simulation.SimSafetyActive", "TRUE")
        write_var(online_app, "GVL_Simulation.SimChainOk", "TRUE")
        time.sleep(0.2)

        # 2. Acquittement des defauts (Reset) pour deverrouiller l'AU
        print("2. Envoi impulsion Reset general (deverrouillage)...")
        write_var(online_app, "GVL_IHM.Modes.Cmd.BtnFaultReset", "TRUE")
        time.sleep(0.3)
        write_var(online_app, "GVL_IHM.Modes.Cmd.BtnFaultReset", "FALSE")
        time.sleep(0.5)

        # 3. Envoi impulsion d'armement AU
        print("3. Envoi impulsion réarmement contacteur puissance...")
        write_var(online_app, "GVL_IHM.Emergency.Cmd.BtnEmergencyArming", "TRUE")
        time.sleep(0.5)
        write_var(online_app, "GVL_IHM.Emergency.Cmd.BtnEmergencyArming", "FALSE")
        
        # Attente sequence contacteur (1.5 s)
        time.sleep(1.5)

        # 4. Diagnostic apres armement
        d_after = _read_diag(online_app)
        _print_diag(d_after)

        banner = read_banner(online_app)
        print_banner("BANDEAU FINAL", banner)
