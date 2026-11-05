#!/usr/bin/env python3
"""G530 - Integrite referentielle des contrats et du catalogue de taches.

REX 2026-11-02 (briefing T213) : `check_task_contract.py` a rendu PASS sur un
contrat qui interdisait `CODE/G_CYCLE/FB_MachineHomingCycle.st` — un fichier qui
N'EXISTE PAS (renomme `FB_CycleMachineHoming.st` par T239). Une interdiction qui
vise un fichier fantome ne protege rien, et un critere « git diff de <fichier>
vide » passe trivialement. Le controle de structure ne verifie pas l'existence
des chemins cites : c'est ce trou que ce gate ferme.

Ce gate lit :
  - tous les DOC/WFLOW/CONTRACTS/*.yaml ;
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

CONTRACTS_DIR = "DOC/WFLOW/CONTRACTS"
TASKS_FILE = "DOC/WFLOW/TASKS.yaml"
BASELINE_PATH = "TOOLS/AGENT_WORKFLOW/config/contract_refs_baseline.json"

# Racines de chemins qui designent un fichier du depot (jamais un exemple abstrait).
ROOTS = ("CODE/", "DOC/", "TOOLS/", "PRJ_CODESYS/", "CODE_XML/")
# Extensions considerees comme des fichiers concrets.
EXTENSIONS = (
    ".st", ".md", ".yaml", ".yml", ".json", ".py", ".txt", ".xml",
    ".html", ".bat", ".ps1", ".mjs", ".js", ".csv",
)
# Un chemin peut etre precede de ponctuation Markdown / YAML ; on capture le token.
PATH_RE = re.compile(r"[A-Za-z0-9_./\\-]+")
CONTRAT_FIELD_RE = re.compile(r"^\s*contrat:\s*['\"]?([^'\"\n]+)['\"]?\s*$", re.MULTILINE)


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
    if value.endswith(EXTENSIONS):
        return True
    # Un dossier cite comme perimetre (ex. ARCHIVES/**) n'est pas un fichier.
    return False


def extract_paths(text: str) -> set[str]:
    """Retourne l'ensemble des chemins de fichiers du depot cites dans un texte."""
    found: set[str] = set()
    for raw in PATH_RE.findall(text):
        candidate = normalise(raw)
        # Les chemins multi-lignes YAML peuvent etre prefixes par du bruit.
        index = next((candidate.find(root) for root in ROOTS if root in candidate), -1)
        if index > 0:
            candidate = candidate[index:]
        if looks_like_repo_path(candidate):
            found.add(candidate)
    return found


def collect_references(root: Path) -> dict[str, set[str]]:
    """Retourne {source: {chemins cites}} pour les contrats et le catalogue."""
    references: dict[str, set[str]] = {}
    contracts = root / CONTRACTS_DIR
    if contracts.is_dir():
        for path in sorted(contracts.glob("*.yaml")):
            text = path.read_text(encoding="utf-8", errors="replace")
            references[f"{CONTRACTS_DIR}/{path.name}"] = extract_paths(text)
    tasks = root / TASKS_FILE
    if tasks.is_file():
        text = tasks.read_text(encoding="utf-8", errors="replace")
        # Le champ `contrat:` porte parfois une note libre (« A ECRIRE ... ») :
        # on n'y retient que les vrais chemins de fichiers.
        cites: set[str] = set()
        for match in CONTRAT_FIELD_RE.finditer(text):
            cites |= extract_paths(match.group(1))
        references[TASKS_FILE] = cites
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

    references = collect_references(root)
    if not references:
        print("G530 FAIL: aucun contrat ni catalogue trouve (racine erronee ?)")
        return 1

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
