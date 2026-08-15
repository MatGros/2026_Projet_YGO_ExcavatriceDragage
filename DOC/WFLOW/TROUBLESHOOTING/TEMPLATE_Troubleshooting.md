# 🕵️ Session de Recherche de Blocage — <Sujet>

> 📅 Date : <AAAA-MM-JJ> · 🧊 Situation : [SIMULATION BANC] / [SITE]
> 📄 Statut : [OUVERTE] / [EN COURS] / [RÉSOLUE]

## 1. 🧊 Contexte figé

> ⚠️ L'agent NE re-pose PAS ces questions — il lit ce bloc. Toute valeur non listée = défaut (redémarrage).

| Élément | Valeur |
|---|---|
| SimulationModeActive | TRUE / FALSE |
| SimulationBypassActive | TRUE / FALSE |
| Référencement axes (homing) | fait / non fait |
| Mode machine | MAINT_N1 / MAINT_N2 / SEMI_AUTO / DISABLE |
| Redémarrage | chaud / froid / download |
| Autre | ... |

## 2. 🎯 Symptôme

<1 phrase : quoi, où, depuis quand, permanent/intermittent>

## 3. 🧩 Indices / historique

- Derniers changements (code, config, câblage, HMI) : ...
- Déjà essayé (et résultat) : ...
- Conditions d'apparition (mode, charge, position) : ...
- Alarmes / historique d'alarmes : ...

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | ... | `GVL_Troubleshooting.X` | TRUE | FALSE | ❌ éliminée |
| 2 | ... | ... | ... | ... | ✅ **cause** |

## 4bis. 📊 Diagramme de flux compact

> Vue d'un coup d'œil : chemin du signal, chaque nœud marqué **✓ (conforme)** ou **✗ (bloqué)**.
> Le **premier ✗** = cause racine ; les ✗ suivants = conséquences.
> Noms **condensés** — le nom complet n'apparaît que dans le reste du diagnostic.

### Légende
| Symbole | Sens |
|---|---|
| `[A ✓]` / `[A ✗]` | nœud conforme / bloqué |
| `→` | séquence (flux) |
| `OR` | branches parallèles (au moins une doit passer) |
| `[X=12.5]` | valeur numérique (entier/réel) — ✓/✗ selon la plage attendue |

### Exemples
- **Séquence** : `[StimRevDown ✓] → [RawY ✓] → [AtNeutral ✗] → [DeadmanArmed ✗]`
- **OR (branches)** : `([BtnOpen ✓] OR [CycleOpen ✓]) → [CmdOpen ✓]`
- **Numérique** : `[Pos=12.5] → [Mode=2] → [Speed=45%]`

## 5. 📊 Données / interactions

- <lectures, essais, résultats, chronologie>

## 6. 🏁 Conclusion

- **Cause racine** : ...
- **Correction** : ...
- **Statut** : RÉSOLUE / à valider

## 6bis. 🛠️ Proposition de correction

> ⚠️ À remplir **plus tard dans le diagnostic**, une fois la cause racine confirmée — pas avant.

- **Option 1 (immédiat, sans code)** : <action> — <impact/risque>
- **Option 2 (définitif)** : <action> — <impact/risque>
- **⚠️ Validation requise** : [humaine] — ne pas modifier le code / forcer une variable sans validation

## 7. 📝 Journal (chronologique)

- <AAAA-MM-JJ> : <action / observation>
