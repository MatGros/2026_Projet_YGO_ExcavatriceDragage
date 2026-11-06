# -*- coding: utf-8 -*-
"""Reprend les annotations signalees vagues, puis relit les 4 cartes sur un echantillon."""
import csv, json, random, re, urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

T = Path(r"C:\Users\ZEDVICTUS\.claude\jobs\ebe3ca88\tmp\carte")
WT = Path(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\.claude\worktrees\carte-flux")
ST = {p.name: p for p in (WT / "CODE").rglob("*.st") if "CODE_BACKUP" not in str(p)}
AXES = ("M1", "M2", "M3", "AU")
LOC = re.compile(r"\b[\w]+\.st:\d+")


def L(f):
    return ST[f].read_text(encoding="utf-8-sig", errors="replace").splitlines() if f in ST else []


def post(p, n=6000):
    d = {"model": "deepseek-v4.1-flash:cloud", "prompt": p, "stream": False, "think": False, "options": {"num_ctx": 48000, "num_predict": n, "temperature": 0}}
    rq = urllib.request.Request("http://localhost:11434/api/generate", data=json.dumps(d).encode("utf-8"), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(rq, timeout=280) as r:
        return json.loads(r.read().decode("utf-8")).get("response", "")


def ctx(a):
    out = []
    for loc in LOC.findall(a["code"])[:2]:
        f, n = loc.split(":")
        n = int(n)
        out.append("--- %s\n%s" % (loc, "\n".join(x.rstrip() for x in L(f)[max(0, n - 12):n + 8])))
    return "\n".join(out)


FIX = """Reecris chaque annotation signalee trop vague. Rends exactement une ligne : N|numero|CONDITION|SI_DERNIER_VRAI
Cite les variables exactes et les branches IF du code fourni. Si le noeud recoit une structure complete, ecris "copie de structure depuis X". Pas de | dans les textes, aucune autre phrase. Ne dis jamais d'aller lire le code.

{items}
"""
for ax in AXES:
    p = T / f"annot_{ax}.json"
    ann = json.load(open(p, encoding="utf-8"))
    todo = []
    rv = T / f"revue_{ax}.txt"
    if rv.exists():
        for l in rv.read_text(encoding="utf-8").splitlines():
            m = re.match(r"\s*V\|([^|]*)\|VAGUE\|(.*)", l)
            if m and m.group(1).strip() in ann:
                todo.append((m.group(1).strip(), m.group(2).strip()))
    todo += [(c, "renvoi a remplacer") for c, a in ann.items() if "a lire dans le code" in (a["condition"] + a["si_dernier_vrai"]).lower()]
    keys = list(dict.fromkeys(c for c, _ in todo))
    why = dict(todo)
    done = 0
    for i in range(0, len(keys), 10):
        b = keys[i:i + 10]
        items = "\n\n".join("# %d: %s\nCritique : %s\nAncien : %s\n%s\n%s" % (keys.index(c), c, why[c][:160], ann[c]["condition"][:200], ann[c]["code"][:300], ctx(ann[c])) for c in b)
        for l in post(FIX.format(items=items)).splitlines():
            m = re.match(r"\s*N\|(\d+)\|(.*?)\|(.*)$", l)
            if m and int(m.group(1)) < len(keys):
                c = keys[int(m.group(1))]
                ann[c]["condition"], ann[c]["si_dernier_vrai"] = m.group(2).strip(), m.group(3).strip()
                done += 1
    json.dump(ann, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(ax, "a reprendre", len(keys), "repris", done)
