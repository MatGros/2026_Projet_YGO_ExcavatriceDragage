#!/usr/bin/env python3
"""Verifie l'encapsulation d'un FB (et de ses FB enfants, via registry.yaml `sources`) :

1. Ecriture externe : toute affectation (`X := ...` ou `X.Y := ...`) dont l'identifiant de
   base `X` n'est PAS declare dans les blocs VAR_INPUT/VAR_OUTPUT/VAR_IN_OUT/VAR/VAR_TEMP/
   VAR_STAT/VAR CONSTANT de ce meme FB. Un FB ne doit jamais ecrire une variable qui ne lui
   appartient pas -- tout doit transiter par son interface declaree (VAR_INPUT/VAR_OUTPUT/
   VAR_IN_OUT) ou par des sous-instances qu'il possede lui-meme (VAR).
2. Acces GVL direct : toute reference a un identifiant `GVL_*` dans le corps executable --
   une variable globale ne doit jamais entrer/sortir d'un FB autrement que par son interface
   (VAR_INPUT/VAR_OUTPUT/VAR_IN_OUT), meme en lecture seule.

Rapporte AUSSI, pour chaque fichier de la chaine (pas seulement les violations), le nombre de
membres par interface (IN/OUT/IN_OUT/LOCAL) -- une chaine "propre" doit rester visible dans le
rapport, pas seulement le silence en cas de 0 violation.

Non bloquant par design (comme af_coverage.py) : un fichier illisible ou un parsing degrade
retourne une liste vide plutot qu'une exception -- ce module est un bonus de detection, jamais
une dependance dure du pipeline. Analyse purement textuelle (pas de compilation) : peut avoir
des angles morts sur une syntaxe ST exotique (tableaux multi-dim, POINTER TO, etc.) -- a
verifier manuellement si un doute subsiste apres un rapport "0 violation".
"""

import re
import pathlib

_COMMENT_BLOCK_RE = re.compile(r"\(\*.*?\*\)", re.DOTALL)
_COMMENT_LINE_RE = re.compile(r"//[^\n]*")
_FB_NAME_RE = re.compile(r"FUNCTION_BLOCK\s+(?:PUBLIC\s+|PRIVATE\s+|INTERNAL\s+|ABSTRACT\s+|FINAL\s+)*(\w+)")
_VAR_KIND_RE = re.compile(
    r"\bVAR(_INPUT|_OUTPUT|_IN_OUT|_TEMP|_STAT)?(\s+CONSTANT)?\b(.*?)END_VAR",
    re.DOTALL,
)
_DECL_NAME_RE = re.compile(r"^\s*(\w+)\s*(?:AT\s*%\w+)?\s*:\s*[^:=]")
_ASSIGN_RE = re.compile(r":=")
# Chemin d'affectation : identifiant eventuellement suivi d'indexations tableau
# (ex: `instCauses[0].Active`, `Tab[i].Field`, `Mat[1][2]`) puis eventuellement de segments
# membres separes par des points. Le groupement capture TOUT le chemin pour en extraire la
# base (premier identifiant), et non seulement le dernier segment de membre.
_IDENT_PATH_TAIL_RE = re.compile(
    r"([A-Za-z_]\w*(?:\s*\[[^\]\n]*\]\s*)*(?:\.[A-Za-z_]\w*(?:\s*\[[^\]\n]*\]\s*)*)*)\s*$"
)
_GVL_REF_RE = re.compile(r"\bGVL_\w+\b")

_KIND_LABELS = {
    "_INPUT": "input", "_OUTPUT": "output", "_IN_OUT": "inout",
    "_TEMP": "local", "_STAT": "local", None: "local",
}

# Mots-cles / types ST ne devant jamais etre consideres comme une "variable non declaree" --
# le corps peut affecter une donnee via un cast ou une struct litterale (rare dans ce codebase,
# garde-fou minimal).
_ST_RESERVED_LHS = {"THIS"}


def _strip_comments(text: str) -> str:
    text = _COMMENT_BLOCK_RE.sub(" ", text)
    text = _COMMENT_LINE_RE.sub(" ", text)
    return text


def _declared_names_by_kind(text_no_comments: str) -> dict:
    """{name: kind} ou kind in {input, output, inout, local}. En cas de redeclaration
    (jamais legal en ST mais on ne s'y fie pas), le dernier bloc rencontre gagne."""
    by_name = {}
    for suffix, _const, block in _VAR_KIND_RE.findall(text_no_comments):
        kind = _KIND_LABELS[suffix or None]
        for line in block.splitlines():
            m = _DECL_NAME_RE.match(line)
            if m:
                by_name[m.group(1)] = kind
    return by_name


def _executable_body(text_no_comments: str) -> str:
    """Tout ce qui suit le dernier END_VAR (les blocs de declaration sont toujours groupes en
    tete d'un FUNCTION_BLOCK/PROGRAM en ST) -- coupe avant END_FUNCTION_BLOCK/END_PROGRAM s'il
    est present."""
    idx = text_no_comments.rfind("END_VAR")
    if idx == -1:
        return ""
    body = text_no_comments[idx + len("END_VAR"):]
    for terminator in ("END_FUNCTION_BLOCK", "END_PROGRAM"):
        t_idx = body.find(terminator)
        if t_idx != -1:
            body = body[:t_idx]
    return body


