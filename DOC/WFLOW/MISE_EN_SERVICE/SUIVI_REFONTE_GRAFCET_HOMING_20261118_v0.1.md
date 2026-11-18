# Suivi Refonte GRAFCET Homing — Constats Simulation, Décisions & Points à Valider

- **Date :** 2026-11-18
- **Statut :** Cahier de suivi vivant (aucune modification `CODE/` appliquée)
- **Point de sauvegarde Git :** `381021be` (`wip(checkpoint): point de sauvegarde avant refonte grafcet homing T377`)
- **Objectif :** Tracer les constats observés en simulation, leur cause vérifiée dans le code, les règles déjà posées (Step 0 / Step 1 / transverse) et les points à trancher avant codage puis test en simulation.

---

## 1. Constats terrain / simulation & causes vérifiées dans le code

### 1.1 Entrée en homing & risque de relance si déjà référencé
- **Constat :** Crainte qu'un appui bouton joystick alors que la machine est déjà référencée puisse lancer le cycle homing. En `MAINT_N1`, le bandeau affiche `[JOYSTICK] Appuyer homme-mort au neutre` et `Homing: HX0 - M1+M2 non ref - Homing unitaire possible`.
- **Cause code :**
  - `FB_CycleMachineHoming.st:416-420` : la transition `HX0_REPOS -> HX1_BUCKET_PREPARE` (`IF (StartEdge.Q OR BtnValidationEdge.Q) AND ModeIsMaint2 AND NOT JoystickDeflected`) **n'a aucun verrou `NOT MachineHomed`**. Une relance quand déjà référencé est donc possible.
  - `PRG_02_Acquisition.st:609-610` : `BtnValidation` et `StartRequest` sont sur `CycleMachineHoming.Cmd.BtnValidate` / `BtnStart` (IHM), pas sur un maintien 5 s joystick.
  - `FB_Hmi_BannerFormatter.st:850` : `[JOYSTICK] Appuyer homme-mort au neutre` apparaît car `ArmingPermit` (`PRG_04_Treuils_Benne.st:1223`) reste `TRUE` en `MAINT_N1` même non référencé.

### 1.2 Benne « qui se souvient » d'être référencée & butées actives sans référence
- **Constat :** Même avec codeurs non référencés (`Homed = FALSE`), la benne garde sa référence (`BucketReferenced`) et s'arrête sur ses butées logicielles habituelles ; en `MAINT_N1`, même en sélectionnant benne ou avec `fdc bucket` (`TglManualBucketLimits`) ON/OFF, on tape une butée logicielle alors qu'on ne sait pas où est le câble. En `MAINT_N2`, on peut dépasser la benne et piloter en couplé (`Sync`) ou benne à l'infini hors homing.
- **Cause code :**
  - `FB_Bucket.st:403-419` : `BucketState.BucketReferenced` (persistant) n'est remis à `FALSE` **que** sur `HomingSuspectM1 OR HomingSuspectM2` (2 s), **jamais** quand `HomedM1 = FALSE` ou `HomedM2 = FALSE`.
  - `PRG_04_Treuils_Benne.st:769-801` : `ManualBucketLimitsActive` (défaut `TglManualBucketLimits := TRUE`, `ST_BucketCmd.st:18`) applique `OffsetOpenM` / `OffsetCloseM` **sans vérifier `HomedM1 AND HomedM2`**.
  - `FB_Safety_Winch.st:565` : la butée basse logicielle `CablePosM <= CfgCableLimitDescentM` **n'est pas conditionnée par `Homed`**, et `InReferencingMode` (`PRG_04_Treuils_Benne.st:1020`) ne lit que `EncoderM2.Measurement.HomingLifecycle.Busy` (pas `MachineHoming.Active`). Donc en `MAINT_N1`, même `TglManualBucketLimits = OFF`, la butée câble basse coupe.
  - `PRG_04_Treuils_Benne.st:1121-1130` : en `MAINT_N2`, `MaintN2` court-circuite `SafetyWinch` et les permis process (ne garde que `PowerContactorEngaged_DI` et `M1M2_TopPositionFree_DI`), d'où les mouvements libres sans butée en `N2`.
  - `FB_Modes.st:194, 307, 381-399` : `SelSyncEnable` est `TRUE` au boot (couplé/synchro par défaut).
  - **Note simulateur (`FB_SimBench.st:492-497`) :** en simulation, `M2_MechanicStopEngaged` bloque l'avance codeur M2 aux bornes `BucketOffsetOpen_M - 0.40` / `BucketOffsetCloseM` même si contacteurs moteur et frein sont actifs (butée mécanique simulée — en réel rien n'arrête le treuil).

