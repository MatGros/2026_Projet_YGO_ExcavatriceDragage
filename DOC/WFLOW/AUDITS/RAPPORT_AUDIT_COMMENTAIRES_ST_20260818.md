# 📋 Rapport d'Audit — Conformité des Commentaires CODE/*.st (Standard §2ter)

> 📅 Date : 2026-08-18 · 🔍 Méthode : audit exhaustif des 170 fichiers `CODE/*.st` (fan-out 10 sous-agents) + scan complémentaire ciblé.
> 📏 Référentiel : `DOC/STDS/CODE_QUALITY_STANDARDS.md` **§2ter** (Zéro « Journal Intime / REX » dans le Code) + §2 (cartouche ≤ 15 lignes) + §2ter.3 (régions concises).

---

## 🎯 Synthèse

| Métrique | Valeur |
|---|---|
| Fichiers audités | **170** |
| Fichiers avec violations | **~55** |
| Violations totales | **~120** |
| — type `REX` (journal intime / lot / date / correctif) | **~70** |
| — type `verbose` (récit de développement / refactor) | **~45** |
| — type `header_too_long` (cartouche > 15 lignes) | **2** |
| — type `region_rex` | 0 |

> ⚠️ Le code est **globalement non conforme** au §2ter : la majorité des commentaires de développement (REX, lots, dates, récits de correctif) ont été laissés dans le code au lieu d'être déplacés dans `DOC/`.

---

## 📂 Fichiers concernés (par dossier)

### 🔴 Priorité haute — fichiers métier/sécurité (REX nombreux)
| Fichier | Violations | Exemples |
|---|---|---|
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | ~20 | `(Fiche 01, demande client)`, `FICHE 05`, `(18)`, `(T111)`, `(T114)`, `(9)`, `(26)`, `(27)` |
| `CODE/GVL_PERSISTENT.st` | 8 | `MES-008`, `MES-009`, `MES-010`, `MES-007/T78`, `7.5 -> 7.0 -> 6.75 (demande client)`, `T66`, `T81/T82` |
| `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` | 4 | `WINCH-CORE-01`, `BrakeFeedback ajouté`, `Auparavant seul...`, `n'a visiblement pas suffi` |
| `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` | 2 | `faisait dépasser la cible réelle`, `restait figé sur OffsetOpenM (défaut)` |
| `CODE/G_CYCLE/FB_Cycle.st` | 4 | `T36`, `T43` (x3) |
| `CODE/M_MAIN/PRG_05_Translation.st` | 4 | `(L4)`, `T106`, `supprimé`, `déplacée` |
| `CODE/M_MAIN/PRG_07_Supervision.st` | 2 | `T83 (décision CK6)`, `Ajouté ici` |
| `CODE/H_TREUILS_BENNE/FB_Winch.st` | 1 | `WINCH-CORE-01` |
| `CODE/H_TREUILS_BENNE/FB_WinchSync.st` | 1 | `T113` |
| `CODE/D_JOYSTICK/FB_Joystick.st` | 1 | commentaire homme-mort très verbeux (L174) |

