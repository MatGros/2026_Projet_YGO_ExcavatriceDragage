#!/usr/bin/env python3
"""G518 - Odometrie M3 : SOURCE UNIQUE entre machine et banc de simulation (T361 -> T301/L1).

Classe de bug couverte : le banc SimBench et l'estimateur de position M3 portaient chacun leur
propre echelle et leurs propres positions capteurs. Le banc avait 30 m / FullTravelTimeS / 40 Hz
en dur et des positions 0/5/15/20/30 recopiees a la main ; l'estimateur lisait GVL_PERSISTENT.
Les deux ont diverge (trace Suivi_74, audit T360 : sauts de recalage de 4 a 9 m, rapport 4,7).
Un controle d'EGALITE entre deux copies (version T361 de ce gate) ne suffisait pas : il fallait
supprimer la copie. Depuis T301/L1 (2026-10-28) :

  * machine : gain = FB_Translation_OdometryGain.GainActive (reglage site, repli persistant),
              positions = GVL_PERSISTENT._TranslationPos*_M ;
  * banc    : recoit CES valeurs par PRG_02 (gain effectif publie par PRG_05, positions
              persistantes) et n'en declare AUCUNE.

Ce gate ECHOUE si :
  1. une geometrie ou une echelle en dur reapparait dans le banc (CST_PositionAt*, FullTravelTimeS,
     CST_NominalFrequency_Hz dans FB_Sim_Translation ; CST_M3FullTravelTimeS dans FB_SimBench) ;
  2. le banc n'integre plus la vitesse par le gain recu (sens x gain x frequence) ;
  3. FB_SimBench ne passe plus le gain et les 5 positions recus a instSimTranslation ;
  4. PRG_02 ne cable plus le gain EFFECTIF (PRG_05 ... OdometryGainActive) et les 5 positions
     GVL_PERSISTENT vers le banc ;
  5. PRG_05 ne cable plus l'estimateur sur le gain actif de FB_Translation_OdometryGain, ne publie
     plus ce gain, ou si FB_Translation_OdometryGain ne lit plus ses reglages dans GVL_PERSISTENT ;
  6. les cas de test de l'invariant ont disparu (anti-test-vacuant) ;
  7. le maximum variateur du banc (CST_M3MaxFreq_Hz) differe de GVL_PERSISTENT._TranslationMaxFreq_Hz
     ou n'est plus passe a instSimTranslation.

Signale SANS bloquer : defaut declare de FB_Translation_PositionEstimator.GainMetersPerHzSec
different du gain de repli persistant (piege pour une instanciation de test non cablee).

Regles couvertes : TASK_CONTRACT_T301_CALIBRATION_ODOMETRIE_M3.yaml (AC8), T361 (historique).

Usage :
    python TOOLS/AGENT_WORKFLOW/scripts/G518_check_m3_odometry_scale.py [racine]
    python TOOLS/AGENT_WORKFLOW/scripts/G518_check_m3_odometry_scale.py . --selftest
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

CIBLE_PERSIST = "CODE/GVL_PERSISTENT.st"
CIBLE_SIMBENCH = "CODE/L_SIMULATION/FB_SimBench.st"
CIBLE_SIMTRAD = "CODE/L_SIMULATION/FB_Sim_Translation.st"
CIBLE_PRG02 = "CODE/M_MAIN/PRG_02_Acquisition.st"
CIBLE_PRG05 = "CODE/M_MAIN/PRG_05_Translation.st"
CIBLE_ESTIMATEUR = "CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st"
CIBLE_TESTS_SIM = "TOOLS/TEST_AUTO_CI/RESULTS/L_SIMULATION/tests/test_fb_sim_translation.st"
CIBLE_TESTS_GAIN = "TOOLS/TEST_AUTO_CI/RESULTS/I_TRANSLATION/tests/test_fb_translation_odometrygain.st"

REL_TOL = 0.01
POSITIONS = ("Tremie", "PV", "P2", "P1", "Maintenance")

# (1) Doublons interdits : declarations d'une geometrie / echelle propre au banc.
DOUBLONS_SIMTRAD = (r"\bCST_PositionAt\w*\s*:", r"\bFullTravelTimeS\s*:", r"\bCST_NominalFrequency_Hz\s*:")
DOUBLONS_SIMBENCH = (r"\bCST_M3FullTravelTimeS\s*:",)

TESTS_REQUIS_SIM = ("TC-T301-SRC-001", "TC-T301-SRC-002")
TESTS_REQUIS_GAIN = ("TC-T301-ODO-001", "TC-T301-ODO-002", "TC-T301-ODO-003")


def read(root: Path, relative: str) -> str:
    path = root / relative
    if not path.is_file():
        raise FileNotFoundError(relative)
    return path.read_text(encoding="utf-8", errors="replace")


def reel(text: str, nom: str) -> float:
    """Valeur d'une declaration `<nom> : REAL := <valeur>;`."""
    motif = re.compile(rf"\b{re.escape(nom)}\s*:\s*REAL\s*:=\s*(-?\d+(?:\.\d+)?)\s*;")
    trouve = motif.search(text)
    if not trouve:
        raise ValueError(f"declaration `{nom} : REAL := ...;` introuvable")
    return float(trouve.group(1))


