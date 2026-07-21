#!/usr/bin/env python3
"""Generate Pro-style PlantUML diagrams for the project workflow.

Replaces old Mermaid diagrams with modern, high-definition PNG images.
- workflow: read from AGENT_WORKFLOW/config/workflow_diagram.json;
- structure: built from the AGENT_WORKFLOW filesystem.
"""

from __future__ import annotations

import argparse
import base64
import html
import json
import re
import struct
import urllib.request
import zlib
from pathlib import Path

# Le serveur public PlantUML rejette/coupe silencieusement tout raster
# au-delà de ~4096px (PLANTUML_LIMIT_SIZE). On se garde une marge et on
# force systématiquement une directive `scale max` (la seule qui empêche
# réellement le crop côté serveur - contrairement aux skinparam
# maxImageWidth/maxImageHeight qui ne le font PAS de façon fiable).
PLANTUML_SERVER_HARD_LIMIT = 4096
SAFE_MAX_DIM = 3800

# --- Style PlantUML "Pro" Centralisé ---
PUML_STYLE = """
' --- Style Configuration ---
' RÈGLE GÉNÉRALE : Utilisation des emojis autorisée et recommandée pour réduire la taille du texte et favoriser une lecture visuelle intuitive.
skinparam backgroundColor #FFFFFF
skinparam shadowing true
skinparam roundcorner 10
skinparam fontname "Segoe UI"
skinparam fontsize 14
skinparam ArrowColor #455A64
skinparam ArrowThickness 1.5

' --- Colors ---
!define REFINEMENT_COLOR #FFE0B2
!define GATE_COLOR #C8E6C9
!define VALIDATION_COLOR #F8BBD0
!define TRACE_COLOR #E1BEE7
!define INPUT_COLOR #BBDEFB
!define DIRECTORY_COLOR #E3F2FD
!define ROOT_COLOR #263238
"""

def plantuml_encode(puml_text):
    """Encode PlantUML text for the official server API."""
    compressor = zlib.compressobj(level=-1, method=zlib.DEFLATED, wbits=-15)
    zlib_data = compressor.compress(puml_text.encode("utf-8"))
    zlib_data += compressor.flush()
    base64_data = base64.b64encode(zlib_data).decode("utf-8")
    std_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    puml_chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
    table = str.maketrans(std_chars, puml_chars)
    return base64_data.translate(table)

def _ensure_scale_safety(puml_text: str, max_dim: int = SAFE_MAX_DIM) -> str:
    """Injecte `scale max WxH` après @startuml si absent, pour empêcher
    tout dépassement de la limite serveur PlantUML (crop silencieux)."""
    if "scale " in puml_text:
        return puml_text
    lines = puml_text.splitlines()
    for i, line in enumerate(lines):
        if line.strip().startswith("@startuml"):
            lines.insert(i + 1, f"scale max {max_dim}x{max_dim}")
            return "\n".join(lines)
    return puml_text


def _read_png_dimensions(data: bytes) -> tuple[int, int]:
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("signature PNG absente/invalide")
    width, height = struct.unpack(">II", data[16:24])
    return width, height


def render_puml(puml_text, output_path: Path, output_format="png") -> bool:
    """Render PlantUML text to an image file via the official server.

    Injecte une garde anti-crop puis valide le résultat (taille fichier +
    dimensions réelles du PNG). Retourne True si le diagramme est fiable,
    False sinon (fichier quand même écrit pour inspection)."""
    puml_text = _ensure_scale_safety(puml_text) if output_format == "png" else puml_text
    encoded = plantuml_encode(puml_text)
    url = f"http://www.plantuml.com/plantuml/{output_format}/{encoded}"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(req) as response:
            if response.status != 200:
                print(f"[ECHEC] {output_path.name} : serveur PlantUML HTTP {response.status}")
                return False
            data = response.read()
    except Exception as e:
        print(f"[ECHEC] {output_path.name} : rendu PlantUML impossible ({e})")
        return False

    output_path.write_bytes(data)

    if len(data) < 5000:
        print(f"[ECHEC] {output_path.name} : fichier suspect ({len(data)} octets, probablement une erreur PlantUML)")
        return False

    if output_format != "png":
        print(f"[OK] {output_path.name} ({len(data)} octets)")
        return True

    try:
        width, height = _read_png_dimensions(data)
    except ValueError as e:
        print(f"[ECHEC] {output_path.name} : {e}")
        return False

    if width >= PLANTUML_SERVER_HARD_LIMIT or height >= PLANTUML_SERVER_HARD_LIMIT:
        print(
            f"[ECHEC] {output_path.name} : {width}x{height}px atteint/dépasse la limite "
            f"serveur ({PLANTUML_SERVER_HARD_LIMIT}px) -> diagramme probablement CROPPED. "
            f"Réduire SAFE_MAX_DIM ou scinder le diagramme en plusieurs vues."
        )
        return False

    print(f"[OK] {output_path.name} généré ({width}x{height}px, {len(data)} octets)")
    return True

def load_manifest(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))

def build_workflow_puml(manifest: dict) -> str:
    # Layout dot (defaut) produit un canvas natif trop grand pour ce nombre
    # de noeuds -> le serveur PlantUML clippe avant meme d'appliquer `scale`.
    # smetana tasse le layout et reste dans la limite serveur.
    lines = ["@startuml Workflow", "!pragma layout smetana", PUML_STYLE]
    lines.append('title Workflow de Développement Automate (Hybride Pi + Claude)')
    
    nodes_by_group = {}
    for node in manifest["nodes"]:
        nodes_by_group.setdefault(node.get("group"), []).append(node)
    
    color_map = {
        "INPUT": "BBDEFB",
        "REFINEMENT": "FFE0B2",
        "GATES": "C8E6C9",
        "VALIDATION": "F8BBD0",
        "TRACEABILITY": "E1BEE7"
    }
    
    for group in manifest["groups"]:
        puml_color = color_map.get(group["id"], "EEEEEE")
        lines.append(f'rectangle "{group["label"]}" as {group["id"]} #{puml_color} {{')
        for node in nodes_by_group.get(group.get("id"), []):
            label_text = node["label"].replace("\n", "\\n")
            lines.append(f'    rectangle "{label_text}" as {node["id"]}')
        lines.append("}")
    
    for edge in manifest["edges"]:
        source, target = edge[0], edge[1]
        edge_label = f' : {edge[2]}' if len(edge) > 2 else ""
        style = edge[3] if len(edge) > 3 else "solid"
        arrow = ".." if style == "dotted" else "--"
        lines.append(f"{source} {arrow}> {target}{edge_label}")
    
    lines.append("@enduml")
    return "\n".join(lines)

def main() -> int:
    project_root = Path(__file__).resolve().parents[1]
    workflow_root = project_root / "TOOLS" / "AGENT_WORKFLOW"
    manifest = workflow_root / "config" / "workflow_diagram.json"

    parser = argparse.ArgumentParser(description="Generate Pro PlantUML diagrams")
    parser.add_argument("--output-dir", type=Path, default=project_root / "DOC" / "DIAGRAMS")
    args = parser.parse_args()
    workflow_dir = args.output_dir / "TOOLS"
    workflow_dir.mkdir(parents=True, exist_ok=True)

    # 1. Workflow
    print("Génération du Workflow...")
    workflow_puml = build_workflow_puml(load_manifest(manifest))
    ok = render_puml(workflow_puml, workflow_dir / "DIAG_WF_DevelopmentWorkflow.png")

    return 0 if ok else 1

if __name__ == "__main__":
    raise SystemExit(main())
