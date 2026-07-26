# 📦 Historique des versions CODESYS — Lien DOC ↔ CODE

Trace le programme CODESYS testé/validé à un instant donné, pour retrouver quelle version de l'analyse fonctionnelle (`DOC/AF_Partie*`) lui correspondait (retour arrière, FAT/SAT, essais site).

Une entrée par jalon significatif — pas besoin de logguer chaque sous-version mineure. Lignes courtes (~70 caractères), style `·` compact.

### `v0.5.0_PostCableReplacement` — 2026-07-26
- Jalon v0.5.0 après changement des câbles physiques (suite aux essais filmés en v0.4.27)
- Nettoyage et archivage des anciens projets de qualification dans `ARCHIVES/Code/`
- Mise à jour de la documentation de suivi et des checklists de mise en service

### `v0.4.27_Audit_Persistance_Bypass_Frein` — 2026-07-24
- Audit exhaustif de rémanence `PERSISTENT` / `RETAIN` + Bridge Pattern `PRG_09_Supervision`
- Diagnostic complet de l'incident d'échauffement frein (`FB_Brake` ↔ `FB_Winch`)
- Publication du rapport d'audit et cahier d'essais dans `DOC/AUDITS/RAPPORT_Audit_Persistance_Bypass_Frein_v1.0.md`

### `v0.4.26_ConfigPersistence_TranslationSupervisionSuite` — 2026-07-24
- Translation M3 `SetFreq_Hz` protégé : `_TranslationSetFreq_Hz` + flag `Initialized` dédié (Lot 4)
- Suite test PLC `FB_SupervisionValidation` (TC-CP1..CP5) : Sync approfondi + balayage Cycle/
  Commun/Bucket/Winch M1+M2 + Translation (Lot 6)
- Raccordement orchestrateur `FB_PLC_Tests_Management` (`SuiteSupervision=8`, ciblée hors `RunAll`)
- Clôture chantier `ConfigPersistence` (Lots 1-6) · contrat `CONFIG-PERSIST-01` → `tests_status:
  implemented` (exécution CODESYS réelle restant à faire)
- Commits `a88e56d`/`3faa941` poussés sur `origin/main`

### `DOC_RESTORATION_AF07_AF11` — 2026-07-23
- Restauration intégrale post-audit de `AF_Partie-11_Fonction_Translation_v1.11.md` (v1.12, EtherCAT AC600, 5 capteurs, Méca A/B)
- Consolidation complète de `AF_Partie-07_Interface_IHM_v1.7.md` (v1.9, structures ST_*HMI & GVL_IHM), suppression du doublon v1.8
- Intégration cartographie flux IHM, audits bypass & persistance config

### `AUDIT_ConfigPersistence` — 2026-07-23
- Audit persistance étendu à tout `GVL_IHM` : `TranslationM3.Cmd.SetFreq_Hz`, `Cycle.SetDepth_M/
  SetOffset_M`, calib joystick, `M2Benne.CfgTimeoutDuration`, `BypassRestoreDone` identifiés
  non/mal protégés — décisions et options architecturales dans `DOC/AUDITS/ConfigPersistence/`
- Piste retenue à investiguer : struct persistant miroir + FB générique par type (`FB_CfgPersist_*`),
  homogénéisation `ST_BucketHMI`/`ST_SyncHMI` vers le pattern Cmd/State/Cfg/Bypass (Winch/Translation)

### `CONFIG-PERSIST-01` — 2026-07-23
- Fix persistance config IHM (`CfgMaxStepDescente` et 10+ champs Cfg M1/M2/Sync) : sentinelles
  `= 0.0` cassées remplacées par flag `Initialized`/`CfgInitialized` dédié
- Alarme IHM `ConfigRestoredFromPersistent` + acquittement front (`BtnAckConfigRestored`)
- Bug cousin corrigé : `BypassRestoreDone` passé en `VAR RETAIN` (repartait à FALSE à chaque download)
- ⚠️ Test PLC automatique restant à écrire (T65) — vérification manuelle Watch/forçage en attendant

### `DOC_ClassementEtREX_Treuils` — 2026-07-23
- Anciennes checklists, P13 v1.2 et audits clôturés déplacés en archives
- NAVBOARDs regroupés dans `DOC/NAVBOARDS/`
- P7 v1.6, P11 v1.9/v1.10 et audit Winch déplacés sans fusion
- Essais treuils : plafond palier temporairement réglé à `0` (`T64`)

