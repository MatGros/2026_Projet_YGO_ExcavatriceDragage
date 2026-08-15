# 🕵️ Session de Recherche de Blocage — DeadmanArmed tombe à 0 en commande descente

> 📅 Date : 2026-08-15 · 🧊 Situation : [SIMULATION BANC]
> 📄 Statut : [RÉSOLUE — cause identifiée, correction à appliquer]

## 1. 🧊 Contexte figé

| Élément | Valeur |
|---|---|
| SimulationModeActive | TRUE |
| SimulationBypassActive | TRUE |
| Référencement axes (homing) | fait |
| Mode machine | MAINT_N1 |
| Redémarrage | chaud (valeurs par défaut) |
| Auto-arm sim (`SimJoystickRawButton`) | **retiré** (2026-08-15) — le homme-mort est testé fidèlement |

## 2. 🎯 Symptôme

`DeadmanArmed` tombe à 0 après ~3 s quand je commande la descente (`SimJoystickRev_Down_Open_Active`). Reproductible, pas intermittent.

## 3. 🧩 Indices / historique

- Derniers changements : suppression de l'auto-arm sim (`SimJoystickRawButton := TRUE`) pour tester le vrai homme-mort.
- Déjà essayé : re-import + reload du bundle ; le comportement persiste.
- Conditions d'apparition : en commande « descente » (stimulus composé down+open).
- Alarmes : aucune.

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | Désarmement au neutre (grâce 3 s) | `Joystick.Step4_NeutralAcquired` | FALSE (axe bouge) | **TRUE au clic** | ✅ **mécanisme + cause** |
| 2 | Fin de cycle benne | `BenneOuvertureFermeture.Idx401_BucketBusy` | FALSE | FALSE | ❌ éliminée |
| 3 | État benne incohérent | `BenneOuvertureFermeture.Idx105_StateIncoherent` | 0 | 0 | ❌ éliminée |
| 4 | Changement de mode | `ContexteMachineGlobal.Idx101_ModeActive` | MAINT_N1 stable | MAINT_N1 | ❌ éliminée |
| 5 | Bouton virtuel non alimenté | `Joystick.Step3_DeadmanPressed` | TRUE | **→ 0 au clic** | ⚠️ suspect |

> ⚠️ **REX 2026-08-15** : `Device.export` n'est **jamais** une référence (AGENTS.md). Toute conclusion
> basée dessus est invalide. L'analyse ci-dessous repose **uniquement** sur le code source (`.st` + bundle).

## 4bis. 📊 Diagramme de flux compact

### Diagramme (ASCII) — état de chaque nœud
```text
[StimRevDown ✓] → [RawY ✓] → [AtNeutral ✗] → [DeadmanArmed ✗]
```
- ✓ = **conforme** · ✗ = **bloqué** · `→` = séquence · `OR` = branches parallèles · `[X=12.5]` = valeur numérique
- 🔴 **Premier ✗ = cause racine** : `AtNeutral` (axe au neutre au lieu de défléchir en descente) → conséquence en cascade : `DeadmanArmed` désarmé après grâce 3 s.
- Noms condensés : `StimRevDown` = `SimJoystickRev_Down_Open_Active` · `RawY` = `JoyYRaw_ANA2` · `AtNeutral` = `Step4_NeutralAcquired` · `DeadmanArmed` = `Joystick.DeadmanArmed`.

## 5. 📊 Données / interactions

- `Idx401_BucketBusy` = FALSE fixe → **pas** de cycle benne.
- `Idx105_StateIncoherent` = 0 → état benne cohérent.
- `Step3_DeadmanPressed` (= `JoyBtnRaw`) **passe à 0 quand j'envoie la commande** → le bouton virtuel n'est pas alimenté / relâché.
- `Step4_NeutralAcquired` (= `AtNeutral`) : **TRUE au clic** (lecture `Device.Application.GVL_Troubleshooting.Joystick.Step4_NeutralAcquired`) → **l'axe ne se défléchit PAS** malgré la commande descente.
- 🔍 **Analyse code source (`.st` + bundle)** : le désarmement à ~3 s = `DeadmanArmGraceTime` (3 s) + `NeutralHoldTimer` (100 ms) dans `FB_Joystick.st` (l.199-204), **conditionné par `AtNeutral=TRUE`**. En descente `RawY=0` → `ScaleY.OutPct=-100` → `AtNeutral` devrait être FALSE. Or il est TRUE → **l'axe reste au neutre** : la commande descente ne défléchit pas l'axe.

## 6. 🏁 Conclusion

- **Cause racine** : la commande descente **ne défléchit pas l'axe** → `AtNeutral` reste TRUE → après la grâce 3 s (`DeadmanArmGraceTime`), le désarmement neutre (`NeutralHoldTimer`) coupe `DeadmanArmed`. Le mécanisme (hypothèse 1) est confirmé par la lecture.
- **Pourquoi l'axe ne défléchit pas** : à vérifier côté stimulus sim. Deux pistes :
  1. **Stimulus directionnel non câblé / non alimenté** : `SimJoystickRev_Down_Open_Active` ne produit pas `RawY=0` (bouton directionnel non relié à l'axe dans le code exécuté).
  2. **Stimulus composite** : si plusieurs boutons directionnels sont actifs simultanément, `SimJoystickDirectionCount>1` → les 2 axes forcés à 5000 (neutre) → `AtNeutral=TRUE`.
- **Correction** :
  1. **Immédiat (sans code)** : commander la descente par le stimulus analogique brut — `SimJoystickRawY := 0` (descente) + `SimJoystickRawButton := TRUE` (armement). Garanti de défléchir l'axe.
  2. **Vérifier** : lire `RawY` (`HwIn.Operator.JoyYRaw_ANA2`) au clic — doit être `0` en descente. Si `5000` → le stimulus ne défléchit pas.
- **Statut** : RÉSOLUE (cause identifiée) — correction à appliquer + vérification `RawY`.

## 6bis. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** : commander la descente par le stimulus brut — `SimJoystickRawY := 0` + `SimJoystickRawButton := TRUE` — défléchit l'axe garanti, contourne le stimulus directionnel défaillant.
- **Option 2 (définitif)** : corriger le câblage du stimulus directionnel `SimJoystickRev_Down_Open_Active` pour qu'il produise `RawY=0` (vérifier `FB_SimBench` / sélection sim `HwIn.Operator`).
- **⚠️ Validation requise** : [humaine] — ne pas modifier le code / forcer une variable sans validation.

## 7. 📝 Journal (chronologique)

- 2026-08-15 : suppression auto-arm sim (`PRG_02`) + doc `AF_Partie-13` alignée.
- 2026-08-15 : re-import + reload bundle ; symptôme persiste.
- 2026-08-15 : `Idx401`/`Idx105` éliminent la piste benne ; `Step3` suspect ; `Step4` à lire.
- 2026-08-15 : **REX** — conclusion basée sur `Device.export` retirée (jamais une référence, AGENTS.md). Analyse refondée sur le code source.
- 2026-08-15 : lecture `Step4_NeutralAcquired`=TRUE au clic → **cause confirmée** : l'axe ne se défléchit pas, désarmement neutre après 3 s. Correction : stimulus brut `SimJoystickRawY=0` + vérif `RawY`.
