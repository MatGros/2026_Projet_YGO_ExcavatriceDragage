# 📋 Analyse Fonctionnelle — Partie 13 : Fonction Simulation (v1.2)

> **Projet** : Excavatrice de dragage — Automate CODESYS 3.5
> **Rôle** : Architecture unifiée de simulation banc de test (bit maître + granularité par
> device), remplaçant `GVL_DEBUG` (6 flags indépendants ajoutés au coup par coup).
> **Version** : v1.2 (Revue et alignement - 2026-07-08 : Lot #9-17/18: Joystick simulation split into `Joystick_IsReal` (CANopen communication node) and `JoystickSignal_IsReal` (raw signals). Shared top sensor simulation automatically bypasses inhibited winches).
> 🔧 **Nettoyage documentaire (audit doc, 2026-07-09)** : harmonisation titre/nom de fichier (le
> titre affichait v1.1, le champ "Version" ci-dessus était déjà en v1.2) + renvois croisés mis à
> jour vers les dernières versions des autres `AF_PartieN`. Aucun changement de contenu fonctionnel.
> **Version 1.1** (Revue et mise en œuvre du plan d'action — 2026-07-07)
> 🔗 **Dépend de** : [P2 Architecture v2.11](AF_Partie-02_Architecture_Programme_v2.11.md),
> [P3 Contrat FB v1.3](AF_Partie-03_Template_FB_Commun_v1.3.md) §1bis (briques réduites),
> [P8 Joystick v1.3](AF_Partie-08_Fonction_Joystick_v1.3.md), [P9 Winch v1.7](AF_Partie-09_Fonction_Winch_v1.10.md),
> [P11 Chariot v1.2](AF_Partie-11_Fonction_Chariot_v1.6.md) §7/§9bis.
> ⚙️ **Changements v1.1** : 
> - Déplacement de [GVL_Simulation.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/GVL_Simulation.st) vers `CODE/SIMULATION/` pour regrouper la GVL avec ses FB de simulation.
> - Extraction de la variable `BlinkClock1Hz` vers une nouvelle GVL système globale [GVL_Global.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/GVL_Global.st) dans `CODE/MAIN/`.
> - Création et câblage du bloc [FB_Sim_Safety.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/FB_Sim_Safety.st) pour simuler de manière réaliste la boucle d'AU, l'auto-test de redondance et la séquence de réarmement.

---

## 🎯 1. Rôle et contexte

Le matériel réel (bus EtherCAT/CANopen, capteurs, contacteurs) n'est pas disponible pour les
essais. Le programme doit pouvoir tourner **intégralement en simulation CODESYS** (devices hors
ligne), tout en restant testable de façon réaliste : codeurs qui comptent quand un treuil
« tourne », chariot qui se déplace, capteurs qui suivent les commandes.

Une simulation existait déjà, mais de façon organique : `GVL_DEBUG.st` empilait 6 flags
indépendants ajoutés au coup par coup, dont un (`DBG_ContactorFeedbackBypass_TEST`) surchargé sur
3 responsabilités sans rapport (bypass contacteurs+thermique, force bus EtherCAT/CANopen,
active la simulation physique des codeurs). Cette Partie 13 remplace cet empilement par un
modèle hiérarchique explicite.

**Priorité de développement** : treuils (M1/M2) + grappin + codeurs d'abord (Lots 1-3). Le
chariot M3 (translation) est couvert mais n'est pas la priorité (Lots 4-5).

---

## 🧩 2. `GVL_Simulation` — Bit maître + granularité par device

Fichier [GVL_Simulation.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/GVL_Simulation.st). État effectif « ce device est simulé » :

```
SimulationModeActive AND NOT <Device>_IsReal
```

- `SimulationModeActive` (bit maître, défaut `TRUE`) : par défaut, **tous** les devices sont
  simulés.
- Un booléen `<Device>_IsReal` par device permet de sortir CE device précis de la simulation
  un par un, au fur et à mesure du recâblage réel en mise en service — sans toucher au code.

| Variable | Device couvert |
|---|---|
| `VariateurM3_IsReal` | AC600 EtherCAT (chariot M3) |
| `EncoderM1_IsReal` / `EncoderM2_IsReal` | COD1/COD2 EtherCAT |
| `Joystick_IsReal` | CANopen JOY1 (communication et état en ligne) |
| `JoystickSignal_IsReal` | Signaux physiques bruts du Joystick (permet d'injecter des consignes simulées) |
| `EmergencyStopChain_IsReal` | Chaîne AU câblée et contacteur de puissance |
| `TopPositionSensor_IsReal` | Fin de course haut physique commun M1/M2 |
| `SlackCableSwitch_IsReal` | Mou de câble M2 |
| `PhaseRotationOk_IsReal` | Contrôle rotation phases |
| `ThermalM1_IsReal` / `ThermalM2_IsReal` | Thermique moteur M1/M2 |
| `ContactorFeedbackM1/M2/M3_IsReal` | Retours contacteurs (sens + frein) par axe |
| `ChariotPosition_IsReal` | Capteurs Fosse1/Fosse2/Maintenance/Trémie |

`JoystickForceNeutralRaw`, `JoystickForceMaxRaw` et `EncoderSimSpeedFactor` restent dans la [GVL_Simulation](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/GVL_Simulation.st). L'horloge utilitaire générique `BlinkClock1Hz` est déplacée dans [GVL_Global.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/GVL_Global.st).

⚠️ Toujours repasser `SimulationModeActive` à `FALSE` avant exploitation réelle avec la machine
effectivement câblée (ou basculer chaque `_IsReal` au fur et à mesure du recâblage).

### 🔝 Simulation dynamique du Capteur de Position Haute (TopPositionSensor)

En simulation (`TopPositionSensor_IsReal = FALSE`), l'état du capteur physique haut commun est déterminé dynamiquement par la position simulée des câbles de M1 and M2 :
```
SimTopSensorTriggered := (NOT InhibitM1 AND (CablePosM1 >= HomingTargetM1_M))
                      OR (NOT InhibitM2 AND (CablePosM2 >= HomingTargetM2_M));
```
- **Bypass sur inhibition** : Si l'un des treuils est inhibé (`InhibitM1` ou `InhibitM2` actif), sa position est automatiquement exclue du calcul de déclenchement du capteur simulé. Cela permet de simuler et de tester le homing ou les mouvements du treuil restant sans qu'un treuil inhibé (dont la position simulée pourrait être figée en butée haute) ne vienne fausser ou bloquer l'état du capteur haut commun.

---

## 🧱 3. FB de simulation (`CODE/SIMULATION/`)

Profil « brique réduite » ([Partie3 v1.3](AF_Partie-03_Template_FB_Commun_v1.3.md) §1bis) : pas de contrat `Enable`/`Reset`/`Error` complet, pas
de `StartStop`/`SafeStop` — ce sont des outils de banc, pas du métier machine.

### `FB_Sim_Safety` (Nouveau v1.1 — Simulation AU / réarmement)
Simule le comportement physique de la chaîne de sécurité AU et de l'auto-test du contacteur de puissance en simulation.
* Fichier associé : [FB_Sim_Safety.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/FB_Sim_Safety.st)
* **Entrées** :
  - `Enable` (BOOL) : Activation de la simulation.
  - `PowerCutOff_A` / `PowerCutOff_B` (BOOL) : États des relais PLC de coupure amont (`PowerCutOff_A_RQ` / `B_RQ`).
  - `EmergencyArming` (BOOL) : Impulsion de réarmement physique/IHM (`EmergencyArming_RQ`).
* **Sorties** :
  - `SimChainOk` (BOOL) : Simulation de la boucle AU fermée. Est `TRUE` si `PowerCutOff_A` et `PowerCutOff_B` sont à `TRUE` (commande maintenue fail-safe).
  - `SimContactorOk` (BOOL) : Simulation du contacteur de puissance fermé (auto-maintien). S'engage au front montant de `EmergencyArming` (si `SimChainOk` est `TRUE`) et retombe dès que `SimChainOk` repasse à `FALSE`.

### `FB_Sim_Encoder` (priorité — treuils M1/M2 + codeurs)
Fait « compter » un codeur absolu comme si le treuil tournait réellement.
* Fichier associé : [FB_Sim_Encoder.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/FB_Sim_Encoder.st)
* **Entrées** :
  - `Enable` : `SimulationModeActive AND NOT EncoderMx_IsReal`
  - `RelayFwd` / `RelayRev` : Sens commandé (contacteurs du treuil)
  - `SpeedRefPct` : Vitesse rampée courante (`instWinchMx.SpeedRamp.Current`)
  - `PresetCmd` / `PresetValue` : Preset homing (`CODx_PresettTrigCmd = 2`)

Sortie `RawPosOut` (UDINT), aiguillée à la place de la valeur EtherCAT réelle quand le device
n'est pas `Operational` (deux instances indépendantes M1/M2 dans [PRG_02_Encoders.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_02_Encoders.st)).

### `FB_Sim_Joystick` (priorité — homme-mort réel des treuils/grappin)
Simule les **entrées brutes** (`RawX`/`RawY`/`RawButton`) : le homme-mort réel de `FB_Joystick` reste
pleinement actif et doit toujours être « actionné » pour armer.
* Fichier associé : [FB_Sim_Joystick.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/FB_Sim_Joystick.st)

Instancié dans [PRG_01_Diagnostics.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_01_Diagnostics.st) avant `FB_Joystick_0` ; quand `NOT Joystick_IsReal`, ses
sorties remplacent `JoyXRaw_ANA1`/`JoyYRaw_ANA2`/`JoyBtnRaw` (via `SEL`), et le bus
CANopen (`CanOnline`/`CanOperational`) est forcé de la même façon.

### `FB_Sim_Chariot` (M3, non prioritaire)
Simulation de trajet M3 par temps de parcours — remplace le forçage manuel du capteur de
position cible en vue instance CODESYS (doc [Partie11 §9bis](AF_Partie-11_Fonction_Chariot_v1.6.md)).
* Fichier associé : [FB_Sim_Chariot.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/FB_Sim_Chariot.st)

Sorties `PosFosse1/PosFosse2/PosMaintenance/PosTremie` (BOOL), OR'ées sur `InputRaw` des
capteurs réels correspondants dans [PRG_00_Inputs.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_00_Inputs.st).

### `FB_Sim_DigitalMirror` (brique générique, utilisée pour M3, non prioritaire)
Miroir commande→retour temporisé (délai mécanique simulé) réutilisant `TON`.
* Fichier associé : [FB_Sim_DigitalMirror.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/FB_Sim_DigitalMirror.st)

---

## 🗺️ 5. Points d'aiguillage par PRG

| PRG existant | Ce qui change |
|---|---|
| [PRG_00_Inputs.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_00_Inputs.st) | Appel de `instSimSafety` ([FB_Sim_Safety](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/FB_Sim_Safety.st)) avec `PowerCutOff_A_RQ`, `PowerCutOff_B_RQ` et `EmergencyArming_RQ`. `instEmergencyStopOk` et `instEmergencyChain` sont raccordées sur ses sorties au lieu des forçages statiques. |
| [PRG_01_Diagnostics.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_01_Diagnostics.st) | `instSimJoystick` inséré avant `FB_Joystick_0`. OR de bypass Operational/WcState (EtherCAT ×3, CANopen) par device. |
| [PRG_02_Encoders.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_02_Encoders.st) | Bloc inline remplacé par 2 instances `FB_Sim_Encoder` (M1/M2 indépendantes). |
| [PRG_06_WinchControl.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_06_WinchControl.st) | `BypassContactorCheck` calculé par axe, passé à `instWinchM1`/`instWinchM2`. |
| [PRG_07_ChariotControl.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_07_ChariotControl.st) | `BypassContactorCheck` pour `instChariotM3` ; miroir contacteur M3 remplacé par `FB_Sim_DigitalMirror` (×2, Fwd/Rev). |
| [PRG_09_Supervision.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_09_Supervision.st) | Mirrors IHM pointent vers l'état effectif par device de `GVL_Simulation`. |

---

## 💡 6. Note d'application CODESYS 3.5

1. Importer la GVL globale [GVL_Global.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/GVL_Global.st) dans `CODE/MAIN/`.
2. Supprimer l'ancienne `GVL_Simulation` du dossier `MAIN` et importer [GVL_Simulation.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/GVL_Simulation.st) dans le dossier `SIMULATION`.
3. Importer le bloc [FB_Sim_Safety.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/FB_Sim_Safety.st) dans `SIMULATION`.
4. Mettre à jour [PRG_00_Inputs.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_00_Inputs.st) en remplaçant son code par la version de `CODE/MAIN/PRG_00_Inputs.st`.
5. Par défaut, `SimulationModeActive := TRUE` et tous les `_IsReal := FALSE` : le comportement est équivalent à la simulation complète, mais la boucle d'AU réagit désormais aux commandes de coupure et au réarmement de l'auto-test.
6. Pour tester le réarmement :
   - L'activation de l'impulsion `GVL_IHM.Modes.CmdEmergencyArming` démarre la séquence d'auto-test (coupe et restaure chaque canal `PowerCutOff_A_RQ` puis `B_RQ`).
   - Le bloc de simulation `FB_Sim_Safety` voit la baisse de ces signaux et fait temporairement chuter `EmergencyChain` en entrée de l'automate.
   - Si les deux étapes d'auto-test réussissent, l'impulsion `EmergencyArming_RQ` est envoyée et `FB_Sim_Safety` verrouille le contacteur `SimContactorOk` à `TRUE`.
   - L'automate reçoit la confirmation `EmergencyStopOk := TRUE` et finalise le réarmement.