### 1.3 Alarme `[BENNE] ErrorID:05` uniquement pendant l'appui
- **Constat :** Aucun défaut visible à l'arrêt avant d'appuyer ; dès qu'on commande la benne, `1/1 [BENNE] ErrorID:05 - codeurs treuils non references` s'affiche pendant le mouvement et disparaît au relâchement.
- **Cause code :**
  - `FB_Bucket.st:282-288` : `HomingMotionWithoutReference` (`instCauses[4]`) exige `(ReqAscent OR ReqDescend OR CmdOpen_IHM OR CmdClose_IHM OR ProgramBucketDriveActive)` avec `Latching := FALSE`.
  - `PRG_03_Modes_Cycle.st:161, 354-355` + `PRG_04_Treuils_Benne.st:355-356` : `WinchBothIntent.ReqAscent/Descend` recopie `AxisY.Direction` même en jog M2, ce qui allume `instCauses[4]` uniquement pendant la déflexion joystick.

### 1.4 Boutons IHM Homing (`HX1`, `Abort`, `Forçage step`)
- **Constat 1 (`HX1`) :** Affiche `Homing: HX1 - RefHoming Fermer benne, valider sur IHM`, mais appuyer sur « Valider » IHM est sans effet.
  - **Cause (`FB_CycleMachineHoming.st:433`, `PRG_02_Acquisition.st:609-612`) :** le bouton IHM « Valider » écrit `CycleMachineHoming.Cmd.BtnValidate` (`BtnValidation`, lu **uniquement en `HX0`**), alors que `HX1` n'écoute que `M2TreuilBenne.Bucket.Cmd.BtnConfirmHomingBucket` (autre struct IHM).
- **Constat 2 (`Exit / Abort`) :** Sur `Homing: Erreur ou Echec homing - Acquitter (Reset)`, « Exit / Abort » ne fait rien ; seul l'acquittement général efface l'état.
  - **Cause (`PRG_02_Acquisition.st:589` vs `PRG_03_Modes_Cycle.st:243`) :** le bouton IHM « Abort » est probablement câblé sur `CycleSemiAuto.Cmd.BtnAbort` et non sur `CycleMachineHoming.Cmd.BtnAbort`.
- **Constat 3 (Forçage step) :** Le champ de forçage ne saute pas d'étape.
  - **Cause :** côté `CycleMachineHoming` (`FB_CycleMachineHoming.st:307-325`), le forçage exige **ensemble** `TglCommissioning = TRUE` (remis à `FALSE` au boot) + `Mode = MAINT_N2` + front sur `BtnForceStepApply`. Côté `CycleSemiAuto` (`FB_CycleSemiAuto.st:687-696`), `SetForceStepTgt` est rejeté si le mode n'est pas `SEMI_AUTO` (expulsion vers `MAINT_N1` si `MachineHomed = FALSE`).

