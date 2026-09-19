#!/usr/bin/env python3
"""Gate G408 : plafond de longueur des messages IHM (lisibilite operateur).

REX 2026-09-19 (troubleshooting PalierNot4Kobold) : en repli AX_STAB, le bandeau
affichait un pave de plus de 100 caracteres (« [CYCLE] Defaut a AX7 (recherche fond)
: palier 4 non confirme sur M1 ou M2 en recherche Kobold). Choisir Reprendre ou Ab »)
illisible sur l'IHM. La cause racine etait noyee dans le texte.

Ce gate verifie UNIQUEMENT la LISIBILITE : toute chaine destinee a l'operateur
(variables de message IHM ) ne doit pas depasser MAX_IHM caracteres.

Il ne remplace PAS :
  - G406 (litteral STRING > 80 -> taille de buffer CODESYS / avertissement C0198) ;
  - G407 (pire cas CONCAT vs STRING(N) cible -> troncature runtime).
G406/G407 protegent la MEMOIRE ; G408 protege la LECTURE par l'operateur.

Regle : tout litteral STRING '...' affecte a une cible de message IHM listee dans
IHM_TARGETS et de plus de MAX_IHM caracteres (defaut 70) est rejete. Une exception
justifiee se declare dans OUT_OF_SCOPE ("chemin:ligne" -> justification).

Usage:
    python G408_check_ihm_message_length.py [project_root]

Exit codes:
    0 = PASS / 1 = FAIL / 2 = USAGE ERROR
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Plafond de lisibilite d'un message operateur affiche sur une ligne de bandeau.
MAX_IHM = 70
# Plafond du MESSAGE ASSEMBLE (resultat d'une concatenation CONCAT) : un fragment court
# peut s'assembler en message illisible — c'est le RESULTAT que lit l'operateur.
MAX_IHM_MSG = 70

# Cibles portant un texte DESTINE a l'operateur (bandeau / actions / alarmes).
IHM_TARGETS: tuple[str, ...] = (
    "OperatorAction",
    "OperatorActionCandidate",
    "CycleStateStr",
    "SpecialConditionCandidate",
    "SequenceProgressText",
    "AbortMsgText",
    "AlarmArray",
)

# Exceptions explicites et BORNEES : "chemin:ligne" -> justification.
# Cle portable : chemin relatif en POSIX ( '/'), identique sous Windows et Linux.
OUT_OF_SCOPE: dict[str, str] = {
    "CODE/G_CYCLE/FB_CycleSemiAuto.st:1501": (
        "Branche 'reprise boot' de l'etape AX_STAB (M3 au-dela de P1) : texte volontairement "
        "explicite car ce chemin n'est PAS un defaut cycle. Revue expert 2026-09-19 : ne pas "
        "modifier cette branche dans le lot 'reporting defauts cycle'."
    ),
}

_TARGET_ASSIGN_RE = re.compile(
    r"(?<![A-Za-z0-9_])(?P<target>[A-Za-z_][A-Za-z0-9_]*)"
    r"(?:\s*\[[^\]]*\])?\s*:="
)


def _strip_comments(text: str) -> str:
    """Remplace commentaires (* ... *) et // par des espaces (conserve les lignes)."""
    out: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        if text.startswith("(*", i):
            end = text.find("*)", i + 2)
            if end == -1:
                out.append(" " * (n - i))
                break
            chunk = text[i:end + 2]
            out.append("".join("\n" if ch == "\n" else " " for ch in chunk))
            i = end + 2
            continue
        if text.startswith("//", i):
            end = text.find("\n", i + 2)
            if end == -1:
                out.append(" " * (n - i))
                break
            out.append(" " * (end - i))
            i = end
            continue
        out.append(text[i])
        i += 1
    return "".join(out)


def _literals(expr: str) -> list[tuple[int, str]]:
    """Extrait les litteraux '...' d'une expression, avec leur offset dans l'expression."""
    found: list[tuple[int, str]] = []
    j = 0
    while j < len(expr):
        if expr[j] == "'":
            k = j + 1
            buf: list[str] = []
            while k < len(expr):
                if expr[k] == "'":
                    if k + 1 < len(expr) and expr[k + 1] == "'":
                        buf.append("'")
                        k += 2
                        continue
                    break
                buf.append(expr[k])
                k += 1
            found.append((j, "".join(buf)))
            j = k + 1
            continue
        j += 1
    return found


