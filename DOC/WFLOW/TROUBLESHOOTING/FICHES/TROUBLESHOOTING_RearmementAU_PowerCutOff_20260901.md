# 🕵️ Session de Troubleshooting — Réarmement AU : challenge chaîne PowerCutOffRequest (abandon étape 5, cause 16#0010)

> 📌 `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_RearmementAU_PowerCutOff_20260901.md`
> 📅 Date : 2026-09-01 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [OUVERTE]
> 🎯 Type : **Challenge / diagnostic** — l'hypothèse « PowerCutOffRequest bloque l'armement » est challengée.

## 1. 🧊 Contexte figé (horodaté)
- Symptôme rapporté : le réarmement de l'AU **abandonne à l'étape 5** avec `LastAbortCause = 16#0010` (PowerCutOffRequest).
- Le diagnostic précédent (fiche `TROUBLESHOOTING_RearmementAU_20260821.md`) avait trouvé **MecaA latched sur M1 ET M2** (bit7, cause PowerCutOff) en simu, mode DISABLE.
- L'utilisateur signale que « ça ne fonctionne **toujours pas** » → l'hypothèse PowerCutOff est challengée : est-ce la cause racine ou un symptôme ?
- **NOUVELLE DONNÉE (2026-09-01)** : juste avant d'armer, `instSafetyEmergencyManagement.State.Armable = 1` et `ErrorId = 0`, MAIS le réarmement échoue quand même (`LastAbortStep=5`, `LastAbortCause=16#0010`). Hypothèse utilisateur : « un défaut non acquitté fait échouer le réarmement alors que l'état dit Armable=1 ».

## 2. 🎯 Symptôme
Abandon de la séquence d'armement AU à l'étape 5 (Pulse) avec cause `16#0010` (PowerCutOffRequest). Permanent.

## 3. 🧩 Indices / historique
- Fiche précédente : MecaA latched M1+M2 (bit7, PowerCutOff) en simu DISABLE.
- La séquence **démarre** (donc PowerCutOffRequest=FALSE au départ) puis **abandonne à l'étape 5** → PowerCutOffRequest devient TRUE pendant l'impulsion d'armement (engagement du contacteur).
- Alarmes : à confirmer par snapshot (MecaA/MecaB/MecaD/MecaE/thermique sur M1/M2/M3).

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | PowerCutOffRequest est la cause racine | `Safety.PowerCutOffRequest` | FALSE pour armer (FB_Safety_EmergencyManagementLogic.st:198-206, 326-332) | TRUE à l'abandon | 🔴 **symptôme**, pas cause racine |
| 2 | Une cause PowerCutOff latched (MecaA/MecaB/thermique) bloque | `LevageUnitaireM1/M2.Safety_300.Idx3xx_ErrorMeca*` + `TranslationPontM3.Safety_300.Idx317_ErrorId` | FALSE au repos | ? | à lire (snapshot) |
| 3 | La cause se re-latche pendant l'armement (feedback) | `Safety.LastAbortStep`/`LastAbortCause` + cause bit | 16#0010 + bit cause | 5 / 16#0010 | 🔴 à confirmer |
| 4 | Latch non acquitté (Reset manquant) | `Safety.ArmingErrorId` / `Safety.SafetyError` | 0 après Reset | ? | à lire |
| 5 | **Armable=1 masque un défaut non acquitté** (hypothèse utilisateur) | `State.Armable` vs `PowerCutOffRequest` | Armable=1 ⟹ PowerCutOffRequest=FALSE (FB_Safety_EmergencyManagementLogic.st:326-332) | Armable=1, PCO=FALSE au snapshot | ❌ **réfutée** (voir §7) |
| 6 | **La cause se latche PENDANT l'armement (feedback)** | `TranslationPontM3.Safety_300.Idx314_ErrorMecaA` / `Idx317_ErrorId` | FALSE au repos | ? | 🔴 **cause probable** (à confirmer) |

## 5. 📊 Arbre vertical des hypothèses (flux de données)

```text
ArmRequest (front) → [Armable:BOOL] → [ArmingSeqStep=1..4 tests A/B] → [étape 5 Pulse]
   → contacteur s'engage → PowerContactorEngaged=TRUE
   → un FB Safety latche une cause PowerCutOff (M3 MecaA/MecaB ? M1/M2 MecaA ?)
   → PowerCutOffRequest=TRUE → abandon 16#0010 à l'étape 5 ❌
```

