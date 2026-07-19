#!/usr/bin/env python3
"""Run lightweight, non-destructive checks on project ST sources."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

FORBIDDEN = ("CoupeEnable", "FB_Watchdog")
DOC_REF = re.compile(r"DOC/[A-Za-z0-9_./-]+\.md")
# Détecte instFB.VarOutput :=  (écriture sur VAR_OUTPUT d'une instance)
VAR_OUTPUT_WRITE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\.(Ready|Busy|Done|Error|ErrorId|State|StateAtError)\s*:=")

# Baseline des violations VAR_OUTPUT connues (dette technique préexistante)
# Clé = chemin relatif SANS prefixe CODE/
# Toute NOUVELLE occurrence non listée ici = ERROR
KNOWN_VAR_OUTPUT_VIOLATIONS = {
    "DIAG/FB_DiagCanOpen.st": {
        "DeviceJoystick.State", "DeviceJoystick.Error", "DeviceJoystick.ErrorId"
    },
    "DIAG/FB_DiagEthercat.st": {
        "DeviceVariateur.State", "DeviceEncoderM1.State", "DeviceEncoderM2.State",
        "DeviceVariateur.Error", "DeviceEncoderM1.Error", "DeviceEncoderM2.Error",
        "DeviceVariateur.ErrorId", "DeviceEncoderM1.ErrorId", "DeviceEncoderM2.ErrorId"
    },
    "MAIN/PRG_09_Supervision.st": {
        "M1TreuilRetenue.Ready", "M1TreuilRetenue.Busy", "M1TreuilRetenue.Done",
        "M1TreuilRetenue.Error", "M1TreuilRetenue.ErrorId",
        "Encoder.Error", "Encoder.ErrorId",
        "M2TreuilBucket.Ready", "M2TreuilBucket.Busy", "M2TreuilBucket.Done",
        "M2TreuilBucket.Error", "M2TreuilBucket.ErrorId",
        "Bucket.Ready", "Bucket.Busy", "Bucket.Done", "Bucket.Error", "Bucket.ErrorId",
        "Bucket.State",
        "Sync.Ready", "Sync.Error", "Sync.ErrorId", "Sync.State",
        "TranslationM3.Ready", "TranslationM3.Busy", "TranslationM3.Done",
        "TranslationM3.Error", "TranslationM3.ErrorId",
        "Cycle.Ready", "Cycle.Busy", "Cycle.Done", "Cycle.Error", "Cycle.ErrorId",
        "JoystickJOY1.Error", "JoystickJOY1.ErrorId"
    }
}



def requires_doc_reference(path: Path) -> bool:
    normalized = path.as_posix()
    if "/SIMULATION/PLC_TESTS/" in normalized:
        return False
    if path.name.startswith(("FB_", "PRG_", "GVL_")):
        return True
    return any(f"/{folder}/" in normalized for folder in ("AU", "TRANSLATION", "TREUILS"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scope", nargs="?", default="CODE", help="ST file or directory")
    args = parser.parse_args()
    scope = Path(args.scope)
    files = [scope] if scope.is_file() else sorted(scope.rglob("*.st"))
    errors = 0
    warnings = 0

    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        for token in FORBIDDEN:
            if token in text:
                print(f"[ERROR] {path}: forbidden token {token}", file=sys.stderr)
                errors += 1
        # VAR_OUTPUT write detection
        for m in VAR_OUTPUT_WRITE.finditer(text):
            inst_name = m.group(1)
            var_name = m.group(2)
            key = f"{inst_name}.{var_name}"
            rel_path = path.as_posix()
            if rel_path.startswith("CODE/"):
                rel_path = rel_path[5:]
            known = KNOWN_VAR_OUTPUT_VIOLATIONS.get(rel_path, set())
            if key in known:
                print(f"[WARN] {path}: known VAR_OUTPUT write debt: {key}", file=sys.stderr)
                warnings += 1
            else:
                print(f"[ERROR] {path}:{m.start()}: NEW illegal write to VAR_OUTPUT {key}", file=sys.stderr)
                errors += 1
        header = text[:4000]
        required = requires_doc_reference(path)
        if "DOC/" not in header:
            if required:
                print(f"[WARN] {path}: no DOC reference in header")
                warnings += 1
        for reference in DOC_REF.findall(header):
            if not Path(reference).is_file():
                level = "ERROR" if required else "WARN"
                print(f"[{level}] {path}: DOC reference not found: {reference}", file=sys.stderr if required else sys.stdout)
                if required:
                    errors += 1
                else:
                    warnings += 1

    print(f"Code style check: {'FAIL' if errors else 'PASS'} ({errors} error(s), {warnings} warning(s))")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
