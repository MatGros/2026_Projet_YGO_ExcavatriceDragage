> # ❌ FICHE ANNULEE (2026-07-27) — NE PAS EXECUTER
>
> Remplacee par `TASK_L7-L8_HwSim_Verrou_Specs_v2.0.md`.
> Motif : le comparateur `FB_HwCompare`/`HwDelta` est abandonne — la lecture cote a cote
> `HwReal`/`HwSim`/`HwIn` en vue instance et `PRG_11_Troubleshooting` couvrent le besoin
> sans ajouter de couche. Le reste (verrou + specs) est repris dans la v2.0.

# 🔍 FICHE DE TÂCHE — Lot L7 : comparateur `HwDelta` (modèle ↔ réel)

> 🤖 Agent d'implémentation externe · 📅 2026-07-27 · **v1.0** · 🟢 risque faible (observateur pur)
> ⏱️ **Prérequis** : lot L6 appliqué (banc `FB_SimBench` derrière `HwIn`). ✅ C'est le cas.
> 📖 **Contexte et règles : §1 et §4 de
> [`TASK_L2-L3_Retrait_GVL_PLC_Tests_v1.0.md`](TASK_L2-L3_Retrait_GVL_PLC_Tests_v1.0.md)**.

---

## 1. 🎯 Objectif — le critère objectif de bascule simulation → réel

Pendant la mise en service, on câble les capteurs un par un. La question à laquelle il faut
répondre **avant** de couper la simulation d'un domaine est :

> « Est-ce que le matériel réel dit déjà ce que le modèle attend ? »

Aujourd'hui on ne peut y répondre qu'en coupant la simulation **et en voyant ce qui casse**.
Ce lot fournit la réponse **à l'avance**, sans rien couper.

Les trois images ont **les mêmes champs**, donc elles se comparent directement :

```
HwReal  ── ce que dit le matériel        (déjà rempli en permanence, §0)
HwSim   ── ce que le banc attend         (sortie de FB_SimBench)
HwIn    ── ce que le programme utilise   (l'un ou l'autre, par domaine)
HwDelta ── 🎯 les champs où HwReal ≠ HwSim
```

---

## 2. 🔧 Travail

### 2.1 Exposer `HwSim`

Dans `PRG_00_Inputs`, déclarer `HwSim : ST_HardwareImage;` en `VAR_OUTPUT` et l'alimenter depuis
les sorties de `instSimBench` — **que la simulation soit active ou non**, si `SimShadowCompare`
le demande (voir 2.3). Cela permet de lire les 3 images côte à côte en vue instance.

### 2.2 Créer `FB_HwCompare` (`CODE/SIMULATION/`)

Brique réduite ([Partie 3 §1bis](../../AF_Partie-03_Template_FB_Commun_v1.3.md)) — **observateur pur**.

| Entrée | |
|---|---|
| `Enable` | active la comparaison |
| `HwReal`, `HwSim` | `ST_HardwareImage` (par `VAR_IN_OUT` si plus efficace) |
| `StableTime` | `TIME := T#2S` — durée de stabilité exigée avant de rendre un verdict |
| `MachineIsStill` | `BOOL` — TRUE si aucune commande de mouvement n'est active |

| Sortie | |
|---|---|
| `HwDelta` | `ST_HardwareImage` : `TRUE` sur chaque champ **booléen** où `HwReal ≠ HwSim` |
| `MismatchCount` | `UINT` — nombre total d'écarts en cours |
| `MismatchWinch/Translation/Operator/Machine` | `UINT` — écarts par domaine |
| `CompareValid` | `BOOL` — TRUE quand le verdict est exploitable (voir §3) |

### 2.3 Câbler dans `PRG_00_Inputs`

- `SimShadowCompare : BOOL := FALSE;` dans `GVL_Simulation` — active la comparaison en MES,
  reste à `FALSE` en exploitation (CPU nul).
- Appeler `instHwCompare` **après** `instSimBench` et **après** le remplissage de `HwReal`.
- `MachineIsStill` : à construire à partir des commandes de sortie (aucun relais de sens, aucun
  palier, aucune commande M3). **Vérifie les noms réels dans `PRG_10_Outputs`.**

### 2.4 Publier vers l'IHM (`PRG_09_Supervision`)

Ajouter dans une struct dédiée (ex. `ST_CommissioningHMI` dans `GVL_IHM.Commun`) :
`MismatchCount`, les 4 compteurs par domaine, `CompareValid`.
⚠️ **N'ajoute aucun champ dans `ST_IHM_MANU`** (table figée, transmise à un tiers).

---

## 3. 🛑 Le piège central de ce lot — **le bruit**

Un modèle idéal comparé à une machine réelle **diverge en permanence pendant les transitoires** :
un contacteur réel retombe en 40 ms, un frein a de l'hystérésis, le modèle est instantané.
Un comparateur qui clignote à chaque mouvement sera **ignoré par l'opérateur** — donc inutile.

### Règles obligatoires

| # | Règle |
|---|---|
| **R1** | **Verdict uniquement à l'arrêt stabilisé** : `MachineIsStill` vrai depuis `StableTime` (2 s). En mouvement, `CompareValid := FALSE` et **aucun écart n'est publié** |
| **R2** | **Comparer uniquement les grandeurs LOGIQUES** : retours contacteurs, freins, capteurs TOR, états devices, bits de mot d'état |
| **R3** | **Ne JAMAIS comparer les grandeurs continues** : `COD1/COD2_PosValue`, `M3_ActualFrequencyHz`, joystick `RawX/RawY`. Le banc ne prétend pas prédire une position réelle. Elles restent lisibles côte à côte, **sans verdict** |
| **R4** | **Observateur pur** : `FB_HwCompare` n'écrit **jamais** dans `HwIn`, ne déclenche **aucun** défaut, ne bloque **aucun** mouvement. Il informe, c'est tout |

---

## 4. ⛔ Interdictions

- ❌ Aucune écriture dans `HwIn`, `HwReal`, ni dans une variable métier
- ❌ Aucun `SafeStop`, `PowerCutOff`, `ErrorId` déclenché par ce bloc
- ❌ Aucune modification des 4 `IF` d'aiguillage (acquis L6)
- ❌ Aucun champ ajouté à `ST_IHM_MANU`
- ❌ Aucune comparaison de grandeur continue
- ❌ Aucun commit

---

## 5. 📤 Livrable

`DOC/AUDITS/PreLivraison/TASKS/RAPPORT_L7_v1.0.md` :

- interface de `FB_HwCompare`
- **liste des champs comparés** et **liste des champs exclus** (avec la raison)
- comment `MachineIsStill` est construit (noms de sortie réels utilisés)
- confirmation : aucune écriture hors `HwDelta`/compteurs
- tes alertes

### ✅ Critères de sortie

- [ ] `SimShadowCompare = FALSE` ⇒ **aucun impact**, aucun calcul
- [ ] Verdict rendu uniquement à l'arrêt stabilisé (2 s)
- [ ] Aucune grandeur continue comparée
- [ ] Observateur pur : zéro écriture métier
- [ ] Style et mise en page de `PRG_00` (lot L5) préservés

### 🧪 Validation (par l'utilisateur)

1. Compilation 0 erreur
2. `SimShadowCompare = FALSE` → comportement inchangé
3. Machine saine + `SimShadowCompare = TRUE` + machine à l'arrêt → **`MismatchCount = 0`**
4. Débrancher volontairement un capteur → l'écart apparaît **sur ce seul champ**
5. Faire un mouvement → `CompareValid = FALSE`, aucun écart publié (pas de bruit)
