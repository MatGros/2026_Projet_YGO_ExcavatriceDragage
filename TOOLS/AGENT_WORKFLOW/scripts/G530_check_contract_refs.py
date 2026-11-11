#!/usr/bin/env python3
"""G530 - Integrite referentielle des contrats et du catalogue de taches.

REX 2026-11-02 (briefing T213) : `check_task_contract.py` a rendu PASS sur un
contrat qui interdisait `CODE/G_CYCLE/FB_MachineHomingCycle.st` — un fichier qui
N'EXISTE PAS (renomme `FB_CycleMachineHoming.st` par T239). Une interdiction qui
vise un fichier fantome ne protege rien, et un critere « git diff de <fichier>
vide » passe trivialement. Le controle de structure ne verifie pas l'existence
des chemins cites : c'est ce trou que ce gate ferme.

Ce gate lit :
  - les sources YAML des dossiers CONTRACTS, anciens ou ranges sous TASKS/ ;
  - les contrats des dossiers de tache actifs (role, contenu ou reference explicite) ;
  - le champ `contrat:` de chaque tache de DOC/WFLOW/TASKS.yaml.

Il extrait les chemins de fichiers du depot (CODE/, DOC/, TOOLS/, PRJ_CODESYS/)
et verifie leur existence sur disque.

Comportement fail-closed MAIS non bloquant a l'introduction :
  - les chemins absents listes dans la baseline
    TOOLS/AGENT_WORKFLOW/config/contract_refs_baseline.json sont signales en
    WARN (dette connue, non masquee) ;
  - tout chemin absent HORS baseline est une ERROR -> sortie 1.
Ainsi une nouvelle reference morte ne peut plus entrer silencieusement, sans
casser la CI sur la dette existante. `--update-baseline` fige l'etat courant
(action humaine tracee, jamais automatique).

Usage :
    python TOOLS/AGENT_WORKFLOW/scripts/G530_check_contract_refs.py [racine]
    python TOOLS/AGENT_WORKFLOW/scripts/G530_check_contract_refs.py . --report
    python TOOLS/AGENT_WORKFLOW/scripts/G530_check_contract_refs.py . --strict
    python TOOLS/AGENT_WORKFLOW/scripts/G530_check_contract_refs.py . --update-baseline
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import yaml

CONTRACTS_DIR = "DOC/WFLOW/CONTRACTS"
TASK_DIRECTORIES = "DOC/WFLOW/TASKS"
TASKS_FILE = "DOC/WFLOW/TASKS.yaml"
BASELINE_PATH = "TOOLS/AGENT_WORKFLOW/config/contract_refs_baseline.json"

# Racines de chemins qui designent un fichier du depot (jamais un exemple abstrait).
ROOTS = ("CODE/", "DOC/", "TOOLS/", "PRJ_CODESYS/", "CODE_XML/")
# Extensions considerees comme des fichiers concrets.
EXTENSIONS = (
    ".st", ".md", ".yaml", ".yml", ".json", ".py", ".txt", ".xml",
    ".html", ".bat", ".ps1", ".mjs", ".js", ".csv",
)
# Capturer le chemin jusqu'a son extension, espaces et parentheses inclus.
# Un autre debut de chemin ne doit pas etre absorbe par une citation de dossier.
_ROOT_PATTERN = r"(?:CODE_XML|PRJ_CODESYS|TOOLS|CODE|DOC)[/\\]"
_EXT_PATTERN = "|".join(re.escape(ext[1:]) for ext in EXTENSIONS)
_OPTION_PATTERN = r"\s--?[A-Za-z][A-Za-z0-9-]*(?=\s|=|$)"
PATH_RE = re.compile(
    rf"(?<![A-Za-z0-9_]){_ROOT_PATTERN}(?=[\w.*-])"
    rf"(?:(?!{_ROOT_PATTERN}|[/\\]\s|{_OPTION_PATTERN})[^\r\n`\"'<>|;,:+=])*?"
    rf"\.(?:{_EXT_PATTERN})(?=$|[\s,;:)\]}}>\x60\"'#]|\.(?=\s|$))"
)
EXCLUDED_PARTS = {"archives", ".git", "node_modules", ".venv", "venv"}


def normalise(token: str) -> str:
    """Normalise un token en chemin relatif POSIX, sans ponctuation de bord."""
    value = token.replace("\\", "/").strip().strip(".,;:)`'\"")
    while value.startswith("./"):
        value = value[2:]
    return value


def looks_like_repo_path(value: str) -> bool:
    if not value.startswith(ROOTS):
        return False
    # Un motif (glob, ellipse de documentation) ne designe aucun fichier precis.
    if "*" in value or "..." in value:
        return False
    # Une parenthese ouvrant une explication en prose ne fait pas partie
    # du chemin ; les vrais dossiers parentheses restent acceptes.
    if value.count("(") != value.count(")"):
        return False
    if value.endswith(EXTENSIONS):
        return True
    # Un dossier cite comme perimetre (ex. ARCHIVES/**) n'est pas un fichier.
    return False


def extract_paths(text: str) -> set[str]:
    """Retourne les chemins complets cites, espaces et parentheses inclus."""
    return {
        candidate
        for match in PATH_RE.finditer(text)
        if looks_like_repo_path(candidate := normalise(match.group(0)))
    }


def _strings(value):
    """Scalaires textuels YAML, y compris les scalaires replies et listes."""
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from _strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from _strings(item)


def _load_yaml(path: Path):
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8", errors="replace"))
    except yaml.YAMLError as exc:
        raise ValueError(f"YAML inexploitable : {path}: {exc}") from exc


def catalogue_paths(root: Path) -> set[str]:
    """References du champ contrat reel, jamais une ligne physique tronquee."""
    path = root / TASKS_FILE
    if not path.is_file():
        return set()
    document = _load_yaml(path)
    if not isinstance(document, dict) or not isinstance(document.get("tasks"), list):
        raise ValueError(f"Catalogue inexploitable : {TASKS_FILE} doit porter tasks: [..]")
    found: set[str] = set()
    for task in document["tasks"]:
        if isinstance(task, dict):
            for text in _strings(task.get("contrat")):
                found.update(extract_paths(text))
    return found


def _active_source(root: Path, path: Path) -> bool:
    """Exclure l'exemple TXXX/, pas les vrais fichiers nommes TXXX_*.yaml."""
    if not path.resolve().is_relative_to(root.resolve()):
        return False
    try:
        relative = path.relative_to(root)
    except ValueError:
        return False
    if any(part.casefold() in EXCLUDED_PARTS for part in relative.parts):
        return False
    if path.suffix.lower() not in {".yaml", ".yml"} or ".bak" in path.name.casefold():
        return False
    try:
        task_relative = path.relative_to(root / TASK_DIRECTORIES)
    except ValueError:
        return True
    return not (task_relative.parts and task_relative.parts[0] == "TXXX")


