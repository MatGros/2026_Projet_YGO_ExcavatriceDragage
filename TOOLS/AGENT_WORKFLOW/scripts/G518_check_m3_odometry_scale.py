#!/usr/bin/env python3
"""G518 - Echelle odometrique M3 : le banc et l'estimateur doivent PARTAGER le meme ratio (T361).

Classe de bug couverte (trace Suivi_74, audit T360) : le banc SimBench et l'estimateur de
position M3 integrent la MEME frequence retournee par le variateur, mais chacun avec une
echelle construite de son cote :

  * estimateur   : dx = f x GainMetersPerHzSec x dt, gain cable en PRG_05_Translation.st sur
                   GVL_PERSISTENT._TranslationGainMetersPerHzSec (source unique, 0,02 m/(Hz.s)) ;
  * banc         : dx = f x (CST_PositionAtMaintenance / (f_nominale x FullTravelTimeS)) x dt.

Aucun gate ne reliait ces deux expressions. Le banc est donc reste a 8,0 s (ratio 0,09375)
alors que le gain reel passait a 0,02 : rapport 4,7. L'estimateur prenait un retard constant
et CHAQUE franchissement de capteur forcait un saut de plusieurs metres (4,53 / 9,12 / 4,59 m
mesures). C'est la marque d'une echelle partagee sans garde-fou : le defaut se representera a
la prochaine calibration du gain (T301).

Ce gate ECHOUE si :
  1. le ratio du banc (30 m / (40 Hz x CST_M3FullTravelTimeS)) ne vaut pas le gain odometrique
     persistant a REL_TOL pres ;
  2. le defaut declare de FB_Sim_Translation.FullTravelTimeS ne vaut pas la meme echelle (une
     instanciation hors SimBench doit rester coherente) ;
  3. la constante CST_M3FullTravelTimeS n'est plus PASSEE a instSimTranslation (constante
     morte : le gate passerait alors sur une valeur qui n'atteint plus le modele) ;
  4. les cas de test TC-T361-ALIGN-001 / -002 ont disparu du fichier de test, ou si le fichier
     n'asserte plus l'echelle 0,02 (anti-test-vacuant) ;
  5. le gain n'est plus injecte dans l'estimateur depuis GVL_PERSISTENT (PRG_05_Translation).

Signale SANS bloquer (perimetre d'autres acteurs) : le defaut declare de
FB_Translation_PositionEstimator.GainMetersPerHzSec, s'il diverge du gain persistant.

Regle couverte : TASK_CONTRACT_T361_SIMU_RATIO_M3.yaml (AC1, AC2, AC3, AC5).
Origine : AUDIT_T360_TRACE_RATIO_ESTIMATEUR_M3_20260921.md.

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
CIBLE_PRG05 = "CODE/M_MAIN/PRG_05_Translation.st"
CIBLE_ESTIMATEUR = "CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st"
CIBLE_TESTS = "TOOLS/TEST_AUTO_CI/RESULTS/L_SIMULATION/tests/test_fb_sim_translation.st"

# Tolerance RELATIVE entre les deux echelles. 1 % est une marge de lisibilite : les deux
# expressions sont algebriquement identiques, seule l'ecriture decimale differe.
REL_TOL = 0.01

# Cas de test portant l'invariant du lot (doivent exister, sinon le gate serait vacuant).
TESTS_REQUIS = ("TC-T361-ALIGN-001", "TC-T361-ALIGN-002")
# Valeur d'echelle que les cas de test doivent asserter (m/(Hz.s)).
ECHELLE_TEST = 0.02

# Cablage de la constante du banc vers le modele : sans lui, la constante est morte.
CABLAGE_BANC = "FullTravelTimeS := CST_M3FullTravelTimeS"
# Cablage du gain persistant vers l'estimateur.
CABLAGE_GAIN = "GainMetersPerHzSec   := GVL_PERSISTENT._TranslationGainMetersPerHzSec"


def read(root: Path, relative: str) -> str:
    path = root / relative
    if not path.is_file():
        raise FileNotFoundError(relative)
    return path.read_text(encoding="utf-8", errors="replace")


def reel(text: str, nom: str) -> float:
    """Valeur d'une declaration `<nom> : REAL := <valeur>;` (nom litteral, sans regex utilisateur)."""
    motif = re.compile(rf"\b{re.escape(nom)}\s*:\s*REAL\s*:=\s*(-?\d+(?:\.\d+)?)\s*;")
    trouve = motif.search(text)
    if not trouve:
        raise ValueError(f"declaration `{nom} : REAL := ...;` introuvable")
    return float(trouve.group(1))


