"""Execute la boucle fermee T417 avec les composants ST de production et preserve une preuve sourcee."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import os

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "TOOLS/TEST_AUTO_CI/scripts"))
import run_tests


TEST_FILE = "TOOLS/TEST_AUTO_CI/RESULTS/L_SIMULATION/tests/test_t417_m3_integrated.st"
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    evidence_root = (ROOT / "DOC/WFLOW").resolve()
    if not output.is_relative_to(evidence_root) or not output.parent.is_dir():
        parser.error("La preuve doit cibler un dossier existant sous DOC/WFLOW.")
    if output.exists():
        parser.error("La preuve existe deja; choisir un nouveau nom.")

    registry = run_tests.load_registry()
    sources: list[str] = []
    for component in REGISTRY_COMPONENTS:
        for source in registry[component]["sources"]:
            if source not in sources:
                sources.append(source)
    for source in ARBITRATION_SOURCES:
        if source not in sources:
            sources.append(source)
    sources.append(HARNESS_FILE)
    entry = {
        "domain": "L_SIMULATION",
        "sources": sources,
        "test": TEST_FILE,
    }
    proof_paths = [*sources, TEST_FILE, "TOOLS/TEST_AUTO_CI/scripts/run_tests.py", __file__]
    hashes = {
        path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
        for path in proof_paths
    }

    run_tests._ensure_gpp_in_path()
    # Le parseur de tests ne supporte pas ADVANCE_TIME dans un FOR. Derouler
    # uniquement ces boucles simples preserve un ADVANCE_TIME par scan sans
    # modifier la suite commune ni les sources de production.
    test_source = (ROOT / TEST_FILE).read_text(encoding="utf-8")
    loop_pattern = re.compile(
        r"(?m)^\s*FOR\s+([A-Za-z_]\w*)\s*:=\s*(\d+)\s+TO\s+(\d+)\s+DO\s*\n"
        r"(.*?)^\s*END_FOR;\s*$",
        re.DOTALL,
    )

    def unroll(match: re.Match[str]) -> str:
        first, last = int(match.group(2)), int(match.group(3))
        body = match.group(4)
        iterator = re.compile(rf"\b{re.escape(match.group(1))}\b")
        return "\n".join(iterator.sub(str(index), body) for index in range(first, last + 1))

    expanded_test = loop_pattern.sub(unroll, test_source)
    if re.search(r"(?m)^\s*FOR\b", expanded_test):
        parser.error("Boucle FOR non deroulee; seul le format simple T417 est supporte.")
    expanded_dir = ROOT / "TOOLS/TEST_AUTO_CI/.scratch" / f"t417_m3_expanded_{os.getpid()}"
    expanded_dir.mkdir(parents=True, exist_ok=False)
    expanded_path = expanded_dir / "test_t417_m3_integrated.st"
    expanded_path.write_text(expanded_test, encoding="utf-8")
    entry["test"] = str(expanded_path)
    result = run_tests.run_one(
        "FB_TestHarnessT417_M3",
        entry,
        cycle_time_ms=10,
        debug=args.debug,
        enable_chronogram=False,
        generate_reports=False,
    )
    evidence = {
        "sources_sha256": hashes,
        "components": list(REGISTRY_COMPONENTS) + ["FB_TranslationCmdArbitrationM3"],
        "test": TEST_FILE,
        "ok": result["ok"],
        "tests": result["tests"],
        "scratch": str(result.get("scratch", "")),
        "cycle_period_ms": 10,
        "starting_precondition": "physical P1 seeded by FB_SimBench; public StepForceTgt=14 starts coverage at AX14",
        "mocked_inputs": [
            "M1/M2 speed, position, contactors, brakes and top-window facts",
            "bucket Done/Open facts",
            "operator, mode arbiter, drive network and upstream power-contactor facts",
        ],
        "safety_bypasses": "none",
        "scope": "isolated ST harness; not a CODESYS runtime or machine test",
    }
    with output.open("x", encoding="utf-8") as stream:
        json.dump(evidence, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    for case in result["tests"]:
        print(("PASS" if case["passed"] else "FAIL") + " " + case["name"])
        if case.get("detail"):
            print("  " + case["detail"])
    print("Preuve : " + str(output))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
