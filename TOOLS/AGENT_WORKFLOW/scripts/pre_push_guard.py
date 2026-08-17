#!/usr/bin/env python3
"""pre_push_guard.py — Hook pre-push INFORMATIF et NON BLOQUANT.

But : alerter l'humain (et rappeler aux agents IA) sur ce qui est poussé, SANS
bloquer le push. Un agent IA pousse tout sans se poser de questions ; ce script
affiche un résumé + des avertissements si quelque chose ne devrait pas être là
(suppressions, fichiers hors périmètre), et rappelle que ce n'est PAS le rôle
de l'agent de déplacer/supprimer/ne-pas-committer des fichiers.

Usage (appelé par .git/hooks/pre-push) :
    pre_push_guard.py <remote> <url>   # lit les refs sur stdin

Toujours exit 0 (non bloquant).
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

# Fichiers/dossiers que les agents ne doivent JAMAIS toucher (déplacer/supprimer/committer).
# À adapter au projet. Un fichier supprimé ici déclenche un avertissement.
PROTECTED_PATHS = (
    "CODE_XML/",       # bundle généré — ne pas committer à la main
    "Device.export",   # export CODESYS — débogage ponctuel, jamais une référence
    "ARCHIVES/",       # jamais une source active
)


def _run(cmd: list[str]) -> str:
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return (r.stdout or "") + (r.stderr or "")


def main() -> int:
    remote = sys.argv[1] if len(sys.argv) > 1 else "?"
    url = sys.argv[2] if len(sys.argv) > 2 else "?"

    print("=" * 60)
    print(f"pre-push guard (informatif, non bloquant) — remote: {remote}")
    print("=" * 60)

    lines = [ln.strip() for ln in sys.stdin if ln.strip()]
    if not lines:
        print("(aucune ref à pousser)")
        return 0

    for line in lines:
        parts = line.split()
        if len(parts) < 4:
            continue
        local_ref, local_sha, remote_ref, remote_sha = parts[:4]
        print(f"\n> {local_ref} -> {remote_ref}")

        # Diff entre l'état distant et l'état local
        stat = _run(["git", "diff", "--stat", remote_sha, local_sha])
        if stat.strip():
            print(stat.strip())

        # Détection des suppressions
        name_status = _run(["git", "diff", "--name-status", remote_sha, local_sha])
        deletions = []
        protected_hits = []
        for ln in name_status.splitlines():
            ln = ln.strip()
            if not ln:
                continue
            status = ln[0]
            path = ln[1:].strip()
            if status == "D":
                deletions.append(path)
            for p in PROTECTED_PATHS:
                if path.startswith(p):
                    protected_hits.append((status, path))

        if deletions:
            print(f"\n[!] {len(deletions)} fichier(s) SUPPRIME(S) dans ce push :")
            for d in deletions:
                print(f"    - {d}")
            print("    -> Verifier que ces suppressions sont INTENTIONNELLES et validees par l'humain.")

        if protected_hits:
            print(f"\n[X] {len(protected_hits)} fichier(s) PROTEGE(S) touche(s) :")
            for status, path in protected_hits:
                print(f"    - [{status}] {path}")
            print("    -> Ces fichiers ne doivent PAS etre deplaces/supprimes/committes par un agent.")

    print("\n" + "=" * 60)
    print("RAPPEL : ce hook est INFORMATIF et NON BLOQUANT.")
    print("PREMIER REFLEXE : si tu vois un fichier que tu n'as PAS modifie, ou une")
    print("suppression, ou un fichier qui ne devrait pas etre la -> STOP et DEMANDE a l'humain.")
    print("Ne supprime JAMAIS un fichier que tu n'as pas toi-meme cree/modifie :")
    print("l'humain (ou un autre agent) a pu l'editer. Ce n'est pas ton role de")
    print("deplacer, supprimer ou ne-pas-committer des fichiers. La decision finale")
    print("appartient a l'humain.")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
