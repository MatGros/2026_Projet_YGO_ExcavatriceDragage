# 🕵️ Session de Troubleshooting — Référencement treuils/benne en MAINT_N2 → cutoff / crash

> 📌 **Emplacement** : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_ReferencementCutoff_20260820.md`
> 📅 Date : 2026-08-20 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [EN COURS]

## 1. 🧊 Contexte figé (horodaté)

### Texte de contexte
- Depuis le **commit #3** (`23d1671`, migration PRG_06 en ST + renommage FB interlocks), en **MAINT_N2**, le référencement codeur/benne déclenchait un **défaut + coupure puissance**.
- **Observation récente** : le référencement fonctionne maintenant (intermittent), mais **« refe benne fermée » replante** (crash/reboot PLC).
- **`GVL_Simulation.SimulationBypassActive = 1` n'active pas les bypass**.
- **PRG_06_Outputs.st ne respecte pas les standards** (régions `{region}` absentes).

### Variables & valeurs
| Élément | Variable complète | Valeur | Horodatage |
|---|---|---|---|
| Simulation mode | `GVL_Simulation.SimulationModeActive` | à vérifier | 2026-08-20 |
| Sim winch | `GVL_Simulation.SimWinchActive` | à vérifier | 2026-08-20 |
| Bypass simu | `GVL_Simulation.SimulationBypassActive` | 1 (forcé) | 2026-08-20 |
| Bypass bus | `PRG_02_Acquisition.Data.SimulationBypassActive` | à vérifier | 2026-08-20 |

## 2. 🎯 Symptôme
Référencement codeur/benne en MAINT_N2 → défaut + coupure puissance (intermittent) ; « refe benne fermée » → crash/reboot PLC. `SimulationBypassActive` n'active pas les bypass.

## 3. 🧩 Indices / historique
- Derniers changements : commit #3 (PRG_06 ST + FB rename), P2/P3/P4 (bus Data).
- Déjà essayé : référencement simple fonctionne maintenant ; benne fermée replante.
- Conditions : MAINT_N2, simulation, référencement.
- Alarmes : défaut + coupure puissance.

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | Bypass non actif → safety non bypassée → cutoff | `Data.SimulationBypassActive` | TRUE si 3 flags (GVL_Simulation l.7-8) | à vérifier | ❓ |
| 2 | PowerCutOffReq agrégation ST ≠ oracle | `PowerCutOffReq` | M1 OR M2 OR M3 (oracle) | M1 OR M2 OR M3 | ✅ (confirmé) |
| 3 | FB rename a cassé un lien | `instWinchOutputInterlockM1` | présent | présent | ✅ (confirmé) |
| 4 | Crash benne fermée = watchdog/mémoire | — | — | — | ❓ |

## 5. 📊 Arbre vertical des hypothèses

```text
[SimulationBypassActive=1] → [SimulationModeActive=?] → [SimWinchActive=?] → [Data.SimulationBypassActive=?] ❓
```

**Résumé** : `[SimBypass=1] → [SimMode=?] → [SimWinch=?] → [Data.SimBypass=?] ❓`

## 6. 📊 Données / interactions & chronogramme (🟡)

### Lectures & essais
- Référencement simple : fonctionne maintenant (intermittent).
- Refe benne fermée : replante (crash).

## 7. 🏁 Conclusion
- **Cause racine** : à déterminer (en cours).

## 8. 🛠️ Proposition de correction
- **Option 1 (immédiat, sans code)** : vérifier l'état des 3 flags simulation (SimulationModeActive, SimWinchActive, SimulationBypassActive) + `Data.SimulationBypassActive`.
- **Option 2 (définitif)** : à déterminer.
- **⚠️ Validation requise** : [humaine] — ne pas modifier le code sans validation.

## 9. ✅ Vérification de la correction / non-régression
- À faire après correction.

## 10. 📝 Journal (chronologique)
- 2026-08-20 : ouverture fiche. Observations : cutoff intermittent, crash benne fermée, SimulationBypassActive n'active pas les bypass, PRG_06 sans régions.
