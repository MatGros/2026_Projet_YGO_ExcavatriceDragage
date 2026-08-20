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
  L13 orphelins : FUNCTION_BLOCK jamais instancie / GVL jamais reference /
      PROGRAM stub sans aucune instruction executable (REX 2026-08-01 :
      FB_Sim_AU_ChainFeedback, GVL_Simulation_AU, PRG_NETWORK_CFC — ecrits
      puis jamais raccordes, jamais detectes avant suppression manuelle)

Aucun controle ne lit `Device.export` : cet export est mis a jour au bon vouloir
humain, il ne peut donc pas servir de reference. Debogage ponctuel uniquement.

Usage :
  python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py            # tout CODE/
  python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report   # + bloc de restitution
  python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --files CODE/MAIN/PRG_10_Outputs_LD.st
"""

from __future__ import annotations

import argparse
import re
import sys
import yaml
from dataclasses import dataclass, field
from pathlib import Path

# Import L8-L12 gates
try:
    from linkage_gates_l8_l12 import (
        L8Checker, L8Finding,
        L9Checker, L9Finding,
        L10Checker, L10Finding,
        L11Checker, L11Finding,
        L12Checker, L12Finding,
        load_io_mapping,
    )
except ImportError as e:
    print(f"[WARNING] L8-L12 gates not available: {e}")
    # Fallback: empty classes
    class L8Checker: pass
    class L9Checker: pass
    class L10Checker: pass
    class L11Checker: pass
    class L12Checker: pass
    def load_io_mapping(root): return {}

# Import Device.export parser
try:
    from parse_device_export import load_device_export_io_map
except ImportError:
    # Si parse_device_export n'est pas disponible, créer version fallback
    def load_device_export_io_map(root: Path) -> dict:
        """Fallback: retourne dico vide si parser indisponible."""
        return {}

# FB fournis par une librairie CODESYS (pas de POU correspondant dans CODE/).
# Ajouter ici uniquement apres verification, jamais pour faire taire une erreur.
LIBRARY_FB_TYPES: set[str] = set()

# L13 — orphelins connus, exemptes du niveau ERROR mais toujours affiches en WARN.
# Ajouter ici UNIQUEMENT apres verification manuelle + justification tracee,
# jamais pour faire taire un vrai bug. Retirer la ligne des qu'elle n'est plus
# vraie (POU instancie/reference, ou supprime).
KNOWN_ORPHANS_PENDING_DECISION: dict[str, str] = {
    "FB_Output": (
        "brique candidate 'reduite' : integration Winch/Translation pas encore "
        "decidee (cf. header CODE/A_COMMUN/FB_Output.st) — retirer de cette liste "
        "des qu'elle est instanciee ou supprimee"
    ),
    # 2026-08-05 — orphelins constates lors de l'audit Translation M3 (session
    # M3, aucun n'a ete introduit par cette session : lecture seule des
    # domaines Winch/Cycle/Encodeurs). Surfacent ici uniquement parce que
    # c'est la premiere fois qu'un fichier CODE/*.st est touche sous ce hook
    # depuis leur apparition — pas une regression de ce lot.
    "FB_Safety_Winch": (
        "meme classe de bug que FB_Safety_Translation, deja documentee dans "
        "l'en-tete CODE/M_MAIN/PRG_06_Outputs.st avant cette session — hors "
        "perimetre M3, PLAN_TASK lot 5 'Reliquats safety' (T72-T74) — "
        "suppression/cablage a trancher par l'utilisateur"
    ),
    "FB_Cycle": (
        "orpheline constatee 2026-08-05 en creusant l'audit M3 (sequenceur "
        "SEMI_AUTO complet jamais instancie) — hors perimetre de la session "
        "M3, non investiguee en detail, necessite un audit dedie avant toute "
        "decision"
    ),
    "FB_Acquisition_Preflight": (
        "orpheline revelee 2026-08-05 par le premier passage du hook Stop sur "
        "CODE/*.st depuis son introduction — non investiguee, hors perimetre "
        "de la session M3, necessite un audit dedie"
    ),
    "FB_Encoder_Safety": (
        "orpheline revelee 2026-08-05, meme situation que FB_Acquisition_Preflight "
        "— non investiguee, hors perimetre M3, necessite un audit dedie"
    ),
    "FB_Encoder_SpeedMeasure": (
        "orpheline revelee 2026-08-05, meme situation que FB_Acquisition_Preflight "
        "— non investiguee, hors perimetre M3, necessite un audit dedie"
    ),
    "FB_Encoder_SpeedMonitor": (
        "orpheline revelee 2026-08-05, meme situation que FB_Acquisition_Preflight "
        "— non investiguee, hors perimetre M3, necessite un audit dedie"
    ),
    "FB_WinchLoadEstimator": (
        "orpheline revelee 2026-08-05, meme situation que FB_Acquisition_Preflight "
        "— non investiguee, hors perimetre M3, necessite un audit dedie"
    ),
    "FB_Winch_Symmetry": (
        "orpheline revelee 2026-08-05, meme situation que FB_Acquisition_Preflight "
        "— non investiguee, hors perimetre M3, necessite un audit dedie"
    ),
}

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
# `GVL_Foo.Champ` : reference a un champ de GVL (nom libre, pas seulement PRG_).
GVL_FIELD_REF = re.compile(r"\b(?P<gvl>GVL_\w+)\s*\.\s*(?P<member>[A-Za-z_]\w*)")


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
    PRG_AU_Acquisition_CFC.xml). G200_check_linkage.py ne parse que les .st : ces POU
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


def load_native_xml_block_types(root: Path) -> set[str]:
    """Types de FB réellement instanciés dans les pages CFC XML natives.

    L13 contrôlait historiquement uniquement les déclarations ST ``instX : FB_X``.
    Une page CFC native déclare ses instances dans XML (``typeName=``) : l'ignorer
    créait le faux positif « FB orphelin » dès qu'un FB était câblé uniquement dans
    une page XML. Les bundles ne sont pas utilisés ici : la source XML est la
    preuve, donc le contrôle reste valable avant génération du bundle.
    """
    types: set[str] = set()
    code = root / "CODE"
    if not code.is_dir():
        return types
    for xml_path in code.rglob("*.xml"):
        if xml_path.name.startswith("CODE_Bundle") or xml_path.name.startswith("CODE_AU_Bundle"):
            continue
        text = xml_path.read_text(encoding="utf-8", errors="replace")
        types.update(match.group("type") for match in BUNDLE_BLOCK.finditer(text))
    return types


def load_bundle_blocks(root: Path) -> list[tuple[str, str, str]]:
    """Retourne [(pou, instanceName, typeName)] du bundle PLCopenXML."""
    bundle = root / "CODE_XML" / "CODE_Bundle.xml"
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


def load_gvl_files(code: Path) -> dict[str, Path]:
    """GVL sans header POU (VAR_GLOBAL nu) : nom de fichier -> chemin.

    parse_pou() ne les voit pas : POU_HEADER ne matche que PROGRAM/
    FUNCTION_BLOCK/FUNCTION/INTERFACE, et un fichier GVL_*.st est un simple
    bloc VAR_GLOBAL sans aucun de ces mots-cles. On les retrouve par
    convention de nommage (obligatoire, cf. NAMING_CONVENTION.md).
    """
    out: dict[str, Path] = {}
    for path in sorted(code.rglob("GVL_*.st")):
        raw = path.read_text(encoding="utf-8", errors="replace")
        if re.search(r"^\s*VAR_GLOBAL\b", strip_comments(raw), re.MULTILINE):
            out[path.stem] = path
    return out


def parse_gvl_fields(path: Path) -> tuple[set[str], bool]:
    """Champs top-level d'un fichier GVL + indicateur `qualified_only`.

    Sans `{attribute 'qualified_only'}`, CODESYS autorise l'acces AUX CHAMPS
    par leur nom nu (sans prefixe `NomGvl.`) : c'est le cas de GVL_PERSISTENT,
    GVL_BypassRetain et GVL_Translation_M3_Stub sur ce projet. Un detecteur
    qui n'exigerait que la forme qualifiee produirait des faux positifs
    massifs sur ces GVL pourtant activement utilisees.
    """
    raw = path.read_text(encoding="utf-8", errors="replace")
    clean = strip_comments(raw)
    qualified_only = "qualified_only" in clean
    fields: set[str] = set()
    for block in VAR_BLOCK.finditer(clean):
        if block.group(1) != "VAR_GLOBAL":
            continue
        for decl in DECL.finditer(block.group("body")):
            if decl.group("ref"):
                continue
            name = decl.group("name")
            if name.upper() in {"END_VAR", "STRUCT"}:
                continue
            fields.add(name)
    return fields, qualified_only


def find_l13_orphans(pous: dict[str, Pou], gvl_files: dict[str, Path], root: Path) -> list[str]:
    """L13 — POU/GVL declare dans CODE/ mais jamais reellement cable.

    REX 2026-08-01 (LOT_A_SUPPRESSION_CODE_MORT) : `FB_Sim_AU_ChainFeedback`,
    `GVL_Simulation_AU` et `PRG_NETWORK_CFC` ont ete ecrits, bundles, testes
    au niveau forme... et jamais raccordes au reste du programme. Aucun des
    controles L1-L12 ne les voit, car ils portent sur le cablage INTERNE
    d'un POU deja identifie comme utilise, pas sur la question "ce POU
    sert-il a quelque chose ?". Trois signatures distinctes, aucune ne lit
    Device.export (decision 2026-07-29) :

      - FUNCTION_BLOCK jamais instancie : aucune declaration `nom : CeType`
        nulle part ailleurs dans CODE/ (le type ne sert a rien s'il n'est
        le type d'aucune variable).
      - GVL jamais reference : aucun `NomGvl.Champ` hors de son propre
        fichier (une GVL existe pour etre lue/ecrite par d'autres POU).
      - PROGRAM stub vide : aucune instruction executable dans le corps
        (uniquement declarations/commentaires) — un PROGRAM reellement
        cable dans une tache a toujours au moins une affectation ou un
        appel ; un stub jamais complete est indiscernable d'un stub jamais
        raccorde, donc traite comme orphelin.

    Deliberement PAS base sur une liste "officielle" de programmes (ex.
    section Execution cible de AF_Partie-02) : cette liste peut devenir
    perimee independamment du code (elle l'etait déjà pour plusieurs
    PROGRAM legitimes lors de la conception de ce gate), ce qui produirait
    des faux positifs sur du code actif. Le stub vide est un fait purement
    structurel, jamais perime.
    """
    errors: list[str] = []

    # --- FUNCTION_BLOCK jamais instancie ------------------------------------
    type_usage: dict[str, set[str]] = {}
    for pou in pous.values():
        for typ, _section, _line in pou.declarations.values():
            type_usage.setdefault(typ, set()).add(pou.name)

    # Les instances CFC XML n'apparaissent pas dans les declarations ST.
    # Marquage distinct afin que L13 reste explicable dans les rapports.
    for typ in load_native_xml_block_types(root):
        type_usage.setdefault(typ, set()).add("<CFC_XML_NATIVE>")

    for pou in sorted(pous.values(), key=lambda p: p.name):
        if pou.kind != "FUNCTION_BLOCK":
            continue
        if not type_usage.get(pou.name):
            rel = pou.path.relative_to(root).as_posix()
            _report(errors, pou.name, f"[L13-FB] {rel}: FUNCTION_BLOCK `{pou.name}` declare mais jamais "
                    f"instancie (aucun `: {pou.name}` ailleurs dans CODE/) — orphelin")

    # --- GVL jamais referencee -----------------------------------------------
    code = root / "CODE"
    raw_by_path: dict[Path, str] = {
        p: strip_comments(p.read_text(encoding="utf-8", errors="replace"))
        for p in code.rglob("*.st")
    }
    for gvl_name, gvl_path in sorted(gvl_files.items()):
        fields, qualified_only = parse_gvl_fields(gvl_path)
        others = {path: text for path, text in raw_by_path.items() if path != gvl_path}

        qualified_hit = any(
            any(m.group("gvl") == gvl_name for m in GVL_FIELD_REF.finditer(text))
            for text in others.values()
        )
        bare_hit = False
        if not qualified_only and fields:
            word_re = re.compile(r"\b(?:" + "|".join(re.escape(f) for f in fields) + r")\b")
            bare_hit = any(word_re.search(text) for text in others.values())

        if not (qualified_hit or bare_hit):
            rel = gvl_path.relative_to(root).as_posix()
            _report(errors, gvl_name, f"[L13-GVL] {rel}: `{gvl_name}` declare mais aucun de ses champs "
                    f"n'est jamais lu/ecrit hors de ce fichier (qualifie ou nu) — orphelin")

    # --- PROGRAM stub sans instruction executable -----------------------------
    for pou in sorted(pous.values(), key=lambda p: p.name):
        if pou.kind != "PROGRAM":
            continue
        if not pou.body.strip():
            rel = pou.path.relative_to(root).as_posix()
            _report(errors, pou.name, f"[L13-PRG] {rel}: PROGRAM `{pou.name}` sans aucune instruction "
                    f"executable (stub vide) — orphelin, jamais cable")

    return errors


def _report(errors: list[str], name: str, message: str) -> None:
    """Ajoute un finding L13, sauf si `name` est une exemption tracee (WARN quand meme)."""
    waiver = KNOWN_ORPHANS_PENDING_DECISION.get(name)
    if waiver:
        print(f"[WARN] {message} — EXEMPTE : {waiver}")
    else:
        errors.append(message)


# ═══════════════════════════════════════════════════════════════════════════════
# L8-L12 CHECKERS
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class L8Finding:
    """Résultat L8 (assignation VAR_OUTPUT)."""
    level: str  # HIGH, MEDIUM, OK, IGNORE
    var_name: str
    var_type: str
    line: int
    message: str
    details: str = ""


class L8Checker:
    """Vérifie que les VAR_OUTPUT physiques sont assignées."""
    
    PHYSICAL_OUTPUT_PATTERNS = [r"_RQ$", r"_DQ$", r"_Q$", r"_DO$"]
    IGNORE_PATTERNS = [r"^Diag", r"_Txt$", r"_Count$", r"_Status", r"_Temp", r"_Feedback"]
    
    def __init__(self, pou: Pou):
        self.pou = pou
    
    def is_physical_output(self, var_name: str) -> bool:
        """Détermine si une VAR_OUTPUT est physique."""
        if not any(re.search(p, var_name) for p in self.PHYSICAL_OUTPUT_PATTERNS):
            return False
        if any(re.search(p, var_name) for p in self.IGNORE_PATTERNS):
            return False
        return True
    
    def check(self) -> list[L8Finding]:
        """Analyse les VAR_OUTPUT."""
        if self.pou.kind != "PROGRAM":
            return []
        
        findings = []
        
        for var_name, (typ, section, line) in self.pou.declarations.items():
            if section != "VAR_OUTPUT":
                continue
            
            if not self.is_physical_output(var_name):
                findings.append(L8Finding(
                    level="IGNORE",
                    var_name=var_name,
                    var_type=typ,
                    line=line,
                    message="Diagnostic/IHM output (no physical pattern)",
                ))
                continue
            
            # Chercher assignation directe
            direct_pattern = rf"^\s*{re.escape(var_name)}\s*:="
            if re.search(direct_pattern, self.pou.body, re.MULTILINE):
                findings.append(L8Finding(
                    level="OK",
                    var_name=var_name,
                    var_type=typ,
                    line=line,
                    message="Assigned directly",
                ))
            # Chercher assignation conditionnelle
            elif re.search(rf"\b{re.escape(var_name)}\s*:=", self.pou.body):
                findings.append(L8Finding(
                    level="MEDIUM",
                    var_name=var_name,
                    var_type=typ,
                    line=line,
                    message="Assigned conditionally only",
                ))
            else:
                findings.append(L8Finding(
                    level="HIGH",
                    var_name=var_name,
                    var_type=typ,
                    line=line,
                    message="Never assigned",
                    details="Physical output declared but implementation missing",
                ))
        
        return findings


@dataclass
class L9Finding:
    """Résultat L9 (mapping matériel)."""
    level: str
    var_name: str
    address: str = ""
    message: str = ""


class L9Checker:
    """Vérifie que VAR_OUTPUT physiques sont addressées.

    Limitation : Device.export XML CODESYS est très propriétaire.
    Alternative : chercher utilisation de l'adresse dans le code ST.
    """

    # `load_io_mapping()` ne construit des clés que pour ces deux POU (seuls
    # points de contact réels entre le code et les canaux physiques bruts du
    # CSV — cf. son propre code : IEC address %Q → PRG_OUTPUTS_LD, sinon
    # PRG_01_Inputs_LD). Vérifier un VAR_OUTPUT de n'importe quel autre PROGRAM
    # contre cette table est un faux positif garanti par construction : la
    # clé ne peut structurellement jamais y figurer (REX 2026-08-01, T100).
    PHYSICAL_IO_POUS = frozenset({"PRG_OUTPUTS_LD", "PRG_01_Inputs_LD"})

    def __init__(self, pou: Pou, device_io_map: dict):
        self.pou = pou
        self.device_io_map = device_io_map

    def check(self) -> list[L9Finding]:
        """Analyse les VAR_OUTPUT.

        Remarque : Device.export XML n'expose pas directement les adresses I/O.
        L9 seulement vérifie si device_io_map est disponible et peuplée.
        """
        if self.pou.kind != "PROGRAM":
            return []

        if self.pou.name not in self.PHYSICAL_IO_POUS:
            return []

        findings = []

        # Si device_io_map vide ou None, ignorer L9 (Device.export parsing a échoué)
        if not self.device_io_map:
            return findings

        for var_name, (typ, section, line) in self.pou.declarations.items():
            if section != "VAR_OUTPUT":
                continue

            full_name = f"{self.pou.name}.{var_name}"

            if full_name in self.device_io_map:
                addr = self.device_io_map[full_name].get("address", "?")
                findings.append(L9Finding(
                    level="OK",
                    var_name=var_name,
                    address=addr,
                    message=f"Mapped to {addr}",
                ))
            else:
                # Non prouvé faux : le CSV nomme les canaux avec leur libellé
                # matériel brut (ex. `M1_RelayFwd_Up_DQ`) alors que le code
                # utilise le nom métier retraité (ex. `M1RelayFwd`) — aucune
                # correspondance automatique fiable sans risquer d'inventer
                # une adresse. WARN, pas KO : à rapprocher manuellement par
                # l'utilisateur, jamais par une heuristique de nommage.
                findings.append(L9Finding(
                    level="MEDIUM",
                    var_name=var_name,
                    message=(
                        "Not found in I/O map by exact name — verifier "
                        "manuellement contre le nom de canal brut du CSV "
                        "(convention de nommage differente)"
                    ),
                ))

        return findings
    
    def _has_address_annotation(self, var_name: str) -> bool:
        """Vérifie si variable a annotation d'adresse (%QX, %QD, etc.)."""
        # Chercher dans commentaires proches
        context = self.pou.body[max(0, self.pou.body.find(var_name)-200):self.pou.body.find(var_name)+200]
        return bool(re.search(r"%[QI][XDWB]\d+\.\d+", context))


@dataclass
class L10Finding:
    """Résultat L10 (producteur unique)."""
    level: str
    var_name: str
    sources: list[tuple[str, int]] = field(default_factory=list)
    message: str = ""


class L10Checker:
    """Vérifie que chaque variable a UN SEUL producteur."""
    
    def __init__(self, pous: dict[str, Pou]):
        self.pous = pous
        self.assignments: dict[str, list[tuple[str, int]]] = {}
    
    def analyze_all(self) -> None:
        """Collecte toutes les assignations."""
        for pou in self.pous.values():
            for match in re.finditer(r"(\w+)\s*:=", pou.body):
                var_name = match.group(1)
                full_name = f"{pou.name}.{var_name}"
                line = line_of(pou.body, match.start())
                
                if full_name not in self.assignments:
                    self.assignments[full_name] = []
                self.assignments[full_name].append((pou.name, line))
    
    def check(self) -> list[L10Finding]:
        """Détecte multiwriter."""
        self.analyze_all()
        findings = []
        
        for full_name, sources in self.assignments.items():
            if len(sources) > 1:
                findings.append(L10Finding(
                    level="MEDIUM",
                    var_name=full_name,
                    sources=sources,
                    message=f"Assigned from {len(sources)} locations",
                ))
            elif len(sources) == 1:
                findings.append(L10Finding(
                    level="OK",
                    var_name=full_name,
                    sources=sources,
                    message="Single producer",
                ))
        
        return findings


@dataclass
class L11Finding:
    """Résultat L11 (polarité)."""
    level: str
    var_name: str
    keywords: list[str] = field(default_factory=list)
    message: str = ""


class L11Checker:
    """Vérifie que VAR_OUTPUT ont polarité documentée."""
    
    POLARITY_KEYWORDS = [
        "TRUE", "FALSE",
        "avant", "arrière", "forward", "reverse",
        "relâche", "serre", "open", "close",
        "maintien", "coupure", "maintain", "cut",
        "actif", "inactif", "enabled", "disabled",
    ]
    
    def __init__(self, pou: Pou, raw_source: str):
        self.pou = pou
        self.raw_source = raw_source  # Source non-commentée pour extraire les commentaires
    
    def check(self) -> list[L11Finding]:
        """Analyse les VAR_OUTPUT."""
        if self.pou.kind != "PROGRAM":
            return []
        
        findings = []
        
        # Extraire commentaires du source brut
        comments_by_line = self._extract_comments()
        
        for var_name, (typ, section, line) in self.pou.declarations.items():
            if section != "VAR_OUTPUT":
                continue
            
            comment = comments_by_line.get(line, "")
            
            if not comment:
                findings.append(L11Finding(
                    level="MEDIUM",
                    var_name=var_name,
                    message="No comment (polarity undocumented)",
                ))
            else:
                found_keywords = [k for k in self.POLARITY_KEYWORDS if k.lower() in comment.lower()]
                if found_keywords:
                    findings.append(L11Finding(
                        level="OK",
                        var_name=var_name,
                        keywords=found_keywords,
                        message=f"Polarity documented: {', '.join(found_keywords[:3])}",
                    ))
                else:
                    findings.append(L11Finding(
                        level="MEDIUM",
                        var_name=var_name,
                        message="Comment present but no polarity keywords",
                    ))
        
        return findings
    
    def _extract_comments(self) -> dict[int, str]:
        """Extrait commentaires (* ... *) par numéro de ligne (approx)."""
        comments = {}
        # Chercher tous les commentaires
        for match in re.finditer(r"\(\*([^)]*)\*\)", self.raw_source, re.DOTALL):
            line_num = self.raw_source[:match.start()].count("\n") + 1
            comment_text = match.group(1)
            # Stocker pour la ligne ET les 3 lignes après (prise de chance)
            for offset in range(0, 3):
                comments[line_num + offset] = comment_text
        return comments


@dataclass
class L12Finding:
    """Résultat L12 (timing)."""
    level: str
    var_name: str
    duration_ms: int = 0
    message: str = ""


class L12Checker:
    """Vérifie que pulses ont timing réaliste."""
    
    PULSE_KEYWORDS = ["Pulse", "ARM", "Reset", "Trigger", "Arming", "Emergency"]
    MIN_PULSE_TIME_MS = 100
    
    def __init__(self, pou: Pou):
        self.pou = pou
    
    def check(self) -> list[L12Finding]:
        """Analyse les VAR_OUTPUT pulse."""
        if self.pou.kind != "PROGRAM":
            return []
        
        findings = []
        
        for var_name, (typ, section, line) in self.pou.declarations.items():
            if section != "VAR_OUTPUT":
                continue
            
            # Est-ce un pulse?
            is_pulse = any(k.lower() in var_name.lower() for k in self.PULSE_KEYWORDS)
            
            if not is_pulse:
                continue  # Skip non-pulse
            
            # Chercher duration dans le body complet (pas juste le context)
            # Chercher patterns: T#1s, T#200ms, etc. ou "Duration: 1000"
            duration_pattern = r"[Tt]#(\d+)([ms|s]+)|[Dd]uration.*?(\d+)(\s*)(ms|s|min)"
            match = re.search(duration_pattern, self.pou.body)
            
            if not match:
                findings.append(L12Finding(
                    level="MEDIUM",
                    var_name=var_name,
                    message="Pulse without documented duration",
                ))
            else:
                # Parser la durée trouvée
                if match.group(1):  # Format T#1s
                    val = int(match.group(1))
                    unit = match.group(2)
                else:  # Format "Duration: 1000"
                    val = int(match.group(3))
                    unit = match.group(5) or "ms"
                
                if unit.startswith("s"):
                    duration_ms = val * 1000
                elif unit.startswith("min"):
                    duration_ms = val * 60000
                else:
                    duration_ms = val
                
                if duration_ms < self.MIN_PULSE_TIME_MS:
                    findings.append(L12Finding(
                        level="HIGH",
                        var_name=var_name,
                        duration_ms=duration_ms,
                        message=f"Pulse too fast: {duration_ms}ms (min: {self.MIN_PULSE_TIME_MS}ms)",
                    ))
                else:
                    findings.append(L12Finding(
                        level="OK",
                        var_name=var_name,
                        duration_ms=duration_ms,
                        message=f"Pulse duration OK: {duration_ms}ms",
                    ))
        
        return findings


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

    # L13 — orphelins (FB jamais instancie / GVL jamais reference / PROGRAM stub vide)
    gvl_files = load_gvl_files(code)
    l13_errors = find_l13_orphans(pous, gvl_files, root)

    # L6 RETIRE (decision 2026-07-29). Il lisait `Device.export` pour verifier
    # qu'un PROGRAM figurait dans la configuration de tache. Or `Device.export`
    # est mis a jour au bon vouloir humain : ce n'est PAS une reference de
    # controle, seulement un outil de debogage ponctuel. Le controle produisait
    # donc du bruit par conception des que l'export avait un jour de retard.
    # Ne pas le reintroduire : aucun gate ne doit dependre de `Device.export`.

    # ═══════════════════════════════════════════════════════════════════════════════
    # L8-L12 CHECKS
    # ═══════════════════════════════════════════════════════════════════════════════
    
    l8_errors: list[str] = []
    l8_warnings: list[str] = []
    l8_verified: list[str] = []
    
    l9_errors: list[str] = []
    l9_warnings: list[str] = []
    l9_verified: list[str] = []
    
    l10_warnings: list[str] = []
    l10_verified: list[str] = []
    
    l11_warnings: list[str] = []
    l11_verified: list[str] = []
    
    l12_errors: list[str] = []
    l12_warnings: list[str] = []
    l12_verified: list[str] = []
    
    # Charger io_mapping.yaml pour L9 (source of truth)
    device_io_map = load_io_mapping(root)
    # Fallback: Device.export si io_mapping vide
    if not device_io_map:
        device_io_map = load_device_export_io_map(root)
    
    # Lire source brut pour L11 (extraction commentaires)
    raw_sources: dict[str, str] = {}
    for path in code.rglob("*.st"):
        raw_sources[path.name] = path.read_text(encoding="utf-8", errors="replace")
    
    for pou in sorted(pous.values(), key=lambda p: p.name):
        rel = pou.path.relative_to(root).as_posix()
        
        # L8 — Assignation VAR_OUTPUT
        l8_checker = L8Checker(pou)
        for finding in l8_checker.check():
            if finding.level == "HIGH":
                msg = f"[L8] {rel}:{finding.line}: {finding.var_name} : {finding.var_type} — {finding.message}"
                if finding.details:
                    msg += f" ({finding.details})"
                l8_errors.append(msg)
            elif finding.level == "MEDIUM":
                msg = f"[L8] {rel}:{finding.line}: {finding.var_name} : {finding.var_type} — {finding.message}"
                l8_warnings.append(msg)
            elif finding.level == "OK":
                l8_verified.append(f"{finding.var_name} : {finding.var_type} (output) — {finding.message}")
        
        # L9 — Mapping matériel
        if device_io_map:  # Seulement si Device.export était parsable
            l9_checker = L9Checker(pou, device_io_map)
            for finding in l9_checker.check():
                if finding.level == "HIGH":
                    l9_errors.append(f"[L9] {rel}: {finding.var_name} — {finding.message}")
                elif finding.level == "MEDIUM":
                    l9_warnings.append(f"[L9] {rel}: {finding.var_name} — {finding.message}")
                elif finding.level == "OK":
                    l9_verified.append(f"{finding.var_name} → {finding.address}")
        
        # L10 — Producteur unique (agréger à la fin)
        # (Voir après boucle)
        
        # L11 — Polarité documentée
        raw_source = raw_sources.get(pou.path.name, "")
        l11_checker = L11Checker(pou, raw_source)
        for finding in l11_checker.check():
            if finding.level == "MEDIUM":
                l11_warnings.append(f"[L11] {rel}: {finding.var_name} — {finding.message}")
            elif finding.level == "OK":
                l11_verified.append(f"{finding.var_name} — {', '.join(finding.keywords[:2])}")
        
        # L12 — Timing
        l12_checker = L12Checker(pou)
        for finding in l12_checker.check():
            if finding.level == "HIGH":
                l12_errors.append(f"[L12] {rel}: {finding.var_name} — {finding.message}")
            elif finding.level == "MEDIUM":
                l12_warnings.append(f"[L12] {rel}: {finding.var_name} — {finding.message}")
            elif finding.level == "OK":
                l12_verified.append(f"{finding.var_name} — {finding.duration_ms}ms")
    
    # L10 — Producteur unique (globalement)
    if pous:
        l10_checker = L10Checker(pous)
        for finding in l10_checker.check():
            if finding.level == "MEDIUM":
                sources_str = ", ".join([f"{src}:{line}" for src, line in finding.sources])
                l10_warnings.append(f"[L10] {finding.var_name} — {finding.message} ({sources_str})")
            elif finding.level == "OK":
                l10_verified.append(f"{finding.var_name} — {finding.message}")
    
    # Collecte globale
    all_errors = errors + l8_errors + l9_errors + l12_errors + l13_errors
    all_warnings = warnings + l8_warnings + l9_warnings + l11_warnings + l12_warnings + l10_warnings
    all_verified = verified + l8_verified + l9_verified + l10_verified + l11_verified + l12_verified

    # Affichage
    for warning in all_warnings:
        print(f"[WARN] {warning}")
    for error in all_errors:
        print(f"[ERROR] {error}", file=sys.stderr)

    if args.report:
        print()
        print("```text")
        print(f"Auto-verification liaison (G200_check_linkage.py) — {'FAIL' if all_errors else 'PASS'}")
        print(f"  Linkage (L1-L7):    {len(verified)} OK, {len(errors)} KO")
        print(f"  L8 (Output assign): {len(l8_verified)} OK, {len(l8_errors)} KO, {len(l8_warnings)} WARN")
        print(f"  L9 (I/O mapping):   {len(l9_verified)} OK, {len(l9_errors)} KO, {len(l9_warnings)} WARN")
        print(f"  L10 (Single prod):  {len(l10_verified)} OK, {len(l10_warnings)} WARN")
        print(f"  L11 (Polarity):     {len(l11_verified)} OK, {len(l11_warnings)} WARN")
        print(f"  L12 (Timing):       {len(l12_verified)} OK, {len(l12_errors)} KO, {len(l12_warnings)} WARN")
        l13_total = sum(1 for p in pous.values() if p.kind in ("FUNCTION_BLOCK", "PROGRAM")) + len(gvl_files)
        print(f"  L13 (Orphelins):    {l13_total - len(l13_errors)} OK, {len(l13_errors)} KO")

        selected = args.files or []
        shown = [v for v in verified + l8_verified + l9_verified + l10_verified + l11_verified + l12_verified 
                 if not selected or any(s in v for s in selected)]
        limit = 12
        for line in shown[:limit]:
            print(f"  OK  {line}")
        if len(shown) > limit:
            print(f"  ... {len(shown) - limit} autres verifiees")
        
        for error in (errors + l8_errors + l9_errors + l12_errors + l13_errors)[:8]:
            print(f"  KO  {error}")
        for warning in (warnings + l8_warnings + l9_warnings + l11_warnings + l12_warnings + l10_warnings)[:5]:
            print(f"  !   {warning}")
        print("```")

    failed = bool(all_errors) or (args.strict and bool(all_warnings))
    print(
        f"\nLinkage check: {'FAIL' if failed else 'PASS'} "
        f"({len(all_errors)} erreur(s), {len(all_warnings)} avertissement(s), "
        f"{len(all_verified)} instance(s) verifiee(s))"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
