#!/usr/bin/env python3
"""Prove CODE/MAIN PROGRAM coverage and identity in CODE_Bundle.xml.

Coverage proves every discovered source PROGRAM is emitted exactly once with the
language dictated by its source extension. Identity additionally proves that a
source filename, source POU, and generated POU use the same final POU identity:
``PRG_XX_<Role>``. Legacy identity failures are separately listed with
``--report`` so they cannot be mistaken for coverage failures.

Usage:
  python TOOLS/AGENT_WORKFLOW/scripts/check_bundle_main_coverage.py
  python TOOLS/AGENT_WORKFLOW/scripts/check_bundle_main_coverage.py --report
  python TOOLS/AGENT_WORKFLOW/scripts/check_bundle_main_coverage.py --root <projet>
"""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path

PROGRAM_HEADER = re.compile(r"^\s*PROGRAM\s+(?P<name>[A-Za-z_]\w*)\b", re.MULTILINE)
FINAL_PROGRAM_NAME = re.compile(r"^PRG_\d{2}_")
LANGUAGE_TAGS = {"ST", "LD", "CFC", "FBD", "SFC", "IL"}


@dataclass(frozen=True)
class MainProgramSource:
    """A PROGRAM source found below CODE/MAIN with its required bundle language."""

    name: str
    path: Path
    expected_language: str


@dataclass
class CheckResult:
    """Failures separated so a valid coverage is never reported as valid identity."""

    coverage_errors: list[str]
    identity_errors: list[str]

    @property
    def errors(self) -> list[str]:
        return self.coverage_errors + self.identity_errors


def local_name(tag: str) -> str:
    """Return an XML tag name without its optional namespace."""
    return tag.rsplit("}", maxsplit=1)[-1]


def is_standalone_ld_export(path: Path, programs: list[str]) -> bool:
    """Return whether ``path`` is the delivery export of its sibling LD ST source.

    A ``PRG_*_LD.xml`` next to its identically named ``.st`` is import material,
    not a native XML source. The ST source remains the sole bundle input.
    """
    if not (path.stem.endswith("_LD") and programs == [path.stem]):
        return False
    st_source = path.with_suffix(".st")
    if not st_source.is_file():
        return False
    match = PROGRAM_HEADER.search(st_source.read_text(encoding="utf-8", errors="replace"))
    return match is not None and match.group("name") == path.stem


def discover_main_program_sources(main: Path) -> tuple[list[MainProgramSource], list[str], list[str]]:
    """Discover PROGRAM sources and validate their source-level identity."""
    sources: list[MainProgramSource] = []
    coverage_errors: list[str] = []
    identity_errors: list[str] = []

    for path in sorted(main.rglob("*.st")):
        text = path.read_text(encoding="utf-8", errors="replace")
        match = PROGRAM_HEADER.search(text)
        if not match:
            if path.stem.startswith("PRG_"):
                coverage_errors.append(f"[BMC0] {path}: source PRG sans declaration PROGRAM")
            continue

        name = match.group("name")
        expected_language = "LD" if path.stem.endswith("_LD") else "ST"
        sources.append(MainProgramSource(name, path, expected_language))
        if name != path.stem:
            identity_errors.append(
                f"[BMI1] {path}: basename `{path.stem}` != PROGRAM declare `{name}`"
            )
        if not FINAL_PROGRAM_NAME.match(name):
            identity_errors.append(
                f"[BMI2] {path}: POU final `{name}` doit commencer par `PRG_XX_`"
            )

    for path in sorted(main.rglob("*.xml")):
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError as exc:
            coverage_errors.append(f"[BMC0] {path}: XML source mal forme ({exc})")
            continue

        programs = [
            pou.get("name")
            for pou in root.iter()
            if local_name(pou.tag) == "pou"
            and pou.get("name")
            and pou.get("pouType", "program") == "program"
        ]
        if not programs:
            if path.stem.startswith("PRG_"):
                coverage_errors.append(f"[BMC0] {path}: source PRG XML sans pou/@name")
            continue
        if is_standalone_ld_export(path, programs):
            # Un *_LD.xml à côté de son .st est un artefact de livraison interdit :
            # le Ladder n'est livré QUE par le bundle (REX 2026-08, import CODESYS).
            coverage_errors.append(
                f"[BMC0] {path}: standalone LD export interdit — la livraison "
                f"Ladder est CODE_Bundle.xml uniquement (REX 2026-08)"
            )
            continue
        if not path.stem.endswith("_CFC"):
            coverage_errors.append(f"[BMC0] {path}: source PROGRAM XML doit etre nomme *_CFC.xml")
            continue

        for name in programs:
            sources.append(MainProgramSource(name, path, "CFC"))
            if name != path.stem:
                identity_errors.append(
                    f"[BMI1] {path}: basename `{path.stem}` != XML pou/@name `{name}`"
                )
            if not FINAL_PROGRAM_NAME.match(name):
                identity_errors.append(
                    f"[BMI2] {path}: POU final `{name}` doit commencer par `PRG_XX_`"
                )

    names = Counter(source.name for source in sources)
    for name, count in sorted(names.items()):
        if count > 1:
            source_paths = ", ".join(
                source.path.as_posix() for source in sources if source.name == name
            )
            coverage_errors.append(
                f"[BMC1] PROGRAM {name} declare {count} fois dans CODE/MAIN ({source_paths})"
            )
    return sources, coverage_errors, identity_errors


