#!/usr/bin/env python3
"""G517 — Enveloppe de securite du forcage de step du cycle semi-automatique (T358).

Classe de risque couverte
-------------------------
Le lot T358 a VIDE le forcage de step de ses gardes de contexte, sur decision
humaine explicite (objet coince dans la benne : besoin de sauter une etape
immediatement, sans dialogue). Ce qui a ete retire :

  Mode = E_Mode.SEMI_AUTO, NOT Fault.Latched, NOT JoystickDeflected,
  DiveStartStopped, NOT KoboldImmersionQualified, NOT BottomContextValid

et le mecanisme a deux temps (preparation ForceStepPrepared, puis confirmation par
Start joystick neutre). Ce que ce lot RETIRE, un autre lot peut le remettre par
effet de bord sans le dire : un `AND NOT JoystickDeflected` rajoute « pour la
securite » rendrait le forcage de nouveau inutilisable, exactement le symptome qui
a declenche T358 (constat exploitant du 2026-09-21).

Ce gate ne juge PAS l'opportunite de la decision : il verrouille l'ENVELOPPE qui
reste, celle sur laquelle l'exploitant s'est engage :

  C1  le bloc de forcage existe et ne contient AUCUNE des six gardes retirees ;
  C2  le bloc est place APRES le RETURN de la porte §2 (Enable / AU / codeur) :
      le forcage ne contourne jamais une securite independante ;
  C3  la SEULE validation restante est la plage des valeurs de E_AutoCycleStep ;
  C4  la table numero -> etape couvre les 23 membres de l'enumeration (aucun trou
      ne peut se transformer en saut silencieux vers AX0) ;
  C5  la consigne n'est JAMAIS ecrite par le FB (aucun producteur concurrent du champ
      IHM), elle est acquittee par PRG_03 sur l'impulsion StepForceTgtTaken du FB :
      anti-boucle, et la meme valeur reste immediatement re-jouable ;
  C6  le scan du forcage n'emet AUCUNE commande d'actionneur ;
  C7  la reprise consciente apres bascule de mode est preservee (WaitingResume) ;
  C8  la consigne ne vient d'AUCUNE donnee persistante (aucun saut au demarrage) ;
  C9  les signaux partages retires de la garde restent VIVANTS ailleurs
      (KoboldImmersionQualified, Fault.Latched) : on n'a pas supprime leur calcul.

Usage
-----
    python TOOLS/AGENT_WORKFLOW/scripts/G517_check_force_step_envelope.py .
    python TOOLS/AGENT_WORKFLOW/scripts/G517_check_force_step_envelope.py --selftest

--selftest mute le texte reel en memoire et verifie que CHAQUE controle devient
rouge : un gate qui ne peut pas echouer ne prouve rien.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

FORCE_ANCHOR = "2bis. FORCAGE DE STEP"
FORCE_END_ANCHOR = "Ready := Enable AND NOT Fault.Latched;"
GATE_CONDITION = "IF NOT Enable OR NOT PowerContactorEngaged OR EncoderFaultPresent THEN"
CONV_BRANCH = "ForceStepCandidateValid := TRUE;"
EXPECTED_CONV_BRANCHES = 23
RANGE_CHECK = "(StepForceConsigne >= 0) AND (StepForceConsigne <= CST_StepForceMax)"
# Acquittement COMPARE-ET-EFFACE (PRG_03) : la consigne n'est effacee que si le champ porte
# encore exactement la valeur lue AVANT l'appel du FB.
ACQ_READ = "StepForceTgtCmd := GVL_IHM.CycleSemiAuto.Cmd.SetForceStepTgt;"
ACQ_GUARD = "AND (GVL_IHM.CycleSemiAuto.Cmd.SetForceStepTgt = StepForceTgtCmd) THEN"
ACQ_WRITE = "GVL_IHM.CycleSemiAuto.Cmd.SetForceStepTgt := -1;"
ACQ_IMPULSE = "IF instCycleSemiAuto.StepForceTgtTaken"
CONSIGNE_READ = "StepForceConsigne := StepForceTgt;"
WIRING = "StepForceTgt            := StepForceTgtCmd,"
# Conditions AUTORISEES dans le bloc de forcage : liste BLANCHE exacte. Toute condition
# supplementaire (ou tout terme ajoute dans l'une de ces conditions) est un refus.
ALLOWED_CONDITIONS = (
    "IF StepForceConsigne <> CST_StepForceNone THEN",
    f"IF {RANGE_CHECK} THEN",
    "IF ForceStepCandidateValid THEN",
)
ENUM_TYPE_FILE = "CODE/G_CYCLE/_TYPES/E_AutoCycleStep.st"

REMOVED_GUARDS = (
    "E_Mode.SEMI_AUTO",
    "Fault.Latched",
    "JoystickDeflected",
    "DiveStartStopped",
    "KoboldImmersionQualified",
    "BottomContextValid",
    # Deuxieme filet : tout nouveau terme de contexte introduit dans le bloc est refuse
    # meme s'il n'appartient pas aux six gardes d'origine du lot.
    "DeadmanArmed",
    "JoystickPush",
    "JoystickPull",
    "PowerContactorEngaged",
    "EncoderFaultPresent",
    "CfgCommissioningEnable",
    "Fault.Error",
)

# Neutralisation COMPLETE des 4 familles de demandes au scan du forcage : lignes integrales,
# pour qu'un retrait partiel (ex. ReqDescend) ne passe pas.
FORCE_NEUTRALISATIONS = (
    "WinchM1Cmd.RunRequest := FALSE; WinchM1Cmd.ReqAscent := FALSE; WinchM1Cmd.ReqDescend := FALSE; WinchM1Cmd.StepTgt := 0;",
    "WinchM2Cmd.RunRequest := FALSE; WinchM2Cmd.ReqAscent := FALSE; WinchM2Cmd.ReqDescend := FALSE; WinchM2Cmd.StepTgt := 0;",
    "TranslationCmd.ReqStart := FALSE; TranslationCmd.PositionTgt := 0;",
    "BucketCmd.ReqOpen := FALSE; BucketCmd.ReqClose := FALSE; BucketCmd.ReqKoboldMeasureEnable := FALSE;",
)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def check(root: Path, cycle_text: str | None = None, prg03_text: str | None = None,
          cmd_text: str | None = None, persist_text: str | None = None) -> list[str]:
    """Rend la liste des constats. Toute injection (tests de mutation) passe par les
    arguments texte : le gate reste ainsi verifiable sans ecrire dans le depot."""
    cycle = read(root / "CODE/G_CYCLE/FB_CycleSemiAuto.st") if cycle_text is None else cycle_text
    prg03 = (read(root / "CODE/M_MAIN/PRG_03_Modes_Cycle.st")
             if prg03_text is None else prg03_text)
    cmd = (read(root / "CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCmd.st")
           if cmd_text is None else cmd_text)
    persist = read(root / "CODE/GVL_PERSISTENT.st") if persist_text is None else persist_text

    errors: list[str] = []

    start = cycle.find(FORCE_ANCHOR)
    if start < 0:
        return ["C1: bloc de forcage introuvable (ancre '2bis. FORCAGE DE STEP' absente)"]
    end = cycle.find(FORCE_END_ANCHOR, start)
    if end < 0:
        return ["C1: fin de bloc de forcage introuvable (ancre Ready := ... absente)"]
    block = cycle[start:end]

    # C1 — LISTE BLANCHE des conditions : aucune garde de contexte ne peut revenir, ni
    # dans une condition nouvelle, ni ajoutee a une condition existante (texte pinne).
    for guard in REMOVED_GUARDS:
        if guard in block:
            errors.append(f"C1: garde de contexte reintroduite dans le forcage : {guard!r}")
    remainder = block
    for condition in ALLOWED_CONDITIONS:
        if condition not in remainder:
            errors.append(f"C1: condition attendue absente du forcage : {condition!r}")
            continue
        remainder = remainder.replace(condition, "", 1)
    if re.search(r"(?<![A-Za-z_])IF(?![A-Za-z_])", remainder):
        errors.append(
            "C1: condition supplementaire dans le bloc de forcage — une garde de contexte "
            "a ete ajoutee (le forçage doit rester sans condition)"
        )

    # C2 — placement apres la porte §2
    gate_at = cycle.find(GATE_CONDITION)
    if gate_at < 0:
        errors.append("C2: porte de securite §2 introuvable (Enable / AU / codeur)")
    else:
        gate_return = cycle.find("RETURN;", gate_at)
        if gate_return < 0:
            errors.append("C2: RETURN de la porte §2 introuvable")
        elif start < gate_return:
            errors.append(
                "C2: le forcage est place AVANT la porte §2 — il contournerait "
                "Enable / PowerContactorEngaged / EncoderFaultPresent"
            )

    # C3 — seule validation restante : la plage d'enumeration
    if RANGE_CHECK not in block:
        errors.append(f"C3: validation de plage absente du forcage : {RANGE_CHECK!r}")

    # C4 — table numero -> etape EXACTE : chaque membre de l'enumeration doit etre mappe a
    # SA valeur (un simple comptage laisserait passer une permutation de cibles).
    enum_text = read(root / ENUM_TYPE_FILE)
    members = {int(v): name for name, v in re.findall(r"(\w+)\s*:=\s*(\d+)\b", enum_text)}
    if len(members) != EXPECTED_CONV_BRANCHES:
        errors.append(
            f"C4: enumeration E_AutoCycleStep de {len(members)} membres (attendu {EXPECTED_CONV_BRANCHES}) "
            "— le contrat T358 suppose 23 valeurs contigues 0..22"
        )
    for value, name in sorted(members.items()):
        pattern = rf"^\s*{value}:\s*ForceStepCandidate := E_AutoCycleStep\.{name};"
        if not re.search(pattern, block, re.MULTILINE):
            errors.append(
                f"C4: table numero -> etape FAUSSE ou absente pour {value} "
                f"(attendu E_AutoCycleStep.{name})"
            )
    branches = block.count(CONV_BRANCH)
    if branches != EXPECTED_CONV_BRANCHES:
        errors.append(
            f"C4: table numero -> etape incomplete : {branches} branche(s) sur "
            f"{EXPECTED_CONV_BRANCHES} attendues (un membre non traite deviendrait un refus muet)"
        )

    # C5 — consigne NON ecrite par le FB, acquittee par PRG_03 sur StepForceTgtTaken
    if "StepForceTgt :=" in block or "StepForceTgt :=" in cycle:
        errors.append("C5: le FB ecrit la consigne de forcage (producteur concurrent du champ IHM interdit)")
    if CONSIGNE_READ not in cycle:
        errors.append(f"C5: lecture unique de la consigne absente du FB : {CONSIGNE_READ!r}")
    if "StepForceTgtTaken := (StepForceTgt <> CST_StepForceNone);" not in cycle:
        errors.append(
            "C5: le FB ne publie plus l'impulsion StepForceTgtTaken depuis la consigne "
            "(PRG_03 n'a plus rien a acquitter : boucle de forcage)"
        )
    if ACQ_READ not in prg03:
        errors.append(
            f"C5: lecture de la consigne AVANT l'appel du FB absente de PRG_03 : {ACQ_READ!r} "
            "(sans elle, l'acquittement ne peut pas etre un compare-et-efface)"
        )
    if ACQ_IMPULSE not in prg03 or ACQ_GUARD not in prg03 or ACQ_WRITE not in prg03:
        errors.append(
            "C5: acquittement de la consigne absent ou non conditionne dans PRG_03 — sans "
            "compare-et-efface, soit la meme valeur est rejouee a chaque scan (boucle), soit "
            "une ecriture d'operateur arrivee pendant le corps du FB est effacee (ordre perdu)"
        )

    # C6 — scan du forcage sans commande
    if "StateExecutionInhibit := TRUE" not in block:
        errors.append("C6: le scan du forcage n'inhibe pas le CASE (l'etape cible s'executerait dans le scan du forcage)")
    for neutral in FORCE_NEUTRALISATIONS:
        if neutral not in block:
            errors.append(f"C6: demande d'actionneur non neutralisee au scan du forcage : {neutral!r}")

    # C7 — reprise consciente preservee
    for token, label in (
        ("WaitingResume := TRUE", "ecriture de l'attente de reprise"),
        ("ELSIF StartEdge.Q OR DeadmanArmedEdge.Q THEN", "consommation consciente de l'attente"),
        ("State := PausedState;", "restauration de l'etape memorisee"),
    ):
        if token not in cycle:
            errors.append(f"C7: reprise consciente apres bascule de mode degradee ({label} absente)")
    for gone in ("ForceStepPrepared", "ForceStepWaiting"):
        if gone in cycle or gone in prg03:
            errors.append(f"C7: mecanisme de forcage a deux temps encore present : {gone}")

    # C8 — consigne non persistee
    if WIRING not in prg03:
        errors.append(f"C8: cablage de la consigne de forcage inattendu (attendu : {WIRING!r})")
    if "CycleSemiAuto.Cfg.ForceStepTarget" in prg03:
        errors.append("C8: la cible de forcage est encore alimentee par une configuration persistee")
    if "SetForceStepTgt" in persist:
        errors.append("C8: la consigne de forcage apparait dans GVL_PERSISTENT (saut d'etape possible au demarrage)")
    if "SetForceStepTgt : INT := -1" not in cmd:
        errors.append("C8: consigne absente de ST_CycleCmd ou sans sentinelle -1 a la declaration")

    # C9 — signaux partages toujours vivants hors du bloc : controle du CALCUL lui-meme,
    # et pas seulement d'un comptage d'occurrences (retirer la seule affectation de calcul
    # laisserait le comptage intact).
    if "KoboldImmersionQualified := TRUE;" not in cycle:
        errors.append("C9: le calcul de KoboldImmersionQualified a disparu du FB (signal de securite perdu)")
    if cycle.count("KoboldImmersionQualified") < 4:
        errors.append("C9: KoboldImmersionQualified n'est plus calcule/consomme hors forcage (signal de securite perdu)")
    if "Ready := Enable AND NOT Fault.Latched;" not in cycle:
        errors.append("C9: le latch de defaut n'alimente plus Ready (signal de securite perdu)")

    return errors


def selftest(root: Path) -> int:
    """Mutations en memoire : chacune DOIT rendre le gate rouge."""
    cycle = read(root / "CODE/G_CYCLE/FB_CycleSemiAuto.st")
    prg03 = read(root / "CODE/M_MAIN/PRG_03_Modes_Cycle.st")
    cmd = read(root / "CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCmd.st")
    persist = read(root / "CODE/GVL_PERSISTENT.st")

    mutations = [
        ("C1 garde joystick reintroduite",
         lambda: check(root, cycle.replace(RANGE_CHECK, RANGE_CHECK + " AND NOT JoystickDeflected"), prg03, cmd, persist)),
        ("C1 garde de contexte NON LISTEE ajoutee dans la condition de plage",
         lambda: check(root, _mutate_block(cycle, RANGE_CHECK, RANGE_CHECK + " AND NOT DeadmanArmed"), prg03, cmd, persist)),
        ("C1 condition de forcage supplementaire",
         lambda: check(root, _mutate_block(cycle, "IF ForceStepCandidateValid THEN",
                                           "IF ForceStepCandidateValid AND NOT JoystickPush THEN"), prg03, cmd, persist)),
        ("C1 garde contexte fond reintroduite",
         lambda: check(root, cycle.replace(RANGE_CHECK, "(NOT BottomContextValid) AND " + RANGE_CHECK), prg03, cmd, persist)),
        ("C2 forcage deplace avant la porte",
         lambda: check(root, _move_force_before_gate(cycle), prg03, cmd, persist)),
        ("C3 plage retiree",
         lambda: check(root, _mutate_block(cycle, RANGE_CHECK, "TRUE"), prg03, cmd, persist)),
        ("C4 branche de conversion supprimee",
         lambda: check(root, cycle.replace(CONV_BRANCH, "", 1), prg03, cmd, persist)),
        ("C4 PERMUTATION de deux cibles (18 <-> 19), comptage inchange",
         lambda: check(root, _swap_targets(cycle), prg03, cmd, persist)),
        ("C5 acquittement PRG_03 supprime",
         lambda: check(root, cycle, prg03.replace(ACQ_WRITE, "// acquittement retire"), cmd, persist)),
        ("C5 compare-et-efface remplace par un effacement inconditionnel",
         lambda: check(root, cycle, prg03.replace(ACQ_GUARD, "THEN"), cmd, persist)),
        ("C5 signal d acquittement supprime du FB",
         lambda: check(root, cycle.replace("StepForceTgtTaken := (StepForceTgt <> CST_StepForceNone);", "StepForceTgtTaken := FALSE;"), prg03, cmd, persist)),
        ("C6 inhibition du CASE supprimee",
         lambda: check(root, _mutate_block(cycle, "StateExecutionInhibit := TRUE", "StateExecutionInhibit_Inchange"), prg03, cmd, persist)),
        ("C6 neutralisation PARTIELLE d une demande (ReqDescend retire)",
         lambda: check(root, _mutate_block(cycle, "WinchM1Cmd.ReqDescend := FALSE; ", ""), prg03, cmd, persist)),
        ("C7 reprise consciente supprimee",
         lambda: check(root, cycle.replace("ELSIF StartEdge.Q OR DeadmanArmedEdge.Q THEN", "ELSIF FALSE THEN"), prg03, cmd, persist)),
        ("C7 forcage a deux temps reintroduit",
         lambda: check(root, cycle, prg03.replace(WIRING, WIRING + "\n    ForceStepPrepared_shouldfail := FALSE,"), cmd, persist)),
        ("C8 cible persistee recablee",
         lambda: check(root, cycle, prg03.replace("CycleSemiAuto.Cmd.SetForceStepTgt", "CycleSemiAuto.Cfg.ForceStepTarget"), cmd, persist)),
        ("C8 consigne persistee",
         lambda: check(root, cycle, prg03, cmd, persist.replace("_CycleCfgPersist", "_CycleCfgPersist_And_SetForceStepTgt"))),
        ("C9 calcul du signal Kobold supprime (comptage inchange)",
         lambda: check(root, cycle.replace("KoboldImmersionQualified := TRUE;", "KoboldImmersionQualified := FALSE;"), prg03, cmd, persist)),
        ("C9 signal de securite perdu",
         lambda: check(root, cycle.replace("KoboldImmersionQualified", "KoboldImmersionRenomme"), prg03, cmd, persist)),
    ]

    failures = 0
    for label, run in mutations:
        errors = run()
        if errors:
            print(f"  [OK] mutation detectee : {label} -> {errors[0]}")
        else:
            print(f"  [KO] mutation NON detectee : {label}")
            failures += 1

    if failures:
        print(f"G517 SELFTEST FAIL ({failures} mutation(s) non detectee(s))")
        return 1
    print(f"G517 SELFTEST PASS ({len(mutations)} mutations, toutes detectees)")
    return 0


def _move_force_before_gate(cycle: str) -> str:
    """Deplace litteralement le bloc de forcage avant la porte §2 : mutation C2."""
    start = cycle.find(FORCE_ANCHOR)
    end = cycle.find(FORCE_END_ANCHOR, start)
    gate_at = cycle.find(GATE_CONDITION)
    if start < 0 or end < 0 or gate_at < 0:
        return cycle
    block = cycle[start:end]
    return cycle[:start] + cycle[end:gate_at] + block + cycle[gate_at:]


def _swap_targets(cycle: str) -> str:
    """Permute les cibles 18 et 19 dans le bloc de forcage : mutation C4.

    Le NOMBRE de branches reste 23 : seul le controle de la table EXACTE (valeur -> membre)
    peut detecter cette mutation, c'est precisement la limite que ce test verrouille.
    """
    start = cycle.find(FORCE_ANCHOR)
    end = cycle.find(FORCE_END_ANCHOR, start)
    if start < 0 or end < 0:
        return cycle
    block = cycle[start:end]
    block = block.replace("E_AutoCycleStep.AX18_DONE_SYNC;", "@@PERMUT@@;")
    block = block.replace("E_AutoCycleStep.AX_STAB;", "E_AutoCycleStep.AX18_DONE_SYNC;")
    block = block.replace("@@PERMUT@@;", "E_AutoCycleStep.AX_STAB;")
    return cycle[:start] + block + cycle[end:]


def _mutate_block(cycle: str, old: str, new: str, count: int = -1) -> str:
    """Remplace du texte UNIQUEMENT dans le bloc de forcage : mutations C3, C5, C6."""
    start = cycle.find(FORCE_ANCHOR)
    end = cycle.find(FORCE_END_ANCHOR, start)
    if start < 0 or end < 0:
        return cycle
    block = cycle[start:end].replace(old, new) if count < 0 else cycle[start:end].replace(old, new, count)
    return cycle[:start] + block + cycle[end:]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", default=".", type=Path, help="racine du depot")
    parser.add_argument("--selftest", action="store_true", help="verifie que chaque controle peut echouer")
    args = parser.parse_args()
    root = args.root.resolve()

    if args.selftest:
        return selftest(root)

    errors = check(root)
    if errors:
        print("G517 FAIL: " + " | ".join(errors))
        return 1
    print("G517 PASS - enveloppe du forcage de step conforme (placement apres porte §2, plage d'enum seule validation, consigne acquittee, reprise consciente preservee)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
