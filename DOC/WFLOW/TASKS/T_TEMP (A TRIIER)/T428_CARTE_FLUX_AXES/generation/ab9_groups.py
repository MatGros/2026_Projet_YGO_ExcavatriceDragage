# -*- coding: utf-8 -*-
import csv, json, re
from collections import Counter, defaultdict
from pathlib import Path
C = Path("carte")
def grp(c):
    p = c.split(".")
    if p[0].startswith("GVL_"):
        return ".".join(p[:2])
    if len(p) > 1 and p[1].startswith("inst"):
        return ".".join(p[:2])
    return p[0]
for ax in ("M1", "M2", "M3"):
    rows = list(csv.DictReader(open(C / f"cone_{ax}.csv", encoding="utf-8"), delimiter=";"))
    edges = json.load(open(C / f"edges_{ax}.json"))
    g = defaultdict(list)
    for r in rows:
        g[grp(r["chemin"])].append(r)
    dep = defaultdict(lambda: 999)
    for k, v in g.items():
        dep[k] = min(int(r["depth"]) for r in v)
    links = Counter()
    for a, b in edges:
        ga, gb = grp(a), grp(b)
        if ga != gb:
            links[(gb, ga)] += 1   # amont -> aval
    out = {k: {"depth": dep[k], "n": len(v), "visibles": sum(r["visible"] == "True" for r in v),
               "classes": Counter(r["classe"] for r in v).most_common(4)} for k, v in g.items()}
    json.dump({"groups": out, "links": [[a, b, n] for (a, b), n in links.items()]}, open(C / f"groups_{ax}.json", "w"), indent=0)
    print("==", ax, "blocs", len(g), "liens", len(links))
    for k in sorted(out, key=lambda x: (out[x]["depth"], x))[:45]:
        o = out[k]
        print(f"  d{o['depth']:>2} {k:<58} n={o['n']:<4} vis={o['visibles']}")
