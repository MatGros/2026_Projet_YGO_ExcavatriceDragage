# 🗺️ Cartographie des flux IHM → Actionneurs (v1.0 — 2026-07-24)

> 🎯 **But** : tracer, pour chaque actionneur (M1, M2, M3), le chemin complet **bouton/joystick IHM → arbitrage →
> FB de mouvement → sécurité → sortie physique**, avec TOUS les contrôles traversés. Objectif : préparer les
> futures modifs, accélérer le débogage, homogénéiser les patterns entre métiers.
>
> ⚠️ Document **d'analyse / lecture seule** : aucune modification de `CODE/` n'a été faite pour le produire.
> Il **décrit** l'état actuel du code (session 2026-07-24), il ne le change pas.
>
> 📄 Périmètre analysé : `PRG_00_Inputs`, `PRG_03_Safety`, `PRG_04_Modes`, `PRG_06_WinchControl`,
> `PRG_07_TranslationControl`, `PRG_08_AuxiliaryControl`, `PRG_09_Supervision`, `PRG_10_Outputs`,
> `FB_Joystick`, `FB_Winch`, `FB_Translation`, `FB_Bucket`, `FB_Safety_Winch`, `FB_Safety_Translation`,
> `FB_WinchSync`, `FB_SpeedStep`, `FB_Brake`, `FB_Ramp`, `FB_AxisScale`, `FB_Modes`.
>
> 🧭 À lire avec : `DOC/AF_Partie-02_Architecture_Programme_v2.12.md` (ordre des tâches),
> `DOC/AF_Partie-03_Template_FB_Commun_v1.3.md` (contrat FB), `DOC/NAVBOARDS/` (mémos terrain).

---

## 0. Ordre d'exécution (rappel — 1 scan MainTask 10 ms)

```
PRG_00_Inputs        → acquisition capteurs + décodage mot capteurs M3 + purge IHM au boot
PRG_01_Diagnostics    → FB_Joystick (Hall + homme-mort), diag bus CAN/EtherCAT, heartbeat IHM
PRG_02_Encoders       → FB_Encoder_Abs/Scale/Homing M1/M2 (position câble en mètres)
PRG_03_Safety         → FB_Safety_Winch M1/M2, FB_Safety_Translation (surveillance métier)
PRG_04_Modes          → FB_Modes (arbitrage Mode, SyncEnable, InhibitM1/M2, HomingApproachEnable...)
PRG_05_Cycle          → séquenceur SEMI_AUTO (consignes auto vers PRG_06/07)
PRG_06_WinchControl   → arbitrage M1/M2/Benne, appel FB_Bucket, instWinchM1/M2, FB_WinchSync
PRG_07_TranslationControl → arbitrage M3, appel instTranslationM3 (FB_Translation)
PRG_08_AuxiliaryControl   → diagnostic thermique centrale hydraulique (aucune commande)
PRG_09_Supervision    → mapping GVL_IHM ↔ code, FaultMachineReset_IHM, horloge clignotement
PRG_10_Outputs        → écriture FB_Output (I/O réels), Safety_EmergencyManagement, PowerCutOff
```

⚠️ Un FB appelé en position N lit les sorties d'un FB en position N+k **du scan précédent** (retard
d'1 cycle = 10 ms). Les fichiers signalent ces cas avec `🆕 REX ... 1 cycle de retard` — sans
gravité tant que la grandeur évolue progressivement (position codeur), mais jamais sur un front
sécurité critique (voir §4 "retards d'1 scan assumés").

---

## 1. Flux M3 — Translation (bouton IHM "Marche avant" MAINT_N1/N2)

### 1.1 Schéma résumé

