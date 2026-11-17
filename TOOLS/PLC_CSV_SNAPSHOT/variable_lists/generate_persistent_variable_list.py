#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genere la liste a plat (variables feuilles) de GVL_PERSISTENT a partir du CODE.

Entree  : CODE/GVL_PERSISTENT.st + les TYPE ... STRUCT de CODE/**/*.st
Sortie  : persistent_variables.txt (une variable par ligne, chemin relatif a l'application,
          ex. GVL_PERSISTENT._CalibM1.HomingRefRaw) lue par
          ../codesys_console/codesys_snapshot_persistent.py

Developpe : tableaux (ARRAY[1..5] OF REAL -> x[1] .. x[5], multi-dimensions -> x[1,2]),
structures imbriquees, enums (feuille). Ignore les STRING (non lisibles en lot).

Usage : python generate_persistent_variable_list.py [--output FICHIER] [--with-sim] [--skip REGEX]

Limite connue : le projet en ligne peut dater d'une version differente du CODE (ex. machine sur
v0.7.24). Un chemin absent du projet en ligne sort en « ERREUR: ... » dans le CSV, sans arreter
la lecture des autres. Ne modifie ni CODE/ ni l'automate.
"""
from __future__ import annotations

import argparse
import itertools
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
CODE_DIR = REPO_ROOT / "CODE"
GVL_PATH = CODE_DIR / "GVL_PERSISTENT.st"
GVL_NAME = "GVL_PERSISTENT"
DEFAULT_OUTPUT = Path(__file__).resolve().parent / "persistent_variables.txt"

NAME_RE = r"[A-Za-z_][A-Za-z0-9_]*"
TYPE_BLOCK_RE = re.compile(
    r"\bTYPE\s+(" + NAME_RE + r")\s*(?:EXTENDS\s+(" + NAME_RE + r")\s*)?:(.*?)\bEND_TYPE\b",
    re.DOTALL | re.IGNORECASE,
)
ARRAY_RE = re.compile(r"^ARRAY\s*\[(.+?)\]\s*OF\s+(.+)$", re.DOTALL | re.IGNORECASE)
STRING_RE = re.compile(r"^W?STRING\b", re.IGNORECASE)
DECL_RE = re.compile(r"^\s*(" + NAME_RE + r"(?:\s*,\s*" + NAME_RE + r")*)\s*:\s*(.+?)\s*(?::=.*)?$", re.DOTALL)
GVL_BLOCK_RE = re.compile(r"\bVAR_GLOBAL\b[^;]*?\n(.*?)\bEND_VAR\b", re.DOTALL | re.IGNORECASE)


def strip_comments(text: str) -> str:
    """Retire (* ... *), // ... et les pragmas { ... } d'une ligne."""
    text = re.sub(r"\(\*.*?\*\)", "", text, flags=re.DOTALL)
    text = re.sub(r"//[^\r\n]*", "", text)
    return re.sub(r"\{[^}\r\n]*\}", "", text)


def split_statements(body: str) -> list[str]:
    """Decoupe sur ';' au niveau 0 de parentheses/crochets (initialiseurs multi-lignes)."""
    out, depth, current = [], 0, []
    for ch in body:
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        if ch == ";" and depth == 0:
            out.append("".join(current))
            current = []
        else:
            current.append(ch)
    tail = "".join(current).strip()
    if tail:
        out.append(tail)
    return [s.strip() for s in out if s.strip()]


def parse_declarations(body: str) -> list[tuple[str, str]]:
    """Retourne [(nom, type)] pour chaque declaration 'nom : type [:= init]'."""
    members: list[tuple[str, str]] = []
    for stmt in split_statements(body):
        m = DECL_RE.match(stmt)
        if not m:
            continue
        type_text = re.sub(r"\s+", " ", m.group(2)).strip()
        for name in (n.strip() for n in m.group(1).split(",")):
            members.append((name, type_text))
    return members


def build_registry() -> dict[str, list[tuple[str, str]]]:
    """{type: [(champ, type)]} pour tous les STRUCT de CODE/ ; les enums/alias n'y figurent pas."""
    raw: dict[str, tuple[str | None, list[tuple[str, str]]]] = {}
    for path in CODE_DIR.rglob("*.st"):
        text = strip_comments(path.read_text(encoding="utf-8", errors="replace"))
        for m in TYPE_BLOCK_RE.finditer(text):
            name, parent, body = m.group(1), m.group(2), m.group(3)
            sm = re.search(r"\bSTRUCT\b(.*?)\bEND_STRUCT\b", body, re.DOTALL | re.IGNORECASE)
            if not sm:
                continue
            raw[name] = (parent, parse_declarations(sm.group(1)))

    registry: dict[str, list[tuple[str, str]]] = {}

    def resolve(name: str, seen: tuple[str, ...] = ()) -> list[tuple[str, str]]:
        if name in registry:
            return registry[name]
        parent, own = raw[name]
        inherited: list[tuple[str, str]] = []
        if parent and parent in raw and parent not in seen:
            inherited = resolve(parent, seen + (name,))
        registry[name] = inherited + own
        return registry[name]

    for type_name in raw:
        resolve(type_name)
    return registry


