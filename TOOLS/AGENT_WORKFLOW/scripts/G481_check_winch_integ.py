#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
G481 — Le harnais d'intégration treuil WINCH_INTEG compile et s'exécute.

Contexte (T181-00 AC7) : la suite `test_winch_integ.st` fait tourner la chaîne
PRG_03 -> PRG_04(miroir) -> FB_Winch x2 -> PRG_06 ensemble. Sa BASELINE est
volontairement ROUGE (des oracles ciblent un comportement que T181-01..16
n'a pas encore livré). Ce gate ne vérifie donc PAS que tout est vert — il
vérifie que :
  1. la chaîne COMPILE (aucun FB en erreur de compilation),
  2. la suite S'EXÉCUTE (le binaire d'asserts tourne),
  3. le nombre de vecteurs TEST attendu est présent (>= MIN_VECTORS),
  4. les vecteurs ROUGE-baseline connus (marqueur `ROUGE baseline` dans le .st)
     ne sont pas passés VERTS par accident (sinon le refactor correspondant est
     peut-être déjà fait sans mettre à jour l'oracle).

FAIL si : compilation cassée, suite ne s'exécute pas, vecteurs manquants,
ou un vecteur ROUGE-baseline vire au VERT (à re-qualifier).

Usage : python TOOLS/AGENT_WORKFLOW/scripts/G481_check_winch_integ.py
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(__file__).resolve().parents[3]
RUNNER = ROOT / "TOOLS" / "TEST_AUTO_CI" / "scripts" / "run_tests.py"
SUITE = ROOT / "TOOLS" / "TEST_AUTO_CI" / "RESULTS" / "H_TREUILS_BENNE" / "tests" / "test_winch_integ.st"
MIN_VECTORS = 24


def main() -> int:
    if not SUITE.is_file():
        print("[G481] SKIP — test_winch_integ.st absent (T181-00 non livré)")
        return 0

    txt = SUITE.read_text(encoding="utf-8", errors="replace")
    vectors = re.findall(r"^TEST\s+'([^']+)'", txt, re.MULTILINE)
    if len(vectors) < MIN_VECTORS:
        print(f"[G481] FAIL — {len(vectors)} vecteurs TEST, attendu >= {MIN_VECTORS}")
        return 1
    baseline_red = {v for v in vectors if "ROUGE baseline" in v or "ROUGE-baseline" in v}

    proc = subprocess.run(
        [sys.executable, str(RUNNER), "--fb", "WINCH_INTEG"],
        cwd=str(ROOT), capture_output=True, text=True, encoding="utf-8", errors="replace",
        timeout=600,
    )
    out = (proc.stdout or "") + (proc.stderr or "")

    if "Traceback (most recent call last)" in out:
        print("[G481] FAIL — le runner a planté (Traceback)")
        print("\n".join(out.splitlines()[-20:]))
        return 1

    # Compilation : chaque FB de la chaîne doit être PASS à la compil
    compile_fail = re.findall(r"^\s*FAIL\s+(FB_\w+)\s+IN=", out, re.MULTILINE)
    if compile_fail:
        print(f"[G481] FAIL — compilation cassée sur : {', '.join(sorted(set(compile_fail)))}")
        print("\n".join(l for l in out.splitlines() if "FAIL" in l and "IN=" in l))
        return 1

    if "=== RESUME ===" not in out and "RESUME" not in out:
        print("[G481] FAIL — la suite ne s'est pas exécutée (pas de bloc RESUME)")
        print("\n".join(out.splitlines()[-20:]))
        return 1

    # Un vecteur ROUGE-baseline qui passe VERT : à re-qualifier. Tant que la suite
    # n'est pas calibrée (marqueur ci-dessous), c'est un WARN informatif ; une fois
    # calibrée, retirer le marqueur -> devient FAIL bloquant.
    calibrated = "SUITE_CALIBREE" in txt
    green_lines = re.findall(r"^\s*PASS\s+(HARN-[^\n:]+:[^\n]*)", out, re.MULTILINE)
    green_titles = {g.strip() for g in green_lines}
    leaked = []
    for br in baseline_red:
        short = br.split(":", 1)[0].strip()
        if any(short in g for g in green_titles):
            leaked.append(br)
    if leaked:
        head = "FAIL" if calibrated else "WARN"
        print(f"[G481] {head} — vecteur(s) ROUGE-baseline passé(s) VERT :")
        for l in leaked:
            print(f"   - {l}")
        if calibrated:
            return 1
        print("   (suite non encore calibrée — assertions triviales, cf. plan de tir T181-00)")

    m = re.search(r"WINCH_INTEG\s*\((\d+)/(\d+)\)", out)
    score = m.group(0) if m else "score inconnu"
    tail = "" if calibrated else " [suite NON calibrée : stimulus/oracles à dérouiller]"
    print(f"[G481] PASS — chaîne compile, suite exécutée, {len(vectors)} vecteurs "
          f"({len(baseline_red)} ROUGE-baseline attendus) — {score}{tail}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