def discover_sources(root: Path) -> list[Path]:
    """Sources controlees, independantes du nom du sas de rangement.

    Un dossier CONTRACTS garde son corpus YAML complet (contrat standard,
    legacy, contexte, catalogue de signaux). Hors de ce dossier, le role
    contractuel doit etre explicite dans le nom, le contenu ou le catalogue.
    """
    sources: set[Path] = set()
    legacy = root / CONTRACTS_DIR
    if legacy.is_dir():
        sources.update(p for p in legacy.rglob("*") if p.is_file() and _active_source(root, p))
    task_root = root / TASK_DIRECTORIES
    if task_root.is_dir():
        for path in task_root.rglob("*"):
            if not path.is_file() or not _active_source(root, path):
                continue
            parents = path.relative_to(task_root).parts[:-1]
            named = re.search(r"(?:^|_)(?:CONTRAT|CONTRACT)(?:_|\.)", path.name, re.I)
            in_corpus = any(part.casefold() == "contracts" for part in parents)
            if in_corpus or named:
                sources.add(path)
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            if re.search(r"^contract\s*:", text, re.M) or (
                re.search(r"^task_id\s*:", text, re.M)
                and re.search(r"^(?:objectifs_testables|objective|criticality)\s*:", text, re.M)
            ):
                sources.add(path)
    for value in catalogue_paths(root):
        path = root / value
        if path.is_file() and _active_source(root, path):
            sources.add(path)
    return sorted(sources)


