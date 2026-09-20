#!/usr/bin/env python3
"""G513 — Memoire de comptage brut d'un codeur : producteur unique, aucune reinjection muette (T342).

Classe de bug couverte (CR2 de T338, incident banc 2026-09-20) : le banc de simulation
``FB_SimBench`` reecrivait la memoire de comptage brut des codeurs (``RawPosM1``/``RawPosM2``,
references ``GVL_PERSISTENT._SimEncoderRawPosM1/M2``) au PREMIER scan suivant la reactivation du
banc (``IF NOT SimBenchWasEnabled``), sur un simple test de valeur ::

    IF RawPosM2 = 0 THEN
        RawPosM2 := CST_M2EncoderInitialRaw;   (* 1 100 000 pts *)
    END_IF;

Deux defauts en un :

1. **Producteur multiple** — ``FB_Sim_Encoder`` est le producteur unique du comptage brut
   (accumulation signee / preset). Un autre bloc qui y ecrit casse l'invariant d'encapsulation
   et rend la memoire du codeur imprevisible.
2. **Test de valeur non discriminant** — apres le correctif T338 (comptage brut = entier SIGNE
   32 bits, dont le zero est arbitraire), la valeur 0 n'est PAS une « memoire vierge » : c'est un
   point de passage legitime. La reinjection transformait donc un zero reel en teleportation :
   1 100 000 pts / 4096 pts/m = 268,55 m de position publiee en un scan, sans mouvement, sans
   defaut, reference de homing conservee (saut mesure 8,50 -> 204,677 m apres AU).

Regles :

- **A (producteur unique)** : hors du modele codeur (``FB_Sim_Encoder``) et du relais PDO du
  codeur reel (``FB_Encoder_Abs``, preset EtherCAT), AUCUNE affectation n'est faite sur une
  memoire de comptage brut (``*RawPos*``, ``*PosPts*``, ``*Odom*``).
- **B (reinjection sur test de valeur)** : une affectation d'une memoire de comptage brut gardee
  par un test d'egalite a un litteral (``IF <comptage> = <n> THEN``) est interdite, MEME dans le
  modele — l'auto-correction sur la valeur est non discriminante par construction.

Exception admise, et elle doit etre VISIBLE dans le code : le marqueur de revue ``@seed-ok`` sur
la ligne d'affectation (cas volontaire, documente et assume).

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/G513_check_sim_encoder_memory_write.py [racine]
  python TOOLS/AGENT_WORKFLOW/scripts/G513_check_sim_encoder_memory_write.py --selftest
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

# Vocabulaire du comptage brut de position (volontairement etroit : les compteurs d'evenements
# — AttemptCount, AlarmCount, BlipCount... — se remettent legitimement a 0).
COUNT_TOKENS = ("RawPos", "PosPts", "Odom")

# Producteurs legitimes du comptage brut : le modele de banc, et le relais PDO du codeur reel
# (qui ne fait que recopier la valeur lue sur le bus / appliquer un preset EtherCAT).
PRODUCER_FILES = ("FB_Sim_Encoder.st", "FB_Encoder_Abs.st")

ASSIGN = re.compile(r"^\s*([A-Za-z_]\w*)\s*:=\s*(.+?);\s*(?:\(\*.*?\*\))?\s*$")
VALUE_TEST = re.compile(r"^\s*IF\s+([A-Za-z_]\w*)\s*=\s*(-?\d+)\s+THEN", re.IGNORECASE)
ALLOW_MARKER = "@seed-ok"

# Fenetre d'analyse apres un test de valeur (lignes) pour trouver l'affectation gardee.
WINDOW_AFTER = 8

# Lignes de commentaire/region neutralisees avant analyse.
COMMENT_PREFIXES = ("//", "(*", "{")


def _is_count_name(name: str) -> bool:
    return any(token in name for token in COUNT_TOKENS)


def _code_of(line: str) -> str:
    return line.split("(*")[0].split("//")[0]


def scan_text(text: str, filename: str) -> list[tuple[int, str]]:
    """Retourne les violations d'un texte source : (ligne, message)."""
    lines = text.splitlines()
    findings: list[tuple[int, str]] = []
    allowed_file = Path(filename).name in PRODUCER_FILES

    for num, line in enumerate(lines, 1):
        stripped = line.strip()
        if not stripped or stripped.startswith(COMMENT_PREFIXES):
            continue
        if ALLOW_MARKER in line:
            continue

        # Regle A — hors producteur, aucune ecriture d'une memoire de comptage brut.
        match = ASSIGN.match(_code_of(line))
        if match and _is_count_name(match.group(1)) and not allowed_file:
            findings.append((
                num,
                f"regle A : `{match.group(1)}` (memoire de comptage brut) est ecrit par "
                f"{Path(filename).name}, qui n'est pas son producteur unique "
                f"(attendu : {' / '.join(PRODUCER_FILES)}, ou marqueur {ALLOW_MARKER})",
            ))

        # Regle B — reinjection gardee par un test d'egalite a un litteral.
        test = VALUE_TEST.match(_code_of(line))
        if test and _is_count_name(test.group(1)):
            guarded = test.group(1)
            window = lines[num:num + WINDOW_AFTER]
            for offset, candidate in enumerate(window, start=1):
                if ALLOW_MARKER in candidate:
                    break
                inner = ASSIGN.match(_code_of(candidate))
                if inner and inner.group(1) == guarded:
                    findings.append((
                        num + offset,
                        f"regle B : `{guarded} := {inner.group(2).strip()}` est garde par le test de "
                        f"valeur `{guarded} = {test.group(2)}` (ligne {num}) — un `= 0` de comptage brut "
                        f"n'est pas une memoire vierge, c'est un point de passage legitime "
                        f"(teleportation mesuree 268,55 m, CR2 de T338)",
                    ))
                    break

    return findings


