#!/usr/bin/env python3
"""G521 - Acquittement automatique borne : jamais declenche par une entree materielle (T367).

Classe de bug couverte : l'acquittement AUTOMATIQUE des defauts latches est un geste SANS appui
operateur. Il n'est admissible que dans DEUX situations bornees, et seulement si le declencheur
prouve un geste conscient :

  (a) DEMARRAGE A FROID — une fois le transitoire d'E/S termine (`Data.InputModules.Fault = FALSE`)
      et un temps de stabilisation ecoule ; la campagne est bornee dans le temps.
  (b) REARMEMENT AU — un front du contacteur de puissance GATE par le fait qu'une sequence
      d'armement a REELLEMENT DEMARRE (`EmergencyState.Step` sur front). Le contacteur peut
      s'engager SANS aucun geste operateur : relachement d'un AU avec maintien repris, demarrage
      a chaine fermee, bypass de mise en service. Un front BRUT du contacteur doit donc ne
      JAMAIS suffire — c'est le coeur de TC-T367-107.

Ce gate ECHOUE si :
  1. le declencheur du rearmement n'est plus gate par la sequence d'armement (front brut du
     contacteur) ;
  2. la memoire « geste operateur » est re-armee par un NIVEAU de sequence (`OR (Step <> 0)`),
     au lieu d'un FRONT de demarrage : un etat de sequence residuel re-armerait la memoire et
     un front ulterieur du contacteur declencherait un acquittement sans geste nouveau ;
  3. la source « sequence d'armement » n'est plus `PRG_06_Outputs.EmergencyState.Step`, ou le
     contacteur n'est plus lu en fait qualifie `EmergencyState.ContactorOk` ;
  4. la porte unique `FaultMachineReset_IHM` a perdu une des sources operateur existantes, ou
     n'injecte plus les deux campagnes ;
  5. la campagne n'est plus bornee (nombre d'impulsions max ou clause de fin de campagne) ;
  6. la campagne de demarrage a froid n'est plus gatee par la fin du transitoire d'E/S, ou
     n'est plus bornee dans le temps ;
  7. le bloc de campagne reference une entree MATERIELLE brute (`_DI`/`_RQ`) : un acquittement
     ne doit jamais etre declenche par une voie d'E/S ;
  8. la porte unique n'est plus ecrite par un seul site, ou l'acquittement est force a TRUE ;
  9. les cas de test qui portent l'invariant ont disparu ou sont devenus vacues
     (TC-T367-101/103/107 : comptage exact, non-masquage, front brut du contacteur).

Usage :
    python TOOLS/AGENT_WORKFLOW/scripts/G521_check_fault_reset_not_hw_triggered.py [racine]
    python TOOLS/AGENT_WORKFLOW/scripts/G521_check_fault_reset_not_hw_triggered.py . --selftest
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

CIBLE_PRG = "CODE/M_MAIN/PRG_07_Supervision.st"
CIBLE_TESTS = "TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/tests/test_prg_07_supervision.st"

DEBUT_BLOC = "BootInputTransientDone := NOT PRG_02_Acquisition.Data.InputModules.Fault;"
FIN_BLOC = "FaultMachineReset_IHM :="

# Faits attendus (code, commentaires retires).
REARM_GATE = "RearmAckStart := ContactorOkEdge.Q AND RearmSeqSeen;"
SEQ_FACT = "RearmSeqRunning := (PRG_06_Outputs.EmergencyState.Step <> 0);"
SEQ_EDGE_TRIG = "RearmSeqStartEdge(CLK := RearmSeqRunning);"
SEQ_ARM = "RearmSeqSeen := TRUE;"
CONTACTOR_EDGE = "ContactorOkEdge(CLK := PRG_06_Outputs.EmergencyState.ContactorOk);"
GESTE_CONSOMME = "RearmSeqSeen := FALSE;"
BOOT_TRANSIENT = "BootInputTransientDone := NOT PRG_02_Acquisition.Data.InputModules.Fault;"
BOOT_WINDOW_CALL = "BootWindowTimer(IN := TRUE, PT := CST_AckBootWindow);"
BOOT_ALLOWED = "AckPulseAllowed := BootInputTransientDone;"
PULSE_ROOM = "AckPulseRoom       := AckPulseCount < CST_AckPulseMax;"
BOOT_LAST_PULSE = (
    "BootCampaignLastPulse := AckCampaignActive AND AckCampaignIsBoot AND "
    "(AckPulseCount >= CST_AckPulseMax);"
)
REARM_LAST_PULSE = (
    "RearmCampaignLastPulse := AckCampaignActive AND (NOT AckCampaignIsBoot) AND "
    "(AckPulseCount >= CST_AckPulseMax);"
)
PULSE_INJECTION = "OR BootAckPulse OR RearmAckPulse;"

# Les 5 sources d'acquittement operateur — toute disparition est une regression.
# (La premiere source porte l'affectation, les suivantes le prefixe `OR`.)
SOURCES_OPERATEUR = (
    "GVL_IHM.Modes.Cmd.BtnFaultReset",
    "GVL_IHM.M1TreuilRetenue.Cmd.BtnReset",
    "GVL_IHM.M2TreuilBenne.Cmd.BtnReset",
    "GVL_IHM.M2TreuilBenne.Bucket.Cmd.BtnReset",
    "GVL_IHM.CycleSemiAuto.Cmd.BtnReset",
)

# Bornes : nombre d'impulsions et fenetre de demarrage a froid.
BORNE_PULSES = re.compile(r"CST_AckPulseMax\s*:\s*USINT\s*:=\s*(\d+)\s*;")
BORNE_FENETRE = re.compile(r"CST_AckBootWindow\s*:\s*TIME\s*:=\s*T#(\d+)s\s*;")
NIVEAU_SEQUENCE = re.compile(r"RearmSeqSeen\s*:=[^;]*\bOR\b")
MATERIEL_BRUT = re.compile(r"\b[A-Za-z_]\w*_(?:DI|DQ|RQ)\b")

CAS_OBLIGATOIRES = (
    "TC-T367-101",
    "TC-T367-102",
    "TC-T367-103",
    "TC-T367-104",
    "TC-T367-105",
    "TC-T367-106",
    "TC-T367-107",
    "TC-T367-108",
)


def sans_commentaires(texte: str) -> str:
    """Retire les commentaires ST (* ... *) et // : on ne juge que le CODE."""
    texte = re.sub(r"\(\*.*?\*\)", " ", texte, flags=re.DOTALL)
    return "\n".join(ligne.split("//")[0] for ligne in texte.splitlines())