def cable(text: str, gauche: str, droite: str) -> bool:
    """Vrai si l'affectation/parametre `gauche := droite` existe (espaces libres)."""
    motif = re.compile(rf"(?<![\w.]){re.escape(gauche)}\s*:=\s*{re.escape(droite)}\s*[,;)\n]")
    return motif.search(text) is not None


def ecart_relatif(a: float, b: float) -> float:
    return abs(a - b) / abs(b) if b else float("inf")


def analyse(textes: dict[str, str]) -> tuple[list[str], list[str]]:
    erreurs: list[str] = []
    avertissements: list[str] = []
    sim, bench = textes[CIBLE_SIMTRAD], textes[CIBLE_SIMBENCH]
    prg02, prg05 = textes[CIBLE_PRG02], textes[CIBLE_PRG05]

    # (1) Aucun doublon de geometrie / echelle dans le banc.
    for motif in DOUBLONS_SIMTRAD:
        if re.search(motif, sim):
            erreurs.append(f"doublon reintroduit dans FB_Sim_Translation : `{motif}` - la geometrie/echelle "
                           f"du banc doit venir de la machine (PRG_02), pas d'une constante locale")
    for motif in DOUBLONS_SIMBENCH:
        if re.search(motif, bench):
            erreurs.append(f"doublon reintroduit dans FB_SimBench : `{motif}`")

    # (2) Vitesse du banc = sens x gain recu x frequence.
    if not re.search(r"MAX\(0\.0,\s*GainMetersPerHzSec\)\s*\*\s*ActualFrequency_Hz", sim):
        erreurs.append("FB_Sim_Translation n'integre plus la vitesse par le gain recu "
                       "(attendu : TravelDirection * MAX(0.0, GainMetersPerHzSec) * ActualFrequency_Hz)")

    # (3) FB_SimBench transmet gain + positions au modele.
    if not cable(bench, "GainMetersPerHzSec", "M3_OdometryGain"):
        erreurs.append("FB_SimBench ne passe plus `GainMetersPerHzSec := M3_OdometryGain` a instSimTranslation")
    for pos in POSITIONS:
        if not cable(bench, f"Pos{pos}_M", f"M3_Pos{pos}_M"):
            erreurs.append(f"FB_SimBench ne passe plus `Pos{pos}_M := M3_Pos{pos}_M` a instSimTranslation")

    # (4) PRG_02 cable le gain EFFECTIF et les positions machine vers le banc.
    if not cable(prg02, "M3_OdometryGain", "PRG_05_Translation.Data.TranslationState.OdometryGainActive"):
        erreurs.append("PRG_02 ne cable plus le gain EFFECTIF de l'estimateur vers le banc "
                       "(`M3_OdometryGain := PRG_05_Translation.Data.TranslationState.OdometryGainActive`)")
    for pos in POSITIONS:
        if not cable(prg02, f"M3_Pos{pos}_M", f"GVL_PERSISTENT._TranslationPos{pos}_M"):
            erreurs.append(f"PRG_02 ne cable plus `M3_Pos{pos}_M := GVL_PERSISTENT._TranslationPos{pos}_M`")

    # (5) PRG_05 : estimateur sur le gain actif, publication, reglages persistants du FB de gain.
    attendus_prg05 = (
        ("GainMetersPerHzSec", "instOdometryGainM3.GainActive"),
        ("TranslationState.OdometryGainActive", "instOdometryGainM3.GainActive"),
        ("PosPV_M", "GVL_PERSISTENT._TranslationPosPV_M"),
        ("PosP2_M", "GVL_PERSISTENT._TranslationPosP2_M"),
        ("CalibFreq_Hz", "GVL_PERSISTENT._TranslationCalibFreq_Hz"),
        ("CalibTime_S", "GVL_PERSISTENT._TranslationCalibTimeP2PV_S"),
        ("FallbackGain", "GVL_PERSISTENT._TranslationGainMetersPerHzSec"),
    )
    for gauche, droite in attendus_prg05:
        if not cable(prg05, gauche, droite):
            erreurs.append(f"PRG_05 : cablage `{gauche} := {droite}` absent")

    # (6) Anti-test-vacuant.
    for cible, cas_requis in ((CIBLE_TESTS_SIM, TESTS_REQUIS_SIM), (CIBLE_TESTS_GAIN, TESTS_REQUIS_GAIN)):
        tests = textes.get(cible, "")
        for cas in cas_requis:
            if cas not in tests:
                erreurs.append(f"cas de test {cas} absent de {cible} (invariant non verifie)")

    # (7) Maximum variateur du banc = maximum reel, et cable.
    try:
        max_reel = reel(textes[CIBLE_PERSIST], "_TranslationMaxFreq_Hz")
        max_banc = reel(bench, "CST_M3MaxFreq_Hz")
        if ecart_relatif(max_banc, max_reel) > REL_TOL:
            erreurs.append(f"maximum variateur du banc DESALIGNE : CST_M3MaxFreq_Hz = {max_banc:g} Hz contre "
                           f"_TranslationMaxFreq_Hz = {max_reel:g} Hz")
    except (ValueError, KeyError) as exc:
        erreurs.append(f"maximum variateur introuvable : {exc}")
    if not cable(bench, "MaxFreq_Hz", "CST_M3MaxFreq_Hz"):
        erreurs.append("FB_SimBench ne passe plus `MaxFreq_Hz := CST_M3MaxFreq_Hz` au modele")

    # Avertissement : defaut d'estimateur different du repli.
    try:
        repli = reel(textes[CIBLE_PERSIST], "_TranslationGainMetersPerHzSec")
        defaut_est = reel(textes[CIBLE_ESTIMATEUR], "GainMetersPerHzSec")
        if ecart_relatif(defaut_est, repli) > REL_TOL:
            avertissements.append(f"defaut declare de FB_Translation_PositionEstimator.GainMetersPerHzSec = "
                                  f"{defaut_est:g} != gain de repli {repli:g} (sans effet en production, PRG_05 cable "
                                  f"le gain actif ; piege pour un test non cable)")
    except (ValueError, KeyError):
        pass

    return erreurs, avertissements


