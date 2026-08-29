#!/usr/bin/env python3
"""G470 — Unicité du catalogue TC de la matrice AF (guard REX 2026-08-29).

Les TC sont uniques par construction : 1 ID = 1 intention de validation, déclarée
une seule fois. Ce gate lit UNIQUEMENT ``af_traceability_matrix.yaml`` (rapide,
aucune relecture des specs) et détecte :

  - recouvrement   : un même ID TC-Pxx-NNN déclaré par >= 2 clés non-variantes
                     (clé composée « TC-P01-001, TC-P01-008 » + clé simple) ;
  - cross_domain   : un même ID canonique présent dans plusieurs domaines AF.

Les familles volontaires ``TC-Pxx-NNN.k`` (déclinaisons d'un cas parent) et les
clés sans ID canonique (scénarios, intitulés libres) sont signalées mais
informatives. Les écrasements de clés (main vs sous-fiche) ne sont visibles
qu'à l'extraction — ils sont reportés par ``extract_functions_matrix.py``
lui-même (comptés dans son ``--strict``).

Informatif par défaut (exit 0, même convention que G450) ; ``--strict`` -> exit 2.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:  # pragma: no cover
    print("PyYAML requis", file=sys.stderr)
    sys.exit(1)

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extract_functions_matrix import quality_report  # noqa: E402

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[union-attr]
    except Exception:  # pragma: no cover
        pass

DEFAULT_MATRIX = Path(__file__).resolve().parents[1] / "config" / "af_traceability_matrix.yaml"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--matrix", type=Path, default=DEFAULT_MATRIX, help="Matrice AF à contrôler")
    parser.add_argument("--strict", action="store_true", help="Exit 2 si problème d'unicité")
    args = parser.parse_args(argv)

    if not args.matrix.is_file():
        print(f"G470 : matrice introuvable : {args.matrix}", file=sys.stderr)
        return 1
    matrix: dict[str, Any] = yaml.safe_load(args.matrix.read_text(encoding="utf-8")) or {}

    rep = quality_report(matrix)
    s = rep["stats"]
    print(
        f"G470 : {s['domains']} domaines, {s['functions']} fonctions, "
        f"{s['validation_points']} PV, {s['unique_tc']} TC uniques"
    )

    problems = len(rep["overlaps"]) + len(rep["cross_domain"])
    if rep["overlaps"]:
        by_dom: dict[str, list[str]] = {}
        for o in rep["overlaps"]:
            by_dom.setdefault(o["domain"], []).append(o["tc"])
        for dom, tcs in sorted(by_dom.items()):
            print(f"G470 !! recouvrement {dom} : {', '.join(sorted(tcs))} (clé composée/range + clé simple)")
    for cd in rep["cross_domain"]:
        print(f"G470 !! TC non unique inter-domaines : {cd['tc']} -> {', '.join(cd['domains'])}")

    if problems:
        print(f"G470 : {problems} problème(s) d'unicité catalogue TC")
        if args.strict:
            return 2
        print("G470 : mode informatif (pas bloquant) — normaliser les specs pour passer en vert strict")
    else:
        print("G470 : unicité catalogue TC OK")
    if rep["non_canonical"]:
        by_dom2: dict[str, int] = {}
        for n in rep["non_canonical"]:
            by_dom2[n["domain"]] = by_dom2.get(n["domain"], 0) + 1
        detail = ", ".join(f"{d}({c})" for d, c in sorted(by_dom2.items()))
        print(f"G470 -- : {len(rep['non_canonical'])} clé(s) sans ID TC canonique ({detail}) [informatif]")
    return 0


if __name__ == "__main__":
    sys.exit(main())
