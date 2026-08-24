# 🔎 Revue indépendante — Arbre FB de `PRG_02_Acquisition`

📅 2026-08-24 · 🤖 Sous-agent read-only (Expert Automatisme) · 🚫 Aucune modification de code

## 🎯 Périmètre

Revue exhaustive des 14 fichiers du call-tree de `CODE/M_MAIN/PRG_02_Acquisition.st` :
acquisition HwReal/HwSim/HwIn, joystick, diagnostics réseau (CANopen/EtherCAT), façade
codeurs M1/M2 (`FB_Encoder` + 6 sous-FB), décodage position translation M3.

## 📋 Fichiers lus et contrôlés (14/14)

| Fichier | Lignes |
|---|---|
| `CODE/M_MAIN/PRG_02_Acquisition.st` | 1-451 (complet) |
| `CODE/L_SIMULATION/FB_SimBench.st` | 1-350 (complet) |
| `CODE/D_JOYSTICK/FB_Joystick.st` | 1-242 (complet) |
| `CODE/C_DIAG_RESEAUX/FB_Diag_CanOpen.st` | 1-157 (complet) |
| `CODE/C_DIAG_RESEAUX/FB_Diag_Ethercat.st` | 1-231 (complet) |
| `CODE/E_CODEURS/FB_Encoder.st` | 1-198 (complet) |
| `CODE/E_CODEURS/FB_Encoder_Abs.st` | 1-163 (complet) |
| `CODE/E_CODEURS/FB_Encoder_Homing.st` | 1-245 (complet) |
| `CODE/E_CODEURS/FB_Encoder_Safety.st` | 1-106 (complet) |
| `CODE/E_CODEURS/FB_Encoder_Scale.st` | 1-41 (complet) |
| `CODE/E_CODEURS/FB_Encoder_SpeedMeasure.st` | 1-142 (complet) |
| `CODE/E_CODEURS/FB_Encoder_SpeedMonitor.st` | 1-124 (complet) |
| `CODE/E_CODEURS/FB_EncoderReliability.st` | 1-35 (complet) |
| `CODE/I_TRANSLATION/FB_Translation_PositionDecoder.st` | 1-118 (complet) |

Référentiels normatifs consultés : `CODE_QUALITY_STANDARDS.md`, `NAMING_CONVENTION.md`,
`AF_Partie-03_Contrats_Composants_v2.1.md`, `AF_Partie-08` (Joystick), `AF_Partie-09` (Encoder,
chapô + 6 fiches FB).

## ✅ Synthèse par fichier

| Fichier | Verdict | Findings |
|---|---|---|
| `FB_Joystick.st` | 🔴 BLOCK | Sécurité (ArmingPermit figé) + doc + region |
| `FB_Encoder_Homing.st` | 🔴 BLOCK | Sécurité (arrêt confirmé absent) + doc archi + doc migration |
| `FB_Encoder_Safety.st` | 🟠 MAJOR | Reset inerte, bit Fault non latché |
| `FB_Encoder_SpeedMonitor.st` | 🟠 MAJOR | `PowerContactorEngaged` réflexe injustifié + `Mode` mort |
| `PRG_02_Acquisition.st` | 🟠 MAJOR | Porte le câblage `ArmingPermit=TRUE` |
| `FB_Encoder.st` | 🟡 MINOR | Régions sans préfixe `§N` |
| `FB_Encoder_Abs.st` | 🟡 MINOR | Notes, non bloquant |
| `FB_Diag_CanOpen.st` | 🟡 MINOR | Reset quasi inerte |
| `FB_Diag_Ethercat.st` | 🟡 MINOR | Reset inerte + regroupement régions |
| `FB_EncoderReliability.st` | 🟢 PASS | — |
| `FB_Encoder_Scale.st` | 🟢 PASS | — |
| `FB_Encoder_SpeedMeasure.st` | 🟢 PASS | — |
| `FB_Translation_PositionDecoder.st` | 🟢 PASS | Bug préexistant cité (M3_SensorsWord), non nouveau |
| `FB_SimBench.st` | 🟢 PASS | — |

**Verdict global : 🔴 BLOCK** — 2 points de sécurité machine réelle non tranchés.

## 🚨 Points bloquants sécurité (à trancher par l'utilisateur)

### 1. Homme-mort joystick désarmé — `FB_Joystick.st` / `PRG_02_Acquisition.st:303`
`ArmingPermit := TRUE` câblé en dur (commentaire du code lui-même : « Câblage TEMPORAIRE »).
L'AF08 v2.0 décrivait un désarmement homme-mort sur changement de mode / fin de cycle benne
(`Mode`, `BenneBusy`, `PreserveArmingAfterBucket`) — ces entrées **n'existent plus** dans le FB.
**Conséquence potentielle : plus aucun désarmement automatique de l'homme-mort.**

### 2. Homing codeur sans vérification d'arrêt — `FB_Encoder_Homing.st`
`FwdRevSpeedFeedbackOff` et `BrakeFeedback` déclarés en entrée mais **jamais lus**. Le bit2
`ErrorId` (« Arrêt non confirmé », documenté et testé par `TC-P09-004`) **n'est jamais positionné**.
**Conséquence potentielle : homing possible sans garantie que contacteurs/frein soient au repos.**

## 📎 Signalements hors périmètre (devoir d'alerte, doc à mettre à jour)

1. `AF_Partie-08_Fonction_Joystick_v2.0.md` périmée vs `FB_Joystick.st` réel.
2. `AF_Partie-09 §4.2/§6` affirme une migration du homing vers `PRG_04_Treuils_Benne` « soldée » —
   le code place toujours le homing dans `FB_Encoder` (facade), appelé depuis `PRG_02`.
3. `FB_Encoder_Homing_v1.0.md §2/§3ter` documente une interface (`Mode`, `UnitaryMode`,
   `WinchSelected`) qui ne correspond plus au FB réel (remplacée par `HomingPermit`).

---
*Rapport intégral du sous-agent conservé dans la transcription de session — ce document en est
la synthèse actionnable.*
