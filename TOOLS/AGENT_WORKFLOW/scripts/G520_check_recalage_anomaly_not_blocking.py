#!/usr/bin/env python3
"""G520 - Recalage M3 : le temoin d'anomalie ne conditionne JAMAIS la correction (T361).

Classe de bug couverte (erreur commise puis corrigee AVANT code, dans l'analyse T361 elle-meme) :
transformer le seuil d'anomalie de recalage en GARDE. Un recalage n'a de sens que quand l'odometrie
a derive : au franchissement d'un capteur, la correction vaut `ecart de gain x distance depuis le
dernier repere`, soit 0,10 m pour 1 % sur les 10 m entre deux capteurs - alors que le deplacement
d'un seul scan vaut 40 Hz x 0,02 m/(Hz.s) x 0,010 s = 0,008 m. Toute garde calibree sur la
dynamique d'un scan rejette donc les corrections UTILES et laisse une position fausse ET non corrigee.

Decision utilisateur 2026-09-21 : 5 capteurs conserves, recalage TOUJOURS applique, AUCUNE zone
morte, et un simple TEMOIN (RecalibrationAnomaly / RecalibrationCorrectionM) au-dela de 0,50 m.
La decision Q2 du lot T333 (« recaler SANS garde tant que T301 n'a pas calibre le gain ») reste
la regle.

Ce gate ECHOUE si :
  1. le bloc de recalage contient une reference au seuil ou au temoin (le temoin est devenu une garde) ;
  2. la mesure de la correction (PositionBeforeM) n'est plus prise AVANT le bloc de recalage ;
  3. le temoin n'est plus calcule a partir de la correction REELLEMENT appliquee
     (`RecalibrationCorrectionM := ABS(...)`) avec un seuil STRICTEMENT superieur ;
  4. le nombre d'affectations de recalage change (5 reperes, un par capteur) ;
  5. le cas de test de la decision Q2 (TC-P11-EST-007) a disparu du fichier de test, ou l'un des
     4 cas du temoin (TC-T361-ANOM-001..004) n'est plus declare (anti-test-vacuant) ;
  6. le cas ANOM-002 n'asserte plus, DANS SON PROPRE BLOC, que la correction est APPLIQUEE malgre
     le temoin (l'invariant « observer, jamais bloquer » ne serait plus teste).

Usage :
    python TOOLS/AGENT_WORKFLOW/scripts/G520_check_recalage_anomaly_not_blocking.py [racine]
    python TOOLS/AGENT_WORKFLOW/scripts/G520_check_recalage_anomaly_not_blocking.py . --selftest
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

CIBLE_FB = "CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st"
CIBLE_TESTS = "TOOLS/TEST_AUTO_CI/RESULTS/I_TRANSLATION/tests/test_fb_translation_positionestimator.st"

SEUIL = "CST_RecalibrationAnomalyM"
TEMOIN = "RecalibrationAnomaly"
AMPLITUDE = "RecalibrationCorrectionM"
REFERENCE = "PositionBeforeM"

# Les 5 reperes absolus servis par le bloc de recalage, un par capteur.
AFFECTATIONS_RECALAGE = (
    "PositionEstimatedM := PosMaintenanceM;",
    "PositionEstimatedM := PosP1M;",
    "PositionEstimatedM := PosP2M;",
    "PositionEstimatedM := PosPVM;",
    "PositionEstimatedM := PosTremieM;",
)

MESURE_ATTENDUE = f"{AMPLITUDE} := ABS(PositionEstimatedM - {REFERENCE});"
TEMOIN_ATTENDU = f"{TEMOIN} := {AMPLITUDE} > {SEUIL};"
REFERENCE_ATTENDUE = f"{REFERENCE} := PositionEstimatedM;"

CAS_TEMOIN = ("TC-T361-ANOM-001", "TC-T361-ANOM-002", "TC-T361-ANOM-003", "TC-T361-ANOM-004")
CAS_INCIDENT = "TC-T361-ANOM-002"
# Cas portant la decision Q2 du lot T333 : il ne doit PAS disparaitre du fichier de test.
CAS_Q2 = "TC-P11-EST-007"

DEBUT_BLOC_RECALAGE = "IF NOT FirstScanDone THEN"
FIN_BLOC_RECALAGE = "\nEND_IF;\n\n"

# Preuves exigees DANS le bloc du cas d'incident.
PREUVE_TEMOIN = f"ASSERT_TRUE(fb.{TEMOIN}"
PREUVE_APPLICATION = "ASSERT_NEAR(fb.PositionEstimatedM, 20.0"


def sans_commentaires(texte: str) -> str:
    """Retire les commentaires ST (* ... *) et // : on ne juge que le CODE."""
    texte = re.sub(r"\(\*.*?\*\)", " ", texte, flags=re.DOTALL)
    return "\n".join(ligne.split("//")[0] for ligne in texte.splitlines())


