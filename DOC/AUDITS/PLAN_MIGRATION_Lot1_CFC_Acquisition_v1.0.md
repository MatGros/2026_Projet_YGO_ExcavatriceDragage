# 📑 Plan de Migration & Spécification : Lot 1 — "CFC Acquisition & Bus Data Flow"

> 📌 **Statut** : Document de Cadrage et Plan de Migration Stratégique (Étape 1).
> 📅 **Date** : 30 Juillet 2026
> 🎯 **Objectif** : Valider la génération PLCopenXML du CFC, tester l'échange par structures (DUT) et migrer la couche **Acquisition E/S / Diagnostics Network** en **1 POU CFC autonome**, tout en garantissant la non-régression du reste du programme via la technique du doublement de fonctions (`_old`).

---

## 🧭 1. Objectifs & Périmètre du Lot 1 (Kick-off Migration)

```text
┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 STRATÉGIE DE MIGRATION SANS RISQUE                                │
├───────────────────────────────────────────────────────────────────────────────────────────────────┤
│  1. CONSERVATION DE L'EXISTANT  : Les programmes PRG_00_Inputs.st et PRG_01_Diagnostics.st sont  │
│                                  renommés temporairement PRG_00_Inputs_old.st et                  │
│                                  PRG_01_Diagnostics_old.st. Aucun code métier n'est détruit.     │
│                                                                                                   │
│  2. CRÉATION DU POU CFC DÉDIÉ   : Création d'un POU unique `PRG_00_Acquisition_CFC` (format CFC)    │
│                                  regroupant l'acquisition HwIn, les diagnostics CAN/EtherCAT,     │
│                                  et la qualification des 2 codeurs + Joystick.                    │
│                                                                                                   │
│  3. CRÉATION DES BUS ST_ (DUT)  : Injection des 3 premières structures de Bus de Données unifiées │
│                                  (`ST_HwIn_Bus`, `ST_Diag_NetworkBus`, `ST_Cmd_JoystickBus`).    │
│                                                                                                   │
│  4. VALIDATION AUTOMATIQUE      : Vérification du bundle XML par `generate_codesys_bundle.py`     │
│                                  et validation du câblage par `check_linkage.py`.                │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🧱 2. Nouveaux Bus de Données (DUTs) introduits au Lot 1

Afin d'éliminer le câblage fil à fil, 3 structures de bus standardisées sont créées :

### 🔌 A. `ST_HwIn_Bus` (Image d'Entrée Unifiée Réel ↔ Simulation)
Regroupe l'ensemble des bornes physiques filtrées et prêtes pour les blocs de sécurité :
- `EmergencyStopOk : BOOL` (Contacteur de puissance engagé)
- `EmergencyChain : BOOL` (Boucle physique d'arrêt d'urgence)
- `TopPositionSensor : BOOL` (Fin de course Haut commun M1/M2)
- `SlackCableSwitch : BOOL` (Mou de câble tambour M2)
- `PhaseRotationOk : BOOL` (Rotation des phases réseau)
- `BrakeThermalFeedback : BOOL` (Thermique frein commun M1/M2/M3)
- `SensorsWordM3 : WORD` (Mot des 5 capteurs position Translation M3)

### 📡 B. `ST_Diag_NetworkBus` (Diagnostic Réseau & Espions Bus)
Regroupe la santé des 4 nœuds de communication bus :
- `JoystickOnline : BOOL` (Nœud CANopen Joystick présent)
- `JoystickOperational : BOOL` (Nœud CANopen Joystick en mode Operational)
- `DriveM3Online : BOOL` (Esclave EtherCAT Variateur AC600 présent)
- `EncoderM1Online : BOOL` (Esclave EtherCAT Codeur COD1 présent)
- `EncoderM2Online : BOOL` (Esclave EtherCAT Codeur COD2 présent)
- `NetworkGlobalError : BOOL` (Synthèse défaut bus)

### 🕹️ C. `ST_Cmd_JoystickBus` (Consigne Conduite Qualification)
Regroupe le résultat du traitement du bloc `FB_Joystick` :
- `DeadmanArmed : BOOL` (Bouton homme-mort validé)
- `SpeedRefX_Pct : REAL` (Consigne axe X lissée et raccordée 0..100%)
- `SpeedRefY_Pct : REAL` (Consigne axe Y lissée et raccordée 0..100%)
- `JoystickFault : BOOL` (Anomalie signal analogique / déconnexion)

---

## 🎨 3. Structure du POU Graphique CFC : `PRG_00_Acquisition_CFC`

Ce programme CFC remplace avantageusement la séquence `PRG_00_Inputs` + `PRG_01_Diagnostics`.

```text
 ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │                                                    PROGRAM PRG_00_Acquisition_CFC (CFC)                                                        │
 ├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
 │                                                                                                                                                  │
 │   [ 1. FRONT RÉEEL / SIMULATION ]           [ 2. DIAGNOSTIC BUS CAN & ETHERCAT ]           [ 3. QUALIFICATION JOYSTICK & BUS OUTPUT ]      │
 │                                                                                                                                                  │
 │  ┌───────────────────────────────┐           ┌───────────────────────────────────┐           ┌──────────────────────────────────────┐    │
 │  │          instInputs           │           │          instDiagCanOpen          │           │             FB_Joystick_0            │    │
 │  │           (FB_Input)          │           │          (FB_DiagCanOpen)          │           │             (FB_Joystick)            │    │
 │  ├───────────────────────────────┤           ├───────────────────────────────────┤           ├──────────────────────────────────────┤    │
 │  │ HwReal (Bornier Hardware)     │           │ CANbusStateRaw [INT]              │           │ RawX, RawY, BtnDeadman               │    │
 │  │ HwSim  (Banc Virtuel)         │           │ DeviceJoystickStateRaw [DEV_STATE]│           │ Calibration & Deadband               │    │
 │  ├───────────────────────────────┤           ├───────────────────────────────────┤           ├──────────────────────────────────────┤    │
 │  │ HwInBus   [ST_HwIn_Bus]       ├──────────►│ JoystickOnline    [BOOL]          ├──────────►│ DeadmanArmed    [BOOL]               │    │
 │  └───────────────────────────────┘           │ JoystickOperational [BOOL]        │           │ SpeedRefX_Pct   [REAL]               │    │
 │                                              └─────────────────┬─────────────────┘           │ SpeedRefY_Pct   [REAL]               │    │
 │                                                                │                             │ CmdJoystickBus  [ST_Cmd_JoystickBus] ├──┐ │
 │                                                                │                             └──────────────────────────────────────┘  │ │
 │                                              ┌─────────────────┴─────────────────┐                                                     │ │
 │                                              │         instDiagEthercat          │                                                     │ │
 │                                              │        (FB_DiagEthercat)          │                                                     │ │
 │                                              ├───────────────────────────────────┤                                                     │ │
 │                                              │ DriveM3Online     [BOOL]          │                                                     │ │
 │                                              │ EncoderM1Online   [BOOL]          │                                                     │ │
 │                                              │ EncoderM2Online   [BOOL]          │                                                     │ │
 │                                              │ DiagNetworkBus    [ST_DiagNetwork]├───────────────────────────────────────────────────┐ │ │
 │                                              └───────────────────────────────────┘                                                   │ │ │
 ├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼─┼─┤
 │   [ PUBLICATION GLOBALE GVL_GLOBAL POUR CONSUMMATEURS (PRG_02..10) ]                                                                │ │ │
 │                                                                                                                                      │ │ │
 │   • GVL_Global.HwInBus         ◄─────────────────────────────────────────────────────────────────────────────────────────────────┼─┼─┘
 │   • GVL_Global.DiagNetworkBus  ◄─────────────────────────────────────────────────────────────────────────────────────────────────┼─┘
 │   • GVL_Global.CmdJoystickBus  ◄─────────────────────────────────────────────────────────────────────────────────────────────────┘
 └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 4. Plan de Séquencement de la Migration (Étapes Pas à Pas)

