# -*- coding: utf-8 -*-
"""Index des ecritures ST et remontee best-effort au producteur reel."""
import re
from ts_lib import *

KW = {"TRUE", "FALSE", "NOT", "AND", "OR", "XOR", "MOD", "SEL", "LIMIT", "MIN", "MAX", "ABS", "UDINT_TO_DINT", "THEN",
      "IF", "ELSE", "ELSIF", "END_IF"}
POU_RE = re.compile(r"^\s*(FUNCTION_BLOCK|PROGRAM|FUNCTION)\s+(?:(?:PUBLIC|FINAL|ABSTRACT|INTERNAL|PROTECTED)\s+)*([A-Za-z_]\w*)", re.M)
SEC_RE = re.compile(r"^\s*(VAR_INPUT|VAR_OUTPUT|VAR_IN_OUT|VAR_GLOBAL|VAR_STAT|VAR_TEMP|VAR)\b[^\n]*$", re.M)


class Pou:
    def __init__(s, name, kind, path):
        s.name, s.kind, s.path = name, kind, path
        s.vars = {}      # nom -> (type, section, init)
        s.writes = []    # (lhs, rhs, line)
        s.calls = []     # (inst, {param: expr}, {param: target}, line)


def parse_args(txt):
    parts, depth, cur = [], 0, ""
    for ch in txt:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)
    ins, outs = {}, {}
    for x in parts:
        if "=>" in x:
            a, b = x.split("=>", 1)
            outs[a.strip()] = re.sub(r"\s+", " ", b).strip()
        elif ":=" in x:
            a, b = x.split(":=", 1)
            ins[a.strip()] = re.sub(r"\s+", " ", b).strip()
    return ins, outs


def index_code():
    pous = {}
    for p in CODE.rglob("*.st"):
        raw = read(p)
        cl = blank_comments(raw)
        rel = str(p.relative_to(REPO)).replace("\\", "/")
        if re.match(r"\s*TYPE\b", cl):
            continue
        m = POU_RE.search(cl)
        if m:
            name, kind = m.group(2), m.group(1)
        elif "VAR_GLOBAL" in cl:
            name, kind = p.stem, "GVL"
        else:
            name, kind = p.stem, "?"
        pou = Pou(name, kind, rel)
        pous[name] = pou
        # sections VAR
        pos, last_end = 0, 0
        for sm in SEC_RE.finditer(cl):
            sec = sm.group(1)
            e = cl.find("END_VAR", sm.end())
            if e < 0:
                continue
            last_end = max(last_end, e + 7)
            for l in cl[sm.end():e].splitlines():
                fm = FIELD.match(l)
                if fm:
                    for nm in fm.group("names").split(","):
                        pou.vars[nm.strip()] = (re.sub(r"\s+", " ", fm.group("type")).strip(), sec, (fm.group("init") or "").strip())
        body_off = last_end
        body = cl[body_off:]
        ln = lambda off: cl.count("\n", 0, body_off + off) + 1
        # parcours profondeur de parentheses
        depth = 0
        i = 0
        n = len(body)
        tok = re.compile(r"[A-Za-z_][\w.\[\]]*")
        while i < n:
            c = body[i]
            if c == "(":
                depth += 1
                i += 1
                continue
            if c == ")":
                depth -= 1
                i += 1
                continue
            if depth == 0:
                t = tok.match(body, i)
                if t:
                    nm = t.group(0)
                    j = t.end()
                    while j < n and body[j] in " \t\r\n":
                        j += 1
                    if body.startswith(":=", j):
                        e = j + 2
                        d = 0
                        while e < n and not (body[e] == ";" and d == 0):
                            d += (body[e] == "(") - (body[e] == ")")
                            e += 1
                        pou.writes.append((nm, re.sub(r"\s+", " ", body[j + 2:e]).strip(), ln(i)))
                        i = e
                        continue
                    if body.startswith("(", j) and nm.upper() not in KW:
                        d, e = 0, j
                        while e < n:
                            d += (body[e] == "(") - (body[e] == ")")
                            e += 1
                            if d == 0:
                                break
                        ins, outs = parse_args(body[j + 1:e - 1])
                        pou.calls.append((nm, ins, outs, ln(i)))
                        i = e
                        continue
                    i = t.end()
                    continue
            i += 1
    return pous


