#!/usr/bin/env python3
"""G511 - Garde de montee du cycle de referencement : realiste ET non consommee a vide.

Ce gate ECHOUE si :
  1. la garde de montee (CfgTimeoutClimb) est inferieure au temps de montee physique
     minimal requis (course maximale de cable / borne haute de vitesse du palier 1,
     avec marge) -> un cycle echouerait par timeout sans aucun defaut machine ;
  2. la garde n'est pas conditionnee par la MONTER COMMANDEE (compteur « temps mural »
     qui se consomme pendant un arret operateur ou un arret d'urgence) ;
  3. l'etape verrouillee de referencement (HX7) ou ses conditions de capture a l'arret
     (capteur atteint + arret mecanique + commande relachee) ont disparu ;
  4. les cas de test portant ces exigences ont disparu du fichier de test (anti-test-vacuant).

Regle couverte : TASK_CONTRACT_T340_HOMING_LOCKED_ASCENT.yaml (AC1, AC2, AC5, AC6).
Origine : constat A1 du challenge T340 -- garde HX2 = timeout mural de 120 s en dur alors
qu'un trajet reel au palier 1 demande ~146 s (58,5 m a 0,4 m/s), donc echec du cycle
(HXF_FAILED) sans aucun defaut machine.

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

# Marge de securite sur le temps de montee physique minimal (rampes, charge, usure).
MARGE_GARDE = 2.0

# Cas de test qui portent les exigences du lot T340 (etape verrouillee + garde de montee).
TESTS_REQUIS = (
    "TC-P09-H200",
    "TC-P09-H201",
    "TC-P09-H202",
    "TC-P09-H203",
    "TC-P09-H204",
    "TC-P09-H205",
    "TC-P09-H206",
    "TC-P09-H207",
    "TC-P09-H208",
    "TC-P09-H209",
    "TC-P09-H210",
    "TC-P09-H211",
    "TC-P09-H212",
)


def read(root: Path, relative: str) -> str:
    path = root / relative
    if not path.is_file():
        raise FileNotFoundError(relative)
    return path.read_text(encoding="utf-8", errors="replace")


def _time_vers_secondes(litteral: str) -> float | None:
    """Convertit un litteral IEC T#... en secondes (s / ms / m / h)."""
    match = re.fullmatch(r"T#(\d+(?:\.\d+)?)(ms|s|m|h)", litteral)
    if not match:
        return None
    valeur = float(match.group(1))
    return valeur * {"ms": 0.001, "s": 1.0, "m": 60.0, "h": 3600.0}[match.group(2)]


def _gardes_declarees(cfg_source: str) -> tuple[float | None, float | None]:
    """Retourne (garde de montee, garde de descente) declarees dans le type de config, en secondes."""
    def extraire(champ: str) -> float | None:
        match = re.search(rf"{champ}\s*:\s*TIME\s*:=\s*(T#\d+(?:\.\d+)?(?:ms|s|m|h))", cfg_source)
        return _time_vers_secondes(match.group(1)) if match else None

    return extraire("CfgTimeoutClimb"), extraire("CfgTimeoutHomeAxes")


