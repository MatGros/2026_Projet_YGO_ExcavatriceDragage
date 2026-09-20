#!/usr/bin/env python3
"""G512 — Argument nomme MORT dans un appel de test CI (T339).

Classe de bug couverte : un test de `TOOLS/TEST_AUTO_CI/RESULTS/*/tests/*.st` passe
un argument nomme qui ne correspond a AUCUNE entree/sortie de l'interface declaree du
FB teste, mais a un membre INTERNE de ce FB (`VAR`, `VAR CONSTANT`, `VAR_TEMP`...).

Pourquoi c'est vicieux : STruCpp traduit un argument nomme en affectation de membre
C++ (`s.FB.MOTIONREQUESTACTIVE = true;`). Comme le FB genere expose AUSSI ses
variables locales, l'affectation COMPILE — mais le corps du FB recalcule ce membre au
scan suivant (`MotionRequestActive := (ReqAscent OR ReqDescend) AND NOT ...`). Le test
« passe » donc en ne pilotant RIEN : il est **vacant** (incident T295/T339, ~30 sites
dans `test_fb_bucket.st`).

Pire cas voisin, deja rencontre : si le membre n'existe pas du tout dans la classe
generee, l'affectation ne compile pas et le FB entier tombe en erreur de compilation
(`MOTIONDIRECTION`, rapport FB_Bucket du 2026-09-14) — un seul argument mort suffit a
masquer TOUS les tests du FB.

Regle : tout argument nomme d'un appel a une instance de FB compilee depuis les
`sources` du registre CI doit appartenir a l'interface declaree du FB
(`VAR_INPUT`, `VAR_OUTPUT`, `VAR_IN_OUT`).

Deux classes sont distinguees, parce qu'elles n'ont PAS la meme valeur de detection :

  * MORT SILENCIEUX (**bloquant**) : le nom correspond a un membre INTERNE du FB
    (`VAR`, `VAR CONSTANT`, `VAR_TEMP`...). L'affectation C++ compile, le FB ecrase la
    valeur au scan suivant : le test passe en ne prouvant RIEN. Le harnais ne peut pas
    le voir — c'est la classe d'incident T339.
  * MORT BRUYANT (avertissement, non bloquant) : le nom n'existe nulle part dans le FB.
    La compilation C++ echoue et masque TOUT le fichier de test : le signal est deja
    donne par la CI elle-meme, le gate ne fait que le rendre explicite.

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/G512_check_dead_ci_test_arguments.py [racine]
  python TOOLS/AGENT_WORKFLOW/scripts/G512_check_dead_ci_test_arguments.py --selftest
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

REGISTRY_REL = Path("TOOLS/TEST_AUTO_CI/scripts/config/registry.yaml")

# Blocs de declaration ST et classement : INTERFACE (pilotable/testable de l'exterieur)
# vs INTERNE (jamais un argument nomme legitime d'un appel depuis un test).
INTERFACE_BLOCKS = {"VAR_INPUT", "VAR_OUTPUT", "VAR_IN_OUT"}
INTERNAL_BLOCKS = {
    "VAR", "VAR CONSTANT", "VAR_TEMP", "VAR_INST", "VAR_STAT", "VAR_EXTERNAL",
    "VAR_GLOBAL",
}
ALL_BLOCKS = INTERFACE_BLOCKS | INTERNAL_BLOCKS

BLOCK_OPEN = re.compile(
    r"^\s*(" + "|".join(sorted(ALL_BLOCKS, key=len, reverse=True)) + r")\b",
    re.IGNORECASE,
)
BLOCK_CLOSE = re.compile(r"^\s*END_VAR\b", re.IGNORECASE)
DECL = re.compile(
    r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:AT\s*%[IQM][\w.]*)?\s*:",
)
FUNCTION_BLOCK = re.compile(r"^\s*FUNCTION_BLOCK\s+(?:PUBLIC\s+)?([A-Za-z_]\w*)", re.IGNORECASE)
INSTANCE_DECL = re.compile(r"^\s*([A-Za-z_]\w*)\s*:\s*([A-Za-z_]\w*)\s*;\s*$")
NAMED_ARG = re.compile(r"^\s*([A-Za-z_]\w*)\s*:=")


def strip_st_comments(text: str) -> str:
    """Remplace les commentaires ST par des espaces, en conservant les numeros de ligne."""
    out: list[str] = []
    depth = 0
    i = 0
    while i < len(text):
        char = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if depth == 0 and char == "/" and nxt == "/":
            while i < len(text) and text[i] != "\n":
                out.append(" ")
                i += 1
            continue
        if char == "(" and nxt == "*":
            depth += 1
            out.append("  ")
            i += 2
            continue
        if depth > 0 and char == "*" and nxt == ")":
            depth -= 1
            out.append("  ")
            i += 2
            continue
        if depth > 0:
            out.append("\n" if char == "\n" else " ")
            i += 1
            continue
        out.append(char)
        i += 1
    return "".join(out)


def parse_fb_interfaces(text: str) -> dict[str, dict[str, set[str]]]:
    """Retourne {NOM_FB_MAJUSCULES: {"interface": {...}, "internal": {...}}}."""
    result: dict[str, dict[str, set[str]]] = {}
    current_fb: str | None = None
    current_block: str | None = None
    for line in text.splitlines():
        match = FUNCTION_BLOCK.match(line)
        if match:
            current_fb = match.group(1).upper()
            current_block = None
            result.setdefault(current_fb, {"interface": set(), "internal": set()})
            continue
        if current_fb is None:
            continue
        if BLOCK_OPEN.match(line):
            # 'VAR' peut etre suivi d'un qualificatif : 'VAR CONSTANT', 'VAR GLOBAL'...
            tokens = line.strip().split()
            token = tokens[0].upper()
            if token == "VAR" and len(tokens) > 1 and f"VAR {tokens[1].upper()}" in ALL_BLOCKS:
                token = f"VAR {tokens[1].upper()}"
            current_block = token
            continue
        if BLOCK_CLOSE.match(line):
            current_block = None
            continue
        if current_block in INTERFACE_BLOCKS or current_block in INTERNAL_BLOCKS:
            decl = DECL.match(line)
            if decl:
                bucket = "interface" if current_block in INTERFACE_BLOCKS else "internal"
                result[current_fb][bucket].add(decl.group(1).upper())
    return result


def interface_of(interfaces: dict[str, dict[str, set[str]]], type_name: str) -> set[str]:
    """Ensemble des noms d'interface declares pour un type de FB."""
    entry = interfaces.get(type_name)
    return entry["interface"] if entry else set()


