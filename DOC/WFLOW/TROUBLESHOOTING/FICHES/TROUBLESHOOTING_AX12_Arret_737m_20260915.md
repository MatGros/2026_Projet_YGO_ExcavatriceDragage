# 🕵️ Session de Troubleshooting — AX12 : arrêt de montée vers 7,37 m

> 📅 2026-09-15 · 🧊 Situation : SIMULATION BANC · 📄 Statut : CAUSE CONFIRMÉE, CORRECTION À VALIDER

## 1. 🧊 Contexte figé

Snapshot 11:19:50, cycle SEMI_AUTO, machine homed, AX12, joystick montée maintenu, aucune alarme.

| Élément | Variable | Valeur |
|---|---|---:|
| Étape | `G_CycleSemiAuto.Idx206_Step` | `AX12_LOADED_ASCENT` |
| M1 position | `H_LevageSynchroniseM1M2.Idx101_M1_CablePos_M` | 7,3671875 m |
| M2 position brute | `H_LevageSynchroniseM1M2.Idx102_M2_CablePos_M` | 21,64087 m |
| Offset actif benne | `K_BenneOuvertureFermeture.Idx103_OffsetPos_M` | 15 m |
| Écart sync corrigé | `H_LevageSynchroniseM1M2.Idx103_SyncDelta_M` | 0,726318359 m |
| M1 zone haute / palier | `I_LevageUnitaireM1.Control_400.Idx412/402` | TRUE / P1 |
| M2 zone haute / palier | `J_LevageUnitaireM2.Control_400.Idx412/402` | FALSE / P5 |
| Demande Both | `I/J_LevageUnitaire*.Demandes_200.Idx211` | TRUE / TRUE |
| Alarmes cycle / SafeStop | `G_CycleSemiAuto.Idx204` / `I/J...Idx302` | FALSE / FALSE |

Source : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/snapshot/Snapshot_Troubleshooting_20260915_111950.csv`.

## 2. 🎯 Symptôme

En AX12, la montée Both s'interrompt vers M1=7,37 m sans alarme ni passage AX13 ; un nouvel appui
permet un déplacement supplémentaire.

## 3. 🧩 Indices

- AX12 reste actif et continue de demander la montée.
- Aucun permis de montée ni SafeStop n'est tombé dans le snapshot.
- M1 est déjà dans sa zone de ralentissement haute ; M2 corrigé est encore hors zone.
- Les champs troubleshooting M2 `Idx323/324` sont trompeurs : ils comparent M2 brut à H sans offset,
  contrairement au calcul effectif du programme.

## 4. 🌳 Arbre des causes

| # | Hypothèse | Preuve | Verdict |
|---|---|---|---|
| 1 | FDC physique actif | `M1M2_TopPositionFree_DI=TRUE` | ❌ |
| 2 | SafeStop ou défaut cycle | tous faux, ErrorId=0 | ❌ |
| 3 | Joystick / demande absente | demandes Both et 100 % actives | ❌ |
| 4 | FDC logiciel M1 atteint | M1=7,367 < 7,5 m | ❌ |
| 5 | Discordance de palier en Both | M1=P1, M2=P5 ; égalité finale stricte | ✅ |
| 6 | Effet exclusif SimBench | logique dans `FB_Winch`/`PRG_04` | ❌ |

## 5. 📊 Arbre vertical

```text
Both montée AX12 = TRUE
  ├─ M1 7,367 m ≥ 7,5-0,5 → InTopSlowdownZone=TRUE → P1
  ├─ M2 corrigé ≈ 6,641 m < 7,5-0,5 → InTopSlowdownZone=FALSE → P5
  └─ PRG_04 exige demandes finales identiques
       └─ P1 ≠ P5 → demandes physiques M1/M2 neutralisées
```

**Résumé** : `[Both=1] → [M1=P1, M2=P5] → [cohérence finale=0] → [sorties physiques=0]`.

## 6. 📊 Chronogramme rapporté

| Événement | AX12 | M1 | M2 | Résultat |
|:---:|:---:|:---:|:---:|:---:|
| Montée | actif | approche 7,37 m | retard corrigé ~0,73 m | mouvement |
| Zone haute M1 | actif | P1 | P5 | arrêt silencieux |
| Nouvel appui | actif | redémarrage bas palier | redémarrage bas palier | déplacement supplémentaire |

## 7. 🏁 Conclusion

- **Cause racine** : ralentissement calculé par axe alors que la barrière Both exige des paliers identiques.
- **Origine Git** : `f36c4480` introduit la barrière stricte ; `92601d2c` passe AX12 à P5 et crée le
  cas exact P1/P5. Verdict audit indépendant : **RÉGRESSION IDENTIFIÉE, confiance 95 %**.
- **Hors cause** : T291-A ne touche que la descente AX4..AX7 ; T292/T293 simulation n'ont pas modifié
  `PRG_04`, `FB_Winch` ni AX12. La mesure codeur n'a pas été régressée.
- **Portée** : logique commune simulation/réel ; la simulation n'est pas la cause exclusive.
- **Règle métier** : en M1 seul/Both, M1 pilote l'approche et l'arrêt nominal ; M2 suit. M2 corrigé
  conserve les protections indépendantes H+1 SafeStop et H+2 PowerCutOff.

## 8. 🛠️ Proposition

- **Immédiat** : ne pas valider la remontée machine AX12 comme sûre sur la seule preuve simulation.
- **Définitif** : traiter T291-B avec profil commun piloté par M1 en Both, protections M2 corrigées
  indépendantes, et diagnostic de la barrière finale.
- ⚠️ Validation humaine du plan C4 obligatoire avant code.

## 9. ✅ Non-régression attendue

Tester M1 seul, M2 seul, Both avec écart, offsets ouvert/fermé, seuils H/H+1/H+2, capteur TOP,
descente de dégagement et absence de redémarrage automatique.

## 10. 📝 Journal

- 2026-09-15 11:19:50 : snapshot 528/528 acquis.
- 2026-09-15 11:34 : diagnostic confirmé par snapshot et traçage inverse ST ; aucun code modifié.
- 2026-09-15 11:50 : audit Git indépendant ; régression f36c4480 + 92601d2c confirmée à 95 %.
