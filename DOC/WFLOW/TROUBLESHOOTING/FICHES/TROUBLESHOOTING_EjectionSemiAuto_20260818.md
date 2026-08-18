# 🕵️ Session de Troubleshooting — Éjection SEMI_AUTO (MAINT_N2 → mode 3) + coupure puissance

> 📅 Date : 2026-08-18 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [EN COURS]

## 1. 🧊 Contexte figé (horodaté)

- Simulation active · MAINT_N2 → tentative SEMI_AUTO
- Snapshots : `172503` (MAINT_N2) · `172623` (SEMI_AUTO ~1s) · `172509` (DISABLE + coupure)
- Référencés (Homed M1/M2 = TRUE) · Benne ouverte (`BucketIsOpen=TRUE`)
- Modes dragage actifs : DiveSearch + ExtractionSequence + DumpAtTremie

### Variables & valeurs
| <nobr>Élément</nobr> | <nobr>Variable</nobr> | 172503 | 172623 | 172509 |
|---|---|---|---|---|
| Mode | `Idx101_ModeActive` | MAINT_N2 | **SEMI_AUTO** | **DISABLE** |
| Puissance | `Idx302_PowerContactorEngaged` | TRUE | TRUE | **FALSE** |
| SafeStop | `Idx303_SafeStopActiveAny` | FALSE | FALSE | **TRUE** |
| PowerCutOff | `Idx304_PowerCutOffActiveAny` | FALSE | FALSE | FALSE |
| M3 vitesse | `TranslationPontM3...ArbitratedSpeed_Pct` | 0 | **100** | 0 |
| M3 drive | `...DriveActualFreq_Hz` | 0 | **50** | 0 |
| M3 status | `...DriveStatusWord` | 128 | **135 (0x87)** | 128 |
| M3 capteurs | `...PosTremie/PV/P2/P1/Maint` | tous FALSE | **tous FALSE** | tous FALSE |
| M3 Fdc Rev | `...LimitSwitchRevActive` | TRUE | TRUE | TRUE |
| M3 incohérence | `...PositionDecoderIncoherent` | FALSE | FALSE | FALSE |

## 2. 🎯 Symptôme

Passage MAINT_N2 → SEMI_AUTO : le mode passe bien à SEMI_AUTO (~1 s), **M3 démarre en translation**, puis un défaut **coupe la puissance** (`PowerContactorEngaged=FALSE`) et **éjecte en DISABLE** (mode 0).

## 3. 🧩 Indices / historique

