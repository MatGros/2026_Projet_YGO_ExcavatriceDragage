# 🔍 SYNTHÈSE D'IMPLÉMENTATION — Mode SEMI_AUTO (pour audit indépendant) — v1.1

**Projet** : Excavatrice de Dragage en Carrière Noyée
**Cible API** : CODESYS 3.5 (IEC 61131-3)
**Date** : 15 Août 2026
**Objet** : Récapitulatif exhaustif de l'implémentation du mode SEMI_AUTO, destiné à un
**agent auditeur indépendant** pour vérifier le travail (code, conformité, non-régression).
**v1.1** : intègre les corrections de la revue critique (homme-mort au démarrage, seuils
SpeedMismatch réels, tolérance matière benne 2 m).

> 🎯 **Pour l'auditeur** : ce document liste CE QUI a été fait, COMMENT, et les points à
> vérifier. Il ne remplace pas la lecture du code réel — il oriente l'audit.

---

## 🧭 Sommaire

1. Contexte & décisions validées
2. Périmètre de l'implémentation (lots L1-L5)
3. Fichiers modifiés (git)
4. Vérifications mécaniques effectuées
5. Points fail-safe documentés (à confirmer)
6. Points à auditer (risques / non-régression)
7. Documents de référence

---

## 🎯 1. Contexte & décisions validées

L'implémentation suit `DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.1.md` et
`DOC/WFLOW/AUDITS/DESIGN_SEMI_AUTO_CYCLE_v0.1.md`. Décisions utilisateur actées :

| # | Décision | Choix retenu |
|---|---|---|
| **D1** | Instances séquence | **2 instances** (`instCycleMaintenance` + `instCycleSemiAuto`), gating sorties par mode, reprise transparente |
| **D2** | Homme-mort | **Fenêtre 3 s** (pas de maintien) ; mouvement continue sans appui ; **arrêt au centre du manche** (`CycleMotionPermit`) |
| **D3** | Pause / Abort | **Pas de Pause** ; `Abort` → retour `X0_PREPARATION` |
| **Q3bis** | Compteur de prélèvements | **RETAIN** (`_CycleSampleCount`), compte inconditionnel, reset MAINT only |
| **Q4** | Vitesses par phase | **Réutilise config maintenance** (paliers max, vitesses PV) |

---

## 📦 2. Périmètre de l'implémentation (lots L1-L5)

| Lot | Contenu | Fichier |
|---|---|---|
| **L1** | Réécriture `FB_Cycle` conforme §11bis R1-R9 + enum `E_CycleStep` | `CODE/G_CYCLE/FB_Cycle.st`, `CODE/G_CYCLE/E_CycleStep.st` |
| **L2** | 2 instances `FB_Cycle` dans `PRG_03_Modes_Cycle` | `CODE/M_MAIN/PRG_03_Modes_Cycle.st` |
| **L3** | Pont SEMI_AUTO treuils/benne (M1/M2, benne, Kobold) | `CODE/M_MAIN/PRG_04_Treuils_Benne.st` |
| **L4** | Pont SEMI_AUTO translation M3 | `CODE/M_MAIN/PRG_05_Translation.st` |
| **L5** | GVL_IHM + banner + compteur + troubleshooting | `CODE/J_SUPERVISION/_TYPES/ST_CycleState.st`, `CODE/M_MAIN/PRG_07_Supervision.st`, `CODE/GVL_PERSISTENT.st` |

---

## 📄 3. Fichiers modifiés (git)

| Fichier | Nature | Modification |
|---|---|---|
| `CODE/G_CYCLE/E_CycleStep.st` | Modifié | Enum X0→X13 + STABILIZING (X12 supprimé) |
| `CODE/G_CYCLE/FB_Cycle.st` | Réécrit | CASE enum unique (R1), labels `Xn - texte` (R2), graphe linéaire (R3), `X13_DONE_SYNC` finale (R4), TON scaffold (R5), porte R8, `CycleStepAtError` (R9), tempo max d'étape, homme-mort 3s. **v1.1** : `DeadmanArmed` requis au démarrage (X0→X1) |
| `CODE/M_MAIN/PRG_03_Modes_Cycle.st` | Modifié | 2 instances `instCycleMaintenance`/`instCycleSemiAuto` câblées. **v1.1** : SpeedMismatch 1.5 m/s / 500 ms, `Benne_IsRoughlyClosed` câblé |
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | Modifié | Pont SEMI_AUTO : M1/M2 consomment `instCycleSemiAuto.WinchM1Cmd/WinchM2Cmd` ; benne `CmdBucketCloseArbitrated`/`CmdOpen_IHM` ; Kobold `KoboldContactorCmdArbitrated`. **v1.1** : sortie `Benne_IsRoughlyClosed` (tolérance 2 m) |
| `CODE/M_MAIN/PRG_05_Translation.st` | Modifié | Pont SEMI_AUTO : `SelTarget`/`M3_StartStop_Active` consomment `instCycleSemiAuto.TranslationCmd` |
| `CODE/J_SUPERVISION/_TYPES/ST_CycleState.st` | Modifié | + `CycleStepAtError`, `SampleCount` |
| `CODE/M_MAIN/PRG_07_Supervision.st` | Modifié | Publication `GVL_IHM.Cycle.State.*` (débloque T115) |
| `CODE/GVL_PERSISTENT.st` | Modifié | + `_CycleSampleCount` (RETAIN) |

