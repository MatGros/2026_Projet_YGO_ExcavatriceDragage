# 🎬 CAMPAGNE D'ESSAIS — 22/09/2026
## 🎯 Objectif unique : **1 CYCLE SANS BLOCAGE**

> 📄 Versionné : `DOC/WFLOW/TESTS/CAMPAGNE_20260922_CYCLE_SANS_BLOCAGE.md` · Orchestrateur : DSH01
> 🧰 Base : bundle **frais** à HEAD (rien à importer de plus) · ⏱️ Passe complète ≈ quelques minutes

---

## ⏱️ 0 — AVANT TOUT (5 min) : 6 cases à cocher

| ✅ | À vérifier | Où lire | Attendu |
|---|---|---|---|
| ☐ | **Mode** | bandeau / `Modes.State` | `SEMI_AUTO` |
| ☐ | **Homing** | `G_CycleSemiAuto.Idx106_HomedM1M2` | `TRUE` |
| ☐ | 🚨 **Fenêtre haute M1/M2** | `H_LevageSynchroniseM1M2.Idx101 / Idx102` | M1 ≈ 7 m · **M2 ≈ 7 m (PAS 15,67 !)** |
| ☐ | **AU armé** | `EmergencyState.ContactorOk` / `C_Safety.Step5_ArmingAllowed` | `TRUE` |
| ☐ | **Simu uniquement** | `GVL_Simulation.SimChainOk` | **écrire `TRUE`** sinon armement impossible |
| ☐ | **M3** | `L_TranslationPontM3.Inputs_100.Idx104_PosP1_DI` | `TRUE` à P1 |

⚠️ Si **M2 = 15,67 m** → **arrête-toi** : refais le homing M2 (MAINT_N2, `SelJoystickWinch=2`, `BtnHome`) **avant** de lancer un cycle.

---

## 🚀 1 — LE TEST : **UNE PASSE COMPLÈTE**

| Étape | Ce que tu regardes | Signe OK |
|---|---|---|
| `AX1_INIT` | conditions initiales | passe |
| `AX2` translation → P1 | `WinchesAtTopWindow`, pas de défaut | passe |
| `AX3` ouverture benne | benne s'ouvre | ouvre |
| `AX3_WAIT_DIVE_START` | arrêt mécanique confirmé | passe |
| `AX4…AX8` plongée | descente, Kobold, **fond confirmé** | descend, s'arrête |
| `AX9…AX12` extraction | fermeture + montée | remonte |
| `AX13` égouttage | tempo | passe |
| `AX14` → trémie | translation | passe |
| `AX15A/B` vidage | benne s'ouvre au-dessus de la trémie | vide |
| `AX18` | compteur +1, rebouclage `AX2` | **passe bouclée** |

### 🏁 SUCCÈS =
1. ✅ Atteindre **`AX18`**
2. ✅ `SampleCount` **+1**
3. ✅ **Aucun défaut latché** (`Idx217_FaultLatched = FALSE`, `Idx205_ErrorId = 0`)

---

## 🚨 2 — LES 5 PIÈGES (qui te feront croire que c'est cassé)

| Piège | Ce que tu vois | Ce que tu fais |
|---|---|---|
| 🧭 **M2 à +15,67 m** | `[CYCLE] ErrorID:08 - hors FDC haut translation P1` | homing M2 en N2 **avant** le cycle |
| ⚙️ **Benne auto** (toggle TRUE par défaut) | boutons manuels « both » **inertes**, sans message | désactiver `Commun.Cfg.TglEnableCoupledBucketSequencing` (pilotage manuel seulement) |
| 🧪 **Simulation** | impossible d'**armer** | `GVL_Simulation.SimChainOk := TRUE` (à refaire à chaque ré-entrée en sim) |
| 🕹️ **Sortie AX2** | bloqué en **AX2** alors que M3 est à P1 | maintien **Y- franc** (pas de diagonale) jusqu'au changement d'étape |
| 🧾 **CI** | cycle **non prouvé** (5 rouges + repli `AX_STAB`) | **ne conclus pas depuis la CI** — la preuve = ta passe |

---

## 🧾 3 — LES 3 LOTS À RECETTER **DANS LA MÊME PASSE** (zéro import en plus)

| Lot | Ce que tu vérifies pendant la passe | Signe OK |
|---|---|---|
| **T345-L2** *(AX14→AX15A, commit `b7b2c04b`)* | arrivée trémie **sans relâchement** exigé : 1 scan neutre puis push | arrivée **fluide**, pas de blocage |
| **T331** *(repli AX15B, commit `31c9db0d`)* | le geste **Y+** à AX15B → ⚠️ cf. §4 | **ne pas le déclencher** en essai nominal |
| **T295** *(timeout benne, commit `e011036b`)* | ouverture benne à AX15B **sans `[BENNE] ErrorID:03`** | pas d'erreur benne |

---

## 🚨 4 — LE DANGER À CONNAÎTRE (⚠️ le plus important)

```text
À AX15B :  Y+ maintenu  =  ✅ ferme la benne
                          ⛔ MAIS sort du vidage → AX10 → AX10B → AX11 → AX12 (montée en charge, palier 1)
```

- 🛑 **Sortie ALLER SIMPLE** : on ne revient au vidage qu'en **refaisant une passe**.
- ✅ **Pas de mouvement autonome** : j'ai vérifié — **chaque étape exige le geste** ; **relâcher = tout s'arrête**.
- 🎯 **Pour ta démo** : **ne tire PAS Y+ à AX15B** si tu ne veux pas quitter le vidage.
- 🛠️ Correctif (**désambiguïser** le geste + message) : **prêt à cadrer**, dis-moi GO.

---

## 📝 5 — RELEVÉ (remplis en marchant)

| # | Étape atteinte | Défaut ? (ErrorId) | Remarque / geste |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |

---

## 🧰 6 — SI ÇA BLOQUE

1. 🧊 **NE FAIS PAS DE RESET** avant d'avoir relevé — un Reset efface la preuve.
2. 📸 Snapshot **standard** (`run_tests`… non : `TOOLS/PLC_CSV_SNAPSHOT`) **pendant ou juste après** le blocage.
3. 🔎 Lecture rapide : `G_CycleSemiAuto.Idx206_Step` · `Idx205_ErrorId` · `Idx218_FaultLatchedId` · `H_LevageSynchroniseM1M2.Idx101-103`.
4. 📨 Envoie-moi le CSV → je dépouille et je te dis **quel** verrou a tenu.

> ⛔ **Rappel** : aucune modification de code n'est incluse dans cette campagne — tout est **déjà à HEAD**, bundle **frais**.
