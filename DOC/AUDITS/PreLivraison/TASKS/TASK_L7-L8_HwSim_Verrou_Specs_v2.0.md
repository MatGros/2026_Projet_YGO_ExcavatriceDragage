# 🔒 FICHE DE TÂCHE — Lots L7 (réduit) + L8 : exposition `HwSim`, verrou anti-récidive, specs

> 🤖 **Agent d'implémentation externe — fiche autoportante, tu n'as besoin d'aucun historique.**
> 📅 2026-07-27 · **v2.0** — remplace `TASK_L7_Comparateur_HwDelta_v1.0.md` (❌ annulée) et
> `TASK_L8_Verrou_et_Specs_v1.0.md`. Ces deux fiches sont **caduques**, ne les suis pas.
> 🟢 Risque faible : **aucune logique automate n'est modifiée.**

---

## 1. 🏭 Contexte

Automate **CODESYS 3.5**, machine spéciale : **excavatrice de dragage** en carrière noyée.
~10 000 lignes de **ST** dans `CODE/`. 3 axes : **M1** treuil de retenue, **M2** treuil de benne,
**M3** translation (variateur AC600 EtherCAT). Sécurité : chaîne AU câblée + `PowerCutOff`
logiciel redondant A/B, blocs `FB_Safety_*`.

Orchestration séquentielle, tâche 10 ms : `PRG_00_Inputs` → … → `PRG_10_Outputs` →
`PRG_11_Troubleshooting` (espion de diagnostic, lecture seule).

⚠️ **Machine en cours de mise en service, livraison client imminente.** Prudence maximale.
⚠️ **L'utilisateur applique tout MANUELLEMENT** dans CODESYS. Tu modifies les fichiers du dépôt ;
tu ne compiles pas, tu ne déploies pas, tu ne commites pas.

### Ce qui vient d'être fait (contexte utile)

Un chantier de rationalisation vient de retirer une simulation qui était **diffuse** : ~46 points
d'injection répartis dans 8 programmes, dont des conditions `DI OR (SimActive AND NOT …IsReal)`
qui **forçaient un capteur à l'état sain**. Ce mécanisme a masqué un vrai bug de polarité de retour
frein (dit **C1**) : deux erreurs symétriques se compensaient, invisibles jusqu'au câblage réel.

L'architecture actuelle est une **frontière unique** :

```
   [%IX / PDO réels] ──► HwReal ─┐
                                  ├──► HwIn ──► PRG_00 §1 … PRG_10 ──► machine
   [FB_SimBench]     ──► HwSim ──┘
```

`GVL_Simulation` = 1 bit maître + 4 domaines (`SimWinchActive`, `SimTranslationActive`,
`SimOperatorActive`, `SimMachineActive`), en polarité positive. Un domaine est simulé **OU** réel,
jamais un mélange. L'aiguillage tient en **4 `IF`** dans `PRG_00_Inputs` §0bis.

### 📚 Lectures obligatoires

| Fichier | Pourquoi |
|---|---|
| `CLAUDE.md` | Règles projet, guardrails, style |
| `DOC/NAMING_CONVENTION.md` | PascalCase, pas de hongrois |
| `CODE/MAIN/PRG_00_Inputs.st` §0/§0bis | La frontière, telle qu'elle existe |
| `DOC/AUDITS/PreLivraison/PLAN_Rationalisation_Simulation_v1.0.md` | Le pourquoi du chantier |

---

## 2. 🎯 PARTIE A — exposer `HwSim` (petit lot, à faire en premier)

**But** : pouvoir lire côte à côte, en vue instance CODESYS, ce que dit le matériel (`HwReal`),
ce que le modèle de banc attend (`HwSim`) et ce que le programme utilise (`HwIn`). Les trois
structures ont **les mêmes champs** : la comparaison se fait à l'œil, sans aucun code.

**À faire, et rien de plus** :
- Déclarer `HwSim : ST_HardwareImage;` en `VAR_OUTPUT` de `PRG_00_Inputs`
- L'alimenter depuis les sorties de `instSimBench`, **après** son appel
- Vérifier que `HwSim` n'est **jamais** lu par la logique métier (c'est un point d'observation)

⛔ **Ne développe AUCUN comparateur**, aucun `HwDelta`, aucun compteur d'écarts, aucun champ IHM.
Une fiche précédente le demandait : **elle est annulée**. La vue instance suffit.

---

## 3. 🔧 PARTIE B — outillage (`TOOLS/AGENT_WORKFLOW/scripts/`)

### B1. Réparer `check_structure.py` — **blocage actuel du Gate 1**

