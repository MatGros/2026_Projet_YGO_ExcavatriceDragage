# 📋 Analyse Fonctionnelle — Partie 7 : Interface de Supervision IHM (v1.5)

> **Projet** : Excavatrice de dragage — Automate CODESYS 3.5  
> **Rôle** : Spécification des structures de données d'échange et du mapping pour la supervision IHM (M1, M2, Benne, Translation, Cycle, Synchro).  
> **Version** : v1.5 (2026-07-18, alignement avec `PRG_00`→`PRG_10`, `GVL_IHM.Cycle` et l'interface complète `GVL_IHM.TranslationM3`).
> 🆕 **T44 (2026-07-18)** : ajout des mesures vitesse câble M1/M2, variations vitesse et
> état des moniteurs dans `ST_WinchHMI`, ainsi que de l'écart vitesse M1/M2 dans `ST_CycleHMI`.
> **v1.5 (2026-07-18)** : `PRG_MAIN` supprimé des descriptions opératoires ; le mapping est porté par `PRG_09_Supervision`, les commandes sont consommées par les programmes métier concernés. Ajout des interfaces Cycle et Translation M3 complètes.  
>
> **v1.4 (2026-07-15)** : ST_TranslationHMI struct updated to reflect the AC600 EtherCAT drive integration (fields RelayFwd/RelayRev and BypassBrakeFeedback no longer exist).  
> **v1.3 (2026-07-08)** : Lot #9-17 : Alignment on latest implementation. ST_WinchHMI updated with independent cable limits, inhibition commands, and Meca A/B/C/D diagnostics. ST_ModesHMI updated to match the actual code including full arming sequence outputs.  
> 🔧 **Nettoyage documentaire (audit doc, 2026-07-09)** : harmonisation titre/nom de fichier — le titre affichait encore v1.2 alors que le champ "Version" (ci-dessus) était déjà en v1.3 ; le nom de fichier suit désormais la version la plus haute. Aucun changement de contenu fonctionnel.  
> 🔗 **Dépend de** : [P2 Architecture v2.12](AF_Partie-02_Architecture_Programme_v2.12.md), [P3 Contrat FB v1.3](AF_Partie-03_Template_FB_Commun_v1.3.md), [P9 Winch v1.7](AF_Partie-09_Fonction_Winch_v1.11.md), [P10 Homing v1.10](AF_Partie-10_Fonction_Encoder_Homing_v1.10.md), [P12 Benne v1.4](AF_Partie-12_Fonction_Benne_v1.4.md), [P13 Simulation v1.1](AF_Partie-13_Fonction_Simulation_v1.2.md).

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
    CableLimitDescentM      : REAL := -20.0;    (* Limite basse physique de descente (m, négatif) - dédiée/indépendante *)
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
    BrakeCmd                : BOOL;             (* Commande frein (TRUE = desserré / libre) *)
    
    (* 🛡️ Sécurités & Diagnostics *)
    Homed                   : BOOL;             (* Prise d'origine (Homing) validée *)
    SafeStopActive          : BOOL;             (* Arrêt rapide activé par la sécurité *)
    ForbidDescentActive     : BOOL;             (* Descente interdite (mou de câble / limites) *)
    ForbidAscentActive      : BOOL;             (* Montée interdite (fin de course haut) *)
    SlackCableDetected      : BOOL;             (* Mou de câble physiquement détecté *)
    ThermalFault            : BOOL;             (* Défaut surchauffe thermique moteur *)
    EncoderFault            : BOOL;             (* Perte de liaison ou incohérence codeur *)
    CableLimitDescentReached: BOOL;             (* Longueur max de câble atteinte (limite basse physique) *)
    Encoder                 : ST_EncoderHMI;    (* Données d'échange et diagnostic du codeur *)
    
    (* 🔍 Diagnostics de cohérence contacteurs réutilisés *)
    ContactorsCheck         : ST_ContactorCheck; (* Coherence contacteurs sens+vitesse fusionnée *)
    BrakeContactorCheck     : ST_ContactorCheck; (* Coherence retour frein *)

    (* 🎮 Commandes Opérateur (Boutons tactiles) *)
    CmdReset                : BOOL;             (* Demande reset par treuil, agrégée dans le reset domaine partagé *)
    CmdHome                 : BOOL;             (* Lancement de la prise d'origine *)
    ConfirmCoherence        : BOOL;             (* Confirmation de cohérence au démarrage *)
    CmdInhibit              : BOOL;             (* Bouton IHM inhibition treuil (MAINT_N2) *)
    
    (* 🐞 Bypasses de Test (Visualisation / Forçage) *)
    BypassContactorFeedback : BOOL;             (* Bypass retours contacteurs (banc de test) *)
    BypassSlackCable        : BOOL;             (* Bypass capteur mou de câble (banc de test) *)
    BypassTopPositionSensor : BOOL;             (* Bypass capteur position haute (banc de test) *)
    SafetyError             : BOOL;             (* Bloc sécurité (Safety) en défaut *)
    SafetyErrorId           : WORD;             (* Code défaut de sécurité *)
    InhibitActive           : BOOL;             (* Miroir lecture seule : inhibition active *)
    MecaADriftM             : REAL;             (* Dérive mesurée Méca A (m) *)
    MecaCDriftM             : REAL;             (* Dérive mesurée Méca C (m) *)
    MecaBElapsedTime        : TIME;             (* Temps écoulé confirmation contacteurs/frein *)
END_STRUCT
END_TYPE
```

### B. Mécanisme Benne (`ST_BucketHMI`)
Permet de manipuler la configuration de l'ouverture et de la fermeture du benne et de surveiller l'état cinématique.

```pascal
TYPE ST_BucketHMI :
STRUCT
    (* ⚙️ Configurations & Paramètres (Lecture/Écriture RETAIN) *)
    Config              : ST_BucketConfig; (* Offsets Open/Close/Coherence *)
    TimeoutDuration     : TIME := T#30s;    (* Temps max pour l'ouverture/fermeture *)

    (* 🚦 États & Retours (Lecture seule) *)
    State               : ST_BucketState;  (* État mémorisé (IsOpen, IsClosed, etc.) *)
    FBState             : E_State;          (* État de l'automate interne (FB_Bucket) *)
    ActiveOffsetM       : REAL;             (* Offset actif injecté dans la synchro *)
    M2StartStop         : BOOL;             (* Commande Start/Stop forcée vers M2 *)
    M2Direction         : INT;              (* Commande direction forcée vers M2 *)
    M2ForceSlowSpeed    : BOOL;             (* Blocage vitesse rapide de M2 *)
    Ready               : BOOL;             (* Bloc opérationnel *)
    Busy                : BOOL;             (* Mouvement d'ouverture/fermeture en cours *)
    Done                : BOOL;             (* Mouvement terminé avec succès *)
    Error               : BOOL;             (* Benne en défaut *)
    ErrorId             : WORD;             (* Code bitfield du défaut benne *)

    (* 🎮 Commandes Opérateur (Boutons tactiles) *)
    CmdOpen             : BOOL;             (* Bouton commande ouverture *)
    CmdClose            : BOOL;             (* Bouton commande fermeture *)
    CmdReset            : BOOL;             (* Acquittement défaut benne *)
END_STRUCT
END_TYPE
```

### C. Surveillance de Synchronisme (`ST_SyncHMI`)
Gère l'écart limite mécanique et affiche la dérive réelle.

```pascal
TYPE ST_SyncHMI :
STRUCT
    (* ⚙️ Paramètres / Calibration (Lecture/Écriture RETAIN) *)
    SyncToleranceM      : REAL := 0.10;     (* Tolérance max d'écart (m) *)

    (* 🚦 États (Lecture seule) *)
    DeltaPosM           : REAL;             (* Écart de position réel mesuré (m) *)
    SyncActive          : BOOL;             (* Indicateur si surveillance active *)
    SyncWarn            : BOOL;             (* LED d'alarme écart hors tolérance *)
    Ready               : BOOL;             (* Bloc de synchro prêt *)
    Error               : BOOL;             (* Alarme synchro active *)
    ErrorId             : WORD;             (* Code défaut synchro *)
    State               : E_State;          (* État de l'automate interne *)

    (* 🎮 Commandes / Bypasses *)
    SyncEnable          : BOOL;             (* Demande de synchro active (MAINT_N1/N2) — TRUE = synchro active (défaut) *)
END_STRUCT
END_TYPE
```

### D. Joystick / Organe de Commande (`ST_JoystickHMI`)
Regroupe les informations de commande et d'état du joystick CANopen.

```pascal
TYPE ST_JoystickHMI :
STRUCT
    RawX        : INT;        (* 🕹️ Axe X brut du joystick (0..10000) *)
    RawY        : INT;        (* 🕹️ Axe Y brut du joystick (0..10000) *)
    RawButton   : BOOL;       (* 🔘 Bouton homme-mort brut *)
    CmdX        : ST_AxisCmd; (* ⚙️ Consigne d'axe X normalisée *)
    CmdY        : ST_AxisCmd; (* ⚙️ Consigne d'axe Y normalisée *)
    Online      : BOOL;       (* 📡 Liaison CAN joystick active *)
    Operational : BOOL;       (* 🟢 Joystick opérationnel *)
    Calibrate   : BOOL;       (* 🎯 Demande de recalage au neutre *)
END_STRUCT
END_TYPE
```

### E. Modes de Marche (`ST_ModesHMI`)
Permet de piloter et de surveiller l'état des modes de marche de la machine.

```pascal
TYPE ST_ModesHMI :
STRUCT
    CurrentMode           : E_Mode; (* 🎚️ Mode de marche actuellement actif *)
    ModeRequest           : E_Mode := E_Mode.MAINT_N1; (* 🖥️ Demande de changement de mode *)
    EmergencyStopOk       : BOOL;   (* 🛡️ État de la chaîne d'arrêt d'urgence *)
    FaultMachineReset     : BOOL;   (* 🔔 Acquittement défauts/alarmes domaine sécurité/métier *)
    ModeReset             : BOOL;   (* 🔁 Acquittement défaut FB_Modes uniquement *)
    AnyFaultActive        : BOOL;   (* 🔴 Au moins un défaut actif dans le domaine *)
    PowerCutOffActive     : BOOL;   (* 🧨 Au moins une coupure de puissance logicielle ou physique active *)
    
    (* 🔧 Séquence de réarmement et diagnostics *)
    CmdEmergencyArming    : BOOL;   (* 🎮 Commande réarmement contacteur puissance *)
    CmdEmergencyCutOff    : BOOL;   (* 🎮 Commande coupure d'urgence puissance amont *)
    EmergencyChainOk      : BOOL;   (* 🔗 Boucle AU physique saine *)
    PowerContactorOk      : BOOL;   (* 🔌 Contacteur puissance engagé (miroir EmergencyStopOk) *)
    EmergencyArmable      : BOOL;   (* 🟢 Réarmement possible maintenant *)
    EmergencyArmingBusy   : BOOL;   (* ⏳ Séquence de réarmement ou verrouillage 5s en cours *)
    RedundancyTestFailed  : BOOL;   (* 🔴 Échec de l'auto-test de redondance canal A/B *)
    EmergencyArmingFailed : BOOL;   (* 🔴 Impulsion envoyée sans engagement sous 2s *)
END_STRUCT
END_TYPE
```

### F. Diagnostics Codeurs Absolus (`ST_EncoderHMI`)
Contient les informations d'état et les commandes spécifiques aux codeurs absolus Kübler.

```pascal
TYPE ST_EncoderHMI :
STRUCT
    RawPos           : UDINT; (* 📊 Position brute lue sur le bus *)
    Alarms           : UINT;  (* ⚠️ Code d'alarme brut du codeur *)
    Warnings         : UINT;  (* 🟧 Code d'avertissement brut du codeur *)
    SlaveOperational : BOOL;  (* 📡 Esclave EtherCAT opérationnel *)
    PresetTriggerCmd : WORD;  (* 🎯 Commande de preset active *)
    PresetValueOut   : UDINT; (* 📐 Valeur de preset envoyée au codeur *)
END_STRUCT
END_TYPE
```

### G. Translation M3 (`ST_TranslationHMI`)
Regroupe les informations de commande, d'état et de diagnostic de l'axe transversal de la machine (M3).

```pascal
TYPE ST_TranslationHMI :
STRUCT
    (* Commandes opérateur (manuel / maintenance) *)
    SelectedTargetNum       : INT;     (* Numéro de la cible de position sélectionnée *)
    ReqFwd                  : BOOL;    (* Requête marche avant manuelle (bouton IHM, pas encore arbitrée) *)
    ReqRev                  : BOOL;    (* Requête marche arrière manuelle (bouton IHM, pas encore arbitrée) *)
    FreqSetpointHz          : REAL;    (* Consigne fréquence manuelle [Hz], limitée par PRG_10_Outputs *)

    (* États & diagnostics FB_Translation *)
    FBState                 : E_State; (* État de l'automate interne (FB_Translation) *)
    Ready                   : BOOL;
    Busy                    : BOOL;
    Done                    : BOOL;
    Error                   : BOOL;
    ErrorId                 : WORD;
    BrakeCmd                : BOOL;    (* Commande de desserrage du frein (lecture seule, TRUE = desserré) *)
    BrakeFeedback           : BOOL;    (* Retour physique de l'état du frein *)
    PositionSensorTarget    : BOOL;    (* Capteur de détection de la position cible atteint *)
    DriveActualFreqHz       : REAL;    (* Fréquence de sortie réelle du variateur (Hz) *)

    (* Diagnostic variateur EtherCAT (décodé) *)
    DriveCommReady          : BOOL;    (* Variateur M3 : communication prête (StatusWord bit7) *)
    DrivePowerReady         : BOOL;    (* Variateur M3 : puissance prête (StatusWord bit0) *)

    (* Bypass diag (banc de test — auto-calculé depuis GVL_Simulation) *)
    BypassContactorFeedback : BOOL;    (* Activation du bypass des retours contacteurs (sens + frein) *)

    (* Sécurité (FB_Safety_Translation) *)
    SafetyError             : BOOL;
    SafetyErrorId           : WORD;
END_STRUCT
END_TYPE
```

### H. Diagnostics Réseau (`ST_NetworkDiagHMI`)
Regroupe les états de diagnostics des bus de communication CANopen et EtherCAT.

```pascal
TYPE ST_NetworkDiagHMI :
STRUCT
    BusCanOpen          : ST_DiagDevice;  (* 📡 Diagnostics bus CANopen *)
    Joystick            : ST_DiagDevice;  (* 🕹️ Diagnostics esclave Joystick *)
    CanError            : BOOL;           (* ⚠️ Anomalie CANopen *)
    CanErrorId          : WORD;           (* ❌ Code anomalie CANopen *)
    
    BusEthercat         : ST_DiagDevice;  (* 📡 Diagnostics bus EtherCAT *)
    EncoderM1           : ST_DiagDevice;  (* 🧲 Diagnostics esclave COD1 *)
    EncoderM2           : ST_DiagDevice;  (* 🧲 Diagnostics esclave COD2 *)
    VariateurM3         : ST_DiagDevice;  (* ↔️ Diagnostics esclave AC600 *)
    EcatError           : BOOL;           (* ⚠️ Anomalie EtherCAT *)
    EcatErrorId         : WORD;           (* ❌ Code anomalie EtherCAT *)
END_STRUCT
END_TYPE
```

---

## 🎛️ 3. Déclaration GVL (`GVL_IHM.st`)

```pascal
VAR_GLOBAL RETAIN
    WinchM1 : ST_WinchHMI;  (* Variables d'échange IHM Treuil Principal M1 *)
    WinchM2 : ST_WinchHMI;  (* Variables d'échange IHM Treuil Auxiliaire M2 *)
    Benne : ST_BucketHMI;(* Variables d'échange IHM Mécanisme Benne *)
    Sync    : ST_SyncHMI;   (* Variables d'échange IHM Surveillance de synchro *)
    JoystickJOY1 : ST_JoystickHMI; (* Variables d'échange IHM Joystick *)
    Modes   : ST_ModesHMI;  (* Variables d'échange IHM Modes de marche *)
    TranslationM3 : ST_TranslationHMI;(* Variables d'échange IHM Translation M3 *)
    Network : ST_NetworkDiagHMI;(* Variables d'échange IHM Diagnostics réseau *)
END_VAR
```

---

## 🔄 4. Logique de Mapping (`PRG_09_Supervision.st`)

Le mapping bidirectionnel est centralisé dans `PRG_09_Supervision.st` :

1. **Au tout début de l'implémentation** :
   Les commandes issues de l'IHM sont recopiées vers les interfaces métier dédiées (`PRG_04_Modes`, `PRG_05_Cycle`, `PRG_07_TranslationControl`). Les anciens stubs ne sont conservés que lorsqu'ils sont encore nécessaires.
   * Chaque structure treuil possède son propre `CmdHome`. Le front est consommé directement par
     l'instance Homing correspondante dans `PRG_02_Encoders` ; aucun `HomingMode_IHM`, sélecteur
     global ou `StubHomeButton_IHM` n'est utilisé. Les deux demandes peuvent être simultanées.
   * Les commandes de reset treuils et benne sont agrégées pour piloter l'acquittement machine transverse `MachineReset_IHM`.

2. **Dans les sections de miroir d'état de `PRG_09_Supervision`** :
   * Les mesures réelles, les sorties d'état automates et les sous-structures de diagnostic (`ContactorsCheck`, etc.) sont affectées à `GVL_IHM` pour alimenter les écrans de supervision.
   * Les paramètres de calibration modifiés à l'écran (`TopSensorPositionM`, `MaxStepDescente`, `RampAccelRate`, etc.) sont recopiés vers les registres de travail de l'automate.
   * Les overrides de test sont autorisés uniquement lorsque `GVL_Simulation.SimulationModeActive = TRUE`.

Les commandes de cycle sont regroupées dans `GVL_IHM.Cycle` et acquittées par `PRG_05_Cycle`.
Les commandes Translation M3 sont regroupées dans `GVL_IHM.TranslationM3` et consommées par
`PRG_07_TranslationControl`. Les structures ST réelles du dossier `CODE/SUPERVISION` font foi.

---

## 🔌 5. Note d'application CODESYS 3.5

1. **Création des types de données** :
   Dans le dossier `_TYPES` du projet CODESYS, ajouter les fichiers de structure : [ST_WinchHMI.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SUPERVISION/ST_WinchHMI.st), [ST_BucketHMI.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SUPERVISION/ST_BucketHMI.st), [ST_SyncHMI.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SUPERVISION/ST_SyncHMI.st), [ST_JoystickHMI.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SUPERVISION/ST_JoystickHMI.st), [ST_ModesHMI.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SUPERVISION/ST_ModesHMI.st), [ST_EncoderHMI.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SUPERVISION/ST_EncoderHMI.st), [ST_TranslationHMI.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SUPERVISION/ST_TranslationHMI.st), [ST_NetworkDiagHMI.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SUPERVISION/ST_NetworkDiagHMI.st).

2. **Déclaration de la GVL** :
   Créer une GVL nommée `GVL_IHM` et y copier le contenu de [GVL_IHM.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SUPERVISION/GVL_IHM.st). S'assurer de la cocher en **Retain** si requis par votre configuration automate (la directive `VAR_GLOBAL RETAIN` assure la persistance des données au niveau du compilateur).

3. **Mise à jour du mapping** :
   Vérifier `PRG_09_Supervision.st` et les raccordements métier `PRG_04_Modes`, `PRG_05_Cycle`,
   `PRG_07_TranslationControl`. Il n'existe plus de POU racine `PRG_MAIN`.