def internal_of(interfaces: dict[str, dict[str, set[str]]], type_name: str) -> set[str]:
    """Ensemble des noms de membres internes declares pour un type de FB."""
    entry = interfaces.get(type_name)
    return entry["internal"] if entry else set()


def parse_instances(text: str, known_types: set[str]) -> dict[str, str]:
    """Retourne {instance: TYPE_FB} pour les instances declarees dont le type est teste."""
    instances: dict[str, str] = {}
    for line in text.splitlines():
        match = INSTANCE_DECL.match(line)
        if not match:
            continue
        name, type_name = match.group(1), match.group(2)
        if type_name.upper() in known_types:
            instances[name] = type_name.upper()
    return instances


def split_top_level(args: str) -> list[tuple[int, str]]:
    """Decoupe une liste d'arguments sur les virgules de premier niveau.
    Retourne [(offset_dans_args, texte_argument)]."""
    parts: list[tuple[int, str]] = []
    depth = 0
    start = 0
    for index, char in enumerate(args):
        if char in "([":
            depth += 1
        elif char in ")]":
            depth -= 1
        elif char == "," and depth == 0:
            parts.append((start, args[start:index]))
            start = index + 1
    tail = args[start:]
    if tail.strip():
        parts.append((start, tail))
    return [part for part in parts if part[1].strip()]


