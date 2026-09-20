#!/usr/bin/env python3
"""G515 — Seuil IHM d'ouverture benne : branche ADDITIVE, qualifiee, bornee (T262 phase B).

Classe de bug couverte (deux formes, toutes deux observees sur ce depot) :

1. **Champ IHM mort.** `ExtractionStartOpening_Pct` a existe du 2026-09-15 au 2026-09-21
   en etant declare, borne et persiste — mais lu par AUCUNE logique de transition. Le
   contrat promettait un reglage operateur ; l'operateur ne reglait rien. Un seuil qui
   n'est pas consomme par les DEUX sites qui contraignent la transition (l'arrivee de
   fermeture de `FB_Bucket` ET la tolerance matiere de `PRG_04`) reste mort : c'est la
   conjonction de `FB_CycleSemiAuto.st:1298` qui l'impose.

2. **Branche substitutive au lieu d'additive.** La tolerance matiere 2,0 m et
   l'anticipation de fermeture 1,2 m sont des FILETS ANTI-BLOCAGE documentes (matiere
   dense / galets qui ne ferme jamais a 100 %). Les remplacer par un seuil configurable
   ouvre une discontinuite : `0 %` deviendrait plus permissif que `1 %`, et le plancher
   historique disparaitrait. Regle : les deux expressions historiques restent le TEXTE
   D'ORIGINE ; le seuil est une DISJONCTION ajoutee.

Controles (tous bloquants) :
  C1  l'arrivee de fermeture historique de FB_Bucket est presente, mot pour mot ;
  C2  elle est suivie LOCALEMENT de la disjonction `OR ...Reached` (branche ajoutee) ;
  C3  `CloseAnticipationM` n'est jamais affecte (l'anticipation historique est intacte) ;
  C4  la tolerance matiere 2,0 m de PRG_04 est presente, mot pour mot ;
  C5  elle est suivie LOCALEMENT de la disjonction de la branche seuil ;
  C6  le reglage est REELLEMENT lu (GVL_IHM...ExtractionStartOpening_Pct cable) ;
  C7  FB_Bucket recoit le reglage par son interface declaree (aucune lecture cachee de GVL) ;
  C8  la branche est QUALIFIEE : `MeasureValid AND IsIntermediate` dans le FB de decision ;
  C9  la geometrie est VIVANTE (debattement), jamais un litteral en dur ;
  C10 la borne du FB de decision et celle du bornage PRG_07 sont EGALES.

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/G515_check_t262_bucket_opening_threshold.py [racine]
  python TOOLS/AGENT_WORKFLOW/scripts/G515_check_t262_bucket_opening_threshold.py --selftest
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

F_BUCKET = "CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st"
F_THRESH = "CODE/H_TREUILS_BENNE/BENNE/FB_BucketCloseThreshold.st"
F_PRG04 = "CODE/M_MAIN/PRG_04_Treuils_Benne.st"
F_PRG07 = "CODE/M_MAIN/PRG_07_Supervision.st"

# Expressions HISTORIQUES — doivent rester le texte d'origine (A′).
HIST_ARRIVAL = "CablePosM2 >= (CablePosM1 + Config.OffsetCloseM - Config.CloseAnticipationM)"
HIST_TOLERANCE = "instBucket.DeltaPosition_M >= (_BucketCfgPersist.Config.OffsetCloseM - 2.0)"

# Localite : la disjonction ajoutee doit suivre l'expression historique de tres pres.
LOCAL_WINDOW = 120

CONSUMED_OR = "OR instCloseThreshold.Reached"
WIRED_INPUT = "CloseReachedOpening_Pct := GVL_IHM.CycleSemiAuto.Cfg.ExtractionStartOpening_Pct"
QUALIFY_GUARD = "MeasureValid AND IsIntermediate"
LIMIT_FB = re.compile(r"CST_MaxThresholdPct\s*:\s*INT\s*:=\s*(\d+)")
LIMIT_PRG07 = re.compile(
    r"ExtractionStartOpening_Pct\s*:=\s*LIMIT\(\s*0\s*,\s*GVL_IHM\.CycleSemiAuto\.Cfg\.ExtractionStartOpening_Pct\s*,\s*(\d+)\s*\)"
)
ANTICIPATION_WRITE = re.compile(r"CloseAnticipationM\s*:=")
HARDCODED_SPAN = re.compile(r"Distance_M\s*:=[^\n;]*\b15(?:\.0+)?\b")
DEAD_FIELD = re.compile(r"ExtractionStartOpening_Pct\s*:=")


def require(text: str, fragment: str, label: str, errors: list[str]) -> None:
    if fragment not in text:
        errors.append(f"{label} : fragment attendu absent -> `{fragment}`")


def require_near(text: str, anchor: str, fragment: str, label: str, errors: list[str]) -> None:
    """Le fragment doit apparaitre dans la fenetre locale qui suit l'ancre."""
    pos = text.find(anchor)
    if pos < 0:
        errors.append(f"{label} : ancre absente -> `{anchor}`")
        return
    window = text[pos: pos + len(anchor) + LOCAL_WINDOW]
    if fragment not in window:
        errors.append(f"{label} : `{fragment}` absent dans les {LOCAL_WINDOW} caracteres suivant l'ancre")


