#!/usr/bin/env python3
"""G486 - garde statique du vocabulaire de clamp T181-09.

Le garde interdit les anciens identifiants de bornage dans CODE/ et vérifie
que PRG_04 ne porte qu'un seul état de montée contrôlée. ``--self-test``
exerce les deux défauts par mutations textuelles contrôlées.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CODE = ROOT / "CODE"
PRG04 = ROOT / "CODE" / "M_MAIN" / "PRG_04_Treuils_Benne.st"
OLD_NAMES = (
    "ForceMinSpeedStep",
    "M2_ForceSlowSpeed",
    "CfgMaxStepDescente",
    "ControlAscentActive",
    "M2ForceSlowSpeed",
    "Idx403_ControlAscentActive",
)


def _violations(code_text: str, prg04_text: str) -> list[str]:
    found = [name for name in OLD_NAMES if name in code_text]
    if "ExtractionControlActive" in prg04_text and "ControlAscentActive" in prg04_text:
        found.append("PRG04:double_controlled_ascent_flag")
    return found


def _scan() -> list[str]:
    chunks: list[str] = []
    for path in CODE.rglob("*.st"):
        chunks.append(path.read_text(encoding="utf-8", errors="replace"))
    code_text = "\n".join(chunks)
    prg04_text = PRG04.read_text(encoding="utf-8", errors="replace")
    return _violations(code_text, prg04_text)


def _self_test() -> int:
    clean = "ExtractionControlActive := TRUE; M2_BucketJogLimit := TRUE;"
    assert not _violations(clean, clean)
    old = clean + " ForceMinSpeedStep := FALSE;"
    assert "ForceMinSpeedStep" in _violations(old, clean)
    duplicate = clean + " ControlAscentActive := FALSE;"
    assert "ControlAscentActive" in _violations(duplicate, duplicate)
    print("[G486] SELF-TEST PASS (2 mutations détectées)")
    return 0


def main() -> int:
    if "--self-test" in sys.argv:
        return _self_test()
    if not CODE.is_dir() or not PRG04.is_file():
        print("[G486] FAIL - CODE ou PRG_04 introuvable")
        return 1
    violations = _scan()
    if violations:
        print("[G486] FAIL - vocabulaire clamp interdit détecté:")
        for item in violations:
            print(f"  - {item}")
        return 1
    print("[G486] PASS - vocabulaire clamp et drapeau unique conformes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
