#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
===============================================================================
🧭 GENERATE_GRAFCET_FROM_ST — Générateur Déterministe de GRAFCET / SFC
===============================================================================
Projet : Excavatrice de Dragage en Carrière Noyée
Rôle   : Parseur 100% statique et déterministe (SANS LLM) de code Structured Text (ST).
         Extrait automatiquement :
           - Les étapes du CASE <StateVar> OF
           - Les transitions réelles (State := TargetStep)
           - Les réceptivités / conditions exactes (IF / ELSIF / ELSE)
           - Les numéros de ligne dans le code source ST réel
         Génère :
           1. Diagrammes Mermaid (.md) pour VS Code / GitHub
           2. Visualiseur Web interactif moderne (.html)
           3. Données structurées JSON (.json)
===============================================================================
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[1]

DEFAULT_CYCLES = [
    {
        "id": "homing",
        "name": "Cycle Homing Machine",
        "fb": "FB_CycleMachineHoming",
        "file": REPO_ROOT / "CODE" / "G_CYCLE" / "FB_CycleMachineHoming.st",
        "md_out": REPO_ROOT / "DOC" / "WFLOW" / "DIAGRAMS" / "GRAFCET_HOMING.md",
    },
    {
        "id": "semiauto",
        "name": "Cycle Semi-Automatique de Dragage",
        "fb": "FB_CycleSemiAuto",
        "file": REPO_ROOT / "CODE" / "G_CYCLE" / "FB_CycleSemiAuto.st",
        "md_out": REPO_ROOT / "DOC" / "WFLOW" / "DIAGRAMS" / "GRAFCET_SEMIAUTO.md",
    },
]


def clean_mermaid_label(text: str, max_len: int = 55) -> str:
    """Nettoie et formate une condition pour qu'elle soit valide dans un label Mermaid."""
    s = text.strip()
    s = s.replace('"', "'").replace('|', '||').replace('<', '&lt;').replace('>', '&gt;')
    s = re.sub(r'\s+', ' ', s)
    if len(s) > max_len:
        # Découpage intelligent sur AND ou OR
        for op in [' AND ', ' OR ']:
            if op in s:
                parts = s.split(op)
                s = f"<br/>{op.strip()} ".join(parts)
                break
    return s