def echelle_banc(pos_maintenance: float, freq_nominale: float, temps_trajet: float) -> float:
    """Ratio m/(Hz.s) reellement integre par le banc pour une frequence retournee f."""
    if freq_nominale <= 0.0 or temps_trajet <= 0.0:
        raise ValueError("frequence nominale ou temps de trajet non exploitable")
    return pos_maintenance / (freq_nominale * temps_trajet)


def ecart_relatif(a: float, b: float) -> float:
    return abs(a - b) / abs(b) if b else float("inf")


def analyse(textes: dict[str, str]) -> tuple[list[str], list[str]]:
    """Retourne (erreurs bloquantes, avertissements). Testable sans disque (selftest)."""
    erreurs: list[str] = []
    avertissements: list[str] = []

    try:
        gain = reel(textes[CIBLE_PERSIST], "_TranslationGainMetersPerHzSec")
        t_banc = reel(textes[CIBLE_SIMBENCH], "CST_M3FullTravelTimeS")
        t_defaut = reel(textes[CIBLE_SIMTRAD], "FullTravelTimeS")
        pos_maint = reel(textes[CIBLE_SIMTRAD], "CST_PositionAtMaintenance")
        freq_nom = reel(textes[CIBLE_SIMTRAD], "CST_NominalFrequency_Hz")
    except (ValueError, KeyError) as exc:
        return [f"lecture impossible : {exc}"], avertissements

    ratio_banc = echelle_banc(pos_maint, freq_nom, t_banc)
    ratio_defaut = echelle_banc(pos_maint, freq_nom, t_defaut)

    # (1) Echelle REELLEMENT utilisee en simulation (CST_M3FullTravelTimeS).
    if ecart_relatif(ratio_banc, gain) > REL_TOL:
        erreurs.append(
            f"echelle du banc DESALIGNEE : ratio = {pos_maint:g} / ({freq_nom:g} x {t_banc:g}) "
            f"= {ratio_banc:.6f} m/(Hz.s) contre gain persistant {gain:.6f} m/(Hz.s) "
            f"(rapport {ratio_banc / gain:.3f}) - chaque franchissement de capteur produira "
            f"un saut de recalage ; recalculer CST_M3FullTravelTimeS = {pos_maint:g} / "
            f"({freq_nom:g} x {gain:g}) = {pos_maint / (freq_nom * gain):g} s"
        )

    # (2) Defaut declare du FB : une instanciation hors SimBench doit rester coherente.
    if ecart_relatif(ratio_defaut, gain) > REL_TOL:
        erreurs.append(
            f"defaut declare de FB_Sim_Translation.FullTravelTimeS ({t_defaut:g} s) hors echelle : "
            f"ratio {ratio_defaut:.6f} contre {gain:.6f} m/(Hz.s) - valeur attendue "
            f"{pos_maint / (freq_nom * gain):g} s"
        )

    # (3) Anti-constante-morte : la valeur du banc doit ATTEINDRE le modele.
    if CABLAGE_BANC not in textes[CIBLE_SIMBENCH]:
        erreurs.append(
            f"`{CABLAGE_BANC}` absent de FB_SimBench.st : CST_M3FullTravelTimeS n'atteint plus "
            f"le modele, le controle d'echelle porterait sur une constante morte"
        )

    # (4) Anti-test-vacuant.
    tests = textes.get(CIBLE_TESTS, "")
    for cas in TESTS_REQUIS:
        if cas not in tests:
            erreurs.append(f"cas de test {cas} absent de {CIBLE_TESTS} (invariant non verifie)")
    if f"{ECHELLE_TEST:g}" not in tests:
        erreurs.append(
            f"aucune assertion d'echelle {ECHELLE_TEST:g} m/(Hz.s) dans {CIBLE_TESTS}"
        )

    # (5) Le gain doit rester injecte dans l'estimateur depuis la source persistante unique.
    if CABLAGE_GAIN not in textes[CIBLE_PRG05]:
        erreurs.append(
            "le gain odometrique n'est plus injecte dans l'estimateur depuis GVL_PERSISTENT "
            f"({CIBLE_PRG05}) : le gate ne saurait plus quelle echelle est la reference"
        )

    # Avertissement (perimetre d'autres acteurs, sans effet au runtime : PRG_05 injecte la
    # valeur persistante) - un defaut de FB perime reste un piege pour les tests unitaires.
    try:
        defaut_est = reel(textes[CIBLE_ESTIMATEUR], "GainMetersPerHzSec")
        if ecart_relatif(defaut_est, gain) > REL_TOL:
            avertissements.append(
                f"defaut declare de FB_Translation_PositionEstimator.GainMetersPerHzSec = "
                f"{defaut_est:g} alors que le gain persistant vaut {gain:g} : sans effet en "
                f"production (PRG_05 injecte la valeur persistante), mais toute instanciation "
                f"de test qui ne cable pas le gain utilise une echelle perimee"
            )
    except (ValueError, KeyError):
        pass

    return erreurs, avertissements


