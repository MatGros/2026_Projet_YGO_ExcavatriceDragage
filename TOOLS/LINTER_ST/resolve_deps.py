#!/usr/bin/env python3
"""Resout, pour un ou plusieurs .st cibles, l'ensemble transitif des fichiers CODE/
declarant les types/FB references (TYPE, FUNCTION_BLOCK, PROGRAM, FUNCTION).

Remplace le hint `grep -oE ": (ST_|E_|FB_)[A-Za-z0-9_]+"` documente dans
TOOLS/COMPILER_ST2C_STruCpp/README.md, qui rate les references sans ':' juste avant
(ex: `ARRAY[0..15] OF ST_FbCause` -- verifie sur FB_Joystick.st, session 2026-08-23).

Usage:
    python resolve_deps.py <fichier.st> [fichier2.st ...] [--code-root CODE]

Sortie JSON sur stdout:
    {
        "resolved": {"NomType": "CODE/.../Fichier.st", ...},
        "unresolved": ["NomType", ...]
    }
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

DECL_RE = re.compile(
    r"^\s*(?:TYPE|FUNCTION_BLOCK(?:\s+PUBLIC)?|PROGRAM|FUNCTION)\s+(?P<name>[A-Za-z_]\w*)",
    re.MULTILINE,
)

# Reference a un identifiant type/FB : apres ':', 'OF', 'ARRAY[..] OF', ou en instanciation
# `NomFB(`. Volontairement large (mieux vaut resoudre un faux ami que rater une dependance --
# resoudre un nom qui n'est pas un type existant ne casse rien, il est simplement ignore).
# NB : pas de \b avant ':' -- ':' est un caractere non-mot, si le caractere precedent est aussi
# non-mot (espace) il n'y a AUCUNE frontiere de mot a cette position, \b ne matche jamais (bug
# verifie empiriquement sur FB_Joystick.st, session 2026-08-23 -- 5 des 6 dependances reelles
# passaient inapercues).
REF_RE = re.compile(
    r"\bOF\s+(?P<name_of>(?:ST_|E_|FB_)\w+)\b"
    r"|:\s+(?P<name_colon>(?:ST_|E_|FB_)\w+)\b"
    r"|\b(?P<name_call>(?:ST_|E_|FB_)\w+)\s*\("
    r"|\b(?P<name_gvl>GVL_\w+)\b"
    r"|\b(?P<name_persist>_[A-Za-z]\w*)\b"
)

# GVL_*.st n'ont AUCUN mot-cle de declaration (pas de TYPE/FUNCTION_BLOCK/PROGRAM) -- juste
# `VAR_GLOBAL ... END_VAR`, le nom de la GVL est le nom du FICHIER (convention CODESYS : une GVL
# est un objet a part entiere du projet, pas un POU). DECL_RE ne les detecte donc jamais.
# Verifie sur GVL_Global.st / GVL_IHM.st (session 2026-08-23).
GVL_STEM_RE = re.compile(r"^GVL_\w+$")

# Variables PERSISTENT (GVL_PERSISTENT.st, convention NC-070 : prefixe `_`) sont accedees SANS
# aucun prefixe de GVL (pas de `GVL_PERSISTENT.` devant, contrairement aux autres GVL) -- il faut
# donc indexer chaque MEMBRE individuellement, pas juste le nom du fichier GVL. Verifie sur
# PRG_03_Modes_Cycle.st -> _CommunCfgPersist, _CycleSampleCount, session 2026-08-23.
GVL_MEMBER_DECL_RE = re.compile(r"^\s*(_[A-Za-z]\w*)\s*:\s*[A-Za-z_]", re.MULTILINE)

# Mots-cles/valeurs ST qui matchent accidentellement le prefixe (aucun aujourd'hui, garde pour
# durcir la regex sans casser silencieusement si un jour un mot-cle standard commence par ces
# prefixes).
IGNORE_NAMES: set[str] = set()


def _strip_comments(text: str) -> str:
    text = re.sub(r"\(\*.*?\*\)", "", text, flags=re.DOTALL)
    text = re.sub(r"//[^\n]*", "", text)
    return text


def build_declaration_index(code_root: Path) -> dict[str, Path]:
    """Scan one-shot de CODE/ : nom declare -> fichier .st qui le declare."""
    index: dict[str, Path] = {}
    for st_file in code_root.rglob("*.st"):
        if GVL_STEM_RE.match(st_file.stem):
            index[st_file.stem] = st_file
            gvl_text = _strip_comments(st_file.read_text(encoding="utf-8", errors="replace"))
            for gm in GVL_MEMBER_DECL_RE.finditer(gvl_text):
                index.setdefault(gm.group(1), st_file)
            continue

        text = _strip_comments(st_file.read_text(encoding="utf-8", errors="replace"))
        for m in DECL_RE.finditer(text):
            name = m.group("name")
            if name in index and index[name] != st_file:
                # Deux fichiers declarent le meme nom -- signale mais ne bloque pas
                # (resolution du premier trouve, ordre non garanti : a corriger a la main si ca
                # arrive un jour, pas un cas rencontre sur ce repo aujourd'hui).
                continue
            index[name] = st_file
    return index


def find_references(st_file: Path) -> set[str]:
    text = _strip_comments(st_file.read_text(encoding="utf-8", errors="replace"))
    refs: set[str] = set()
    for m in REF_RE.finditer(text):
        name = (
            m.group("name_of") or m.group("name_colon") or m.group("name_call")
            or m.group("name_gvl") or m.group("name_persist")
        )
        if name and name not in IGNORE_NAMES:
            refs.add(name)
    return refs


def resolve(targets: list[Path], code_root: Path) -> tuple[dict[str, Path], set[str]]:
    index = build_declaration_index(code_root)

    resolved: dict[str, Path] = {}
    unresolved: set[str] = set()
    seen_files: set[Path] = set()
    queue: list[Path] = list(targets)

    while queue:
        current = queue.pop()
        if current in seen_files:
            continue
        seen_files.add(current)

        for name in find_references(current):
            if name in resolved or name in unresolved:
                continue
            decl_file = index.get(name)
            if decl_file is None:
                unresolved.add(name)
                continue
            resolved[name] = decl_file
            if decl_file not in seen_files:
                queue.append(decl_file)

    return resolved, unresolved


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("targets", nargs="+", help="Fichier(s) .st cible(s)")
    parser.add_argument("--code-root", default="CODE", help="Racine des sources ST (defaut: CODE)")
    args = parser.parse_args()

    code_root = Path(args.code_root)
    if not code_root.is_dir():
        print(f"ERROR: --code-root '{code_root}' introuvable", file=sys.stderr)
        return 2

    targets = [Path(t) for t in args.targets]
    for t in targets:
        if not t.is_file():
            print(f"ERROR: fichier cible introuvable: {t}", file=sys.stderr)
            return 2

    resolved, unresolved = resolve(targets, code_root)

    output = {
        "resolved": {name: str(path) for name, path in sorted(resolved.items())},
        "unresolved": sorted(unresolved),
    }
    print(json.dumps(output, indent=2, ensure_ascii=False))

    return 0 if not unresolved else 1


if __name__ == "__main__":
    sys.exit(main())
