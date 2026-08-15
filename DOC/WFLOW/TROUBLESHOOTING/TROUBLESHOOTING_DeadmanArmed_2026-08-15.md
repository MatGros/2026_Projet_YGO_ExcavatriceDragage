# 🕵️ Session de Recherche de Blocage — DeadmanArmed tombe à 0 en commande descente

> 📅 Date : 2026-08-15 · 🧊 Situation : [SIMULATION BANC]
> 📄 Statut : [EN COURS]

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
| 1 | Désarmement au neutre (grâce 3 s) | `Joystick.Step4_NeutralAcquired` | FALSE (axe bouge) | **à confirmer** | ⏳ |
| 2 | Fin de cycle benne | `BenneOuvertureFermeture.Idx401_BucketBusy` | FALSE | FALSE | ❌ éliminée |
| 3 | État benne incohérent | `BenneOuvertureFermeture.Idx105_StateIncoherent` | 0 | 0 | ❌ éliminée |
| 4 | Changement de mode | `ContexteMachineGlobal.Idx101_ModeActive` | MAINT_N1 stable | MAINT_N1 | ❌ éliminée |
| 5 | Bouton virtuel non alimenté | `Joystick.Step3_DeadmanPressed` | TRUE | **→ 0 au clic** | ⚠️ suspect |

## 5. 📊 Données / interactions

- `Idx401_BucketBusy` = FALSE fixe → **pas** de cycle benne.
- `Idx105_StateIncoherent` = 0 → état benne cohérent.
- `Step3_DeadmanPressed` (= `JoyBtnRaw`) **passe à 0 quand j'envoie la commande** → le bouton virtuel n'est pas alimenté.
- `Step4_NeutralAcquired` (= `AtNeutral`) : **à lire au moment du clic** — c'est la variable décisive.

## 6. 🏁 Conclusion

- **Cause racine** : à confirmer. Deux pistes :
  1. **Désarmement au neutre** (documenté `AF_Partie-08 §4`) : si `AtNeutral=TRUE` au clic → la direction ne déplace pas l'axe → problème de câblage sim.
  2. **Bouton virtuel non alimenté** : `Step3` tombe à 0 → le stimulus ne traverse pas `FB_SimBench`.
- **Correction** : à déterminer après confirmation de `Step4_NeutralAcquired`.
- **Statut** : EN COURS — attend la lecture de `Step4_NeutralAcquired`.

## 7. 📝 Journal (chronologique)

- 2026-08-15 : suppression auto-arm sim (`PRG_02`) + doc `AF_Partie-13` alignée.
- 2026-08-15 : re-import + reload bundle ; symptôme persiste.
- 2026-08-15 : `Idx401`/`Idx105` éliminent la piste benne ; `Step3` suspect ; `Step4` à lire.