### 🟠 Priorité moyenne — GVL_IHM & types supervision
| Fichier | Violations | Exemples |
|---|---|---|
| `CODE/J_SUPERVISION/GVL_IHM.st` | 3 | `(2026-08)`, bloc `IHM_MANU supprimé`, bloc `NOTE procédure banc retirée (L2→L4d, L5→L8)` |
| `CODE/J_SUPERVISION/_TYPES/ST_CommunHMI.st` | 5 | `(demande utilisateur)`, `etaient ecrits par erreur`, `FIX :`, `MES-008`, `(Fiche 05)` |
| `CODE/J_SUPERVISION/_TYPES/ST_ModesCmd.st` | 4 | `ex-MachineReset`, `TASK-0001`, `consolidé en switch UNIQUE`, `comportement historique` |
| `CODE/J_SUPERVISION/_TYPES/ST_HwMachine.st` | 4 | `Lot L5`, `renommé depuis... (Device_IO_20260812)` (x2), `pas encore câblé` |
| `CODE/J_SUPERVISION/_TYPES/ST_HwTranslation.st` | 2 | `Lot L5`, `T96` |
| `CODE/J_SUPERVISION/_TYPES/ST_CommunCfg.st` | 4 | `rapatriés depuis ST_WinchCfg`, `Blocage instantané à 0m`, `retiré`, `(4) — Fiche 01` |
| `CODE/J_SUPERVISION/_TYPES/ST_Bypass*.st` (Bucket/Network/Translation/Winch) | 6 | `FIX persistance` (x4), `PRG_SUPERVISION_CFC.st` |
| `CODE/J_SUPERVISION/_TYPES/ST_CycleState.st` | 3 | `(T43/T45)`, `(R9)`, `(Q3bis)` |
| `CODE/J_SUPERVISION/_TYPES/ST_WinchCfg.st` | 2 | `déplacés vers...`, `FIX : flag restauration` |
| `CODE/J_SUPERVISION/_TYPES/ST_BucketCmd.st` | 2 | `(18)`, `(18bis)` |
| `CODE/J_SUPERVISION/_TYPES/ST_ChainDredgingAssist.st` | 2 | `(9)` (x2) |
| `CODE/J_SUPERVISION/_TYPES/ST_ChainBucket.st` | 1 | `(Fiche 05)` |
| `CODE/J_SUPERVISION/_TYPES/ST_Chain_Translation_Inputs.st` | 1 | `T96` |
| `CODE/J_SUPERVISION/_TYPES/ST_CycleCfg.st` / `ST_CycleHMI.st` | 2 | `T66` |
| `CODE/J_SUPERVISION/_TYPES/ST_EncoderHMI.st` | 1 | `(2026-08, réorganisation)` |
| `CODE/J_SUPERVISION/_TYPES/ST_WinchState.st` | 1 | `(déplacés 2026-08)` |
| `CODE/J_SUPERVISION/_TYPES/ST_HwOperator.st` / `ST_HardwareImage.st` / `ST_HwWinch.st` | 3 | `Lot L5` |
| `CODE/J_SUPERVISION/_TYPES/ST_BypassCommun.st` | 2 | cartouche 16 lignes + `(demande client)` + `renommé` |
| `CODE/J_SUPERVISION/_TYPES/ST_SyncCmd.st` | 1 | `ex-OverrideSync inversé` |
| `CODE/J_SUPERVISION/_TYPES/ST_BucketHMIState.st` | 1 | `ex-champ "State", renommé` |
| `CODE/J_SUPERVISION/_TYPES/ST_SyncCfg.st` / `ST_SyncState.st` | 2 | `ex-CfgInitialized renommé`, `ex-"State", renommé` |
| `CODE/J_SUPERVISION/_TYPES/ST_TranslationCfg.st` / `ST_TranslationCmd.st` / `ST_TranslationHMI.st` / `ST_TranslationFinalInterlockRequest.st` | 4 | `créé suite constat terrain`, `PAR AXE supprimé`, `manquait`, `FIX :` |
| `CODE/J_SUPERVISION/_TYPES/ST_WinchBenneHMI.st` / `ST_WinchFinalInterlockRequest.st` | 2 | `IEC 61131-3 n'offre pas d'héritage`, `(retrait FB_Brake)` |
| `CODE/J_SUPERVISION/_TYPES/ST_SafetyChecklist.st` | 1 | `Absent jusqu'ici : diagnostiquer...` |
| `CODE/J_SUPERVISION/_TYPES/ST_DredgingAssistCmd.st` / `ST_DredgingAssistState.st` | 2 | `(9)` |