def extraire_bloc(code: str) -> str:
    """Texte du bloc des deux campagnes, de la fin du transitoire jusqu'a la porte unique."""
    debut = code.find(DEBUT_BLOC)
    if debut == -1:
        return ""
    fin = code.find(FIN_BLOC, debut)
    return code[debut:fin] if fin != -1 else code[debut:]


def bloc_test(tests: str, cas: str) -> str:
    """Texte d'un cas de test, de sa declaration `TEST '<cas>` jusqu'a son END_TEST."""
    debut = tests.find(f"TEST '{cas}")
    if debut == -1:
        return ""
    fin = tests.find("END_TEST", debut)
    return tests[debut:fin] if fin != -1 else tests[debut:]


def analyse(code_prg: str, tests: str) -> list[str]:
    """Retourne la liste des erreurs bloquantes. Testable sans disque (selftest)."""
    erreurs: list[str] = []
    code = sans_commentaires(code_prg)

    bloc = extraire_bloc(code)
    if not bloc:
        return [f"bloc des campagnes introuvable (`{DEBUT_BLOC}` absent de {CIBLE_PRG})"]

    # (1) Le front du contacteur doit rester GATE par la sequence d'armement.
    if REARM_GATE not in bloc:
        erreurs.append(
            f"`{REARM_GATE}` absent : le declencheur du rearmement n'est plus gate par une "
            "sequence d'armement — un front brut du contacteur declencherait un acquittement "
            "sans aucun geste operateur"
        )
    if CONTACTOR_EDGE not in bloc:
        erreurs.append(
            f"`{CONTACTOR_EDGE}` absent : le contacteur n'est plus lu en fait qualifie "
            "`EmergencyState.ContactorOk`"
        )

    # (2) La memoire du geste est armee par un FRONT de sequence, jamais par un NIVEAU.
    if SEQ_FACT not in bloc:
        erreurs.append(
            f"`{SEQ_FACT}` absent : la source « sequence d'armement » n'est plus "
            "`PRG_06_Outputs.EmergencyState.Step`"
        )
    if SEQ_EDGE_TRIG not in bloc or SEQ_ARM not in bloc:
        erreurs.append(
            "la memoire « geste operateur » n'est plus armee par un front de demarrage de "
            f"sequence (`{SEQ_EDGE_TRIG}` / `{SEQ_ARM}`)"
        )
    if NIVEAU_SEQUENCE.search(code):
        erreurs.append(
            "la memoire « geste operateur » est re-armee par un NIVEAU de sequence "
            "(`RearmSeqSeen := ... OR ...`) : un etat de sequence residuel suffirait a "
            "autoriser un acquittement sur un front ulterieur du contacteur"
        )
    if GESTE_CONSOMME not in bloc:
        erreurs.append(
            f"`{GESTE_CONSOMME}` absent : le geste n'est plus consomme, une nouvelle campagne "
            "pourrait sortir sans nouveau geste operateur"
        )

    # (3) Porte unique : 5 sources operateur + les 2 campagnes, un seul ecrivain.
    porte = code[code.find(FIN_BLOC):] if FIN_BLOC in code else ""
    for source in SOURCES_OPERATEUR:
        if source not in porte:
            erreurs.append(f"source operateur perdue dans la porte unique : `{source}`")
    if PULSE_INJECTION not in porte:
        erreurs.append(
            f"`{PULSE_INJECTION}` absent de la porte unique : les campagnes ne sont plus injectees"
        )
    if code.count(FIN_BLOC) != 1:
        erreurs.append(
            f"la porte unique `{FIN_BLOC}` est ecrite {code.count(FIN_BLOC)} fois "
            "(producteur unique exige)"
        )
    if re.search(r"FaultMachineReset_IHM\s*:=\s*TRUE\s*;", code):
        erreurs.append("`FaultMachineReset_IHM := TRUE` : acquittement force, donc permanent")

    # (4) Campagne bornee : nombre d'impulsions, clause de fin, droit d'impulsion.
    borne = BORNE_PULSES.search(code)
    if borne is None:
        erreurs.append("`CST_AckPulseMax` (nombre maximal d'impulsions par campagne) introuvable")
    elif int(borne.group(1)) > 3:
        erreurs.append(
            f"`CST_AckPulseMax = {borne.group(1)}` : la campagne n'est plus bornee a 3 impulsions"
        )
    for attendu, libelle in (
        (PULSE_ROOM, "droit d'impulsion de la campagne"),
        (BOOT_LAST_PULSE, "fin de la campagne de demarrage a froid"),
        (REARM_LAST_PULSE, "fin de la campagne de rearmement"),
    ):
        if attendu not in bloc:
            erreurs.append(f"clause de bornage absente ({libelle}) : `{attendu}`")

    # (5) Campagne de demarrage a froid : gatee par la fin du transitoire ET bornee en temps.
    for attendu, libelle in (
        (BOOT_TRANSIENT, "fin du transitoire d'E/S"),
        (BOOT_WINDOW_CALL, "fenetre de demarrage a froid"),
        (BOOT_ALLOWED, "autorisation d'impulsion liee au transitoire d'E/S"),
    ):
        if attendu not in bloc:
            erreurs.append(f"garde absente ({libelle}) : `{attendu}`")
    fenetre = BORNE_FENETRE.search(code)
    if fenetre is None:
        erreurs.append(
            "`CST_AckBootWindow` (borne de temps de la campagne de demarrage a froid) introuvable"
        )
    elif int(fenetre.group(1)) <= 0:
        erreurs.append("`CST_AckBootWindow` nulle : la campagne de demarrage a froid n'est plus bornee")

    # (6) Anti « acquittement declenche par une entree materielle ».
    mat = MATERIEL_BRUT.search(bloc)
    if mat:
        erreurs.append(
            f"le bloc de campagne reference l'entree materielle brute `{mat.group(0)}` : un "
            "acquittement ne doit jamais etre declenche par une voie d'E/S"
        )

    # (7) Anti-test-vacuant : les cas qui portent l'invariant doivent rester non vacues.
    for cas in CAS_OBLIGATOIRES:
        if f"TEST '{cas}" not in tests:
            erreurs.append(f"cas de test {cas} absent du fichier de test")
    cas_103 = bloc_test(tests, "TC-T367-103")
    if "faultCore.Fault.Latched" not in cas_103 or "ASSERT_TRUE(faultLatchedAfter" not in cas_103:
        erreurs.append(
            "TC-T367-103 n'asserte plus qu'une cause encore Active reste latchee "
            "(preuve de non-masquage devenue vacue)"
        )
    cas_107 = bloc_test(tests, "TC-T367-107")
    if "ASSERT_EQ(pulseCount, 0," not in cas_107:
        erreurs.append(
            "TC-T367-107 n'asserte plus qu'un front du contacteur sans sequence operateur "
            "n'emet aucune impulsion"
        )
    cas_101 = bloc_test(tests, "TC-T367-101")
    if "ASSERT_EQ(pulseCount, 3," not in cas_101:
        erreurs.append(
            "TC-T367-101 n'asserte plus le nombre exact d'impulsions de la campagne de boot"
        )

    return erreurs


