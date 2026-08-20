"""Garde-fou (REX 2026-08-13) : G410 s'applique à TOUS les POU `_LD`, pas juste PRG_06.

Un POU `_LD` nouveau (ex. `PRG_02_Acquisition_LD`) doit être couvert par les mêmes
invariants LD que `PRG_06_Outputs` — c'est le trou qui a laissé passer un XML
scratch avec 11 `outVariable` (IndexOutOfRangeException à l'import CODESYS).
"""

from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

NS = "http://www.plcopen.org/xml/tc6_0200"
NS_POU = {"pou": NS}

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "G410_check_ld_invariants.py"
SPEC = importlib.util.spec_from_file_location("G410_check_ld_invariants", SCRIPT)

g410 = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = g410
SPEC.loader.exec_module(g410)


def _q(tag: str) -> str:
    return f"{{{NS}}}{tag}"


def _write_bundle(pous: list[ET.Element]) -> Path:
    root = ET.Element(_q("project"))
    types = ET.SubElement(root, _q("types"))
    wrap = ET.SubElement(types, _q("pous"))
    for pou in pous:
        wrap.append(pou)
    fd, path = tempfile.mkstemp(suffix=".xml")
    os.close(fd)
    ET.ElementTree(root).write(path, encoding="utf-8", xml_declaration=True)
    return Path(path)


def _make_ld_pou(name: str, with_out_variable: bool) -> ET.Element:
    """POU programme `_LD` : rail gauche, bloc FB, optionnellement un outVariable
    (motif inVariable→outVariable interdit, règle 4 de G410)."""
    pou = ET.Element(_q("pou"), {"name": name, "pouType": "program"})
    iface = ET.SubElement(pou, _q("interface"))
    lvars = ET.SubElement(iface, _q("localVars"))
    var = ET.SubElement(lvars, _q("variable"), {"name": "instX"})
    typ = ET.SubElement(var, _q("type"))
    ET.SubElement(typ, _q("derived"), {"name": "FB_X"})
    body = ET.SubElement(pou, _q("body"))
    ld = ET.SubElement(body, _q("LD"))
    ET.SubElement(ld, _q("leftPowerRail"), {"localId": "0"})
    block = ET.SubElement(
        ld,
        _q("block"),
        {"localId": "10", "typeName": "FB_X", "instanceName": "instX"},
    )
    ET.SubElement(block, _q("inputVariables"))
    ET.SubElement(block, _q("inOutVariables"))
    ET.SubElement(block, _q("outputVariables"))
    if with_out_variable:
        ET.SubElement(ld, _q("inVariable"), {"localId": "20"})
        ET.SubElement(ld, _q("outVariable"), {"localId": "21"})
    ET.SubElement(ld, _q("rightPowerRail"), {"localId": "2147483646"})
    return pou


def test_g410_applies_invariants_to_non_prg06_ld_pou():
    """Un POU `_LD` autre que PRG_06 (ex. PRG_02_Acquisition_LD) doit être vérifié."""
    pou = _make_ld_pou("PRG_02_Acquisition_LD", with_out_variable=True)
    bundle = _write_bundle([pou])

    errors, warnings = g410.check_bundle(bundle)

    assert any("PRG_02_Acquisition_LD" in e for e in errors), (
        "G410 doit signaler les violations du POU `_LD` non-PRG_06 — sinon il est "
        "toujours figé sur PRG_06 et un nouveau POU LD n'est jamais contrôlé"
    )
    assert any("outVariable" in e for e in errors), (
        "La violation attendue (outVariable présent) doit être détectée"
    )


def test_g410_ignores_fb_types_named_ld():
    """Les FB types nommés `*_LD` (sans corps LD, pouType=functionBlock) sont ignorés :
    aucune violation « sans corps LD » ni invariant LD ne doit les viser."""
    pou = ET.Element(_q("pou"), {"name": "FB_WinchOutputInterlock", "pouType": "functionBlock"})
    body = ET.SubElement(pou, _q("body"))
    ET.SubElement(body, _q("ST"))
    bundle = _write_bundle([pou])

    errors, warnings = g410.check_bundle(bundle)

    assert not any("FB_WinchOutputInterlock" in e for e in errors), (
        f"Le FB type `*_LD` ne doit pas déclencher les invariants LD : {errors}"
    )


def test_g410_missing_ld_pou_passe():
    """Un bundle sans aucun POU programme `_LD` doit passer (PRG_06 migré en ST
    le 2026-08-20 : plus de barrière Ladder programme, rien à vérifier)."""
    pou = ET.Element(_q("pou"), {"name": "PRG_02_Acquisition", "pouType": "program"})
    body = ET.SubElement(pou, _q("body"))
    ET.SubElement(body, _q("ST"))
    bundle = _write_bundle([pou])

    errors, warnings = g410.check_bundle(bundle)

    assert not errors, f"Un bundle sans POU `_LD` programme doit passer : {errors}"
