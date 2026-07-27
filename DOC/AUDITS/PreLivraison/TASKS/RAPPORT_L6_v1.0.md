# 📋 RAPPORT DE RÉALISATION — Lot L6 : Banc de Simulation Confiné `HwIn`

> 🤖 **Auteur** : Agent d'implémentation externe  
> 📅 **Date** : 2026-07-27  
> 🏷️ **Version** : v1.0  
> ⏱️ **Périmètre** : Lot L6 (Refonte `GVL_Simulation`, Création `FB_SimBench`, Aiguillage `PRG_00_Inputs` §0bis, Miroirs `PRG_09_Supervision` §4)

---

## 1. 🎯 Synthèse des travaux réalisés

Le lot L6 a été exécuté en conformité avec la fiche de tâche [`TASK_L6_Banc_Simulation_v1.0.md`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/DOC/AUDITS/PreLivraison/TASKS/TASK_L6_Banc_Simulation_v1.0.md) et les directives de sécurité de [`TASK_L2-L3_Retrait_GVL_PLC_Tests_v1.0.md`](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/DOC/AUDITS/PreLivraison/TASKS/TASK_L2-L3_Retrait_GVL_PLC_Tests_v1.0.md) :

1. **Refonte de `GVL_Simulation.st` (25 flags ──► 5 flags)** :
   - `SimulationModeActive` : Bit maître (défaut `FALSE`, polarité positive `TRUE = simulé`).
   - 4 flags de domaine : `SimWinchActive`, `SimTranslationActive`, `SimOperatorActive`, `SimMachineActive`.
   - Stimuli de banc (entrées de modèle) : `SimM3SensorsWordActive`, `SimM3SensorsWord`, `SimJoystickRawX/Y/Button`, `SimKoboldContactValue`, `SimEncoderSpeedFactor := 1.0` (remis à 1.0), `SimSyncDeviationInjectM1/M2`, `SimSyncDeviationOffset_M := 0.5`.
   - Supprimé : tous les anciens flags `*IsReal` (double négation).

2. **Création du bloc maître `FB_SimBench.st` (`CODE/SIMULATION/FB_SimBench.st`)** :
   - Interface pure sans lecture de variable globale (brique réduite Partie3 §1bis).
   - Composition des 4 modèles existants (`FB_Sim_Encoder`, `FB_Sim_Translation`, `FB_Sim_Joystick`, `FB_Sim_Safety`).
   - Génération des structures d'image matérielle simulées : `Winch`, `Translation`, `Operator`, `Machine` (`ST_HardwareImage`).

3. **Aiguillage dans `PRG_00_Inputs.st` §0bis** :
   - Instanciation unique `instSimBench`.
   - Remplacement de `HwIn := HwReal` par 4 instructions `IF` (affectation de structure complète par domaine).
   - Conservation intégrale du formatage monochrome et de la carte des blocages (L5).

4. **Ré-alimentation des miroirs IHM dans `PRG_09_Supervision.st` §4** :
   - Les 5 miroirs d'état de simulation IHM (`M1TreuilRetenue.Bypass.ContactorFeedback`, `M2TreuilBenne.Bypass.ContactorFeedback`, `TranslationM3.Bypass.ContactorFeedback`, `Commun.Bypass.SlackCable`, `Commun.Bypass.TopPositionSensor`) sont ré-alimentés avec la valeur effective `SimulationModeActive AND Sim<Domaine>Active`.

---

## 2. 🔌 Interface complète de `FB_SimBench`

```pascal
FUNCTION_BLOCK PUBLIC FB_SimBench
VAR_INPUT
    Enable                     : BOOL;             // GVL_Simulation.SimulationModeActive

    // Commandes issues du scan N-1
    M1_RelayFwd                : BOOL;
    M1_RelayRev                : BOOL;
    M1_SpeedRefPct             : REAL;
    M1_PresetTriggerCmd        : WORD;
    M1_PresetValueOut          : UDINT;
    M1_BrakeCmd                : BOOL;             // TRUE = desserrage commandé

    M2_RelayFwd                : BOOL;
    M2_RelayRev                : BOOL;
    M2_SpeedRefPct             : REAL;
    M2_PresetTriggerCmd        : WORD;
    M2_PresetValueOut          : UDINT;
    M2_BrakeCmd                : BOOL;             // TRUE = desserrage commandé

    M3_Direction               : INT;
    M3_SpeedRefPct             : REAL;
    M3_BrakeCmd                : BOOL;             // TRUE = desserrage commandé
    M3_TargetNum               : INT;

    PowerKeepAlive_A           : BOOL;
    PowerKeepAlive_B           : BOOL;
    EmergencyArming_RQ         : BOOL;

    // Stimuli
    SimEncoderSpeedFactor      : REAL := 1.0;
    SimSyncDeviationInjectM1   : BOOL := FALSE;
    SimSyncDeviationInjectM2   : BOOL := FALSE;
    SimSyncDeviationOffset_M   : REAL := 0.5;

    SimM3SensorsWordActive     : BOOL := FALSE;
    SimM3SensorsWord           : BYTE := 16#01;

    SimJoystickRawX            : INT := 5000;
    SimJoystickRawY            : INT := 5000;
    SimJoystickRawButton       : BOOL := FALSE;

    SimKoboldContactValue      : BOOL := FALSE;
    BtnEmergencyStop           : BOOL := FALSE;

    HwReal                     : ST_HardwareImage;
END_VAR
VAR_OUTPUT
    Winch                      : ST_HwWinch;
    Translation                : ST_HwTranslation;
    Operator                   : ST_HwOperator;
    Machine                    : ST_HwMachine;
END_VAR
VAR_IN_OUT
    RawPosM1                   : UDINT;
    RawPosM2                   : UDINT;
END_VAR
```

