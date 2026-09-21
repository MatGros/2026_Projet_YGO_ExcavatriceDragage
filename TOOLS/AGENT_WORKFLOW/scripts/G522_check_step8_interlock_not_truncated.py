#!/usr/bin/env python3
"""G522 - Diagnostic mouvement : Step8 ne lit JAMAIS le seul FinalInterlockError (T371).

Classe de bug couverte : le diagnostic `ST_MotionChecklist` publie `Step8_OutputInterlockOk`
(« etage de sortie LD debloque ») pour M1, M2 et M3. Ce champ etait derive du SEUL
`FinalInterlockError` — or ce booleen n'est alimente que par UNE cause de la barriere finale
(ErrorId bit0 = timeout confirmation frein, FB_WinchOutputInterlock.st:516-519 -> :528-532).

4 modes de refus REELS de la barriere laissaient donc `Step8` VERT (tous a `Fault.Error = FALSE`) :
  F1 :357-363  RestartInhibit                      -> State FAULT,              Reason RESTART_INHIBITED
  F2 :364-373  ContactorStuckLatched               -> State FAULT,              Reason SENSE_DROP_TIMEOUT
  F3 :393-404  SafeStop OR PermitFinalBlocked      -> State READY,              Reason NONE
  F4 :424-429  RestartRequired OR DeadTimePending  -> State WAIT_RESTART_DELAY, Reason NONE

⚠️ F3 et F4 gardent `Reason = NONE` et F3 garde meme `State = READY` : lire le seul `Reason` ne
   suffit pas, et lire `State` + `Reason` ne suffit pas pour F3.

🔴 REX 2026-09-21 (revue independante T371, verdict BLOCK) — LA TAUTOLOGIE A NE JAMAIS REINTRODUIRE :
   le temoin de F3 « demande vivante sans ordre emis » a d'abord ete ecrit
   `FinalMotorRequest AND NOT (State.RelayFwd OR State.RelayRev)`. C'est une TAUTOLOGIE FAUSSE :
   `State.RelayFwd/RelayRev` viennent de FB_Winch (FB_WinchStateProjection.st:102-103 <- WinchM1Ref),
   c'est-a-dire de la DEMANDE — le signal meme envoye a la barriere (PRG_04_Treuils_Benne.st:1603-1604
   `RequestedRelayFwd := instWinchM1.RelayFwd`). Or `MotorRequest` implique deja
   `RequestedRelayFwd XOR RequestedRelayRev` (FB_WinchOutputInterlock.st:182) : le terme ne pouvait
   donc JAMAIS s'armer, F3 restait vert, et le cas de test « passait » sur un etat impossible.
   ✅ Le SEUL temoin VALIDE publie est `State.BrakeCmd`, recopie de la SORTIE de la barriere
   (FB_WinchStateProjection.st:108 et :175 <- InterlockMx.BrakeCmd, soit `RelayFwd OR RelayRev`
   VALIDES, FB_WinchOutputInterlock.st:487).

Ce gate ECHOUE si :
  1. une affectation `Step8_OutputInterlockOk` est derivee du seul `FinalInterlockError`
     (RHS contenant `FinalInterlockError` sans lire `FinalInterlockState`) — mutation d'incident ;
  2. les termes qui portent les 4 modes ont disparu d'un axe M1/M2 : lecture de `FinalInterlockState`,
     etats `FAULT` + `WAIT_RESTART_DELAY` ;
  3. LE TEMOIN F3 EST REINTRODUIT SOUS FORME TAUTOLOGIQUE : le terme « demande vivante sans ordre
     valide » doit s'appuyer sur `BrakeCmd` (sortie VALIDEE) et NE DOIT PAS mentionner `RelayFwd` /
     `RelayRev` (DEMANDE) — comparaison demande/demande = terme toujours faux ;
  4. le temoin F3 a disparu d'un axe M1/M2, ou l'axe M3 ne lit plus `E_State.ERROR` ;
  5. `Step8_InterlockState` / `Step8_InterlockReason` ne sont plus publies pour un des 3 axes ;
  6. `Step8_OutputInterlockOk` a disparu du DUT `ST_MotionChecklist` (renommage/suppression — la
     retro-compatibilite IHM est exigee) ou les 2 champs de LECTURE ont disparu du DUT ;
  7. une ligne de CONDUITE consomme les 2 nouveaux champs (hors declaration DUT et publication du
     diagnostic) : usage DIAGNOSTIC UNIQUEMENT (latence N-1) ;
  8. les cas de test F1-F4 ont disparu, sont devenus vacues, ou le cas F3 est PIOTE sur un etat
     IMPOSSIBLE en exploitation (demande retiree + sortie coupee) — c'est ainsi qu'un temoin
     tautologique passe inapercu.

Usage :
    python TOOLS/AGENT_WORKFLOW/scripts/G522_check_step8_interlock_not_truncated.py [racine]
    python TOOLS/AGENT_WORKFLOW/scripts/G522_check_step8_interlock_not_truncated.py . --selftest
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

CIBLE_FB = "CODE/J_SUPERVISION/FB_TroubleshootingView.st"
CIBLE_DUT = "CODE/J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_MotionChecklist.st"
CIBLE_TESTS = "TOOLS/TEST_AUTO_CI/RESULTS/J_SUPERVISION/tests/test_fb_troubleshootingview.st"

# Les 3 axes : (variable GVL, instance lue par le diagnostic, libelle)
AXES = (
    ("N_MotionM1", "WinchM1", "M1"),
    ("O_MotionM2", "WinchM2", "M2"),
    ("P_MotionM3", "Translation", "M3"),
)

CHAMPS_LECTURE = ("Step8_InterlockState", "Step8_InterlockReason")

# Termes exiges dans la decision M1/M2 (F1/F2 : FAULT, F4 : WAIT_RESTART_DELAY, gate : DISABLED,
# F3 : temoin valide). DISABLED est le seul terme qui bascule Step8 dans une situation semi-nominale
# (gate Enable/AU) : son oubli etait indetectable dans la v1 (REX revue T371).
TERMES_M1M2 = (
    "E_WinchFinalInterlockState.FAULT",
    "E_WinchFinalInterlockState.DISABLED",
    "E_WinchFinalInterlockState.WAIT_RESTART_DELAY",
)
# Terme exige dans la decision M3 (le seul temoin ACTIF disponible est le defaut)
TERME_M3 = "E_State.ERROR"

# Interdit DANS la decision : `FinalInterlockReason` est une cause MEMORISEE, jamais remise a NONE
# apres acquittement (FB_WinchOutputInterlock.st:513 / FB_TranslationOutputInterlock.st:123-130) :
# l'injecter recreerait un FAUX ROUGE PERMANENT. Il doit rester PUBLIE, pas DECISIONNEL.
DECISION_INTERDITE = "FinalInterlockReason"

# Temoin VALIDE du refus F3 : sortie de la barriere, jamais la demande.
TEMOIN_VALIDE = "BrakeCmd"
# Signaux de DEMANDE (miroirs de FB_Winch) : interdits dans le temoin (tautologie).
DEMANDE_INTERDITE = ("RelayFwd", "RelayRev")

CAS_OBLIGATOIRES = ("TC-P14-TSV-06", "TC-P14-TSV-07", "TC-P14-TSV-08", "TC-P14-TSV-09")
CAS_F3 = "TC-P14-TSV-08"


def sans_commentaires(texte: str) -> str:
    """Retire les commentaires ST (* ... *) et // : on ne juge que le CODE."""
    texte = re.sub(r"\(\*.*?\*\)", " ", texte, flags=re.DOTALL)
    return "\n".join(ligne.split("//")[0] for ligne in texte.splitlines())