### `96ef589` — 2026-07-23
- Bypass globaux/ciblés Winch · Translation M3 · synchro · benne · réseau
- Homing unitaire M1/M2 réglable, cible initiale `0,0 m`
- Validation banc/terrain et désactivation finale des bypass requises

### `DOC_SuiviMiseEnService` — 2026-07-23
- Registre historique MES créé : séances, mesures, preuves et décisions terrain
- `PLAN_TASK` reste la source unique des actions différées à implémenter (`Txx`)

### `v0.4.31_CommissioningDocsIhmState` — 2026-07-22
- NAVBOARD Joystick/M3 + checklists v1.1 alignés sur IHM `.Cmd/.State/.Safety`
- Fiches terrain courtes : ordre de bascule simulation, mouvement prudent, reset sûr

---

### `v0.4.30_SupervisionStateAndExportFix` — 2026-07-22
- Remplacement du namespace sémantique `.Status.` par `.State.` pour clarifier le retour d'états
- Regroupement physique de toutes les structures DUTs (`ST_*.st`) dans le sous-dossier `CODE/SUPERVISION/_TYPES/`
- Résolution des erreurs de compilation CODESYS (201 erreurs) par correction directe des chemins de variables obsolètes dans le fichier d'export XML `Device.export`
- Alignement du code source des suites de tests PLC (`FB_ModesValidation.st`, `FB_HeartbeatValidation.st`), de `PRG_05_Cycle.st` et de `PRG_09_Supervision.st`

---

### `v0.4.29_SupervisionStructuredCmdStatus` — 2026-07-22
- Structuration complète de supervision des axes Winch M1/M2 et Translation M3 en Cmd/Status/Cfg
- Création des types DUT dédiés ST_WinchCmd, ST_WinchStatus, ST_WinchCfg, ST_TranslationCmd, ST_TranslationStatus
- Alignement complet du remapping IHM dans PRG_09_Supervision, des autres POUs et des suites de tests PLC
- Consolidation documentaire avec l'Analyse Fonctionnelle Partie 7 v1.6 complète

---

### `v0.4.28_SupervisionFrenchExceptions` — 2026-07-22
- Restauration des exceptions de nommage en Français exigées pour l'IHM
- Renommage en `M1TreuilRetenue`, `M2TreuilBenne` et `M2Benne`
- Isolation des variables de test HMI (Tst*) sous des structures dédiées Test (ST_TestTranslation/ST_TestCycle)
- Isolation des diagnostics de sécurité IHM (SafetyError*) sous des structures dédiées Safety (ST_SafetyTranslation/ST_SafetyWinch)
- Alignement de tous les programmes consommateurs (`PRG_00` à `PRG_10`) et tests PLC

---

### `v0.4.27_SupervisionConformityRename` — 2026-07-22
- Renommage complet de la supervision GVL_IHM et des structures ST_*HMI
- Alignement strict avec les repères physiques : M1Winch, M2Winch, M2WinchBucket, TranslationM3
- Ajout systématique des underscores pour les suffixes d'unités physiques (_M, _Pct, _Hz, _Mps)
- Adaptation de tous les programmes consommateurs (PRG_00 à PRG_10) et suites de tests PLC

---

### `v0.4.26_IhmCompatibilityRepair` — 2026-07-22
- Restauration des noms publics IHM historiques : visualisation inchangée
- `CODE_Bundle.xml` inclut désormais `GVL_PERSISTENT` requis par les PRG
- À confirmer : compilation CODESYS après import du bundle réparé

---

### `v0.4.23_TranslationM3_PersistentRamp` — 2026-07-22
- 🔴 BUG : `ST_TranslationHMI.PositionMaintenance` vs PRG_09 `Position_Maintenance` (nom divergents, erreur compilation) — aligné sur struct (`PositionMaintenance`)
- 🟡 Translation ramp rates → PERSISTENT : `_TranslationRampAccelRate_Pct`(20)·`_TranslationRampDecelNormal_Pct`(40)·`_TranslationRampDecelFast_Pct`(100) dans GVL_PERSISTENT + câblage PRG_07 (auparavant hardcodés dans FB_Translation)
- 🟡 Speed cap 40% → PERSISTENT `_TranslationAutoSpeedCap_Pct` (remplace `MIN(40.0,..)` hardcodé dans PRG_07)
- 🟠 Unification source fréquence max : `DriveFreqScaleMaxHz` câblé depuis `_TranslationMaxFreq_Hz` par PRG_07 (plus de double source)
- DOC AF_Partie-11 : nouveau tableau PERSISTENT Translation M3 + note source unique

