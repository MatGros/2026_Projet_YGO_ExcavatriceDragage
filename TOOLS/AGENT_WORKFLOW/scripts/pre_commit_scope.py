#!/usr/bin/env python3
"""pre_commit_scope.py — Hook pre-commit BLOQUANT sur fichier partagé.

But : empêcher qu'une branche de feature écrase un fichier de coordination
partagé (ex. DOC/WFLOW/TASKS.yaml) que d'autres ont mis à jour sur main.

Logique (cas par cas) :
  - Sur main (ou master)            -> libre, on laisse faire.
  - Fichier non modifié dans le commit -> rien à faire, on laisse faire.
  - main n'a PAS bougé depuis le point de divergence (merge-base) :
        la version de main == celle du merge-base == celle que la branche a
        modifiée. Personne d'autre n'a travaillé dessus -> merge SÛR, on laisse
        faire (exit 0).
  - main a AUSSI bougé (version main != version merge-base) :
        deux sources de vérité divergent -> on BLOQUE (exit 1) et on alerte
        l'humain pour qu'il mette à jour main manuellement.

Usage (appelé par .git/hooks/pre-commit) :
    pre_commit_scope.py

Exit 0 = commit autorisé. Exit 1 = commit refusé.
"""

from __future__ import annotations

import subprocess
import sys

# Fichier de coordination partagé à protéger. À adapter au projet.
PROTECTED_FILE = "DOC/WFLOW/TASKS.yaml"
# Branche de référence (source de vérité du fichier partagé).
MAIN_BRANCH = "main"


def _run(cmd: list[str]) -> str:
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return (r.stdout or "").strip()


def _branch() -> str:
    return _run(["git", "branch", "--show-current"])


def _staged_files() -> list[str]:
    out = _run(["git", "diff", "--cached", "--name-only"])
    return [ln.strip() for ln in out.splitlines() if ln.strip()]


def _file_at(rev: str) -> str | None:
    """Retourne le contenu de PROTECTED_FILE à la révision rev, ou None si absent."""
    r = subprocess.run(
        ["git", "show", f"{rev}:{PROTECTED_FILE}"],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    if r.returncode != 0:
        return None
    return r.stdout


def main() -> int:
    branch = _branch()
    if branch in (MAIN_BRANCH, "master"):
        return 0  # sur la branche de référence, libre

    if PROTECTED_FILE not in _staged_files():
        return 0  # fichier partagé non modifié -> rien à faire

    # main a-t-il bougé depuis le point de divergence ?
    merge_base = _run(["git", "merge-base", "HEAD", MAIN_BRANCH])
    if not merge_base:
        # Impossible de déterminer (main absent ?) -> on laisse passer, on ne
        # bloque pas sur une incertitude.
        return 0

    base_ver = _file_at(merge_base)
    main_ver = _file_at(MAIN_BRANCH)

    if base_ver is None or main_ver is None:
        # Fichier absent d'un côté (créé sur la branche ?) -> on laisse passer.
        return 0

    if base_ver == main_ver:
        # main n'a pas touché le fichier depuis la divergence -> merge sûr.
        return 0

    print("=" * 60)
    print(f"⛔ BLOQUÉ : {PROTECTED_FILE} modifié sur la branche '{branch}'")
    print("   ET main a aussi bougé depuis le point de divergence.")
    print("   Risque de désynchronisation du fichier partagé.")
    print("=" * 60)
    print("   → Mets à jour main manuellement, puis retire ce fichier du commit :")
    print(f"       git restore --staged {PROTECTED_FILE}")
    print("   → Ou, si la mise à jour est volontaire et coordonnée, demande")
    print("     explicitement à l'humain de débloquer.")
    print("=" * 60)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
