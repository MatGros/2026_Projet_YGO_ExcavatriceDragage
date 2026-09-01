# 🧭 Note de décision — Qualification du fond Kobold en SEMI_AUTO (gap plongée)

> **Réf** : T202-E · **Date** : 2026-09-01 · **Auteur** : DSH (orchestrateur des cycles)
> **Objet** : arbitrer l'écart entre l'intention (AF-04 §4.2) et le code (`FB_Cycle`) sur la
> validation du fond Kobold en cycle automatique.
> **Statut** : ⏳ EN ATTENTE DE DÉCISION HUMAINE

---

## 1. 🎯 Le problème

En **SEMI_AUTO**, `FB_Cycle` (grafcet X0→X13) valide le fond en **X4_DESCEND_OPEN → X5_BOTTOM_CONFIRMED**
sur le **DI brut** `KoboldContactFond` (retour capteur direct, ligne 463 de `FB_Cycle.st`).

Or `FB_DiveSearch` (le FB durci de qualification du fond) **n'est pas appelé** dans `FB_Cycle` :
il n'est instancié que dans `PRG_03` en mode **MAINT_N1/N2**. En SEMI_AUTO, `FB_Cycle` est le seul
producteur de la validation du fond et il lit le DI brut, **sans la qualification immersion**.

**Conséquence** : en cycle auto, un capteur défaillant ou un faux contact peut valider le fond **sans
immersion préalable** — alors qu'en MAINT, `FB_DiveSearch` exige l'immersion validée avant la
recherche de fond.

## 2. 📖 Le constat code vs AF

| | Programme (`FB_Cycle`) | AF-04 §4.2 |
|---|---|---|
| **Transition X4→X5** | `JoystickDeflected ∧ KoboldContactFond` (DI brut) | « fond validé (**FB_DiveSearch**) » |
| **Qualification immersion** | ❌ Absente en SEMI_AUTO | ✅ Exigée par `FB_DiveSearch` |
| **Palier ≤ 4** | `StepTgt:=3` fixe (palier 3) | Palier ≤ 4 strict |
| **Coupure contacteur** | `ReqKoboldMeasureEnable := ProcessPermitM1_Descend` | Coupure anti-chauffe |

L'AF-04 §4.2 prétend que X5 = « fond validé (FB_DiveSearch) » — **faux pour le chemin SEMI_AUTO**.

## 3. ⚖️ Options & recommandation

### Option 1 — Alignement (recommandée par défaut, cohérente AF)
`FB_Cycle` X4→X5 consomme la **sortie qualifiée** `BottomTouchConfirmed` de `FB_DiveSearch`
(comme le chemin MAINT) — le cycle auto exige l'immersion validée avant le fond.
- **Avantage** : cohérent avec AF-04, robustesse équivalente MAINT/SEMI_AUTO, réutilise le FB durci.
- **Inconvénient** : dépend de la disponibilité de `FB_DiveSearch` en SEMI_AUTO (activation/instanciation à prévoir), léger délai.

### Option 2 — Séparation assumée (plus risquée)
Garder la logique inline sur DI brut, **corriger l'AF-04** pour documenter que le SEMI_AUTO ne
qualifie pas l'immersion.
- **Avantage** : zéro changement de code, comportement actuel conservé.
- **Inconvénient** : **risque sécurité** (faux fond sans immersion), divergence de robustesse entre modes, double maintenance.

### 💡 Challenge constructif
**Option 1 est plus sûre.** L'option 2 fige une faille de robustesse (faux contact → faux fond).
Cependant, l'Option 1 exige de définir comment `FB_DiveSearch` est activé/câblé en SEMI_AUTO
(sous-instance dans le chemin cycle, ou brique partagée). **Décision humaine requise**.

## 4. 🧩 Critères de décision

| Critère | Option 1 | Option 2 |
|---|---|---|
| Cohérence AF-04 | ✅ | ❌ (AF à corriger) |
| Robustesse anti-faux-fond | ✅ | ❌ |
| Uniformité MAINT/SEMI_AUTO | ✅ | ❌ |
| Effort d'implémentation | Moyen | Faible |
| Risque sécurité | Faible | Moyen |

## 5. ✅ Décision requise (humain)

> **Quelle option retenir ?**
> - **Option 1** : `FB_Cycle` utilise `BottomTouchConfirmed` de `FB_DiveSearch` (qualification immersion en SEMI_AUTO).
> - **Option 2** : garder le DI brut, corriger l'AF-04 (comportement voulu).

*Cocher l'option choisie : ☐ Option 1 ☐ Option 2*
