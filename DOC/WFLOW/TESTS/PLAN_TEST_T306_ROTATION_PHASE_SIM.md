# 🧪 PLAN DE TEST — T306 ROTATION DE PHASE (SIMULATION)
## ⚡ Objectif : prouver qu'un défaut de rotation de phase ARRÊTE la machine de façon sûre et VERROUILLÉE

> 📅 2026-09-22 · 🏷️ DSH01 · 🧩 Lot testé : **T306 phase 1** (contrat `TASK_CONTRACT_T306_PHASE1_INJECTION_SIM.yaml`, C2)
> ⚠️ **Nom du stimulus** : `GVL_Simulation.SimPhaseRotationOk` — *à confirmer sur le diff réel à la réception du lot (je te le valide avant l'import)*

---

## 🧩 0 — AVANT DE COMMENCER (3 pré-requis, sinon le test ne prouve rien)

| ✅ | Pré-requis | Où |
|---|---|---|
| ☐ | **Mode simulation actif** | `GVL_Simulation.SimulationModeActive = TRUE` |
| ☐ | **Simulation sécurité active** | `GVL_Simulation.SimSafetyActive = TRUE` ← *sans ceci, l'image machine n'est **pas** simulée* (`PRG_02_Acquisition.st:138`) |
| ☐ | **L'import est fait** | diff bundle : `FB_SimBench`, `FB_Sim_Safety`, `GVL_Simulation` |
| ☐ | **État de référence sain** | `PhaseRotationOk_DI = TRUE`, `PhaseRotationFault = FALSE`, aucun défaut actif |

---

## ⚡ 1 — L'INJECTION (le nouveau bouton)

```text
GVL_Simulation.SimPhaseRotationOk  :=  FALSE        (défaut TRUE = phases saines)
```

**Attendu immédiatement :**

| Ce qu'on lit | Valeur attendue |
|---|---|
| `PRG_02_Acquisition.HwIn.Machine.PhaseRotationOk_DI` | **FALSE** |
| `GVL_IHM.Commun.PhaseRotationFault` | **TRUE** |

⛔ **Si ces 2 valeurs ne bougent pas** → l'injection n'est pas câblée : arrête là et dis-le-moi (c'est **le** point à prouver).

---

## 🎯 2 — LES 6 VÉRIFICATIONS (dans l'ordre, ~2 min)

| # | Quoi vérifier | Où lire | Attendu |
|---|---|---|---|
| **1** | Défaut treuil **M1** | `GVL_Troubleshooting.I_LevageUnitaireM1.Safety_300.Idx312_ErrorPhaseRotation` | **TRUE** |
| **2** | Défaut treuil **M2** | `GVL_Troubleshooting.J_LevageUnitaireM2.Safety_300.Idx312_ErrorPhaseRotation` | **TRUE** |
| **3** | Défaut translation **M3** | `GVL_Troubleshooting.L_TranslationPontM3.Safety_300.Idx311_ErrorPhaseRotation` | **TRUE** |
| **4** | **Bandeau IHM** | affichage | **`[M1] ErrorID:05 - rotation phases`** · **`[M2] ErrorID:05`** · **`[M3] ErrorID:03`** |
| **5** | **Sorties coupées** (le plus important) | `M1RelayFwd` · `M1SpeedContactor1..4` · **`M1BrakeCmd`** (idem M2) · sorties M3 | **tous à FALSE** ⇒ *freins serrés par manque de tension* |
| **6** | **Préflight** (si tu le lances) | `PreflightErrorId` | bit **`16#0100`** posé ⇒ passage en production **interdit** |

🎯 **Test bonus décisif** : commande un **mouvement** (montée ou descente) pendant le défaut → **aucun mouvement ne doit être possible** : ni `RunRequest`, ni relais, ni contacteur, ni frein desserré.

---

## 🔒 3 — LE VERROU (le test le plus important de la session)

```text
a) Remettre le stimulus à TRUE   →  GVL_Simulation.SimPhaseRotationOk := TRUE
   ATTENDU : les defauts RESTENT presents (Idx312/Idx311 toujours TRUE),
             les axes RESTENT bloques, AUCUN redemarrage automatique.
             (Un latche qui tombe tout seul = DEFAUT DE SECURITE)

b) Acquitter par le bouton IHM (FaultMachineReset_IHM) — appui = FRONT
   ATTENDU : le front acquitte, retour a l'etat sain (Idx312/Idx311 -> FALSE).
   ATTENDU AUSSI : un Reset HORS front (maintien) ne doit RIEN faire.

c) Variante severe : re-injecter la faute (FALSE) PUIS appuyer Reset
   ATTENDU : re-verrouillage IMMEDIAT au meme scan — l'acquittement ne doit
             jamais masquer une cause encore presente.
```

---

## 🚨 4 — CE QUI SERAIT UN ÉCHEC (à me remonter tel quel, sans corriger)

| Symptôme | Gravité |
|---|---|
| Un **mouvement possible** malgré le défaut (relais/contacteur à 1, `BrakeCmd` à 1) | 🔴 **C4 — arrête les essais** |
| **Réarmement automatique** après disparition de la faute (sans Reset) | 🔴 **C4** |
| Un **Reset acquitte** alors que la faute est **encore présente** | 🔴 **C4** |
| Pas de **message IHM** (bandeau vide) malgré le défaut | 🟠 majeur |
| L'injection **ne bouge pas** `PhaseRotationOk_DI` | 🟠 le lot n'est pas câblé |

---

## 📝 5 — RELEVÉ (remplis en marchant)

| # | Test | Valeur lue | Attendu ? | Remarque |
|---|---|---|---|---|
| 1 | M1 défaut | | ☐ | |
| 2 | M2 défaut | | ☐ | |
| 3 | M3 défaut | | ☐ | |
| 4 | Bandeau | | ☐ | |
| 5 | Sorties coupées | | ☐ | |
| 6 | Verrou sans Reset | | ☐ | |
| 7 | Reset sur front | | ☐ | |
| 8 | Re-verrouillage si faute présente | | ☐ | |

---

## 🧰 6 — SI ÇA BLOQUE

1. 🧊 **NE FAIS PAS DE RESET** avant d'avoir relevé (un Reset efface la preuve).
2. 📸 Snapshot **pendant / juste après** le blocage.
3. 📨 Envoie-moi le CSV → je dépouille et je te dis **quelle** cause a tenu.

---

## ⏭️ 7 — BONUS (si ta session dure encore : 10-15 min)

📄 **Fiche campagne** : `DOC/WFLOW/TESTS/CAMPAGNE_20260922_CYCLE_SANS_BLOCAGE.md`
- **1 pas complet** du cycle (`AX1_INIT → AX18`) — l'objectif « 1 cycle sans blocage ».
- 🎯 Rappel des 2 pièges : **`M2 ≈ 15,67 m` → `ErrorID:08`** (homing M2 d'abord) · **ne pas tirer Y+ à AX15B** (sortie du vidage vers `AX10`).

> ⛔ **Ce plan teste un lot NON ENCORE ACCEPTÉ** (challenge + revue indépendante à suivre). Si un comportement te paraît anormal, ce n'est pas forcément ton erreur : **remonte-le**.
