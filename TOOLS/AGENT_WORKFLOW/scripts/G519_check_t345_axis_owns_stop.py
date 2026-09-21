#!/usr/bin/env python3
"""G519 - L'axe possede son arret : verrou d'arrivee non annulable par la demande (T345 lot L1).

Classe de bug couverte (terrain 2026-09-21, AX2, translation M3, arrivee P1) : le
sequenceur retire sa demande sur le jeton d'arrivee, soit environ 9 scans AVANT la fin du
debounce de 100 ms de FB_Translation. Le sens d'arrivee etait alors capture sur
CommandedTremie/CommandedMaintenance, deux locaux deja remis a FALSE par cette perte de
demande : le verrou d'arrivee s'armait donc sans sens memorise et la condition de
relachement acceptait une demande du MEME sens. Consequence : rebond du capteur -> la
demande est re-armee -> le verrou est relache -> le chariot repart -> Translation_Busy
repasse a TRUE -> la confirmation d'arret de 500 ms de la porte de cycle ne s'arme JAMAIS
et le chariot depasse le point d'arrete.

Ce gate lit les SOURCES REELLES (le harnais CI FB_TestHarness_PRG_05 est un stub miroir :
il ne compile pas PRG_05_Translation.st, voir run_tests.py `source_prg`), et refuse toute
regression des invariants qui portent l'autorite d'arret de l'axe.

Controles
---------
AC1  FB_Translation : le sens du dernier mouvement est memorise par l'axe, independamment
     de la demande.
AC2  FB_Translation : l'armement du verrou d'arrivee qualifie le sens sur cette memoire
     quand la demande est deja retombee.
AC3  FB_Translation : le verrou d'arrivee reste relachable UNIQUEMENT par une demande
     explicite de sens inverse (autorite de l'axe, comportement a conserver).
AC4  FB_Translation : le fait public d'arret confirme n'est pas vacuaire — verrou d'arrivee
     ET absence de rotation reelle ET frein non commande ouvert ET aucun defaut.
AC5  FB_Translation : ce fait est remis a FALSE dans la gate de neutralisation NOT Enable.
AC6  PRG_05 : la perte de la demande n'efface plus la cible deja qualifiee (memoire de code
     de cible) ; la cible ne retombe que sur le jeton du point memorise.
AC7  PRG_05 : les DEUX points de consommation du bypass de fin de course (FB_Translation et
     FB_Safety_Translation) sont gated par le mode MAINT_N2.
AC8  PRG_05 : l'origine de ce gate est l'arbitrage FB_Modes (Auth.Mode), jamais le
     selecteur IHM brut.

Usage :
    python G519_check_t345_axis_owns_stop.py [racine] [--report] [--selftest]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FB_TRANSLATION = ROOT / "CODE" / "I_TRANSLATION" / "FB_Translation.st"
PRG05 = ROOT / "CODE" / "M_MAIN" / "PRG_05_Translation.st"


def strip_comments(text: str) -> str:
    """Retire les commentaires ST : un motif recopie dans un commentaire ne vaut pas preuve."""
    text = re.sub(r"\(\*.*?\*\)", " ", text, flags=re.DOTALL)
    text = re.sub(r"//[^\n]*", " ", text)
    return text


def compact(text: str) -> str:
    return re.sub(r"\s+", " ", text)


def read(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(f"[G519] FAIL - {path} introuvable")
    return path.read_text(encoding="utf-8", errors="replace")


def check_fb_translation(text: str) -> list[str]:
    errors: list[str] = []
    body = compact(strip_comments(text))

    # AC1 - memoire de sens du dernier mouvement commande (mise a jour inconditionnelle).
    mem = re.search(
        r"IF CommandedTremie THEN (\w+) := 1; ELSIF CommandedMaintenance THEN \1 := -1; END_IF",
        body,
    )
    if mem is None:
        errors.append(
            "AC1 aucune memoire de sens du dernier mouvement : le sens d'arrivee ne peut pas "
            "survivre a la perte de la demande"
        )
        memory = None
    else:
        memory = mem.group(1)

    # AC2 - qualification du sens d'arrivee sur cette memoire.
    if memory:
        if not re.search(rf"ArrivalWasTremie := \({memory} = 1\)", body):
            errors.append(f"AC2 ArrivalWasTremie non qualifie par la memoire {memory}")
        if not re.search(rf"ArrivalWasMaintenance := \({memory} = -1\)", body):
            errors.append(f"AC2 ArrivalWasMaintenance non qualifie par la memoire {memory}")
        if not re.search(r"IF ArrivalEdge\.Q THEN ArrivalLock := TRUE; IF CommandedTremie OR CommandedMaintenance THEN", body):
            errors.append(
                "AC2 l'armement du verrou ne distingue plus le cas 'demande deja retombee' : "
                "les deux drapeaux seraient FALSE et le verrou serait relachable dans le meme sens"
            )

    # AC3 - relachement par sens inverse uniquement.
    if not re.search(
        r"IF ArrivalLock AND \(\(ReqTremie AND NOT ArrivalWasTremie\) OR "
        r"\(ReqMaintenance AND NOT ArrivalWasMaintenance\)\) THEN ArrivalLock := FALSE; END_IF",
        body,
    ):
        errors.append(
            "AC3 la condition de relachement par sens inverse a disparu ou a change de forme "
            "(regle de conservation du lot)"
        )

    # AC4 - fait public d'arret confirme, non vacuaire.
    fact = re.search(r"ArrivalStopConfirmed := (ArrivalLock.*?);", body)
    if fact is None:
        errors.append("AC4 fait public ArrivalStopConfirmed absent ou non derive du verrou d'arrivee")
    else:
        expr = fact.group(1)
        for term, label in (
            ("ArrivalLock", "verrou d'arrivee"),
            ("ABS(DriveActualFreqHz) <= 0.5", "absence de rotation reelle"),
            ("NOT BrakeReleaseRequest", "frein non commande ouvert"),
            ("NOT Fault.Error", "aucun defaut"),
        ):
            if term not in expr:
                errors.append(f"AC4 terme manquant dans ArrivalStopConfirmed ({label}) : {term}")

    # AC5 - remise a FALSE dans la gate de neutralisation.
    gate = re.search(r"IF NOT Enable THEN(.*?)RETURN;", body, flags=re.DOTALL)
    if gate is None:
        errors.append("AC5 gate de neutralisation NOT Enable introuvable dans FB_Translation")
    elif "ArrivalStopConfirmed := FALSE;" not in gate.group(1):
        errors.append("AC5 ArrivalStopConfirmed n'est pas remis a FALSE dans la gate NOT Enable (fait fantome)")

    return errors


def check_prg05(text: str) -> list[str]:
    errors: list[str] = []
    body = compact(strip_comments(text))

    # AC6 - memoire de code de cible ; la cible ne retombe que sur le jeton memorise.
    if not re.search(r"M3_TargetCodeSel := 1;", body):
        errors.append(
            "AC6 aucune memoire de code de cible : la perte de la demande efface la cible "
            "deja qualifiee et interrompt le debounce d'arrivee"
        )
    if not re.search(r"CASE M3_TargetCodeSel OF 1: M3_PositionSensorTarget := M3_AtTremieStable;", body):
        errors.append("AC6 la cible publiee n'est plus derivee du code de cible memorise")
    # La cible ne doit JAMAIS etre effacee par la seule perte de la demande : le seul
    # effacement admis est celui du CASE de memoire (branche ELSE, code de cible nul).
    blanks = re.findall(r"M3_PositionSensorTarget := FALSE;", body)
    if len(blanks) != 1:
        errors.append(
            f"AC6 {len(blanks)} effacements de M3_PositionSensorTarget (attendu : 1, la branche "
            "ELSE du CASE de memoire) — un effacement conditionne par la demande est reapparu"
        )
    if "ELSE M3_PositionSensorTarget := FALSE; END_CASE;" not in body:
        errors.append("AC6 l'effacement de la cible n'est plus la branche ELSE du CASE de memoire")

    # AC7 - deux points de consommation du bypass de fin de course gated MAINT_N2.
    gated = re.findall(r"BypassLimitSwitch := (\w+) AND \(", body)
    if len(gated) < 2:
        errors.append(
            f"AC7 seulement {len(gated)} point(s) de consommation du bypass de fin de course "
            "gated par un mode (attendu : 2 — FB_Safety_Translation et FB_Translation)"
        )
    for name in set(gated):
        # AC8 - origine du gate : arbitrage FB_Modes.
        if not re.search(
            rf"{name} := \(PRG_03_Modes_Cycle\.Data\.Auth\.Mode = E_Mode\.MAINT_N2\);",
            body,
        ):
            errors.append(
                f"AC8 {name} ne derive pas de l'arbitrage PRG_03_Modes_Cycle.Data.Auth.Mode "
                "(= E_Mode.MAINT_N2)"
            )

    return errors


def run(root: Path) -> list[str]:
    return check_fb_translation(read(root / "CODE" / "I_TRANSLATION" / "FB_Translation.st")) + check_prg05(
        read(root / "CODE" / "M_MAIN" / "PRG_05_Translation.st")
    )


def selftest(root: Path) -> int:
    """Verifie que chaque controle REJETTE une violation synthetique (gate non complaisant)."""
    fb = read(root / "CODE" / "I_TRANSLATION" / "FB_Translation.st")
    prg = read(root / "CODE" / "M_MAIN" / "PRG_05_Translation.st")
    mutations = [
        ("AC1/AC2 memoire de sens supprimee",
         fb.replace("IF CommandedTremie THEN", "IF FALSE THEN", 1), prg),
        ("AC3 relachement non garde par le sens inverse",
         fb.replace("ReqTremie AND NOT ArrivalWasTremie", "ReqTremie", 1), prg),
        ("AC4 fait d'arret rendu vacuaire (frein)",
         fb.replace("AND NOT BrakeReleaseRequest;", ";", 1), prg),
        ("AC5 fait d'arret non neutralise",
         fb.replace("ArrivalStopConfirmed := FALSE;", "", 1), prg),
        ("AC6 cible effacee par la perte de la demande",
         prg.replace("CASE M3_TargetCodeSel OF", "IF NOT (M3_ReqTremie_Active OR M3_ReqMaintenance_Active) THEN M3_PositionSensorTarget := FALSE; END_IF; CASE M3_TargetCodeSel OF", 1), None),
        ("AC7 bypass de fin de course non gate",
         re.sub(r"BypassLimitSwitch\s+:= M3_MaintN2 AND \(", "BypassLimitSwitch := (", prg, count=1), None),
        ("AC8 gate non issu de l'arbitrage de mode",
         prg.replace("M3_MaintN2 := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2)", "M3_MaintN2 := GVL_IHM.Modes.Cmd.TglJoystickMaster", 1), None),
    ]
    failed = 0
    for label, mutated_fb, mutated_prg in mutations:
        errors = []
        if mutated_prg is None:
            errors = check_prg05(mutated_fb)
        else:
            errors = check_fb_translation(mutated_fb) + check_prg05(mutated_prg)
        if errors:
            print(f"  OK   {label} -> rejetee")
        else:
            failed += 1
            print(f"  FAIL {label} -> NON rejetee (gate complaisant)")
    if failed:
        print(f"[G519] SELFTEST FAIL - {failed} mutation(s) non detectee(s)")
        return 1
    print(f"[G519] SELFTEST PASS - {len(mutations)} mutations toutes rejetees")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", default=".", help="racine du depot (defaut : .)")
    parser.add_argument("--report", action="store_true", help="affiche les invariants verifies")
    parser.add_argument("--selftest", action="store_true", help="verifie que le gate rejette des violations synthetiques")
    args = parser.parse_args()
    root = Path(args.root).resolve()

    if args.selftest:
        return selftest(root)

    errors = run(root)
    if errors:
        print("[G519] FAIL - l'axe ne possede plus son arret :")
        for error in errors:
            print(f"  - {error}")
        return 1

    if args.report:
        print("  AC1  memoire de sens du dernier mouvement (FB_Translation)")
        print("  AC2  sens d'arrivee qualifie par cette memoire")
        print("  AC3  relachement par sens inverse uniquement")
        print("  AC4  fait public ArrivalStopConfirmed non vacuaire")
        print("  AC5  fait remis a FALSE dans la gate NOT Enable")
        print("  AC6  cible non effacee par la perte de la demande (memoire de code de cible)")
        print("  AC7  bypass de fin de course gate en 2 points de consommation")
        print("  AC8  origine du gate = arbitrage FB_Modes")
    print("[G519] PASS - l'axe possede son arret : verrou d'arrivee non annulable par la demande")
    return 0


if __name__ == "__main__":
    sys.exit(main())
