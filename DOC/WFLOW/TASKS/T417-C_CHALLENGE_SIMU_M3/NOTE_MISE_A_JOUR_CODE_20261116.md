# 📦 Note de mise à jour code — Lot M3 / Cycle Semi-Auto / MAINT N2 (2026-11-16)

> **Statut :** Commité en lots granulaires · **Bundles prêts :** `CODE_XML/CODE_Bundle.xml` et `CODE_XML/CODE_DiffBundle.xml` (12 objets).  
> **Compagnon terrain :** [GUIDE_TERRAIN_MES_M3_ET_CHANTIERS_20261116.md](./GUIDE_TERRAIN_MES_M3_ET_CHANTIERS_20261116.md)  
> **Principe :** Toutes les nouvelles souplesses de cycle sont **débrayables** et **désactivées par défaut** (`FALSE` / `0.0`) dans `GVL_IHM.CycleSemiAuto.Cmd` (fin de `ST_CycleCmd.st:26-28`, non persistées ➔ zéro décalage `GVL_PERSISTENT`).

---

## 1. 🪣 Ouverture benne anticipée en zone PV & retour P1 sans capteur Trémie

- **Bit IHM :** `GVL_IHM.CycleSemiAuto.Cmd.TglAllowDumpInPV` (`BOOL`, défaut **`FALSE`**) — [`ST_CycleCmd.st:26`](../../../../CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCmd.st#L26).
  - `FALSE` = comportement strict d'origine : en `AX14`, le chariot doit atteindre `M3_AtTremieStable`, s'arrêter, relâcher le manche, puis ouvrir en `AX15A`/`AX15B`.
  - `TRUE` = comportement souple activé :
    1. En `AX14` (`FB_CycleSemiAuto.st:834` et `:1524-1536`) : dès que le chariot est en zone PV (`PRG_02_Acquisition.HwIn.Translation.M3_PosPV_DI = TRUE`), pousser le joystick Y (`JoystickPush`) avec l'homme-mort (`DeadmanArmed`) arme `PvDumpLatched := TRUE` **sans bloquer** la translation X gauche (`TranslationTremiePermit` + `FB_TranslationCmdArbitrationM3.st:71-72` acceptent `AxisY.Direction <= 0` quand `SelTarget = 1`).
    2. `PRG_03_Modes_Cycle.st:117-119` inclut `TglAllowDumpInPV AND M3_PosPV_DI` dans `M3AtTremie` transmis à `FB_Modes` pour autoriser le pilotage benne dans la zone PV.
    3. Dès que `Benne_Done AND Benne_IsOpen` est vrai en `AX14` (ou en `AX15A` avec `PvDumpLatched`), le cycle passe **directement** à `AX18_DONE_SYNC` (`FB_CycleSemiAuto.st:1531-1536`, `:1571-1573`), permettant le retour vers `P1` sans exiger `M3_PosTremie_DI`.
- **⚠️ Nuance réelle vérifiée au code (à connaître sur site) :**
  - Dans `FB_WinchCmdArbitrationM2.st:69`, l'ouverture benne reste soumise à `RunRequest := Context.BucketM2RunRequest AND (Joystick.AxisX.Direction = 0);` (*« Axe X translation prioritaire : aucun contacteur treuil pendant un jog X »*).
  - **Conséquence concrète :** si l'opérateur maintient **X gauche ET Y poussé en même temps** dans la zone PV, la translation X reste prioritaire et **M2 n'ouvre pas la benne tant que X n'est pas relâché**. En revanche, dès qu'il relâche X en zone PV (en gardant Y poussé + homme-mort), la benne s'ouvre sur place sans atteindre le capteur Trémie et bascule vers `AX18` dès `Benne_IsOpen`.
  - *(Si le mouvement simultané réel M3 + M2 pendant le push PV est souhaité après essai site, il faudra lever la condition `Joystick.AxisX.Direction = 0` uniquement pour ce cas précis dans `FB_WinchCmdArbitrationM2.st:69`.)*

---

## 2. 🟢 Assouplissement des conditions initiales `AX1_INIT` + Diagnostic granulaire

- **Bit IHM :** `GVL_IHM.CycleSemiAuto.Cmd.TglRelaxSemiAutoStart` (`BOOL`, défaut **`FALSE`**) — [`ST_CycleCmd.st:27`](../../../../CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCmd.st#L27).
  - `FALSE` = conditions strictes d'origine (`CST_CycleInitWindowM = 0.4 m` autour de `CfgCableLimitAscent_M` + benne qualifiée `IsClosed OR IsOpen` + M3 hors zone Maintenance).
  - `TRUE` (`PRG_03_Modes_Cycle.st:59`, `:180-196`) :
    1. Fenêtre haute élargie de `0.4 m` à **`CST_CycleInitWindowRelaxM = 2.0 m`**.
    2. Qualification benne assouplie : si les treuils sont dans la zone haute (`CycleWinchesHighZoneOk = TRUE`), l'état intermédiaire benne ne bloque plus `AX1_INIT` (`CycleBucketQualifiedOk`).
    3. Le blocage si M3 est en zone Maintenance (`CycleM3NotInMaintOk`) reste actif par sécurité.
- **Diagnostic granulaire `AX1_INIT` (toujours actif, sans bit) :** `FB_CycleSemiAuto.st:974-986` via `InitM3MaintBlocked`, `InitWinchTopBlocked`, `InitBucketStateBlocked` câblés dans `PRG_03_Modes_Cycle.st:289-291` :
  - `'AX1 - Chariot M3 en zone Maintenance'`
  - `'AX1 - Treuils M1/M2 hors zone haute'`
  - `'AX1 - Etat benne non qualifie'`

---

## 3. ⏱️ Pause réglable avant ouverture benne (`AX14` ➔ `AX15B`)

- **Paramètre IHM :** `GVL_IHM.CycleSemiAuto.Cmd.SetPauseBeforeDump_S` (`REAL`, défaut **`0.0` s**, borné `[0.0 .. 30.0]` s) — [`ST_CycleCmd.st:28`](../../../../CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCmd.st#L28).
  - `0.0` = transparent (aucune attente supplémentaire).
  - `> 0.0` (`FB_CycleSemiAuto.st:380-385`, `:1574-1580`) : maintient `AX15A_DUMP_ARRIVE` en attente temporisée (`PauseBeforeDumpTimer`) avant d'autoriser `AX15B_DUMP_OPEN` (sauf si ouverture anticipée PV déjà enclenchée `PvDumpLatched`).

---

## 4. 🛑 Correctif arrêt M3 au 1er trou capteur en `SEMI_AUTO` (`T417-E`)

- **Toujours actif** (aligne `SEMI_AUTO` sur l'arrêt `MANU`) :
  - [`FB_Translation.st:290-294`](../../../../CODE/I_TRANSLATION/FB_Translation.st#L290-L294) : `ArrivalLock` inclus dans `EffectiveSafeStop` ➔ déclenche la rampe rapide (`CfgRampDecelFastRate`) dès le 1er trou capteur (`Tremie` ou `P1`).
  - [`FB_Translation.st:320-322`](../../../../CODE/I_TRANSLATION/FB_Translation.st#L320-L322) : `MovementRequested := NOT ArrivalLock AND (...)` ➔ coupe immédiatement `BrakeReleaseRequest` au 1er trou au lieu d'attendre la fin de rampe lente (`2.5 s`).
  - [`PRG_05_Translation.st:709-723`](../../../../CODE/M_MAIN/PRG_05_Translation.st#L709-L723) + [`PRG_06_Outputs.st:118,437-448`](../../../../CODE/M_MAIN/PRG_06_Outputs.st#L437-L448) : déclaration/câblage de `ReqMaintenanceSemantic` et passage de `M3_TremieHardStopLatched` en `VAR RETAIN`. Tant que le capteur Trémie a été touché et qu'aucun recul vers P1/Maintenance n'est demandé (ou `FaultMachineReset_IHM` hors came), la marche avant Trémie reste coupée même si le chariot dépasse la came physique.
  - [`FB_CycleSemiAuto.st:1537-1546`](../../../../CODE/G_CYCLE/FB_CycleSemiAuto.st#L1537-L1546) : en `AX14`, `PositionTgt := 1` est maintenu pendant tout `TranslationStopTimer` (`500 ms`).

---

## 5. 🔧 Commande inconditionnelle contacteurs / treuils en `MAINT_N2` (`T395`)

- **Toujours actif dès que `Auth.Mode = E_Mode.MAINT_N2`** :
  - [`FB_Modes.st:364-370`](../../../../CODE/F_MODES/FB_Modes.st#L364-L370) : scission `MAINT_N2` / `MAINT_N1` — `JoystickWinchSelectRequest` (`0` = M1+M2, `1` = M1 seul, `2` = M2 seul) passe sans écrasement par `M3AtTremie` ni `CoupledBucketSeqEnable`.
  - [`PRG_03_Modes_Cycle.st:532-538`](../../../../CODE/M_MAIN/PRG_03_Modes_Cycle.st#L532-L538) : `WinchDescentAuth_M3` forcé à `TRUE` en `MAINT_N2`.
  - [`PRG_04_Treuils_Benne.st:501-514`](../../../../CODE/M_MAIN/PRG_04_Treuils_Benne.st#L501-L514) : neutralisation de `BucketBusy`, `BucketM2RunRequest`, `WinchBothMotionBlockedByBucket`, `SyncBlocksAscent`, `SyncBlocksDescent` en `MAINT_N2`.
  - [`PRG_04_Treuils_Benne.st:1121-1130`](../../../../CODE/M_MAIN/PRG_04_Treuils_Benne.st#L1121-L1130) : `SafeStopM1/M2_Active` et `EffectivePermitM1/M2_*` libérés tant que `PowerContactorEngaged_DI = TRUE`, en conservant la barrière haute `M1M2_TopPositionFree_DI` (sauf bypass explicite).
  - [`PRG_04_Treuils_Benne.st:1180-1200`](../../../../CODE/M_MAIN/PRG_04_Treuils_Benne.st#L1180-L1200) et `:1619-1655` : `ArmingPermit` maintenu même sous défaut latché ; `BrakeFeedback` / `FwdRevSpeedFeedbackOff` et `PowerCutOff` adaptés pour `FB_WinchOutputInterlock`.
  - [`PRG_06_Outputs.st:355-364`](../../../../CODE/M_MAIN/PRG_06_Outputs.st#L355-L364) : `instSyncContactorFinal.BypassGlobal` inclut `MAINT_N2`.

---

## 6. 🛡️ Anti-démarrage accidentel du Grafcet Homing au joystick (`T377` partiel R3)

- **Toujours actif** (sans bit IHM supplémentaire) :
  - [`PRG_02_Acquisition.st:607-609`](../../../../CODE/M_MAIN/PRG_02_Acquisition.st#L607-L609) : retrait de `HwIn.Operator.JoyBtnRaw OR` sur `BtnValidation` — seul le bouton IHM dédié (`BtnStart` / `BtnValidate`) reste actif.
  - [`FB_CycleMachineHoming.st:411-420`](../../../../CODE/G_CYCLE/FB_CycleMachineHoming.st#L411-L420) (`HX0_REPOS`) : ajout de `AND NOT JoystickDeflected` à l'entrée du cycle.
- **Conséquence terrain à connaître :**
  - Toucher le joystick (homme-mort `JoyBtnRaw` ou débattement manche) en `MAINT_N2` **ne démarre plus jamais** `FB_CycleMachineHoming` — le homing unitaire manuel (`BtnHome` / `BtnHomingAtZero`) reste 100 % libre.
  - Le geste *« 3 appuis homme-mort joystick »* est retiré (lancement cycle = IHM exclusif, manche au neutre).
  - *Rappel code vérifié (`FB_CycleMachineHoming.st:23, 273-289, 602-605` + `PRG_04_Treuils_Benne.st:715-718`) :* `BootReady` n'est pas bloquant en `HX0` (ne pas appuyer sur `BtnStart` sans codeurs), et si `MachineHomed` a déjà été `TRUE` dans la session puis perdu, un **Reset IHM à l'arrêt mécanique** (`FaultMachineReset_IHM`) reste nécessaire pour réarmer `ReHomingAckRequired` avant `SEMI_AUTO`.

---

## 7. 📊 Trace CODESYS & fichiers de livraison associés

- **Trace M3 classée par échelle (35 variables, 4 groupes) :** `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/config/Trace_Site_M3_Par_Echelle.trace`
- **Générateur complet / diff :**
  - `CODE_XML/CODE_Bundle.xml` (264 objets)
  - `CODE_XML/CODE_DiffBundle.xml` (12 objets modifiés + fermeture des types)
