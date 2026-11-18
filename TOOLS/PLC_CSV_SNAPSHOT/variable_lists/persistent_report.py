#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Post-traitement du dernier releve de persistantes : version declaree + diff precedent + diff defauts.

PYTHON 3 EXTERNE (pas la console CODESYS). Le releve lui-meme se fait dans CODESYS (snapshot_persistent.py,
projet en ligne, Login fait a la main) ; ce script ne se connecte a rien et n'ecrit rien sur l'automate.

Usage :
  python persistent_report.py --hints                  # indices pour renseigner la version (n'ecrit rien)
  python persistent_report.py --version "v0.7.45"      # consigne la version declaree, puis compare
  python persistent_report.py --version inconnue       # accepte : marquee « inconnue », ne bloque jamais
  options : --dir DOSSIER (defaut : DOC/WFLOW/MISE_EN_SERVICE/20261117_PERSISTANTES), --no-diff

Ecrit a cote du releve : <releve>.version.txt (version DECLAREE par l'utilisateur, jamais une preuve)
et _derniere_version.txt (derniere valeur donnee, reproposee au releve suivant).
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
DEFAULT_DIR = REPO / "DOC" / "WFLOW" / "MISE_EN_SERVICE" / "20261117_PERSISTANTES"
LAST = "_derniere_version.txt"


def git(*args: str) -> str:
    try:
        return subprocess.run(["git", "-C", str(REPO), *args], capture_output=True, text=True, timeout=20).stdout.strip()
    except Exception:
        return ""


def newest_project() -> str:
    files = sorted((REPO / "PRJ_CODESYS").glob("*.project"), key=lambda p: p.stat().st_mtime, reverse=True)
    if not files:
        return "aucun .project trouve"
    p = files[0]
    return f"{p.stem} (enregistre {datetime.fromtimestamp(p.stat().st_mtime):%d/%m %H:%M})"


def hints(folder: Path, releve: Path) -> list[str]:
    last = (folder / LAST).read_text(encoding="utf-8").strip() if (folder / LAST).exists() else "aucune"
    dirty = " + modifications non commitees dans CODE/" if git("status", "--short", "CODE") else ""
    return [
        f"Releve le plus recent : {releve.name}",
        f"Derniere version declaree : {last}",
        f"Projet .project le plus recent : {newest_project()}",
        f"Commit courant du depot : {git('log', '-1', '--format=%h %cd', '--date=format:%d/%m %H:%M')}{dirty}",
        "ATTENTION : ce sont des indices, pas la version chargee dans l'automate (le projet ouvert peut etre injecte dans une autre version).",
    ]


def run(script: str, *args: str) -> None:
    print(f"\n$ python {script} {' '.join(args)}")
    r = subprocess.run([sys.executable, "-I", str(HERE / script), *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    print((r.stdout or "").rstrip())
    if r.returncode not in (0, 1) or r.stderr.strip():
        print(f"(code retour {r.returncode}) {r.stderr.strip()}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", type=Path, default=DEFAULT_DIR)
    ap.add_argument("--hints", action="store_true")
    ap.add_argument("--version", help="version/ID declare par l'utilisateur ('inconnue' accepte)")
    ap.add_argument("--no-diff", action="store_true")
    a = ap.parse_args()
    files = sorted(a.dir.glob("Persistantes_*.csv"))
    if not files:
        print(f"ERREUR: aucun releve Persistantes_*.csv dans {a.dir}", file=sys.stderr)
        return 2
    releve = files[-1]
    if a.hints or not a.version:
        print("\n".join(hints(a.dir, releve)))
        if not a.version:
            return 0
    version = a.version.strip() or "inconnue"
    (releve.with_name(releve.stem + ".version.txt")).write_text(
        f"version declaree par l'utilisateur : {version}\n"
        f"saisie le : {datetime.now():%Y-%m-%d %H:%M}\n"
        f"statut : DECLARATION (jamais une preuve de ce qui est charge dans l'automate)\n"
        f"commit du depot a cette date : {git('log', '-1', '--format=%h')}\n"
        f"projet .project le plus recent : {newest_project()}\n", encoding="utf-8")
    if version.lower() != "inconnue":
        (a.dir / LAST).write_text(version + "\n", encoding="utf-8")
    print(f"Version consignee : {version}  ->  {releve.stem}.version.txt")
    if a.no_diff:
        return 0
    if len(files) >= 2:
        run("compare_persistent_csv.py", str(files[-2]), str(releve))
    else:
        print("\nUn seul releve : pas de comparaison avec un precedent.")
    run("diff_persistent_defaults.py", str(releve))
    return 0


if __name__ == "__main__":
    sys.exit(main())
