#!/usr/bin/env python3
"""G507 - Garde-fou T295 : le watchdog de timeout benne ne consomme QUE du temps de commande
operateur REELLEMENT engagee (semantique a2 : temps SUSPENDU hors engagement, jamais remis a
zero au relachement), sans jamais etre neutralise.

Cause racine corrigee (T295, 2026-09-20) : `TonTimeout(IN := Lifecycle.Busy)` comptait du temps
MURAL depuis l'armement de la manoeuvre. `Lifecycle.Busy` reste vrai pendant toute la manoeuvre,
donc les pauses operateur legitimes (relachement du joystick en AX3_OPEN_BUCKET / AX15B_DUMP_OPEN)
etaient imputees au budget de CfgTimeoutDuration -> faux [BENNE] ErrorID:03 (cause 2), latche.

Ce gate ECHOUE si :
  1. le TON de timeout est de nouveau arme sans terme d'engagement operateur
     (retour a `IN := Lifecycle.Busy` seul) ;
  2. l'engagement n'est plus defini comme `Lifecycle.Busy AND MotionRequestActive` ;
  3. le PT du TON ne derive plus de `CfgTimeoutDuration` (litteral T# en dur, budget fige) ;
  4. le cumul du temps engage n'est plus GELE au relachement (semantique a1 = remise a zero) ;
  5. la remise a zero du cumul a disparu (fin de manoeuvre / Reset sur front) ;
  6. le latch de la cause 2 ou le defaut declare de `CfgTimeoutDuration` ont ete modifies ;
  7. les tests CI T295 (commande continue, pause sans defaut, cumul, arrivee nominale) ont
     disparu, OU ne pilotent pas les VRAIES entrees (ReqAscent/ReqDescend) — un test qui ne
     pilote que l'argument nomme `MotionRequestActive` est VACUANT (STruCpp l'ignore : c'est un
     VAR local de FB_Bucket, pas un VAR_INPUT).

REX « garde-fou mort-ne » (G490/G499) : ce gate est BRANCHE dans PLANS de run_all_gates.py.

Usage :
    python TOOLS/AGENT_WORKFLOW/scripts/G507_check_t295_bucket_timeout_engaged.py [racine]
    python TOOLS/AGENT_WORKFLOW/scripts/G507_check_t295_bucket_timeout_engaged.py . --selftest
"""

from pathlib import Path
import re
import sys

BUCKET = "CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st"
TESTS = "TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_bucket.st"

REQUIRED_TESTS = ("TC-P10-046.1", "TC-P10-046.2", "TC-P10-046.3", "TC-P10-046.4")


def read(root: Path, relative: str) -> str:
    path = root / relative
    if not path.is_file():
        raise FileNotFoundError(relative)
    return path.read_text(encoding="utf-8")


def check_bucket_timeout(source: str) -> list[str]:
    """Controles statiques de l'invariant T295 sur le source de FB_Bucket."""
    errors: list[str] = []

    # -- TON de timeout : une seule occurrence armée (avec PT), les autres sont des remises a FALSE
    armed = [body for body in re.findall(r"TonTimeout\s*\((.*?)\)\s*;", source, re.DOTALL)
             if re.search(r"\bPT\s*:=", body)]
    if not armed:
        errors.append("appel arme TonTimeout(IN := ..., PT := ...) introuvable")
        return errors
    if len(armed) > 1:
        errors.append(f"{len(armed)} appels armes TonTimeout(...) : un seul watchdog autorise")
    body = armed[0]

    in_match = re.search(r"\bIN\s*:=\s*(.*?)(?:,\s*\bPT\s*:=|$)", body, re.DOTALL)
    pt_match = re.search(r"\bPT\s*:=\s*(.*?)$", body, re.DOTALL)
    in_expr = " ".join(in_match.group(1).split()) if in_match else ""
    pt_expr = " ".join(pt_match.group(1).split()) if pt_match else ""

    # -- 1/2. Engagement operateur : `Lifecycle.Busy AND MotionRequestActive`
    engage = re.search(r"(\w+)\s*:=\s*Lifecycle\.Busy\s+AND\s+MotionRequestActive\s*;", source)
    if not engage:
        errors.append(
            "engagement operateur introuvable : attendu `<Var> := Lifecycle.Busy AND MotionRequestActive;`"
        )
    else:
        engage_var = engage.group(1)
        if engage_var not in in_expr:
            errors.append(
                f"TON de timeout arme SANS terme d'engagement operateur "
                f"(IN := {in_expr or '<vide>'} ; attendu : {engage_var})"
            )
    if "Lifecycle.Busy" in in_expr and "MotionRequestActive" not in in_expr and not engage:
        errors.append("TON de timeout de nouveau arme sur le seul Lifecycle.Busy")

    # -- 3. Le budget reste CfgTimeoutDuration, jamais un litteral fige
    pt_var = re.fullmatch(r"\w+", pt_expr)
    if pt_var is None:
        errors.append(f"PT du TON de timeout n'est plus une variable de budget (PT := {pt_expr or '<vide>'})")
    elif not re.search(rf"\b{pt_var.group(0)}\s*:=\s*CfgTimeoutDuration\s*-", source):
        errors.append(
            f"PT du TON de timeout ne derive plus de CfgTimeoutDuration "
            f"(PT := {pt_expr} ; attendu : {pt_expr} := CfgTimeoutDuration - <cumul>)"
        )
    if "T#" in pt_expr:
        errors.append(f"PT du TON de timeout fige par un litteral (PT := {pt_expr})")
    if not re.search(r"\w+\s*<\s*T#0s", source):
        errors.append("garde anti-PT-negatif absente (budget restant non borne a T#0s)")

    # -- 4. Cumul GELE au relachement (a2), jamais remis a zero a chaque relachement (a1)
    if not re.search(r"(\w+)\s*:=\s*\1\s*\+\s*\w+\s*;", source):
        errors.append(
            "cumul du temps engage introuvable : la suspension (a2) a disparu "
            "(le TON serait de nouveau remis a zero a chaque relachement)"
        )
    if not re.search(r"IF\s+NOT\s+\w+\s+THEN\s+(\w+)\s*:=\s*\1\s*\+\s*\w+\s*;", source, re.DOTALL):
        errors.append("gel du cumul hors engagement absent (cumul non suspendu)")

    # -- 5. Remise a zero : fin de manoeuvre et Reset sur front
    zeros = re.findall(r"(\w*Accum\w*)\s*:=\s*T#0s\s*;", source)
    if len(zeros) < 2:
        errors.append("remise a zero du cumul absente ou incomplete (fin de manoeuvre et/ou Reset sur front)")
    if not re.search(r"IF\s+ResetEdge\.Q\s+THEN", source):
        errors.append("remise a zero du cumul sur Reset sur front absente")
    if not re.search(r"IF\s+NOT\s+Lifecycle\.Busy\s+THEN[\s\S]{0,200}?T#0s\s*;", source):
        errors.append("remise a zero du cumul en fin de manoeuvre (Lifecycle.Busy retombe) absente")

    # -- 6. Elements actes comme INCHANGES (contrat T295)
    if "instCauses[2].Latching := TRUE;" not in source:
        errors.append("instCauses[2].Latching := TRUE absent (latch de la cause timeout modifie)")
    if "TimeoutFaultLatched := TRUE;" not in source:
        errors.append("armement de TimeoutFaultLatched absent")
    if not re.search(r"CfgTimeoutDuration\s*:\s*TIME\s*:=\s*T#60s\s*;", source):
        errors.append("defaut FB CfgTimeoutDuration := T#60s modifie (interdit par le contrat T295)")

    return errors


