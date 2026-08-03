#!/usr/bin/env python3
"""Gate: reject PLCopenXML bundle whose ST bodies contain POU terminator tokens.

REX 2026-08-03 : un bundle bien forme XML et un linkage vert ne prouvent pas
qu'un POU compile dans CODESYS. Le generateur embarquait END_PROGRAM /
END_FUNCTION_BLOCK dans <ST><xhtml> quand la source .st le contenait ;
CODESYS ajoute son propre terminator -> C0009 "Jeton inattendu END_PROGRAM
trouve" + C0190. Ce gate inspecte le bundle et rejette tout body ST qui
contient un token de fin de POU.

Usage:
    python check_bundle_st_syntax.py [project_root]

Exit codes:
    0 = PASS (aucun body ST ne contient de terminator)
    1 = FAIL (un ou plusieurs body ST contiennent un terminator)
    2 = USAGE ERROR
"""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# Tokens de fin de POU/type qui ne doivent JAMAIS apparaitre dans un body ST.
# END_STRUCT / END_TYPE / END_FUNCTION couvrent les types ; END_VAR est legit
# dans un body (multi-section) donc exclu.
# \b evite le faux positif : END_FUNCTION est sous-chaine de END_FUNCTION_BLOCK.
# Ordre : on teste END_FUNCTION_BLOCK avant END_FUNCTION pour ne pas matcher
# la sous-chaine en premier.
POU_TERMINATOR_RES = (
    re.compile(r"\bEND_PROGRAM\b"),
    re.compile(r"\bEND_FUNCTION_BLOCK\b"),
    re.compile(r"\bEND_FUNCTION\b"),
    re.compile(r"\bEND_TYPE\b"),
    re.compile(r"\bEND_STRUCT\b"),
)
POU_TERMINATOR_NAMES = (
    "END_PROGRAM",
    "END_FUNCTION_BLOCK",
    "END_FUNCTION",
    "END_TYPE",
    "END_STRUCT",
)

PLCOPEN_NS = "{http://www.plcopen.org/xml/tc6_0200}"
XHTML_NS = "{http://www.w3.org/1999/xhtml}"


def _extract_st_text(st_el: ET.Element) -> str:
    """Reconstruit le texte d'un body <ST> en concatenant <xhtml> et <xhtml:p>."""
    parts: list[str] = []
    if st_el.text:
        parts.append(st_el.text)
    for child in st_el.iter():
        if child is st_el:
            continue
        if child.tag == XHTML_NS + "xhtml" or child.tag.endswith("}xhtml"):
            if child.text:
                parts.append(child.text)
            for p in child.iter():
                if p is child:
                    continue
                if p.tag.endswith("}p"):
                    parts.append("".join(p.itertext()))
        if child.tail:
            parts.append(child.tail)
    return "\n".join(p for p in parts if p is not None)


def analyze_bundle(bundle: Path) -> list[tuple[str, str, int, str]]:
    """Return list of (pou_name, terminator, line, snippet) for each violation."""
    tree = ET.parse(bundle)
    root = tree.getroot()
    violations: list[tuple[str, str, int, str]] = []

    for pou in root.iter():
        if pou.tag != PLCOPEN_NS + "pou":
            continue
        name = pou.get("name", "?")
        body = pou.find(PLCOPEN_NS + "body")
        if body is None:
            continue
        st_el = body.find(PLCOPEN_NS + "ST")
        if st_el is None:
            continue  # LD/CFC body : non concerne
        text = _extract_st_text(st_el)
        if not text:
            continue
        for idx, pat in enumerate(POU_TERMINATOR_RES):
            m = pat.search(text)
            if m:
                line_no = text[: m.start()].count("\n") + 1
                lines = text.split("\n")
                snippet = lines[line_no - 1].strip() if 0 < line_no <= len(lines) else ""
                violations.append((name, POU_TERMINATOR_NAMES[idx], line_no, snippet))
                # Un seul terminator par POU suffit pour signaler ; ne pas
                # accumuler END_FUNCTION_BLOCK + END_FUNCTION sur la meme ligne.
                break
    return violations


def main() -> int:
    args = sys.argv[1:]
    root = Path(args[0]).resolve() if args else Path.cwd()
    bundle = root / "CODE" / "CODE_Bundle.xml"
    if not bundle.is_file():
        print(f"ERROR: bundle introuvable : {bundle}", file=sys.stderr)
        return 2

    try:
        violations = analyze_bundle(bundle)
    except ET.ParseError as exc:
        print(f"ERROR: bundle XML mal forme : {exc}", file=sys.stderr)
        return 2

    if not violations:
        print("PASS : aucun body ST ne contient de terminator de POU.")
        return 0

    print(f"FAIL : {len(violations)} body(ies) ST contiennent un terminator de POU :")
    for name, term, line, snippet in violations:
        print(f"  - {name} : '{term}' ligne {line} -> {snippet[:80]}")
    print(
        "\nCause : le generateur embarque END_PROGRAM/END_FUNCTION_BLOCK dans <ST><xhtml>. "
        "CODESYS ajoute son propre terminator -> C0009 'Jeton inattendu'. "
        "Verifier st_sections._strip_pou_terminator et reexecuter generate_codesys_bundle.py."
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())