| Étape | Action Technologique | Fichiers Modifiés / Impactés | Mode de Vérification |
|---|---|---|---|
| **E1** | **Bascule `_old`** | Renommer `PRG_00_Inputs.st` ➔ `PRG_00_Inputs_old.st` et `PRG_01_Diagnostics.st` ➔ `PRG_01_Diagnostics_old.st`. | Le code originel reste disponible dans `CODE/MAIN/` pour comparaison direct. |
| **E2** | **Création des DUTs** | Création des types `ST_HwIn_Bus.st`, `ST_Diag_NetworkBus.st`, `ST_Cmd_JoystickBus.st` dans `CODE/COMMUN/_TYPES/`. | Test de syntaxe ST. |
| **E3** | **Génération du CFC XML** | Écriture du fichier `PRG_00_Acquisition_CFC.xml` dans `CODE/MAIN/`. | Exécution de `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` ➔ Valide le PLCopenXML. |
| **E4** | **Adaptation des consommateurs**| Mettre à jour `PRG_02_Encoders`, `PRG_03_Safety`, `PRG_06_WinchControl`, `PRG_07_TranslationControl` pour lire leurs entrées sur `GVL_Global.HwInBus` et `GVL_Global.CmdJoystickBus`. | Exécution de `python TOOLS/AGENT_WORKFLOW/scripts/check_linkage.py` ➔ Doit sortir **0 erreur de liaison**. |
| **E5** | **Comparatif Fonctionnel & Non-Régression** | Vérifier la conformité de `PRG_00_Acquisition_CFC` vs `DOC/AF_Partie-06_IO_Conditioning_v1.8.md` et `AF_Partie-08_Fonction_Joystick_v1.3.md`. | Exécution de `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py` (tous les gates au vert). |

---

## 🎯 5. Prochaine Étape Opérationnelle

Cette feuille de route Lot 1 permet de :
1. ✅ **Valider immédiatement** la génération et l'import du XML CFC dans CODESYS 3.5.
2. ✅ **Tester la performance** des Bus de Données DUTs sans toucher à la logique lourde des treuils ou de la sécurité.
3. ✅ **Conserver les fonctions `_old`** pour rassurer la maîtrise d'ouvrage et comparer visuellement à chaque étape.

Es-tu d'accord pour valider ce plan de migration Lot 1 et lancer la création du POU CFC `PRG_00_Acquisition_CFC` et de ses structures associées ?
