#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
G480 — Le harnais d'intégration FB_TestHarness_PRG_04 reste un MIROIR de PRG_04.

Contexte (T181-00 AC2 ; B4 §3.1) : le mégabloc FB_Main_EndToEnd n'instancie pas le
vrai PRG_04 mais un stub `FB_TestHarness_PRG_04.st` qui ré-implémente sa logique
(agrégateur de clamp, SEL M1/M2, permits §5). Sans garde, chaque édition de
PRG_04_Treuils_Benne.st désynchronise le stub en silence -> tests verts sur du code
non représentatif (REX PRG_10_Outputs_LD).

Ce gate compare, pour les expressions structurantes du clamp de palier, l'ensemble
des CONDITIONS (identifiants) utilisées côté PRG_04 et côté stub. Divergence -> FAIL.

Expressions surveillées (une par (instance, borne)) :
  - MaxStepAscent           M1 et M2
  - CfgMaxStepDescente      M1 et M2   (renommé MaxStepDown à terme — les 2 noms tolérés)

Usage : python TOOLS/AGENT_WORKFLOW/scripts/G480_check_harness_mirrors_prg04.py [--report]
Sortie : 0 si miroir OK, 1 si divergence. Informatif si les 2 fichiers n'ont pas
encore la même forme (avant/pendant T181-08/10) — signalé WARN, pas FAIL.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(__file__).resolve().parents[3]
PRG04 = ROOT / "CODE" / "M_MAIN" / "PRG_04_Treuils_Benne.st"
STUB = ROOT / "TOOLS" / "TEST_AUTO_CI" / "RESULTS" / "M_MAIN" / "FB_TestHarness_PRG_04.st"

# Bornes surveillées : nom de champ passé à instWinchMx( ... <champ> := SEL(<cond>, ...) )
WATCHED = ["MaxStepAscent", "CfgMaxStepDescente", "MaxStepDown", "MaxStepUp"]

# Identifiants "de bruit" à ignorer dans la comparaison des conditions
NOISE = {
    "SEL", "OR", "AND", "NOT", "TRUE", "FALSE",
    "EffectiveMaxStepAscent", "EffectiveMaxStepDescente", "EffectiveMaxStepDescent",
    "instWinchSync", "SyncDeviationWarn", "ReqProgram", "ReqBucket",
}
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_.]*")


def _blocks(text: str, inst: str) -> str:
    """Renvoie le contenu de l'appel `inst(` ... `);` (1er trouvé)."""
    i = text.find(inst + "(")
    if i < 0:
        return ""
    depth = 0
    out = []
    for ch in text[i:]:
        out.append(ch)
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                break
    return "".join(out)


def _clamp_conditions(call_text: str, field: str) -> set[str] | None:
    """Extrait l'ensemble des identifiants de la condition du SEL affecté à `field`."""
    m = re.search(rf"\b{re.escape(field)}\s*:=\s*SEL\s*\(", call_text)
    if not m:
        return None
    start = m.end()
    depth = 1
    end = start
    for k in range(start, len(call_text)):
        c = call_text[k]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                end = k
                break
    inner = call_text[start:end]
    cond = inner.split(",", 1)[0]  # 1er argument du SEL = la condition
    ids = set()
    for t in IDENT.findall(cond):
        if t in NOISE or t[0].isdigit():
            continue
        # normalise : garde les 2 derniers segments du chemin pointe
        # (PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ForceMinSpeedStep
        #  == ReqProgram.ReqBucket.ForceMinSpeedStep == ReqBucket.ForceMinSpeedStep)
        seg = t.split(".")
        norm = ".".join(seg[-2:]) if len(seg) >= 2 else t
        if norm.split(".")[-1] in NOISE:
            continue
        ids.add(norm)
    return ids


def _collect(path: Path) -> dict[str, set[str]]:
    txt = path.read_text(encoding="utf-8", errors="replace")
    res: dict[str, set[str]] = {}
    for inst in ("instWinchM1", "instWinchM2"):
        call = _blocks(txt, inst)
        for f in WATCHED:
            conds = _clamp_conditions(call, f)
            if conds is not None:
                res[f"{inst}.{f}"] = conds
    return res


def main() -> int:
    report = "--report" in sys.argv
    if not PRG04.is_file() or not STUB.is_file():
        print("[G480] SKIP — PRG_04 ou stub introuvable")
        return 0

    prg = _collect(PRG04)
    stub = _collect(STUB)

    if not prg or not stub:
        print("[G480] WARN — expressions de clamp SEL introuvables (refactor T181-08/10 en cours ?)")
        return 0

    diverg = []
    for key in sorted(set(prg) | set(stub)):
        a = prg.get(key)
        b = stub.get(key)
        if a is None or b is None:
            diverg.append((key, f"présent d'un seul côté (PRG_04={a is not None}, stub={b is not None})"))
        elif a != b:
            only_prg = a - b
            only_stub = b - a
            diverg.append((key, f"conditions divergentes  seulement PRG_04={sorted(only_prg)}  seulement stub={sorted(only_stub)}"))
        elif report:
            print(f"[G480] OK  {key}  ({len(a)} conditions)")

    if diverg:
        print("[G480] FAIL — le stub FB_TestHarness_PRG_04 n'est plus le miroir de PRG_04 :")
        for key, msg in diverg:
            print(f"   - {key} : {msg}")
        print("   -> aligner TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/FB_TestHarness_PRG_04.st sur CODE/M_MAIN/PRG_04_Treuils_Benne.st")
        return 1

    print(f"[G480] PASS — stub aligné sur PRG_04 ({len(prg)} expressions de clamp comparées)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
