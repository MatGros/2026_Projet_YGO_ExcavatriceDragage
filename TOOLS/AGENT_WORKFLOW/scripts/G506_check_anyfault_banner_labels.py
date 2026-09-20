#!/usr/bin/env python3
"""Gate G506 — toute cause agregee dans AnyFaultActive a un libelle bandeau (T255-D).

Classe de bug couverte (T255-D, mesure 2026-09-20) : une cause ACTIVE allumait le voyant
`GVL_IHM.Modes.State.AnyFaultActive` sans qu'AUCUN canal du bandeau ne la nomme.

Cas mesure : `FB_Safety_Winch.instCauses[6]` (« Limite basse cable atteinte », bit6 =
16#0040, vue LIVE non latchee) est agregee par `Safety.Error` (PRG_07:541-542) mais le
carrousel ne decodait ni le bit 5 ni le bit 6 : voyant allume, `AlarmBanner.HasAlarm`
FALSE, texte d'action reduit au rappel joystick.

Ce gate relie mecaniquement les DEUX moities :
  1. la liste REELLE des sources agregees, lue dans le code de PRG_07 ;
  2. pour chaque source, le libelle attendu dans le carrousel, lu dans
     FB_Hmi_BannerFormatter.st (affectation de `AlarmArray[...]`).

⚖️ **Completude PAR BIT (revue read-only 2026-09-20, MAJOR-2)** : pour les treuils M1/M2,
la table du gate est indexee par BIT et sa completude est verifiee contre la liste des
causes REELLES du producteur (`FB_Safety_Winch.st`, `instCauses[i].Texte`). Consequences :
  - un nouveau bit ajoute au producteur sans ligne dans ce gate -> FAIL ;
  - **supprimer une ligne de la table ne supprime pas l'exigence** (le bit manquant est
    detecte par comparaison au producteur), ce que l'ancienne version par « source » ne
    faisait pas : elle aurait laisse passer exactement le bug T255-D.

Il echoue si :
  - une source agregee dans AnyFaultActive n'est pas cartographiee ;
  - un bit du producteur treuil n'est ni publie avec libelle, ni exempte nominativement ;
  - une cause non exemptee a perdu son libelle `AlarmArray[...]` ou sa garde de validite ;
  - un libelle exempte reapparait (exemption devenue obsolete).

Les EXEMPTIONS sont NOMINATIVES : raison + tache de rattachement, toujours affichees.

Usage :
    python G506_check_anyfault_banner_labels.py [project_root]

Exit codes :
    0 = PASS / 1 = FAIL / 2 = USAGE ERROR
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

PRG_07 = "CODE/M_MAIN/PRG_07_Supervision.st"
BANNER = "CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st"
WINCH_SRC = "CODE/H_TREUILS_BENNE/FB_Safety_Winch.st"

AGGREGATE_TARGET = "GVL_IHM.Modes.State.AnyFaultActive"

# ── 1. Treuils M1/M2 : table PAR BIT, complete contre FB_Safety_Winch.st ──────────
# bit -> (libelle attendu ("" = exempte), garde de validite, (raison, rattachement) | None)
# Le libelle contient {Mx} : remplace par M1 ou M2 selon le treuil.
WINCH_BIT_MAP: dict[int, tuple[str, str | None, tuple[str, str] | None]] = {
    0: ("[Mx] ErrorID:01 - perte com operateur", "Joy1Valid", None),
    1: ("[Mx] ErrorID:02 - perte codeur", "EncMxValid", None),
    2: (
        "",
        None,
        (
            "classe WARNING exclue du carrousel par la spec AF-07 v2.3 section 6 (lignes 290-291 : "
            "mou de cable, surchauffe moteur) ; visible en [HISTO] apres disparition de la cause",
            "spec AF-07 section 6 (retrait = decision de spec, jamais d'agent)",
        ),
    ),
    3: (
        "",
        None,
        (
            "classe WARNING exclue du carrousel par la spec AF-07 v2.3 section 6 (lignes 290-291) ; "
            "visible en [HISTO] quand la cause a disparu et n'est pas acquittee",
            "spec AF-07 section 6 (retrait = decision de spec, jamais d'agent)",
        ),
    ),
    4: ("[Mx] ErrorID:05 - rotation phases", "Vh0800Valid", None),
    5: (
        "",
        None,
        (
            "ETAT NORMAL de fin de course haut, pas un defaut : capteur haut actionne "
            "(FB_Safety_Winch.st:309-316), etat volontairement maintenu pendant les manoeuvres "
            "benne (FB_Safety_Winch.st:373-378). Classe warning au sens AF-07 section 6 ; de plus "
            "la DI M1M2_TopPositionFree_DI est COMMUNE aux deux treuils, donc une publication par "
            "treuil afficherait 2 alarmes pour un seul capteur (revue 2026-09-20, MINOR-1/2). "
            "L'action operateur est deja publiee par la branche « Montee interdite - limite haute »",
            "T220 (retrait si decision de publier les etats de fin de course en carrousel)",
        ),
    ),
    6: ("[Mx] Limite basse cable atteinte", "EncMxValid", None),
    7: ("[Mx] ErrorID:08 - MecaA - deplacement sans commande", "EncMxValid", None),
    8: ("[Mx] ErrorID:09 - MecaB - arret non confirme apres stop", "EncMxValid", None),
    9: ("[Mx] ErrorID:10 - MecaC - glissement pendant benne figee", "EncMxValid", None),
    10: (
        "",
        None,
        (
            "cause LATCHEE jamais publiee en actif : visible en [HISTO] seulement APRES disparition "
            "(FB_Hmi_BannerFormatter.st:1127) ; famille du REX MES-032 / C1-ANYFAULTACTIVE-EXHAUSTIF",
            "T220 (retrait quand T220 publiera les defauts thermiques en actif)",
        ),
    ),
    11: ("[Mx] ErrorID:12 - MecaD - non-arret au capteur haut", "EncMxValid", None),
    12: ("[Mx] ErrorID:13 - MecaE - ecart synchro M1/M2 critique", "EncMxValid", None),
    13: ("[Mx] ErrorID:13 - MecaE - ecart synchro M1/M2 critique", "EncMxValid", None),
    14: ("[Mx] ErrorID:15 - sens oppose", "EncMxValid", None),
    15: ("[Mx] ErrorID:16 - discordance commande/retour/mouvement", "EncMxValid", None),
}
# Libelles complementaires du treuil qui ne portent pas de numero de bit (etat dedie).
WINCH_EXTRA_LABELS: list[tuple[str, str, str | None]] = [
    ("[Mx] Survitesse treuil detectee (SafeStop)", "EncMxValid", None),
]

WINCH_SOURCES = ("GVL_IHM.M1TreuilRetenue.Safety.Error", "GVL_IHM.M2TreuilBenne.Safety.Error")

# ── 2. Autres sources agregees : (source, libelle, garde) ────────────────────────
ROW = tuple[str, str, str | None]
ROWS_OTHER: list[ROW] = [
    ("PRG_06_Outputs.EmergencyDiag.Error", "[AU] ErrorID:01 - redondance contacteurs", None),
    ("PRG_02_Acquisition.Data.InputModules.Fault", "[IO] Defaut module Local IO (DI8/DO8)", None),
    ("GVL_IHM.M3Translation.Safety.Error", "[M3] ErrorID:01 - perte com operateur", "Joy1Valid"),
    ("GVL_IHM.M1M2Sync.State.Error", "[SYNC] ErrorID:01 - ecart M1/M2", "EncM1Valid"),
    ("GVL_IHM.M2TreuilBenne.Bucket.State.Error", "[BENNE] ErrorID:01 - configuration geometrie invalide", None),
    ("GVL_IHM.CycleSemiAuto.State.Error", "[CYCLE] ErrorID:01 - limite legale atteinte", "EncM1Valid"),
]

# Sources exemptees ENTIEREMENT (aucun bit enumerable cote bandeau) : (source, raison, tache)
EXEMPT_SOURCES: list[tuple[str, str, str]] = [
    (
        "GVL_IHM.JOY1Joystick.State.Error",
        "le formateur ne recoit AUCUNE entree ErrorId joystick (VAR_INPUT lignes 11-81) : impossible "
        "de publier ce defaut fonctionnel (calibration bit0, capteur hors plage bit1, perte bus bit2) "
        "tant qu'aucune entree ne le transporte",
        "T220 (retrait quand le formateur recevra le diagnostic joystick)",
    ),
    (
        "PRG_03_Modes_Cycle.Data.ModesFault.Error",
        "aucune entree carrousel pour les defauts d'arbitrage de mode ; le motif de bascule refusee "
        "est expose a l'operateur en SpecialConditionText (lignes 359-361)",
        "T220 (retrait quand les refus de mode auront une entree carrousel)",
    ),
    (
        "PRG_03_Modes_Cycle.Data.ModesFault.Latched",
        "idem ModesFault.Error : meme famille, meme canal de repli SpecialConditionText",
        "T220 (meme condition de retrait que ModesFault.Error)",
    ),
]

_ALARM_ASSIGN_RE = re.compile(r"AlarmArray\[[^\]]*\]\s*:=\s*'(?P<label>[^']*)'")
_BLOCK_OPEN_RE = re.compile(r"^\s*(?:IF|ELSIF|WHILE|FOR|CASE)\b(?P<cond>.*)$")
_CAUSE_TEXT_RE = re.compile(r"instCauses\[(?P<idx>\d+)\]\.Texte\s*:=\s*'(?P<text>[^']*)'")


def _strip_comments(text: str) -> str:
    out: list[str] = []
    i, n = 0, len(text)
    while i < n:
        if text.startswith("(*", i):
            end = text.find("*)", i + 2)
            if end == -1:
                break
            out.append("".join("\n" if ch == "\n" else " " for ch in text[i:end + 2]))
            i = end + 2
            continue
        if text.startswith("//", i):
            end = text.find("\n", i + 2)
            out.append("" if end == -1 else " ")
            i = n if end == -1 else end
            continue
        out.append(text[i])
        i += 1
    return "".join(out)


def aggregate_sources(prg07_text: str) -> list[str]:
    """Sources agregees dans AnyFaultActive, dans l'ordre du code."""
    clean = _strip_comments(prg07_text)
    match = re.search(rf"{re.escape(AGGREGATE_TARGET)}\s*:=\s*(?P<body>.*?);", clean, re.DOTALL)
    if not match:
        raise ValueError(f"{AGGREGATE_TARGET} introuvable dans {PRG_07}")
    body = match.group("body").replace("\n", " ")
    return [part.strip() for part in re.split(r"\bOR\b", body) if part.strip()]