---

### `v0.4.24_TranslationM3_Positioner` — 2026-07-22
- MAINT M3 : `PositioningSelect` explicite, Jog/Positionneur + `PositionReached` IHM
- Boutons IHM sans requête : direction neutre, plus de fallback joystick implicite
- Docs Partie 7 v1.6 / Partie 11 v1.10 + NAVBOARD synchronisés

---

### `v0.4.25_TranslationM3_JoystickAnimation` — 2026-07-22
- `JoystickDeflectionPct` : axe X fonctionnel M3 signé, animation IHM autour du neutre
- Docs Partie 7 v1.7 / Partie 11 v1.11 + NAVBOARD synchronisés

---

### `v0.4.22_IHM_Joystick_Supervision` — 2026-07-22
- Renommage masse SUPERVISION (~50 champs suffixe `_M`/`_Pct`/`_Hz`/`_Mps`)
- `ST_JoystickHMI`·`PRG_09` : +DeadmanArmed·NeutralX/YAct·AxisCmdX/Y · RawX/Y/Button→FB_Joystick
- `GVL_PERSISTENT` : params joystick (deadband·filter·accel/decel·invert) + `_BucketState`
- DOC AF_Partie-11 : `DriveFreqScaleMaxHz` défaut 50→60 Hz + note qualifié
- DOC AF_Partie-12 : §9 `_BucketState` mémoire longueur câble désynchro

---

### `v0.4.21_SimM3BootFix` — 2026-07-21
- Correction polarité frein Méca B dans `FB_Safety_Translation` (`NOT BrakeFeedback`)
- Position neutre P2 (00111) au boot sans cible dans `FB_Sim_Translation`
- Boot simulation M3 Translation 100% sain sans faux défaut ni blocage AU

---

### `v0.4.20_WinchCorePrep` — 2026-07-21
- WINCH-CORE-01 · hauteurs 8,0/8,5 m · DISABLE M1/M2/M3
- Bypass codeur individuel MAINT_N2 · ConfigError SpeedStep bit2
- Charge estimée montée seule · seuil cycle aligné · purge commandes boot
- Tests PLC Modes étendus TC-M7→M12 · aucune visualisation modifiée

---

### `v0.4.19_CommissioningPrep` — 2026-07-21
- Préparation version mise en service terrain (pre-commissioning)
- Audit treuils M1/M2 (`DOC/AUDIT_Winch_v1.0.md`), suites PLC_TESTS validées
- Génération du bundle PLCopenXML `MGS_v0.4.19_CommissioningPrep`

---

### `v0.4.18_PlcTests_ManualSuites` — 2026-07-19
- Suites PLC_TESTS séparées : `RunSafety`, `RunTranslation`, `RunBucket`, `RunEncoder`, `RunModes`
- `RunAll` déprécié/ignoré : aucun lancement automatique au chargement
- Manager en lecture seule des sorties FB ; correction des erreurs CODESYS C0037
- Watchdog : arrêt + rapport de la suite active, sans blocage des autres suites
- AF Partie 14 complétée par l'addendum suites manuelles indépendantes

---

### `Audit_Winch_v1.0` — 2026-07-21
- Audit complet fonctionnalité treuils (M1/M2) : architecture, safety, synchronisme, IHM, ergonomie
- 2 P0 critiques : incohérence hauteurs (8.0/8.5/12.5m), FB_SpeedStep MaxStepNumber non borné
- 5 P1 : contradiction "sans codeur", latence PRG_03/PRG_06, synchronisme ambigu, seuils non validés, IHM ne reflète pas commandes effectives
- Bonnes/mauvaises idées identifiées, plan d'actions en 3 phases (P0 avant machine, banc, terrain)
- Doc créée : `DOC/AUDIT_Winch_v1.0.md`

---

### `v0.4.18_DocSweep_IHMRetrait` — 2026-07-18
- Méga passe documentaire : AF Partie 07 (v1.5) et Partie 11 (v1.9) republiées, PLAN_TASK et AUDIT synchronisés
- Retrait définitif IHM_MANU (ST_IHM_MANU + AF Partie-07 v1.4 archivées) — pilotage manuel = MAINT_N1/N2 + joystick homme-mort
- Nouvelles suites PLC_TESTS ENCODER/MODES + checklists mise en service Joystick/Translation
- Commit `397cee0` — clôture plan logiciel initial (homing, safety, vitesse codeur/paliers)

