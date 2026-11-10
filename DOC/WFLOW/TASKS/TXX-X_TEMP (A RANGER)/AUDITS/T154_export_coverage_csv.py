#!/usr/bin/env python3
"""Exporte le tableau Markdown T154 en CSV filtrable dans Excel (DOC-only)."""
from __future__ import annotations

import argparse
import csv
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    rows: list[dict[str, str]] = []
    for line in args.report.read_text(encoding="utf-8").splitlines():
        if not line.startswith("| AF-"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) != 4:
            raise ValueError(f"Ligne tableau invalide : {line}")
        af, function, tc, coverage = cells
        rows.append(
            {
                "AF": af,
                "Fonction": function.strip("`"),
                "TC_couvrants": tc.replace("`", ""),
                "Couverture_detail": coverage.replace("<br>", " | "),
                "CI_declare": "OUI" if "✅ CI" in coverage else "NON",
                "Hors_CI_explicite": "OUI" if "🟡" in coverage else "NON",
                "TC_absent_du_CI": "OUI" if "❌ absent" in coverage else "NON",
                "Fonction_sans_TC": "OUI" if "❌ Sans TC" in coverage else "NON",
            }
        )

    if not rows:
        raise ValueError("Aucune ligne fonctionnelle AF trouvée dans le rapport")
    with args.output.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]), delimiter=";")
        writer.writeheader()
        writer.writerows(rows)
    print(f"CSV écrit : {args.output} ({len(rows)} fonctions)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