def producer_bits(safety_text: str) -> dict[int, str]:
    """Bits de cause REELLEMENT declares par le producteur : instCauses[i].Texte."""
    clean = _strip_comments(safety_text)
    return {int(m.group("idx")): m.group("text") for m in _CAUSE_TEXT_RE.finditer(clean)}


def alarm_assignments(banner_text: str) -> list[tuple[str, str, int]]:
    """(libelle, condition englobante, ligne) de chaque affectation AlarmArray[...] := '<libelle>'."""
    clean = _strip_comments(banner_text)
    rows: list[tuple[str, str, int]] = []
    cond = ""
    pending = ""
    for lineno, line in enumerate(clean.splitlines(), start=1):
        stripped = line.strip()
        if pending:
            pending = f"{pending} {stripped}"
            if "THEN" in pending.upper():
                cond = pending
                pending = ""
            continue
        m_open = _BLOCK_OPEN_RE.match(line)
        if m_open:
            body = m_open.group("cond")
            if "THEN" in body.upper() or "CASE" in body.upper():
                cond = body
            else:
                pending = body
            continue
        m = _ALARM_ASSIGN_RE.search(line)
        if m:
            rows.append((m.group("label"), cond, lineno))
    return rows


def _has_positive_guard(assignments: list[tuple[str, str, int]], label: str, garde: str) -> bool:
    """Vrai si `label` est publie dans un bloc garde POSITIVEMENT par `garde`.

    Une garde NIEE (`NOT EncM1Valid`) ne satisfait pas le controle : elle publierait
    l'alarme precisement dans le cas ou la mesure est invalide.
    """
    guard_re = re.compile(rf"(?<!NOT )\b{re.escape(garde)}\b")
    return any(lab == label and guard_re.search(cond) for lab, cond, _ in assignments)


