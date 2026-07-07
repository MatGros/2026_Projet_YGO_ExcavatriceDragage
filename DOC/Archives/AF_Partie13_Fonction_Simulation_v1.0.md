# 📋 Analyse Fonctionnelle — Partie 13 : Fonction Simulation (v1.0)

> **Projet** : Excavatrice de dragage — Automate CODESYS 3.5
> **Rôle** : Architecture unifiée de simulation banc de test (bit maître + granularité par
> device), remplaçant `GVL_DEBUG` (6 flags indépendants ajoutés au coup par coup).
> **Version** : v1.0 (Création — 2026-07-05)
> 🔗 **Dépend de** : [P2 Architecture v2.8](AF_Partie2_Architecture_Programme_v2.8.md),
> [P3 Contrat FB v1.3](AF_Partie3_Template_FB_Commun_v1.3.md) §1bis (briques réduites),
> [P8 Joystick v1.2](AF_Partie8_Fonction_Joystick_v1.2.md), [P9 Winch v1.5](AF_Partie9_Fonction_Winch_v1.5.md),
> [P11 Chariot v1.2](AF_Partie11_Fonction_Chariot_v1.2.md) §7/§9bis.

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

Fichier `CODE/MAIN/GVL_Simulation.st`. État effectif « ce device est simulé » :

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
| `Joystick_IsReal` | CANopen JOY1 |
| `EmergencyStopChain_IsReal` | Chaîne AU câblée |
| `TopPositionSensor_IsReal` | Fin de course haut commun M1/M2 |
| `SlackCableSwitch_IsReal` | Mou de câble M2 |
| `PhaseRotationOk_IsReal` | Contrôle rotation phases |
| `ThermalM1_IsReal` / `ThermalM2_IsReal` | Thermique moteur M1/M2 |
| `ContactorFeedbackM1/M2/M3_IsReal` | Retours contacteurs (sens + frein) par axe |
| `ChariotPosition_IsReal` | Capteurs Fosse1/Fosse2/Maintenance/Trémie |

`BlinkClock1Hz`, `JoystickForceNeutralRaw`, `JoystickForceMaxRaw` : utilitaires repris tels
quels de `GVL_DEBUG` (sans préfixe `DBG_`).

⚠️ Toujours repasser `SimulationModeActive` à `FALSE` avant exploitation réelle avec la machine
effectivement câblée (ou basculer chaque `_IsReal` au fur et à mesure du recâblage).

### Table de migration (ancien `GVL_DEBUG` → nouveau pilote)

| Ancien flag | Nouveau pilote | Sites migrés |
|---|---|---|
| `DBG_EmergencyStopOkBypass_TEST` | `SimulationModeActive AND NOT EmergencyStopChain_IsReal` | `PRG_00_Inputs.st` |
| `DBG_TopPositionSensorBypass_TEST` | `... AND NOT TopPositionSensor_IsReal` | `PRG_00_Inputs.st` |
| `DBG_SlackCableSwitch_TEST` | `... AND NOT SlackCableSwitch_IsReal` | `PRG_00_Inputs.st` |
| `DBG_CtrlPhaseRotation_Bypass_TEST` | `... AND NOT PhaseRotationOk_IsReal` | `PRG_00_Inputs.st` |
| `DBG_ContactorFeedbackBypass_TEST` (thermique M1/M2) | `... AND NOT ThermalM1/M2_IsReal` | `PRG_00_Inputs.st` |
| `DBG_ContactorFeedbackBypass_TEST` (StuckClosed/StuckOpen, via `BypassContactorCheck`) | `... AND NOT ContactorFeedbackM1/M2/M3_IsReal` (par axe) | `FB_Winch` (M1/M2), `FB_Chariot` (M3), `FB_Brake` |
| `DBG_ContactorFeedbackBypass_TEST` (bus Operational/WcState EtherCAT ×3 + CANopen) | `... AND NOT VariateurM3/EncoderM1/EncoderM2/Joystick_IsReal` (par device) | `PRG_01_Diagnostics.st` |
| `DBG_ContactorFeedbackBypass_TEST` (simulation physique codeurs) | `... AND NOT EncoderM1/M2_IsReal` (via `FB_Sim_Encoder.Enable`) | `PRG_02_Encoders.st` |
| `DBG_DeadmanBypass_TEST` (bypass homme-mort dans `FB_Joystick`) | **Supprimé** — remplacé par `FB_Sim_Joystick` | `FB_Joystick.st` |

