# 📐 Spécification Fondamentale d'Architecture & Matrice Générale des Bus (DUT)

> 📌 **Statut** : Document de Cadre Architectural Définitif (Migration CFC & Architecture Bus).
> 📅 **Date** : 30 Juillet 2026
> 🎯 **Objectif** : Éliminer tout tâtonnement et définir **la matrice globale et complète de TOUS les bus d'échange** requis pour l'automate. Tout POU CFC (à commencer par le Lot 1 `PRG_00_Acquisition_CFC`) est conçu dès le premier jour avec **l'intégralité de ses connecteurs de bus**, prêts à alimenter la suite de la migration.

---

## 🧭 1. Les 4 Niveaux de Responsabilités de l'Automate

Pour éviter le mélange entre l'Acquisition, la Sécurité, le Contrôle et les Sorties, l'automate est structuré en **4 Niveaux d'Abstraction stricts** :

```text
 ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ LEVEL 0 : ACQUISITION & QUALIFICATION MATÉRIELLE (`PRG_00_Acquisition_CFC`)                            │
 │  • Acquisition Bornier Physique (HwReal), Banc Virtuel (HwSim) ➔ Produit HwInBus                       │
 │  • Diagnostic des bus (CANopen, EtherCAT) ➔ Produit DiagNetworkBus                                     │
 │  • Qualification du Joystick & Homme-Mort ➔ Produit CmdJoystickBus                                     │
 └────────────────────────────────────┬────────────────────────────────────────────────────────────────────┘
                                      │ (Diffusé via GVL_Global aux Bus Généraux)
                                      ▼
 ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ LEVEL 1 : CHAPEAU DE SÉCURITÉ & SURVEILLANCE MÉCANIQUE (`FB_Safety_*`)                                  │
 │  • Reçoit : HwInBus, DiagNetworkBus, CmdModesBus, Positions Codeurs                                    │
 │  • Calcule : Les verrous de sécurité (SafeStop, ForbidAscent, ForbidDescent, PowerCutOff)               │
 │  • Produit : SafetyWinchM1Bus, SafetyWinchM2Bus, SafetyTranslationBus                                  │
 └────────────────────────────────────┬────────────────────────────────────────────────────────────────────┘
                                      │ (Délivre les verrous de sécurité)
                                      ▼
 ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ LEVEL 2 : ARBITRAGE, SYNCHRO & ACTIONNEURS MÉTIERS (`FB_Winch`, `FB_Translation`, `FB_Cycle`)           │
 │  • Reçoit à GAUCHE  : Consignes arbitrées (CmdJoystickBus / CmdAutoBus / CmdModesBus)                    │
 │  • Reçoit en HAUT   : Verrous de sécurité (SafetyWinchM1Bus, SafetyWinchM2Bus, SafetyTranslationBus)    │
 │  • Traitement      : Synchro M1/M2 (`FB_WinchSync`), Benne (`FB_Bucket`), Rampes Hz & Contacteurs         │
 │  • Produit        : ActionWinchM1Bus, ActionWinchM2Bus, ActionTranslationBus                           │
 └────────────────────────────────────┬────────────────────────────────────────────────────────────────────┘
                                      │ (Demande de marche brute)
                                      ▼
 ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │ LEVEL 3 : BARRIÈRE DE CONTROLE ET SORTIES PHYSIQUES (`FB_*OutputInterlock_LD` + `PRG_10_Outputs_LD`)   │
 │  • Watchdog Frein 500 ms, Séquencement Contacteurs Vitesse C1..C4                                       │
 │  • Écriture physique des relais et de la ligne d'Arrêt d'Urgence Redondante A/B (PowerCutOff_A/B)       │
 └─────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🚌 2. Matrice Complète des Bus de Communication (DUTs)

Tous les échanges du CFC reposent sur **8 Structures de Bus Standardisées** :

### 1. `ST_HwInBus` (Bus des Entrées Conditionnées)
- **Émetteur** : `PRG_00_Acquisition_CFC` (`instInputs`)
- **Reçoit** : Bornier physique + `ST_CmdModesBus` (pour l'aiguillage réversible Réel ↔ Simulation).
- **Contenu** : `EmergencyStopOk`, `EmergencyChain`, `TopPositionSensor`, `SlackCableSwitch`, `PhaseRotationOk`, `BrakeThermalFeedback`, `M1FwdRevSpeedFeedbackOff`, `M1ThermalFeedback`, `M1BrakeFeedback`, `M2FwdRevSpeedFeedbackOff`, `M2ThermalFeedback`, `M2BrakeFeedback`, `M3SensorsWord`.

### 2. `ST_DiagNetworkBus` (Bus de Santé des Lignes Réseau)
- **Émetteur** : `PRG_00_Acquisition_CFC` (`instDiagCanOpen`, `instDiagEthercat`)
- **Contenu** : `JoystickOnline`, `JoystickOperational`, `DriveM3Online`, `DriveM3Operational`, `EncoderM1Online`, `EncoderM2Online`, `NetworkGlobalError`.

### 3. `ST_CmdJoystickBus` (Bus du Organe de Conduite Manuel)
- **Émetteur** : `PRG_00_Acquisition_CFC` (`instJoystick`)
- **Contenu** : `DeadmanArmed`, `SpeedRefX_Pct`, `SpeedRefY_Pct`, `RawX`, `RawY`, `JoystickFault`, `IsCentralPositionX`, `IsCentralPositionY`.

### 4. `ST_CmdModesBus` (Bus de Configuration & Modes Machine)
- **Émetteur** : `FB_Modes`
- **Contenu** : `ActiveMode` (`E_Mode`), `SimulationModeActive`, `SyncEnable`, `InhibitM1`, `InhibitM2`, `BypassGlobal`, `HomingApproachEnable`.

### 5. `ST_SafetyWinchBus` / `ST_SafetyTranslationBus` (Bus Chapeau Sécurité)
- **Émetteur** : `FB_Safety_Winch` (M1 & M2) / `FB_Safety_Translation` (M3)
- **Consommateurs** : Blocs actionneurs `FB_Winch` et `FB_Translation` (Entrée du HAUT).
- **Contenu** : `SafeStop`, `PowerCutOff`, `ForbidAscent`, `ForbidDescent`, `ErrorId`, `ErrorOperatorComm`, `ErrorDriveComm`, `ErrorMecaA`, `ErrorMecaB`.

### 6. `ST_CmdWinchBus` / `ST_CmdTranslationBus` (Bus Consignes Arbitrées)
- **Émetteur** : Organe de commande (Joystick en Manuel, `FB_Cycle` en Auto, Bouton IHM en Maint).
- **Contenu** : `StartStop`, `Direction`, `SpeedRefPct`, `TargetNum`, `ActiveOffsetM` (Benne).

### 7. `ST_ActionWinchBus` / `ST_ActionTranslationBus` (Bus d'Ordres Actionneurs)
- **Émetteur** : Actionneurs `FB_Winch` M1/M2 / `FB_Translation` M3.
- **Consommateur** : Barrière de sortie `FB_*OutputInterlock_LD`.
- **Contenu** : `RequestedRelayFwd`, `RequestedRelayRev`, `RequestedContactor1..4`, `RequestedStep`, `BrakeReleaseRequest`, `RequestedDriveFreqHz`, `RequestedDriveControlWord`.

### 8. `ST_StateWinchBus` / `ST_StateTranslationBus` (Bus de Diagnostic IHM & Supervision)
- **Émetteur** : Actionneurs & Barrières de sortie.
- **Consommateur** : `PRG_09_Supervision` ➔ Copie directe dans `GVL_IHM`.
- **Contenu** : `Ready`, `Busy`, `Done`, `State`, `StateAtError`, `BrakeCmd`, `BrakeTimeoutElapsed`, `RestartInhibit`.


---

## 🎨 3. Implémentation du CFC Pilote (Lot 1 : `PRG_00_Acquisition_CFC`)

Le POU CFC `PRG_00_Acquisition_CFC` est développé pour inclure d'emblée l'ensemble de ses bornes d'échange bus :

```text
 ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │                                              POU CFC : PRG_00_Acquisition_CFC                                                   │
 ├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
 │                                                                                                                                 │
 │  [ ENTRÉE CONFIGURATION BUS ]                                                                                                   │
 │    GVL_Global.CmdModesBus (Lit SimulationModeActive) ──┐                                                                        │
 │                                                        │                                                                        │
 │  [ ENTRÉES MATÉRIELLES / SIMU ]                        ▼                                                                        │
 │    HwReal (Bornier Physique)  ────────┐      ┌──────────────────┐                                                               │
 │    HwSim  (Banc Virtuel)      ────────┼─────►│    instInputs    ├────────────────────────────────────────► (ST_HwIn_Bus)          │
 │                                       │      │    (FB_Input)    │                                            │                    │
 │                                       │      └──────────────────┘                                            │                    │
 │  [ DIAGNOSTIC BUS CAN & ETHERCAT ]    │                                                                      │                    │
 │    RawCanBusState / RawJoystickState ─┼─────►┌──────────────────┐                                            │                    │
 │    RawVariateur / RawEncoderM1 / M2  ─┼────►│ instDiagCanOpen  ├─┐                                          │                    │
 │                                       │      │ instDiagEthercat ├─┼────────────────────────────────────────┼─►(ST_Diag_NetworkBus)
 │                                       │      └──────────────────┘ │                                          │   │                │
 │  [ TRAITEMENT JOYSTICK ]              │                           │                                          │   │                │
 │    Channel X / Y / BtnDeadman ────────┴───────────────────────────┼────────►┌───────────────┐                │   │                │
 │                                                                   └────────►│ instJoystick ├───────────────┼───┼─►(ST_Cmd_JoyBus)
 │                                                                             └───────────────┘                │   │   │            │
 ├──────────────────────────────────────────────────────────────────────────────────────────────────────────────┼───┼───┼────────────┤
 │  [ PUBLICATION DANS GVL_GLOBAL POUR UTILISATION PAR TOUS LES CABLES CFC SUIVANTS ]                           │   │   │            │
 │                                                                                                              │   │   │            │
 │    GVL_Global.HwInBus        ◄─────────────────────────────────────────────────────────────────────────────────┘   │   │            │
 │    GVL_Global.DiagNetworkBus ◄─────────────────────────────────────────────────────────────────────────────────────┘   │            │
 │    GVL_Global.CmdJoystickBus ◄─────────────────────────────────────────────────────────────────────────────────────────┘            │
 └─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🗺️ 5. Cartographie Globale & Détaillée des 5 POU CFC du Programme Automate

