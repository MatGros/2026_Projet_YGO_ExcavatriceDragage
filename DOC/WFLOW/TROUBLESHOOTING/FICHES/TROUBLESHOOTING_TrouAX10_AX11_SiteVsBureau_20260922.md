# 🕵️ Session de Troubleshooting — Trou AX10 → AX11 (site vs bureau)

> 📅 Date : 2026-09-22 · 🧊 Situation : **SITE MACHINE RÉELLE** (vs bureau = simulation) · 📄 Statut : EN COURS

## 1. 🧊 Contexte figé (horodaté)

> À confirmer à la reprise. Ne PAS re-demander ensuite.

- Situation : SITE (le trou AX10→AX11 **absent au bureau/banc**, présent en site).
- Symptôme décrit : « trou AX10 AX11 » — probablement la **retombée à zéro des commandes treuils M1/M2 à la transition fermeture benne → montée contrôlée** (phénomène déjà documenté en banc dans `TRACE62`).
- Référencement treuils : à confirmer.
- Mode machine : à confirmer (SEMI_AUTO a priori).

| Élément | Variable complète | Valeur | Horodatage |
|---|---|---|---|
| (à lire en snapshot) | ... | ... | ... |

## 2. 🎯 Symptôme

Trou / saut dans les commandes treuils entre les étapes **AX10** (fermeture benne) et **AX11** (montée contrôlée) en site ; ce trou **n'apparaissait pas au bureau** (banc / simulation). Permanent ou intermittent : à confirmer.

## 3. 🧩 Indices / historique

- Base saine du matin : commit `8ec1fa28` (variante `AX11_A_MATIN`) ; variante `AX11_B_MECA_B_APRES_MIDI` puis `AX11_C_HOMING_INHIBE`.
- Fiche antérieure : `TROUBLESHOOTING_AX10_AX11_AX12_TRACE62_20260919.md` (banc) — hypothèse **H2 (barrière d'atomicité)** très probable, non tranchée faute de variables tracées.
- Déjà essayé : à confirmer par l'utilisateur.
- Conditions d'apparition : à confirmer.
- Alarmes : à confirmer.

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | Barrière d'atomicité neutralise M1+M2 tant qu'ils ne sont pas prêts simultanément | `WinchBothMotionReady` / `DirectionChangePending` | TRUE avant transfert (PRG_04) | — | à vérifier |
| 2 | Étape `AX10B_RACCORDEMENT_P1` non atteinte → bascule brute AX10→AX11 | `CycleStep` / `CycleStateStr` | 22 avant 11 (FB_CycleSemiAuto) | — | à vérifier |
| 3 | Retour fermeture benne (`CloseReached`) retardé/instable en site | `FB_Bucket.CloseReached` / `BucketCloseReached` | stable ≥300 ms | — | à vérifier |
| 4 | Surveillance écart vitesse M1/M2 (AX11) déclenche en conditions réelles | `SpeedMismatchActive` / `FB_SyncDeviation` | FALSE | — | à vérifier |
| 5 | Configuration site ≠ banc (`CtrlAscentMaxStep`, `CtrlAscentDistanceM`) | `CfgCtrlAscentMaxStep` / `CfgCtrlAscentDistanceM` | borné [1..2] | — | à vérifier |

## 5. 📊 Arbre vertical des hypothèses (flux de données)

```text
(à compléter après lecture snapshot / analyse branches)
```

**Résumé une ligne** : _(à compléter)_

## 6. 📊 Données / interactions & chronogramme (🟡)

_(à compléter)_

## 7. 🏁 Conclusion

- **Cause racine** : _(à déterminer)_

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** : _(à compléter)_
- **Option 2 (définitif)** : _(à compléter)_
- **⚠️ Validation requise** : [humaine]

## 9. ✅ Vérification de la correction / non-régression

_(à compléter)_

## 10. 📝 Journal (chronologique)

- 2026-09-22 : ouverture fiche (site) ; lancement analyse statique parallèle des branches AX10→AX11 ; aucun code modifié.

---
