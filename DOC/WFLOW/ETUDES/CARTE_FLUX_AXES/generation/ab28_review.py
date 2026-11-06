# -*- coding: utf-8 -*-
"""Relecture finale : nouvel echantillon sur les 4 cartes, cle = numero pour eviter les pertes."""
import csv, json, random, re, urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

T = Path(r"C:\Users\ZEDVICTUS\.claude\jobs\ebe3ca88\tmp\carte")
WT = Path(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\.claude\worktrees\carte-flux")
D = WT / "DOC/WFLOW/ETUDES/CARTE_FLUX_AXES"
ST = {p.name: p for p in (WT / "CODE").rglob("*.st") if "CODE_BACKUP" not in str(p)}
LOC = re.compile(r"\b[\w]+\.st:\d+")
random.seed(23)


def post(p):
    d = {"model": "deepseek-v4.1-flash:cloud", "prompt": p, "stream": False, "think": False, "options": {"num_ctx": 64000, "num_predict": 5000, "temperature": 0}}
    rq = urllib.request.Request("http://localhost:11434/api/generate", data=json.dumps(d).encode("utf-8"), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(rq, timeout=280) as r:
        return json.loads(r.read().decode("utf-8")).get("response", "")


def review(ax):
    rows = [r for r in csv.DictReader(open(D / f"CARTE_{ax}.csv", encoding="utf-8-sig"), delimiter=";") if LOC.search(r["code"])]
    sample = random.sample(rows, min(45, len(rows)))
    res = []
    for k in range(0, len(sample), 15):
        b = sample[k:k + 15]
        code = []
        for r in b:
            for loc in LOC.findall(r["code"])[:2]:
                f, n = loc.split(":")
                n = int(n)
                x = ST[f].read_text(encoding="utf-8-sig", errors="replace").splitlines()
                code.append("## %s\n%s" % (loc, "\n".join(x[max(0, n - 7):n + 6])))
        p = "Relis ces annotations d'un flux PLC face au code. Une affectation de structure complete copie chaque membre : ce n'est pas une erreur. Rends une ligne par numero, sans autre texte : V|numero|OK ou FAUX ou VAGUE|raison courte.\n\n" + "\n".join(
            "%d: %s | condition: %s | si dernier vrai: %s" % (i, r["chemin"], r["condition"], r["si_dernier_vrai"]) for i, r in enumerate(b)) + "\n\n# Code\n" + "\n".join(code)
        t = post(p)
        for m in re.finditer(r"V\|(\d+)\|(OK|FAUX|VAGUE)\|?(.*)", t):
            i = int(m.group(1))
            if i < len(b):
                res.append((b[i]["chemin"], m.group(2), m.group(3)[:150]))
    return ax, len(sample), res


tot = {"OK": 0, "FAUX": 0, "VAGUE": 0}
with ThreadPoolExecutor(4) as ex:
    for ax, n, res in ex.map(review, ("M1", "M2", "M3", "AU")):
        c = {k: sum(r[1] == k for r in res) for k in tot}
        for k in tot:
            tot[k] += c[k]
        print(ax, "echantillon", n, "notees", len(res), c)
        for r in res:
            if r[1] == "FAUX":
                print("   FAUX", r[0][-60:], "|", r[2])
print("TOTAL", tot)