**Résumé une ligne** : `[Armable=1] → [Step=5] → [PowerCutOffRequest=1] ❌ (cause racine = cause PowerCutOff latched, pas PowerCutOffRequest lui-même)`

## 6. 📊 Données / interactions & chronogramme (🟡)
- Chaîne tracée par lecture de code (PREUVE) : voir §7.
- Chronogramme attendu (à confirmer par snapshot) :
| Événement | PowerCutOffRequest | ArmingStep | PowerContactorEngaged |
|:---:|:---:|:---:|:---:|
| Départ armement | 0 | 1 | 0 |
| Tests A/B | 0 | 1→4 | 0 |
| Pulse (étape 5) | 0→1 | 5 | 0→1 |
| Abandon | 1 | 0 | 1 |

## 7. 🏁 Conclusion (challenge)

- **Chaîne PowerCutOffRequest complète (PREUVE, lecture code)** :
  1. `FB_Safety_Winch.st:§3` → `PowerCutOff := CausesPowerCutOffActive` (bits 2,7,8,9,10,11,13 = MotorThermal, MecaA, MecaB, MecaC, BrakeThermal, MecaD, MecaEEscalade — tous latched). Ancien masque `16#2F84` (retiré T209) : SANS MecaE-écart (bit12, laissé au SafeStop tant que non confirmé).
  2. `FB_Safety_Translation.st:249` → `PowerCutOff := (Fault.ErrorId AND 16#00F8)<>0` (bits 3..7 = BrakeThermal, MecaB, MecaA, LimitSwitch, SensorIncoherent).
  3. `PRG_04_Treuils_Benne.st:1074,1089` → `WinchM1/M2FinalInterlockRequest.PowerCutOff := instSafetyWinchM1/M2.PowerCutOff`.
  4. `PRG_05_Translation.st:378` → `TranslationFinalInterlockRequest.PowerCutOff := instSafetyTranslationM3.PowerCutOff`.
  5. `PRG_06_Outputs.st:292-294` → `PowerCutOffReq := M1.PowerCutOff OR M2.PowerCutOff OR M3.PowerCutOff`.
  6. `PRG_06_Outputs.st:302` → `PowerCutOffRequest := PowerCutOffReq` → `instSafetyEmergencyManagement`.
  - Abandon : `FB_Safety_EmergencyManagementLogic.st:175-183` → si `PowerCutOffRequest` pendant séquence → `LastAbortCause=16#0010`, `ArmingSeqStep:=0`.

- **État réel AU exposé au snapshot** : `GVL_Troubleshooting.Safety` (ST_SafetyChecklist) **entièrement câblée** (`FB_TroubleshootingView.st:494-526`) et **présente dans `troubleshooting_variables.txt:327-352`**. Expose `PowerCutOffRequest`, `PowerCutOffActive`, `ArmingStep`, `LockoutActive`, `PowerContactorEngaged`, `LastAbortStep`, `LastAbortCause`, `Step5_ArmingAllowed`, etc. + par axe `Idx303_PowerCutOffActive` + bits causes individuels + `TranslationPontM3.Idx317_ErrorId`. **Un seul snapshot suffit pour identifier le FB et le bit cause.**

- **Blocage réel identifié** : `PowerCutOffRequest` est le **déclencheur immédiat** (confirmé), mais c'est un **symptôme**. La cause racine est une **cause PowerCutOff latched** dans un FB Safety (M1/M2/M3) qui **ne se lève que par Reset** (`FB_FaultCore.st:41-43`). L'abandon à l'étape 5 = la cause se latche quand le contacteur s'engage (feedback). Candidats : **M3 MecaA (bit5, 1s, PowerCutOff)** ou **M3 MecaB (bit4, 3s)** au power-up du variateur, ou **M1/M2 MecaA** (fiche précédente). **À confirmer par snapshot** (bits causes).

- **Cohérence réarmement** : le code **vérifie bien** toutes les conditions (`FB_Safety_EmergencyManagementLogic.st:198-206` : boucle fermée, pas de coupure, pas de lockout, contacteur relâché, pas de redondance). Le gate est correct. Le problème = `PowerCutOffRequest` TRUE dû à une cause latched non acquittée / re-latchée.