def scan_file(path: Path) -> list[tuple[int, str]]:
    return scan_text(path.read_text(encoding="utf-8", errors="replace"), path.name)


def scan_repo(root: Path) -> list[str]:
    errors: list[str] = []
    for st in sorted((root / "CODE").rglob("*.st")):
        rel = st.relative_to(root).as_posix()
        for num, message in scan_file(st):
            errors.append(f"{rel}:{num}: {message}")
    return errors


# ── Selftest ────────────────────────────────────────────────────────────────────────────────
# La mutation d'incident EXACTE (bloc CR2 de FB_SimBench.st:273-280 avant T342).
SELFTEST_INCIDENT = """FUNCTION_BLOCK PUBLIC FB_Selftest
VAR_IN_OUT
    RawPosM2 : UDINT;
END_VAR
    IF NOT SimBenchWasEnabled THEN
        IF RawPosM2 = 0 THEN
            RawPosM2 := CST_M2EncoderInitialRaw;
        END_IF;
    END_IF;
    SimBenchWasEnabled := TRUE;
END_FUNCTION_BLOCK
"""

# Auto-correction sur test de valeur DANS le producteur : la regle B doit la voir aussi.
SELFTEST_VALUE_TEST_IN_PRODUCER = """FUNCTION_BLOCK PUBLIC FB_Sim_Encoder
VAR_IN_OUT
    RawPos : UDINT;
END_VAR
    IF RawPos = 0 THEN
        RawPos := 1000000;
    END_IF;
END_FUNCTION_BLOCK
"""

# Formes conformes : accumulation signee et preset du producteur, relais du codeur reel.
SELFTEST_LEGIT = """FUNCTION_BLOCK PUBLIC FB_Sim_Encoder
VAR_IN_OUT
    RawPos : UDINT;
END_VAR
    IF RelayFwd THEN
        RawPos := DINT_TO_UDINT(UDINT_TO_DINT(RawPos) + UDINT_TO_DINT(Increment));
    ELSIF PresetPending THEN
        RawPos := PresetValue;
    END_IF;
END_FUNCTION_BLOCK
"""

SELFTEST_MARKER = """FUNCTION_BLOCK PUBLIC FB_Selftest
VAR_IN_OUT
    RawPosM2 : UDINT;
END_VAR
    RawPosM2 := 1000000; (* @seed-ok : amorcage volontaire, cas documente *)
END_FUNCTION_BLOCK
"""


def selftest(root: Path) -> int:
    """Le detecteur doit voir les deux mutations d'incident, sans faux positif."""
    failures: list[str] = []

    incident = scan_text(SELFTEST_INCIDENT, "FB_SimBench.st")
    if not any("regle B" in message for _, message in incident):
        failures.append("mutation NON detectee : reinjection `IF RawPosM2 = 0 THEN ... := CST_*` (regle B)")
    if not any("regle A" in message for _, message in incident):
        failures.append("mutation NON detectee : ecriture de RawPosM2 hors producteur (regle A)")

    if not any("regle B" in message for _, message in scan_text(SELFTEST_VALUE_TEST_IN_PRODUCER, "FB_Sim_Encoder.st")):
        failures.append("mutation NON detectee : test de valeur dans le producteur lui-meme (regle B)")

    if scan_text(SELFTEST_LEGIT, "FB_Sim_Encoder.st"):
        failures.append("faux positif : accumulation signee / preset du producteur signale a tort")

    if scan_text(SELFTEST_MARKER, "FB_SimBench.st"):
        failures.append(f"faux positif : marqueur {ALLOW_MARKER} non respecte")

    # Preuve sur la mutation REELLE : le fichier corrige ne doit RIEN lever, et la version
    # d'avant correction (bloc reinjecte) doit lever les deux regles.
    real = root / "CODE" / "L_SIMULATION" / "FB_SimBench.st"
    if real.is_file():
        if scan_file(real):
            failures.append(f"{real.name} porte encore une ecriture de memoire de comptage brut")
        legacy = real.read_text(encoding="utf-8", errors="replace").replace(
            "Ready := TRUE;",
            "IF NOT SimBenchWasEnabled THEN\n"
            "    IF RawPosM2 = 0 THEN\n"
            "        RawPosM2 := CST_M2EncoderInitialRaw;\n"
            "    END_IF;\n"
            "END_IF;\n"
            "Ready := TRUE;",
            1,
        )
        legacy_findings = scan_text(legacy, real.name)
        if not any("regle B" in message for _, message in legacy_findings):
            failures.append("mutation du fichier REEL non detectee (bloc CR2 re-injecte)")

    if failures:
        print("[G513] SELFTEST FAIL :")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print("[G513] SELFTEST PASS — detecteur reactif aux deux mutations d'incident, sans faux positif")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", type=Path, default=ROOT, help="racine du depot (defaut : depot)")
    parser.add_argument("--selftest", action="store_true", help="verifie que le detecteur rejette les mutations")
    args = parser.parse_args()

    root = args.root.resolve()
    if not (root / "CODE").is_dir():
        print(f"[G513] FAIL — dossier CODE introuvable sous {root}")
        return 1

    if args.selftest:
        return selftest(root)

    errors = scan_repo(root)
    if errors:
        print("[G513] FAIL — memoire de comptage brut ecrite hors de son producteur, ou reinjectee sur test de valeur :")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("[G513] PASS — comptage brut : producteur unique respecte, aucune reinjection muette")
    return 0


if __name__ == "__main__":
    sys.exit(main())
