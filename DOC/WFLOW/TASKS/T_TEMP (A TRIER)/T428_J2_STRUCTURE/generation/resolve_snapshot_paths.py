# -*- coding: utf-8 -*-
"""Resolution statique des chemins du snapshot dans les declarations ST de CODE/.
Usage : python j3_resolve.py <liste.txt> [<liste2.txt>...]  -> chemins non resolus, code 1 si KO."""
import re, sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
REPO = Path(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage")
DECL = re.compile(r"^\s*([A-Za-z_]\w*)\s*(?:AT\s+%\S+\s*)?:\s*(?:ARRAY\s*\[[^\]]*\]\s*OF\s*)?([A-Za-z_][\w.]*)", re.I)
HEAD = re.compile(r"^\s*(?:\{[^}]*\}\s*)*(PROGRAM|FUNCTION_BLOCK|TYPE|VAR_GLOBAL)\b\s*(?:(?:ABSTRACT|FINAL|PUBLIC|INTERNAL)\s+)*([A-Za-z_]\w*)?(?:\s+EXTENDS\s+([A-Za-z_]\w*))?", re.I)
KW = {"VAR", "VAR_INPUT", "VAR_OUTPUT", "VAR_IN_OUT", "VAR_TEMP", "VAR_STAT", "VAR_INST", "END_VAR", "STRUCT", "END_STRUCT", "END_TYPE", "TYPE", "CONSTANT", "RETAIN", "PERSISTENT"}
scopes, parent = {}, {}
for f in (REPO / "CODE").rglob("*.st"):
    if any(x in f.parts for x in ("ARCHIVES",)):
        continue
    cur, body = None, True
    for raw in f.read_text(encoding="utf-8", errors="replace").splitlines():
        l = re.sub(r"//.*|\(\*.*?\*\)", "", raw)
        m = HEAD.match(l)
        if m:
            kind, name, ext = m.group(1).upper(), m.group(2), m.group(3)
            if kind == "VAR_GLOBAL":
                name = f.stem
            if name:
                cur = name
                scopes.setdefault(cur, {})
                if ext:
                    parent[cur] = ext
            body = True
            continue
        if re.match(r"^\s*(END_FUNCTION_BLOCK|END_PROGRAM|END_TYPE|END_VAR\b.*\bEND\b)", l):
            pass
        if cur is None:
            continue
        if re.match(r"^\s*(METHOD|PROPERTY|ACTION)\b", l, re.I):
            cur = None
            continue
        d = DECL.match(l)
        if d and d.group(1).upper() not in KW and ":=" not in l.split(":", 1)[0]:
            if not re.search(r":=", l.split(";")[0].split(":", 1)[0]):
                scopes[cur].setdefault(d.group(1), d.group(2))


def members(t):
    out = {}
    while t:
        out = {**scopes.get(t, {}), **out}
        t = parent.get(t)
    return out


def resolve(path):
    seg = path.split(".")
    if seg[0] not in scopes:
        return "racine inconnue " + seg[0]
    t = seg[0]
    for s in seg[1:]:
        m = members(t)
        if s not in m:
            return "membre absent %s dans %s" % (s, t)
        t = m[s]
    return None


ko = 0
for lst in sys.argv[1:]:
    for p in Path(lst).read_text(encoding="utf-8").split():
        r = resolve(p)
        if r:
            ko += 1
            print("KO", p, "|", r)
print("chemins KO", ko)
sys.exit(1 if ko else 0)
