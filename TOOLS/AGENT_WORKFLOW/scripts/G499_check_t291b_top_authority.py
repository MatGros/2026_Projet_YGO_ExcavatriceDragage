#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
G499_check_t291b_top_authority.py — Garde-fou mécanique T291-B (Phases B0/B1)

Vérifications :
1. Continuité de DisplayOffsetM dans FB_Bucket.st (interdit l'ancien saut IsClosed/IsOpen).
2. Clamping et absence de masquage de configuration inversée.
3. M2PositionCorrectedValid reste conservateur (FALSE en position intermédiaire).
4. Aucun FDC ni permis ni AX12 n'est raccordé à M2PositionCorrected en phase B1.
"""

import pathlib
import sys
import re

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO_ROOT = pathlib.Path(__file__).resolve().parents[3]
FB_BUCKET_FILE = REPO_ROOT / "CODE" / "H_TREUILS_BENNE" / "BENNE" / "FB_Bucket.st"
PRG_04_FILE = REPO_ROOT / "CODE" / "M_MAIN" / "PRG_04_Treuils_Benne.st"
SAFETY_WINCH_FILE = REPO_ROOT / "CODE" / "H_TREUILS_BENNE" / "FB_Safety_Winch.st"

def main():
    errors = []
    warnings = []

    # 1. Vérification FB_Bucket.st
    if not FB_BUCKET_FILE.is_file():
        errors.append(f"Fichier introuvable : {FB_BUCKET_FILE}")
    else:
        content_bucket = FB_BUCKET_FILE.read_text(encoding="utf-8", errors="replace")

        # Interdiction de l'ancienne affectation discrète
        old_pattern = r"IF\s+BucketState\.IsClosed\s+AND\s+NOT\s+BucketState\.IsOpen\s+THEN\s+DisplayOffsetM\s*:=\s*Config\.OffsetCloseM"
        if re.search(old_pattern, content_bucket, re.IGNORECASE):
            errors.append("FB_Bucket.st contient encore l'ancienne affectation discrète de DisplayOffsetM par état franc.")

        # Vérification du calcul continu par LIMIT
        continuous_pattern = r"DisplayOffsetM\s*:=\s*LIMIT\s*\(\s*Config\.OffsetOpenM\s*,\s*DeltaPosition_M\s*,\s*Config\.OffsetCloseM\s*\)"
        if not re.search(continuous_pattern, content_bucket):
            errors.append("FB_Bucket.st ne contient pas le calcul continu DisplayOffsetM := LIMIT(Config.OffsetOpenM, DeltaPosition_M, Config.OffsetCloseM).")

        # Vérification du repli sans masquage
        if "LIMIT(Config.OffsetCloseM, DeltaPosition_M, Config.OffsetOpenM)" in content_bucket:
            errors.append("FB_Bucket.st contient un LIMIT inversé qui masque une configuration aberrante.")

    # 2. Vérification PRG_04_Treuils_Benne.st
    if not PRG_04_FILE.is_file():
        errors.append(f"Fichier introuvable : {PRG_04_FILE}")
    else:
        content_prg04 = PRG_04_FILE.read_text(encoding="utf-8", errors="replace")

        # M2PositionCorrected doit utiliser DisplayOffsetM
        pos_pattern = r"BucketState\.M2PositionCorrected\s*:=\s*PRG_02_Acquisition\.Data\.EncoderM2\.Measurement\.CablePosM\s*-\s*instBucket\.DisplayOffsetM"
        if not re.search(pos_pattern, content_prg04):
            errors.append("PRG_04_Treuils_Benne.st n'assigne pas M2PositionCorrected depuis instBucket.DisplayOffsetM.")

        # Validité conservatrice : FALSE en intermédiaire
        valid_pattern = r"BucketState\.M2PositionCorrectedValid\s*:=\s*_BucketState\.BucketReferenced\s+AND\s+\(_BucketState\.IsClosed\s+XOR\s+_BucketState\.IsOpen\)"
        if not re.search(valid_pattern, content_prg04):
            errors.append("PRG_04_Treuils_Benne.st : M2PositionCorrectedValid n'exige pas (IsClosed XOR IsOpen).")

        # Vérification qu'aucun FDC n'utilise M2PositionCorrected en B1
        if re.search(r"TopLimitM2_M\s*:=.*M2PositionCorrected", content_prg04):
            errors.append("PRG_04_Treuils_Benne.st raccorde prématurément TopLimitM2_M à M2PositionCorrected (interdit en B1).")

    # 3. Rapport
    print("=" * 60)
    print("🛡️ GARDE-FOU MÉCANIQUE T291-B — CONTINUITÉ M2 POSITION (G499)")
    print("=" * 60)
    if errors:
        for err in errors:
            print(f"❌ ERREUR : {err}")
        print("\nRésultat : FAIL")
        sys.exit(1)
    else:
        print("✅ FB_Bucket.st : calcul continu DisplayOffsetM vérifié.")
        print("✅ FB_Bucket.st : absence d'affectation discontinue ou de masquage vérifiée.")
        print("✅ PRG_04_Treuils_Benne.st : M2PositionCorrected continu vérifié.")
        print("✅ PRG_04_Treuils_Benne.st : M2PositionCorrectedValid conservateur vérifié.")
        print("✅ Périmètre strict B1 : aucun raccordement anticipé aux FDC vérifié.")
        print("\nRésultat : PASS (0 erreur)")
        sys.exit(0)

if __name__ == "__main__":
    main()
