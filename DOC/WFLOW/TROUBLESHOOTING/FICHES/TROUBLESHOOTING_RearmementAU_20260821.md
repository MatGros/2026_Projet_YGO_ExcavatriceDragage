# 🕵️ Session de Troubleshooting — Impossibilité de réarmer l'AU (puissance) — Meca latched

> 📌 `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_RearmementAU_20260821.md`
> 📅 Date : 2026-08-21 · 🧊 Situation : [SIMULATION BANC] · 📄 Statut : [OUVERTE]

## 1. 🧊 Contexte figé (horodaté)
- Snapshot : `Snapshot_Troubleshooting_20260821_003351.csv` (2026-08-21 00:33)
- Simulation active (`SimulationModeActive=TRUE`, `SimSafetyActive=TRUE`). Mode machine : **DISABLE**.
- Référencement M1/M2 : **fait** (`HomingHomed=TRUE`).
- Joystick : comm OK, neutre, deadman non armé.

### Variables & valeurs (snapshot)
| Élément | Variable | Valeur |
|---|---|---|
| Mode | Contexte.Idx101_ModeActive | `E_Mode.DISABLE` |
| AU | Safety.HwIn_PowerContactorEngaged_DI | FALSE |
| AU | Safety.PowerContactorEngaged | FALSE |
| AU | Safety.ArmingStep | 0 (IDLE) |
| AU | Safety.ArmingPulseActive | FALSE |
| AU | Safety.AllConditionsMet | FALSE |
| AU | Safety.MaintainAActive / MaintainBActive | TRUE / TRUE |
| AU | Safety.Step5_ArmingAllowed | TRUE |
| AU | Safety.PowerCutOffActive / Request | FALSE / FALSE |
| AU | Safety.SafetyError | FALSE |
| M1 | LevageUnitaireM1.Safety_300.Idx313_ErrorMecaA | **TRUE** |
| M2 | LevageUnitaireM2.Safety_300.Idx313_ErrorMecaA | **TRUE** |
| M1/M2 | Idx302_SafeStopActive | TRUE |
| M3 | TranslationPontM3.Safety_300.*Error* | tous FALSE |

## 2. 🎯 Symptôme
Impossible de **réarmer l'AU / la puissance** : le contacteur et la chaîne AU **clignotent**, l'utilisateur « a du mal à acquitter/réarmer ». Mode DISABLE, Meca latched sur M1 ET M2.

## 3. 🧩 Indices / historique
- Changements récents : migration T137 (16 FB → `ST_FbStatus`) + correctif sim M3 (PRG_02) — non commités. (⚠️ cause n°1 = régression → à garder en tête.)
- Déjà essayé : tentative de réarmement AU (front bouton réarmement), sans succès.
- Condition : machine en DISABLE, MecaA latched M1+M2.
- Alarmes : MecaA (bit7) actif sur M1 et M2.

## 4. 🌳 Arbre des causes & hypothèses
> À compléter.

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | Réarmement AU bloqué par défaut safety (Meca) actif | `Safety.AllConditionsMet` | TRUE pour armer (FB_Safety_EmergencyManagement) | FALSE | 🔴 à analyser |
| 2 | Séquence d'armement AU ne démarre pas (front bouton manqué / gate) | `Safety.ArmingStep` | ≠0 en cours de réarmement | 0 | 🔴 à analyser |
| 3 | Défaut MecaA spurious (T143) pose la machine en défaut | `ErrorMecaA` | FALSE au repos | TRUE | 🔴 à analyser |
| 4 | Réintégration du front de réarmement (HMI→PLC) | `GVL_IHM.Modes.Cmd.BtnEmergencyArming` | front sur appui | ? | à lire |

## 5-10. À compléter au fil du diagnostic.
