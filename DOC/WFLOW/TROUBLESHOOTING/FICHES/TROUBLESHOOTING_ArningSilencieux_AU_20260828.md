# 🕵️ Session de Troubleshooting — Réarmement AU silencieux 1er essai boot — 20260828

> 📌 Fiche : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_ArningSilencieux_AU_20260828.md`
> 📅 Date : 2026-08-28 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [EN COURS]

## 1. 🧊 Contexte figé (horodaté)

- Snapshots fournis par l'utilisateur : `Snapshot_Troubleshooting_20260828_231317.csv`, `..231327`, `..231334`, `..231348` (`TOOLS/PLC_CSV_SNAPSHOT/RESULTS/snapshot/`).
- Situation : **simulation banc, premier boot**. Mode : `E_Mode.DISABLE` (idx101). Simulation active (idx102=TRUE).
- Chaîne : `Safety.HwIn_EmergencyChainClosed_DI` = TRUE (boutons relâchés). Contacteur : `HwIn_PowerContactorEngaged_DI` = FALSE au départ.
- Réarmement demandé via `BtnEmergencyArming` (IHM).

### Variables & valeurs (extraites des 4 snapshots)
| Élément | Variable | S1 231317 | S2 231327 | S3 231334 | S4 231348 |
|---|---|---|---|---|---|
| Chaîne AU contexte M1/M2 | ContexteMachineGlobal.Idx301 / LevageUnitaireM1/2.Idx301 | T | **F**/T | T | T |
| Contacteur puissance | ContexteMachineGlobal.Idx302 | F | F | F | **T** |
| Step armement | Safety.ArmingStep | 0 | 0 | 0 | 0 |
| ErrorId AU | Safety.ArmingErrorId | 0 | 0 | **0** | 0 |
| ArmBusy | Safety.ArmingBusy | F | F | F | F |
| Lockout | Safety.LockoutActive | F | F | F | F |
| PowerCutOffRequest | Safety.PowerCutOffRequest | F | F | F | F |
| PowerCutOffActiveAny | ContexteMachineGlobal.Idx304 | F | F | F | F |
| MaintainA/B | Safety.MaintainAActive/B | T/T | T/T | T/T | T/T |
| HwIn chaîne | Safety.HwIn_EmergencyChainClosed_DI | T | T | T | T |
| HwIn contacteur | Safety.HwIn_PowerContactorEngaged_DI | F | F | F | T |

## 2. 🎯 Symptôme

En simulation premier boot, le **1er réarmement AU échoue silencieusement** : retour à état initial « chain OK, contacteur OK », **0 erreur IHM**. Un **acquittement puis 2e tentative réarme** (S4 contacteur=T). L'utilisateur ignore pourquoi ni quoi faire. Permanent (reproductible au boot).

## 3. 🧩 Indices / historique

- Derniers changements : récent (projet en cours, refonte AU `FB_Safety_EmergencyManagement` + `FB_Sim_Safety`).
- Déjà essayé : acquittement global puis re-tentative → **réussit**.
- Conditions d'apparition : premier boot simulation, avant tout acquittement.
- Alarmes : aucune (ErrorId=0, ArmFailed=FALSE).

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| H1 | PowerCutOffRequest métier coupe la séquence | `Safety.PowerCutOffRequest` / `Idx304` | FALSE au repos (`PRG_06.st:295-297`) | FALSE (4 snapshots) | ❌ éliminée |
| H2 | Chaîne tombe (retour) pendant le test → sortie step 5/6 (`Logic:168`) | évolution `Idx301` vs temps | chaîne stable | **oscille F/T** (S2) | ⚠️ **candidat** |
| H3 | Restauration A/B non confirmée en 200ms → sortie step 2/4 (`Logic:207/234`) | simu temps de retour chaîne | retour < 200ms | non capturé (step=0 au snapshot) | ⚠️ **candidat** (non tranché) |
| H4 | Front ArmRequest avalé par autotest §2 (`RETURN` ligne 145 au 1er enable) | ordonnancement au boot | — | non capturé | ⚠️ **candidat** |
| H5 | Cause/Ack jamais posée : sortie silencieuse légitime (coupe volontaire) | `Bypass/forçage` | — | aucun forçage vu | ❌ |

## 5. 📊 Arbre vertical des hypothèses

```text
SYMPTÔME : 1er réarmement échoue sans message
├─ S1 état neutre [Safety.ArmingStep=0, ErrorId=0] ✅
├─ S2 test redondance : chaîne Idx301 oscille F/T sur structures (chute retours) 
│    └─ ❌ H1 PowerCutOffRequest = FALSE partout → éliminée
├─ S3 (t+7s) retour état initial [step=0, ErrorId=0, lockout=F] → échec AUCUNE cause
│    └─ sortie silencieuse : 168/207/234 OU front avalé §2 (145)
├─ S4 (t+14s) après acquittement + 2e essai → contacteur T ✅
└─ verdict : échec par SORTIE SILENCIEUSE, cause exacte à isoler par traçage (patch)
```

**Résumé** : `[PowerCutOffRequest=F] → [Idx301 oscille] → [step retombe=0 sans ErrorId] ⚠️ sortie silencieuse non identifiée`

## 6. 📊 Données / interactions & chronogramme (🟡)

### Lectures & essais
- 4 snapshots fournis, intervalle ~10-17s. Ordre temporel : S1(neutre) → S2(test, chaîne tombée) → S3(état initial, échec silencieux) → S4(réarmé).
- `Safety.PowerCutOffRequest` FALSE sur les 4 → H1 éliminée par preuve.

### Chronogramme
| Événement | Idx301 | Idx302 | Step | ErrorId |
|:---:|:---:|:---:|:---:|:---:|
| S1 neutre | T | F | 0 | 0 |
| → S2 test (chaîne tombe) | F/T | F | 0 | 0 |
| → S3 retour initial (échec) | T | F | 0 | **0** |
| → S4 après reset + 2e essai | T | T | 0 | 0 |

## 7. 🏁 Conclusion

- **Cause racine** : échec par **sortie silencieuse** de la séquence AU pendant le 1er essai au boot (branches `FB_Safety_EmergencyManagementLogic.st:168/207/234` ou front avalé à l'autotest `:145`). H1 (PowerCutOff) **éliminée par preuve**. Le step exact est NON capturable avec les variables de snapshot actuelles (todo T173-A : ajouter trace).
- **Statut** : à valider → suivi en tâche T173.

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** : refaire un 2e essai (comportement actuel) — non informatif.
- **Option 2 (définitif)** : tracer la cause d'abandon de séquence + produire erreur/message → tâche T173 (patch de traçage puis étude puis modification). **⚠️ Validation humaine requise avant tout code.**

## 9. ✅ Vérification de la correction / non-régression

- À compléter après T173 (le patch de traçage doit prouver la provenance, puis la correction doit supprimer toute sortie silencieuse et afficher un message ; non-régression : les 4 scénarios armement validés).

## 10. 📝 Journal (chronologique)

- 2026-08-28 : ouverture fiche. 4 snapshots analysés. H1 éliminée (PowerCutOff=F partout). Échec = sortie silencieuse, cause à isoler → création T173.
