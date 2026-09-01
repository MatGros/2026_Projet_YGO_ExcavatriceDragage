# 🧪 Fiche de test — Validation refactor T215 (GVL_IHM.DredgingAssist → 3 structures)

> **Réf** : T215 · **Date** : 2026-09-01 · **Contexte** : refactor IHM (pur renommage, zéro logique)
> **Type** : validation machine/IHM (2 tests)
> **Statut** : ⏳ À exécuter

---

## 🧪 Test 1 — Persistance des toggles/configs au boot

**Objectif** : vérifier que le refactor n'a pas cassé la mémorisation des réglages.

| # | Action | Attendu |
|---|---|---|
| 1 | En MAINT_N1, active `TglEnableDiveSearch` + règle `DiveStartMin_M` à 2.0m | Valeurs modifiées |
| 2 | Redémarre le PLC (reset chaud) | — |
| 3 | Vérifie `GVL_IHM.CycleDiveSearch.Cmd.TglEnableDiveSearch` | **TRUE** (toggle mémorisé) |
| 4 | Vérifie `GVL_IHM.CycleDiveSearch.Cfg.DiveStartMin_M` | **2.0m** (config mémorisée) |

**Critère de validation** : ✅ valeurs restaurées · ⚠️ si retour au défaut → persistance cassée.

---

## 🧪 Test 2 — Fonctionnement plongée/extraction via les nouveaux chemins

**Objectif** : vérifier que le recâblage des consommateurs (PRG_03/04/07) fonctionne.

| # | Action | Attendu |
|---|---|---|
| 1 | En MAINT_N1, active `TglEnableDiveSearch` | — |
| 2 | Lance une plongée (benne ouverte, treuils ≥ 1m, descente) | `DiveBusy` = TRUE, `DiveState` progresse |
| 3 | Vérifie `CycleDiveSearch.State.DiveReady/Busy/State` | États reflètent `FB_DiveSearch` |
| 4 | Vérifie projection troubleshooting `M_AssistanceDragage.Idx201/202` | Cohérent avec état réel |

**Critère de validation** : ✅ plongée démarre et progresse · ✅ projection troubleshooting cohérente

---

## ✅ Résultat

| Test | Résultat | Commentaire |
|---|---|---|
| Test 1 (persistance) | ☐ | |
| Test 2 (fonctionnement) | ☐ | |
