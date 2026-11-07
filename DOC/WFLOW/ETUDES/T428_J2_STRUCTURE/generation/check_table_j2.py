# -*- coding: utf-8 -*-
"""Controle J2 T428 : couverture, decisions tracees, ancres, doublons, meme ordre sur les 3 axes.
Usage : python check_table_j2.py <TABLE_CORRESPONDANCE.csv> <racine depot>. Code retour 1 si un test echoue."""
import collections, csv, re, sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
table, repo = Path(sys.argv[1]), Path(sys.argv[2])
rows = list(csv.DictReader(open(table, encoding="utf-8-sig"), delimiter=";"))
by = {r["chemin_actuel"]: r for r in rows}
fails = []


def t(nom, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + nom + ((" : " + str(detail)[:300]) if detail else ""))
    if not ok:
        fails.append(nom)


s = lambda c: c.replace("GVL_Troubleshooting.", "")
listed = [s(x) for x in (repo / "TOOLS/PLC_CSV_SNAPSHOT/variable_lists/troubleshooting_variables.txt").read_text(encoding="utf-8").split()]
t("AC1 toutes les variables du snapshot ont une decision", all(p in by for p in listed), [p for p in listed if p not in by][:5])
t("Pas de ligne en double", len(by) == len(rows))
ok = {"GARDER", "RETRAIT_COPIE", "RETRAIT_NEGATION", "RETRAIT_NON_ECRITE", "RETRAIT_NON_APPLICABLE", "A_VALIDER", "CABLER_J3", "CABLER_J4", "AJOUT_J3"}
t("Decisions connues", all(r["decision"] in ok for r in rows))
ret = [r for r in rows if r["decision"].startswith("RETRAIT")]
t("AC6 chaque retrait cite une raison de panne", all("panne" in r["raison"].lower() or r["decision"] in ("RETRAIT_NON_ECRITE", "RETRAIT_NON_APPLICABLE") for r in ret))
t("AC6 aucun retrait au motif figee", not [r for r in ret if re.search(r"fig[ée]e", r["raison"], re.I)])
anc = [r for r in ret if r["decision"] in ("RETRAIT_COPIE", "RETRAIT_NEGATION")]
bad = [r["chemin_actuel"] for r in anc if r["variable_conservee"] not in by or by[r["variable_conservee"]]["decision"].startswith("RETRAIT")]
t("Ancres existantes et conservees", not bad, bad[:6])
kept = [r for r in rows if not r["decision"].startswith("RETRAIT")]
g = collections.defaultdict(list)
for r in kept:
    if r["classe"] == "COPIE" and r["regle"] != "R4" and not r["decision"].startswith("CABLER"):
        g[r["source"]].append(r["chemin_actuel"])
dup = {k: v for k, v in g.items() if len(v) > 1}
t("0 doublon sans raison parmi les conservees", not dup, list(dup.items())[:3])
axes = ("AXE.M1", "AXE.M2", "AXE.M3")
vide = [(a, e) for a in axes for e in range(1, 11) if not any(r["zone"] == a and r["etape"] == str(e) for r in kept)]
t("AC2 les 10 etapes existent sur les 3 axes", not vide, vide)
hors = [r["chemin_actuel"] for r in kept if r["zone"].startswith("AXE") and r["etape"] not in {str(i) for i in range(1, 11)}]
t("Etape valide pour toute variable d'axe", not hors, hors[:5])
ordre = []
for r in rows:
    if r["zone"] in axes and (r["zone"], int(r["etape"])) not in ordre:
        ordre.append((r["zone"], int(r["etape"])))
t("AC2 meme ordre sur les 3 axes", [e for a, e in ordre if a == "AXE.M1"] == [e for a, e in ordre if a == "AXE.M2"] == [e for a, e in ordre if a == "AXE.M3"] == list(range(1, 11)))
code = "\n".join(p.read_text(encoding="utf-8", errors="replace") for p in (repo / "CODE").rglob("*.st"))
add = [r["chemin_actuel"] for r in rows if r["decision"] == "AJOUT_J3" and not re.search(r"\b" + re.escape(r["chemin_actuel"].rsplit(".", 1)[-1]) + r"\b", code)]
t("Variables ajoutees presentes dans le code", not add, add)
C = collections.Counter(r["decision"] for r in rows)
print("BILAN", dict(C), "| snapshot", len(listed), "->", len(kept))
sys.exit(1 if fails else 0)
