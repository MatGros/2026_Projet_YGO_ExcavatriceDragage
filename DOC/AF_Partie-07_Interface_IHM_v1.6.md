# 📋 Analyse Fonctionnelle — Partie 7 : Interface de Supervision IHM (v1.6)

> 🧱 **Architecture C/S/C (2026-07-22)** — Structuration complète des données d'échange de supervision en sous-structures standardisées : `Cmd` (commandes), `State` (états et mesures), `Cfg` (configurations et réglages), `Safety` (diagnostics de sécurité) et `Bypass` / `Test` (stimulations banc).
> 
> **Projet** : Excavatrice de dragage — Automate CODESYS 3.5  
> **Rôle** : Spécification des structures de données d'échange et du mapping pour la supervision IHM.  
> **Version** : v1.6 (2026-07-22, restructuration Cmd/State/Cfg).  
> 🔗 **Dépend de** : [P2 Architecture v2.12](AF_Partie-02_Architecture_Programme_v2.12.md), [P9 Winch v1.11](AF_Partie-09_Fonction_Winch_v1.11.md), [P11 Translation v1.9](AF_Partie-11_Fonction_Translation_v1.9.md).

---

## 🎯 1. Principes Généraux

L'interface opérateur (HMI) communique avec le PLC via la liste de variables globales `GVL_IHM` (déclarée en `RETAIN` pour préserver les configurations au boot).
Pour clarifier les flux de données et isoler les actions utilisateur des retours d'information, chaque équipement de supervision (`M1TreuilRetenue`, `M2TreuilBenne`, `TranslationM3`) est structuré ainsi :

* **`.Cmd`** : Commandes et actions opérateur (boutons tactiles volatiles, purgés au boot).
* **`.State`** : Retours d'état de l'automate, mesures physiques, états capteurs (lecture seule HMI).
* **`.Cfg`** : Configurations, seuils et consignes de calibration (persistants RETAIN).
* **`.Safety`** : Diagnostics granulaires et états de sécurité (FB_Safety).
* **`.Bypass`** / **`.Test`** : Forçages pour la maintenance (MAINT_N2) et la simulation sur banc.

---

## ⚙️ 2. Structure Treuils (`ST_WinchHMI`)

Utilisée par `GVL_IHM.M1TreuilRetenue` (Treuil 1) et `GVL_IHM.M2TreuilBenne` (Treuil 2).

### A. Commandes (`Cmd : ST_WinchCmd`)
* `BtnUp`, `BtnDown` : Mouvements manuels maintenus (MAINT_N1).
* `BtnReset` : Acquittement défauts local du treuil.
* `BtnHome` : Demande de prise d'origine (Homing).
* `BtnConfirmCoherence` : Confirmation de cohérence au démarrage.
* `BtnInhibit` : Inhibition du treuil (MAINT_N2).

### B. États et Mesures (`State : ST_WinchState`)
* `Position_M`, `MeasuredSpeed_Mps` : Retours physiques du câble.
* `Ready`, `Busy`, `Done`, `Error`, `ErrorId` : États du bloc métier `FB_Winch`.
* `RelayFwd`, `RelayRev`, `Contactor1..4`, `BrakeCmd` : Sorties physiques et commande frein.
* `Homed`, `HomingBusy`, `HomingDone`, `HomingError` : Diagnostics du homing.
* `Encoder` : Diagnostic complet du codeur EtherCAT (`ST_EncoderHMI`).
* `ContactorsCheck`, `BrakeContactorCheck` : Cohérence contacteurs et frein.

### C. Configurations (`Cfg : ST_WinchCfg`)
* `CfgTopSensorPos_M` : Position cible du capteur haut (m).
* `CfgHomingTarget_M` : Cible unitaire pour le Homing en MAINT_N2 (m).
* `CfgMaxStepDescente` : Palier max de vitesse autorisé en descente (1..5).
* `CfgRampAccelRate`, `CfgRampDecelNormalRate`, `CfgRampDecelFastRate` : Consignes de rampe.
* `CfgCableLimitDescent_M`, `CfgCableLimitAscent_M` : Garde-fous de fin de course.

---

## ⚙️ 3. Structure Translation (`ST_TranslationHMI`)

Utilisée par `GVL_IHM.TranslationM3` (Chariot translation).

### A. Commandes (`Cmd : ST_TranslationCmd`)
* `SelPositioning` : `TRUE` = Positionneur sur `SelTarget` ; `FALSE` = Jog manuel libre.
* `SelTarget` : Numéro de la cible de position sélectionnée.
* `BtnFwd`, `BtnRev` : Commandes manuelles marche avant/arrière.
* `SetFreq_Hz` : Consigne de fréquence manuelle demandée.
* `TglJoystickMaster` : `TRUE` = Commande par joystick ; `FALSE` = Boutons tactiles.

### B. États et Mesures (`State : ST_TranslationState`)
* `FBState`, `Ready`, `Busy`, `Done`, `Error`, `ErrorId` : États du bloc `FB_Translation`.
* `BrakeCmd`, `BrakeFeedback` : Commande et retour du frein translation.
* `PositionReached` : Target atteinte en positionnement.
* `JoystickDeflection_Pct` : Visualisation de la consigne manuelle appliquée.
* `DriveActualFreq_Hz`, `DriveFreqRef_Hz` : Fréquences de sortie et consigne variateur.
* `DriveCommReady`, `DrivePowerReady` : Diagnostics du variateur AC600.
* `PositionTremie`, `PositionPV`, `PositionP2`, `PositionP1`, `PositionMaintenance` : Retours capteurs.

---

## 🛡️ 4. Diagnostics de Sécurité (`Safety : ST_Safety*`)

* **`ST_SafetyWinch`** : Diagnostics granulaires (slack cable, thermal fault, encoder fault, Meca A-E).
* **`ST_SafetyTranslation`** : Diagnostics M3 (limites, rotation phases, drive com, Meca A-B).