def expression_axe(code: str, variable: str) -> str | None:
    """Expression RHS de `<...>.<variable>.Step8_OutputInterlockOk := ...;`."""
    motif = re.compile(
        r"[A-Za-z_][\w.]*\." + re.escape(variable) + r"\.Step8_OutputInterlockOk\s*:=\s*(.*?);",
        re.DOTALL,
    )
    trouve = motif.search(code)
    return re.sub(r"\s+", " ", trouve.group(1)).strip() if trouve else None


def bloc_test(tests: str, cas: str) -> str:
    debut = tests.find(f"TEST '{cas}")
    if debut == -1:
        return ""
    fin = tests.find("END_TEST", debut)
    return tests[debut:fin] if fin != -1 else tests[debut:]


def analyse(
    fb_src: str, dut_src: str, tests_src: str, autres: dict[str, str]
) -> list[str]:
    """Erreurs bloquantes. Testable sans disque (selftest)."""
    erreurs: list[str] = []
    fb = sans_commentaires(fb_src)
    dut = sans_commentaires(dut_src)

    # (1)..(4) Decision par axe.
    for variable, instance, label in AXES:
        expr = expression_axe(fb, variable)
        if expr is None:
            erreurs.append(
                f"affectation `Step8_OutputInterlockOk` introuvable pour l'axe {label} "
                f"({variable}) : le diagnostic de cet axe a disparu"
            )
            continue

        if "FinalInterlockError" in expr and "FinalInterlockState" not in expr:
            erreurs.append(
                f"axe {label} : `Step8_OutputInterlockOk` est derive du SEUL FinalInterlockError "
                "(mutation d'incident T371) — 4 modes de refus reels (F1 RestartInhibit, F2 "
                "ContactorStuckLatched, F3 SafeStop/PermitFinalBlocked, F4 RestartRequired/"
                "DeadTimePending) redeviendraient verts alors que la barriere refuse"
            )
        if "FinalInterlockState" not in expr:
            erreurs.append(
                f"axe {label} : la decision ne lit plus l'ETAT publie de la barriere finale "
                "(`FinalInterlockState`) — F1/F2/F4 ne sont plus detectes"
            )

        if label in ("M1", "M2"):
            for terme in TERMES_M1M2:
                if terme not in expr:
                    erreurs.append(
                        f"axe {label} : terme de refus `{terme}` absent de la decision — "
                        "un des 4 modes de refus (ou la gate Enable/AU) n'est plus couvert"
                    )
            # (3) Temoin F3 : present ET non tautologique.
            if "FinalMotorRequest" not in expr:
                erreurs.append(
                    f"axe {label} : temoin F3 (`FinalMotorRequest`) absent de la decision — "
                    "F3 (SafeStop/PermitFinalBlocked, State=READY + Reason=NONE) redevient VERT"
                )
            elif TEMOIN_VALIDE not in expr:
                erreurs.append(
                    f"axe {label} : le temoin F3 ne s'appuie plus sur la SORTIE VALIDEE "
                    f"(`{TEMOIN_VALIDE}`) de la barriere — F3 n'est plus detectable"
                )
            interdits = [nom for nom in DEMANDE_INTERDITE if nom in expr]
            if interdits:
                erreurs.append(
                    f"axe {label} : le temoin F3 s'appuie sur la DEMANDE {interdits} au lieu de la "
                    "sortie validee -> TAUTOLOGIE (REX revue independante T371 du 2026-09-21 : "
                    "`MotorRequest` implique deja `RequestedRelayFwd XOR RequestedRelayRev`, "
                    "FB_WinchOutputInterlock.st:182, et `State.RelayFwd/RelayRev` sont ces memes "
                    "demandes, FB_WinchStateProjection.st:102-103) : le terme ne peut JAMAIS s'armer"
                )
        else:
            if TERME_M3 not in expr:
                erreurs.append(
                    f"axe {label} : terme de refus `{TERME_M3}` absent de la decision"
                )

        # `Reason` est une cause MEMORISEE : interdite dans la DECISION (faux rouge permanent).
        if DECISION_INTERDITE in expr:
            erreurs.append(
                f"axe {label} : `{DECISION_INTERDITE}` est entre dans la DECISION — c'est une cause "
                "MEMORISEE, jamais remise a NONE par un acquittement sur certains chemins "
                "(FB_WinchOutputInterlock.st:510-514, FB_TranslationOutputInterlock.st:123-130) : "
                "l'utiliser rendrait Step8 FAUX EN PERMANENCE apres acquittement (faux ROUGE). "
                "Il doit rester PUBLIE (champ de lecture), jamais DECISIONNEL."
            )

        # (5) Les 2 champs de LECTURE doivent rester publies par axe.
        for champ in CHAMPS_LECTURE:
            if f"{variable}.{champ}" not in fb:
                erreurs.append(
                    f"axe {label} : `{champ}` n'est plus publie — le technicien ne peut plus lire "
                    "l'etat/la cause reelle de la barriere depuis la checklist mouvement"
                )

    # (6) Contrat de retro-compatibilite du DUT.
    if not re.search(r"\bStep8_OutputInterlockOk\b", dut):
        erreurs.append(
            "`Step8_OutputInterlockOk` a disparu du DUT ST_MotionChecklist : renommage ou "
            "suppression interdits (retro-compatibilite IHM, T371 A2)"
        )
    for champ in CHAMPS_LECTURE:
        if not re.search(rf"\b{champ}\b\s*:", dut):
            erreurs.append(
                f"`{champ}` absent du DUT ST_MotionChecklist (champ de LECTURE exige par T371)"
            )

    # (7) Aucune ligne de CONDUITE ne consomme les 2 champs (usage DIAGNOSTIC UNIQUEMENT).
    for chemin, texte in autres.items():
        if chemin in (CIBLE_FB, CIBLE_DUT):
            continue
        code = sans_commentaires(texte)
        for champ in CHAMPS_LECTURE:
            if champ in code:
                erreurs.append(
                    f"`{champ}` consomme hors diagnostic dans `{chemin}` : ces champs sont en "
                    "latence N-1 (projection PRG_04:1688-1696) et ne doivent JAMAIS porter une "
                    "decision de conduite"
                )

    # (8) Anti-test-vacuant ET anti-etat-impossible.
    for cas in CAS_OBLIGATOIRES:
        if f"TEST '{cas}" not in tests_src:
            erreurs.append(f"cas de test {cas} absent du fichier de test (preuve F1-F4 perdue)")
            continue
        bloc = bloc_test(tests_src, cas)
        if "ASSERT_FALSE(GVL_Troubleshooting." not in bloc:
            erreurs.append(
                f"{cas} n'asserte plus que Step8 reste FALSE alors que la barriere refuse "
                "(preuve devenue vacue)"
            )
    bloc_f3 = bloc_test(tests_src, CAS_F3)
    if bloc_f3:
        if not re.search(r"BrakeCmd\s*:=\s*FALSE", bloc_f3):
            erreurs.append(
                f"{CAS_F3} ne pilote plus la SORTIE VALIDEE coupee (`BrakeCmd := FALSE`) : sans ce "
                "signal, le cas ne prouve plus rien sur F3"
            )
        if not re.search(r"RelayFwd\s*:=\s*TRUE", bloc_f3):
            erreurs.append(
                f"{CAS_F3} retire la DEMANDE (`RelayFwd := TRUE`) : cet etat est IMPOSSIBLE en "
                "exploitation (FB_Winch demande toujours pendant un refus) — c'est exactement le "
                "piege qui a masque la tautologie du premier correctif (REX revue T371)"
            )

    return erreurs


