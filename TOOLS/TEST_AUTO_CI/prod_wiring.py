#!/usr/bin/env python3
"""Diagramme de bloc "boite noire" (pins gauche=IN, droite=OUT/IN_OUT) pour un FB teste.

Principe (demande explicite) : l'INTERFACE (liste des pins, section, type) ne vient JAMAIS
du parsing du .st du FB -- elle vient du generated.hpp produit par STruCpp (compilateur =
verite). On "peuple" ensuite ces pins avec le cablage REEL de production, qui lui ne peut
venir que du point d'instanciation dans le .st appelant (instXxx(Param := Expr, ...) pour les
IN/IN_OUT, instXxx.Pin pour les OUT) -- aucune autre source ne le connait (ni le C genere, ni
le rapport de test qui n'a que des valeurs synthetiques).

Croiser les deux permet un controle de coherence NON BLOQUANT :
  - un pin de l'interface jamais cable en prod -> avertissement (interface inutilisee)
  - un argument cable qui ne correspond a aucun pin -> avertissement (interface a change,
    cablage orphelin -- typiquement un decalage suite a un renommage de pin)
"""

import pathlib
import re

_SECTION_RE = re.compile(
    r"class \w+ \{\npublic:\n(.*?)\n\n    // Implicit", re.DOTALL)
_FIELD_LINE_RE = re.compile(r"^\s*([\w:<>]+)\s+(\w+);\s*$")
_SECTION_HEADERS = {
    "// Inputs": "inputs",
    "// Outputs": "outputs",
    "// In-Out": "in_out",
    "// Local variables": None,  # stop -- pins terminent ici
}


def extract_pins(hpp_text: str, fb_class_name: str) -> dict:
    """Retourne {"inputs": [(name, type)], "outputs": [...], "in_out": [...]} dans l'ordre
    IEC declare -- lu depuis les marqueurs de section que STruCpp emet lui-meme dans le C++
    genere (// Inputs / // Outputs / // In-Out / // Local variables), jamais depuis le .st."""
    m = re.search(rf"class {re.escape(fb_class_name)} \{{\npublic:\n(.*?)\n\n    // Implicit",
                   hpp_text, re.DOTALL)
    pins = {"inputs": [], "outputs": [], "in_out": []}
    if not m:
        return pins

    current = None
    for line in m.group(1).splitlines():
        stripped = line.strip()
        if stripped in _SECTION_HEADERS:
            current = _SECTION_HEADERS[stripped]
            if current is None:
                break
            continue
        if current is None:
            continue
        fm = _FIELD_LINE_RE.match(line)
        if fm:
            pins[current].append((fm.group(2), fm.group(1)))
    return pins


def _strip_comments(text: str) -> str:
    text = re.sub(r"\(\*.*?\*\)", lambda mo: re.sub(r"[^\r\n]", " ", mo.group(0)), text, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", "", text)


def _find_balanced_call(text: str, instance_name: str) -> str | None:
    """Trouve `instance_name(` et retourne le contenu entre la parenthese ouvrante et sa
    fermante (equilibree -- gere les expressions imbriquees comme un ET logique multi-lignes
    ou un appel de fonction en argument)."""
    m = re.search(rf"\b{re.escape(instance_name)}\s*\(", text)
    if not m:
        return None
    start = m.end()
    depth = 1
    i = start
    while i < len(text) and depth > 0:
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
        i += 1
    if depth != 0:
        return None
    return text[start:i - 1]


def parse_call_args(st_text: str, instance_name: str) -> dict:
    """Retourne {PARAM_NOM_MAJ: expression_originale} pour l'appel instance_name(...) trouve
    dans st_text. Cle en MAJUSCULES pour matcher directement les noms de pins de
    generated.hpp (STruCpp uppercase systematiquement)."""
    clean = _strip_comments(st_text)
    block = _find_balanced_call(clean, instance_name)
    if block is None:
        return {}

    args: dict = {}
    depth = 0
    current = []
    parts = []
    for ch in block:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append("".join(current))
            current = []
        else:
            current.append(ch)
    if "".join(current).strip():
        parts.append("".join(current))

    for part in parts:
        if ":=" not in part:
            continue
        name, expr = part.split(":=", 1)
        args[name.strip().upper()] = expr.strip().rstrip(",")
    return args


def find_output_usages_in_text(text: str, instance_name: str, file_label: str = "") -> dict:
    """Retourne {PIN_NOM_MAJ: [(file_label, ligne_de_contexte), ...]} pour chaque
    `instance_name.Pin` trouve dans le texte (usage en lecture des sorties)."""
    clean = _strip_comments(text)
    usages: dict = {}
    pattern = re.compile(rf"\b{re.escape(instance_name)}\.(\w+)")
    lines = clean.splitlines()

    for m in pattern.finditer(clean):
        pin = m.group(1).upper()
        line_idx = clean.count("\n", 0, m.start())
        context = lines[line_idx].strip() if line_idx < len(lines) else ""
        usages.setdefault(pin, []).append((file_label, context))
    return usages


def find_output_usages(search_root, instance_name: str) -> dict:
    """Scanne TOUT `search_root` (recursif, *.st) pour les usages `instance_name.Pin` --
    les consommateurs d'une sortie sont typiquement dans un AUTRE fichier que celui qui
    instancie le FB (ex: FB_Joystick instancie dans PRG_02_Acquisition, mais AxisCmdX/Y
    consommes par les PRG Treuils/Translation) -- se limiter au fichier d'instanciation
    produirait des faux positifs "jamais lu"."""
    usages: dict = {}
    for path in pathlib.Path(search_root).rglob("*.st"):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if instance_name not in text:
            continue
        file_label = str(path.relative_to(search_root)).replace("\\", "/")
        for pin, hits in find_output_usages_in_text(text, instance_name, file_label).items():
            usages.setdefault(pin, []).extend(hits)
    return usages


def build_wiring(hpp_path, fb_class_name: str, prod_file, instance_name: str, search_root=None) -> dict:
    """Assemble pins (verite compilateur) + cablage reel (verite .st de production) + les
    ecarts entre les deux. Jamais d'exception : fichier prod absent/illisible -> cablage vide
    (le diagramme se degrade en pinout nu, pas de crash du run de test). search_root :
    repertoire scanne pour les usages de sortie (defaut : dossier parent de prod_file)."""
    try:
        hpp_text = pathlib.Path(hpp_path).read_text(encoding="utf-8")
    except OSError:
        return {"pins": {"inputs": [], "outputs": [], "in_out": []}, "call_args": {},
                "output_usages": {}, "unwired_inputs": [], "unwired_outputs": [],
                "orphan_args": []}

    pins = extract_pins(hpp_text, fb_class_name)

    call_args, output_usages = {}, {}
    if prod_file is not None:
        try:
            prod_text = pathlib.Path(prod_file).read_text(encoding="utf-8")
            call_args = parse_call_args(prod_text, instance_name)
            root = search_root or pathlib.Path(prod_file).parent
            output_usages = find_output_usages(root, instance_name)
        except OSError:
            pass

    in_names = {n.upper() for n, _t in pins["inputs"] + pins["in_out"]}
    out_names = {n.upper() for n, _t in pins["outputs"]}

    unwired_inputs = sorted(n for n in in_names if n not in call_args)
    unwired_outputs = sorted(n for n in out_names if n not in output_usages)
    orphan_args = sorted(n for n in call_args if n not in in_names)

    return {
        "pins": pins, "call_args": call_args, "output_usages": output_usages,
        "unwired_inputs": unwired_inputs, "unwired_outputs": unwired_outputs,
        "orphan_args": orphan_args,
    }
