> # ⛔ DOCUMENT PÉRIMÉ — NE PAS S'Y FIER (2026-07-27)
>
> L'architecture décrite ci-dessous **n'existe plus dans le code**. Ont été supprimés :
> `GVL_PLC_Tests` et ses 20 `Override*` · `FB_Sim_DigitalMirror` · les 25 flags `*IsReal`
> (double négation) · les 8 conditions `DI OR (SimulationModeActive AND NOT …IsReal)` ·
> les instances `FB_Sim_*` dispersées dans 8 programmes.
>
> **Architecture réelle (commits `72a3bbc`, `4817c0b`)** : toutes les entrées matérielles sont
> acquises en **un seul endroit** (`PRG_00_Inputs` §0) dans une image unique `HwIn`
> (`ST_HardwareImage`). La simulation se rebranchera **derrière cette frontière** (lot L6) :
> 1 bit maître + 4 domaines en polarité positive, `FB_SimBench`, 4 `IF` d'aiguillage par
> domaine entier.
>
> 👉 **Référence à jour** : [`AUDITS/PreLivraison/PLAN_Rationalisation_Simulation_v1.0.md`](AUDITS/PreLivraison/PLAN_Rationalisation_Simulation_v1.0.md)
> et les fiches `AUDITS/PreLivraison/TASKS/`.
> 📌 **Ce document sera remplacé par `AF_Partie-13 v2.0` au lot L8**, une fois L6 et L7 appliqués.

# 📋 Analyse Fonctionnelle — Partie 13 : Fonction Simulation (v1.4)

> **Projet** : Excavatrice de dragage — Automate CODESYS 3.5
> **Rôle** : Architecture unifiée de simulation banc de test (bit maître + granularité par
> device), remplaçant `GVL_DEBUG` (6 flags indépendants ajoutés au coup par coup).
> **Version** : v1.4 (REX 2026-07-26 — retrait du framework de tests automatiques in-PLC
> [`PLC_TESTS`, archivé `ARCHIVES/Code/PLC_TESTS/`] : `GVL_PLC_Tests` est réduite à ses 20
> `Override*`, désormais des **forçages manuels** [vue instance CODESYS, et IHM pour les 5
> capteurs position M3 via `PRG_09_Supervision`]. Plus aucun automate ne les pilote. La
> non-régression passe par la simulation manuelle et les essais FAT/SAT).
> **Version 1.3** (REX 2026-07-22 — `SimulationModeActive` par défaut `FALSE` [machine réelle
> par défaut] ; bypass diagnostic CANopen/EtherCAT/Heartbeat IHM **découplé** du bit maître, piloté
> désormais SEUL par son `Bus<Device>IsReal`, pour rester actif banc sans bus/IHM câblés même
> simulation globale coupée).
> **Version 1.2** (Revue et alignement - 2026-07-08 : Lot #9-17/18: Joystick simulation split into
> `Joystick_IsReal` (CANopen communication node) and `JoystickSignal_IsReal` (raw signals). Shared
> top sensor simulation automatically bypasses inhibited winches).
> **Version 1.1** (Revue et mise en œuvre du plan d'action — 2026-07-07)
> 🔗 **Dépend de** : [P2 Architecture v2.12](AF_Partie-02_Architecture_Programme_v2.12.md),
> [P3 Contrat FB v1.3](AF_Partie-03_Template_FB_Commun_v1.3.md) §1bis (briques réduites),
> [P8 Joystick v1.3](AF_Partie-08_Fonction_Joystick_v1.3.md), [P9 Winch v1.7](AF_Partie-09_Fonction_Winch_v1.12.md),
> [P11 Translation v1.11](AF_Partie-11_Fonction_Translation_v1.11.md) §3bis/§7/§9bis.

---

## 🎯 1. Rôle et contexte

Le matériel réel (bus EtherCAT/CANopen, capteurs, contacteurs) n'est pas disponible pour les
essais. Le programme doit pouvoir tourner **intégralement en simulation CODESYS** (devices hors
ligne), tout en restant testable de façon réaliste : codeurs qui comptent quand un treuil
« tourne », translation qui se déplace, capteurs qui suivent les commandes.

Une simulation existait déjà, mais de façon organique : `GVL_DEBUG.st` empilait 6 flags
indépendants ajoutés au coup par coup, dont un (`DBG_ContactorFeedbackBypass_TEST`) surchargé sur
3 responsabilités sans rapport (bypass contacteurs+thermique, force bus EtherCAT/CANopen,
active la simulation physique des codeurs). Cette Partie 13 remplace cet empilement par un
modèle hiérarchique explicite.

**Priorité de développement** : treuils (M1/M2) + benne + codeurs d'abord (Lots 1-3). Le
translation M3 (translation) est couvert mais n'est pas la priorité (Lots 4-5).

---

## 🧩 2. `GVL_Simulation` — Bit maître + granularité par device

Fichier [GVL_Simulation.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/GVL_Simulation.st). État effectif « ce device est simulé » (devices §2bis exclus, voir plus bas) :

```
SimulationModeActive AND NOT <Device>_IsReal
```

- `SimulationModeActive` (bit maître, **défaut `FALSE` depuis REX 2026-07-22**) : par défaut, la
  machine se comporte comme réelle (aucun device forcé sain). Passer à `TRUE` pour rebasculer TOUS
  les devices en simulation d'un coup (banc d'essai complet sans aucun matériel).