def charge_textes(root: Path) -> dict[str, str]:
    return {rel: read(root, rel) for rel in (
        CIBLE_PERSIST, CIBLE_SIMBENCH, CIBLE_SIMTRAD, CIBLE_PRG05, CIBLE_ESTIMATEUR, CIBLE_TESTS,
    )}


# ── Mutations de reference (preuve que le detecteur voit la classe de bug) ────────────────

def _textes_de_reference() -> dict[str, str]:
    """Arbre minimal reproduisant les invariants : sert de base aux mutations du selftest."""
    return {
        CIBLE_PERSIST: '_TranslationGainMetersPerHzSec  : REAL := 0.02; // 50 Hz = 1.0 m/s\n',
        CIBLE_SIMBENCH: (
            "CST_M3FullTravelTimeS       : REAL := 37.5;\n"
            "instSimTranslation(\n    FullTravelTimeS := CST_M3FullTravelTimeS,\n);\n"
        ),
        CIBLE_SIMTRAD: (
            "    FullTravelTimeS : REAL := 37.5;\n"
            "    CST_PositionAtMaintenance : REAL := 30.0;\n"
            "    CST_NominalFrequency_Hz : REAL := 40.0;\n"
        ),
        CIBLE_PRG05: "    GainMetersPerHzSec   := GVL_PERSISTENT._TranslationGainMetersPerHzSec,\n",
        CIBLE_ESTIMATEUR: "    GainMetersPerHzSec   : REAL := 0.008333;\n",
        CIBLE_TESTS: (
            "TEST 'TC-T361-ALIGN-001 Ratio odometrique du banc = gain reel 0,02 m/(Hz.s)'\n"
            "TEST 'TC-T361-ALIGN-002 Distance banc = integrale f x 0,02 m/(Hz.s) sur 6 s'\n"
            "    ASSERT_NEAR(fb.VelocityTrue_Mps / fb.ActualFrequency_Hz, 0.02, 0.0002, '...');\n"
        ),
    }


