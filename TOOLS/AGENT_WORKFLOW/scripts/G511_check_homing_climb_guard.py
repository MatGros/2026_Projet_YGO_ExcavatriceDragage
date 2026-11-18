#!/usr/bin/env python3
"""G511 - Garde de montee & sequence du cycle de referencement 5 etapes (T417-C).

Ce gate ECHOUE si :
  1. la garde de montee (CfgTimeoutClimb) est inferieure au temps de montee physique
     minimal requis (course maximale de cable / borne haute de vitesse du palier 1,
     avec marge) -> un cycle echouerait par timeout sans aucun defaut machine ;
  2. la garde n'est pas conditionnee par la MONTEE COMMANDEE (compteur « temps mural »
     qui se consomme pendant un arret operateur ou un arret d'urgence) ;
  3. les etapes D1-D7 du GRAFCET 5 etapes ou le preset HX4 8.5m+OffsetCloseM ont disparu ;
  4. les cas de test portant ces exigences ont disparu du fichier de test (anti-test-vacuant).

Usage :
    python TOOLS/AGENT_WORKFLOW/scripts/G511_check_homing_climb_guard.py [racine]
    python TOOLS/AGENT_WORKFLOW/scripts/G511_check_homing_climb_guard.py . --selftest
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

CIBLE_FB = "CODE/G_CYCLE/FB_CycleMachineHoming.st"
CIBLE_CFG = "CODE/G_CYCLE/_TYPES/ST_fbMachineHomingCycle_Cfg.st"
CIBLE_ENUM = "CODE/G_CYCLE/_TYPES/E_MachineHomingTxState.st"
CIBLE_PERSIST = "CODE/GVL_PERSISTENT.st"
CIBLE_PRG02_REEL = "CODE/M_MAIN/PRG_02_Acquisition.st"
CIBLE_TESTS = "TOOLS/TEST_AUTO_CI/RESULTS/G_CYCLE/tests/test_fb_cyclemachinehoming.st"

MARGE_GARDE = 2.0
TESTS_REQUIS = tuple(f"TC-P09-H{i:03d}" for i in range(1, 15))


def read(root: Path, relative: str) -> str:
    path = root / relative
    if not path.is_file():
        raise FileNotFoundError(relative)
    return path.read_text(encoding="utf-8", errors="replace")


def _time_vers_secondes(litteral: str) -> float | None:
    match = re.fullmatch(r"T#(\d+(?:\.\d+)?)(ms|s|m|h)", litteral)
    if not match:
        return None
    valeur = float(match.group(1))
    return valeur * {"ms": 0.001, "s": 1.0, "m": 60.0, "h": 3600.0}[match.group(2)]


def _gardes_declarees(cfg_source: str) -> tuple[float | None, float | None]:
    def extraire(champ: str) -> float | None:
        match = re.search(rf"{champ}\s*:\s*TIME\s*:=\s*(T#\d+(?:\.\d+)?(?:ms|s|m|h))", cfg_source)
        return _time_vers_secondes(match.group(1)) if match else None

    return extraire("CfgTimeoutClimb"), extraire("CfgTimeoutHomeAxes")


def _geometrie(persist_source: str) -> tuple[float, float]:
    haut = re.search(r"CfgTopSensorPos_M\s*:=\s*(-?\d+(?:\.\d+)?)", persist_source)
    bas = re.search(r"CfgCableLimitDescent_M\s*:=\s*(-?\d+(?:\.\d+)?)", persist_source)
    vitesse = re.search(r"SpeedBandMaxMps\s*:=\s*\[\s*(\d+(?:\.\d+)?)", persist_source)
    manquants = [
        nom
        for nom, match in (("CfgTopSensorPos_M", haut), ("CfgCableLimitDescent_M", bas),
                           ("SpeedBandMaxMps[1]", vitesse))
        if match is None
    ]
    if manquants:
        raise ValueError("repere(s) introuvable(s) dans GVL_PERSISTENT : " + ", ".join(manquants))
    course = float(haut.group(1)) - float(bas.group(1))
    return course, float(vitesse.group(1))


def check_invariant(fb: str, cfg: str, enum: str, persist: str, prg02: str) -> list[str]:
    errors: list[str] = []

    garde_montee, garde_descente = _gardes_declarees(cfg)
    if garde_montee is None:
        errors.append("CfgTimeoutClimb introuvable ou sans defaut TIME dans " + CIBLE_CFG)
    else:
        course, vitesse = _geometrie(persist)
        if vitesse <= 0.0:
            errors.append("borne haute de vitesse du palier 1 nulle ou negative dans " + CIBLE_PERSIST)
        else:
            minimum_requis = course / vitesse * MARGE_GARDE
            if garde_montee < minimum_requis:
                errors.append(
                    f"garde de montee {garde_montee:.0f} s < minimum physique "
                    f"{minimum_requis:.1f} s (course {course:.1f} m / {vitesse:.2f} m/s x marge {MARGE_GARDE:.0f})"
                )
    if garde_descente is None:
        errors.append("CfgTimeoutHomeAxes introuvable ou sans defaut TIME dans " + CIBLE_CFG)

    if re.search(r"CfgTimeoutClimb\s*:=", prg02) or re.search(r"CfgTimeoutHomeAxes\s*:=", prg02):
        errors.append(
            "PRG_02 renseigne CfgTimeoutClimb/CfgTimeoutHomeAxes : la garde doit etre lue "
            "a la nouvelle source dans ce gate (mise a jour consciente requise)"
        )

    if "ClimbTimer(IN := ClimbCommandActive" not in fb:
        errors.append("garde de montee non conditionnee par ClimbCommandActive (compteur temps mural)")
    if re.search(r"ClimbTimer\(\s*IN\s*:=\s*\(\s*SeqStep", fb):
        errors.append("garde de montee encore armee sur le seul step (forme historiquement fautive)")
    if "ClimbCommandActive := ClimbStepActive AND ClimbPermit" not in fb:
        errors.append("ClimbCommandActive ne depend plus du permis operateur de montee")
    if "ClimbStepActive    := (SeqStep = E_MachineHomingTxState.HX2_CLIMB_TO_TOP);" not in fb and "ClimbStepActive := (SeqStep = E_MachineHomingTxState.HX2_CLIMB_TO_TOP);" not in fb:
        errors.append("ClimbStepActive non lie a HX2_CLIMB_TO_TOP")

    for state in (
        "HX0_REPOS", "HX1_BUCKET_PREPARE", "HX2_CLIMB_TO_TOP",
        "HX3_TOP_CLEARANCE", "HX4_FINAL_CONFIRM", "HX7_FAILED"
    ):
        if state not in enum:
            errors.append(f"etat {state} absent de {CIBLE_ENUM}")
        if f"E_MachineHomingTxState.{state}:" not in fb:
            errors.append(f"etape {state} non implementee dans le CASE du GRAFCET")

    if "M1Demand.HomeReq          := TRUE" not in fb and "M1Demand.HomeReq := TRUE" not in fb:
        errors.append("demande de reference M1 absente en HX4")
    if "M2Demand.HomeReq          := TRUE" not in fb and "M2Demand.HomeReq := TRUE" not in fb:
        errors.append("demande de reference M2 absente en HX4")

    return errors


def check_tests(tests: str) -> list[str]:
    return [f"cas de test manquant : {ident}" for ident in TESTS_REQUIS if ident not in tests]


MUTATIONS = (
    ("garde de montee revenue a 120 s en dur",
     lambda src: src.replace("CfgTimeoutClimb         : TIME := T#300s;", "CfgTimeoutClimb         : TIME := T#120s;")),
    ("garde de montee non conditionnee par la commande",
     lambda src: src.replace("ClimbTimer(IN := ClimbCommandActive", "ClimbTimer(IN := ClimbStepActive")),
    ("demande de reference M1 supprimee",
     lambda src: src.replace("M1Demand.HomeReq          := TRUE;", "M1Demand.HomeReq          := FALSE;")),
)


def selftest(cfg: str, fb: str, enum: str, persist: str, prg02: str, tests: str) -> list[str]:
    failures: list[str] = []
    if check_invariant(fb, cfg, enum, persist, prg02) or check_tests(tests):
        failures.append("source de reference deja non conforme : selftest non concluant")
        return failures
    for label, mutate in MUTATIONS:
        if label.startswith("garde de montee revenue"):
            mutated = mutate(cfg)
            detecte = bool(check_invariant(fb, mutated, enum, persist, prg02))
        else:
            mutated = mutate(fb)
            detecte = bool(check_invariant(mutated, cfg, enum, persist, prg02))
        if mutated == (cfg if label.startswith("garde de montee revenue") else fb):
            failures.append(f"mutation non appliquee (motif absent) : {label}")
        elif not detecte:
            failures.append(f"mutation NON detectee : {label}")

    for ident in ("TC-P09-H001", "TC-P09-H007", "TC-P09-H014"):
        mut_tests = tests.replace(ident, "TC-P09-HXXX")
        if mut_tests == tests:
            failures.append(f"mutation non appliquee (motif absent) : cas de test {ident}")
        elif not check_tests(mut_tests):
            failures.append(f"mutation NON detectee : cas de test {ident} supprime")
    return failures


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = Path(args[0] if args else ".").resolve()
    try:
        fb = read(root, CIBLE_FB)
        cfg = read(root, CIBLE_CFG)
        enum = read(root, CIBLE_ENUM)
        persist = read(root, CIBLE_PERSIST)
        prg02 = read(root, CIBLE_PRG02_REEL)
        tests = read(root, CIBLE_TESTS)
    except FileNotFoundError as exc:
        print(f"G511 FAIL: fichier absent: {exc}")
        return 1

    try:
        errors = check_invariant(fb, cfg, enum, persist, prg02) + check_tests(tests)
    except ValueError as exc:
        print(f"G511 FAIL: {exc}")
        return 1

    if "--selftest" in sys.argv:
        errors += [f"selftest : {f}" for f in selftest(cfg, fb, enum, persist, prg02, tests)]

    if errors:
        for erreur in errors:
            print(f"G511 FAIL: {erreur}")
        return 1

    garde, _ = _gardes_declarees(cfg)
    course, vitesse = _geometrie(persist)
    print(
        "G511 PASS: garde de montee "
        f"{garde:.0f} s >= minimum physique {course / vitesse * MARGE_GARDE:.1f} s "
        f"(course {course:.1f} m, {vitesse:.2f} m/s, marge {MARGE_GARDE:.0f}) ; "
        "consommee uniquement pendant la montee commandee ; "
        "sequence 5 etapes complete (HX0..HX4 + HX7_FAILED) et "
        f"{len(TESTS_REQUIS)} cas de test presents."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
