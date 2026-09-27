"""Garde-fou T401 : interface groupée et diagramme câblé du POC M3."""
from __future__ import annotations

from pathlib import Path
import re
import sys

import yaml


ROOT = Path(__file__).resolve().parents[3]
MODEL = ROOT / "TOOLS/TWINBENCH/modelica_poc_m3/M3_POC.mo"
CATALOG = ROOT / "DOC/WFLOW/CONTRACTS/T401_M3_POC_SIGNAL_CATALOG.yaml"

EXPECTED_GROUPS = {
    ("input", "M3Commands", "commands"),
    ("parameter", "M3Configuration", "configuration"),
    ("output", "M3Measurements", "measurements"),
    ("output", "M3DiscreteFeedback", "feedback"),
    ("output", "M3DeviceState", "deviceState"),
    ("output", "M3Diagnostics", "diagnostics"),
}

REQUIRED_STANDARD_BLOCKS = {
    "Modelica.Blocks.Nonlinear.Limiter",
    "Modelica.Blocks.Nonlinear.SlewRateLimiter",
    "Modelica.Blocks.Math.Product",
    "Modelica.Blocks.Math.Gain",
    "Modelica.Blocks.Continuous.LimIntegrator",
}


def fail(messages: list[str]) -> None:
    for message in messages:
        print(f"FAIL: {message}")
    raise SystemExit(1)


def main() -> None:
    errors: list[str] = []
    text = MODEL.read_text(encoding="utf-8")
    model_match = re.search(r"\bmodel\s+TranslationM3\b(.*?)\bend\s+TranslationM3\s*;", text, re.S)
    if not model_match:
        fail(["modèle TranslationM3 introuvable"])
    model = model_match.group(1)
    public = model.split("protected", 1)[0]

    groups = set(re.findall(
        r"^\s*(input|output|parameter)\s+(M3\w+)\s+(\w+)\s*;", public, re.M
    ))
    if groups != EXPECTED_GROUPS:
        errors.append(f"groupes publics attendus={sorted(EXPECTED_GROUPS)} trouvés={sorted(groups)}")

    flat = re.findall(
        r"^\s*(input|output|parameter)\s+(Boolean|Integer|Real)\s+(\w+)", public, re.M
    )
    if flat:
        errors.append(f"variables scalaires publiques interdites={flat}")

    declared: set[tuple[str, str, str]] = set()
    for direction, record_type, group_name in groups:
        record = re.search(
            rf"\brecord\s+{re.escape(record_type)}\b(.*?)\bend\s+{re.escape(record_type)}\s*;",
            text,
            re.S,
        )
        if not record:
            errors.append(f"record {record_type} introuvable")
            continue
        for data_type, field_name in re.findall(
            r"^\s*(Boolean|Integer|Real)\s+(\w+)", record.group(1), re.M
        ):
            declared.add((direction, f"{group_name}.{field_name}", data_type))

    catalog = yaml.safe_load(CATALOG.read_text(encoding="utf-8"))
    items = {
        (row["direction"], row["name"], row["data_type"]): row
        for row in catalog.get("signals", [])
    }
    missing = sorted(declared - set(items))
    stale = sorted(set(items) - declared)
    if missing:
        errors.append(f"signaux absents du catalogue={missing}")
    if stale:
        errors.append(f"signaux périmés dans le catalogue={stale}")

    roles = catalog.get("roles", {})
    profiles = catalog.get("role_profiles", {})
    invalid = []
    for key, row in items.items():
        profile = profiles.get(row.get("role"), {})
        if (row.get("role") not in roles or not row.get("unit") or not row.get("label")
                or not (row.get("kind") or profile.get("kind"))
                or not (row.get("access") or profile.get("access"))
                or not (row.get("authority") or profile.get("authority"))):
            invalid.append(key)
    if invalid:
        errors.append(f"métadonnées incomplètes={invalid}")

    absent_blocks = sorted(block for block in REQUIRED_STANDARD_BLOCKS if block not in model)
    if absent_blocks:
        errors.append(f"blocs standards absents du diagramme={absent_blocks}")
    connection_count = len(re.findall(r"\bconnect\s*\(", model))
    if connection_count < 8:
        errors.append(f"diagramme insuffisamment câblé: {connection_count} connexions")
    if "Diagram(" not in model:
        errors.append("annotation Diagram manquante")

    required_loop_fragments = {
        "contrôleur LocalLoopController": "block LocalLoopController",
        "exemples": "package Examples",
        "scénario AllerRetour": "model AllerRetour",
        "scénario BoucleLocale": "model BoucleLocale",
        "boucle illimitée configurable": "Integer cycleCount=0",
        "retour capteur Maintenance": "not feedback.maintenancePositionIsActive",
        "retour capteur Trémie": "feedback.tremiePositionIsActive",
    }
    for label, fragment in required_loop_fragments.items():
        if fragment not in text:
            errors.append(f"{label} absent: {fragment}")
    if text.find("block LocalLoopController") > text.find("model TranslationM3"):
        errors.append("LocalLoopController doit rester séparé et déclaré avant la plante")
    translation_body = model_match.group(1)
    if "LocalLoopController" in translation_body:
        errors.append("LocalLoopController ne doit pas être instancié dans TranslationM3")

    if errors:
        fail(errors)
    print(
        f"PASS: 6 groupes, {len(declared)} signaux catalogués, "
        f"{connection_count} connexions, {len(REQUIRED_STANDARD_BLOCKS)} familles de blocs standards, "
        "Examples et boucle locale présents."
    )


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, yaml.YAMLError) as exc:
        print(f"FAIL: {exc}")
        sys.exit(1)
