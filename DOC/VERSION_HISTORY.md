# 📦 Historique des versions CODESYS — Lien DOC ↔ CODE

Trace le programme CODESYS testé/validé à un instant donné, pour retrouver quelle version de l'analyse fonctionnelle (`DOC/AF_Partie*`) lui correspondait (retour arrière, FAT/SAT, essais site).

Une entrée par jalon significatif — pas besoin de logguer chaque sous-version mineure. Lignes courtes (~70 caractères), style `·` compact.

---

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
- Consigne fréquence translation M3 réglable/clampée

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
