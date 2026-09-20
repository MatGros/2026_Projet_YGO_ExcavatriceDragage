#!/usr/bin/env python3
"""G516 — Interrupteur de configuration MORT : lu et jamais ecrit (T352).

Classe de bug couverte (T352, 2026-09-21) : ``GVL_Simulation.st`` declarait cinq
parametres de PRODUCTION du service d'auto-acquittement borne des diagnostics
transitoires T278 ::

    AutoResetTransientDiagAtStartupEnable    : BOOL := FALSE;   (* :106 *)
    AutoResetTransientDiagAfterRearmEnable   : BOOL := FALSE;   (* :107 *)

et ``PRG_02_Acquisition.st:225-226`` les consommait comme arguments nommes du FB ::

    StartupEnable    := GVL_Simulation.AutoResetTransientDiagAtStartupEnable,
    PowerRearmEnable := GVL_Simulation.AutoResetTransientDiagAfterRearmEnable,

**Aucun point de tout ``CODE/`` ne les ecrivait jamais.** Le service existait, etait
cable, compile, bundle et « livre » — et pourtant totalement inerte sur machine reelle :
la machine a etats du FB ne sortait jamais de ``State=0``, l'observateur ne voyait ni
``Phase`` passer a 1/2 ni ``ResetPulse`` bouger. C'est le symetrique exact de G514
(variable locale ecrite et jamais lue, T346) : ici la variable est **lue**, consommee par
un FB, et jamais ecrite.

Pourquoi c'est un vrai risque et pas du rangement : un interrupteur jamais ecrit fige une
fonctionnalite dans l'etat de sa valeur d'initialisation. Aucun gate ne le voyait (bundle
valide, G200 vert, 21 gates vertes), et la lecture du code ne le montre pas non plus —
« ``StartupEnable := GVL_Simulation.X`` » ressemble a un cablage normal.

═══════════════════════════════════════════════════════════════════════════════════════
POURQUOI LE MODE BLOQUANT EST DELIBEREMENT ETROIT (mesure, pas prudence de principe)
═══════════════════════════════════════════════════════════════════════════════════════
Le detecteur generique (« booleen de GVL consomme en argument nomme de FB et jamais ecrit
dans CODE/ ») a ete MESURE sur l'arbre complet avant correctif : **16 sites**, dont les
2 du bug T352. Les 14 autres sont des reglages de banc ou des bits de bypass safety dont
l'ecriture est legitiment externe au PLC (pilotage CODESYS en ligne, restauration RETAIN,
IHM par symboles) : ``SimWinchDynamicsActive``, ``SimBucketJamActive``,
``SimM2CoupledDescentModelActive``, ``GVL_BypassRetain.BypassAuArmingPreconditions``,
``SimulationModeActive``, etc.

Trancher « reglage de banc » contre « interrupteur de production » est une DECISION
HUMAINE, pas une regle mecanique : c'est precisement la confusion qui a produit ce bug
(des parametres de production gares dans une GVL nommee *Simulation*). Un gate bloquant
sur la regle large serait donc rouge en permanence, et un agent n'a pas le droit de
s'auto-delivrer une liste d'exemptions pour le faire taire (regle projet : une allowlist
ne se decide pas dans un gate).

D'ou deux modes :

- **defaut, BLOQUANT** : invariant de non-regression T352 — dans
  ``CODE/M_MAIN/PRG_02_Acquisition.st``, l'appel ``instAutoResetTransientDiag`` porte ses
  2 autorisations en dur a ``TRUE`` et **aucune** de ses entrees n'est servie par
  ``GVL_Simulation``. Zero faux positif, et le gate redevient ROUGE des que quelqu'un
  recable ces entrees sur un booleen de GVL sans ecrivain.
- ``--scan-all`` **INFORMATIF** : le detecteur generique sur tout ``CODE/``, qui liste la
  population complete a arbitrer. Il ne bloque pas, et il porte sa propre limite.

Usage ::

    python TOOLS/AGENT_WORKFLOW/scripts/G516_check_dead_config_switch.py .
    python TOOLS/AGENT_WORKFLOW/scripts/G516_check_dead_config_switch.py . --scan-all
    python TOOLS/AGENT_WORKFLOW/scripts/G516_check_dead_config_switch.py --selftest
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

# Cible de l'invariant bloquant (perimetre du lot T352)
WIRING_FILE = "CODE/M_MAIN/PRG_02_Acquisition.st"
WIRING_INSTANCE = "instAutoResetTransientDiag"
REQUIRED_LITERALS = ("StartupEnable", "PowerRearmEnable")
FORBIDDEN_INPUT_SOURCE = "GVL_Simulation"

BLOCK_COMMENT_RE = re.compile(r"\(\*.*?\*\)", re.DOTALL)
LINE_COMMENT_RE = re.compile(r"//[^\r\n]*")
VAR_GLOBAL_RE = re.compile(
    # ⚠️ Les modificateurs restent sur la MEME ligne que VAR_GLOBAL ([ \t]+ et non \s+) et le corps
    # commence juste apres le saut de ligne : sans cela, le \s* gourmand avalait le debut de la
    # premiere declaration, DECL_RE ancre sur ^ ne la voyait plus, et l'interrupteur reellement
    # mort (celui de la ligne 1 du bloc) etait le SEUL a echapper au gate — prouve par le selftest.
    r"VAR_GLOBAL\b(?:[ \t]+[A-Z_]+)*[ \t]*\r?\n(?P<body>.*?)END_VAR",
    re.DOTALL | re.IGNORECASE,
)
DECL_RE = re.compile(r"^[ \t]*(_\w+|\w+)\s*:\s*BOOL\b", re.MULTILINE | re.IGNORECASE)
WRITE_RE = re.compile(r"\b(GVL_\w+)\s*\.\s*(\w+)\s*(?:\[[^\]]*\]|\.[\w.\[\]]+)?\s*:=")
NAMED_ARG_USE_RE = re.compile(r"\b(\w+)\s*:=\s*(GVL_\w+)\s*\.\s*(\w+)\s*[,)]", re.IGNORECASE)
NAMED_ARG_RE = re.compile(r"\b(\w+)\s*:=", re.IGNORECASE)


def strip_comments(source: str) -> str:
    """Neutralise les commentaires en conservant les numeros de ligne."""

    def blank(match: re.Match[str]) -> str:
        return re.sub(r"[^\n]", " ", match.group(0))

    return LINE_COMMENT_RE.sub("", BLOCK_COMMENT_RE.sub(blank, source))


def declared_global_bools(gvl_path: str, source: str) -> list[tuple[str, str, int]]:
    """Retourne (nom_gvl, nom_variable, ligne) pour chaque BOOL d'un VAR_GLOBAL.

    Le nom de la GVL est le NOM DU FICHIER sans suffixe (convention du projet : le nom du
    fichier est celui du POU / de la GVL), jamais le chemin : c'est ce nom qui apparait dans
    les acces qualifies ``GVL_X.Var`` du code appelant.
    """
    clean = strip_comments(source)
    gvl_name = Path(gvl_path).stem
    found: list[tuple[str, str, int]] = []
    for block in VAR_GLOBAL_RE.finditer(clean):
        for decl in DECL_RE.finditer(block.group("body")):
            line = clean.count("\n", 0, block.start("body") + decl.start()) + 1
            found.append((gvl_name, decl.group(1), line))
    return found


def analyse_sources(gvl_sources: dict[str, str], code_sources: dict[str, str]) -> tuple[list[str], int]:
    """Detecteur generique (mode --scan-all), sans acces disque : testable en memoire."""
    written: set[tuple[str, str]] = set()
    uses: dict[tuple[str, str], list[tuple[str, int, str]]] = {}

    for name, source in code_sources.items():
        clean = strip_comments(source)
        for match in WRITE_RE.finditer(clean):
            written.add((match.group(1).lower(), match.group(2).lower()))
        for match in NAMED_ARG_USE_RE.finditer(clean):
            line = clean.count("\n", 0, match.start()) + 1
            key = (match.group(2).lower(), match.group(3).lower())
            uses.setdefault(key, []).append((name, line, match.group(1)))

    errors: list[str] = []
    checked = 0
    for gvl_name, source in gvl_sources.items():
        for gvl, var, line in declared_global_bools(gvl_name, source):
            key = (gvl.lower(), var.lower())
            if key not in uses:
                continue
            checked += 1
            if key in written:
                continue
            sites = ", ".join(f"{name}:{ln} (arg {arg})" for name, ln, arg in uses[key][:3])
            errors.append(
                f"{gvl_name}:{line}: interrupteur de configuration MORT — {gvl}.{var} est consomme "
                f"comme argument nomme ({sites}) et n'est JAMAIS ecrit dans CODE/. "
                "La fonctionnalite qu'il autorise est figee sur sa valeur d'initialisation."
            )
    return errors, checked


def load_tree(root: Path) -> tuple[dict[str, str], dict[str, str]]:
    code = root / "CODE"
    if not code.is_dir():
        return {}, {}
    gvl_sources: dict[str, str] = {}
    code_sources: dict[str, str] = {}
    for path in sorted(code.rglob("*.st")):
        source = path.read_text(encoding="utf-8-sig", errors="replace")
        rel = path.relative_to(root).as_posix()
        code_sources[rel] = source
        if path.name.startswith("GVL_"):
            gvl_sources[rel] = source
    return gvl_sources, code_sources


def extract_named_args(source: str, instance: str) -> dict[str, str] | None:
    """Retourne {argument: expression} pour l'appel ``instance(`` ... ``)`` du POU.

    Retourne None si l'appel est absent. Les valeurs multi-lignes (OR, AND) sont aplaties.
    """
    clean = strip_comments(source)
    start = clean.find(f"{instance}(")
    if start < 0:
        return None
    open_paren = clean.index("(", start)
    depth = 0
    end = -1
    for index in range(open_paren, len(clean)):
        char = clean[index]
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                end = index
                break
    if end < 0:
        return None

    body = clean[open_paren + 1 : end]
    markers = list(NAMED_ARG_RE.finditer(body))
    args: dict[str, str] = {}
    for index, marker in enumerate(markers):
        stop = markers[index + 1].start() if index + 1 < len(markers) else len(body)
        value = " ".join(body[marker.end() : stop].split()).rstrip(",").strip()
        args[marker.group(1)] = value
    return args


def check_wiring_invariant(source: str, path_label: str) -> list[str]:
    """Invariant T352 bloquant : autorisations en dur, aucune entree servie par GVL_Simulation."""
    errors: list[str] = []
    args = extract_named_args(source, WIRING_INSTANCE)
    if args is None:
        return [
            f"{path_label}: appel {WIRING_INSTANCE}(...) introuvable — l'invariant T352 ne peut pas "
            "etre verifie (le FB d'auto-acquittement borne doit rester appele dans ce POU)"
        ]

    for name in REQUIRED_LITERALS:
        if name not in args:
            errors.append(
                f"{path_label}: {WIRING_INSTANCE} n'a plus d'argument {name} — les 2 autorisations "
                "doivent rester cablees explicitement (decision humaine : actives par defaut)"
            )
        elif args[name].upper() != "TRUE":
            errors.append(
                f"{path_label}: {WIRING_INSTANCE}.{name} = {args[name]!r} au lieu du litteral TRUE. "
                "Un service de securite/confort cable sur un booleen de configuration sans ecrivain "
                "redevient INERTE sans que rien ne le signale (bug T352)."
            )

    for name, value in args.items():
        if FORBIDDEN_INPUT_SOURCE in value:
            errors.append(
                f"{path_label}: {WIRING_INSTANCE}.{name} est servi par {value!r} — la frontiere "
                f"reel/simule de {FORBIDDEN_INPUT_SOURCE} ne doit pas nourrir un parametre de "
                "production (cf. G100 et cause racine T352)"
            )
    return errors


# ── Fixtures d'autorecette (en memoire, aucun fichier ecrit) ──────────────────
SELFTEST_GVL_REAL = """VAR_GLOBAL
    (* forme reelle T352 : les 2 autorisations du service, jamais ecrites *)
    AutoResetTransientDiagAtStartupEnable    : BOOL := FALSE;
    AutoResetTransientDiagAfterRearmEnable   : BOOL := FALSE;
    (* contre-preuve : celle-ci EST ecrite ailleurs *)
    AutoResetTransientDiagMaxAttempts        : USINT := 1;
    (* bruit : booleen de GVL lu hors argument nomme *)
    SimulationModeActive                     : BOOL := FALSE;
