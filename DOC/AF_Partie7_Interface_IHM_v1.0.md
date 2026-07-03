# 📋 Analyse Fonctionnelle — Partie 7 : Interface de Supervision IHM (v1.0)

> **Projet** : Excavatrice de dragage — Automate CODESYS 3.5  
> **Rôle** : Spécification des structures de données d'échange et du mapping pour la supervision IHM (M1, M2, Grappin, Synchro).  
> **Version** : v1.0 (Création - 2026-07-03)  
> 🔗 **Dépend de** : [P2 Architecture v2.7](AF_Partie2_Architecture_Programme_v2.7.md), [P3 Contrat FB v1.3](AF_Partie3_Template_FB_Commun_v1.3.md), [P9 Winch v1.1](AF_Partie9_Fonction_Winch_v1.1.md), [P10 Homing v1.6](AF_Partie10_Fonction_Encoder_Homing_v1.6.md), [P12 Grappin v1.0](AF_Partie12_Fonction_Grappin_v1.0.md).

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
    MaxStepDescente         : INT := 2;         (* Limitation palier vitesse en descente (1..5) *)
    RampAccelRate           : REAL := 50.0;     (* Rampe d'accélération (%/s) *)
    RampDecelNormalRate     : REAL := 150.0;    (* Rampe de décélération normale (%/s) *)
    RampDecelFastRate       : REAL := 400.0;    (* Rampe de décélération rapide / SafeStop (%/s) *)

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
    ForbidDescentActive     : BOOL;             (* Descente interdite (détecteur mou de câble) *)
    SlackCableDetected      : BOOL;             (* Mou de câble physiquement détecté *)
    ThermalFault            : BOOL;             (* Défaut surchauffe thermique moteur *)
    EncoderFault            : BOOL;             (* Perte de liaison ou incohérence codeur *)
    
    (* 🔍 Diagnostics de cohérence contacteurs réutilisés *)
    FwdContactorCheck       : ST_ContactorCheck; (* Coherence contacteur montée *)
    RevContactorCheck       : ST_ContactorCheck; (* Coherence contacteur descente *)
    BrakeContactorCheck     : ST_ContactorCheck; (* Coherence retour frein *)

    (* 🎮 Commandes Opérateur (Boutons tactiles) *)
    CmdReset                : BOOL;             (* Acquittement défauts spécifique treuil *)
    CmdHome                 : BOOL;             (* Lancement de la prise d'origine *)
    ConfirmCoherence        : BOOL;             (* Confirmation de cohérence au démarrage *)
    
    (* 🐞 Bypasses de Test (Visualisation / Forçage) *)
    BypassContactorFeedback : BOOL;             (* Bypass retours contacteurs (banc de test) *)
    BypassSlackCable        : BOOL;             (* Bypass capteur mou de câble (banc de test) *)
    BypassTopPositionSensor : BOOL;             (* Bypass capteur position haute (banc de test) *)
END_STRUCT
END_TYPE
```

### B. Mécanisme Grappin (`ST_GrappinHMI`)
Permet de manipuler la configuration de l'ouverture et de la fermeture du grappin et de surveiller l'état cinématique.

```pascal
TYPE ST_GrappinHMI :
STRUCT
    (* ⚙️ Configurations & Paramètres (Lecture/Écriture RETAIN) *)
    Config              : ST_GrappinConfig; (* Offsets Open/Close/Coherence *)
    TimeoutDuration     : TIME := T#30s;    (* Temps max pour l'ouverture/fermeture *)

    (* 🚦 États & Retours (Lecture seule) *)
    State               : ST_GrappinState;  (* État mémorisé (IsOpen, IsClosed, etc.) *)
    FBState             : E_State;          (* État de l'automate interne (FB_Grappin) *)
    ActiveOffsetM       : REAL;             (* Offset actif injecté dans la synchro *)
    M2StartStop         : BOOL;             (* Commande Start/Stop forcée vers M2 *)
    M2Direction         : INT;              (* Commande direction forcée vers M2 *)
    M2ForceSlowSpeed    : BOOL;             (* Blocage vitesse rapide de M2 *)
    Ready               : BOOL;             (* Bloc opérationnel *)
    Busy                : BOOL;             (* Mouvement d'ouverture/fermeture en cours *)
    Done                : BOOL;             (* Mouvement terminé avec succès *)
    Error               : BOOL;             (* Grappin en défaut *)
    ErrorId             : WORD;             (* Code bitfield du défaut grappin *)

    (* 🎮 Commandes Opérateur (Boutons tactiles) *)
    CmdOpen             : BOOL;             (* Bouton commande ouverture *)
    CmdClose            : BOOL;             (* Bouton commande fermeture *)
    CmdReset            : BOOL;             (* Acquittement défaut grappin *)
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
    OverrideSync        : BOOL;             (* Désactivation de la synchro (MAINT_N2) *)
END_STRUCT
END_TYPE
```

---

## 🎛️ 3. Déclaration GVL (`GVL_IHM.st`)

```pascal
VAR_GLOBAL RETAIN
    WinchM1 : ST_WinchHMI;  (* Variables d'échange IHM Treuil Principal M1 *)
    WinchM2 : ST_WinchHMI;  (* Variables d'échange IHM Treuil Auxiliaire M2 *)
    Grappin : ST_GrappinHMI;(* Variables d'échange IHM Mécanisme Grappin *)
    Sync    : ST_SyncHMI;   (* Variables d'échange IHM Surveillance de synchro *)
END_VAR
```

---

## 🔄 4. Logique de Mapping (`PRG_MAIN.st`)

Le mapping bidirectionnel est divisé en deux parties dans `PRG_MAIN.st` :

1. **Au tout début de l'implémentation** :
   Les commandes issues de l'IHM sont recopiées dans les variables globales de commande stub de l'application (compatibilité descendante).
   * Les boutons tactiles `CmdHome` des deux treuils sont analysés pour positionner `HomingMode_IHM` (1, 2 ou 3) et générer l'impulsion `StubHomeButton_IHM`.
   * Les commandes de reset treuils et grappin sont agrégées pour piloter l'acquittement machine transverse `MachineReset_IHM`.

2. **À la toute fin de l'implémentation (avant le conditionnement des sorties physiques)** :
   * Les mesures réelles, les sorties d'état automates et les sous-structures de diagnostic (`FwdContactorCheck`, etc.) sont affectées à `GVL_IHM` pour alimenter les écrans de supervision.
   * Les paramètres de calibration modifiés à l'écran (`TopSensorPositionM`, `MaxStepDescente`, `RampAccelRate`, etc.) sont recopiés vers les registres de travail de l'automate.
   * Une logique de synchronisation bidirectionnelle est mise en œuvre pour les bypasses de test (banc de simulation) afin que l'état sur l'écran d'un treuil soit cohérent avec l'état global simulation (`GVL_DEBUG`).

---

## 🔌 5. Note d'application CODESYS 3.5

1. **Création des types de données** :
   Dans le dossier `_TYPES` du projet CODESYS, ajouter les trois fichiers de structure : [ST_WinchHMI.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/ST_WinchHMI.st), [ST_GrappinHMI.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/ST_GrappinHMI.st), [ST_SyncHMI.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/ST_SyncHMI.st).

2. **Déclaration de la GVL** :
   Créer une GVL nommée `GVL_IHM` et y copier le contenu de [GVL_IHM.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/GVL_IHM.st). S'assurer de la cocher en **Retain** si requis par votre configuration automate (la directive `VAR_GLOBAL RETAIN` assure la persistance des données au niveau du compilateur).

3. **Mise à jour de PRG_MAIN** :
   Remplacer l'implémentation de `PRG_MAIN` en y collant le code mis à jour de [PRG_MAIN.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/PRG_MAIN.st).