### 🟡 Priorité basse — simulation & divers
| Fichier | Violations | Exemples |
|---|---|---|
| `CODE/L_SIMULATION/FB_Sim_Encoder.st` | 3 | **cartouche 28 lignes** (>15), `Extraction PURE de la logique`, `RawPos déplacé en VAR_IN_OUT` |
| `CODE/L_SIMULATION/FB_SimBench.st` | 3 | `Lot L6`, `P1 Lot L6` (x2) |
| `CODE/M_MAIN/GVL_Global.st` | 2 | `orphelines`, `jamais appelée` |
| `CODE/M_MAIN/PRG_06_Outputs_LD.st` | 3 | `T72-T74`, `ajoutée`, `renommées` |
| `CODE/E_CODEURS/FB_Encoder_Scale.st` | 2 | `(à coller dans la partie déclaration...)` |
| `CODE/H_TREUILS_BENNE/FB_DriftGuard.st` | 1 | `(à coller dans le corps ST...)` |

---

## 🛠️ Actions à mener (par priorité)

### 🔴 Action 1 — Purge REX des fichiers métier/sécurité (bloquant)
**Périmètre** : `PRG_04`, `GVL_PERSISTENT`, `FB_Safety_Winch`, `FB_Bucket`, `FB_Cycle`, `PRG_05`, `PRG_07`, `FB_Winch`, `FB_WinchSync`, `FB_Joystick`.
**Action** : retirer les références de lot (`Txxx`, `Lx`, `Fiche xx`, `(9)`, `(18)`, `MES-xxx`), dates, et récits de correctif. Garder le rôle métier. **La traçabilité vit dans `DOC/`** (VERSION_HISTORY, AF, PLAN_TASK, fiches).
**Risque** : ⚠️ **sécurité** — ne pas altérer la logique, uniquement les commentaires. Vérifier `G200` liaison + gates après.

### 🟠 Action 2 — Purge REX/verbose des types supervision (`J_SUPERVISION/_TYPES/`)
**Périmètre** : ~25 fichiers `ST_*` (CommunHMI, ModesCmd, HwMachine, HwTranslation, CommunCfg, Bypass*, CycleState, WinchCfg, BucketCmd, ChainDredgingAssist, etc.).
**Action** : retirer `(demande client)`, `FIX :`, `renommé depuis`, `déplacé`, `ex-...`, `Lot L5`, dates. Garder le rôle du champ.

### 🟡 Action 3 — Cartouches > 15 lignes
**Périmètre** : `FB_Sim_Encoder` (28 lignes), `ST_BypassCommun` (16 lignes).
**Action** : réduire à ≤ 15 lignes (rôle + E/S essentielles).

### 🟡 Action 4 — Instructions de collage (`(à coller dans...)`)
**Périmètre** : `FB_Encoder_Scale`, `FB_DriftGuard`.
**Action** : supprimer (le corps ST est déjà dans le fichier).

### 🟡 Action 5 — Commentaire verbeux homme-mort
**Périmètre** : `FB_Joystick.st` L174.
**Action** : condenser au rôle métier.

---

## 📌 Recommandations

1. **Traiter par lot** (un dossier à la fois), avec `git diff` vérifié et gates verts après chaque lot — aligné sur le chantier T123 déjà fait.
2. **Ne pas toucher à la logique** : uniquement les commentaires. Vérifier `G200` liaison + `run_all_gates.py` après.
3. **Déplacer la traçabilité** : les REX retirés du code doivent être reportés dans `DOC/VERSION_HISTORY.md` / fiches / PLAN_TASK si non déjà tracés.
4. **Garde-fou** : envisager un gate `Gxxx` qui détecte les patterns REX (`T\d+`, `L\d`, `MES-\d`, `Fiche`, `demande client`, `renommé`, `déplacé`, dates) dans les commentaires `CODE/*.st` — pour empêcher la régression (règle `fix:` + `guard:`).

---

## ⚠️ Note
- Le rapport est basé sur l'audit fan-out (170 fichiers) + scan complémentaire des 20 derniers fichiers (résultat tronqué). Les comptages sont des **estimations** (~120 violations / ~55 fichiers) — à affiner lot par lot.
- **Aucun fichier n'a été modifié** par cet audit (lecture seule).
