# 🕵️ Session de Troubleshooting — Recherche de Blocage et de Panne — CableLimitAscent M1 ne se déclenche pas

> 📅 Date : 2026-08-22 01:08 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : EN COURS

## 1. 🧊 Contexte figé (horodaté)

> Snapshot horodaté. Re-figer si > 5 min ou événement (redémarrage, changement de mode).
> Toute valeur non listée = à vérifier (ne pas supposer).

### Texte de contexte
Rapport utilisateur : `GVL_IHM.M1TreuilRetenue.Safety.CableLimitAscent` ne passe pas à `TRUE` à ≥ 7,5 m, et le treuil M1 ne s'arrête pas en montée. Observé en simulation banc.

### Variables & valeurs
| Élément | Variable complète | Valeur | Horodatage |
|---|---|---|---|
| Symptôme flag | `GVL_IHM.M1TreuilRetenue.Safety.CableLimitAscent` | FALSE (reste 0) | 2026-08-22 |
| Limite haut config | `_CommunCfgPersist.CfgCableLimitAscent_M` | 7.5 | CODE/GVL_PERSISTENT.st L138 |
| Position observée | `PRG_02_Acquisition.Data.CablePosM1` | ≥ 7.5 (rapporté) | 2026-08-22 |

> ❗ `CfgCableLimitAscent_M` est un RETAIN modifiable IHM — vérifier la valeur **live** (peut différer de 7.5 si modifiée en IHM).

## 2. 🎯 Symptôme

`Safety.CableLimitAscent` reste `FALSE` quand `CablePosM1` ≥ 7,5 m, ET le treuil M1 ne s'arrête pas en montée à la limite haute. Deux symptômes distincts : un flag IHM jamais armé + un défaut d'arrêt réel.

## 3. 🧩 Indices / historique

- Derniers changements : refactor encodage/homing (T146) — homing simulé donnait 0 m au lieu de 8,5 m ; gates G340/G420. Pas de modif sur PRG_04/Safety récente signalée.
- Déjà essayé : (non fourni)
- Conditions : position observée ≥ 7,5 m en montée ; référencement supposé fait.
- Alarmes : (non renseigné)

## 4. 🌳 Arbre des causes & hypothèses

> Liste exhaustive. Chaque « valeur attendue » avec SOURCE.

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | `CableLimitAscent` IHM jamais publié | `PRG_04 §8` (affectation `WinchM1Safety.CableLimitAscent`) | existante → **absente** (preuve statique) | n/a | ✅ **cause** (défaut IHM) |
| 2 | Encoder pas `Homed` | `HomingM1.HomingHomed` | TRUE | **TRUE** (snapshot) | ❌ éliminée |
| 3 | `HomingSuspect` = TRUE | `HomingM1.HomingSuspect` | FALSE | **FALSE** | ❌ éliminée |
| 4 | `InReferencingMode` figé | `HomingM1.HomingBusy` | FALSE | **FALSE** | ❌ éliminée |
| 5 | Position réellement < 7.5 | `CablePosM1` | ≥ 7.5 | **7.916504** | ❌ éliminée (≥) |
| 6 | **AscentPermit ne tombe pas (anomalie)** | `Safety.AscentPermitEffective` + `InTopSlowdownZone` | AscentPermit FALSE à ≥7.5 | **AscentPermit=TRUE, SlowdownZone=TRUE** | ✅ **cause (à finaliser)** |
| 6a | `BypassTopLimitSoftware` actif | `GVL_IHM.M1TreuilRetenue.Bypass.TopLimitSoftware` OR `Commun.Bypass.TopLimitSoftware` | FALSE | **indiv=FALSE, Commun=TRUE** (snapshot 013154) | ✅ **cause confirmée** |
| 6b | `CfgCableLimitAscent_M` live > 7.92 | `_CommunCfgPersist.CfgCableLimitAscent_M` | 7.5 (GVL_PERSISTENT L138) | **7.5** (snapshot 013154) | ❌ éliminée |
| 6b | `CfgCableLimitAscent_M` live > 7.92 | `_CommunCfgPersist.CfgCableLimitAscent_M` | 7.5 (GVL_PERSISTENT L138) | **à lire live** | ❓ |

