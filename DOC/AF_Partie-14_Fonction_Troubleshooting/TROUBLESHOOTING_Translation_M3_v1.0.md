# 🩺 Troubleshooting Translation M3 — v1.0

> 🎯 Guide de mise en service et dépannage terrain, chronologique, pour la Translation M3
> (variateur AC600 EtherCAT). Complète la table générique `AF_Partie-14_Fonction_Troubleshooting_v1.1.md`
> §5 (`TranslationPontM3`) avec le détail spécifique M3 : chaque cause de blocage, dans l'ordre où
> la rencontrer, avec la variable exacte à observer en Watch CODESYS.
> 📄 Sources : `CODE/TRANSLATION/*.st`, `CODE/MAIN/PRG_02_Acquisition.st`, `PRG_05_Translation.st`,
> `PRG_06_Outputs_LD.st`. Spec métier : `DOC/AF_Partie-11_Fonction_Translation_v2.1.md`.
> ⚠️ **Lecture seule stricte** — ce document n'est pas une procédure d'action machine, c'est une
> aide à l'observation. Toute action reste sous la responsabilité de l'opérateur/automaticien.

---

## ⚠️ Prérequis à lire AVANT tout essai (état du code au 2026-08-05, mis à jour après LOT0/M4/LOT3/LOT2 + audit sécurité)

Les 4 lots identifiés le 2026-08-05 sont **implémentés et vérifiés côté code** (`check_linkage.py`,
`check_ld_invariants.py` PASS). Un audit sécurité indépendant a ensuite trouvé 2 trous **encore
réels** qui bloquent ou dégradent un essai M3 — à ne pas confondre avec un défaut terrain :

| # | Trou | État | Effet sur l'essai | Réf. |
|---|---|---|---|---|
| 1 | `SafetyStructureNotValidated := TRUE` (garde-fou global, `PRG_06_Outputs_LD.st`) | 🔴 **Toujours bloquant, non touché par ces lots** | **Aucune sortie moteur/frein M1/M2/M3 n'est autorisée**, quoi que fasse l'opérateur — c'est une seule variable partagée par M1/M2/M3 : la lever pour tester M3 arme aussi M1/M2 | `PRG_06_Outputs_LD.st:45` |
| 2 | `FB_Safety_Translation` jamais instancié | ✅ **Résolu (lot M4)** | `SafeStop` M3 réagit désormais aux 8 mécanismes (perte comm, rotation phase, thermique frein, Méca A/B, butées, incohérence capteurs), plus `InputModuleFault` | AF_Partie-11 v2.1 §5 alerte 5 (résolue), PLAN_TASK T104 |
| 3 | Commande AC600 (`DriveControlWord`/`DriveFreqRefHz`) jamais écrite en sortie physique | ✅ **Résolu côté ST (lot LOT2)** — ⚠️ **mapping E/S CODESYS manuel restant** | `DriveControlWord`/`DriveFreqRefWord` calculés et capturés dans `PRG_06_Outputs_LD` (`M3_DriveControlWord`/`M3_DriveFreqRefWord`), mais le raccordement final aux registres PDO (`M3_CommandWord` %QW6, `M3_SetpointFrequencyHz` %QW7) est un geste **manuel CODESYS** (I/O mapping dialog) — tant qu'il n'est pas fait, le moteur ne tourne toujours pas | AF_Partie-11 v2.1 §5 alerte 6 (résolue), PLAN_TASK T105, `PRG_06_Outputs_LD.st` §2 |
| 4 | 🆕 `PowerCutOff` M3 est une impasse (`PRG_06_Outputs_LD.st:229`, `PowerCutOffReq := FALSE` figé) | 🔴 **Trouvé par l'audit sécurité 2026-08-05, non résolu** | `instSafetyTranslationM3.PowerCutOff` (5 mécanismes/8 : thermique frein, Méca A/B, butées, incohérence capteurs) est calculé mais **rien ne le transmet à la coupure amont réelle** — seul `SafeStop` (rampe + frein) réagit concrètement. Le seul actuateur de coupure puissance existant est la chaîne AU/sécurité mécanique (`instSafetyEmergencyManagement`) | Audit sécurité 2026-08-05, `TASK_CONTEXT_M5_OUTPUTS_POWERCUTOFF.yaml` |
| 5 | 🆕 Homme-mort (`DeadmanArmed`) exigé sur M3 seul | ✅ **Résolu (lot LOT3)**, ⚠️ écart M1/M2 non traité | `M3_StartStop_Active` exige `JoystickDeadmanArmed` en MAINT_N1/N2. **M1/M2 (treuils) n'ont pas cette exigence** — écart entre domaines, hors périmètre de ce document | PLAN_TASK T106 |

