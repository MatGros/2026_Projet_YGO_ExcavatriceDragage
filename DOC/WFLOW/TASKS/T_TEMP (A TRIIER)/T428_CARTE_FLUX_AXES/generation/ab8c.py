# -*- coding: utf-8 -*-
"""Cone de dependances : de chaque sortie physique vers les commandes, reglages et capteurs."""
import csv, json, re, sys
from collections import Counter, defaultdict, deque
from pathlib import Path

sys.path.insert(0, r"C:\Users\ZEDVICTUS\.claude\jobs\ebe3ca88\tmp")
from ts_lib import *
from ts_trace import index_code, Tracer, KW

TMP = Path(r"C:\Users\ZEDVICTUS\.claude\jobs\ebe3ca88\tmp")
C = TMP / "carte"
types = build_types()
pous = index_code()
tr = Tracer(types, pous)
ID = re.compile(r"[A-Za-z_]\w*(?:\[[^\]]*\])?(?:\.[A-Za-z_]\w*(?:\[[^\]]*\])?)*")
SKIP = KW | {"THEN", "OF", "DO", "TO", "BY", "WHILE", "FOR", "END_FOR", "CASE", "END_CASE", "ABS", "TRUE", "FALSE"}


def conds_for(pou):
    txt = blank_comments(read(REPO / pou.path))
    n = txt.count("\n") + 2
    ev = []
    st = []
    for m in re.finditer(r"\b(IF|ELSIF|ELSE|END_IF|CASE|END_CASE)\b", txt):
        w = m.group(1)
        line = txt.count("\n", 0, m.start()) + 1
        if w in ("IF", "ELSIF"):
            e = txt.find("THEN", m.end())
            c = txt[m.end():e]
            if w == "IF":
                st.append([c])
            elif st:
                st[-1].append(c)
        elif w == "CASE":
            e = txt.find("OF", m.end())
            st.append([txt[m.end():e]])
        elif w in ("END_IF", "END_CASE") and st:
            st.pop()
        ev.append((line, " ".join(" ".join(x) for x in st)))
    arr = [""] * n
    for i, (l, s) in enumerate(ev):
        end = ev[i + 1][0] if i + 1 < len(ev) else n
        for k in range(l, min(end, n)):
            arr[k] = s
    return arr


CONDS = {k: None for k in pous}


def cond_at(pn, ln):
    if pn not in pous or pous[pn].kind == "GVL":
        return ""
    if CONDS.get(pn) is None:
        CONDS[pn] = conds_for(pous[pn])
    a = CONDS[pn]
    return a[ln] if 0 <= ln < len(a) else ""


def idents(expr):
    out = []
    for m in ID.finditer(expr):
        s = m.group(0)
        if s.upper() in SKIP or s.split(".")[0].upper() in SKIP:
            continue
        if re.match(r"(E_\w+\.|CST_|T#|[A-Z_]+_TO_)", s):
            continue
        out.append(s)
    return out


def norm(p):
    return re.sub(r"\[[^\]]*\]", "", p)


def writers(pn, rel):
    res = list(tr.writers(pn, rel))
    if pous[pn].kind != "GVL":
        for lhs, rhs, ln in pous[pn].writes:
            l = norm(lhs)
            if l.startswith(rel + "."):
                res.append((l, rhs, ln, "assign", pn))
    return res


def canon(pn, rel, st):
    if st:
        return ".".join([st[0][0]] + [s[1] for s in st] + [rel])
    return pn + "." + rel


def klass(c):
    u = c
    if ".Bypass" in u or "Bypass" in u.split(".")[-1]:
        return "BYPASS"
    if c.startswith("GVL_IHM.") and ".Cmd." in c:
        return "COMMANDE"
    if c.startswith("GVL_PERSISTENT") or ".Cfg" in c or "CfgPersist" in c or c.split(".")[-1].startswith("Cfg") or c.split(".")[-1].startswith("Tgl"):
        return "REGLAGE"
    if c.startswith("GVL_Simulation") or "Sim" in c.split(".")[0]:
        return "SIMU"
    if c.startswith("GVL_IHM."):
        return "IHM"
    return "AUTRE"


FRONT = {"M1": r"M2|Bucket|M3|Translation|Benne", "M2": r"M1|M3|Translation", "M3": r"M1|M2|Winch|Bucket|Benne"}
COMMON = r"instCycleSemiAuto|instCycleMachineHoming|instSafetyEmergency|GVL_Simulation|Sim[A-Z]|FB_Sim"


