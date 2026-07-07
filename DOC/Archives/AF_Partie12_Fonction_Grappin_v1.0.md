# 📋 Analyse Fonctionnelle — Partie 12 : Fonction Grappin (v1.0)

> **Projet** : Excavatrice de dragage — Automate CODESYS 3.5  
> **Rôle** : Spécification de la fonction métier Grappin (ouverture/fermeture par désynchronisation M2) et intégration dans l'orchestration générale.  
> **Version** : v1.0 (Création - 2026-07-03)  
> 🔗 **Dépend de** : [P2 Architecture v2.7](AF_Partie2_Architecture_Programme_v2.7.md), [P3 Contrat FB v1.3](AF_Partie3_Template_FB_Commun_v1.3.md), [P4 Cycle v1.2](AF_Partie4_Cycle_Sequenceur_v1.2.md) §6, [P9 Winch v1.1](AF_Partie9_Fonction_Winch_v1.1.md) §9.

---

## 🎯 1. Rôle métier & Principe cinématique

Le grappin n'ayant pas de moteur propre, sa fermeture et son ouverture sont réalisées en modifiant la longueur relative du câble du **Treuil M2** (fermeture) par rapport au **Treuil M1** (levage/immobile) :

* **Fermeture** : Un déroulement contrôlé de M2 seul (M1 à l'arrêt) ferme les mâchoires du grappin sous l'effet du poids des coquilles.
* **Ouverture** : Un enroulement contrôlé de M2 seul (M1 à l'arrêt) rouvre les mâchoires.
* **Mouvement synchrone** : Lorsque le grappin est dans un état stable (ouvert ou fermé), toute consigne de plongée ou de remontée doit faire tourner les deux treuils ensemble (M1 + M2) en maintenant l'écart requis (offset).

---

## ⚙️ 2. Logique de commande (IHM + Joystick)

Toute modification de l'état du grappin combine une sélection sur la supervision (IHM) et une action physique de l'opérateur (Joystick) agissant comme validation homme-mort.

```
       [ IHM ]                              [ JOYSTICK ]
Demande Ouv/Ferm Grappin  ──────►  Validation physique Homme-mort (Y)  ──────►  Mouvement M2 seul
```

### A. Phase de Fermeture
1. **Sélection IHM** : L'opérateur demande la fermeture du grappin.
2. **Validation Joystick** : L'opérateur doit pousser le joystick (axe Y) vers le bas (**dérouler / descente**).
3. **Comportement treuils** :
   * Le treuil **M1 reste immobile** (`RelayFwd := FALSE`, `RelayRev := FALSE`, freins serrés).
   * Le treuil **M2 descend** en vitesse lente.
4. **Vitesse lente stricte** :
   * La vitesse doit être minimale.
   * **Aucun des 4 contacteurs de vitesse de M2 ne doit s'allumer** (`Contactor1..4 := FALSE`). Seul le sens de rotation (`RelayRev := TRUE`) et le contacteur de ligne de puissance sont enclenchés.
5. **Arrêt automatique** : Le mouvement s'arrête de lui-même dès que M2 atteint la position de fermeture cible (`CablePosM2 = CablePosM1 + OffsetClose`).
6. **Mémorisation** : Une fois la position atteinte, la logique de commande coupe le mouvement et mémorise l'état **Grappin Fermé**.

### B. Phase d'Ouverture
1. **Sélection IHM** : L'opérateur demande l'ouverture du grappin.
2. **Validation Joystick** : L'opérateur doit tirer le joystick (axe Y) vers le haut (**enrouler / montée**).
3. **Comportement treuils** :
   * Le treuil **M1 reste immobile**.
   * Le treuil **M2 monte** en vitesse lente (aucun contacteur de vitesse, juste le sens `RelayFwd := TRUE`).
4. **Arrêt automatique** : Le mouvement s'arrête dès que M2 atteint la position d'ouverture cible (`CablePosM2 = CablePosM1 + OffsetOpen`).
5. **Mémorisation** : Une fois la position atteinte, le mouvement est coupé et l'état **Grappin Ouvert** est mémorisé.

---

## ⚖️ 3. Intégration de la Synchronisation & Offsets

L'état physique du grappin modifie directement les critères de surveillance de synchronisme des deux treuils :

### A. Suspension de la Synchro en mouvement
Pendant les phases actives de fermeture ou d'ouverture (lorsque M2 bouge seul), le bloc `FB_WinchSync` doit être **désactivé** (`Enable := FALSE` ou ignoré par interlock) pour éviter les faux défauts de synchronisation.

### B. Application d'Offsets de Synchronisation
Une fois le mouvement terminé et l'état stabilisé (ouvert ou fermé), la surveillance de synchronisme se réactive mais doit intégrer l'écart de position induit :

* **Si Grappin Fermé** : L'écart surveillé devient :
  $$\Delta\text{Pos} = |\text{CablePosM1} - \text{CablePosM2} + \text{OffsetClose}|$$
* **Si Grappin Ouvert** : L'écart surveillé devient :
  $$\Delta\text{Pos} = |\text{CablePosM1} - \text{CablePosM2} + \text{OffsetOpen}|$$

Le bloc `FB_WinchSync` doit recevoir l'offset courant à appliquer (`ActiveOffsetM`) pour réaliser une comparaison correcte par rapport à la tolérance (`SyncToleranceM`).

---

## 🗂️ 4. Interface des blocs et types de données

### A. Structure de Configuration (`ST_GrappinConfig`)
```pascal
TYPE ST_GrappinConfig :
STRUCT
    OffsetOpenM     : REAL;    (* Écart M1/M2 en mètres grappin ouvert *)
    OffsetCloseM    : REAL;    (* Écart M1/M2 en mètres grappin fermé *)
    CoherenceLimitM : REAL;    (* Seuil de détection d'incohérence au boot *)
END_STRUCT
END_TYPE
```

### B. Structure d'État (`ST_GrappinState`)
```pascal
TYPE ST_GrappinState :
STRUCT
    IsOpen          : BOOL;    (* TRUE = Grappin ouvert mémorisé *)
    IsClosed        : BOOL;    (* TRUE = Grappin fermé mémorisé *)
    LastPosM2Open   : REAL;    (* Dernière position M2 mémorisée ouvert *)
    LastPosM2Close  : REAL;    (* Dernière position M2 mémorisée fermé *)
    StateIncoherent : BOOL;    (* État non sûr (divergence boot/réel) *)
END_STRUCT
END_TYPE
```

### C. Interface du bloc Grappin (`FB_Grappin`)
```pascal
(* Entrées *)
Enable              : BOOL;        // Standard
Reset               : BOOL;        // Standard (front)
EmergencyStopOk     : BOOL;        // Standard
Mode                : E_Mode;      // Standard
CmdOpen_IHM         : BOOL;        // Demande ouverture IHM
CmdClose_IHM        : BOOL;        // Demande fermeture IHM
JoystickY_StartStop : BOOL;        // Validation homme-mort (AxisCmdY.StartStop)
JoystickY_Direction : INT;         // Sens joystick (AxisCmdY.Direction)
CablePosM1          : REAL;        // Position réelle M1
CablePosM2          : REAL;        // Position réelle M2
Config              : ST_GrappinConfig; // Configuration RETAIN

(* Entrées/Sorties (VAR_IN_OUT) *)
GrappinState        : ST_GrappinState;  // État mémorisé (RETAIN)

(* Sorties *)
Ready               : BOOL;
Busy                : BOOL;
Done                : BOOL;
Error               : BOOL;
ErrorId             : WORD;        // bit0: Timeout mouvement, bit1: Incohérence boot, bit2: Limites dépassées
State               : E_State;
StateAtError        : E_State;
ActiveOffsetM       : REAL;        // Offset à injecter dans FB_WinchSync
M2_StartStop        : BOOL;        // Commande StartStop vers Winch M2
M2_Direction        : INT;         // Commande Direction vers Winch M2
M2_ForceSlowSpeed   : BOOL;        // Bloque les contacteurs de vitesse de M2
```

---

## 🔌 5. Note d'application CODESYS 3.5

1. **Persistance** : L'instance de `ST_GrappinState` et `ST_GrappinConfig` doivent être déclarées en variables persistantes (`VAR RETAIN`) dans `PRG_MAIN` pour conserver la mémoire mécanique du grappin après coupure de tension.
2. **Couplage Winch M2** : La commande de vitesse lente forcée (`M2_ForceSlowSpeed`) doit masquer la table de paliers ou forcer `MaxStepNumber := 0` ou un paramètre dédié sur le décodeur de paliers pour n'autoriser aucun contacteur de vitesse.
3. **Calcul de cohérence au boot** : Au premier cycle API, comparer `CablePosM2` avec `LastPosM2Open` ou `LastPosM2Close` (selon le dernier état mémorisé). Si l'écart dépasse `CoherenceLimitM`, forcer la sortie `StateIncoherent := TRUE` et exiger un référencement manuel.
