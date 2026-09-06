from pathlib import Path
import subprocess
import sys


SCRIPT = Path(__file__).parents[1] / "scripts" / "G495_check_cycle_sat_contract.py"


def _tree(tmp_path: Path, cycle: str) -> Path:
    files = {
        "CODE/G_CYCLE/FB_CycleSemiAuto.st": cycle,
        "CODE/M_MAIN/PRG_03_Modes_Cycle.st":
            "\n".join((
                "JoystickPull            := PRG_02_Acquisition.Data.Joystick.AxisY.DirectionPositive;",
                "BottomTouchConfirmed   := instCycleSemiAuto.BottomTouched;",
                "Data.SequenceState.CycleChecksInhibited   := FALSE;",
                "Data.SequenceState.ForceStepPrepared      := FALSE;",
            )),
        "CODE/M_MAIN/PRG_04_Treuils_Benne.st":
            "(PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.SEMI_AUTO)",
    }
    for rel, text in files.items():
        path = tmp_path / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    return tmp_path


def test_g495_accepts_complete_contract(tmp_path: Path):
    cycle = "\n".join((
        "JoystickPull", "TouchPositionM1", "TouchPositionM2", "ForceStepCandidate", "ForceStepWaiting",
        "ABS(WinchSyncDeltaM) <= CtrlAscentToleranceM",
        "BottomTouchStabTimer.Q AND DiveStartStopped",
        "CycleChecksInhibited := CfgCycleChecksInhibit AND CfgCommissioningEnable", "ForceStepPrepared",
        "21: ForceStepCandidate := E_AutoCycleStep.AX3_WAIT_DIVE_START",
        "(CfgForceStepTarget <> 18) AND (CfgForceStepTarget <> 19)",
        *("RunRequest := DeadmanArmed AND JoystickPull" for _ in range(8)),
    ))
    result = subprocess.run([sys.executable, str(SCRIPT), str(_tree(tmp_path, cycle))], capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr


def test_g495_rejects_pseudo_feedback_and_raw_delta(tmp_path: Path):
    cycle = "\n".join((
        "JoystickPull", "TouchPositionM1", "TouchPositionM2",
        "ABS(WinchSyncDeltaM) <= CtrlAscentToleranceM",
        "BottomTouchStabTimer.Q AND DiveStartStopped",
        "CycleChecksInhibited := CfgCycleChecksInhibit AND CfgCommissioningEnable",
        "ForceStepPrepared", "ForceStepCandidate", "ForceStepWaiting",
        "21: ForceStepCandidate := E_AutoCycleStep.AX3_WAIT_DIVE_START",
        "(CfgForceStepTarget <> 18) AND (CfgForceStepTarget <> 19)",
        *("RunRequest := DeadmanArmed AND JoystickPull" for _ in range(8)),
        "KoboldContactorFeedback", "ABS(M1_CablePosM - M2_CablePosM) <= CtrlAscentToleranceM",
    ))
    result = subprocess.run([sys.executable, str(SCRIPT), str(_tree(tmp_path, cycle))], capture_output=True, text=True)
    assert result.returncode == 1
    assert "pseudo-feedback" in result.stdout
    assert "ecart brut AX11" in result.stdout
