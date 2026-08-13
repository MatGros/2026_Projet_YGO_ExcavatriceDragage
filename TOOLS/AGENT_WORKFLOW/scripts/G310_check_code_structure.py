#!/usr/bin/env python3
"""Valide la structure des PROGRAM de CODE/ avant l'import CODESYS.

Classe de bugs couverte (audit 2026-08) : un fichier peut declarer un POU sous
un autre nom (PRG_OUTPUTS_LD.st -> PRG_10_Outputs_LD), et un suffixe _CFC peut
etre emis en Structured Text. Ces incoherences trompent la revue, les agents et
la trace de l'ordre MainTask sans etre des erreurs PLCopenXML.

Controles :
  S1  nom du fichier source == nom du PROGRAM declare
  S2  suffixe _CFC / _LD == langage correspondant dans CODE_Bundle.xml
  S3  chaque PROGRAM porte le prefixe d'ordre PRG_XX_
  S4  un fichier .st ne contient pas plus d'un END_PROGRAM ou END_FUNCTION_BLOCK,
      et l'epilogue correspond au type de POU declare (REX 2026-08 : double
      END_PROGRAM dans PRG_MODES_CFC.st -> 10 erreurs de compilation CODESYS).
      Les fragments sans epilogue sont ignores.

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/G310_check_code_structure.py
  python TOOLS/AGENT_WORKFLOW/scripts/G310_check_code_structure.py --root <projet>
"""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

PROGRAM_HEADER = re.compile(r"^\s*PROGRAM\s+(?P<name>[A-Za-z_]\w*)\b", re.MULTILINE)
FUNCTION_BLOCK_HEADER = re.compile(r"^\s*FUNCTION_BLOCK\b", re.MULTILINE)
END_PROGRAM_RE = re.compile(r"^\s*END_PROGRAM\b", re.MULTILINE)
END_FUNCTION_BLOCK_RE = re.compile(r"^\s*END_FUNCTION_BLOCK\b", re.MULTILINE)
ORDERED_PROGRAM = re.compile(r"^PRG_\d{2}_")
LANGUAGE_SUFFIXES = {"_CFC": "CFC", "_LD": "LD"}
BUNDLE_NAMES = {"CODE_Bundle.xml", "CODE_AU_Bundle.xml"}


@dataclass(frozen=True)
class ProgramSource:
    name: str
    path: Path


def local_name(tag: str) -> str:
    """Retourne le nom XML sans namespace PLCopenXML."""
    return tag.rsplit("}", maxsplit=1)[-1]


def st_program_sources(code: Path) -> list[ProgramSource]:
    sources: list[ProgramSource] = []
    for path in sorted((code / "MAIN").glob("*.st")):
        text = path.read_text(encoding="utf-8", errors="replace")
        match = PROGRAM_HEADER.search(text)
        if match:
            sources.append(ProgramSource(match.group("name"), path))
    return sources


def xml_program_sources(code: Path) -> list[ProgramSource]:
    """Trouve les PROGRAM CFC natifs, une fois les .st convertis en .xml."""
    sources: list[ProgramSource] = []
    for path in sorted((code / "MAIN").glob("*.xml")):
        if path.name in BUNDLE_NAMES:
            continue
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError as exc:
            print(f"[ERROR] [S0] {path}: XML source mal forme ({exc})", file=sys.stderr)
            continue
        for pou in root.iter():
            if local_name(pou.tag) == "pou":
                name = pou.get("name")
                if name and name.startswith("PRG_"):
                    sources.append(ProgramSource(name, path))
    return sources


def bundle_languages(bundle: Path) -> dict[str, set[str]]:
    """Retourne les langages reels emis pour chaque POU dans le bundle."""
    root = ET.parse(bundle).getroot()

    languages: dict[str, set[str]] = {}
    for pou in root.iter():
        if local_name(pou.tag) != "pou":
            continue
        name = pou.get("name")
        if not name or not name.startswith("PRG_"):
            continue
        found = {local_name(child.tag) for child in pou.iter()}
        languages[name] = found & {"ST", "LD", "CFC", "FBD", "SFC", "IL"}
    return languages