# ── Auto-test : chaque controle doit pouvoir echouer (mutations) ──────────────

def charge(root: Path) -> tuple[str, str, str, dict[str, str]]:
    fb = root / CIBLE_FB
    dut = root / CIBLE_DUT
    tests = root / CIBLE_TESTS
    for chemin in (fb, dut, tests):
        if not chemin.is_file():
            raise FileNotFoundError(str(chemin))
    autres = {
        str(p.relative_to(root)).replace("\\", "/"): p.read_text(encoding="utf-8")
        for p in sorted((root / "CODE").rglob("*.st"))
    }
    return fb.read_text(encoding="utf-8"), dut.read_text(encoding="utf-8"), tests.read_text(
        encoding="utf-8"
    ), autres


def _re_sub(texte: str, motif: str, remplacement: str) -> str:
    """Substitution regex (1re occurrence). Ancre souple : resiste au reformatage.
    DOTALL obligatoire : les expressions `Step8_*` s'etalent sur plusieurs lignes."""
    return re.sub(motif, remplacement, texte, count=1, flags=re.DOTALL)


def m_derive_seul_defaut(fb, dut, tests, autres):
    """LA mutation d'incident : retour au `NOT FinalInterlockError` seul (axe M1)."""
    nouveau = _re_sub(
        fb,
        r"(GVL_Troubleshooting\.N_MotionM1\.Step8_OutputInterlockOk\s*:=\s*).*?;",
        r"\1NOT WinchM1.State.FinalInterlockError;",
    )
    return nouveau, dut, tests, autres


