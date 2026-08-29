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

# ── Unicité catalogue TC (REX 2026-08-29 : les TC sont uniques par construction) ──
TC_TOKEN_RE = re.compile(r"TC-P\d+-\d+")
VARIANT_RE = re.compile(r"\.\d+\s*$")


def is_variant_key(key: str) -> bool:
    """TC-Pxx-NNN.k = déclinaison déclarée d'un cas parent (famille volontaire)."""
    return bool(VARIANT_RE.search(key.strip()))


def tc_tokens(key: str) -> list[str]:
    """IDs canoniques TC-Pxx-NNN mentionnés dans une clé (variantes ramenées au parent)."""
    return TC_TOKEN_RE.findall(VARIANT_RE.sub("", str(key)))


def quality_report(matrix: dict[str, Any]) -> dict[str, Any]:
    """Contrôle qualité du catalogue : unicité canonique des TC + trous de canonisation.

    - recouvrement : un même ID TC-Pxx-NNN est déclaré par >= 2 clés non-variantes
      (ex. clé composée « TC-P01-001, TC-P01-008 » ET clé simple « TC-P01-001 ») ;
    - cross_domain : un même ID canonique apparaît dans plusieurs domaines AF ;
    - non_canonical : clés sans aucun ID TC-Pxx-NNN (intitulés libres, scénarios).
    """
    domains = matrix.get("domains", {})
    canonical_owner: dict[str, list[str]] = {}
    overlaps: list[dict[str, Any]] = []
    non_canonical: list[dict[str, str]] = []
    n_fn = n_pv = 0
    unique_tc: set[str] = set()

    for dom in sorted(domains):
        data = domains[dom] or {}
        n_fn += len(data.get("functions", {}) or {})
        vps = data.get("validation_points", {}) or {}
        n_pv += len(vps)
        non_var_tokens: dict[str, list[str]] = {}
        for vid in vps:
            toks = tc_tokens(vid)
            if not toks:
                non_canonical.append({"domain": dom, "id": vid})
                continue
            unique_tc.update(toks)  # une variante .k prouve l'existence du parent
            if is_variant_key(vid):
                continue
            for t in toks:
                non_var_tokens.setdefault(t, []).append(vid)
                if dom not in canonical_owner.setdefault(t, []):
                    canonical_owner[t].append(dom)
        for t in sorted(non_var_tokens):
            keys = non_var_tokens[t]
            if len(keys) > 1:
                overlaps.append({"domain": dom, "tc": t, "keys": keys})

    cross_domain = [
        {"tc": t, "domains": doms} for t, doms in sorted(canonical_owner.items()) if len(doms) > 1
    ]
    return {
        "stats": {
            "domains": len(domains),
            "functions": n_fn,
            "validation_points": n_pv,
            "unique_tc": len(unique_tc),
        },
        "overlaps": overlaps,
        "cross_domain": cross_domain,
        "non_canonical": non_canonical,
        "overwrites": [],
    }


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


def clean_html_cell(cell: str) -> str:
    """Nettoie le texte d'une cellule HTML (balises, entités, espaces)."""
    text = re.sub(r"<br\s*/?\s*>", " ", cell, flags=re.IGNORECASE)
    text = re.sub(r"<[^>]+>", "", text)
    text = (
        text.replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&amp;", "&")
        .replace("&nbsp;", " ")
    )
    # Uniformise les restes Markdown éventuels (backticks, gras).
    return clean_markdown_cell(text)


def parse_html_tables(lines: list[str]) -> list[list[dict[str, str]]]:
    """Parse les tableaux HTML (<table>...) d'une section en liste de dictionnaires.

    Format cible : gabarits AF (HTML figé, colgroup, th/td sur <tr> mono-ligne ou multi-ligne).
    """
    content = "\n".join(lines)
    tables: list[list[dict[str, str]]] = []
    for block_match in re.finditer(r"<table\b.*?</table>", content, flags=re.IGNORECASE | re.DOTALL):
        block = block_match.group(0)
        head_match = re.search(r"<thead\b(.*?)</thead>", block, flags=re.IGNORECASE | re.DOTALL)
        if not head_match:
            continue
        headers = [
            clean_html_cell(h.group(1))
            for h in re.finditer(r"<th\b[^>]*>(.*?)</th>", head_match.group(1), flags=re.IGNORECASE | re.DOTALL)
        ]
        if not headers:
            continue
        body = block[head_match.end():]
        rows: list[dict[str, str]] = []
        for tr_match in re.finditer(r"<tr\b[^>]*>(.*?)</tr>", body, flags=re.IGNORECASE | re.DOTALL):
            row_html = tr_match.group(1)
            cells = [
                clean_html_cell(td.group(1))
                for td in re.finditer(r"<td\b[^>]*>(.*?)</td>", row_html, flags=re.IGNORECASE | re.DOTALL)
            ]
            if not cells:
                continue
            row_dict: dict[str, str] = {}
            for i, header in enumerate(headers):
                row_dict[header] = cells[i] if i < len(cells) else ""
            rows.append(row_dict)
        if rows:
            tables.append(rows)
    return tables


