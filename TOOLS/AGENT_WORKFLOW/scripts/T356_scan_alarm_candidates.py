#!/usr/bin/env python3
"""T356 — inventaire MECANIQUE des candidats defaut/alarme du projet.

Pourquoi ce script (et pas une lecture manuelle) :
    une lecture seule ne garantit PAS l'exhaustivite sur 262 fichiers `.st`.
    Ce script produit l'UNIVERS DE DEPART par pattern de nommage, sans jugement :
    zero faux negatif sur les patterns retenus, zero verdict metier.

Il n'est PAS un gate : aucun exit code bloquant, pas de branchement dans
`run_all_gates.py` (audit ponctuel T356, cf. brief). Il est REUTILISABLE apres
correctifs : relancer et comparer les CSV.

CE QU'IL EXTRAIT (5 etages independants) :
  1. `declarations` — toute declaration `<Nom> : <Type>;` dont le nom matche un
     pattern candidat (tier 1 = vocabulaire du brief, tier 2 = elargissement
     assume faute de vocabulaire alarme dans NAMING_CONVENTION.md).
  2. `causes` — les causes elementaires reelles des producteurs
     (`instCauses[i].Texte := '...'`) + la ligne d'ecriture `instCauses[i].Active :=`
     (c'est LA ou le bit est reellement mis a TRUE) + `Latching`.
  3. `bandeau` — chaque affectation `AlarmArray[...] := '<libelle>'` du carrousel
     avec sa ligne et sa condition englobante (garde).
  4. `aggregation` — les termes reels de `GVL_IHM.Modes.State.AnyFaultActive`.
  5. `references` — pour CHAQUE nom candidat, toutes ses occurrences dans CODE/
     avec role (ECRITURE_TRUE / ECRITURE / LECTURE) et nom de fichier.

Sorties (CSV + JSON) dans le dossier passe en argument.

Usage :
    python T356_scan_alarm_candidates.py [racine_projet] [--out DOSSIER]
    python T356_scan_alarm_candidates.py . --out DOC/WFLOW/AUDITS/T356_ALARMES_20260921

Aucune ecriture hors du dossier `--out`, aucun CODE/ modifie, aucun exit code
non nul hors erreur d'usage (1) ou fichier manquant (2).
"""

from __future__ import annotations

import csv
import json
import re
import sys
from pathlib import Path

# ── Patterns candidats ────────────────────────────────────────────────────────
# Tier 1 = vocabulaire EXACT du brief T356 (insensible a la casse).
TIER1 = ("Fault", "Defect", "Alarm", "Warning", "Error", "Diag", "Failure", "Trip")
# Tier 2 = elargissement, motive par l'absence de vocabulaire alarme dans
# NAMING_CONVENTION.md (constat T356). Signale comme tel dans le CSV.
TIER2 = (
    "Defaut", "Anomal", "Incident", "Violation", "Invalid", "Saturated",
    "OutOfRange", "Reject", "Latched", "BlockReason", "Reserve",
)
CANDIDATE_RE = re.compile("|".join(TIER1 + TIER2), re.IGNORECASE)

# Declaration simple : `<Nom> : <Type>;` (le nom peut matcher, on ne juge pas le type).
DECL_RE = re.compile(r"^\s*(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*:\s*(?P<type>[^;()]+);")
BLOCK_RE = re.compile(
    r"^\s*(?P<kw>VAR_INPUT|VAR_OUTPUT|VAR_IN_OUT|VAR_GLOBAL|VAR_TEMP|VAR_CONFIG|"
    r"VAR_CONSTANT|VAR CONSTANT|VAR)\b"
)
STRUCT_RE = re.compile(r"^\s*(?P<kind>TYPE|STRUCT|END_STRUCT|END_TYPE|FUNCTION_BLOCK|FUNCTION|PROGRAM)\b")
TYPE_OF_POU_RE = re.compile(
    r"^\s*(?:PUBLIC\s+)?(FUNCTION_BLOCK|FUNCTION|PROGRAM)\s+(?:PUBLIC\s+)?(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
)

