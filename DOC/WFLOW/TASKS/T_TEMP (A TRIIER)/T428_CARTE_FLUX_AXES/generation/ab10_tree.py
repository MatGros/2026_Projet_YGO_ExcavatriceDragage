# -*- coding: utf-8 -*-
import csv, json, sys
from collections import Counter, defaultdict, deque
from pathlib import Path

C = Path(r"C:\Users\ZEDVICTUS\.claude\jobs\ebe3ca88\tmp\carte")
ax = sys.argv[1]
rows = {r["chemin"]: r for r in csv.DictReader(open(C / f"cone_{ax}.csv", encoding="utf-8"), delimiter=";")}
edges = json.load(open(C / f"edges_{ax}.json"))


def grp(c):
    p = c.split(".")
    if p[0].startswith("GVL_"):
        return ".".join(p[:2])
    if len(p) > 1 and p[1].startswith("inst"):
        return ".".join(p[:2])
    return p[0]


up, down = defaultdict(set), defaultdict(set)
for a, b in edges:
    up[a].add(b)
    down[b].add(a)
iface = set()
for a, b in edges:
    if grp(a) != grp(b):
        iface |= {a, b}
outs = [c for c, r in rows.items() if int(r["depth"]) == 0]


def path_to_out(src):
    prev = {src: None}
    q = deque([src])
    while q:
        n = q.popleft()
        if n in outs:
            p = []
            while n is not None:
                p.append(n)
                n = prev[n]
            return p
        for d in down[n]:
            if d not in prev:
                prev[d] = n
                q.append(d)
    return None


term = [c for c, r in rows.items() if r["classe"] in ("COMMANDE", "BYPASS", "REGLAGE", "FRONTIERE") or c.endswith("_DI") or ".HwIn." in c or ".HwReal." in c]
term = [c for c in term if not up[c] or rows[c]["classe"] in ("COMMANDE", "FRONTIERE")]
res, noreach = {}, []
for t in term:
    p = path_to_out(t)
    if p:
        res[t] = p
    else:
        noreach.append(t)
print(ax, "noeuds", len(rows), "interface", len(iface), "terminaux", len(term), "avec chemin", len(res), "sans", len(noreach))
print("sans chemin:", noreach[:12])
print("classes term", Counter(rows[t]["classe"] for t in term).most_common())
L = [len(p) for p in res.values()]
print("longueur chemin min/med/max", min(L), sorted(L)[len(L) // 2], max(L))
json.dump({"iface": sorted(iface), "paths": res, "outs": outs}, open(C / f"tree_{ax}.json", "w"), indent=0)
for t in [c for c in res if rows[c]["classe"] == "COMMANDE"][:6]:
    print("\n", t)
    for n in res[t]:
        print("   ", n, "|", rows[n]["section"], "|", rows[n]["loc"][:40], "| vis" if rows[n]["visible"] == "True" else "|")