def collect_references(root: Path) -> dict[str, set[str]]:
    """Retourne {source: {chemins cites}} pour les sources et le catalogue."""
    references: dict[str, set[str]] = {}
    for path in discover_sources(root):
        # Conserver les commentaires deja controles, puis reconstituer les
        # scalaires replies/quotes pour ne perdre aucune reference structuree.
        text = path.read_text(encoding="utf-8", errors="replace")
        cites = extract_paths(text)
        for scalar in _strings(_load_yaml(path)):
            cites.update(extract_paths(scalar))
        references[path.relative_to(root).as_posix()] = cites
    if (root / TASKS_FILE).is_file():
        references[TASKS_FILE] = catalogue_paths(root)
    return references


def missing_paths(root: Path, references: dict[str, set[str]]) -> dict[str, list[str]]:
    """Retourne {chemin absent: [sources qui le citent]}."""
    missing: dict[str, list[str]] = {}
    cache: dict[str, bool] = {}
    for source, paths in references.items():
        for value in sorted(paths):
            if value not in cache:
                cache[value] = (root / value).exists()
            if not cache[value]:
                missing.setdefault(value, []).append(source)
    return {value: sorted(set(sources)) for value, sources in sorted(missing.items())}


def load_baseline(root: Path) -> set[str]:
    path = root / BASELINE_PATH
    if not path.is_file():
        return set()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return set()
    known = data.get("known_missing")
    return set(known) if isinstance(known, list) else set()


def write_baseline(root: Path, missing: dict[str, list[str]]) -> None:
    path = root / BASELINE_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "why": (
            "Cette baseline fige la DETTE de references mortes constatee a "
            "l'introduction de G530. Elle n'excuse rien : tout nouveau chemin "
            "absent hors de cette liste fait echouer le gate. La reduire est un "
            "travail attendu ; l'augmenter exige une decision humaine tracee."
        ),
        "known_missing": sorted(missing),
    }
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    argv = sys.argv[1:]
    report = "--report" in argv
    strict = "--strict" in argv
    update = "--update-baseline" in argv
    args = [a for a in argv if not a.startswith("--")]
    root = Path(args[0] if args else ".").resolve()

    try:
        references = collect_references(root)
    except (ValueError, OSError) as exc:
        print(f"G530 FAIL: {exc}")
        return 1
    if not references:
        print("G530 FAIL: aucun contrat ni catalogue trouve (racine erronee ?)")
        return 1

    source_count = sum(source != TASKS_FILE for source in references)
    if not source_count:
        print("G530 FAIL: aucune source YAML de contrat decouverte ; le catalogue seul ne prouve pas la couverture")
        return 1
    print(f"G530 couverture: {source_count} source(s) YAML, catalogue {'present' if TASKS_FILE in references else 'absent'}")

    missing = missing_paths(root, references)
    total_refs = sum(len(paths) for paths in references.values())

    if update:
        write_baseline(root, missing)
        print(f"G530: baseline ecrite ({len(missing)} chemins absents figes) -> {BASELINE_PATH}")
        return 0

    known = load_baseline(root)
    nouvelle_dette = {value: src for value, src in missing.items() if value not in known}
    dette_connue = {value: src for value, src in missing.items() if value in known}

    if report or dette_connue:
        for value, sources in dette_connue.items():
            print(f"G530 WARN: chemin absent (dette connue) {value} <- {', '.join(sources)}")
    for value, sources in nouvelle_dette.items():
        print(f"G530 FAIL: chemin absent {value} <- {', '.join(sources)}")

    if strict:
        for value, sources in dette_connue.items():
            print(f"G530 FAIL (--strict): chemin absent {value} <- {', '.join(sources)}")
        if dette_connue:
            return 1

    if nouvelle_dette:
        print(
            "G530 FAIL: "
            f"{len(nouvelle_dette)} nouvelle(s) reference(s) morte(s). "
            "Corriger le chemin cite, ou --update-baseline si l'absence est assumee."
        )
        return 1

    print(
        f"G530 PASS: {total_refs} chemins cites dans {len(references)} source(s), "
        f"0 nouvelle reference morte ({len(dette_connue)} dette(s) connue(s) en baseline)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