def check(texts: dict[str, str]) -> list[str]:
    errors: list[str] = []
    bucket = texts[F_BUCKET]
    thresh = texts[F_THRESH]
    prg04 = texts[F_PRG04]
    prg07 = texts[F_PRG07]

    # C1/C2 — arrivee de fermeture : historique intact + disjonction locale.
    require(bucket, HIST_ARRIVAL, "C1 arrivee de fermeture historique (FB_Bucket)", errors)
    require_near(bucket, HIST_ARRIVAL, CONSUMED_OR, "C2 disjonction ajoutee a l'arrivee (FB_Bucket)", errors)

    # C3 — l'anticipation historique n'est jamais affectee.
    if ANTICIPATION_WRITE.search(bucket):
        errors.append(
            "C3 `CloseAnticipationM` est AFFECTE dans FB_Bucket : l'anticipation historique "
            "(1,2 m, filet anti-blocage) doit rester intacte — le seuil est une branche ADDITIVE"
        )

    # C4/C5 — tolerance matiere : historique intact + disjonction locale.
    require(prg04, HIST_TOLERANCE, "C4 tolerance matiere 2,0 m historique (PRG_04)", errors)
    require_near(prg04, HIST_TOLERANCE, CONSUMED_OR, "C5 disjonction ajoutee a la tolerance (PRG_04)", errors)

    # C6 — le reglage est REELLEMENT consomme (anti-champ-mort). On compte les lectures
    # hors affectations : une affectation est un BORNAGE, pas une consommation.
    reads = [
        line
        for line in prg04.splitlines()
        if "ExtractionStartOpening_Pct" in line and not DEAD_FIELD.search(line) and not line.strip().startswith("//")
    ]
    if len(reads) < 2:
        errors.append(
            f"C6 seuil NON CONSOMME par les DEUX sites (FB_Bucket + PRG_04) : "
            f"{len(reads)} lecture(s) hors bornage trouvee(s) — le champ serait a nouveau mort"
        )

    # C7 — le reglage entre dans FB_Bucket par son interface declaree, jamais par GVL cachee.
    require(prg04, WIRED_INPUT, "C7 cablage du reglage vers l'interface de FB_Bucket (PRG_04)", errors)
    require(bucket, "CloseReachedOpening_Pct", "C7 interface declaree de FB_Bucket", errors)
    if "GVL_IHM" in bucket:
        errors.append(
            "C7 FB_Bucket lit GVL_IHM directement : canal cache interdit — la configuration "
            "doit entrer par l'interface declaree (produit par PRG_04)"
        )

    # C8 — la branche est qualifiee (mesure fiable ET position plausible).
    require(thresh, QUALIFY_GUARD, "C8 qualification `MeasureValid AND IsIntermediate`", errors)

    # C9 — geometrie vivante, jamais un litteral en dur dans la conversion.
    require(thresh, "Span_M := OffsetCloseM - OffsetOpenM", "C9 debattement vivant", errors)
    if HARDCODED_SPAN.search(thresh):
        errors.append("C9 `Distance_M` calcule sur un litteral 15 en dur : la geometrie persistee est modifiable")

    # C10 — les deux bornes doivent rester EGALES.
    m_fb = LIMIT_FB.search(thresh)
    m_prg = LIMIT_PRG07.search(prg07)
    if not m_fb:
        errors.append("C10 borne du FB de decision introuvable (CST_MaxThresholdPct)")
    if not m_prg:
        errors.append("C10 bornage PRG_07 introuvable (LIMIT(0, ..., N))")
    if m_fb and m_prg and m_fb.group(1) != m_prg.group(1):
        errors.append(
            f"C10 bornes DIVERGENTES : FB de decision = {m_fb.group(1)} %, bornage PRG_07 = {m_prg.group(1)} % "
            "— une divergence rend la defense en profondeur inoperante"
        )

    return errors


