# 📋 Inventaire des défauts bloquants — Mise en Service (base 2026-09-03)

> 🎯 **But** : recenser **exhaustivement** les gardes / défauts qui **latchent** ou **bloquent le mouvement**, décider pour chacun : ✅ garder tel quel · 🔧 élargir le seuil · 🕒 faux positif (contrôle au mauvais moment → re-fenêtrer) · 🚧 bypass granulaire *le temps des essais* + **date de réactivation**.
> 🔗 Tâche pilote : **`T243`**. Registre : `REGISTRE_Suivi_MiseEnService_20260903.md` (MES-045).
> ⚠️ Tout **bypass** posé = ligne ici avec `réactivation cible` + report dans `T243`.

---

## 1. Méthode

1. Au banc : provoquer / observer chaque défaut, noter snapshot + trace.
2. Pour chaque ligne : renseigner **symptôme réel**, **seuil/fenêtre actuels**, **verdict**.
3. Verdict 🔧 / 🕒 → créer sous-tâche de `T243` ou patch direct si trivial & sûr.
4. Verdict 🚧 → armer le bypass IHM **existant** (ne PAS créer de bypass code jetable), noter `réactivation cible`.

### Légende verdict
| | Sens |
|---|---|
| ✅ | Correct, garder |
| 🔧 | Élargir le seuil (valeur mal calibrée) |
| 🕒 | Faux positif — contrôle actif au mauvais moment → re-fenêtrer (gate homing/benne/arrêt) |
| 🚧 | Bypass granulaire temporaire (essais) + réactivation planifiée |
| ❓ | À investiguer au banc |

---

## 2. Inventaire (pré-rempli — à compléter au banc)

### 2.1 Sécurité treuils — `FB_Safety_Winch` (M1 / M2)

| # | Défaut | Loc. | Seuil / fenêtre actuels | Symptôme banc 2026-09-03 | Bypass IHM | Verdict | Suite |
|---|--------|------|------------------------|--------------------------|------------|---------|-------|
| SW-1 | **MecaA** — dérive non commandée (`DriftGuardA`) | `FB_Safety_Winch` §1 c.7 | `Arm` si `FwdRevSpeedFeedbackOff AND NOT RefWindowActive` ; `RefWindowActive = InReferencingMode OR BenneBusy OR PosStepDetected OR NOT TonRefSettle(2s)` ; `PosStepDetected` si `ABS(ΔCablePos) > CST_RefPosStepM` | 🔴 latché sur M2 « à la sortie du capteur top » quand preset M2 = 8.5 alors que M2 physiquement ~23.5 (benne fermée). `RefWindowActive` ne couvrait pas le saut de 15 m (ou trop court). | `M2TreuilBenne.Bypass.MecaA` | 🕒 (faux positif) + 🔧 | `T240` (preset M2 offset-aware) rend le cas normal ; **sinon** : élargir `TonRefSettle` / abaisser `CST_RefPosStepM` pour que `PosStepDetected` déclenche sur +15 m ; vérifier `InReferencingMode` M2 actif pendant tout le preset. |
| SW-2 | **MecaE** — écart synchro M1/M2 critique | `FB_WinchSync` / `FB_Safety_Winch` c.13 | `CfgSyncCriticalTolerance_M` (≈ 2.5 m), comparaison `(M2 − ActiveOffsetM) − M1` | 🔴 « écart synchro critique » fantôme : `ActiveOffsetM = 0` (état benne « ouvert ») alors que M2 physiquement 15 m sous M1 → synchro **désactivée à la main** au banc. | `M1M2Sync.Bypass.Global` / `M2TreuilBenne.Bypass.MecaE` | 🕒 (faux positif) | `T241` (classifieur §4a fiabilise `ActiveOffsetM`) doit supprimer la cause. **À revérifier** après download T241. Sinon 🔧 marge critique pendant homing. |
| SW-3 | **MecaE escalade** (niveau 2 → PowerCutOff, bit13) | `FB_SyncContactor` (T225) | `ContactorMismatchEscalated` + debounce `CST_MismatchDebounce` | ❓ pas vu ce jour | — | ❓ | Vérifier qu'un homing (vecteurs contacteurs M1≠M2 transitoires) ne l'arme pas. |
| SW-4 | **MecaB** M3 (ready-to-switch-on) | `FB_Safety_Translation` (`6dd8f3cb`) | gardé par `DriveOnline AND DriveOperational` | ❓ | `TranslationM3.Bypass.*` | ❓ | Lié au point 3 séance (bits « at position » M3). |
| SW-5 | Perte codeur (latched) | `FB_Safety_Winch` c.1 | `NOT EncoderAvailable` | ❓ | `EncoderFaultBypass` | ❓ | Vérifier au boot bus. |
| SW-6 | Mou de câble (bit3) | `FB_Safety_Winch` / `PRG_04` `SlackCableAscentCapStep1` | `NOT M2_TensionedCable_DI` ou bit3 ErrorId | ❓ | `Commun.Bypass.SlackCable` | ❓ | Peut brider la montée à P1 en récup. |