def bundle_program_languages(bundle: Path) -> dict[str, list[set[str]]]:
    """Return every emitted PROGRAM occurrence and its language tags."""
    root = ET.parse(bundle).getroot()
    programs: dict[str, list[set[str]]] = defaultdict(list)
    for pou in root.iter():
        if local_name(pou.tag) != "pou":
            continue
        name = pou.get("name")
        if not name:
            continue
        languages = {local_name(element.tag) for element in pou.iter()} & LANGUAGE_TAGS
        programs[name].append(languages)
    return programs


def check(root: Path) -> CheckResult:
    """Return coverage and identity failures independently."""
    main = root / "CODE" / "MAIN"
    bundle = root / "CODE" / "CODE_Bundle.xml"
    if not main.is_dir():
        return CheckResult([f"[BMC0] repertoire introuvable : {main}"], [])
    if not bundle.is_file():
        return CheckResult([f"[BMC0] bundle introuvable : {bundle}"], [])

    sources, coverage_errors, identity_errors = discover_main_program_sources(main)
    try:
        emitted = bundle_program_languages(bundle)
    except ET.ParseError as exc:
        return CheckResult(coverage_errors + [f"[BMC0] bundle XML mal forme : {exc}"], identity_errors)

    for source in sources:
        occurrences = emitted.get(source.name, [])
        count = len(occurrences)
        if count != 1:
            coverage_errors.append(
                f"[BMC2] {source.name}: attendu exactement une emission dans CODE_Bundle.xml, "
                f"trouve {count}"
            )
            continue
        languages = occurrences[0]
        if source.expected_language not in languages:
            actual = ", ".join(sorted(languages)) or "aucun langage"
            coverage_errors.append(
                f"[BMC3] {source.name}: source {source.path.name} attend "
                f"{source.expected_language}, bundle emet {actual}"
            )
    return CheckResult(coverage_errors, identity_errors)


def status(errors: list[str]) -> str:
    return "FAIL" if errors else "PASS"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument(
        "--report",
        action="store_true",
        help="Distinguer la couverture bundle des non-conformites d'identite historiques",
    )
    args = parser.parse_args()

    result = check(args.root.resolve())
    for error in result.errors:
        print(f"[ERROR] {error}", file=sys.stderr)
    print(
        f"Bundle MAIN coverage: {status(result.coverage_errors)} "
        f"({len(result.coverage_errors)} erreur(s))"
    )
    print(
        f"Bundle MAIN identity: {status(result.identity_errors)} "
        f"({len(result.identity_errors)} erreur(s))"
    )

    if args.report:
        print()
        print("```text")
        print("Rapport couverture MAIN / identite POU")
        print(f"  Couverture bundle : {status(result.coverage_errors)}")
        for error in result.coverage_errors:
            print(f"  KO couverture : {error}")
        print(f"  Identite POU     : {status(result.identity_errors)}")
        for error in result.identity_errors:
            print(f"  KO identite : {error}")
        print("```")

    return 1 if result.errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
