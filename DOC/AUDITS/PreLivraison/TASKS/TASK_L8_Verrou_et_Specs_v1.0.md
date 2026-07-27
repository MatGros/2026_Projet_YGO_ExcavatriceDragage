> # ❌ FICHE ANNULEE (2026-07-27) — NE PAS EXECUTER
>
> Remplacee par `TASK_L7-L8_HwSim_Verrou_Specs_v2.0.md`.
> Motif : le comparateur `FB_HwCompare`/`HwDelta` est abandonne — la lecture cote a cote
> `HwReal`/`HwSim`/`HwIn` en vue instance et `PRG_11_Troubleshooting` couvrent le besoin
> sans ajouter de couche. Le reste (verrou + specs) est repris dans la v2.0.

# 🔒 FICHE DE TÂCHE — Lot L8 : verrou anti-récidive + remise à niveau des specs

> 🤖 Agent d'implémentation externe · 📅 2026-07-27 · **v1.0** · 🟢 risque faible (outillage + doc)
> ⏱️ **Prérequis** : lot L7 appliqué. Peut être **enchaîné directement** après L7.
> 📖 **Contexte et règles : §1 et §4 de
> [`TASK_L2-L3_Retrait_GVL_PLC_Tests_v1.0.md`](TASK_L2-L3_Retrait_GVL_PLC_Tests_v1.0.md)**.
> ⚠️ Ce lot ne touche **aucune logique automate**. Uniquement outillage Python + documentation.

---

## 1. 🎯 Objectif

Verrouiller l'acquis des lots L2→L7 pour qu'il ne se dégrade pas, et remettre les specs en
cohérence avec le code — aujourd'hui elles décrivent une architecture qui n'existe plus.

---

## 2. 🔧 Partie A — outillage (`TOOLS/AGENT_WORKFLOW/scripts/`)

### A1. Réparer `check_code_style.py` (constat **C3** de l'audit)

Le contrôle produit **36 faux positifs sur 36** depuis la restructuration `Cmd`/`State`/`Cfg` de
`GVL_IHM`. La regex capture `State` / `Safety` comme nom d'instance :

```python
VAR_OUTPUT_WRITE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\.(Ready|Busy|Done|Error|ErrorId|State|StateAtError)\s*:=")
```

`GVL_IHM.M1TreuilRetenue.State.Ready := …` (miroir de supervision **légitime**, Bridge Pattern
assumé) est classé « écriture croisée illégale ».

