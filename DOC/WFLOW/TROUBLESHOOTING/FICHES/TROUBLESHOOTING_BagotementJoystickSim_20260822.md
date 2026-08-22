# 🕵️ Session de Troubleshooting — Bagotement joystick simulé ne se déclenche pas

> 📅 Date : 2026-08-22 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [RÉSOLUE]

## 1. 🧊 Contexte figé

- **SimulationModeActive** : TRUE (banc)
- **SimOperatorActive** : TRUE
- **SimJoystickBagotement_Active** : TRUE (activé pour le test)
- **SimJoystickOvershoot_Active** : testé séparément (fonctionne)
- Bouton directionnel : poussé à fond puis relâché

## 2. 🎯 Symptôme

Le **bagotement** au relâchement du joystick simulé ne se déclenche pas : le joystick revient **pile au neutre** (5000) sans aucun balancement, alors que `SimJoystickBagotement_Active = TRUE`. L'overshoot de montée, lui, fonctionne.

## 3. 🧩 Indices / historique

- **Derniers changements** : création du comportement dynamique joystick (montée/retombée/bagotement) par subagent, puis corrections (C4 combinaison boutons, amplitude bagotement 200→500, amortissement 0.11→0.05).
- **Déjà essayé** : augmenté l'amplitude (500) et réduit l'amortissement (0.05) — toujours rien.
- **Conditions** : après une montée à fond, au relâchement. Overshoot (montée) fonctionne, bagotement (retombée) non.
- **Alarmes** : aucune (simulation).

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | `BagotementActive` non transmis au modèle | câblage GVL→PRG_02→FB_SimBench→FB_Sim_Joystick | TRUE | à vérifier | ❓ |
| 2 | État ne passe jamais par RISE avant relâchement | `State` du FB | 1 (RISE) avant relâchement | à vérifier | ❓ |
| 3 | État ne passe pas en OVERSHOOT au relâchement | `State` après relâchement | 3 (OVERSHOOT) | à vérifier | ❓ |
| 4 | Oscillateur trop amorti (mouvement invisible) | `OscDev` / `OscVel` | non nul | à vérifier | ❓ |
| 5 | Condition `RawX=NeutralRaw AND RawY=NeutralRaw` jamais atteinte | `RawX`/`RawY` | vraie | à vérifier | ❓ |

## 5. 📊 Arbre vertical des hypothèses

```text
Bagotement absent
├─ H1 : BagotementActive transmis ? ── GVL → PRG_02 → SimBench → SimJoystick ❓
├─ H2 : montée effectuée (State=RISE) ? ❓
├─ H3 : relâchement → State=OVERSHOOT ? ❓
├─ H4 : oscillateur produit OscDev≠0 ? ❓
└─ H5 : condition neutre atteinte ? ❓
```

## 6. 📊 Données / chronogramme (🟡)

- **Lecture CODESYS** (par l'utilisateur) requise pour trancher H2/H3/H4.

## 7. 🏁 Conclusion

- **Cause racine** : `FB_SimBench.st` (choix de sortie) émettait un **neutre figé (5000)** dès que le bouton était relâché, donc la retombée/bagotement (qui n'ont lieu qu'après relâchement) n'étaient **jamais transmis** à `Operator.JoyX`. La machine d'état interne de `FB_Sim_Joystick` était saine (OVERSHOOT déclenché correctement).
- **Statut** : RÉSOLUE (correction appliquée, à valider en simu).

## 8. 🛠️ Proposition de correction

- **Option 2 (définitif, appliquée)** :
  1. `FB_Sim_Joystick` : ajout sortie `ReturningActive` (TRUE si état FALL ou OVERSHOOT).
  2. `FB_SimBench` : émettre le modèle si `DirectionCount >= 1` **OU** `ReturningActive`, sinon stimulus analogique brut.
- **⚠️ Validation requise** : humaine (à retester en simu).

## 9. ✅ Vérification de la correction

- **Preuve par test CI ad hoc** (`RESULTS/_TROUBLESHOOTING/tests/run.py`) : **4/4 PASS** (montée progressive, bagotement, overshoot, neutre).
- **Preuve par trace CODESYS** (`Suivi_Sim_20260822_2.trace`) : `JOY1Joystick.State.RawY` montre clairement le bagotement — dépassement (10000 → 4788, ~4% sous le neutre), oscillations (4944→4788→4968→5073→5094→5042→4984→4958→4973→4999→5017→5016→5006→4995→4992→4995), stabilisation à 5000.
- **Symptôme résolu** : le bagotement se déclenche en CODESYS réel. Rien d'autre cassé.

## 10. 📝 Journal (chronologique)

- 2026-08-22 : ouverture fiche. Symptôme = bagotement ne se déclenche pas. Hypothèses H1-H5.
- 2026-08-22 : délégation de l'analyse statique de la chaîne de déclenchement (§4/§6/§7 + câblage) à un sous-agent.
- 2026-08-22 : **verdict sous-agent** — cause racine = gating de sortie `FB_SimBench` l.305-317 (émet neutre figé après relâchement). H1/H5 éliminées par preuve.
- 2026-08-22 : correction appliquée (sortie `ReturningActive` + gating `FB_SimBench`). Bundle régénéré.
- 2026-08-22 : **validation par test CI ad hoc** (4/4 PASS) puis **par trace CODESYS** (bagotement visible : dépassement + oscillations + stabilisation).
- 2026-08-22 : **CLÔTURÉE — RÉSOLUE**.

> 🧭 **Bilan méthode** : l'efficacité du dépannage a reposé sur la **combinaison** de 3 outils :
> 1. **Analyse statique déléguée** (sous-agent a tracé la chaîne) → cause racine identifiée sans exécuter le PLC.
> 2. **Test CI ad hoc** (`_TROUBLESHOOTING/`) → comportement prouvé automatiquement (4/4 PASS).
> 3. **Trace CODESYS** → confirmation en réel du bagotement.
> → Méthode **reproductible** et documentée dans la skill troubleshooting (§4ter + orientation).