## 5. 📊 Arbre vertical des hypothèses (flux de données)

```text
CableLimitAscent IHM = 0
  └─ [A] PRG_04 §8 écrit WinchM1Safety.CableLimitAscent ?  -> NON (aucune affectation) ❌  => flag IHM JAMAIS armé
                                                                  (cause 1, PROUVÉE — champ orphelin + decl. inutilisée CableLimitAscentM1Reached)

Arrêt M1 en montée = non
  └─ FB_Winch.EffectiveSafeStop (NOT AscentPermit AND CmdDir<>-1) — FB_Winch L148-150, L309-311
        └─ instSafetyWinchM1.AscentPermit — FB_Safety_Winch L455-460
              = NOT( ((bit5 OR NOT TopSensor AND NOT Homing) AND NOT BypTopSwitch)
                     OR ((Homed AND NOT HomingSuspect AND NOT HomingBusy AND (CablePosM>=7.5)) AND NOT BypTopSoft) )
              ├─ Homed ?             -> à lire (HomingM1.HomingHomed)
              ├─ HomingSuspect ?     -> à lire (HomingM1.HomingSuspect)
              ├─ InReferencingMode ? -> à lire (HomingM1.HomingBusy)
              ├─ CablePosM1>=7.5 ?   -> à lire
              └─ BypTopSoft ?        -> à lire
```

**Résumé 1 ligne** : `flag IHM jamais écrit ❌ (prouvé) + AscentPermit ne tombe pas car BypassTopLimitSoftware COMMUN (RETAIN) = TRUE ✅`

## 6. 📊 Données / interactions (🟡)

- Lecture statique `CODE/*.st` : **cause flag IHM prouvée** (aucun écrit de `WinchM1Safety.CableLimitAscent`).
- Snapshot 013154 (439 var) : `Idx321_CfgTopLimitM=7.5`, `Idx322_CablePosM=7.775`, `Idx323_TopLimitReached=TRUE`, **`Idx324_AscentBlockedByTopLimit=FALSE`**, `Idx325_BypassTopLimitSoftware=FALSE`, **`Idx326_BypassTopLimitSoftCommun=TRUE`**, `Idx328_BypassTopLimitSwitchCommun=TRUE`, `Idx330_BypassGlobalCommun=FALSE`.
- → **cause 2 confirmée** : bypass commun `TopLimitSoftware`/`TopLimitSwitch` (RETAIN) actifs.

## 7. 🏁 Conclusion

- **Cause racine 1 (flag IHM)** : `GVL_IHM.M1TreuilRetenue.Safety.CableLimitAscent` n'est **jamais publié** (PRG_04 §8 ne l'affecte pas). Déclarations `CableLimitAscentM1Reached/M2Reached` **orphelines**. → flag reste 0 par construction (défaut IHM, sans impact arrêt).
- **Cause racine 2 (non-arrêt)** : **`GVL_IHM.Commun.Bypass.TopLimitSoftware = TRUE`** (bypass RETAIN `GVL_BypassRetain.BypassTopLimitSoftware`, restauré au boot + sync IHM). Lève la butée logicielle → `AscentPermit` reste TRUE → pas d'arrêt à 7,5 m. État de test laissé actif, **pas un bug de logique**.
- **Statut** : **RÉSOLUE** (cause 2 identifiée → correction immédiate = désactiver bypass commun ; cause 1 = à corriger en code, optionnel).

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** : IHM → `GVL_IHM.Commun.Bypass.TopLimitSoftware` et `TopLimitSwitch` = **FALSE** ; re-test montée → arrêt à 7,5 m. ⚠️ RETAIN : resteront OFF après redémarrage uniquement si on ne les réactive pas — risque sécurité si laissés ON en exploitation.
- **Option 2 (définitif, code)** :
  - Publier `CableLimitAscent`/`CableLimitDescent` dans `PRG_04 §8` (bug flag IHM), câbler `CableLimitAscentM1/M2Reached`.
  - **Garde-fou (`guard:`)** : signaler un bypass commun de sécurité resté actif hors mode essai/MAINT (protection levée en exploitation).