Afin d'avoir une vision 100% claire et complète de l'architecture finale, voici le détail exact des **5 POU CFC Métiers** qui remplaceront l'ensemble des anciens programmes ST :

```text
 ┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 │                                 L'ARBORESCENCE FINALE DES 5 POU CFC                                    │
 ├────────────────────────────────────────────────────────────────────────────────────────────────────────┤
 │ 📡 POU 1 : `PRG_00_Acquisition_CFC`   ➔ Acquisition E/S, Simulation & Diagnostic Réseau               │
 │ 📏 POU 2 : `PRG_02_Encoders_CFC`      ➔ Pipeline Codeurs Tambours M1/M2 (Scale, Homing, Safety)      │
 │ 🛡️ POU 3 : `PRG_03_Safety_CFC`        ➔ Chapeau Superviseur Sécurités (Winch M1/M2 & Translation M3) │
 │ ↔️ POU 4 : `PRG_07_Translation_CFC`   ➔ Axe Translation M3 (Variateur AC600, Decodage 5 Capteurs)     │
 │ ⚖️ POU 5 : `PRG_06_WinchControl_CFC`  ➔ Treuils M1/M2, Synchro, Benne & Assistants Plongée/Extraction   │
 └────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 1. `PRG_00_Acquisition_CFC` (Niveau 0 - Acquisition & Network)
- **Rôle** : Reçoit `HwReal` et `HwSim`, applique l'aiguillage réversible vers `HwIn`, surveille les bus CANopen & EtherCAT, et traite le joystick.
- **Instances internes** : `instInputs` (`FB_Input`), `instDiagCanOpen`, `instDiagEthercat`, `instJoystick`.
- **Bus émis** : `ST_HwIn_Bus`, `ST_Diag_NetworkBus`, `ST_Cmd_JoystickBus`.

### 2. `PRG_02_Encoders_CFC` (Niveau 0bis - Métrologie Codeurs)
- **Rôle** : Lecture bus EtherCAT des codeurs absolus tambours COD1 (M1) et COD2 (M2), conversion points ➔ mètres, gestion du référencement (Homing) et surveillance incohérence/saut de valeur.
- **Instances internes** : `instEncoderAbsM1/M2`, `instEncoderScaleM1/M2`, `instEncoderHomingM1/M2`, `instEncoderSafetyM1/M2`.
- **Bus émis** : `ST_State_EncoderM1Bus`, `ST_State_EncoderM2Bus`.

### 3. `PRG_03_Safety_CFC` (Niveau 1 - Chapeau Superviseur Sécurité)
- **Rôle** : Reçoit `ST_HwIn_Bus`, `ST_Diag_NetworkBus` et les positions des codeurs. Calcule les verrous de sécurité pour l'ensemble de la machine.
- **Instances internes** : `instSafetyWinchM1`, `instSafetyWinchM2`, `instSafetyTranslationM3`, `instSpeedMonitorM1/M2`.
- **Bus émis** : `ST_Safety_WinchM1Bus`, `ST_Safety_WinchM2Bus`, `ST_Safety_TranslationBus`.

### 4. `PRG_07_Translation_CFC` (Niveau 2 - Domaine Translation M3)
- **Rôle** : Décode les 5 capteurs TOR de position (`Trémie..Maintenance`), arbitre les consignes (Joystick vs Auto), exécute la rampe et la conversion Hz, et passe par la barrière finale de contrôle frein.
- **Instances internes** : `instPositionDecoder`, `instTranslationM3` (`FB_Translation`), `instTranslationOutputInterlock_LD`.
- **Bus consommés** : `ST_HwIn_Bus`, `ST_Safety_TranslationBus`, `ST_Cmd_JoystickBus`, `ST_Cmd_AutoBus`.
- **Bus émis** : `ST_Action_TranslationBus`, `ST_State_TranslationBus`.

### 5. `PRG_06_WinchControl_CFC` (Niveau 2 - Domaine Treuils M1/M2 & Synchro)
- **Rôle** : Arbitre les commandes pour M1 et M2, gère le synchronisme d'écartement (`FB_WinchSync`), le décalage de benne (`FB_Bucket`), les sous-cycles d'assistance (`FB_DiveSearch`, `FB_ExtractionSequence`), le pilotage des 2 treuils `FB_WinchM1/M2` et leurs barrières de sortie frein.
- **Instances internes** : `instWinchSync`, `instBucket`, `instDiveSearch`, `instExtractionSequence`, `instWinchM1`, `instWinchM2`, `instWinchOutputInterlockM1_LD`, `instWinchOutputInterlockM2_LD`.
- **Bus consommés** : `ST_HwIn_Bus`, `ST_Safety_WinchM1Bus`, `ST_Safety_WinchM2Bus`, `ST_State_EncoderM1/M2Bus`.
- **Bus émis** : `ST_Action_WinchM1Bus`, `ST_Action_WinchM2Bus`, `ST_State_WinchM1/M2Bus`.

