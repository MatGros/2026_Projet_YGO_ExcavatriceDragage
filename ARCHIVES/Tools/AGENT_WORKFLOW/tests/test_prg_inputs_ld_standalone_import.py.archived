"""Regression guard for the bundle PRG_01_Inputs_LD PLCopenXML LD graph.

Couvre la REX 2026-08-03 (import CODESYS "index hors tableau" sur
PRG_01_Inputs_LD) : le POU Ladder livré dans CODE_Bundle.xml doit respecter
la structure CODESYS réelle observée sur l'oracle
samples_reference_codesys/PRG_input_LD.xml :
  - chaque input formel du FB apparaît dans inputVariables, même non câblé ;
  - input non câblé → inVariable à expression vide ;
  - BOOL littéral FALSE → expression "0" (pas "FALSE") ;
  - sorties Error/ErrorId → <connectionPointOut><expression/></connectionPointOut> ;
  - rightPowerRail présent en fin de LD.

La procédure de livraison courante est le bundle : il n'existe plus de
fichier standalone CODE/MAIN/PRG_01_Inputs_LD.xml.
"""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GENERATOR_ROOT = ROOT / "TOOLS" / "ST_PLCOPENXML_GENERATOR"
sys.path.insert(0, str(GENERATOR_ROOT))

from generator.diagnostics import DiagnosticCollector
from generator.file_discovery import discover_objects
from generator.xml_builder import build_project_xml
from generator.xml_serializer import serialize

POU_NAME = "PRG_01_Inputs_LD"
BUNDLE = ROOT / "CODE" / "CODE_Bundle.xml"


def local_name(tag: str) -> str:
    return tag.rsplit("}", maxsplit=1)[-1]


def bundle_pou() -> ET.Element:
    root = ET.parse(BUNDLE).getroot()
    pous = [
        element
        for element in root.iter()
        if local_name(element.tag) == "pou" and element.get("name") == POU_NAME
    ]
    assert len(pous) == 1, f"POU {POU_NAME} absent ou dupliqué dans le bundle"
    return pous[0]


def generated_pou() -> ET.Element:
    diagnostics = DiagnosticCollector()
    objects = discover_objects(ROOT / "CODE", diagnostics)
    inputs = [object_ for object_ in objects if object_.name == POU_NAME]
    assert len(inputs) == 1
    assert inputs[0].raw_xml_path is None

    project = build_project_xml(
        POU_NAME,
        {object_.name: object_ for object_ in objects},
        diagnostics,
        include_deps=False,
        project_name="ExcavatriceDragage",
    )
    generated = [
        element
        for element in ET.fromstring(serialize(project)).iter()
        if local_name(element.tag) == "pou" and element.get("name") == POU_NAME
    ]
    assert len(generated) == 1
    return generated[0]


def test_bundle_prg01_is_native_single_ld_pou() -> None:
    pou = bundle_pou()
    assert pou.get("pouType") == "program"
    bodies = [element for element in pou.iter() if local_name(element.tag) == "LD"]
    assert len(bodies) == 1, "PRG_01_Inputs_LD doit être un POU Ladder (1 corps LD)"
    assert pou.find(".//{*}LD/{*}leftPowerRail") is not None
    assert pou.find(".//{*}LD/{*}rightPowerRail") is not None


def test_bundle_prg01_matches_the_generator() -> None:
    """Le POU livré dans le bundle doit être identique au graphe généré."""
    expected = generated_pou()
    actual = bundle_pou()
    assert ET.canonicalize(ET.tostring(actual, encoding="unicode")) == ET.canonicalize(
        ET.tostring(expected, encoding="unicode")
    )


def test_bundle_prg01_blocks_declare_all_fb_inputs() -> None:
    """Chaque bloc FB_Input expose ses 4 inputs formels, même non câblés."""
    pou = bundle_pou()
    blocks = pou.findall(".//{*}LD/{*}block")
    assert len(blocks) == 22, f"Attendu 22 blocs FB_Input, trouvé {len(blocks)}"
    for block in blocks:
        assert block.get("typeName") == "FB_Input"
        params = {
            variable.get("formalParameter")
            for variable in block.findall(".//{*}inputVariables/{*}variable")
        }
        assert {"InputRaw", "InvertLogic", "FilterTime", "ChannelOk"} <= params, (
            f"Bloc {block.get('instanceName')}: inputs formels incomplets: {params}"
        )


def test_bundle_prg01_unwired_inputs_are_empty_invariables() -> None:
    """InvertLogic/ChannelOk non câblés → inVariable à expression vide (oracle)."""
    pou = bundle_pou()
    ld = pou.find(".//{*}LD")
    blocks = ld.findall("{*}block")
    first = blocks[0]
    first_id = first.get("localId")
    inputs = {
        variable.get("formalParameter"): variable
        for variable in first.findall("{*}inputVariables/{*}variable")
    }
    for p_name in ("InvertLogic", "ChannelOk"):
        conn = inputs[p_name].find("{*}connectionPointIn/{*}connection")
        src_id = conn.get("refLocalId")
        src = ld.find(f"{{*}}inVariable[@localId='{src_id}']")
        assert src is not None, f"{p_name}: source inVariable {src_id} absente"
        expr = src.find("{*}expression")
        assert expr is not None and (expr.text is None or expr.text == ""), (
            f"{p_name} (non câblé) doit porter une expression vide"
        )
    assert first_id == blocks[0].get("localId")


def test_bundle_prg01_brake_false_serialized_as_zero() -> None:
    """InvertLogic := FALSE doit être sérialisé expression "0" (oracle)."""
    pou = bundle_pou()
    ld = pou.find(".//{*}LD")
    expressions = [
        element.text
        for element in ld.findall(".//{*}inVariable/{*}expression")
        if element.text is not None
    ]
    assert "0" in expressions, f"Aucun FALSE sérialisé en '0': {expressions[:20]}"
    assert "FALSE" not in expressions, f"'FALSE' littéral interdit: {expressions[:20]}"
    assert expressions.count("T#20MS") >= 22, "FilterTime T#20MS manquant"


def test_bundle_prg01_error_outputs_have_empty_expression() -> None:
    """Sorties Error/ErrorId → <connectionPointOut><expression/></connectionPointOut>."""
    pou = bundle_pou()
    for block in pou.findall(".//{*}LD/{*}block"):
        outputs = block.findall(".//{*}outputVariables/{*}variable")
        for output in outputs:
            name = output.get("formalParameter")
            cpo = output.find("{*}connectionPointOut")
            assert cpo is not None, f"Sortie {name} sans connectionPointOut"
            if name == "State":
                assert cpo.find("{*}expression") is None
            else:
                assert cpo.find("{*}expression") is not None, (
                    f"Sortie {name}: <expression/> attendu dans connectionPointOut"
                )


def test_bundle_prg01_no_standalone_xml_anywhere() -> None:
    """La livraison est le bundle : aucun fichier *_LD.xml n'existe en CODE/."""
    standalone = ROOT / "CODE" / "MAIN" / f"{POU_NAME}.xml"
    assert not standalone.exists(), "Standalone XML supprimé — ne doit pas réapparaître"