# ── Auto-test : chaque controle doit pouvoir echouer (mutations) ──────────────

def charge(root: Path) -> tuple[str, str]:
    prg = root / CIBLE_PRG
    tests = root / CIBLE_TESTS
    for chemin in (prg, tests):
        if not chemin.is_file():
            raise FileNotFoundError(str(chemin))
    return prg.read_text(encoding="utf-8"), tests.read_text(encoding="utf-8")


def _sub(texte: str, avant: str, apres: str) -> str:
    return texte.replace(avant, apres, 1)


def m_front_brut(code: str, tests: str) -> tuple[str, str]:
    return _sub(code, REARM_GATE, "RearmAckStart := ContactorOkEdge.Q;"), tests


def m_niveau_sequence(code: str, tests: str) -> tuple[str, str]:
    return _sub(
        code,
        "IF RearmSeqStartEdge.Q THEN\n    RearmSeqSeen := TRUE;\nEND_IF;",
        "RearmSeqSeen := RearmSeqSeen OR RearmSeqRunning;",
    ), tests


def m_borne_supprimee(code: str, tests: str) -> tuple[str, str]:
    return _sub(code, "CST_AckPulseMax     : USINT := 3;", "CST_AckPulseMax     : USINT := 9;"), tests


def m_injection_supprimee(code: str, tests: str) -> tuple[str, str]:
    return _sub(code, "OR BootAckPulse OR RearmAckPulse;", ";"), tests


