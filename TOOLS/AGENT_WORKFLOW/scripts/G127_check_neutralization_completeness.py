#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""G127 — Completude du gate de neutralisation `IF NOT Enable ... RETURN` (informatif).

Referentiel : AGENTS.md (« Enable=FALSE = neutralisation »), AF_Partie-03 §4,
CODE_QUALITY_STANDARDS.md §7 (Organisation d'un POU — Initialisation / gates).

Regle : dans un FB porteur d'un gate `IF NOT Enable [...] THEN ... RETURN; END_IF`,
TOUTE sortie publiee ecrite dans le corps (VAR_OUTPUT simple, ou champ de struct de
sortie `X.champ := ...` ou `X := ...`) doit AUSSI etre ecrite dans le bloc du gate,
sinon une valeur perimee du dernier scan actif reste publiee (bug FB_Encoder.HwOut
2026-08-27 ; bug FB_Joystick.AxisCmd anterieur).

Statut : INFORMATIF (exit 0). Le detail RHS n'est pas verifie (une sortie peut
legitimement etre alimentee autrement dans le gate — ex. depuis Calib RETAIN,
AF09 §4) : seule la PRESENCE d'une affectation dans le gate est exigee.

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/G127_check_neutralization_completeness.py [racine]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

VAR_OUTPUT_BLOCK_RE = re.compile(r"VAR_OUTPUT\b(.*?)\bEND_VAR", re.DOTALL | re.IGNORECASE)
OUT_FIELD_RE = re.compile(r"^\s*([A-Za-z_]\w*)\s*:", re.MULTILINE)
# Gate : `IF NOT Enable ... THEN` ... premier `RETURN;` ... `END_IF;`
GATE_RE = re.compile(
    r"IF\s+NOT\s+Enable\b[^\n]*?THEN(?P<body>.*?)RETURN\s*;",
    re.DOTALL | re.IGNORECASE,
)
# Cible d'affectation LHS : `Nom` ou `Nom.champ` (avant `:=`)
ASSIGN_LHS_RE = re.compile(r"^\s*([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)\s*:=", re.MULTILINE)


def strip_comments(text: str) -> str:
    text = re.sub(r"\(\*.*?\*\)", "", text, flags=re.DOTALL)
    text = re.sub(r"//[^\n]*", "", text)
    return text


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    code = root / "CODE"
    if not code.is_dir():
        print(f"G127: dossier introuvable : {code}", file=sys.stderr)
        return 0

    total_gates = 0
    gaps: list[str] = []
    clean = 0

    for f in sorted(code.rglob("FB_*.st")):
        raw = f.read_text(encoding="utf-8", errors="replace")
        text = strip_comments(raw)

        gate_m = GATE_RE.search(text)
        if not gate_m:
            continue
        total_gates += 1

        mo = VAR_OUTPUT_BLOCK_RE.search(text)
        if not mo:
            continue
        out_names = {n for n in OUT_FIELD_RE.findall(mo.group(1))}
        if not out_names:
            continue

        gate_body = gate_m.group("body")
        body_after_gate = text[gate_m.end():]

        gate_lhs = {m.split(".")[0] for m in ASSIGN_LHS_RE.findall(gate_body)}
        # racines de sortie ecrites APRES le gate (corps metier)
        body_lhs_roots = {m.split(".")[0] for m in ASSIGN_LHS_RE.findall(body_after_gate)}

        missing = sorted((body_lhs_roots & out_names) - gate_lhs)
        if missing:
            gaps.append(f"[WARN] {f.as_posix()} : sortie(s) ecrite(s) dans le corps mais "
                        f"absente(s) du gate NOT Enable -> {', '.join(missing)}")
        else:
            clean += 1

    for g in gaps:
        print(g)
    print(f"\nG127 : {total_gates} FB avec gate NOT Enable, {clean} complet(s), "
          f"{len(gaps)} incomplet(s) (informatif, non bloquant).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