Le script n'autorise que `AUDITS`, `CHECKLISTS`, `DIAGRAMS` sous `DOC/`, alors que
**`DOC/NAVBOARDS/` existe et est légitime** (référencé par le projet).

À faire : autoriser `NAVBOARDS`, et vérifier que les sous-dossiers récents passent aussi
(`DOC/AUDITS/PreLivraison/`, `DOC/AUDITS/PreLivraison/TASKS/`). C'est le script qui est en retard
sur la structure, pas l'inverse.

### B2. Réparer `check_code_style.py` (constat **C3**)

Le contrôle produit **36 faux positifs sur 36** depuis la restructuration `Cmd`/`State`/`Cfg` de
`GVL_IHM`. La regex capture `State` / `Safety` comme nom d'instance :

```python
VAR_OUTPUT_WRITE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\.(Ready|Busy|Done|Error|ErrorId|State|StateAtError)\s*:=")
```

`GVL_IHM.M1TreuilRetenue.State.Ready := …` est un **miroir de supervision légitime** (Bridge
Pattern assumé), classé à tort « écriture croisée illégale ».

À faire : exclure les chemins commençant par `GVL_IHM.`, et rafraîchir
`KNOWN_VAR_OUTPUT_VIOLATIONS` (l'entrée `MAIN/PRG_09_Supervision.st` liste encore
`M1TreuilRetenue.Ready`, `M2TreuilBucket.*` — noms qui n'existent plus).

> 🎯 **Un garde-fou qui crie tout le temps n'est plus un garde-fou.** Corrige B2 **avant** B3,
> sinon les nouvelles règles ne prouveraient rien.

### B3. Nouvelle règle — confinement de la simulation

Toute référence à `GVL_Simulation.` est **interdite**, sauf dans :

| Autorisé | Raison |
|---|---|
| `CODE/SIMULATION/**` | le banc lui-même |
| `CODE/MAIN/PRG_00_Inputs.st` | la frontière unique (§0bis) |
| `CODE/MAIN/PRG_09_Supervision.st` | publication d'état vers l'IHM |
| `CODE/MAIN/PRG_11_Troubleshooting.st` | espion de diagnostic (lecture seule) |

Message d'erreur explicite avec `fichier:ligne`. Intégrer à `run_all_gates.py`.

### B4. Nouvelle règle — zéro forçage hybride

Interdire **partout, sans exception**, le motif `OR (GVL_Simulation.<flag> AND …)`.
C'est la forme qui force un capteur à l'état sain et qui a masqué le bug C1.

### B5. Nettoyage

Supprimer le doublon `CODE/CODE/CODE_Bundle.xml` (chemin dupliqué par erreur) et vérifier que le
générateur écrit bien dans `CODE/CODE_Bundle.xml`.

---

## 4. 📄 PARTIE C — documentation

### C1. `AF_Partie-13` → **v2.0** (réécriture complète)

L'actuelle `v1.4` porte un bandeau ⛔ PÉRIMÉ : elle décrit une architecture qui n'existe plus.
Elle doit être **remplacée**, pas rafistolée.

| § | Contenu attendu |
|---|---|
| Rôle | Ce qu'est la simulation, et ce qu'elle **n'est pas** (ni un bypass, ni un outil de forçage) |
| **Doctrine 3 outils** | Bypass IHM = ignorer un défaut sur matériel **présent** · Simulation = fabriquer une valeur pour matériel **absent** · Force natif CODESYS = injecter une panne **ponctuelle** |
| Architecture | Frontière unique `HwReal`/`HwSim`/`HwIn`, les 4 `IF`, `FB_SimBench`, schéma du flux |
| Granularité | 1 bit maître + 4 domaines, polarité positive. Un domaine est simulé **OU** réel |
| Modèles | Rôle de chaque `FB_Sim_*` composé par le banc + **conventions de polarité**, notamment `Mx_BrakeIsOpen := BrakeCmd` **sans `NOT`** — et pourquoi |
| Observation | `HwReal`/`HwSim`/`HwIn` côte à côte en vue instance ; renvoi vers `PRG_11_Troubleshooting` |
| Historique | Ce qui a été retiré (`GVL_PLC_Tests`, `FB_Sim_DigitalMirror`, 25 flags `*IsReal`) et **pourquoi** — le REX du bug C1 doit y figurer |
| Application | Note d'import CODESYS |

Sources : le code réel (`FB_SimBench.st`, `PRG_00_Inputs.st`), `PLAN_Rationalisation_Simulation_v1.0.md`,
`DOC/CHECKLISTS/CHECKLIST_MiseEnRoute_Simulation_v1.0.md`.

### C2. `AF_Partie-06` → **v1.7**

Le principe (`FB_Input`, filtre 20 ms, inversion NO/NC) **reste valable**. Ajouter ce qui est en
amont : chaîne `%IX → HwReal → HwIn → FB_Input`, acquisition centralisée en `PRG_00` §0,
nouvelle convention de nommage des E/S.

### C3. `NAMING_CONVENTION.md`

Formaliser la convention appliquée le 2026-07-27 :

```
<Domaine>_<ÉtatQuandTRUE>_DI      M1_BrakeIsOpen_DI    → TRUE = frein ouvert
<Domaine>_<ActionCommandée>_RQ    M1_BrakeRelease_RQ   → TRUE = desserrage commandé
```
Justification : un nom muet sur sa polarité a coûté un défaut réel.
Source : `DOC/AUDITS/PreLivraison/TABLE_Renommage_IO_v1.0.md`.

### C4. `AF_Partie-01`

Mettre à jour les noms de la chaîne de sécurité : `PowerContactorEngaged_DI` (⚠️ ce n'est **pas**
la boucle AU), `EmergencyChainClosed_DI`, `PowerKeepAlive_A/B_RQ` (fail-safe : `TRUE` = puissance
maintenue).

### C5. `VERSION_HISTORY.md` et `CLAUDE.md`

Jalon du chantier (lots T80 + L2→L8). Dans `CLAUDE.md` : arborescence à jour
(`PRG_11_Troubleshooting`, `_TYPES/ST_Hw*`, `FB_SimBench`), retirer les mentions de `GVL_PLC_Tests`.

### 📏 Style de rédaction (règle projet)

| Document | Style |
|---|---|
| `AF_PartieN` (specs) | **Concis et technique, zéro perte d'information**, emoji comme repères visuels. La précision technique prime sur la brièveté |
| `NAMING_CONVENTION`, `VERSION_HISTORY`, `CLAUDE.md` | **Concis, direct, TDAH-friendly**, emoji, tables courtes > prose |

⚠️ **Versionnage** : archiver la version précédente dans `ARCHIVES/Doc/` **avant** d'incrémenter,
puis mettre à jour les références croisées. (`ARCHIVES/Doc/` est gitignoré : les fichiers restent
sur disque.)

---

## 5. ⛔ Interdictions

- ❌ **Aucune modification de logique automate.** Seule exception : la déclaration `HwSim` (partie A)
- ❌ Aucun comparateur, aucun `HwDelta`, aucun compteur d'écarts
- ❌ Aucune exemption **globale** dans les gates : listes précises uniquement
- ❌ Ne supprime pas les REX historiques des specs : ils expliquent des décisions de sécurité
- ❌ Aucun renommage de variable
- ❌ Aucun `git commit`, aucun `git push`

---

## 6. 🚨 Devoir d'alerte

Arrête-toi et signale — **sans rien modifier** — si tu constates :

- une incohérence avec les specs `DOC/AF_Partie-*.md` ou `CLAUDE.md` ;
- une référence à `GVL_Simulation` hors des 4 emplacements autorisés (§B3) : **ne la corrige pas
  toi-même**, signale-la — c'est peut-être une fuite réelle à instruire ;
- un motif de forçage hybride encore présent ;
- un écart aux standards d'automatisme (sécurité positive, reset sur front, état sûr en défaut) ;
- tout doute, même mineur, sur une chaîne de sécurité.

👉 **N'invente rien, ne devine rien, ne comble aucun trou.** Signale et attends.

---

## 7. 📤 Livrable

`DOC/AUDITS/PreLivraison/TASKS/RAPPORT_L7-L8_v1.0.md` :

- partie A : où `HwSim` est déclaré et alimenté, preuve qu'aucune logique métier ne le lit
- résultat de `run_all_gates.py` **avant / après** (les 36 faux positifs doivent tomber à 0)
- **test des nouvelles règles** : introduire volontairement une référence interdite → le gate doit
  la détecter → puis retirer le test. Donne les commandes et les sorties
- liste des documents créés / incrémentés / archivés + références croisées mises à jour
- tes alertes

### ✅ Critères de sortie

- [ ] `HwSim` exposé, aucun comparateur développé
- [ ] `run_all_gates.py` **PASS**, zéro faux positif
- [ ] Règles de confinement et de forçage hybride actives **et testées**
- [ ] `AF_Partie-13 v2.0` et `AF_Partie-06 v1.7` publiées, bandeaux ⛔/⚠️ retirés
- [ ] `NAMING_CONVENTION`, `AF_Partie-01`, `VERSION_HISTORY`, `CLAUDE.md` à jour
- [ ] Doublon `CODE/CODE/` supprimé
- [ ] Aucun autre fichier `CODE/**/*.st` modifié
