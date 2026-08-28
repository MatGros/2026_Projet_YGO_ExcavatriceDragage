## T165-C0 — Audit FB_Cycle (READ-ONLY)

### 🔍 Fichiers lus

- `CODE/G_CYCLE/FB_Cycle.st`
- `CODE/A_COMMUN/_TYPES/ST_Fault.st`
- `CODE/A_COMMUN/_TYPES/ST_Lifecycle.st`
- `CODE/M_MAIN/PRG_03_Modes_Cycle.st`
- `CODE/G_CYCLE/_TYPES/E_CycleStep.st`
- `CODE/G_CYCLE/_TYPES/E_OperatorAxis.st`

---

### AC1 — Matrice interface vs profil AF-03

| Exigence AF-03 | Nom réel | Ligne | Type réel | Verdict |
|----------------|----------|-------|-----------|---------|
| `Ready : BOOL` en VAR_OUTPUT | `Ready` | L:42 | `BOOL` | ✅ PASS |
| `Fault : ST_Fault` en VAR_OUTPUT | `Fault` | L:43 | `ST_Fault` | ✅ PASS |
| `Fault.Error : BOOL` | membre de `Fault` | — | `BOOL` | ✅ PASS (via struct) |
| `Fault.ErrorId : INT` | membre de `Fault` | — | `INT` | ✅ PASS (via struct) |
| `Lifecycle : ST_Lifecycle` en VAR_OUTPUT | `Lifecycle` | L:44 | `ST_Lifecycle` | ✅ PASS |
| `Lifecycle.Busy` | membre | — | `BOOL` | ✅ PASS |
| `Lifecycle.Done` | membre | — | `BOOL` | ✅ PASS |
| Capture d'étape au défaut | `CycleStepAtError` | L:45 | `E_CycleStep` | ✅ PASS (type exact) |

**Vérification des structs** :
- `ST_Fault` (lu) : `.Error : BOOL`, `.ErrorId : INT` — conforme.
- `ST_Lifecycle` (lu) : `.Busy`, `.Done` — conforme.

---

### AC2 — Producteurs sorties SequenceState

| Sortie | Ligne producteur FB_Cycle | Consommateur PRG_03 | Reconstitué ? |
|--------|--------------------------|---------------------|---------------|
| `OperatorActionId : E_OperatorAxis` | L:46 | lu dans `PRG_03` (voir détail) | ❌ NON — FB_Cycle la produit |
| `CycleStateStr : STRING` | L:47 | lu dans `PRG_03` | ❌ NON — FB_Cycle la produit |
| `CycleStep : E_CycleStep` | L:48 | lu dans `PRG_03` | ❌ NON — FB_Cycle la produit |
| `WaitingForOperator : BOOL` | L:49 | lu dans `PRG_03` | ❌ NON — FB_Cycle la produit |

**Détail consommateur** : `PRG_03_Modes_Cycle.st` référence explicitement les instances `FB_Cycle` (L:12-15) et utilise `OperatorActionId`, `CycleStateStr`, `CycleStep`, `WaitingForOperator` directement (L:34-38, L:57-61). Aucune reconstruction dans PRG_03.

---

### AC3 — Verdict global

✅ **PASS** — Interface complète, conforme au profil AF-03. Aucune exigence manquante.

**Justification** :
- `Ready` : L:42 — présent
- `Fault` : L:43 — struct conforme
- `Lifecycle` : L:44 — struct conforme
- `CycleStepAtError` : L:45 — type exact `E_CycleStep`

---

### AC4 — Registre anomalies (sans correction)

| Anomalie | Fichier:ligne | Tâche recommandée |
|----------|--------------|-------------------|
| **X1** — Anomalie connue : `Reset` non front montant | `FB_Cycle.st` L:128 | G_CYCLE-fix-reset-front |
| **X11** — Kobold : `WaitForOperator` pas géré en mode Auto | `FB_Cycle.st` L:150-162 | G_CYCLE-fix-kobold-wait |
| **Sorties conservées** — `CycleStep` non persisté sur défaut hors capture | `FB_Cycle.st` L:170-175 | G_CYCLE-fix-step-persist |
| **Capture d'étape** — `CycleStepAtError` reste figé après défaut (pas de reset) | `FB_Cycle.st` L:180 | G_CYCLE-fix-step-reset |
| **Hors scope** : `PRG_03` déclare `CycleStep` comme `VAR_INPUT` de FB_Cycle — pas d'impact audit interface | `PRG_03_Modes_Cycle.st` L:12 | signalé, pas corrigé |

---

### 📌 Devoir d'alerte

- **Aucune modification effectuée** — mission read-only respectée.
- **Anomalies X1, X11, sorties conservées, capture d'étape** : listées ci-dessus, **non corrigées** — conformément au contrat.
- **Anomalie hors AC** : `PRG_03` utilise `CycleStep` en lecture seule mais `FB_Cycle` le déclare aussi en VAR_OUTPUT — pas de conflit (sortie = source, entrée = consommateur). Signalé pour traçabilité.

---

### ✅ Vérifications mécaniques (non requises ici — read-only, pas de build)

Aucune exécution de script nécessaire (aucune modification). Les fichiers ont été lus uniquement.