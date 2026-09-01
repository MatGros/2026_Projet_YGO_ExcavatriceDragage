#!/usr/bin/env python3
"""Gate: reject STRING literals longer than the default CODESYS STRING size (80).

REX 2026-08-31 : des littéraux STRING > 80 caractères affectés à un champ `STRING`
(sans taille explicite, donc 80 par défaut) déclenchaient l'avertissement CODESYS
C0198 « constante de chaîne trop longue pour le type cible STRING ». Ce gate détecte
ces littéraux AVANT compilation pour éviter l'avertissement.

Règle : tout littéral STRING '...' de plus de `MAX_LEN` caractères (défaut 80, la
taille par défaut d'un `STRING` CODESYS) est rejeté. Les champs déclarés plus grands
(STRING(120), etc.) peuvent dépasser 80 : dans ce cas, ajouter une exception explicite
dans OUT_OF_SCOPE (chemin:ligne) avec justification.

Le scanner ignore correctement les commentaires (bloc (* ... *) et ligne //) et gère
les apostrophes échappées ('' ) dans les littéraux STRING.

Usage:
    python G406_check_st_string_length.py [project_root]

Exit codes:
    0 = PASS (aucun littéral STRING trop long)
    1 = FAIL (un ou plusieurs littéraux STRING trop longs)
    2 = USAGE ERROR
"""

from __future__ import annotations

import sys
from pathlib import Path

# Taille par défaut d'un STRING CODESYS (sans taille explicite).
MAX_LEN = 80

# Exceptions explicites et BORNÉES : littéraux > 80 légitimes pour un champ STRING(120)
# ou plus. Format : "chemin:ligne" -> justification. Un littéral non listé fait échouer.
OUT_OF_SCOPE: dict[str, str] = {}


def _extract_strings(text: str) -> list[tuple[int, str, int]]:
    """Scanne le texte et retourne (ligne, contenu, longueur) pour chaque littéral STRING.

    Ignore les commentaires (* ... *) et //, gère les apostrophes échappées '' dans
    les littéraux. Retourne uniquement les littéraux de longueur > MAX_LEN.
    """
    violations: list[tuple[int, str, int]] = []
    i = 0
    n = len(text)
    line = 1
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        # Commentaire de bloc (* ... *)
        if text.startswith("(*", i):
            end = text.find("*)", i + 2)
            if end == -1:
                break
            line += text[i:end + 2].count("\n")
            i = end + 2
            continue
        # Commentaire de ligne //
        if text.startswith("//", i):
            end = text.find("\n", i + 2)
            if end == -1:
                break
            i = end
            continue
        # Chaîne double-quote "..." (directives {region "..."}, etc.) : on la saute
        # pour ne pas confondre une apostrophe française (ex. d'etat) avec un littéral.
        if c == '"':
            end = text.find('"', i + 1)
            if end == -1:
                break
            line += text[i:end + 1].count("\n")
            i = end + 1
            continue
        # Littéral STRING '...' (avec '' pour échapper une apostrophe)
        if c == "'":
            start_line = line
            j = i + 1
            buf: list[str] = []
            while j < n:
                if text[j] == "'":
                    if j + 1 < n and text[j + 1] == "'":
                        buf.append("'")  # apostrophe échappée
                        j += 2
                        continue
                    break  # fin du littéral
                if text[j] == "\n":
                    line += 1
                buf.append(text[j])
                j += 1
            length = len(buf)
            if length > MAX_LEN:
                violations.append((start_line, "".join(buf)[:60], length))
            i = j + 1
            continue
        i += 1
    return violations


def main() -> int:
    args = sys.argv[1:]
    root = Path(args[0]).resolve() if args else Path.cwd()
    code_dir = root / "CODE"
    if not code_dir.is_dir():
        print(f"ERROR: dossier CODE introuvable : {code_dir}", file=sys.stderr)
        return 2

    all_violations: list[tuple[str, int, str, int]] = []
    for st_file in sorted(code_dir.rglob("*.st")):
        try:
            text = st_file.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            print(f"ERROR: {st_file} n'est pas en UTF-8 lisible", file=sys.stderr)
            return 2
        rel = str(st_file.relative_to(root))
        for line_no, snippet, length in _extract_strings(text):
            key = f"{rel}:{line_no}"
            if key in OUT_OF_SCOPE:
                continue
            all_violations.append((rel, line_no, snippet, length))

    if not all_violations:
        print(f"PASS : aucun littéral STRING > {MAX_LEN} caractères dans les sources .st.")
        return 0

    print(f"FAIL : {len(all_violations)} littéral(aux) STRING > {MAX_LEN} caractères :")
    for path, line, snippet, length in all_violations:
        print(f"  - {path}:{line} ({length} car.) -> '{snippet}'")
    print(
        f"\nCause : un littéral STRING > {MAX_LEN} caractères affecté à un champ `STRING` "
        "(taille par défaut 80) déclenche l'avertissement CODESYS C0198. "
        "Contracter le texte, ou si le champ cible est plus grand (STRING(120)), "
        "ajouter une exception explicite dans OUT_OF_SCOPE du gate."
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