def charge_textes(root: Path) -> dict[str, str]:
    return {rel: read(root, rel) for rel in (
        CIBLE_PERSIST, CIBLE_SIMBENCH, CIBLE_SIMTRAD, CIBLE_PRG02, CIBLE_PRG05, CIBLE_ESTIMATEUR,
        CIBLE_TESTS_SIM, CIBLE_TESTS_GAIN,
    )}


def selftest(root: Path) -> int:
    """Le detecteur doit refuser chaque mutation d'incident sur l'arbre REEL, et l'accepter tel quel."""
    try:
        base = charge_textes(root)
    except FileNotFoundError as exc:
        print(f"[G518] SELFTEST FAIL - fichier introuvable : {exc}")
        return 1
    echecs: list[str] = []
    if analyse(base)[0]:
        echecs.append(f"arbre reel en echec : {analyse(base)[0]}")

    def mute(cible: str, avant: str, apres: str, libelle: str, regex: bool = False) -> None:
        textes = dict(base)
        if regex:
            nouveau, n = re.subn(avant, apres, textes[cible], count=1)
        else:
            n = textes[cible].count(avant)
            nouveau = textes[cible].replace(avant, apres, 1)
        if n == 0:
            echecs.append(f"mutation inapplicable (motif absent) : {libelle}")
            return
        textes[cible] = nouveau
        if not analyse(textes)[0]:
            echecs.append(f"mutation NON detectee : {libelle}")

    mute(CIBLE_SIMTRAD, "VAR CONSTANT", "VAR CONSTANT\n    CST_PositionAtMaintenance : REAL := 30.0;",
         "position en dur reintroduite dans le banc")
    mute(CIBLE_SIMTRAD, "VAR CONSTANT", "VAR CONSTANT\n    CST_NominalFrequency_Hz : REAL := 40.0;",
         "echelle 40 Hz reintroduite dans le banc")
    mute(CIBLE_SIMBENCH, "VAR CONSTANT", "VAR CONSTANT\n    CST_M3FullTravelTimeS : REAL := 37.5;",
         "temps de trajet en dur reintroduit dans FB_SimBench")
    mute(CIBLE_SIMTRAD, r"MAX\(0\.0,\s*GainMetersPerHzSec\)", "0.02", "vitesse banc sur gain fige", regex=True)
    mute(CIBLE_SIMBENCH, "GainMetersPerHzSec := M3_OdometryGain", "GainMetersPerHzSec := 0.02",
         "gain fige passe au modele")
    mute(CIBLE_SIMBENCH, "PosP1_M            := M3_PosP1_M", "PosP1_M            := 20.0",
         "position P1 figee passee au modele")
    mute(CIBLE_PRG02, "PRG_05_Translation.Data.TranslationState.OdometryGainActive",
         "GVL_PERSISTENT._TranslationGainMetersPerHzSec", "banc cable sur le gain de REPLI au lieu du gain effectif")
    mute(CIBLE_PRG02, "GVL_PERSISTENT._TranslationPosPV_M", "1.5", "position PV du banc figee")
    mute(CIBLE_PRG05, "GainMetersPerHzSec   := instOdometryGainM3.GainActive",
         "GainMetersPerHzSec   := GVL_PERSISTENT._TranslationGainMetersPerHzSec",
         "estimateur cable sur le repli au lieu du gain actif")
    mute(CIBLE_PRG05, "GVL_PERSISTENT._TranslationCalibTimeP2PV_S", "2.0", "temps de calibration fige")
    mute(CIBLE_TESTS_GAIN, "TC-T301-ODO-002", "TC-XXXX", "cas de test ODO supprime")
    mute(CIBLE_SIMBENCH, "MaxFreq_Hz      := CST_M3MaxFreq_Hz", "MaxFreq_Hz      := 40.0",
         "maximum variateur du banc non cable")

    if echecs:
        print("[G518] SELFTEST FAIL :")
        for echec in echecs:
            print(f"  - {echec}")
        return 1
    print("[G518] SELFTEST PASS - 12 mutations de doublon/cablage detectees, 0 faux positif sur arbre reel")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", type=Path, default=ROOT, help="racine du depot (defaut : depot)")
    parser.add_argument("--selftest", action="store_true", help="verifie que le detecteur rejette les mutations d'incident")
    args = parser.parse_args()

    root = args.root.resolve()
    if not (root / "CODE").is_dir():
        print(f"[G518] FAIL - dossier CODE introuvable sous {root}")
        return 1
    if args.selftest:
        return selftest(root)

    try:
        textes = charge_textes(root)
    except FileNotFoundError as exc:
        print(f"[G518] FAIL - fichier du controle introuvable : {exc}")
        return 1

    erreurs, avertissements = analyse(textes)
    for avertissement in avertissements:
        print(f"[G518] AVERTISSEMENT - {avertissement}")
    if erreurs:
        print("[G518] FAIL - odometrie M3 : la source unique machine -> banc est rompue :")
        for erreur in erreurs:
            print(f"  - {erreur}")
        return 1
    print("[G518] PASS - banc M3 sans geometrie ni echelle propre : positions GVL_PERSISTENT + gain effectif PRG_05")
    return 0


if __name__ == "__main__":
    sys.exit(main())
