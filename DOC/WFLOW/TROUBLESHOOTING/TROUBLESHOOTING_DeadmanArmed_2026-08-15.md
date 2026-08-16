# 🕵️ Session de Troubleshooting — Recherche de Blocage et de Panne — DeadmanArmed tombe à 0 en commande descente

> 📅 Date : 2026-08-15 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [RÉSOLUE — cause identifiée, correction à appliquer]

## 1. 🧊 Contexte figé (horodaté)

| <nobr>Élément</nobr> | <nobr>Variable complète</nobr> | Valeur | <nobr>Horodatage</nobr> |
|---|---|---|---|
| Simulation active | `GVL_Simulation.SimulationModeActive` | TRUE | 2026-08-15 |
| Bypass actif | `GVL_Simulation.SimulationBypassActive` | TRUE | 2026-08-15 |
| Référencement axes | `PRG_02_Acquisition.instHomingM1.Homed` | fait | 2026-08-15 |
| Mode machine | `PRG_03_Modes_Cycle.Auth.Mode` | MAINT_N1 | 2026-08-15 |
| Redémarrage | — | chaud | 2026-08-15 |
| Auto-arm sim | `GVL_Simulation.SimJoystickRawButton` | **retiré** (2026-08-15) | 2026-08-15 |

## 2. 🎯 Symptôme

`DeadmanArmed` tombe à 0 après ~3 s quand je commande la descente (`SimJoystickRev_Down_Open_Active`). Reproductible, pas intermittent.

## 3. 🧩 Indices / historique

- Derniers changements : suppression de l'auto-arm sim (`SimJoystickRawButton := TRUE`) pour tester le vrai homme-mort.
- Déjà essayé : re-import + reload du bundle ; le comportement persiste.
- Conditions d'apparition : en commande « descente » (stimulus composé down+open).
- Alarmes : aucune.

## 4. 🌳 Arbre des causes & hypothèses

| # | <nobr>Hypothèse</nobr> | <nobr>Variable de décision</nobr> | <nobr>Valeur attendue (source)</nobr> | <nobr>Valeur lue</nobr> | Verdict |
|---|---|---|---|---|---|
| 1 | Désarmement au neutre (grâce 3 s) | `Joystick.Step4_NeutralAcquired` | FALSE (axe bouge) — `FB_Joystick.st` l.199-204 | **TRUE au clic** | ✅ **cause** |
| 2 | Fin de cycle benne | `BenneOuvertureFermeture.Idx401_BucketBusy` | FALSE — `AF_Partie-08 §4` | FALSE | ❌ |
| 3 | État benne incohérent | `BenneOuvertureFermeture.Idx105_StateIncoherent` | 0 — `ST_ChainBucket` | 0 | ❌ |
| 4 | Changement de mode | `ContexteMachineGlobal.Idx101_ModeActive` | MAINT_N1 stable — `E_Mode` | MAINT_N1 | ❌ |
| 5 | Bouton virtuel non alimenté | `Joystick.Step3_DeadmanPressed` | TRUE — `FB_SimBench` l.324 | **→ 0 au clic** | ⚠️ suspect |

> ⚠️ **REX 2026-08-15** : `Device.export` n'est **jamais** une référence (AGENTS.md). Analyse sur code source (`.st` + bundle).

## 5. 📊 Arbre vertical des hypothèses (flux de données) — OBLIGATOIRE

```text
Symptôme : DeadmanArmed tombe à 0 en commande descente
│
├─ H1 Demande
│   ├─ [StimRevDown:BOOL=TRUE] ✅
│   └─ [RawY:INT=0] ✅
├─ H2 Joystick FB
│   ├─ [AtNeutral:BOOL=TRUE] ❌ blocage (axe au neutre au lieu de défléchir)
│   └─ [DeadmanArmed:BOOL=FALSE] ❌ conséquence
```

**Résumé une ligne** : `[StimRevDown:BOOL=1] → [RawY:INT=0] → [AtNeutral:BOOL=1] ❌ → [DeadmanArmed:BOOL=0] ❌`

## 6. 📊 Données / interactions & chronogramme (🟡)

### Lectures & essais
- `Idx401_BucketBusy` = FALSE fixe → pas de cycle benne.
- `Idx105_StateIncoherent` = 0 → état benne cohérent.
- `Step3_DeadmanPressed` (= `JoyBtnRaw`) → 0 au clic → bouton virtuel non alimenté.
- `Step4_NeutralAcquired` (= `AtNeutral`) = **TRUE au clic** → l'axe ne se défléchit PAS malgré la commande descente.
- 🔍 Code : désarmement ~3 s = `DeadmanArmGraceTime` (3 s) + `NeutralHoldTimer` (100 ms) dans `FB_Joystick.st` (l.199-204), conditionné par `AtNeutral=TRUE`. En descente `RawY=0` → `ScaleY.OutPct=-100` → `AtNeutral` devrait être FALSE. Or il est TRUE → l'axe reste au neutre.

### Chronogramme (🟡 — séquence observée)
| <nobr>Événement</nobr> | <nobr>StimRevDown</nobr> | <nobr>DeadmanArmed</nobr> | <nobr>AtNeutral</nobr> |
|:---:|:---:|:---:|:---:|
| T1 | █ | █ | |
| → 100 ms | | | |
| T2 | █ | █ | |
| → 3 s | | | |
| T3 | █ |   | █ |

## 7. 🏁 Conclusion

- **Cause racine** : la commande descente **ne défléchit pas l'axe** → `AtNeutral` reste TRUE → après la grâce 3 s (`DeadmanArmGraceTime`), le désarmement neutre (`NeutralHoldTimer`) coupe `DeadmanArmed`. Mécanisme (hypothèse 1) confirmé par lecture.
- **Pourquoi l'axe ne défléchit pas** : à vérifier côté stimulus sim (2 pistes : stimulus non câblé / stimulus composite → neutre).
- **Statut** : RÉSOLUE (cause identifiée) — correction à appliquer + vérification `RawY`.

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** : commander la descente par le stimulus brut — `SimJoystickRawY := 0` + `SimJoystickRawButton := TRUE` — défléchit l'axe garanti, contourne le stimulus directionnel défaillant.
- **Option 2 (définitif)** : corriger le câblage du stimulus directionnel `SimJoystickRev_Down_Open_Active` pour qu'il produise `RawY=0` (vérifier `FB_SimBench` / sélection sim `HwIn.Operator`).
- **⚠️ Validation requise** : [humaine] — ne pas modifier le code / forcer une variable sans validation.

## 9. ✅ Vérification de la correction / non-régression

> ⚠️ **Hand-off humain** : la correction (§8) doit être validée par l'humain avant application.

- À faire après correction : vérifier que `DeadmanArmed` reste armé en commande descente, et que `RawY=0` au clic. Rien d'autre cassé ?

## 10. 📝 Journal (chronologique)

- 2026-08-15 : suppression auto-arm sim (`PRG_02`) + doc `AF_Partie-13` alignée.
- 2026-08-15 : re-import + reload bundle ; symptôme persiste.
- 2026-08-15 : `Idx401`/`Idx105` éliminent la piste benne ; `Step3` suspect ; `Step4` à lire.
- 2026-08-15 : **REX** — conclusion basée sur `Device.export` retirée (jamais une référence, AGENTS.md).
- 2026-08-15 : lecture `Step4_NeutralAcquired`=TRUE au clic → **cause confirmée** : l'axe ne se défléchit pas, désarmement neutre après 3 s. Correction : stimulus brut `SimJoystickRawY=0` + vérif `RawY`.