def parse_dims(dim_text: str) -> list[list[int]] | None:
    """'1..5, 1..2' -> [[1..5], [1..2]] ; None si une borne n'est pas un entier litteral."""
    dims: list[list[int]] = []
    for part in dim_text.split(","):
        m = re.match(r"^\s*(-?\d+)\s*\.\.\s*(-?\d+)\s*$", part)
        if not m:
            return None
        lo, hi = int(m.group(1)), int(m.group(2))
        dims.append(list(range(lo, hi + 1)))
    return dims


def walk(type_text: str, prefix: str, registry, out: list[str], notes: list[str]) -> None:
    type_text = type_text.strip()
    am = ARRAY_RE.match(type_text)
    if am:
        dims = parse_dims(am.group(1))
        if dims is None:
            notes.append(f"{prefix}: bornes de tableau non litterales ({am.group(1)}), non developpe")
            return
        for combo in itertools.product(*dims):
            walk(am.group(2), f"{prefix}[{','.join(str(i) for i in combo)}]", registry, out, notes)
        return
    if STRING_RE.match(type_text):
        notes.append(f"{prefix}: STRING ignoree")
        return
    if type_text in registry:
        for field, field_type in registry[type_text]:
            walk(field_type, f"{prefix}.{field}", registry, out, notes)
        return
    out.append(prefix)  # type simple, enum ou type inconnu : feuille


def main(output: Path, with_sim: bool, skips: list[str], with_learning: bool = False) -> int:
    if not GVL_PATH.exists():
        print(f"ERREUR: {GVL_PATH} introuvable", file=sys.stderr)
        return 2
    gvl_text = strip_comments(GVL_PATH.read_text(encoding="utf-8", errors="replace"))
    top_level: list[tuple[str, str]] = []
    for block in GVL_BLOCK_RE.finditer(gvl_text):
        top_level.extend(parse_declarations(block.group(1)))
    if not top_level:
        print("ERREUR: aucune declaration trouvee dans GVL_PERSISTENT.st", file=sys.stderr)
        return 2

    registry = build_registry()
    skip_res = [re.compile(s) for s in skips]
    if not with_sim:
        skip_res.append(re.compile(r"^" + GVL_NAME + r"\._Sim"))
    if not with_learning:
        # Table d'apprentissage de vitesse (120 variables) : collecteur passif, non utilise en exploitation.
        skip_res.append(re.compile(r"^" + GVL_NAME + r"\._WinchSpeedLearnTable\."))

    leaves: list[str] = []
    notes: list[str] = []
    for name, type_text in top_level:
        walk(type_text, f"{GVL_NAME}.{name}", registry, leaves, notes)
    kept = [v for v in leaves if not any(r.search(v) for r in skip_res)]

    header = [
        "# Liste a plat des variables de GVL_PERSISTENT (genere par generate_persistent_variable_list.py)",
        f"# Source : CODE/GVL_PERSISTENT.st ; {len(top_level)} variables de premier niveau, "
        f"{len(kept)} variables feuilles (sur {len(leaves)})",
        "# Ne pas editer a la main : relancer le generateur si la structure change.",
    ]
    header += [f"# NOTE {n}" for n in notes]
    output.write_text("\n".join(header + kept) + "\n", encoding="utf-8")
    print(f"{len(top_level)} variables de premier niveau -> {len(kept)} feuilles ({len(leaves) - len(kept)} ignorees)")
    for n in notes:
        print("  note:", n)
    print("->", output)
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="fichier de sortie")
    parser.add_argument("--with-sim", action="store_true", help="inclure les variables _Sim* (banc de test)")
    parser.add_argument("--with-learning", action="store_true", help="inclure _WinchSpeedLearnTable (120 variables, non utilisee)")
    parser.add_argument("--skip", action="append", default=[], help="regex de chemins a ignorer (repetable)")
    args = parser.parse_args()
    sys.exit(main(args.output, args.with_sim, args.skip, args.with_learning))