➡️ Un essai M3 réel (moteur qui tourne) reste **bloqué** tant que #1 (garde-fou global) et le
mapping E/S manuel (#3) ne sont pas faits. Un essai à blanc (capteurs, IHM, calculs internes,
frein seul, réaction `SafeStop` complète) est possible et utile dès maintenant — voir §1 à §4.
⚠️ **Le trou #4 (`PowerCutOff`) reste un risque résiduel réel une fois le moteur commandable** :
sur perte comm EtherCAT pendant un mouvement, seul le frein mécanique arrête la machine.

---

## 1. Ordre de diagnostic (haut → bas, ne jamais sauter une étape)

```text
1. Modules DI (santé matérielle)          → §2
2. Mode machine (autorisation)             → §3
3. Capteurs de position (5 capteurs)       → §4
4. Communication (Joystick / EtherCAT)     → §5
5. Sécurité mouvement (Méca A/B, safety)   → §6  ⚠️ SafeStop actif, PowerCutOff amont encore un trou (prérequis #4)
6. Frein                                    → §7
7. Commande moteur AC600                    → §8  ⚠️ calculé, mapping E/S manuel restant (prérequis #3)
8. Barrière finale / interlock              → §9
9. Bypass actifs (vérifier qu'aucun ne masque le symptôme)  → §10
```

Une étape non conforme invalide toutes les suivantes : ne pas conclure sur le frein si les
capteurs de position sont déjà incohérents.

---

## 2. Modules DI (santé matérielle)

| Observable | Nominal | Si défaut | Action |
|---|---|---|---|
| `PRG_02_Acquisition.LocalDigitalIoOk` | `TRUE` | `FALSE` | Vérifier alimentation/bus du module portant M3 |
| `PRG_02_Acquisition.Vh0800EndOk` / `Vh0808EtpOk` | `TRUE` | `FALSE` | Idem, module concerné |
| `PRG_02_Acquisition.InputModuleFault` | `FALSE` | `TRUE` | Agrégat des 3 modules ; une des 9 causes de `SafeStop` M3 depuis le lot M4 (§6) |

Table complète (transverse M1/M2/M3) : `AF_Partie-14_Fonction_Troubleshooting_v1.1.md` §2.2.

---

## 3. Mode machine (autorisation)

| Observable | Attendu pour jog/positionneur | Sinon |
|---|---|---|
| `PRG_03_Modes_Cycle.Auth.Mode` | `MAINT_N1` ou `MAINT_N2` pour jog manuel ; `SEMI_AUTO` pour positionneur automatique | Aucune commande M3 n'est arbitrée (`PRG_05_Translation.st` §1 force tout à neutre hors ces modes) |
| `PRG_03_Modes_Cycle.Auth.MaintenanceM3TargetEnable` | `TRUE` uniquement en `MAINT_N2` | Cible "Maintenance" (SelTarget=4) refusée sinon (TC-P11-012) — comportement voulu, pas un bug |

---

## 4. Capteurs de position (5 capteurs — `FB_Translation_PositionDecoder`, instance `instPosDecoderM3` dans `PRG_02_Acquisition`)

Ordre physique attendu, mot binaire `SensorsWord` (bit4=Trémie … bit0=Maintenance) :

```text
11111 → 01111 → 00111 → 00011 → 00001 → 00000
Trémie                                    Maintenance
```