def selftest(root: Path) -> int:
    """Le detecteur doit voir chaque mutation d'incident, et rester vert sur l'arbre conforme."""
    echecs: list[str] = []

    def erreurs_de(mutation) -> list[str]:
        textes = _textes_de_reference()
        mutation(textes)
        return analyse(textes)[0]

    # (0) La reference elle-meme doit passer (sinon le selftest ne prouve rien).
    if erreurs_de(lambda t: None):
        echecs.append(f"faux positif sur l'arbre de reference : {erreurs_de(lambda t: None)}")

    # (1) Mutation REELLE de l'incident : retour a l'ancien temps de trajet du banc.
    def mutation_banc_8s(t):
        t[CIBLE_SIMBENCH] = t[CIBLE_SIMBENCH].replace("37.5", "8.0")

    if not erreurs_de(mutation_banc_8s):
        echecs.append("mutation NON detectee : CST_M3FullTravelTimeS remis a 8,0 s (motif d'incident)")

    # (2) Mutation du DEFAUT du FB seul.
    def mutation_defaut_8s(t):
        t[CIBLE_SIMTRAD] = t[CIBLE_SIMTRAD].replace("FullTravelTimeS : REAL := 37.5", "FullTravelTimeS : REAL := 8.0")

    if not erreurs_de(mutation_defaut_8s):
        echecs.append("mutation NON detectee : defaut FullTravelTimeS remis a 8,0 s")

    # (3) Calibration du gain sans recalcul du banc (le scenario T301).
    def mutation_gain(t):
        t[CIBLE_PERSIST] = t[CIBLE_PERSIST].replace("0.02", "0.025")

    if not erreurs_de(mutation_gain):
        echecs.append("mutation NON detectee : gain recalibre a 0,025 sans mise a jour du banc")

    # (4) Constante morte : la valeur du banc n'est plus passee au modele.
    def mutation_cablage_mort(t):
        t[CIBLE_SIMBENCH] = t[CIBLE_SIMBENCH].replace(
            "FullTravelTimeS := CST_M3FullTravelTimeS", "FullTravelTimeS := 37.5"
        )

    if not erreurs_de(mutation_cablage_mort):
        echecs.append("mutation NON detectee : CST_M3FullTravelTimeS n'est plus passee au modele")

    # (5) Gain plus injecte dans l'estimateur (reference d'echelle perdue).
    def mutation_gain_non_injecte(t):
        t[CIBLE_PRG05] = "    GainMetersPerHzSec   := 0.02,\n"

    if not erreurs_de(mutation_gain_non_injecte):
        echecs.append("mutation NON detectee : gain non injecte depuis GVL_PERSISTENT")

    # (6) Test vacant : cas d'alignement supprimes.
    def mutation_tests_supprimes(t):
        t[CIBLE_TESTS] = "TEST 'TC-T300-MEC-010 Le chariot suit la frequence'\n"

    if not erreurs_de(mutation_tests_supprimes):
        echecs.append("mutation NON detectee : cas de test d'alignement supprimes")

    # (7) Echelle CONFORME recalculee (0,025 m/(Hz.s) => 30 s) : aucun faux positif attendu.
    def mutation_conforme(t):
        t[CIBLE_PERSIST] = t[CIBLE_PERSIST].replace("0.02", "0.025")
        t[CIBLE_SIMBENCH] = t[CIBLE_SIMBENCH].replace("37.5", "30.0")
        t[CIBLE_SIMTRAD] = t[CIBLE_SIMTRAD].replace("FullTravelTimeS : REAL := 37.5", "FullTravelTimeS : REAL := 30.0")

    if erreurs_de(mutation_conforme):
        echecs.append(f"faux positif : echelle conforme recalculee refusee : {erreurs_de(mutation_conforme)}")

    # (8) Preuve sur l'arbre REEL : conforme, et sa mutation d'incident est bien vue.
    try:
        textes = charge_textes(root)
    except FileNotFoundError as exc:
        echecs.append(f"fichier du controle introuvable sur l'arbre reel : {exc}")
    else:
        reels, _ = analyse(textes)
        if reels:
            echecs.append(f"arbre reel en echec : {reels}")
        mute = dict(textes)
        mute[CIBLE_SIMBENCH] = mute[CIBLE_SIMBENCH].replace("37.5", "8.0", 1)
        if not analyse(mute)[0]:
            echecs.append("mutation de l'arbre REEL non detectee (CST_M3FullTravelTimeS -> 8,0)")

    if echecs:
        print("[G518] SELFTEST FAIL :")
        for echec in echecs:
            print(f"  - {echec}")
        return 1
    print("[G518] SELFTEST PASS - 6 mutations d'echelle detectees, 0 faux positif sur arbre conforme")
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
        print("[G518] FAIL - echelle odometrique M3 non partagee entre le banc et l'estimateur :")
        for erreur in erreurs:
            print(f"  - {erreur}")
        return 1

    gain = reel(textes[CIBLE_PERSIST], "_TranslationGainMetersPerHzSec")
    t_banc = reel(textes[CIBLE_SIMBENCH], "CST_M3FullTravelTimeS")
    pos_maint = reel(textes[CIBLE_SIMTRAD], "CST_PositionAtMaintenance")
    freq_nom = reel(textes[CIBLE_SIMTRAD], "CST_NominalFrequency_Hz")
    print(
        f"[G518] PASS - banc et estimateur partagent l'echelle odometrique : "
        f"{pos_maint:g} m / ({freq_nom:g} Hz x {t_banc:g} s) = {echelle_banc(pos_maint, freq_nom, t_banc):.6f} "
        f"= gain persistant {gain:.6f} m/(Hz.s)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
