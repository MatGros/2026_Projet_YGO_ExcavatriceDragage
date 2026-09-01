# 🕵️ Session de Troubleshooting — Blocage translation M3 en simulation

> 📌 **Emplacement** : `DOC/WFLOW/TROUBLESHOOTING/FICHES/`
> 📅 Date : 2026-09-01 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [OUVERTE]

## 1. 🧊 Contexte figé (horodaté)

### Texte de contexte
Utilisateur bloqué en simulation : **impossible de se déplacer en translation M3**,
que ce soit avec ou sans bypass, codeurs référencés ou non. Hypothèse utilisateur :
capteurs de décodage. À tracer sur toute la chaîne de commande M3.

### Variables & valeurs
| <nobr>Élément</nobr> | <nobr>Variable complète</nobr> | Valeur | <nobr>Horodatage</nobr> |
|---|---|---|---|
| (à compléter par snapshot) | ... | ... | ... |

## 2. 🎯 Symptôme
Impossible de se déplacer en translation M3 en simulation, avec ou sans bypass,
codeurs référencés ou non. Permanent.

## 3. 🧩 Indices / historique
- Derniers changements : plan permits M3 (T184/T204) + T214 stimuli boutons IHM.
- Déjà essayé : bypass on/off, codeurs référencés/non.
- Conditions : simulation.
- Alarmes : à déterminer.

## 4. 🌳 Arbre des causes & hypothèses
| # | <nobr>Hypothèse</nobr> | <nobr>Variable de décision</nobr> | <nobr>Valeur attendue (source)</nobr> | <nobr>Valeur lue</nobr> | Verdict |
|---|---|---|---|---|---|
| 1 | Gate permit M3 (TremiePermit/MaintenancePermit) bloque | `EffectivePermitM3_*` | TRUE si direction autorisée | ... | ❓ |
| 2 | SafeStop M3 actif | `TranslationSafety.SafeStop` | FALSE | ... | ❓ |
| 3 | PowerCutOff M3 | `TranslationFinalInterlockRequest.PowerCutOff` | FALSE | ... | ❓ |
| 4 | Interlock hauteur treuils (< 6m) | `M3_HeightInterlockOk` | TRUE | ... | ❓ |
| 5 | Arbitrage source (JoyMaster vs IHM) | `TglJoystickMaster` | cohérent avec la commande | ... | ❓ |
| 6 | Frein M3 ne relâche pas | `BrakeReleaseRequest` | TRUE | ... | ❓ |
| 7 | Capteurs de décodage / position | `M3_StatusWord`, `M3_ActualFrequencyHz` | ... | ... | ❓ |
| 8 | Simulation bypass non effectif | `SimulationBypassActive` | TRUE | ... | ❓ |

## 5. 📊 Arbre vertical des hypothèses (flux de données)
```text
Commande (joystick/IHM) → arbitrage M3 → permits → SafeStop/PowerCutOff → interlock hauteur
  → FB_Translation (rampe) → FB_TranslationOutputInterlock → sorties variateur M3
```
**Résumé une ligne** : à compléter après analyse.

## 6. 📊 Données / interactions & chronogramme
- (à compléter)

## 7. 🏁 Conclusion
- **Cause racine** : à déterminer.
- **Statut** : OUVERTE.

## 8. 🛠️ Proposition de correction
- (à compléter)

## 9. ✅ Vérification de la correction / non-régression
- (à compléter)

## 10. 📝 Journal (chronologique)
- 2026-09-01 : ouverture fiche, lancement analyse statique chaîne M3.

---

📖 Documentation : `GUIDE_Troubleshooting.md`