def parse_st_cycle(file_path: Path) -> Dict[str, Any]:
    """Parse un fichier ST et extrait l'automate à états (CASE <var> OF)."""
    if not file_path.is_file():
        raise FileNotFoundError(f"Fichier ST introuvable : {file_path}")

    with open(file_path, "r", encoding="utf-8", errors="replace") as f:
        text = f.read()
        lines = text.splitlines()

    # Détection de tous les blocs CASE
    case_matches = list(re.finditer(r'^\s*CASE\s+([A-Za-z0-9_\.]+)\s+OF', text, re.IGNORECASE | re.MULTILINE))
    if not case_matches:
        raise ValueError(f"Aucun bloc CASE trouvé dans {file_path}")

    # Sélection du CASE principal (celui qui possède le plus grand nombre de branches enum)
    best_case = None
    best_steps_count = -1
    best_enum = ""

    for m in case_matches:
        var_name = m.group(1)
        start_pos = m.end()
        end_case_match = re.search(r'\bEND_CASE\b', text[start_pos:], re.IGNORECASE)
        if not end_case_match:
            continue
        case_content = text[start_pos:start_pos + end_case_match.start()]
        
        # Détection des labels d'étapes (avec ou sans nom d'enum)
        enum_step_matches = list(re.finditer(r'^\s*([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\s*:(?!=)', case_content, re.MULTILINE))
        if len(enum_step_matches) > best_steps_count:
            best_steps_count = len(enum_step_matches)
            best_enum = enum_step_matches[0].group(1) if enum_step_matches else ""
            # Calcul du numéro de ligne de début et fin
            line_start = text[:m.start()].count('\n') + 1
            line_end = text[:start_pos + end_case_match.start()].count('\n') + 1
            best_case = {
                "var_name": var_name,
                "enum_name": best_enum,
                "line_start": line_start,
                "line_end": line_end,
                "content": case_content,
            }

    if not best_case:
        raise ValueError(f"Impossible d'isoler la machine d'état principale dans {file_path}")

    var_name = best_case["var_name"]
    enum_name = best_case["enum_name"]
    case_lines = best_case["content"].splitlines()
    base_line = best_case["line_start"]

    steps: List[Dict[str, Any]] = []
    step_indices: Dict[str, int] = {}
    current_step: Optional[Dict[str, Any]] = None
    if_stack: List[Tuple[str, str, int]] = []
    comment_buffer: List[str] = []

    for idx, raw_line in enumerate(case_lines):
        actual_line_no = base_line + idx + 1
        line = raw_line.strip()

        # Collecte des commentaires contextuels
        if line.startswith("//"):
            clean_comm = line.lstrip("/ ").strip()
            if clean_comm:
                comment_buffer.append(clean_comm)
            continue

        # Détection d'un label d'étape (ex: E_AutoCycleStep.AX0_REPOS: ou HX0_REPOS:)
        step_pattern = r'^\s*(?:' + re.escape(enum_name) + r'\.)?([A-Za-z0-9_]+)\s*:(?!=)'
        m_step = re.match(step_pattern, raw_line)
        if m_step:
            step_name = m_step.group(1)
            desc = " ".join(comment_buffer[-3:]) if comment_buffer else ""
            comment_buffer = []
            if_stack = []

            current_step = {
                "name": step_name,
                "line": actual_line_no,
                "description": desc,
                "actions": [],
                "transitions": [],
            }
            step_indices[step_name] = len(steps)
            steps.append(current_step)
            continue

        if not current_step:
            continue

        # Gestion des structures de conditions
        m_if = re.search(r'\bIF\s+(.*?)\s+THEN\b', line, re.IGNORECASE)
        if m_if:
            cond_text = m_if.group(1).strip()
            if_stack.append(('IF', cond_text, actual_line_no))

        m_elsif = re.search(r'\bELSIF\s+(.*?)\s+THEN\b', line, re.IGNORECASE)
        if m_elsif:
            cond_text = m_elsif.group(1).strip()
            if if_stack:
                if_stack[-1] = ('ELSIF', cond_text, actual_line_no)
            else:
                if_stack.append(('ELSIF', cond_text, actual_line_no))

        m_else = re.search(r'\bELSE\b', line, re.IGNORECASE)
        if m_else and not re.search(r'\bELSIF\b', line, re.IGNORECASE):
            if if_stack:
                if_stack[-1] = ('ELSE', 'ELSE', actual_line_no)

        if re.search(r'\bEND_IF\b', line, re.IGNORECASE):
            if if_stack:
                if_stack.pop()

        # Détection des transitions : <var_name> := [enum.]<target_step>;
        assign_pat = re.escape(var_name) + r'\s*:=\s*(?:' + re.escape(enum_name) + r'\.)?([A-Za-z0-9_]+)\s*;'
        m_assign = re.search(assign_pat, line)
        if m_assign:
            target_step = m_assign.group(1)
            # Reconstitution de la condition complète
            if if_stack:
                cond_full = " AND ".join(f"({c[1]})" for c in if_stack)
            else:
                cond_full = "TRUE (inconditionnel)"

            t_info = {
                "from": current_step["name"],
                "to": target_step,
                "condition": cond_full,
                "condition_short": clean_mermaid_label(cond_full),
                "line": actual_line_no,
            }
            current_step["transitions"].append(t_info)
            continue

        # Détection des affectations notables / actions
        if ":=" in line and not line.startswith("//"):
            act_clean = re.sub(r'//.*$', '', line).strip()
            if len(act_clean) > 2 and not act_clean.startswith(var_name):
                if len(current_step["actions"]) < 6:
                    current_step["actions"].append(act_clean)

    return {
        "file_name": file_path.name,
        "file_path": str(file_path),
        "state_variable": var_name,
        "enum_name": enum_name,
        "line_start": best_case["line_start"],
        "line_end": best_case["line_end"],
        "total_steps": len(steps),
        "total_transitions": sum(len(s["transitions"]) for s in steps),
        "steps": steps,
    }


