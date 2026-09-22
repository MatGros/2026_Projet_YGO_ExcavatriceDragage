#!/usr/bin/env python3
"""G504 - Garde-fou T330 : invariant haut (reglages TOP / FDC / ralentissement).

Remplace la regle historique ERRONEE de G483 AC2b (« reserve <= bande de ralentissement »),
ABROGEE par decision humaine Q1 du 2026-09-20 (plan C3 T330 v1.3).

DEUX regles DISTINCTES, controlees SEPAREMENT :
  (1) ReserveTop_M = CfgTopSensorPos_M - CfgCableLimitAscent_M >= 1.00 m
  (2) WinchSlowdownDistanceTop_M >= 0.50 m          (jamais comparee a la reserve)

Controles
---------
  G504-1   reserve >= 1.00 m sur les defauts persistes ET les defauts de type
  G504-2   ralentissement haut >= 0.50 m, evalue SEUL
  G504-3   aucun nom de champ introuvable : tout symbole lu doit exister,
           JAMAIS de repli numerique muet (REX 2026-09-20 : champ fantome)
  G504-4   aucun NOUVEAU champ de reglage haut (baseline figee, validee humainement)
  G504-5   bornes absolues Q21 : FDC dans [0 ; 9.00], TOP dans [1 ; 10.00]
  G504-6   aucun clamp MUET : toute ecriture de correction porte un message
  G504-7   les gardes sont des CST_* locales : ni persistantes, ni IHM
  G504-8   dans CODE/, les noms INEXISTANTS de la commande sont absents
           (PositionHomingTop_M / PositionFdcLogicielHaut_M)
  G504-9   les 3 exceptions de montee vers le TOP sont NOMMEES (AC5)
  G504-10  R0 (clamp absolu) est INCONDITIONNELLE et EN AMONT de la regle Delta (Q21 bis)

Perimetre : lecture seule. Informatif par defaut (exit 0) ; --strict -> exit 2.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
GVL = ROOT / "CODE" / "GVL_PERSISTENT.st"
WINCHCFG = ROOT / "CODE" / "J_SUPERVISION" / "_TYPES" / "1_TREUILS_BENNE" / "ST_WinchCfg.st"
COMMUNCFG = ROOT / "CODE" / "J_SUPERVISION" / "_TYPES" / "7_COMMUN_CONFIG" / "ST_CommunCfg.st"
PRG07 = ROOT / "CODE" / "M_MAIN" / "PRG_07_Supervision.st"
# T341 : le CORPS de la normalisation a ete extrait de PRG_07 vers ce FB dedie
# (CODE_QUALITY_STANDARDS §10.2 -- aucune logique metier inline dans un PRG).
# Le bloc de regles controle par G504-6 / G504-10 est donc balise DANS LE FB ;
# le cablage du signal de homing (G504-9) reste dans PRG_07, au site d'appel.
FB_NORMALIZER = ROOT / "CODE" / "J_SUPERVISION" / "FB_CfgT330Normalizer.st"
CODE = ROOT / "CODE"

# Bornes Q21 (plan v1.3, decision C1 : TOP dans [-20 ; 25] et FDC dans [-25 ; 20])
FDC_MIN, FDC_MAX = -25.00, 20.00
TOP_MIN, TOP_MAX = -20.00, 25.00
RESERVE_MIN = 1.00
SLOWDOWN_MIN = 0.50

# Baseline G504-4 : champs de reglage haut LEGITIMES a la date de creation du gate.
# Toute valeur HORS de cette liste dans les fichiers de declaration = champ NEUF -> FAIL.
BASELINE_FIELDS = {
    "CfgCableLimitAscent_M",
    "CfgTopSensorPos_M",
    "CfgCableLimitDescent_M",
    "WinchSlowdownDistanceTop_M",
    "WinchSlowdownDistanceBottom_M",
    "WinchSlowdownMaxStep",
    "WinchMaxStepAscent",
    "WinchMaxStepDescent",
}
FIELD_PATTERNS = (
    r"LimitAscent", r"HomingTop", r"Fdc", r"TopSensorPos", r"Slowdown",
)
# Noms INTERDITS dans CODE/ : libelles de la commande qui n'existent PAS dans le projet.
FORBIDDEN_CODE_NAMES = ("PositionHomingTop_M", "PositionFdcLogicielHaut_M")
# Les 3 exceptions de montee vers le TOP (contrat AC5).
TOP_EXCEPTIONS = ("InReferencingMode", "OverrideTopSoftwareN1", "BypassTopLimitSoftware")
REGION_OPEN = '{region "\U0001f527 T330 NORMALISATION"}'


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError:
        return ""


def missing(path: Path, errors: list[str], label: str) -> bool:
    """G504-3 : un nom introuvable est une ERREUR, jamais un repli silencieux."""
    if not path.is_file():
        errors.append(f"G504-3 fichier introuvable ({label}) : {path.relative_to(ROOT)}")
        return True
    return False


def find_value(text: str, name: str) -> float | None:
    """Valeur d'un champ DANS un fichier donne. Retourne None si absent (jamais de defaut muet)."""
    m = re.search(rf"\b{re.escape(name)}\s*:=\s*(-?[0-9]+(?:\.[0-9]+)?)", text)
    return float(m.group(1)) if m else None