# Identifiant NON QUALIFIE affecte ( `X := ...` mais pas `A.B.X := ...` ) : seule forme ou le
# nom designe sans ambiguite la source locale. Les relais qualifies (ex. GVL_IHM...CycleStateStr
# dans PRG_07) sont un AUTRE symbole et ne doivent pas rendre le nom local "multi-fichiers".
_ASSIGN_RE = re.compile(r"(?<![A-Za-z0-9_.])(?P<name>[A-Za-z_]\w*)\s*:=")


def _find_matching_paren(text: str, open_idx: int) -> int:
    depth = 0
    in_str = False
    i = open_idx
    n = len(text)
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
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def _split_args(inner: str) -> list[str]:
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
        elif c == "(":
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


def _depths(text: str) -> list[int]:
    """Profondeur de parentheses a chaque index (chaines '...' ignorees)."""
    depth = 0
    in_str = False
    out = [0] * len(text)
    i, n = 0, len(text)
    while i < n:
        out[i] = depth
        c = text[i]
        if in_str:
            if c == "'":
                if i + 1 < n and text[i + 1] == "'":
                    out[i + 1] = depth
                    i += 2
                    continue
                in_str = False
            i += 1
            continue
        if c == "'":
            in_str = True
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
        i += 1
    return out


def _expr_until(text: str, start: int) -> str:
    """Expression affectee : s'arrete au ';' de fin d'instruction ou a la ',' qui termine
    un argument nomme d'appel de FB, en ignorant les separateurs imbriques."""
    depth = 0
    in_str = False
    i, n = start, len(text)
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
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
        elif depth <= 0 and (c == ";" or c == ","):
            break
        i += 1
    return text[start:i]


def _assignments(text: str) -> dict[str, list[str]]:
    """Ident -> expressions qui lui sont affectees dans tout le fichier.

    Ne retient que les AFFECTATIONS D'ETAT (profondeur de parentheses 0) : les arguments
    nommes d'un appel de FB (`Cible := Source,` a l'interieur de la liste d'arguments)
    ne sont pas des affectations et ne doivent pas creer un faux second proprietaire
    d'un identifiant interne a un POU.
    """
    depths = _depths(text)
    out: dict[str, list[str]] = {}
    for m in _ASSIGN_RE.finditer(text):
        if depths[m.start()] != 0:
            continue
        out.setdefault(m.group("name"), []).append(_expr_until(text, m.end()))
    return out


class _WorstLen:
    """Longueur PIRE CAS resolue d'une expression ST (litteraux + identifiants assignes).

    Resolution LOCALE (fichier courant) puis INTER-FICHIERS, mais uniquement pour les
    identifiants assignes dans UN SEUL fichier du projet : c'est le seul cas ou la source
    est non ambigue. Un nom assigne dans plusieurs fichiers (homonymes entre POU) reste
    NON resolu -> WARN, jamais une estimation hasardeuse.
    """

    def __init__(
        self,
        assign_map: dict[str, list[str]],
        global_unique: dict[str, list[str]] | None = None,
    ):
        self.assign_map = assign_map
        self.global_unique = global_unique or {}
        self.memo: dict[str, int] = {}
        self.unknown = False

    def expr(self, e: str, depth: int = 0) -> int:
        e = e.strip()
        if not e:
            return 0
        m = re.fullmatch(r"'((?:[^']|'')*)'", e)
        if m:
            return len(m.group(1).replace("''", "'"))
        m = re.fullmatch(r"[A-Za-z_]\w*", e)
        if m:
            return self.ident(m.group(0), depth)
        m = re.fullmatch(r"CONCAT\s*\((.*)\)", e, re.DOTALL)
        if m:
            return sum(self.expr(a, depth) for a in _split_args(m.group(1)))
        self.unknown = True
        return 0

    def ident(self, name: str, depth: int = 0) -> int:
        if name in self.assign_map:
            exprs = self.assign_map[name]
        elif name in self.global_unique:
            exprs = self.global_unique[name]
        else:
            # Source non univoque (ou absente) : longueur NON prouvable -> jamais comptee
            # 0 en silence, signalee (WARN, pas FAIL).
            self.unknown = True
            return 0
        if depth > 4:
            self.unknown = True
            return 0
        if name in self.memo:
            return self.memo[name]
        self.memo[name] = 0  # garde anti-recursion
        best = 0
        for e in exprs:
            best = max(best, self.expr(e, depth + 1))
        self.memo[name] = best
        return best


