# -*- coding: utf-8 -*-
"""Parsing ST minimal (lecture seule) pour l'inventaire troubleshooting."""
import re, sys
from pathlib import Path

REPO = Path(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage")
CODE = REPO / "CODE"
OUT = Path(r"C:\Users\ZEDVICTUS\.claude\jobs\ebe3ca88\tmp")

BASE_SIZE = {"BOOL": 1, "BYTE": 1, "SINT": 1, "USINT": 1, "INT": 2, "UINT": 2, "WORD": 2,
             "DINT": 4, "UDINT": 4, "DWORD": 4, "REAL": 4, "TIME": 4, "TOD": 4, "DATE": 4, "DT": 4,
             "LINT": 8, "ULINT": 8, "LWORD": 8, "LREAL": 8, "LTIME": 8}


def read(p):
    return Path(p).read_text(encoding="utf-8", errors="replace")


def blank_comments(text, keep_pragma=False):
    """Remplace commentaires par espaces en gardant les retours ligne (numeros de ligne stables)."""
    out = []
    i, n = 0, len(text)
    depth = 0
    in_str = False
    while i < n:
        c = text[i]
        if depth == 0 and not in_str and text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
            continue
        if not in_str and text.startswith("(*", i):
            depth += 1
            out.append("  ")
            i += 2
            continue
        if depth and text.startswith("*)", i):
            depth -= 1
            out.append("  ")
            i += 2
            continue
        if depth:
            out.append("\n" if c == "\n" else " ")
            i += 1
            continue
        if c == "'":
            in_str = not in_str
        out.append(c)
        i += 1
    return "".join(out)


FIELD = re.compile(
    r"^\s*(?P<names>[A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*(?:AT\s+\S+\s*)?:\s*"
    r"(?P<type>ARRAY\s*\[[^\]]*\]\s*OF\s+[\w.()]+|[A-Za-z_][\w.]*(?:\s*[\(\[]\s*[\w+\-* ]+\s*[\)\]])?)"
    r"\s*(?::=\s*(?P<init>[^;]*))?;")


def extract_comment(raw_line):
    m = re.search(r"//\s*(.*)$", raw_line)
    if m:
        return m.group(1).strip()
    m = re.search(r"\(\*\s*(.*?)\s*\*\)\s*$", raw_line)
    if m:
        return m.group(1).strip()
    return ""


def build_types():
    """{nom: {'kind':'struct'|'enum'|'alias', ...}}"""
    types = {}
    for p in CODE.rglob("*.st"):
        raw = read(p)
        rawl = raw.splitlines()
        clean = blank_comments(raw)
        lines = clean.splitlines()
        i = 0
        while i < len(lines):
            m = re.match(r"\s*TYPE\s+([A-Za-z_]\w*)\s*(?:EXTENDS\s+([\w, ]+))?\s*:(.*)$", lines[i])
            if not m:
                i += 1
                continue
            name, ext, rest = m.group(1), m.group(2), m.group(3)
            j = i
            chunk = []
            while j < len(lines) and not re.match(r"\s*END_TYPE", lines[j]):
                chunk.append(lines[j])
                j += 1
            body = "\n".join(chunk)
            if re.search(r"\bSTRUCT\b", body):
                fields = []
                for k in range(i, j):
                    fm = FIELD.match(lines[k])
                    if fm and "END_STRUCT" not in lines[k]:
                        for nm in fm.group("names").split(","):
                            fields.append(dict(name=nm.strip(), type=re.sub(r"\s+", " ", fm.group("type")).strip(),
                                               init=(fm.group("init") or "").strip(),
                                               comment=extract_comment(rawl[k]) if k < len(rawl) else "",
                                               file=str(p.relative_to(REPO)).replace("\\", "/"), line=k + 1))
                types[name] = dict(kind="struct", fields=fields, extends=(ext or "").strip(),
                                   file=str(p.relative_to(REPO)).replace("\\", "/"))
            elif "ENUM" in body:
                mem = re.findall(r"^\s*([A-Za-z_]\w*)\s*(?::=\s*(-?[\w#]+))?\s*,?\s*$", body, flags=re.M)
                types[name] = dict(kind="enum", base="INT", members=[x for x in mem if x[0] not in ("ENUM", "END_ENUM")],
                                   file=str(p.relative_to(REPO)).replace("\\", "/"))
            else:
                # enum : TYPE E_X : ( ... ) BASE;  alias : TYPE X : BOOL;
                em = re.search(r"\)\s*([A-Za-z_]\w*)?\s*(?::=[^;]*)?;", body)
                if "(" in body and em:
                    types[name] = dict(kind="enum", base=(em.group(1) or "INT").upper(),
                                       members=re.findall(r"([A-Za-z_]\w*)\s*(?::=\s*(-?[\w#]+))?\s*[,)]",
                                                          body[body.find("("):]),
                                       file=str(p.relative_to(REPO)).replace("\\", "/"))
                else:
                    am = re.search(r":\s*([A-Za-z_]\w*)\s*;", body)
                    types[name] = dict(kind="alias", base=(am.group(1) if am else "?"))
            i = j + 1
    return types


def size_of(t, types):
    """Taille (octets) d'une FEUILLE, somme brute sans alignement."""
    u = t.upper()
    m = re.match(r"W?STRING(?:\s*[\(\[]\s*(\d+)\s*[\)\]])?$", u)
    if m:
        n = int(m.group(1) or 80)
        return (n + 1) * (2 if u.startswith("W") else 1)
    if u in BASE_SIZE:
        return BASE_SIZE[u]
    if t == "DEVICE_STATE":
        return 2  # HYPOTHESE : enum bibliotheque IO CODESYS, base INT (hors CODE/)
    if t in types:
        d = types[t]
        if d["kind"] == "enum":
            return BASE_SIZE.get(d["base"], 2)
        if d["kind"] == "alias":
            return size_of(d["base"], types)
    return None


def align_of(t, types):
    u = t.upper()
    if u.startswith("STRING") or u.startswith("WSTRING"):
        return 1
    s = size_of(t, types)
    return s if s else 1


def walk(t, prefix, types, out, meta=None, top=None):
    """Descend dans les structs ; feuilles = types scalaires / enum / chaines."""
    arr = re.match(r"ARRAY\s*\[\s*(-?\w+)\s*\.\.\s*(-?\w+)\s*\]\s*OF\s+(.+)$", t)
    if arr:
        lo, hi = arr.group(1), arr.group(2)
        try:
            lo, hi = int(lo), int(hi)
        except ValueError:
            out.append(dict(path=prefix, type=t, size=None, comment=(meta or {}).get("comment", "ARRAY borne symbolique"),
                            file=(meta or {}).get("file", ""), line=(meta or {}).get("line", "")))
            return
        for k in range(lo, hi + 1):
            walk(arr.group(3).strip(), f"{prefix}[{k}]", types, out, meta)
        return
    if t in types and types[t]["kind"] == "struct":
        d = types[t]
        if d.get("extends"):
            walk(d["extends"], prefix, types, out, meta)
        for f in d["fields"]:
            walk(f["type"], f"{prefix}.{f['name']}", types, out, f)
    else:
        out.append(dict(path=prefix, type=t, size=size_of(t, types), comment=(meta or {}).get("comment", ""),
                        file=(meta or {}).get("file", ""), line=(meta or {}).get("line", "")))


def struct_aligned_size(t, types, pack=None):
    """Taille alignement naturel (hypothese) ; retourne (size, align)."""
    arr = re.match(r"ARRAY\s*\[\s*(-?\d+)\s*\.\.\s*(-?\d+)\s*\]\s*OF\s+(.+)$", t)
    if arr:
        s, a = struct_aligned_size(arr.group(3).strip(), types, pack)
        return s * (int(arr.group(2)) - int(arr.group(1)) + 1), a
    if t in types and types[t]["kind"] == "struct":
        off, maxa = 0, 1
        d = types[t]
        fields = list(d["fields"])
        if d.get("extends"):
            fields = [dict(type=d["extends"])] + fields
        for f in fields:
            s, a = struct_aligned_size(f["type"], types, pack)
            maxa = max(maxa, a)
            off = (off + a - 1) // a * a + s
        return (off + maxa - 1) // maxa * maxa, maxa
    return (size_of(t, types) or 0), align_of(t, types)


def gvl_fields():
    p = CODE / "J_SUPERVISION" / "GVL_Troubleshooting.st"
    raw = read(p)
    rawl = raw.splitlines()
    clean = blank_comments(raw).splitlines()
    res = []
    for k, l in enumerate(clean):
        m = FIELD.match(l)
        if m and "VAR_GLOBAL" not in l:
            res.append(dict(name=m.group("names"), type=m.group("type"), comment=extract_comment(rawl[k]), line=k + 1))
    return res


def all_leaves(types):
    out = []
    for f in gvl_fields():
        grp = []
        walk(f["type"], "GVL_Troubleshooting." + f["name"], types, grp)
        for g in grp:
            g["group"] = f["name"]
            g["top_type"] = f["type"]
        out.extend(grp)
    return out


def view_assignments():
    """[(lhs_path, expr, line_debut)] dans FB_TroubleshootingView (corps)."""
    p = CODE / "J_SUPERVISION" / "FB_TroubleshootingView.st"
    clean = blank_comments(read(p))
    res = []
    for m in re.finditer(r"GVL_Troubleshooting\.([A-Za-z_][\w.]*)\s*:=\s*(.*?);", clean, flags=re.S):
        line = clean.count("\n", 0, m.start()) + 1
        res.append(("GVL_Troubleshooting." + m.group(1), re.sub(r"\s+", " ", m.group(2)).strip(), line))
    return res


def view_input_ports():
    p = CODE / "J_SUPERVISION" / "FB_TroubleshootingView.st"
    clean = blank_comments(read(p))
    body = clean[clean.find("VAR_INPUT"):clean.find("END_VAR")]
    return [m.group(1) for l in body.splitlines() for m in [FIELD.match(l)] if m and "VAR_INPUT" not in l for m in [re.match(r"\s*(\w+)", l)]]


def prg07_bindings():
    clean = blank_comments(read(CODE / "M_MAIN" / "PRG_07_Supervision.st"))
    s = clean.find("instTroubleshootingView(")
    e = clean.find(");\n", s)
    txt = clean[s + len("instTroubleshootingView("):e]
    # decoupage aux virgules de profondeur 0
    parts, depth, cur = [], 0, ""
    for ch in txt:
        if ch == "(":
            depth += 1
        if ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)
    b = {}
    for x in parts:
        if ":=" in x:
            k, v = x.split(":=", 1)
            b[k.strip()] = re.sub(r"\s+", " ", v).strip()
    return b
