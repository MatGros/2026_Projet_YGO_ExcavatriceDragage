# 🕵️ Session de Troubleshooting — Recherche de Blocage et de Panne — Blocage Synchro M1/M2 + Échec silencieux réarmement AU

> 📌 **Emplacement obligatoire** : Créer la fiche sous `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_<SujetCourt>_AAAAMMJJ.md`.
> 📅 Date : 2026-08-31 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [OUVERTE]

## 1. 🧊 Contexte figé (horodaté)

> Snapshot horodaté : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/snapshot/Snapshot_Troubleshooting_20260831_101017.csv` (495 var).
> **Re-figer si > 5 min** ou si un événement (redémarrage, changement de mode) avant de conclure.

### Texte de contexte
- **Situation** : [SIMULATION BANC] — `SimulationModeActive=TRUE`, `SimSafetyActive=TRUE`.
- **Mode machine** : `E_Mode.DISABLE` (au moment du snapshot — l'opérateur a quitté le mode maintenance après le blocage).
- **Référencement** : M1 et M2 homed (`HomingM1.HomingHomed=TRUE`, `HomingM2.HomingHomed=TRUE`).
- **Chaîne AU** : fermée (`EmergencyChainClosed=TRUE`), **contacteur puissance OFF** (`PowerContactorEngaged=FALSE`).
- **Écart synchro** : M1=8,50 m, M2=17,82 m → `SyncDelta_M=-9,32 m` (écart anormal, > tolérance critique).

### Variables & valeurs
| <nobr>Élément</nobr> | <nobr>Variable complète</nobr> | Valeur | <nobr>Horodatage</nobr> |
|---|---|---|---|
| Mode | `ContexteMachineGlobal.Idx101_ModeActive` | `E_Mode.DISABLE` | 10:10:17 |
| Chaîne AU | `ContexteMachineGlobal.Idx301_EmergencyChainClosed` | `TRUE` | 10:10:17 |
| Contacteur puissance | `ContexteMachineGlobal.Idx302_PowerContactorEngaged` | `FALSE` | 10:10:17 |
| SafeStop agrégé | `ContexteMachineGlobal.Idx303_SafeStopActiveAny` | `FALSE` | 10:10:17 |
| PowerCutOff agrégé | `ContexteMachineGlobal.Idx304_PowerCutOffActiveAny` | `FALSE` | 10:10:17 |
| Pos M1 | `LevageSynchroniseM1M2.Idx101_M1_CablePos_M` | `REAL#8.5` | 10:10:17 |
| Pos M2 | `LevageSynchroniseM1M2.Idx102_M2_CablePos_M` | `REAL#17.8234863` | 10:10:17 |
| Écart synchro | `LevageSynchroniseM1M2.Idx103_SyncDelta_M` | `REAL#-9.323486` | 10:10:17 |
| Demande synchro IHM | `LevageSynchroniseM1M2.Idx202_SyncEnabled_IHM` | `FALSE` | 10:10:17 |
| **Défaut synchro actif** | `LevageSynchroniseM1M2.Idx302_SyncFaultActive` | **`TRUE`** | 10:10:17 |
| Mouvement synchro autorisé | `LevageSynchroniseM1M2.Idx401_SyncMotionAllowed` | `FALSE` | 10:10:17 |
| Erreur synchro cycle | `CycleSemiAuto.Idx306_WinchSyncError` | `TRUE` | 10:10:17 |
| MecaE M1 | `LevageUnitaireM1.Safety_300.Idx317_ErrorMecaE` | `FALSE` | 10:10:17 |
| MecaE M2 | `LevageUnitaireM2.Safety_300.Idx317_ErrorMecaE` | `FALSE` | 10:10:17 |
| **Dernière étape abandon AU** | `Safety.LastAbortStep` | **`INT#5`** | 10:10:17 |
| **Cause dernier abandon AU** | `Safety.LastAbortCause` | **`WORD#16` (16#0010 = PowerCutOff)** | 10:10:17 |
| PowerCutOffRequest | `Safety.PowerCutOffRequest` | `FALSE` | 10:10:17 |
| PowerCutOffActive | `Safety.PowerCutOffActive` | `FALSE` | 10:10:17 |
| Contacteur puissance | `Safety.PowerContactorEngaged` | `FALSE` | 10:10:17 |
| Échec armement | `Safety.ArmingFailed` | `FALSE` | 10:10:17 |
| Redondance | `Safety.RedundancyTestFailed` | `FALSE` | 10:10:17 |
| ErrorId armement | `Safety.ArmingErrorId` | `WORD#0` | 10:10:17 |
| Étape armement | `Safety.ArmingStep` | `INT#0` | 10:10:17 |
| Lockout | `Safety.LockoutActive` | `FALSE` | 10:10:17 |

## 2. 🎯 Symptôme

**Symptôme 1 (blocage synchro)** : après référencement d'un codeur en mode synchro (M1=8,5 m, M2=17 m → écart 9,3 m), la machine **reste en mode synchronisme** malgré le retrait de la demande (`SynchroRequest`/`SelSyncEnable=FALSE`). `SyncFaultActive=TRUE`, `SyncMotionAllowed=FALSE`. Permanent.

**Symptôme 2 (échec silencieux réarmement AU)** : le réarmement AU se déroule (séquence + messages IHM) mais aboutit à « chaîne OK, power contacteur off ». L'échec **n'est pas explicité** — seul « pupitre réarmé à U et puissance » s'affiche. L'utilisateur veut un message explicite + éventuellement un reset.

## 3. 🧩 Indices / historique

- **Derniers changements** : référencement d'un codeur (M2) pendant le mode synchro → écart M1/M2 créé.
- **Déjà essayé** : retrait de la demande synchro (sans effet) ; réarmement AU (séquence se déroule mais échec silencieux).
- **Conditions d'apparition** : mode synchro (MAINT_N1/N2), écart codeurs > tolérance.
- **Alarmes** : `WinchSyncError=TRUE`, `SyncFaultActive=TRUE`. Pas d'alarme d'échec d'armement (`ArmingFailed=FALSE`, `ArmingErrorId=0`).

## 4. 🌳 Arbre des causes & hypothèses

> Chaque « valeur attendue » a une SOURCE (code `.st`).

| # | <nobr>Hypothèse</nobr> | <nobr>Variable de décision</nobr> | <nobr>Valeur attendue (source)</nobr> | <nobr>Valeur lue</nobr> | Verdict |
|---|---|---|---|---|---|
| 1 | Écart codeurs > tolérance critique | `LevageSynchroniseM1M2.Idx103_SyncDelta_M` | `> 0.5 m` (FB_SyncDeviation.st:82) | `-9.32 m` | ✅ **cause** |
| 2 | Défaut synchro **latché** (non auto-effaçable) | `LevageSynchroniseM1M2.Idx302_SyncFaultActive` | `TRUE` tant que non Reset (FB_WinchSync.st:157, FB_FaultCore) | `TRUE` | ✅ **cause** |
| 3 | Retrait demande synchro déverrouille le défaut | `LevageSynchroniseM1M2.Idx202_SyncEnabled_IHM` | `FALSE` → devrait lever le défaut | `FALSE` mais `SyncFaultActive=TRUE` | ❌ **éliminée** (latch persiste) |
| 4 | SyncActive forcé TRUE par le mode | `FB_WinchSync.st:96-103` (CASE Mode) | MAINT_N1→TRUE imposé ; ELSE→TRUE | Mode DISABLE → ELSE → TRUE | ✅ **cause** (reste en synchro) |
| 5 | Abandon armement par PowerCutOffRequest | `Safety.LastAbortCause` | `16#0010` (FB_Safety_EmergencyManagementLogic.st:175-183) | `16#0010` | ✅ **cause** |
| 6 | Abandon PowerCutOff pose un défaut d'armement | `Safety.ArmingFailed` / `Safety.ArmingErrorId` | `TRUE`/`≠0` si défaut | `FALSE`/`0` | ❌ **éliminée** (abandon silencieux par conception) |
| 7 | PowerCutOffRequest provient du défaut synchro | `Safety.PowerCutOffRequest` | `TRUE` si MecaE→PowerCutOff (FB_Safety_Winch.st:415, PRG_06:292-294) | `FALSE` (au snapshot, mode DISABLE) | 🟡 **confirmé par traçage** (voir §5) |
| 8 | Message d'échec IHM absent | `FB_Hmi_BannerFormatter.st:395-407` | AbortMsgText si AbortMsgActive | « pupitre réarmé à U et puissance » | ✅ **cause** (message générique/effacé) |

## 5. 📊 Arbre vertical des hypothèses (flux de données) — OBLIGATOIRE

```text
[Idx103_SyncDelta_M = -9.32 m]  (M1=8.5, M2=17.8)
   │  > CfgSyncCriticalToleranceM (0.5 m)  → FB_SyncDeviation.st:82
   ▼
[FB_SyncDeviation.SyncDeviationFault = TRUE]  (filtre 800ms)
   │  cause 2, Latching:=TRUE  → FB_WinchSync.st:156-158
   ▼
[FB_WinchSync.Fault.Error = TRUE]  → SyncFaultActive=TRUE (Idx302) ❌
   │  SyncActive forcé TRUE par mode (FB_WinchSync.st:96-103)
   ▼
[SyncMotionAllowed = FALSE (Idx401)]  → blocage mouvement synchro ❌
   │
   │  (parallèle) écart > 2.5 m → FB_Safety_Winch MecaE (bit12)
   │  → MecaE escalade (bit13) → PowerCutOff (0x2F84) → FB_Safety_Winch.st:415
   ▼
[WinchM1/M2FinalInterlockRequest.PowerCutOff]  → PRG_04:1074/1089
   ▼
[PowerCutOffReq]  → PRG_06:292-294
   ▼
[instSafetyEmergencyManagement.PowerCutOffRequest]
   │  pendant séquence armement (étape 5) → FB_Safety_EmergencyManagementLogic.st:175-183
   ▼
[ArmingSeqStep 5→0, LastAbortCause=16#0010]  ❌  (PAS de EmergencyArmingFailedCause)
   ▼
[IHM : AbortMsgText générique OU « pupitre réarmé à U et puissance »]  ❌  (FB_Hmi_BannerFormatter.st:395-407)
```

**Résumé une ligne** : `[SyncDelta=-9.32m] → [SyncDeviationFault latché] → [SyncFaultActive=TRUE] ❌` et `[MecaE→PowerCutOff] → [Arming abort step5 cause 16#0010] → [échec silencieux] ❌`

## 6. 📊 Données / interactions & chronogramme (🟡)

### Lectures & essais
- Snapshot 10:10:17 : `SyncFaultActive=TRUE`, `SyncDelta_M=-9.32`, `SyncEnabled_IHM=FALSE`, `SyncMotionAllowed=FALSE`.
- Snapshot 10:10:17 : `LastAbortStep=5`, `LastAbortCause=16#0010`, `PowerCutOffRequest=FALSE`, `PowerContactorEngaged=FALSE`.
- Snapshot 10:10:17 : `ErrorMecaE=FALSE` (M1 et M2) — cohérent avec mode DISABLE (FB_Safety_Winch désactivé, PRG_04:670/731).

### Chronogramme (tableau vertical — événements × signaux)
| <nobr>Événement</nobr> | <nobr>SyncFaultActive</nobr> | <nobr>PowerCutOffReq</nobr> | <nobr>ArmingSeqStep</nobr> | <nobr>PowerContactor</nobr> |
|:---:|:---:|:---:|:---:|:---:|
| Référencement M2 (écart 9,3 m) | █ | █ (MecaE) | 0 | █ (coupé) |
| Réarmement AU | █ | █ | 1→5 |   |
| Abandon step 5 (PowerCutOff) | █ | █ | 0 |   |
| Reset + sortie mode → DISABLE | █ (re-latch) |   | 0 |   |
| Snapshot 10:10:17 | █ |   | 0 |   |

## 7. 🏁 Conclusion

- **Cause racine 1 (blocage synchro)** : le défaut d'écart synchro (`FB_WinchSync` cause 2, `SyncDeviationFault`) est **latché** (`Latching:=TRUE`, FB_WinchSync.st:157). Il s'est verrouillé car l'écart M1/M2 = 9,32 m > tolérance critique 0,5 m (FB_SyncDeviation.st:82). Le retrait de la demande (`SelSyncEnable=FALSE`) **ne déverrouille pas** un défaut latché — seul un **Reset** le fait (FB_FaultCore). De plus, `SyncActive` est **forcé TRUE** par le mode (FB_WinchSync.st:96-103 : MAINT_N1 → imposé ; ELSE → TRUE), donc la machine reste en surveillance synchro malgré le retrait de la demande. `SyncMotionAllowed=FALSE` bloque tout mouvement synchro.
- **Cause racine 2 (échec silencieux réarmement)** : la séquence d'armement s'est interrompue à l'**étape 5** (impulsion) car `PowerCutOffRequest` était actif (`LastAbortCause=16#0010`). Or, dans `FB_Safety_EmergencyManagementLogic.st:175-183`, un abandon par `PowerCutOffRequest` **ne pose PAS** `EmergencyArmingFailedCause` (délibérément, pour ne pas créer de fausse alarme pour une coupure métier voulue). Donc **aucun défaut d'armement n'est latché** → aucun message d'erreur explicite. Le `PowerCutOffRequest` provient de la chaîne : écart synchro → MecaE (FB_Safety_Winch) → MecaE escalade (bit13) → `PowerCutOff` (0x2F84) → `PowerCutOffReq` (PRG_06:292-294) → `instSafetyEmergencyManagement.PowerCutOffRequest`.
- **Statut** : à valider (cause racine prouvée par lecture snapshot + traçage inverse).

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** :
  - **Réduire l'écart M1/M2** avant de réarmer : ramener M2 (ou M1) à la position de l'autre treuil (dérouler/enrouler en mode unitaire, hors synchro) pour que `|M1−M2| ≤ 0,5 m`. Cela lève la cause du défaut synchro et permet un Reset propre.
  - **Reset** (`FaultMachineReset_IHM`) pour déverrouiller le défaut synchro latché (FB_WinchSync) ET le défaut MecaE (FB_Safety_Winch) — le Reset est le seul moyen de lever un défaut latché.
  - **Réarmer l'AU** une fois `PowerCutOffRequest=FALSE` (cause synchro levée) — la séquence pourra alors dépasser l'étape 5.
  - *Impact/risque* : opérationnel, sans modification de code. Nécessite de pouvoir piloter un treuil en unitaire malgré le blocage (vérifier que le mode unitaire est accessible).

- **Option 2 (définitif)** :
  - **Message IHM explicite** : dans `FB_Hmi_BannerFormatter.st` §4, enrichir le message d'abandon pour cause `16#0010` afin de nommer la cause racine (ex. « [AU] Coupure sécurité métier active — défaut synchro M1/M2 (écart X m) — réduire l'écart puis Reset »). Actuellement le message est générique (« Coupure securite metier active ») et ne pointe pas vers le défaut synchro.
  - **Reset explicite** : garantir que le message d'abandon `16#0010` reste affiché (non effacé par un Reset intempestif) jusqu'à ce que la cause soit réellement levée, OU proposer un bouton « Reset + réarmer » qui enchaîne : lever la cause → Reset → réarmement.
  - **Optionnel (ergonomie)** : exposer `instWinchSync.Fault.ErrorId` (décomposition des causes) dans `GVL_Troubleshooting.LevageSynchroniseM1M2` pour que l'IHM/dépannage distingue écart codeurs vs discordance contacteurs (trou d'acquisition actuel).
  - *Impact/risque* : modification de code (IHM formateur) — **validation humaine requise**. Ne modifie pas le comportement de sécurité de l'AU.

