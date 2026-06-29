#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
extract.py — Extrait chaque POU (FB / PRG) de PROJ_Full_ImportExport/Device.export dans un fichier
.xml individuel sous CODE/ (dossier unique, versionne avec git).

Chaque fichier contient le bloc XML complet de l'entree, VERBATIM (octets
inchanges), pour un round-trip parfait.

Comportement quand un fichier existe deja dans CODE/ :
  - identique           -> ignore en silence ("inchange") ;
  - present mais different -> demande [o]ui / [n]on / [t]out / [q]uitter
                              (sauf --yes qui ecrase tout sans demander).

Usage :
    python tools/extract.py            # extrait/maj vers CODE/
    python tools/extract.py --yes      # ecrase tout sans confirmation
    python tools/extract.py --out X --source Y
"""
from __future__ import print_function

import argparse
import io
import sys
from pathlib import Path

import codesys_common as cc

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE = PROJECT_ROOT / "PROJ_Full_ImportExport" / "Device.export"
DEFAULT_OUT = PROJECT_ROOT / "CODE"


def main(argv=None):
    parser = argparse.ArgumentParser(description="Extrait les FB/PRG de Device.export vers CODE/.")
    parser.add_argument("--source", default=str(DEFAULT_SOURCE),
                        help="Chemin du Device.export (defaut: PROJ_Full_ImportExport/Device.export)")
    parser.add_argument("--out", default=str(DEFAULT_OUT),
                        help="Dossier de sortie (defaut: CODE/)")
    parser.add_argument("--yes", action="store_true",
                        help="Ecrase tous les fichiers existants sans demander")
    args = parser.parse_args(argv)

    source = Path(args.source)
    out = Path(args.out)

    if not source.is_file():
        print("ERREUR: source introuvable : {}".format(source))
        return 1

    text = source.read_text(encoding="utf-8")
    out.mkdir(parents=True, exist_ok=True)

    pous = list(cc.iter_pou_entries(text))
    if not pous:
        print("ERREUR: aucun POU trouve dans {}.".format(source))
        return 1

    print("\nExtraction depuis : {}".format(source))
    print("Sortie            : {}\n".format(out))

    state = {"all": args.yes}
    n_new = n_upd = n_same = n_skip = n_lock = 0

    def safe_write(dest, block):
        """Ecrit dest ; retourne True si ok, False si verrouille/erreur d'acces."""
        try:
            dest.write_text(block, encoding="utf-8")
            return True
        except (PermissionError, OSError) as e:
            print("    !! ECHEC ecriture {} : {} (fichier verrouille ? fermez-le)".format(
                dest.name, e))
            return False

    try:
        for pou in pous:
            fname = cc.safe_filename(pou["name"], pou["guid"])
            dest = out / fname
            block = pou["block"]
            kind = "FB " if "FUNCTION_BLOCK" in block else "PRG"
            body = "Ladder/FBD" if cc.is_ladder(block) else "ST"

            if dest.exists():
                try:
                    current = dest.read_text(encoding="utf-8")
                except (PermissionError, OSError) as e:
                    n_lock += 1
                    print("  VERROUILLE [{}] {:<21} {} : {}".format(kind, pou["name"], body, e))
                    continue
                if current == block:
                    n_same += 1
                    print("  inchange  [{}] {:<22} {}".format(kind, pou["name"], body))
                    continue
                # different -> demande
                print("  MODIFIE   [{}] {:<22} {} (fichier existant different)".format(
                    kind, pou["name"], body))
                if not cc.confirm_each("Ecraser {}".format(fname), state):
                    n_skip += 1
                    print("    -> ignore.")
                    continue
                if safe_write(dest, block):
                    n_upd += 1
                    print("    -> mis a jour.")
                else:
                    n_lock += 1
            else:
                if safe_write(dest, block):
                    n_new += 1
                    print("  nouveau   [{}] {:<22} {} -> {}".format(kind, pou["name"], body, fname))
                else:
                    n_lock += 1
    except cc.QuitRequested:
        print("\nInterrompu par l'utilisateur.")
        return 1

    print("\nRecap : {} POU dans Device.export.".format(len(pous)))
    print("  nouveaux : {} | mis a jour : {} | inchanges : {} | ignores : {} | verrouilles : {}".format(
        n_new, n_upd, n_same, n_skip, n_lock))
    print("OK." if n_lock == 0 else "TERMINE avec {} fichier(s) verrouille(s) (non ecrits).".format(n_lock))
    return 0 if n_lock == 0 else 2


if __name__ == "__main__":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    except Exception:
        pass
    sys.exit(main())
