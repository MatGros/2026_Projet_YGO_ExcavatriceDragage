# -*- coding: utf-8 -*-
"""Remplace les renvois generiques par les maillons aval reels du graphe."""
import csv, json
from collections import defaultdict
from pathlib import Path

T = Path(r"C:\Users\ZEDVICTUS\.claude\jobs\ebe3ca88\tmp\carte")
GEN = ("Verifier le maillon suivant", "Reprendre le parcours dans la carte")
for ax in ("M1", "M2", "M3", "AU"):
    p = T / f"annot_{ax}.json"
    if not p.exists():
        continue
    ann = json.load(open(p, encoding="utf-8"))
    rows = {r["chemin"]: r for r in csv.DictReader(open(T / f"cone_{ax}.csv", encoding="utf-8"), delimiter=";")}
    down = defaultdict(set)
    for a, b in json.load(open(T / f"edges_{ax}.json")):
        down[b].add(a)
    n = m = 0
    for c, a in ann.items():
        if not a["si_dernier_vrai"].startswith(GEN):
            continue
        next_ = sorted(down[c], key=lambda x: (int(rows[x]["depth"]) if x in rows else 99, x))[:2]
        if next_:
            a["si_dernier_vrai"] = "Verifier en aval : " + ", ".join(next_)
            n += 1
        else:
            m += 1
    json.dump(ann, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(ax, "remplaces", n, "sans aval", m)
