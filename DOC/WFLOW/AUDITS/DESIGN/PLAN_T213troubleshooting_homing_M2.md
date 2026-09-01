# 🧩 PLAN — T213 — Refactorer le troubleshooting : variables de homing M2

| | |
|---|---|
| **ID** | T213 |
| **Criticité** | C2 (machine réelle — validation humaine avant compilation) |
| **Domaine** | OUTILLAGE (troubleshooting) |
| **Stratégie** | patch (pur ajout de diagnostic, zéro changement de logique) |
| **Contrat** | `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T213.yaml` |
| **Statut** | ⬜ à faire — plan prêt, **ARRET VALIDATION** avant écriture CODE/ |

---

## 🎯 Objectifs testables (repris du contrat)

1. **Exposer** dans `GVL_Troubleshooting.F_HomingM2` les variables détaillées du homing M2 (cible dynamique + offset benne + état FB_MachineHomingCycle), alimentées depuis leur source réelle (PRG_02_Acquisition bus Data + GVL_IHM).
2. **Régénérer** `troubleshooting_variables.txt` depuis `CODE` (via `generate_variable_list_from_code.py`) avec toutes les nouvelles feuilles, sans divergence.
3. **Permettre le diagnostic** du bug homing M2 « benne fermée » (M2 reste à 8.5 m au lieu de prendre la cible dynamique).
4. **Aucun changement de comportement machine** : logique homing (FB_MachineHomingCycle, PRG_02 §4, facades codeur) intacte.
5. **Valider avec l'humain** avant toute compilation.

### Variables à exposer — source de vérité

| Variable | Type | Source réelle (producteur unique) | Champ cible dans F_HomingM2 |
|---|---|---|---|
| `MachineHomingMechanicalStopOk` | BOOL | `PRG_02_Acquisition.MachineHomingMechanicalStopOk` | `MechanicalStopOk` |
| `BucketReferenceRequested` | BOOL | `PRG_02_Acquisition.BucketReferenceRequested` | `BucketReferenceRequested` |
| `UseDynamicTarget` (M2) | BOOL | `instEncoderM2.UseDynamicTarget` | `UseDynamicTarget` |
| `DynamicHomingTargetM` | REAL | `instEncoderM2.DynamicHomingTargetM` | `DynamicHomingTargetM` |
| `M2Demand.HomeReq` | BOOL | `instMachineHomingCycle.M2Demand.HomeReq` | `M2DemandHomeReq` |
| `M2Demand.UseDynamicTarget` | BOOL | `instMachineHomingCycle.M2Demand.UseDynamicTarget` | `M2DemandUseDynamicTarget` |
| `M2Demand.DynamicTarget_M` | REAL | `instMachineHomingCycle.M2Demand.DynamicTarget_M` | `M2DemandDynamicTarget_M` |
| `CfgTopHomingTarget_M` | REAL | `MachineHomingCfg.CfgTopHomingTarget_M` | `CfgTopHomingTarget_M` |
| `CfgOffsetClose_M` | REAL | `MachineHomingCfg.CfgOffsetClose_M` | `CfgOffsetClose_M` |
| État FB_MachineHomingCycle | BOOL/INT | `instMachineHomingCycle.MachineHomed / MachineHomingActive / MachineHomingStep / MachineHomingFailed` | `MachineHomed / HomingCycleActive / HomingCycleStep / HomingCycleFailed` |

> ⚠️ **Chaîne de causalité du bug visé** : `M2Demand.UseDynamicTarget` ⇒
> `instEncoderM2.UseDynamicTarget` ⇒ cible = `CfgTopHomingTarget_M + CfgOffsetClose_M`
> en « benne fermée ». Le snapshot doit montrer chaque maillon pour voir où M2
> reste à 8.5 m.

---

## 🧱 Découpage en phases

### 🔹 Phase 1 — Cadrage & contrat (fait)
- [x] Lire T213 dans `TASKS.yaml`, spécs `AF_Partie-09` (v2.4), `AF_Partie-14` (v1.4), source `PRG_02_Acquisition.st`, `FB_MachineHomingCycle.st`, `GVL_Troubleshooting.st`, `FB_TroubleshootingView.st`.
- [x] Rédiger `TASK_CONTRACT_T213.yaml` + passer `check_task_contract.py`.
- [x] Rédiger ce plan + **ARRET VALIDATION** (humain C2).

