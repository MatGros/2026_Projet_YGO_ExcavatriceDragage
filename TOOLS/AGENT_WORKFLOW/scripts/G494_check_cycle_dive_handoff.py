#!/usr/bin/env python3
"""G494 - Contrat de securite du handoff AX3 -> AX4 (T257)."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
CYCLE = (ROOT / "CODE/G_CYCLE/FB_CycleSemiAuto.st").read_text(encoding="utf-8-sig")
PRG03 = (ROOT / "CODE/M_MAIN/PRG_03_Modes_Cycle.st").read_text(encoding="utf-8-sig")
PRG04 = (ROOT / "CODE/M_MAIN/PRG_04_Treuils_Benne.st").read_text(encoding="utf-8-sig")

REQUIRED = {
    "etat attente dedie": "E_AutoCycleStep.AX3_WAIT_DIVE_START:",
    "preuve benne ouverte non busy": "IF Benne_IsOpen AND NOT Benne_Busy THEN",
    "qualification poussee Y-": "DiveStartStopTimer.Q AND DeadmanArmed AND JoystickPush",
    "vitesses valides": "M1_SpeedValid AND M2_SpeedValid",
    "contacteurs retombes": "M1_ContactorsReleased AND M2_ContactorsReleased",
    "freins appliques": "M1_BrakeApplied AND M2_BrakeApplied",
    "timeout latche": "instCauses[10].Latching := TRUE",
    "Kobold directionnel": "IF DeadmanArmed AND JoystickPush AND KoboldInitTimer.Q THEN",
}
errors = [name for name, token in REQUIRED.items() if token not in CYCLE]
if "Data.WinchBothIntent.Active     := WinchBothMotionActive;" not in PRG03:
    errors.append("publication intention BOTH semi-auto")
if "(PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.SEMI_AUTO)" not in PRG04:
    errors.append("barriere PRG04 bornee a SEMI_AUTO")
if "NOT WinchBothFinalRequestsCoherent" not in PRG04:
    errors.append("egalite effective des sorties M1/M2")
if errors:
    print("G494 FAIL: " + ", ".join(errors))
    sys.exit(1)
print("G494 PASS - invariants statiques handoff AX3/AX4 et barriere bornee SEMI_AUTO presents")