def m_source_operateur_supprimee(code: str, tests: str) -> tuple[str, str]:
    return _sub(code, "                    OR GVL_IHM.M1TreuilRetenue.Cmd.BtnReset\n", ""), tests


def m_transitoire_supprime(code: str, tests: str) -> tuple[str, str]:
    return _sub(
        code,
        BOOT_TRANSIENT,
        "BootInputTransientDone := TRUE;",
    ), tests


def m_fenetre_supprimee(code: str, tests: str) -> tuple[str, str]:
    return _sub(code, "CST_AckBootWindow   : TIME  := T#30s;", "CST_AckBootWindow   : TIME  := T#0s;"), tests


def m_materiel_brut(code: str, tests: str) -> tuple[str, str]:
    return _sub(
        code,
        "RearmAckStart := ContactorOkEdge.Q AND RearmSeqSeen;",
        "RearmAckStart := ContactorOkEdge.Q AND RearmSeqSeen AND PowerContactorEngaged_DI;",
    ), tests


def m_cas_test_supprime(code: str, tests: str) -> tuple[str, str]:
    return code, _sub(tests, "TEST 'TC-T367-107", "TEST 'X-T367-107")


def m_preuve_non_masquage(code: str, tests: str) -> tuple[str, str]:
    return code, _sub(tests, "ASSERT_TRUE(faultLatchedAfter,", "ASSERT_TRUE(NOT faultLatchedAfter,")


