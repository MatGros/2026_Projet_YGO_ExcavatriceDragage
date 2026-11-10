# -*- coding: utf-8 -*-
"""Passe de correction : frontieres par regle, annotations floues relues avec contexte elargi."""
import csv, json, re, sys, urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

T = Path(r"C:\Users\ZEDVICTUS\.claude\jobs\ebe3ca88\tmp\carte")
WT = Path(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\.claude\worktrees\carte-flux")
ST = {p.name: p for p in (WT / "CODE").rglob("*.st") if "CODE_BACKUP" not in str(p)}
CACHE = {}


def L(f):
    if f not in CACHE:
        CACHE[f] = ST[f].read_text(encoding="utf-8-sig", errors="replace").splitlines() if f in ST else []
    return CACHE[f]


def post(p):
    d = {"model": "deepseek-v4.1-flash:cloud", "prompt": p, "stream": False, "think": False, "options": {"num_ctx": 32000, "num_predict": 6000, "temperature": 0}}
    rq = urllib.request.Request("http://localhost:11434/api/generate", data=json.dumps(d).encode("utf-8"), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(rq, timeout=280) as r:
        return json.loads(r.read().decode("utf-8")).get("response", "")


VAGUE = re.compile(r"a lire dans le code|selon sa logique|logique interne|^$", re.I)
P = """Pour chaque noeud d'un flux PLC, rends exactement une ligne : N|numero|CONDITION|SI_DERNIER_VRAI
CONDITION : conditions reelles lues dans le code fourni, en francais court, en citant les variables exactes, y compris les branches IF. SI_DERNIER_VRAI : variable ou bloc aval a verifier. Si un noeud est une simple recopie ou entree, dis-le et nomme sa source. N'ecris jamais "a lire dans le code". Pas de | dans les textes. Aucune phrase hors de ces lignes.

{items}
"""


def ctx(a):
    out = []
    for loc in re.findall(r"\b[\w]+\.st:\d+", a["code"])[:2]:
        f, n = loc.split(":")
        n = int(n)
        out.append("--- %s\n%s" % (loc, "\n".join(x.rstrip() for x in L(f)[max(0, n - 14):n + 10])))
    return "\n".join(out)


for ax in ("M1", "M2", "M3"):
    ann = json.load(open(T / f"annot_{ax}.json", encoding="utf-8"))
    rows = {r["chemin"]: r for r in csv.DictReader(open(T / f"cone_{ax}.csv", encoding="utf-8"), delimiter=";")}
    front = 0
    todo = []
    for c, a in ann.items():
        if a["code"].strip().endswith("entree liee a :"):
            a["condition"] = "Hors de cet axe ou produit en amont de la frontiere : voir la carte de l'axe concerne ou PRG_03"
            a["si_dernier_vrai"] = "Reprendre le parcours dans la carte de l'axe concerne"
            front += 1
        elif a["code"].startswith("entree liee a"):
            src = a["code"].replace("entree liee a :", "").strip()
            a["condition"] = "Entree recue depuis : " + src
            a["si_dernier_vrai"] = "Comparer avec la source : un ecart indique un probleme de liaison"
        elif VAGUE.search(a["condition"]):
            todo.append(c)
    batches = [todo[i:i + 12] for i in range(0, len(todo), 12)]

    def run(b):
        items = "\n\n".join("# %d: %s\n%s\n%s" % (todo.index(c), c, ann[c]["code"][:300], ctx(ann[c])) for c in b)
        return post(P.format(items=items))

    done = 0
    for attempt in range(2):
        with ThreadPoolExecutor(5) as ex:
            texts = list(ex.map(run, batches))
        for t in texts:
            for l in t.splitlines():
                m = re.match(r"\s*N\|(\d+)\|(.*?)\|(.*)$", l)
                if m and int(m.group(1)) < len(todo):
                    c = todo[int(m.group(1))]
                    ann[c]["condition"], ann[c]["si_dernier_vrai"] = m.group(2).strip(), m.group(3).strip()
                    done += 1
        rest = [c for c in todo if VAGUE.search(ann[c]["condition"])]
        batches = [rest[i:i + 12] for i in range(0, len(rest), 12)]
        if not rest:
            break
    json.dump(ann, open(T / f"annot_{ax}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(ax, "frontieres", front, "reprises", len(todo), "encore floues", sum(bool(VAGUE.search(a["condition"])) for a in ann.values()))
