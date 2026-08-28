# Préambule obligatoire — sous-agent Ollama
Automate CODESYS 3.5, machine de dragage en carrière noyée. Code ST dans `CODE/`, appliqué manuellement.
Sécurité machine réelle. Expert Senior Automatisme. Style TDAH-Friendly. Réponds en français. Zéro blabla.

---

# MISSION T165-C0 : Audit READ-ONLY de FB_Cycle — Conformité profil AF-03

## Contrat (TASK_CONTRACT_T165-C0_AUDIT_FB_CYCLE_PREREQUISITE.yaml)
- **Criticité** : C4 — Pré-requis avant implémentation T165-C1/C2 (publication du bus Data vers PRG_03)
- **Mode** : LECTURE SEULE — AUCUNE modification de code
- **Objectif** : Vérifier si l'interface réelle de `FB_Cycle` satisfait le profil de composant AF-03 requis par `PRG_03_Modes_Cycle`

## Critères d'acceptation testables

### AC1 — Matrice interface réelle vs exigences AF-03
Comparer ligne par ligne l'interface `FB_Cycle` aux 4 exigences du profil :
- `Ready : BOOL` en VAR_OUTPUT
- `Fault : ST_Fault` en VAR_OUTPUT (struct avec `.Error : BOOL`, `.ErrorId : INT`)
- `Lifecycle : ST_Lifecycle` en VAR_OUTPUT (struct avec `.Busy`, `.Done`)
- Capture d'étape au défaut : `CycleStepAtError : E_CycleStep` ou équivalent

Produire une **table code:ligne → exigence → PASS/FAIL/BLOCK**.

### AC2 — Producteurs des sorties SequenceState
Vérifier que les sorties suivantes ont un producteur FB identifié dans `FB_Cycle` et ne sont PAS reconstituées dans `PRG_03` :
- `OperatorActionId : E_OperatorAxis` (ou nom exact présent)
- `CycleStateStr : STRING`
- `CycleStep : E_CycleStep`
- `WaitingForOperator : BOOL`

Produire une **matrice producteur → sortie → consommateur** (source dans FB_Cycle:ligne).

### AC3 — Verdict BLOCK si profil absent
Si une exigence est manquante → verdict BLOCK + proposer l'intitulé d'une tâche G_CYCLE séparée (fix+guard), sans modifier CODE.

### AC4 — Registre anomalies non-opportunistes
Lister sans corriger : X1, X11, Kobold, sorties conservées, capture d'étape. Juste liste + tâche recommandée.

## Fichiers à lire (READ ONLY)

1. `CODE/G_CYCLE/FB_Cycle.st` — interface complète + corps
2. `CODE/A_COMMUN/_TYPES/ST_Fault.st` — struct ST_Fault
3. `CODE/A_COMMUN/_TYPES/ST_Lifecycle.st` — struct ST_Lifecycle
4. `CODE/M_MAIN/PRG_03_Modes_Cycle.st` — consommateur de FB_Cycle
5. `CODE/G_CYCLE/_TYPES/E_CycleStep.st` — enum des étapes
6. `CODE/G_CYCLE/_TYPES/E_OperatorAxis.st` — enum des axes opérateur

## Format de restitution obligatoire

```
## T165-C0 — Audit FB_Cycle (READ-ONLY)

### AC1 — Matrice interface vs profil AF-03
| Exigence AF-03 | Nom réel | Ligne | Type réel | Verdict |
|----------------|----------|-------|-----------|---------|
| Ready          | ...      | L:..  | ...       | PASS/FAIL |
| Fault.Error    | ...      | ...   | ...       | ... |
| Lifecycle.Busy | ...      | ...   | ...       | ... |
| CycleStepAtError | ...    | ...   | ...       | ... |

### AC2 — Producteurs sorties SequenceState
| Sortie | Ligne producteur FB_Cycle | Consommateur PRG_03 | Reconstitué ? |
|--------|--------------------------|---------------------|---------------|
...

### AC3 — Verdict global
PASS / BLOCK (avec justification ligne par ligne si BLOCK)

### AC4 — Registre anomalies (sans correction)
| Anomalie | Fichier:ligne | Tâche recommandée |
|----------|--------------|-------------------|
...
```

## ⛔ INTERDITS ABSOLUS
- Aucune modification de fichier
- Aucun commit, push, reset
- Ne pas élargir le scope — signaler toute anomalie hors AC, ne pas la corriger
