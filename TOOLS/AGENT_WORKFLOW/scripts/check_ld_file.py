#!/usr/bin/env python3
"""Vérifie qu'un fichier PRG_*_LD.st est convertible en XML Ladder valide.

REX 2026-08-13 (PRG_02_Acquisition_LD scratch) : un fichier `_LD.st` isolé
doit PROUVER sa convertibilité — un "XML bien formé" ne prouve jamais l'import
CODESYS (IndexOutOfRangeException à la création de l'objet). Ce script :
  1. convertit le `.st` en XML temporaire via st_to_ld.py (échoue si non convertible) ;
  2. valide les invariants LD (G410_check_ld_invariants.py) sur le XML produit
     (outVariable, coils non déclarées, localId, contact sur broche de sortie...).

Usage:
    python check_ld_file.py <fichier_LD.st>
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ST_TO_LD = ROOT / "TOOLS" / "ST_PLCOPENXML_GENERATOR" / "scripts" / "st_to_ld.py"
G410 = ROOT / "TOOLS" / "AGENT_WORKFLOW" / "scripts" / "G410_check_ld_invariants.py"


def run(cmd: list[str]) -> tuple[int, str]:
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT)
    return r.returncode, (r.stdout + r.stderr).strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ld_st", type=Path, help="Fichier PRG_*_LD.st à vérifier")
    args = parser.parse_args()

    st_path = args.ld_st.resolve()
    if not st_path.is_file():
        print(f"ERROR: fichier introuvable : {st_path}", file=sys.stderr)
        return 2
    if not st_path.name.endswith("_LD.st"):
        print(f"ERROR: {st_path.name} n'est pas un PRG_*_LD.st", file=sys.stderr)
        return 2

    # 1. Conversion en XML temporaire — BLOQUANTE : st_to_ld refuse net les constructions
    #    non convertibles (IF/CASE/SEL/copie struct). C'est la protection principale.
    with tempfile.TemporaryDirectory() as tmpdir:
        out_xml = Path(tmpdir) / f"{st_path.stem}.xml"
        code, out = run([sys.executable, str(ST_TO_LD), str(st_path), "-o", str(out_xml)])
        if code != 0:
            print(f"FAIL: {st_path.name} non convertible en XML Ladder :\n{out}", file=sys.stderr)
            return 1
        # 2. Invariants LD (G410) — INFORMATIF : la conversion isolée ne reproduit pas le
        #    bundle complet (PRG_06 passe par son oracle qui normalise les outVariable PDO).
        #    Le verdict bloquant reste le bundle complet (palier C).
        code, out = run([sys.executable, str(G410), "--bundle", str(out_xml), "--report"])
        print(out)
        if code != 0:
            print(f"[!] {st_path.name} : violations d'invariants LD sur la conversion isolée "
                  f"— à confirmer sur le bundle complet (palier C).", file=sys.stderr)

    print(f"PASS: {st_path.name} convertible + invariants LD informés")
    return 0


if __name__ == "__main__":
    sys.exit(main())
