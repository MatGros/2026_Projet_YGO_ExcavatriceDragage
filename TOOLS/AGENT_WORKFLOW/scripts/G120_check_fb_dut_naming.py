#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""G120 — Nommage des DUT propriete d'un seul FB (NC-110, informatif).

Referentiel : DOC/STDS/NAMING_CONVENTION.md — regle NC-110.

Regle : un DUT (`TYPE ST_xxx`) reference dans l'interface (VAR_INPUT / VAR_OUTPUT /
VAR_IN_OUT) d'exactement UN `FB_*` — et d'aucun autre FB — est la propriete de ce FB
et doit porter le prefixe `ST_fb<NomFb>_<Role>` (`fb` minuscule colle + `_` apres le
nom du FB). Ex. `FB_Joystick` -> `ST_fbJoystick_Cfg`, `ST_fbJoystick_AxisCmd`.

Statut : INFORMATIF (exit 0 systematique). Le socle existant (`ST_WinchCfg`,
`ST_CycleCfg`, `ST_EncoderHw`, ...) reste valide jusqu'a un lot de renommage dedie ;
ce gate mesure l'ecart et signale tout NOUVEAU DUT non conforme.

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/G120_check_fb_dut_naming.py [racine]
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

# Types socle transverses / partages : jamais propriete d'un seul FB, hors perimetre NC-110.
SHARED_TYPES = {
    "ST_Fault", "ST_FaultCause", "ST_Status", "ST_Lifecycle",
    "ST_Diag_Device", "ST_ContactorCheck",
}

# FB dont l'interface reference des DUT SANS en etre proprietaire (plomberie) :
#  - FB_CfgPersistBridge_* : pont IHM<->persistant, le proprietaire est le FB metier
#  - FB_Sim* / FB_SimBench : bancs de simulation, miroir d'interfaces existantes
#  - FB_TroubleshootingView / FB_Hmi_* : lecteurs de DUT IHM (`ST_*HMI`), pas proprietaires
NON_OWNER_FB_PREFIXES = (
    "FB_CfgPersistBridge_", "FB_Sim", "FB_TroubleshootingView", "FB_Hmi_",
)

TYPE_DEF_RE = re.compile(r"^\s*TYPE\s+(ST_\w+)\s*:", re.MULTILINE | re.IGNORECASE)
# Une ligne de declaration d'interface : `Nom : ST_Xxx;` (avec eventuel ARRAY/commentaire)
IFACE_FIELD_RE = re.compile(r"^\s*\w+\s*:\s*(?:ARRAY\s*\[[^\]]*\]\s*OF\s*)?(ST_\w+)", re.IGNORECASE)
SECTION_RE = re.compile(r"\b(VAR_INPUT|VAR_OUTPUT|VAR_IN_OUT|VAR\b|END_VAR)", re.IGNORECASE)


def iface_types(text: str) -> set[str]:
    """DUT references dans VAR_INPUT / VAR_OUTPUT / VAR_IN_OUT (pas VAR interne)."""
    found: set[str] = set()
    in_iface = False
    for line in text.splitlines():
        m = SECTION_RE.search(line)
        if m:
            kw = m.group(1).upper().strip()
            if kw in ("VAR_INPUT", "VAR_OUTPUT", "VAR_IN_OUT"):
                in_iface = True
                continue
            if kw in ("VAR", "END_VAR"):
                in_iface = False
                continue
        if in_iface:
            fm = IFACE_FIELD_RE.match(line)
            if fm:
                found.add(fm.group(1))
    return found


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    code = root / "CODE"
    if not code.is_dir():
        print(f"G120: dossier introuvable : {code}", file=sys.stderr)
        return 0  # informatif

    st_files = list(code.rglob("*.st"))
    # 1. Tous les DUT definis + leur fichier
    dut_file: dict[str, Path] = {}
    for f in st_files:
        for mt in TYPE_DEF_RE.finditer(f.read_text(encoding="utf-8", errors="replace")):
            dut_file[mt.group(1)] = f

    # 2. Pour chaque FB : types references dans son interface
    fb_iface: dict[str, set[str]] = {}
    for f in st_files:
        if not f.stem.startswith("FB_"):
            continue
        if f.stem.startswith(NON_OWNER_FB_PREFIXES):
            continue
        fb_iface[f.stem] = iface_types(f.read_text(encoding="utf-8", errors="replace"))

    # 3. DUT -> set des FB qui le referencent en interface
    owners: dict[str, set[str]] = {}
    for fb, types in fb_iface.items():
        for t in types:
            owners.setdefault(t, set()).add(fb)

    warns: list[str] = []
    ok = 0
    for dut, fbs in sorted(owners.items()):
        if dut in SHARED_TYPES or dut not in dut_file:
            continue
        if dut.endswith("HMI"):
            continue  # DUT d'echange IHM -> convention `ST_*HMI`, pas NC-110
        if len(fbs) != 1:
            continue  # partage entre plusieurs FB -> DUT de domaine, hors NC-110
        fb = next(iter(fbs))
        stem = fb[len("FB_"):]                      # FB_Joystick -> Joystick
        expected = f"ST_fb{stem}_"
        if dut.startswith(expected):
            ok += 1
        else:
            warns.append(
                f"[WARN] {dut}  (propriete unique de {fb}, defini {dut_file[dut].as_posix()}) "
                f"-> attendu prefixe `{expected}<Role>` (NC-110)"
            )

    for w in warns:
        print(w)
    print(
        f"\nG120 NC-110 : {ok} DUT conforme(s), {len(warns)} a migrer "
        f"(informatif — lot de renommage dedie, non bloquant)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