def frontier(c, ax):
    head = c.split(".")
    tail = ".".join(head[1:])
    if re.search(COMMON, c):
        return True
    if c.startswith("PRG_03_Modes_Cycle") or c.startswith("GVL_IHM.Modes") or c.startswith("GVL_PERSISTENT"):
        return True
    return bool(re.search(FRONT[ax], tail))


def cone(roots, ax, limit=8000):
    seen = {}
    edges = set()
    q = deque()
    for r in roots:
        o = tr.owner_of(r, ("PRG_06_Outputs", []))
        k = (o[0], o[1], tuple(o[2]))
        seen[k] = dict(depth=0, loc=[])
        q.append(k)

    def visit(parent, dep, ctx):
        try:
            o = tr.owner_of(dep, ctx)
        except Exception:
            return
        if not o or o[0] not in pous:
            return
        k = (o[0], o[1], tuple(o[2]))
        edges.add((parent, k))
        if k not in seen and len(seen) < limit:
            seen[k] = dict(depth=seen[parent]["depth"] + 1, loc=[])
            if frontier(canon(k[0], k[1], list(k[2])), ax):
                seen[k]["front"] = True
            else:
                q.append(k)

    while q:
        k = q.popleft()
        pn, rel, st = k
        st = list(st)
        wr = writers(pn, rel)
        root = rel.split(".")[0]
        v = pous[pn].vars.get(root)
        for lhs, rhs, ln, kind, wp in wr[:60]:
            seen[k]["loc"].append("%s:%d" % (pous[wp].path.split("/")[-1], ln))
            ctx = (wp, st) if wp == pn else (wp, [])
            rest = rel[len(lhs):] if rel.startswith(lhs) else ""
            for d in idents(rhs):
                visit(k, d + (rest if re.fullmatch(ID.pattern, rhs) else ""), ctx)
            for d in idents(cond_at(wp, ln)):
                visit(k, d, ctx)
        if not wr and v and st is not None and pn in pous and pous[pn].kind != "GVL" and v[0] not in pous:
            # FB standard (R_TRIG, TON, SR...) : la sortie depend de toutes les entrees de son appel
            for inst, ins, outs_, ln in pous[pn].calls:
                if norm(inst).split(".")[0] == root or norm(inst) == norm(rel).rsplit(".", 1)[0]:
                    seen[k]["loc"].append("%s:%d" % (pous[pn].path.split("/")[-1], ln))
                    for ex in ins.values():
                        for d in idents(ex):
                            visit(k, d, (pn, st))
                    for d in idents(cond_at(pn, ln)):
                        visit(k, d, (pn, st))
        if v and v[1] in ("VAR_INPUT", "VAR_IN_OUT") and st:
            b = tr.binding(pn, root, st)
            if b:
                ctx = (st[-1][0], st[:-1])
                rest = rel[len(root):]
                if re.fullmatch(ID.pattern, b):
                    visit(k, b + rest, ctx)
                else:
                    for d in idents(b):
                        visit(k, d, ctx)
    return seen, edges


# Couverture snapshot
listed = set((REPO / "TOOLS/PLC_CSV_SNAPSHOT/variable_lists/troubleshooting_variables.txt").read_text(encoding="utf-8").split())
covered = set(listed)
for r in csv.DictReader(open(TMP / "troubleshooting_inventory.csv", encoding="utf-8-sig"), delimiter=";"):
    if r["classe_expression"] in ("COPIE", "NEGATION"):
        for s in re.findall(r"[A-Za-z_][\w.]*", " ".join([r["source_amont"], r["chaine_exemple"]])):
            covered.add(s)

# Alias de valeur : suit les copies pures depuis chaque source de feuille snapshot
def aliases(start):
    out = set()
    try:
        o = tr.owner_of(start, ("PRG_07_Supervision", []))
    except Exception:
        return out
    todo = [o] if o else []
    seen = set()
    while todo:
        pn, rel, st = todo.pop()
        key = (pn, rel, tuple(st))
        if key in seen or pn not in pous or len(seen) > 40:
            continue
        seen.add(key)
        out.add(canon(pn, rel, list(st)))
        wr = writers(pn, rel)
        root = rel.split(".")[0]
        v = pous[pn].vars.get(root)
        if not wr and v and v[1] in ("VAR_INPUT", "VAR_IN_OUT") and st:
            b = tr.binding(pn, root, st)
            if b and re.fullmatch(ID.pattern, b):
                n = tr.owner_of(b + rel[len(root):], (st[-1][0], st[:-1]))
                if n:
                    todo.append(n)
            continue
        for lhs, rhs, ln, kind, wp in wr[:6]:
            rest = rel[len(lhs):] if rel.startswith(lhs) else ""
            r = rhs.strip()
            if r.upper().startswith("NOT "):
                r = r[4:].strip()
            if re.fullmatch(ID.pattern, r):
                n = tr.owner_of(r + rest, (wp, list(st)) if wp == pn else (wp, []))
                if n:
                    todo.append(n)
    return out