### Plan logiciel initial — clôture implémentation — 2026-07-18
- Homing unitaire M1/M2 MAINT_N2 : sélection, cible libre ±99 m, diagnostics
- Safety Winch : sens opposé bit14, absence mouvement bit15, temporisations
- Safety Translation alignée matériel AC600 + frein ; T26 checklist terrain livrée
- Reliquats restants limités aux décisions constructeur/client et essais terrain

### Doc plan vitesse codeur / paliers — 2026-07-18
- T41 à T48 ajoutées au plan : vitesse câble m/s, surveillance M1/M2
- 5 paliers mesurés, estimation charge et garde-fou de changement de palier

### `v0.4.17_SemiAuto_CycleSafety` — 2026-07-18
- Homme-mort obligatoire pendant les mouvements semi-auto M1/M2/M3
- Relâchement joystick = arrêt ; nouvelle sollicitation = reprise de l'étape
- Cycle Kobold raccordé au cycle semi-auto ; arrêt sûr sur perte de puissance/AU
- E/S Kobold raccordées : `KoboldContactFond_DI`=%IX0.5 et `KoboldContactor_DQ`=%QX0.6
- Tests PLC anti-blocage : états terminaux, watchdog et journal d'événements

### `v0.4.16_ReferenceToFix_BucketRun` — 2026-07-18 (M3)
- M3 conforme au codage cinq capteurs `Trémie|PV|P2|P1|Maintenance`
- Nouveau `FB_Translation_PositionDecoder` : mots valides et incohérences
- Ralentissement PV câblé, limites extrêmes Trémie/Maintenance alignées
- Bit7 safety incohérence remonté à l'IHM ; simulation des mots corrigée
- AF Partie 11 publiée en v1.8 et architecture en v2.12

### `v0.4.16_ReferenceToFix_BucketRun` — 2026-07-18 (PLC_TESTS)
- Séquenceur anti-blocage : erreurs terminales, watchdog suite et journal d'événements
- Correction `StepTc06Teardown` hors table (`69` → `63`)

### `v0.4.16_ReferenceToFix_BucketRun` — 2026-07-17
- Fix générateur PLCopenXML (`TOOLS/`) : `REFERENCE TO` sérialisait en `<pointer>` au lieu de `<derived name="REFERENCE TO X">` — confirmé sur échantillon réel (`FB_TestReference.xml`)
- `FB_BucketValidation` : garde `__ISVALIDREF()` avant déréférencement `instBucket`/`instWinchM2` (protège le 1ᵉʳ scan, avant assignation par `PRG_06_WinchControl`)
- `PRG_06_WinchControl` : `:=` → `REF=` pour rebind `GVL_Simulation.refBucket/refWinchM2` (`:=` faisait une copie de valeur à travers une réf non liée → access violation runtime CODESYS)
- ✅ RUN confirmé OK en simulation CODESYS (`FB_PLC_Tests_Management` + suite Bucket)

### 📄 Doc seule — 2026-07-16
- AF_Partie-14 v1.1 → **v1.2** : §7 réécrit intégralement (spec finale framework test in-PLC piloté par tables)
- Issue double revue croisée experte (primitives ↔ archi données) + audit — pas de modif `CODE/`
- Migration M1→M6 cadrée, à dérouler séparément (M1 = socle générique `FB_TestSequencer`)

### `v0.4.15_PlcTestsFramework_TranslationSuite` — 2026-07-16 (TEST)
- Framework PLC_TESTS migré vers AF_Partie-14 v1.2 (M1→M3+) : tables déclaratives
- Moteur unique `FB_TestSequencer` + bricks (`FB_TestCheck/Stimulus/Stopwatch/EventOrder/EdgeCounter/Timeout`)
- Réorganisé en sous-dossiers TYPES/(ENUMS·STRUCTS) · BRICKS · SUITE_SAFETY · SUITE_TRANSLATION
- `FB_SafetyValidation` réécrit (remplace le CASE monolithique v1.0/1.1)
- + nouvelle suite `FB_TranslationValidation` (TC-T1 Fdc extrême, TC-T2 Méca B, TC-T3 Méca A)
- `FB_PLC_Tests_Management` orchestre multi-suites (CmdRunAll enchaîne Safety→Translation→Bucket)
- GVL_PLC_Tests : `Cmd`/`Status` + 1 variable nommée par suite (pas de tableau, demande utilisateur)
- + `Cases[].Name` et `Report.FailureSummary` (lisibilité, évite de parcourir chaque case)
- Fix générateur PLCopenXML (`TOOLS/`) : bornes de tableau symboliques (`GVL_Const.MaxX`) étaient silencieusement omises du bundle — corrigé, non vérifié en import réel
- Fix ST : `FOR_END`→`END_FOR`, `VAR` imbriqué illégal (tous deux dans `FB_TestSequencer`)
- ⚠️ Connu non résolu : bug lockout `EmergencyArmingLockoutActive` (posé aussi sur succès) pas encore corrigé dans `FB_Safety_EmergencyManagementLogic.st` ; step Trip TC-01 à corriger (vérifier `EmergencyStopOk`, pas `PowerCutOff_A/B_RQ`)

