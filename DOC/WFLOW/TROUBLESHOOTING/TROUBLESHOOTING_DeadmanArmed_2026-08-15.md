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
| 1 | Désarmement au neutre (grâce 3 s) | `Joystick.Step4_NeutralAcquired` | FALSE (axe bouge) | **TRUE (axe au neutre)** | ✅ **mécanisme** |
| 2 | Fin de cycle benne | `BenneOuvertureFermeture.Idx401_BucketBusy` | FALSE | FALSE | ❌ éliminée |
| 3 | État benne incohérent | `BenneOuvertureFermeture.Idx105_StateIncoherent` | 0 | 0 | ❌ éliminée |
| 4 | Changement de mode | `ContexteMachineGlobal.Idx101_ModeActive` | MAINT_N1 stable | MAINT_N1 | ❌ éliminée |
| 5 | Bouton virtuel non alimenté | `Joystick.Step3_DeadmanPressed` | TRUE | **→ 0 au clic** | ⚠️ suspect |
| 6 | **Version sim périmée (cause racine)** | `Device.export` vs `CODE_Bundle.xml` | câblage boutons directionnels | **absent dans Device.export** | ✅ **cause** |

## 5. 📊 Données / interactions

- `Idx401_BucketBusy` = FALSE fixe → **pas** de cycle benne.
- `Idx105_StateIncoherent` = 0 → état benne cohérent.
- `Step3_DeadmanPressed` (= `JoyBtnRaw`) **passe à 0 quand j'envoie la commande** → le bouton virtuel n'est pas alimenté.
- `Step4_NeutralAcquired` (= `AtNeutral`) : **TRUE au clic** → l'axe ne se déplace PAS malgré la commande descente.
- 🔍 **Cause racine (version sim)** : `Device.export` (14/08, code exécuté) a une section `FB_SimBench` opérateur qui **n'utilise QUE** `SimJoystickRawX/RawY/RawButton` — les boutons directionnels (`SimJoystickRev_Down_Open_Active`…) ne sont **pas câblés** à l'axe. Le bundle `CODE_Bundle.xml` (15/08) et `FB_SimBench.st` (15/08) **les câblent** (`JoyYRaw_ANA2 := 0` + `JoyBtnRaw := ... OR DirectionCount>0`). → Le banc exécute une **version périmée** de `FB_SimBench`.

## 6. 🏁 Conclusion

- **Cause racine** : le banc exécute un `FB_SimBench` **périmé** (Device.export 14/08) qui ne câble pas les boutons directionnels. Commande descente via `SimJoystickRev_Down_Open_Active` = **no-op** sur l'axe → `AtNeutral` reste TRUE → après la grâce 3 s (`DeadmanArmGraceTime`), le désarmement neutre (`NeutralHoldTimer`) coupe `DeadmanArmed`. Le mécanisme (hypothèse 1) est correct ; la cause profonde est l'écart de version sim.
- **Correction** :
  1. **Immédiat (sans code)** : commander la descente par le stimulus analogique brut — `SimJoystickRawY := 0` (descente) + `SimJoystickRawButton := TRUE` (armement). Compatible avec le code exécuté.
  2. **Définitif** : ré-importer le bundle courant (`CODE_Bundle.xml`, 15/08) et **vérifier** que `SimJoystickRev_Down_Open_Active` défléchit réellement l'axe (lecture `AtNeutral`/`RawY`). Re-générer `Device.export` pour aligner la référence.
- **Statut** : RÉSOLUE (cause identifiée) — correction à appliquer + vérification.

## 7. 📝 Journal (chronologique)

- 2026-08-15 : suppression auto-arm sim (`PRG_02`) + doc `AF_Partie-13` alignée.
- 2026-08-15 : re-import + reload bundle ; symptôme persiste.
- 2026-08-15 : `Idx401`/`Idx105` éliminent la piste benne ; `Step3` suspect ; `Step4` à lire.
- 2026-08-15 : `Step4_NeutralAcquired`=TRUE au clic → axe non défléchi. Écart de version `Device.export` (14/08, sans boutons directionnels) vs `CODE_Bundle.xml`/`FB_SimBench.st` (15/08, avec). Cause racine = version sim périmée.