def check(root: Path) -> list[str]:
    code = root / "CODE"
    main = code / "MAIN"
    if not main.is_dir():
        return [f"[S0] repertoire introuvable : {main}"]

    sources = st_program_sources(code) + xml_program_sources(code)
    bundle = root / "CODE_XML" / "CODE_Bundle.xml"
    if not bundle.is_file():
        return [f"[S0] bundle introuvable : {bundle.relative_to(root).as_posix()}"]
    try:
        languages = bundle_languages(bundle)
    except ET.ParseError as exc:
        return [f"[S0] bundle XML mal forme : {exc}"]

    errors: list[str] = []
    for source in sources:
        rel = source.path.relative_to(root).as_posix()
        if source.path.stem != source.name:
            errors.append(
                f"[S1] {rel}: nom de fichier '{source.path.stem}' != PROGRAM '{source.name}'"
            )

        expected_language = next(
            (language for suffix, language in LANGUAGE_SUFFIXES.items() if source.name.endswith(suffix)),
            None,
        )
        if expected_language:
            actual_languages = languages.get(source.name, set())
            if expected_language not in actual_languages:
                emitted = ", ".join(sorted(actual_languages)) or "absent du bundle"
                errors.append(
                    f"[S2] {rel}: {source.name} suffixe {expected_language} "
                    f"mais bundle emet {emitted}"
                )

        if not ORDERED_PROGRAM.match(source.name):
            errors.append(
                f"[S3] {rel}: {source.name} sans prefixe d'ordre PRG_XX_"
            )

    errors.extend(check_st_end_keywords(root, code))

    return errors


def check_st_end_keywords(root: Path, code: Path) -> list[str]:
    """S4 : pas plus d'un END_PROGRAM/END_FUNCTION_BLOCK par .st, pas de croisement.

    Un fichier .st qui declare PROGRAM ou FUNCTION_BLOCK est verifie uniquement
    s'il contient au moins un mot-cle d'epilogue (END_PROGRAM ou
    END_FUNCTION_BLOCK). Les fichiers .st du projet sont souvent des fragments
    incomplets (implementation seule, sans epilogue) — ils restent valides.

    Les cas refles :
      - Plus d'un END_PROGRAM ou END_FUNCTION_BLOCK dans un meme fichier.
      - END_PROGRAM dans un fichier FUNCTION_BLOCK (ou inverse).
    """
    errors: list[str] = []
    for path in sorted(code.rglob("*.st")):
        text = path.read_text(encoding="utf-8", errors="replace")
        is_program = PROGRAM_HEADER.search(text) is not None
        is_fb = FUNCTION_BLOCK_HEADER.search(text) is not None
        if not is_program and not is_fb:
            continue

        rel = path.relative_to(root).as_posix()
        ep_count = len(END_PROGRAM_RE.findall(text))
        efb_count = len(END_FUNCTION_BLOCK_RE.findall(text))

        # Pas d'epilogue du tout = fragment incomplet, on ignore.
        if ep_count == 0 and efb_count == 0:
            continue

        # Plus d'un epilogue d'un meme type.
        if ep_count > 1:
            errors.append(
                f"[S4] {rel}: {ep_count} END_PROGRAM detectes (maximum : 1)"
            )
        if efb_count > 1:
            errors.append(
                f"[S4] {rel}: {efb_count} END_FUNCTION_BLOCK detectes "
                f"(maximum : 1)"
            )

        # Croisement : END_PROGRAM dans un FUNCTION_BLOCK ou inverse.
        if is_fb and ep_count > 0:
            errors.append(
                f"[S4] {rel}: FUNCTION_BLOCK declare mais contient "
                f"END_PROGRAM ({ep_count})"
            )
        if is_program and efb_count > 0:
            errors.append(
                f"[S4] {rel}: PROGRAM declare mais contient "
                f"END_FUNCTION_BLOCK ({efb_count})"
            )

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    args = parser.parse_args()

    root = args.root.resolve()
    errors = check(root)
    for error in errors:
        print(f"[ERROR] {error}", file=sys.stderr)

    print(f"Code structure check: {'FAIL' if errors else 'PASS'} ({len(errors)} erreur(s))")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
