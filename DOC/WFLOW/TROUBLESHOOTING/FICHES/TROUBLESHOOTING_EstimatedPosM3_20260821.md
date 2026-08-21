# 🕵️ Session de Troubleshooting — EstimatedPosM3_M bloquée + capteurs simulés figés

> 📌 **Emplacement** : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_EstimatedPosM3_20260821.md`
> 📅 Date : 2026-08-21 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [EN COURS]

## 1. 🧊 Contexte figé (horodaté)

### Texte de contexte
- Simulation active (banc). Mode MAINT, déplacement M3 (translation).
- `ActiveDirection` / `ActiveSpeedRef_Pct` évoluent correctement (consigne présente).
- `EstimatedPosM3_M` reste bloquée alors que le système indique que l'axe bouge.
- Les capteurs simulés ne suivent plus la position (avant, ils évoluaient avec le déplacement).

### Variables & valeurs
| <nobr>Élément</nobr> | <nobr>Variable complète</nobr> | Valeur | <nobr>Horodatage</nobr> |
|---|---|---|---|
| Position estimée | `GVL_IHM.TranslationM3.State.EstimatedPosM3_M` | bloquée | 2026-08-21 |
| Sens arbitré | `GVL_IHM.TranslationM3.State.ActiveDirection` | évolue | 2026-08-21 |
| Consigne vitesse | `GVL_IHM.TranslationM3.State.ActiveSpeedRef_Pct` | évolue | 2026-08-21 |

## 2. 🎯 Symptôme

En simulation, `EstimatedPosM3_M` reste bloquée alors que la consigne (`ActiveDirection`/`ActiveSpeedRef_Pct`) évolue ; les capteurs simulés ne suivent plus la position.

## 3. 🧩 Indices / historique

- Derniers changements : **commit `f09536d`** — fidélité sim M3 : le modèle sim est désormais alimenté par la **sortie réelle** (`RequestedDriveControlWord`/`RequestedDriveFreqHz`, post-interlock) au lieu de la commande brute (`M3_Direction_Active`/`M3_SpeedRef_Active`).
- Déjà essayé : —
- Conditions d'apparition : déplacement M3 en simulation.
- Alarmes : —

## 4. 🌳 Arbre des causes & hypothèses

| # | <nobr>Hypothèse</nobr> | <nobr>Variable de décision</nobr> | <nobr>Valeur attendue (source)</nobr> | <nobr>Valeur lue</nobr> | Verdict |
|---|---|---|---|---|---|
| 1 | Commande variateur bloquée (post-interlock) → modèle sim ne progresse pas | `GVL_Troubleshooting.TranslationPontM3.Control_400.Idx403_DriveControlWord` | ≠ 0 si mouvement (FB_Translation §5bis) | `WORD#0` | ✅ confirmé |
| 2 | SafeStop actif → rampe à 0 → pas de commande | `...Safety_300.Idx302_SafeStopActive` | FALSE | `FALSE` | ❌ éliminée |
| 3 | Interlock sortie bloque la commande | `...Control_400.Idx404_FinalInterlockState` / `Idx405_FinalInterlockReason` | READY / 0 | `READY` / `NONE` | ❌ éliminée |
| 4 | Erreur FB_Translation → commande coupée | `...Control_400.Idx401_MotionAllowed` / `Translation.State.Error` | TRUE / FALSE | `TRUE` | ❌ éliminée |
| 5 | Fin de course extrême atteinte | `...Safety_300.Idx304/305_LimitSwitchFwd/RevActive` | FALSE | `FALSE` | ❌ éliminée |
| 6 | **Interlock hauteur M1/M2** | `...Safety_300.Idx308_HeightInterlockBlocking` | FALSE | **`TRUE`** | ✅ **cause** |
| 7 | Fréquence réelle simulée nulle | `...Inputs_100.Idx106_DriveActualFreq_Hz` | > 0 si mouvement | `0` | ✅ conséquence |

**Sous-cause de #6** : `CablePosM1 = CablePosM2 = 244.099 m` > `PositionMaxM = 99.0` (FB_Encoder_Safety) → `EncoderIncoherent = TRUE` (bit0 "Bornes") → `M3_HeightInterlockOk = FALSE`. État sim résiduel : codeur sim M1/M2 à 244 m (raw `999830`), hors bornes physiques.