### `v0.4.15_IHM_MANU_TranslationHoming` — 2026-07-16 (TEST)
- Translation M3 alignée sur Winch : IHM_MANU = 3ᵉ source d'arbitrage (PRG_07 §1bis)
- Fin bypass M3_CommandWord · instSafetyTranslationM3.Enable inconditionnel (débloque TC-T1/2/3)
- Vitesse Manu boutons/joystick conservée via FreqSetpointHz (diffère du Winch, décision produit)
- Retrait bypass Homing (HomingEncoder_M1/M2) — PRG_02_Encoders/ST_IHM_MANU
- + AF_Partie-11_Fonction_Translation v1.7
- Aux Hydrauliques + WinchMaxStepFwd/Rev restent hors périmètre (différés)

### Corrections nommage + intégration — 2026-07-16 (TEST)
- Renommage `FB_Benne→FB_Bucket` (défait accidentellement par un script de retour arrière buggé, sans commit) restauré depuis `HEAD`
- Suite `FB_BucketValidation` (ex-`FB_BenneValidation`) intégrée dans `FB_PLC_Tests_Management` (3e maillon de chaîne)
- Dossiers racine `EMERGENCY→AU`, `ENCODERS→CODEURS`
- ⚠️ Version de test — pas encore réimportée/validée en CODESYS

### `v0.4.14_SafetyValidation_EmergencyChain` — 2026-07-16 (TEST)
- FB_Safety_EmergencyChain : encapsule la boucle AU + sorties erreur individuelles Translation
- Déplacé/renommé vers EMERGENCY/FB_Safety_EmergencyManagement
- Fix affectation Busy/Done dans le bloc parent composite
- PRG_SafetyValidation : banc de test réglementaire automatisé de la boucle d'urgence
- + AF_Partie-14_PLC_Tests_Validation v1.0 (CI/CD, exécution des tests)
- GVL_Global.BlinkClock (ex-BlinkClock1Hz) alimenté via Util.BLINK, asymétrique réglable
- (GVL_PERSISTENT._BlinkTimeOn/_BlinkTimeOff, défaut 1s/800ms)
- Config : HomingTarget par défaut 8.5m, limite haute normale 8.0m
- ⚠️ Version de test — pas encore réimportée/validée en CODESYS pour la partie Blink

### `v0.4.13_GlobalRename_GVL_Persistent` — 2026-07-16
- Renommage global Chariot→Translation, Grappin→Benne, _COMMON→COMMUN
- SYSTEM/ scindé en DIAG/ · nettoyage GVL_BUS/GVL_Machine_Stub morts
- GVL_PERSISTENT réorganisée par métier (Winch/Benne/Translation…)
- + décorateur `_` obligatoire et suffixes unité (`_Ms`, `_M`…) partout
- T30 : fréquence translation std 30Hz / max 60Hz, persistée
- Fix visu Device.export (remplacement sûr des balises value)
- + erreurs de compilation restantes

### `v0.4.12_TranslationHMI_Migration` — 2026-07-15
- ST_TranslationHMI migre ReqFwd/ReqRev/FreqSetpointHz depuis IHM_MANU
- + diag décodé DriveCommReady/DrivePowerReady (pas de WORD brut)
- Pas l'état final : bypass ManuActive→M3_CommandWord reste
- Fix FB_Sim_Translation bloqué (relais morts ère DEGRADED_IO)
- → rebranché sur M3_CommandWord
- BypassBrakeFeedback supprimé (fusion BypassContactorFeedback)
- Rename Translation/Joystick→TranslationM3/JoystickJOY1 (Benne : BenneM2 tenté puis annulé, stutter M2)
- ⚠️ pas encore réimporté/compilé dans CODESYS

