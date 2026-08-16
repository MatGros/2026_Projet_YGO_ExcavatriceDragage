# 🕵️ Session de Troubleshooting — Non-référencé : descente treuils bloquée

> 📅 Date : 2026-08-16 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [EN COURS]

## 1. 🧊 Contexte figé (horodaté)

- Snapshot au repos : `Snapshot_Troubleshooting_20260816_204716.csv`
- Snapshot en commande : `Snapshot_Troubleshooting_20260816_223240.csv`
- Simulation sans HW · Mode `MAINT_N1` · `SimulationEnabled=TRUE`
- Non référencé : `HomingM1/M2.HomingHomed=FALSE` · `HomingDone=FALSE`
- Benne non référencée : `BenneOuvertureFermeture.StateIncoherent=TRUE` · `IsOpen=FALSE` · `IsClosed=FALSE`

### Variables & valeurs (snapshot commande)
| Élément | Variable complète | Valeur |
|---|---|---|
| Montée active M1 | `MotionM1.RelayFwdActive` | TRUE |
| Montée active M2 | `MotionM2.RelayFwdActive` | TRUE |
| Frein desserré | `CmdBrakeRelease_RQ` M1/M2 | TRUE |
| Position câble | `CablePos_M` M1/M2 | 244.5 → 246.6 m |
| Descente interdite | `ForbidDescentEffective` M1/M2 | TRUE |
| Dive actif | `AssistanceDragage.EnableDiveSearch` | TRUE |
| Benne ouverte | `BenneOuvertureFermeture.BucketIsOpen` | FALSE |
| Benne incohérente | `BenneOuvertureFermeture.StateIncoherent` | TRUE |
| Défaut benne | `BenneOuvertureFermeture.ErrorIdRaw` | WORD#10 (bit4 glissement M1, latched) |

## 2. 🎯 Symptôme

**Problème 1 (résolu)** : en simulation non référencé, descente bloquée par interlock Dive (benne non ouverte).

**Problème 2 (résolu)** : codeurs référencés, benne fermée, synchro activée → descente bloquée par interlock Dive, montée par limite haute. Pas de bug.

**Problème 3 (en cours, même contexte)** : **changement de mode** — passage MAINT_N1 → MAINT_N2 OK, mais demande du **mode 3 (SEMI_AUTO / automatique)** → **reste à MAINT_N1**. Le mode ne commute pas.

## 3. 🧩 Indices / historique

- Derniers changements : non référencé (pas de homing), benne non référencée (pas de ConfirmOpen/Close)
- Déjà essayé : commande joystick montée/descente
- Conditions : MAINT_N1, Dive search actif (`TglEnableDiveSearch`)
- Alarmes : `BucketFaultActive=TRUE`, `ErrorIdRaw=#10`

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | Aucune demande de mouvement | `ArbitratedSpeed_Pct` | >0 en commande | 100 (M1) | ❌ éliminée |
| 2 | Montée bloquée | `RelayFwdActive` | TRUE | TRUE | ❌ éliminée |
| 3 | **Descente bloquée par interlock Dive** | `DescendPermitDiveBucketOpen` | TRUE | FALSE | ✅ **cause** |
| 4 | Benne non référencée | `_BucketState.IsOpen` | TRUE | FALSE | ✅ **cause amont** |

## 5. 📊 Arbre vertical des hypothèses

```text
Commande descente (Direction=-1)
  → instDiveSearch.Enable = TRUE (TglEnableDiveSearch, MAINT_N1)  ✅
  → _BucketState.IsOpen = FALSE (benne non référencée)            ❌
  → DescendPermitDiveBucketOpen = FALSE                           ❌
  → DescendPermitM1/M2_Raw = FALSE                                ❌
  → ForbidDescentEffective = TRUE                                 ❌
  → RelayRev = FALSE → descente bloquée
```

**Résumé une ligne** : `[Dive=1] → [BucketIsOpen=0] → [DescendPermitDiveBucketOpen=0] ❌`

## 6. 📊 Données / interactions

- Montée : `RelayFwdActive=TRUE`, position 244.5→246.6 m → **mouvement réel confirmé**
- Descente : `ForbidDescentEffective=TRUE` → bloquée

## 7. 🏁 Conclusion

**Problème 1** : la descente est bloquée par l'interlock Dive (`DescendPermitDiveBucketOpen`), qui exige la benne **confirmée ouverte** (`_BucketState.IsOpen=TRUE`). Or la benne n'est pas référencée (`StateIncoherent=TRUE`, `IsOpen=FALSE`). ✅ Résolu (comportement normal).

**Problème 2** : codeurs référencés, benne référencée **fermée**, synchro activée. Commande descente → **bloquée par l'interlock Dive** (exige benne ouverte, or benne fermée). Montée → bloquée par **limite haute** (8.5m, normal). **Pas de bug** — comportement conforme. ✅ Cause confirmée par lecture.

**Amélioration IHM identifiée** : quand un mouvement est bloqué par un interlock, l'IHM doit afficher la **cause + l'action** (ex. « Ouvrir la benne ») — voir T118.
- **Statut** : RÉSOLUE (comportement normal, pas de bug). Amélioration IHM → T118.

## 8. 🛠️ Proposition de correction

- **Option 1 (immédiat, sans code)** : désactiver `TglEnableDiveSearch` (IHM) → lève l'interlock Dive, descente libre pour référencer.
- **Option 2 (immédiat, sans code)** : confirmer position benne ouverte (`BtnConfirmOpenPos`) → `IsOpen=TRUE` → descente autorisée.
- **Option 3 (définitif, IHM)** : afficher un voyant/animation « non référencé » clair (données `Homed` déjà disponibles dans `ST_EncoderHMI`).
- **Option 4 (définitif, sécurité)** : acquittement/validation IHM obligatoire quand non référencé (déplacement palier 1 sans fins de course).
- **⚠️ Validation requise** : [humaine] — ne pas modifier le code / forcer une variable sans validation.

## 9. ✅ Vérification de la correction / non-régression

- À compléter après validation.

## 10. 📝 Journal (chronologique)

- 2026-08-16 : ouverture session. Snapshot repos + commande analysés. Cause racine identifiée (interlock Dive + benne non référencée).
- 2026-08-16 : **Problème 2** — codeurs référencés, défauts acquittés, synchro activée, mais aucun mouvement montée/descente malgré Deadman armé et permits OK. En cours d'analyse.
- 2026-08-16 : **Problème 2 résolu** — pas de bug. Descente bloquée par interlock Dive (benne fermée), montée bloquée par limite haute (8.5m). Amélioration IHM (cause + action) → T118.
- 2026-08-16 : **Problème 3** — changement de mode MAINT_N1→N2 OK, mais demande mode 3 (SEMI_AUTO) → reste à MAINT_N1. En cours d'analyse.
