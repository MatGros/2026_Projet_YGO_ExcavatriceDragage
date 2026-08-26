#!/usr/bin/env python3
"""Extraction de la matrice des fonctions et des points de validation des specs AF.

Parcourt l'ensemble des fichiers AF actifs (DOC/AF/AF_Partie-NN_*.md et sous-fiches)
et extrait :
  - La section '### 🎯 Table des fonctions' (si presente)
  - La section '## 🧪 Points de validation' (présente dans chaque AF / sous-fiche)

Génère un fichier YAML consolidé par domaine AF.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    yaml = None  # type: ignore

sys.path.insert(0, str(Path(__file__).resolve().parent))
from G340_check_doc_links import VERSIONED as VERSIONED_MD  # noqa: E402
from G340_check_doc_links import AF_PARTIE as AF_MAIN_PATTERN  # noqa: E402

RE_FUNCTIONS_HEADING = re.compile(r"^#{2,4}\s+.*Table des fonctions", re.IGNORECASE)
RE_VALIDATION_HEADING = re.compile(r"^#{2,4}\s+.*Points de validation", re.IGNORECASE)
RE_ANY_HEADING = re.compile(r"^#{1,4}\s+")


def clean_markdown_cell(cell: str) -> str:
    """Nettoie le texte d'une cellule Markdown (balises HTML, backticks, liens, styles)."""
    text = cell.strip()
    # Supprimer les balises <nobr>, </nobr>, <code>, </code>, <small>, </small>, <b>, </b>, etc.
    text = re.sub(r"</?[a-zA-Z0-9]+(?:\s+[^>]*)?>", "", text)
    # Supprimer les liens markdown [text](url) -> text
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    # Supprimer les backticks `code` -> code
    text = re.sub(r"`([^`]+)`", r"\1", text)
    # Supprimer le gras **text** -> text
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    return text.strip()


def parse_markdown_table(lines: list[str]) -> list[dict[str, str]]:
    """Parse une table Markdown en liste de dictionnaires clé-valeur."""
    rows: list[list[str]] = []
    for line in lines:
        stripped = line.strip()
        if not stripped.startswith("|") or not stripped.endswith("|"):
            continue
        # Découpage des colonnes en ignorant le premier et dernier vide (autour des | extrêmes)
        # Un pipe échappé fait partie d'une formule Markdown (ex. `\|x\|`),
        # ce n'est pas un séparateur de colonne.
        cols = [col.strip() for col in re.split(r"(?<!\\)\|", stripped[1:-1])]
        # Ignorer les lignes de séparation |---|---|
        if all(re.match(r"^:?-+:?$", col) for col in cols if col):
            continue
        rows.append(cols)

    if not rows or len(rows) < 2:
        return []

    headers = [clean_markdown_cell(h) for h in rows[0]]
    result: list[dict[str, str]] = []
    for row_cols in rows[1:]:
        row_dict: dict[str, str] = {}
        for i, header in enumerate(headers):
            val = row_cols[i] if i < len(row_cols) else ""
            row_dict[header] = clean_markdown_cell(val)
        result.append(row_dict)
    return result


def parse_markdown_tables(lines: list[str]) -> list[list[dict[str, str]]]:
    """Découpe les blocs de tableaux distincts d'une même section Markdown."""
    tables: list[list[dict[str, str]]] = []
    block: list[str] = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("|") and stripped.endswith("|"):
            block.append(line)
        else:
            if block:
                parsed = parse_markdown_table(block)
                if parsed:
                    tables.append(parsed)
                block = []
    if block:
        parsed = parse_markdown_table(block)
        if parsed:
            tables.append(parsed)
    return tables


