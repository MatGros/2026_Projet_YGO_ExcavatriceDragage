#!/usr/bin/env python3
"""Gate: rejeter les commentaires « Journal Intime / REX » dans les sources .st.

Standard : CODE_QUALITY_STANDARDS.md §2ter (Zéro « Journal Intime / REX » dans le Code).
Les commentaires dans CODE/*.st doivent décrire EXCLUSIVEMENT ce que fait le code
(rôle métier, plages, unités, polarité). Tout historique de développement — numéros de
lot (T123, L6, Fiche 01), références de mesure (MES-008), dates, « demande client »,
« correctif », « renommé », « déplacé », « ajouté », « supprimé », « avant ce lot »,
« ex-... » — est interdit : la traçabilité vit dans DOC/ (VERSION_HISTORY, AF, PLAN_TASK).

Ce gate scanne les commentaires (bloc (* ... *) et ligne //) et rejette ceux qui
contiennent un pattern REX. Il est volontairement heuristique : les patterns « durs »
(numéros de lot, dates, MES, Fiche, REX, demande client, correctif) sont des erreurs ;
les patterns « mous » (ajouté/supprimé/renommé/déplacé/ex-/FIX) sont signalés pour
revue manuelle (warning) — un humain tranche s'ils décrivent un rôle métier légitime.

Usage:
    python G430_check_comments_rex.py [project_root]

Exit codes:
    0 = PASS (aucun commentaire REX)
    1 = FAIL (un ou plusieurs commentaires REX)
    2 = USAGE ERROR
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Patterns « durs » : quasi-certainement un REX / journal intime.
# ⚠️ Volontairement CONSERVATEUR : on ne signale que les REX clairs et sans ambiguïté
# (numéros de lot, dates, MES, Fiche, REX, demande client, correctif). Les mots « mous »
# (ajouté/supprimé/renommé/déplacé/ex-/FIX:) sont EXCLUS pour éviter tout faux positif
# (ex. « position corrigée », « Trémie(1), P1(3), Maintenance(4) », « demande utilisateur »).
HARD_RE = re.compile(
    r"\b(?:T\d{2,3}|L\d|MES-\d+|Fiche\s+\d+|REX|WINCH-CORE|TASK-\d+)\b"
    r"|demande\s+client"
    r"|correctif"
    r"|\(20\d\d-\d\d\)"
    r"|avant\s+ce\s+lot"
    r"|avant\s+Fiche"
)

# Aucun pattern « mou » : le gate ne signale que les REX clairs (zéro faux positif).
SOFT_RE = re.compile(r"(?!x)x")  # ne matche jamais


def _extract_comments(text: str) -> list[tuple[int, str]]:
    """Retourne (ligne, texte) pour chaque commentaire ST (bloc (* ... *) et ligne //)."""
    comments: list[tuple[int, str]] = []
    i = 0
    n = len(text)
    in_string = False
    while i < n:
        c = text[i]
        if c == "'":
            in_string = not in_string
            i += 1
            continue
        if in_string:
            i += 1
            continue
        if text.startswith("(*", i):
            end = text.find("*)", i + 2)
            if end == -1:
                end = n
            block = text[i + 2 : end]
            line_no = text[:i].count("\n") + 1
            comments.append((line_no, block))
            i = end + 2
            continue
        if text.startswith("//", i):
            end = text.find("\n", i + 2)
            if end == -1:
                end = n
            line_no = text[:i].count("\n") + 1
            comments.append((line_no, text[i + 2 : end]))
            i = end
            continue
        i += 1
    return comments


def main() -> int:
    # Sortie UTF-8 : les commentaires contiennent accents/emojis, la console Windows
    # (cp1252) ne peut pas les encoder sinon.
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    args = sys.argv[1:]
    root = Path(args[0]).resolve() if args else Path.cwd()
    code_dir = root / "CODE"
    if not code_dir.is_dir():
        print(f"ERROR: dossier CODE introuvable : {code_dir}", file=sys.stderr)
        return 2

    hard_violations: list[tuple[str, int, str, str]] = []
    soft_violations: list[tuple[str, int, str, str]] = []

    for st_file in sorted(code_dir.rglob("*.st")):
        try:
            text = st_file.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            print(f"ERROR: {st_file} n'est pas en UTF-8 lisible", file=sys.stderr)
            return 2
        rel = str(st_file.relative_to(root))
        for line_no, comment in _extract_comments(text):
            for m in HARD_RE.finditer(comment):
                hard_violations.append((rel, line_no, m.group(0), comment.strip()[:90]))
            for m in SOFT_RE.finditer(comment):
                soft_violations.append((rel, line_no, m.group(0), comment.strip()[:90]))

    if not hard_violations and not soft_violations:
        print("PASS : aucun commentaire REX / journal intime dans les sources .st.")
        return 0

    if hard_violations:
        print(f"FAIL : {len(hard_violations)} commentaire(s) REX (pattern dur) :")
        for path, line, pat, snippet in hard_violations:
            print(f"  - {path}:{line} [{pat}] -> {snippet}")
    if soft_violations:
        print(f"WARN : {len(soft_violations)} commentaire(s) à revoir (pattern mou) :")
        for path, line, pat, snippet in soft_violations:
            print(f"  - {path}:{line} [{pat}] -> {snippet}")

    print(
        "\nStandard : CODE_QUALITY_STANDARDS.md §2ter — les commentaires décrivent ce que "
        "fait le code, pas l'historique de développement. La traçabilité (lots, MES, dates, "
        "correctifs) vit dans DOC/ (VERSION_HISTORY, AF, PLAN_TASK)."
    )
    return 1 if hard_violations else 0


if __name__ == "__main__":
    raise SystemExit(main())