- **Challenge de l'hypothèse utilisateur (Armable=1 + défaut non acquitté)** : **RÉFUTÉE par le code.** `State.Armable` = `Logic.Armable` sans transformation (`FB_Safety_EmergencyManagement.st:74` → `FB_Safety_EmergencyManagementOutput.st:76`), et `Logic.Armable` exige **`NOT PowerCutOffRequest`** (`FB_Safety_EmergencyManagementLogic.st:326-332`). Donc **`Armable=1` ⟹ `PowerCutOffRequest=FALSE` à cet instant** : aucun défaut PowerCutOff n'est actif au moment du snapshot. `ErrorId=0` est l'ErrorId propre de l'AU (bits redondance/armement/startup, §9), indépendant des causes PowerCutOff des FB Safety — il ne dit rien sur les FB Safety.
- **Mécanisme réel** : le défaut n'est PAS présent avant l'armement ; il est **CRÉÉ par l'armement lui-même (feedback)**. La séquence démarre (Armable=1, PowerCutOffRequest=FALSE), passe les tests A/B (steps 1-4), puis à l'**étape 5 (Pulse)** le contacteur s'engage → un FB Safety latche une cause PowerCutOff → `PowerCutOffRequest=TRUE` → abandon 16#0010. Candidat le plus probable : **Translation M3 MecaA (bit5, 1s, PowerCutOff)** — au power-up du variateur, si `DriveActualFreqHz > 0.5 Hz` avec `Direction=0` et `NOT BrakeCmd` (`FB_Safety_Translation.st:171-178`), MecaA latche après 1s (≈ durée du pulse) → abandon à l'étape 5. Alternative : **M3 MecaB (bit4, 3s)** → abandon à l'étape 6. **À confirmer par snapshot** (`TranslationPontM3.Safety_300.Idx314_ErrorMecaA` / `Idx317_ErrorId`).

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** : prendre **un snapshot** pendant l'abandon → lire `Safety.LastAbortCause` + `LevageUnitaireM1/M2.Safety_300.Idx3xx_ErrorMeca*` + `TranslationPontM3.Safety_300.Idx317_ErrorId` → identifier le FB/bit cause → lever la cause physique → **Reset** (`FaultMachineReset_IHM`) pour dé-latcher → réarmer. — Impact : résout si cause latched non acquittée.
- **Option 2 (définitif, IHM)** : dans `FB_Hmi_BannerFormatter.st:370`, décoder la cause 16#0010 en **cause explicite** (M1/M2/M3 + bit MecaA/MecaB/thermique) au lieu du message générique « lever la cause puis rearmer ». Le FB a déjà `WinchM1Safety/WinchM2Safety/TranslationSafety` en entrée. — Impact : rend l'échec visible et actionnable.
- **Option 3 (séquence, décision sécurité)** : évaluer si l'armement doit être robuste aux transitoires des tests A/B (ne pas abandonner sur PowerCutOffRequest pendant les tests, seulement pendant Pulse/Confirm). ⚠️ **Décision de sécurité — ne pas affaiblir l'interlock sans validation humaine.**
- **⚠️ Validation requise** : [humaine] — ne pas modifier le code / forcer une variable sans validation.

## 9. ✅ Vérification de la correction / non-régression
- À faire après correction validée : réarmer l'AU → `PowerContactorEngaged=TRUE`, `AllConditionsMet=TRUE`, `ArmingStep=0`, `LastAbortCause=0`.

## 10. 📝 Journal (chronologique)
- 2026-09-01 : challenge de l'hypothèse PowerCutOff — chaîne tracée par lecture de code, état AU exposé au snapshot confirmé, cause racine = cause PowerCutOff latched (symptôme ≠ cause). Snapshot requis pour identifier le bit cause exact.
- 2026-09-01 (2e passe) : nouvelle donnée `Armable=1` + `ErrorId=0` avant armement → hypothèse utilisateur « défaut non acquitté masqué par Armable » **réfutée** (Armable exige NOT PowerCutOffRequest). Mécanisme réel = **feedback** : la cause PowerCutOff se latche PENDANT l'armement (étape 5, engagement contacteur), candidat M3 MecaA (bit5, 1s). Snapshot requis pour confirmer le bit cause.