```
GVL_IHM.TranslationM3.Cmd.BtnFwd (IHM)
        │
        ▼
PRG_07_TranslationControl §1bis (arbitrage MAINT_N1/N2)
   ├─ gate Mode (SEMI_AUTO / MAINT_N1-N2 / Manuel)
   ├─ Direction_Active := +1 (BtnFwd, TglJoystickMaster=FALSE)
   ├─ StartStop_Active := Direction<>0
   │                      AND (DeadmanArmed OR Bypass.Global)     ← homme-mort OBLIGATOIRE
   │                      AND (NOT TglJoystickMaster OR AxisCmdX.StartStop)
   ├─ SpeedRef_Active := FreqPct (SetFreq_Hz / _TranslationMaxFreq_Hz *100, def. 30% si 0)
   ├─ InvertDirection (mise en service) applique un signe -1 supplémentaire
   ├─ LIMIT(0..100%) final (garde-fou toutes sources)
   ├─ MaintenanceM3TargetEnable (cible 4 bloquée hors MAINT_N2, arbitré dans FB_Modes)
   └─ PositionSensorTarget (capteur cible réel, CASE SelTarget)
        │
        ▼
instTranslationM3 (FB_Translation) — FB DE MOUVEMENT
   ├─ 1. GATE Enable AND EmergencyStopOk → sinon sorties nulles (DriveControlWord=0, freq=0)
   │      Enable = StubMachineEnableN1 AND (Mode <> DISABLE)
   ├─ 2. Reset (front) → efface bits ErrorId dont la cause a disparu
   ├─ 3. Debounce capteur position cible (CaptorDebounce 100ms) → TargetReached
   ├─ 4. RAMPE (arbitrage Enable > SafeStop > StartStop) :
   │      RampTargetPct = SpeedRefPct SAUF SI :
   │        - SafeStop=TRUE (FB_Safety_Translation) → cible 0, décél RAPIDE
   │        - fin de course extrême dans le sens demandé (LimitSwitchFwd/Rev, sauf Bypass) → 0
   │      + ralentissement auto (SlowdownSensor=PV, uniquement Direction=1, vers ApproachSpeedPct)
   │      + arrêt exact sur capteur cible (ArrivalLock, verrouille tant que capteur actif)
   ├─ 5. INTERLOCK changement de sens (jamais Fwd+Rev simultané, vitesse confirmée nulle sauf 1er engagement)
   ├─ 5bis. DriveFreqRefHz = rampe courante × DriveFreqScaleMaxHz / 100
   │        DriveControlWord = 1(Fwd)/2(Rev)/7(Reset)/0(arrêt) — coupure immédiate si Fdc extrême atteint
   ├─ 6. FB_Brake (séquence frein, temps physiques : fermeture contacteur → magnétisation → relâche)
   └─ 7. ErrorId bitfield (bit0 frein, bit3 défaut variateur DriveStatusWord.4, bit6 Fdc extrême)
        │
        ▼
PRG_10_Outputs
   ├─ M3_CommandWord := instTranslationM3.DriveControlWord   (PDO EtherCAT, mot de commande AC600)
   ├─ M3_SetpointFrequencyHz := DriveFreqRefHz × 100          (PDO EtherCAT, consigne fréquence)
   ├─ instTranslationBrakeCmd(Command := TranslationBrakeCmd) → M3_BrakeCmd_RQ (sortie TOR frein)
   └─ M3_RelayFwd_DQ / M3_RelayRev_DQ forcés FALSE (obsolètes, pilotage 100% EtherCAT)
        │
        ▼
   VARIATEUR AC600 (EtherCAT) — reçoit ControlWord+FreqRef, applique couple/vitesse au moteur M3
   FREIN M3 (bobine, manque de courant) — reçoit BrakeCmd, colle si non alimenté
```

### 1.2 Sécurité traversée (couche PRG_03_Safety → FB_Safety_Translation)

`SafeStop` (entrée FB_Translation) est calculé en continu, indépendamment de l'arbitrage §1.1, par
`instSafetyTranslationM3` :