class Tracer:
    def __init__(s, types, pous):
        s.t, s.p = types, pous

    def owner_of(s, path, ctx):
        """Resout un chemin -> (pou, rel, stack). ctx = (pou, stack)."""
        pou, stack = ctx
        path = re.sub(r"\[[^\]]*\]", "", path)
        parts = path.split(".")
        if parts[0] in s.p and s.p[parts[0]].kind in ("PROGRAM", "GVL"):
            pou, stack = parts[0], []
            parts = parts[1:]
        if not parts:
            return None
        # descente dans les FB
        cur, st = pou, list(stack)
        k = 0
        while k < len(parts):
            v = s.p[cur].vars.get(parts[k]) if cur in s.p else None
            if not v:
                break
            ty = v[0]
            if ty in s.p and s.p[ty].kind == "FUNCTION_BLOCK" and k + 1 < len(parts):
                # VAR_IN_OUT de type FB : passer par la liaison appelant si possible
                if v[1] == "VAR_IN_OUT" and st:
                    b = s.binding(cur, parts[k], st)
                    if b:
                        r = s.owner_of(b + "." + ".".join(parts[k + 1:]), (st[-1][0], st[:-1]))
                        return r
                st = st + [(cur, parts[k])]
                cur = ty
                parts = parts[k + 1:]
                k = 0
                continue
            k += 1
        return cur, ".".join(parts), st

    def binding(s, fb, param, st):
        if not st:
            return None
        caller, inst = st[-1]
        for c in s.p[caller].calls:
            if c[0] == inst and param in c[1]:
                return c[1][param]
        return None

    def writers(s, pou, rel):
        """ecritures exactes ou ancetre/descendant dans le POU."""
        res = []
        if s.p[pou].kind == "GVL":
            full = pou + "." + rel
            for q in s.p.values():
                for lhs, rhs, ln in q.writes:
                    l = re.sub(r"\[[^\]]*\]", "", lhs)
                    if l == full or full.startswith(l + "."):
                        res.append((l[len(pou) + 1:], rhs, ln, "assign", q.name))
                for inst, ins, outs, ln in q.calls:
                    for prm, tgt in outs.items():
                        t = re.sub(r"\[[^\]]*\]", "", tgt)
                        if t == full or full.startswith(t + "."):
                            res.append((t[len(pou) + 1:], f"{inst}.{prm}", ln, "out", q.name))
                    ty = q.vars.get(inst.split(".")[0], (None,))[0]
                    if ty in s.p:
                        for prm, ex in ins.items():
                            pv = s.p[ty].vars.get(prm)
                            e = re.sub(r"\[[^\]]*\]", "", ex)
                            if pv and pv[1] == "VAR_IN_OUT" and (e == full or full.startswith(e + ".")):
                                res.append((e[len(pou) + 1:], f"{inst}.{prm}", ln, "inout", q.name))
            return res
        for lhs, rhs, ln in s.p[pou].writes:
            l = re.sub(r"\[[^\]]*\]", "", lhs)
            if l == rel or rel.startswith(l + "."):
                res.append((l, rhs, ln, "assign", pou))
        for inst, ins, outs, ln in s.p[pou].calls:
            for prm, tgt in outs.items():
                t = re.sub(r"\[[^\]]*\]", "", tgt)
                if t == rel or rel.startswith(t + "."):
                    res.append((t, f"{inst}.{prm}", ln, "out", pou))
            # passage VAR_IN_OUT
            ty = s.p[pou].vars.get(inst.split(".")[0], (None,))[0]
            if ty in s.p:
                for prm, ex in ins.items():
                    pv = s.p[ty].vars.get(prm)
                    if pv and pv[1] == "VAR_IN_OUT":
                        e = re.sub(r"\[[^\]]*\]", "", ex)
                        if e == rel or rel.startswith(e + "."):
                            res.append((e, f"{inst}.{prm}", ln, "inout", pou))
        return res

    def trace(s, path, ctx=None, depth=0, seen=None):
        """Retourne liste de chaines [(etapes...)], derniere etape = producteur."""
        seen = seen or set()
        r = s.owner_of(path, ctx or ("PRG_07_Supervision", []))
        if not r:
            return [[f"? {path}"]]
        pou, rel, st = r
        key = (pou, rel, tuple(st))
        if key in seen or depth > 12:
            return [[f"(boucle) {pou}.{rel}"]]
        seen = seen | {key}
        if pou not in s.p:
            return [[f"? {pou}.{rel}"]]
        wr = s.writers(pou, rel)
        root = rel.split(".")[0]
        v = s.p[pou].vars.get(root)
        here = f"{pou}.{rel}"
        fp = s.p[pou].path
        if not wr:
            if v and v[1] in ("VAR_INPUT", "VAR_IN_OUT") and st:
                b = s.binding(pou, root, st)
                if b:
                    rest = rel[len(root):]
                    if re.fullmatch(r"[A-Za-z_][\w.\[\]]*", b):
                        return [[here] + c for c in s.trace(b + rest, (st[-1][0], st[:-1]), depth + 1, seen)]
                    return [[here, f"CALC@{st[-1][0]}: {b}"]]
            return [[f"TERM {here} (aucun ecrivain ST) [{v[1] if v else '?'}]"]]
        chains = []
        for lhs, rhs, ln, kind, wp in wr[:10]:
            rest = rel[len(lhs):]
            fpw = s.p[wp].path
            loc = f"{fpw.split('/')[-1]}:{ln}"
            cctx = (wp, st) if wp == pou else (wp, [])
            if re.fullmatch(r"E_\w+\.\w+|-?[\d.]+|TRUE|FALSE|[A-Z][A-Z0-9_]+", rhs):
                chains.append([f"CONST@{loc} {wp} {lhs} := {rhs}"])
                continue
            if kind in ("out", "inout") or re.fullmatch(r"[A-Za-z_][\w.\[\]]*", rhs):
                for c in s.trace(rhs + rest, cctx, depth + 1, seen):
                    chains.append([f"{pou}.{lhs}{rest}@{loc}"] + c)
            else:
                chains.append([f"CALC@{loc} {wp} {lhs} := {rhs[:90]}"])
        return chains