def _geometrie(persist_source: str) -> tuple[float, float]:
    """Retourne (course maximale de cable en m, borne haute de vitesse palier 1 en m/s)."""
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

    # --- 1. Garde de montee realiste (derivee de la geometrie, pas un litteral hors sol) ---
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

    # Le garde-fou doit rester la source unique de la valeur : si un POU la renseigne, ce gate
    # doit etre mis a jour (fail-closed volontaire, jamais un oubli silencieux).
    if re.search(r"CfgTimeoutClimb\s*:=", prg02) or re.search(r"CfgTimeoutHomeAxes\s*:=", prg02):
        errors.append(
            "PRG_02 renseigne CfgTimeoutClimb/CfgTimeoutHomeAxes : la garde doit etre lue "
            "a la nouvelle source dans ce gate (mise a jour consciente requise)"
        )

    # --- 2. Garde consommee UNIQUEMENT pendant le mouvement commande ---
    if "ClimbTimer(IN := ClimbCommandActive" not in fb:
        errors.append("garde de montee non conditionnee par ClimbCommandActive (compteur temps mural)")
    if "HomeAxesTimer(IN := DescentCommandActive" not in fb:
        errors.append("garde de descente non conditionnee par DescentCommandActive (compteur temps mural)")
    if re.search(r"ClimbTimer\(\s*IN\s*:=\s*\(\s*SeqStep", fb):
        errors.append("garde de montee encore armee sur le seul step (forme historiquement fautive)")
    if "ClimbCommandActive := ClimbStepActive AND ClimbPermit" not in fb:
        errors.append("ClimbCommandActive ne depend plus du permis operateur de montee")
    # La garde doit refleter l'ORDRE EMIS, jamais la seule intention : dans l'etape verrouillee,
    # un ordre de montee n'est emis qu'en MAINT_N2 (hors MAINT_N2 l'etape est TENUE sans ordre).
    if "LockedClimbCommand := LockedClimbActive AND ModeIsMaint2" not in fb:
        errors.append(
            "LockedClimbCommand absent : la garde de montee se consommerait sans aucun ordre emis "
            "(etape verrouillee tenue hors MAINT_N2)"
        )
    if "ClimbStepActive := (SeqStep = E_MachineHomingTxState.HX2_CLIMB) OR LockedClimbCommand;" not in fb:
        errors.append("la garde de montee n'est pas keyee sur l'ordre reellement emis (LockedClimbCommand)")

    # --- 3. Etape verrouillee presente, et capture a l'arret conditionnee ---
    if "HX7_LOCKED_REFERENCE" not in enum:
        errors.append("etat HX7_LOCKED_REFERENCE absent de " + CIBLE_ENUM)
    if "E_MachineHomingTxState.HX7_LOCKED_REFERENCE:" not in fb:
        errors.append("etape HX7_LOCKED_REFERENCE non implementee dans le CASE du GRAFCET")
    # Preuve de franchissement : l'etape verrouillee ne s'ouvre que si le capteur haut n'est PAS
    # deja actif (un capteur colle/force ou une machine deja en position haute mene au chemin herite,
    # sinon la capture immediate poserait un datum faux).
    if "IF BucketCloseConfirmedLatched AND NOT TopPositionSensor THEN" not in fb:
        errors.append(
            "entree de l'etape verrouillee non conditionnee a un capteur haut INACTIF : "
            "un capteur deja actif permettrait une capture sans franchissement (datum faux)"
        )
    capture = re.search(r"LockedCaptureAllowed\s*:=\s*LockedSettleActive AND ([^\n]+)", fb)
    if capture is None:
        errors.append("condition de capture LockedCaptureAllowed introuvable")
    else:
        termes = capture.group(1)
        if "WinchesMechanicallyStopped" not in termes:
            errors.append("capture a l'arret non conditionnee par l'arret mecanique confirme")
        if "SeenNeutral" not in termes:
            errors.append("capture a l'arret non conditionnee par le retour au neutre de la commande")
    if 'M1Demand.HomeReq := TRUE' not in fb or 'M2Demand.HomeReq := TRUE' not in fb:
        errors.append("demande de reference conjointe M1/M2 absente")

    # --- 4. Anti-test-vacuant : les cas portant ces exigences existent ---
    return errors


def check_tests(tests: str) -> list[str]:
    return [f"cas de test manquant : {ident}" for ident in TESTS_REQUIS if ident not in tests]


MUTATIONS = (
    ("garde de montee revenue a 120 s en dur",
     lambda src: src.replace("CfgTimeoutClimb      : TIME := T#300s;", "CfgTimeoutClimb      : TIME := T#120s;")),
    ("garde de montee non conditionnee par la commande",
     lambda src: src.replace("ClimbTimer(IN := ClimbCommandActive", "ClimbTimer(IN := ClimbStepActive")),
    ("garde de montee keyee sur l'intention au lieu de l'ordre emis",
     lambda src: src.replace("ClimbStepActive := (SeqStep = E_MachineHomingTxState.HX2_CLIMB) OR LockedClimbCommand;",
                             "ClimbStepActive := (SeqStep = E_MachineHomingTxState.HX2_CLIMB) OR LockedClimbActive;")),
    ("capture a l'arret sans condition d'arret mecanique",
     lambda src: src.replace("LockedCaptureAllowed := LockedSettleActive AND WinchesMechanicallyStopped AND SeenNeutral",
                             "LockedCaptureAllowed := LockedSettleActive AND SeenNeutral")),
    ("capture a l'arret sans condition de retour au neutre",
     lambda src: src.replace("LockedCaptureAllowed := LockedSettleActive AND WinchesMechanicallyStopped AND SeenNeutral",
                             "LockedCaptureAllowed := LockedSettleActive AND WinchesMechanicallyStopped")),
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
    # Mutation sur l'entree de l'etape verrouillee : capteur haut deja actif accepte (datum faux).
    mut_entry = fb.replace("IF BucketCloseConfirmedLatched AND NOT TopPositionSensor THEN",
                           "IF BucketCloseConfirmedLatched THEN")
    if mut_entry == fb:
        failures.append("mutation non appliquee (motif absent) : entree HX7 acceptant un capteur deja actif")
    elif not check_invariant(mut_entry, cfg, enum, persist, prg02):
        failures.append("mutation NON detectee : entree HX7 acceptant un capteur deja actif")
    # Mutation sur le fichier de test (anti-test-vacuant).
    for ident in ("TC-P09-H209", "TC-P09-H212"):
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
        "etape verrouillee HX7 et capture a l'arret conditionnee presentes ; "
        f"{len(TESTS_REQUIS)} cas de test presents."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