def generate_mermaid_markdown(cycle_data: Dict[str, Any], title: str) -> str:
    """Produit un document Markdown avec diagramme Mermaid CEI 60848."""
    steps = cycle_data["steps"]
    var_name = cycle_data["state_variable"]
    enum_name = cycle_data["enum_name"]
    file_name = cycle_data["file_name"]

    md: List[str] = [
        f"# 🧭 GRAFCET Séquenceur — {title}",
        "",
        f"> **Source réelle** : `{file_name}`  ",
        f"> **Variable d'état** : `{var_name}` (`{enum_name}`)  ",
        f"> **Métriques** : **{len(steps)}** étapes · **{cycle_data['total_transitions']}** transitions réelles extraites mécaniquement.  ",
        "",
        "```mermaid",
        "%%{init: {",
        "  'theme': 'base',",
        "  'themeVariables': {",
        "    'primaryColor': '#1e293b',",
        "    'primaryTextColor': '#ffffff',",
        "    'primaryBorderColor': '#00e5ff',",
        "    'lineColor': '#00e5ff',",
        "    'secondaryColor': '#0f172a',",
        "    'tertiaryColor': '#1e293b',",
        "    'edgeLabelBackground': '#0b1329',",
        "    'textColor': '#ffffff',",
        "    'fontSize': '12px'",
        "  }",
        "}}%%",
        "flowchart TD",
        "    %% Style CEI 60848 standard haut contraste",
        "    classDef stepClass fill:#1e293b,stroke:#00e5ff,stroke-width:2.5px,color:#ffffff,font-family:monospace;",
        "    classDef initialStep fill:#0f172a,stroke:#38bdf8,stroke-width:4px,color:#38bdf8,font-family:monospace;",
        "    classDef failStep fill:#450a0a,stroke:#ef4444,stroke-width:2.5px,color:#fca5a5,font-family:monospace;",
        "    classDef completeStep fill:#064e3b,stroke:#10b981,stroke-width:2.5px,color:#6ee7b7,font-family:monospace;",
        "",
    ]

    # Déclaration des nœuds
    for idx, s in enumerate(steps):
        s_name = s["name"]
        s_line = s["line"]
        label = f"<b>{s_name}</b><br/>(L{s_line})"
        
        # Étape initiale ou spéciale
        if idx == 0 or s_name.endswith("_REPOS") or s_name.endswith("_READY") or s_name in ("HX0_REPOS", "AX0_REPOS"):
            md.append(f'    {s_name}[["{label}"]]:::initialStep')
        elif "FAIL" in s_name or "ERR" in s_name:
            md.append(f'    {s_name}["{label}"]:::failStep')
        elif "HOMED" in s_name or "COMPLETE" in s_name:
            md.append(f'    {s_name}["{label}"]:::completeStep')
        else:
            md.append(f'    {s_name}["{label}"]:::stepClass')

    md.append("")
    md.append("    %% Transitions réelles extraites du code")

    # Déclaration des arêtes avec réceptivités
    transition_count = 0
    for s in steps:
        s_from = s["name"]
        for t in s["transitions"]:
            transition_count += 1
            s_to = t["to"]
            cond_short = t["condition_short"]
            t_line = t["line"]
            edge_label = f"L{t_line}: {cond_short}"
            md.append(f'    {s_from} -->|"{edge_label}"| {s_to}')

    md.append("    linkStyle default stroke:#00e5ff,stroke-width:2.5px,color:#ffffff,fill:none;")
    md.append("```")
    md.append("")
    md.append("---")
    md.append("")
    md.append("## 📋 Tableau Récapitulatif des Étapes & Transitions Réelles")
    md.append("")
    md.append("| # | Étape Source | Ligne ST | Cible | Ligne Transition | Réceptivité / Condition Réelle |")
    md.append("|---|---|---|---|---|---|")

    step_num = 0
    for s in steps:
        step_num += 1
        s_name = s["name"]
        s_line = s["line"]
        if not s["transitions"]:
            md.append(f"| {step_num} | `{s_name}` | L{s_line} | *(Étape terminale)* | — | *(Aucune transition sortante)* |")
        else:
            for t in s["transitions"]:
                c_clean = t["condition"].replace("|", "\\|")
                md.append(f"| {step_num} | `{s_name}` | L{s_line} | `{t['to']}` | L{t['line']} | `{c_clean}` |")

    return "\n".join(md)


