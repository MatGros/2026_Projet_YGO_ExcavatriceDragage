#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
clean.py — Archive le contenu de CODE/ et Device.export dans ARCHIVES/<timestamp>/,
puis prepare une slate clean pour le prochain export CODESYS.

Usage :
    python tools/clean.py
    python tools/clean.py --dry-run    (affiche ce qui serait archivé, sans rien faire)
"""
from __future__ import print_function

import argparse
import io
import sys
import shutil
from pathlib import Path
from datetime import datetime

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CODE = PROJECT_ROOT / "CODE"
DEFAULT_PROJ = PROJECT_ROOT / "PROJ_Full_ImportExport"
DEFAULT_ARCHIVE_ROOT = PROJECT_ROOT / "ARCHIVES"


def main(argv=None):
    parser = argparse.ArgumentParser(description="Archive CODE/ et Device.export, prepare slate clean.")
    parser.add_argument("--code", default=str(DEFAULT_CODE),
                        help="Dossier CODE a archiver (defaut: CODE/)")
    parser.add_argument("--proj", default=str(DEFAULT_PROJ),
                        help="Dossier PROJ_Full_ImportExport (defaut: PROJ_Full_ImportExport/)")
    parser.add_argument("--archive-root", default=str(DEFAULT_ARCHIVE_ROOT),
                        help="Racine des archives (defaut: ARCHIVES/)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Affiche ce qui serait archivé sans rien faire")
    args = parser.parse_args(argv)

    code = Path(args.code)
    proj = Path(args.proj)
    archive_root = Path(args.archive_root)
    device_export = proj / "Device.export"

    if not code.is_dir():
        print("ERREUR: CODE/ introuvable : {}".format(code))
        return 1

    # Timestamp pour le nom de l'archive
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    archive_dir = archive_root / timestamp
    archive_code = archive_dir / "CODE"
    archive_export = archive_dir / "Device.export.backup"

    print("\nNettoyage du projet")
    print("===================\n")
    print("Archive sera creee : {}".format(archive_dir))
    print("  - CODE/ -> {}".format(archive_code))
    if device_export.exists():
        print("  - Device.export -> {}".format(archive_export))
    print("")

    if args.dry_run:
        print("[DRY RUN - aucun changement ne sera effectue]")
        return 0

    # Confirmation
    try:
        ans = input("Confirmer l'archivage ? [o]ui / [n]on : ").strip().lower()
    except EOFError:
        ans = ""
    if ans not in ("o", "oui", "y", "yes"):
        print("Annule.")
        return 0

    # Creation repertoire archive
    archive_root.mkdir(parents=True, exist_ok=True)
    archive_dir.mkdir(parents=True, exist_ok=True)

    # Archivage de CODE/
    files_moved = 0
    if code.is_dir():
        try:
            shutil.move(str(code), str(archive_code))
            files_moved = len(list(archive_code.rglob("*")))
            print("CODE/ archive : {} fichier(s).".format(files_moved))
        except Exception as e:
            print("ERREUR lors de l'archivage de CODE/ : {}".format(e))
            return 1
        # Recreer un dossier CODE/ vide
        code.mkdir(parents=True, exist_ok=True)
        print("CODE/ reinitialise (vide).")

    # Archivage de Device.export
    if device_export.exists():
        try:
            shutil.copy2(device_export, archive_export)
            print("Device.export archive : {}".format(archive_export.name))
            # Vider Device.export : garder juste le fichier vide pour reimport
            # (on ne le supprime pas, pour garder le chemin et le nom)
            device_export.write_text("", encoding="utf-8")
            print("Device.export vidange (pret pour reimport CODESYS).")
        except Exception as e:
            print("ERREUR lors de l'archivage de Device.export : {}".format(e))
            return 1

    print("\nArchivage termine :")
    print("  dossier : {}".format(archive_dir.relative_to(PROJECT_ROOT)))
    print("  {} fichier(s) archive(s).".format(files_moved))
    print("\nOK. Vous pouvez exporter votre projet CODESYS → PROJ_Full_ImportExport/Device.export")
    return 0


if __name__ == "__main__":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    except Exception:
        pass
    sys.exit(main())
