#!/usr/bin/env python3
"""Bloque les nouvelles fuites scratch a la racine du depot (T279)."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


ROOT_SCRATCH_EXACT = {".dsh_tmp", "tmp", ".tmpsandbox", "scratch", "CODE_XML.freshness"}


def is_root_scratch(name: str) -> bool:
    """Retourne vrai pour un dossier scratch interdit a la racine."""
    return name.startswith(".tmp_") or name in ROOT_SCRATCH_EXACT


def root_scratch_name(path: str) -> str | None:
    """Extrait le dossier scratch racine d'un chemin Git, sinon None."""
    first = path.replace("\\", "/").split("/", 1)[0]
    return first if is_root_scratch(first) else None


def load_baseline(path: Path) -> set[str]:
    """Lit la dette historique explicitement versionnee, sans la rendre invisible."""
    data = json.loads(path.read_text(encoding="utf-8"))
    entries = data.get("legacy_root_scratch_dirs", [])
    if not isinstance(entries, list) or not all(isinstance(item, str) and is_root_scratch(item) for item in entries):
        raise ValueError("legacy_root_scratch_dirs invalide")
    return set(entries)


def tracked_paths(root: Path) -> set[str]:
    """Retourne les chemins suivis sans scanner les ACL potentiellement verrouillees."""
    result = subprocess.run(
        ["git", "ls-files"], cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace"
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "git ls-files a echoue")
    return {line for line in result.stdout.splitlines() if line}


def find_violations(root: Path, legacy: set[str], tracked: set[str]) -> tuple[list[str], list[str]]:
    """Retourne (erreurs, avertissements) en distinguant dette connue et fuite nouvelle."""
    errors: list[str] = []
    warnings: list[str] = []
    legacy_tracked: dict[str, int] = {}
    present = {entry.name for entry in root.iterdir() if entry.is_dir() and is_root_scratch(entry.name)}

    for name in sorted(present):
        if name in legacy:
            warnings.append(f"dette T279 presente a la racine : {name}")
        else:
            errors.append(f"scratch interdit a la racine : {name}")

    for path in sorted(tracked):
        name = root_scratch_name(path)
        if name is None:
            continue
        if name in legacy:
            legacy_tracked[name] = legacy_tracked.get(name, 0) + 1
        else:
            errors.append(f"fichier Git suivi en zone scratch interdite : {path}")

    for name, count in sorted(legacy_tracked.items()):
        warnings.append(f"fichiers Git historiques en zone scratch : {name} ({count})")

    for name in sorted(legacy - present):
        warnings.append(f"baseline T279 obsolete (dossier absent, a retirer apres validation) : {name}")
    return errors, warnings


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument(
        "--baseline", type=Path, default=Path(__file__).resolve().parents[1] / "config" / "workspace_hygiene_baseline.json"
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = args.project_root.resolve()
    baseline = args.baseline.resolve()
    try:
        errors, warnings = find_violations(root, load_baseline(baseline), tracked_paths(root))
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"[ERROR] G345 indisponible : {exc}", file=sys.stderr)
        return 2
    for warning in warnings:
        print(f"[WARN] {warning}")
    for error in errors:
        print(f"[ERROR] {error}", file=sys.stderr)
    print(f"Workspace hygiene: {'FAIL' if errors else 'PASS'} ({len(errors)} erreur(s), {len(warnings)} avertissement(s))")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
