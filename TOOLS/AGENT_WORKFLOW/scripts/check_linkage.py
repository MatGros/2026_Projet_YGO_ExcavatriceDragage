#!/usr/bin/env python3
"""Gate de liaison : verifie qu'aucun POU/instance n'est orphelin ou mal cable.

Classe de bug couverte (REX 2026-07-29, PRG_10_Outputs_LD) :
un FB peut etre ecrit, importe, bundle et teste sans jamais etre reellement
instancie/appele la ou il doit vivre. Le bundle XML et les tests Python ne
prouvent QUE la forme, jamais le cablage. Ce script prouve le cablage.

Controles :
  L1  instance FB declaree en VAR mais jamais appelee dans le corps du POU
  L2  type FB inconnu (aucun POU de ce nom dans CODE/)
  L3  appel d'une instance non declaree dans ce POU
  L4  reference croisee POU.Membre.Champ vers un POU/membre inexistant
  L5  typeName du bundle PLCopenXML != type reellement declare
  L7  meme nom d'instance declare dans plusieurs PROGRAM (ambiguite)

Aucun controle ne lit `Device.export` : cet export est mis a jour au bon vouloir
humain, il ne peut donc pas servir de reference. Debogage ponctuel uniquement.

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/check_linkage.py            # tout CODE/
  python TOOLS/AGENT_WORKFLOW/scripts/check_linkage.py --report   # + bloc de restitution
  python TOOLS/AGENT_WORKFLOW/scripts/check_linkage.py --files CODE/MAIN/PRG_10_Outputs_LD.st
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

# FB fournis par une librairie CODESYS (pas de POU correspondant dans CODE/).
# Ajouter ici uniquement apres verification, jamais pour faire taire une erreur.
LIBRARY_FB_TYPES: set[str] = set()

# Sections de declaration dont le contenu est une interface, pas une instance
# possedee : on n'exige pas d'appel pour celles-ci.
INTERFACE_SECTIONS = {"VAR_INPUT", "VAR_OUTPUT", "VAR_IN_OUT", "VAR_EXTERNAL"}

# `FUNCTION_BLOCK PUBLIC FB_Winch EXTENDS ...` : modificateurs d'acces optionnels.
POU_HEADER = re.compile(
    r"^\s*(PROGRAM|FUNCTION_BLOCK|FUNCTION|INTERFACE)\s+"
    r"(?:(?:PUBLIC|PRIVATE|PROTECTED|INTERNAL|FINAL|ABSTRACT)\s+)*"
    r"([A-Za-z_]\w*)",
    re.MULTILINE,
)
VAR_BLOCK = re.compile(
    r"^[ \t]*(VAR_INPUT|VAR_OUTPUT|VAR_IN_OUT|VAR_EXTERNAL|VAR_GLOBAL|VAR_TEMP|VAR_STAT|VAR)"
    r"(?P<attrs>[ \t]+(?:CONSTANT|RETAIN|PERSISTENT|\{[^}]*\})[^\r\n]*)?[ \t]*$"
    r"(?P<body>.*?)^[ \t]*END_VAR",
    re.MULTILINE | re.DOTALL,
)
# `Nom : Type;`  /  `Nom : ARRAY[..] OF Type;`  /  `Nom : REFERENCE TO Type;`
DECL = re.compile(
    r"^[ \t]*(?P<name>[A-Za-z_]\w*)\s*:\s*"
    r"(?P<ref>REFERENCE\s+TO\s+)?"
    r"(?:ARRAY\s*\[[^\]]*\]\s*OF\s+)?"
    r"(?P<type>[A-Za-z_]\w*)",
    re.MULTILINE,
)
CALL = re.compile(r"\b(?P<name>[A-Za-z_]\w*)\s*\(")
CROSS_REF = re.compile(r"\b(?P<pou>PRG_\w+)\s*\.\s*(?P<member>[A-Za-z_]\w*)")
BUNDLE_BLOCK = re.compile(r'<block\b[^>]*typeName="(?P<type>[^"]+)"[^>]*instanceName="(?P<inst>[^"]+)"')
BUNDLE_POU = re.compile(r'<pou\s+name="(?P<name>[^"]+)"')


def strip_comments(text: str) -> str:
    """Neutralise (* *) et // en conservant les numeros de ligne."""

    def blank(match: re.Match[str]) -> str:
        return re.sub(r"[^\r\n]", " ", match.group(0))

    text = re.sub(r"\(\*.*?\*\)", blank, text, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", blank, text)


@dataclass
class Pou:
    name: str
    kind: str
    path: Path
    # nom -> (type, section, ligne)
    declarations: dict[str, tuple[str, str, int]] = field(default_factory=dict)
    body: str = ""
    body_offset_map: list[tuple[int, int]] = field(default_factory=list)

    def owned_instances(self, fb_types: set[str]) -> dict[str, tuple[str, int]]:
        """Instances de FB reellement possedees par ce POU (hors interface)."""
        out: dict[str, tuple[str, int]] = {}
        for name, (typ, section, line) in self.declarations.items():
            if section in INTERFACE_SECTIONS:
                continue
            if typ in fb_types or typ.startswith("FB_"):
                out[name] = (typ, line)
        return out


def line_of(text: str, pos: int) -> int:
    return text.count("\n", 0, pos) + 1


def parse_pou(path: Path) -> Pou | None:
    raw = path.read_text(encoding="utf-8", errors="replace")
    clean = strip_comments(raw)

    header = POU_HEADER.search(clean)
    if not header:
        return None
    pou = Pou(name=header.group(2), kind=header.group(1), path=path)

    # Le corps = le fichier nettoye dont on neutralise les zones de declaration.
    # On conserve les sauts de ligne pour que les numeros de ligne restent exacts.
    body_chars = list(clean)

    def blank_span(start: int, end: int) -> None:
        for i in range(start, end):
            if body_chars[i] != "\n":
                body_chars[i] = " "

    blank_span(0, header.end())

    for block in VAR_BLOCK.finditer(clean):
        if block.start() < header.end():
            continue
        blank_span(block.start(), block.end())
        section = block.group(1)
        attrs = block.group("attrs") or ""
        if "CONSTANT" in attrs:
            section = f"{section}_CONSTANT"
        for decl in DECL.finditer(block.group("body")):
            if decl.group("ref"):
                continue  # REFERENCE TO : alias, pas une instance possedee
            name = decl.group("name")
            if name.upper() in {"END_VAR", "STRUCT"}:
                continue
            pou.declarations.setdefault(
                name,
                (
                    decl.group("type"),
                    section,
                    line_of(clean, block.start("body") + decl.start()),
                ),
            )
    pou.body = "".join(body_chars)
    return pou


def load_native_xml_pou_names(root: Path) -> set[str]:
    """POU definis directement en XML PLCopenXML natif (ex. PRG_GLOBAL_CFC.xml,
    PRG_AU_Acquisition_CFC.xml). check_linkage.py ne parse que les .st : ces POU
    sont donc traites comme externes de confiance pour L4 (reference croisee),
    le generator/xml_builder.py validant deja leur cablage interne a la build.
    """
    names: set[str] = set()
    code = root / "CODE"
    if not code.is_dir():
        return names
    for xml_path in code.rglob("*.xml"):
        if xml_path.name.startswith("CODE_Bundle") or xml_path.name.startswith("CODE_AU_Bundle"):
            continue
        text = xml_path.read_text(encoding="utf-8", errors="replace")
        names.update(m.group("name") for m in BUNDLE_POU.finditer(text))
    return names


def load_bundle_blocks(root: Path) -> list[tuple[str, str, str]]:
    """Retourne [(pou, instanceName, typeName)] du bundle PLCopenXML."""
    bundle = root / "CODE" / "CODE_Bundle.xml"
    if not bundle.is_file():
        return []
    text = bundle.read_text(encoding="utf-8", errors="replace")
    out: list[tuple[str, str, str]] = []
    pous = [(m.start(), m.group("name")) for m in BUNDLE_POU.finditer(text)]
    for match in BUNDLE_BLOCK.finditer(text):
        owner = ""
        for pos, name in pous:
            if pos < match.start():
                owner = name
            else:
                break
        out.append((owner, match.group("inst"), match.group("type")))
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--files", nargs="*", help="Limiter le rapport a ces fichiers (analyse globale conservee)")
    parser.add_argument("--report", action="store_true", help="Afficher le bloc de restitution agent")
    parser.add_argument("--strict", action="store_true", help="Traiter les avertissements comme des erreurs")
    args = parser.parse_args()

    root = args.root.resolve()
    code = root / "CODE"
    if not code.is_dir():
        print(f"[ERROR] dossier introuvable : {code}", file=sys.stderr)
        return 2

    pous: dict[str, Pou] = {}
    for path in sorted(code.rglob("*.st")):
        pou = parse_pou(path)
        if pou:
            pous[pou.name] = pou

    native_xml_pous = load_native_xml_pou_names(root)

    fb_types = {p.name for p in pous.values() if p.kind == "FUNCTION_BLOCK"} | LIBRARY_FB_TYPES
    function_names = {p.name for p in pous.values() if p.kind == "FUNCTION"}

    # Index global des instances : nom -> [POU]
    instances_by_name: dict[str, list[str]] = {}
    for pou in pous.values():
        for inst in pou.owned_instances(fb_types):
            instances_by_name.setdefault(inst, []).append(pou.name)

    errors: list[str] = []
    warnings: list[str] = []
    verified: list[str] = []

    for pou in sorted(pous.values(), key=lambda p: p.name):
        rel = pou.path.relative_to(root).as_posix()
        called = {m.group("name") for m in CALL.finditer(pou.body)}

        for inst, (typ, line) in sorted(pou.owned_instances(fb_types).items()):
            # L2 — type inconnu
            if typ not in fb_types:
                errors.append(
                    f"[L2] {rel}:{line}: type inconnu `{typ}` pour l'instance `{inst}` "
                    f"(aucun FUNCTION_BLOCK de ce nom dans CODE/)"
                )
                continue
            # L1 — instance jamais appelee
            if inst not in called:
                errors.append(
                    f"[L1] {rel}:{line}: instance `{inst} : {typ}` declaree mais JAMAIS appelee "
                    f"dans le corps de {pou.name} (orpheline)"
                )
            else:
                call_line = line_of(pou.body, pou.body.find(f"{inst}("))
                verified.append(f"{inst} : {typ} — declaree {rel}:{line} · appelee :{call_line}")

            # L7 — homonymie entre PROGRAMMES uniquement.
            # Deux FB peuvent legitimement composer une brique de meme nom
            # (`Brake`, `CycleTimeCalc`) : c'est de l'encapsulation, pas un doublon.
            # Entre PROGRAM, en revanche, un meme nom d'instance signale un
            # possible copier-coller de cablage.
            owners = [o for o in instances_by_name.get(inst, []) if pous[o].kind == "PROGRAM"]
            if pou.kind == "PROGRAM" and len(owners) > 1:
                warnings.append(
                    f"[L7] {rel}:{line}: nom d'instance `{inst}` declare dans plusieurs POU "
                    f"({', '.join(sorted(owners))}) — verifier qu'aucune n'est un doublon accidentel"
                )

        # L3 — appel d'une instance non declaree ici
        owned = set(pou.owned_instances(fb_types))
        for name in sorted(called):
            if name in owned or name in fb_types or name in function_names:
                continue
            other_owners = [o for o in instances_by_name.get(name, []) if o != pou.name]
            if other_owners:
                pos = pou.body.find(f"{name}(")
                errors.append(
                    f"[L3] {rel}:{line_of(pou.body, pos)}: `{name}(...)` appele dans {pou.name} "
                    f"alors que l'instance est declaree dans {', '.join(sorted(other_owners))}"
                )

        # L4 — reference croisee vers un POU/membre inexistant
        for match in CROSS_REF.finditer(pou.body):
            target, member = match.group("pou"), match.group("member")
            if target == pou.name:
                continue
            line = line_of(pou.body, match.start())
            if target in native_xml_pous:
                continue  # POU XML natif (CFC) : cablage deja valide par le generator a la build
            if target not in pous:
                errors.append(f"[L4] {rel}:{line}: reference vers le POU inexistant `{target}`")
            elif member not in pous[target].declarations:
                errors.append(
                    f"[L4] {rel}:{line}: `{target}.{member}` — `{member}` n'est declare nulle part "
                    f"dans {target} (reference orpheline, ne compilera pas)"
                )

    # L5 — coherence bundle PLCopenXML
    for owner, inst, typ in load_bundle_blocks(root):
        pou = pous.get(owner)
        if not pou:
            continue
        declared = pou.declarations.get(inst)
        if not declared:
            errors.append(
                f"[L5] CODE/CODE_Bundle.xml: bloc `{inst}` dans {owner} sans declaration correspondante"
            )
        elif declared[0] != typ:
            errors.append(
                f"[L5] CODE/CODE_Bundle.xml: {owner}.{inst} typeName=\"{typ}\" "
                f"alors que la declaration dit `{declared[0]}`"
            )

    # L6 RETIRE (decision 2026-07-29). Il lisait `Device.export` pour verifier
    # qu'un PROGRAM figurait dans la configuration de tache. Or `Device.export`
    # est mis a jour au bon vouloir humain : ce n'est PAS une reference de
    # controle, seulement un outil de debogage ponctuel. Le controle produisait
    # donc du bruit par conception des que l'export avait un jour de retard.
    # Ne pas le reintroduire : aucun gate ne doit dependre de `Device.export`.

    for warning in warnings:
        print(f"[WARN] {warning}")
    for error in errors:
        print(f"[ERROR] {error}", file=sys.stderr)

    if args.report:
        print()
        print("```text")
        print(f"Auto-verification liaison (check_linkage.py) — {'FAIL' if errors else 'PASS'}")
        selected = args.files or []
        shown = [v for v in verified if not selected or any(s in v for s in selected)]
        limit = 12 if selected else 6
        for line in shown[:limit]:
            print(f"  OK  {line}")
        if len(shown) > limit:
            print(f"  ... {len(shown) - limit} autres instances verifiees")
        for error in errors[:5]:
            print(f"  KO  {error}")
        for warning in warnings[:3]:
            print(f"  !   {warning}")
        print("```")

    failed = bool(errors) or (args.strict and bool(warnings))
    print(
        f"\nLinkage check: {'FAIL' if failed else 'PASS'} "
        f"({len(errors)} erreur(s), {len(warnings)} avertissement(s), "
        f"{len(verified)} instance(s) verifiee(s))"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
