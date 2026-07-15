# 🛠️ IHM_MANU — Journal des Modifications Provisoires
**Mise en service urgence d'excavatrice de dragage (Secours)**

---

## 📌 BANDEAU D'INTRODUCTION

La fonctionnalité **IHM_MANU** est un **dispositif DÉROGATOIRE et PROVISOIRE** ajouté pour les besoins de mise en service terrain (2026-07-09). Elle permet un **pilotage direct des sorties physiques** (relais M1/M2, contacteurs vitesse K1-K4, variateur M3 EtherCAT) en **contournant complètement le programme fonctionnel normal** (PRG_06_WinchControl, PRG_07_TranslationControl, PRG_03_Safety), avec un **minimum de sécurités logicielles**.

**Responsabilité du nettoyage futur :** Ce document enumère CHAQUE modification pour que, une fois la mise en service achevée, il soit simple et exhaustif de supprimer/rétablir le code normal.

⚠️ **EN MODE MANU, SEULE LA CHAÎNE AU PHYSIQUE (arrêt d'urgence matériel indépendante) PROTÈGE.**

---

## 🆕 MISE À JOUR MAJEURE — SESSION 2026-07-15

**Changement de doctrine pour M1/M2 (treuils) UNIQUEMENT.** Les sections **3** et **7** ci-dessous décrivent l'état **AVANT** cette session (bypass total, `Enable:=FALSE`) — **elles ne reflètent plus le code actuel pour M1/M2** et sont conservées à titre d'historique (barrées mentalement). Voir nouvelles sections **8, 9, 10, 11** pour l'état réel.

**Résumé du changement :** IHM_MANU ne bypass plus `PRG_06_WinchControl`/`FB_Safety_Winch` pour M1/M2 — il devient une **3ᵉ source d'arbitrage** (à côté de SEMI_AUTO et joystick Auto), au même titre que les autres, pour bénéficier nativement de la rampe accel/décel, du ralentissement en zone d'approche de butée, et de la sécurité `FB_Safety_Winch` (désormais **toujours active**, plus de bypass conditionnel). **Motif** : arrêts violents constatés en simulation aux butées logicielles (pas de ralentissement, coupure relais instantanée) + confusions "Fault allumé mais je peux bouger" (butées logicielles traitées comme un vrai défaut machine).

**Ce qui reste un VRAI bypass dérogatoire (inchangé, sections 3/4/5/6 toujours valables) :** Translation M3 (logique de bypass — voir nuance section 11 ci-dessous), Auxiliaires Hydrauliques (Grille/Casque), homing direct simulé M1/M2 (`PRG_02_Encoders`), timer visuel `FB_Encoder_Abs`.

**Nouveau point provisoire ajouté (section 10)** : plafond palier "essais progressifs" (`WinchMaxStepFwd/Rev`) — réactivé spécifiquement pour cette session, TEMPORAIRE, à retirer avec le reste (voir `PLAN_TASK_v1.0.md` T28).

## 🆕 MISE À JOUR — SESSION 2026-07-15 (2), sortie Translation M3 de `ST_IHM_MANU`

**Ce qui a changé pour M3 :** Les champs de commande/diagnostic manuels M3 (`M3_RelayFwd/Rev`,
`M3_FreqSetpoint/Actual`, `M3_CommandWordMonitor/StatusWordMonitor`, `M3_CommReady/PowerReady`)
sont **retirés de `ST_IHM_MANU`** (struct provisoire) et migrés vers `ST_TranslationHMI`
(`GVL_IHM.TranslationM3`, struct **définitif**), renommés sans préfixe `M3_` (`ReqFwd`/`ReqRev`/
`FreqSetpointHz`) et avec le diag variateur décodé (`DriveCommReady`/`DrivePowerReady` au lieu
d'un `WORD` brut). Voir section 11 pour le détail.

**Ce qui n'a PAS changé (la vraie dérogation reste active) :** La logique de bypass elle-même
— `PRG_10_Outputs` écrit toujours `M3_CommandWord`/`M3_SetpointFrequencyHz` directement quand
`ManuActive=TRUE`, sans passer par `FB_Translation`/`FB_Safety_Translation` (sections 3/7 toujours
valables sur le fond). Seule la **localisation des variables** change — objectif : permettre
de développer/tester l'IHM (activation progressive bus EtherCAT → mouvements → freins/
sécurité, via `GVL_Simulation.VariateurM3_IsReal`/`ContactorFeedbackM3_IsReal`/
`TranslationPosition_IsReal`, déjà granulaires) sans dépendre du switch global `ModeDisable`.

---

## 📋 FICHIERS MODIFIÉS — INVENTAIRE DÉTAILLÉ

### 1. **CODE/SUPERVISION/ST_IHM_MANU.st** — Nouveau type créé (complet, lignes 1–52)

| Élément | Description |
|---------|-------------|
| **Type** | `ST_IHM_MANU` |
| **Portée** | Type de données (définition seule, pas d'instance) |
| **Raison** | Agrégation de tous les signaux IHM pour pilotage manuel direct |

**Champs du struct :**
- `ModeDisable : BOOL` — **logique inversée VOLONTAIRE** : FALSE (défaut, non-RETAIN) = mode Manu ACTIF sans action opérateur. Doit passer explicitement à TRUE pour revenir au normal. ⚠️ **Ceci est le point le plus dangereux et le premier à corriger au nettoyage.**
- `JoystickSelect : BOOL` — choix de la source de commande (TRUE = Joystick CANopen, FALSE = boutons HMI).
- `JoystickWinchSelect : INT` — sélection du treuil piloté par le joystick Y (1 = M1, 2 = M2, 3 = M1+M2).
- `PositionM_M1/M2 : REAL` — lecture brute position codeur (affichage diagnostic)
- `M1/M2_RelayFwd/Rev : BOOL` — commandes montée/descente par axe, interlock Fwd/Rev
- `HomingEncoder_M1/M2 : BOOL` — front = référencement codeur (OR avec CmdHome existant, **aucune dérogation sécurité**)
- `M1_M2_RelayFwd/Rev : BOOL` — commandes couplées (mouvement simultané M1+M2)
- `M1_M2_Contactor1-4 : BOOL` — contacteurs vitesse K1-K4 communs (un seul actif à la fois, interlock fail-safe)
- ~~`M3_RelayFwd/Rev`~~, ~~`M3_FreqSetpoint/Actual`~~, ~~`M3_CommandWordMonitor/StatusWordMonitor`~~, ~~`M3_CommReady/PowerReady`~~ — **retirés le 2026-07-15 (2)**, migrés vers `GVL_IHM.TranslationM3` (`ST_TranslationHMI`, struct définitif — voir section 11).
- `GridOpenCmd/GridCloseCmd : BOOL` — commandes maintenues ouverture/fermeture grille.
- `HelmetOpenCmd/HelmetCloseCmd : BOOL` — commandes maintenues ouverture/fermeture casque.
- `FdcBenneOpenEnable/CloseEnable : BOOL` — activation HMI des sécurités virtuelles benne.
- `BenneDelta : REAL` — écart en mètres M1-M2 en temps réel.
- `FdcBenneOpenActive/CloseActive : BOOL` — états actifs de fin de course benne (coupe les relais M2).
- `WinchMaxStepFwd/WinchMaxStepRev : INT` — réglage dynamique des limites de vitesse manuelles (paliers max en montée/descente).

**À supprimer au nettoyage :** Fichier entier.
---

### 2. **CODE/SUPERVISION/GVL_IHM.st** — Déclaration instance (ligne 17)

```st
IHM_MANU : ST_IHM_MANU; (* 🛠️ Variables d'échange IHM provisoires pour pilotage manuel direct (Secours) *)
```

**À modifier au nettoyage :** Supprimer cette ligne de la section VAR_GLOBAL RETAIN.

---

### 3. **CODE/MAIN/PRG_10_Outputs.st** — Trois blocs balisés Début/Fin IHM_MANU

> ⚠️ **PARTIELLEMENT PÉRIMÉ (session 2026-07-15)** — Le "Bloc 2" ci-dessous (états effectifs `M1Fwd_Eff`/`M1Rev_Eff`/`M2Fwd_Eff`/`M2Rev_Eff`, décodage K1-K4 via `instManuSpeedStep`, rampe locale `instHmiSpeedRamp`) a été **entièrement supprimé** pour M1/M2 — remplacé par le pilotage `FB_Winch` (voir section 8). Ne reste dans ce fichier que le calcul des "Demand" (boutons/joystick, interlocks, `StartupNeutralOk`, `FdcBenne`) qui alimente désormais `PRG_06_WinchControl`, et la partie **M3/Auxiliaires qui reste un vrai bypass, inchangée**. Le "Bloc 3" (PowerCutOff) reste valable tel quel.

#### 🔶 **Bloc 1 : Déclarations VAR** (lignes 73–90)

```st
// ─────────  Début modification IHM_MANU  ─────────
    // 🆕 REX 2026-07-09 — Mode IHM_MANU (mise en service urgence, override direct sorties)
    ManuActive            : BOOL; // NOT GVL_IHM.IHM_MANU.ModeDisable (logique inversée, voir ST_IHM_MANU)
    // Détection de fronts montants pour priorité temporelle (Boutons HMI uniquement)
    TrigM1Fwd             : BOOL;
    TrigM1Rev             : BOOL;
    TrigM2Fwd             : BOOL;
    TrigM2Rev             : BOOL;
    TrigCoupledFwd        : BOOL;
    TrigCoupledRev        : BOOL;
    TrigM3Fwd             : BOOL;
    TrigM3Rev             : BOOL;
    // États au scan précédent (Boutons HMI uniquement)
    LastM1Fwd             : BOOL;
    LastM1Rev             : BOOL;
    LastM2Fwd             : BOOL;
    LastM2Rev             : BOOL;
    LastCoupledFwd        : BOOL;
    LastCoupledRev        : BOOL;
    LastM3Fwd             : BOOL;
    LastM3Rev             : BOOL;

    // Commandes brutes demandées (après aiguillage HMI / Joystick)
    M1Fwd_Demand          : BOOL;
    M1Rev_Demand          : BOOL;
    M2Fwd_Demand          : BOOL;
    M2Rev_Demand          : BOOL;
    CoupledFwd_Demand     : BOOL;
    CoupledRev_Demand     : BOOL;
    M3Fwd_Demand          : BOOL;
    M3Rev_Demand          : BOOL;

    // États effectifs calculés (après interlocks et limites)
    M1Fwd_Eff             : BOOL;
    M1Rev_Eff             : BOOL;
    M2Fwd_Eff             : BOOL;
    M2Rev_Eff             : BOOL;
    K1_Eff                : BOOL; // Contacteurs vitesse communs M1+M2
    K2_Eff                : BOOL;
    K3_Eff                : BOOL;
    K4_Eff                : BOOL;
    M3Fwd_Eff             : BOOL;
    M3Rev_Eff             : BOOL;

    instManuSpeedStep     : FB_SpeedStep; // 🪜 FB de décodage palier pour Joystick en mode Manu
    instM3RelayFwdLed     : FB_Output; // 💡 LED témoin mise en service (M3_RelayFwd_DQ) — PAS de mouvement réel
    instM3RelayRevLed     : FB_Output; // 💡 LED témoin mise en service (M3_RelayRev_DQ) — PAS de mouvement réel

    // 🆕 REX 2026-07-14 — Gestion RAMPES / décodage à la volée en mode HMI bouton
    CycleTimeCalc         : FB_CycleTime; // ⏱️ Calculateur temps de cycle réel
    instHmiSpeedRamp      : FB_Ramp;      // 📈 Rampe d'accélération pour vitesse HMI
    WinchMoving           : BOOL;         // 🚨 Au moins une commande de treuil HMI active
    HmiRampTarget         : REAL;         // 🎯 Cible de la rampe HMI
    SpeedRefPct           : REAL;         // 📊 Consigne vitesse courante (issue de la rampe)
// ─────────  Fin modification IHM_MANU  ─────────
```

**Rôle :** Variables de travail, états précédents (Last*) et détection de fronts (Trig*) pour les interlocks temporels actifs, et instances FB de sortie pour LEDs de mise en service M3, ainsi que les blocs de rampe/timing HMI.

**À supprimer au nettoyage :** Bloc entier (30 lignes de déclarations + instances FB).

---

#### 🔶 **Bloc 2 : Calcul logique et override VAR_INPUT** (lignes 93–183)

**Position dans le code :** En tête du corps d'implémentation (avant les appels FB_Output existants), pour que l'override prenne effet immédiatement dans le même scan.

**Logique :**
1. Calcul `ManuActive := NOT GVL_IHM.IHM_MANU.ModeDisable` (logique inversée)
2. Affichage position codeurs M1/M2 et calcul de l'écart `BenneDelta` (M1 - M2).
3. Évaluation des sécurités actives : `FdcBenneOpenActive` (si `FdcBenneOpen` est coché et `delta >= 0.0`) et `FdcBenneCloseActive` (si `FdcBenneClose` est coché et `delta <= -10.0`).
4. **IF ManuActive THEN :**
   - **Aiguillage Source** : Si `JoystickSelect` = TRUE, les commandes `Demand` viennent du Joystick CANopen (Y -> Winch sélectionné par `JoystickWinchSelect`, X -> Translation M3 avec consigne fréquence calculée `SpeedRef * 0.5`). Sinon (mode HMI bouton), les commandes sont automatiquement maintenues pendant la décélération de la rampe HMI pour un arrêt progressif et sécurisé, et les demandes antagonistes sont verrouillées croisées.
   - **Contrôle Winch M2** : Sécurité FDC Benne active applique le blocage individuel de M2 (`FdcBenneOpenActive` coupe la descente, `FdcBenneCloseActive` coupe la montée). Les commandes couplées contournent cette limite pour éviter la divergence.
   - **Vitesse Winch** : Si Joystick, utilisation de `FB_SpeedStep` pour décoder K1-K4 sur la vitesse du joystick (avec limitation en descente). Si HMI bouton, utilisation de la même fonction `FB_SpeedStep` connectée à la rampe de vitesse `instHmiSpeedRamp` (démarrage à 0%, montée progressive à 100% tant que le bouton est maintenu, décélération progressive vers 0% au relâchement, avec limitation en descente).
   - **Auxiliaires Hydrauliques** : Mappage des commandes Grille / Casque action maintenue, avec interlock logique, et forçage automatique de `PRG_08_AuxiliaryControl.HydraulicPumpRunCmd := TRUE` en mouvement.
   - **Verrouillage de sécurité global** : Toutes les commandes effectives (treuils, translation, auxiliaires) sont filtrées par `PRG_00_Inputs.EmergencyStopOk` afin de couper immédiatement tout mouvement (et arrêter la simulation des codeurs sur PC) en cas d'arrêt d'urgence actif ou de défaut critique.
   - Recalcul des VAR_INPUT existants (M1RelayFwd, M1RelayRev, M1BrakeCmd, M1/M2SpeedContactor1-4, TranslationBrakeCmd).
5. **Translation M3 — mot de commande EtherCAT direct :**
   - Si `ManuActive AND M3Fwd_Eff` → `M3_CommandWord := 1` + fréquence
   - Si `ManuActive AND M3Rev_Eff` → `M3_CommandWord := 2` + fréquence
   - Sinon → `M3_CommandWord := 0` (arrêt, couvre aussi le mode normal)
   - Copie vars de diagnostic (CommandWordMonitor, StatusWordMonitor, FreqActual)
   - 💡 Pilotage LEDs M3 (M3_RelayFwd_DQ, M3_RelayRev_DQ) — **témoins mise en service uniquement, ne pilotent PAS le variateur**

**À supprimer au nettoyage :** Bloc entier (incluant la réinitialisation des variables temporaires et des auxiliaires dans le bloc `ELSE` de désactivation du mode Manu).

---

#### 🔶 **Bloc 3 : Override PowerCutOff_A_RQ / PowerCutOff_B_RQ** (lignes 244–252)

```st
IF ManuActive THEN
    PowerCutOff_A_RQ := NOT ForceTestA;
    PowerCutOff_B_RQ := NOT ForceTestB;
    // ─────────  Fin modification IHM_MANU  ─────────
ELSE
    PowerCutOff_A_RQ := NOT (PRG_03_Safety... ) AND NOT ForceTestA AND NOT GVL_IHM.Modes.CmdEmergencyCutOff;
    PowerCutOff_B_RQ := NOT (PRG_03_Safety... ) AND NOT ForceTestB AND NOT GVL_IHM.Modes.CmdEmergencyCutOff;
END_IF;
```

**Rôle :** **Imbriqué dans le IF/ELSE existant**, en mode Manu force les sorties `PowerCutOff_A_RQ` et `PowerCutOff_B_RQ` à `TRUE` (pour shunter les coupures logicielles des blocs sécurités) **sauf** si l'auto-test du réarmement (`ForceTestA` ou `ForceTestB`) est en cours, ce qui permet de tester et réarmer la boucle de sécurité physique.

**À modifier au nettoyage :** Retirer le bloc IF ManuActive/ELSE, replacer directement la logique normale dans le code.

**Ligne critique :** 249–251 (les 3 lignes du bloc THEN).

---

### 4. **CODE/MAIN/PRG_02_Encoders.st** — Override direct et bypass sécurité homing

#### 🔶 **Bloc 1 : M1 et M2 - PresetRequest/Value direct (Bypass de instHoming)**
Si `ManuActive` est activé, les commandes `HomingEncoder_M1/M2` pilotent directement le bloc `instEncoderAbsM1/M2` :
*   `PresetRequest` = `instHomingM1.PresetRequest OR (PRG_10_Outputs.ManuActive AND GVL_IHM.IHM_MANU.HomingEncoder_M1)`
*   `PresetValue` = `16777216` (milieu de plage)

**Rôle :** Permet d'envoyer l'écriture dans les mots physiques sans aucune condition de mode (MAINT_N1/N2 non requis) ni de sécurité (contacteur sens/frein non vérifiés).

#### 🔶 **Bloc 2 : Enregistrement manuel de calibration et reset bouton HMI**
Code ajouté tout à la fin du POU `PRG_02_Encoders` pour détecter le succès (`PresetAck`) ou le timeout (`PresetNak`) afin d'écrire directement l'offset de position dans la mémoire persistante pour faire `12.5` mètres (Offset = `16726016`), puis de désactiver le bouton HMI.

#### 🔶 **Bloc 3 : Aiguillage codeur réel / simulé (Restauration logique propre)**
L'aiguillage d'entrée des codeurs (lignes 68-78) a été nettoyé de la condition `AND NOT PRG_10_Outputs.ManuActive` afin de permettre au simulateur de codeur `instSimEncoderM1/M2` de fonctionner correctement sur PC même lorsque `ManuActive = TRUE`. Pour basculer sur les codeurs réels, il suffit de configurer `EncoderM1_IsReal` et `EncoderM2_IsReal` à `TRUE` dans `GVL_Simulation` (ou désactiver `SimulationModeActive`).

**À modifier au nettoyage :** 
*   Rétablir les entrées `PresetRequest := instHomingM1.PresetRequest` et `PresetValue := instHomingM1.PresetValue` sur `instEncoderAbsM1` et `instEncoderAbsM2`.
*   Retirer le bloc de code conditionnel `IF PRG_10_Outputs.ManuActive THEN ... END_IF` tout à la fin du fichier.

---

### 5. **CODE/MAIN/PRG_08_AuxiliaryControl.st** — Modification du bloc VAR en VAR_INPUT
Pour permettre à `PRG_10_Outputs.st` d'écrire directement dans `HydraulicPumpRunCmd` pour la logique de démarrage automatique de la centrale hydraulique en mode dérogatoire, le bloc de variables locales a été converti en `VAR_INPUT`.

**À modifier au nettoyage :** Changer `VAR_INPUT` en `VAR` pour rétablir la portée locale.

---

### 6. **CODE/ENCODERS/FB_Encoder_Abs.st** — Temporisation visuelle de l'écriture

#### 🔶 **Bloc 1 : Maintien visuel à 0.5s dans le step 1**
Un timer `PresetTimerVisual : TON` a été ajouté au bloc d'acquisition. Une fois le codeur recalé, le bit `PresetTriggerCmd := 2` est maintenu pendant **0.5 seconde** avant d'être repassé à `0` (step 0).

**Rôle :** Permet à l'œil humain et aux visualisations CODESYS de voir passer l'impulsion et l'écriture de valeur brute sur le bus en simulation.

**À modifier au nettoyage :** Rétablir la transition immédiate sans `PresetTimerVisual` dans le Step 1, et supprimer la déclaration du timer dans `VAR`.

### 7. **CODE/MAIN/PRG_03_Safety.st** — Désactivation des sécurités logicielles métier en mode IHM_MANU

> ⚠️ **PÉRIMÉ POUR M1/M2 (session 2026-07-15) — INVERSÉ.** Cette section décrit l'état AVANT le
> 2026-07-15 : `Enable := FALSE` quand `ManuActive` actif (bypass sécurité total pour éviter les
> faux Méca B/E). **Ce n'est PLUS le cas** : `instSafetyWinchM1`/`instSafetyWinchM2.Enable` sont
> désormais **inconditionnels** (`NOT InhibitM1`/`NOT InhibitM2`, comme en Auto — voir section 9).
> La fausse alarme Méca B a été corrigée à la racine (voir section 9.3 : `JoystickYNeutral`
> regarde aussi les boutons IHM, pas juste le joystick) plutôt que masquée par un bypass complet.
> **`instSafetyTranslationM3` reste inchangé** (toujours `Enable := NOT ManuActive OR ...`, bypass
> conditionnel d'origine conservé — M3 reste hors scope, voir bandeau §2 en tête de document).

Pour éviter les fausses alarmes de sécurité logicielle (comme Méca B - pilotage sans commande opérateur en raison du joystick inutilisé, ou Méca E) lorsque l'opérateur utilise les commandes HMI boutons en mode Manu, les instances `instSafetyWinchM1`, `instSafetyWinchM2` et `instSafetyTranslationM3` étaient désactivées (`Enable := FALSE`) dès que `ManuActive` était actif *(état pré-2026-07-15, M1/M2 uniquement)*.

**À modifier au nettoyage :** ~~Rétablir les entrées `Enable` d'origine~~ **Déjà fait pour M1/M2** (2026-07-15). Reste à faire pour M3 : `Enable := NOT PRG_10_Outputs.ManuActive OR ...` (translation) doit être retiré pour redevenir `Enable := TRUE` inconditionnel, une fois M3 sorti du bypass (dépend de la finalisation `FB_Translation`, cf. `PLAN_TASK` T4/T12/T26).

---

### 8. **CODE/MAIN/PRG_06_WinchControl.st** — IHM_MANU comme 3ᵉ source d'arbitrage M1/M2 *(NOUVEAU 2026-07-15)*

**Rôle :** Remplace le bypass direct des sections 3 (Bloc 2) — M1/M2 sont désormais pilotés par les MÊMES instances `instWinchM1`/`instWinchM2` (`FB_Winch`) qu'en Auto/SEMI_AUTO, avec une branche `ELSIF PRG_10_Outputs.ManuActive THEN` insérée entre la branche SEMI_AUTO et la branche joystick Auto (§1 pour M1, §2 pour M2).

**Logique de la branche Manu (par treuil) :**
- Lit `PRG_10_Outputs.M1Fwd_Demand`/`M1Rev_Demand`/`CoupledFwd_Demand`/`CoupledRev_Demand` (calculés dans `PRG_10_Outputs`, lus avec **1 scan de retard** ~10ms — PRG_10 en position 10, PRG_06 en position 6, même principe que `Benne.Busy`/`SyncMinorDeviation` déjà accepté ailleurs dans ce fichier) pour déterminer `Direction`/`StartStop`.
- `SpeedRefPct` = déflexion joystick brute (si `JoystickSelect=TRUE`, vitesse proportionnelle comme en Auto) ou `100.0` (si boutons HMI — `FB_Winch` rampe déjà en interne, plus besoin de rampe locale).
- Fins de course benne (`FdcBenneOpen/CloseActive`) appliquées au pilotage **individuel M2 ET couplé** (M1+M2), et désormais **aussi à M1 individuel** (`CoupledFwdBenneOk`/`CoupledRevBenneOk`, calculés une fois, réutilisés M1+M2 pour un arrêt synchrone) — corrige un trou trouvé en revue (ex-code ne masquait QUE M2 individuel, jamais M1 seul ni le couplé).

**Conséquence :** M1/M2 bénéficient nativement en Manu de : rampe accel/décel (`WinchM1/M2RampAccelRate/DecelNormal/DecelFast_Pct`), ralentissement en zone d'approche de butée (`WinchSlowdownDistance_M`/`WinchSlowSpeedPct`), maintien du relais de sens pendant la décélération (pas de coupure instantanée à pleine vitesse).

**À modifier au nettoyage :** Rien à faire — cette branche `ELSIF ManuActive` est le code **définitif**, pas une dérogation à retirer (elle deviendra juste inatteignable si `ModeDisable` reste `TRUE` en permanence après qualification). Seul `PRG_10_Outputs.M1Fwd_Demand`/etc. (calcul amont, boutons/joystick) reste spécifique IHM_MANU.

---

### 9. **`GVL_PERSISTENT.st` / `PRG_06_WinchControl.st` / `ST_WinchHMI.st` / `PRG_09_Supervision.st` — Nouvelle limite `CableLimitAscentM1/2_M`** *(NOUVEAU 2026-07-15)*

**Problème identifié :** `HomingTargetM1/2_M` (12.5m) servait à la fois de cible Homing (approche petite vitesse du capteur physique) ET de seuil d'arrêt normal en exploitation — l'exploitation normale finissait par réveiller le capteur physique hors référencement, que `FB_Safety_Winch` traite comme une anomalie (Méca D, bit11) → escalade `SafeStop`+`PowerCutOff` après 3s (`PostRampTimeout`), perçu comme un blocage/défaut en approchant 12m.

**Fix :** Nouvelle variable persistante indépendante `CableLimitAscentM1_M`/`CableLimitAscentM2_M` (défaut **12.0m**, mirroir exact de `CableLimitDescentM1/2_M` côté descente) :
- `HomingTargetM1/2_M` (12.5m) redevient **exclusivement** la cible du Homing.
- `PRG_06_WinchControl` : `TopLimitM` (alimente la rampe `FB_Winch`) et le seuil `ForbidAscentMx_Raw` (arrêt normal, bypass en `HomingApproachEnable`) utilisent désormais `CableLimitAscentMx_M`.
- Exposée IHM : `GVL_IHM.WinchM1/M2.CableLimitAscentM` (miroir bidirectionnel dans `PRG_09_Supervision`, même pattern que `CableLimitDescentM`) + `CableLimitAscentReached` (miroir lecture seule, symétrique `CableLimitDescentReached`).
- `WinchTopStopMarginM` (ex-marge relative) **retiré** (obsolète, remplacé par la valeur absolue).

**9.3 — Correctif Méca B (`SafetyErrorId=256`, bit8) :** `JoystickYNeutral` (entrée `FB_Safety_Winch`) ne regardait que le joystick CANopen — piloter M1/M2 via boutons HMI (IHM_MANU, `JoystickSelect=FALSE`) faisait croire à "aucune commande opérateur" en continu (joystick physiquement au neutre) → `SafeStop` après 3s de mouvement légitime aux boutons. **Fix** (`PRG_03_Safety.st`) : `JoystickYNeutral` regarde aussi les boutons IHM_MANU bruts (individuel M1/M2 + couplé), en plus du joystick — défense en profondeur conservée (lecture directe des boutons, indépendante de l'arbitrage `FB_Winch`/`PRG_06`).

**9.4 — `FB_Safety_Translation.st` :** correctif bug indépendant (pas spécifique Manu) — `Error`/`ErrorId` n'étaient pas remis à zéro quand `Enable=FALSE`, causant un défaut latché à vie (remontait comme faux défaut M3 en simulation). Aligné sur `FB_Safety_Winch`, qui le faisait déjà.

**À modifier au nettoyage :** Rien — ce sont des corrections d'architecture définitives (limite haute + fix Méca B + fix latch Translation), pas des dérogations IHM_MANU.

---

### 10. **`GVL_IHM.IHM_MANU.WinchMaxStepFwd`/`WinchMaxStepRev` — Réactivation TEMPORAIRE "essais progressifs"** *(NOUVEAU 2026-07-15 — ⚠️ VRAIE DÉROGATION, À RETIRER)*

**Contexte :** Ces 2 champs existent depuis l'origine d'IHM_MANU (§1, section "Champs du struct") mais étaient devenus **orphelins** : leur seul consommateur (`instManuSpeedStep`/`ActiveMaxStepFwd/Rev` dans `PRG_10_Outputs`) a été supprimé en section 8 (M1/M2 pilotés par `FB_Winch`, qui n'avait qu'un plafond `MaxStepDescente`, pas de plafond montée).

**Demande utilisateur explicite (2026-07-15) :** *"Je veux utiliser WinchMaxStepFwd et Rev, que ça s'applique en simu et en IHM_MANU tout le temps. C'est uniquement quand les essais auront été avancés et qu'on aura bien figé les vitesses, que ça disparaîtra plus tard."* → **dérogation VOLONTAIRE et TEMPORAIRE**, à retirer avec le reste d'IHM_MANU (ou avant, dès que les vitesses de croisière sont validées terrain).

**Implémentation :**
- `FB_Winch.st` : nouveau paramètre `MaxStepAscent : INT := 5` (mirroir de `MaxStepDescente`, appliqué quand `CommandedDirection=1` hors approche homing). Défaut 5 = **aucune restriction pour Auto**, qui ne branche jamais autre chose que 5.
- `PRG_06_WinchControl.st` : `EffectiveMaxStepAscent`/`EffectiveMaxStepDescente` calculés une fois (communs M1/M2, comme le champ IHM) — `SEL(ManuActive, <valeur Auto>, <valeur Manu bornée 1..5>)`. **En descente, le plafond Manu (`WinchMaxStepRev`) est le MIN avec `WinchMaxStepDescente`** (jamais moins protecteur qu'Auto, seulement plus prudent possible) — **en montée (`WinchMaxStepFwd`), aucun plafond mécanique Auto n'existe, donc Manu applique directement sa valeur bornée 1..5.**

**À supprimer au nettoyage (AVANT ou PENDANT le nettoyage général IHM_MANU, cf. `PLAN_TASK_v1.0.md` T28) :**
- [ ] `FB_Winch.st` : retirer le paramètre `MaxStepAscent` (ou le laisser à son défaut 5 partout, inoffensif si plus rien ne le branche à autre chose)
- [ ] `PRG_06_WinchControl.st` : retirer `ManuMaxStepFwd`/`ManuMaxStepRev`/`EffectiveMaxStepAscent`/`EffectiveMaxStepDescente`, rebrancher `MaxStepDescente := GVL_PERSISTENT.WinchMaxStepDescente` directement (comme avant), `MaxStepAscent` non branché (défaut 5)
- [ ] `ST_IHM_MANU.st` : `WinchMaxStepFwd`/`WinchMaxStepRev` redeviennent orphelins (ou supprimés avec le reste du struct, section §1)

---

### 11. **`ST_TranslationHMI.st` / `GVL_IHM.st` / `PRG_07/09/10` — Translation M3 sort de `ST_IHM_MANU`** *(NOUVEAU 2026-07-15 (2))*

**Rôle :** `ST_TranslationHMI` (`GVL_IHM.TranslationM3`, déjà existant mais partiel) devient la structure
IHM pour M3 : migre les commandes manuelles ex-`ST_IHM_MANU`
(`ReqFwd`/`ReqRev`/`FreqSetpointHz`, sans préfixe `M3_` — redondant sous `GVL_IHM.TranslationM3.xxx`),
et décode le diagnostic variateur (`DriveCommReady`/`DrivePowerReady`, StatusWord bit7/bit0) au
lieu d'exposer un `WORD` brut — objectif : simplifier le binding pour le développeur IHM (LED/
checkbox direct, pas de bit-masking manuel côté visu).

**Corrections faites au passage :**
- `BypassBrakeFeedback` (`ST_TranslationHMI`) supprimé — n'était **jamais écrit** nulle part
  (contrairement à `BypassContactorFeedback`, auto-calculé en `PRG_09` depuis
  `GVL_Simulation.ContactorFeedbackM3_IsReal`, qui couvre déjà "sens + frein"). `PRG_07_TranslationControl`
  utilise désormais `BypassContactorFeedback` pour le `SEL` de `BrakeFeedback` (champ mort corrigé).
- `DriveActualFreqHz` : source unique `PRG_00_Inputs.M3_ActualFrequencyHz_Filtered`, écrite une
  seule fois en `PRG_09` (Auto ET Manu) — supprime le doublon `IHM_MANU.M3_FreqActual` et la
  lecture fragile de l'ex-`instTranslationM3.DriveActualFreqHz` (qui lisait en réalité le `VAR_INPUT`
  de l'instance, pas une sortie du FB).
- **Bug corrigé (simulation position M3)** : `FB_Sim_Translation` (`instSimTranslation`, `PRG_00_Inputs`)
  lisait `RelayFwd`/`RelayRev` depuis `GVL_Translation_M3_Stub.M3_RelayFwd/Rev` — variables **jamais
  écrites** depuis l'abandon du mode relais `DEGRADED_IO` (v0.4.11) : la simulation de trajet M3
  (Fosse1/Fosse2/Maintenance/Trémie) restait bloquée en permanence. Rebranché sur `M3_CommandWord
  = 1/2` (valeur EtherCAT réellement envoyée, Auto ET Manu). `GVL_Translation_M3_Stub.M3_RelayFwd/
  Rev/RelaySpeedGv/ContactorFeedbackFwd/Rev` sont maintenant des reliquats 100% orphelins de
  l'ère `DEGRADED_IO` — candidats nettoyage (`PLAN_TASK_v1.0.md`, à ajouter §🗑️).

**Rename `GVL_IHM` (portée plus large, hors IHM_MANU) :** `Translation`→`TranslationM3`, `Benne`→
`Joystick`→`JoystickJOY1` (aligne sur `WinchM1`/`WinchM2` — le nom du membre porte son
identifiant matériel). `Benne` reste sans suffixe (⚠️ tentative `BenneM2` faite puis
**annulée** le même jour — répétait `M2` avec les champs internes du struct, ex.
`M2PositionCorrected`/`M2StartStop`/`State.LastPosM2Close` : un seul benne, pas de paire à
distinguer comme M1/M2 treuils, donc pas besoin de suffixe axe). Ne concerne pas la dérogation
IHM_MANU elle-même (Benne/Joystick n'y ont jamais été).

**Ce qui N'A PAS changé (dérogation toujours active) :** `PRG_10_Outputs` écrit toujours
`M3_CommandWord`/`M3_SetpointFrequencyHz` en direct quand `ManuActive=TRUE`, sans passer par
`FB_Translation`/`FB_Safety_Translation` — voir sections 3/7. Le passage de M3 sur le même modèle que
M1/M2 (section 8, arbitrage natif `FB_Translation`/`PRG_07` même en Manu) reste un chantier séparé
(`PLAN_TASK_v1.0.md` T4/T12/T26).

**À modifier au nettoyage :** Rien de spécifique à cette section — `GVL_IHM.TranslationM3` est
définitif, seul le bypass `ManuActive` sur `M3_CommandWord` (sections 3/7) reste à retirer plus
tard.

---

## 🧹 CHECKLIST NETTOYAGE COMPLET

### Phase 1 : Vérifications préalables
- [ ] Confirmer que la mise en service terrain est terminée et stable
- [ ] Vérifier que le programme fonctionnel normal (PRG_06/07/03, Safety) est **opérationnel et testé**
- [ ] S'assurer qu'aucun opérateur ne dépend plus du mode IHM_MANU

### Phase 2 : Suppression de code
- [ ] **ST_IHM_MANU.st** : Supprimer le fichier entier
- [ ] **GVL_IHM.st** (ligne 17) : Supprimer la déclaration `IHM_MANU : ST_IHM_MANU;`
- [ ] **PRG_10_Outputs.st** :
  - [ ] Supprimer les déclarations VAR (lignes 73–88, bloc Début/Fin)
  - [ ] Supprimer le bloc override principal (lignes 93–183, bloc Début/Fin)
  - [ ] **Bloc PowerCutOff_A_RQ/B_RQ (lignes 351–355)** : Retirer le IF ManuActive, recollage du ELSE à la place
    ```st
    // ❌ AVANT :
    IF ManuActive THEN
        PowerCutOff_A_RQ := TRUE;
        PowerCutOff_B_RQ := TRUE;
    ELSE
        PowerCutOff_A_RQ := NOT (...) AND ...
        ...
    END_IF;
    
    // ✅ APRÈS :
    PowerCutOff_A_RQ := NOT (...) AND ...
    PowerCutOff_B_RQ := NOT (...) AND ...
    ```
- [ ] **PRG_02_Encoders.st** :
  - [ ] Retirer la condition `AND NOT PRG_10_Outputs.ManuActive` de l'aiguillage simulation/réel (lignes 68-78) pour rétablir la logique nominale.
  - [ ] Restaurer `PresetRequest := instHomingM1.PresetRequest` et `PresetValue := instHomingM1.PresetValue` sur les appels de `instEncoderAbsM1` et `instEncoderAbsM2` (lignes 97-98 et 146-147).
  - [ ] Retirer le bit de forçage dérogatoire sur l'entrée `Home` des blocs `instHomingM1` et `instHomingM2` (lignes 113 et 162).
  - [ ] Supprimer entièrement le bloc conditionnel de fin de fichier (lignes 214-239).
- [ ] **PRG_08_AuxiliaryControl.st** :
  - [ ] Rétablir le bloc de variables locales en `VAR` au lieu de `VAR_INPUT`.
- [ ] **PRG_03_Safety.st** :
  - [ ] Rétablir les entrées `Enable` d'origine sur `instSafetyWinchM1` et `instSafetyWinchM2` (supprimer `AND NOT PRG_10_Outputs.ManuActive`).
  - [ ] Rétablir `Enable := TRUE` sur `instSafetyTranslationM3` (supprimer `NOT PRG_10_Outputs.ManuActive`).

### Phase 3 : Tests de validation
- [ ] Compiler le projet CODESYS sans erreur
- [ ] Télécharger sur l'automate
- [ ] Vérifier que le joystick commande correctement M1/M2/M3 (pas d'override resté actif)
- [ ] Confirmer que les sécurités métier (FB_Safety_Winch/Translation, limites, synchro) sont à nouveau actives
- [ ] Tester l'auto-test redondance AU et le réarmement (EmergencyCutOff doit refonctionner)

### Phase 4 : Commit git
- [ ] Créer un commit unique avec tous les changements de suppression IHM_MANU
- [ ] Message suggéré : `fix(cleanup): remove provisional IHM_MANU bypass after field commissioning`
- [ ] Supprimer ce document de traçabilité (IHM_MANU_Journal_Modifications.md) **OU** le ranger en Archives/

---

## ⚠️ POINTS NON VÉRIFIÉS / À CONFIRMER SUR BANC

### 1. **M3_CommandWord (Registre 0x3101 Variateur AC600)**

**Recette fournisseur (non vérifiée au moment du codage 2026-07-09) :**
- `0x0000` = Arrêt
- `0x0001` = Marche avant
- `0x0002` = Marche arrière

**Actions requises :**
- Avant usage prolongé, forcer le mot de commande depuis CODESYS (instance PRG_10_Outputs.M3_CommandWord) et observer le comportement du variateur à moteur à vide
- **Risque identifié :** Les valeurs réelles du registre 0x3101 côté carte EtherCAT pourraient différer de la recette fournisseur initiale ou avoir des significations alternatives (ex. bits de flags). Corriger immédiatement si comportement anormal (moteur tourne à l'inverse, ignore la fréquence, etc.)
- **Remédiation :** Mettre à jour les lignes 165/168 (M3_CommandWord := 1/2) si la recette change

### 2. **Absence de vérification mode opérateur en IHM_MANU**

Actuellement, il n'y a **pas de vérification du mode machine** (Mode N1/N2/N3/etc.) avant autorisation du mouvement. Tout mouvement est autorisé en mode Manu, quel que soit l'état du mode, sauf les conditions internes de homing (qui restent inchangées).

**Implication :** Un opérateur pourrait forcer un mouvement en mode ARRÊT, par exemple. À vérifier terrain et voir si une protection supplémentaire est souhaitable.

### 3. **Fréquence M3 — pas de bounds-check**

`GVL_IHM.TranslationM3.FreqSetpointHz` (ex-`IHM_MANU.M3_FreqSetpoint`) est clampé à `GVL_PERSISTENT.TranslationMaxFreqHz` dans `PRG_10_Outputs` mais cette limite elle-même n'est pas garantie alignée sur les bornes réelles du variateur (ex. 0–60 Hz nominalement).

**À confirmer :** Les limites du variateur AC600 doivent-elles être respectées en mode Manu ou peut-on libérer complètement ?

### 4. **Timeout DE SÉCURITÉ sur PowerCutOff_A/B_RQ = TRUE FIXE**

En mode Manu, PowerCutOff_A/B_RQ sont maintenues TRUE indéfiniment **sans surveillance de redondance** (ForceTestA/B n'est jamais déclenché). Si une ligne de sécurité tombe en panne et la détection de redondance est perdue, il n'y a **aucun timeout** pour le signaler.

**Implication :** La machine peut tourner longtemps sans savoir que la redondance A OU B est cassée. À investiguer si un mécanisme de supervision est souhaitable (ex. pulse périodique de test même en Manu).

---

## 📊 TABLEAU RÉCAPITULATIF DES RISQUES

| Risque | Gravité | Présence | Mitigation |
|--------|---------|----------|-----------|
| **ModeDisable inversé** — mode Manu ACTIF par défaut | 🔴 CRITIQUE | Oui (conception volontaire) | Vérifier chaque démarrage ; supprimer au nettoyage |
| **PowerCutOff_A/B_RQ = TRUE FIXE** — AU seul protège | 🔴 CRITIQUE | Oui | Seul l'AU matériel indépendant protège |
| **M3_CommandWord non vérifié sur banc** | 🟠 ÉLEVÉ | Oui | Test moteur à vide avant usage prolongé |
| **Pas de vérification mode opérateur** | 🟡 MOYEN | Oui | À confirmer terrain si souhaitable |
| **Pas de supervision redondance PowerCutOff** | 🟡 MOYEN | Oui | Envisager test périodique même en Manu |
| **Fréquence M3 sans limites** | 🟡 MOYEN | Oui | À confirmer si limites variateur doivent s'appliquer |
| ~~**M1/M2 : `FB_Safety_Winch` désactivée en Manu**~~ | ~~🔴 CRITIQUE~~ | **✅ RÉSOLU 2026-07-15** | Sécurité M1/M2 désormais toujours active (section 9), plus un bypass total |
| **`WinchMaxStepFwd/Rev` réactivés (essais progressifs)** | 🟡 MOYEN | Oui (2026-07-15, VOLONTAIRE) | Temporaire assumé — bornage 1..5 + MIN avec plafond Auto en descente (jamais moins protecteur) ; à retirer (section 10) |

---

## 📚 RÉFÉRENCES DOCUMENTS

- **DOC/AF_Partie-03_Template_FB_Commun_v1.3.md** — Contrat FB (interface, précédence Enable/SafeStop/StartStop)
- **DOC/AF_Partie-09_Fonction_Winch_v1.9.md** — Winch M1/M2, safety, garde-fous Méca A–E
- **DOC/AF_Partie-11_Fonction_Translation_v1.3.md** — Translation M3, variateur AC600
- **DOC/AF_Partie-10_Fonction_Encoder_Homing_v1.7.md** — Homing codeurs (conditions Mode/arrêt/capteur)
- **CODE/MAIN/PRG_03_Safety.st** — Logique sécurité normales (PowerCutOff Méca A/B/C)

---

## 🔄 HISTORIQUE

| Date | Auteur | Action |
|------|--------|--------|
| **2026-07-09** | Mise en service urgence | Ajout fonctionnalité IHM_MANU provisoire (ST_IHM_MANU, blocs PR G_10/PRG_02) |
| **2026-07-15** | Session refonte sécurité | M1/M2 branchés sur `FB_Winch`/`PRG_06_WinchControl` (fin du bypass total, sections 8-9) ; nouvelle limite `CableLimitAscentM1/2_M` ; fix Méca B (bit8, boutons HMI) ; fix benne couplé+M1 individuel ; fix latch `FB_Safety_Translation` ; réactivation TEMPORAIRE `WinchMaxStepFwd/Rev` (section 10, **vraie dérogation restante**) |
| **2026-07-15 (2)** | Refonte IHM Translation M3 | Commandes/diag manuels M3 sortis de `ST_IHM_MANU` → `ST_TranslationHMI`/`GVL_IHM.TranslationM3` (définitif, section 11) ; diag variateur décodé ; fix `BypassBrakeFeedback` (fusionné `BypassContactorFeedback`) ; fix simulation position M3 (`FB_Sim_Translation` rebranché, était bloquée) ; rename `GVL_IHM.Joystick` → `JoystickJOY1` (`Benne` : tenté `BenneM2` puis annulé, stutter
avec champs internes M2) — **la dérogation bypass `ManuActive`→`M3_CommandWord` reste, elle, inchangée** |
| **À définir** | Nettoyage | Suppression IHM_MANU après validation terrain (M3/Auxiliaires bypass logique + section 10 restent à retirer) |

---

**Document créé :** 2026-07-09 | **Version :** 1.0  
**État :** 🔴 PROVISOIRE — À SUPPRIMER APRÈS MISE EN SERVICE ACHEVÉE