### 🔹 Phase 2 — Étendre la structure de diagnostic (bloquée par P1)
- **2a.** Étendre `CODE/J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_HomingChecklist.st` (membre `F_HomingM2`) avec les champs détaillés homing M2 (tableau ci-dessus) — nomenclature `*Checklist` respectée.
- **2b.** Étendre `CODE/G_CYCLE/_TYPES/ST_MachineHoming.st` (bus `Data.MachineHoming`) : ajouter les valeurs intermédiaires à publier (mécanique stop OK, demande référence, cible dynamique calculée, offset) — si le bus existant ne les porte déjà pas.
- *Gate 2* : `bundle + G200 PASS` (aucun lien cassé par l'ajout de champs).

### 🔹 Phase 3 — Publier les faits par PRG_02 (bloquée par P2)
- **3a.** Dans `CODE/M_MAIN/PRG_02_Acquisition.st` (§4 homing) : publier les valeurs homing M2 sur `Data.MachineHoming.*` (mécanique stop OK, référence demandée, cible dynamique, offset, état FB) — **producteur unique** conservé.
- *Gate 3* : `bundle + G200 PASS` ; grep des chemins publiés dans le bundle.

### 🔹 Phase 4 — Projeter via FB_TroubleshootingView (bloquée par P2+P3)
- **4a.** Ajouter les `VAR_INPUT` au `FB_TroubleshootingView.st` portant la structure homing M2 (reçoit `Data.MachineHoming` depuis PRG_02 + compléments GVL_IHM si besoin).
- **4b.** Dans `CODE/M_MAIN/PRG_07_Supervision.st` (appel `instTroubleshootingView`) : câbler les nouvelles entrées depuis `PRG_02_Acquisition.Data` (et GVL_IHM).
- **4c.** Dans `FB_TroubleshootingView.st` §6 : affecter chaque champ cible `GVL_Troubleshooting.F_HomingM2.*` — **lecture seule stricte, aucune commande/calcul métier**.
- *Gate 4* : `bundle + G200 PASS` + revue diff (AC4).

### 🔹 Phase 5 — Régénérer la liste + auto-vérification (bloquée par P4)
- **5a.** Exécuter `python TOOLS/PLC_CSV_SNAPSHOT/variable_lists/generate_variable_list_from_code.py --output ...` puis comparer sans différence avec `troubleshooting_variables.txt` (AC3).
- **5b.** `bundle frais + G200 PASS (0 erreur) + run_all_gates.py --palier C` (AC5/AC6).

### 🔹 Phase 6 — Documentation (parallèle P4→P5)
- **6a.** Mettre à jour `DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md` : section homing conjoint — renvoyer aux nouvelles feuilles de diagnostic M2.
- **6b.** Mettre à jour `DOC/AF/AF_Partie-14_Fonction_Troubleshooting_v1.4.md` : table de visu homing M2 (nouveaux champs exposés).
- *(Parallélisable avec P4/P5 — pas de dépendance bloquante).*

### 🔹 Phase 7 — ARRET VALIDATION finale & restitution (bloquée par P5+P6)
- Restitution : bandeau conformité + validation humaine du snapshot réel avant intégration CODESYS.

---

## 🧪 Plan de TEST

### Cas à couvrir
| TC | Cas | Résultat attendu | Gate |
|---|---|---|---|
| TC-01 | Bundle généré après ajout champ | `G200 PASS` (0 erreur), pas de lien cassé | P2→P5 |
| TC-02 | Régénération `troubleshooting_variables.txt` | comparaison sans différence (AC3) | P5a |
| TC-03 | `check_task_contract.py T213.yaml` | `PASS` (T1..T8, T8 structurel OK) | P1 |
| TC-04 | Snapshot réel en MAINT_N2, fenêtre homing benne fermée | colonnes homing M2 visibles ; `UseDynamicTarget` actif, `DynamicHomingTargetM = CfgTop + CfgOffsetClose` (AC7) | P7 |
| TC-05 | Diff `FB_MachineHomingCycle.st` | `vide` — logique homing immuable (AC5) | P5b |
| TC-06 | `run_all_gates.py --palier C` | PASS (no new regression ; baseline pré-existante documentée) | P5b |
| TC-07 | Nommage des nouveaux champs | conforme `NC-xxx` (suffixes, unités `M`, polarité) (AC6) | P4/P7 |

> ⚠️ TC-04 nécessite **export CODESYS frais** (jamais `Device.export` du dépôt) puis
> intégration manuelle et snapshot réel — action humaine.

---

## ⚙️ Plan CI — Gates à chaque étape

| Palier | Quand | Commandes |
|---|---|---|
| **A** | P1 (contrat) | `python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T213.yaml` |
| **B** | fin P2/P3/P4 (structure + publication + projection) | `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` + `python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report` |
| **C** | fin P5 (liste + lot complet) | `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C` (puis `--palier D` si énoncé) |

---

## 🤝 Prévision d'assignation AGENT

| Rôle | Acteur | Portée |
|---|---|---|
| **Implémentation** | sous-agent (DSH/Codex) — Phases 2→5 | structures, publication bus, projection, régénération liste |
| **Revue technique indépendante** | second sous-agent ou orchestrateur | revue diff réel (`git diff`), audit nommage, lecture-seule FB, FB_MachineHomingCycle immuable |
| **Validation humaine (autorité finale)** | humain | **ARRET VALIDATION** plan P1 + **validation finale** avant compilation (TC-04/snapshot réel) |

> 📌 La validation finale reste à l'orchestrateur/humain (lecture du `git diff`
> réel), jamais à l'agent qui a produit le code.

---

## 📚 Modifications DOC à prévoir

- **Specs** : `DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md` (homing conjoint & cible dynamique) · `DOC/AF/AF_Partie-14_Fonction_Troubleshooting_v1.4.md` (table de visu homing M2).
- **Naming** : `DOC/STDS/NAMING_CONVENTION.md` — **ne pas modifier**, seulement l'auditer (NC-xxx) pour valider les nouveaux noms de champs.
- **Registres** : `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/troubleshooting_variables.txt` (régénéré) · `TOOLS/TEST_AUTO_CI/registry.yaml` (si un test couvre la liste) · `DOC/WFLOW/TASKS.yaml` (statut `⬜ → ⏳ → ✅`).

---

## 🛑 ARRETS DE VALIDATION HUMAINE

| # | Où | Motif |
|---|---|---|
| **ARRET VALIDATION 1** | fin Phase 1 (ce plan) | Criticité C2 machine réelle : aucun code ne s'écrit sans accord humain sur ce plan. |
| **ARRET VALIDATION 2** | fin Phase 7 (restitution) | Validation humaine du snapshot/troubleshooting réel (TC-04) obligatoire avant intégration/compilation CODESYS ; aucun commit sans validation explicite. |

---

> 🔒 **Rappel AGENTS.md** : le travail pré-code de cette livraison (contrat + plan)
> ne modifie **aucun** fichier de `CODE/`. L'implémentation (Phases 2→5) reste
> bloquée tant que `ARRET VALIDATION 1` n'est pas levé par l'humain.
