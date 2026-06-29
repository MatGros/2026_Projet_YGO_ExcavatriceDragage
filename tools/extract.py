#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
extract.py — Extrait chaque POU (FB / PRG) de PRJ/Device.export dans un fichier
.xml individuel sous extraction/.

Chaque fichier contient le bloc XML complet de l'entree, VERBATIM (octets
inchangés), pour un round-trip parfait. On edite ensuite ces fichiers a la main,
puis on les reinjecte avec inject.py.

Usage :
    python tools/extract.py                # extrait vers ../extraction/
    python tools/extract.py --clean        # vide extraction/ avant
    python tools/extract.py --source X --out Y
"""
from __future__ import print_function

import argparse
import io
import sys
from pathlib import Path

import codesys_common as cc

# Racines par defaut, relatives a ce script (tools/ -> projet)
PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE = PROJECT_ROOT / "PRJ" / "Device.export"
DEFAULT_OUT = PROJECT_ROOT / "extraction"


def main(argv=None):
    parser = argparse.ArgumentParser(description="Extrait les FB/PRG de Device.export.")
    parser.add_argument("--source", default=str(DEFAULT_SOURCE),
                        help="Chemin du Device.export (defaut: PRJ/Device.export)")
    parser.add_argument("--out", default=str(DEFAULT_OUT),
                        help="Dossier de sortie (defaut: extraction/)")
    parser.add_argument("--clean", action="store_true",
                        help="Vide les .xml du dossier de sortie avant extraction")
    args = parser.parse_args(argv)

    source = Path(args.source)
    out = Path(args.out)

    if not source.is_file():
        print("ERREUR: source introuvable : {}".format(source))
        return 1

    text = source.read_text(encoding="utf-8")

    out.mkdir(parents=True, exist_ok=True)
    if args.clean:
        removed = 0
        for f in out.glob("*.xml"):
            f.unlink()
            removed += 1
        if removed:
            print("Nettoyage : {} fichier(s) .xml supprime(s).".format(removed))

    pous = list(cc.iter_pou_entries(text))
    if not pous:
        print("ERREUR: aucun POU trouve dans {}.".format(source))
        return 1

    fb_count = prg_count = ladder_count = 0
    print("\nExtraction depuis : {}".format(source))
    print("Sortie            : {}\n".format(out))

    for pou in pous:
        fname = cc.safe_filename(pou["name"], pou["guid"])
        ladder = cc.is_ladder(pou["block"])
        # Heuristique FB vs PRG : presence du mot-cle dans le bloc Interface
        kind = "FB " if "FUNCTION_BLOCK" in pou["block"] else "PRG"
        if kind == "FB ":
            fb_count += 1
        else:
            prg_count += 1
        body = "Ladder/FBD" if ladder else "ST"
        if ladder:
            ladder_count += 1

        (out / fname).write_text(pou["block"], encoding="utf-8")
        print("  [{}] {:<22} {:<10} -> {}".format(kind, pou["name"], body, fname))

    print("\nRecap : {} POU ({} FB, {} PRG) ; {} en Ladder/FBD (VAR editable seulement).".format(
        len(pous), fb_count, prg_count, ladder_count))
    print("OK.")
    return 0


if __name__ == "__main__":
    # Force UTF-8 sur la sortie console Windows
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    except Exception:
        pass
    sys.exit(main())