### `v0.4.11_Translation_AC600_Safety` — 2026-07-15
- EtherCAT AC600 nominal M3 · fin définitive mode relais DEGRADED_IO
- Sécurités Méca A (dérive vitesse à l'arrêt)
- + Méca B (incohérence frein/variateur)
- + arrêt fins de course extrêmes (fosses/trémie)
- Diag com EtherCAT · simu StatusWord/ActualFrequency/frein
- Doc STO ajoutée

### `v0.4.10_FdcBucket_Rename` — 2026-07-15
- TASK-0002 : FdcBucketOpen/Close→OpenEnable/CloseEnable
- (ST_IHM_MANU) — clarifie rôle config vs état
- MAJ logique PRG_10_Outputs

### — 2026-07-15
- 🗑️ Retrait DOC/AGENT_HANDOFF/ (queue, push_server.py, hooks)
- Posé en v0.4.8 · TASK-0001/0002 seules tâches réelles produites
- (TASK-0003-0010 = test pipeline factice)
- Remplacé par plugin antigravity (délégation Claude↔Gemini)

### `v0.4.9_JoystickWinchSelect_N2` — 2026-07-15
- TASK-0001 : Joystick M1/M2-seul restreint à MAINT_N2
- (évite désynchro fortuite) — sinon forcé Couplé (3)
- JoystickWinchSelectRequest/Arbitrated ajoutés FB_Modes
- Câblé PRG_04_Modes · PRG_10_Outputs utilise la consigne arbitrée

### `v0.4.8_IHM_MANU_FBWinch` — 2026-07-15
- IHM_MANU pilote M1/M2 via FB_Winch (PRG_06, 3ᵉ source arbitrage)
- Rampe/ralentissement natifs · doctrine "Conditional Bypass"
- retirée FB_Safety_Winch (Enable inconditionnel, granularité _IsReal)
- Fix latch FB_Safety_Translation (Error pas remis à 0 si Enable=FALSE)
- Fix Fdc benne appliqué M1 individuel + couplé (pas que M2)
- Fix compil PRG_02_Encoders (var supprimée)
- Nouvelle limite CableLimitAscentM1/M2_M (12.0m, exploitation)
- distincte HomingTarget (12.5m, réservé Homing)
- Fix Méca B bit8 (boutons HMI ignorés par JoystickYNeutral)
- WinchMaxStepFwd/Rev réactivé temporaire + fix boot-init à 0

### `v0.4.7_IHM_MANU_JOY` — 2026-07-14
- Alignement doctrine "Conditional Bypass" (sécu/homing)
- bloquants si réel, shuntés si simulé
- Fix Startup in Neutral · reset Grafcet auto sous IHM_MANU
- Timers homme-mort dynamiques · déblocage stub pompe hydraulique

### `v0.4.6_IHM_MANU_JOY` — 2026-07-14
- Joystick CANopen (X/Y) · décodage paliers K1-K4
- Fdc virtuelles benne (delta M1-M2)
- Commande auxiliaires hydrauliques · bornage vitesse paliers
- Consigne fréquence translation M3 réglable/limitée

### `v0.4.5_IHM_MANU` — 2026-07-09
- Fix lecture codeur réel forcée en mode Manu
- même si simu générale active

### `v0.4.4_IHM_MANU` — 2026-07-08
- Ajout structure IHM_MANU (pilotage direct secours)
- Mise en service urgence

### `v0.4.3_SimNoHardware-YGO_CablePre-Commissioning` — 2026-07-08
- Simu sans blocage validée (recul, vitesses, butée M2)
- HMI stable, bypass synchro — avant enroulage réel

### `v0.4.2_SimNoHardware-SyncBypass` — 2026-07-08
- Butée haute M2 dynamique (12m/14m)
- Offset bargraphe stabilisé en mouvement
- Bypass synchro en butées

### `v0.4.1_SimNoHardware-SyncUpdate` — 2026-07-08
- Méca E synchro critique ajoutée
- Arrêt rampe normale sur écart mineur (vs SafeStop)
- Simu stable, pas de MES matérielle

### `v0.4.0_SimNoHardware` — 2026-07-08
- Mouvements M1/M2 + benne stables en simulation
- Aucune MES matérielle réelle
