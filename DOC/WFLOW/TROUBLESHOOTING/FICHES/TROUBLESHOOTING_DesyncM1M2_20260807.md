# 🕵️ Session de Troubleshooting — M2 bloqué palier 1 en montée couplée (M1 monte normalement)

> 📌 Emplacement : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_DesyncM1M2_20260807.md`
> 📅 Date : 2026-08-07 · 🧊 Situation : [SITE MACHINE RÉELLE] · 📄 Statut : [EN COURS]
> 🎯 Périmètre : `CODE_v0.5.25_20260807` (exclusivement)

## 1. 🧊 Contexte figé (horodaté)

**Situation :** SITE MACHINE RÉELLE — **HW réel, sans simulation**, bypass actifs.

| Élément | Variable complète | Valeur |
|---|---|---|
| Joystick maître | `GVL_IHM.Modes.Cmd.TglJoystickMaster` | TRUE |
| Sélection treuil joystick | `GVL_IHM.Modes.Cmd.SelJoystickWinch` | **2** |
| Limites benne manuelles | `GVL_IHM.M2TreuilBenne.Bucket.Cmd.TglManualBucketLimits` | **TRUE** |
| Contacteur puissance | `GVL_IHM.Modes.State.PowerContactorEngaged` | TRUE |
| Bypass M1 | `GVL_IHM.M1TreuilRetenue.Bypass.Global` | TRUE |
| Bypass M2 | `GVL_IHM.M2TreuilBenne.Bypass.Global` | TRUE |
| Bypass Synchro | `GVL_IHM.M1M2Sync.Bypass.Global` | TRUE |
| Bypass Translation | `GVL_IHM.TranslationM3.Bypass.Global` | TRUE |
| Homing M1 / M2 | `...State.Encoder.Homed` | TRUE / TRUE |
| Position M1 / M2 | `...State.Position_M` | 7.4158 / 7.6475 |
| Confirm open / close pos | `...Bucket.Cmd.BtnConfirmOpenPos/ClosePos` | FALSE / FALSE |

**Modes DredgingAssist — tous désactivés (0)** : `TglEnableDiveSearch`, `TglEnableExtractionSequence`, `TglBucketAtBottomConfirmed`, `TglBypassDiveSearchSequence`, `TglEnableDumpAtTremie`.

**Config (GVL_PERSISTENT) :** `CfgCableLimitAscent_M`=6.75 · `WinchSlowdownDistance_M`=1.0 · `WinchSlowdownMaxStep`=1 · `WinchMaxStepAscent`=5 · `OffsetCloseM`=15.0 · `OffsetOpenM`=0.0 · `CoherenceLimitM`=1.0 · `ExtractionControlDistance_M`=2.0.

## 2. 🎯 Symptôme

En montée couplée, **M1 monte normalement** (paliers vitesse contacteur 1→2→…) alors que **M2 est bloqué en palier 1 (P1)** → désynchronisation M1/M2. L'utilisateur veut **monter avec les mêmes commandes sur M1 et M2**.

## 3. 🧩 Indices / historique

- **Régression** : le même programme montait à palier 2, synchronisé, avant ce lot. Le lot 2026-08-07 a ajouté le mécanisme `ManualBucketLimitsActive` (REX 18).
- **Capture PRG_04 (FB_Winch)** : `MaxStepAscent=1`, `CfgMaxStepDescente=1`, `Homed=TRUE`, `HomingSuspect=FALSE`, `BypassGlobal=TRUE`, `CommandedDirection=0`, `ActiveMaxStep=5`.
- **Souvenir utilisateur** : parfois perte de l'état benne fermée → système interdisait la montée (mécanisme distinct `CoupledMotionBlockedByBucket`).

## 4. 🌳 Arbre des causes & hypothèses

> Symptôme : M2 plafonné palier 1, M1 libre. Le plafond de palier M2 est fixé par `MaxStepAscent` (PRG_04 §6).

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | **`ManualBucketLimitsActive` plafonne M2** (Select=2 + TglManualBucketLimits) | `PRG_03_Modes_Cycle.Auth.JoystickWinchSelectArbitrated` | 2 (PRG_04 §5) | à lire | ✅ **cause** |
| 2 | `ControlAscentActive` (Fiche 01) | `BenneOuvertureFermeture.Idx403_ControlAscentActive` | FALSE (sinon M1 aussi plafonné) | — | ❌ éliminée (M1 monte) |
| 3 | `instBucket.M2_ForceSlowSpeed` (BUSY) | `BenneOuvertureFermeture.Idx401_BucketBusy` | FALSE (sinon M1 bloqué) | — | ❌ éliminée (M1 monte) |
| 4 | `ForceMinSpeedStep` (Extraction) | toggles DredgingAssist | FALSE (tous à 0) | 0 | ❌ éliminée |

## 5. 📊 Arbre vertical des hypothèses (flux de données)

```text
Symptôme : M2 plafonné palier 1, M1 monte normalement
│
├─ H1 Plafond palier M2 (PRG_04 §6 MaxStepAscent)
│   └─ [MaxStepAscent M2:INT] = 1 ❌ (capture)
│       └─ SEL(ForceMinSpeedStep OR ControlAscentActive OR M2_ForceSlowSpeed OR ManualBucketLimitsActive)
│           ├─ [ForceMinSpeedStep] = FALSE (toggles 0)
│           ├─ [ControlAscentActive] = FALSE (M1 monte)
│           ├─ [M2_ForceSlowSpeed] = FALSE (instBucket pas BUSY)
│           └─ [ManualBucketLimitsActive] = TRUE ✅ ← CULPABLE
│               └─ [TglManualBucketLimits] = TRUE
│               └─ [SelectArbitrated] = 2 (SelJoystickWinch=2, mode MAINT_N1/N2)
└─ H2 M1 (comparaison)
    └─ [MaxStepAscent M1:INT] = 5 (pas de ManualBucketLimitsActive) ✅
