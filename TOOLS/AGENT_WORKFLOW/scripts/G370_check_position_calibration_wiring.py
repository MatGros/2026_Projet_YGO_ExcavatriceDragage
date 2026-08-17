#!/usr/bin/env python3
"""Garde-fou REX 2026-08-06 (treuils M1/M2, ascension bloquee palier 1 sans raison apparente).

`instWinchM1`/`instWinchM2` (et 4 autres instances du meme fichier : `instDiveSearch`,
`instExtractionSequence`, `instBucket`, `instWinchSync`) recevaient un comptage codeur BRUT
(`UDINT_TO_REAL(PRG_02_Acquisition.HwReal.Winch.COD1_PosValue)`, valeurs de l'ordre du million)
au lieu de la position calibree (`PRG_02_Acquisition.CablePosM1`, en metres), plus `Homed`/
`PositionsValid`/`*MeasuredSpeedValid` fixes en dur a `TRUE` au lieu de l'etat reel. Consequence
vecue sur machine : le ralentissement "proche butee haute" (`CablePosM >= TopLimitM - ...`)
se declenchait en permanence (comptage brut >> seuil en metres), bridant le treuil a la vitesse
lente indefiniment, quelle que soit la position physique reelle.

Regle : tout appel de FB dans `CODE/MAIN/*.st` ne doit JAMAIS passer
`UDINT_TO_REAL(...HwReal...PosValue)` directement en argument — la position doit toujours
transiter par la chaine de calibration (`PRG_02_Acquisition.CablePosM1/M2` ou equivalent).
Egalement : `Homed`/`HomedM1`/`HomedM2`/`PositionsValid`/`*MeasuredSpeedValid` ne doivent jamais
etre codes en dur a un literal BOOL — toujours un signal reel.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

RAW_POSITION_IN_CALL = re.compile(r"UDINT_TO_REAL\s*\([^)]*HwReal[^)]*Pos", re.IGNORECASE)
HARDCODED_VALIDITY = re.compile(
    r"\b(Homed|HomedM1|HomedM2|HomingSuspect|PositionsValid|M[12]MeasuredSpeedValid|MeasuredSpeedValid)\s*:=\s*(TRUE|FALSE)\s*,"
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=".", help="Racine du projet")
    args = parser.parse_args()
    root = Path(args.root)

    errors = 0
    main_dir = root / "CODE" / "M_MAIN" if (root / "CODE" / "M_MAIN").is_dir() else root / "CODE" / "MAIN"
    for path in sorted(main_dir.rglob("*.st")):
        text = path.read_text(encoding="utf-8", errors="replace")
        rel = path.relative_to(root).as_posix()

        for m in RAW_POSITION_IN_CALL.finditer(text):
            line_no = text.count("\n", 0, m.start()) + 1
            print(
                f"[ERROR] {rel}:{line_no}: position codeur brute (UDINT_TO_REAL sur HwReal) "
                f"passee directement a un appel de FB — utiliser la position calibree "
                f"(PRG_02_Acquisition.CablePosM1/M2) au lieu du comptage brut (REX 2026-08-06, "
                f"treuil bloque palier 1 en montee).",
                file=sys.stderr,
            )
            errors += 1

        for m in HARDCODED_VALIDITY.finditer(text):
            line_no = text.count("\n", 0, m.start()) + 1
            print(
                f"[WARN] {rel}:{line_no}: '{m.group(1)} := {m.group(2)}' code en dur — "
                f"verifier qu'un signal reel (instHomingM1/M2.Homed, instEncoderAbsM1/M2."
                f"EncoderAvailable, M1_SpeedValid/M2_SpeedValid, ...) n'est pas disponible "
                f"(REX 2026-08-06).",
            )

    print(f"Position calibration wiring check: {'FAIL' if errors else 'PASS'} ({errors} error(s))")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