def check_tests(test_source: str) -> list[str]:
    """Presence ET pouvoir discriminant des tests T295 (anti-test-vacuant)."""
    errors: list[str] = []
    for name in REQUIRED_TESTS:
        if f"TEST '{name}" not in test_source:
            errors.append(f"test {name} absent de {TESTS}")
            continue
        block = re.search(rf"TEST '({re.escape(name)}[^\n]*)\n(.*?)END_TEST", test_source, re.DOTALL)
        if not block:
            errors.append(f"corps du test {name} illisible")
            continue
        body = block.group(2)
        # Le pilotage doit passer par les VRAIES entrees, jamais par l'argument nomme inerte.
        if not re.search(r"\bReq(Ascent|Descend)\s*:=\s*TRUE", body):
            errors.append(f"{name} : aucune commande via les vraies entrees (ReqAscent/ReqDescend := TRUE)")
        if "MotionRequestActive" in body and not re.search(r"\bReq(Ascent|Descend)\s*:=\s*(TRUE|FALSE)", body):
            errors.append(f"{name} : pilotage par l'argument nomme MotionRequestActive (ignore par STruCpp) -> test vacuant")
        if name in ("TC-P10-046.2", "TC-P10-046.3", "TC-P10-046.4"):
            if not re.search(r"\bReq(Ascent|Descend)\s*:=\s*FALSE", body):
                errors.append(f"{name} : la pause operateur ne relache pas une vraie entree (ReqAscent/ReqDescend := FALSE)")
    return errors


# Mutations synthetiques : le gate doit les REJETER (preuve de pouvoir discriminant).
MUTATIONS = (
    (
        "a2 -> a1 (remise a zero au relachement)",
        lambda src: re.sub(r"IF NOT TimeoutEngaged THEN[\s\S]*?END_IF;", "TimeoutSegmentTime := T#0s;",
                           src, count=1),
    ),
    (
        "engagement supprime (TON arme sur le seul Lifecycle.Busy)",
        lambda src: src.replace("TimeoutEngaged AND NOT TimeoutRestart", "Lifecycle.Busy"),
    ),
    (
        "PT fige par un litteral",
        lambda src: src.replace("PT := TimeoutRemainingTime", "PT := T#60s"),
    ),
    (
        "latch de la cause 2 retire",
        lambda src: src.replace("instCauses[2].Latching := TRUE;", "instCauses[2].Latching := FALSE;"),
    ),
)


def selftest(source: str) -> list[str]:
    failures: list[str] = []
    if check_bucket_timeout(source):
        failures.append("source de reference deja non conforme : selftest non concluant")
    for label, mutate in MUTATIONS:
        mutated = mutate(source)
        if mutated == source:
            failures.append(f"mutation non appliquee (motif absent) : {label}")
            continue
        if not check_bucket_timeout(mutated):
            failures.append(f"mutation NON detectee : {label}")
    return failures


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    root = Path(args[0] if args else ".").resolve()

    try:
        source = read(root, BUCKET)
        tests = read(root, TESTS)
    except FileNotFoundError as exc:
        print(f"G507 FAIL: fichier absent: {exc}")
        return 1

    errors = check_bucket_timeout(source) + check_tests(tests)

    if "--selftest" in sys.argv:
        errors += [f"selftest : {f}" for f in selftest(source)]

    if errors:
        for error in errors:
            print(f"G507 FAIL: {error}")
        return 1

    print("G507 PASS: timeout benne = temps de commande engagee seul (suspension a2, latch conserve)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