def check_invariant(errors: list[str]) -> None:
    gvl = read(GVL)
    winch = read(WINCHCFG)
    commun = read(COMMUNCFG)
    if missing(GVL, errors, "GVL_PERSISTENT") or missing(WINCHCFG, errors, "ST_WinchCfg") or missing(
        COMMUNCFG, errors, "ST_CommunCfg"
    ):
        return

    fdc = find_value(gvl, "CfgCableLimitAscent_M")
    top = find_value(gvl, "CfgTopSensorPos_M")
    slow = find_value(gvl, "WinchSlowdownDistanceTop_M")
    for name, val in (("CfgCableLimitAscent_M", fdc), ("CfgTopSensorPos_M", top),
                      ("WinchSlowdownDistanceTop_M", slow)):
        if val is None:
            errors.append(
                f"G504-3 champ `{name}` INTROUVABLE dans GVL_PERSISTENT.st — "
                "aucun repli numerique muet n'est autorise (REX champ fantome 2026-09-20)"
            )
    if None in (fdc, top, slow):
        return

    delta = round(top - fdc, 6)
    if delta < RESERVE_MIN:
        errors.append(f"G504-1 reserve = {delta:.2f} m < {RESERVE_MIN:.2f} m ")
    if slow < SLOWDOWN_MIN:
        errors.append(f"G504-2 ralentissement haut = {slow:.2f} m < {SLOWDOWN_MIN:.2f} m ")
    # G504-5 bornes absolues Q21 (defauts persistes)
    if not (FDC_MIN <= fdc <= FDC_MAX):
        errors.append(f"G504-5 FDC persiste {fdc:.2f} hors bornes [{FDC_MIN:.2f} ; {FDC_MAX:.2f}] ")
    if not (TOP_MIN <= top <= TOP_MAX):
        errors.append(f"G504-5 TOP persiste {top:.2f} hors bornes [{TOP_MIN:.2f} ; {TOP_MAX:.2f}] ")
    # Defauts de TYPE (miroir des declarations)
    dfdc = find_value(commun, "CfgCableLimitAscent_M")
    dtop = find_value(winch, "CfgTopSensorPos_M")
    dslow = find_value(commun, "WinchSlowdownDistanceTop_M")
    if dfdc is not None and not (FDC_MIN <= dfdc <= FDC_MAX):
        errors.append(f"G504-5 defaut de type FDC {dfdc:.2f} hors bornes (ST_CommunCfg.st) ")
    if dtop is not None and not (TOP_MIN <= dtop <= TOP_MAX):
        errors.append(f"G504-5 defaut de type TOP {dtop:.2f} hors bornes (ST_WinchCfg.st) ")
    if dslow is not None and dslow < SLOWDOWN_MIN:
        errors.append(f"G504-2 defaut de type ralentissement {dslow:.2f} m < {SLOWDOWN_MIN:.2f} m ")


