# 🪛 Diagnostic — Pilotage des Contacteurs de Vitesse (Treuils M1/M2)

**Date** : 2026-08-31
**Auteur** : Agent diagnostic (lecture seule — aucun fichier `CODE/` modifié)
**Sujet** : Paliers de vitesse → contacteurs non-cumulatifs / anormaux en simulation (plongée)

---

## 🚨 Verdict synthétique

Le pilotage des contacteurs de vitesse est **« one-hot » (mutuellement exclusif)** et **non cumulatif par conception** : un seul contacteur de vitesse peut être actif à la fois. De plus, la table de contacteurs `ST_SpeedStepTable` (censée configurer l'empreinte des paliers) est **complètement contournée** pour la sortie physique — `FB_Winch` ne consomme que le **numéro entier de palier** (`StepNumber`) et recalcule les contacteurs localement avec l'équation `Contactor(n) := (StepNumber = n)`.

**Conséquence directe :**
| Palier demandé (StepNumber) | Contacteurs émis (physique / simu) | Attendu « thermomètre » |
|---|---|---|
| 1 | `C1` seul ✅ | `C1` |
| 2 | `C2` seul (ou clampé→`C1`, voir §5) ❌ | `C1+C2` |
| 3 | `C3` seul — **C1 et C2 éteints** ❌ | `C1+C2+C3` |
| 4 | `C4` seul — C1/C2/C3 éteints ❌ | `C1+C2+C3+C4` |
| 5 | aucun (pas de `(StepNumber=5)`) | `C1..C4` |

→ Le « palier 2 → aucun contacteur » et « palier 3 → C3 mais C1/C2 s'éteignent » observés en
simulation sont **exactement** la signature de ce décodage one-hot (avec un effet de clamp §5).

---

## 1. 🧬 Cause racine (prouvée par lecture de code)

### 1.1 Le décodage contacteur de `FB_Winch` est one-hot, pas table

`CODE/H_TREUILS_BENNE/FB_Winch.st` — région §5, lignes **278–281** :

```st
Contactor1 := (StepNumber = 1);
Contactor2 := (StepNumber = 2);
Contactor3 := (StepNumber = 3);
Contactor4 := (StepNumber = 4);
```

- C'est une **égalité exclusive** (`StepNumber = n`) → **un seul contacteur** peut prendre `TRUE` à la fois.
- Le palier 5 n'est **jamais** représenté (pas de ligne `StepNumber = 5`), donc aucun contacteur vitesse au palier 5 → les 4 contacteurs sont retombés.
- Il n'y a **aucune accumulation** (`OR` cumulative) et **aucune lecture des `P{n}R{m}`** ici.

### 1.2 La table `ST_SpeedStepTable` est contournée (décor de sortie)

`FB_Winch` **instancie** bien `FB_SpeedStep` et lui passe `Table := Config.SpeedStepTable` (l. 214),
mais **ne lit que `SpeedStep.StepNumber`** (l. 217 : `RequestedStep := SpeedStep.StepNumber`) et
**jette** `SpeedStep.Contactor1..4` (les sorties issues de la table).

- Les bits `P1R1..P5R4` ne pilotent **rien** pour la sortie physique.
- Seul `StepThreshold_Pct` de la table est réellement utile (conversion %→palier amont, `FB_Joystick`,
  `PRG_04`, `PRG_07`).
- → Quoi qu'on configure dans la table contacteurs, la sortie reste `(StepNumber=n)`.

**`FB_SpeedStep` lui-même est table-driven et COULD être cumulatif** (l. 74–78 : `CASE StepNumber →
Contactor1 := Table.P{n}R1; ...`). Mais comme la sortie est ignorée, le décodage table est **mort**.
C'est ici la **double incohérence** : le FB décodage existe et est correct, mais il alimente une
sortie que `FB_Winch` ne consomme pas.

---

## 2. 📍 Localisation du bug

| Maillon | Fichier | Rôle | Statut |
|---|---|---|---|
| Décodage table | `CODE/H_TREUILS_BENNE/FB_SpeedStep.st` | `CASE → Table.P{n}R{m}` | ✅ Correct… **mais inutilisé** |
| **Producteur contacteurs** | `CODE/H_TREUILS_BENNE/FB_Winch.st:278-281` | `Contactor(n):=(StepNumber=n)` **one-hot** | 🔴 **BUG RACINE** |
| Contournement table | `FB_Winch.st:211-217` | lit `StepNumber`, jette `SpeedStep.Contactor*` | 🔴 |
| Table défaut | `CODE/GVL_PERSISTENT.st:16-23` | thermomètre **décalé d'un cran** | 🟠 (même inutilisée) |
| Interlock | `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` §5 (l. 357–364) | **pass-through** `Contactor := RequestedContactor` | ✅ rien ne recrée |
| Sorties physiques | `CODE/M_MAIN/PRG_06_Outputs.st` l. 133–146 / 206–219 | pass-through → DQ | ✅ rien ne recrée |
| Simulation | `CODE/L_SIMULATION/FB_SimBench.st` l. 201–209 | retourne « tous contacteurs retombés » à partir des DQ | ✅ fidèle à la commande |

**Le bug est dans `FB_Winch` (§5), pas dans l'interlock, ni PRG_06, ni la simu.** Ces derniers
transmettent fidèlement le one-hot déjà produit.

---

## 3. 🔍 Les deux treuils M1/M2

**Identiques — même table, même séquence, même défaut :**

- `PRG_04_Treuils_Benne.st:903` : `M1WinchCfg.SpeedStepTable := _WinchSpeedStepTable`
- `PRG_04_Treuils_Benne.st:951` : `M2WinchCfg.SpeedStepTable := _WinchSpeedStepTable`
  → **même table commune** pour M1 et M2 (commentaire l. 483 : « M2 consomme directement
  `_WinchSpeedStepTable` (table normale) »).
- M1 et M2 sont tous deux des instances de `FB_Winch` (`instWinchM1` / `instWinchM2`) → **même
  décodage one-hot** `(StepNumber=n)`.
- L'interlock et PRG_06 traitent M1 et M2 strictement à l'identique.

➡️ **Aucune divergence M1/M2** : les deux treuils partagent le même bug one-hot et la même table
(ignorée pour la sortie). Aucune asymétrie symétrie/dragage supplémentaire.

---

## 4. 🏗️ Table `GVL_PERSISTENT` — contenu réel (défaut RETAIN)

`CODE/GVL_PERSISTENT.st:16-23` (table commune `_WinchSpeedStepTable`) :

```st
P1 := [FALSE, FALSE, FALSE, FALSE]   // Palier 1 : AUCUN contacteur ❌
P2 := [TRUE,  FALSE, FALSE, FALSE]   // Palier 2 : C1 seul
P3 := [TRUE,  TRUE,  FALSE, FALSE]   // Palier 3 : C1+C2
P4 := [TRUE,  TRUE,  TRUE,  FALSE]   // Palier 4 : C1+C2+C3
P5 := [TRUE,  TRUE,  TRUE,  TRUE ]   // Palier 5 : C1+C2+C3+C4
StepThreshold_Pct := [20,40,60,80,100]
```

**Analyse :** cette table est **manifestement un « thermomètre » (cumulative) mais décalé d'un cran** :
elle ne contient QUE 4 « barreaux » répartis sur 5 paliers, avec le palier 1 **vide**. La forme
attendue d'un thermomètre serait `Pn := [R1..Rn = TRUE]` (palier 1 = `C1`, palier 2 = `C1+C2`, …).
Ici c'est `Pn := [R1..R(n-1) = TRUE]` → chaque palier a **un contacteur de moins** et le palier 1
est vide.

### ⚠️ Ceci explique littéralement le symptôme observé **si la simu reflète `FB_SpeedStep`** :
- Palier 1 → table `P1` vide → **aucun contacteur** ❌
- Palier 2 → table `P2 = C1` → `C1` seul (≠ cumulative 1+2)
- Palier 3 → table `P3 = C1+C2` → C1 et C2 (pas C3)

Mais la chaîne physique réelle **contourne la table**, donc en simu on voit en réalité le one-hot de
`FB_Winch` (l. 278-281) : il y a **une double source de vérité** entre :
- la **table** (`FB_SpeedStep`, cumulative décalée), jamais branchée, et
- le **one-hot** (`FB_Winch`, mutual exclusion), réellement branché sur les DQ.

---

## 5. 🧲 Sur le symptôme précis « palier 2 → aucun contacteur »

Le one-hot pur (`(StepNumber=2)` → `C2`) ne donne pas *« aucun »*, mais `C2` seul. L'observation
« aucun » en **plongée** est cohérente avec un **clamp du palier au palier 1** par le :
- **SpeedGuard** de `FB_Winch` §5 (l. 222-233) : si `SpeedGuardEnable` et la bande mesurée n'ont pas
  encore validé `MeasuredSpeedBand ≥ 2`, `RequestedStep` est claqué à `1` → `StepNumber=1` → seul
  `C1` est émis. L'opérateur « au palier 2 » ne voit **aucun contacteur supplémentaire** → « rien ne
  s'enclenche » pour le palier visé.
- ou cadence du StepShaper (`FB_WinchStepShaper` : monte +1 cran / délai) pendant la transition 1→2.

Dans tous les cas, **aucune empreinte cumulative** `C1+C2` n'apparaît jamais au palier 2, quelle que
soit la lecture (one-hot → `C2` ; clamp → `C1` ; table → `C1`). C'est le **défaut one-hot** qui rend
le palier 2 « vide » de cumul.

> 🟡 Pour trancher entre `C2` one-hot vs `C1` clampé au palier 2, un **snapshot live** de
> `StepNumber`, `SpeedGuardLimited` et `CommandedDirection` (M1/M2) est requis. Les deux conclusions
> convergent vers le MÊME défaut racine (§1).

---

## 6. 🛡️ Impact safety (machine réelle)

1. **Perte de l'étagement de démarrage (thermomètre)** : au lieu d'engager `C1+C2+C3` graduellement,
   chaque palier engage **un seul contacteur** puis commute. En plongée (treuil sous charge), le
   passage brutal `C2→C3` (avec C1/C2 éteints) provoque des **à-coups de couple / chute de charge** au
   point mort (les 1–2 contacteurs retombent avant le 3ᵉ).

2. **Palier 5 = « tout coupé »** : `(StepNumber=5)` n'existe pas → au palier 5, les 4 contacteurs
   vitesse sont commandés `FALSE` alors que le treuil est censé être en pleine vitesse → **chute de
   couple moteur à pleine course** (risque de chute de benne / perte de contrôle en descente).

3. **Retour « tous contacteurs retombés » faussé en transitoire** : pendant la commutation
   one-hot, il y a un instant où AUCUN contacteur vitesse n'est émis (`C2` coupé avant `C3`) →
   `M1_ContactorsReleased_DI` / `FwdRevSpeedFeedbackOff` **s'activent pendant un mouvement réel**,
   ce qui peut **armer la Méca A / valider des conditions d'arrêt à tort** (voir commentaire
   `FB_SimBench` §2, qui note explicitement ce risque). L'interlock de sortie (§3bis) peut alors
   chuter le contacteur de sens alors que le treuil est encore en rotation.