- **⚠️ Validation requise** : humaine — pas de modif code sans validation.

## 9. ✅ Vérification de la correction / non-régression

> Hand-off humain : correction §8 validée par l'humain avant application.

- (à remplir après correction)

## 10. 📝 Journal (chronologique)

- 2026-08-22 01:08 : fiche créée ; cause 1 (flag IHM jamais publié) prouvée par lecture statique ; cause 2 (non-arrêt) en attente de lecture live `AscentPermit`/`HomingM1`.
- 2026-08-22 01:0x : snapshot utilisateur (419 var) → élimine homing (Homed/Suspect/Busy) et confirme `CablePosM1=7,92 ≥ 7,5` mais `AscentPermitEffective=TRUE`. 2 causes restantes : `Bypass.TopLimitSoftware` actif OU `CfgCableLimitAscent_M` live > 7,92.
- 2026-08-22 01:0x : ajout du bloc diagnostic « limite haute » dans `GVL_Troubleshooting` :
  - `ST_Chain_Winch_Safety.st` : champs `Idx321_CfgTopLimitM` → `Idx330_BypassGlobalCommun` (M1+M2).
  - `FB_TroubleshootingView` : VAR_INPUT `CfgTopLimitM` + câblage M1/M2 des 10 champs.
  - `PRG_07` : `CfgTopLimitM := _CommunCfgPersist.CfgCableLimitAscent_M`.
  - Corrigé `generate_variable_list_from_code.py` (chemin périmé `K_DEPANNAGE` → `J_SUPERVISION`).
  - Listes régénérées 419 → **439 variables**. Gates TOUS PASS (28,9 s), liaison 0 erreur.
  - ⚠️ Hand-off humain : appliquer les 3 `.st` dans CODESYS + rebuild, re-login, relancer snapshot.
- 2026-08-22 01:1x : **révision skill troubleshooting** (demande utilisateur) : Étape 4bis durcie — **ne demander aucun état de variable sans avoir vérifié qu'il est capturable** (implémenté dans `GVL_Troubleshooting` + présent dans `troubleshooting_variables.txt`) ; canal unique = **snapshot CSV**, jamais de lecture Watch ; si variable manquante → l'ajouter + régénérer la liste avant de demander. Aligné `.dsh/` et `.claude/` SKILL.md + prompt `troubleshooting.md` §0. Chemin fiche corrigé vers `FICHES/`.
- 2026-08-22 01:3x : **cause 2 confirmée par snapshot 013154** — `GVL_IHM.Commun.Bypass.TopLimitSoftware/TopLimitSwitch = TRUE` (bypass commun RETAIN). Origine : `GVL_Simulation.SimulationBypassActive := TRUE` par défaut → front au 1er scan → PRG_07 §2d forçait les bypass TopLimit/LimitLegal à TRUE au boot.
- 2026-08-22 01:3x : **CORRECTION CODE (validée utilisateur)** — `PRG_07 §2d` : retiré l'auto-forcement `Commun.Bypass.TopLimitSwitch/TopLimitSoftware/LimitLegal := TRUE` au front de `SimulationBypassActive`. Gardé les bypass Meca (`M1/M2.Safety/Process`). En-tête `GVL_Simulation.st` mis à jour. **Gates TOUS PASS (30,8 s), liaison 0 erreur.** ⚠️ Hand-off humain : appliquer `PRG_07_Supervision.st` + `GVL_Simulation.st` dans CODESYS, rebuild, re-login ; **remettre `Commun.Bypass.TopLimitSoftware`/`TopLimitSwitch` à FALSE** (RETAIN actuel encore TRUE) ; re-tester montée → arrêt à 7,5 m.