def m_temoin_tautologique(fb, dut, tests, autres):
    """LE 2e incident (revue T371) : temoin F3 reconstruit sur la DEMANDE."""
    nouveau = _re_sub(
        fb,
        r"AND NOT \(WinchM1\.State\.FinalMotorRequest AND NOT WinchM1\.State\.BrakeCmd\)",
        "AND NOT (WinchM1.State.FinalMotorRequest AND NOT (WinchM1.State.RelayFwd OR WinchM1.State.RelayRev))",
    )
    return nouveau, dut, tests, autres


def m_temoin_supprime(fb, dut, tests, autres):
    """Temoin F3 entierement retire (F3 redevient vert)."""
    nouveau = _re_sub(
        fb,
        r"\s*AND NOT \(WinchM1\.State\.FinalMotorRequest AND NOT WinchM1\.State\.BrakeCmd\)",
        "",
    )
    return nouveau, dut, tests, autres


def m_etat_f4_supprime(fb, dut, tests, autres):
    """Terme WAIT_RESTART_DELAY (F4) retire d'un axe."""
    nouveau = _re_sub(
        fb,
        r"\s*AND NOT \(WinchM2\.State\.FinalInterlockState = E_WinchFinalInterlockState\.WAIT_RESTART_DELAY\)",
        "",
    )
    return nouveau, dut, tests, autres


