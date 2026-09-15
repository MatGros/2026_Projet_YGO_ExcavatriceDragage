#!/usr/bin/env python3
"""Guard T291-A: automatic dive M1=P4 / M2=P5 stays narrowly scoped.

This check is intentionally textual. It prevents the trial from silently becoming
a broad bypass of M1/M2 contactor concordance or a manual/maintenance behavior.
"""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8", errors="replace")


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def main() -> int:
    errors: list[str] = []

    cycle = read("CODE/G_CYCLE/FB_CycleSemiAuto.st")
    prg03 = read("CODE/M_MAIN/PRG_03_Modes_Cycle.st")
    prg04 = read("CODE/M_MAIN/PRG_04_Treuils_Benne.st")
    prg06 = read("CODE/M_MAIN/PRG_06_Outputs.st")
    sync = read("CODE/H_TREUILS_BENNE/FB_SyncContactor.st")
    winch_sync = read("CODE/H_TREUILS_BENNE/FB_WinchSync.st")
    cycle_cmd = read("CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCmd.st")

    require("TglAutoDiveM2Step5Trial : BOOL := FALSE" in cycle_cmd,
            "IHM trial toggle must be non-persistent and default FALSE", errors)
    require("AutoDiveM2Step5TrialLatched := CfgAutoDiveM2Step5Trial;" in cycle,
            "Cycle must latch the trial only before AX4 dive start", errors)
    require("WinchM1Cmd.StepTgt  := CST_StepDive;" in cycle,
            "M1 dive command must remain tied to CST_StepDive/P4", errors)
    require("WinchM2Cmd.StepTgt  := DiveM2StepTgt;" in cycle,
            "M2 dive command must use the selected P4/P5 target", errors)
    require("(M1_SpeedStepApplied > CST_StepDive)" in cycle,
            "Cycle cause 8 must still forbid M1 above P4", errors)
    require("(M2_SpeedStepApplied > DiveM2StepTgt)" in cycle,
            "Cycle cause 8 must cap M2 to the selected dive target", errors)
    require("State = E_AutoCycleStep.AX4_DESCEND_DIVING" in cycle
            and "State = E_AutoCycleStep.AX7_SEARCH_BOTTOM" in cycle,
            "Trial publication must be limited to automatic dive states AX4..AX7", errors)
    require("CfgAutoDiveM2Step5Trial := GVL_IHM.CycleSemiAuto.Cmd.TglAutoDiveM2Step5Trial" in prg03,
            "PRG03 must wire the IHM trial toggle into FB_CycleSemiAuto", errors)
    require("Data.AutoDiveM1Step4M2Step5Active          := instCycleSemiAuto.AutoDiveM1Step4M2Step5Active" in prg03,
            "PRG03 must publish the active trial profile", errors)
    require("DescentStep45Permit := PRG_03_Modes_Cycle.Data.AutoDiveM1Step4M2Step5Active" in prg04,
            "PRG04 upstream sync monitor must receive the trial permit", errors)
    require("AND (EffectiveMaxStepDescent = 4)" in prg04
            and "AND (CommonMaxStepDescent = EffectiveMaxStepDescent)" in prg04
            and "M2MaxStepDown := 5;" in prg04,
            "PRG04 must open only the nominal M2 descent cap to P5 without overriding safety reductions", errors)
    require("ReqM1Winch.MaxStepDown              := CommonMaxStepDescent;" in prg04,
            "M1 must keep the common P4 descent cap", errors)
    require("WinchBothFinalStep45Coherent :=" in prg04
            and "RequestedStep = 4" in prg04
            and "RequestedStep = 5" in prg04,
            "PRG04 final publication guard must accept only shaped M1=P4/M2=P5", errors)
    require("Data.AutoDiveM1Step4M2Step5Active := PRG_03_Modes_Cycle.Data.AutoDiveM1Step4M2Step5Active" in prg04,
            "PRG04 must relay the trial profile to PRG06", errors)
    require("DescentStep45Permit := PRG_04_Treuils_Benne.Data.AutoDiveM1Step4M2Step5Active" in prg06,
            "PRG06 final sync monitor must receive the relayed trial permit", errors)
    require("DescentStep45Matched := DescentStep45Permit" in sync
            and "SpeedStepTable.P4R1" in sync
            and "SpeedStepTable.P5R4" in sync,
            "FB_SyncContactor must decode the exact P4/P5 table vectors", errors)
    require("Diag.RelayFwdMismatch" in sync and "Diag.RelayRevMismatch" in sync,
            "FB_SyncContactor must keep direction mismatch diagnostics active", errors)
    require("DescentStep45Permit             : BOOL := FALSE" in winch_sync
            and "SpeedStepTable                  : ST_SpeedStepTable" in winch_sync,
            "FB_WinchSync must expose the narrow permit and speed table", errors)

    if errors:
        print("G498 T291-A guard: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("G498 T291-A guard: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