def extraire_bloc_recalage(code: str) -> str:
    """Texte du bloc de recalage (IF NOT FirstScanDone ... END_IF final), ou chaine vide."""
    debut = code.find(DEBUT_BLOC_RECALAGE)
    if debut == -1:
        return ""
    fin = code.find(FIN_BLOC_RECALAGE, debut)
    if fin == -1:
        return code[debut:]
    return code[debut:fin + len("\nEND_IF;")]


def bloc_test(tests: str, cas: str) -> str:
    """Texte d'un cas de test, de sa declaration `TEST '<cas>` jusqu'a son END_TEST."""
    debut = tests.find(f"TEST '{cas}")
    if debut == -1:
        return ""
    fin = tests.find("END_TEST", debut)
    return tests[debut:fin] if fin != -1 else tests[debut:]


def analyse(code_fb: str, tests: str) -> list[str]:
    """Retourne la liste des erreurs bloquantes. Testable sans disque (selftest)."""
    erreurs: list[str] = []
    code = sans_commentaires(code_fb)

    bloc = extraire_bloc_recalage(code)
    if not bloc:
        return [f"bloc de recalage introuvable (`{DEBUT_BLOC_RECALAGE}` absent de {CIBLE_FB})"]

    # (1) Le temoin ne doit JAMAIS entrer dans le bloc de recalage.
    for interdit in (SEUIL, TEMOIN, AMPLITUDE):
        if interdit in bloc:
            erreurs.append(
                f"`{interdit}` est reference DANS le bloc de recalage : le temoin est devenu une "
                f"garde, donc un recalage legitime peut etre refuse (position fausse ET non corrigee)"
            )

    # (2) Le nombre d'affectations de recalage doit rester 5 (un repere par capteur).
    for affectation in AFFECTATIONS_RECALAGE:
        if bloc.count(affectation) != 1:
            erreurs.append(
                f"affectation de recalage `{affectation}` presente {bloc.count(affectation)} fois "
                f"dans le bloc (1 attendue) : les 5 reperes absolus ne sont plus tous servis"
            )

    # (3) La mesure doit etre prise AVANT le bloc de recalage.
    position_reference = code.find(REFERENCE_ATTENDUE)
    position_bloc = code.find(DEBUT_BLOC_RECALAGE)
    if position_reference == -1:
        erreurs.append(f"`{REFERENCE_ATTENDUE}` absent : la correction n'est plus mesuree")
    elif position_reference > position_bloc:
        erreurs.append(
            f"`{REFERENCE_ATTENDUE}` est prise APRES le debut du bloc de recalage : la mesure "
            f"porterait sur une position deja recalee (temoin systematiquement nul)"
        )

    # (4) Temoin calcule sur la correction REELLEMENT appliquee, a seuil strictement superieur.
    if MESURE_ATTENDUE not in code:
        erreurs.append(f"`{MESURE_ATTENDUE}` absent : l'amplitude n'est plus la correction appliquee")
    if TEMOIN_ATTENDU not in code:
        erreurs.append(
            f"`{TEMOIN_ATTENDU}` absent : le temoin n'est plus un seuil STRICTEMENT superieur "
            f"sur la correction mesuree"
        )

    # (5) Anti-test-vacuant : les cas doivent etre DECLARES (`TEST '<id>`), pas seulement cites.
    for cas in CAS_TEMOIN:
        if not bloc_test(tests, cas):
            erreurs.append(f"cas de test {cas} non declare dans {CIBLE_TESTS} (temoin non verifie)")
    if not bloc_test(tests, CAS_Q2):
        erreurs.append(
            f"cas de test {CAS_Q2} non declare dans {CIBLE_TESTS} : la decision Q2 du lot T333 "
            f"(recaler SANS garde) a disparu du fichier de test"
        )

    # (6) Le cas d'incident doit prouver, DANS SON BLOC, que la correction est appliquee malgre le temoin.
    incident = bloc_test(tests, CAS_INCIDENT)
    if incident:
        if PREUVE_TEMOIN not in incident:
            erreurs.append(
                f"{CAS_INCIDENT} ne leve plus le temoin (`{PREUVE_TEMOIN}` absent) : "
                f"le cas d'anomalie n'est plus concluant"
            )
        if PREUVE_APPLICATION not in incident:
            erreurs.append(
                f"{CAS_INCIDENT} ne prouve plus que la position est RECALEE malgre le temoin "
                f"(`{PREUVE_APPLICATION}` absent) : l'invariant « observer, jamais bloquer » "
                f"n'est plus teste"
            )

    return erreurs


def charge(root: Path) -> tuple[str, str]:
    fb = root / CIBLE_FB
    tests = root / CIBLE_TESTS
    for chemin in (fb, tests):
        if not chemin.is_file():
            raise FileNotFoundError(chemin.relative_to(root).as_posix())
    return (fb.read_text(encoding="utf-8", errors="replace"),
            tests.read_text(encoding="utf-8", errors="replace"))


# -- Mutations de reference (chacune doit etre refusee) ------------------------------------

