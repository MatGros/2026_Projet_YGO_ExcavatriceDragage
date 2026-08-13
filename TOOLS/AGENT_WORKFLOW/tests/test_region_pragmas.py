"""Garde-fou des Regions Pragma CODESYS dans les POU ST selectionnes."""
from __future__ import annotations

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
CODE_DIR = ROOT / "CODE"

TARGETS = {
    "AU/FB_Safety_EmergencyManagementLogic.st",
    "CODEURS/FB_Encoder_Homing.st",
    "CYCLE/FB_Cycle.st",
    "CYCLE/FB_DiveSearch.st",
    "CYCLE/FB_ExtractionSequence.st",
    "DEPANNAGE/FB_TroubleshootingView.st",
    "DIAG/FB_Diag_Ethercat.st",
    "JOYSTICK/FB_Joystick.st",
    "MAIN/PRG_02_Acquisition.st",
    "MAIN/PRG_04_Treuils_Benne.st",
    "MAIN/PRG_05_Translation.st",
    "MAIN/PRG_07_Supervision.st",
    "MODES/FB_Modes.st",
    "SIMULATION/FB_SimBench.st",
    "TRANSLATION/FB_Safety_Translation.st",
    "TRANSLATION/FB_Translation.st",
    "TREUILS/BENNE/FB_Bucket.st",
    "TREUILS/FB_Safety_Winch.st",
    "TREUILS/FB_Winch.st",
    "TREUILS/FB_WinchSync.st",
}

REGION_START = re.compile(r'^\{region\s+"([^"\r\n]+)"\}$', re.IGNORECASE)
REGION_END = re.compile(r"^\{endregion\}$", re.IGNORECASE)
REGION_LIKE = re.compile(r"^\{(?:region|endregion)\b", re.IGNORECASE)
POU_START = re.compile(r"^\s*(?:PROGRAM|FUNCTION_BLOCK)\b", re.IGNORECASE)


def _relative(path: Path) -> str:
    return path.relative_to(CODE_DIR).as_posix()


def _is_forbidden(path: Path) -> bool:
    return path.stem.endswith("_LD") or path.name.startswith(("GVL_", "ST_", "E_"))


def test_region_pragmas_are_well_formed_and_limited_to_st_pous() -> None:
    for path in CODE_DIR.rglob("*.st"):
        stack: list[tuple[str, int]] = []
        has_region = False
        is_pou = False
        for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            line = raw_line.strip()
            is_pou = is_pou or bool(POU_START.match(line))
            start = REGION_START.match(line)
            if start:
                has_region = True
                stack.append((start.group(1), line_number))
                continue
            if REGION_END.match(line):
                has_region = True
                assert stack, f"{_relative(path)}:{line_number}: {{endregion}} sans {{region}}"
                stack.pop()
                continue
            assert not REGION_LIKE.match(line), f"{_relative(path)}:{line_number}: pragma Region mal forme"

        assert not stack, f"{_relative(path)}:{stack[-1][1]}: {{region}} non fermee"
        if has_region:
            assert is_pou, f"{_relative(path)}: Region hors PROGRAM/FUNCTION_BLOCK"
            assert not _is_forbidden(path), f"{_relative(path)}: Region interdite dans ce type de source"


def test_selected_multi_responsibility_pous_are_regioned() -> None:
    missing = [relative for relative in sorted(TARGETS) if '{region ' not in (CODE_DIR / relative).read_text(encoding="utf-8").lower()]
    assert not missing, f"Regions manquantes dans les POU cibles: {', '.join(missing)}"