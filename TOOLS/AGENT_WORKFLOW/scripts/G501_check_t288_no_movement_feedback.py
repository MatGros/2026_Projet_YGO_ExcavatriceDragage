#!/usr/bin/env python3
"""G501 - Contrat statique T288, absence de mouvement sous commande."""
from pathlib import Path
import re
import sys


def read(root: Path, relative: str) -> str:
    path = root / relative
    if not path.is_file():
        raise FileNotFoundError(relative)
    return path.read_text(encoding="utf-8")


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    errors: list[str] = []

    try:
        safety = read(root, "CODE/H_TREUILS_BENNE/FB_Safety_Winch.st")
        hmi = read(root, "CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st")
        tests = read(root, "TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_safety_winch.st")
    except FileNotFoundError as exc:
        print(f"G501 FAIL: fichier absent: {exc}")
        return 1

    match = re.search(r"TonNoMovement\s*\((.*?)\n\s*\);", safety, re.DOTALL)
    if not match:
        errors.append("appel TonNoMovement absent")
    else:
        timer = match.group(1)
        for required in ("MovementCommanded", "BrakeFeedback", "EncoderAvailable", "NOT PositionMovementDetected"):
            if required not in timer:
                errors.append(f"garde TonNoMovement absente: {required}")
        if "FwdRevSpeedFeedbackOff" in timer:
            errors.append("retour collectif interdit encore l absence de mouvement")

    if not re.search(r"NoMovementTimeout\s*:\s*TIME\s*:=\s*T#3s;", safety):
        errors.append("NoMovementTimeout=3s absent")
    if "OR CauseOppositeDirActive OR CauseNoMovementActive;" not in safety:
        errors.append("CauseNoMovementActive non route vers SafeStop")
    power_match = re.search(r"CausesPowerCutOffActive\s*:=\s*(.*?);", safety, re.DOTALL)
    if not power_match or "CauseNoMovementActive" in power_match.group(1):
        errors.append("CauseNoMovementActive routee vers PowerCutOff")

    for axis in ("M1", "M2"):
        expected = f"[{axis}] ErrorID:16 - discordance commande/retour/mouvement"
        if expected not in hmi:
            errors.append(f"message IHM ErrorID 16 {axis} absent")

    if "TC-P10-054 T288" not in tests or "FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := TRUE" not in tests:
        errors.append("test T288 retour collectif au repos absent")
    if "TC-P10-055 T288" not in tests or "FwdRevSpeedFeedbackOff := FALSE, BrakeFeedback := TRUE" not in tests:
        errors.append("test retour contacteur engage absent")

    if errors:
        for error in errors:
            print(f"G501 FAIL: {error}")
        return 1

    print("G501 PASS: ErrorID 16 couvre les deux retours contacteurs, SafeStop seul apres 3s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