with open(TMP / "troubleshooting_inventory.csv", encoding="utf-8-sig") as _f:
    _rows = list(csv.DictReader(_f, delimiter=";"))
for r in _rows:
    if r["classe_expression"] in ("COPIE", "NEGATION") and re.fullmatch(r"[A-Za-z_][\w.\[\]]*", r["source_amont"].strip()):
        covered |= aliases(r["source_amont"].strip())
for p in listed:
    if not p.startswith("GVL_Troubleshooting"):
        covered |= aliases(p)
print("covered", len(covered))

M3OUT = [m for m in pous["PRG_06_Outputs"].vars if re.match(r"M3_", m) and pous["PRG_06_Outputs"].vars[m][1] in ("VAR_OUTPUT", "VAR")]
ROOTS = {
    "M1": ["M1_RelayAscent_RQ", "M1_RelayDescent_RQ", "M1_SpeedContactor_1_DQ", "M1_SpeedContactor_2_DQ", "M1_SpeedContactor_3_DQ", "M1_SpeedContactor_4_DQ", "M1_BrakeRelease_RQ"],
    "M2": ["M2_RelayAscent_Close_RQ", "M2_RelayDescent_Open_RQ", "M2_SpeedContactor_1_DQ", "M2_SpeedContactor_2_DQ", "M2_SpeedContactor_3_DQ", "M2_SpeedContactor_4_DQ", "M2_BrakeRelease_RQ"],
    "M3": sorted({l for l, _, _ in pous["PRG_06_Outputs"].writes if l.startswith("M3_") and l.endswith(("_RQ", "_DQ", "Hz", "Word"))}),
}
print("M3OUT", M3OUT[:20])
for ax, roots in ROOTS.items():
    seen, edges = cone(roots, ax)
    rows = []
    for (pn, rel, st), inf in seen.items():
        c = canon(pn, rel, list(st))
        v = pous[pn].vars.get(rel.split(".")[0])
        sect = v[1] if v else "?"
        vis = c in covered or any(c.startswith(x + ".") for x in ()) or norm(c) in covered
        rows.append(dict(chemin=c, depth=inf["depth"], classe="FRONTIERE" if inf.get("front") and klass(c) == "AUTRE" else klass(c), section=sect, type=v[0] if v else "?", loc=" ".join(sorted(set(inf["loc"]))[:4]), visible=vis))
    rows.sort(key=lambda r: (r["depth"], r["chemin"]))
    with open(C / ("cone_%s.csv" % ax), "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()), delimiter=";")
        w.writeheader()
        w.writerows(rows)
    json.dump([[canon(a[0], a[1], list(a[2])), canon(b[0], b[1], list(b[2]))] for a, b in edges], open(C / ("edges_%s.json" % ax), "w"))
    nv = sum(r["visible"] for r in rows)
    print("==", ax, "noeuds", len(rows), "aretes", len(edges), "visibles", nv, "%.0f%%" % (100 * nv / len(rows)), "prof max", max(r["depth"] for r in rows))
    print("  classes", Counter(r["classe"] for r in rows).most_common())
    print("  sections", Counter(r["section"] for r in rows).most_common(8))
    cmd = sorted(r["chemin"] for r in rows if r["classe"] == "COMMANDE")
    print("  commandes", len(cmd), [c.split("GVL_IHM.")[-1] for c in cmd])
    print("  roots", roots[:9])
    for t in ("instArbM1.RunRequest","instArbM2.RunRequest","SyncOperationPermit","instWinchOutputInterlockM1.RelayFwd","instWinchOutputInterlockM2.RelayFwd","M3_TremieHardStopActive","instArbM3.RunRequest"):
        print("   ", t, [(r["depth"], r["visible"]) for r in rows if r["chemin"].endswith(t)][:2])
    print("  prof", sorted(Counter(r["depth"] for r in rows).items())[:24])