def generate_interactive_html(cycles_data: List[Dict[str, Any]], out_path: Path) -> None:
    """Génère un cockpit web interactif moderne regroupant tous les cycles."""
    json_data = json.dumps(cycles_data, ensure_ascii=False)

    html_content = f"""<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Cockpit GRAFCET Automatique — Séquenceurs Industriels</title>
  <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
  <style>
    :root {{
      --bg-dark: #070a13;
      --bg-card: rgba(18, 24, 38, 0.85);
      --bg-card-hover: rgba(28, 40, 68, 0.95);
      --border-subtle: rgba(255, 255, 255, 0.08);
      --primary: #00e5ff;
      --primary-glow: rgba(0, 229, 255, 0.35);
      --accent: #f59e0b;
      --success: #10b981;
      --danger: #ef4444;
      --text-main: #f1f5f9;
      --text-muted: #94a3b8;
      --font-mono: 'Consolas', 'Monaco', 'Courier New', monospace;
      --font-ui: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
    }}

    * {{ box-sizing: border-box; margin: 0; padding: 0; }}

    body {{
      background: var(--bg-dark);
      background-image: 
        radial-gradient(circle at 10% 10%, rgba(0, 229, 255, 0.05) 0%, transparent 40%),
        radial-gradient(circle at 90% 90%, rgba(16, 185, 129, 0.05) 0%, transparent 40%),
        linear-gradient(to bottom, #070a13, #0b1120);
      color: var(--text-main);
      font-family: var(--font-ui);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }}

    header {{
      background: rgba(11, 17, 32, 0.95);
      backdrop-filter: blur(12px);
      border-bottom: 1px solid var(--border-subtle);
      position: sticky;
      top: 0;
      z-index: 100;
      padding: 12px 24px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4);
    }}

    .brand {{
      display: flex;
      align-items: center;
      gap: 12px;
    }}

    .brand-icon {{
      font-size: 26px;
    }}

    .brand-title h1 {{
      font-size: 18px;
      font-weight: 700;
      letter-spacing: 0.5px;
      color: #fff;
    }}

    .brand-title p {{
      font-size: 11px;
      color: var(--primary);
      text-transform: uppercase;
      letter-spacing: 1px;
    }}

    .cycle-tabs {{
      display: flex;
      gap: 8px;
      background: rgba(0, 0, 0, 0.3);
      padding: 4px;
      border-radius: 8px;
      border: 1px solid var(--border-subtle);
    }}

    .cycle-tab {{
      background: transparent;
      border: none;
      color: var(--text-muted);
      padding: 8px 16px;
      border-radius: 6px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s ease;
      display: flex;
      align-items: center;
      gap: 8px;
    }}

    .cycle-tab.active {{
      background: var(--primary);
      color: #000;
      box-shadow: 0 0 12px var(--primary-glow);
    }}

    main {{
      flex: 1;
      padding: 20px 24px;
      display: grid;
      grid-template-columns: 1fr 420px;
      gap: 20px;
    }}

    .graph-panel {{
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      border-radius: 12px;
      padding: 20px;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      position: relative;
    }}

    .panel-header {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;
      padding-bottom: 12px;
      border-bottom: 1px solid var(--border-subtle);
    }}

    .panel-title {{
      font-size: 16px;
      font-weight: 700;
      color: var(--primary);
      display: flex;
      align-items: center;
      gap: 8px;
    }}

    .meta-badge {{
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid var(--border-subtle);
      padding: 4px 10px;
      border-radius: 6px;
      font-size: 12px;
      font-family: var(--font-mono);
      color: var(--text-muted);
    }}

    .mermaid-container {{
      flex: 1;
      overflow: auto;
      background: #0a0f1d;
      border-radius: 8px;
      padding: 20px;
      display: flex;
      justify-content: center;
      align-items: flex-start;
      min-height: 500px;
    }}

    /* SURCHARGES HAUT CONTRASTE — Thème sombre ultra-lisible */
    .mermaid-container svg {{
      max-width: 100%;
      height: auto;
    }}

    /* Liens et flèches en Cyan électrique éclatant (#00e5ff) */
    .mermaid-container .edgePath path,
    .mermaid-container path.flowchart-link,
    .mermaid-container .edge-thickness-normal,
    .mermaid-container path.path {{
      stroke: #00e5ff !important;
      stroke-width: 2.5px !important;
      stroke-opacity: 1 !important;
      filter: drop-shadow(0 0 2px rgba(0, 229, 255, 0.5));
    }}

    /* Pointes de flèches */
    .mermaid-container marker path,
    .mermaid-container .arrowheadPath,
    .mermaid-container #flowchart-pointEnd path,
    .mermaid-container [id*="pointEnd"] path {{
      fill: #00e5ff !important;
      stroke: #00e5ff !important;
      stroke-width: 1.5px !important;
    }}

    /* Boîtes de texte des réceptivités / transitions */
    .mermaid-container .edgeLabel {{
      background-color: #080e1e !important;
      fill: #080e1e !important;
      color: #ffffff !important;
    }}

    .mermaid-container .edgeLabel rect,
    .mermaid-container .labelBox {{
      fill: #080e1e !important;
      stroke: #00e5ff !important;
      stroke-width: 1.2px !important;
      rx: 4px;
      ry: 4px;
    }}

    .mermaid-container .edgeLabel span,
    .mermaid-container .edgeLabel p,
    .mermaid-container .edgeLabel div,
    .mermaid-container .edgeLabel foreignObject {{
      color: #ffffff !important;
      background-color: #080e1e !important;
      font-weight: 700 !important;
      font-size: 11.5px !important;
      line-height: 1.35 !important;
      padding: 3px 6px !important;
      border-radius: 4px !important;
      border: 1px solid rgba(0, 229, 255, 0.6) !important;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.9) !important;
    }}

    /* Nœuds d'étapes */
    .mermaid-container .node rect,
    .mermaid-container .node polygon {{
      stroke-width: 2.5px !important;
      filter: drop-shadow(0 4px 10px rgba(0, 0, 0, 0.7));
    }}

    .mermaid-container .node .label {{
      color: #ffffff !important;
      font-family: var(--font-mono) !important;
      font-weight: 700 !important;
    }}

    .side-panel {{
      display: flex;
      flex-direction: column;
      gap: 16px;
    }}

    .card {{
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      border-radius: 12px;
      padding: 16px;
    }}

    .search-box {{
      width: 100%;
      background: rgba(0, 0, 0, 0.4);
      border: 1px solid var(--border-subtle);
      border-radius: 6px;
      padding: 8px 12px;
      color: #fff;
      font-size: 13px;
      margin-bottom: 12px;
    }}

    .search-box:focus {{
      outline: none;
      border-color: var(--primary);
    }}

    .step-list {{
      max-height: 480px;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }}

    .step-item {{
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid var(--border-subtle);
      border-radius: 8px;
      padding: 10px 12px;
      cursor: pointer;
      transition: all 0.2s;
    }}

    .step-item:hover, .step-item.active {{
      border-color: var(--primary);
      background: var(--bg-card-hover);
    }}

    .step-head {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 4px;
    }}

    .step-name {{
      font-family: var(--font-mono);
      font-size: 13px;
      font-weight: 700;
      color: #fff;
    }}

    .step-line {{
      font-family: var(--font-mono);
      font-size: 11px;
      color: var(--primary);
    }}

    .step-desc {{
      font-size: 12px;
      color: var(--text-muted);
      line-height: 1.3;
    }}

    .trans-pill {{
      display: inline-block;
      margin-top: 6px;
      padding: 2px 6px;
      background: rgba(0, 229, 255, 0.1);
      border: 1px solid rgba(0, 229, 255, 0.2);
      border-radius: 4px;
      font-size: 11px;
      font-family: var(--font-mono);
      color: var(--primary);
    }}

    .detail-card {{
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      border-radius: 12px;
      padding: 16px;
    }}

    .detail-title {{
      font-size: 14px;
      font-weight: 700;
      margin-bottom: 8px;
      color: #fff;
    }}

    .code-box {{
      background: #050811;
      border: 1px solid var(--border-subtle);
      border-radius: 6px;
      padding: 10px;
      font-family: var(--font-mono);
      font-size: 12px;
      color: #38bdf8;
      overflow-x: auto;
      max-height: 200px;
    }}

    footer {{
      padding: 12px 24px;
      text-align: center;
      font-size: 11px;
      color: var(--text-muted);
      border-top: 1px solid var(--border-subtle);
    }}
  </style>
</head>
<body>
  <header>
    <div class="brand">
      <span class="brand-icon">🧭</span>
      <div class="brand-title">
        <h1>GRAFCET INDUSTRIEL — PARSEUR ST AUTOMATIQUE</h1>
        <p>100% Mécanique & Déterministe · Sans LLM · CEI 60848</p>
      </div>
    </div>
    <div class="cycle-tabs" id="cycleTabs"></div>
  </header>

  <main>
    <section class="graph-panel">
      <div class="panel-header">
        <div class="panel-title" id="panelTitle">Graphe Fonctionnel de Commande</div>
        <div class="meta-badge" id="metaBadge">Source: ST</div>
      </div>
      <div class="mermaid-container" id="mermaidContainer">
        <div class="mermaid" id="mermaidGraph"></div>
      </div>
    </section>

    <aside class="side-panel">
      <div class="card">
        <input type="text" class="search-box" id="searchBox" placeholder="🔍 Filtrer étape ou condition...">
        <div class="step-list" id="stepList"></div>
      </div>

      <div class="detail-card" id="detailCard">
        <div class="detail-title">Détails de l'étape sélectionnée</div>
        <div id="detailContent" style="font-size: 13px; color: var(--text-muted);">
          Sélectionnez une étape dans la liste ou le diagramme pour voir ses actions et conditions exactes.
        </div>
      </div>
    </aside>
  </main>

  <footer>
    Généré automatiquement par <code>TOOLS/GRAFCET_GENERATOR/generate_grafcet_from_st.py</code> à partir du code Structured Text réel.
  </footer>

  <script>
    const CYCLES = {json_data};
    let currentCycleIdx = 0;
    let selectedStep = null;

    mermaid.initialize({{
      startOnLoad: false,
      theme: 'base',
      themeVariables: {{
        darkMode: true,
        background: '#0a0f1d',
        primaryColor: '#1e293b',
        primaryTextColor: '#ffffff',
        primaryBorderColor: '#00e5ff',
        lineColor: '#00e5ff',
        secondaryColor: '#0f172a',
        tertiaryColor: '#1e293b',
        edgeLabelBackground: '#080e1e',
        textColor: '#ffffff',
        fontSize: '12px'
      }},
      flowchart: {{
        curve: 'basis',
        nodeSpacing: 45,
        rankSpacing: 45,
        useMaxWidth: false
      }}
    }});

    function init() {{
      const tabsContainer = document.getElementById('cycleTabs');
      tabsContainer.innerHTML = '';
      CYCLES.forEach((c, idx) => {{
        const btn = document.createElement('button');
        btn.className = `cycle-tab ${{idx === currentCycleIdx ? 'active' : ''}}`;
        btn.innerHTML = `${{c.id === 'homing' ? '🧭' : '✨'}} ${{c.name}}`;
        btn.onclick = () => switchCycle(idx);
        tabsContainer.appendChild(btn);
      }});

      renderCurrentCycle();

      document.getElementById('searchBox').addEventListener('input', (e) => {{
        filterSteps(e.target.value.toLowerCase());
      }});
    }}

    function switchCycle(idx) {{
      currentCycleIdx = idx;
      selectedStep = null;
      document.querySelectorAll('.cycle-tab').forEach((t, i) => {{
        t.classList.toggle('active', i === idx);
      }});
      renderCurrentCycle();
    }}

    async function renderCurrentCycle() {{
      const cycle = CYCLES[currentCycleIdx];
      document.getElementById('panelTitle').innerHTML = `${{cycle.name}} (<code>${{cycle.state_variable}}</code>)`;
      document.getElementById('metaBadge').innerText = `${{cycle.file_name}} · L${{cycle.line_start}}..L${{cycle.line_end}} · ${{cycle.total_steps}} étapes`;

      renderStepList(cycle.steps);
      await renderMermaid(cycle);
    }}

    function renderStepList(steps) {{
      const listEl = document.getElementById('stepList');
      listEl.innerHTML = '';
      steps.forEach((s) => {{
        const item = document.createElement('div');
        item.className = 'step-item';
        item.id = `step-item-${{s.name}}`;
        item.onclick = () => showStepDetail(s);

        const transCount = s.transitions ? s.transitions.length : 0;
        item.innerHTML = `
          <div class="step-head">
            <span class="step-name">${{s.name}}</span>
            <span class="step-line">L${{s.line}}</span>
          </div>
          <div class="step-desc">${{s.description || 'Étape fonctionnelle'}}</div>
          <div class="trans-pill">${{transCount}} transition(s) sortante(s)</div>
        `;
        listEl.appendChild(item);
      }});
    }}

    function filterSteps(query) {{
      const cycle = CYCLES[currentCycleIdx];
      const filtered = cycle.steps.filter(s => {{
        const inName = s.name.toLowerCase().includes(query);
        const inDesc = (s.description || '').toLowerCase().includes(query);
        const inTrans = s.transitions.some(t => t.to.toLowerCase().includes(query) || t.condition.toLowerCase().includes(query));
        return inName || inDesc || inTrans;
      }});
      renderStepList(filtered);
    }}

    function showStepDetail(s) {{
      selectedStep = s;
      document.querySelectorAll('.step-item').forEach(el => el.classList.remove('active'));
      const activeEl = document.getElementById(`step-item-${{s.name}}`);
      if (activeEl) activeEl.classList.add('active');

      const detailEl = document.getElementById('detailContent');
      let transHtml = '';
      if (s.transitions && s.transitions.length > 0) {{
        transHtml = '<ul style="margin-left: 16px; margin-top: 6px; display: flex; flex-direction: column; gap: 6px;">';
        s.transitions.forEach(t => {{
          transHtml += `<li><b>➔ ${{t.to}}</b> (L${{t.line}}) :<br/><span style="color:#00e5ff; font-family:monospace; font-size:11px;">${{t.condition}}</span></li>`;
        }});
        transHtml += '</ul>';
      }} else {{
        transHtml = '<em>Étape terminale ou attente d\\'événement externe.</em>';
      }}

      let actHtml = '';
      if (s.actions && s.actions.length > 0) {{
        actHtml = `<div class="code-box" style="margin-top: 8px;">${{s.actions.join('<br/>')}}</div>`;
      }}

      detailEl.innerHTML = `
        <div style="margin-bottom: 8px;">
          <strong style="color:#fff; font-size:15px; font-family:monospace;">${{s.name}}</strong>
          <span style="color:var(--primary); font-family:monospace; margin-left:8px;">Ligne ST : L${{s.line}}</span>
        </div>
        <p style="margin-bottom: 8px; color:#cbd5e1;">${{s.description || 'Aucun commentaire préfixé dans le code ST.'}}</p>
        <div style="font-weight:600; color:#fff; margin-top:10px;">Transitions sortantes :</div>
        ${{transHtml}}
        ${{s.actions && s.actions.length > 0 ? '<div style="font-weight:600; color:#fff; margin-top:10px;">Actions notables :</div>' + actHtml : ''}}
      `;
    }}

    async function renderMermaid(cycle) {{
      const container = document.getElementById('mermaidContainer');
      container.innerHTML = '<div class="mermaid" id="mermaidGraph"></div>';
      const graphEl = document.getElementById('mermaidGraph');

      let mLines = [
        'flowchart TD',
        '    classDef stepClass fill:#1e293b,stroke:#00e5ff,stroke-width:2.5px,color:#ffffff;',
        '    classDef initialStep fill:#0f172a,stroke:#38bdf8,stroke-width:4px,color:#38bdf8;',
        '    classDef failStep fill:#450a0a,stroke:#ef4444,stroke-width:2.5px,color:#fca5a5;',
        '    classDef completeStep fill:#064e3b,stroke:#10b981,stroke-width:2.5px,color:#6ee7b7;'
      ];

      cycle.steps.forEach((s, idx) => {{
        const label = `<b>${{s.name}}</b><br/>L${{s.line}}`;
        if (idx === 0 || s.name.endsWith('_REPOS') || s.name.endsWith('_READY') || s.name === 'HX0_REPOS' || s.name === 'AX0_REPOS') {{
          mLines.push(`    ${{s.name}}[["${{label}}"]]:::initialStep`);
        }} else if (s.name.includes('FAIL') || s.name.includes('ERR')) {{
          mLines.push(`    ${{s.name}}["${{label}}"]:::failStep`);
        }} else if (s.name.includes('HOMED') || s.name.includes('COMPLETE')) {{
          mLines.push(`    ${{s.name}}["${{label}}"]:::completeStep`);
        }} else {{
          mLines.push(`    ${{s.name}}["${{label}}"]:::stepClass`);
        }}
      }});

      cycle.steps.forEach(s => {{
        s.transitions.forEach(t => {{
          const shortCond = t.condition_short.replace(/"/g, "'");
          mLines.push(`    ${{s.name}} -->|"L${{t.line}}: ${{shortCond}}"| ${{t.to}}`);
        }});
      }});

      mLines.push('    linkStyle default stroke:#00e5ff,stroke-width:2.5px,color:#ffffff,fill:none;');

      const graphDefinition = mLines.join('\\n');
      try {{
        const {{ svg }} = await mermaid.render('mermaid-svg-render', graphDefinition);
        container.innerHTML = svg;
      }} catch (err) {{
        console.error('Erreur rendu Mermaid:', err);
        container.innerHTML = `<pre style="color:var(--danger); font-family:monospace;">Erreur rendu diagramme : ${{err.message}}</pre>`;
      }}
    }}

    window.addEventListener('DOMContentLoaded', init);
  </script>
</body>
</html>
"""

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html_content)