def extract_sections(content: str) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    """Extrait les tables des sections Fonctions et Points de validation d'un contenu markdown."""
    lines = content.splitlines()
    functions_rows: list[dict[str, str]] = []
    validation_rows: list[dict[str, str]] = []

    current_section: str | None = None
    current_section_level: int | None = None
    section_lines: list[str] = []

    def flush_section():
        nonlocal current_section, current_section_level, section_lines, functions_rows, validation_rows
        if current_section == "functions":
            for parsed in parse_markdown_tables(section_lines):
                if any("fonction" in header.lower() for header in parsed[0]):
                    functions_rows.extend(parsed)
                    break
        elif current_section == "validation":
            for parsed in parse_markdown_tables(section_lines):
                if any(header.lower().startswith("id") for header in parsed[0]):
                    validation_rows.extend(parsed)
                    break
        current_section = None
        current_section_level = None
        section_lines = []

    for line in lines:
        stripped = line.strip()
        if RE_FUNCTIONS_HEADING.match(stripped):
            flush_section()
            current_section = "functions"
            current_section_level = len(stripped) - len(stripped.lstrip("#"))
            continue
        elif RE_VALIDATION_HEADING.match(stripped):
            flush_section()
            current_section = "validation"
            current_section_level = len(stripped) - len(stripped.lstrip("#"))
            continue
        elif RE_ANY_HEADING.match(stripped) and current_section:
            heading_level = len(stripped) - len(stripped.lstrip("#"))
            # Les sous-titres (ex. « Types d'essai », puis « Catalogue »)
            # appartiennent encore à la section courante. Seul un titre de
            # même niveau ou supérieur la clôture.
            if current_section_level is not None and heading_level <= current_section_level:
                flush_section()
                continue

        if current_section:
            section_lines.append(line)

    flush_section()
    return functions_rows, validation_rows


def normalize_function_item(row: dict[str, str]) -> dict[str, Any]:
    """Normalise un dictionnaire extrait de la table des fonctions."""
    # Colonnes attendues : ID | Fonction | Description | Réalisée par | Criticité | TC couvrants | Statut
    item: dict[str, Any] = {}
    for k, v in row.items():
        k_lower = k.lower()
        if "id" == k_lower:
            item["id"] = v
        elif "fonction" in k_lower:
            item["fonction"] = v
        elif "description" in k_lower:
            item["description"] = v
        elif "réalisée par" in k_lower or "realisee par" in k_lower or "réalisé par" in k_lower:
            item["realisee_par"] = v
        elif "criticité" in k_lower or "criticite" in k_lower:
            item["criticite"] = v
        elif "tc" in k_lower:
            # Séparer les TC s'il y en a plusieurs (ex: TC-P08-006, TC-P08-009)
            tc_list = [tc.strip() for tc in re.split(r"[,;]+", v) if tc.strip() and tc.strip() != "—"]
            item["tc_couvrants"] = tc_list if tc_list else ([v] if v and v != "—" else [])
        elif "statut" in k_lower:
            item["statut"] = v
        elif "état" in k_lower or "etat" in k_lower:
            item["etat"] = v

    item.setdefault("id", row.get("ID", ""))
    item.setdefault("fonction", row.get("Fonction", ""))
    item.setdefault("description", row.get("Description", ""))
    item.setdefault("realisee_par", row.get("Réalisée par", row.get("Realisee par", "")))
    item.setdefault("criticite", row.get("Criticité", row.get("Criticite", "")))
    item.setdefault("tc_couvrants", [])
    item.setdefault("statut", row.get("Statut", ""))
    item.setdefault("etat", row.get("État", row.get("Etat", "")))
    return item


def normalize_validation_item(row: dict[str, str]) -> dict[str, Any]:
    """Normalise un dictionnaire extrait des points de validation."""
    # Colonnes attendues : ID | Intention | Preuve | Type | Réf
    item: dict[str, Any] = {}
    for k, v in row.items():
        k_lower = k.lower()
        if "id" in k_lower:
            item["id"] = v
        elif "intention" in k_lower or "comportement" in k_lower:
            item["intention"] = v
        elif "preuve" in k_lower:
            item["preuve"] = v
        elif "type" in k_lower:
            item["type"] = v
        elif "réf" in k_lower or "ref" in k_lower:
            item["ref"] = v
        elif "état" in k_lower or "etat" in k_lower:
            item["etat"] = v

    item.setdefault("id", row.get("ID", ""))
    item.setdefault("intention", row.get("Intention", row.get("Intention / Comportement attendu", "")))
    item.setdefault("type", row.get("Type", ""))
    item.setdefault("etat", row.get("État", row.get("Etat", "")))
    return item


