#!/usr/bin/env python3
"""G485 - T181-19: SyncCoupled is a diagnostic-only DriveRequest field.

This focused guard checks the producer boundary in PRG_04 and rejects any use
of SyncCoupled by FB_Winch logic.  ``--self-test`` exercises controlled
mutations without touching repository files.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PRG04 = ROOT / "CODE" / "M_MAIN" / "PRG_04_Treuils_Benne.st"
WINCH = ROOT / "CODE" / "H_TREUILS_BENNE" / "FB_Winch.st"
DRIVE_REQUEST = ROOT / "CODE" / "H_TREUILS_BENNE" / "_TYPES" / "ST_fbWinch_DriveRequest.st"


def strip_comments(text: str) -> str:
    text = re.sub(r"\(\*.*?\*\)", " ", text, flags=re.DOTALL)
    return re.sub(r"//[^\n]*", " ", text)


def check_text(prg04: str, winch: str, drive_request: str) -> list[str]:
    errors: list[str] = []
    if not re.search(r"\bSyncCoupled\s*:\s*BOOL\b", drive_request):
        errors.append("ST_fbWinch_DriveRequest ne declare pas SyncCoupled : BOOL")

    executable_prg = strip_comments(prg04)
    assignments = re.findall(
        r"\bSyncCoupled\s*:=\s*instWinchSync\.SyncActive\b", executable_prg,
        flags=re.IGNORECASE,
    )
    if len(assignments) != 2:
        errors.append(
            f"PRG_04 contient {len(assignments)} affectations SyncCoupled := instWinchSync.SyncActive (attendu 2)"
        )

    executable_winch = strip_comments(winch)
    if re.search(r"\bSyncCoupled\b", executable_winch, flags=re.IGNORECASE):
        errors.append("FB_Winch lit ou utilise SyncCoupled dans sa logique executable")

    # Ensure no diagnostic field is smuggled into an actuator/palier assignment
    if re.search(
        r"(?:RelayFwd|RelayRev|RequestedStep|StepNumber)\s*:=\s*[^;\n]*\bSyncCoupled\b",
        executable_winch,
        flags=re.IGNORECASE,
    ):
        errors.append("SyncCoupled alimente une commande ou un calcul de palier FB_Winch")
    return errors


def run_self_test() -> int:
    prg = """
    DriveRequest := (BottomLimitM := B1, SyncCoupled := instWinchSync.SyncActive);
    DriveRequest := (BottomLimitM := B2, SyncCoupled := instWinchSync.SyncActive);
    """
    winch = "RelayFwd := RequestedStep > 0;"
    request = "SyncCoupled : BOOL;"
    failures = []
    if check_text(prg, winch, request):
        failures.append("cas nominal rejeté")
    mutated_prg = prg.replace("SyncCoupled := instWinchSync.SyncActive", "SyncCoupled := FALSE", 1)
    if not check_text(mutated_prg, winch, request):
        failures.append("mutation producteur non détectée")
    mutated_winch = winch + "\nIF DriveRequest.SyncCoupled THEN RequestedStep := 0; END_IF;"
    if not check_text(prg, mutated_winch, request):
        failures.append("mutation FB_Winch non détectée")
    if failures:
        print("[G485] SELF-TEST FAIL - " + "; ".join(failures))
        return 1
    print("[G485] SELF-TEST PASS - cas nominal + 2 mutations rejetées")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return run_self_test()
    missing = [p for p in (PRG04, WINCH, DRIVE_REQUEST) if not p.is_file()]
    if missing:
        print("[G485] FAIL - fichier(s) introuvable(s): " + ", ".join(str(p.relative_to(ROOT)) for p in missing))
        return 1
    errors = check_text(
        PRG04.read_text(encoding="utf-8", errors="replace"),
        WINCH.read_text(encoding="utf-8", errors="replace"),
        DRIVE_REQUEST.read_text(encoding="utf-8", errors="replace"),
    )
    if errors:
        print("[G485] FAIL - invariants SyncCoupled diagnostic:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print("[G485] PASS - SyncCoupled publie dans PRG_04 et reste absent de la logique FB_Winch")
    return 0


if __name__ == "__main__":
    sys.exit(main())