### 1.5 Voyant / bouton d'acquittement IHM (`AnyFaultActive`) — PROBLÈME CRITIQUE
- **Constat :** Lors d'un défaut homing (`Homing: Erreur ou Echec homing - Acquitter (Reset)`), le voyant général de défauts (`GVL_IHM.Modes.State.AnyFaultActive`) ne s'allume pas, donc l'opérateur ne voit pas que l'acquittement est attendu / disponible.
- **Cause (`PRG_07_Supervision.st:612-622`, `ST_MachineHoming.st:11-27`) :** `AnyFaultActive` omet :
  1. `MachineHoming.Failed` (et `Fault.Error/.Latched` du cycle homing n'est même pas publié sur `ST_MachineHoming`),
  2. Les défauts `[HISTO]` mémorisés (`Safety.LatchedId <> 0` sur M1, M2, M3 — `AnyFaultActive` ne lit que `Safety.Error`),
  3. Les défauts blocs actionneurs (`M1TreuilRetenue.State.Error` / `.FinalInterlockError`, `M2TreuilBenne.State.Error` / `.FinalInterlockError`, `M3Translation.State.Error` / `.FinalInterlockError`),
  4. Les défauts codeurs M1/M2 (`EncoderM1/M2.Fault`, `.HomingError`),
  5. Les états latchés `Joystick.Fault.Latched` (`PRG_07:652` ne publie que `.Error`) et `EmergencyFault.Latched`.

### 1.6 Forçage `HX2`, descente permise, `[BENNE] ErrorID:04` et NON-COUPURE sur capteur haut (`SimTopPositionActive`) — CRITIQUE
- **Constat 1 (`HX2` forcé permet la descente + message) :** En forçant `HX2`, la machine affiche `HX2 - RefHoming Tirer JOY palier 1 vers haut`, mais autorise quand même la descente au joystick, et déclenche `[BENNE] ErrorID:04 - glissement treuil M1`.
  - **Cause descente (`FB_WinchCmdArbitrationM1.st:56-104`, `PRG_03_Modes_Cycle.st:458-459`) :** en mode maintenance, `FB_WinchCmdArbitrationM1/M2` ignore `ReqWinch` (qui ne porte que `ReqAscent` depuis `HX2`) et lit directement `Joystick.AxisY` (`BothIntent`) — la descente n'est donc pas bloquée et les paliers ne sont pas bridés par `HX2`.
  - **Cause `ErrorID:04` (`FB_Bucket.st:274`) :** `M1SlipDetected := Lifecycle.Busy AND (ABS(CablePosM1 - M1RefPosM) > M1SlipToleranceM)` s'active si `instBucket` était `Busy` pendant que M1 monte.
- **Constat 2 (GRAVE — contacteurs & frein restent actifs sur capteur haut + aucun défaut `Meca D` / `PowerCutOff`) :** En montant couplé avec `GVL_Simulation.SimTopPositionActive := TRUE` (et « bypass désactivé »), les contacteurs de frein et puissance restent enclenchés, la montée continue et aucun défaut mécanique majeur ne tombe.
  - **Cause côté simulation / RETAIN (`PRG_07_Supervision.st:367, 379-397`, `PRG_04_Treuils_Benne.st:868, 1126-1129`) :**
    - `SimBypassRise` force `GVL_IHM.Commun.Bypass.TopLimitSwitch := TRUE` (ainsi que `Bypass.Safety` et `Bypass.Process`), et `GVL_IHM.Commun.Bypass.TopLimitSwitch` est **sauvegardé en `RETAIN`** (`BypassTopLimitSwitch`).
    - Même si le bypass individuel M1/M2 est `FALSE`, `BypassM1/M2TopLimitSwitchEff` vaut `M*Bypass.TopLimitSwitch OR Commun.Bypass.TopLimitSwitch`. S'il est resté à `TRUE`, `EffectivePermitM1/M2_Ascent` (`PRG_04:1127,1129`) reste `TRUE` même quand `M1M2_TopPositionFree_DI = FALSE`, **et** `BypassSafety` neutralise Meca D (`FB_Safety_Winch.st:376`).
  - **Cause GRAVE sur machine réelle en `MAINT_N2` (`PRG_04_Treuils_Benne.st:1632, 1653`) :**
    - En `MAINT_N2`, `WinchM1/M2FinalInterlockRequest.PowerCutOff := instSafetyWinchM*.PowerCutOff AND NOT MaintN2` **masque totalement `PowerCutOff` (donc `Meca D`)** ! Même sur machine réelle, si contacteurs/frein restent collés sur le capteur haut `TopPositionSensor` plus de `PostRampTimeout`, `MAINT_N2` ne coupe **jamais** la puissance.
  - **Cause découplage `HX2 -> HX3` (`FB_CycleMachineHoming.st:465-471`) :** dès que `TopPositionSensor` monte, `HX2` passe en `HX3`, mais `FB_WinchCmdArbitrationM1/M2` en `MAINT_N2` continue d'obéir au joystick brut au lieu de couper la montée.

- **Constat 3 (Erreur au relâchement capteur haut) :** Après relâchement de `SimTopPositionActive`, passage en `Homing: Erreur ou Echec homing - Acquitter (Reset)` sans guider l'opérateur à redescendre.
  - **Cause (`FB_CycleMachineHoming.st:244-255, 264-267, 465-471`) :** à l'activation du capteur, `HX2` passe en `HX3` (`IsInMovePhase = FALSE`). Comme les treuils continuaient à tourner en `HX3` (`MotionOutOfPhase`) ou n'ont pas validé le preset dans `CfgTimeoutHomeAxes` (`HomeAxesTimedOut`), `TransactionAbort` a latché `Fault.Latched` (`HX7_FAILED`).

---

## 2. Comportement cible déjà posé (à vérifier & compléter)

### Transverse (hors GRAFCET)
- [x] **Dépendance codeurs -> benne :** si `NOT HomedM1 OR NOT HomedM2` (ou perte référence), la benne **ne peut pas** rester qualifiée comme référencée (`BucketReferenced` ou sa validité machine invalidée).
- [x] **Verrou translation `M3` si non référencé :** interdire toute translation `M3` dès que `NOT MachineHomed` (Step 0 inclus, pas seulement pendant `CycleRunning` comme aujourd'hui dans `PRG_05_Translation.st:524-526`).
- [x] **`AnyFaultActive` exhaustif :** toute alarme / tout défaut actif ou latché demandant un acquittement doit allumer `GVL_IHM.Modes.State.AnyFaultActive` (et rendre le voyant/bouton acquittement actif).
- [x] **Zéro bouton IHM dispersé / ZERO nouveau bouton matériel :** tout déclenchement et validation doit s'appuyer uniquement sur les entrées/boutons existants (`JoyBtnRaw`, axes joystick, `CycleMachineHoming.Cmd.*`, boutons reset).

### Step 0 — État initial non référencé (hors cycle homing)
- **Condition d'état :** `NOT MachineHomed` (M1 non ref, M2 non ref, ou benne non ref).
- **Sécurité mouvement :**
  - En `MAINT_N1` : mouvement libre treuils/benne **interdit** tant qu'on n'est pas entré dans le cycle homing (pas de conduite à l'aveugle, pas de butées fausses).
  - En `MAINT_N2` : reste mode secours brut (à trancher : autoriser mouvement libre secours vs homing en N1/N2, voir §3).
- **Message opérateur permanent :** indiquer explicitement dès Step 0 (avant même d'appuyer sur une commande) que la machine doit avoir **les codeurs ET la benne référencés**, et comment lancer le homing (**maintien 5 s** au neutre). Si commande actionnée sans être entré en homing : blocage + rappel clair du prérequis.
- **Transition d'entrée `Step 0 -> Step 1` (anti-homing intempestif sans nouveau bouton) :**
  1. **Verrou absolu déjà référencé :** impossible si `MachineHomed = TRUE`.
  2. **Anti-collage :** le bouton déclencheur doit avoir été vu relâché (`FALSE`) au moins 1 fois depuis le passage en Step 0 / le boot.
  3. **Neutre strict continu :** joystick au neutre (`AtNeutralXY`) pendant **toute** la temporisation (toute déflexion remet à 0).
  4. **Maintien continu 5 s** avec décompte/consigne affichée dans le message.

### Step 1 — Référencement / fermeture visuelle benne (dans le homing)
- **Pilotage permis :** ouverture **ET** fermeture benne sur M2 seul (palier lent).
- **Butées logicielles :** **aucune limite logicielle** (ni FDC benne `OffsetOpen/Close`, ni limite câble basse `CfgCableLimitDescentM`), car position câble inconnue.
- **Message opérateur :** avertir explicitement qu'il n'y a **aucune limite (dangereux)** et indiquer l'objectif : **fermer la benne visuellement** (+ comment valider la fin d'étape).
- **Garde-fou durée continue (`X` s) :**
  - Si commande ouverture ou fermeture maintenue en continu > `X` s (durée max course normale), coupure nette immédiate de la commande + message explicite.
  - Réarmement impossible tant que le joystick n'est pas repassé à **zéro (neutre)** et l'homme-mort relâché/repris.

### Step 2 (nouvel élément posé) — Montée couplée vers capteur haut (après benne fermée)
- **Sens permis :** **montée couplée M1+M2 uniquement** (palier lent), **descente interdite** — ou à la rigueur descente bornée à **max 2 s** uniquement si besoin de détendre le câble en cas de désynchro (à trancher §3).
- **Message opérateur :** indiquer clairement d'aller **doucement**, de **regarder** le câble et de **s'approcher au plus près du capteur haut**.
- **Arrêt & sécurité capteur haut (NON NÉGOCIABLE) :**
  - Dès activation du capteur haut (`M1M2_TopPositionFree_DI = FALSE`), **coupure immédiate** des relais montée + freins (jamais contournée en cycle homing).
  - Surveillance type **Meca D (`PowerCutOff`)** active même pendant le homing / maintenance : si des contacteurs de puissance ou freins restent actifs dans un sens au-delà du délai court d'arrêt alors que le capteur haut est actif → **coupure puissance (`PowerCutOff`) + défaut majeur latché** (même sans encodeur référencé).

### Step 3 (nouvel élément posé) — Capteur haut touché → dégagement descente & ouverture benne
- **Déclenchement :** dès que le capteur haut est activé (`M1M2_TopPositionFree_DI = FALSE`), la montée coupe net **sans** déclencher un défaut bloquant (si contacteurs/frein retombent normalement dans le délai d'arrêt).
- **Obligation de dégagement :** montée interdite ; message clair demandant de **quitter le capteur haut** et de **descendre de quelques mètres** (avec référence provisoire M1/M2 / benne pour permettre le mouvement synchro puis l'ouverture benne).
- **Ouverture benne :** après/pendant dégagement du capteur haut, la benne doit s'ouvrir (préparation du 2e passage).

### Step 4 à Step N (Passe 2 — validation finale avant TOP)
- **Nouveau cycle fermeture benne :** l'opérateur referme la benne et **valide**.
- **Montée couplée avec arrêt AVANT capteur haut :** l'opérateur remonte couplé et s'arrête **avant** de toucher le capteur haut (sans déclencher le FdC haut).
- **Validation finale avec avertissement :** demande de confirmation opérateur explicite avec message d'avertissement → contrôle que M1, M2 et la benne sont bien référencés (altimétrie standard `8.5 m` proche capteur haut) → message **« Homing fait »** → **`MachineHomed := TRUE`**, machine libérée (treuils + benne + `M3`).

---

## 3. Décisions ouvertes à valider avant Step 2+ et codage

Cocher / compléter les choix retenus :

1. **Mode autorisé pour le cycle Homing :**
   - [ ] **Option B (recommandée sécurité) :** Homing guidé faisable en **`MAINT_N1`** (et `MAINT_N2`), tout mouvement libre étant **bloqué en `MAINT_N1` Step 0** tant que non référencé. `MAINT_N2` reste réservé au secours/dépannage brut.
   - [ ] **Option A :** Passage en **`MAINT_N2` obligatoire** pour lancer le homing (et `MAINT_N1` bloqué tant que non référencé) — *attention : `MaintN2` masque aujourd'hui `SafetyWinch` ET `PowerCutOff` (`PRG_04:1121, 1632, 1653`), ce qui empêche `Meca D` de couper sur capteur haut : inacceptable pendant un homing.*

2. **Déclencheur du maintien 5 s en Step 0 :**
   - [ ] `JoyBtnRaw` (bouton homme-mort joystick) au neutre pendant **5 s** en `MAINT_N1` (sans risque car mouvement libre bloqué en Step 0) + `BtnStart` IHM conservé en secours/N2.
   - [ ] Autre : ______________________

3. **Durée max continue `X` s en Step 1 (garde-fou anti-course infinie benne) :**
   - Valeur souhaitée : `___ s` (ex. `15 s` / `20 s`, ou liée au réglage `Bucket.Cfg.CfgTimeoutDuration` ?).

4. **Geste de validation « Benne fermée » à la fin de Step 1 (`Step 1 -> Step 2`) :**
   - [ ] Bouton IHM unifié `CycleMachineHoming.Cmd.BtnValidate` (et/ou `BtnStart` / `BtnConfirmHomingBucket` ?).
   - [ ] Geste joystick (ex. maintien X s au neutre ? — ou défini avec Step 2).

5. **Comportement `BtnAbort` (quitter le homing) :**
   - [ ] Bouton IHM unique (ou aligner `CycleSemiAuto.Cmd.BtnAbort` / `CycleMachineHoming.Cmd.BtnAbort`), autorisant sortie vers Step 0 **hors défaut** sans masquer un défaut latché nécessitant un vrai `Reset`.

6. **Step 2 — Descente « détente câble » :**
   - [ ] Montée seule stricte (0 descente en Step 2).
   - [ ] Descente autorisée uniquement par impulsions / max `2 s` si besoin de détendre un câble désynchronisé.

7. **Meca D / `PowerCutOff` en `MAINT_N2` :**
   - [ ] Supprimer le masquage `AND NOT MaintN2` sur `PowerCutOff` (`PRG_04:1632,1653`) pour `Meca D` (escalade capteur haut) afin qu'un collage contacteur sur fin de course haut coupe toujours la puissance.

8. **Verrou `M3` si `NOT MachineHomed` (`PRG_05:524-526`) :**
   - [ ] Interdire `M3` dès Step 0 en `MAINT_N1` et `SEMI_AUTO` (et confirmer si `MAINT_N2` garde ou non un accès secours `M3` pour dégagement chariot).

9. **Altimétrie `8.5 m` — Passe 1 vs Passe 2 :**
   - [ ] **Option 1 :** Le preset codeurs `8.5 m` est pris au contact capteur haut (**Passe 1**) → le dégagement de quelques mètres + ouverture/fermeture benne en **Passe 2** valide la mécanique et la benne ; l'arrêt « avant TOP » en Passe 2 confirme visuellement et publie `MachineHomed := TRUE` (altimétrie exacte issue du capteur TOP).
   - [ ] **Option 2 :** Le contact capteur haut Passe 1 ne pose qu'une ref provisoire → l'arrêt « avant TOP » en Passe 2 réécrit `8.5 m` sur validation opérateur *(attention : précision visuelle ± quelques dm au lieu de la cote capteur exacte)*.

---

## 4. Précisions restantes à verrouiller sur le GRAFCET

- **Descente « quelques mètres » (Step 3) :** distance minimale imposée pour quitter le capteur haut (ex. `2.0 m` ou `3.0 m` sous capteur haut ?), ou validation capteur relâché + Δz ?
- **Ouverture benne (Step 3/4) :** manuelle guidée par l'opérateur ou automatique, et quel critère fait passer au nouveau cycle de fermeture (Step 4) ?
- **Passe 2 — « s'arrête avant TOP » :** comment l'opérateur sait où s'arrêter (ex. `CfgCableLimitAscent_M` = `7.5 m` ou proche `8.0 m` si Passe 1 a déjà pris la cote `8.5 m`, ou arrêt libre opérateur) et quel bouton valide la fin (`BtnValidate`) ?
- **Cas d'échec en cours de cycle :** timeout montée, perte de sync / écart M1-M2, contacteur collé sur TOP (`Meca D` → `PowerCutOff`).