| bit | Cause | Portée |
|---|---|---|
| 0 | Perte communication opérateur (joystick CAN / heartbeat IHM) | SafeStop |
| 1 | Perte communication EtherCAT variateur | SafeStop |
| 2 | Rotation de phase incorrecte | SafeStop |
| 3 | Surchauffe/perte thermique frein (commun M1/M2/M3) | SafeStop + **PowerCutOff** |
| 4 | Méca B — pas de confirmation arrêt (variateur/frein) sous 3s | SafeStop + **PowerCutOff** |
| 5 | Méca A — mouvement non commandé détecté (fréquence mesurée >0.5Hz à l'arrêt) | SafeStop + **PowerCutOff** |
| 6 | Fin de course extrême atteinte | SafeStop + **PowerCutOff** |
| 7 | Incohérence mot des 5 capteurs position | SafeStop + **PowerCutOff** |

`SafeStop := Error OR NOT EmergencyStopOk` — **tout bit met en SafeStop**, contrairement à
`FB_Safety_Winch` où seuls certains bits participent (voir §2.2). `PowerCutOff` agit sur
`PRG_10_Outputs.PowerCutOffReq` → coupe la puissance amont (redondant Série A/B), indépendamment de
tout arbitrage logiciel M3.

### 1.3 Décodage capteurs position (en amont, PRG_00_Inputs position 0)

`FB_Translation_PositionDecoder` assemble les 5 capteurs (Trémie/PV/P2/P1/Maintenance) en un mot
5 bits, valide **uniquement** les 6 combinaisons de progression monotone (11111→...→00000). Toute
autre combinaison lève `Incoherent` → remonte en `SensorWordIncoherent` (Safety bit7) **et**
neutralise `LimitSwitchFwd/Rev` (pas de Fdc fantôme sur mot incohérent).

---

## 2. Flux M1/M2 — Treuils (joystick ou boutons IHM MAINT_N1/N2)

### 2.1 Schéma résumé (M1, symétrique pour M2 avec inversions de signe documentées)

```
Joystick axe Y (RawY) ou GVL_IHM.M1TreuilRetenue.Cmd.BtnUp/BtnDown
        │
        ▼
FB_Joystick (PRG_01_Diagnostics, AVANT PRG_06 dans l'ordre de tâche)
   ├─ GATE (Enable, EmergencyStopOk, bus CAN Operational)
   ├─ Calibration dynamique (NeutralXMem/YMem, RETAIN)
   ├─ FB_AxisScale (deadband 10%, LIMIT ±100%)
   ├─ 🔴 HOMME-MORT (DeadmanArmed) :
   │     - Armement : appui bouton AU NEUTRE (ScaleX/Y.OutPct = 0.0)
   │     - Désarmement : neutre tenu 500ms (NeutralHoldTime, après geste démarré)
   │     - Reconfirmation : bouton maintenu OU réappuyé avant 10s (DeadmanRearmTimeout)
   │     - Désarmement forcé : changement de Mode, fin de cycle benne (front descendant Busy)
   ├─ FB_Filter_PT1 (lissage 100ms) → FB_Ramp (accel 50%/s, décel 150%/s)
   └─ AxisCmdY.SpeedRef (signé) / .Direction (-1/0/+1) / .StartStop (magnitude>0.1)
        │
        ▼
PRG_06_WinchControl §0-2 (arbitrage, ORDRE D'APPEL CRITIQUE : Benne appelé EN PREMIER)
   ├─ instBucket (FB_Bucket) appelé avant l'arbitrage M1/M2 (évite fenêtre 1 scan mouvement manuel
   │   pendant démarrage benne — voir §3)
   ├─ SI instBucket.Busy → M2 piloté PAR le benne (vitesse 15% forcée), M1 indépendant
   ├─ SINON arbitrage Mode : SEMI_AUTO (cycle auto + homme-mort) / MAINT_N1-N2 (joystick OU
   │   boutons IHM selon GVL_IHM.Modes.TglJoystickMaster, sélection M1/M2/Couplé via
   │   JoystickWinchSelectArbitrated, réservé MAINT_N2)
   ├─ Gate directionnel SyncMinorDeviationBlocksUp/Down (écart synchro mineur, opt-in
   │   _SyncSoftStopEnable) : bloque UNIQUEMENT le sens qui aggrave l'écart
   ├─ BenneBusyFallEdge : coupure immédiate M1/M2 au scan exact de fin de cycle benne
   │   (comble le retard structurel du désarmement homme-mort, 1 scan)
        │
        ▼
instWinchSync (FB_WinchSync) — surveillance croisée M1/M2 (appelée APRÈS l'arbitrage)
   ├─ DeltaPosM = |CablePosM1 - CablePosM2 + ActiveOffsetM| (fiable seulement si Homed M1 ET M2)
   ├─ bit0 écart hors tolérance (filtré 800ms) → SyncMinorDeviation (SafeStop rampe normale OU
   │   fast selon _SyncSoftStopEnable)
   └─ bit1 incohérence commande (RelayFwd/Rev/Contactor1-4 différents M1 vs M2, filtré 500ms)
      → SafeStop FAST inconditionnel
        │
        ▼
SafeStopM1_Active / ForbidDescentM1_Active / ForbidAscentM1_Active
   = OR(sources propres à M1) OR (instWinchSync.SyncActive AND source équivalente M2)
   ← COUPLAGE CROISÉ : en synchro active, un arrêt sur M2 coupe aussi M1 (et réciproquement)
        │
        ▼
instWinchM1 (FB_Winch) — FB DE MOUVEMENT
   ├─ 1. GATE Enable AND EmergencyStopOk (Enable = StubMachineEnableN1 AND Mode<>DISABLE
   │        AND NOT InhibitM1)
   ├─ 2. EffectiveSafeStop = SafeStop OR (ForbidDescent AND Direction<>1) OR (ForbidAscent AND Direction<>-1)
   ├─ 3. RAMPE (arbitrage Enable > EffectiveSafeStop > StartStop)
   │      + ralentissement auto approche limite haute/basse (Homed AND NOT HomingSuspect)
   ├─ 4. Interlock changement de sens (vitesse confirmée nulle, sauf 1er engagement)
   ├─ 5. Plafond palier dynamique (ActiveMaxStep) :
   │      - Non référencé/suspect → palier 1 (sauf BypassGlobal)
   │      - Descente → CfgMaxStepDescente (couple, pas vitesse, défaut 3)
   │      - Montée + HomingApproachActive → palier 1
   │      - Montée normale → MaxStepAscent (5 = pas de restriction)
   ├─ 6. FB_SpeedStep (hystérésis anti-battement, table ST_SpeedStepTable, validation config
   │      P0.2 : seuils croissants, hystérésis>0, cohérence contacteurs par palier)
   │      → StepNumber (0..5), Contactor1..4
   ├─ 7. RelayFwd/RelayRev (masqués si ForbidDescent/ForbidAscent respectivement)
   └─ 8. FB_Brake (même séquence temporisée que M3)
        │
        ▼
PRG_10_Outputs (câblage direct, appelé EN PLUS TÔT dans PRG_06 même, car PRG_10 = tâche indépendante)
   ├─ M1RelayFwd/Rev → instM1RelayFwd/Rev (FB_Output) → M1_RelayFwd_DQ / M1_RelayRev_DQ
   ├─ M1SpeedContactor1..4 → M1_SpeedContactor_x_DQ
   └─ M1BrakeCmd → M1_BrakeCmd_RQ
        │
        ▼
   CONTACTEURS DE SENS M1 (relais NO) + CONTACTEURS DE VITESSE (résistances rotoriques)
   FREIN M1 (bobine, manque de courant)
```

### 2.2 Sécurité traversée (couche PRG_03_Safety → FB_Safety_Winch, 1 instance par treuil)

16 bits ErrorId (0 à 15), classés par sortie maîtresse :

| Sortie | Bits inclus | Effet |
|---|---|---|
| `SafeStop` | 0,1,2,4,7,8,9,10,11,12,13,14,15 + (bit3 si SyncEnable) | Rampe décél rapide, 2 sens, Enable maintenu |
| `ForbidDescent` | bit6 (limite basse câble) | Bloque `RelayRev` uniquement |
| `ForbidAscent` | bit5 (fin de course haute) OU bit3+NOT SyncEnable (récup mou câble) | Bloque `RelayFwd` uniquement |
| `PowerCutOff` | bits 2,7,8,9,10,11,13 | Coupure puissance amont |

Détail des mécanismes différenciés (« Méca A à E », terminologie du code) :

- **Méca A (bit7)** — roue libre : armé quand contacteurs+frein confirmés coupés ; si dérive
  position (`FB_DriftGuard`, tolérance 2.0m) ou vitesse mesurée >0.02m/s pendant cette fenêtre →
  défaut + `PowerCutOff` immédiat (SafeStop seul seul jugé insuffisant, contacteurs déjà coupés).
- **Méca B (bit8)** — pilotage actif sans commande : perte CAN OU joystick neutre ; si contacteurs
  OU frein ne confirment pas être retombés/serrés sous 3s → défaut + `PowerCutOff`.
- **Méca C (bit9)** — glissement M1 pendant benne (escalade) : armé uniquement instance M1
  (`BenneHoldStillActive`), tolérance 2.0m (> 1.0m déjà surveillé côté `FB_Bucket`) → `PowerCutOff`.
- **Méca D (bit11)** — capteur haut atteint hors référencement, contacteurs/frein non confirmés
  coupés sous 3s → `PowerCutOff`.
- **Méca E (bits 12/13)** — écart synchro CRITIQUE (2.0m, indépendant de `FB_WinchSync` bit0/bit1,
  défense en profondeur) : bit12 détection → SafeStop ; bit13 escalade si pas confirmé arrêté →
  `PowerCutOff`.
- **bit14/15** — sens réel opposé à la commande confirmé 500ms / absence de mouvement malgré
  commande confirmée 3s → `SafeStop` seul (pas d'escalade automatique).

### 2.3 Couplage croisé M1/M2 (spécifique treuils, absent chez M3)

Contrairement à M3 (instance unique), les deux treuils sont **couplés en synchro active**
(`instWinchSync.SyncActive`) :
tout `SafeStop`/`ForbidAscent`/`ForbidDescent` sur l'un se propage **immédiatement** à l'autre
(pas d'attente du filtre 500/800ms de `FB_WinchSync` — la propagation logicielle directe est
plus rapide). Hors synchro (benne busy ou `SyncEnable=FALSE` en MAINT_N2), chaque treuil réagit
**uniquement** à sa propre limite/défaut — commande indépendante voulue pour la mise en service.

---

## 3. Flux M2 spécifique — Benne (bouton IHM "Fermer" + joystick)

```
GVL_IHM.M2Benne.BtnClose (IHM) OU PRG_05_Cycle.instCycle.CmdBucket_Close (auto)
        │
        ▼
FB_Bucket (appelé EN PREMIER dans PRG_06, avant tout arbitrage M1/M2)
   ├─ GATE Enable (codeurs M1+M2 disponibles ET M2 non-inhibé) AND EmergencyStopOk
   ├─ Détection incohérence boot (position M2 vs dernière position mémorisée, tolérance
   │   Config.CoherenceLimitM) → force état "ni ouvert ni fermé" si incohérent
   ├─ Garde-fou codeurs non référencés (bit3) : CablePosM1/M2 fiables seulement si Homed M1 ET M2
   ├─ Confirmation manuelle position ouverte/fermée (mise en service, front, MAINT_N1/N2, treuils
   │   à l'arrêt) → référence directe sans mouvement
   ├─ Méca C couche 1 (bit4) : M1 doit rester IMMOBILE pendant que M2 bouge seul (tolérance 1.0m,
   │   escalade PowerCutOff côté FB_Safety_Winch si 2.0m dépassé, voir §2.2)
   ├─ Surveillance limites de placement (bit2) et timeout mouvement (bit0, 30s)
   ├─ 🎛️ MACHINE À ÉTATS (READY → BUSY → DONE) :
   │     - Demande acceptée SEULEMENT si M1_Busy=FALSE ET M2_Busy=FALSE (tous modes)
   │     - Activation : requête IHM/cycle + homme-mort joystick DANS LE BON SENS
   │       (CloseReq: JoystickY_Direction=1 ; OpenReq: JoystickY_Direction=-1)
   │     - Pendant BUSY : sens inverse (recul) autorisé mais BORNÉ à M2StartPosM (jamais de
   │       réouverture/refermeture complète depuis là)
   │     - Arrêt auto sur cible atteinte (CablePosM2 vs CablePosM1+Offset) → DONE
   └─ Sorties : M2_StartStop, M2_Direction, M2_ForceSlowSpeed (TRUE = vitesse 15% forcée)
        │
        ▼
PRG_06_WinchControl §2 : SI instBucket.Busy → M2_StartStop_Active := instBucket.M2_StartStop
                                              M2_Direction_Active := instBucket.M2_Direction
                                              M2_SpeedRef_Active  := 15.0 (fixe)
        │
        ▼
   [même chemin FB_Winch → FB_SpeedStep → FB_Brake → PRG_10_Outputs que §2.1, instWinchM2]
```

⚠️ Sens moteur M2 : **REX 2026-07-07** — Enroulage M2 (Direction=+1) **FERME** le benne (câblage
terrain), déroulage (Direction=-1) **OUVRE**. Documenté ici car source de confusion fréquente
(inversé par rapport à l'intuition "monter = ouvrir un grappin classique").

---

## 4. Patterns identiques identifiés entre métiers (M1/M2/M3)

Les 3 métiers (Winch M1, Winch M2, Translation M3) partagent un **squelette commun strict**, hérité
du contrat `AF_Partie-03_Template_FB_Commun_v1.3.md` §1bis (FB de mouvement) :

| Étape | M1/M2 (`FB_Winch`) | M3 (`FB_Translation`) | Identique ? |
|---|---|---|---|
| Gate Enable/EmergencyStopOk | ✅ sorties nulles, `DISABLED` | ✅ identique | ✅ Oui |
| Premier scan (purge RAM) | ✅ `FirstScanDone` | ✅ `FirstScanDone` | ✅ Oui |
| Reset front | ✅ `R_TRIG` | ✅ `R_TRIG` | ✅ Oui |
| Précédence Enable>SafeStop>StartStop | ✅ `EffectiveSafeStop` | ✅ direct `SafeStop` | ✅ Oui (nom de variable diffère) |
| Rampe accel/décel (`FB_Ramp`) | ✅ `SpeedRamp` | ✅ `SpeedRamp` | ✅ Oui, même FB |
| Ralentissement auto approche | ✅ 2 bornes (haute+basse, `TopLimitM`/`BottomLimitM`) | ✅ 1 seule borne (`SlowdownSensor`=PV, un seul sens) | ⚠️ Pattern proche mais **pas identique** : M1/M2 rampent sur les 2 bornes symétriquement, M3 ne ralentit qu'à l'approche de Trémie |
| Interlock changement de sens | ✅ `DirectionChangeDelay` (200ms, vitesse nulle confirmée sauf 1er engagement) | ✅ identique | ✅ Oui, code quasi dupliqué à l'identique |
| Arrêt exact sur capteur cible | ❌ N/A (pas de positionneur M1/M2) | ✅ `ArrivalLock` | ❌ Spécifique M3 |
| Décodage vitesse → sorties physiques | `FB_SpeedStep` (5 paliers, contacteurs résistance rotorique) | Direct (fréquence variateur EtherCAT) | ❌ Architecture différente (TOR vs analogique/PDO) |
| `FB_Brake` (frein temporisé) | ✅ instance dédiée | ✅ instance dédiée | ✅ Oui, même FB, mêmes réglages par défaut |
| ErrorId bitfield | ✅ 3 bits (frein, contacteurs, config SpeedStep) | ✅ 3 bits (frein, variateur, Fdc) | ✅ Structure identique, causes différentes |
| Sortie sûre sur défaut | ✅ RelayFwd/Rev/Contactor=FALSE, BrakeCmd=FALSE | ✅ DriveControlWord=0, freq=0, BrakeCmd=FALSE | ✅ Oui |

**Vérification "pas de cas particulier caché"** : le pattern precedence Enable>SafeStop>StartStop
est bien respecté dans les 3 FB, **sans exception ni bypass conditionnel résiduel** — l'ancien
mécanisme `IHM_MANU` (bypass direct des sorties, override manuel) a été **retiré définitivement**
(REX 2026-07-19, voir bandeau `PRG_10_Outputs.st`), remplacé partout par un pilotage identique
Auto/Manuel via la même instance FB de mouvement, sous supervision Safety réelle inconditionnelle.

### 4.1 Différences notables entre M1/M2 (couplés) et M3 (seul)

- **Couplage croisé** : M1/M2 se coupent mutuellement en synchro active (§2.3) ; M3 n'a **aucun**
  mécanisme équivalent (pas de second axe à synchroniser).
- **Sélection de source manuelle** : M1/M2 et M3 partagent le même pattern
  `GVL_IHM.Modes.TglJoystickMaster` (M1/M2) / `GVL_IHM.TranslationM3.Cmd.TglJoystickMaster` (M3,
  variable **différente**, propre à M3) — TRUE=joystick, FALSE=boutons IHM maintenus. Mais le
  homme-mort joystick réel (`FB_Joystick.DeadmanArmed`) reste **toujours** exigé en parallèle des
  boutons IHM, dans les 2 domaines (REX 2026-07-19, bug corrigé identiquement dans les 2 lots à
  des dates différentes — signalé comme "même leçon" dans les commentaires du code M3).
- **Plafond palier dynamique** (`ActiveMaxStep`) : concept propre à M1/M2 (résistances rotoriques
  discrètes) — n'a pas d'équivalent chez M3 (consigne fréquence continue, pas de paliers).

### 4.2 Retards d'1 scan assumés (liste consolidée, tous non-critiques sécurité)

| Lecture | Producteur | Consommateur | Retard | Justification documentée |
|---|---|---|---|---|
| `instWinchM1/M2.Busy` | PRG_06 (appelé après FB_Bucket) | `FB_Bucket.M1_Busy/M2_Busy` | 1 scan | N'affecte que l'ACCEPTATION d'une nouvelle demande |
| `instBucket.Busy` (dans Safety) | PRG_06 | `PRG_03_Safety.BenneHoldStillActive` | 1 scan | PRG_03 avant PRG_06 dans l'ordre de tâche |
| `instWinchSync` (écart M1/M2) | PRG_06 (appelé après arbitrage) | `SyncMinorDeviation` (même fichier, cycle suivant) | 1 scan | Position évolue progressivement, pas par à-coup |
| `EncoderFaultPresent` | `FB_Encoder_Safety` (après FB_Modes) | `FB_Modes` | 1 scan | Même principe que `HomingRefRaw` (Partie10 §9bis) |
| `M3_CommandWord` (simulation trajet) | PRG_10 (position 10) | `instSimTranslation` (PRG_00, position 0) | 1 scan | Négligeable devant `TravelTimeS` (8s) |

Aucun de ces retards ne concerne un **arrêt de sécurité** (`SafeStop`/`PowerCutOff`/AU) : ces
chemins sont recalculés **au même scan** partout où c'est documenté comme critique (ex. Méca E lit
`ExpectedOtherWinchPosM` corrigé de l'offset benne, calculé dans le MÊME programme `PRG_03_Safety`,
au même scan).

---

## 5. Points d'attention pour futures modifs

1. **Toute nouvelle sortie physique** doit passer par `PRG_10_Outputs` (jamais de câblage direct
   depuis un autre PRG, sauf le cas déjà documenté `PRG_06`→`PRG_10` par variables intermédiaires
   commentées "REX 2026-07-07 : tâche indépendante").
2. **Toute nouvelle entrée métier (bouton IHM, capteur)** doit suivre le pattern
   `PRG_00_Inputs` (acquisition + `FB_Input` filtrage) → GVL_IHM (purge boot documentée) →
   consommation par le PRG concerné — jamais de lecture directe d'un `_DI`/`_DQ` brut hors
   `PRG_00`/`PRG_10`.
3. **Tout nouveau FB de mouvement** doit respecter STRICTEMENT le squelette du §4 (gate, premier
   scan, reset front, précédence Enable>SafeStop>StartStop, sortie sûre sur défaut) — c'est ce qui
   rend les 3 métiers actuels auditables et comparables malgré leurs différences physiques.
4. **Le couplage croisé M1/M2** (§2.3) est un piège classique si un nouveau garde-fou est ajouté
   côté M1 seul sans l'ajouter symétriquement côté M2 (cf. bug historique "Méca E oublié côté M2"
   corrigé le 2026-07-08, signe de `SignedDeltaPosM` inversé entre M1/M2).
5. **`FB_WinchSync`** reste un FB de surveillance seule (pas de correction active de vitesse) —
   toute future demande de "recalage automatique" nécessite une nouvelle entrée dédiée sur
   `FB_Winch`, actuellement absente (hors périmètre documenté).

---

## 6. Références croisées

| Sujet | Doc de référence |
|---|---|
| Contrat FB standard/mouvement | `DOC/AF_Partie-03_Template_FB_Commun_v1.3.md` §1/§1bis |
| Détail métier Winch (Méca A-E) | `DOC/AF_Partie-09_Fonction_Winch_v1.11.md` |
| Détail métier Translation | `DOC/AF_Partie-11_Fonction_Translation_v1.9.md` |
| Détail métier Benne | `DOC/AF_Partie-12_Fonction_Benne_v1.4.md` |
| Détail métier Joystick/homme-mort | `DOC/AF_Partie-08_Fonction_Joystick_v1.3.md` |
| Architecture / ordre de tâche | `DOC/AF_Partie-02_Architecture_Programme_v2.12.md` |
| Mémos terrain rapides | `DOC/NAVBOARDS/NAVBOARD_TranslationM3.md`,
  `DOC/NAVBOARDS/NAVBOARD_MiseEnService_JoystickTranslation.md` |
| Historique suppression IHM_MANU | `ARCHIVES/Doc/IHM_MANU_Journal_Modifications.md` |
| Diagrammes existants (PNG, HiFi) | `DOC/DIAGRAMS/CODE/DIAG_CODE_Treuils_HiFi.png`,
  `DIAG_CODE_TranslationM3_HiFi.png` (+ vues 1/2/3), `DIAG_CODE_Benne_HiFi.png`,
  `DIAG_CODE_Safety_HiFi.png`, `DIAG_CODE_Joystick_HiFi.png` |

📌 Ce document est **complémentaire** aux diagrammes PNG déjà générés (`TOOLS/DIAGRAM_GENERATORS/`) :
ceux-ci montrent la structure statique des FB/instances, celui-ci trace le **flux dynamique de
données** bouton → actionneur avec tous les points de contrôle traversés.