`GVL_DEBUG.st` est supprimé. Les mirrors IHM (`PRG_09_Supervision.st`, `GVL_IHM.WinchM1/M2/Chariot.Bypass*`)
et le commentaire procédural de `GVL_IHM.st` référencent désormais `GVL_Simulation`.

---

## 🧱 3. FB de simulation (`CODE/SIMULATION/`)

Profil « brique réduite » (Partie3 §1bis) : pas de contrat `Enable`/`Reset`/`Error` complet, pas
de `StartStop`/`SafeStop` — ce sont des outils de banc, pas du métier machine.

### `FB_Sim_Encoder` (priorité — treuils M1/M2 + codeurs)
Extraction pure de la logique déjà en place dans `PRG_02_Encoders.st` (aucun changement de
comportement). Fait « compter » un codeur absolu comme si le treuil tournait réellement.

| Entrée | Rôle |
|---|---|
| `Enable` | `SimulationModeActive AND NOT EncoderMx_IsReal` |
| `RelayFwd` / `RelayRev` | Sens commandé (contacteurs du treuil) |
| `SpeedRefPct` | Vitesse rampée courante (`instWinchMx.SpeedRamp.Current`) |
| `PresetCmd` / `PresetValue` | Preset homing (`CODx_PresettTrigCmd = 2`) |

Sortie `RawPosOut` (UDINT), aiguillée à la place de la valeur EtherCAT réelle quand le device
n'est pas `Operational` (deux instances indépendantes M1/M2 dans `PRG_02_Encoders.st`).

### `FB_Sim_Joystick` (priorité — homme-mort réel des treuils/grappin)
Remplace l'ancien bypass homme-mort codé en dur dans `FB_Joystick` (`DBG_DeadmanBypass_TEST`,
qui forçait `DeadmanArmed` en permanence — un vrai contournement de sécurité). Simule les
**entrées brutes** (`RawX`/`RawY`/`RawButton`) : le homme-mort réel de `FB_Joystick` reste
pleinement actif et doit toujours être « actionné » pour armer.

Instancié dans `PRG_01_Diagnostics.st` avant `FB_Joystick_0` ; quand `NOT Joystick_IsReal`, ses
sorties remplacent `JoyXRaw_ANA1`/`JoyYRaw_ANA2`/`JoyBtnRaw` (via `SEL`), et le bus
CANopen (`CanOnline`/`CanOperational`) est forcé de la même façon.

`FB_Grappin` (`CODE/GRAPPIN/FB_Grappin.st`) n'a **aucun capteur physique propre** — il dérive
tout de `CablePosM1`/`CablePosM2` (sorties `FB_Encoder_Scale`, alimentées par `FB_Sim_Encoder`) et
de `JoystickY_StartStop`/`Direction`. Il est donc déjà entièrement couvert par
`FB_Sim_Encoder` + `FB_Sim_Joystick`, sans FB dédié.

### `FB_Sim_Chariot` (M3, non prioritaire)
Simulation de trajet M3 par temps de parcours — remplace le forçage manuel du capteur de
position cible en vue instance CODESYS (doc Partie11 §9bis).

| Entrée | Rôle |
|---|---|
| `Enable` | `SimulationModeActive AND NOT ChariotPosition_IsReal` |
| `TargetNum` | Cible sélectionnée (`GVL_Chariot_M3_Stub.StubChariotPositionSelect_IHM`) |
| `RelayFwd` / `RelayRev` | Sens commandé |
| `TravelTimeS` | Temps de trajet simulé — **8.0s** (milieu de la fourchette 5-10s validée utilisateur) |

Sorties `PosFosse1/PosFosse2/PosMaintenance/PosTremie` (BOOL), OR'ées sur `InputRaw` des
capteurs réels correspondants dans `PRG_00_Inputs.st`. Changement de cible = trajet remis à
zéro ; relais retombés = progression en pause (pas de reset).

### `FB_Sim_DigitalMirror` (brique générique, utilisée pour M3, non prioritaire)
Miroir commande→retour temporisé (délai mécanique simulé), au lieu du miroir instantané
inconditionnel précédent. Réutilise `TON` (Partie3 §0). Utilisée pour le retour contacteur M3
dans `PRG_07_ChariotControl.st` (`MirrorDelay := T#150ms`, nettement sous le
`ContactorFeedbackTimeout` de 500ms pour ne pas déclencher StuckClosed/StuckOpen à tort).

---

## 🔌 4. `BypassContactorCheck` — granularité par axe pour StuckClosed/StuckOpen