def _paren_depths(body: str) -> list:
    """Profondeur de parenthesage/crochet a chaque position de `body` (avant le caractere),
    pour distinguer une affectation reelle (profondeur 0) d'un argument nomme d'appel FB
    (profondeur > 0, ex: `fb(Enable := TRUE)`)."""
    depths = [0] * (len(body) + 1)
    depth = 0
    for i, ch in enumerate(body):
        depths[i] = depth
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth = max(0, depth - 1)
    depths[len(body)] = depth
    return depths


def _assignment_targets(body: str) -> list:
    """Retourne l'identifiant de base (avant le premier '.') de chaque affectation reelle
    (`:=` a profondeur de parenthesage 0) du corps."""
    depths = _paren_depths(body)
    targets = []
    for m in _ASSIGN_RE.finditer(body):
        if depths[m.start()] != 0:
            continue
        prefix = body[:m.start()]
        tail = _IDENT_PATH_TAIL_RE.search(prefix)
        if not tail:
            continue
        path = tail.group(1)
        base = path.split(".")[0]
        # Depouille l'indexation tableau de la base : `instCauses[0].Active` -> `instCauses`
        # (un tableau declare est l'identifiant de base legal, pas son index).
        base = re.sub(r"\s*\[.*$", "", base)
        if base.upper() in _ST_RESERVED_LHS:
            continue
        targets.append(base)
    return targets


def check_fb_encapsulation(source_path):
    """Analyse un seul fichier .st. Retourne None si ce n'est pas un FUNCTION_BLOCK (DUT/ENUM,
    hors perimetre de ce controle) ou si le fichier est illisible. Sinon, un dict TOUJOURS
    rempli (meme sans violation) :
    {file, fb_name, n_input, n_output, n_inout, n_local,
     external_writes: [...], gvl_refs: [...], has_violation: bool}."""
    try:
        raw = pathlib.Path(source_path).read_text(encoding="utf-8")
    except OSError:
        return None

    text = _strip_comments(raw)
    fb_match = _FB_NAME_RE.search(text)
    if not fb_match:
        return None
    fb_name = fb_match.group(1)

    declared = _declared_names_by_kind(text)
    body = _executable_body(text)

    external_writes = sorted({t for t in _assignment_targets(body) if t not in declared})
    gvl_refs = sorted(set(_GVL_REF_RE.findall(body)))

    counts = {"input": 0, "output": 0, "inout": 0, "local": 0}
    for kind in declared.values():
        counts[kind] += 1

    return {
        "file": str(source_path), "fb_name": fb_name,
        "n_input": counts["input"], "n_output": counts["output"],
        "n_inout": counts["inout"], "n_local": counts["local"],
        "external_writes": external_writes, "gvl_refs": gvl_refs,
        "has_violation": bool(external_writes or gvl_refs),
    }


def check_encapsulation_chain(source_paths) -> list:
    """Applique check_fb_encapsulation a chaque fichier de la chaine `sources` d'une entree
    registry.yaml (deja dans l'ordre de compilation, donc les FB enfants sont inclus) --
    c'est la meme chaine que celle compilee/testee, aucune decouverte de dependance separee.
    Retourne UN dict par FUNCTION_BLOCK de la chaine (DUT/ENUM ignores), violation ou pas --
    au consommateur de filtrer sur `has_violation` s'il ne veut que les anomalies."""
    report = []
    for p in source_paths:
        result = check_fb_encapsulation(p)
        if result is not None:
            report.append(result)
    return report


def _format_line(entry: dict) -> str:
    status = "FAIL" if entry["has_violation"] else "PASS"
    line = (f"{status:9s} {entry['fb_name']:30s} IN={entry['n_input']:<3d} "
            f"OUT={entry['n_output']:<3d} IN_OUT={entry['n_inout']:<3d} "
            f"LOCAL={entry['n_local']:<3d} ({entry['file']})")
    return line


if __name__ == "__main__":
    import sys
    import yaml

    repo_root = pathlib.Path(__file__).resolve().parents[3]
    registry = yaml.safe_load((repo_root / "TOOLS/TEST_AUTO_CI/registry.yaml").read_text(encoding="utf-8"))

    target = sys.argv[1] if len(sys.argv) > 1 else None
    any_violation = False
    for fb_name, entry in registry.items():
        if target and fb_name != target:
            continue
        sources = [repo_root / s for s in entry["sources"]]
        chain = check_encapsulation_chain(sources)
        print(f"== {fb_name} ==")
        for e in chain:
            print(f"  {_format_line(e)}")
            if e["has_violation"]:
                any_violation = True
                for w in e["external_writes"]:
                    print(f"      ecriture externe non declaree : {w}")
                for g in e["gvl_refs"]:
                    print(f"      acces GVL direct (bypass interface) : {g}")
    sys.exit(1 if any_violation else 0)