def main():
    parser = argparse.ArgumentParser(description="Générateur déterministe de GRAFCET à partir du code ST réel.")
    parser.add_argument("--all", action="store_true", default=True, help="Traiter tous les cycles principaux du projet")
    parser.add_argument("--input", type=str, help="Fichier ST individuel à parser")
    parser.add_argument("--out-html", type=str, help="Fichier HTML de sortie")
    parser.add_argument("--out-md", type=str, help="Fichier Markdown de sortie")
    args = parser.parse_args()

    cycles_to_process = []

    if args.input:
        in_p = Path(args.input)
        c_id = in_p.stem.lower()
        cycles_to_process.append({
            "id": c_id,
            "name": in_p.stem,
            "fb": in_p.stem,
            "file": in_p,
            "md_out": Path(args.out_md) if args.out_md else REPO_ROOT / "DOC" / "WFLOW" / "DIAGRAMS" / f"{in_p.stem}.md",
        })
    else:
        cycles_to_process = DEFAULT_CYCLES

    results = []
    print("=" * 70)
    print("🧭 PARSEUR ST DE GRAFCET & SÉQUENCEURS INDUSTRIELS (SANS LLM)")
    print("=" * 70)

    for c in cycles_to_process:
        print(f"\n📂 Traitement : {c['name']} ({c['file'].name})")
        parsed = parse_st_cycle(c["file"])
        parsed["id"] = c["id"]
        parsed["name"] = c["name"]
        results.append(parsed)

        print(f"  ✓ Variable d'état : {parsed['state_variable']} ({parsed['enum_name']})")
        print(f"  ✓ Étapes détectées : {parsed['total_steps']}")
        print(f"  ✓ Transitions réelles extraites : {parsed['total_transitions']}")

        # Génération du Markdown Mermaid
        md_content = generate_mermaid_markdown(parsed, c["name"])
        md_path = c["md_out"]
        md_path.parent.mkdir(parents=True, exist_ok=True)
        with open(md_path, "w", encoding="utf-8") as f:
            f.write(md_content)
        print(f"  📄 Diagramme Mermaid exporté : {md_path}")

    # Génération du visualiseur HTML
    html_out = Path(args.out_html) if args.out_html else SCRIPT_DIR / "GRAFCET_VIEWER.html"
    generate_interactive_html(results, html_out)
    print(f"\n============================================================")
    print(f"✅ VISUALISEUR WEB INTERACTIF GÉNÉRÉ AVEC SUCCÈS")
    print(f"============================================================")
    print(f"🖥️ Fichier HTML : {html_out}")
    print(f"👉 Accessible directement via double-clic ou navigateur local !")
    print(f"============================================================")


if __name__ == "__main__":
    main()