# Champs de cause : expression MULTI-LIGNES (les producteurs coupent l'expression
# sur plusieurs lignes, cf. FB_CycleSemiAuto.st:446-450 ou FB_Safety_Winch.st:319).
CAUSE_FIELD_RE = re.compile(
    r"instCauses\[(?P<idx>\d+)\]\.(?P<field>Active|Latching|Texte)\s*:=\s*(?P<expr>.*?);",
    re.DOTALL,
)
# Ecriture d'un latch/booleen a TRUE (origine amont reelle d'une cause).
TRUE_WRITE_RE = re.compile(r"^\s*(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*:=\s*TRUE\s*;", re.MULTILINE)
IDENT_RE = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\b")

# Index de cause SYMBOLIQUE : `instCauses[CST_CauseXxx]` (FB_CycleMachineHoming).
CAUSE_SYM_RE = re.compile(r"instCauses\[(?P<const>[A-Za-z_][A-Za-z0-9_]*)\]")
CONST_INT_RE = re.compile(r"^\s*(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*:\s*(?:INT|WORD|DINT)\s*:=\s*(?P<val>\d+)\s*;", re.MULTILINE)

# Ecriture AD HOC d'un bit de ErrorId : `X.ErrorId := X.ErrorId OR 16#0010;` (FB_Diag_*,
# FB_Acquisition_Preflight) — chemin de production distinct de FB_FaultCore.
ERRORID_BIT_RE = re.compile(
    r"(?P<target>[A-Za-z_][A-Za-z0-9_.]*ErrorId)\s*:=\s*(?P<expr>[^;]*16#[0-9A-Fa-f]{2,4}[^;]*);"
)
ERRORID_MASK_RE = re.compile(r"(?P<op>OR|AND|=)\s*16#(?P<mask>[0-9A-Fa-f]{2,4})")

ALARM_ASSIGN_RE = re.compile(r"(?P<target>AlarmArray|Banner\.AlarmBanner\.AlarmArray)\[(?P<idx>[^\]]*)\]\s*:=\s*(?P<val>.+?);")
AGG_TARGET = "GVL_IHM.Modes.State.AnyFaultActive"


# ── Utilitaires texte ────────────────────────────────────────────────────────
def strip_comments(text: str) -> str:
    """Remplace le contenu des commentaires par des espaces (numeros de ligne conserves)."""
    out: list[str] = []
    i, n = 0, len(text)
    while i < n:
        if text.startswith("(*", i):
            end = text.find("*)", i + 2)
            if end == -1:
                out.append("".join("\n" if ch == "\n" else " " for ch in text[i:]))
                break
            out.append("".join("\n" if ch == "\n" else " " for ch in text[i:end + 2]))
            i = end + 2
            continue
        if text.startswith("//", i):
            end = text.find("\n", i + 2)
            if end == -1:
                break
            i = end
            continue
        out.append(text[i])
        i += 1
    return "".join(out)


def st_files(root: Path) -> list[Path]:
    code = root / "CODE"
    files = sorted(p for p in code.rglob("*.st") if p.is_file())
    return files