def get_active_af_files(doc_af_dir: Path) -> dict[str, dict[str, Any]]:
    """Sélectionne les fichiers AF actifs (version la plus élevée par domaine et sous-fiches associées)."""
    domains: dict[str, list[tuple[tuple[int, int], Path]]] = {}
    for p in doc_af_dir.glob("AF_Partie-*_v*.md"):
        m = VERSIONED_MD.match(p.name)
        if not m:
            continue
        m_dom = AF_MAIN_PATTERN.match(p.name)
        if not m_dom:
            continue
        dom = m_dom.group("num")
        ver = (int(m.group("major")), int(m.group("minor")))
        domains.setdefault(dom, []).append((ver, p))

    active_af: dict[str, dict[str, Any]] = {}
    for dom, list_paths in sorted(domains.items()):
        list_paths.sort(key=lambda x: x[0], reverse=True)
        main_file = list_paths[0][1]
        
        # Trouver les sous-fiches éventuelles dans un sous-dossier ou préfixées
        sub_files: list[Path] = []
        matching_dirs = sorted(
            d for d in doc_af_dir.iterdir() if d.is_dir() and d.name.startswith(f"AF_Partie-{dom}_")
        )
        for matching_dir in matching_dirs:
            for sf in sorted(matching_dir.glob("*.md")):
                if sf.is_file():
                    sub_files.append(sf)

        # Chercher également les sous-fiches au même niveau ex: AF_Partie-10_FB_*.md
        for sf in sorted(doc_af_dir.glob(f"AF_Partie-{dom}_FB_*.md")):
            if sf.is_file() and sf != main_file and sf not in sub_files:
                sub_files.append(sf)

        active_af[dom] = {
            "main": main_file,
            "sub_files": sub_files,
        }

    return active_af


def merge_file_into(dom_data: dict[str, Any], file_path: Path) -> None:
    """Extrait un fichier AF et fusionne ses fonctions/points de validation dans dom_data."""
    content = file_path.read_text(encoding="utf-8")
    f_rows, v_rows = extract_sections(content)

    for row in f_rows:
        norm_f = normalize_function_item(row)
        fid = norm_f.pop("id", "")
        if fid:
            dom_data["functions"][fid] = norm_f

    for row in v_rows:
        norm_v = normalize_validation_item(row)
        vid = norm_v.pop("id", "")
        if vid:
            dom_data["validation_points"][vid] = norm_v


def build_matrix(doc_af_dir: Path) -> dict[str, Any]:
    """Construit la matrice des fonctions et des points de validation."""
    active_af = get_active_af_files(doc_af_dir)
    matrix: dict[str, Any] = {"domains": {}}

    for dom, files_info in sorted(active_af.items()):
        main_file: Path = files_info["main"]
        sub_files: list[Path] = files_info["sub_files"]

        dom_data: dict[str, Any] = {
            "file": main_file.name,
            "functions": {},
            "validation_points": {},
        }

        merge_file_into(dom_data, main_file)
        for sf in sub_files:
            merge_file_into(dom_data, sf)

        matrix["domains"][f"AF-{dom}"] = dom_data

    return matrix


def dump_yaml(data: dict[str, Any], out_path: Path) -> None:
    """Écrit les données YAML."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if yaml is not None:
        with open(out_path, "w", encoding="utf-8") as f:
            yaml.dump(data, f, allow_unicode=True, sort_keys=False, default_flow_style=False)
    else:
        import json
        out_path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    default_root = Path(__file__).resolve().parents[3]
    default_out = Path(__file__).resolve().parents[1] / "config" / "af_traceability_matrix.yaml"

    parser.add_argument("--root", type=Path, default=default_root, help="Racine du dépôt")
    parser.add_argument("--output", "-o", type=Path, default=default_out, help="Fichier de sortie YAML")
    args = parser.parse_args()

    doc_af_dir = args.root / "DOC" / "AF"
    if not doc_af_dir.is_dir():
        print(f"Erreur : répertoire introuvable {doc_af_dir}", file=sys.stderr)
        return 1

    matrix = build_matrix(doc_af_dir)
    dump_yaml(matrix, args.output)
    print(f"Matrice des fonctions exportée avec succès : {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
