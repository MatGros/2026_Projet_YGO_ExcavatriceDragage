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

## ⚠️ Prérequis à lire AVANT tout essai (état du code au 2026-08-05)

Trois trous connus **bloquent ou dégradent** un essai M3, indépendamment de tout défaut terrain.
Ne pas les confondre avec un problème de câblage ou de capteur pendant le dépannage :

| # | Trou | Effet sur l'essai | Réf. |
|---|---|---|---|
| 1 | `SafetyStructureNotValidated := TRUE` (garde-fou global, `PRG_06_Outputs_LD.st`) | **Aucune sortie moteur/frein M1/M2/M3 n'est autorisée**, quoi que fasse l'opérateur. Normal tant qu'un lot safety dédié ne l'a pas levé | `PRG_06_Outputs_LD.st:45` |
| 2 | `FB_Safety_Translation` jamais instancié | `SafeStop` M3 ne réagit qu'à `InputModuleFault` — perte comm, rotation phase, thermique frein, Méca A/B, butées, incohérence capteurs **n'ont aucun effet SafeStop/PowerCutOff** tant que ce lot n'est pas fait | AF_Partie-11 v2.1 §5 alerte 5, PLAN_TASK T104 |
| 3 | Commande AC600 (`DriveControlWord`/`DriveFreqRefHz`) jamais écrite en sortie physique | **Le moteur M3 ne peut pas tourner**, même hors garde-fou #1 — seul le frein (`M3_BrakeRelease_RQ`) est câblé | AF_Partie-11 v2.1 §5 alerte 6, PLAN_TASK T105 |

➡️ Si aucun de ces 3 lots n'est fait : un essai M3 réel (moteur qui tourne) **n'est pas possible**.
Un essai à blanc (capteurs, IHM, calculs internes, frein seul) reste possible et utile — voir §1 à §4.

---

## 1. Ordre de diagnostic (haut → bas, ne jamais sauter une étape)

