#!/usr/bin/env python3
"""Linter ST : compile un .st CODESYS 3.5 (+ dependances) via STruCpp vendore et remonte les
erreurs reelles en JSON structure -- pour integration VSCode (Problems panel) et agents IA.

Outil 100% encapsule dans TOOLS/LINTER_ST/ : binaire strucpp.exe et moulinette de conversion
sont des copies locales, aucune dependance d'execution vers TOOLS/COMPILER_ST2C_STruCpp/
(consigne utilisateur 2026-08-23).

Priorite explicite : zero faux positif. Si une dependance de type reste non resolue apres
resolve_deps.py, on NE remonte PAS d'erreur "Undefined type" (bruit de tooling, pas un vrai
bug) -- on le signale separement en stderr/JSON "incomplete" et on sort avec le code 2.

Usage:
    python lint.py <fichier.st> [--code-root CODE] [--json]

Codes de sortie:
    0 = compilation propre, 0 erreur
    1 = erreurs reelles trouvees (remontees en JSON)
    2 = analyse incomplete (dependance non resolue) -- aucune fausse alerte emise
    3 = erreur d'usage (fichier introuvable, strucpp.exe absent, ...)
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import resolve_deps  # noqa: E402
import linter_st_convert_codesys_to_iec as converter  # noqa: E402

TOOL_ROOT = Path(__file__).parent
STRUCPP_EXE = TOOL_ROOT / "bin" / "win32-x64" / "strucpp.exe"

# Format d'erreur STruCpp confirme empiriquement (session 2026-08-23, sur FB_Joystick.st reel) :
# "FB_Joystick.st:23:33: error: Undefined type 'ST_DIAG_DEVICE' in FUNCTION_BLOCK 'FB_JOYSTICK'"
# La doc officielle (ARCHITECTURE.md, lue apres coup) precise que CompileError.severity a 3
# valeurs possibles : "error" | "warning" | "info" -- seuls error/warning ont ete vus sur nos
# fichiers reels a ce jour, mais "info" est inclus pour ne pas silencieusement ignorer une ligne
# si STruCpp en emet un jour (ex: sur une future version vendoree).
ERROR_LINE_RE = re.compile(
    r"^(?P<file>[^:]+\.st):(?P<line>\d+):(?P<col>\d+):\s*(?P<severity>error|warning|info):\s*(?P<message>.+)$"
)

UNDEFINED_TYPE_RE = re.compile(r"Undefined type '(?P<name>\w+)'")

# "Undeclared variable" (distinct de "Undefined type") -- STruCpp l'emet notamment quand un PRG
# accede aux membres d'un AUTRE PROGRAM par acces qualifie CODESYS (ex: PRG_02_Acquisition.Data.X)
# : contrairement aux GVL, ce n'est PAS une histoire de qualificatif retirable -- teste isolement,
# STruCpp reconnait bel et bien le PROGRAM mais refuse l'acces direct a ses membres ("Cannot
# access members of program 'X' directly -- declare a variable of type 'X' first"). Limite
# structurelle non contournable simplement, verifiee sur PRG_03_Modes_Cycle.st, session
# 2026-08-23. resolve_deps.py ne detecte meme pas PRG_XX comme dependance (prefixe hors de son
# REF_RE) -- le nom n'apparait donc jamais dans known_unresolved malgre le fichier existant.
UNDECLARED_VARIABLE_RE = re.compile(r"Undeclared variable '(?P<name>\w+)'")

# Types externes CONNUS (bibliotheques natives CODESYS/CANopen/EtherCAT, jamais declares dans
# CODE/) -- liste blanche EXPLICITE, pas une deduction par absence de prefixe projet (tente puis
# abandonnee, session 2026-08-23 : "pas de prefixe ST_/E_/FB_/GVL_ => externe" faisait aussi
# passer INT_INCONNU (vrai bug de test) en "incomplete" au lieu d'errors -- une regression sur le
# test de non-regression deja en place). Ajouter ici au cas par cas quand un vrai type externe
# est rencontre (ex: DEVICE_STATE trouve sur FB_TroubleshootingView.st).
KNOWN_EXTERNAL_TYPES = {"DEVICE_STATE", "BLINK"}


def _run_strucpp(converted_files: list[Path], out_cpp: Path) -> str:
    if not STRUCPP_EXE.is_file():
        print(f"ERROR: strucpp.exe introuvable a {STRUCPP_EXE}", file=sys.stderr)
        sys.exit(3)
    result = subprocess.run(
        [str(STRUCPP_EXE), *[str(f) for f in converted_files], "-o", str(out_cpp)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return result.stdout + result.stderr


def _parse_diagnostics_raw(raw_output: str, converted_to_source: dict[str, Path]) -> list[dict]:
    """Mode raw : AUCUN filtrage, chaque ligne d'erreur/warning de STruCpp devient un
    diagnostic tel quel -- y compris les 'Undefined type'/'Undeclared variable' qu'on filtre
    normalement (DEVICE_STATE, GVL/PROGRAM qualifie, etc.). C'est le point de comparaison."""
    diagnostics: list[dict] = []
    for line in raw_output.splitlines():
        m = ERROR_LINE_RE.match(line.strip())
        if not m:
            continue
        converted_name = m.group("file")
        source_path = converted_to_source.get(converted_name, converted_name)
        diagnostics.append({
            "file": str(source_path),
            "line": int(m.group("line")),
            "col": int(m.group("col")),
            "severity": m.group("severity"),
            "message": m.group("message"),
        })
    return diagnostics


