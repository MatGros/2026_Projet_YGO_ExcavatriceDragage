#!/usr/bin/env python3
"""Gate documentaire : audit en lecture seule du depot (liens morts, versions perimees, AF).

Classe de bug couverte (audit 2026-07-29) : AGENTS.md, CLAUDE.md, README.md
et les consignes pointant vers des specs supprimees ou deplacees.

Ce script est un AUDITEUR PUR EN LECTURE SEULE :
  D1  lien vers un fichier inexistant                             -> ERREUR
  D2  lien vers une version plus ancienne que celle presente      -> ERREUR
  D3  plusieurs versions actives du meme document dans DOC/       -> AVERTISSEMENT
  D4  lien interne casse vers un autre fichier du depot           -> ERREUR
  D7  renvoi en PROSE vers un numero d'AF qui n'existe pas        -> ERREUR

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/check_doc_links.py
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Scan global : docs, standards, outillage, consignes et code ST.
SCAN_GLOBS = ("*.md", ".claude/skills/*.md", "DOC/**/*.md", "TOOLS/**/*.md", "CODE/**/*.st")
EXCLUDED_PARTS = {"ARCHIVES", "node_modules", ".venv", "venv", ".git", ".pi-subagents"}

# Journaux historiques : ils citent des documents tels qu'ils existaient a la date
# de l'entree. Un lien vers un document depuis archive n'y est pas une erreur.
HISTORICAL_LOGS = {
    "DOC/VERSION_HISTORY.md",
    "DOC/AUDIT_Coherence_Documentaire_v1.0.md",
    "DOC/WFLOW/AUDITS/Architecture/AUDIT_M0_GEL_ETAT_INITIAL.md",
    "DOC/WFLOW/AUDITS/Architecture/REGISTRE_ARBITRAGES_MIGRATION.md",
    "DOC/MES/CHECKLISTS/EXTRACTIONS/FB_Encoder_Extraction_Code_v1.0.md",
}

# D7 — journaux de bord et contrats de tache : ils citent le numero d'AF tel qu'il
# etait a la date de l'entree. Reecrire un journal falsifierait l'historique.
NUMBERING_HISTORICAL_PREFIXES = (
    "DOC/WFLOW/PLAN_TASK",
    "DOC/WFLOW/CONTRACTS/",
    "DOC/WFLOW/AUDITS/",
)
NUMBERING_OPT_OUT = "doc-links:numerotation-historique"

VERSIONED = re.compile(r"^(?P<stem>.+?)_v(?P<major>\d+)\.(?P<minor>\d+)\.md$")
LINK = re.compile(r"(?P<path>(?:DOC|CODE|TOOLS)/[A-Za-z0-9_./\-]+\.(?:md|st|py|xml))")
AF_PARTIE = re.compile(r"^AF_Partie-(?P<num>\d{2})_")

AF_MENTION = re.compile(
    r"\b(?:"
    r"AF_Partie-(?P<num>\d{2})"
    r"|AF(?P<num2>\d{2})"
    r"|Partie\s+(?P<num3>\d{2})"
    r")\b"
)


def is_excluded(path: Path) -> bool:
    return any(part in EXCLUDED_PARTS for part in path.parts)


def doc_key(name: str) -> str | None:
    """Clef d'identite d'un document, independante de sa version."""
    match = VERSIONED.match(name)
    if not match:
        return None
    partie = AF_PARTIE.match(name)
    return f"AF_Partie-{partie.group('num')}" if partie else match.group("stem")


def latest_versions(doc_dir: Path) -> dict[str, tuple[tuple[int, int], str]]:
    """clef -> ((major, minor), nom de fichier) de la version la plus recente."""
    latest: dict[str, tuple[tuple[int, int], str]] = {}
    for entry in doc_dir.rglob("*.md"):
        match = VERSIONED.match(entry.name)
        key = doc_key(entry.name)
        if not match or not key:
            continue
        version = (int(match.group("major")), int(match.group("minor")))
        if key not in latest or version > latest[key][0]:
            latest[key] = (version, entry.name)
    return latest


def all_versions(doc_dir: Path) -> dict[str, list[str]]:
    versions: dict[str, list[str]] = {}
    for entry in sorted(doc_dir.rglob("*.md")):
        key = doc_key(entry.name)
        if key:
            versions.setdefault(key, []).append(entry.name)
    return versions


def iter_files(root: Path):
    seen: set[Path] = set()
    for pattern in SCAN_GLOBS:
        for path in root.glob(pattern):
            if path.is_file() and not is_excluded(path.relative_to(root)) and path not in seen:
                seen.add(path)
                yield path


def active_af_numbers(doc_dir: Path) -> set[str]:
    numbers: set[str] = set()
    for entry in doc_dir.rglob("*.md"):
        match = AF_PARTIE.match(entry.name)
        if match:
            numbers.add(match.group("num"))
    return numbers


def build_basename_map(root: Path) -> dict[str, list[str]]:
    mapping: dict[str, list[str]] = {}
    for path in iter_files(root):
        rel = path.relative_to(root).as_posix()
        mapping.setdefault(path.name, []).append(rel)
    return mapping


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_root", nargs="?", default=".")
    args = parser.parse_args()

    root = Path(args.project_root).resolve()
    doc_dir = root / "DOC"

    if not doc_dir.is_dir():
        print(f"ERROR: Dossier DOC/ introuvable dans {root}", file=sys.stderr)
        return 2

    latest = latest_versions(doc_dir)
    versions = all_versions(doc_dir)
    af_numbers = active_af_numbers(doc_dir)
    by_basename = build_basename_map(root)

    errors: list[str] = []
    warnings: list[str] = []

    # D3 — plusieurs versions actives du meme document
    for key, files in versions.items():
        if len(files) > 1:
            best = latest[key][1]
            others = [f for f in files if f != best]
            warnings.append(
                f"DOC/: {len(files)} versions actives de `{key}` — garder `{best}`, "
                f"archiver dans ARCHIVES/Doc/ : {', '.join(others)}"
            )

    for path in iter_files(root):
        rel = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace")

        if rel in HISTORICAL_LOGS:
            continue

        if path.suffix == ".md" and "/prompts/" not in f"/{rel}":
            content = text.lstrip()
            if content.startswith("---"):
                closing = content.find("\n---", 3)
                content = content[closing + 4 :] if closing > 0 else content
            first = next((l for l in content.splitlines() if l.strip()), "")
            if not first.lstrip().startswith("#"):
                errors.append(
                    f"{rel}:1: document sans titre H1 — contenu de tete probablement perdu "
                    f"(commence par : {first.strip()[:60]!r})"
                )

        historical = rel.startswith(NUMBERING_HISTORICAL_PREFIXES) or NUMBERING_OPT_OUT in text
        archive_spans = [m.span() for m in re.finditer(r"ARCHIVES/[A-Za-z0-9_./\-]+", text)]
        if af_numbers and not historical:
            reported: set[tuple[int, str]] = set()
            for match in AF_MENTION.finditer(text):
                raw_num = match.group("num") or match.group("num2") or match.group("num3")
                if not raw_num:
                    continue
                num = raw_num.zfill(2)
                if num in af_numbers:
                    continue
                if any(start <= match.start() < end for start, end in archive_spans):
                    continue
                line = text.count("\n", 0, match.start()) + 1
                if (line, num) in reported:
                    continue
                reported.add((line, num))
                errors.append(
                    f"{rel}:{line}: renvoi `{match.group(0)}` vers une AF inexistante "
                    f"(numeros publies : {', '.join(sorted(af_numbers))})"
                )

        for match in LINK.finditer(text):
            target = match.group("path")
            if "..." in target or "XX" in target or "PartieN" in target:
                continue
            line = text.count("\n", 0, match.start()) + 1
            resolved = root / target

            if resolved.is_file():
                name = Path(target).name
                key = doc_key(name)
                if key and key in latest:
                    match_version = VERSIONED.match(name)
                    if match_version:
                        version = (int(match_version.group("major")), int(match_version.group("minor")))
                        if version < latest[key][0]:
                            newest = latest[key][1]
                            errors.append(
                                f"{rel}:{line}: `{target}` est perime — version active : DOC/{newest}"
                            )
                continue

            archived = root / "ARCHIVES" / "Doc" / Path(target).relative_to(Path(target).parts[0])
            if archived.is_file():
                archived_rel = archived.relative_to(root).as_posix()
                errors.append(
                    f"{rel}:{line}: `{target}` est archive — referencer `{archived_rel}`"
                )
                continue

            basename = Path(target).name
            if basename == "PLAN_TASK_v1.0.md":
                candidates = ["DOC/WFLOW/PLAN_TASK.md"]
            else:
                candidates = by_basename.get(basename, [])
            if len(candidates) == 1 and candidates[0] != target:
                errors.append(
                    f"{rel}:{line}: `{target}` a ete deplace vers `{candidates[0]}`"
                )
                continue

            key = doc_key(Path(target).name)
            if key and key in latest:
                newest = latest[key][1]
                errors.append(
                    f"{rel}:{line}: lien mort `{target}` — version active : DOC/{newest}"
                )
            else:
                errors.append(
                    f"{rel}:{line}: lien mort `{target}` (aucune version active trouvee)"
                )

    for warning in warnings:
        print(f"[WARN] {warning}")
    for error in errors:
        print(f"[ERROR] {error}", file=sys.stderr)

    print(
        f"\nDoc links check: {'FAIL' if errors else 'PASS'} "
        f"({len(errors)} erreur(s), {len(warnings)} avertissement(s))"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
