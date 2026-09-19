#!/usr/bin/env python3
"""Garde-fou T262 : plafond AX10 M2 proportionnel, borné par AX11."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def require(path: Path, fragment: str, label: str) -> bool:
    text = path.read_text(encoding="utf-8")
    if fragment in text:
        print(f"[OK] {label}")
        return True
    print(f"[KO] {label}: fragment attendu absent dans {path.relative_to(ROOT)}")
    return False


def main() -> int:
    cfg = ROOT / "CODE/H_TREUILS_BENNE/_TYPES/ST_fbWinchCmdArbitration_Cfg.st"
    context = ROOT / "CODE/H_TREUILS_BENNE/_TYPES/ST_fbWinchCmdArbitration_Context.st"
    arbiter = ROOT / "CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM2.st"
    prg04 = ROOT / "CODE/M_MAIN/PRG_04_Treuils_Benne.st"
    bucket = ROOT / "CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st"
    cycle = ROOT / "CODE/G_CYCLE/FB_CycleSemiAuto.st"
    prg03 = ROOT / "CODE/M_MAIN/PRG_03_Modes_Cycle.st"
    prg06 = ROOT / "CODE/M_MAIN/PRG_06_Outputs.st"

    checks = [
        require(cfg, "BucketAutoMaxStepUp       : INT := 1;", "Configuration dédiée AX10 présente"),
        require(context, "BucketAutoCloseActive           : BOOL;", "Contexte AX10 présent"),
        require(
            arbiter,
            "ELSIF ReqAscent AND Context.BucketAutoCloseActive THEN\n"
            "            StepTgt := MIN(BucketRequestedStep, Cfg.BucketAutoMaxStepUp);",
            "AX10 conserve le joystick et applique uniquement son plafond",
        ),
        require(
            prg04,
            "ArbContext.BucketAutoCloseActive          := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.SEMI_AUTO)\n"
            "    AND (PRG_03_Modes_Cycle.Data.SequenceState.Step = E_AutoCycleStep.AX10_CLOSE_BUCKET)\n"
            "    AND PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.ReqClose;",
            "Activation strictement limitée à AX10 SEMI_AUTO",
        ),
        require(
            prg04,
            "ArbM2Cfg.BucketAutoMaxStepUp       := LIMIT(1, GVL_IHM.CycleSemiAuto.Cfg.CtrlAscentMaxStep, 2);",
            "Plafond AX10 aligné sur la configuration AX11 P1..P2",
        ),
        require(
            prg04,
            "IF ArbContext.BucketAutoCloseActive THEN\n"
            "        M2MaxStepUp := MIN(M2MaxStepUp, LIMIT(1, GVL_IHM.CycleSemiAuto.Cfg.CtrlAscentMaxStep, 2));",
            "Clamp final M2 conserve le plafond AX10 sans relever les protections amont",
        ),
        require(
            prg04,
            "OR (BucketNotClosedAscentCapStep1 AND NOT ArbContext.BucketAutoCloseActive) THEN",
            "Plafond benne non fermée ne réécrase pas AX10 actif",
        ),
    ]
    checks.extend([
        require(bucket, "HoldAscentP1AfterClose", "FB_Bucket porte le maintien AX10B explicite"),
        require(bucket, "CloseReached", "FB_Bucket publie la fermeture atteinte sans faux Done"),
        require(cycle, "E_AutoCycleStep.AX10B_RACCORDEMENT_P1", "Cycle possede une etape AX10B nommee sans ambiguite"),
        require(cycle, "WinchM1Cmd.RunRequest := TRUE; WinchM1Cmd.ReqAscent := TRUE;", "Transfert demande M1 P1 explicitement"),
        require(cycle, "WinchM2Cmd.RunRequest := TRUE; WinchM2Cmd.ReqAscent := TRUE;", "Transfert demande M2 P1 explicitement"),
        require(cycle, "CST_Ax10bHandoffWaitTime : TIME := T#2s;", "Repli borne si M1 indisponible"),
        require(prg03, "M1FinalAscentStartReady := PRG_06_Outputs.Data.M1AscentStartReady", "Disponibilite finale M1 retournee au cycle"),
        require(prg06, "AND (instWinchOutputInterlockM1.DeadTimeElapsed >= T#700ms);", "Disponibilite finale exige la purge du temps mort maximal"),
    ])
    return 0 if all(checks) else 1


if __name__ == "__main__":
    sys.exit(main())
