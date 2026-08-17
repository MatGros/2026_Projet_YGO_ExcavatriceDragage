#!/usr/bin/env python3
"""Gate: reject non-ASCII characters inside STRING literals in .st sources.

REX 2026-08-17 : un emoji (⚠️) dans un littéral STRING de FB_Hmi_BannerFormatter.st
cassait la compilation CODESYS (C0555 + erreurs en cascade C0189/C0009). CODESYS
n'interprète pas les STRING en UTF-8 par défaut ; un caractère multi-octets dans un
littéral '...' dérègle le parseur. Les emojis dans les COMMENTAIRES sont inoffensifs
(CODESYS les ignore) — seuls les littéraux STRING sont concernés.

Ce gate scanne les sources .st, ignore les commentaires (bloc (* ... *) et ligne //),
et rejette tout littéral STRING contenant un caractère non-ASCII (ord > 127).

Usage:
    python G405_check_st_string_ascii.py [project_root]

Exit codes:
    0 = PASS (aucun littéral STRING non-ASCII)
    1 = FAIL (un ou plusieurs littéraux STRING non-ASCII)
    2 = USAGE ERROR
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Caractère non représentable en un octet (ord > 255) : emoji, traits de cadre, etc.
# Les accents latins (é, è, à — ord 128..255) sont représentables en un octet et
# CODESYS les gère ; seuls les caractères multi-octets (emoji, box-drawing) cassent
# la compilation. On ne rejette donc que ceux-là.
NON_ASCII_RE = re.compile(r"[^\x00-\xFF]")

# Délimiteurs de littéral STRING en ST : '...' avec '' pour échapper une apostrophe.
STRING_RE = re.compile(r"'((?:[^']|'')*)'")


def _strip_comments(text: str) -> str:
    """Retire les commentaires ST (bloc (* ... *) et ligne //) hors littéraux STRING."""
    out: list[str] = []
    i = 0
    n = len(text)
    in_string = False
    while i < n:
        c = text[i]
        # Littéral STRING : on le recopie tel quel (le gate vérifie son contenu).
        if c == "'":
            out.append(c)
            i += 1
            in_string = not in_string
            continue
        if in_string:
            out.append(c)
            i += 1
            continue
        # Commentaire de bloc (* ... *)
        if text.startswith("(*", i):
            end = text.find("*)", i + 2)
            if end == -1:
                out.append(" ")  # commentaire non fermé : on le neutralise
                i = n
            else:
                out.append(" " * (end + 2 - i))
                i = end + 2
            continue
        # Commentaire de ligne //
        if text.startswith("//", i):
            end = text.find("\n", i + 2)
            if end == -1:
                out.append(" ")
                i = n
            else:
                out.append(" " * (end - i))
                i = end
            continue
        out.append(c)
        i += 1
    return "".join(out)


def _find_non_ascii_strings(code: str) -> list[tuple[int, str]]:
    """Retourne (ligne, snippet) pour chaque littéral STRING contenant un non-ASCII."""
    stripped = _strip_comments(code)
    violations: list[tuple[int, str]] = []
    for m in STRING_RE.finditer(stripped):
        literal = m.group(1)
        if NON_ASCII_RE.search(literal):
            line_no = stripped[: m.start()].count("\n") + 1
            snippet = literal[:60]
            violations.append((line_no, snippet))
    return violations


def main() -> int:
    args = sys.argv[1:]
    root = Path(args[0]).resolve() if args else Path.cwd()
    code_dir = root / "CODE"
    if not code_dir.is_dir():
        print(f"ERROR: dossier CODE introuvable : {code_dir}", file=sys.stderr)
        return 2

    all_violations: list[tuple[str, int, str]] = []
    for st_file in sorted(code_dir.rglob("*.st")):
        try:
            text = st_file.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            print(f"ERROR: {st_file} n'est pas en UTF-8 lisible", file=sys.stderr)
            return 2
        for line_no, snippet in _find_non_ascii_strings(text):
            all_violations.append((str(st_file.relative_to(root)), line_no, snippet))

    if not all_violations:
        print("PASS : aucun littéral STRING non-ASCII dans les sources .st.")
        return 0

    print(f"FAIL : {len(all_violations)} littéral(aux) STRING non-ASCII :")
    for path, line, snippet in all_violations:
        print(f"  - {path}:{line} -> '{snippet}'")
    print(
        "\nCause : un caractere multi-octet (emoji, trait de cadre) dans un litteral STRING "
        "casse la compilation CODESYS (C0555 + erreurs en cascade). "
        "Remplacer par du texte ASCII (ex. 'ATTENTION: ...' au lieu de 'WARNING: ...'). "
        "Les emojis restent autorises dans les commentaires."
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
