# -*- coding: utf-8 -*-
"""Genere la carte d'un axe : referentiel, tableau par etage, arbre par commande. Controle la couverture."""
import csv, json, re, sys
from collections import Counter, defaultdict
from pathlib import Path

T = Path(r"C:\Users\ZEDVICTUS\.claude\jobs\ebe3ca88\tmp\carte")
DEST = Path(r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\.claude\worktrees\carte-flux\DOC\WFLOW\ETUDES\CARTE_FLUX_AXES")
DEST.mkdir(parents=True, exist_ok=True)
ax = sys.argv[1]
rows = {r["chemin"]: r for r in csv.DictReader(open(T / f"cone_{ax}.csv", encoding="utf-8"), delimiter=";")}
tree = json.load(open(T / f"tree_{ax}.json"))
ann = json.load(open(T / f"annot_{ax}.json", encoding="utf-8"))
ORDER = ["SOURCE", "MODE", "REGLAGE", "BYPASS", "ARBITRAGE", "DEMANDE", "PERMIS", "SECURITE", "BARRIERE", "SORTIE", "MESURE", "RETOUR"]


def etage(c, llm):
    r = rows[c]
    if int(r["depth"]) == 0 or "Protector" in c:
        return "SORTIE"
    if r["classe"] == "BYPASS":
        return "BYPASS"
    if r["classe"] == "REGLAGE":
        return "REGLAGE"
    if r["classe"] == "COMMANDE" or "instJoystick" in c:
        return "SOURCE"
    if re.search(r"OutputInterlock|instSyncContactorFinal", c):
        return "BARRIERE"
    if re.search(r"instSafety|instWinchSync", c):
        return "SECURITE"
    if re.search(r"instArb", c):
        return "ARBITRAGE"
    if re.search(r"instEncoder|instPosDecoder", c):
        return "MESURE"
    if re.search(r"instWinchM\d|instTranslationM3|instBucket", c):
        return "DEMANDE"
    if c.startswith("PRG_03_Modes_Cycle") or c.startswith("GVL_IHM.Modes"):
        return "MODE"
    if re.search(r"Brake.*_DI|Contactor.*_DI|Feedback|BrakeIsOpen", c):
        return "RETOUR"
    if re.search(r"\.HwIn\.|\.HwReal\.|_DI$", c):
        return "MESURE"
    return llm


def statut(c):
    r = rows[c]
    if r["visible"] == "True":
        return "VISIBLE"
    if r["section"] in ("VAR", "VAR_OUTPUT", "VAR_INPUT", "VAR_IN_OUT", "VAR_GLOBAL"):
        return "LISIBLE?"
    return "A CONTROLER"


def esc(s):
    return (s or "").replace("|", "/")


nodes = {}
for c, a in ann.items():
    nodes[c] = dict(a, etage=etage(c, a["etage"]), statut=statut(c))
pathnodes = {n for p in tree["paths"].values() for n in p}
missing = sorted(pathnodes - set(nodes))
cmd = sorted(c for c in rows if rows[c]["classe"] == "COMMANDE")
regl = sorted(c for c in rows if rows[c]["classe"] == "REGLAGE")
byp = sorted(c for c in rows if rows[c]["classe"] == "BYPASS")
mesu = sorted(c for c in nodes if nodes[c]["etage"] in ("MESURE", "RETOUR") and re.search(r"HwIn|HwReal|_DI$", c))
out = tree["outs"]
st = Counter(n["statut"] for n in nodes.values())
L = []
A = L.append
A(f"# Carte de flux {ax}\n")
A("> Généré depuis `CODE/`. Chaîne, `fichier:ligne` et code cité : extraction mécanique. Colonnes de lecture : rédigées puis à relire. Aucune preuve sur automate.\n")
A(f"**Couverture :** {len(rows)} variables dans le graphe, {len(nodes)} maillons d'interface annotés, {len(tree['paths'])} points d'entrée reliés à une sortie, {len(missing)} maillon de chemin non annoté.\n")
A(f"**Statuts :** {dict(st)}. `VISIBLE` = chemin du snapshot ou copie directe. `LISIBLE?` = variable existante, lecture directe à confirmer sur automate.\n")
A("## 1. Référentiel\n")
A(f"### Actionneurs ({len(out)})\n")
A("\n".join(f"- `{o}`" for o in sorted(out)) + "\n")
A(f"### Commandes atteintes ({len(cmd)})\n")
A("\n".join(f"- `{c}` — {'VISIBLE' if rows[c]['visible']=='True' else 'non visible'}" for c in cmd) + "\n")
A(f"### Réglages ({len(regl)})\n")
A("\n".join(f"- `{c}`" for c in regl) + "\n")
A(f"### Bypass ({len(byp)})\n")
A("\n".join(f"- `{c}`" for c in byp) + "\n")
A(f"### Mesures et retours physiques ({len(mesu)})\n")
A("\n".join(f"- `{c}` — {nodes[c]['statut']}" for c in mesu) + "\n")
A("## 2. Maillons par étage (de la source vers l'actionneur)\n")
for e in ORDER:
    g = sorted([c for c, n in nodes.items() if n["etage"] == e], key=lambda c: (-int(rows[c]["depth"]), c))
    if not g:
        continue
    A(f"### {e} ({len(g)})\n")
    A("| Maillon | Statut | Code | Condition | Si dernier vrai |\n|---|---|---|---|---|")
    for c in g:
        n = nodes[c]
        A(f"| `{c}` | {n['statut']} | `{esc(n['code'])[:150]}` | {esc(n['condition'])} | {esc(n['si_dernier_vrai'])} |")
    A("")
A("## 3. Arbre par commande (chemin le plus court vers une sortie)\n")
A("Parcours de haut en bas : si la valeur attendue s'arrête à un maillon, chercher dans la colonne `Si dernier vrai` du maillon. Les autres branches sont dans `edges` du graphe.\n")
for c in sorted(tree["paths"], key=lambda x: (rows[x]["classe"] != "COMMANDE", x)):
    if rows[c]["classe"] != "COMMANDE":
        continue
    A(f"### `{c}`\n")
    for i, m in enumerate(reversed(tree["paths"][c])):
        n = nodes.get(m, {})
        A(f"{i+1}. **{n.get('etage','?')}** `{m}` — {n.get('statut','?')}")
    A("")
(DEST / f"CARTE_{ax}.md").write_text("\n".join(L), encoding="utf-8")
with open(DEST / f"CARTE_{ax}.csv", "w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f, delimiter=";")
    w.writerow(["chemin", "etage", "statut", "profondeur", "code", "condition", "si_dernier_vrai"])
    for c, n in sorted(nodes.items(), key=lambda kv: (ORDER.index(kv[1]["etage"]) if kv[1]["etage"] in ORDER else 99, -int(rows[kv[0]]["depth"]), kv[0])):
        w.writerow([c, n["etage"], n["statut"], rows[c]["depth"], n["code"], n["condition"], n["si_dernier_vrai"]])
print(ax, "noeuds", len(nodes), "statuts", dict(st), "etages", Counter(n["etage"] for n in nodes.values()).most_common(), "non annotes", len(missing), "octets md", (DEST / f"CARTE_{ax}.md").stat().st_size)