END_VAR
"""

SELFTEST_PRG_REAL = """PROGRAM PRG_Selftest
instDiag(
    Enable           := TRUE,
    StartupEnable    := GVL_Simulation.AutoResetTransientDiagAtStartupEnable,
    PowerRearmEnable := GVL_Simulation.AutoResetTransientDiagAfterRearmEnable,
    Cfg_MaxAttempts  := GVL_Simulation.AutoResetTransientDiagMaxAttempts
);
END_PROGRAM
"""

SELFTEST_WRITER = """PROGRAM PRG_Writer
GVL_Simulation.AutoResetTransientDiagMaxAttempts := 2;
END_PROGRAM
"""

SELFTEST_COMMENT_ONLY = """PROGRAM PRG_Selftest
(* GVL_Simulation.AutoResetTransientDiagAtStartupEnable := TRUE; *)
instDiag(StartupEnable := GVL_Simulation.AutoResetTransientDiagAtStartupEnable);
END_PROGRAM
"""

SELFTEST_SCALAR_READ = """PROGRAM PRG_Selftest
IF GVL_Simulation.SimulationModeActive THEN
    Counter := Counter + 1;
END_IF;
END_PROGRAM
"""

SELFTEST_WIRING_FIXED = """PROGRAM PRG_02_Acquisition
instAutoResetTransientDiag(
    Enable                  := TRUE,
    StartupEnable           := TRUE,
    PowerRearmEnable        := TRUE,
    EmergencyChainClosed    := HwIn.Machine.EmergencyChainClosed_DI,
    MotionActive             := PRG_04_Treuils_Benne.Data.BothActive
                                  OR PRG_04_Treuils_Benne.Data.WinchM1State.Busy,
    DiagnosticsStable        := instDiagEthercat.DeviceEthercatMaster.Operational
                                  AND instDiagCanOpen.DeviceCanOpenMaster.Operational
);
END_PROGRAM
"""


def selftest() -> int:
    """Le detecteur doit voir l'interrupteur mort REEL ; l'invariant bloquant doit voir une regression."""
    failures: list[str] = []

    # 1. Forme reelle : les 2 autorisations T352 sont detectees, les 2 autres non.
    errors, checked = analyse_sources(
        {"CODE/L_SIMULATION/GVL_Simulation.st": SELFTEST_GVL_REAL},
        {
            "CODE/M_MAIN/PRG_02_Acquisition.st": SELFTEST_PRG_REAL,
            "CODE/M_MAIN/PRG_Writer.st": SELFTEST_WRITER,
        },
    )
    if checked != 2:
        failures.append(
            f"scan-all : 2 booleens consommes en argument nomme attendus, {checked} vu(s) "
            "(MaxAttempts est un USINT : hors perimetre, la regle ne porte que sur les BOOL)"
        )
    if not any("AutoResetTransientDiagAtStartupEnable" in e for e in errors):
        failures.append("scan-all : mutation NON detectee — AtStartupEnable jamais ecrit")
    if not any("AutoResetTransientDiagAfterRearmEnable" in e for e in errors):
        failures.append("scan-all : mutation NON detectee — AfterRearmEnable jamais ecrit")
    if any("AutoResetTransientDiagMaxAttempts" in e for e in errors):
        failures.append("scan-all : faux positif — MaxAttempts est ECRIT (PRG_Writer)")
    if any("SimulationModeActive" in e for e in errors):
        failures.append("scan-all : faux positif — SimulationModeActive est lu hors argument nomme")
    if len(errors) != 2:
        failures.append(f"scan-all : {len(errors)} signalement(s) au lieu de 2")

    # 2. Une ecriture en COMMENTAIRE ne blanchit pas l'interrupteur mort.
    errors, _ = analyse_sources(
        {"CODE/L_SIMULATION/GVL_Simulation.st": SELFTEST_GVL_REAL},
        {"CODE/M_MAIN/PRG_02_Acquisition.st": SELFTEST_COMMENT_ONLY},
    )
    if not any("AutoResetTransientDiagAtStartupEnable" in e for e in errors):
        failures.append("scan-all : une ecriture en COMMENTAIRE a blanchi a tort un interrupteur mort")

    # 3. Une lecture scalaire n'entre pas dans le perimetre.
    errors, checked = analyse_sources(
        {"CODE/L_SIMULATION/GVL_Simulation.st": SELFTEST_GVL_REAL},
        {"CODE/M_MAIN/PRG_Scalar.st": SELFTEST_SCALAR_READ},
    )
    if checked != 0 or errors:
        failures.append(
            f"scan-all : perimetre elargi a tort ({checked} verifie(s) / {len(errors)} erreur(s)) "
            "sur une lecture scalaire — doit rester 0/0"
        )

    # 4. Invariant bloquant : le cablage CORRIGE passe.
    if check_wiring_invariant(SELFTEST_WIRING_FIXED, "selftest"):
        failures.append("invariant : le cablage corrige (TRUE en dur) est signale a tort")

    # 5. Invariant bloquant : la REGRESSION (retour a un booleen de GVL) doit etre vue.
    regressed = SELFTEST_WIRING_FIXED.replace(
        "    StartupEnable           := TRUE,", "    StartupEnable           := GVL_Simulation.X,"
    ).replace("    PowerRearmEnable        := TRUE,", "    PowerRearmEnable        := FALSE,")
    regress_errors = check_wiring_invariant(regressed, "selftest")
    if not any("StartupEnable" in e for e in regress_errors):
        failures.append("invariant : regression NON detectee — StartupEnable recable sur une GVL")
    if not any("PowerRearmEnable" in e for e in regress_errors):
        failures.append("invariant : regression NON detectee — PowerRearmEnable ramene a FALSE")

    # 6. Invariant bloquant : un appel disparu est une perte de fonctionnalite, pas un silence.
    if not check_wiring_invariant("PROGRAM PRG_02_Acquisition\nEND_PROGRAM", "selftest"):
        failures.append("invariant : appel disparu NON signale")

    if failures:
        print("[G516] SELFTEST FAIL :")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print(
        "[G516] SELFTEST PASS — scan-all : 2/2 interrupteurs morts T352 detectes, MaxAttempts (ecrit) "
        "et SimulationModeActive (lecture scalaire) NON signales, ecriture en commentaire neutralisee ; "
        "invariant bloquant : cablage corrige vert, recablage sur GVL rouge, retour a FALSE rouge, "
        "appel disparu rouge"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", type=Path, default=ROOT, help="racine du depot (defaut : depot)")
    parser.add_argument("--scan-all", action="store_true",
                        help="mode INFORMATIF : detecteur generique sur tout CODE/ (ne bloque pas)")
    parser.add_argument("--selftest", action="store_true", help="autorecette en memoire, sans ecriture disque")
    args = parser.parse_args()

    if args.selftest:
        return selftest()

    root = Path(args.root).resolve()

    if args.scan_all:
        gvl_sources, code_sources = load_tree(root)
        errors, checked = analyse_sources(gvl_sources, code_sources)
        print(f"[G516 --scan-all INFORMATIF] booleens de GVL consommes en argument nomme : {checked} "
              f"(GVL : {len(gvl_sources)}, fichiers ST : {len(code_sources)})")
        print("[G516 --scan-all] Population a arbitrer HUMAINEMENT (reglage de banc vs interrupteur "
              "de production) — ce mode ne bloque pas :")
        for error in errors:
            print(f"  - {error}")
        print(f"[G516 --scan-all] {len(errors)} site(s) signale(s) — NON bloquant par construction")
        return 0

    wiring_path = root / WIRING_FILE
    if not wiring_path.is_file():
        print(f"[ERROR] {WIRING_FILE} introuvable sous {root}", file=sys.stderr)
        return 1
    errors = check_wiring_invariant(wiring_path.read_text(encoding="utf-8-sig", errors="replace"), WIRING_FILE)
    for error in errors:
        print(f"[ERROR] {error}", file=sys.stderr)
    print(
        "Interrupteur de configuration mort — invariant de cablage T352 "
        f"(autorisations en dur, aucune entree servie par {FORBIDDEN_INPUT_SOURCE}) : "
        f"{'FAIL' if errors else 'PASS'} ({len(errors)} erreur(s))"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