### 2.2 Benne — `FB_Bucket`

| # | Défaut | Loc. | Seuil actuel | Symptôme banc | Verdict | Suite |
|---|--------|------|--------------|---------------|---------|-------|
| BK-1 | **OffsetMax** (`ErrorID:02`) — écart M2−M1 hors plage | `FB_Bucket` §1 c.1 | **avant** : `M2 > M1 + OffsetClose + 2` **ou** `M2 < M1` (sec) ; latch immédiat | 🔴 latché à **13 cm** de M2 sous M1 (sur-jog à l'ouverture, `OffsetOpen = 0`). | 🔧 **fait** (`f4c0ffbf`) | borne basse = `OffsetOpenM − CoherenceLimitM` + latch si hors plage **> 500 ms**. À valider banc. |
| BK-2 | **CfgFault** (`ErrorID:01`) — géométrie config | `FB_Bucket` §1 c.0 | `OffsetOpenM >= OffsetCloseM` **ou** `OffsetOpenM < 0` | latcherait à la recalibration (`OffsetOpen ≈ −0.13`). | 🔧 **fait** (`f4c0ffbf`) | seuil bas `OffsetOpenM < −2.0`. |
| BK-3 | **HomingFault** (`ErrorID:10`) — codeurs non réf. pour séquence benne | `FB_Bucket` §1 c.4 | `NOT HomedM1 OR NOT HomedM2` | attendu (protège la séquence). | ✅ | garder ; pour utilisation partielle non-réf. → bit forcé provisoire `HomedM1/M2` (cf. `T244`). |
| BK-4 | **Timeout** (`ErrorID:04`) | `FB_Bucket` §1 c.2 | `CfgTimeoutDuration` (T#60s, réglable IHM) | ❓ | ❓ | vérifier suffisant en jog lent. |
| BK-5 | **M1Slip** (`ErrorID:08`) | `FB_Bucket` §1 c.3 | `ABS(M1 − M1RefPos) > M1SlipToleranceM` (1.0 m) pendant `Busy` | ❓ | 🔧 ? | à confirmer benne en charge. |
| BK-6 | **StateIncoherent** (boot : ni ouvert ni fermé, ou les deux) | `FB_Bucket` §3 | `FirstCycle` | apparaît si datum benne perdu au boot. | 🕒 | `T241` §4a (commit `b6837198`) recale l'état dès arrêt machine + réf. ; `T244` bit forcé pour usage partiel. |

### 2.2bis Calibration bandes de classification (`T241` §4a — dépendance directe)

> ⚠️ La classification `NearClosed`/`NearOpen` = `|Δ − Offset| ≤ CoherenceLimitM`. Avec `OffsetCloseM = 15` (non calibré) et `CoherenceLimitM = 1.0` → bande fermée = **[14.0, 16.0]**. Or Δ réel benne fermée sur FDC ≈ **13.95** (MES-045) → **hors bande** → classe intermédiaire, `ActiveOffsetM` ne snape pas.
> **Ordre banc obligatoire** : (1) recalibrer `OffsetCloseM ≈ 13.95` / `OffsetOpenM ≈ −0.13` aux vrais FDC ; (2) sinon élargir `CoherenceLimitM` → **1.5** (tassement galets + allongement sous charge).
> Point 1 (arrêt volontaire mi-course, Δ ≈ 7.5) : retombe sur dernier état franc + `HoldOffsetM` — continuité géométrique voulue, à valider banc. (Revue expert externe 2026-09-03.)

### 2.3 Cycle homing machine — `FB_CycleMachineHoming`

| # | Blocage | Loc. | Condition | Symptôme | Verdict | Suite |
|---|---------|------|-----------|----------|---------|-------|
| HM-1 | `TransactionAbort` → `HXF_FAILED` en HX3 | HX3 | dépend de `M1/M2Status.HomedAndReliable` | 🔴 M2 jamais `HomedAndReliable` (MecaA SW-1) → abort → FAILED, datum M2 corrompu. | 🕒 | résolu par SW-1 / `T240`. |
| HM-2 | Auto-armement HX0→HX1 | HX0 | `AutoArmTimer.Q AND NOT BothAxesHomed` (depuis `eec7014d`) | OK après fix (ne repart plus si homed). | ✅ | — |
| HM-3 | Forçage step | §4bis | `TglCommissioning AND MAINT_N2` (gate `NOT Fault.Latched` **retiré** `9a2518d2`) | OK (marche défaut latché). | ✅ | tester banc. |

### 2.4 Translation M3 — bits « at position » (point 3 séance)

| # | Symptôme | Hypothèses | Verdict | Suite |
|---|----------|------------|---------|-------|
| M3-1 | Bits « at position » (trémie / P1 / zone maintenance) **ne s'activent pas** à l'arrivée sur la position. | (a) seuil de fenêtre position trop serré vs précision décodeur capteurs ; (b) logique de détection zone maintenance incorrecte ; (c) position M3 pas mise à jour (`FB_Translation_PositionDecoder` / `PositionEstimator`) ; (d) référence M3 non faite. | ❓ **`T242`** | Diag banc : snapshot position M3 vs seuils `_TranslationCfgPersist` ; vérifier décodage capteurs (MES-018) ; élargir fenêtre OU corriger logique. |

### 2.5 Permis de mouvement (rappel — non-latchés mais bloquants)

| # | Permis | Loc. | Piège connu | Verdict |
|---|--------|------|-------------|---------|
| PM-1 | `EffectivePermitM2_Descend` (ouverture benne) | `PRG_04` | gaté `DescendPermitDiveBucketOpen` (Dive only) → benne pas ouvrable hors Dive | 🔧 **fait** (`0defd32e`, R1 : `+ ManualBucketJogActive`) |
| PM-2 | `CommonMaxStep*` = 1 si M1/M2 non `HomedAndReliable` | `PRG_04` §5ter | palier bloqué à 1 tant que non réf. (sécurité ISO 13849) | ✅ garder ; usage partiel → `T244` bits forcés |
| PM-3 | Translation interdite si `M1/M2 < _TranslationMinHeightM1M2_M` (6.0 m) | `PRG_05` | dépend de la mesure M1/M2 (fausse si datum corrompu) | 🕒 lié `T241` |

---

## 3. Bypass actifs (essais) — à réactiver

| Bypass IHM | Motif | Posé le | Réactivation cible | Réf |
|------------|-------|---------|--------------------|-----|
| `M1M2Sync.Bypass.Global` (FB_WinchSync) | MecaE fantôme (SW-2) datum M2 faux | 2026-09-03 (banc, manuel utilisateur) | après validation `T241` §4a au banc | MES-045 |
| *(compléter au fil des essais)* | | | | |

---

## 4. Décisions structurantes à retenir

- **Ne jamais** poser un bypass **code** jetable : utiliser les bypass **IHM granulaires existants** (matrice AF-05 §4bis) → traçable, réversible, réactivable.
- Tout défaut lié à une **mesure de position** est suspect tant que le référencement M1/M2/benne n'est pas fiable (`T241` + `T240`) → prioriser ces deux tâches.
- Pour l'**utilisation partielle** machine non référencée : bits forcés provisoires documentés dans `T244`, jamais dans le code committé sans marquage `[PROVISOIRE]` + tâche de retrait.
