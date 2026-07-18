# ✅ Checklist Mise en Service — Translation M3 (AC600 / EtherCAT) — v1.0

> 📌 Répond à **T26** (`DOC/PLAN_TASK_v1.0.md` §3). Mission strictement **documentaire/terrain** :
> aucun fichier `CODE/` modifié, aucun changement de logique, pas de régénération de bundle,
> pas de commit. Checklist dérivée de l'audit croisé de la spec métier et du code réel.
>
> **Sources auditées** :
> - `DOC/AF_Partie-02_Architecture_Programme_v2.12.md` (§3bis codage capteurs, tableau garde-fous Méca A/B)
> - `DOC/AF_Partie-05_Modes_Maintenance_v1.6.md` (E_Mode, MAINT_N1/N2, mot de passe)
> - `DOC/AF_Partie-07_Interface_IHM_v1.5.md` (structures `GVL_IHM`)
> - `DOC/AF_Partie-11_Fonction_Translation_v1.9.md` (spec métier complète Translation)
> - `CODE/MAIN/PRG_07_TranslationControl.st` (arbitrage source de commande M3)
> - `CODE/TRANSLATION/FB_Translation.st`, `FB_Translation_PositionDecoder.st`, `FB_Safety_Translation.st`
> - `CODE/MAIN/PRG_03_Safety.st`, `PRG_00_Inputs.st`, `PRG_01_Diagnostics.st`, `PRG_10_Outputs.st` (câblage réel des instances)
> - `CODE/DIAG/FB_DiagEthercat.st`, `CODE/SUPERVISION/ST_TranslationHMI.st`
> - `CODE/SIMULATION/GVL_Simulation.st`, `CODE/SIMULATION/PLC_TESTS/SUITE_TRANSLATION/FB_TranslationValidation.st` (suite automatisée existante TC-T1→T6)
>
> **Hors périmètre (explicitement exclu par la mission T26)** : paliers/vitesse des codeurs M1/M2
> (`FB_SpeedStep`), séquenceur de cycle (`FB_Cycle`/`E_CycleStep`). Ces sujets sont traités par
> d'autres tâches du plan projet.

---

## 0. Rôle du document et méthode

Cette checklist couvre la mise en service **terrain** de la fonction Translation M3 (variateur
AC600, piloté exclusivement par EtherCAT — pas de mode dégradé par relais, abandonné définitivement
en v1.5, voir §17 point de vigilance). Chaque item précise :
- la **procédure** (comment déclencher la condition testée),
- la **valeur attendue** (seuil/temporisation/comportement, tirés du code réel),
- le **critère Pass/Fail**.

