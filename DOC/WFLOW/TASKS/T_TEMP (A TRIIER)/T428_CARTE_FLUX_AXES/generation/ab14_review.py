# -*- coding: utf-8 -*-
import csv, json, random, re, urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

T = Path(r"C:\Users\ZEDVICTUS\.claude\jobs\ebe3ca88\tmp\carte")
WT = Path(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\.claude\worktrees\carte-flux")
D = WT / "DOC/WFLOW/ETUDES/CARTE_FLUX_AXES"
ST = {p.name: p for p in (WT / "CODE").rglob("*.st") if "CODE_BACKUP" not in str(p)}
cones = {ax: {r["chemin"]: r for r in csv.DictReader(open(T / f"cone_{ax}.csv", encoding="utf-8"), delimiter=";")} for ax in ("M1", "M2", "M3")}
# 1. commandes declarees vs atteintes
decl = set()
for n, p in ST.items():
    if not n.startswith("ST_"):
        continue
    for l in p.read_text(encoding="utf-8-sig", errors="replace").splitlines():
        m = re.match(r"\s*((?:Btn|Tgl|Sel|Set)\w+)\s*:", l)
        if m:
            decl.add(m.group(1))
reach = {c.split(".")[-1] for ax in cones for c in cones[ax]}
print("declarees", len(decl), "atteintes", len(decl & reach))
print("JAMAIS ATTEINTES:", sorted(decl - reach))
# 2. maillons connus
KNOWN = {"M1": ["SyncOperationPermit", "WinchBothFinalRequestsCoherent", "CommonMaxStepAscent", "DirectionChangePending", "RestartInhibit", "AuthorizedStep", "EffectivePermitM1_Ascent"],
         "M2": ["SyncOperationPermit", "ManualBucketJogActive", "OffsetTargetM", "M2_LimitShift", "RestartInhibit", "EffectivePermitM2_Ascent"],
         "M3": ["M3_ReqTremie_Active", "M3_TremieHardStopActive", "RestartInhibit", "M3_MaintN2", "DriveFreqCmdWord", "TremieLimitClear"]}
for ax, names in KNOWN.items():
    print(ax, {n: [c for c in cones[ax] if c.endswith("." + n)][:1] != [] for n in names})
# 3. relecture d'echantillon
random.seed(7)


def post(p):
    d = {"model": "deepseek-v4.1-flash:cloud", "prompt": p, "stream": False, "think": False, "options": {"num_ctx": 64000, "num_predict": 5000}}
    rq = urllib.request.Request("http://localhost:11434/api/generate", data=json.dumps(d).encode("utf-8"), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(rq, timeout=280) as r:
        return json.loads(r.read().decode("utf-8")).get("response", "")


def review(ax):
    rows = list(csv.DictReader(open(D / f"CARTE_{ax}.csv", encoding="utf-8-sig"), delimiter=";"))
    sample = random.sample([r for r in rows if r["code"] and "entree liee" not in r["code"]], 60)
    files = sorted({l.split(":")[0].strip() for r in sample for l in re.findall(r"\b[\w]+\.st:\d+", r["code"])})
    ctx = []
    for r in sample:
        for loc in re.findall(r"\b[\w]+\.st:\d+", r["code"])[:2]:
            f, n = loc.split(":")
            L = ST[f].read_text(encoding="utf-8-sig", errors="replace").splitlines()
            n = int(n)
            ctx.append("## %s\n%s" % (loc, "\n".join(L[max(0, n - 6):n + 4])))
    p = "Relis strictement ces annotations d'un flux PLC face au code cite. Une affectation de structure complete copie bien chaque membre : ce n'est pas une erreur. Pour CHAQUE ligne rends V|chemin|OK ou FAUX ou VAGUE|correction courte. Sans autre texte.\n\n# Annotations\n" + "\n".join(
        "%s | %s | condition: %s | si dernier vrai: %s" % (r["chemin"], r["code"][:300], r["condition"], r["si_dernier_vrai"]) for r in sample) + "\n\n# Code\n" + "\n".join(ctx)
    t = post(p)
    (T / f"revue_{ax}.txt").write_text(t, encoding="utf-8")
    v = re.findall(r"V\|[^|]*\|(OK|FAUX|VAGUE)", t)
    return ax, len(v), {k: v.count(k) for k in ("OK", "FAUX", "VAGUE")}


with ThreadPoolExecutor(3) as ex:
    for r in ex.map(review, ("M1", "M2", "M3")):
        print(r)
print("--- FAUX")
for ax in ("M1", "M2", "M3"):
    for l in (T / f"revue_{ax}.txt").read_text(encoding="utf-8").splitlines():
        if "|FAUX" in l:
            print(ax, l[:210])