## 5. 📊 Arbre vertical des hypothèses (flux de données)

```text
CablePosM1/M2 = 244.099 m (sim, raw 999830)
   └─ FB_Encoder_Safety: 244 > PositionMaxM=99 → EncoderIncoherent=TRUE (bit0 Bornes) ❌
        └─ M3_HeightInterlockOk = FALSE (PRG_05 §0) ❌
             └─ HeightInterlockBlocking = TRUE ✅
                  └─ M3_StartStop_Active = FALSE
                       └─ RequestedDriveControlWord = 0 ✅
                            └─ Modèle sim M3_Direction=0 → capteurs figés + fréquence=0
                                 └─ EstimatedPosM3_M bloquée ✅
```

**Résumé une ligne** : `[CablePos=244>99] → [EncoderIncoherent=1] → [HeightInterlock=1] → [DriveControlWord=0] → [Sim figé] → [EstimatedPos bloquée] ❌`

## 6. 📊 Données / interactions & chronogramme (🟡)

### Lectures & essais
- (en attente des valeurs utilisateur)

## 7. 🏁 Conclusion

- **Cause racine** : le codeur sim M1/M2 est à **244 m** (raw `999830`), **hors bornes physiques [-99, +99]** → `FB_Encoder_Safety.EncoderIncoherent = TRUE` (bit0 "Bornes") → `M3_HeightInterlockOk = FALSE` → `HeightInterlockBlocking = TRUE` → `M3_StartStop_Active = FALSE` → `RequestedDriveControlWord = 0` → modèle sim M3 figé → **capteurs figés + EstimatedPosM3_M bloquée**.
- **Statut** : **RÉSOLUE** — cause racine confirmée + corrections appliquées (convention M3 inversée, sim démarre à la trémie, cohérence d'affichage).

## 8. 🛠️ Proposition de correction

> ✅ **Appliquée (plan validé par l'utilisateur, 4 concepts)** :
> 1. **Convention M3 inversée** (0 m=Trémie, 30 m=Maintenance) : `GVL_PERSISTENT._TranslationPosXxx_M` + `FB_Translation_PositionEstimator` (défauts, bornage, signe d'intégration).
> 2. **Sim M3 démarre à la trémie** (0 m) + distances non-linéaires : `FB_Sim_Translation` (PositionProgress en mètres, seuils 0/5/15/20/30).
> 3. **Cohérence d'affichage** : `PRG_05` gate `ActiveDirection`/`ActiveSpeedRef_Pct` par `RequestedDriveControlWord <> 0` (plus d'affichage "je bouge mais ça bouge pas").
> 4. **AF** : `AF_Partie-11` (convention) + fiche `FB_Sim_Translation`.
>
> ⚠️ **Non modifié** : treuils M1/M2 (décision utilisateur — le référencement perdu au démarrage est normal, homing manuel requis). L'interlock hauteur se lèvera après homing M1/M2.
> ⚠️ **Bug pré-existant corrigé au passage** : recalage estimateur au 1er scan partait de Maintenance (ordre IF/ELSIF) — garde `FirstScanDone`.

## 9. ✅ Vérification de la correction / non-régression

- Bundle régénéré : `CODE_XML/CODE_Bundle.xml` (176 objets, 0 erreur).
- G200 liaison : **PASS** (0 erreur, 1166 instances).
- Gates palier C : **15/15 PASS**.
- À vérifier en sim (hand-off humain) : après homing M1/M2, M3 translation doit bouger, les capteurs sim suivre la position, et `EstimatedPosM3_M` démarrer à 0 m (trémie) puis progresser vers 30 m (maintenance).

## 10. 📝 Journal (chronologique)

- 2026-08-21 : ouverture fiche. Hypothèse principale : commande variateur post-interlock bloquée (régression `f09536d`).
- 2026-08-21 : snapshot → `HeightInterlockBlocking=TRUE`, `DriveControlWord=0`. Cause racine : codeur sim M1/M2 à 244 m hors bornes.
- 2026-08-21 : plan 4 concepts validé (convention inversée + sim trémie + AF + cohérence d'affichage). Treuils non touchés.
- 2026-08-21 : corrections appliquées, bundle + gates verts (15/15). Fiche RÉSOLUE.
