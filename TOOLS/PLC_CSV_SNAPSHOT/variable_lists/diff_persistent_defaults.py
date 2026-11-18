#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Liste des ecarts entre un releve de persistantes (CSV) et les valeurs PAR DEFAUT du code.

Usage :
  python diff_persistent_defaults.py                      # releve le plus recent du dossier PERSISTANTES
  python diff_persistent_defaults.py RELEVE.csv [--output ECARTS.csv] [--all]

Entree  : CSV de snapshot_persistent.py (Variable;Type;Valeur) + CODE/GVL_PERSISTENT.st + les TYPE du CODE.
Sortie  : Ecarts_defaut_<horodatage>.csv a cote du releve (Variable;Type;Valeur lue;Defaut;Origine du defaut)
          + resume a l'ecran. Lecture seule : ne se connecte a rien, ne modifie ni CODE/ ni l'automate.

CE QUE LA LISTE EST : les variables dont la valeur lue differe du defaut declare dans le code
(initialiseur `:=` du GVL ou du champ de STRUCT, sinon defaut implicite 0 / FALSE).
CE QU'ELLE N'EST PAS : une preuve de perte au chargement. Un ecart est normal pour une calibration,
un reglage terrain ou un compteur ; c'est la liste des valeurs QUI DEVRAIENT SURVIVRE a un chargement
complet (RETAIN remis a zero), donc a verifier apres un tel chargement. Ecart = candidat, pas defaut.