4. **Non-conformité à la spec attendue (cumul thermo)** : le comportement ne respecte ni la table
   configurée, ni l'attendu métier « palier n = contacteurs 1..n » → risque de mauvaise interprétation
   IHM/maintenance et de dérive de comportement entre simulation et machine.

---

## 7. ✅ Preuves (grep / lecture)

| Preuve | Fichier : ligne | Contenu |
|---|---|---|
| Décodage one-hot | `FB_Winch.st:278-281` | `Contactor1 := (StepNumber = 1); …` |
| Table passée mais non lue pour sortie | `FB_Winch.st:211-217` | `SpeedStep(Table := Config.SpeedStepTable)` puis `RequestedStep := SpeedStep.StepNumber` |
| Décodage table inutilisé | `FB_SpeedStep.st:74-78` | `CASE StepNumber: Contactor1 := Table.P{n}R1; …` |
| Table commune M1/M2 | `PRG_04:903,951` | `M1/M2WinchCfg.SpeedStepTable := _WinchSpeedStepTable` |
| Interlock pass-through | `FB_WinchOutputInterlock.st:357-364` | `Contactor1 := RequestedContactor1; …` |
| Sortie DQ pass-through | `PRG_06:133-146,206-219` | `M1_SpeedContactor_n_DQ := M1SpeedContactor_n` |
| Simu fidèle à la commande | `FB_SimBench.st:201-209` | `M1_ContactorsReleased_DI := NOT (Relay ⋁ C1⋁C2⋁C3⋁C4)` |
| Table décalée | `GVL_PERSISTENT.st:16-23` | `P1` vide, `P5` = 4 contacteurs, cumul décalé |

