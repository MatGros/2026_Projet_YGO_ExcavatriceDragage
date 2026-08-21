#!/usr/bin/env python3
"""Moulinette : convertit les idiomes CODESYS 3.5 non reconnus par STruCpp (compilateur
ST -> C++17, https://github.com/Autonomy-Logic/STruCpp) vers de l'IEC 61131-3 equivalent.
Ne touche jamais aux fichiers CODE/ sources -- ecrit une copie dans un dossier de sortie,
pour la chaine de compilation PoC (TOOLS/COMPILER_ST2C_STruCpp).

3 transformations, toutes mecaniques et semantiquement neutres pour la logique du FB :

1. TYPE x : ENUM lit := val, ... END_ENUM END_TYPE
   -> TYPE x : (lit := val, ...); END_TYPE
   (forme lisible CODESYS -> forme parenthesee standard ; valeurs explicites CONSERVEES,
    STruCpp les supporte nativement contrairement au vieux binaire matiec teste initialement)

2. {region "..."} / {endregion} / {attribute '...'} / {warning ...}
   -> supprimes (pragmas de pliage/annotation IDE, aucun effet sur la logique)

3. FUNCTION_BLOCK PUBLIC Name / PROGRAM INTERNAL Name / ...
   -> FUNCTION_BLOCK Name (qualificatif de visibilite CODESYS retire ; sans effet sur le
      comportement d'un FB teste en boite noire hors compilation multi-unites)
"""

import argparse
import pathlib
import re
import sys

ENUM_BLOCK_RE = re.compile(
    r"TYPE\s+(?P<name>\w+)\s*:\s*ENUM\s*(?P<body>.*?)END_ENUM\s*END_TYPE",
    re.DOTALL | re.IGNORECASE,
)

PRAGMA_RE = re.compile(r"\{[^}]*\}")

POU_QUALIFIER_RE = re.compile(
    r"\b(FUNCTION_BLOCK|PROGRAM|FUNCTION)\s+(PUBLIC|INTERNAL|PROTECTED|ABSTRACT|FINAL)\b",
    re.IGNORECASE,
)

LITERAL_RE = re.compile(r"(?P<lit>\w+)\s*(?::=\s*(?P<val>-?\d+))?")


def _strip_comments(text: str) -> str:
    text = re.sub(r"\(\*.*?\*\)", "", text, flags=re.DOTALL)
    text = re.sub(r"//[^\n]*", "", text)
    return text


def _parse_literals(body: str):
    body_clean = _strip_comments(body)
    literals = []
    for chunk in body_clean.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        m = LITERAL_RE.match(chunk)
        if not m:
            continue
        lit = m.group("lit")
        val = m.group("val")
        literals.append((lit, int(val) if val is not None else None))
    return literals


def _convert_enum_blocks(text: str, source_name: str, warnings: list) -> str:
    def _replace(match):
        name = match.group("name")
        body = match.group("body")
        literals = _parse_literals(body)
        if not literals:
            warnings.append(f"{source_name}: {name} -- aucun litteral trouve, bloc ENUM laisse tel quel")
            return match.group(0)

        rendered = ", ".join(
            f"{lit} := {val}" if val is not None else lit
            for lit, val in literals
        )
        return f"TYPE {name} :\n    ({rendered});\nEND_TYPE"

    return ENUM_BLOCK_RE.sub(_replace, text)


def _strip_pragmas(text: str) -> str:
    return PRAGMA_RE.sub("", text)


def _strip_pou_qualifiers(text: str) -> str:
    return POU_QUALIFIER_RE.sub(lambda m: m.group(1), text)


POU_OPEN_RE = re.compile(r"^\s*(FUNCTION_BLOCK|PROGRAM|FUNCTION)\b", re.IGNORECASE | re.MULTILINE)


def _close_missing_pou_end(text: str, source_name: str, warnings: list) -> str:
    """Les .st du projet sont des fragments colles dans l'editeur CODESYS (qui fournit
    lui-meme l'enveloppe) -- il leur manque systematiquement le END_xxx de fermeture.
    Ajoute le mot-cle correspondant s'il est absent, sans toucher au fichier source."""
    m = POU_OPEN_RE.search(_strip_comments(text))
    if not m:
        return text
    kw = m.group(1).upper()
    end_kw = f"END_{kw}"
    if re.search(rf"^\s*{end_kw}\b", text, re.MULTILINE | re.IGNORECASE):
        return text
    warnings.append(f"{source_name}: {end_kw} absent -- ajoute en fin de fichier")
    return text.rstrip() + f"\n{end_kw}\n"


def convert_text(text: str, source_name: str, warnings: list) -> str:
    text = _convert_enum_blocks(text, source_name, warnings)
    text = _strip_pragmas(text)
    text = _strip_pou_qualifiers(text)
    text = _close_missing_pou_end(text, source_name, warnings)
    return text


def convert_file(src: pathlib.Path, dst: pathlib.Path, warnings: list) -> None:
    text = src.read_text(encoding="utf-8")
    converted = convert_text(text, src.name, warnings)
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(converted, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", help="Fichier(s) .st source a convertir")
    parser.add_argument("--out", required=True, help="Dossier de sortie (copies converties)")
    args = parser.parse_args()

    out_dir = pathlib.Path(args.out)
    warnings: list = []

    for raw in args.inputs:
        src = pathlib.Path(raw)
        dst = out_dir / src.name
        convert_file(src, dst, warnings)
        print(f"OK  {src} -> {dst}")

    if warnings:
        print("\n--- AVERTISSEMENTS ---")
        for w in warnings:
            print(f"[WARN] {w}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
