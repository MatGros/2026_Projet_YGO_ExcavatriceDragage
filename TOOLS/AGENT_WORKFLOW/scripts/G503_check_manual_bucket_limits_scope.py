#!/usr/bin/env python3
"""G503 - Portee stricte de ManualBucketLimitsActive (T327).

REX 2026-09-20 : elargir ManualBucketLimitsActive au-dela du jog unitaire M2
(ex. condition "NOT instBucket.Lifecycle.Busy" seule) a applique les bornes du JOG
manuel a la descente couplee MAINT WinchSel=0 et au cycle SEMI_AUTO AX4. Benne
ouverte, Delta < OpenAnticipationM -> ProcessPermitM2_Descend=FALSE -> couplage
atomique M1/M2 -> aucun treuil ne demarre. Preuve terrain : decocher le toggle
retablit tout.

Invariants verifies dans PRG_04_Treuils_Benne.st :
  1. ManualBucketLimitsActive := ... contient TglManualBucketLimits
     AND (JoystickWinchSelectArbitrated = 2) AND NOT CoupledBucketPhaseLocked.
  2. Cette affectation ne contient ni instBucket.Lifecycle.Busy ni SelJoystickWinch
     (selecteur brut IHM) -- seule l'arbitree fait foi.
  3. La borne T248 (T248BucketJogActive) existe, est gatee sur
     CoupledBucketPhaseLocked AND Arbitrated = 2, et utilise CoherenceLimitM
     (frontiere reelle IsClosed/IsOpen), jamais une Anticipation.
"""
from pathlib import Path
import re
import sys

TARGET = Path("CODE/M_MAIN/PRG_04_Treuils_Benne.st")


def _assignment(text: str, name: str) -> str:
    m = re.search(rf"^{name}\s*:=(.*?);", text, re.M | re.S)
    return m.group(1) if m else ""


def main() -> int:
    if not TARGET.is_file():
        print(f"G503 FAIL: fichier absent: {TARGET}")
        return 1
    text = TARGET.read_text(encoding="utf-8")
    errors = []

    manual = _assignment(text, "ManualBucketLimitsActive")
    if not manual:
        errors.append("affectation ManualBucketLimitsActive introuvable")
    else:
        flat = " ".join(manual.split())
        if "TglManualBucketLimits" not in flat:
            errors.append("ManualBucketLimitsActive ne depend plus de TglManualBucketLimits")
        if not re.search(r"JoystickWinchSelectArbitrated\s*=\s*2", flat):
            errors.append("ManualBucketLimitsActive n'est plus gate sur JoystickWinchSelectArbitrated = 2 "
                          "(portee elargie au couple / SEMI_AUTO -> REX 2026-09-20)")
        if not re.search(r"AND\s+NOT\s+PRG_03_Modes_Cycle\.Data\.Auth\.CoupledBucketPhaseLocked", flat):
            errors.append("ManualBucketLimitsActive n'exclut plus la phase T248 (CoupledBucketPhaseLocked)")
        if "instBucket.Lifecycle.Busy" in flat:
            errors.append("ManualBucketLimitsActive gate sur instBucket.Lifecycle.Busy (elargissement interdit)")
        if "SelJoystickWinch" in flat:
            errors.append("ManualBucketLimitsActive lit le selecteur brut IHM au lieu de l'arbitre")

    t248 = _assignment(text, "T248BucketJogActive")
    if not t248:
        errors.append("affectation T248BucketJogActive introuvable")
    else:
        flat = " ".join(t248.split())
        if "CoupledBucketPhaseLocked" not in flat or not re.search(r"JoystickWinchSelectArbitrated\s*=\s*2", flat):
            errors.append("T248BucketJogActive doit etre CoupledBucketPhaseLocked AND Arbitrated = 2")

    for permit in ("ProcessPermitM2_Descend", "ProcessPermitM2_Ascent"):
        body = " ".join(_assignment(text, permit).split())
        m = re.search(r"NOT\s*\(\s*T248BucketJogActive\s+AND\s*\((.*?)\)\)\)", body)
        if not m:
            errors.append(f"{permit} : terme T248BucketJogActive absent")
            continue
        term = m.group(1)
        if "CoherenceLimitM" not in term:
            errors.append(f"{permit} : la borne T248 n'utilise pas CoherenceLimitM")
        if "AnticipationM" in term:
            errors.append(f"{permit} : la borne T248 reutilise une Anticipation (interdit)")

    if errors:
        for e in errors:
            print(f"G503 FAIL: {e}")
        return 1
    print("G503 PASS: ManualBucketLimitsActive = jog unitaire M2 strict (Arbitrated=2, hors T248) ; "
          "borne T248 sur CoherenceLimitM")
    return 0


if __name__ == "__main__":
    sys.exit(main())
