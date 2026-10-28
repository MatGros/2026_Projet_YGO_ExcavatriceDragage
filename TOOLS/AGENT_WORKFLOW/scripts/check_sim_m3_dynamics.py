#!/usr/bin/env python3
"""Garde fonctionnel M3 : execute les scenarios sur les vrais FB ST du banc.

Pas de copie Python de la mecanique, pas de suite CI globale ni de rapport HTML.
Les scratchs du runner sont conserves selon la politique du projet.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def main() -> int:
    return subprocess.call(
        [sys.executable, str(ROOT / "TOOLS/TEST_AUTO_CI/scripts/run_tests.py"),
         "--fb", "SimM3Dynamics", "--fast"],
        cwd=ROOT,
    )


if __name__ == "__main__":
    raise SystemExit(main())
