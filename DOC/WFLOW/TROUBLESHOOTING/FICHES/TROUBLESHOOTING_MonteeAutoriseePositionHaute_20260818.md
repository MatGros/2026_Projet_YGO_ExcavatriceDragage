# 🕵️ Session de Troubleshooting — Montée autorisée en position haute + descente bloquée (simulation dragage)

> 📅 Date : 2026-08-18 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [EN COURS]

## 1. 🧊 Contexte figé (horodaté)

> ⚠️ Contexte partiel — à compléter par lecture utilisateur (voir §6). Ne pas conclure avant.

- Simulation active (`SimulationModeActive=TRUE`) · `SimWinchActive=TRUE`
- `SimulationBypassActive` : **à confirmer** (TRUE = bypass top limits actif)
- Mode machine : **à confirmer** (MAINT_N1 / MAINT_N2 / SEMI_AUTO)
- Référencement (Homed M1/M2) : **à confirmer**
- Commande : joystick ou boutons IHM : **à confirmer**
- Treuil concerné : M1 / M2 / both : **à confirmer**

### Variables & valeurs
| <nobr>Élément</nobr> | <nobr>Variable complète</nobr> | Valeur | <nobr>Horodatage</nobr> |
|---|---|---|---|
| Capteur haut simulé | `HwIn.Winch.M1M2_TopPositionFree_DI` | TRUE (toujours, FB_SimBench L211) | statique |
| Bypass top limit | `PRG_02_Acquisition.SimulationBypassActive` | à confirmer | |
| Position M1 | `CablePosM1` | à confirmer | |
| Position M2 | `CablePosM2` | à confirmer | |
| Défaut treuil | `MotionM1/MotionM2.ErrorId` | à confirmer | |

## 2. 🎯 Symptôme

En simulation dragage : appui « remonter » → le treuil **monte** (alors que l'utilisateur s'attend à une interdiction en position haute), puis **passe en défaut**. La **descente ne fonctionne pas**. Incohérence perçue : « on peut monter (interdit) mais pas descendre (autorisé) ».

## 3. 🧩 Indices / historique

- Derniers changements : fiche 2026-08-16 (même domaine) — descente bloquée par interlock Dive (benne non ouverte), montée bloquée par limite haute (comportement normal).
- Déjà essayé : appui remonter / descendre en simulation.
- Conditions : simulation, mode dragage.
- Alarmes : à confirmer (ErrorId).

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | **Montée autorisée car top limit bypassé en simu** | `SimulationBypassActive` → `BypassTopLimitSwitch/Software` | TRUE (PRG_04 L732-735, L790-793) | à confirmer | ⏳ |
| 2 | Capteur haut jamais atteint en simu | `HwIn.Winch.M1M2_TopPositionFree_DI` | TRUE constant (FB_SimBench L211) | TRUE | ✅ statique |
| 3 | **Défaut = Méca B (pilotage actif sans commande opérateur)** | `instSafetyWinchMx.ErrorId bit8` | TRUE si boutons + joystick neutre >3s (FB_Safety_Winch L302-310) | à confirmer | ⏳ |
| 4 | Descente bloquée par interlock Dive | `DescendPermitDiveBucketOpen` | FALSE si benne non ouverte (PRG_04 L660-661) | à confirmer | ⏳ |
| 5 | Descente bloquée par limite basse / mou câble | `instSafetyWinchMx.DescendPermit` | à confirmer | à confirmer | ⏳ |

## 5. 📊 Arbre vertical des hypothèses (flux de données)

```text
MONTÉE (Direction=+1)
  → TopPositionSensor = TRUE (simu, jamais atteint)          ✅ (jamais interdit)
  → BypassTopLimitSwitch/Software = TRUE (simu bypass)       ✅ (limite logicielle ignorée)
  → AscentPermit = TRUE                                      ✅ → montée AUTORISÉE
  → (si boutons) JoystickYNeutral=TRUE + mouvement >3s      ❌ → Méca B (bit8) → défaut

DESCENTE (Direction=-1)
  → instDiveSearch.Enable + benne non ouverte                ❌
  → DescendPermitDiveBucketOpen = FALSE                      ❌ → descente BLOQUÉE
```

**Résumé une ligne** : `[TopSensor=1]→[BypassTop=1]→[AscentPermit=1]→monte→[MecaB=1]❌` · `[Dive=1]→[BucketOpen=0]→[DescendPermit=0]❌`

## 6. 📊 Données / interactions

> ⏳ Lectures utilisateur requises pour confirmer (canal `GVL_Troubleshooting`) :
> - `MotionM1/MotionM2.ErrorId` (le défaut exact)
> - `ContexteMachineGlobal` : mode, `SimulationBypassActive`
> - `HomingM1/HomingM2.Homed`
> - `BenneOuvertureFermeture.IsOpen`
> - `MotionM1/MotionM2.AscentPermit` / `DescendPermit`

## 7. 🏁 Conclusion

- **Cause racine** : à confirmer (ErrorId treuil en suspens).
- **Descente bloquée — PROUVÉE** : `DumpAtTremieDescentLocked=TRUE` (M3 pas à P1/Maintenance stable) → `DescendPermitM1/M2_Raw=FALSE` (PRG_04 L816-821). Benne ouverte (`BucketIsOpen=TRUE`) → l'interlock Dive n'est PAS le bloqueur ici.
- **Montée → défaut** : SafeStop + PowerCutOff (winch safety) actifs au snapshot 160206. Bit exact (ErrorId) non capturé dans les snapshots (champs `MotionM1/M2` en « ERREUR: Expression non valide »).
- **`Idx203_BypassSensorsGlobal=FALSE`** → la limite haute N'EST PAS bypassée (hypothèse initiale éliminée).
- **Statut** : EN COURS — basculé en revue conception (T125/T126/T127) ; ErrorId à fournir pour clore le volet défaut.

## 8. 🛠️ Proposition de correction

> À compléter une fois la cause confirmée.

## 9. ✅ Vérification de la correction / non-régression

> À compléter après validation.

## 10. 📝 Journal (chronologique)

- 2026-08-18 : ouverture session. Analyse statique : montée autorisée en position haute = bypass top limit en simulation (FB_SimBench L211 + PRG_04 L732-735) ; défaut suspecté = Méca B (boutons + joystick neutre) ; descente bloquée = interlock Dive (benne non ouverte). En attente de confirmation utilisateur.
- 2026-08-18 : snapshots 160206/160229 lus. **Hypothèse bypass top limit éliminée** (`Idx203_BypassSensorsGlobal=FALSE`). **Descente bloquée prouvée** = `DumpAtTremieDescentLocked` (M3 pas à P1/Maintenance). Défaut montée = SafeStop+PowerCutOff, bit exact non capturé.
- 2026-08-18 : bascule en **revue conception** des modes dragage (DiveSearch/ExtractionSequence/DumpAtTremie). Écarts DumpAtTremie identifiés (verrou translation trémie absent, latch « une fois descendu » absent, logique inline dans PRG_04). Loggé → **T125** (revue), **T126** (IHM cause+contexte), **T127** (cycle semi-auto). ErrorId treuil toujours en suspens.