def call_sites(text: str, instances: dict[str, str]) -> list[tuple[int, str, str, list[tuple[int, str]]]]:
    """Retourne les appels d'instances : (ligne, instance, type_fb, [(ligne, argument_nomme)])."""
    sites: list[tuple[int, str, str, list[tuple[int, str]]]] = []
    for instance, type_name in instances.items():
        pattern = re.compile(rf"(?<![A-Za-z0-9_.]){re.escape(instance)}\s*\(")
        for match in pattern.finditer(text):
            open_index = text.index("(", match.start())
            depth = 0
            index = open_index
            while index < len(text):
                if text[index] == "(":
                    depth += 1
                elif text[index] == ")":
                    depth -= 1
                    if depth == 0:
                        break
                index += 1
            if depth != 0:
                continue
            args = text[open_index + 1:index]
            line = text.count("\n", 0, open_index) + 1
            named: list[tuple[int, str]] = []
            for offset, raw in split_top_level(args):
                arg = NAMED_ARG.match(raw)
                if arg:
                    named_line = text.count("\n", 0, open_index + 1 + offset) + 1
                    named.append((named_line, arg.group(1).upper()))
            sites.append((line, instance, type_name, named))
    return sites


def find_dead_arguments(
    test_text: str, fb_interfaces: dict[str, dict[str, set[str]]]
) -> list[tuple[int, str, str, str, str]]:
    """Retourne [(ligne, instance, type_fb, argument, classe)] dans un fichier de test.
    classe = "silencieux" (membre interne du FB) ou "bruyant" (nom inexistant)."""
    cleaned = strip_st_comments(test_text)
    instances = parse_instances(cleaned, set(fb_interfaces))
    findings: list[tuple[int, str, str, str, str]] = []
    for _call_line, instance, type_name, named in call_sites(cleaned, instances):
        interface = interface_of(fb_interfaces, type_name)
        internal = internal_of(fb_interfaces, type_name)
        for line, arg in named:
            if arg in interface:
                continue
            kind = "silencieux" if arg in internal else "bruyant"
            findings.append((line, instance, type_name, arg, kind))
    return sorted(findings)


def load_registry(root: Path) -> dict:
    import yaml

    registry_path = root / REGISTRY_REL
    return yaml.safe_load(registry_path.read_text(encoding="utf-8"))


def scan_repo(root: Path) -> tuple[list[str], list[str]]:
    """Retourne (bloquants, avertissements)."""
    blocking: list[str] = []
    warnings: list[str] = []
    registry = load_registry(root)
    for fb_name, entry in registry.items():
        sources = entry.get("sources") or []
        interfaces: dict[str, dict[str, set[str]]] = {}
        for rel in sources:
            path = root / rel
            if not path.is_file():
                continue
            interfaces.update(parse_fb_interfaces(path.read_text(encoding="utf-8", errors="replace")))
        if not interfaces:
            continue
        test_rel = entry.get("test")
        if not test_rel:
            continue
        test_path = root / test_rel
        if not test_path.is_file():
            continue
        test_text = test_path.read_text(encoding="utf-8", errors="replace")
        for line, instance, type_name, arg, kind in find_dead_arguments(test_text, interfaces):
            message = (
                f"{test_rel}:{line}: argument nomme MORT `{arg}` sur l'appel `{instance}(...)` "
                f"({fb_name}) — `{arg}` est hors interface declaree de {type_name} "
                f"(VAR_INPUT/VAR_OUTPUT/VAR_IN_OUT)"
            )
            if kind == "silencieux":
                blocking.append(
                    f"{message} ; c'est un membre INTERNE ({type_name}) : l'affectation compile "
                    f"mais le FB ecrase la valeur au scan suivant -> test VACANT"
                )
            else:
                warnings.append(
                    f"{message} ; nom INEXISTANT dans {type_name} -> erreur de compilation C++ "
                    f"attendue (signal deja porte par la CI)"
                )
    return blocking, warnings


SELFTEST_GOOD = """FUNCTION_BLOCK PUBLIC FB_Selftest
VAR_INPUT
    Enable : BOOL;
    ReqAscent : BOOL;
END_VAR
VAR_OUTPUT
    RunRequest : BOOL;
END_VAR
VAR_IN_OUT
    Shared : ST_Dummy;
END_VAR
VAR
    MotionRequestActive : BOOL;
END_VAR
"""

SELFTEST_TEST_TEMPLATE = """SETUP
VAR
    FB : FB_Selftest;
    Shared : ST_Dummy;
END_VAR
END_SETUP

TEST 'selftest'
    FB(Enable := TRUE, {dead}ReqAscent := TRUE, Shared := Shared);
END_TEST
"""


