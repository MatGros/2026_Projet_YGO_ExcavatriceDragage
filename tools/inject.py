#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
inject.py — Reinjecte les fragments POU modifies (dossier import/) dans
PRJ/Device.export, en les retrouvant par leur GUID unique.

Securites :
  - chaque fragment doit etre un XML bien forme ;
  - son GUID doit exister (et etre unique) dans Device.export ;
  - le LineInfoPersistence doit correspondre au GUID (anti-corruption) ;
  - pour un POU Ladder/FBD, le corps graphique (NetworkList) ne doit pas avoir
    change (sinon avertissement) ;
  - backup horodate .bak avant ecriture ;
  - confirmation interactive [o/N] ;
  - re-verification XML du fichier complet apres ecriture (rollback sinon).

Usage :
    python tools/inject.py                 # depuis ../import/ vers PRJ/Device.export
    python tools/inject.py --yes           # sans confirmation interactive
    python tools/inject.py --imports X --target Y
"""
from __future__ import print_function

import argparse
import io
import sys
import shutil
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

import codesys_common as cc

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TARGET = PROJECT_ROOT / "PRJ" / "Device.export"
DEFAULT_IMPORTS = PROJECT_ROOT / "import"


def fragment_info(frag_text):
    """
    Valide qu'un fragment est un XML bien forme et retourne (guid, name).
    Leve ValueError sinon.
    """
    try:
        ET.fromstring(frag_text)
    except ET.ParseError as e:
        raise ValueError("XML mal forme : {}".format(e))

    guid_m = cc.GUID_RE.search(frag_text)
    name_m = cc.NAME_RE.search(frag_text)
    if not guid_m or not name_m:
        raise ValueError("Guid ou Name introuvable dans le fragment.")
    return guid_m.group(1).strip(), name_m.group(1).strip()


def check_lineinfo(frag_text, guid):
    """Avertit si un LineInfoPersistence ne reference pas le bon GUID."""
    problems = []
    for m in cc.re.finditer(
            r'<Single\s+Name="LineInfoPersistence"\s+Type="string">([^<]*)</Single>',
            frag_text):
        val = m.group(1)
        if guid not in val:
            problems.append(val)
    return problems


def main(argv=None):
    parser = argparse.ArgumentParser(description="Reinjecte les FB/PRG modifies dans Device.export.")
    parser.add_argument("--target", default=str(DEFAULT_TARGET),
                        help="Device.export cible (defaut: PRJ/Device.export)")
    parser.add_argument("--imports", default=str(DEFAULT_IMPORTS),
                        help="Dossier des fragments a reinjecter (defaut: import/)")
    parser.add_argument("--yes", action="store_true",
                        help="Ne pas demander de confirmation (mode non interactif)")
    args = parser.parse_args(argv)

    target = Path(args.target)
    imports = Path(args.imports)

    if not target.is_file():
        print("ERREUR: cible introuvable : {}".format(target))
        return 1
    if not imports.is_dir():
        print("ERREUR: dossier import introuvable : {}".format(imports))
        return 1

    frag_files = sorted(imports.glob("*.xml"))
    if not frag_files:
        print("Rien a faire : aucun .xml dans {}.".format(imports))
        return 0

    text = target.read_text(encoding="utf-8")

    # Index des POU existants par GUID
    existing = {}
    for pou in cc.iter_pou_entries(text):
        existing.setdefault(pou["guid"], []).append(pou)

    planned = []   # (frag_path, name, guid, old_pou, new_block, delta)
    errors = []

    print("\nAnalyse des fragments de {} ...\n".format(imports))
    for fp in frag_files:
        frag_text = fp.read_text(encoding="utf-8")
        try:
            guid, name = fragment_info(frag_text)
        except ValueError as e:
            errors.append("{} : {}".format(fp.name, e))
            print("  REFUSE  {:<40} {}".format(fp.name, e))
            continue

        matches = existing.get(guid, [])
        if len(matches) == 0:
            msg = "GUID {} absent de la cible".format(guid)
            errors.append("{} : {}".format(fp.name, msg))
            print("  REFUSE  {:<40} {}".format(fp.name, msg))
            continue
        if len(matches) > 1:
            msg = "GUID {} non unique dans la cible ({} occurrences)".format(guid, len(matches))
            errors.append("{} : {}".format(fp.name, msg))
            print("  REFUSE  {:<40} {}".format(fp.name, msg))
            continue

        old_pou = matches[0]

        # Garde-fou LineInfoPersistence
        li_problems = check_lineinfo(frag_text, guid)
        if li_problems:
            print("  ATTENTION {:<38} LineInfoPersistence ne reference pas le GUID : {}".format(
                fp.name, li_problems))

        # Garde-fou Ladder : NetworkList ne doit pas avoir change
        if cc.is_ladder(old_pou["block"]):
            old_impl = _extract_impl(old_pou["block"])
            new_impl = _extract_impl(frag_text)
            if old_impl is not None and old_impl != new_impl:
                print("  ATTENTION {:<38} corps Ladder/FBD modifie (deconseille).".format(fp.name))

        new_block = frag_text
        # On normalise : pas de newline final parasite hors balise
        if new_block.endswith("\n") and not old_pou["block"].endswith("\n"):
            new_block = new_block.rstrip("\n")

        delta = len(new_block) - len(old_pou["block"])
        planned.append((fp, name, guid, old_pou, new_block, delta))
        print("  OK      {:<40} {:<22} (delta {:+d} car.)".format(fp.name, name, delta))

    if not planned:
        print("\nAucun fragment valide a reinjecter.")
        return 1 if errors else 0

    print("\n{} POU a reinjecter :".format(len(planned)))
    for _, name, guid, _, _, delta in planned:
        print("   - {:<22} {}  (delta {:+d})".format(name, guid, delta))
    if errors:
        print("\n{} fragment(s) refuse(s) (ignore(s)).".format(len(errors)))

    if not args.yes:
        try:
            ans = input("\nReinjecter ces POU dans {} ? [o/N] ".format(target.name)).strip().lower()
        except EOFError:
            ans = ""
        if ans not in ("o", "oui", "y", "yes"):
            print("Annule. Aucun changement.")
            return 0

    # Backup horodate
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = target.with_suffix(target.suffix + ".{}.bak".format(stamp))
    shutil.copy2(target, backup)
    print("\nBackup cree : {}".format(backup.name))

    # Remplacement par offsets decroissants (pour ne pas decaler les suivants)
    planned_by_pos = sorted(planned, key=lambda t: t[3]["start"], reverse=True)
    new_text = text
    for _, name, guid, old_pou, new_block, _ in planned_by_pos:
        new_text = new_text[:old_pou["start"]] + new_block + new_text[old_pou["end"]:]

    # Verification XML du fichier complet AVANT d'ecrire
    try:
        ET.fromstring(new_text)
    except ET.ParseError as e:
        print("ERREUR: le resultat ne serait pas un XML valide ({}).".format(e))
        print("Aucune ecriture effectuee. Backup conserve : {}".format(backup.name))
        return 1

    target.write_text(new_text, encoding="utf-8")

    print("\nReinjection terminee : {} POU mis a jour dans {}.".format(len(planned), target.name))
    print("Backup : {}".format(backup.name))
    print("OK. Vous pouvez reimporter Device.export dans CODESYS.")
    return 0


def _extract_impl(block):
    """Retourne le sous-bloc <Single Name="Implementation" ...>...</Single> ou None."""
    m = cc.re.search(r'<Single\s+Name="Implementation"\b', block)
    if not m:
        return None
    end = cc.find_entry_end(block, m.start())
    return block[m.start():end]


if __name__ == "__main__":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    except Exception:
        pass
    sys.exit(main())
