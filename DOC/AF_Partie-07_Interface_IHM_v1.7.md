# 📋 Analyse Fonctionnelle — Partie 7 : Interface de Supervision IHM (v1.9)

> 🆕 **v1.9 (2026-07-23) — Restauration intégrale post-audit & consolidation** :
> Restauration complète des spécifications de la v1.2 (`ST_WinchHMI`, `ST_GrappinHMI`, `ST_SyncHMI`, 
> `ST_JoystickHMI`, `ST_ModesHMI`, `ST_EncoderHMI`, `ST_TranslationHMI`, `ST_NetworkDiagHMI`, `GVL_IHM`) 
> combinée aux évolutions v1.7/v1.8 (JoystickDeflectionPct M3).

---

## 🎯 1. Rôle & Objectif

L'interface opérateur (HMI) nécessite un point d'accès standardisé et unique pour lire les variables d'état (bargraphes, aiguilles de vitesse, voyants défauts, retours contacteurs) et écrire les paramètres de calibration (seuil de synchro, cibles de homing, rampes) ou les commandes tactiles (boutons de prise d'origine, acquittements défauts).

Toutes les variables d'échange IHM sont regroupées dans la liste de variables globales `GVL_IHM`.

---

## ⚙️ 2. Structures de données (`_TYPES`)

### A. Treuils M1 / M2 (`ST_WinchHMI`)
Regroupe les informations nécessaires au contrôle et au diagnostic d'un treuil individuel. Il compose `ST_ContactorCheck` pour surveiller l'état et l'usure/défaut des contacteurs de puissance physiques.

```pascal
TYPE ST_WinchHMI :
STRUCT
    (* ⚙️ Paramètres / Calibration (Lecture/Écriture RETAIN) *)
    TopSensorPositionM      : REAL := 12.5;     (* Position cible du capteur haut (m) *)
    MaxStepDescente         : INT := 3;         (* Limitation palier vitesse en descente (1..5) - commun M1/M2 *)
    RampAccelRate           : REAL := 50.0;     (* Rampe d'accélération (%/s) *)
    RampDecelNormalRate     : REAL := 150.0;    (* Rampe de décélération normale (%/s) *)
    RampDecelFastRate       : REAL := 400.0;    (* Rampe de décélération rapide / SafeStop (%/s) *)
    CableLimitDescentM      : REAL := -20.0;    (* Limite basse physique de descente (m, négatif) *)
    SlowdownDistanceM       : REAL := 1.0;      (* Distance avant limite pour ralentir (m) *)
    SlowSpeedPct            : REAL := 15.0;     (* Vitesse consigne lente dans zone ralentissement (%) *)

    (* 🚦 États & Mesures (Lecture seule) *)
    PositionM               : REAL;             (* Position actuelle du câble (mètres) *)
    SpeedRefPct             : REAL;             (* Consigne de vitesse finale après rampe (%) *)
    StepNumber              : INT;              (* Palier de vitesse actif (0..5) *)
    FBState                 : E_State;          (* État de l'automate interne (FB_Winch) *)
    Ready                   : BOOL;             (* Treuil prêt à fonctionner *)
    Busy                    : BOOL;             (* Mouvement en cours *)
    Done                    : BOOL;             (* Action terminée *)
    Error                   : BOOL;             (* Treuil en défaut *)
    ErrorId                 : WORD;             (* Code bitfield du défaut treuil *)
    
    (* 🔌 Sorties Physiques / Indicateurs LEDs *)
    RelayFwd                : BOOL;             (* Relais Montée activé *)
    RelayRev                : BOOL;             (* Relais Descente activé *)
    Contactor1              : BOOL;             (* Contacteur vitesse palier 1 *)
    Contactor2              : BOOL;             (* Contacteur vitesse palier 2 *)
    Contactor3              : BOOL;             (* Contacteur vitesse palier 3 *)
    Contactor4              : BOOL;             (* Contacteur vitesse palier 4 *)
    BrakeCmd                : BOOL;             (* Commande frein (TRUE = desserré) *)
    
    (* 🛡️ Sécurités & Diagnostics *)
    Homed                   : BOOL;             (* Prise d'origine (Homing) validée *)
    SafeStopActive          : BOOL;             (* Arrêt rapide activé par la sécurité *)
    ForbidDescentActive     : BOOL;             (* Descente interdite *)
    ForbidAscentActive      : BOOL;             (* Montée interdite *)
    SlackCableDetected      : BOOL;             (* Mou de câble physiquement détecté *)
    ThermalFault            : BOOL;             (* Défaut surchauffe thermique moteur *)
    EncoderFault            : BOOL;             (* Perte de liaison ou incohérence codeur *)
    CableLimitDescentReached: BOOL;             (* Longueur max de câble atteinte *)
    Encoder                 : ST_EncoderHMI;    (* Données d'échange et diagnostic du codeur *)
    
    (* 🔍 Diagnostics de cohérence contacteurs réutilisés *)
    ContactorsCheck         : ST_ContactorCheck; (* Coherence contacteurs sens+vitesse *)
    BrakeContactorCheck     : ST_ContactorCheck; (* Coherence retour frein *)

    (* 🎮 Commandes Opérateur (Boutons tactiles) *)
    CmdReset                : BOOL;             (* Acquittement défauts spécifique treuil *)
    CmdHome                 : BOOL;             (* Lancement de la prise d'origine *)
    ConfirmCoherence        : BOOL;             (* Confirmation de cohérence au démarrage *)
    CmdInhibit              : BOOL;             (* Bouton IHM inhibition treuil *)
    
    (* 🐞 Bypasses de Test *)
    BypassContactorFeedback : BOOL;             (* Bypass retours contacteurs *)
    BypassSlackCable        : BOOL;             (* Bypass capteur mou de câble *)
    BypassTopPositionSensor : BOOL;             (* Bypass capteur position haute *)
    SafetyError             : BOOL;             (* Bloc sécurité (Safety) en défaut *)
    SafetyErrorId           : WORD;             (* Code défaut de sécurité *)
    InhibitActive           : BOOL;             (* Inhibition active *)
    MecaADriftM             : REAL;             (* Dérive mesurée Méca A (m) *)
    MecaCDriftM             : REAL;             (* Dérive mesurée Méca C (m) *)
    MecaBElapsedTime        : TIME;             (* Temps écoulé confirmation contacteurs/frein *)
END_STRUCT
END_TYPE
```