- Derniers changements : modes dragage actifs (DiveSearch/ExtractionSequence/DumpAtTremie).
- Déjà essayé : passage MAINT_N2 → SEMI_AUTO.
- Conditions : simulation, M3 en translation.
- Alarmes : à confirmer (ErrorId M3).

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | **M3 translation déclenche un défaut safety** (escalade Fdc bit6) | `instSafetyTranslationM3.ErrorId` | bit6 (16#0040) si M3 pousse en butée Maintenance | à confirmer | ⏳ |
| 2 | M3 en marche arrière dans la butée Maintenance | `M3_Direction_Active` | -1 + `LimitSwitchRevActive=TRUE` | à confirmer | ⏳ |
| 3 | Capteurs position M3 tous FALSE (M3 entre positions / simu) | `TranslationPosXxx` | incohérent | tous FALSE | ⚠️ anomalie |
| 4 | Coupure puissance = chute keep-alive (SafeStop) | `Safety.PowerContactorEngaged` | FALSE après défaut | FALSE | ✅ |

## 5. 📊 Arbre vertical des hypothèses

```text
MAINT_N2 → SEMI_AUTO
  → Auth.Mode = SEMI_AUTO (snapshot 172623)                    ✅
  → M3 démarre (ArbitratedSpeed=100, DriveFreq=50Hz)           ✅
  → M3 en butée Maintenance (LimitSwitchRevActive=TRUE)        ⚠️
  → (si Direction=-1 + FdcRev) escalade Fdc bit6 après 1.5s    ❌ → PowerCutOff
  → PowerKeepAlive chute → chaîne AU ouverte                    ❌
  → PowerContactorEngaged=FALSE → Auth.Mode=DISABLE            ❌ éjection
```

**Résumé une ligne** : `[SEMI_AUTO=1]→[M3 bouge]→[FdcRev=1 + Dir=-1]→[bit6 escalade]→[PowerCutOff]→[DISABLE]`

## 6. 📊 Données / interactions

- M3 en mouvement (50Hz, StatusWord 0x87) au snapshot 172623, **tous capteurs position FALSE**.
- `LimitSwitchRevActive=TRUE` constant (M3 côté Maintenance).
- Coupure puissance + SafeStop au snapshot 172509, mode DISABLE.

## 7. 🏁 Conclusion

- **Cause racine (prouvée)** : dans `PRG_05_Translation` (branche SEMI_AUTO), `M3_Direction_Active` et `M3_SpeedRef_Active` étaient calculés **indépendamment de `Start`** (direction=-1 car `SelTarget≠1`, vitesse=100). Le modèle de simulation `FB_Sim_Translation` **ignore `Start`** → M3 « bouge » en marche arrière à 100% alors que le cycle est à X0. M3 en butée Maintenance (`LimitSwitchRevActive=TRUE`) → **escalade fin de course (bit6)** → PowerCutOff → chute keep-alive → `PowerContactorEngaged=FALSE` → **mode DISABLE** (éjection).
- **Statut** : ✅ **RÉSOLUE** (correction appliquée + gates PASS).

## 8. 🛠️ Proposition de correction

- **Option 2 (définitif, appliquée)** : gater `M3_Direction_Active` + `M3_SpeedRef_Active` sur `M3_StartStop_Active` (= `TranslationCmd.Start`) dans `PRG_05_Translation` (branche SEMI_AUTO). Si `Start=FALSE` → direction=0, vitesse=0. **Validée par l'utilisateur 2026-08-18.**
- **⚠️ Validation requise** : [humaine] — appliquée après validation.

## 9. ✅ Vérification de la correction / non-régression

- Bundle régénéré (`CODE_XML/CODE_Bundle.xml` fresh) · G200 liaison **PASS** · **18/18 gates PASS**.
- **Test banc à faire** : MAINT_N2 → SEMI_AUTO sans Start → M3 ne doit plus bouger, pas d'éjection.

## 10. 📝 Journal (chronologique)

- 2026-08-18 : ouverture session. 3 snapshots analysés (MAINT_N2 → SEMI_AUTO → DISABLE). M3 démarre en translation en SEMI_AUTO, puis coupure puissance + éjection DISABLE. Cause suspectée = défaut safety M3 (escalade Fdc). ErrorId M3 requis.
- 2026-08-18 : `LimitSwitchRev` = côté **Maintenance** (pas trémie) — `M3_LimitSwitchRevStable` = verrou Fdc Maintenance/P1 (PRG_05 L39). Capteurs position FALSE = normal en simu (état initial M3). Position translation ne doit PAS bloquer le démarrage cycle (point utilisateur). **Trou raquette** : `instSafetyTranslationM3.ErrorId` + `M3_Direction_Active` absents des snapshots → **T129**. Conformité commentaires GVL_IHM → **T128**.
- 2026-08-18 : **cause racine confirmée** — `M3_Direction_Active`/`M3_SpeedRef_Active` non gatés sur `Start` en SEMI_AUTO + `FB_Sim_Translation` ignore `Start` → escalade Fdc → éjection. **Correction appliquée** dans `PRG_05_Translation.st` (gating sur `Start`), validée utilisateur. Bundle + 18/18 gates PASS. ⏳ Test banc à faire.
- 2026-08-18 : **✅ CLÔTURÉE** — validation utilisateur sur banc : compile OK, passage en mode 3 (SEMI_AUTO) fonctionne, plus d'éjection.