def main() -> int:
    args = sys.argv[1:]
    root = Path(args[0]).resolve() if args else Path.cwd()
    code_dir = root / "CODE"
    if not code_dir.is_dir():
        print(f"ERROR: dossier CODE introuvable : {code_dir}", file=sys.stderr)
        return 2

    violations: list[tuple[str, int, int, str]] = []
    warns: list[tuple[str, int, int, str]] = []
    # ── Passe 1 : charger les sources et indexer les identifiants par fichier.
    # Un identifiant assigne dans UN SEUL fichier est resolu globalement (ex. CycleStateStr,
    # produit par le cycle et consomme par le bandeau). Un homonyme inter-POU n'est jamais
    # resolu (longueur non prouvable) : pas d'estimation hasardeuse.
    loaded: list[tuple[str, str, dict[str, list[str]]]] = []
    owners: dict[str, set[str]] = {}
    for st_file in sorted(code_dir.rglob("*.st")):
        raw = st_file.read_text(encoding="utf-8")
        clean = _strip_comments(raw)
        rel = st_file.relative_to(root).as_posix()
        am = _assignments(clean)
        loaded.append((clean, rel, am))
        for name in am:
            owners.setdefault(name, set()).add(rel)
    global_unique: dict[str, list[str]] = {}
    for _clean, _rel, am in loaded:
        for name, exprs in am.items():
            if len(owners[name]) == 1:
                global_unique[name] = exprs

    # ── Passe 2 : verifications.
    for clean, rel, assign_map in loaded:
        # Toute affectation a une cible IHM, OU QU'ELLE SOIT (y compris sous IF/ELSIF/CASE).
        # Le parseur precedent n'attrapait que les instructions en tete de fragment ';' et
        # laissait echapper les branches (faux negatifs, revue expert 2026-09-19).
        for match in _TARGET_ASSIGN_RE.finditer(clean):
            if match.group("target") not in IHM_TARGETS:
                continue
            expr_start = match.end()
            stmt_end = clean.find(";", expr_start)
            expr = clean[expr_start:] if stmt_end == -1 else clean[expr_start:stmt_end]
            for lit_offset, lit in _literals(expr):
                if len(lit) <= MAX_IHM:
                    continue
                lit_line = clean.count("\n", 0, expr_start + lit_offset) + 1
                key = f"{rel}:{lit_line}"
                if key in OUT_OF_SCOPE:
                    continue
                violations.append((rel, lit_line, len(lit), lit[:60]))

        # ── Message ASSEMBLE : le plafond de lisibilite porte sur le RESULTAT de la
        # concatenation, pas sur les fragments — des fragments courts peuvent s'assembler
        # en un message illisible. Resolution recursive (litteraux + identifiants assignes,
        # y compris les intermediaires construits par CONCAT).
        for m in re.finditer(r"(?<![A-Za-z0-9_])(\w+)\s*:=\s*CONCAT\s*\(", clean):
            name = m.group(1)
            if name not in IHM_TARGETS:
                continue
            open_idx = clean.index("(", m.end() - 1)
            close_idx = _find_matching_paren(clean, open_idx)
            if close_idx == -1:
                continue
            expr = clean[m.end() - 7: close_idx + 1]
            ev = _WorstLen(assign_map, global_unique)
            worst = ev.expr(expr)
            line_no = clean.count("\n", 0, m.start()) + 1
            key = f"{rel}:{line_no}"
            if key in OUT_OF_SCOPE:
                continue
            if worst > MAX_IHM_MSG:
                violations.append((rel, line_no, worst, f"CONCAT {name} : message assemble"))
            elif ev.unknown:
                warns.append((rel, line_no, worst, f"CONCAT {name} : fragment non resolu"))

    if warns:
        print(
            f"INFO : {len(warns)} message(s) IHM a fragment non resolu "
            "(pire cas connu sous le plafond, verification manuelle recommandee) :"
        )
        for path, line, length, snippet in warns:
            print(f"  - {path}:{line} ({length} car. connus) -> {snippet}")

    if not violations:
        print(
            f"PASS : aucun message IHM > {MAX_IHM} caracteres (litteral) et > {MAX_IHM_MSG} "
            f"caracteres (message assemble) "
            f"(cibles : {', '.join(IHM_TARGETS)})."
        )
        return 0

    print(
        f"FAIL : {len(violations)} message(s) IHM trop long(s) "
        f"(litteral > {MAX_IHM} ou message assemble > {MAX_IHM_MSG}) :"
    )
    for path, line, length, snippet in violations:
        print(f"  - {path}:{line} ({length} car.) -> {snippet}")
    print(
        f"\nCause : message operateur trop long (illisible sur une ligne de bandeau). "
        f"Contracter le texte sous {MAX_IHM_MSG} caracteres ASSEMBLES (le plafond porte sur le "
        "resultat de la concatenation, pas sur les fragments), ou declarer une exception "
        "justifiee dans OUT_OF_SCOPE du gate."
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
