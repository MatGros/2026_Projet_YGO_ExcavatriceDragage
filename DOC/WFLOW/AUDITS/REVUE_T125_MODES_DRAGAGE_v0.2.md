# 🌊 T125 — Revue conception modes dragage (DiveSearch / ExtractionSequence / DumpAtTremie)

> 📄 **ÉTUDE / REVUE DE CONCEPTION (zéro code)** · **v0.2** (corrigée après revue indépendante
> 2026-08-24) · 📅 2026-08-24 · 🎯 T125 — revue des modes de dragage (plongée/recherche fond,
> extraction, vidage trémie) selon **le standard projet** (1 FB = 1 responsabilité) et le
> **fonctionnel après essais**.
> Source : `PRG_04_Treuils_Benne.st`, `FB_DiveSearch.st`, `FB_ExtractionSequence.st`, structs
> `J_SUPERVISION/_TYPES/5_ASSISTANCE_DRAGAGE/`. 🔗 Tâche : [`../TASKS.yaml`](../TASKS.yaml) → T125.

> 🟠 **v0.2** : intègre la revue indépendante — constats **confirmés** mais **5 corrections**
> (périmètre élargi, reformulation, clarification DescentLocked, ST_Modes*, découpage commits).

---

## 1. Constats (session 2026-08-18, confirmés code 2026-08-24)

| # | Constat | Statut code | Confirmé |
|---|---|---|---|
| ① | Logique **DumpAtTremie inline dans PRG_04** → violation du standard | `DumpAtTremieBucketOpenArmed` (PRG_04:337), `DumpAtTremieDescentLocked` (PRG_04:796-801), **+ `DumpAtTremieActive`/`DumpAtTremieAssistActive` (PRG_04:170-172)** vivent **dans PRG_04**, absents de FB_DiveSearch/ExtractionSequence | ✅ |
| ② | **Verrou translation à la trémie absent** | aucun lien `DumpAtTremie` → translation M3 | ✅ |
| ③ | **Latch « une fois descendu → translation interdite » absent** | `DescentLocked` verrouille la **descente M1/M2** (hors P1/Maintenance), **pas la translation** — latch translation = besoin neuf | ✅ |

**Adossé (2026-08-21)** : regrouper les types des séquences/cycles (`ST_DredgingAssistCfg/State/
Cmd/HMI`, tout `ST_Cycle*`) de `J_SUPERVISION/_TYPES/5_ASSISTANCE_DRAGAGE` et
`3_CYCLE_ET_MODES` vers **`G_CYCLE`** (avec leurs FB DiveSearch/ExtractionSequence/Cycle).

---

## 2. Revue — standard & responsabilité (v0.2)

### 2.1. DumpAtTremie inline → FB dédié (constat ①, périmètre élargi)

> 🟠 **Correction revue** : la logique inline vit dans un **PRG** (pas « un FB viole »).
> Reformulation : l'orchestration PRG_04 porte une **logique métier inline** qui devrait être
> encapsulée dans un **FB dédié** (`FB_DumpAtTremie`).

| Périmètre actuel (PRG_04) | Cible |
|---|---|
| `DumpAtTremieActive` / `DumpAtTremieAssistActive` (L170-172) | → logique du FB `FB_DumpAtTremie` |
| `DumpAtTremieBucketOpenArmed` (L337) | → sortie du FB |
| `DumpAtTremieDescentLocked` (L796-798) | → logique interne du FB |

**⚠️ Sécurité** : préserver l'**assemblage des permits** (`PRG_04:790/813`, anti-télescopage
synchro) pendant le refactor du `DescentLocked` — jamais casser la synchro. Refactor **mécanique**
(déplacement, pas de changement de logique) + preuve G200.

### 2.2. Verrou translation trémie (②) + latch descente (③)

- **② Verrou translation à la trémie** : si benne en DumpAtTremie, interdire/limiter la translation
  M3 vers trémie (recoupe **T108**).
- **③ Latch « une fois descendu → translation interdite » (hors P1/Maintenance)** : 🐌 **correction**
  — le `DumpAtTremieDescentLocked` existant verrouille la **descente M1/M2**, il **n'est pas une
  base directe de réutilisation** pour le latch translation. Le latch translation est un **besoin
  neuf** (nouveau verrouillage, à concevoir).

### 2.3. Structuration des types → G_CYCLE (décision 2026-08-21)

| Dossier actuel | Types | Cible |
|---|---|---|
| `_TYPES/5_ASSISTANCE_DRAGAGE` | `ST_DredgingAssistCfg/State/Cmd/HMI` | `G_CYCLE` |
| `_TYPES/3_CYCLE_ET_MODES` | tout `ST_Cycle*` | `G_CYCLE` |

> 🐌 **Correction** : préciser si `ST_Modes*` de `3_CYCLE_ET_MODES` bougent aussi (décision
> utilisateur à confirmer). **Risque nul de casse** (résolution CODESYS par nom de type global) —
> ⚠️ **déplacement, ne PAS dupliquer** (conflit de nommage).

---

## 3. Découpe d'implémentation recommandée

| Lot | Contenu |
|---|---|
| **Lot 1** | Logique `FB_DumpAtTremie` (encapsulation des calculs PRG_04) — isolation testable |
| **Lot 2** | Déplacement types → `G_CYCLE` (mécanique, pas de logique) |

> ✅ **2 commits isolés** (revue) : ne pas mélanger logique métier et déplacement de types dans un
> seul diff (lisibilité, non-régression).

---

## 5. Points à valider (avant implémentation)

| # | Question |
|---|---|
| 1 | Créer un **FB dédié** (`FB_DumpAtTremie`) — validé utilisateur ? |
| 2 | Verrou trémie : rattacher à **T108** (interlock trémie) ? |
| 3 | Latch descente→translation : **concevoir en neuf** (pas réutiliser DescentLocked) — validé ? |
| 4 | `ST_Modes*` bougent-ils aussi vers G_CYCLE ? |
| 5 | Implémentation (code + types) → **validation humaine** (safety-adjacent) |

---

## 6. Documents liés

| Doc | Lien |
|---|---|
| Tâche | T125 |
| FB | `CODE/G_CYCLE/FB_DiveSearch.st` · `FB_ExtractionSequence.st` |
| PRG_04 | `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (L170-172, L337, L790-813, L796-798) |
| Types | `CODE/J_SUPERVISION/_TYPES/5_ASSISTANCE_DRAGAGE/` · `3_CYCLE_ET_MODES/` |
| Standard | `DOC/STDS/CODE_QUALITY_STANDARDS.md` (1 FB = 1 resp) |
| Revue indépt | revue T125 (2026-08-24) — 5 corrections intégrées |