def _parse_diagnostics(
    raw_output: str,
    converted_to_source: dict[str, Path],
    known_unresolved: set[str],
    project_names: set[str],
    external_types: set[str],
) -> tuple[list[dict], set[str]]:
    """known_unresolved = types que resolve_deps() avait DEJA identifies comme absents de
    l'index CODE/ avant meme de compiler (prefixes projet detectes mais fichier introuvable).
    project_names = TOUS les noms declares dans CODE/ (TYPE/FUNCTION_BLOCK/PROGRAM/GVL), pour
    reperer un "Undeclared variable" sur un nom qui EXISTE dans le projet (limite STruCpp
    d'acces qualifie, jamais un vrai bug -- voir UNDECLARED_VARIABLE_RE ci-dessus).

    Filtres complementaires, dans cet ordre :
    1. "Undefined type" NAME dans known_unresolved -> bruit de tooling deja identifie, filtre.
    2. "Undefined type" NAME dans KNOWN_EXTERNAL_TYPES -> type externe hors CODE/ (ex:
       DEVICE_STATE) -- filtre, ajoute a 'external' (jamais une erreur).
    3. "Undeclared variable" NAME qui EST un nom declare du projet -> limite d'acces qualifie
       STruCpp (GVL/PRG), filtre, ajoute a 'external'.
    Sinon -> vraie erreur, jamais filtree (typo/bug, verifie empiriquement sur INT_INCONNU,
    session 2026-08-23).
    """
    diagnostics: list[dict] = []
    external: set[str] = set()

    for line in raw_output.splitlines():
        m = ERROR_LINE_RE.match(line.strip())
        if not m:
            continue

        message = m.group("message")
        # STruCpp normalise le nom en MAJUSCULES dans le message d'erreur (ST est
        # case-insensitive par spec) -- comparaison insensible a la casse, verifie
        # empiriquement (declar. 'ST_Diag_Device' -> "Undefined type 'ST_DIAG_DEVICE'").
        undef = UNDEFINED_TYPE_RE.search(message)
        if undef:
            name = undef.group("name")
            if name.upper() in known_unresolved:
                continue
            if name.upper() in external_types:
                external.add(name)
                continue

        undeclared = UNDECLARED_VARIABLE_RE.search(message)
        if undeclared:
            name = undeclared.group("name")
            # DEVICE_STATE.RUNNING (acces a un literal d'enum externe) peut remonter en
            # "Undeclared variable" plutot qu'"Undefined type" selon le contexte syntaxique --
            # verifie sur PRG_03_Modes_Cycle.st, session 2026-08-23.
            if name.upper() in project_names or name.upper() in external_types:
                external.add(name)
                continue

        converted_name = m.group("file")
        source_path = converted_to_source.get(converted_name, converted_name)
        diagnostics.append({
            "file": str(source_path),
            "line": int(m.group("line")),
            "col": int(m.group("col")),
            "severity": m.group("severity"),
            "message": message,
        })

    return diagnostics, external


