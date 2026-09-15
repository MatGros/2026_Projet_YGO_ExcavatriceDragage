#!/usr/bin/env python3
"""G499 - Contrat statique T289 pour la temporisation d'egouttage AX13."""
from pathlib import Path
import re
import sys


def read(root: Path, relative: str) -> str:
    path = root / relative
    if not path.is_file():
        raise FileNotFoundError(relative)
    return path.read_text(encoding="utf-8")


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    errors: list[str] = []

    try:
        cfg = read(root, "CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCfg.st")
        state = read(root, "CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleState.st")
        public = read(root, "CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_SequencePublicState.st")
        cycle = read(root, "CODE/G_CYCLE/FB_CycleSemiAuto.st")
        prg03 = read(root, "CODE/M_MAIN/PRG_03_Modes_Cycle.st")
        prg07 = read(root, "CODE/M_MAIN/PRG_07_Supervision.st")
    except FileNotFoundError as exc:
        print(f"G499 FAIL: fichier absent: {exc}")
        return 1

    if not re.search(r"\bDrainTime_S\s*:\s*INT\s*:=\s*5\s*;", cfg):
        errors.append("ST_CycleCfg.DrainTime_S INT par defaut a 5 absent")
    if re.search(r"\bDrainTime\s*:\s*TIME\b", cfg):
        errors.append("ancien faux parametre ST_CycleCfg.DrainTime TIME encore present")
    if "CycleDrainTimeEffective_S := LIMIT(1, GVL_IHM.CycleSemiAuto.Cfg.DrainTime_S, 3600);" not in prg03:
        errors.append("borne 1..3600 absente avant consommation")
    if "DINT_TO_TIME(INT_TO_DINT(CycleDrainTimeEffective_S) * DINT#1000)" not in prg03:
        errors.append("conversion secondes vers TIME absente")
    if "CfgDrainTime            := CycleDrainTimeEffective" not in prg03:
        errors.append("FB_CycleSemiAuto non alimente par la consigne convertie")
    if "DrainTimeElapsed := DrainingTimer.ET;" not in cycle:
        errors.append("temps ecoule non produit depuis DrainingTimer.ET")
    if "IF DrainingTimer.Q OR SkipDrainEdge.Q THEN" not in cycle:
        errors.append("transition AX13 par TON ou Skip introuvable")
    if "DrainTimeElapsed    : TIME;" not in public:
        errors.append("champ TIME absent du bus public")
    if "DrainTimeElapsed_S     : INT;" not in state:
        errors.append("champ INT secondes absent de l'etat IHM")
    if prg03.count("Data.SequenceState.DrainTimeElapsed") < 3:
        errors.append("mapping SEMI_AUTO et remises a zero hors mode incomplets")
    if "TIME_TO_DINT(PRG_03_Modes_Cycle.Data.SequenceState.DrainTimeElapsed) / DINT#1000" not in prg07:
        errors.append("conversion elapsed TIME vers secondes absente")

    if errors:
        for error in errors:
            print(f"G499 FAIL: {error}")
        return 1

    print("G499 PASS: DrainTime_S unique [1..3600], conversion TON et elapsed IHM relies")
    return 0


if __name__ == "__main__":
    sys.exit(main())