def main() -> int:
    args = sys.argv[1:]
    root = Path(args[0]).resolve() if args else Path.cwd()
    prg07 = root / PRG_07
    banner_path = root / BANNER
    safety_path = root / WINCH_SRC
    for path in (prg07, banner_path, safety_path):
        if not path.is_file():
            print(f"ERROR: fichier introuvable : {path}", file=sys.stderr)
            return 2

    try:
        sources = aggregate_sources(prg07.read_text(encoding="utf-8"))
    except ValueError as exc:
        print(f"FAIL : {exc}", file=sys.stderr)
        return 1
    assignments = alarm_assignments(banner_path.read_text(encoding="utf-8"))
    labels = {label for label, _cond, _line in assignments}
    caused = producer_bits(safety_path.read_text(encoding="utf-8"))

    errors: list[str] = []
    warns: list[str] = []
    known = set(WINCH_SOURCES) | {row[0] for row in ROWS_OTHER} | {src for src, _r, _t in EXEMPT_SOURCES}

    # 1. Toute source agregee doit etre cartographiee.
    for src in sources:
        if src not in known:
            errors.append(
                f"source agregee NON CARTOGRAPHIEE : {src} — ajouter ses libelles par bit dans ce gate, "
                "ou une exemption nominative avec raison et tache"
            )

    # 2. Completude PAR BIT des treuils, contre le producteur FB_Safety_Winch.st.
    if not caused:
        errors.append(
            f"aucune cause lue dans {WINCH_SRC} (instCauses[i].Texte) : le controle de completude "
            "par bit ne peut pas etre prouve — verifier le producteur"
        )
    missing_bits = sorted(set(caused) - set(WINCH_BIT_MAP))
    extra_bits = sorted(set(WINCH_BIT_MAP) - set(caused))
    for bit in missing_bits:
        errors.append(
            f"BIT NON CARTOGRAPHIE : le producteur declare instCauses[{bit}] "
            f"(« {caused[bit]} ») mais ce gate ne prevoit ni libelle ni exemption pour le bit {bit} "
            "-> cause potentiellement muette (c'est exactement le bug T255-D)"
        )
    for bit in extra_bits:
        errors.append(
            f"BIT FANTOME : ce gate cartographie le bit {bit}, absent du producteur "
            f"({WINCH_SRC}) -> ligne a retirer ou producteur a verifier"
        )

    # 3. Libelles attendus : presents + garde positive.
    for src in WINCH_SOURCES:
        if src not in sources:
            warns.append(f"source treuil non agregee (retirer ?) : {src}")
            continue
        mx = "M1" if "M1TreuilRetenue" in src else "M2"
        for bit, (label_tpl, garde, exempt) in sorted(WINCH_BIT_MAP.items()):
            if exempt or not label_tpl:
                continue
            label = label_tpl.replace("Mx", mx)
            if label not in labels:
                errors.append(f"CAUSE MUETTE : {src} bit {bit} -> aucun libelle AlarmArray ne porte '{label}'")
                continue
            if garde:
                garde_eff = garde.replace("EncMxValid", f"Enc{mx}Valid")
                if not _has_positive_guard(assignments, label, garde_eff):
                    errors.append(
                        f"GARDE MANQUANTE : '{label}' ({src} bit {bit}) doit rester conditionnee "
                        f"positivement par {garde_eff} (masquage des filles sous l'alarme parente)"
                    )
        for label_tpl, garde, _exempt in WINCH_EXTRA_LABELS:
            label = label_tpl.replace("Mx", mx)
            if label not in labels:
                errors.append(f"CAUSE MUETTE : {src} -> aucun libelle AlarmArray ne porte '{label}'")
            elif garde:
                garde_eff = garde.replace("EncMxValid", f"Enc{mx}Valid")
                if not _has_positive_guard(assignments, label, garde_eff):
                    errors.append(f"GARDE MANQUANTE : '{label}' ({src}) doit rester gardee par {garde_eff}")

    # 4. Autres sources.
    for src, label, garde in ROWS_OTHER:
        if src not in sources:
            warns.append(f"ligne de table sans source agregee (retirer ?) : {src} -> {label}")
            continue
        if label not in labels:
            errors.append(f"CAUSE MUETTE : {src} agregee dans AnyFaultActive mais aucun libelle ne porte '{label}'")
        elif garde and not _has_positive_guard(assignments, label, garde):
            errors.append(f"GARDE MANQUANTE : '{label}' ({src}) doit rester gardee par {garde}")

    # 5. Exemptions : affichees, jamais silencieuses ; obsoletes signalees.
    for src in WINCH_SOURCES:
        mx = "M1" if "M1TreuilRetenue" in src else "M2"
        for bit, (label_tpl, _garde, exempt) in sorted(WINCH_BIT_MAP.items()):
            if not exempt:
                continue
            raison, tache = exempt
            warns.append(f"exemption nominative : {src} bit {bit} ({caused.get(bit, '?')}) -> {raison} [rattachement : {tache}]")
    for src, raison, tache in EXEMPT_SOURCES:
        if src not in sources:
            warns.append(f"exemption sans source agregee (retirer ?) : {src} -> {tache}")
            continue
        warns.append(f"exemption nominative (source entiere) : {src} -> {raison} [rattachement : {tache}]")

    if warns:
        print(f"INFO : {len(warns)} exemption(s) / point(s) de vigilance (nominatifs) :")
        for w in warns:
            print(f"  - {w}")

    if errors:
        print(f"\nFAIL : {len(errors)} cause(s) muette(s) ou non cartographiee(s) :")
        for e in errors:
            print(f"  - {e}")
        print(
            "\nRegle (T255-D) : une cause qui allume le voyant de defaut doit etre nommee a "
            "l'operateur. Ajouter le libelle dans le carrousel (avec sa garde positive de validite) "
            "ou declarer une exemption nominative motivee dans ce gate."
        )
        return 1

    print(
        f"PASS : {len(sources)} source(s) agregee(s) dans AnyFaultActive, "
        f"{len(caused)} cause(s) du producteur treuil cartographiee(s) par bit "
        f"({len(WINCH_BIT_MAP)} bits couverts sur 2 treuils), "
        f"{len([1 for _b, (_l, _g, e) in WINCH_BIT_MAP.items() if e]) + len(EXEMPT_SOURCES)} "
        "exemption(s) nominative(s) verifiee(s)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