def mutation_garde_dans_le_bloc(code: str, tests: str) -> tuple[str, str]:
    """La faute d'origine : le seuil devient une condition du recalage."""
    ancre = "    ELSIF TrigTremie.Q OR TrigDnTremie.Q THEN"
    garde = f"    IF ABS(PositionEstimatedM - {REFERENCE}) <= {SEUIL} THEN\n"
    return code.replace(ancre, garde + ancre, 1), tests


def mutation_mesure_supprimee(code: str, tests: str) -> tuple[str, str]:
    return code.replace(MESURE_ATTENDUE, f"{AMPLITUDE} := 0.0;", 1), tests


def mutation_reference_tardive(code: str, tests: str) -> tuple[str, str]:
    return code.replace(REFERENCE_ATTENDUE, "", 1) + f"\n{REFERENCE_ATTENDUE}\n", tests


def mutation_seuil_non_strict(code: str, tests: str) -> tuple[str, str]:
    return code.replace(TEMOIN_ATTENDU, f"{TEMOIN} := {AMPLITUDE} >= {SEUIL};", 1), tests


def mutation_repere_supprime(code: str, tests: str) -> tuple[str, str]:
    return code.replace("        PositionEstimatedM := PosPVM;\n", "", 1), tests


def mutation_cas_temoin_supprime(code: str, tests: str) -> tuple[str, str]:
    return code, tests.replace(bloc_test(tests, CAS_INCIDENT), "", 1)


def mutation_cas_q2_supprime(code: str, tests: str) -> tuple[str, str]:
    return code, tests.replace(bloc_test(tests, CAS_Q2), "", 1)


def mutation_preuve_application_supprimee(code: str, tests: str) -> tuple[str, str]:
    incident = bloc_test(tests, CAS_INCIDENT)
    if not incident:
        return code, tests
    mutile = incident.replace(PREUVE_APPLICATION, "ASSERT_NEAR(fb.PositionEstimatedM, 0.0", 1)
    return code, tests.replace(incident, mutile, 1)


MUTATIONS = (
    ("seuil transforme en garde dans le bloc de recalage", mutation_garde_dans_le_bloc),
    ("mesure de la correction supprimee", mutation_mesure_supprimee),
    ("reference de mesure prise trop tard", mutation_reference_tardive),
    ("seuil non strictement superieur", mutation_seuil_non_strict),
    ("repere absolu retire du bloc de recalage", mutation_repere_supprime),
    ("cas de test du temoin supprime", mutation_cas_temoin_supprime),
    ("cas Q2 (T333) retire du fichier de test", mutation_cas_q2_supprime),
    ("preuve que la correction est appliquee malgre le temoin supprimee", mutation_preuve_application_supprimee),
)


def selftest(root: Path) -> int:
    """Le detecteur doit voir chaque mutation, et rester vert sur l'arbre reel."""
    echecs: list[str] = []
    try:
        code_reel, tests_reels = charge(root)
    except FileNotFoundError as exc:
        print(f"[G520] SELFTEST FAIL : fichier introuvable sur l'arbre reel : {exc}")
        return 1

    # (0) L'arbre reel doit passer, sinon le selftest ne prouve rien.
    reels = analyse(code_reel, tests_reels)
    if reels:
        echecs.append(f"faux positif sur l'arbre REEL : {reels}")

    for libelle, mutation in MUTATIONS:
        code_mute, tests_mutes = mutation(code_reel, tests_reels)
        if (code_mute, tests_mutes) == (code_reel, tests_reels):
            echecs.append(f"mutation inoperante (ancre introuvable) : {libelle}")
            continue
        if not analyse(code_mute, tests_mutes):
            echecs.append(f"mutation NON detectee : {libelle}")

    if echecs:
        print("[G520] SELFTEST FAIL :")
        for echec in echecs:
            print(f"  - {echec}")
        return 1
    print(f"[G520] SELFTEST PASS - {len(MUTATIONS)} mutations refusees, 0 faux positif sur arbre reel")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", type=Path, default=ROOT, help="racine du depot (defaut : depot)")
    parser.add_argument("--selftest", action="store_true", help="verifie que le detecteur rejette les mutations")
    args = parser.parse_args()

    root = args.root.resolve()
    if not (root / "CODE").is_dir():
        print(f"[G520] FAIL - dossier CODE introuvable sous {root}")
        return 1

    if args.selftest:
        return selftest(root)

    try:
        code_fb, tests = charge(root)
    except FileNotFoundError as exc:
        print(f"[G520] FAIL - fichier du controle introuvable : {exc}")
        return 1

    erreurs = analyse(code_fb, tests)
    if erreurs:
        print("[G520] FAIL - le recalage M3 n'est plus un recalage :")
        for erreur in erreurs:
            print(f"  - {erreur}")
        return 1

    seuil = re.search(rf"{SEUIL}\s*:\s*REAL\s*:=\s*([0-9.]+)", code_fb)
    print(
        f"[G520] PASS - recalage M3 toujours applique sur les 5 reperes ; temoin d'anomalie "
        f"purement observationnel (seuil {seuil.group(1) if seuil else '?'} m), jamais une garde"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