def parse_tables(lines: list[str]) -> list[list[dict[str, str]]]:
    """Tableaux d'une section, HTML (gabarits AF migrés) d'abord, Markdown ensuite."""
    return parse_html_tables(lines) + parse_markdown_tables(lines)


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
            for parsed in parse_tables(section_lines):
                if any("fonction" in header.lower() for header in parsed[0]):
                    functions_rows.extend(parsed)
                    break
        elif current_section == "validation":
            for parsed in parse_tables(section_lines):
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


def merge_file_into(
    dom_data: dict[str, Any],
    file_path: Path,
    domain: str = "",
    report: dict[str, Any] | None = None,
) -> None:
    """Extrait un fichier AF et fusionne ses fonctions/points de validation dans dom_data.

    Une clé déjà présente est écrasée (comportement historique : dernier fichier gagne)
    mais signalée dans ``report["overwrites"]`` — jamais en silence.
    """
    content = file_path.read_text(encoding="utf-8")
    f_rows, v_rows = extract_sections(content)

    for row in f_rows:
        norm_f = normalize_function_item(row)
        fid = norm_f.pop("id", "")
        if fid:
            if fid in dom_data["functions"] and report is not None:
                report["overwrites"].append({"domain": domain, "kind": "fonction", "id": fid, "file": file_path.name})
            dom_data["functions"][fid] = norm_f

    for row in v_rows:
        norm_v = normalize_validation_item(row)
        vid = norm_v.pop("id", "")
        if vid:
            if vid in dom_data["validation_points"] and report is not None:
                report["overwrites"].append({"domain": domain, "kind": "pv", "id": vid, "file": file_path.name})
            dom_data["validation_points"][vid] = norm_v


def build_matrix(doc_af_dir: Path, report: dict[str, Any] | None = None) -> dict[str, Any]:
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

        merge_file_into(dom_data, main_file, f"AF-{dom}", report)
        for sf in sub_files:
            merge_file_into(dom_data, sf, f"AF-{dom}", report)

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
    parser.add_argument(
        "--strict", action="store_true",
        help="Exit 2 si recouvrement / écrasement / doublon inter-domaines (défaut : informatif)",
    )
    args = parser.parse_args()

    doc_af_dir = args.root / "DOC" / "AF"
    if not doc_af_dir.is_dir():
        print(f"Erreur : répertoire introuvable {doc_af_dir}", file=sys.stderr)
        return 1

    report: dict[str, Any] = {"overwrites": []}
    matrix = build_matrix(doc_af_dir, report)
    dump_yaml(matrix, args.output)
    print(f"Matrice des fonctions exportée avec succès : {args.output}")

    rep = quality_report(matrix)
    rep["overwrites"] = report["overwrites"]
    s = rep["stats"]
    print(
        f"  {s['domains']} domaines, {s['functions']} fonctions, "
        f"{s['validation_points']} PV, {s['unique_tc']} TC uniques"
    )
    problems = len(rep["overwrites"]) + len(rep["overlaps"]) + len(rep["cross_domain"])
    for ow in rep["overwrites"]:
        print(f"  !! écrasement {ow['domain']} {ow['kind']} {ow['id']} (réapparu dans {ow['file']})")
    if rep["overlaps"]:
        by_dom: dict[str, list[str]] = {}
        for o in rep["overlaps"]:
            by_dom.setdefault(o["domain"], []).append(o["tc"])
        for dom, tcs in sorted(by_dom.items()):
            print(f"  !! recouvrement {dom} : {', '.join(sorted(tcs))} (clé composée/range + clé simple)")
    for cd in rep["cross_domain"]:
        print(f"  !! TC non unique inter-domaines : {cd['tc']} -> {', '.join(cd['domains'])}")
    non_canon = rep["non_canonical"]
    if non_canon:
        by_dom2: dict[str, int] = {}
        for n in non_canon:
            by_dom2[n["domain"]] = by_dom2.get(n["domain"], 0) + 1
        detail = ", ".join(f"{d}({c})" for d, c in sorted(by_dom2.items()))
        print(f"  -- clés sans ID TC canonique : {len(non_canon)} ({detail}) [informatif]")

    if problems:
        if args.strict:
            print(f"  !! --strict : {problems} problème(s) d'unicité catalogue TC", file=sys.stderr)
            return 2
        print(f"  -- {problems} problème(s) d'unicité (informatif, --strict pour bloquer)")
    else:
        print("  unicité catalogue TC : OK (0 écrasement, 0 recouvrement, 0 doublon inter-domaines)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
