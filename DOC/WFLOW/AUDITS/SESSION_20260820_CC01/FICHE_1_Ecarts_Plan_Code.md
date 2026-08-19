# 📊 Fiche 1 — Écarts `PLAN_TASK` ↔ code réel

> 📅 2026-08-20 · 🤖 `CC-01` · 🔍 Read-only
> 🎯 **But** : lister les statuts `PLAN_TASK` que le code contredit, avec preuve mécanique.
> 📌 Cette fiche **ne change aucun statut** — elle instruit la décision. `PLAN_TASK.md` fait foi.

---

## 🎯 Pourquoi cette fiche existe

Un statut faux coûte plus cher qu'une tâche non faite : l'agent suivant part d'une base erronée.
Le REX fondateur du projet (`PRG_10_Outputs_LD`, 2026-07-29) est exactement ça — du code déclaré
terminé qui n'était relié à rien, validé par tous les contrôles.

**Méthode** : pour chaque tâche non-`✅`, lecture du code cité dans la colonne « Source & Détails ».
Sans preuve `fichier:ligne`, la tâche est classée *indéterminable* — jamais supposée faite.

---

## 🔴 Les 7 écarts constatés

| # | Statut actuel | Constat vérifié | Statut proposé |
|---|:---:|---|:---:|
| **T137** — migration `ST_FbStatus` | ⬜ | Le type `ST_FbStatus` **n'existe dans aucun fichier de `CODE/`**. La tâche ne peut pas démarrer : son prérequis n'est pas livré (voir fiche 3) | ⏸️ **bloqué** |
| **T136** — contrats d'interface FB | ⏳ `AGY-01` | Documentation et garde-fou livrés, mais le type socle `ST_FbStatus` qu'ils décrivent est absent du code | ⏳ **incomplet** |
| **T94** — garde-fou vitesse persistant | ⏳ `PI-01` | `SpeedGuardEnableM1/M2` sont des variables **locales** au programme, ni persistantes ni exposées à l'IHM. L'exigence n'est pas satisfaite | ⬜ **à faire** |
| **T142** — bus DUT inter-programmes | ⏳ | Les 4 types existent et sont consommés, mais **ne sont pas suivis par git** (jamais versionnés) et un champ n'est jamais alimenté (voir fiche 2) | ⏳ + 🔴 **bug** |
| **T123 / lot 13** — standardisation | 🔒 `AGY-01` | Les 13 sous-tâches `T123-A` à `T123-M` sont toutes closes ; seule `T123-VAL` reste ouverte. Le verrou n'a plus d'objet | ✅ **+ T123-VAL ⬜** |
| **T109** — polarité positive `*Permit` | ⬜ | La convention est **déjà appliquée dans le code** (`DescendPermit`, `AscentPermit`). Reste uniquement à l'inscrire dans la convention de nommage | ✅ code · ⬜ doc |
| Ligne « 🟡 Partiel » — `FB_Input`/`FB_Output` | 🟡 | `FB_Input` **n'existe plus** dans le code. La ligne décrit un état révolu | 🗑️ **à purger** |

### 📍 Preuves

| Élément | Emplacement | Ce qu'on lit |
|---|---|---|
| `ST_FbStatus` absent | *(aucun fichier)* | Recherche sur tout `CODE/` : zéro occurrence. Le type n'est décrit que dans `CODE_QUALITY_STANDARDS.md` §2quinquies |
| `SpeedGuardEnable` local | `CODE/M_MAIN/PRG_04_Treuils_Benne.st:71-72` | Déclaré en variable interne du programme, pas dans `GVL_PERSISTENT` ni `GVL_IHM` |
| `DescendPermit`/`AscentPermit` | `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:89-90` | Sorties déjà nommées en polarité positive |
| `FB_Input` disparu | *(aucun fichier)* | Recherche sur tout `CODE/` : zéro occurrence |
| Sous-tâches T123 closes | `DOC/WFLOW/PLAN_TASK.md:58-70` | 13 lignes `✅`, une seule `⬜` (`T123-VAL`) |

---

## 🔒 Effet secondaire : accumulation des verrous

| Constat | Détail |
|---|---|
| **Verrou sans objet** | `T123` reste `🔒` alors que tout son périmètre est clos |
| **Même agent, même périmètre** | `AGY-01` porte `T123`, `T136` et `T140` — tous touchent `PRG_04`/`PRG_07` |
| **`⏳` qui s'empilent** | 7 tâches attendent une validation qui n'arrive pas (`T84`, `T85`, `T86`, `T81`, `T82`, `T140`, `T142`) |
| **Tâche en étude sans porteur** | `T130` est `🔍` avec `Lock Agent` à `—` |

⚠️ La règle « **un lot à la fois** : analyse → plan → validation → implémentation → contrôle →
validation » (`PLAN_TASK.md:75`) n'est plus tenue. Sept lots sont ouverts simultanément, tous en
attente de la même ressource : **la validation humaine sur banc**.

---

## 🧭 Ce que ça implique

1. **Aucun nouveau lot de code ne devrait s'ouvrir** tant que les 7 `⏳` ne sont pas tranchés :
   soit testés et clos, soit reclassés honnêtement en « codé, non testé ».
2. **Le vocabulaire `⏳` est ambigu** : il mélange « testé, attente de signature » et « écrit,
   jamais exécuté ». Ces deux états n'ont pas le même risque machine.
3. La ligne « 🟡 Partiel » entretient une **fausse dette** : elle décrit des briques supprimées.

---

## ❓ Décisions attendues

| # | Question | Pourquoi elle bloque |
|---|---|---|
| Q2 | Parmi les 7 `⏳`, lesquels ont **réellement** été exécutés en CODESYS ? | Un `⏳` non testé sur une fonction de sécurité est un risque machine, pas une formalité administrative |
| Q3 | `AGY-01` a-t-il encore un travail en cours sur `PRG_04`/`PRG_07` ? | Toute intervention de ma part sur ces fichiers créerait une collision d'édition |
| Q5 | Accepte-t-on de distinguer `⏳ testé` / `🧊 codé non testé` dans la légende ? | Lever l'ambiguïté qui laisse croire qu'un lot est plus avancé qu'il ne l'est |
