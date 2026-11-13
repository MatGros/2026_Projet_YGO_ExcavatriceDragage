"""Runner sandbox strucpp pour M3 (100% lecture seule sur CODE/)."""
from __future__ import annotations

import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(ROOT / "TOOLS/TEST_AUTO_CI/scripts"))
import run_tests

TEST_FILE = Path(__file__).parent / "test_m3_sandbox.st"
HARNESS_FILE = "TOOLS/TEST_AUTO_CI/MOCKS/FB_TestHarnessT417_M3.st"
REGISTRY_COMPONENTS = (
    "FB_SimBench",
    "FB_CycleSemiAuto",
    "FB_Translation",
    "FB_Safety_Translation",
    "FB_TranslationOutputInterlock",
    "FB_Translation_PositionEstimator",
    "FB_Translation_PositionDecoder",
)
ARBITRATION_SOURCES = (
    "CODE/I_TRANSLATION/_TYPES/ST_fbTranslationCmdArbitration_IHM.st",
    "CODE/I_TRANSLATION/_TYPES/ST_fbTranslationCmdArbitration_Context.st",
    "CODE/I_TRANSLATION/_TYPES/ST_fbTranslationCmdArbitration_Cfg.st",
    "CODE/I_TRANSLATION/FB_TranslationCmdArbitrationM3.st",
    "CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_Modes_Autorisations.st",
    "CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/ST_AcquisitionJoystickQualified.st",
    "CODE/D_JOYSTICK/ST_fbJoystick_AxisCmd.st",
)


def main() -> int:
    registry = run_tests.load_registry()
    sources: list[str] = []
    for comp in REGISTRY_COMPONENTS:
        for src in registry[comp]["sources"]:
            if src not in sources:
                sources.append(src)
    for src in ARBITRATION_SOURCES:
        if src not in sources:
            sources.append(src)
    sources.append(HARNESS_FILE)

    run_tests._ensure_gpp_in_path()
    test_src = TEST_FILE.read_text(encoding="utf-8")
    loop_pattern = re.compile(
        r"(?m)^\s*FOR\s+([A-Za-z_]\w*)\s*:=\s*(\d+)\s+TO\s+(\d+)\s+DO\s*\n"
        r"(.*?)^\s*END_FOR;\s*$",
        re.DOTALL,
    )

    def unroll(m: re.Match[str]) -> str:
        first, last = int(m.group(2)), int(m.group(3))
        body = m.group(4)
        it = re.compile(rf"\b{re.escape(m.group(1))}\b")
        return "\n".join(it.sub(str(idx), body) for idx in range(first, last + 1))

    expanded = loop_pattern.sub(unroll, test_src)
    scratch = ROOT / "TOOLS/TEST_AUTO_CI/.scratch" / f"agy02_sandbox_{os.getpid()}"
    scratch.mkdir(parents=True, exist_ok=True)
    exp_path = scratch / "test_m3_sandbox.st"
    exp_path.write_text(expanded, encoding="utf-8")

    entry = {"domain": "L_SIMULATION", "sources": sources, "test": str(exp_path)}
    result = run_tests.run_one(
        "FB_TestHarnessT417_M3",
        entry,
        cycle_time_ms=10,
        debug=False,
        enable_chronogram=False,
        generate_reports=False,
    )
    for c in result["tests"]:
        print(("PASS" if c["passed"] else "FAIL"), c["name"], c.get("detail", ""))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
