# 🕵️ Troubleshooting — Cycle ErrorID:08 / Translation P1

> 📅 2026-09-22 · 🧪 Situation rapportée : simulation · 📄 Statut : EN COURS

## 1. Contexte figé

- Rapport opérateur : `[CYCLE] ErrorID:08 - hors FDC haut translation P1`.
- M3 est à P1 ; benne non ouverte ; un léger mouvement est possible mais non considéré grave.
- Snapshot PLC : **non encore acquis**.

## 2. Fait code prouvé

`FB_CycleSemiAuto.st:506-510` pose le bit `16#0080` **seulement** si :

```text
State = AX2_TRANSLATE_P1
AND NOT CycleChecksInhibited
AND NOT WinchesAtTopWindow
```

Ce bit est formaté exactement par `FB_Hmi_BannerFormatter.st:1154-1155`.
La position/état de la benne n'est pas une condition de cette alarme.

## 3. Arbre de causes ouvert

```text
ErrorID:08
└─ AX2_TRANSLATE_P1 actif
   └─ WinchesAtTopWindow = FALSE
      ├─ M1 hors fenêtre haute (position / seuil / référencement)
      ├─ M2 hors fenêtre haute (position / seuil / référencement)
      ├─ un bref déplacement a sorti un axe de fenêtre
      └─ calcul de fenêtre/configuration incohérent
```

## 4. Acquisition unique demandée

Les variables nécessaires sont présentes à la fois dans `GVL_Troubleshooting` et dans
`troubleshooting_variables.txt`. Demander un unique CSV via le snapshot standard,
pendant ou juste après l'erreur :

- `G_CycleSemiAuto.Idx204..206, Idx208, Idx217..219`
- `H_LevageSynchroniseM1M2.Idx101..103`
- `I_LevageUnitaireM1.Safety_300.Idx321..324`
- `J_LevageUnitaireM2.Safety_300.Idx321..324`
- `L_TranslationPontM3.Inputs_100.Idx104`

## 5. Conclusion provisoire

La cause logique de l'alarme est prouvée ; la cause terrain qui fait tomber
`WinchesAtTopWindow` reste à mesurer. Aucun code modifié, aucune variable forcée.

## 5bis. 📥 DÉPOUILLEMENT DU SNAPSHOT 05:49 (orchestrateur DSH01, 2026-09-22) — ACQUISITION NON CONCLUANTE

Le snapshot `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/snapshot/Snapshot_Troubleshooting_20260922_054918.csv`
(536/536 variables lues) a été dépouillé sur la liste exacte demandée au §4. **Verdict : le snapshot a été pris HORS épisode d'erreur** — l'acquisition demandée **reste donc PENDANTE**.

| Variable demandée | Valeur lue | Lecture |
|---|---|---|
| `G_CycleSemiAuto.Idx204_Error` | **FALSE** | aucune erreur cycle active |
| `G_CycleSemiAuto.Idx205_ErrorId` | **WORD#0** | aucun ErrorID courant → **le snapshot n'était pas pendant l'erreur** |
| `G_CycleSemiAuto.Idx217_FaultLatched` / `Idx218_FaultLatchedId` | **FALSE** / **WORD#0** | rien de latché non plus → **pas juste après non plus** |
| `G_CycleSemiAuto.Idx219_CycleChecksInhibited` | **FALSE** | inhibitions cycle inactives |
| `G_CycleSemiAuto.Idx206_Step` / `Idx208_StepAtError` | **AX0_REPOS** / **AX0_REPOS** | cycle au repos, aucune étape AX2 en cours |
| `L_TranslationPontM3.Inputs_100.Idx104_PosP1_DI` | **TRUE** | M3 **est bien à P1** (confirme le rapport opérateur) |

**ACTION POUR LE PORTEUR** : refaire **un seul** snapshot **pendant l'erreur** ou **immédiatement après son apparition** (avant tout Reset), avec la même liste.

### PISTE NOUVELLE, ISSUE DU MÊME SNAPSHOT (à instruire, non tranchée)

Les positions câble relevées sont **incohérentes avec le guide de homing** :

| Variable | Valeur | Référence machine |
|---|---|---|
| `H_LevageSynchroniseM1M2.Idx101_M1_CablePos_M` | **8,5 m** | = **capteur haut** (8,50 m) — cohérent |
| `H_LevageSynchroniseM1M2.Idx102_M2_CablePos_M` | **15,6723633 m** | **7,17 m AU-DESSUS du capteur haut** — incohérent (bas connu à −30 m : `I_/J_…Idx414_BottomLimitActiveM`) |
| `I_/J_…Safety_300.Idx323_TopLimitReached` / `Idx324_AscentBlockedByTopLimit` | **TRUE / TRUE** (M1 **et** M2) | les DEUX axes hors limite haute logicielle (7,5 m) |
| `K_BenneOuvertureFermeture.Idx114_MachineHomingStep` | **INT#60 = VALID** | le programme **se déclare référencé** malgré la position M2 impossible |
| `Idx115_MachineHomingFailed` / `Idx120_MachineHomingLossSafeStop` / `G_CycleSemiAuto.Idx106_HomedM1M2` | FALSE / FALSE / **TRUE** | aucune perte de datum signalée |

➡️ **Hypothèse de travail** : l'anomalie de position M2 explique **le même symptôme par deux chemins** — d'une part l'écart M1/M2 de 7,17 m, d'autre part `WinchesAtTopWindow = FALSE` (cause de l'`ErrorID:08`). **Deux origines possibles, à trancher** : artefact du banc de simulation (positions intégrées par le modèle) **ou** perte/écart de datum réelle. **Il manque un garde de plausibilité** : rien ne refuse `MachineHomingStep = VALID` avec une position au-delà du capteur haut physique.

## 6. Journal

- 2026-09-22 : symptôme rapporté ; traçage inverse lancé par CDX01, analyse statique déléguée.
- 2026-09-22 (orchestrateur DSH01) : snapshot 05:49 dépouillé → **hors épisode**, acquisition à refaire ; piste « position M2 à +15,67 m » ouverte et reliée à `WinchesAtTopWindow`.