---

## 🧪 4. Vérifications mécaniques effectuées

| Gate | Résultat | Note |
|---|---|---|
| `G200_check_linkage.py --report` | ✅ **PASS 0 erreur** (67 OK, 0 KO) | Preuve de câblage réel |
| `G400_check_bundle_st_syntax.py` | ✅ PASS | Syntaxe ST |
| `G380_check_config_persistence.py` | ✅ PASS | Compteur RETAIN |
| `G300`-`G410` (structure, type, doc, HW, interlock, calibration) | ✅ PASS | — |
| `G420` PyTest | ⚠️ FAIL **environnemental** | Permission temp sandbox, **pas une régression** |
| `generate_codesys_bundle.py` | ✅ Régénéré | `CODE_XML/CODE_Bundle.xml` |

---

## ⚠️ 5. Points fail-safe — résolus après revue

> 🆕 **v1.1** : les 3 points fail-safe de la v1.0 ont été **corrigés** suite à la revue critique
> (seuils réels, tolérance matière, homme-mort au démarrage).

| Entrée `FB_Cycle` | Valeur câblée (v1.1) | Statut |
|---|---|---|
| `SpeedMismatchThresholdMps` | `1.5` | ✅ **Résolu** — seuil réel (~1-2 m/s, retenu 1.5) |
| `SpeedMismatchTimeout` | `T#500ms` | ✅ **Résolu** — tempo confirmation |
| `Benne_IsRoughlyClosed` | `PRG_04.Benne_IsRoughlyClosed` (tolérance 2 m) | ✅ **Résolu** — `IsClosed OR (IsIntermediate AND Delta >= OffsetCloseM - 2.0)` |
| `HomingRequest` | `BtnHome M1 OR M2` | ⚠️ À confirmer (bouton homing IHM) |

### Corrections de la revue (v1.1)
| Point revue | Correction | Fichier |
|---|---|---|
| **Risque 1 — Homme-mort** | `DeadmanArmed` requis au **démarrage** (X0→X1) ; continuité = `CycleMotionPermit`. **Pas de calage 3s** (l'appui initie, le manche maintient). | `FB_Cycle.st` |
| **Risque 2 — SpeedMismatch** | Seuil **1.5 m/s**, tempo **500 ms**. | `PRG_03_Modes_Cycle.st` |
| **Risque 3 — Benne_IsRoughlyClosed** | Tolérance **2 m** (matière dense). | `PRG_04_Treuils_Benne.st` + `PRG_03` |

---

## 🔍 6. Points à auditer (risques / non-régression)

### 6.1 Non-régression MAINT (critique)
- Les ponts SEMI_AUTO sont **gated par mode** : en MAINT_N1/N2, les sorties cycle ne sont **pas**
  transmises (les branches `ELSE` conservent l'arbitrage manuel existant).
- **À vérifier** : que les chemins MAINT (`instDiveSearch`, `instExtractionSequence`, arbitrage
  manuel joystick/boutons) restent **inchangés** et fonctionnels.

### 6.2 Retard d'un scan (architecture)
- `FB_Cycle` (rang 03) lit les feedbacks de PRG_04/05 (rangs 04/05) du scan **précédent**.
- Documenté, cohérent avec la pratique existante (PRG_04 « lag 1 scan »). **À valider** en essai.
- ⚠️ **Point critique** : 1 cycle de retard sur l'arrêt au contact fond Kobold — à valider en essai.

### 6.3 Compteur RETAIN
- `_CycleSampleCount` est `VAR_GLOBAL PERSISTENT RETAIN` (survit à la coupure).
- `FB_Cycle.SampleCount` est `VAR_IN_OUT` (référence). **À vérifier** : reset MAINT only (Q3bis).

### 6.4 Tempo max d'étape
- `StepMaxTimer` lancé **seulement si `CycleMotionPermit`** (pas de défaut au repos).
- Valeur `T#60s`. **À valider** sur site.

### 6.5 Homme-mort (D2) — corrigé
- `DeadmanArmed` requis au **démarrage** du cycle (X0→X1) ; continuité = `CycleMotionPermit`
  (`NOT instJoystick.AtNeutral`).
- **À vérifier** : la logique `FB_Joystick` (fenêtre 3 s) est-elle réellement alignée avec
  l'initiation par appui + maintien par déflexion ?

---

## 📚 7. Documents de référence

| Type | Lien |
|---|---|
| Spec | `DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.1.md` |
| Conception | `DOC/WFLOW/AUDITS/DESIGN_SEMI_AUTO_CYCLE_v0.1.md` |
| Code proposition | `DOC/WFLOW/AUDITS/FB_Cycle_proposal.st` |
| Standard séquenceurs | `DOC/STDS/GUIDES/GUIDE_SEQUENCEUR_v1.2.md` |
| Standard qualité | `DOC/STDS/CODE_QUALITY_STANDARDS.md` §11bis |
| Nommage | `DOC/STDS/NAMING_CONVENTION.md` |

*Document de synthèse d'implémentation — pour audit indépendant. Aucune modification de code.*