```text
1. Modules DI (santé matérielle)          → §2
2. Mode machine (autorisation)             → §3
3. Capteurs de position (5 capteurs)       → §4
4. Communication (Joystick / EtherCAT)     → §5
5. Sécurité mouvement (Méca A/B, safety)   → §6  ⚠️ actuellement partielle, voir prérequis
6. Frein                                    → §7
7. Commande moteur AC600                    → §8  ⚠️ actuellement non câblée, voir prérequis
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
| `PRG_02_Acquisition.InputModuleFault` | `FALSE` | `TRUE` | Agrégat des 3 modules ; c'est la SEULE cause actuelle de `SafeStop` M3 (prérequis #2) |

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
| `GVL_IHM.Commun.HeartbeatIhmOk` | `TRUE` | `FALSE` en continu | ⚠️ **Actuellement jamais calculé** (prérequis transverse, PLAN_TASK T107) — ne pas conclure à une vraie perte IHM sans vérifier le code |

⚠️ Ces 4 signaux existent et sont déjà lisibles, mais **n'ont aucun effet sur `SafeStop`/`PowerCutOff` M3** tant que le prérequis #2 (`FB_Safety_Translation` non câblé) n'est pas résolu. Une perte
EtherCAT du variateur, par exemple, ne provoquera **aucune réaction automate** aujourd'hui — seule
l'observation manuelle de `DeviceVariateur.Online` le révèle.

---

## 6. Sécurité mouvement (Méca A/B, butées, incohérence — `FB_Safety_Translation`)

⚠️ **Ce paragraphe décrit le comportement SPÉCIFIÉ, actuellement NON ACTIF (prérequis #2).**
Tant que `TASK_CONTEXT_M4_TRANSLATION_SAFETY.yaml` n'est pas exécuté, ignorer les colonnes
"Réaction attendue" ci-dessous — rien ne se passe automatiquement.

| Bit `ErrorId` | Nom | Condition de déclenchement | Réaction attendue (une fois câblé) |
|---|---|---|---|
| bit0 | Perte communication opérateur | Joystick offline/non-op OU `HeartbeatIhmOk=FALSE` | `SafeStop` |
| bit1 | Perte communication EtherCAT | Variateur offline/non-op | `SafeStop` |
| bit2 | Mauvaise rotation de phases | `PhaseRotationOk_DI=FALSE` | `SafeStop` |
| bit3 | Surchauffe frein commun | `BrakeThermalOk_DI=FALSE` | `SafeStop` + `PowerCutOff` |
| bit4 | Méca B — absence confirmation arrêt | Frein/contacteur incohérent après rampe (`PostRampTimeout`=3s) | `SafeStop` + `PowerCutOff` |
| bit5 | Méca A — mouvement non commandé | Vitesse mesurée alors qu'aucun ordre (1s) | `SafeStop` + `PowerCutOff` |
| bit6 | Butée extrême atteinte | `LimitSwitchFwd` ou `Rev` | `SafeStop` + `PowerCutOff` (immédiat, sans délai — écart T74 harmonisation Méca-style à trancher) |
| bit7 | Incohérence mot capteurs | `SensorWordIncoherent=TRUE` | `SafeStop` + `PowerCutOff` |

**12 bypass disponibles** (`GVL_IHM.TranslationM3.Bypass.*`, RETAIN, MAINT_N2 uniquement en
principe) : `OperatorComm`, `DriveComm`, `ContactorFeedback`, `PhaseRotation`, `BrakeThermal`,
`LimitSwitch`, `SensorIncoherent`, `MecaA`, `MecaB`, `Safety` (groupé PowerCutOff), `Process`
(groupé SafeStop), `Global` (ignore tout). **Seuls `Global`, `ContactorFeedback` et `LimitSwitch`
ont un effet aujourd'hui** (consommés directement par `FB_Translation`) — les 9 autres sont
déclarés côté IHM mais orphelins tant que le prérequis #2 n'est pas résolu.

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

⚠️ **Non câblée à ce jour (prérequis #3)** — cette section documente ce qui SERA observable une
fois `TASK_CONTEXT_LOT2_TRANSLATION_M3_AC600_OUTPUT.yaml` exécuté.

| Observable | Nominal en mouvement | Interprétation |
|---|---|---|
| `PRG_05_Translation.TranslationStateHMI.DriveControlWord` | `1`=Fwd, `2`=Rev, `7`=Reset, `0`=arrêt | Mot demandé par `FB_Translation`, **avant** barrière finale |
| `PRG_02_Acquisition.M3_StatusWord_Filtered` | Bit variable selon état AC600 | Mot d'état retourné par le variateur (protocole constructeur AC600, `0x3101` côté commande) |
| `PRG_05_Translation.TranslationStateHMI.DriveActualFreq_Hz` | Proportionnel à la consigne | Vitesse réelle mesurée — comparer à `DriveFreqRef_Hz` pour détecter un décrochage |
| `PRG_02_Acquisition.HwIn.Translation.M3_ThermalFeedback_DI` | `TRUE` (OK) | Diagnostic seul (T96, résolu) — l'AC600 se protège lui-même, aucune réaction PLC |

**En attendant ce lot** : `TranslationStateHMI.DriveControlWord`/`DriveFreqRef_Hz` restent
observables et reflètent fidèlement le calcul métier — utiles pour valider la logique (rampe,
arbitrage sens, ralentissement PV) **sans** mouvement physique.

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
4. `SafetyStructureNotValidated` = `FALSE` (§9) — sinon rien ne sortira physiquement, c'est attendu
5. Observer `TranslationStateHMI.ActiveDirection`/`ActiveSpeedRef_Pct` — reflète la demande AVANT
   barrière finale, utile même sans sortie physique câblée (§8)
6. Observer `instTranslationOutputInterlockM3.State`/`.Reason` — barrière finale (§9)

### 11.2 Positionneur (SEMI_AUTO ou boutons IHM `SelPositioning`)

1. `Cmd.SelPositioning` = `TRUE`
2. Cible sélectionnée (`SelTarget` interne 1=Trémie/2=P2/3=P1/4=Maintenance) — 4 refusé hors MAINT_N2
3. `M3_PositionSensorTarget` doit suivre le bon capteur selon la cible (§4, `CASE SelTarget` dans
   `PRG_05_Translation.st`)
4. `TargetReached` (`FB_Translation`, debounce `CaptorDebounce`=100ms) — capteur cible confirmé
5. Approche : `SlowdownSensor` (PV) actif uniquement en approche Trémie (`Direction=1`) — jamais
   côté Maintenance, c'est voulu (décision client AF_Partie-02 §3bis)

### 11.3 "Rien ne bouge" — check-list dans l'ordre

1. `SafetyStructureNotValidated` = `TRUE` ? → normal aujourd'hui (prérequis #1), pas un défaut
2. `Auth.Mode` correct pour le scénario ? (§3)
3. `M3InterlockEnable` = `TRUE` ? (§9)
4. `instTranslationOutputInterlockM3.Reason` ≠ `NONE` ? → séquence réarmement (§7)
5. Commande AC600 câblée en sortie physique ? (prérequis #3 — sinon aucun mouvement possible
   même si tout le reste est vert)

---

## 12. Documents liés

| Doc | Rôle |
|---|---|
| `DOC/AF_Partie-11_Fonction_Translation_v2.1.md` | Spec métier M3, §5 alertes détaillées |
| `DOC/AF_Partie-14_Fonction_Troubleshooting_v1.1.md` | Table générique transverse (acquisition DI) |
| `DOC/AF_Partie-14_Fonction_Troubleshooting/FB_TroubleshootingView_v1.0.md` | FB de recopie IHM (`GVL_Troubleshooting`) |
| `CHECKLIST_MiseEnService_Translation` (PLAN_TASK T26) | Checklist de recette terrain — **référencée mais pas encore rédigée** dans `DOC/CHECKLISTS/`, exécution/verdict signé restants |
| `DOC/CHECKLISTS/TASK_CONTEXT/TASK_CONTEXT_M4_TRANSLATION_SAFETY.yaml` | Contrat agent — lève le prérequis #2 |
| `DOC/CHECKLISTS/TASK_CONTEXT/TASK_CONTEXT_LOT2_TRANSLATION_M3_AC600_OUTPUT.yaml` | Contrat agent — lève le prérequis #3 |
| `DOC/CHECKLISTS/TASK_CONTEXT/TASK_CONTEXT_LOT3_TRANSLATION_M3_DEADMAN.yaml` | Contrat agent — homme-mort M3 |
| `DOC/CHECKLISTS/TASK_CONTEXT/TASK_CONTEXT_LOT0_DIAG_IHM_HEARTBEAT.yaml` | Contrat agent — prérequis transverse de M4 |
