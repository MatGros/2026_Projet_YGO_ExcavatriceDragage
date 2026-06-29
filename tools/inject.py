#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
inject.py — Reinjecte dans PROJ_Full_ImportExport/Device.export les POU du dossier CODE/, retrouves
par leur GUID unique.

Detection automatique : un POU dont le fichier CODE/ est IDENTIQUE au bloc deja
present dans Device.export est marque "inchange" et ignore (rien a faire). Seuls
les POU reellement modifies sont proposes a la reinjection.

Pour chaque POU modifie : invite [o]ui / [n]on / [t]out / [q]uitter
(--yes reinjecte tout sans demander).

Securites :
  - fragment XML bien forme ; GUID present et unique dans la cible ;
  - LineInfoPersistence coherent avec le GUID (avertissement sinon) ;
  - corps Ladder/FBD inchange (avertissement sinon) ;
  - backup horodate .bak avant ecriture ;
  - re-validation XML du fichier complet avant ecriture (abandon sinon).

Usage :
    python tools/inject.py             # depuis CODE/ vers PROJ_Full_ImportExport/Device.export
    python tools/inject.py --yes       # reinjecte tout sans confirmation
    python tools/inject.py --source X --target Y
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
DEFAULT_TARGET = PROJECT_ROOT / "PROJ_Full_ImportExport" / "Device.export"
DEFAULT_SOURCE = PROJECT_ROOT / "CODE"


def fragment_info(frag_text):
    """Valide le fragment (XML bien forme) et retourne (guid, name)."""
    try:
        ET.fromstring(frag_text)
    except ET.ParseError as e:
        raise ValueError("XML mal forme : {}".format(e))
    guid_m = cc.GUID_RE.search(frag_text)
    name_m = cc.NAME_RE.search(frag_text)
    if not guid_m or not name_m:
        raise ValueError("Guid ou Name introuvable.")
    return guid_m.group(1).strip(), name_m.group(1).strip()


def check_lineinfo(frag_text, guid):
    problems = []
    for m in cc.re.finditer(
            r'<Single\s+Name="LineInfoPersistence"\s+Type="string">([^<]*)</Single>',
            frag_text):
        if guid not in m.group(1):
            problems.append(m.group(1))
    return problems


def _extract_impl(block):
    m = cc.re.search(r'<Single\s+Name="Implementation"\b', block)
    if not m:
        return None
    return block[m.start():cc.find_entry_end(block, m.start())]


def main(argv=None):
    parser = argparse.ArgumentParser(description="Reinjecte les FB/PRG de CODE/ dans Device.export.")
    parser.add_argument("--target", default=str(DEFAULT_TARGET),
                        help="Device.export cible (defaut: PROJ_Full_ImportExport/Device.export)")
    parser.add_argument("--source", default=str(DEFAULT_SOURCE),
                        help="Dossier des POU (defaut: CODE/)")
    parser.add_argument("--yes", action="store_true",
                        help="Reinjecte tout sans confirmation")
    args = parser.parse_args(argv)

    target = Path(args.target)
    source = Path(args.source)

    if not target.is_file():
        print("ERREUR: cible introuvable : {}".format(target))
        return 1
    if not source.is_dir():
        print("ERREUR: dossier source introuvable : {}".format(source))
        return 1

    # Fichiers a la racine de CODE/ seulement (sous-dossiers type _archive ignores)
    frag_files = sorted(p for p in source.glob("*.xml") if p.is_file())
    if not frag_files:
        print("Rien a faire : aucun .xml dans {}.".format(source))
        return 0

    text = target.read_text(encoding="utf-8")
    existing = {}
    for pou in cc.iter_pou_entries(text):
        existing.setdefault(pou["guid"], []).append(pou)

    candidates = []   # POU modifies, valides : (path, name, guid, old_pou, new_block, delta)
    n_same = n_err = 0

    print("\nAnalyse de {} ...\n".format(source))
    for fp in frag_files:
        try:
            frag_text = fp.read_text(encoding="utf-8")
        except (PermissionError, OSError) as e:
            n_err += 1
            print("  VERROUILLE {:<41} {} (fermez-le)".format(fp.name, e))
            continue
        try:
            guid, name = fragment_info(frag_text)
        except ValueError as e:
            n_err += 1
            print("  REFUSE   {:<42} {}".format(fp.name, e))
            continue

        matches = existing.get(guid, [])
        if len(matches) != 1:
            n_err += 1
            why = "GUID absent de la cible" if not matches else \
                  "GUID non unique ({} occurrences)".format(len(matches))
            print("  REFUSE   {:<42} {}".format(fp.name, why))
            continue

        old_pou = matches[0]
        new_block = frag_text
        if new_block.endswith("\n") and not old_pou["block"].endswith("\n"):
            new_block = new_block.rstrip("\n")

        if new_block == old_pou["block"]:
            n_same += 1
            print("  inchange {:<42} {}".format(fp.name, name))
            continue

        # Avertissements non bloquants
        for bad in check_lineinfo(frag_text, guid):
            print("  ATTENTION {:<41} LineInfoPersistence ne reference pas le GUID : {}".format(
                fp.name, bad))
        if cc.is_ladder(old_pou["block"]):
            if _extract_impl(old_pou["block"]) != _extract_impl(frag_text):
                print("  ATTENTION {:<41} corps Ladder/FBD modifie (deconseille).".format(fp.name))

        delta = len(new_block) - len(old_pou["block"])
        candidates.append((fp, name, guid, old_pou, new_block, delta))
        print("  MODIFIE  {:<42} {:<22} (delta {:+d} car.)".format(fp.name, name, delta))

    print("\n{} inchange(s), {} modifie(s), {} refuse(s).".format(n_same, len(candidates), n_err))
    if not candidates:
        print("Aucun POU a reinjecter.")
        return 1 if n_err else 0

    # Confirmation par POU avec memoire 'tout'
    print("\nConfirmation de la reinjection :")
    state = {"all": args.yes}
    chosen = []
    try:
        for cand in candidates:
            fp, name, guid, _, _, delta = cand
            if cc.confirm_each("Reinjecter {} ({:+d})".format(name, delta), state):
                chosen.append(cand)
            else:
                print("    -> ignore : {}".format(name))
    except cc.QuitRequested:
        print("\nInterrompu. Aucun changement.")
        return 1

    if not chosen:
        print("\nAucun POU selectionne. Aucun changement.")
        return 0

    # Backup
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup = target.with_suffix(target.suffix + ".{}.bak".format(stamp))
    shutil.copy2(target, backup)
    print("\nBackup cree : {}".format(backup.name))

    # Remplacement par offsets decroissants
    new_text = text
    for _, name, guid, old_pou, new_block, _ in sorted(
            chosen, key=lambda t: t[3]["start"], reverse=True):
        new_text = new_text[:old_pou["start"]] + new_block + new_text[old_pou["end"]:]

    try:
        ET.fromstring(new_text)
    except ET.ParseError as e:
        print("ERREUR: resultat XML invalide ({}). Aucune ecriture. Backup conserve.".format(e))
        return 1

    target.write_text(new_text, encoding="utf-8")
    print("\nReinjection terminee : {} POU mis a jour dans {}.".format(len(chosen), target.name))
    print("Backup : {}".format(backup.name))
    print("OK. Vous pouvez reimporter Device.export dans CODESYS.")
    return 0


if __name__ == "__main__":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    except Exception:
        pass
    sys.exit(main())
