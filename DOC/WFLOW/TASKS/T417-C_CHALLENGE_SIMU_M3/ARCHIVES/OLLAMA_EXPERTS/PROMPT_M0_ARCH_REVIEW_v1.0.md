# Revue Architecture & Risques — Refonte GRAFCET Homing 5 Étapes (T417-C)

Tu audites le design détaillé ci-dessous AVANT toute écriture dans `CODE/`. Cherche impitoyablement les pièges sécurité (ISO 13849), les deadlocks joystick/mode, les faux défauts, les bugs de câblage `PRG_02..PRG_07`, et les pièges simulation (`FB_SimBench`).

## 1. Contraintes verrouillées D1–D7
- **D1 Modes :** Homing complet faisable en `MAINT_N1` (mouvements libres N1 bloqués en Step 0 tant que `NOT MachineHomed`) ET en `MAINT_N2` (dégagement libre secours en cas de blocage méca).
- **D2 Entrée Step 0 :**
  - En `MAINT_N1` : `HwIn.Operator.JoyBtnRaw` maintenu `5 s` au neutre strict (`AtNeutralXY`) + anti-collage (`SeenReleased`) + décompte visible dans `MachineHomingInstruction`. Ne dépend pas de `DeadmanArmed` (qui serait bloqué si `ArmingPermit = FALSE` en Step 0 N1).
  - En `MAINT_N2` : front `BtnStart` au neutre (ou `JoyBtnRaw` 5 s).
  - Verrou absolu : impossible d'entrer en Step 1 si `MachineHomed = TRUE`.
- **D3 Step 1 (`HX1_BUCKET_PREPARE`) :**
  - M2 seul (`CmdWinchSelect := 2`), ouverture ET fermeture autorisées au palier 1.
  - ZÉRO butée soft (`ManualBucketLimitsActive` = FALSE et limite basse `CfgCableLimitDescentM` inhibée pendant Step 1 via `SoftLimitsBypassed` distinct de `InReferencingMode` — ne jamais aveugler `TopPositionSensor` / `Meca D`).
  - Purger `instBucket` à l'entrée Step 1 (élimine `ErrorID:04` et `ErrorID:05` résiduels).
  - Garde continue **`20 s`** paramétrable (`Cfg`) avec décompte live dans `MachineHomingInstruction` ; si dépassé, coupure M2 jusqu'au neutre + relâchement homme-mort.
  - Validation par `BtnValidate` au neutre (+ compat `BtnConfirmHomingBucket` si pressé au neutre).
- **D4 Step 2 (`HX2_CLIMB_TO_TOP`) :**
  - Couplé M1+M2 (`CmdWinchSelect := 0`, palier 1), attente arrêt mécanique + neutre + `WinchSelArbitrated = 0` avant ordre mouvement.
  - Montée lente (`DeadmanArmed AND JoystickPull`) + descente détente câble autorisée **bornée à `2 s` max par geste** (coupure nette à 2 s -> retour neutre).
- **D5 Contact TOP vs 8.5 m :**
  - Toucher `TopPositionSensor` = **PERDU / surcourse** → coupure immédiate de la montée, **JAMAIS** d'écriture `8.5 m` sur contact TOP, bascule immédiate en Step 3.
  - Arrêt visuel au plus près **avant** `TopPositionSensor` (`= FALSE`) + `BtnValidate` au neutre → Step 4 (`HX4_FINAL_CONFIRM`).
- **D6 Step 3 (`HX3_TOP_CLEARANCE`) :**
  - Montée strictement interdite.
  - Descente lente couplée M1+M2 autorisée, sans `Meca D` sur descente intentionnelle pure (`ReqDescend AND NOT ReqAscent` et aucun contacteur montée), sans limite soft basse.
  - Temporisation **`4 s` de descente continue APRÈS relâchement `TopPositionSensor`** (indépendante des codeurs), puis au neutre → retour **Step 1**.
- **D4bis Step 4 (`HX4_FINAL_CONFIRM`) :**
  - Mouvements bloqués, message d'avertissement explicite (`8.5 m + benne fermee`).
  - Sur `BtnValidate` au neutre et `NOT TopPositionSensor` : `M1Demand` (`8.5 m`, cible explicite même si `TopPositionSensor = FALSE`) + `M2Demand` (`8.5 m + OffsetCloseM`), attente `BothAxesHomed`, `BucketCommit.CommitClose := TRUE` → `MachineHomed := TRUE` → retour Step 0 avec message `'Homing fait'`.
- **D7 `Meca D` & `M3` :**
  - `Meca D` (`PowerCutOff`) reste ACTIF en `MAINT_N2` (ne plus masquer `PowerCutOff` par `AND NOT MaintN2` dans `PRG_04:1632,1653`, mais éviter faux `Meca B` pendant `MaintenanceN2BrakeForceM1/M2`).
  - Homing possible quelle que soit la position de `M3` (même entre capteurs) : `M3Locked` dès Step 0 en `N1`/`SEMI_AUTO` (libre en `N2` Step 0), levée des blocages `M3AtTremie`, `T248`, `WinchDescentAuth_M3` pendant `MachineHoming.Active`.
- **Fixes socle :**
  - `FB_Bucket` : invalider `BucketReferenced` si `NOT (HomedM1 AND HomedM2)` + `Gate` `WinchBothIntent` sur `WinchSel=0`.
  - `FB_Encoder_Homing` : bloquer `BtnHome` unitaire à 8.5 m hors `TopPositionSensor`, mais permettre le commit explicite Step 4 (`UseDynamicTarget`) quand `MachineHoming.Active`.
  - `PRG_07` : compléter `AnyFaultActive` (+ labels dans `FB_Hmi_BannerFormatter.st` pour G506) et ne pas activer `Bypass.TopLimitSwitch`/`Bypass.Safety` via `SimBypassRise`.
  - `PRG_03` : boot en `MAINT_N1` si `NOT MachineHomed` (évite faux défaut `SEMI_AUTO`).
  - `FB_SimBench` : ne pas engager `M2_MechanicStopEngaged` avant que M1/M2 soient référencés.

## Questions à trancher (réponse concise, factuelle, max 10 points critiques)
1. Y a-t-il un trou de sécurité ou un deadlock caché dans ce flux (ex. `ArmingPermit`, `InReferencingMode`, `Meca D` en N2 + descente par gravité frein forcé, `UseDynamicTarget` M1 au Step 4, `FB_WinchSync`, `Step 1 -> Step 2` transition) ?
2. Vérifier la cohérence des seuils / temps (`20 s` Step 1, `2 s` détente Step 2, `4 s` dégagement Step 3, `5 s` Step 0, `3 s` Meca B/D) et des états de repli (`HX7_FAILED` vs `Abort`).
3. Lister les invariants incontournables à tester dans `test_fb_cyclemachinehoming.st`.