⚠️ Une partie des scénarios de sécurité (fins de course, Méca A, Méca B, incohérence capteurs,
ralentissement PV) est **déjà couverte par une suite de test automatisée en simulation**
(`FB_TranslationValidation`, TC-T1 à TC-T6, `GVL_PLC_Tests.Cmd.RunSuite := SuiteTranslation`
index `2`). Cette checklist :
1. **rappelle** ces cas pour validation croisée en conditions réelles (le test automatisé ne
   remplace pas l'essai physique variateur/capteurs réellement câblés),
2. **couvre en plus** tout ce que la suite automatisée ne teste **pas** (elle le documente
   elle-même dans son en-tête : bit0 perte joystick, bit1 perte com EtherCAT, bit2 rotation de
   phases, bit3 thermique frein — voir §14).

---

## 1. Prérequis banc et sécurité

| # | Prérequis | Valeur attendue | Pass/Fail |
|---|-----------|------------------|-----------|
| 1.1 | `GVL_Simulation.SimulationModeActive` | `FALSE` avant tout essai réel machine (sinon toute la chaîne M3 tourne en simulation logicielle, aucune valeur terrain n'est significative) | ☐ |
| 1.2 | Bascule progressive des `_IsReal` M3 (voir §15 pour méthode détaillée) : `VariateurM3_IsReal`, `TranslationPosition_IsReal`, `ContactorFeedbackM3_IsReal`, `PhaseRotationOk_IsReal`, `BrakeThermal_IsReal` | Chacun passé à `TRUE` un par un au fur et à mesure du câblage réel confirmé | ☐ |
| 1.3 | Chaîne AU physique réarmée | `PRG_00_Inputs.EmergencyStopOk = TRUE` (contact contacteur de puissance confirmé, pas seulement boucle AU) | ☐ |
| 1.4 | Mode machine au démarrage de la checklist | `E_Mode.MAINT_N1` (droits standard, pas de mot de passe) — passer en `MAINT_N2` uniquement pour les items le nécessitant explicitement (§11.6 cible Maintenance) | ☐ |
| 1.5 | Personnel évacué de la zone de débattement translation | Aucune personne dans la trajectoire Trémie↔Maintenance avant tout essai marche avant/arrière (§5) | ☐ |
| 1.6 | Accès IHM disponible : `GVL_IHM.TranslationM3.*` en vue (superviseur ou instance CODESYS online) | Champs `Ready/Busy/Error/ErrorId`, `SafetyError/SafetyErrorId`, `SensorsWord`, `DriveActualFreqHz`, `DriveCommReady/DrivePowerReady` visibles en direct | ☐ |
| 1.7 | Défaut initial acquitté | `PRG_09_Supervision.FaultMachineReset_IHM` disponible (front) pour acquitter tout défaut levé pendant les essais (Reset = front obligatoire, cause disparue + appui) | ☐ |

⚠️ **Point de vigilance majeur** : tant que `SimulationModeActive=TRUE` et qu'un `_IsReal` reste
`FALSE`, le device correspondant est **simulé silencieusement** (pas d'alarme visible) — un
oubli de bascule après câblage réel donne une fausse impression de fonctionnement nominal. Vérifier
explicitement chaque flag avant de conclure un item Pass.

---

## 2. Vérification EtherCAT (bus + variateur AC600)

Diagnostic porté par `FB_DiagEthercat` (`DeviceVariateur`, câblé dans `PRG_01_Diagnostics`) et
repris dans `FB_Safety_Translation` (`DriveOnline`/`DriveOperational`, bit1 `ErrorId`).

| # | Test | Procédure | Valeur attendue | Pass/Fail |
|---|------|-----------|------------------|-----------|
| 2.1 | Device présent sur le bus | Démarrer le maître EtherCAT, `AC600_ECAT_Drive` câblé | `DeviceVariateur.Online = TRUE` | ☐ |
| 2.2 | Device opérationnel (état OP) | Attendre la montée en cycle du maître | `DeviceVariateur.State = 8` (OP) → `DeviceVariateur.Operational = TRUE` ; IHM `DriveCommReady = TRUE` (StatusWord bit7) | ☐ |
| 2.3 | Coupure physique du câble EtherCAT (variateur) | Débrancher le câble EtherCAT du AC600 pendant fonctionnement | `DeviceVariateur.Online` passe `FALSE` sous 1 cycle EtherCAT (4 ms) ; `FB_Safety_Translation.ErrorId` bit1 monte ; `SafeStop=TRUE` immédiat (rampe rapide 100 %/s) | ☐ |
| 2.4 | PowerCutOff sur perte EtherCAT ? | Observer `PRG_03_Safety.instSafetyTranslationM3.PowerCutOff` pendant le test 2.3 | **Reste `FALSE`** — perte EtherCAT seule (bit1) n'entre pas dans le masque `PowerCutOff` (`ErrorId AND 16#00F8`), seul `SafeStop` est déclenché. Ne pas s'attendre à une coupure de puissance sur ce défaut isolé — comportement voulu (voir §14) | ☐ |
| 2.5 | Reconnexion EtherCAT | Rebrancher le câble | `DriveOnline` repasse `TRUE` ; `ErrorId` bit1 ne s'efface **pas** automatiquement (attend un front `Reset`) | ☐ |
| 2.6 | Reset sans cause résolue | Appuyer `FaultMachineReset_IHM` **avant** reconnexion | Le bit reste actif (condition encore vraie) — pas d'effacement tant que `DriveOnline=FALSE` | ☐ |
| 2.7 | Reset après cause résolue | Rebrancher puis appuyer `FaultMachineReset_IHM` (nouveau front) | `ErrorId` bit1 s'efface, `Error` repasse `FALSE` si aucun autre défaut actif | ☐ |
| 2.8 | Mapping I/O CODESYS | Vérifier dans l'arborescence device EtherCAT que `M3_CommandWord`→`0x3101`, `M3_SetpointFrequencyHz`→`0x3100`, `M3_StatusWord`→`0x3102`, `M3_ActualFrequencyHz`→`0x3103` (`Actual Frequency C00.01`) | Adresses PDO conformes à `AF_Partie-11 §5` | ☐ |

---

## 3. Vérification mot de commande AC600 (`DriveControlWord` / `M3_CommandWord`)

Codage nominal (Given Command 1, `0x3101`) : `0`=Aucun/Arrêt, `1`=Marche avant, `2`=Marche arrière, `7`=Reset défaut.

| # | Test | Procédure | Valeur attendue | Pass/Fail |
|---|------|-----------|------------------|-----------|
| 3.1 | Mot à l'arrêt (repos) | Aucune commande, machine au neutre | `DriveControlWord = 0`, `M3_CommandWord = 0` (recopié en sortie par `PRG_10_Outputs`) | ☐ |
| 3.2 | Mot en marche avant | Commander `Direction=+1` (joystick ou `ReqFwd`), homme-mort armé | `DriveControlWord = 1` tant que `MovementRequested=TRUE` (vitesse rampée `> 0.1 %`) | ☐ |
| 3.3 | Mot en marche arrière | Commander `Direction=-1` (`ReqRev`), homme-mort armé | `DriveControlWord = 2` | ☐ |
| 3.4 | Mot pendant un `Reset` | Maintenir `Reset=TRUE` (front) | `DriveControlWord = 7` — prioritaire sur toute autre commande (voir code : test `IF Reset THEN...ELSIF Error...`) | ☐ |
| 3.5 | Mot pendant un défaut (`Error=TRUE`) | Provoquer un défaut (ex. Fdc extrême, §12) | `DriveControlWord = 0` (arrêt forcé, sortie sûre) même si `StartStop`/`Direction` restent actifs | ☐ |
| 3.6 | Cohérence variateur : réponse du AC600 au mot reçu | Observer le variateur physique (afficheur local ou son) lors des tests 3.2/3.3 | Le AC600 démarre effectivement dans le sens correspondant, sans inversion sens/mot | ☐ |
| 3.7 | Sortie sûre au `RETURN` anticipé (`Enable=FALSE` ou `EmergencyStopOk=FALSE`) | Couper `Enable` (ex. via Mode) ou `EmergencyStopOk` | `DriveControlWord := 0` et `DriveFreqRefHz := 0.0` immédiatement, frein resserré (`BrakeCmd=FALSE`) | ☐ |

---

## 4. Vérification fréquence réelle / consigne (`DriveFreqRefHz` / `DriveActualFreqHz`)

Échelle : `0..100 %` de consigne PLC → `0..DriveFreqScaleMaxHz` (60.0 Hz, réglage RETAIN
`FB_Translation.DriveFreqScaleMaxHz`). Codage bus : `Hz × 100` (centi-Hz, `UINT`/`WORD`).

| # | Test | Procédure | Valeur attendue | Pass/Fail |
|---|------|-----------|------------------|-----------|
| 4.1 | Conversion consigne → Hz | Commander une consigne connue (ex. 50 % pleine échelle) | `DriveFreqRefHz ≈ 30.0 Hz` (50 % × 60 Hz) — nominal machine (voir commentaire code : "fonctionnement standard/nominal 30Hz à 50% de consigne") | ☐ |
| 4.2 | Conversion pleine échelle | Consigne 100 % (butée haute joystick ou `FreqSetpointHz = _TranslationMaxFreq_Hz = 60.0 Hz` en MAINT) | `DriveFreqRefHz ≈ 60.0 Hz`, jamais au-delà (voir clamp final §4.5) | ☐ |
| 4.3 | Codage bus centi-Hz | Lire `M3_SetpointFrequencyHz` (PDO brut) pendant le test 4.1 | Valeur ≈ `3000` (30.00 Hz × 100), cohérent avec `REAL_TO_UINT(DriveFreqRefHz * 100.0)` (`PRG_10_Outputs`) | ☐ |
| 4.4 | Fréquence réelle mesurée | Une fois en marche stabilisée, comparer affichage variateur local vs `DriveActualFreqHz` (PLC) | Écart < 1 Hz (tolérance capteur/bus) ; `M3_ActualFrequencyHz_Filtered` = `M3_ActualFrequencyHz` brut ÷ 100 | ☐ |
| 4.5 | Clamp final de sécurité (0..100 %) | Forcer artificiellement une consigne hors plage en amont (ex. `FreqSetpointHz` opérateur > `_TranslationMaxFreq_Hz` saisi manuellement) | `PRG_07_TranslationControl` applique `M3_SpeedRef_Active := LIMIT(0.0, ABS(M3_SpeedRef_Active), 100.0)` **avant** `FB_Translation` — la consigne ne dépasse jamais 100 % / 60 Hz quelle que soit la source (joystick, IHM, cycle) | ☐ |
| 4.6 | Rampe d'accélération | Depuis l'arrêt, commander `StartStop=TRUE` à pleine consigne | Montée en fréquence à `RampAccelRate = 20.0 %/s` (soit ≈12 Hz/s) — pas de à-coup | ☐ |
| 4.7 | Ralentissement à l'approche (voir aussi §10) | Approcher Trémie avec `SlowdownSensor` actif | `DriveFreqRefHz` plafonné à `ApproachSpeedPct = 20.0 %` (≈12 Hz), uniquement `Direction=1` | ☐ |

---

## 5. Essai marche avant / arrière

Rappel sécurité **v1.9** (`AF_Partie-11 §6bis`) : depuis la suppression d'IHM_MANU, **le
homme-mort joystick (`DeadmanArmed`) est exigé quel que soit le mode de pilotage** (boutons IHM
`ReqFwd`/`ReqRev` **ou** joystick) — un oubli de vérifier cette condition invaliderait le test.

| # | Test | Procédure | Valeur attendue | Pass/Fail |
|---|------|-----------|------------------|-----------|
| 5.1 | Marche avant, pilotage joystick | `Mode=MAINT_N1`, `JoystickSelect=TRUE`, joystick homme-mort armé, déflexion axe X positive | `Direction=+1`, `StartStop=TRUE` uniquement si `DeadmanArmed=TRUE` et `AxisCmdX.StartStop=TRUE` ; machine avance | ☐ |
| 5.2 | Marche avant, pilotage boutons IHM | `JoystickSelect=FALSE`, `ReqFwd=TRUE`, **joystick maintenu homme-mort à part** | Le mouvement ne démarre **que si** `DeadmanArmed=TRUE` en parallèle — `ReqFwd` seul (sans homme-mort actif) ne doit produire **aucun** mouvement (`M3_StartStop_Active=FALSE`) | ☐ |
| 5.3 | Marche arrière, pilotage joystick | Symétrique à 5.1, déflexion axe X négative | `Direction=-1`, comportement identique en miroir | ☐ |
| 5.4 | Marche arrière, pilotage boutons IHM | Symétrique à 5.2 avec `ReqRev` | Idem 5.2, homme-mort obligatoire | ☐ |
| 5.5 | Relâchement homme-mort en cours de marche | Marche avant en cours (5.1), relâcher le bouton homme-mort joystick | `DeadmanArmed→FALSE` ⇒ `StartStop→FALSE` ⇒ rampe décel **normale** (40 %/s, pas d'arrêt instantané) puis arrêt frein | ☐ |
| 5.6 | Cible atteinte pendant la marche | Laisser translater jusqu'à un capteur de position cible (P1/P2/Trémie/Maintenance) | `TargetReached=TRUE` (après debounce `CaptorDebounce=100ms`) ⇒ `ArrivalLock=TRUE` ⇒ vitesse forcée à 0 dans le sens d'arrivée ; seul le sens opposé permet de se dégager | ☐ |
| 5.7 | Sélection de cible interdite hors MAINT_N2 | En `MAINT_N1`, sélectionner cible `4` (Maintenance) | `SelectedTargetNum` forcé à `0` (`MaintenanceM3TargetEnable=FALSE` hors `MAINT_N2`) — pas d'accès à la zone Maintenance sans droits étendus | ☐ |
| 5.8 | Sélection de cible autorisée en MAINT_N2 | Passer `Mode=MAINT_N2` (mot de passe), sélectionner cible `4` | `MaintenanceM3TargetEnable=TRUE`, cible acceptée, capteur `TranslationPosMaintenance` câblé sur `M3_PositionSensorTarget` | ☐ |

---

## 6. Interlock changement de sens

Règle (`FB_Translation` §5, doc `AF_Partie-11 §4.2`) : toute inversion directe exige l'arrêt
complet confirmé (`ABS(SpeedRamp.Current) < 0.1 %`) **et** l'écoulement de
`DirectionInterlockDelay = T#200ms`.

| # | Test | Procédure | Valeur attendue | Pass/Fail |
|---|------|-----------|------------------|-----------|
| 6.1 | Inversion depuis l'arrêt complet | Machine à l'arrêt (`Direction=0`), demander directement `Direction=+1` ou `-1` | Prise en compte **immédiate** (`CommandedDirection := Direction` sans délai) — le délai ne s'applique pas au premier démarrage | ☐ |
| 6.2 | Inversion en mouvement | Marche avant en cours à vitesse non nulle, inverser la demande à `Direction=-1` directement | `CommandedDirection` reste sur l'ancien sens tant que `ABS(SpeedRamp.Current) ≥ 0.1 %` — la machine décélère d'abord | ☐ |
| 6.3 | Délai de 200 ms respecté | Poursuivre le test 6.2 jusqu'à vitesse confirmée nulle | Le nouveau sens n'est appliqué qu'après `T#200ms` supplémentaires une fois `ABS(SpeedRamp.Current) < 0.1 %` — chronométrer pour confirmer | ☐ |
| 6.4 | Pas de Fwd+Rev simultané | Observer `DriveControlWord` pendant toute la manœuvre 6.2/6.3 | Jamais de commande incohérente ; `DriveControlWord=0` pendant la phase de transition | ☐ |
| 6.5 | Redémarrage rapide même sens | Demander à nouveau le même sens juste après une inversion refusée | Pas de pénalité supplémentaire — le délai ne s'applique qu'au changement de sens réel | ☐ |

---

## 7. Arrêt normal (`StartStop`)

| # | Test | Procédure | Valeur attendue | Pass/Fail |
|---|------|-----------|------------------|-----------|
| 7.1 | Décélération normale | Marche stabilisée, couper `StartStop` (relâchement homme-mort ou bouton), **sans** `SafeStop` actif | Décélération à `RampDecelNormalRate = 40.0 %/s` jusqu'à 0, puis `DriveControlWord=0` et frein réappliqué | ☐ |
| 7.2 | État machine pendant l'arrêt | Observer `FB_Translation.State` pendant 7.1 | `State = E_State.STOPPING` tant que `ABS(SpeedRamp.Current) > 0.1 %`, puis `E_State.READY` | ☐ |
| 7.3 | Séquence frein à l'arrêt | Observer `BrakeCmd`/`BrakeFeedback` en fin de décélération | Frein réengagé (`BrakeCmd→FALSE`) selon la séquence `FB_Brake` standard (délais `BrakeDelayMotorDecel=500ms` puis fermeture) | ☐ |
| 7.4 | Pas de redémarrage automatique | Une fois à l'arrêt complet, ne renvoyer aucune commande | La machine reste à l'arrêt indéfiniment — aucun redémarrage spontané | ☐ |

---

## 8. `SafeStop`

Sortie de `FB_Safety_Translation`, rampe **rapide** (`RampDecelFastRate = 100.0 %/s`), `Enable`
maintenu (pas une neutralisation totale — conforme précédence `Enable > SafeStop > StartStop`).

| # | Test | Procédure | Valeur attendue | Pass/Fail |
|---|------|-----------|------------------|-----------|
| 8.1 | Déclenchement SafeStop en marche | Provoquer n'importe quel défaut `FB_Safety_Translation` (ex. perte joystick, §14) pendant un mouvement | `SafeStop=TRUE` ⇒ décélération à 100 %/s (plus rapide que l'arrêt normal 7.1) — comparer les deux temps d'arrêt pour confirmer la différence | ☐ |
| 8.2 | `Enable` reste actif pendant SafeStop | Observer `FB_Translation.Ready`/`State` pendant 8.1 | `Ready=TRUE` maintenu (pas de neutralisation totale comme sur `Enable=FALSE`) — seule la rampe change | ☐ |
| 8.3 | Impossible de redémarrer tant que SafeStop actif | Tenter `StartStop=TRUE` pendant que `SafeStop=TRUE` | Précédence respectée : consigne reste à 0 (`IF NOT SafeStop AND StartStop`) | ☐ |
| 8.4 | Sortie de SafeStop après cause résolue + Reset | Résoudre la cause (ex. reconnecter joystick), puis front `Reset` | `SafeStop` retombe à `FALSE`, mouvement à nouveau possible sur nouvelle commande | ☐ |

---

## 9. Arrêt d'urgence (AU)

⚠️ **Rappel spec (`AF_Partie-11` bandeau v1.5, avertissement STO)** : l'entrée matérielle Safe
Torque Off du AC600 **n'est pas câblée** sur la boucle d'AU. La coupure se fait par contacteurs
amont — un glissement en roue libre temporaire est possible pendant la fermeture mécanique du
frein. Ce comportement est **attendu**, pas un défaut.

| # | Test | Procédure | Valeur attendue | Pass/Fail |
|---|------|-----------|------------------|-----------|
| 9.1 | Appui AU pendant marche | Actionner l'arrêt d'urgence physique pendant un mouvement M3 | `EmergencyStopOk→FALSE` ⇒ `FB_Translation` neutralisation totale immédiate (`DriveControlWord:=0`, `DriveFreqRefHz:=0.0`, `BrakeCmd:=FALSE`, `Ready=FALSE`) — **sans rampe**, coupure directe | ☐ |
| 9.2 | Glissement roue libre observé | Pendant 9.1, observer le comportement mécanique réel | Glissement bref possible le temps de la fermeture mécanique du frein (non instantané) — vérifier que ce délai reste dans une plage acceptable au poste, sinon remonter au projet | ☐ |
| 9.3 | Coupure puissance amont confirmée | Vérifier `PRG_03_Safety` → `PowerCutOff` général et `PRG_10_Outputs.PowerCutOff_A_RQ`/`PowerCutOff_B_RQ` | Les deux relais redondants (1oo2) sont sollicités | ☐ |
| 9.4 | Réarmement après AU | Relâcher/réarmer l'AU physique, confirmer `EmergencyStopOk=TRUE`, puis front `Reset` | Machine de nouveau disponible (`Ready=TRUE`) uniquement après réarmement **et** reset — pas de redémarrage auto | ☐ |
| 9.5 | AU pendant SafeStop déjà actif | Déclencher AU alors qu'un SafeStop est déjà en cours (§8) | La neutralisation totale de `EmergencyStopOk=FALSE` prime immédiatement sur le SafeStop en cours (`Enable > SafeStop`, testé en premier dans le code) | ☐ |

---

## 10. PV et ralentissement avant Trémie

Le capteur **PV** (Point de Vitesse) n'est **jamais** une cible d'arrêt — uniquement un point de
ralentissement, **et seulement en direction Trémie** (`Direction=1`). Décision client
(`AF_Partie-02 v2.12 §3bis`) : PV n'assure aucun ralentissement en sens Maintenance.

| # | Test | Procédure | Valeur attendue | Pass/Fail |
|---|------|-----------|------------------|-----------|
| 10.1 | Ralentissement à l'approche Trémie | Marche avant (`Direction=1`) à pleine vitesse, franchir le capteur PV | `RampTargetPct` plafonné à `ApproachSpeedPct=20.0%` dès `SlowdownSensor=TRUE` ; fréquence chute à ≈12 Hz avant d'atteindre Trémie | ☐ |
| 10.2 | Pas de ralentissement en sens Maintenance | Marche arrière (`Direction=-1`), franchir la zone PV en s'éloignant de Trémie | Aucun plafonnement — vitesse pleine échelle maintenue (le ralentissement PV ne s'applique qu'à `Direction=1`) | ☐ |
| 10.3 | PV n'est pas une cible d'arrêt | Observer le comportement au passage PV (les deux sens) | Le mouvement continue au-delà de PV sans `ArrivalLock` (PV exclu de `CASE SelectedTargetNum` — capteur cible jamais câblé sur PV) | ☐ |
| 10.4 | Arrêt exact ensuite sur Trémie | Poursuivre jusqu'au capteur Trémie après ralentissement PV | Arrêt net sur `PositionTremie=TRUE` (debounce 100 ms), `ArrivalLock=TRUE` | ☐ |

---

## 11. Capteurs Trémie/PV/P1/P2/Maintenance (mot 5 bits)

Décodage `FB_Translation_PositionDecoder` : ordre `Trémie(bit4)|PV(bit3)|P2(bit2)|P1(bit1)|Maintenance(bit0)`.
Seules 6 combinaisons monotones sont valides.

| # | Mot binaire | Zone | Test | Valeur attendue | Pass/Fail |
|---|-------------|------|------|------------------|-----------|
| 11.1 | `11111` | Extrême gauche / Trémie | Positionner physiquement en Trémie | `LimitSwitchFwd=TRUE`, `Incoherent=FALSE`, `SensorsWord=16#1F` | ☐ |
| 11.2 | `01111` | Entre Trémie et PV | Position intermédiaire | `Incoherent=FALSE`, aucune limite active | ☐ |
| 11.3 | `00111` | P2 | Position de travail P2 | `Incoherent=FALSE`, `TranslationPosP2=TRUE` seul actif dans le groupe travail | ☐ |
| 11.4 | `00011` | P1 | Position de travail P1 | `Incoherent=FALSE` | ☐ |
| 11.5 | `00001` | Entre P1 et Maintenance | Position intermédiaire | `Incoherent=FALSE` | ☐ |
| 11.6 | `00000` | Extrême droite / Maintenance | Positionner physiquement en Maintenance (nécessite `MAINT_N2`, §5.8) | `LimitSwitchRev=TRUE`, `Incoherent=FALSE` | ☐ |
| 11.7 | Mot incohérent (ex. `10101`, capteur collé) | — | Forcer/simuler un capteur en défaut (deux capteurs non adjacents actifs) | `Incoherent=TRUE` ⇒ `FB_Safety_Translation.ErrorId` bit7 ⇒ **`SafeStop` ET `PowerCutOff`** (défense en profondeur, décision client) | ☐ |
| 11.8 | Chaque capteur individuellement câblé | Actionner chaque capteur TOR un par un à vide (hors mouvement) | `PRG_00_Inputs.TranslationPos<Zone>` bascule sans rebond excessif (filtre `T#20ms` sur chaque `FB_Input`) | ☐ |
| 11.9 | Cohérence mot IHM | Comparer `GVL_IHM.TranslationM3.SensorsWord` (bit4..bit0) affiché avec la position physique réelle | Correspondance exacte à chaque étape 11.1→11.6 | ☐ |

---

## 12. Fins de course extrêmes gauche/droite

| # | Test | Procédure | Valeur attendue | Pass/Fail |
|---|------|-----------|------------------|-----------|
| 12.1 | Fdc avant (Trémie) atteint en marche avant | Approcher Trémie jusqu'à `LimitSwitchFwd=TRUE` en `Direction=1` | Coupure **instantanée** (sans rampe) : `DriveControlWord:=0`, `DriveFreqRefHz:=0.0` — pas de décélération progressive | ☐ |
| 12.2 | Fdc arrière (Maintenance) atteint en marche arrière | Symétrique en `Direction=-1`, `LimitSwitchRev=TRUE` | Idem 12.1 en miroir | ☐ |
| 12.3 | Dégagement possible dans le sens opposé | Une fois bloqué sur un Fdc extrême, commander le sens opposé | Mouvement de dégagement autorisé (le blocage ne s'applique qu'au sens qui a causé l'atteinte de la butée) | ☐ |
| 12.4 | Défaut sécurité associé | Observer `FB_Safety_Translation.ErrorId` pendant 12.1/12.2 | Bit6 levé ⇒ `SafeStop` **et** `PowerCutOff` (masque `0x00F8` inclut bit6) | ☐ |
| 12.5 | Pas de Fdc fantôme sur mot incohérent | Pendant un test §11.7 (mot incohérent), vérifier `LimitSwitchFwd`/`Rev` | Restent `FALSE` — `FB_Translation_PositionDecoder` calcule les limites **uniquement sur mot valide** (`NOT Incoherent AND ...`), évite un Fdc fantôme déclenché par une incohérence | ☐ |

---

## 13. Retour thermique — périmètre à clarifier

⚠️ **Point de clarification terrain** : la mission mentionne un "retour thermique centrale si
concerné". L'audit du code montre **deux thermiques distincts et indépendants**, à ne pas confondre :

| # | Test | Procédure | Valeur attendue | Pass/Fail |
|---|------|-----------|------------------|-----------|
| 13.1 | Thermique **frein commun M1/M2/M3** (`BrakeThermalFeedback`) — **applicable à M3** | Simuler/déclencher la surchauffe du retour thermique frein commun | `FB_Safety_Translation.ErrorId` bit3 levé ⇒ **`SafeStop` + `PowerCutOff`** (masque `0x00F8` inclut bit3) | ☐ |
| 13.2 | Thermique **centrale hydraulique** (`HydraulicThermal_IsReal`, `PRG_08_AuxiliaryControl`) — **NON applicable à M3** | Vérifier le câblage/logique | Ce signal (`HydraulicFaultOk`) n'est **câblé sur aucune entrée de `FB_Safety_Translation`** — le variateur AC600 est un axe électrique, indépendant de la centrale hydraulique. Confirmer qu'aucun câblage terrain ne relie à tort ce retour à M3 | ☐ |
| 13.3 | Reset du défaut thermique frein (13.1) | Laisser refroidir, puis front `Reset` | Bit3 s'efface uniquement après retour à `BrakeThermalFeedback=FALSE` (cause disparue) + reset | ☐ |

📌 **Si la machine réelle expose un autre retour thermique lié à M3** (ex. thermique moteur
variateur dédiée, distincte du frein commun) **non présent dans le code actuel**, remonter au
projet avant mise en service — cette checklist ne peut valider que ce qui existe dans le code
audité (voir §17 limites).

---

## 14. Diagnostics complémentaires non couverts par la suite automatisée

La suite `FB_TranslationValidation` (TC-T1→T6, simulation) documente elle-même ne **pas** tester
les bits 0/1/2/3 de `FB_Safety_Translation` (nécessiteraient des overrides supplémentaires sur les
diagnostics bus). Ces items sont donc **exclusivement terrain**, à couvrir ici :

| # | Test | Procédure | Valeur attendue | Pass/Fail |
|---|------|-----------|------------------|-----------|
| 14.1 | Perte joystick CANopen (bit0) | Débrancher/couper le bus CAN joystick pendant un mouvement M3 | `JoystickOnline`/`JoystickOperational→FALSE` ⇒ `ErrorId` bit0 ⇒ `SafeStop=TRUE`, **pas** de `PowerCutOff` (bit0 hors masque `0x00F8`) | ☐ |
| 14.2 | Perte com EtherCAT variateur (bit1) | Déjà couvert en détail §2.3/2.4 | Voir §2 | ☐ |
| 14.3 | Mauvaise rotation de phases (bit2) | Provoquer/simuler une inversion de rotation de phase (`PhaseRotationOk_DI`) | `ErrorId` bit2 ⇒ `SafeStop=TRUE` seul, **pas** de `PowerCutOff` (bit2 hors masque) | ☐ |
| 14.4 | Thermique frein commun (bit3) | Déjà couvert en détail §13.1 | Voir §13 | ☐ |
| 14.5 | Combinaison multiple | Provoquer 2 défauts simultanés (ex. bit1 + bit6) | `ErrorId` cumule les deux bits (bitfield OR), `PowerCutOff` s'active dès qu'au moins un bit du masque `0x00F8` est présent | ☐ |
| 14.6 | Cohérence IHM des diagnostics découplés | Comparer `GVL_IHM.TranslationM3.SafetyError*` (champs décomposés bit par bit) avec `SafetyErrorId` brut pendant 14.1/14.3 | Chaque booléen IHM (`SafetyErrorJoystick`, `SafetyErrorPhaseRotation`, etc.) reflète exactement le bit correspondant, pas de bit-masking à faire côté IHM | ☐ |

---

## 15. Simulation puis essai réel — méthode de bascule

Conforme au modèle `GVL_Simulation` (`AF_Partie-13`) : bit maître `SimulationModeActive` + un
`_IsReal` par device, bascule **un par un**, jamais de modification de code nécessaire.

| # | Étape | Flag à bascule | Ce que ça déverrouille |
|---|-------|-----------------|--------------------------|
| 15.1 | Validation logique pure (banc, aucun câblage réel) | `SimulationModeActive=TRUE`, tous `_IsReal=FALSE` | Rejoue `FB_TranslationValidation` (TC-T1→T6) en toute sécurité |
| 15.2 | Variateur AC600 réellement raccordé EtherCAT | `VariateurM3_IsReal=TRUE` | §2, §3, §4 deviennent significatifs (mot de commande réel, fréquence réelle) |
| 15.3 | Capteurs de position réellement câblés | `TranslationPosition_IsReal=TRUE` | §10, §11, §12 deviennent significatifs |
| 15.4 | Retour contacteur/frein M3 réellement câblé | `ContactorFeedbackM3_IsReal=TRUE` | Diagnostic frein (`BrakeContactorCheck`) fiable, plus de bypass |
| 15.5 | Contrôle rotation de phase réellement câblé | `PhaseRotationOk_IsReal=TRUE` | §14.3 devient significatif |
| 15.6 | Thermique frein commun réellement câblé | `BrakeThermal_IsReal=TRUE` | §13.1 devient significatif |
| 15.7 | Bascule finale | `SimulationModeActive=FALSE` | Coupe toute simulation résiduelle d'un coup — dernière étape, une fois tous les `_IsReal` ci-dessus confirmés `TRUE` |

⚠️ Ne **jamais** passer `SimulationModeActive=FALSE` avant d'avoir confirmé individuellement
chaque device réel (15.2→15.6) — sinon un device non câblé se retrouve sans aucune simulation de
secours (comportement indéterminé selon l'état électrique flottant de l'entrée).

---

## 16. Synthèse Pass/Fail — tableau récapitulatif

| Section | Nb items | Pass | Fail | Non testé (préciser raison) |
|---------|----------|------|------|------------------------------|
| 1. Prérequis banc | 7 | ☐ | ☐ | |
| 2. EtherCAT | 8 | ☐ | ☐ | |
| 3. Mot de commande | 7 | ☐ | ☐ | |
| 4. Fréquence réelle/consigne | 7 | ☐ | ☐ | |
| 5. Marche avant/arrière | 8 | ☐ | ☐ | |
| 6. Interlock changement de sens | 5 | ☐ | ☐ | |
| 7. Arrêt normal | 4 | ☐ | ☐ | |
| 8. SafeStop | 4 | ☐ | ☐ | |
| 9. Arrêt d'urgence | 5 | ☐ | ☐ | |
| 10. PV et ralentissement | 4 | ☐ | ☐ | |
| 11. Capteurs 5 positions | 9 | ☐ | ☐ | |
| 12. Fins de course extrêmes | 5 | ☐ | ☐ | |
| 13. Retour thermique | 3 | ☐ | ☐ | |
| 14. Diagnostics complémentaires | 6 | ☐ | ☐ | |
| 15. Simulation → réel | 7 étapes (progression, pas Pass/Fail unitaire) | — | — | |

**Verdict global mise en service Translation M3** : ☐ PASS (tout Pass ou Non-testé justifié) — ☐ FAIL (au moins un Fail bloquant sécurité, §8/9/12/13/14 prioritaires)

---

## 17. Références

- `DOC/AF_Partie-02_Architecture_Programme_v2.12.md` §3bis (codage capteurs), tableau garde-fous Méca A/B
- `DOC/AF_Partie-05_Modes_Maintenance_v1.6.md` (E_Mode, MAINT_N1/N2, mot de passe)
- `DOC/AF_Partie-07_Interface_IHM_v1.5.md` (structures GVL_IHM)
- `DOC/AF_Partie-11_Fonction_Translation_v1.9.md` (spec métier complète, §6bis homme-mort obligatoire)
- `DOC/AF_Partie-14_PLC_Tests_Validation_v1.2.md` (framework de test in-PLC, `SuiteTranslation`)
- `CODE/MAIN/PRG_07_TranslationControl.st` (arbitrage source de commande)
- `CODE/TRANSLATION/FB_Translation.st`, `FB_Translation_PositionDecoder.st`, `FB_Safety_Translation.st`
- `CODE/SIMULATION/PLC_TESTS/SUITE_TRANSLATION/FB_TranslationValidation.st` (TC-T1→T6)

---

## 18. Limites de cette checklist

- **Aucun graphique IHM dédié n'a été audité** (hors périmètre) : toute lecture de champ
  (`SensorsWord`, `ErrorId`, `DriveActualFreqHz`...) suppose un accès à l'instance CODESYS online
  ou à une vue superviseur déjà construite exposant `GVL_IHM.TranslationM3.*`.
- **§4.5 (limitation finale 0-100 %)** est vérifié par lecture de code (`PRG_07_TranslationControl.st`
  ligne "Limitation finale M3"), pas par essai physique dans cette session — à confirmer au banc.
- **Cohérence architecture** : ✅ `AF_Partie-02` v2.12 indique désormais le pilotage EtherCAT
  exclusif ; l'ancien `CommMode DEGRADED_IO` est retiré du code réel.
- **§9.2 (glissement roue libre à l'AU)** ne peut être quantifié que par essai physique réel — pas
  de valeur numérique attendue disponible dans le code ou la spec (avertissement qualitatif
  uniquement, `AF_Partie-11` bandeau v1.5).
- **§13** signale une clarification de périmètre découverte pendant l'audit (deux thermiques
  distincts) plutôt qu'un défaut — à confirmer avec l'électricien/automaticien terrain avant de
  cocher Pass/Fail.
