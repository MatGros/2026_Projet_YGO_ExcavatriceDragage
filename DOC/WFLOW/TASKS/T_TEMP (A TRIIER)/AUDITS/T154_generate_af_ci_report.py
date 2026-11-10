#!/usr/bin/env python3
"""Rapport DOC-only T154 : AF/Fonctions/TC ↔ tests CI declares dans registry.yaml."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

import yaml

TC_RE = re.compile(r"TC-P(\d+)-(\d+)(?:/(\d+))?")
TITLE_RE = re.compile(r"TEST\s+'([^']*)'")


def ids_from_text(text: str) -> set[str]:
    """Extract full TC identifiers, including compact TEST titles such as P01-004/009."""
    ids: set[str] = set()
    for part, first, second in TC_RE.findall(text):
        ids.add(f"TC-P{part}-{first}")
        if second:
            ids.add(f"TC-P{part}-{second}")
    return ids


def ids_in_test(path: Path) -> set[str]:
    if not path.is_file():
        return set()
    return ids_from_text("\n".join(TITLE_RE.findall(path.read_text(encoding="utf-8"))))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--matrix", type=Path, required=True)
    parser.add_argument("--registry", type=Path, required=True)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    matrix = yaml.safe_load(args.matrix.read_text(encoding="utf-8")) or {}
    registry = yaml.safe_load(args.registry.read_text(encoding="utf-8")) or {}
    tested: set[str] = set()
    ignored: set[str] = set()
    for entry in registry.values():
        if not isinstance(entry, dict):
            continue
        test = entry.get("test")
        if test:
            tested |= ids_in_test(args.root / test)
        ignored.update(entry.get("af_ignore", []))

    rows: list[str] = []
    no_tc: list[str] = []
    missing: list[str] = []
    for af, domain in sorted(matrix.get("domains", {}).items()):
        points = domain.get("validation_points", {})
        for fid, function in sorted(domain.get("functions", {}).items()):
            raw = function.get("tc_couvrants", [])
            tc_ids = sorted(set(tc for value in raw for tc in ids_from_text(value)))
            if not tc_ids:
                no_tc.append(f"{af} {fid}")
                rows.append(f"| {af} | `{fid}` | — | ❌ Sans TC |")
                continue
            states: list[str] = []
            for tc in tc_ids:
                typ = str(points.get(tc, {}).get("type", ""))
                if tc in tested:
                    states.append(f"{tc} ✅ CI")
                elif tc in ignored:
                    states.append(f"{tc} 🟡 Hors CI (registre)")
                elif "SITE" in typ and "AUTO" not in typ:
                    states.append(f"{tc} 🟡 SITE")
                else:
                    states.append(f"{tc} ❌ absent")
                    missing.append(f"{af} {fid} → {tc}")
            rows.append(f"| {af} | `{fid}` | {', '.join(f'`{x}`' for x in tc_ids)} | {'<br>'.join(states)} |")

    no_tc_lines = [f"- ❌ {item}" for item in no_tc] or ["- ✅ Aucun."]
    missing_lines = [f"- ❌ {item}" for item in missing] or ["- ✅ Aucun."]

    output = [
        "# T154 — Couverture AF / Fonctions / TC / Tests CI",
        "",
        "> Export déterministe DOC-only. Sources : AF actives, matrice fraîche et `registry.yaml`.",
        "> `✅ CI` = ID trouvé dans un titre `TEST` d'un fichier référencé par le registre ; `🟡` = couverture explicitement hors CI.",
        "",
        "## Matrice fonctionnelle",
        "",
        "| AF | Fonction | TC couvrants | Couverture |",
        "|---|---|---|---|",
        *rows,
        "",
        "## Écarts à traiter",
        "",
        "### Fonctions sans TC",
        *no_tc_lines,
        "",
        "### TC non trouvés dans les tests CI déclarés",
        *missing_lines,
        "",
        "## Limites explicites",
        "",
        "- Le rapport ne prétend pas prouver l'exécution d'un test : il vérifie la traçabilité déclarée AF → TC → titre de test enregistré.",
        "- Les preuves SITE restent hors CI ; elles doivent être qualifiées terrain.",
        "- Les exceptions `af_ignore` du registre sont visibles comme `Hors CI (registre)`, jamais masquées.",
    ]
    args.output.write_text("\n".join(output) + "\n", encoding="utf-8")
    print(f"Rapport écrit : {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
