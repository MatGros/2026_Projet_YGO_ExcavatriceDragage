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
ERROR_LINE_RE = re.compile(
    r"^(?P<file>[^:]+\.st):(?P<line>\d+):(?P<col>\d+):\s*(?P<severity>error|warning):\s*(?P<message>.+)$"
)

UNDEFINED_TYPE_RE = re.compile(r"Undefined type '(?P<name>\w+)'")


def _run_strucpp(converted_files: list[Path], out_cpp: Path) -> str:
    if not STRUCPP_EXE.is_file():
        print(f"ERROR: strucpp.exe introuvable a {STRUCPP_EXE}", file=sys.stderr)
        sys.exit(3)
    result = subprocess.run(
        [str(STRUCPP_EXE), *[str(f) for f in converted_files], "-o", str(out_cpp)],
        capture_output=True,
        text=True,
    )
    return result.stdout + result.stderr


def _parse_diagnostics(
    raw_output: str, converted_to_source: dict[str, Path], known_unresolved: set[str]
) -> list[dict]:
    """known_unresolved = types que resolve_deps() avait DEJA identifies comme absents de
    l'index CODE/ avant meme de compiler. Seuls ceux-la sont filtres comme bruit de tooling.

    Un 'Undefined type' STruCpp sur un nom qui n'etait PAS dans known_unresolved est un signal
    fort de vraie erreur (ex: typo hors des prefixes ST_/E_/FB_ que resolve_deps() surveille,
    verifie empiriquement sur INT_INCONNU, session 2026-08-23) -- remonte comme diagnostic reel,
    jamais avale silencieusement.
    """
    diagnostics: list[dict] = []

    for line in raw_output.splitlines():
        m = ERROR_LINE_RE.match(line.strip())
        if not m:
            continue

        message = m.group("message")
        undef = UNDEFINED_TYPE_RE.search(message)
        # STruCpp normalise le nom en MAJUSCULES dans le message d'erreur (ST est
        # case-insensitive par spec) -- comparaison insensible a la casse, verifie
        # empiriquement (declar. 'ST_Diag_Device' -> message "Undefined type 'ST_DIAG_DEVICE'").
        if undef and undef.group("name").upper() in known_unresolved:
            # Dependance deja identifiee manquante par resolve_deps() -- bruit de tooling,
            # filtree (priorite "zero faux positif" en tete de fichier).
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

    return diagnostics


def lint(target: Path, code_root: Path) -> dict:
    resolved, unresolved = resolve_deps.resolve([target], code_root)

    all_sources = [target] + list(resolved.values())

    with tempfile.TemporaryDirectory(prefix="linter_st_") as tmp:
        tmp_path = Path(tmp)
        converted_dir = tmp_path / "converted"
        warnings: list[str] = []
        converted_to_source: dict[str, Path] = {}

        for src in all_sources:
            dst = converted_dir / src.name
            converter.convert_file(src, dst, warnings)
            converted_to_source[dst.name] = src

        out_cpp = tmp_path / "out.cpp"
        converted_files = [converted_dir / s.name for s in all_sources]
        raw_output = _run_strucpp(converted_files, out_cpp)

        known_unresolved = {name.upper() for name in unresolved}
        diagnostics = _parse_diagnostics(raw_output, converted_to_source, known_unresolved)

    all_unresolved = sorted(unresolved)

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
    args = parser.parse_args()

    target = Path(args.target)
    code_root = Path(args.code_root)

    if not target.is_file():
        print(f"ERROR: fichier cible introuvable: {target}", file=sys.stderr)
        return 3
    if not code_root.is_dir():
        print(f"ERROR: --code-root '{code_root}' introuvable", file=sys.stderr)
        return 3

    result = lint(target, code_root)
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