def check_no_new_field(errors: list[str]) -> None:
    """G504-4 : baseline figee (plan v1.3 §3.2 : liste annexee validee humainement)."""
    for path in (WINCHCFG, COMMUNCFG):
        text = read(path)
        for name in re.findall(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:", text, re.MULTILINE):
            if not any(re.search(p, name) for p in FIELD_PATTERNS):
                continue
            if name not in BASELINE_FIELDS:
                errors.append(
                    f"G504-4 champ de reglage haut NON PREVU `{name}` dans {path.name} — "
                    "AC3 interdit tout nouveau champ (mettre la baseline a jour EXIGE une validation humaine)"
                )


def region_body(text: str) -> str | None:
    start = text.find(REGION_OPEN)
    if start < 0:
        return None
    end = text.find("{endregion}", start)
    return text[start:end] if end > start else None


def check_region(errors: list[str]) -> None:
    """G504-6 / -7 / -10 sur le corps de regles du FB ; G504-9 sur le site d'appel PRG_07."""
    if missing(PRG07, errors, "PRG_07_Supervision") or missing(FB_NORMALIZER, errors, "FB_CfgT330Normalizer"):
        return
    fb_body = region_body(read(FB_NORMALIZER))
    if fb_body is None:
        errors.append(
            "G504-6 region balisee ABSENTE dans FB_CfgT330Normalizer.st — "
            "sans balise le perimetre du controle n'est pas decidable (plan v1.3 §3.2)"
        )
        return
    prg_body = region_body(read(PRG07))
    if prg_body is None:
        errors.append(
            "G504-9 region balisee ABSENTE dans PRG_07_Supervision.st — "
            "le cablage du signal de homing au site d'appel n'est plus localisable"
        )
        return
    # G504-6 : aucun clamp muet -> toute ecriture de correction porte le message du FB.
    lines = fb_body.splitlines()
    for i, line in enumerate(lines):
        if re.search(r"(CfgCableLimitAscent_M|CfgTopSensorPos_M|WinchSlowdownDistanceTop_M)\s*:=", line):
            window = "\n".join(lines[i:i + 4])
            if "Corrected := TRUE" not in window:
                errors.append(
                    f"G504-6 clamp MUET ligne ~{i + 1} de la region T330 (FB_CfgT330Normalizer) : "
                    f"ecriture sans message associe -> {line.strip()[:60]}"
                )
    # G504-10 : R0 (clamp absolu) AVANT la regle Delta.
    # Les noms sont distincts par construction : R0 utilise CST_T330FdcMin_M / CST_T330TopMin_M,
    # la regle Delta utilise CST_T330ReserveMinMargin_M. On compare donc leur PREMIERE position.
    pos_clamp = fb_body.find("CST_T330FdcMin_M")
    pos_delta = fb_body.find("CST_T330ReserveMinMargin_M")
    if pos_clamp < 0 or pos_delta < 0:
        errors.append("G504-10 R0 et/ou regle Delta introuvables dans la region T330 du FB")
    elif pos_clamp > pos_delta:
        errors.append(
            "G504-10 le clamp absolu R0 doit etre EN AMONT de la regle Delta (Q21 bis) : "
            "ordre inverse detecte"
        )
    # G504-7 : gardes locales, jamais persistantes ni IHM.
    for cst in ("CST_T330ReserveMinMargin_M", "CST_T330SlowdownTopMin_M", "CST_T330FdcMax_M"):
        if re.search(rf"\b{re.escape(cst)}\b", read(GVL)):
            errors.append(f"G504-7 `{cst}` ne doit PAS etre persistante (GVL_PERSISTENT.st)")
    # G504-9 : les 3 exceptions de montee (contrat AC5), chacune dans son VRAI emplacement.
    # ⚠️ Le gating homing s'appuie sur le CYCLE COMPLET (decision C2a) : HomingLifecycle.Busy
    # seul ne couvre que la transaction de preset (~50 ms), ce qui ne satisferait PAS Q22.
    # ⚠️ Depuis T341 ces deux signaux sont lus au SITE D'APPEL (PRG_07) et passes au FB par
    # l'entree `InHoming` : c'est la que le controle porte desormais.
    # ⚠️ L'override N1 et le bypass N2 vivent dans PRG_04 (lecture seule ici : ce gate ne fait
    # que LIRE, il n'ecrit jamais dans un fichier d'une autre tache).
    if not (re.search(r"MachineHoming\.Active", prg_body) and re.search(r"HomingLifecycle\.Busy", prg_body)):
        errors.append(
            "G504-9 gating homing ABSENT ou INCOMPLET au site d'appel T330 (PRG_07) : le cycle complet "
            "(MachineHoming.Active) ET la transaction preset (HomingLifecycle.Busy) doivent etre "
            "COMBINES (C2a) — HomingLifecycle.Busy seul (~50 ms) ne suffit pas (AC5)"
        )
    prg04 = read(ROOT / "CODE" / "M_MAIN" / "PRG_04_Treuils_Benne.st")
    # ⚠️ Recherche par SOUS-CHAINE : les noms reels portent un suffixe d'axe
    # (`OverrideTopSoftwareN1M1` / `N1M2`) — un `\b` final ne matcherait pas.
    for name in ("OverrideTopSoftwareN1", "BypassTopLimitSoftware"):
        if name not in prg04:
            errors.append(f"G504-9 exception de montee NON NOMMEE dans PRG_04 : `{name}` (AC5)")


def check_forbidden_names(errors: list[str]) -> None:
    """G504-8 : perimetre CODE/ (les documents du cadrage citent ces noms a dessein, pour dire
    qu'ils n'existent pas : les interdire dans la doc serait un faux positif)."""
    if not CODE.is_dir():
        return
    for path in CODE.rglob("*.st"):
        text = read(path)
        for name in FORBIDDEN_CODE_NAMES:
            if name in text:
                errors.append(
                    f"G504-8 nom INEXISTANT `{name}` utilise dans {path.relative_to(ROOT)} — "
                    "ces libelles n'existent pas dans le projet (cadrage T330 section 1)"
                )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict", action="store_true", help="Exit 2 si probleme")
    args = parser.parse_args(argv)

    errors: list[str] = []
    check_invariant(errors)
    check_no_new_field(errors)
    check_region(errors)
    check_forbidden_names(errors)

    if errors:
        print("G504 - invariant haut T330 (reglages TOP / FDC / ralentissement) :")
        for e in errors:
            print(f"  - {e}")
        print(f"G504 : {len(errors)} probleme(s)")
        if args.strict:
            return 2
        print("G504 : mode informatif (pas bloquant)")
        return 0
    print("G504 PASS : reserve >= 1.00 m ET ralentissement >= 0.50 m evaluees SEPAREMENT, ")
    print("           bornes Q21 sur les valeurs persistees et les defauts de type, aucun champ neuf,")
    print("           aucune ecriture de correction sans message, clamp R0 present avant la regle Delta,")
    print("           gating homing sur le CYCLE COMPLET (MachineHoming.Active ET HomingLifecycle.Busy),")
    print("           exceptions override N1 / bypass N2 nommees dans PRG_04.")
    print("           LIMITE CONNUE : ces controles sont TEXTUELS (presence de formes) - ils ne")
    print("           prouvent PAS la semantique d'execution du ST. La recette machine reste P5.")
    print("           Le 3e nom interdit de AC1 (CableLimitAscent_M sans prefixe Cfg) n'est PAS")
    print("           controle ici : il designe un etat BOOL legitime dans CODE/ (faux positif garanti).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