- **⚠️ Validation requise** : [humaine] — ne pas modifier le code / forcer une variable sans validation.

## 9. ✅ Vérification de la correction / non-régression

> ⚠️ **Hand-off humain** : la correction (§8) doit être **validée par l'humain** avant application. L'agent ne modifie pas le code / ne force pas de variable sans validation.

- <test de non-régression après correction : le symptôme est-il résolu ? rien d'autre cassé ?>

## 10. 📝 Journal (chronologique)

- 2026-08-31 : Ouverture de la fiche. Lecture snapshot `Snapshot_Troubleshooting_20260831_101017.csv` (495 var) + code (`FB_Safety_EmergencyManagementLogic`, `FB_Winch`, `FB_Safety_Winch`, `FB_WinchSync`, `FB_SyncDeviation`, `PRG_06_Outputs`, `PRG_04_Treuils_Benne`, `FB_Hmi_BannerFormatter`, `GVL_Troubleshooting`).
- 2026-08-31 : Cause racine 1 (défaut synchro latché) et cause racine 2 (abandon armement silencieux par PowerCutOffRequest) établies par preuve snapshot + traçage inverse. Aucun code modifié.

---

📖 **Documentation complète** (comment remplir chaque section, exemples) : `GUIDE_Troubleshooting.md` (même dossier).
