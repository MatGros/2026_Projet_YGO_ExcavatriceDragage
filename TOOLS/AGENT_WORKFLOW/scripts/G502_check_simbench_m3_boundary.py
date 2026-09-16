#!/usr/bin/env python3
"""G502 - Contrat T300 : le SimBench M3 reste a la frontiere HwSim -> HwIn.

Le modele de translation est un producteur d'image simulee uniquement. Il ne doit
ni alimenter directement les etats metier, ni contourner les sorties finales
post-interlock. Le garde couvre aussi la consommation PRG_05 : le decodeur doit
lire HwIn et TranslationState doit reprendre ce decodeur. Il reste statique : la
trace CODESYS demeure la preuve d'ordonnancement et de comportement runtime.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


M3_INPUT_ASSIGNMENT = re.compile(
    r"^\s*(?:HwSim|HwIn)\.Translation\.M3_(?:PosTremie|PosPV|PosPVP2|PosP1|PosMaintenance)_DI\s*:=",
    re.MULTILINE,
)


def read(root: Path, relative: str) -> str:
    path = root / relative
    if not path.is_file():
        raise FileNotFoundError(relative)
    return path.read_text(encoding="utf-8", errors="replace")


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    errors: list[str] = []
    prg02_relative = "CODE/M_MAIN/PRG_02_Acquisition.st"
    prg05_relative = "CODE/M_MAIN/PRG_05_Translation.st"
    prg07_relative = "CODE/M_MAIN/PRG_07_Supervision.st"
    simbench_relative = "CODE/L_SIMULATION/FB_SimBench.st"
    translation_relative = "CODE/L_SIMULATION/FB_Sim_Translation.st"

    try:
        prg02 = read(root, prg02_relative)
        simbench = read(root, simbench_relative)
        translation = read(root, translation_relative)
        prg05 = read(root, prg05_relative)
        prg07 = read(root, prg07_relative)
    except FileNotFoundError as exc:
        print(f"G502 FAIL: fichier absent: {exc}")
        return 1

    if prg02.count("HwSim.Translation := instSimBench.Translation;") != 1:
        errors.append("pont unique instSimBench.Translation -> HwSim.Translation absent ou multiple")
    if prg02.count("HwIn.Translation := SEL(TranslationInputSourceSimulated, HwReal.Translation, HwSim.Translation);") != 1:
        errors.append("selection unique HwReal/HwSim -> HwIn.Translation absente ou multiple")
    if "SimulationModeRise(CLK := GVL_Simulation.SimulationModeActive);" not in prg02:
        errors.append("armement du domaine simulation sur front montant absent")
    if "IF SimulationModeRise.Q THEN" not in prg02 or "IF SimulationModeFall.Q THEN" not in prg02:
        errors.append("activation/desactivation des domaines simulation hors fronts ou incomplete")
    if "CycleTimeS := LIMIT(0.001, instCycleTime.CycleTimeS, 0.100);" not in translation:
        errors.append("pas de simulation M3 non documente ou borne a 100 ms absent")
    if prg07.count("GVL_IHM.IoHw.In.Hardware := PRG_02_Acquisition.HwIn;") != 1:
        errors.append("miroir IHM/Trace IoHw.In.Hardware doit exposer HwIn arbitre")

    for required in (
        "M3_ReqTremie            := M3_CommandWord = 1",
        "M3_ReqMaintenance       := M3_CommandWord = 2",
        "M3_BrakeCmd              := PRG_06_Outputs.Data.TranslationBrakeCmd",
    ):
        if required not in prg02:
            errors.append(f"commande finale post-interlock absente de PRG_02: {required}")

    for required in (
        "SensorTremie      := PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI",
        "SensorPV          := PRG_02_Acquisition.HwIn.Translation.M3_PosPV_DI",
        "SensorP2          := PRG_02_Acquisition.HwIn.Translation.M3_PosPVP2_DI",
        "SensorP1          := PRG_02_Acquisition.HwIn.Translation.M3_PosP1_DI",
        "SensorMaintenance := PRG_02_Acquisition.HwIn.Translation.M3_PosMaintenance_DI",
    ):
        if required not in prg05:
            errors.append(f"decodeur M3 ne lit plus HwIn dans PRG_05: {required}")

    for required in (
        "TranslationState.SensorsWord := instPosDecoderM3.SensorsWord;",
        "TranslationState.SensorWordIncoherent := instPosDecoderM3.Incoherent;",
        "TranslationState.PositionTremie := instPosDecoderM3.TranslationPosTremie;",
        "TranslationState.PositionMaintenance := instPosDecoderM3.TranslationPosMaintenance;",
    ):
        if required not in prg05:
            errors.append(f"etat M3 ne derive plus du decodeur dans PRG_05: {required}")

    for forbidden in (
        "PRG_05_Translation.st",
        "FB_Translation_PositionDecoder.st",
        "FB_Safety_Translation.st",
    ):
        text = read(root, f"CODE/I_TRANSLATION/{forbidden}") if forbidden.startswith("FB_") else read(root, f"CODE/M_MAIN/{forbidden}")
        if "GVL_Simulation.SimM3" in text:
            errors.append(f"injection GVL_Simulation.SimM3 interdite dans {forbidden}")

    for path in sorted((root / "CODE").rglob("*.st")):
        relative = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace")
        if relative == simbench_relative:
            continue
        for match in M3_INPUT_ASSIGNMENT.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            errors.append(f"ecriture DI M3 hors SimBench: {relative}:{line}")

    if simbench.count("Translation.M3_PosTremie_DI") != 2:
        errors.append("publication PosTremie doit rester limitee aux branches override/modele")
    if "instSimTranslation.PosTremie" not in simbench:
        errors.append("branche modele du SimBench ne publie plus PosTremie")

    if errors:
        for error in errors:
            print(f"G502 FAIL: {error}")
        return 1

    print("G502 PASS: M3 traverse sorties finales -> SimBench -> HwSim -> HwIn -> miroir IoHw -> decodeur PRG_05")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