def rel(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def tier_of(name: str) -> str:
    name_l = name.lower()
    for kw in TIER1:
        if kw.lower() in name_l:
            return "T1(brief)"
    for kw in TIER2:
        if kw.lower() in name_l:
            return "T2(elargi)"
    return "?"


# ── Etage 1 : declarations candidates ───────────────────────────────────────
def scan_declarations(root: Path, files: list[Path], cleaned: dict[str, str]) -> list[dict]:
    rows: list[dict] = []
    for path in files:
        text = cleaned[rel(root, path)]
        block = ""
        struct_ctx = ""
        pou = ""
        for lineno, line in enumerate(text.splitlines(), start=1):
            m_pou = TYPE_OF_POU_RE.match(line)
            if m_pou:
                pou = m_pou.group("name")
            m_kind = STRUCT_RE.match(line)
            if m_kind:
                kind = m_kind.group("kind")
                if kind == "TYPE":
                    struct_ctx = "TYPE"
                elif kind == "STRUCT":
                    struct_ctx = struct_ctx or "STRUCT"
                elif kind in ("END_STRUCT", "END_TYPE"):
                    struct_ctx = ""
            m_block = BLOCK_RE.match(line)
            if m_block:
                block = m_block.group("kw")
                continue
            if re.match(r"^\s*END_VAR\b", line):
                block = ""
                continue
            m = DECL_RE.match(line)
            if not m:
                continue
            name = m.group("name")
            if not CANDIDATE_RE.search(name):
                continue
            rows.append({
                "nom": name,
                "tier": tier_of(name),
                "type": m.group("type").strip(),
                "fichier": rel(root, path),
                "ligne": lineno,
                "bloc": block or ("STRUCT" if struct_ctx else "?"),
                "pou": pou,
                "declaration": line.strip(),
            })
    return rows


# ── Etage 2 : causes reelles des producteurs ────────────────────────────────
def scan_causes(root: Path, files: list[Path], cleaned: dict[str, str]) -> list[dict]:
    rows: list[dict] = []
    for path in files:
        frel = rel(root, path)
        text = cleaned[frel]
        pou = ""
        for line in text.splitlines():
            m_pou = TYPE_OF_POU_RE.match(line)
            if m_pou:
                pou = m_pou.group("name")
                break

        # Resolution des index SYMBOLIQUES (instCauses[CST_CauseXxx] := n) : sans cela
        # 7 causes de FB_CycleMachineHoming sont invisibles (trou de couverture mesure T356).
        consts = {m.group("name"): m.group("val") for m in CONST_INT_RE.finditer(text)}
        sym_seen: dict[int, str] = {}
        for m in CAUSE_SYM_RE.finditer(text):
            sym = m.group("const")
            if sym in consts:
                sym_seen[int(consts[sym])] = sym
        if sym_seen:
            def _sub(m: "re.Match[str]") -> str:
                sym = m.group("const")
                return f"instCauses[{consts[sym]}]" if sym in consts else m.group(0)
            text = CAUSE_SYM_RE.sub(_sub, text)

        texts: dict[int, tuple[str, int]] = {}
        actives: dict[int, list[tuple[int, str]]] = {}
        latch: dict[int, list[tuple[int, str]]] = {}
        for m in CAUSE_FIELD_RE.finditer(text):
            idx = int(m.group("idx"))
            field = m.group("field")
            expr = " ".join(m.group("expr").split())
            lineno = text.count("\n", 0, m.start()) + 1
            if field == "Texte":
                texts[idx] = (m.group("expr").strip().strip("'"), lineno)
            elif field == "Active":
                actives.setdefault(idx, []).append((lineno, expr))
            else:
                latch.setdefault(idx, []).append((lineno, expr))

        # Latch/booleen ecrit a TRUE dans ce fichier : origine amont d'une cause.
        true_writes: dict[str, int] = {}
        for m in TRUE_WRITE_RE.finditer(text):
            name = m.group("name")
            true_writes.setdefault(name, text.count("\n", 0, m.start()) + 1)

        for idx in sorted(set(texts) | set(actives)):
            texte, l_texte = texts.get(idx, ("<absent>", 0))
            assigns = actives.get(idx, [])
            expr_join = " | ".join(f"L{l}:{e}" for l, e in assigns) if assigns else "<absent>"
            first_line = assigns[0][0] if assigns else 0
            lat_join = " | ".join(f"L{l}:{v}" for l, v in latch.get(idx, [])) or "<absent>"
            # Amont : identifiants de l'expression qui sont ecrits a TRUE dans le fichier.
            amont: list[str] = []
            if assigns:
                for name in dict.fromkeys(IDENT_RE.findall(" ".join(e for _l, e in assigns))):
                    if name in true_writes:
                        amont.append(f"{name} ({frel}:{true_writes[name]})")
            rows.append({
                "producteur": pou or frel,
                "fichier": frel,
                "bit": idx,
                "masque_hex": f"16#{1 << idx:04X}",
                "texte_cause": texte,
                "ligne_texte": l_texte,
                "expr_active": expr_join,
                "ligne_ecriture_bit": first_line,
                "latching": lat_join,
                "amont_ecrit_true": " ; ".join(amont) if amont else "",
                "index_symbolique": sym_seen.get(idx, ""),
            })
    return rows


# ── Etage 6 : ecritures AD HOC de bits de ErrorId (hors FB_FaultCore) ───────
def scan_errorid_bits(root: Path, files: list[Path], cleaned: dict[str, str]) -> list[dict]:
    rows: list[dict] = []
    for path in files:
        frel = rel(root, path)
        pou = ""
        for line in cleaned[frel].splitlines():
            m_pou = TYPE_OF_POU_RE.match(line)
            if m_pou:
                pou = m_pou.group("name")
                break
        for m in ERRORID_BIT_RE.finditer(cleaned[frel]):
            expr = " ".join(m.group("expr").split())
            lineno = cleaned[frel].count("\n", 0, m.start()) + 1
            for bit_m in ERRORID_MASK_RE.finditer(expr):
                mask = bit_m.group("mask").upper()
                rows.append({
                    "producteur": pou,
                    "fichier": frel,
                    "ligne": lineno,
                    "cible": m.group("target"),
                    "operation": {"OR": "SET", "AND": "CLEAR", "=": "ASSIGN"}[bit_m.group("op")],
                    "masque_hex": f"16#{mask}",
                    "expression": expr[:180],
                })
    return rows


# ── Etage 3 : libelles du carrousel ─────────────────────────────────────────
def _enclosing_conditions(text: str) -> dict[int, str]:
    """Pour chaque ligne, la derniere condition d'ouverture de bloc vue (best effort)."""
    conds: dict[int, str] = {}
    cond = ""
    pending = ""
    for lineno, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if pending:
            pending = f"{pending} {stripped}"
            if re.search(r"\bTHEN\b", pending, re.IGNORECASE):
                cond = pending
                pending = ""
            conds[lineno] = cond
            continue
        m_open = re.match(r"^\s*(?:IF|ELSIF|WHILE|FOR|CASE)\b(?P<cond>.*)$", line)
        if m_open:
            body = m_open.group("cond")
            if re.search(r"\bTHEN\b", body, re.IGNORECASE) or re.search(r"\bOF\b", body):
                cond = body.strip()
            else:
                pending = body.strip()
            conds[lineno] = cond
            continue
        conds[lineno] = cond
    return conds


def scan_banner(root: Path, cleaned: dict[str, str], banner_rel: str) -> list[dict]:
    rows: list[dict] = []
    for frel, text in cleaned.items():
        if not frel.endswith(".st"):
            continue
        has_assign = any(ALARM_ASSIGN_RE.search(l) for l in text.splitlines())
        if not has_assign:
            continue
        conds = _enclosing_conditions(text)
        for lineno, line in enumerate(text.splitlines(), start=1):
            m = ALARM_ASSIGN_RE.search(line)
            if not m:
                continue
            rows.append({
                "fichier": frel,
                "ligne": lineno,
                "index": m.group("idx"),
                "libelle": m.group("val").strip(),
                "garde": conds.get(lineno, ""),
                "est_formateur": "oui" if frel == banner_rel else "non",
            })
    return rows


# ── Etage 4 : agregation AnyFaultActive ─────────────────────────────────────
def scan_aggregation(root: Path, cleaned: dict[str, str], target_file: str) -> list[dict]:
    rows: list[dict] = []
    for frel, text in cleaned.items():
        if frel != target_file:
            continue
        for lineno, line in enumerate(text.splitlines(), start=1):
            if AGG_TARGET not in line:
                continue
            # recuperer l'expression complete jusqu'au ';'
            buf = line
            j = lineno
            while ";" not in buf and j < len(text.splitlines()):
                j += 1
                buf += " " + text.splitlines()[j - 1]
            expr = buf.split(":=", 1)[1] if ":=" in buf else buf
            expr = expr.split(";", 1)[0]
            for term in re.split(r"\bOR\b", expr):
                term = term.strip()
                if term:
                    rows.append({"terme": term, "fichier": frel, "ligne": lineno})
    return rows


# ── Etage 5 : references de chaque candidat ─────────────────────────────────
WRITE_TRUE_RE = re.compile(r"^(?:\s*)(?P<rest>.*)$")


def role_of(after: str) -> str:
    """Role d'une occurrence a partir du texte qui suit le nom sur sa ligne."""
    a = after.lstrip()
    if a.startswith(":="):
        rhs = a[2:].strip()
        if re.match(r"^TRUE\b", rhs, re.IGNORECASE):
            return "ECRITURE_TRUE"
        if re.match(r"^FALSE\b", rhs, re.IGNORECASE):
            return "ECRITURE_FALSE"
        return "ECRITURE"
    if a.startswith("(") or a.startswith(".") or a.startswith(",") or a.startswith(")"):
        return "LECTURE"
    if a.startswith("="):
        return "ECRITURE"
    return "LECTURE"


def scan_references(root: Path, files: list[Path], cleaned: dict[str, str], names: set[str]) -> list[dict]:
    if not names:
        return []
    pattern = re.compile(r"\b(" + "|".join(sorted((re.escape(n) for n in names), key=len, reverse=True)) + r")\b")
    rows: list[dict] = []
    for path in files:
        frel = rel(root, path)
        text = cleaned[frel]
        for lineno, line in enumerate(text.splitlines(), start=1):
            for m in pattern.finditer(line):
                name = m.group(1)
                if name not in names:
                    continue
                after = line[m.end():]
                rows.append({
                    "nom": name,
                    "fichier": frel,
                    "ligne": lineno,
                    "role": role_of(after),
                    "contexte": line.strip()[:200],
                })
    return rows


# ── Etage 7 : classification de CHAQUE candidat brut (couverture 100%) ──────
TIMER_TYPES = ("TOF", "TON", "TP", "R_TRIG", "F_TRIG", "RS", "SR")
BRICK_NAMES = ("Fault", "Error", "ErrorId", "Latched", "LatchedId", "Faults", "Diag")


def classify(row: dict) -> str:
    name, typ, bloc, frel = row["nom"], row["type"], row["bloc"], row["fichier"]
    if frel.startswith("CODE/L_SIMULATION/"):
        return "BANC_SIMULATION"
    if typ.startswith("ST_Fault") or (name in BRICK_NAMES and typ.startswith("ST_")):
        return "BRIQUE_ST_FAULT"
    if typ in TIMER_TYPES:
        return "TIMER_ANTI_REBOND"
    if "STRING" in typ.upper():
        return "TEXTE_LIBELLE"
    if typ in ("WORD", "INT", "DINT", "BYTE") and CANDIDATE_RE.search(name):
        return "BITFIELD_OU_INDEX"
    if typ == "BOOL":
        if bloc.startswith("VAR_OUTPUT"):
            return "SORTIE_BOOL_PRODUCTEUR"
        if bloc.startswith("VAR_INPUT"):
            return "ENTREE_BOOL_CONSOMMATEUR"
        return "BOOL_INTERNE"
    return "AUTRE"


def scan_qualification(root: Path, declarations: list[dict], causes: list[dict],
                       errorid_bits: list[dict], banner: list[dict],
                       references: list[dict], aggregation: list[dict]) -> list[dict]:
    """Une ligne PAR candidat brut : nature + rattachement mecanique + preuves de trace."""
    refs_by_name: dict[str, list[dict]] = {}
    for ref in references:
        refs_by_name.setdefault(ref["nom"], []).append(ref)
    agg_text = " | ".join(a["terme"] for a in aggregation)
    banner_names = {b["fichier"] for b in banner}
    banner_guards = " | ".join(b["garde"] + " " + b["libelle"] for b in banner)
    cause_names = {c["texte_cause"] for c in causes if c["texte_cause"]}

    rows: list[dict] = []
    for decl in declarations:
        name = decl["nom"]
        refs = refs_by_name.get(name, [])
        writes_true = [f"{r['fichier']}:{r['ligne']}" for r in refs if r["role"] == "ECRITURE_TRUE"]
        writes = [f"{r['fichier']}:{r['ligne']}" for r in refs if r["role"].startswith("ECRITURE")]
        in_banner = [f"{r['fichier']}:{r['ligne']}" for r in refs if r["fichier"] in banner_names]
        in_prg07 = [f"{r['fichier']}:{r['ligne']}" for r in refs if r["fichier"].endswith("PRG_07_Supervision.st")]
        nature = classify(decl)
        # Rattachement mecanique (jamais un verdict metier) :
        if nature == "BRIQUE_ST_FAULT":
            trace = "brique ST_Fault : porteuse d'un bitfield, voir lignes de causes"
        elif writes_true:
            trace = f"ecrit TRUE en {writes_true[0]}"
        elif writes:
            trace = f"ecrit (jamais TRUE litteral) en {writes[0]}"
        elif refs:
            trace = f"seulement lu ({refs[0]['fichier']}:{refs[0]['ligne']})"
        else:
            trace = "AUCUNE reference hors declaration (candidat mort)"
        rows.append({
            "nom": name,
            "tier": decl["tier"],
            "nature": nature,
            "type": decl["type"],
            "bloc": decl["bloc"],
            "fichier": decl["fichier"],
            "ligne": decl["ligne"],
            "pou": decl["pou"],
            "nb_references": len(refs),
            "lignes_ecriture": " ; ".join(writes[:6]),
            "premier_ecrit_true": writes_true[0] if writes_true else "",
            "reference_dans_bandeau": " ; ".join(in_banner[:4]),
            "reference_dans_PRG_07": " ; ".join(in_prg07[:4]),
            "nom_cite_dans_agregation_anyfault": "oui" if name in agg_text else "non",
            "nom_cite_dans_gardes_bandeau": "oui" if name in banner_guards else "non",
            "texte_cause_associe": "oui" if name in cause_names else "non",
            "trace_mecanique": trace,
        })
    return rows


def main() -> int:
    args = sys.argv[1:]
    root = Path.cwd()
    out_dir = Path("DOC/WFLOW/AUDITS/T356_ALARMES_20260921")
    positional = [a for a in args if not a.startswith("--")]
    if positional:
        root = Path(positional[0]).resolve()
    if "--out" in args:
        out_dir = Path(args[args.index("--out") + 1])
    if not (root / "CODE").is_dir():
        print(f"ERROR: dossier CODE introuvable sous {root}", file=sys.stderr)
        return 2
    out_dir = (root / out_dir) if not out_dir.is_absolute() else out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    files = st_files(root)
    cleaned = {rel(root, p): strip_comments(p.read_text(encoding="utf-8", errors="replace")) for p in files}
    print(f"[T356] {len(files)} fichiers .st scannes sous CODE/")

    declarations = scan_declarations(root, files, cleaned)
    causes = scan_causes(root, files, cleaned)
    banner = scan_banner(root, cleaned, "CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st")
    aggregation = scan_aggregation(root, cleaned, "CODE/M_MAIN/PRG_07_Supervision.st")
    errorid_bits = scan_errorid_bits(root, files, cleaned)
    names = {row["nom"] for row in declarations}
    references = scan_references(root, files, cleaned, names)

    def dump(name: str, rows: list[dict], fields: list[str]) -> None:
        path = out_dir / name
        with path.open("w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(fh, fieldnames=fields)
            writer.writeheader()
            for row in rows:
                writer.writerow(row)
        print(f"[T356] {path.as_posix()} — {len(rows)} lignes")

    dump("T356_candidats_declarations.csv", declarations,
         ["nom", "tier", "type", "fichier", "ligne", "bloc", "pou", "declaration"])
    dump("T356_causes_producteurs.csv", causes,
         ["producteur", "fichier", "bit", "masque_hex", "texte_cause", "ligne_texte",
          "expr_active", "ligne_ecriture_bit", "latching", "amont_ecrit_true", "index_symbolique"])
    dump("T356_errorid_bits_ad_hoc.csv", errorid_bits,
         ["producteur", "fichier", "ligne", "cible", "operation", "masque_hex", "expression"])
    dump("T356_bandeau_libelles.csv", banner,
         ["fichier", "ligne", "index", "libelle", "garde", "est_formateur"])
    dump("T356_aggregation_anyfault.csv", aggregation, ["terme", "fichier", "ligne"])
    dump("T356_references.csv", references, ["nom", "fichier", "ligne", "role", "contexte"])

    qualification = scan_qualification(root, declarations, causes, errorid_bits,
                                       banner, references, aggregation)
    dump("T356_univers_complet.csv", qualification,
         ["nom", "tier", "nature", "type", "bloc", "fichier", "ligne", "pou",
          "nb_references", "lignes_ecriture", "premier_ecrit_true",
          "reference_dans_bandeau", "reference_dans_PRG_07",
          "nom_cite_dans_agregation_anyfault", "nom_cite_dans_gardes_bandeau",
          "texte_cause_associe", "trace_mecanique"])

    # ── Croisement mecanique : chaque cause a-t-elle un libelle carrousel ? ──
    labels_by_file: dict[str, list[dict]] = {}
    for row in banner:
        labels_by_file.setdefault(row["fichier"], []).append(row)

    def label_present(label: str, frel: str) -> tuple[str, str]:
        for row in labels_by_file.get(frel, []):
            if row["libelle"].strip("'") == label:
                return "oui", f"{frel}:{row['ligne']}"
        return "non", ""

    synth: dict = {
        "fichiers_st": len(files),
        "candidats_declarations": len(declarations),
        "candidats_par_tier": {},
        "causes_producteurs": len(causes),
        "causes_index_symbolique": sum(1 for c in causes if c["index_symbolique"]),
        "bits_errorid_ad_hoc": len(errorid_bits),
        "causes_texte_vide": sum(1 for c in causes if not c["texte_cause"]),
        "causes_texte_reserve": sum(1 for c in causes if "eserve" in c["texte_cause"]),
        "libelles_carrousel": len(banner),
        "libelles_formateur": sum(1 for b in banner if b["est_formateur"] == "oui"),
        "termes_aggregation": len(aggregation),
        "references_scannees": len(references),
        "causes_par_producteur": {},
    }
    for row in declarations:
        synth["candidats_par_tier"][row["tier"]] = synth["candidats_par_tier"].get(row["tier"], 0) + 1
    for row in causes:
        synth["causes_par_producteur"][row["producteur"]] = synth["causes_par_producteur"].get(row["producteur"], 0) + 1

    (out_dir / "T356_synthese_scan.json").write_text(
        json.dumps(synth, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"[T356] declarations={len(declarations)} causes={len(causes)} "
          f"libelles={len(banner)} termes_agreges={len(aggregation)} references={len(references)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