```

**Résumé une ligne** : `[SelectArbitrated=2] + [TglManualBucketLimits=TRUE] → [ManualBucketLimitsActive=TRUE] → [M2 MaxStepAscent=1] ❌ / [M1 MaxStepAscent=5]`

## 6. 📊 Données / interactions & chronogramme (🟡)

### Capture PRG_04 (FB_Winch)
| Variable | Valeur |
|---|---|
| `Homed` | TRUE |
| `HomingSuspect` | FALSE |
| `BypassGlobal` | TRUE |
| `CommandedDirection` | 0 |
| `MaxStepAscent` | **1** |
| `CfgMaxStepDescente` | **1** |
| `HomingApproachActive` | FALSE |
| `ActiveMaxStep` | 5 |

### Chronogramme
| Événement | M1 Step | M2 Step | M2 MaxStepAscent |
|:---:|:---:|:---:|:---:|
| Montée (attendu) | 2 | 2 | 5 |
| Montée (observé) | 2 | 1 | **1** |

## 7. 🏁 Conclusion

- **Cause racine (confirmée)** : `ManualBucketLimitsActive` = `TglManualBucketLimits` (TRUE) **AND** `SelectArbitrated` (=2, car `SelJoystickWinch=2` en MAINT_N1/N2) → plafonne `MaxStepAscent` de M2 à **1**. M1 n'a pas cette condition → monte normalement. **Désync.**
- **Régression** : mécanisme `ManualBucketLimitsActive` ajouté au lot 2026-08-07 (REX 18). Avant, M2 montait à palier 2, synchronisé.
- **Statut** : cause identifiée (capture `MaxStepAscent=1` + contexte).

## 8. 🛠️ Proposition de correction

> ⚠️ **Validation requise** : [humaine] — ne pas modifier le code / forcer une variable sans validation.

- **Option 1 (immédiat, sans code)** : pour la montée couplée, passer `SelJoystickWinch=0` (both) **OU** `TglManualBucketLimits=FALSE`. ⚠️ Mais l'utilisateur a besoin du mode 2 pour ouvrir/fermer la benne avec les bornes 0–15 m.
- **Option 2 (définitif)** : **découpler** les bornes 0–15 m (à garder) du plafond palier 1 (à retirer en montée couplée) :
  ```st
  MaxStepAscent := SEL(ForceMinSpeedStep OR ControlAscentActive
                       OR instBucket.M2_ForceSlowSpeed
                       OR (ManualBucketLimitsActive AND M1_Direction_Active = 0),
                       EffectiveMaxStepAscent, 1);
  ```
  **Effet** : jog unitaire M2 (M1 arrêté) → bornes + palier 1 conservés. Montée couplée (M1+M2) → bornes conservées, **palier M2 libéré**.
- **⚠️ Validation requise** : [humaine].

## 9. ✅ Vérification de la correction / non-régression

- À remplir après correction validée.

## 10. 📝 Journal (chronologique)

- 2026-08-07 : ouverture fiche. Hypothèse initiale (zone ralentissement haut) **invalidée** par correction utilisateur (M2 bloqué P1, M1 monte).
- 2026-08-07 : capture PRG_04 → `MaxStepAscent=1` → cause = `ManualBucketLimitsActive` (Select=2 + TglManualBucketLimits). Régression REX 18.
