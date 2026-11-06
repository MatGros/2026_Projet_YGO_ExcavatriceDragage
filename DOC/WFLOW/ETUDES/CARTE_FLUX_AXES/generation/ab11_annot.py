# -*- coding: utf-8 -*-
"""Annotation des noeuds d'interface d'un axe, par lots, avec controle de couverture."""
import csv, json, re, sys, time, urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

C = Path(r"C:\Users\ZEDVICTUS\.claude\jobs\ebe3ca88\tmp\carte")
REPO = Path(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\.claude\worktrees\carte-flux")
ax = sys.argv[1]
ST = {p.name: p for p in (REPO / "CODE").rglob("*.st") if "CODE_BACKUP" not in str(p)}
rows = {r["chemin"]: r for r in csv.DictReader(open(C / f"cone_{ax}.csv", encoding="utf-8"), delimiter=";")}
tree = json.load(open(C / f"tree_{ax}.json"))
nodes = sorted(set(tree["iface"]) | {n for p in tree["paths"].values() for n in p}, key=lambda c: (int(rows[c]["depth"]), c))
CACHE = {}


def lines(f):
    if f not in CACHE:
        CACHE[f] = ST[f].read_text(encoding="utf-8-sig", errors="replace").splitlines() if f in ST else []
    return CACHE[f]


EDGES = json.load(open(C / f"edges_{ax}.json"))
UP = {}
for _a, _b in EDGES:
    UP.setdefault(_a, []).append(_b)


def expr(c):
    if not rows[c]["loc"]:
        return "entree liee a : " + ", ".join(sorted(UP.get(c, []))[:3])
    out = []
    for loc in rows[c]["loc"].split()[:2]:
        f, n = loc.split(":")
        n = int(n)
        L = lines(f)
        if 0 < n <= len(L):
            stmt = ""
            for k in range(n - 1, min(n + 9, len(L))):
                stmt += " " + re.sub(r"//.*$", "", L[k])
                if ";" in L[k]:
                    break
            out.append("%s = %s" % (loc, re.sub(r"\s+", " ", stmt).strip()[:420]))
    return " ;; ".join(out)


ETAGES = "SOURCE MODE ARBITRAGE DEMANDE PERMIS SECURITE BARRIERE SORTIE RETOUR MESURE REGLAGE BYPASS"
PROMPT = """Machine reelle : excavatrice de dragage, CODESYS, axe {ax}. Pour chaque noeud du flux ci-dessous, rends exactement une ligne :
N|numero|ETAGE|CONDITION|SI_DERNIER_VRAI
ETAGE parmi : {et}. CONDITION : ce qu'il faut pour que ce noeud soit actif, en francais court, uniquement d'apres la ligne de code citee et le nom ; si la ligne ne suffit pas, ecris "a lire dans le code". SI_DERNIER_VRAI : ce que le mainteneur doit chercher en aval si ce noeud est bon mais pas le suivant.
Pas de | dans les textes. Aucune phrase hors de ces lignes. N'invente aucune variable. Une ligne par numero, sans en sauter.

{items}
"""


def post(prompt):
    p = {"model": "deepseek-v4.1-flash:cloud", "prompt": prompt, "stream": False, "think": False, "options": {"num_ctx": 32000, "num_predict": 9000}}
    rq = urllib.request.Request("http://localhost:11434/api/generate", data=json.dumps(p).encode("utf-8"), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(rq, timeout=280) as r:
        return json.loads(r.read().decode("utf-8")).get("response", "")


items = [(i, c) for i, c in enumerate(nodes)]
batches = [items[k:k + 40] for k in range(0, len(items), 40)]


def run(b):
    txt = "\n".join("%d: %s [%s] %s" % (i, c, rows[c]["section"], expr(c)) for i, c in b)
    return post(PROMPT.format(ax=ax, et=ETAGES, items=txt))


res = {}
for attempt in range(3):
    todo = [b for b in batches if any(i not in res for i, _ in b)]
    if not todo:
        break
    with ThreadPoolExecutor(5) as ex:
        for text in ex.map(run, todo):
            for l in text.splitlines():
                m = re.match(r"\s*N\|(\d+)\|([A-Z]+)\|(.*?)\|(.*)$", l)
                if m and m.group(2) in ETAGES.split():
                    res[int(m.group(1))] = (m.group(2), m.group(3).strip(), m.group(4).strip())
missing = [c for i, c in items if i not in res]
out = {c: dict(etage=res[i][0], condition=res[i][1], si_dernier_vrai=res[i][2], code=expr(c), section=rows[c]["section"], classe=rows[c]["classe"], visible=rows[c]["visible"] == "True", depth=int(rows[c]["depth"])) for i, c in items if i in res}
json.dump(out, open(C / f"annot_{ax}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=0)
from collections import Counter
print(ax, "noeuds", len(items), "annotes", len(out), "manquants", len(missing), missing[:6])
print(Counter(v["etage"] for v in out.values()).most_common())
print("a lire dans le code:", sum("a lire" in v["condition"].lower() for v in out.values()))