def selftest(root: Path) -> int:
    """Le detecteur doit voir la mutation, et ne pas crier sur une forme conforme."""
    failures: list[str] = []
    interfaces = parse_fb_interfaces(SELFTEST_GOOD)

    if interface_of(interfaces, "FB_SELFTEST") != {"ENABLE", "REQASCENT", "RUNREQUEST", "SHARED"}:
        failures.append(
            f"interface mal extraite : {sorted(interface_of(interfaces, 'FB_SELFTEST'))}"
        )
    if internal_of(interfaces, "FB_SELFTEST") != {"MOTIONREQUESTACTIVE"}:
        failures.append(
            f"membres internes mal extraits : {sorted(internal_of(interfaces, 'FB_SELFTEST'))}"
        )

    # 1) Forme conforme : aucun argument mort ne doit etre signale.
    clean = SELFTEST_TEST_TEMPLATE.format(dead="")
    if find_dead_arguments(clean, interfaces):
        failures.append("faux positif : un appel conforme (entrees + VAR_IN_OUT) est signale")

    # 2) Mutation « mort silencieux » : argument nomme d'un VAR INTERNE -> bloquant.
    mutated = SELFTEST_TEST_TEMPLATE.format(dead="MotionRequestActive := TRUE, ")
    findings = find_dead_arguments(mutated, interfaces)
    if not findings or findings[0][3] != "MOTIONREQUESTACTIVE" or findings[0][4] != "silencieux":
        failures.append(
            "mutation NON detectee : `MotionRequestActive := TRUE` (VAR interne) accepte ou mal classe"
        )

    # 3) Cas voisin « mort bruyant » : argument totalement inexistant -> avertissement.
    ghost = SELFTEST_TEST_TEMPLATE.format(dead="MotionDirection := 1, ")
    findings = find_dead_arguments(ghost, interfaces)
    if not findings or findings[0][4] != "bruyant":
        failures.append("mutation NON detectee : argument inexistant `MotionDirection` accepte")

    # 4) Preuve sur le fichier REEL : le motif d'incident re-injecte dans le VRAI
    #    test_fb_bucket.st doit etre detecte, et le fichier courant ne doit RIEN lever.
    real_test = root / "TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_bucket.st"
    real_fb = root / "CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st"
    if real_test.is_file() and real_fb.is_file():
        real_interfaces = parse_fb_interfaces(real_fb.read_text(encoding="utf-8", errors="replace"))
        current = real_test.read_text(encoding="utf-8", errors="replace")
        if find_dead_arguments(current, real_interfaces):
            failures.append(f"{real_test.name} porte encore un argument nomme mort")
        legacy = current.replace(
            "BucketState := BucketState);",
            "MotionRequestActive := TRUE, BucketState := BucketState);",
            1,
        )
        if legacy == current:
            failures.append("selftest : ancrage de re-injection introuvable dans le fichier REEL")
        elif not find_dead_arguments(legacy, real_interfaces):
            failures.append("mutation du fichier REEL non detectee (motif d'incident re-injecte)")

    if failures:
        print("[G512] SELFTEST FAIL :")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print("[G512] SELFTEST PASS — detecteur reactif aux arguments nommes morts, sans faux positif")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", type=Path, default=ROOT, help="racine du depot (defaut : depot)")
    parser.add_argument("--selftest", action="store_true", help="verifie que le detecteur rejette une mutation")
    args = parser.parse_args()

    root = args.root.resolve()
    if not (root / REGISTRY_REL).is_file():
        print(f"[G512] FAIL — registre CI introuvable : {REGISTRY_REL}")
        return 1

    if args.selftest:
        return selftest(root)

    blocking, warnings = scan_repo(root)
    for warning in warnings:
        print(f"[G512] ATTENTION — {warning}")
    if blocking:
        print("[G512] FAIL — argument(s) nomme(s) MORT(s) SILENCIEUX dans des appels de test CI :")
        for error in blocking:
            print(f"  - {error}")
        return 1

    print(
        f"[G512] PASS — aucun argument nomme mort SILENCIEUX dans les appels de test CI "
        f"({len(warnings)} argument(s) inexistant(s) signale(s), deja visibles par la compilation)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