def m_etat_m3_supprime(fb, dut, tests, autres):
    """Lecture d'etat M3 retiree."""
    nouveau = _re_sub(
        fb,
        r"\s*AND NOT \(Translation\.State\.FinalInterlockState = E_State\.ERROR\)",
        "",
    )
    return nouveau, dut, tests, autres


def m_publication_retiree(fb, dut, tests, autres):
    """Publication de la cause retiree sur un axe."""
    nouveau = _re_sub(
        fb,
        r"GVL_Troubleshooting\.O_MotionM2\.Step8_InterlockReason\s*:=\s*WinchM2\.State\.FinalInterlockReason;",
        "",
    )
    return nouveau, dut, tests, autres


def m_dut_champ_retire(fb, dut, tests, autres):
    """Champ de lecture renomme dans le DUT."""
    return fb, _re_sub(dut, r"Step8_InterlockState\s*:", "Step8_InterlockStateRenamed :"), tests, autres


def m_dut_booleen_retire(fb, dut, tests, autres):
    """`Step8_OutputInterlockOk` renomme dans le DUT (retro-compatibilite cassee)."""
    return fb, _re_sub(dut, r"Step8_OutputInterlockOk\s*:", "Step8_OutputInterlockIsOk :"), tests, autres


def m_consommation_conduite(fb, dut, tests, autres):
    """Injection d'une consommation de CONDUITE dans un PRG (latence N-1 interdite)."""
    cible = "CODE/M_MAIN/PRG_04_Treuils_Benne.st"
    if cible not in autres:
        return fb, dut, tests, autres
    autres = dict(autres)
    autres[cible] = autres[cible] + (
        "\nAutorisationConduite := GVL_Troubleshooting.N_MotionM1.Step8_InterlockState = "
        "E_WinchFinalInterlockState.READY;\n"
    )
    return fb, dut, tests, autres


def m_cas_test_supprime(fb, dut, tests, autres):
    """Cas de test F3 retire."""
    return fb, dut, _re_sub(tests, r"TEST 'TC-P14-TSV-08", "TEST 'X-P14-TSV-08"), autres


def m_cas_test_vacue(fb, dut, tests, autres):
    """Cas de test F3 rendu vacue."""
    return (
        fb,
        dut,
        _re_sub(
            tests,
            r"ASSERT_FALSE\(GVL_Troubleshooting\.N_MotionM1\.Step8_OutputInterlockOk",
            "ASSERT_TRUE(NOT GVL_Troubleshooting.N_MotionM1.Step8_OutputInterlockOk",
        ),
        autres,
    )


def m_cas_f3_etat_impossible(fb, dut, tests, autres):
    """Cas F3 piote sur un etat IMPOSSIBLE (demande retiree) : masque la tautologie."""
    return (
        fb,
        dut,
        _re_sub(
            tests,
            r"FB\.WinchM1\.State\.RelayFwd\s*:=\s*TRUE;\s*// DEMANDE presente",
            "FB.WinchM1.State.RelayFwd             := FALSE;",
        ),
        autres,
    )


def m_terme_disabled_supprime(fb, dut, tests, autres):
    """Terme DISABLED (gate Enable/AU) retire d'un axe : bascule indetectee auparavant."""
    nouveau = _re_sub(
        fb,
        r"\s*AND NOT \(WinchM1\.State\.FinalInterlockState = E_WinchFinalInterlockState\.DISABLED\)",
        "",
    )
    return nouveau, dut, tests, autres


