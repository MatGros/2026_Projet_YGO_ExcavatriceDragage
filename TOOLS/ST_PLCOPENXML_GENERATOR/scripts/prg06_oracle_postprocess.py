#!/usr/bin/env python3
"""Post-traitement oracle pour PRG_06_Outputs_LD.

Contourne les bugs de ld_builder.py en remplaçant le POU PRG_06_Outputs_LD
généré par une structure LD conforme à l'oracle CODESYS (samples_reference_codesys/
PRG_06_Outputs_LD.xml). Cette fonction est appelée APRÈS la génération du bundle
par generator.cli, et APRÈS la régénération de vérification dans check_bundle_freshness.py.

REX 2026-08-04 : ld_builder.py produit un LD non importable (IndexOutOfRangeException).
Causes multiples : TRUE en inVariable au lieu de contact, variables qualifiées en
inVariable au lieu de contact, coils fantômes câblées au rail au lieu du bloc,
inputs non connectés créés après le bloc, chemins nested non résolvables.
Le script oracle génère un LD structurellement identique à l'export CODESYS réel.
"""
from __future__ import annotations

import copy
import sys
import xml.etree.ElementTree as ET

# Importer le générateur oracle
_SCRIPT_DIR = None
if __name__ != "__main__":
    import os
    _SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
    if _SCRIPT_DIR not in sys.path:
        sys.path.insert(0, _SCRIPT_DIR)

from gen_prg06_oracle import build_prg06_pou

NS = "http://www.plcopen.org/xml/tc6_0200"
NS_MAP = {"pou": NS}


def inject_prg06_oracle(bundle_path: str) -> bool:
    """Remplace le POU PRG_06_Outputs_LD dans le bundle par l'oracle.

    Args:
        bundle_path: chemin vers CODE_Bundle.xml

    Returns:
        True si le POU a été remplacé, False s'il n'a pas été trouvé.
    """
    tree = ET.parse(bundle_path)
    root = tree.getroot()

    oracle_pou = build_prg06_pou()

    replaced = False
    for pous in root.findall(".//pou:pous", NS_MAP):
        for i, p in enumerate(pous):
            if p.get("name") == "PRG_06_Outputs_LD":
                # Recuperer l ObjectId existant avant de remplacer
                existing_oid = None
                for ad in p.iter():
                    if ad.tag.endswith("data") and "objectid" in (ad.get("name") or "").lower():
                        for child in ad:
                            if child.tag.endswith("ObjectId") and child.text:
                                existing_oid = child.text
                                break
                        break
                # Injecter l ObjectId existant dans le nouveau POU
                if existing_oid:
                    for ad in oracle_pou.iter():
                        if ad.tag.endswith("data") and "objectid" in (ad.get("name") or "").lower():
                            for child in ad:
                                if child.tag.endswith("ObjectId"):
                                    child.text = existing_oid
                                break
                            break
                pous[i] = copy.deepcopy(oracle_pou)
                replaced = True
                break
        if replaced:
            break

    if replaced:
        import sys as _sys
        import os as _os
        _gen_dir = _os.path.join(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__))))
        if _gen_dir not in _sys.path:
            _sys.path.insert(0, _gen_dir)
        from generator.xml_serializer import serialize
        from pathlib import Path
        Path(bundle_path).write_bytes(serialize(root))

    return replaced


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle_path", help="Chemin vers CODE_Bundle.xml")
    args = parser.parse_args()

    ok = inject_prg06_oracle(args.bundle_path)
    if ok:
        print(f"PRG_06_Outputs_LD remplace par l oracle dans {args.bundle_path}")
        sys.exit(0)
    else:
        print(f"ERREUR: PRG_06_Outputs_LD non trouve dans {args.bundle_path}", file=sys.stderr)
        sys.exit(1)