- Un booléen `<Device>_IsReal` par device permet de sortir CE device précis de la simulation
  un par un, au fur et à mesure du recâblage réel en mise en service — sans toucher au code.

| Variable | Device couvert |
|---|---|
| `VariateurM3_IsReal` | AC600 EtherCAT (translation M3) — bypass diag §2bis, découplé du bit maître |
| `EncoderM1_IsReal` / `EncoderM2_IsReal` | COD1/COD2 EtherCAT — bypass diag §2bis, découplé du bit maître |
| `Joystick_IsReal` | CANopen JOY1 (communication et état en ligne) — bypass diag §2bis, découplé du bit maître |
| `JoystickSignal_IsReal` | Signaux physiques bruts du Joystick (permet d'injecter des consignes simulées) — reste gardé par le bit maître |
| `IhmHeartbeat_IsReal` | Heartbeat IHM↔PLC (`TglHeartbeatIhm`) — bypass §2bis, découplé du bit maître |
| `EmergencyStopChain_IsReal` | Chaîne AU câblée et contacteur de puissance |
| `TopPositionSensor_IsReal` | Fin de course haut physique commun M1/M2 |
| `SlackCableSwitch_IsReal` | Mou de câble M2 |
| `PhaseRotationOk_IsReal` | Contrôle rotation phases |
| `ThermalM1_IsReal` / `ThermalM2_IsReal` | Thermique moteur M1/M2 |
| `ContactorFeedbackM1/M2/M3_IsReal` | Retours contacteurs (sens + frein) par axe |
| `TranslationPosition_IsReal` | Capteurs Trémie/PV/P2/P1/Maintenance |

`JoystickForceNeutralRaw`, `JoystickForceMaxRaw` et `EncoderSimSpeedFactor` restent dans la [GVL_Simulation](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/GVL_Simulation.st). L'horloge utilitaire générique `BlinkClock1Hz` est déplacée dans [GVL_Global.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/GVL_Global.st).

⚠️ Pour les devices **hors §2bis**, toujours repasser `SimulationModeActive` à `FALSE` avant
exploitation réelle avec la machine effectivement câblée (ou basculer chaque `_IsReal` au fur et
à mesure du recâblage).

### 🆕 2bis. Bypass diagnostic bus/communication — DÉCOUPLÉ du bit maître (REX 2026-07-22)

Constat : `SimulationModeActive := FALSE` (nouveau défaut) fait « tout redevenir réel d'un coup »,
y compris les diagnostics CANopen/EtherCAT/Heartbeat IHM — alors que ces 3 sujets peuvent rester
non câblés indépendamment de la volonté de sortir des autres devices (capteurs, contacteurs,
position codeur simulée) du mode banc. Sans découplage, couper le bit maître bloque tout
mouvement (`HeartbeatIhmOk`/`JoystickOnline`/`JoystickOperational` → `FALSE`) même si le bus
physique réel est sain, ou même s'il n'est simplement pas encore câblé sur ce banc précis.

Pour ces **4 signaux de diagnostic uniquement**, la condition de bypass dans
[PRG_01_Diagnostics.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_01_Diagnostics.st) est désormais :

```
NOT Bus<Device>IsReal        (au lieu de SimulationModeActive AND NOT Bus<Device>IsReal)
```

| Variable (seule pilote le bypass) | Signal bypassé |
|---|---|
| `BusJoystickIsReal` | `CANbusOnline` + `DeviceJoystickOnline` (CANopen) |
| `BusVariateurM3IsReal` | `DeviceVariateurOnline` + `DeviceVariateurState` (EtherCAT AC600) |
| `BusEncoderM1IsReal` | `DeviceEncoderM1Online` + `DeviceEncoderM1State` (EtherCAT COD1) |
| `BusEncoderM2IsReal` | `DeviceEncoderM2Online` + `DeviceEncoderM2State` (EtherCAT COD2) |
| `BusIhmHeartbeatIsReal` | `TglHeartbeatIhm` (toggle IHM, sinon `GVL_Global.BlinkClock`) |

Ces 5 flags sont **déjà `FALSE` par défaut** dans `GVL_Simulation.st` → comportement inchangé
tant qu'on ne les bascule pas explicitement, **même avec `SimulationModeActive := FALSE`**.

👉 **Ce qui reste gardé par le bit maître** (non concerné par ce découplage) : simulation physique
des codeurs (`FB_Sim_Encoder`, position/comptage), signal joystick brut (`FB_Sim_Joystick`,
`JoystickSignal_IsReal`), chaîne AU (`FB_Sim_Safety`), capteurs/contacteurs, translation M3
(`FB_Sim_Translation`). Pour ces devices, `SimulationModeActive := FALSE` désactive bien toute la
simulation associée (comportement d'origine, inchangé).

⚠️ **Test de non-régression obligatoire après import** (🔧 v1.4 : la suite automatique
`FB_HeartbeatValidation` n'existe plus, à rejouer **manuellement**) : forcer
`GVL_PLC_Tests.OverrideIhmHeartbeatActive := TRUE` puis figer `OverrideIhmHeartbeatToggle`
→ le timeout heartbeat doit tomber ; le refaire basculer → retour sain. Vérifier aussi les modes
touchant `JoystickOnline`/`JoystickOperational`, pour confirmer que le comportement fonctionnel
est inchangé à `Bus*IsReal` constant — seul le déclencheur (bit maître retiré) a changé.

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

⚠️ Ce FB reste gardé par `SimulationModeActive` (§2bis ne le concerne pas) : bit maître à `FALSE`
= plus de comptage simulé. Si `BusEncoderM1IsReal` bypass le diagnostic (§2bis) sans encodeur réel
câblé, la position affichée reste figée (dernière valeur) — bypass diagnostic ≠ simulation physique.

### `FB_Sim_Joystick` (priorité — homme-mort réel des treuils/benne)
Simule les **entrées brutes** (`RawX`/`RawY`/`RawButton`) : le homme-mort réel de `FB_Joystick` reste
pleinement actif et doit toujours être « actionné » pour armer.
* Fichier associé : [FB_Sim_Joystick.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/FB_Sim_Joystick.st)

Instancié dans [PRG_01_Diagnostics.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_01_Diagnostics.st) avant `FB_Joystick_0` ; quand `NOT Joystick_IsReal`, ses
sorties remplacent `JoyXRaw_ANA1`/`JoyYRaw_ANA2`/`JoyBtnRaw` (via `SEL`). Le bus CANopen
(`CanOnline`/`CanOperational`) suit désormais §2bis (`BusJoystickIsReal` seul, découplé du bit
maître) — plus de `SimulationModeActive` dans cette condition-là.

### `FB_Sim_Translation` (M3, non prioritaire)
Simulation de trajet M3 par temps de parcours — remplace le forçage manuel du capteur de
position cible en vue instance CODESYS (doc [Partie11 §9bis](AF_Partie-11_Fonction_Translation_v1.11.md)).
* Fichier associé : [FB_Sim_Translation.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/FB_Sim_Translation.st)

Sorties `PosTremie/PosPV/PosP2/PosP1/PosMaintenance` (BOOL), OR'ées sur `InputRaw` des
capteurs réels correspondants dans [PRG_00_Inputs.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_00_Inputs.st).
La simulation respecte le codage croisé monotone : `11111` (Trémie), `01111` (PV),
`00111` (P2), `00011` (P1), `00001` (approche Maintenance), `00000` (Maintenance).
Aucun état intermédiaire incohérent ne doit être généré par le banc de test.

### `FB_Sim_DigitalMirror` (brique générique, utilisée pour M3, non prioritaire)
Miroir commande→retour temporisé (délai mécanique simulé) réutilisant `TON`.
* Fichier associé : [FB_Sim_DigitalMirror.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/FB_Sim_DigitalMirror.st)

---

## 🗺️ 5. Points d'aiguillage par PRG

| PRG existant | Ce qui change |
|---|---|
| [PRG_00_Inputs.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_00_Inputs.st) | Appel de `instSimSafety` ([FB_Sim_Safety](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/FB_Sim_Safety.st)) avec `PowerCutOff_A_RQ`, `PowerCutOff_B_RQ` et `EmergencyArming_RQ`. `instEmergencyStopOk` et `instEmergencyChain` sont raccordées sur ses sorties au lieu des forçages statiques. |
| [PRG_01_Diagnostics.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_01_Diagnostics.st) | `instSimJoystick` inséré avant `FB_Joystick_0`. Bypass diag CANopen/EtherCAT ×3/Heartbeat IHM **découplé** du bit maître (§2bis, REX 2026-07-22). |
| [PRG_02_Encoders.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_02_Encoders.st) | Bloc inline remplacé par 2 instances `FB_Sim_Encoder` (M1/M2 indépendantes). |
| [PRG_06_WinchControl.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_06_WinchControl.st) | `BypassContactorCheck` calculé par axe, passé à `instWinchM1`/`instWinchM2`. |
| [PRG_07_TranslationControl.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_07_TranslationControl.st) | `BypassContactorCheck` pour `instTranslationM3` ; miroir contacteur M3 remplacé par `FB_Sim_DigitalMirror` (×2, Fwd/Rev). |
| [PRG_09_Supervision.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_09_Supervision.st) | Mirrors IHM pointent vers l'état effectif par device de `GVL_Simulation`. |

---

## 💡 6. Note d'application CODESYS 3.5

**Modifs REX 2026-07-22 (v1.3)** — objets existants à mettre à jour, pas de nouvel objet :

1. `GVL_Simulation` : changer la valeur d'initialisation de `SimulationModeActive` de `TRUE` à
   `FALSE`.
2. `PRG_01_Diagnostics` : remplacer le corps de `instDiagCanOpen(...)`, `instDiagEthercat(...)`
   et `instIhmHeartbeat(...)` par la version à jour de
   [PRG_01_Diagnostics.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/PRG_01_Diagnostics.st) (retire `GVL_Simulation.SimulationModeActive AND` des 9 conditions de bypass CANopen/EtherCAT/Heartbeat).
3. **Import complet possible via** `CODE/CODE_Bundle.xml` (régénéré) — Project → Import PLCopenXML.
4. Après import : `BusJoystickIsReal`, `BusVariateurM3IsReal`, `BusEncoderM1IsReal`,
   `BusEncoderM2IsReal`, `BusIhmHeartbeatIsReal` restent à `FALSE` par défaut → comportement
   inchangé au premier démarrage (bypass toujours actif), même si `SimulationModeActive = FALSE`.
5. **Non-régression** : rejouer **manuellement** le scénario heartbeat via
   `GVL_PLC_Tests.OverrideIhmHeartbeatActive`/`OverrideIhmHeartbeatToggle` (🔧 v1.4 : la suite
   automatique a été archivée) avant toute validation fonctionnelle du lot.

---

**Points d'application antérieurs (v1.1, toujours valables)** :

1. Importer la GVL globale [GVL_Global.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/MAIN/GVL_Global.st) dans `CODE/MAIN/`.
2. Supprimer l'ancienne `GVL_Simulation` du dossier `MAIN` et importer [GVL_Simulation.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/GVL_Simulation.st) dans le dossier `SIMULATION`.
3. Importer le bloc [FB_Sim_Safety.st](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/CODE/SIMULATION/FB_Sim_Safety.st) dans `SIMULATION`.
4. Pour tester le réarmement :
   - L'activation de l'impulsion `GVL_IHM.Modes.CmdEmergencyArming` démarre la séquence d'auto-test (coupe et restaure chaque canal `PowerCutOff_A_RQ` puis `B_RQ`).
   - Le bloc de simulation `FB_Sim_Safety` voit la baisse de ces signaux et fait temporairement chuter `EmergencyChain` en entrée de l'automate.
   - Si les deux étapes d'auto-test réussissent, l'impulsion `EmergencyArming_RQ` est envoyée et `FB_Sim_Safety` verrouille le contacteur `SimContactorOk` à `TRUE`.
   - L'automate reçoit la confirmation `EmergencyStopOk := TRUE` et finalise le réarmement.
