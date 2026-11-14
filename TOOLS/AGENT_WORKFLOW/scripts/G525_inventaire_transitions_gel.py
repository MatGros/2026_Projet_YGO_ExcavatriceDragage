# -*- coding: utf-8 -*-
"""
Inventaire MECANIQUE des transitions du GRAFCET semi-auto.

Compare :
  - les transitions DECLAREES dans le GEL actif retrouve sous DOC/WFLOW/TASKS
    lignes de tableau « | **AT<step>** | ... -> **AX<n>** | »)
  - les transitions CODEES dans CODE/G_CYCLE/FB_CycleSemiAuto.st
    (affectations `State := E_AutoCycleStep.X`, rattachees au `CASE` courant)

Sortie : tableau source -> cible + verdict (CONFORME / NON DECLAREE / SAUT ARRIERE).
Lecture seule stricte : aucun fichier n'est modifie.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

CODE = "CODE/G_CYCLE/FB_CycleSemiAuto.st"
GEL = "DOC/WFLOW/AUDITS/GEL_GRAFCET_SEMIAUTO_20260903.md"
GEL_NAME = re.compile(
    r"^(?:T(?:\d+(?:-[A-Z0-9]+)?|XXX)_)?GEL_GRAFCET_SEMIAUTO_\d{8}(?:_v\d+\.\d+)?\.md$"
)


def resolve_gel(root: Path, explicit: Path | None = None) -> Path:
    """Retrouve une source active unique, jamais un GEL choisi arbitrairement."""
    if explicit is not None:
        path = (explicit if explicit.is_absolute() else root / explicit).resolve()
        if path.suffix.lower() != ".md" or any(part.casefold() == "archives" for part in path.parts):
            raise ValueError(f"GEL explicite non actif ou non Markdown : {path}")
        try:
            relative = path.relative_to(root / "DOC/WFLOW/TASKS")
        except ValueError:
            pass
        else:
            if relative.parts[0].casefold() == "txxx":
                raise ValueError(f"Le dossier exemple TXXX n'est pas une source active : {path}")
        if not path.is_file():
            raise ValueError(f"GEL explicite introuvable : {path}")
        return path
    candidates = {root / GEL} if (root / GEL).is_file() else set()
    tasks = root / "DOC/WFLOW/TASKS"
    if tasks.is_dir():
        for path in tasks.rglob("*.md"):
            relative = path.relative_to(tasks)
            if relative.parts[0].casefold() == "txxx" or any(part.casefold() == "archives" for part in relative.parts):
                continue
            if GEL_NAME.fullmatch(path.name):
                candidates.add(path)
    if len(candidates) != 1:
        found = ", ".join(sorted(str(p) for p in candidates)) or "aucune source"
        raise ValueError(f"GEL actif attendu unique, trouve {len(candidates)} : {found}")
    return next(iter(candidates))


def inventory(root: Path, args: argparse.Namespace) -> None:
    # --- 1. GEL : transitions declarees -------------------------------------------------
    gel_path = resolve_gel(root, args.gel)
    gel = gel_path.read_text(encoding="utf-8", errors="replace")
    declarees = {}  # (source_step, cible) -> ligne GEL
    courant = None
    for n, ligne in enumerate(gel.split("\n"), 1):
        m = re.match(r"\|\s*\*\*(AX[0-9A-Z_]+)\*\*\s*\((\d+)\)", ligne)
        if m:
            courant = m.group(1)
            continue
        m = re.match(r"\|\s*\*\*(AT[0-9A-Za-z_\-]+)\*\*", ligne)
        if m:
            cible = re.search(r"\*\*(AX[0-9A-Z_]+)\s*(\*\*|\()", ligne)
            if courant and cible:
                declarees[(courant, cible.group(1))] = n

    # --- 2. CODE : transitions codees --------------------------------------------------
    src = (root / CODE).read_text(encoding="utf-8", errors="replace").split("\n")
    step = None
    codees = []  # (ligne, source, cible)
    for n, ligne in enumerate(src, 1):
        m = re.match(r"\s*E_AutoCycleStep\.(AX[0-9A-Z_]+)\s*:", ligne)
        if m:
            step = m.group(1)
            continue
        for c in re.finditer(r"State\s*:=\s*E_AutoCycleStep\.(AX[0-9A-Z_]+)", ligne):
            codees.append((n, step or "?", c.group(1)))

    if not declarees or not codees:
        raise ValueError("Inventaire vide : transitions declarees et codees requises")
    print(f"SOURCE GEL : {gel_path}")
    print("TRANSITIONS DECLAREES AU GEL : %d" % len(declarees))
    print("TRANSITIONS CODEES (State := AX...) : %d" % len(codees))
    print("%-6s %-26s %-26s %s" % ("LIGNE", "SOURCE (etape courante)", "CIBLE", "VERDICT"))
    print()
    hors, arriere = 0, 0
    for n, s, c in codees:
        if s == c:
            verdict = "AUTO (init/reinit)"
        elif (s, c) in declarees:
            verdict = "CONFORME AU GEL (L%d)" % declarees[(s, c)]
        else:
            verdict = "*** NON DECLAREE AU GEL ***"
            hors += 1
            ms = re.match(r"AX(\d+)", s)
            mc = re.match(r"AX(\d+)", c)
            if ms and mc and int(mc.group(1)) < int(ms.group(1)):
                verdict += "  <<< SAUT ARRIERE"
                arriere += 1
        print("%-6d %-26s %-26s %s" % (n, s, c, verdict))
    print()
    print("RESULTAT : %d transition(s) NON declaree(s) au GEL, dont %d SAUT(S) ARRIERE" % (hors, arriere))
    print("(lecture seule : inventaire produit, pas une validation des transitions)")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=".", type=Path)
    parser.add_argument("--gel", type=Path, help="GEL explicite relatif a la racine ou absolu")
    args = parser.parse_args(argv)
    try:
        inventory(args.root.resolve(), args)
    except (OSError, ValueError) as exc:
        print(f"G525 ERROR: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
