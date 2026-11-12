"""Tire un échantillon reproductible d'écritures réelles (Write/Edit) des transcripts Claude.

Lecture seule des transcripts. Produit echantillon_a_etiqueter.json avec label=null :
c'est à l'humain d'étiqueter (bon / violation / incertain). Seed fixe pour rejouer le même tirage.
"""
import glob, json, os, random, sys
sys.dont_write_bytecode = True
REPO = "C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/"
SEED, N = 20261112, 20
src = glob.glob(os.path.expanduser("~/.claude/projects/C---MGS-DEV-2026-Projet-YGO-ExcavatriceDragage/*.jsonl"))
pool = []
for f in sorted(src):
    sid = os.path.basename(f).replace(".jsonl", "")
    for n, line in enumerate(open(f, encoding="utf-8", errors="replace")):
        try: e = json.loads(line)
        except Exception: continue
        if e.get("type") != "assistant": continue
        for b in (e.get("message", {}).get("content") or []):
            if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") in ("Write", "Edit"):
                p = (b.get("input", {}).get("file_path") or "").replace("\\", "/")
                rel = p[len(REPO):] if p.startswith(REPO) else p
                pool.append({"session": sid[:8], "ligne": n, "outil": b["name"], "chemin": rel})
rng = random.Random(SEED)
pick = rng.sample(pool, min(N, len(pool)))
out = [dict(id=f"S{i+1:02d}", **x, label=None) for i, x in enumerate(pick)]
dst = os.path.join(os.path.dirname(__file__), "echantillon_a_etiqueter.json")
json.dump({"seed": SEED, "population": len(pool), "consigne": "label: bon | violation | incertain", "items": out},
          open(dst, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("population:", len(pool), "| tirés:", len(out), "| fichier:", dst)