**À faire** : exclure les chemins commençant par `GVL_IHM.`, et rafraîchir
`KNOWN_VAR_OUTPUT_VIOLATIONS` sur les chemins actuels (l'entrée
`MAIN/PRG_09_Supervision.st` liste encore `M1TreuilRetenue.Ready`, `M2TreuilBucket.*` — noms qui
n'existent plus).

> 🎯 **Un garde-fou qui crie tout le temps n'est plus un garde-fou.** Tant que C3 n'est pas
> corrigé, la règle A2 ci-dessous ne prouverait rien.

### A2. Nouvelle règle — confinement de la simulation

Ajouter un contrôle : **toute référence à `GVL_Simulation.` est interdite** sauf dans

| Emplacement autorisé | Raison |
|---|---|
| `CODE/SIMULATION/**` | le banc lui-même |
| `CODE/MAIN/PRG_00_Inputs.st` | la frontière unique (§0bis) |
| `CODE/MAIN/PRG_09_Supervision.st` | publication d'état vers l'IHM |
| `CODE/MAIN/PRG_11_Troubleshooting.st` | espion de diagnostic (lecture seule) |

Message d'erreur explicite, citant `fichier:ligne` et rappelant la doctrine.
Intégrer au `run_all_gates.py` comme les autres gates.

### A3. Contrôle « zéro forçage hybride »

Interdire le motif `OR (GVL_Simulation.<flag> AND …)` **partout**, sans exception : c'est la forme
qui force un capteur à l'état sain et qui a masqué le bug de polarité de frein (C1).

### A4. Nettoyage

Supprimer le doublon `CODE/CODE/CODE_Bundle.xml` (chemin dupliqué par erreur) et vérifier que le
générateur écrit bien dans `CODE/CODE_Bundle.xml`.

---

## 3. 📄 Partie B — documentation

### B1. `AF_Partie-13` → **v2.0** (réécriture complète)

L'actuelle `v1.4` porte un bandeau ⛔ PÉRIMÉ. Elle doit être **remplacée**, pas rafistolée.

Contenu attendu :

| § | Contenu |
|---|---|
| Rôle | Pourquoi une simulation, et ce qu'elle **n'est pas** (ce n'est ni un bypass, ni un outil de forçage) |
| **Doctrine 3 outils** | Bypass IHM = ignorer un défaut sur matériel présent · Simulation = fabriquer une valeur pour matériel absent · Force natif CODESYS = injecter une panne ponctuelle |
| Architecture | Frontière unique : `HwReal` / `HwSim` / `HwIn`, les 4 `IF` d'aiguillage, `FB_SimBench`, schéma du flux |
| Granularité | 1 bit maître + 4 domaines, **polarité positive**. Règle : un domaine est simulé **OU** réel, jamais un mélange |
| Modèles | Rôle de chaque `FB_Sim_*` composé par le banc, et **conventions de polarité** (notamment `Mx_BrakeIsOpen := BrakeCmd`, sans `NOT` — expliquer pourquoi) |
| Comparateur | `HwDelta` : critère objectif de bascule, verdict à l'arrêt stabilisé, grandeurs logiques seulement |
| Historique | Ce qui a été retiré (`GVL_PLC_Tests`, `FB_Sim_DigitalMirror`, 25 flags `*IsReal`) et **pourquoi** — le REX du bug C1 doit y figurer |
| Application | Note d'import CODESYS |

Sources : `AUDITS/PreLivraison/PLAN_Rationalisation_Simulation_v1.0.md`, les rapports `RAPPORT_L5/L6/L7`,
et le code réel (`FB_SimBench.st`, `PRG_00_Inputs.st` §0/§0bis).

### B2. `AF_Partie-06` → **v1.7**

Le principe (`FB_Input`, filtre 20 ms, inversion NO/NC) **reste valable** — ajouter ce qui est
en amont : chaîne `%IX → HwReal → HwIn → FB_Input`, acquisition centralisée en `PRG_00` §0,
nouvelle convention de nommage des E/S.

### B3. `NAMING_CONVENTION.md`

Formaliser la convention appliquée le 2026-07-27 :

```
<Domaine>_<ÉtatQuandTRUE>_DI      M1_BrakeIsOpen_DI    → TRUE = frein ouvert
<Domaine>_<ActionCommandée>_RQ    M1_BrakeRelease_RQ   → TRUE = desserrage commandé
```
Avec la justification : un nom muet sur sa polarité a coûté un défaut réel (C1).
Source : `AUDITS/PreLivraison/TABLE_Renommage_IO_v1.0.md`.

### B4. `AF_Partie-01`

Mettre à jour les noms de la chaîne de sécurité : `PowerContactorEngaged_DI` (⚠️ ce n'est **pas**
la boucle AU), `EmergencyChainClosed_DI`, `PowerKeepAlive_A/B_RQ` (fail-safe : `TRUE` = puissance
maintenue).

### B5. `VERSION_HISTORY.md`

Ajouter le jalon du chantier : lots T80 + L2→L8, ce qui a changé, les commits de référence.

### B6. `CLAUDE.md`

Mettre à jour l'arborescence CODESYS : `PRG_11_Troubleshooting`, `_TYPES/ST_Hw*`, `FB_SimBench`,
et retirer les mentions de `GVL_PLC_Tests`.

---

## 4. 📏 Style de rédaction (règle projet, à respecter)

| Document | Style |
|---|---|
| `AF_PartieN` (specs) | **Concis et technique, zéro perte d'information**, emoji comme repères visuels. La précision technique prime sur la brièveté |
| `NAMING_CONVENTION`, `VERSION_HISTORY`, `PLAN_TASK` | **Concis, direct, TDAH-friendly**, emoji, tokens minimaux. Tables/listes courtes > prose |

⚠️ **Convention de versionnage** : archiver la version précédente dans `ARCHIVES/Doc/` **avant**
d'incrémenter, puis mettre à jour toutes les références croisées (`CLAUDE.md`, liens inter-`AF_PartieN`).
Note : `ARCHIVES/Doc/` est gitignoré — les fichiers restent sur disque.

---

## 5. ⛔ Interdictions

- ❌ **Aucune modification de logique automate** — ce lot est outillage + doc
- ❌ Ne pas ajouter d'exemption globale au gate style : liste précise uniquement
- ❌ Ne pas supprimer l'historique des REX dans les specs : ils expliquent des décisions de sécurité
- ❌ Aucun commit

---

## 6. 📤 Livrable

`DOC/AUDITS/PreLivraison/TASKS/RAPPORT_L8_v1.0.md` :

- résultat de `run_all_gates.py` **avant / après** (le nombre de faux positifs doit tomber à 0)
- test de la règle A2 : introduire volontairement une référence interdite → le gate doit la
  détecter (puis retirer le test)
- liste des documents créés/incrémentés/archivés
- références croisées mises à jour
- tes alertes

### ✅ Critères de sortie

- [ ] `run_all_gates.py` PASS, **zéro faux positif**
- [ ] Règle de confinement `GVL_Simulation.` active et **testée**
- [ ] Règle « zéro forçage hybride » active
- [ ] `AF_Partie-13 v2.0` et `AF_Partie-06 v1.7` publiées, bandeaux ⛔/⚠️ retirés
- [ ] `NAMING_CONVENTION`, `AF_Partie-01`, `VERSION_HISTORY`, `CLAUDE.md` à jour
- [ ] Doublon `CODE/CODE/` supprimé
- [ ] Aucun fichier `CODE/**/*.st` modifié
