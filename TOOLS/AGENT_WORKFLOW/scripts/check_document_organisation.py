#!/usr/bin/env python3
"""Controle T430 : destinations et references de la migration documentaire.

Les correspondances existantes restent la source du perimetre : aucun second
catalogue n'est cree. Les dettes hors correspondance restent du ressort de G530.
Lecture seule ; aucun renommage, nettoyage ou mise a jour de baseline.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import re
from pathlib import Path
from urllib.parse import unquote

import yaml

MANIFEST = "TXXX_CORRESPONDANCE_RENOMMAGE_AUDITS_20261110.json"
REPORT = "TXXX_TRIAGE_CONTRACTS_VS_TASKS_20261110.md"
APPLICATION_REPORT = "TXXX_RAPPORT_RENOMMAGE_AUDITS_20261110.md"
BROKEN_VERSION = re.compile(r"_V(\d+)_(\d+)\.md$")
VERSION = re.compile(r"_v\d+\.\d+\.md$")
TASK_PREFIX = re.compile(r"^T(?:XXX|\d+[A-Z]?(?:-[A-Za-z0-9]+)?)[_-]")
MARKDOWN_LINK = re.compile(
    r"\]\((?:<(?P<angle>[^>\n]+)>"
    r"(?:\s+(?:\"[^\"\n]*\"|'[^'\n]*'|\([^()\n]*\)))?"
    r"|(?P<plain>[^()\n]*(?:\([^()\n]*\)[^()\n]*)*))\)"
)
MARKDOWN_TITLE = re.compile(r"\s+(?:\"[^\"\n]*\"|'[^'\n]*'|\([^()\n]*\))\s*$")


def ignored(path: Path) -> bool:
    return any(part.casefold() in {"archives", ".git", "node_modules"} for part in path.parts) or ".bak" in path.name.casefold()


def load_tool(name: str):
    """Charger les outils du garde, pas du depot-fixture controle."""
    source = Path(__file__).with_name(name + ".py")
    spec = importlib.util.spec_from_file_location(name + "_organisation", source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_migration(root: Path) -> tuple[set[Path], dict[str, Path]]:
    """Jeu exact des destinations et alias complets ancien chemin -> cible."""
    root = root.resolve()
    task_root = root / "DOC/WFLOW/TASKS"
    candidates = [p for p in task_root.rglob(MANIFEST)
                  if not ignored(p.relative_to(task_root)) and p.relative_to(task_root).parts[0] != "TXXX"]
    if len(candidates) != 1:
        raise ValueError(f"manifeste de migration absent ou ambigu ({len(candidates)} trouves)")
    manifest = candidates[0]
    audits = manifest.parent
    staging = audits.parent
    data = json.loads(manifest.read_text(encoding="utf-8"))
    overrides = data.get("current_target_overrides", {})
    if not isinstance(overrides, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in overrides.items()):
        raise ValueError("current_target_overrides doit etre une correspondance explicite")
    expected: set[Path] = set()
    aliases: dict[str, Path] = {}
    destinations: dict[str, Path] = {}

    def add(folder: str, source: str, target: str):
        if not isinstance(source, str) or not isinstance(target, str):
            raise ValueError("source et cible doivent etre des chemins textuels explicites")
        if ignored(Path(source)) or ignored(Path(target)):
            return
        if Path(target).name != target or target in {".", ".."}:
            raise ValueError(f"destination non plate : {target}")
        if BROKEN_VERSION.search(target):
            raise ValueError(f"suffixe de version invalide dans la cible declaree : {target}")
        path = (staging / folder / target).resolve()
        key = path.as_posix().casefold()
        if key in destinations:
            raise ValueError(f"destination dupliquee ou collision Windows : {target}")
        destinations[key] = path
        expected.add(path)
        for prefix in (f"DOC/WFLOW/{folder}", f"{staging.relative_to(root).as_posix()}/{folder}",
                       f"DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/{folder}",
                       f"DOC/WFLOW/TASKS/T_TEMP (A TRIIER)/{folder}"):
            alias = f"{prefix}/{source}".replace("\\", "/")
            if alias in aliases and aliases[alias] != path:
                raise ValueError(f"correspondance ambigue : {alias}")
            aliases[alias] = path
        # Les suffixes malformes ont aussi ete des noms appliques sur disque.
        # Leur remplacement doit etre controle meme apres actualisation du JSON.
        previous_version = re.sub(r"_v(\d+)\.(\d+)\.md$", r"_V\1_\2.md", target)
        if previous_version != target:
            alias = f"{staging.relative_to(root).as_posix()}/{folder}/{previous_version}"
            aliases[alias] = path

    for row in data.get("files", []) + data.get("proposal_files", []):
        # JSON courant : jamais de correction implicite ou d'override historique.
        add("AUDITS", row["source"], row.get("current_target", row["target"]))
    add("AUDITS", APPLICATION_REPORT, APPLICATION_REPORT)
    report = staging / "CONTRACTS" / REPORT
    text = report.read_text(encoding="utf-8")
    if "## Application du renommage" not in text or "## Suite validée" not in text:
        raise ValueError("tables de correspondance CONTRACTS/REVIEWS/TESTS absentes")
    contracts, remainder = text.split("## Application du renommage", 1)[1].split("## Suite validée", 1)
    contract_rows = re.findall(r"^\| `([^`]+)` \| `([^`]+)` \|\s*$", contracts, re.MULTILINE)
    review_rows = re.findall(r"^\| (REVIEWS|TESTS) \| `([^`]+)` \| `([^`]+)` \|", remainder, re.MULTILINE)
    if not contract_rows or not review_rows:
        raise ValueError("tables de correspondance vides")
    def current_table_target(folder: str, source: str, historical: str) -> str:
        keys = {f"{folder}/{source}", f"{folder}/{historical}"}
        values = {overrides[key] for key in keys if key in overrides}
        if not values:
            return historical
        if len(values) != 1:
            raise ValueError(f"override historique ambigu : {folder}/{historical}")
        value = values.pop()
        if not isinstance(value, str):
            raise ValueError(f"override historique invalide : {folder}/{historical}")
        parts = value.replace("\\", "/").split("/")
        if len(parts) != 2 or parts[0] != folder:
            raise ValueError(f"override hors dossier ou non plat : {value}")
        return parts[1]

    for source, target in contract_rows:
        add("CONTRACTS", source, current_table_target("CONTRACTS", source, target))
    for folder, source, target in review_rows:
        add(folder, source, current_table_target(folder, source, target))
    if manifest.resolve() not in expected or report.resolve() not in expected:
        raise ValueError("les sources de correspondance ne figurent pas parmi leurs destinations")
    return expected, aliases


def resolve_link(root: Path, caller: Path, value: str) -> Path | None:
    # Le titre optionnel n'appartient pas au nom du fichier : sans cela un
    # ancien chemin suivi de "Titre" devient invisible aux alias exacts.
    value = MARKDOWN_TITLE.sub("", value.strip())
    value = unquote(value).split("#", 1)[0].strip()
    if not value or value.startswith(("http:", "https:", "mailto:", "plugin:")):
        return None
    path = Path(value)
    if path.is_absolute():
        return path.resolve()
    if value.replace("\\", "/").startswith(("DOC/", "CODE/", "TOOLS/", "CODE_XML/", "PRJ_CODESYS/")):
        return (root / value).resolve()
    return (caller.parent / value).resolve()


def check(root: Path) -> list[str]:
    root = root.resolve()
    errors: list[str] = []
    try:
        expected, aliases = load_migration(root)
    except (ValueError, KeyError, OSError, json.JSONDecodeError) as exc:
        return [f"correspondances inexploitables : {exc}"]
    for path in sorted(expected):
        if not path.is_file():
            errors.append(f"destination attendue absente : {path.relative_to(root).as_posix()}")
        if not TASK_PREFIX.match(path.name):
            errors.append(f"prefixe de tache invalide : {path.name}")
        if BROKEN_VERSION.search(path.name):
            errors.append(f"suffixe de version invalide : {path.name}")
    # Le compte seul ne suffit pas : un remplacement de fichier doit aussi echouer.
    for directory in {p.parent for p in expected}:
        for path in directory.rglob("*"):
            if path.is_file() and not ignored(path.relative_to(directory)) and path.resolve() not in expected:
                errors.append(f"fichier hors correspondance : {path.relative_to(root).as_posix()}")
            if path.is_file() and not ignored(path.relative_to(directory)) and not TASK_PREFIX.match(path.name):
                errors.append(f"prefixe de tache invalide sur disque : {path.relative_to(root).as_posix()}")
            if path.is_file() and BROKEN_VERSION.search(path.name):
                errors.append(f"suffixe de version invalide : {path.relative_to(root).as_posix()}")
    g340 = load_tool("G340_check_doc_links")
    version_paths = {root / "DOC" / rel for values in g340.all_versions(root / "DOC").values() for rel in values}
    for path in expected:
        if VERSION.search(path.name) and path not in version_paths:
            errors.append(f"version non couverte par G340 : {path.relative_to(root).as_posix()}")
    g530 = load_tool("G530_check_contract_refs")
    sources = {p.resolve() for p in g530.discover_sources(root)}
    for path in expected:
        if path.parent.name == "CONTRACTS" and path.suffix in {".yaml", ".yml"} and path not in sources:
            errors.append(f"source YAML non couverte par G530 : {path.relative_to(root).as_posix()}")

    alias_paths = {(root / old).resolve(): target for old, target in aliases.items()}

    def examine(value: Path, location: str):
        target = alias_paths.get(value)
        if target is not None and value != target:
            errors.append(f"reference de migration obsolete : {location} -> {value.relative_to(root).as_posix()} ; cible {target.relative_to(root).as_posix()}")
        elif value in expected and not value.is_file():
            errors.append(f"reference active absente : {location} -> {value.relative_to(root).as_posix()}")

    def strings(value):
        if isinstance(value, str):
            yield value
        elif isinstance(value, dict):
            for item in value.values():
                yield from strings(item)
        elif isinstance(value, list):
            for item in value:
                yield from strings(item)

    # Le contrat est operatoire ; execution/validation sont des comptes rendus
    # dates. Une ancienne reference ponctuee dans verified_by doit etre vue,
    # sans reecrire les preuves historiques qui la citent ailleurs.
    for path in expected:
        if not path.is_file() or path.suffix not in {".yaml", ".yml"}:
            continue
        try:
            document = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
            active = document.get("contract") if isinstance(document, dict) else None
            if isinstance(active, dict):
                for text in strings(active):
                    for value in g530.extract_paths(text):
                        examine((root / value).resolve(), path.relative_to(root).as_posix() + " contract")
        except yaml.YAMLError as exc:
            errors.append(f"source YAML inexploitable : {path.relative_to(root).as_posix()}: {exc}")

    catalogue = root / "DOC/WFLOW/TASKS.yaml"
    if catalogue.is_file():
        try:
            document = yaml.safe_load(catalogue.read_text(encoding="utf-8")) or {}
            for task in document.get("tasks", []):
                for value in g530.extract_paths(str(task.get("contrat") or "")):
                    examine((root / value).resolve(), f"catalogue {task.get('id')}")
        except (yaml.YAMLError, AttributeError, TypeError) as exc:
            errors.append(f"catalogue inexploitable : {exc}")
    else:
        errors.append("catalogue absent : DOC/WFLOW/TASKS.yaml")
    for path in expected:
        if not path.is_file() or path.suffix != ".md":
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for match in MARKDOWN_LINK.finditer(text):
            destination = resolve_link(root, path, match.group("angle") or match.group("plain"))
            if destination is not None:
                examine(destination, path.relative_to(root).as_posix())
    return sorted(set(errors))


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=Path, default=Path("."))
    args = parser.parse_args(argv)
    errors = check(args.root)
    try:
        expected, _ = load_migration(args.root)
        print(f"Document organisation: {len(expected)} destinations declarees, "
              f"{sum(p.parent.name == 'CONTRACTS' and p.suffix in {'.yaml', '.yml'} for p in expected)} sources YAML attendues")
    except (ValueError, KeyError, OSError, json.JSONDecodeError):
        pass  # Le diagnostic exploitable figure deja dans errors.
    for error in errors:
        print("Document organisation FAIL: " + error)
    print(f"Document organisation {'FAIL' if errors else 'PASS'}: {len(errors)} erreur(s), lecture seule")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