def lint(
    target: Path,
    code_root: Path,
    extra_external_types: set[str] | None = None,
    raw: bool = False,
) -> dict:
    """raw=True : mode "STruCpp brut" -- AUCUNE transformation CODESYS->IEC (moulinette
    court-circuitee, fichiers compiles tels quels) et AUCUN filtrage de diagnostic (pas de
    liste blanche KNOWN_EXTERNAL_TYPES, pas de comparaison project_names, pas de statut
    "incomplete") -- CHAQUE message de STruCpp remonte tel quel, meme sur un type externe
    legitime (DEVICE_STATE, BLINK) ou une GVL/PROGRAM qualifiee. C'est le point de comparaison
    demande explicitement par l'utilisateur (session 2026-08-23) : pouvoir voir ce que le
    compilateur dit vraiment, sans nos correctifs, avant de decider de les activer."""
    resolved, unresolved = resolve_deps.resolve([target], code_root)

    # resolve() inclut deja systematiquement toutes les GVL_*.st (voir resolve_deps.py) --
    # dict.fromkeys plutot que list() : plusieurs NOMS peuvent resoudre vers le MEME fichier
    # (ex: chaque membre d'une GVL) -- sans dedup, strucpp.exe recoit ce fichier plusieurs fois
    # et leve "Symbol already defined in scope 'global'" (bug reel trouve session 2026-08-23).
    all_sources = list(dict.fromkeys([target] + list(resolved.values())))

    with tempfile.TemporaryDirectory(prefix="linter_st_") as tmp:
        tmp_path = Path(tmp)
        converted_dir = tmp_path / "converted"
        warnings: list[str] = []
        converted_to_source: dict[str, Path] = {}

        for src in all_sources:
            dst = converted_dir / src.name
            dst.parent.mkdir(parents=True, exist_ok=True)
            if raw:
                dst.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
            else:
                converter.convert_file(src, dst, warnings)
            converted_to_source[dst.name] = src

        out_cpp = tmp_path / "out.cpp"
        converted_files = [converted_dir / s.name for s in all_sources]
        raw_output = _run_strucpp(converted_files, out_cpp)

        if raw:
            diagnostics = _parse_diagnostics_raw(raw_output, converted_to_source)
            external: set[str] = set()
        else:
            project_names = {name.upper() for name in resolve_deps.build_declaration_index(code_root)}
            known_unresolved = {name.upper() for name in unresolved}
            external_types = KNOWN_EXTERNAL_TYPES | {n.upper() for n in (extra_external_types or set())}
            diagnostics, external = _parse_diagnostics(
                raw_output, converted_to_source, known_unresolved, project_names, external_types
            )

    all_unresolved = sorted(set(unresolved) | external) if not raw else []

    if all_unresolved and not diagnostics:
        return {
            "status": "incomplete",
            "target": str(target),
            "diagnostics": [],
            "unresolved_types": all_unresolved,
        }

    return {
        "status": "errors" if diagnostics else "clean",
        "target": str(target),
        "diagnostics": diagnostics,
        "unresolved_types": all_unresolved,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("target", help="Fichier .st a analyser")
    parser.add_argument("--code-root", default="CODE", help="Racine des sources ST (defaut: CODE)")
    parser.add_argument(
        "--extra-external-types",
        default="",
        help="Noms de types externes supplementaires (hors CODE/), separes par des virgules -- "
        "vient de linterSt.knownExternalTypes cote extension VSCode. Fusionne avec la liste "
        "KNOWN_EXTERNAL_TYPES en dur (DEVICE_STATE).",
    )
    parser.add_argument(
        "--raw",
        action="store_true",
        help="Mode STruCpp brut : AUCUNE transformation CODESYS->IEC, AUCUN filtrage de "
        "diagnostic -- chaque message du compilateur remonte tel quel, meme sur un type "
        "externe legitime ou une GVL/PROGRAM qualifiee. Pour comparer avec le mode normal "
        "et voir precisement ce que nos correctifs changent.",
    )
    args = parser.parse_args()

    target = Path(args.target)
    code_root = Path(args.code_root)
    extra_external_types = {n.strip() for n in args.extra_external_types.split(",") if n.strip()}

    if not target.is_file():
        print(f"ERROR: fichier cible introuvable: {target}", file=sys.stderr)
        return 3
    if not code_root.is_dir():
        print(f"ERROR: --code-root '{code_root}' introuvable", file=sys.stderr)
        return 3

    result = lint(target, code_root, extra_external_types, raw=args.raw)
    print(json.dumps(result, indent=2, ensure_ascii=False))

    if result["status"] == "incomplete":
        print(
            f"\n[INFO] Analyse incomplete -- {len(result['unresolved_types'])} type(s) non "
            "resolu(s), aucune fausse alerte emise. Voir 'unresolved_types'.",
            file=sys.stderr,
        )
        return 2
    if result["status"] == "errors":
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