| Observable | Nominal | Si défaut | Cause probable |
|---|---|---|---|
| `PRG_02_Acquisition.M3_SensorsWord` | Une des 6 valeurs ci-dessus | Autre valeur | Capteur collé/HS, câblage croisé — **jamais forcer**, identifier physiquement |
| `PRG_02_Acquisition.M3_SensorWordIncoherent` | `FALSE` | `TRUE` | Mot hors table — bloque théoriquement `SafeStop`+`PowerCutOff` (⚠️ inopérant tant que prérequis #2 non résolu — vérifier `SensorWordIncoherent` directement, pas son effet) |
| `PRG_02_Acquisition.M3_LimitSwitchFwd` | `TRUE` uniquement mot=`11111` (extrême Trémie) | Autrement | Dérivé du décodeur, jamais un capteur physique séparé |
| `PRG_02_Acquisition.M3_LimitSwitchRev` | `TRUE` uniquement mot=`00000` (extrême Maintenance) | Autrement | Idem |
| `PRG_02_Acquisition.TranslationPosPV` | `TRUE` en approche Trémie uniquement | Toujours `FALSE`/`TRUE` | Capteur PV (ralentissement) — historiquement mal câblé (T80, résolu 2026-07-27), revérifier si régression |

**Piège connu (T80, déjà corrigé)** : le capteur PV a longtemps été lu depuis un stub jamais
alimenté (`GVL_Translation_M3_Stub.PosPV_DI`). Si un ralentissement avant Trémie ne se produit
jamais, vérifier que le remappage `M3_PosPV_DI` est toujours en place avant de chercher ailleurs.

---

## 5. Communication (Joystick CAN / EtherCAT AC600)

| Observable | Nominal | Si défaut | Cause probable |
|---|---|---|---|
| `PRG_07_Supervision.instDiagCanOpen.DeviceJoystick.Online` | `TRUE` | `FALSE` | Perte bus CAN joystick |
| `PRG_07_Supervision.instDiagCanOpen.DeviceJoystick.Operational` | `TRUE` | `FALSE` | Esclave CAN non opérationnel (mauvais état CANopen) |
| `PRG_07_Supervision.instDiagEthercat.DeviceVariateur.Online` | `TRUE` | `FALSE` | Perte liaison physique AC600 (câble, alimentation variateur) |
| `PRG_07_Supervision.instDiagEthercat.DeviceVariateur.Operational` | `TRUE` | `FALSE` | Variateur online mais pas opérationnel (config EtherCAT, PDO) |
| `PRG_02_Acquisition.HwReal.Translation.AC600_DeviceState` | `RUNNING` | Autre `DEVICE_STATE` | Diagnostic brut CODESYS du device |
| `GVL_IHM.Commun.HeartbeatIhmOk` | `TRUE` | `FALSE` en continu | ✅ Calculé depuis le lot LOT0 (`FB_Diag_IhmHeartbeat` instancié `PRG_07_Supervision.st`) — une vraie perte IHM est maintenant détectable |

✅ Ces 4 signaux ont désormais un effet réel sur `SafeStop` M3 (`FB_Safety_Translation`, lot M4, §6).
Une perte EtherCAT du variateur pendant un mouvement déclenche la rampe rapide `SafeStop`.
⚠️ Mais **pas de coupure puissance amont** dans ce cas précis (prérequis #4, `PowerCutOff`
toujours une impasse) : seul le frein mécanique arrête réellement la machine sur perte de bus.

---

## 6. Sécurité mouvement (Méca A/B, butées, incohérence — `FB_Safety_Translation`)

✅ **`instSafetyTranslationM3` instancié (lot M4, `PRG_05_Translation.st`) — actif.** Les 8
mécanismes ci-dessous réagissent réellement en `SafeStop`. ⚠️ La colonne `PowerCutOff` reste
**théorique** (prérequis #4) : le bit est calculé et publié (`TranslationSafetyHMI.PowerCutOff`,
IHM/diagnostic) mais rien ne le transmet à une coupure amont réelle — en pratique, seul `SafeStop`
(rampe rapide + frein) agit concrètement aujourd'hui sur ces 5 mécanismes.

| Bit `ErrorId` | Nom | Condition de déclenchement | Réaction réelle aujourd'hui |
|---|---|---|---|
| bit0 | Perte communication opérateur | Joystick offline/non-op OU `HeartbeatIhmOk=FALSE` | `SafeStop` |
| bit1 | Perte communication EtherCAT | Variateur offline/non-op | `SafeStop` |
| bit2 | Mauvaise rotation de phases | `PhaseRotationOk_DI=FALSE` | `SafeStop` |
| bit3 | Surchauffe frein commun | `BrakeThermalOk_DI=FALSE` | `SafeStop` (⚠️ pas de coupure amont réelle, prérequis #4) |
| bit4 | Méca B — absence confirmation arrêt | Frein/contacteur incohérent après rampe (`PostRampTimeout`=3s) | `SafeStop` (⚠️ idem) |
| bit5 | Méca A — mouvement non commandé | Vitesse mesurée alors qu'aucun ordre (1s) | `SafeStop` (⚠️ idem) |
| bit6 | Butée extrême atteinte | `LimitSwitchFwd` ou `Rev` | `SafeStop` (⚠️ idem, immédiat sans délai — écart T74 harmonisation Méca-style à trancher) |
| bit7 | Incohérence mot capteurs | `SensorWordIncoherent=TRUE` | `SafeStop` (⚠️ idem) |

**12 bypass disponibles** (`GVL_IHM.TranslationM3.Bypass.*`, RETAIN, MAINT_N2 uniquement en
principe) : `OperatorComm`, `DriveComm`, `ContactorFeedback`, `PhaseRotation`, `BrakeThermal`,
`LimitSwitch`, `SensorIncoherent`, `MecaA`, `MecaB`, `Safety` (groupé PowerCutOff), `Process`
(groupé SafeStop), `Global` (ignore tout). ✅ **Les 12 sont désormais consommés** par
`instSafetyTranslationM3` (lot M4) — plus aucun orphelin. Vérifier `GVL_IHM.TranslationM3.Bypass.*`
en entier avant un essai (voir aussi §10).

---

## 7. Frein (`FB_Brake`, composé dans `FB_Translation`)

| Observable | Nominal | Si défaut | Action |
|---|---|---|---|
| `PRG_02_Acquisition.HwIn.Translation.M3_BrakeIsOpen_DI` | Suit la commande avec délai | Incohérent | Vérifier contacteur/bobine frein, ou activer `Bypass.ContactorFeedback` en essai contrôlé |
| `PRG_06_Outputs_LD.instTranslationOutputInterlockM3.BrakeTimeoutElapsed` | `T#0ms` au repos | Proche de `T#500ms` | Watchdog sur le point de déclencher `BRAKE_COMMAND_NOT_CONFIRMED` |
| `PRG_06_Outputs_LD.instTranslationOutputInterlockM3.Reason` | `NONE` | `BRAKE_COMMAND_NOT_CONFIRMED` | Confirmation contacteur desserrage jamais reçue sous 500 ms — **Reset (front) + demande neutre (mot 0) + nouvelle demande obligatoires** (anti-redémarrage auto) |
| `PRG_06_Outputs_LD.instTranslationOutputInterlockM3.Reason` | `NONE` | `RESTART_INHIBITED` | Séquence de réarmement pas encore complète — revoir §"Réarmement anti-redémarrage" ci-dessous |

**Réarmement après timeout frein (chronologie exacte, ne pas sauter d'étape)** :
1. Cause physique corrigée (frein confirme bien l'ouverture)
2. Front `Reset` (IHM) — **pas un niveau maintenu**
3. Demande neutre explicite : mot de commande `0` vu au moins un scan
4. Nouvelle demande de mouvement (mot `1` ou `2`)

Sans ces 4 étapes dans l'ordre, `RestartInhibit` reste actif — c'est voulu (pas de redémarrage
automatique après défaut, règle non négociable du projet).

---

## 8. Commande moteur AC600

✅ **Calculée et câblée côté ST jusqu'à `PRG_06_Outputs_LD` (lot LOT2).** ⚠️ **Mapping E/S CODESYS
manuel restant** (prérequis #3) : `M3_CommandWord` (%QW6) et `M3_SetpointFrequencyHz` (%QW7) ne
sont PAS automatiquement reliés à `M3_DriveControlWord`/`M3_DriveFreqRefWord` — ce sont des noms
auto-créés par le mapping E/S `Device.export`, jamais touchés par le bundle. **Tant que ce mapping
manuel n'est pas fait dans CODESYS (onglet I/O mapping du device `AC600_ECAT_Drive`), le moteur ne
reçoit aucune consigne réelle, quel que soit l'état du reste de la chaîne.**

| Observable | Nominal en mouvement | Interprétation |
|---|---|---|
| `PRG_05_Translation.TranslationStateHMI.DriveControlWord` | `1`=Fwd, `2`=Rev, `7`=Reset, `0`=arrêt | Mot demandé par `FB_Translation`, **avant** barrière finale |
| `PRG_06_Outputs_LD.instTranslationOutputInterlockM3.DriveControlWord` | Idem, **après** barrière finale | Mot réellement autorisé (zéro si frein non confirmé, `RestartInhibit`, ou `Error`) |
| `PRG_06_Outputs_LD.M3_DriveControlWord` | Copie locale du mot ci-dessus | **À vérifier lié à `M3_CommandWord` dans le mapping E/S CODESYS** — sinon aucun effet variateur |
| `PRG_06_Outputs_LD.instTranslationOutputInterlockM3.DriveFreqRefWord` | Échelle ×100 : `5000`=50,00 Hz | Consigne fréquence après barrière finale, format registre PDO 0x3100 |
| `PRG_06_Outputs_LD.M3_DriveFreqRefWord` | Copie locale de la consigne ci-dessus | **À vérifier lié à `M3_SetpointFrequencyHz` dans le mapping E/S CODESYS** — sinon aucun effet variateur |
| `PRG_02_Acquisition.M3_StatusWord_Filtered` | Bit variable selon état AC600 | Mot d'état retourné par le variateur (protocole constructeur AC600, `0x3102` côté retour) |
| `PRG_05_Translation.TranslationStateHMI.DriveActualFreq_Hz` | Proportionnel à la consigne | Vitesse réelle mesurée — comparer à `DriveFreqRef_Hz` pour détecter un décrochage |
| `PRG_02_Acquisition.HwIn.Translation.M3_ThermalFeedback_DI` | `TRUE` (OK) | Diagnostic seul (T96, résolu) — l'AC600 se protège lui-même, aucune réaction PLC |

**Premier essai recommandé (utilisateur, 2026-08-05)** : consigne à 10 Hz (marge large sous 50 Hz
nominal) avant de monter en fréquence, une fois le mapping E/S fait et vérifié en Watch CODESYS.

---

## 9. Barrière finale / interlock (`FB_TranslationOutputInterlock_LD`)

| Observable | Nominal | Si défaut | Cause |
|---|---|---|---|
| `PRG_06_Outputs_LD.instTranslationOutputInterlockM3.State` | `READY` au repos, `BUSY` en mouvement | `DISABLED`/`INIT` prolongé | Voir `Reason` ci-dessus |
| `PRG_06_Outputs_LD.M3InterlockEnable` | `TRUE` si mode ≠ DISABLE **et** `SafetyStructureNotValidated=FALSE` | `FALSE` | Vérifier `SafetyStructureNotValidated` en premier (prérequis #1) — c'est la cause la plus fréquente de "rien ne bouge" |
| `PRG_06_Outputs_LD.SafetyStructureNotValidated` | `FALSE` (une fois le lot safety validé retiré) | `TRUE` | **État actuel normal** — aucune sortie M1/M2/M3 n'est autorisée, ce n'est pas un défaut terrain |

---

## 10. Bypass actifs — vérifier qu'aucun ne masque le symptôme réel

Avant de conclure "ça marche", relire `GVL_IHM.TranslationM3.Bypass.*` en entier : un bypass
`Global` ou `ContactorFeedback` resté actif après un essai précédent (champs **RETAIN**, survivent
au download) peut masquer un vrai défaut. Toujours comparer l'essai avec bypass **désactivés**
avant validation finale.

| Bypass | Effet s'il reste actif par erreur |
|---|---|
| `Bypass.Global` | Ignore TOUTES les surveillances déjà actives (`ContactorFeedback`, `LimitSwitch`) |
| `Bypass.ContactorFeedback` | `BrakeFeedback` toujours réputé cohérent — un frein réellement resté serré ne serait pas détecté |
| `Bypass.LimitSwitch` | Butées extrêmes ignorées par `FB_Translation` — risque de collision mécanique en essai réel |

---

## 11. Aide-mémoire par scénario de mise en service

### 11.1 Jog simple (MAINT_N1/N2, boutons IHM ou joystick)

1. `Auth.Mode` = `MAINT_N1` ou `MAINT_N2` (§3)
2. `M3_SensorsWord` valide, pas d'incohérence (§4)
3. `TglJoystickMaster` : `FALSE` = boutons `BtnFwd`/`BtnRev` IHM, `TRUE` = joystick
4. **`PRG_02_Acquisition.JoystickDeadmanArmed` = `TRUE`** (geste homme-mort joystick, bouton appuyé
   au neutre puis mouvement) — exigé depuis le lot LOT3, **même en pilotage boutons IHM** ; sans lui
   `M3_StartStop_Active` reste `FALSE` quoi que fasse l'opérateur (§3)
5. `SafetyStructureNotValidated` = `FALSE` (§9) — sinon rien ne sortira physiquement, c'est attendu
6. **Mapping E/S CODESYS M3 fait et vérifié** (`M3_CommandWord`/`M3_SetpointFrequencyHz`, §8) —
   sinon le mot/la fréquence calculés n'atteignent jamais le variateur
7. Observer `TranslationStateHMI.ActiveDirection`/`ActiveSpeedRef_Pct` — reflète la demande AVANT
   barrière finale
8. Observer `instTranslationOutputInterlockM3.State`/`.Reason`/`.DriveControlWord`/`.DriveFreqRefWord`
   — barrière finale, valeurs réellement autorisées (§8, §9)
9. Premier essai à **10 Hz** (marge de sécurité), pas 50 Hz nominal (décision utilisateur)

### 11.2 Positionneur (SEMI_AUTO ou boutons IHM `SelPositioning`)

1. `Cmd.SelPositioning` = `TRUE`
2. Cible sélectionnée (`SelTarget` interne 1=Trémie/2=P2/3=P1/4=Maintenance) — 4 refusé hors MAINT_N2
3. `M3_PositionSensorTarget` doit suivre le bon capteur selon la cible (§4, `CASE SelTarget` dans
   `PRG_05_Translation.st`)
4. `TargetReached` (`FB_Translation`, debounce `CaptorDebounce`=100ms) — capteur cible confirmé
5. Approche : `SlowdownSensor` (PV) actif uniquement en approche Trémie (`Direction=1`) — jamais
   côté Maintenance, c'est voulu (décision client AF_Partie-02 §3bis)

### 11.3 "Rien ne bouge" — check-list dans l'ordre

1. `SafetyStructureNotValidated` = `TRUE` ? → normal tant que le lot safety global n'est pas
   validé (prérequis #1, **partagé avec M1/M2** — ne pas le lever sans isoler M1/M2, voir prérequis)
2. `Auth.Mode` correct pour le scénario ? (§3)
3. `PRG_02_Acquisition.JoystickDeadmanArmed` = `TRUE` ? → sinon `M3_StartStop_Active` reste bloqué
   même boutons IHM (lot LOT3, §11.1 point 4)
4. `M3InterlockEnable` = `TRUE` ? (§9)
5. `instTranslationOutputInterlockM3.Reason` ≠ `NONE` ? → séquence réarmement (§7)
6. Mapping E/S CODESYS M3 fait (`M3_CommandWord`/`M3_SetpointFrequencyHz`) ? (prérequis #3 —
   sinon aucun mouvement possible même si tout le reste est vert)

---

## 12. Documents liés

| Doc | Rôle |
|---|---|
| `DOC/AF_Partie-11_Fonction_Translation_v2.1.md` | Spec métier M3, §5 alertes détaillées |
| `DOC/AF_Partie-14_Fonction_Troubleshooting_v1.1.md` | Table générique transverse (acquisition DI) |
| `DOC/AF_Partie-14_Fonction_Troubleshooting/FB_TroubleshootingView_v1.0.md` | FB de recopie IHM (`GVL_Troubleshooting`) |
| `CHECKLIST_MiseEnService_Translation` (PLAN_TASK T26) | Checklist de recette terrain — **référencée mais pas encore rédigée** dans `DOC/CHECKLISTS/`, exécution/verdict signé restants |
| `DOC/CHECKLISTS/TASK_CONTEXT/TASK_CONTEXT_M4_TRANSLATION_SAFETY.yaml` | Contrat agent — ✅ exécuté (prérequis #2 résolu) |
| `DOC/CHECKLISTS/TASK_CONTEXT/TASK_CONTEXT_LOT2_TRANSLATION_M3_AC600_OUTPUT.yaml` | Contrat agent — ✅ exécuté côté ST (prérequis #3 : mapping E/S manuel restant) |
| `DOC/CHECKLISTS/TASK_CONTEXT/TASK_CONTEXT_LOT3_TRANSLATION_M3_DEADMAN.yaml` | Contrat agent — ✅ exécuté (homme-mort M3) |
| `DOC/CHECKLISTS/TASK_CONTEXT/TASK_CONTEXT_LOT0_DIAG_IHM_HEARTBEAT.yaml` | Contrat agent — ✅ exécuté (prérequis transverse de M4) |
| `DOC/CHECKLISTS/TASK_CONTEXT/TASK_CONTEXT_M5_OUTPUTS_POWERCUTOFF.yaml` | Contrat agent — lève le prérequis #4 (`PowerCutOff`), non exécuté |
