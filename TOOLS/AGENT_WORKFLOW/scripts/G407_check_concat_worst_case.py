#!/usr/bin/env python3
"""Gate: detecte les depassements de STRING(N) par concatenation CONCAT(...) calculee.

REX 2026-09-19 : FB_Hmi_BannerFormatter.st construisait un message operateur par
CONCAT(litteral, CONCAT(variable, CONCAT(litteral, ...))) dont chaque fragment
individuel passait sous les 80 caracteres (donc invisible pour G406, qui ne
verifie que les litteraux isoles), mais dont la SOMME pire cas depassait la
taille declaree du champ STRING(120) cible -> troncature silencieuse CODESYS,
message operateur coupe en plein mot sur l'IHM reelle.

Principe (par fichier .st, portee locale a la portee) :
  1. Indexer chaque IDENT declare `IDENT : STRING(N)` (ou STRING sans taille -> 80).
  2. Indexer, pour chaque IDENT, tous les litteraux STRING qui lui sont assignes
     directement (`IDENT := 'texte';`) n'importe ou dans le fichier (ex. les
     branches d'un CASE qui alimentent un buffer intermediaire).
  3. Pour chaque assignation `IDENT := <expr>;` ou `<expr>` contient un appel
     CONCAT(...) (eventuellement imbrique sur plusieurs lignes), evaluer la
     longueur PIRE CAS de l'expression :
       - litteral STRING -> sa longueur exacte
       - IDENT connu (declare) -> le max des litteraux qui lui sont assignes
         ailleurs dans le fichier (0 si aucun trouve : traite comme inconnu)
       - tout autre appel de fonction (WORD_TO_STRING, INT_TO_STRING, ...) ->
         longueur inconnue, ignoree du calcul mais signalee en WARN (pas de FAIL
         base sur une estimation non prouvee)
  4. Si la somme pire cas des fragments STRICTEMENT connus depasse la taille
     declaree de l'IDENT cible -> FAIL.

Limite assumee : seuls les fragments resolus avec certitude (litteraux, ou
identifiants dont TOUTES les sources sont des litteraux) comptent dans le total.
Un total qui echoue est donc une preuve ferme de depassement ; un total qui
passe avec des fragments inconnus reste a verifier manuellement (imprime en
WARN, jamais un FAIL).

Usage:
    python G407_check_concat_worst_case.py [project_root]

Exit codes:
    0 = PASS (aucun depassement prouve)
    1 = FAIL (au moins une concatenation depasse la taille declaree)
    2 = USAGE ERROR
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

DEFAULT_STRING_LEN = 80

DECL_RE = re.compile(
    r"^\s*(\w+)\s*:\s*STRING(?:\((\d+)\))?\s*(?::=.*)?;", re.MULTILINE
)
# IDENT := 'litteral' ;  (litteral simple, pas de CONCAT)
SIMPLE_LITERAL_ASSIGN_RE = re.compile(
    r"(\w+)\s*:=\s*'((?:[^']|'')*)'\s*;"
)


def _strip_comments(text: str) -> str:
    out = []
    i, n = 0, len(text)
    while i < n:
        if text.startswith("(*", i):
            end = text.find("*)", i + 2)
            if end == -1:
                break
            out.append(" " * (end + 2 - i))
            i = end + 2
            continue
        if text.startswith("//", i):
            end = text.find("\n", i)
            if end == -1:
                break
            out.append(" " * (end - i))
            i = end
            continue
        out.append(text[i])
        i += 1
    return "".join(out)


def _unescape(lit: str) -> str:
    return lit.replace("''", "'")


def _find_matching_paren(text: str, open_idx: int) -> int:
    depth = 0
    i = open_idx
    n = len(text)
    in_str = False
    while i < n:
        c = text[i]
        if in_str:
            if c == "'":
                if i + 1 < n and text[i + 1] == "'":
                    i += 2
                    continue
                in_str = False
            i += 1
            continue
        if c == "'":
            in_str = True
            i += 1
            continue
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def _split_top_level_args(inner: str) -> list[str]:
    args: list[str] = []
    depth = 0
    buf: list[str] = []
    in_str = False
    i, n = 0, len(inner)
    while i < n:
        c = inner[i]
        if in_str:
            buf.append(c)
            if c == "'":
                if i + 1 < n and inner[i + 1] == "'":
                    buf.append(inner[i + 1])
                    i += 2
                    continue
                in_str = False
            i += 1
            continue
        if c == "'":
            in_str = True
            buf.append(c)
            i += 1
            continue
        if c == "(":
            depth += 1
            buf.append(c)
        elif c == ")":
            depth -= 1
            buf.append(c)
        elif c == "," and depth == 0:
            args.append("".join(buf))
            buf = []
        else:
            buf.append(c)
        i += 1
    if buf:
        args.append("".join(buf))
    return args


class _Eval:
    def __init__(self, literal_max: dict[str, int]):
        self.literal_max = literal_max
        self.unknown = False

    def worst_len(self, expr: str) -> int:
        expr = expr.strip()
        m = re.fullmatch(r"'((?:[^']|'')*)'", expr)
        if m:
            return len(_unescape(m.group(1)))
        m = re.fullmatch(r"CONCAT\s*\((.*)\)", expr, re.DOTALL)
        if m:
            args = _split_top_level_args(m.group(1))
            return sum(self.worst_len(a) for a in args)
        m = re.fullmatch(r"(\w+)", expr)
        if m:
            ident = m.group(1)
            if ident in self.literal_max:
                return self.literal_max[ident]
            self.unknown = True
            return 0
        # Autre appel de fonction (WORD_TO_STRING, INT_TO_STRING, TIME_TO_STRING...)
        self.unknown = True
        return 0


def _scan_file(path: Path, root: Path) -> list[str]:
    raw = path.read_text(encoding="utf-8")
    text = _strip_comments(raw)

    declared: dict[str, int] = {}
    for m in DECL_RE.finditer(text):
        ident, size = m.group(1), m.group(2)
        declared[ident] = int(size) if size else DEFAULT_STRING_LEN

    literal_max: dict[str, int] = {}
    for m in SIMPLE_LITERAL_ASSIGN_RE.finditer(text):
        ident, lit = m.group(1), m.group(2)
        length = len(_unescape(lit))
        literal_max[ident] = max(literal_max.get(ident, 0), length)

    rel = str(path.relative_to(root))
    findings: list[str] = []

    for m in re.finditer(r"(\w+)\s*:=\s*CONCAT\s*\(", text):
        ident = m.group(1)
        if ident not in declared:
            continue
        open_idx = text.index("(", m.end() - 1)
        close_idx = _find_matching_paren(text, open_idx)
        if close_idx == -1:
            continue
        expr = text[m.end() - 7 : close_idx + 1]  # inclut "CONCAT(...)"
        line_no = text.count("\n", 0, m.start()) + 1
        ev = _Eval(literal_max)
        worst = ev.worst_len(expr)
        limit = declared[ident]
        if worst > limit:
            findings.append(
                f"  - {rel}:{line_no} FAIL {ident} (STRING({limit})) : "
                f"pire cas connu {worst} caracteres > {limit}"
            )
        elif ev.unknown:
            findings.append(
                f"  - {rel}:{line_no} WARN {ident} (STRING({limit})) : "
                f"pire cas connu {worst}/{limit}, fragment(s) non resolu(s) "
                "(identifiant sans source litteraire ou fonction de conversion) "
                "-- verification manuelle recommandee"
            )
    return findings


def main() -> int:
    args = sys.argv[1:]
    root = Path(args[0]).resolve() if args else Path.cwd()
    code_dir = root / "CODE"
    if not code_dir.is_dir():
        print(f"ERROR: dossier CODE introuvable : {code_dir}", file=sys.stderr)
        return 2

    fails: list[str] = []
    warns: list[str] = []
    for st_file in sorted(code_dir.rglob("*.st")):
        try:
            findings = _scan_file(st_file, root)
        except UnicodeDecodeError:
            print(f"ERROR: {st_file} n'est pas en UTF-8 lisible", file=sys.stderr)
            return 2
        for line in findings:
            (fails if " FAIL " in line else warns).append(line)

    if warns:
        print(f"INFO : {len(warns)} concatenation(s) avec fragment(s) non resolu(s) (a verifier manuellement) :")
        for line in warns:
            print(line)

    if not fails:
        print("PASS : aucune concatenation CONCAT(...) ne depasse prouvablement sa taille STRING(N) cible.")
        return 0

    print(f"FAIL : {len(fails)} concatenation(s) depassant prouvablement leur STRING(N) cible :")
    for line in fails:
        print(line)
    print(
        "\nCause : la somme pire cas des fragments CONCAT(...) depasse la taille "
        "STRING(N) declaree du champ cible -> troncature silencieuse a l'affectation "
        "(CODESYS coupe sans avertissement au-dela de la taille declaree). "
        "Raccourcir les fragments litteraux/variables impliques, ou agrandir le "
        "STRING(N) cible si le champ IHM en aval le permet (verifier AF_Partie-07)."
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