def m_reason_dans_decision(fb, dut, tests, autres):
    """Injection de `Reason` dans la DECISION : recreerait un faux ROUGE permanent."""
    nouveau = _re_sub(
        fb,
        r"(GVL_Troubleshooting\.N_MotionM1\.Step8_OutputInterlockOk\s*:=\s*)",
        r"\1NOT (WinchM1.State.FinalInterlockReason <> E_WinchFinalInterlockReason.NONE) AND ",
    )
    return nouveau, dut, tests, autres


MUTATIONS = (
    ("derive du seul FinalInterlockError (incident T371 n1)", m_derive_seul_defaut),
    ("temoin F3 tautologique sur la DEMANDE (incident T371 n2)", m_temoin_tautologique),
    ("temoin F3 (sortie validee) entierement retire", m_temoin_supprime),
    ("etat WAIT_RESTART_DELAY (F4) retire sur un axe", m_etat_f4_supprime),
    ("terme DISABLED (gate Enable/AU) retire", m_terme_disabled_supprime),
    ("Reason (cause memorisee) injecte dans la DECISION", m_reason_dans_decision),
    ("lecture d'etat M3 retiree", m_etat_m3_supprime),
    ("publication de la cause retiree sur un axe", m_publication_retiree),
    ("champ de lecture renomme dans le DUT", m_dut_champ_retire),
    ("Step8_OutputInterlockOk renomme dans le DUT", m_dut_booleen_retire),
    ("consommation de CONDUITE injectee (latence N-1)", m_consommation_conduite),
    ("cas de test F3 retire", m_cas_test_supprime),
    ("cas de test F3 rendu vacue", m_cas_test_vacue),
    ("cas F3 piote sur un etat impossible", m_cas_f3_etat_impossible),
)


def selftest(root: Path) -> int:
    echecs: list[str] = []
    try:
        fb_reel, dut_reel, tests_reels, autres_reels = charge(root)
    except FileNotFoundError as exc:
        print(f"[G522] SELFTEST FAIL : fichier introuvable sur l'arbre reel : {exc}")
        return 1

    reels = analyse(fb_reel, dut_reel, tests_reels, autres_reels)
    if reels:
        echecs.append(f"faux positif sur l'arbre REEL : {reels}")

    for libelle, mutation in MUTATIONS:
        fb_m, dut_m, tests_m, autres_m = mutation(fb_reel, dut_reel, tests_reels, autres_reels)
        if (fb_m, dut_m, tests_m) == (fb_reel, dut_reel, tests_reels) and autres_m == autres_reels:
            echecs.append(f"mutation inoperante (ancre introuvable) : {libelle}")
            continue
        if not analyse(fb_m, dut_m, tests_m, autres_m):
            echecs.append(f"mutation NON detectee : {libelle}")

    if echecs:
        print("[G522] SELFTEST FAIL :")
        for echec in echecs:
            print(f"  - {echec}")
        return 1
    print(
        f"[G522] SELFTEST PASS - {len(MUTATIONS)} mutations refusees, "
        "0 faux positif sur arbre reel"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("root", nargs="?", type=Path, default=ROOT, help="racine du depot (defaut : depot)")
    parser.add_argument("--selftest", action="store_true", help="verifie que le detecteur rejette les mutations")
    args = parser.parse_args()

    root = args.root.resolve()
    if not (root / "CODE").is_dir():
        print(f"[G522] FAIL - dossier CODE introuvable sous {root}")
        return 1

    if args.selftest:
        return selftest(root)

    try:
        fb_src, dut_src, tests_src, autres = charge(root)
    except FileNotFoundError as exc:
        print(f"[G522] FAIL - fichier du controle introuvable : {exc}")
        return 1

    erreurs = analyse(fb_src, dut_src, tests_src, autres)
    if erreurs:
        print("[G522] FAIL - le diagnostic mouvement tronque a nouveau l'etat de la barriere finale :")
        for erreur in erreurs:
            print(f"  - {erreur}")
        return 1

    print(
        "[G522] PASS - Step8 derive de l'ETAT publie de la barriere finale sur les 3 axes "
        "(M1/M2 : FAULT + WAIT_RESTART_DELAY + temoin F3 sur la SORTIE VALIDEE BrakeCmd, "
        "jamais sur la demande RelayFwd/RelayRev ; M3 : defaut + etat), Step8_OutputInterlockOk "
        "conserve, etat/cause publies, aucune consommation de CONDUITE"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