**Aucun fichier modifié.** Diagnostic lecture seule.

---

## 8. 🔧 Pistes de correction (PAS appliquées — validation requise)

**Option A (cohérente avec la table) — rendre `FB_Winch` cumulatif à partir de la table :**
au lieu de `Contactor(n) := (StepNumber = n)`, propager les sorties de `SpeedStep.Contactor1..4`
(qui appliquent la table) jusqu'aux DQ. Corriger au préalable la table `GVL_PERSISTENT` :
`P1 := [1,0,0,0]`, `P2 := [1,1,0,0]`, `P3 := [1,1,1,0]`, `P4 := [1,1,1,1]`, `P5 := [1,1,1,1]`.

**Option B (thermomètre pur) :**
`Contactor1 := StepNumber >= 1; Contactor2 := StepNumber >= 2; Contactor3 := StepNumber >= 3;
Contactor4 := StepNumber >= 4;` (et palier 5 = les 4 engageables).

**Guard (obligatoire `fix:` + `guard:`) :** ajouter un garde-fou CI vérifiant que
`FB_Winch` consomme bien les sorties contacteurs de `FB_SpeedStep` (au lieu de recalculer one-hot),
et que la table `GVL_PERSISTENT` satisfait la contrainte thermo `P{n}R{m} ⇒ P{n}R{k} ∀ k≤m`.
