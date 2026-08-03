"""Regression guard for the standalone PRG_INPUTS_LD PLCopenXML import."""

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

POU_NAME = "PRG_INPUTS_LD"
STANDALONE = ROOT / "CODE" / "MAIN" / f"{POU_NAME}.xml"
BUNDLE = ROOT / "CODE" / "CODE_Bundle.xml"


def local_name(tag: str) -> str:
    return tag.rsplit("}", maxsplit=1)[-1]


def named_pous(path: Path) -> list[ET.Element]:
    root = ET.parse(path).getroot()
    return [
        element
        for element in root.iter()
        if local_name(element.tag) == "pou" and element.get("name") == POU_NAME
    ]


def canonical(element: ET.Element) -> str:
    """Compare XML structure independently from serializer attribute order."""
    return ET.canonicalize(ET.tostring(element, encoding="unicode"))


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


def test_prg_inputs_ld_standalone_is_native_single_ld_pou() -> None:
    root = ET.parse(STANDALONE).getroot()
    assert local_name(root.tag) == "project"
    assert any(local_name(element.tag) == "fileHeader" for element in root)
    assert any(local_name(element.tag) == "contentHeader" for element in root)

    pous = [element for element in root.iter() if local_name(element.tag) == "pou"]
    assert len(pous) == 1
    assert pous[0].get("name") == POU_NAME
    assert pous[0].get("pouType") == "program"
    assert any(local_name(element.tag) == "LD" for element in pous[0].iter())


def test_prg_inputs_ld_standalone_and_bundle_match_the_generator() -> None:
    """The delivery export and bundle POU must be the same generated LD graph."""
    standalone = named_pous(STANDALONE)
    bundle = named_pous(BUNDLE)
    assert len(standalone) == 1
    assert len(bundle) == 1

    expected = generated_pou()
    assert canonical(standalone[0]) == canonical(expected)
    assert canonical(bundle[0]) == canonical(expected)