---

## 3. 🛡️ Polarités & Règles physiques des signaux simulés

| Signal Simulée dans `FB_SimBench` | Règle du modèle | Polarité / Convention physique |
|---|---|---|
| `Winch.M1_BrakeIsOpen_DI` | `:= M1_BrakeCmd` | **🔴 CRITIQUE (P1)** : 1 = Frein OUVERT. Inversion faite en aval par `PRG_00_Inputs.BrakeFeedbackInvertLogic`. |
| `Winch.M2_BrakeIsOpen_DI` | `:= M2_BrakeCmd` | **🔴 CRITIQUE (P1)** : 1 = Frein OUVERT. |
| `Translation.M3_BrakeIsOpen_DI` | `:= M3_BrakeCmd` | **🔴 CRITIQUE (P1)** : 1 = Frein OUVERT. |
| `Winch.M1_ContactorsReleased_DI` | `:= NOT M1_RelayFwd AND NOT M1_RelayRev` | 1 = Tous contacteurs retombés (état sain au repos). |
| `Winch.M2_ContactorsReleased_DI` | `:= NOT M2_RelayFwd AND NOT M2_RelayRev` | 1 = Tous contacteurs retombés (état sain au repos). |
| `Winch.M1M2_TopPositionFree_DI` | `:= TRUE` | 1 = Libérée (repos). |
| `Winch.M2_TensionedCable_DI` | `:= TRUE` | 1 = Câble tendu (NC). |
| `Machine.PowerContactorEngaged_DI` | Issue de `FB_Sim_Safety` (`SimContactorOk`) | 1 = Engagé suite impulsion `EmergencyArming_RQ` et maintien `PowerKeepAlive`. |
| `Machine.EmergencyChainClosed_DI` | Issue de `FB_Sim_Safety` (`SimChainOk`) | 1 = Boucle fermée (`PowerKeepAlive_A AND B AND NOT BtnEmergencyStop`). |
| `Translation.M3_Pos*` | Issue de `FB_Sim_Translation` (ou `SimM3SensorsWord`) | 1 = Capteur NO actionné. |

---

## 4. 🔍 Audits Statiques & Vérification de Conformité

1. **Audit de non-dispersion de `GVL_Simulation`** :
   - `GVL_Simulation` n'est accédée dans le code exécutable que dans :
     - `PRG_00_Inputs.st` (§0bis : pilotage de `instSimBench` et des 4 `IF` d'aiguillage).
     - `PRG_09_Supervision.st` (§4 : ré-alimentation des 5 miroirs IHM).
     - `PRG_11_Troubleshooting.st` (Lecture seule pour l'espion diagnostic).
   - **Vérification automatique (Script Python)** : `0` référence en dehors des fichiers autorisés.

2. **Audit d'absence de forçage hybride `OR (SimActive AND ...)`** :
   - **Vérification automatique (Script Python)** : `0` occurrence de motif type `OR (SimActive AND ...)`. Remplacement strictement en bloc par domaine dans `PRG_00_Inputs.st` §0bis.

3. **Validation Statique du Projet CODESYS (ST_PLCOPENXML_GENERATOR)** :
   - Analyseur statique exécuté : **133/133 objets analysés, 0 erreur**.
   - `CODE_Bundle.xml` généré avec succès.

---

## 5. 🚨 Devoir d'alerte — Points d'attention pour les essais

1. **Attente d'action Homme-Mort réel** :
   Le modèle `FB_Sim_Joystick` simule les signaux bruts. Même en mode `SimOperatorActive`, l'armement de la poignée homme-mort (`RawButton := TRUE`) reste requis pour autoriser le mouvement.
2. **Réarmement AU en Simulation** :
   L'activation de `SimMachineActive` simule le contacteur principal. Pour l'engager au boot en simulation, envoyer une impulsion sur `GVL_IHM.Modes.Cmd.BtnEmergencyArming`.
3. **SimEncoderSpeedFactor** :
   Remis à **1.0** dans `GVL_Simulation.st` (conforme P6).

---

## 6. ✅ Checklist des critères de sortie L6

- [x] `GVL_Simulation` refondue (1 bit maître + 4 domaines + stimuli, polarité positive)
- [x] 4 `IF` d'aiguillage dans `PRG_00_Inputs.st` §0bis, affectation de structure entière
- [x] Comportement si `SimulationModeActive = FALSE` strictly identique à L5
- [x] Modèle frein en convention physique (`:= BrakeCmd`, 0 inversion dans le modèle)
- [x] `FB_SimBench` brique réduite sans lecture de variables globales
- [x] `SimEncoderSpeedFactor := 1.0`
- [x] Aucun commit Git effectué