`FB_Winch` et `FB_Chariot` sont **instanciés par axe** (M1/M2/M3) mais partagent le même corps
ST : ils ne peuvent pas déterminer leur propre axe en lisant `GVL_Simulation` directement. Un
nouveau `VAR_INPUT BypassContactorCheck : BOOL` a donc été ajouté à `FB_Winch` (et `FB_Brake`,
composé en interne par `FB_Winch`/`FB_Chariot`), calculé par l'appelant :

```
// PRG_06_WinchControl.st (instWinchM1)
BypassContactorCheck := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM1_IsReal

// PRG_07_ChariotControl.st (instChariotM3)
BypassContactorCheck := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM3_IsReal
```

Chaque instance reçoit ainsi l'état effectif de **son propre axe**, permettant de sortir M1 de la
simulation sans affecter M2 ou M3.

---

## 🗺️ 5. Points d'aiguillage par PRG

| PRG existant | Ce qui change |
|---|---|
| `PRG_00_Inputs.st` | OR de bypass sensoriel (EmergencyStopOk, SlackCableSwitch, TopPositionSensor, CtrlPhaseRotation, thermique M1/M2) suivent la table de migration. `instSimChariot` (`FB_Sim_Chariot`) + 4 OR sur `PosFosse1/2/Maintenance/Tremie_DI`. |
| `PRG_01_Diagnostics.st` | `instSimJoystick` inséré avant `FB_Joystick_0`. OR de bypass Operational/WcState (EtherCAT ×3, CANopen) par device. |
| `PRG_02_Encoders.st` | Bloc inline remplacé par 2 instances `FB_Sim_Encoder` (M1/M2 indépendantes). |
| `PRG_06_WinchControl.st` | `BypassContactorCheck` calculé par axe, passé à `instWinchM1`/`instWinchM2`. |
| `PRG_07_ChariotControl.st` | `BypassContactorCheck` pour `instChariotM3` ; miroir contacteur M3 remplacé par `FB_Sim_DigitalMirror` (×2, Fwd/Rev). |
| `PRG_09_Supervision.st` | Mirrors IHM (`GVL_IHM.WinchM1/M2/Chariot.Bypass*`) pointent vers l'état effectif par device. |
| `GVL_IHM.st` | Commentaire « procédure de test sur banc » mis à jour (noms `GVL_Simulation.*`). |

---

## 💡 6. Note d'application CODESYS 3.5

1. Importer `GVL_Simulation.st` (nouveau GVL), les 4 FB de `CODE/SIMULATION/` (nouveau dossier
   projet), puis réimporter les POU modifiés (`PRG_00_Inputs`, `PRG_01_Diagnostics`,
   `PRG_02_Encoders`, `PRG_06_WinchControl`, `PRG_07_ChariotControl`, `PRG_09_Supervision`,
   `FB_Joystick`, `FB_Winch`, `FB_Chariot`, `FB_Brake`, `GVL_IHM`).
2. Supprimer `GVL_DEBUG` du projet CODESYS une fois tous les sites réimportés.
3. Par défaut, `SimulationModeActive := TRUE` et tous les `_IsReal := FALSE` : comportement
   équivalent à l'ancien `GVL_DEBUG` avec tous les bypass actifs.
4. Pour sortir UN device de la simulation pendant la mise en service (ex. chaîne AU
   effectivement câblée) : forcer `GVL_Simulation.EmergencyStopChain_IsReal := TRUE` en vue
   instance, sans toucher au reste.
5. Pour simuler le joystick : forcer `PRG_01_Diagnostics.instSimJoystick.RawX/RawY/RawButton` en
   vue instance (le homme-mort réel doit être « actionné » via `RawButton`, plus de bypass).

## ✅ 7. Vérification

- **Lot 1** : comportement identique à avant (pas de régression) — reproduire la procédure de
  test de `GVL_IHM.st` (mouvement treuils, homing, grappin) avec les nouveaux noms.
- **Lot 2** : le codeur M1/M2 compte bien quand `RelayFwd`/`RelayRev` est actif, s'arrête à 0.
- **Lot 3** : le homme-mort réel s'arme/désarme avec le joystick simulé (plus de bypass) ; le
  grappin répond correctement au joystick Y avec `CablePosM1/M2` simulés.
- **Lot 4** : le chariot atteint la bonne position après `TravelTimeS` (8.0s), sans forçage
  manuel en vue instance.
- **Lot 5** : retour contacteur M3 cohérent avec la commande (délai 150ms), sans déclencher
  StuckClosed/StuckOpen.