def load(root: Path) -> dict[str, str]:
    return {
        rel: (root / rel).read_text(encoding="utf-8", errors="replace")
        for rel in (F_BUCKET, F_THRESH, F_PRG04, F_PRG07)
    }


MUTATIONS = [
    ("branche seuil retiree de la tolerance PRG_04 (retour au champ mort)", F_PRG04, CONSUMED_OR, ""),
    ("branche seuil retiree de l'arrivee FB_Bucket (seuil inoperant)", F_BUCKET, CONSUMED_OR, ""),
    ("tolerance historique REEECRITE (2,0 m remplace par la branche seuil)", F_PRG04, HIST_TOLERANCE,
     "instCloseThreshold.Reached"),
    ("anticipation historique AFFECTEE", F_BUCKET,
     "            ThresholdMeasureValid := ClassCanRun", "            Config.CloseAnticipationM := 3.0;\n            ThresholdMeasureValid := ClassCanRun"),
    ("garde de qualification retiree", F_THRESH, QUALIFY_GUARD, "TRUE"),
    ("geometrie gelee sur un litteral 15", F_THRESH,
     "Distance_M := INT_TO_REAL(ThresholdEffPct) * Span_M * CST_PctToRatio",
     "Distance_M := INT_TO_REAL(ThresholdEffPct) * 15.0 * CST_PctToRatio"),
    ("borne du bornage PRG_07 desserree a 50 (divergence)", F_PRG07, ", 20)", ", 50)"),
    ("cablage du reglage retire (champ a nouveau mort)", F_PRG04, WIRED_INPUT,
     "CloseReachedOpening_Pct := 0"),
]


def selftest(root: Path) -> int:
    """Le detecteur doit voir chaque mutation, et ne rien lever sur l'arbre reel."""
    base = load(root)
    failures: list[str] = []

    if check(base):
        failures.append("faux positif sur l'arbre REEL : " + " | ".join(check(base)))

    for label, fname, old, new in MUTATIONS:
        mutated = dict(base)
        if old not in mutated[fname]:
            failures.append(f"mutation inapplicable ({label}) : motif introuvable dans {fname}")
            continue
        mutated[fname] = mutated[fname].replace(old, new, 1)
        if not check(mutated):
            failures.append(f"mutation NON detectee : {label}")

    if failures:
        print("[G515] SELFTEST FAIL :")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print(f"[G515] SELFTEST PASS — {len(MUTATIONS)} mutations rejetees, aucun faux positif sur l'arbre reel")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", type=Path, default=ROOT, help="racine du depot (defaut : depot)")
    parser.add_argument("--selftest", action="store_true", help="verifie que le detecteur rejette des mutations")
    args = parser.parse_args()

    root = args.root.resolve()
    if not (root / "CODE").is_dir():
        print(f"[G515] FAIL — dossier CODE introuvable sous {root}")
        return 1

    if args.selftest:
        return selftest(root)

    errors = check(load(root))
    if errors:
        print("[G515] FAIL — seuil IHM d'ouverture benne (T262 phase B) :")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("[G515] PASS — branche seuil ADDITIVE (historiques intacts), qualifiee, bornee et consommee par les deux sites")
    return 0


if __name__ == "__main__":
    sys.exit(main())