Limites : defaut « inconnu » (constante nommee, enum, TIME, expression) -> non compare, liste a part
avec --all. Les variables volatiles (compteurs, position estimee) sont signalees.
"""
from __future__ import annotations

import argparse
import csv
import importlib.util
import re
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_DIR = HERE.parents[2] / "DOC" / "WFLOW" / "MISE_EN_SERVICE" / "20261117_PERSISTANTES"


def _load(name: str):
    spec = importlib.util.spec_from_file_location(name, HERE / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


gen = _load("generate_persistent_variable_list")
cmp_ = _load("compare_persistent_csv")

NAME = gen.NAME_RE
DECL_INIT_RE = re.compile(r"^\s*(" + NAME + r"(?:\s*,\s*" + NAME + r")*)\s*:\s*(.+?)\s*(?::=(.*))?$", re.DOTALL)
UNKNOWN = object()
NUMERIC = re.compile(r"^(U?S?D?L?INT|BYTE|WORD|DWORD|LWORD|REAL|LREAL)$", re.IGNORECASE)


def split_top(text: str, sep: str = ",") -> list[str]:
    out, depth, cur = [], 0, []
    for ch in text:
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        if ch == sep and depth == 0:
            out.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    tail = "".join(cur).strip()
    if tail or cur:
        out.append("".join(cur))
    return [s.strip() for s in out if s.strip()]


def parse_decls(body: str) -> list[tuple[str, str, str | None]]:
    members = []
    for stmt in gen.split_statements(body):
        m = DECL_INIT_RE.match(stmt)
        if not m:
            continue
        ttype = re.sub(r"\s+", " ", m.group(2)).strip()
        init = m.group(3).strip() if m.group(3) else None
        for n in (x.strip() for x in m.group(1).split(",")):
            members.append((n, ttype, init))
    return members


def build_registry() -> dict[str, list[tuple[str, str, str | None]]]:
    raw = {}
    for path in gen.CODE_DIR.rglob("*.st"):
        text = gen.strip_comments(path.read_text(encoding="utf-8", errors="replace"))
        for m in gen.TYPE_BLOCK_RE.finditer(text):
            sm = re.search(r"\bSTRUCT\b(.*?)\bEND_STRUCT\b", m.group(3), re.DOTALL | re.IGNORECASE)
            if sm:
                raw[m.group(1)] = (m.group(2), parse_decls(sm.group(1)))
    reg: dict = {}

    def resolve(n, seen=()):
        if n in reg:
            return reg[n]
        parent, own = raw[n]
        inh = resolve(parent, seen + (n,)) if parent and parent in raw and parent not in seen else []
        reg[n] = inh + own
        return reg[n]

    for n in raw:
        resolve(n)
    return reg


def implicit_default(type_text: str):
    t = type_text.strip().upper()
    if t == "BOOL":
        return False
    if NUMERIC.match(t):
        return 0
    return UNKNOWN


def literal(text: str, type_text: str):
    s = text.strip()
    u = s.upper()
    if u in ("TRUE", "FALSE"):
        return u == "TRUE"
    s2 = re.sub(r"^[A-Za-z]+#", "", s).replace("_", "")
    try:
        if re.match(r"^16#", s2, re.IGNORECASE):
            return int(s2[3:], 16)
        return float(s2) if re.search(r"[.eE]", s2) else int(s2)
    except ValueError:
        return UNKNOWN


def expand(type_text, init, prefix, reg, out):
    """Remplit out[chemin_feuille] = (defaut, origine)."""
    type_text = type_text.strip()
    am = gen.ARRAY_RE.match(type_text)
    if am:
        dims = gen.parse_dims(am.group(1))
        if dims is None:
            return
        import itertools
        combos = list(itertools.product(*dims))
        items = None
        if init and init.strip().startswith("["):
            items = split_top(init.strip()[1:-1])
            if any("(" in i and not i.startswith("(") for i in items):  # repetition 5(0) non developpee
                items = None
        for k, combo in enumerate(combos):
            sub = items[k] if items is not None and k < len(items) else None
            expand(am.group(2), sub, f"{prefix}[{','.join(map(str, combo))}]", reg, out)
        return
    if gen.STRING_RE.match(type_text):
        return
    if type_text in reg:
        given = {}
        if init and init.strip().startswith("("):
            for part in split_top(init.strip()[1:-1]):
                if ":=" in part:
                    k, v = part.split(":=", 1)
                    given[k.strip()] = v.strip()
        for field, ftype, finit in reg[type_text]:
            expand(ftype, given.get(field, finit), f"{prefix}.{field}", reg, out)
        return
    if init is not None:
        v = literal(init, type_text)
        out[prefix] = (v, "explicite" if v is not UNKNOWN else "inconnu: " + init.strip()[:30])
    else:
        d = implicit_default(type_text)
        out[prefix] = (d, "implicite 0/FALSE" if d is not UNKNOWN else "inconnu: " + type_text[:30])


def defaults() -> dict:
    text = gen.strip_comments(gen.GVL_PATH.read_text(encoding="utf-8", errors="replace"))
    top = []
    for block in gen.GVL_BLOCK_RE.finditer(text):
        top.extend(parse_decls(block.group(1)))
    reg = build_registry()
    out: dict = {}
    for name, ttype, init in top:
        expand(ttype, init, f"{gen.GVL_NAME}.{name}", reg, out)
    return out


def norm(value: str):
    s = value.strip()
    if s.upper() in ("TRUE", "FALSE"):
        return s.upper() == "TRUE"
    s = re.sub(r"^[A-Za-z0-9_]+#", "", s)
    try:
        return float(s)
    except ValueError:
        return s


def same(a, b) -> bool:
    if isinstance(a, bool) or isinstance(b, bool):
        return a is b or (isinstance(a, bool) and isinstance(b, bool) and a == b)
    try:
        return abs(float(a) - float(b)) <= 1e-6 * max(1.0, abs(float(b)))
    except (TypeError, ValueError):
        return str(a) == str(b)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("releve", nargs="?", type=Path)
    ap.add_argument("--output", type=Path)
    ap.add_argument("--all", action="store_true", help="liste aussi les defauts inconnus (non compares)")
    args = ap.parse_args()
    releve = args.releve
    if releve is None:
        files = sorted(DEFAULT_DIR.glob("Persistantes_*.csv"))
        if not files:
            print(f"ERREUR: aucun releve dans {DEFAULT_DIR}", file=sys.stderr)
            return 2
        releve = files[-1]
    dflt = defaults()
    rows = list(csv.reader(releve.read_text(encoding="utf-8-sig").splitlines(), delimiter=";"))[1:]
    diffs, unknown, same_n, volatile = [], [], 0, 0
    for r in rows:
        if len(r) < 3 or r[2].startswith("ERREUR"):
            continue
        path, typ, val = r[0], r[1], r[2]
        d = dflt.get(path)
        if d is None or d[0] is UNKNOWN:
            unknown.append((path, typ, val, d[1] if d else "absent du code"))
            continue
        if same(norm(val), d[0]):
            same_n += 1
            continue
        vol = path.startswith(cmp_.VOLATILE_PREFIXES)
        volatile += vol
        diffs.append((path, typ, val, str(d[0]).upper() if isinstance(d[0], bool) else str(d[0]), d[1], "volatile" if vol else ""))
    out = args.output or releve.with_name(f"Ecarts_defaut_{datetime.now():%Y%m%d_%H%M%S}.csv")
    with out.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["Variable", "Type", "Valeur lue", "Defaut du code", "Origine du defaut", "Volatile"])
        w.writerows(diffs)
        if args.all:
            for u in unknown:
                w.writerow([u[0], u[1], u[2], "?", u[3], ""])
    print(f"Releve : {releve.name} ({len(rows)} variables)")
    print(f"  = defaut : {same_n} | ecarts : {len(diffs)} (dont volatiles : {volatile}) | defaut inconnu (non compare) : {len(unknown)}")
    print(f"  -> {out}")
    print("  RAPPEL : un ecart est un candidat a verifier apres chargement complet, pas une perte prouvee.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