def m_preuve_comptage(code: str, tests: str) -> tuple[str, str]:
    return code, _sub(tests, "ASSERT_EQ(pulseCount, 3, 'Campagne de boot", "ASSERT_TRUE(pulseCount >= 0, 'Campagne de boot")


MUTATIONS = (
    ("front du contacteur non gate (geste operateur disparu)", m_front_brut),
    ("memoire du geste re-armee par un niveau de sequence", m_niveau_sequence),
    ("campagne non bornee en nombre d'impulsions", m_borne_supprimee),
    ("campagnes non injectees dans la porte unique", m_injection_supprimee),
    ("source operateur retiree de la porte unique", m_source_operateur_supprimee),
    ("garde du transitoire d'E/S retiree", m_transitoire_supprime),
    ("fenetre de demarrage a froid nulle", m_fenetre_supprimee),
    ("entree materielle brute dans le declencheur", m_materiel_brut),
    ("cas de test TC-T367-107 retire", m_cas_test_supprime),
    ("preuve de non-masquage inversee", m_preuve_non_masquage),
    ("preuve de comptage de la campagne retiree", m_preuve_comptage),
)


def selftest(root: Path) -> int:
    """Le detecteur doit voir chaque mutation, et rester vert sur l'arbre reel."""
    echecs: list[str] = []
    try:
        code_reel, tests_reels = charge(root)
    except FileNotFoundError as exc:
        print(f"[G521] SELFTEST FAIL : fichier introuvable sur l'arbre reel : {exc}")
        return 1

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
        print("[G521] SELFTEST FAIL :")
        for echec in echecs:
            print(f"  - {echec}")
        return 1
    print(f"[G521] SELFTEST PASS - {len(MUTATIONS)} mutations refusees, 0 faux positif sur arbre reel")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", type=Path, default=ROOT, help="racine du depot (defaut : depot)")
    parser.add_argument("--selftest", action="store_true", help="verifie que le detecteur rejette les mutations")
    args = parser.parse_args()

    root = args.root.resolve()
    if not (root / "CODE").is_dir():
        print(f"[G521] FAIL - dossier CODE introuvable sous {root}")
        return 1

    if args.selftest:
        return selftest(root)

    try:
        code_prg, tests = charge(root)
    except FileNotFoundError as exc:
        print(f"[G521] FAIL - fichier du controle introuvable : {exc}")
        return 1

    erreurs = analyse(code_prg, tests)
    if erreurs:
        print("[G521] FAIL - l'acquittement automatique n'est plus borne ni gate :")
        for erreur in erreurs:
            print(f"  - {erreur}")
        return 1

    borne = BORNE_PULSES.search(sans_commentaires(code_prg))
    fenetre = BORNE_FENETRE.search(sans_commentaires(code_prg))
    print(
        "[G521] PASS - acquittement automatique borne : 2 campagnes "
        f"(max {borne.group(1) if borne else '?'} impulsions, fenetre de boot "
        f"{fenetre.group(1) if fenetre else '?'} s), rearmement gate par une sequence "
        "d'armement, aucune entree materielle brute"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