### B. Translation M3 (`ST_TranslationHMI`)
Regroupe les informations de commande, d'état et de diagnostic du variateur AC600 de translation M3.

```pascal
TYPE ST_TranslationHMI :
STRUCT
    FBState                 : E_State; (* État automate (FB_Translation) *)
    Ready                   : BOOL;    (* M3 prêt *)
    Busy                    : BOOL;    (* Mouvement en cours *)
    Done                    : BOOL;    (* Mouvement terminé *)
    Error                   : BOOL;    (* M3 en défaut *)
    ErrorId                 : WORD;    (* Code défaut actif *)
    BrakeCmd                : BOOL;    (* Desserrage frein M3 *)
    BrakeFeedback           : BOOL;    (* Retour état du frein *)
    DriveCommReady          : BOOL;    (* Com EtherCAT AC600 OK (StatusWord Bit 7) *)
    DrivePowerReady         : BOOL;    (* Puissance variateur OK (StatusWord Bit 0) *)
    DriveActualFreqHz       : REAL;    (* Fréquence de sortie réelle variateur (Hz) *)
    JoystickDeflectionPct   : REAL;    (* Déflexion fonctionnelle signée axe X (-100..+100 %) *)
    BypassContactorFeedback : BOOL;    (* Bypass des retours contacteurs / frein *)
END_STRUCT
END_TYPE
```

### C. Modes de Marche (`ST_ModesHMI`)

```pascal
TYPE ST_ModesHMI :
STRUCT
    CurrentMode           : E_Mode; (* Mode actuellement actif *)
    ModeRequest           : E_Mode := E_Mode.MAINT_N1; (* Demande changement mode *)
    EmergencyStopOk       : BOOL;   (* État arrêt d'urgence *)
    FaultMachineReset     : BOOL;   (* Acquittement défauts global *)
    ModeReset             : BOOL;   (* Acquittement FB_Modes *)
    AnyFaultActive        : BOOL;   (* Au moins un défaut actif *)
    PowerCutOffActive     : BOOL;   (* Coupure de puissance active *)
    CmdEmergencyArming    : BOOL;   (* Commande réarmement *)
    CmdEmergencyCutOff    : BOOL;   (* Commande coupure puissance *)
    EmergencyChainOk      : BOOL;   (* Boucle AU physique saine *)
    PowerContactorOk      : BOOL;   (* Contacteur puissance engagé *)
    EmergencyArmable      : BOOL;   (* Réarmement possible *)
    EmergencyArmingBusy   : BOOL;   (* Séquence réarmement/verrouillage en cours *)
    RedundancyTestFailed  : BOOL;   (* Échec auto-test redondance *)
    EmergencyArmingFailed : BOOL;   (* Échec engagement sous 2s *)
END_STRUCT
END_TYPE
```

---

## 🌐 3. Liste des Variables Globales (`GVL_IHM`)

```pascal
VAR_GLOBAL
    WinchM1          : ST_WinchHMI;       (* Treuil principal M1 *)
    WinchM2          : ST_WinchHMI;       (* Treuil secondaire M2 *)
    M3Translation    : ST_TranslationHMI; (* Translation Chariot M3 *)
    Grappin          : ST_GrappinHMI;     (* Automate grappin M2 *)
    Sync             : ST_SyncHMI;        (* Synchronisation M1/M2 *)
    JOY1Joystick     : ST_JoystickHMI;    (* Diagnostic & axes Joystick *)
    Modes            : ST_ModesHMI;       (* Modes de marche & AU *)
    NetworkDiag      : ST_NetworkDiagHMI; (* Diagnostic bus CAN / EtherCAT *)
END_VAR
```
