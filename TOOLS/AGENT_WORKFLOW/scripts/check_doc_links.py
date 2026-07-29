#!/usr/bin/env python3
"""Gate documentaire : aucun lien mort, aucune version perimee dans les consignes.

Classe de bug couverte (audit 2026-07-29) : `AGENTS.md`, `CLAUDE.md`, `README.md`
et l'Etape 0 de la skill CODESYS pointaient des specs supprimees (`_v1.12` alors
que `_v1.14` existait). Un agent qui obeit litteralement ne trouve rien — ou
va lire une version perimee. Le probleme se reproduit a CHAQUE `vX.Y`.

Ce script rend la maintenance inutile :
  D1  lien vers un fichier `DOC/*.md` inexistant                  -> ERREUR
  D2  lien vers une version plus ancienne que celle presente      -> ERREUR
  D3  plusieurs versions actives du meme document dans `DOC/`     -> AVERTISSEMENT
  D4  lien interne casse vers un autre fichier du depot           -> ERREUR

`--fix` reecrit automatiquement les liens D2 vers la derniere version.

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/check_doc_links.py
  python TOOLS/AGENT_WORKFLOW/scripts/check_doc_links.py --fix
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Fichiers de consignes analyses (les specs metier se citent entre elles aussi).
SCAN_GLOBS = ("*.md", ".claude/skills/*.md", "DOC/**/*.md", "TOOLS/**/*.md", "CODE/**/*.st")
EXCLUDED_PARTS = {"ARCHIVES", "node_modules", ".venv", "venv", ".git", ".pi-subagents"}
# Journaux historiques : ils citent des documents tels qu'ils existaient a la date
# de l'entree. Un lien vers un document depuis archive n'y est pas une erreur.
HISTORICAL_LOGS = {"DOC/VERSION_HISTORY.md", "DOC/AUDIT_Coherence_Documentaire_v1.0.md"}

VERSIONED = re.compile(r"^(?P<stem>.+?)_v(?P<major>\d+)\.(?P<minor>\d+)\.md$")
LINK = re.compile(r"(?P<path>(?:DOC|CODE|TOOLS)/[A-Za-z0-9_./\-]+\.(?:md|st|py|xml))")
# `AF_Partie-09_...` : la clef de regroupement est le numero de partie, car le
# libelle peut changer d'une version a l'autre (`Fonction_Winch` -> `Fonction_Treuil`).
AF_PARTIE = re.compile(r"^AF_Partie-(?P<num>\d{2})_")


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
    for entry in doc_dir.glob("*.md"):
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
    for entry in sorted(doc_dir.glob("*.md")):
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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--fix", action="store_true", help="Reecrire les liens vers la derniere version")
    args = parser.parse_args()

    root = args.root.resolve()
    doc_dir = root / "DOC"
    if not doc_dir.is_dir():
        print(f"[ERROR] dossier introuvable : {doc_dir}", file=sys.stderr)
        return 2

    latest = latest_versions(doc_dir)
    # (message, corrige_par_fix) — seuls les liens reellement reecrits disparaissent.
    errors: list[tuple[str, bool]] = []
    warnings: list[str] = []
    fixed: list[str] = []

    # D3 — plusieurs versions actives du meme document
    for key, names in sorted(all_versions(doc_dir).items()):
        if len(names) > 1:
            keep = latest[key][1]
            obsolete = [n for n in names if n != keep]
            warnings.append(
                f"DOC/: {len(names)} versions actives de `{key}` — garder `{keep}`, "
                f"archiver dans ARCHIVES/Doc/ : {', '.join(obsolete)}"
            )

    # Index basename -> chemins reels, pour retrouver un fichier deplace.
    by_basename: dict[str, list[str]] = {}
    for candidate in root.rglob("*"):
        if candidate.is_file() and not is_excluded(candidate.relative_to(root)):
            by_basename.setdefault(candidate.name, []).append(
                candidate.relative_to(root).as_posix()
            )

    for path in iter_files(root):
        rel = path.relative_to(root).as_posix()
        if rel in HISTORICAL_LOGS:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        updated = text

        # D6 — document decapite. REX 2026-07-29 : `NAMING_CONVENTION.md` avait perdu
        # ses 29 premieres lignes (titre, principes PascalCase, prefixes ST_/E_/FB_)
        # sans que personne ne le voie — les agents lisaient une convention amputee
        # de ses regles fondamentales. Un .md de regles commence toujours par son titre.
        # Les `prompts/` sont des corps d'instruction envoyes tels quels a un modele,
        # pas des documents : ils n'ont pas vocation a porter un titre.
        if path.suffix == ".md" and "/prompts/" not in f"/{rel}":
            content = text.lstrip()
            if content.startswith("---"):  # frontmatter YAML (skills) : on le saute
                closing = content.find("\n---", 3)
                content = content[closing + 4 :] if closing > 0 else content
            first = next((l for l in content.splitlines() if l.strip()), "")
            if not first.lstrip().startswith("#"):
                errors.append(
                    (
                        f"{rel}:1: document sans titre H1 — contenu de tete probablement perdu "
                        f"(commence par : {first.strip()[:60]!r})",
                        False,
                    )
                )

        for match in LINK.finditer(text):
            target = match.group("path")
            if "..." in target or "XX" in target or "PartieN" in target:
                continue  # gabarit documentaire, pas un lien reel
            line = text.count("\n", 0, match.start()) + 1
            resolved = root / target

            if resolved.is_file():
                # D2 — le fichier existe mais une version plus recente est publiee
                name = Path(target).name
                key = doc_key(name)
                if key and key in latest:
                    match_version = VERSIONED.match(name)
                    version = (int(match_version.group("major")), int(match_version.group("minor")))
                    if version < latest[key][0]:
                        newest = latest[key][1]
                        errors.append(
                            (f"{rel}:{line}: `{target}` est perime — version active : DOC/{newest}", args.fix)
                        )
                        if args.fix:
                            updated = updated.replace(target, f"DOC/{newest}")
                            fixed.append(f"{rel}: {name} -> {newest}")
                continue

            # D5 — document archive : la reference reste legitime (provenance/REX),
            # a condition qu'elle pointe explicitement `ARCHIVES/` pour qu'aucun
            # agent ne la confonde avec une spec active.
            archived = root / "ARCHIVES" / "Doc" / Path(target).relative_to(Path(target).parts[0])
            if archived.is_file():
                archived_rel = archived.relative_to(root).as_posix()
                errors.append(
                    (
                        f"{rel}:{line}: `{target}` est archive — referencer `{archived_rel}` "
                        f"(explicitement archive, jamais une spec active)",
                        args.fix,
                    )
                )
                if args.fix:
                    updated = updated.replace(target, archived_rel)
                    fixed.append(f"{rel}: {target} -> {archived_rel}")
                continue

            # D4 — fichier deplace : un seul homonyme dans le depot => on le retrouve
            basename = Path(target).name
            candidates = by_basename.get(basename, [])
            if len(candidates) == 1 and candidates[0] != target:
                errors.append(
                    (f"{rel}:{line}: `{target}` a ete deplace vers `{candidates[0]}`", args.fix)
                )
                if args.fix:
                    updated = updated.replace(target, candidates[0])
                    fixed.append(f"{rel}: {target} -> {candidates[0]}")
                continue

            # D1 — lien mort : proposer la version active si on la reconnait
            key = doc_key(Path(target).name)
            if key and key in latest:
                newest = latest[key][1]
                errors.append(
                    (f"{rel}:{line}: lien mort `{target}` — version active : DOC/{newest}", args.fix)
                )
                if args.fix:
                    updated = updated.replace(target, f"DOC/{newest}")
                    fixed.append(f"{rel}: {Path(target).name} -> {newest}")
            else:
                errors.append(
                    (f"{rel}:{line}: lien mort `{target}` (aucune version active trouvee)", False)
                )

        if args.fix and updated != text:
            path.write_text(updated, encoding="utf-8")

    if args.fix and fixed:
        print("Liens corriges :")
        for entry in fixed:
            print(f"  [FIX] {entry}")
        print()

    # Seuls les liens reellement reecrits sortent du bilan ; un lien mort
    # non resoluble reste une erreur, meme apres `--fix`.
    remaining = [message for message, was_fixed in errors if not was_fixed]

    for warning in warnings:
        print(f"[WARN] {warning}")
    for error in remaining:
        print(f"[ERROR] {error}", file=sys.stderr)

    print(
        f"\nDoc links check: {'FAIL' if remaining else 'PASS'} "
        f"({len(remaining)} erreur(s), {len(warnings)} avertissement(s))"
    )
    return 1 if remaining else 0


if __name__ == "__main__":
    raise SystemExit(main())
