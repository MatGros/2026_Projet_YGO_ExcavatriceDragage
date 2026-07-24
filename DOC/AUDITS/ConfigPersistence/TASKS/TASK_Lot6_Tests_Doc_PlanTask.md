# 📋 Document de Tâche — Lot 6 : Suite de test PLC, contrat de test, `PLAN_TASK`, doc
## ⚠️ Ce lot manipule directement des variables `GVL_PERSISTENT` réelles — voir §0

> 🎯 **Pour agent externe sans accès à l'historique de conversation.** Ce document est autonome.
> 📌 Suivi : `PLAN_TASK_v1.0.md`, `DOC/AUDITS/ConfigPersistence/AUDIT_ConfigPersistence_v1.2.md`,
> `DOC/AUDITS/ConfigPersistence/TASK_CONTEXT_CONFIG-PERSIST-01.yaml`.
> 🧭 Convention de nommage obligatoire : `DOC/NAMING_CONVENTION.md` (PascalCase, pas de hongrois).
> 📄 Clôture le chantier persistance IHM (Lots 1-4 tous faits/vérifiés, sauf Lot 4 qui peut être en
> parallèle — indépendant de celui-ci). Dernier volet obligatoire par le contrat de test existant
> (`tests_automated_required: true`, `pony_tail: forbidden`).

---

## 0. Ta responsabilité en tant qu'agent exécutant (pas juste un exécutant mécanique)

- **Si une instruction contredit ce que tu observes dans le code réel** (une ligne citée n'existe
  plus, un champ a un autre nom, un numéro de ligne a bougé) → **arrête-toi et signale-le** avant
  de continuer à deviner.
- **⚠️ La nouvelle suite de test (§4) force directement des variables `GVL_PERSISTENT` réelles**
  (`_SyncCfgPersist`, `_TranslationSetFreq_Hz`) pour simuler une restauration. **Elle DOIT
  sauvegarder la valeur réelle avant de la modifier et la restaurer à la fin, dans TOUS les
  chemins de sortie (fin normale, Abort, watchdog timeout)** — sinon exécuter ce test corromprait
  la vraie configuration persistée de la machine (tolérance synchro, fréquence translation).
  Vérifie toi-même que les 3 chemins de sortie restaurent bien les backups avant de conclure.
- **Si tu repères un risque** (sécurité, effet de bord, incohérence non mentionnée ici) → **remonte-le
  explicitement**, même si rien ne te le demande.
- **Si une partie reste ambiguë** → pose la question plutôt que d'approximer.
- **Ne touche QUE les fichiers listés en §7.**
- Tu as le droit et le devoir de critiquer ce document s'il te semble faux ou incomplet.
- **Tu as le droit de LIRE (jamais modifier) n'importe quel fichier du dépôt pour lever une
  ambiguïté.** Pointeurs utiles :
  - `CODE/SIMULATION/PLC_TESTS/SUITE_MODES/FB_ModesValidation.st` — **LE modèle exact** à suivre
    pour la structure de la nouvelle suite (Start/Abort/CaseId, CASE Step OF, StepTimer/StepLimit,
    Report.Steps[]/Cases[], watchdog 90s, 3 chemins de sortie identiques).
  - `CODE/SIMULATION/PLC_TESTS/SUITE_SAFETY/FB_PLC_Tests_Management.st` — **l'orchestrateur réel**
    qui doit être étendu pour que la nouvelle suite soit lançable/visible (voir §4bis) — lis-le en
    entier avant de le modifier, c'est un fichier dense qui pilote TOUTES les suites existantes.
  - `CODE/SIMULATION/PLC_TESTS/GVL_PLC_Tests_Const.st` — pour ajouter la constante `SuiteSupervision`
    (⚠️ voir §4bis pour la valeur exacte — l'index 7 est déjà pris par "Framework Validation").
  - `CODE/SIMULATION/PLC_TESTS/TYPES/STRUCTS/ST_TestSuiteReport.st`,
    `CODE/SIMULATION/PLC_TESTS/TYPES/ENUMS/E_TestTerminalState.st`,
    `.../E_TestFailReason.st` — types déjà existants réutilisés tels quels.
  - `CODE/MAIN/PRG_09_Supervision.st` — pour confirmer les chemins exacts
    (`GVL_IHM.M1M2Sync.Cfg`, `_SyncCfgPersist`, `GVL_IHM.Commun.ConfigRestoredFromPersistent`,
    `GVL_IHM.Commun.BtnAckConfigRestored`) au moment de l'exécution (ont pu bouger depuis).
  - Si aucun de ces pointeurs ne suffit à lever le doute : arrête-toi et signale.

### 🔧 Correction 2026-07-24 (revue agent) — l'orchestrateur doit être étendu, pas seulement la suite

Un premier passage de ce document supposait à tort que les suites `FB_XxxValidation` existantes
n'étaient rattachées à aucun orchestrateur (recherche initiale faussée par un filtre d'exclusion
trop large sur les chemins contenant "SUITE_"). **Faux** : `FB_PLC_Tests_Management.st` (qui vit,
un peu à contre-sens de son nom, dans `SUITE_SAFETY/`) est l'unique orchestrateur réel — il route
`Cmd.RunSuite` vers une instance dédiée par suite, publie son rapport dans
`GVL_PLC_Tests.SuiteXxxValidation`, et alimente l'affichage IHM (`Status.ActiveSuiteName` etc.).
Créer `FB_SupervisionValidation.st` SANS l'y raccorder produirait un FB orphelin, impossible à
lancer depuis l'IHM/`Cmd.RunSuite` et invisible dans les rapports. **Corrigé** : le périmètre de ce
lot inclut maintenant `FB_PLC_Tests_Management.st` (voir §4bis), `GVL_PLC_Tests.st` (nouveau champ
rapport) et `ST_PlcTestsCmd.st` (nouvelle commande `RunSupervision`).

**Index corrigé** : `SuiteSupervision := 8`, **PAS `7`** — l'index `7` est déjà utilisé en dur par
le smoke-test interne "Framework Validation" (`CurrentSuiteIdx = 7` dans
`FB_PLC_Tests_Management.st`, sections "Démarrage" et "Mise à jour indicateurs IHM") — l'utiliser
créerait une collision silencieuse avec ce test existant.

## 1. Contexte

Le contrat de test `TASK_CONTEXT_CONFIG-PERSIST-01.yaml` (créé à l'ouverture de ce chantier)
exige un test PLC automatisé (`tests_automated_required: true`, `pony_tail: forbidden`,
`human_validation_required: true`) — toujours `tests_status: "planned"`, jamais écrit, alors que
le périmètre réel a explosé depuis (Lots 1-4 couvrent maintenant Sync/Bucket/Commun/Modes/
Joystick/Cycle/Winch M1+M2/Translation, contre 4 fichiers Winch/Sync seulement à l'origine).

Ce lot :
1. Écrit la suite de test PLC manquante (`FB_SupervisionValidation.st`), couvrant le MÉCANISME
   générique de restauration/sauvegarde/alarme (prouvé une fois en profondeur sur `M1M2Sync`,
   le plus simple) + un balayage de couverture léger (lecture seule) des 5 autres domaines à pont
   générique + un test dédié pour Translation (pattern manuel, pas de pont).
2. Met à jour `TASK_CONTEXT_CONFIG-PERSIST-01.yaml` (scope réel, chemin d'implémentation du test).
3. Met à jour `PLAN_TASK_v1.0.md` (T65/T66/T67/T68/T69/T71 — statuts obsolètes, voir §5) et ajoute
   une nouvelle entrée pour `DrainingTime` (trouvé hors scope pendant l'audit initial, jamais tracé).

### 🔍 Découverte importante — T68 est un non-problème, ne PAS le "corriger"

`PLAN_TASK_v1.0.md` T68 dit : *"Calibration neutre joystick (`_JoystickNeutralX/Y`) jamais
réécrite après `BtnCalibrate`"*. **Vérifié faux** : `NeutralXMem`/`NeutralYMem` sont des
`VAR_IN_OUT` de `FB_Joystick`, et `CODE/MAIN/PRG_01_Diagnostics.st` (appel `FB_Joystick_0`) passe
`_JoystickNeutralX`/`_JoystickNeutralY` (les vraies variables `GVL_PERSISTENT`) directement comme
arguments — la calibration (`NeutralXMem := RawX;` dans `FB_Joystick.st`) écrit donc **déjà**
directement dans le persistant, par référence, à chaque recalage. Ce lot **corrige seulement le
texte de T68** dans `PLAN_TASK_v1.0.md` (marqué résolu/non-problème), **ne touche à aucun fichier
`CODE/`** pour ce point.

## 2. Objectif

1. Créer `CODE/SIMULATION/PLC_TESTS/SUITE_SUPERVISION/FB_SupervisionValidation.st` (voir §4).
2. Ajouter `SuiteSupervision : INT := 8;` à `CODE/SIMULATION/PLC_TESTS/GVL_PLC_Tests_Const.st`.
3. Raccorder la nouvelle suite à l'orchestrateur réel : `FB_PLC_Tests_Management.st`,
   `GVL_PLC_Tests.st`, `ST_PlcTestsCmd.st` (voir §4bis).
4. Mettre à jour `DOC/AUDITS/ConfigPersistence/TASK_CONTEXT_CONFIG-PERSIST-01.yaml` (voir §5).
5. Mettre à jour `DOC/PLAN_TASK_v1.0.md` (voir §6).
6. Régénérer le bundle, vérifier les gates (y compris `check_config_persistence.py`).

## 3. Chemins réels vérifiés (à utiliser tels quels dans la suite)

| Domaine | Struct IHM | Struct Persist | Champ testé |
|---|---|---|---|
| Sync (TC-CP1/2/3) | `GVL_IHM.M1M2Sync.Cfg` | `_SyncCfgPersist` | `CfgSyncTolerance_M` (défaut réel `0.25`) |
| Cycle (TC-CP4) | `GVL_IHM.Cycle.Cfg` | `_CycleCfgPersist` | juste `.Initialized` (lecture seule) |
| Commun (TC-CP4) | `GVL_IHM.Commun.Cfg` | `_CommunCfgPersist` | juste `.Initialized` (lecture seule) |
| Bucket (TC-CP4) | `GVL_IHM.M2TreuilBenne.Bucket.Cfg` | `_BucketCfgPersist` | juste `.Initialized` (lecture seule) |
| Winch M1 (TC-CP4) | `GVL_IHM.M1TreuilRetenue.Cfg` | `_WinchM1CfgPersist` | juste `.Initialized` (lecture seule) |
| Winch M2 (TC-CP4) | `GVL_IHM.M2TreuilBenne.Cfg` | `_WinchM2CfgPersist` | juste `.Initialized` (lecture seule) |
| Translation (TC-CP5) | `GVL_IHM.TranslationM3.Cmd` | `_TranslationSetFreq_Hz` (variable plate, pas de struct — voir Lot 4) | `SetFreq_Hz` (défaut réel `0.0`) |

Alarme partagée : `GVL_IHM.Commun.ConfigRestoredFromPersistent` / `GVL_IHM.Commun.BtnAckConfigRestored`.

⚠️ **Ce lot dépend du Lot 4** (Translation `Initialized`/`_TranslationSetFreq_Hz`) pour TC-CP5
uniquement — si le Lot 4 n'est pas encore committé au moment de l'exécution, **signale-le et
saute TC-CP5** (`ConfigError` avec message clair), ne bloque pas les 4 autres cas.

## 4. Nouvelle suite — `CODE/SIMULATION/PLC_TESTS/SUITE_SUPERVISION/FB_SupervisionValidation.st`

Structure EXACTEMENT calquée sur `FB_ModesValidation.st` (même interface, mêmes types, même
squelette watchdog/Abort/verdict — seul le contenu des étapes change) :

```
(* ============================================================================
   🧪 FB_SupervisionValidation — Suite PLC Persistance Config (chantier ConfigPersistence)
   ============================================================================
   🎯 Rôle : valide le mécanisme générique FB_CfgPersistBridge_<Type> (restauration
      PERSISTENT->IHM au boot, sauvegarde continue IHM->PERSISTENT, alarme
      ConfigRestoredFromPersistent) en profondeur sur M1M2Sync (le plus simple), puis
      un balayage de couverture léger (lecture seule, sans risque) des 5 autres domaines
      à pont générique, puis un test dédié pour Translation (pattern manuel, pas de pont).
   📄 Couvre (TASK_CONTEXT_CONFIG-PERSIST-01.yaml, T65) :
      TC-CP1 : Restauration PERSISTENT->IHM quand Initialized=FALSE (M1M2Sync)
      TC-CP2 : Alarme ConfigRestoredFromPersistent ne s'éteint QUE sur front BtnAckConfigRestored
      TC-CP3 : Sauvegarde continue IHM->PERSISTENT stable après restauration (pas de corruption)
      TC-CP4 : Balayage de couverture (lecture seule) — Cycle/Commun/Bucket/WinchM1/WinchM2
               ont chacun Cfg.Initialized=TRUE en fonctionnement normal
      TC-CP5 : Translation.Cmd.SetFreq_Hz (pattern manuel, pas de pont générique) — même
               restauration/alarme que TC-CP1, Lot 4 requis
   ⚠️ TC-CP1/CP2/CP3/CP5 forcent des variables GVL_PERSISTENT réelles (Sync, Translation) —
      sauvegardées au démarrage du test, restaurées dans les 3 chemins de sortie (fin normale,
      Abort, watchdog). Ne JAMAIS retirer cette sauvegarde/restauration.
   🧩 Même moteur allégé (CASE direct) que FB_ModesValidation — pas de StepTable/CheckTable.
   ============================================================================ *)

FUNCTION_BLOCK PUBLIC FB_SupervisionValidation
VAR_INPUT
    Start       : BOOL;
    Abort       : BOOL;
    CaseId      : INT; // 0=tous ; 1..5=cas ciblé
END_VAR
VAR_OUTPUT
    Busy              : BOOL;
    Done              : BOOL;
    AnyFailed         : BOOL;
    StepElapsed       : TIME;
    Report            : ST_TestSuiteReport;
    TerminalState     : E_TestTerminalState;
    ConfigError       : BOOL;
    ConfigErrorStepId : INT;
    ErrorCode         : INT;
    ErrorMessage      : STRING(160);
END_VAR
VAR
    StartPrev       : BOOL;
    Step            : INT;
    CurrentCaseId   : INT;
    RequestedCaseId : INT;
    StepStarted     : BOOL;
    StepTimer       : TON;
    StepLimit       : TIME;
    StepFailed      : BOOL;
    StepPassed      : BOOL;
    Index           : INT;

    // 🛡️ Sauvegardes obligatoires (voir §0/§1) — restaurées dans les 3 chemins de sortie.
    BackupSyncTolerance          : REAL;
    BackupSyncInitialized        : BOOL;
    BackupTranslationFreq        : REAL;
    BackupTranslationInitialized : BOOL;
END_VAR

// === IMPLEMENTATION ===

IF Abort THEN
    // 🛡️ Restauration obligatoire AVANT de sortir (voir §0).
    _SyncCfgPersist.CfgSyncTolerance_M := BackupSyncTolerance;
    GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M := BackupSyncTolerance;
    GVL_IHM.M1M2Sync.Cfg.Initialized := BackupSyncInitialized;
    _TranslationSetFreq_Hz := BackupTranslationFreq;
    GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := BackupTranslationFreq;
    GVL_IHM.TranslationM3.Cmd.Initialized := BackupTranslationInitialized;
    GVL_IHM.Commun.ConfigRestoredFromPersistent := FALSE;
    GVL_IHM.Commun.BtnAckConfigRestored := FALSE;
    Busy := FALSE;
    Done := TRUE;
    AnyFailed := TRUE;
    TerminalState := E_TestTerminalState.TEST_TERMINAL_ABORTED;
    Report.Aborted := TRUE;
    Report.AnyFailed := TRUE;
    Report.TerminalState := TerminalState;
    Report.FailureSummary := 'Supervision/Persistance : ABORTED';
    RETURN;
END_IF;

IF Start AND NOT StartPrev AND NOT Busy THEN
    StartPrev := TRUE;
    Busy := TRUE;
    Done := FALSE;
    AnyFailed := FALSE;
    ConfigError := FALSE;
    ErrorCode := 0;
    ErrorMessage := '';
    TerminalState := E_TestTerminalState.TEST_TERMINAL_NONE;
    IF CaseId < 0 OR CaseId > 5 THEN
        Busy := FALSE;
        Done := TRUE;
        AnyFailed := TRUE;
        ConfigError := TRUE;
        ErrorCode := 6001;
        ErrorMessage := 'Supervision CaseId invalide';
        TerminalState := E_TestTerminalState.TEST_TERMINAL_CONFIG_ERROR;
        Report.TerminalState := TerminalState;
        Report.AnyFailed := TRUE;
        Report.ErrorCode := ErrorCode;
        Report.ErrorMessage := ErrorMessage;
        RETURN;
    END_IF;
    RequestedCaseId := CaseId;

    // 🛡️ Sauvegarde obligatoire AVANT toute modification (voir §0) — toujours faite, quel que
    // soit le cas demandé, pour rester sûr quel que soit le chemin de sortie emprunté.
    BackupSyncTolerance          := _SyncCfgPersist.CfgSyncTolerance_M;
    BackupSyncInitialized        := GVL_IHM.M1M2Sync.Cfg.Initialized;
    BackupTranslationFreq        := _TranslationSetFreq_Hz;
    BackupTranslationInitialized := GVL_IHM.TranslationM3.Cmd.Initialized;

    CASE RequestedCaseId OF
        1: Step := 10;
        2: Step := 20;
        3: Step := 30;
        4: Step := 40;
        5: Step := 50;
    ELSE
        Step := 10; // run all, démarre à TC-CP1
    END_CASE;
    Report.Name := 'Supervision / Persistance Config Validation';
    Report.InProgress := TRUE;
    Report.AllPassed := FALSE;
    Report.AnyFailed := FALSE;
    Report.Aborted := FALSE;
    Report.TerminalState := TerminalState;
    Report.ErrorCode := 0;
    Report.ErrorMessage := '';
    Report.FailureSummary := '';
    Report.CurrentStepId := Step;
    Report.Duration := T#0s;
    Report.RunCounter := Report.RunCounter + 1;
    FOR Index := 1 TO GVL_PLC_Tests_Const.MaxSteps DO
        Report.Steps[Index].Executed := FALSE;
        Report.Steps[Index].Passed := FALSE;
        Report.Steps[Index].FailReason := E_TestFailReason.FAIL_NONE;
        Report.Steps[Index].Duration := T#0s;
    END_FOR;
    FOR Index := 1 TO GVL_PLC_Tests_Const.MaxTestCases DO
        Report.Cases[Index].Executed := FALSE;
        Report.Cases[Index].Ok := FALSE;
        Report.Cases[Index].FailedStepId := 0;
        Report.Cases[Index].FailReason := E_TestFailReason.FAIL_NONE;
        Report.Cases[Index].Duration := T#0s;
    END_FOR;
    StepStarted := FALSE;
ELSIF NOT Start THEN
    StartPrev := FALSE;
END_IF;

IF NOT Busy THEN
    RETURN;
END_IF;

StepElapsed := StepElapsed + UDINT_TO_TIME(INT_TO_UDINT(GVL_PLC_Tests_Const.TaskCycleMs));
Report.Duration := Report.Duration + UDINT_TO_TIME(INT_TO_UDINT(GVL_PLC_Tests_Const.TaskCycleMs));
Report.CurrentStepId := Step;
CurrentCaseId := (Step / 10);
Report.CurrentCaseId := CurrentCaseId;

IF NOT StepStarted THEN
    StepStarted := TRUE;
    StepElapsed := T#0s;
    CASE Step OF
        10: StepLimit := T#200MS;
        11: StepLimit := T#500MS;
        20: StepLimit := T#200MS;
        21: StepLimit := T#500MS;
        22: StepLimit := T#500MS;
        23: StepLimit := T#500MS;
        30: StepLimit := T#500MS;
        40, 41, 42, 43, 44: StepLimit := T#2S; // généreux : la vraie machine a pu booter juste avant ce test
        50: StepLimit := T#200MS;
        51: StepLimit := T#500MS;
        52: StepLimit := T#1S;
    ELSE
        ConfigError := TRUE;
        ConfigErrorStepId := Step;
        ErrorCode := 6002;
        ErrorMessage := 'Supervision étape inconnue';
        StepLimit := T#0s;
    END_CASE;
END_IF;

StepTimer(IN := TRUE, PT := StepLimit);

CASE Step OF
    // ─────────── TC-CP1 : Restauration PERSISTENT->IHM (M1M2Sync) ───────────
    10:
        // Arrange : valeur PERSISTENT sentinelle distincte du défaut réel (0.25), IHM au défaut
        // struct (0.0) + Initialized:=FALSE -> déclenche la restauration au prochain passage du
        // pont réel (PRG_09_Supervision.instCfgPersistBridgeSync, tourne chaque scan MainTask).
        _SyncCfgPersist.CfgSyncTolerance_M := 0.42;
        GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M := 0.0;
        GVL_IHM.M1M2Sync.Cfg.Initialized := FALSE;
        StepPassed := TRUE;
        Step := 11;
        StepStarted := FALSE;

    11:
        // Assert : Hmi restauré depuis Persist, Initialized repassé TRUE.
        IF (GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M = 0.42) AND GVL_IHM.M1M2Sync.Cfg.Initialized THEN
            StepPassed := TRUE;
            IF RequestedCaseId = 1 THEN Step := 0; ELSE Step := 20; END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-CP2 : Alarme ConfigRestoredFromPersistent, doctrine reset=front ───────────
    20:
        GVL_IHM.M1M2Sync.Cfg.Initialized := FALSE; // redéclenche une restauration -> alarme
        StepPassed := TRUE;
        Step := 21;
        StepStarted := FALSE;

    21:
        IF GVL_IHM.Commun.ConfigRestoredFromPersistent THEN
            StepPassed := TRUE;
            Step := 22;
            StepStarted := FALSE;
        END_IF;

    22:
        // L'alarme ne doit JAMAIS s'éteindre seule (doctrine reset=front, REX 2026-07-23).
        IF StepElapsed >= T#200MS THEN
            IF GVL_IHM.Commun.ConfigRestoredFromPersistent THEN
                StepPassed := TRUE;
                Step := 23;
                StepStarted := FALSE;
            ELSE
                StepFailed := TRUE; // régression doctrine reset=front
            END_IF;
        END_IF;

    23:
        // Acquittement par front opérateur.
        GVL_IHM.Commun.BtnAckConfigRestored := TRUE;
        IF NOT GVL_IHM.Commun.ConfigRestoredFromPersistent THEN
            GVL_IHM.Commun.BtnAckConfigRestored := FALSE;
            StepPassed := TRUE;
            IF RequestedCaseId = 2 THEN Step := 0; ELSE Step := 30; END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-CP3 : Sauvegarde continue stable (pas de corruption) ───────────
    30:
        IF NOT GVL_IHM.M1M2Sync.Cfg.Initialized THEN
            GVL_IHM.M1M2Sync.Cfg.Initialized := FALSE; // s'assurer d'être bien restauré (héritage TC-CP1/CP2)
        END_IF;
        IF StepElapsed >= T#200MS THEN
            IF (_SyncCfgPersist.CfgSyncTolerance_M = 0.42) AND (GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M = 0.42) THEN
                StepPassed := TRUE;
                IF RequestedCaseId = 3 THEN Step := 0; ELSE Step := 40; END_IF;
                StepStarted := FALSE;
            ELSE
                StepFailed := TRUE; // Persist ou Hmi a dérivé -> corruption
            END_IF;
        END_IF;

    // ─────────── TC-CP4 : Balayage de couverture (lecture seule, sans risque) ───────────
    40:
        IF GVL_IHM.Cycle.Cfg.Initialized THEN
            StepPassed := TRUE; Step := 41; StepStarted := FALSE;
        END_IF;

    41:
        IF GVL_IHM.Commun.Cfg.Initialized THEN
            StepPassed := TRUE; Step := 42; StepStarted := FALSE;
        END_IF;

    42:
        IF GVL_IHM.M2TreuilBenne.Bucket.Cfg.Initialized THEN
            StepPassed := TRUE; Step := 43; StepStarted := FALSE;
        END_IF;

    43:
        IF GVL_IHM.M1TreuilRetenue.Cfg.Initialized THEN
            StepPassed := TRUE; Step := 44; StepStarted := FALSE;
        END_IF;

    44:
        IF GVL_IHM.M2TreuilBenne.Cfg.Initialized THEN
            StepPassed := TRUE;
            IF RequestedCaseId = 4 THEN Step := 0; ELSE Step := 50; END_IF;
            StepStarted := FALSE;
        END_IF;

    // ─────────── TC-CP5 : Translation SetFreq_Hz (pattern manuel, Lot 4 requis) ───────────
    50:
        _TranslationSetFreq_Hz := 12.5; // valeur sentinelle distincte du défaut réel (0.0)
        GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := 0.0;
        GVL_IHM.TranslationM3.Cmd.Initialized := FALSE;
        StepPassed := TRUE;
        Step := 51;
        StepStarted := FALSE;

    51:
        IF (GVL_IHM.TranslationM3.Cmd.SetFreq_Hz = 12.5) AND GVL_IHM.TranslationM3.Cmd.Initialized THEN
            StepPassed := TRUE;
            Step := 52;
            StepStarted := FALSE;
        END_IF;

    52:
        IF GVL_IHM.Commun.ConfigRestoredFromPersistent THEN
            GVL_IHM.Commun.BtnAckConfigRestored := TRUE;
            IF NOT GVL_IHM.Commun.ConfigRestoredFromPersistent THEN
                GVL_IHM.Commun.BtnAckConfigRestored := FALSE;
                StepPassed := TRUE;
                Step := 0;
                StepStarted := FALSE;
            END_IF;
        END_IF;
END_CASE;

// Verdict local de l'étape : PASS, FAIL ou TIMEOUT contrôlé.
IF StepPassed OR StepFailed OR StepTimer.Q THEN
    IF StepPassed THEN
        Report.Steps[Report.CurrentStepId].Passed := TRUE;
        Report.Steps[Report.CurrentStepId].FailReason := E_TestFailReason.FAIL_NONE;
    ELSE
        Report.Steps[Report.CurrentStepId].Passed := FALSE;
        Report.Steps[Report.CurrentStepId].FailReason := SEL(StepFailed, E_TestFailReason.FAIL_TIMEOUT, E_TestFailReason.FAIL_CHECK);
        AnyFailed := TRUE;
    END_IF;
    Report.Steps[Report.CurrentStepId].Executed := TRUE;
    Report.Steps[Report.CurrentStepId].Duration := StepElapsed;
    IF NOT StepPassed THEN
        Step := 0; // Échec ou timeout = fin immédiate.
    END_IF;
    StepPassed := FALSE;
    StepFailed := FALSE;
    StepTimer(IN := FALSE, PT := StepLimit);
    StepElapsed := T#0s;
    IF Step = 0 THEN
        // 🛡️ Restauration obligatoire AVANT de sortir (voir §0) — fin normale ou échec/timeout.
        _SyncCfgPersist.CfgSyncTolerance_M := BackupSyncTolerance;
        GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M := BackupSyncTolerance;
        GVL_IHM.M1M2Sync.Cfg.Initialized := BackupSyncInitialized;
        _TranslationSetFreq_Hz := BackupTranslationFreq;
        GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := BackupTranslationFreq;
        GVL_IHM.TranslationM3.Cmd.Initialized := BackupTranslationInitialized;
        GVL_IHM.Commun.ConfigRestoredFromPersistent := FALSE;
        GVL_IHM.Commun.BtnAckConfigRestored := FALSE;
        Busy := FALSE;
        Done := TRUE;
        Report.InProgress := FALSE;
        Report.AnyFailed := AnyFailed;
        Report.AllPassed := NOT AnyFailed;
        Report.TerminalState := SEL(AnyFailed, E_TestTerminalState.TEST_TERMINAL_DONE, E_TestTerminalState.TEST_TERMINAL_FAILED);
        TerminalState := Report.TerminalState;
        Report.Cases[1].Name := 'TC-CP1..CP5 Persistance Config';
        Report.Cases[1].Executed := TRUE;
        Report.Cases[1].Ok := NOT AnyFailed;
        Report.Cases[1].FailedStepId := 0;
        Report.Cases[1].FailReason := E_TestFailReason.FAIL_NONE;
        IF AnyFailed THEN
            Report.Cases[1].FailedStepId := Report.CurrentStepId;
            Report.Cases[1].FailReason := E_TestFailReason.FAIL_CHECK;
            Report.FailureSummary := CONCAT('Supervision/Persistance : échec étape ', INT_TO_STRING(Report.CurrentStepId));
        END_IF;
        Report.Cases[1].Duration := Report.Duration;
    ELSE
        StepStarted := FALSE;
    END_IF;
END_IF;

// Limite globale de sécurité de la suite : 90 s maximum.
IF Report.Duration >= T#90s AND Busy THEN
    // 🛡️ Restauration obligatoire AVANT de sortir (voir §0) — watchdog.
    _SyncCfgPersist.CfgSyncTolerance_M := BackupSyncTolerance;
    GVL_IHM.M1M2Sync.Cfg.CfgSyncTolerance_M := BackupSyncTolerance;
    GVL_IHM.M1M2Sync.Cfg.Initialized := BackupSyncInitialized;
    _TranslationSetFreq_Hz := BackupTranslationFreq;
    GVL_IHM.TranslationM3.Cmd.SetFreq_Hz := BackupTranslationFreq;
    GVL_IHM.TranslationM3.Cmd.Initialized := BackupTranslationInitialized;
    GVL_IHM.Commun.ConfigRestoredFromPersistent := FALSE;
    GVL_IHM.Commun.BtnAckConfigRestored := FALSE;
    Busy := FALSE;
    Done := TRUE;
    AnyFailed := TRUE;
    TerminalState := E_TestTerminalState.TEST_TERMINAL_WATCHDOG_TIMEOUT;
    Report.InProgress := FALSE;
    Report.AnyFailed := TRUE;
    Report.AllPassed := FALSE;
    Report.TerminalState := TerminalState;
    Report.ErrorCode := 6003;
    Report.ErrorMessage := 'Watchdog Supervision/Persistance expiré';
    Report.FailureSummary := Report.ErrorMessage;
END_IF;
```

⚠️ Si le Lot 4 n'est pas encore committé (pas de `_TranslationSetFreq_Hz`/`GVL_IHM.TranslationM3.Cmd.Initialized`)
au moment de l'exécution : **signale-le clairement dans ta restitution** plutôt que d'improviser un
remplacement. Tu peux dans ce cas restituer la suite avec TC-CP5 commenté/désactivé
temporairement (`ConfigError` si `CaseId=5` ou `0` demandé), à réactiver dans une passe séparée
une fois le Lot 4 confirmé présent — signale ce choix explicitement, ne le fais pas silencieusement.

## 4bis. Raccordement à l'orchestrateur réel

**Choix de conception (pour limiter le risque sur un fichier dense et partagé par toutes les
suites)** : la nouvelle suite est raccordée comme une suite **ciblée autonome**
(`Cmd.RunSupervision` / `Cmd.RunSuite = 8`), **PAS ajoutée à la chaîne `RunAll`**
(Safety→Translation→Bucket→Encoder→Modes→Heartbeat). Ne touche donc à AUCUNE des branches
`ChainMode` existantes ni à l'ordre d'enchaînement — seulement des ajouts additifs, jamais de
modification du chaînage actuel.

### `CODE/SIMULATION/PLC_TESTS/TYPES/STRUCTS/ST_PlcTestsCmd.st`

État actuel :
```
TYPE ST_PlcTestsCmd :
STRUCT
    RunSafety     : BOOL;
    RunTranslation: BOOL;
    RunBucket     : BOOL;
    RunEncoder    : BOOL;
    RunModes      : BOOL;
    RunHeartbeat  : BOOL;
    RunFramework  : BOOL;
    RunAll        : BOOL;
    RunSuite      : INT;
    RunCase       : INT;
    Abort         : BOOL;
    ClearReport   : BOOL;
END_STRUCT
END_TYPE
```
→ ajouter une ligne `RunSupervision : BOOL;` (même style, juste après `RunHeartbeat` par exemple —
la position exacte dans le struct n'a pas d'importance) :
```
    RunHeartbeat  : BOOL;   // Lance la suite Heartbeat IHM↔PLC
    RunSupervision: BOOL;   // Lance la suite Supervision/Persistance config
    RunFramework  : BOOL;   // Lance l'autotest indépendant du framework
```

### `CODE/SIMULATION/PLC_TESTS/GVL_PLC_Tests.st`

Ajouter, à la suite de `SuiteHeartbeatValidation` (même bloc que les autres rapports de suite) :
```
    SuiteHeartbeatValidation   : ST_TestSuiteReport;  // Rapport de la suite Heartbeat IHM↔PLC
    SuiteSupervisionValidation : ST_TestSuiteReport;  // Rapport de la suite Supervision/Persistance config
```

### `CODE/SIMULATION/PLC_TESTS/GVL_PLC_Tests_Const.st`

```
    SuiteHeartbeat   : INT := 6;    // index de suite Heartbeat IHM↔PLC (Cmd.RunSuite)
    SuiteSupervision : INT := 8;    // index de suite Supervision/Persistance config (Cmd.RunSuite) — ⚠️ 7 est pris par Framework Validation, ne pas réutiliser
```

### `CODE/SIMULATION/PLC_TESTS/SUITE_SAFETY/FB_PLC_Tests_Management.st` — 6 points d'ajout précis

**(a) Déclaration VAR** — à la suite de `instHeartbeatValidation : FB_HeartbeatValidation;` :
```
    instHeartbeatValidation   : FB_HeartbeatValidation;
    instSupervisionValidation : FB_SupervisionValidation;
```
et à la suite de `RequestedCaseHeartbeat : INT;` :
```
    RequestedCaseHeartbeat : INT;
    StartSupervision          : BOOL;
    AbortSupervision          : BOOL;
    RequestedCaseSupervision  : INT;
    LastLoggedSupervisionRun  : UDINT;
```

**(b) Reset dans l'état IDLE/PASSED/FAILED/ABORTED** — à la suite de `AbortHeartbeat := FALSE;` :
```
        AbortHeartbeat := FALSE;
        StartSupervision := FALSE;
        AbortSupervision := FALSE;
```

**(c) Normalisation commande unitaire** — à la suite du bloc `ELSIF GVL_PLC_Tests.Cmd.RunHeartbeat THEN ... END_IF;` (avant le `ELSIF GVL_PLC_Tests.Cmd.RunFramework THEN`) :
```
        ELSIF GVL_PLC_Tests.Cmd.RunHeartbeat THEN
            GVL_PLC_Tests.Cmd.RunSuite := GVL_PLC_Tests_Const.SuiteHeartbeat;
            GVL_PLC_Tests.Cmd.RunHeartbeat := FALSE;
        ELSIF GVL_PLC_Tests.Cmd.RunSupervision THEN
            GVL_PLC_Tests.Cmd.RunSuite := GVL_PLC_Tests_Const.SuiteSupervision;
            GVL_PLC_Tests.Cmd.RunSupervision := FALSE;
        ELSIF GVL_PLC_Tests.Cmd.RunFramework THEN
```

**(d) Démarrage d'une suite ciblée** — ajouter un bloc après celui de Heartbeat (avant le
`END_IF;` qui clôt toute la série de `ELSIF GVL_PLC_Tests.Cmd.RunSuite = ...`), sans condition de
simulation (ce test ne dépend d'aucune E/S simulée, contrairement à Safety/Bucket/Encoder) :
```
        // Démarrage suite Supervision/Persistance config (aucune dépendance simulation matérielle).
        ELSIF GVL_PLC_Tests.Cmd.RunSuite = GVL_PLC_Tests_Const.SuiteSupervision THEN
            ChainMode := FALSE;
            CurrentSuiteIdx := GVL_PLC_Tests_Const.SuiteSupervision;
            StartSupervision := TRUE;
            RequestedCaseSupervision := GVL_PLC_Tests.Cmd.RunCase;
            GVL_PLC_Tests.Status.FailureSummary := '';
            GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_RUNNING;
            GVL_PLC_Tests.Cmd.RunSuite := 0;
            GVL_PLC_Tests.Cmd.RunCase := 0;
        END_IF;
```
⚠️ Le `END_IF;` existant qui clôt la série doit devenir le `END_IF;` de CE dernier bloc (un seul
`END_IF;` final pour toute la chaîne de `ELSIF`) — ne duplique pas le `END_IF;`.

**(e) Watchdog + Abort global** — ajouter à la cascade watchdog (avant le `ELSE AbortBucket :=
TRUE; END_IF;` final de ce bloc) :
```
            ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteHeartbeat THEN
                AbortHeartbeat := TRUE;
            ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteSupervision THEN
                AbortSupervision := TRUE;
            ELSE
                AbortBucket := TRUE;
            END_IF;
```
et ajouter `AbortSupervision := TRUE;` à la suite de `AbortHeartbeat := TRUE;` dans le bloc
`IF AbortTrig.Q OR NOT GVL_Simulation.SimulationModeActive THEN`.

**(f) Surveillance de fin d'exécution** — ajouter un bloc `ELSIF` calqué sur celui de Heartbeat
(terminal, pas de chaînage), juste après le bloc `ELSIF CurrentSuiteIdx = ... SuiteModes AND
instModesValidation.Done THEN ... END_IF;` (dernier bloc avant le `END_CASE;` de la section 2) :
```
        ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteSupervision AND instSupervisionValidation.Done THEN
            AbortSupervision := FALSE;
            IF instSupervisionValidation.TerminalState <> E_TestTerminalState.TEST_TERMINAL_DONE AND instSupervisionValidation.Report.RunCounter <> LastLoggedSupervisionRun THEN
                LastLoggedSupervisionRun := instSupervisionValidation.Report.RunCounter;
                GVL_PLC_Tests.EventSequence := GVL_PLC_Tests.EventSequence + 1;
                IF GVL_PLC_Tests.EventCount < GVL_PLC_Tests_Const.MaxTestEvents THEN
                    GVL_PLC_Tests.EventCount := GVL_PLC_Tests.EventCount + 1;
                ELSE
                    GVL_PLC_Tests.EventOverflow := TRUE;
                END_IF;
                EventIdx := UDINT_TO_INT(GVL_PLC_Tests.EventSequence MOD INT_TO_UDINT(GVL_PLC_Tests_Const.MaxTestEvents)) + 1;
                GVL_PLC_Tests.EventLog[EventIdx].Sequence := GVL_PLC_Tests.EventSequence;
                GVL_PLC_Tests.EventLog[EventIdx].Severity := E_TestEventSeverity.TEST_EVENT_ERROR;
                GVL_PLC_Tests.EventLog[EventIdx].SuiteId := GVL_PLC_Tests_Const.SuiteSupervision;
                GVL_PLC_Tests.EventLog[EventIdx].CaseId := instSupervisionValidation.Report.CurrentCaseId;
                GVL_PLC_Tests.EventLog[EventIdx].StepId := instSupervisionValidation.Report.CurrentStepId;
                GVL_PLC_Tests.EventLog[EventIdx].Code := instSupervisionValidation.ErrorCode;
                GVL_PLC_Tests.EventLog[EventIdx].Message := instSupervisionValidation.ErrorMessage;
            END_IF;
            FinalAborted := instSupervisionValidation.Report.Aborted;
            FinalAnyFailed := instSupervisionValidation.AnyFailed;
            GVL_PLC_Tests.Status.FailureSummary := instSupervisionValidation.Report.FailureSummary;
            IF FinalAborted THEN
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_ABORTED;
            ELSIF FinalAnyFailed THEN
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_FAILED;
            ELSE
                GVL_PLC_Tests.Status.RunState := E_TestRunState.TESTRUN_PASSED;
            END_IF;
        END_IF;
```
⚠️ Cette suite n'étant jamais lancée en `ChainMode`, pas de logique d'enchaînement/agrégation à
ajouter ici (contrairement à Safety→Translation→Bucket) — modèle-toi sur le bloc `SuiteHeartbeat`
existant (terminal, non-chaîné) plutôt que sur Safety/Translation/Bucket (chaînés).

**(g) Appel de l'instance** — section "3. Appel des instances de suites" :
```
instHeartbeatValidation(Start := StartHeartbeat, Abort := AbortHeartbeat, CaseId := RequestedCaseHeartbeat);
instSupervisionValidation(Start := StartSupervision, Abort := AbortSupervision, CaseId := RequestedCaseSupervision);
```

**(h) Centralisation rapport** — section "4. Centralisation et recopie vers GVL_PLC_Tests" :
```
GVL_PLC_Tests.SuiteHeartbeatValidation := instHeartbeatValidation.Report;
GVL_PLC_Tests.SuiteSupervisionValidation := instSupervisionValidation.Report;
```

**(i) Indicateurs IHM** — section "5. Mise à jour des indicateurs de progression IHM", ajouter un
`ELSIF` calqué sur celui de `SuiteHeartbeat`, avant le `ELSE` final (bloc Safety, qui doit rester
en dernier recours) :
```
    ELSIF CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteSupervision THEN
        GVL_PLC_Tests.Status.ActiveSuiteName := instSupervisionValidation.Report.Name;
        GVL_PLC_Tests.Status.ActiveCaseId := instSupervisionValidation.Report.CurrentCaseId;
        GVL_PLC_Tests.Status.ActiveStepId := instSupervisionValidation.Report.CurrentStepId;
        GVL_PLC_Tests.Status.StepElapsed := instSupervisionValidation.StepElapsed;
        GVL_PLC_Tests.Status.TerminalState := instSupervisionValidation.TerminalState;
        GVL_PLC_Tests.Status.ErrorCode := instSupervisionValidation.ErrorCode;
        GVL_PLC_Tests.Status.ErrorMessage := instSupervisionValidation.ErrorMessage;
    ELSE
```

**(j) Agrégation des compteurs de cas** — section 6 (dernière, avant le clignotant), ajouter un
bloc calqué sur celui de `SuiteHeartbeat` :
```
IF ChainMode OR CurrentSuiteIdx = GVL_PLC_Tests_Const.SuiteSupervision THEN
    FOR Idx := 1 TO GVL_PLC_Tests_Const.MaxTestCases DO
        IF instSupervisionValidation.Report.Cases[Idx].Executed THEN
            TotalCount := TotalCount + 1;
            IF instSupervisionValidation.Report.Cases[Idx].Ok THEN
                PassedCount := PassedCount + 1;
            ELSE
                FailedCount := FailedCount + 1;
            END_IF;
        END_IF;
    END_FOR;
END_IF;
```
(le `ChainMode OR` ne se déclenchera jamais puisque cette suite n'est jamais chaînée — gardé
uniquement pour rester au même style que les blocs voisins, ne complique rien).

⚠️ **Relis `FB_PLC_Tests_Management.st` en entier après tes modifications** — c'est un fichier
partagé par 6 suites existantes déjà en production ; une erreur de copier-coller ici (ex. `END_IF`
mal placé, embranchement `ELSIF` cassé) casserait potentiellement TOUTES les suites, pas
seulement la nouvelle. Vérifie que le fichier compile mentalement (parenthèses `IF`/`END_IF`
équilibrées) avant de restituer.

## 5. Mise à jour `TASK_CONTEXT_CONFIG-PERSIST-01.yaml`

État actuel pertinent (extraits) :
```yaml
scope_code:
  - "CODE/MAIN/PRG_09_Supervision.st"
  - "CODE/SUPERVISION/_TYPES/ST_WinchCfg.st"
  - "CODE/SUPERVISION/_TYPES/ST_SyncHMI.st"
  - "CODE/SUPERVISION/_TYPES/ST_CommunHMI.st"
out_of_scope:
  - "Refonte architecture ..."
  - "M2Benne.Config (OffsetOpenM/CloseM) et Commun.LimitLegalDepthMinAllowed_M/Enabled : sentinelle deja correcte ..."
  - "Translation M3 : pas de struct Cfg IHM-editable equivalente identifiee, hors perimetre de ce lot"
  - "Logique safety elle-meme ..."
tests_implementation_paths:
  - "CODE/SIMULATION/PLC_TESTS/SUITE_SUPERVISION/FB_SupervisionValidation.st (a creer -- TC-CP1: ...)"
tests_status: "planned"
test_execution_evidence: []
```
→ remplacer par :
```yaml
scope_code:
  - "CODE/MAIN/PRG_09_Supervision.st"
  - "CODE/MAIN/PRG_00_Inputs.st"
  - "CODE/MAIN/PRG_02_Encoders.st"
  - "CODE/MAIN/PRG_03_Safety.st"
  - "CODE/MAIN/PRG_05_Cycle.st"
  - "CODE/MAIN/PRG_06_WinchControl.st"
  - "CODE/MAIN/PRG_07_TranslationControl.st"
  - "CODE/GVL_PERSISTENT.st"
  - "CODE/COMMUN/FB_CfgPersistBridge_SyncCfg.st"
  - "CODE/COMMUN/FB_CfgPersistBridge_CycleCfg.st"
  - "CODE/COMMUN/FB_CfgPersistBridge_CommunCfg.st"
  - "CODE/COMMUN/FB_CfgPersistBridge_BucketCfg.st"
  - "CODE/COMMUN/FB_CfgPersistBridge_WinchCfg.st"
  - "CODE/SUPERVISION/_TYPES/ST_WinchCfg.st"
  - "CODE/SUPERVISION/_TYPES/ST_SyncCfg.st"
  - "CODE/SUPERVISION/_TYPES/ST_CommunCfg.st"
  - "CODE/SUPERVISION/_TYPES/ST_BucketCfg.st"
  - "CODE/SUPERVISION/_TYPES/ST_CycleCfg.st"
  - "CODE/SUPERVISION/_TYPES/ST_TranslationCmd.st"
  - "TOOLS/AGENT_WORKFLOW/scripts/check_config_persistence.py"
out_of_scope:
  - "Refonte architecture (IHM lit/ecrit PERSISTENT en direct, suppression du miroir GVL_IHM) : non applicable, l'IHM (supervision externe) n'a jamais d'acces direct aux variables PLC internes -- ecarte par l'utilisateur"
  - "Winch Cfg partage M1/M2 (CfgMaxStepDescente/Ascent/SlowdownDistance_M/SlowSpeed_Pct) : deplaces vers Commun.Cfg (Lot 3d-1), plus un probleme de reconciliation -- resolu structurellement, pas par ce lot de test"
  - "Joystick _JoystickNeutralX/Y : verifie deja correctement ecrit par reference (VAR_IN_OUT FB_Joystick), aucun bug -- voir PLAN_TASK T68 corrige"
  - "Logique safety elle-meme (FB_Safety_Winch/FB_Safety_Translation) : aucune modification, seule la restauration de la CONFIG qui alimente ces FB est testee"
tests_implementation_paths:
  - "CODE/SIMULATION/PLC_TESTS/SUITE_SUPERVISION/FB_SupervisionValidation.st (TC-CP1: restauration M1M2Sync, TC-CP2: alarme+ack front, TC-CP3: sauvegarde continue stable, TC-CP4: balayage couverture 5 domaines, TC-CP5: Translation pattern manuel)"
tests_status: "implemented"
test_execution_evidence: []
```
⚠️ `tests_status: "implemented"` (pas `"executed"`/`"passed"`) — le code du test est écrit et
compile, mais **l'exécution réelle en CODESYS reste à faire par l'utilisateur**
(`human_validation_required: true` reste vrai, `test_execution_evidence` reste vide jusqu'à ce que
l'utilisateur fournisse une preuve d'exécution réelle).

## 6. Mise à jour `DOC/PLAN_TASK_v1.0.md`

Corriger le statut des entrées suivantes (garder le numéro Txx, changer seulement l'icône/texte
de statut et ajouter une note de résolution — ne pas supprimer la ligne, l'historique reste utile) :

- **T65** : `🟠` → `🟡` — texte : *"Test PLC automatique écrit (`FB_SupervisionValidation.st`,
  TC-CP1..CP5), en attente d'exécution réelle CODESYS par l'utilisateur avant clôture C3/safety."*
- **T66** : `🔴` → `✅` — texte : *"Résolu (Lot 2f, commit `b61e540`) : `Cycle.Cfg.SetDepth_M`/
  `SetOffset_M` protégés par `_CycleCfgPersist`, alarme `ConfigRestoredFromPersistent` incluse."*
- **T67** : `🟠` → `✅` (si ce lot est committé après le Lot 4 — sinon garder `🟠` et ajouter *"en
  cours, voir Lot 4"*) — texte : *"Résolu (Lot 4) : `TranslationM3.Cmd.SetFreq_Hz` protégé par
  `_TranslationSetFreq_Hz` + flag `Initialized` dédié (pattern manuel, pas de pont générique —
  éviterait de persister aussi `BtnFwd`/`BtnRev`)."*
- **T68** : texte actuel → **corrigé, pas juste marqué résolu** : *"❌ Non-problème — vérifié
  2026-07-24 : `NeutralXMem`/`NeutralYMem` sont des `VAR_IN_OUT` de `FB_Joystick`, `_JoystickNeutralX`/
  `_JoystickNeutralY` sont passées PAR RÉFÉRENCE depuis `PRG_01_Diagnostics.st` — la calibration
  écrit déjà directement dans le persistant. Aucune correction nécessaire."*
- **T69** : `🟡` → `✅` — texte : *"Résolu (Lot 3b, commit `8f90d89`) : `Bucket.Cfg.CfgTimeoutDuration`
  protégé par `_BucketCfgPersist` (effet de bord du miroir de struct complet)."*
- **T71** : `🟡` → `✅` — texte : *"Résolu (Lot 3c, commit `f836c0f`/`9d2d12f`) :
  `check_config_persistence.py` créé et intégré à `run_all_gates.py` (Gate 3)."*

Ajouter une nouvelle entrée (numéro suivant disponible après T75, donc **T76**) :
```
| T76 | 🟡 `FB_Cycle.st:112` : `DrainingTime : TIME := T#5s` jamais câblé depuis `GVL_IHM`/`GVL_PERSISTENT` — paramètre en dur, jamais identifié dans l'audit persistance initial (trouvé en préparant ce chantier, hors scope) | Projet | Trouvé en préparant DOC/AUDITS/ConfigPersistence, `FB_Cycle.st:112` |
```
(reprendre exactement le format des lignes existantes du tableau — colonnes `Txx | Statut/description | Responsable | Référence`, vérifie le nombre de colonnes réel du tableau avant d'insérer, ne devine pas le format)

## 7. Fichiers à modifier

1. `CODE/SIMULATION/PLC_TESTS/SUITE_SUPERVISION/FB_SupervisionValidation.st` (nouveau)
2. `CODE/SIMULATION/PLC_TESTS/GVL_PLC_Tests_Const.st` (ajout `SuiteSupervision := 8`)
3. `CODE/SIMULATION/PLC_TESTS/TYPES/STRUCTS/ST_PlcTestsCmd.st` (ajout `RunSupervision`)
4. `CODE/SIMULATION/PLC_TESTS/GVL_PLC_Tests.st` (ajout `SuiteSupervisionValidation`)
5. `CODE/SIMULATION/PLC_TESTS/SUITE_SAFETY/FB_PLC_Tests_Management.st` (raccordement, voir §4bis)
6. `DOC/AUDITS/ConfigPersistence/TASK_CONTEXT_CONFIG-PERSIST-01.yaml`
7. `DOC/PLAN_TASK_v1.0.md`
8. `CODE/CODE_Bundle.xml` (régénération obligatoire)

## 8. Contraintes STRICTES

- **La suite de test ne doit JAMAIS laisser `_SyncCfgPersist`/`_TranslationSetFreq_Hz` ou les
  champs `GVL_IHM` correspondants dans un état modifié après son exécution** — vérifie les 3
  chemins de sortie (fin normale/échec, Abort, watchdog) avant de restituer (voir §0).
  Ne restitue pas cette suite si un de ces 3 chemins ne restaure pas les backups.
- **Ne pas toucher** `CODE/COMMUN/FB_CfgPersistBridge_*.st` ni leurs instances dans
  `PRG_09_Supervision.st` — le test les OBSERVE, ne les modifie jamais.
- **Ne PAS ajouter la nouvelle suite à la chaîne `RunAll`** (voir §4bis) — raccordement en suite
  ciblée autonome uniquement, ne touche à aucune branche `ChainMode` existante.
- **Ne pas toucher** aux fichiers des lots précédents déjà committés.
- **Ne pas modifier `TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py`** ni aucun autre outillage.
- **PascalCase strict**, pas de hongrois.
- Ne pas ajouter T68 comme "corrigé dans le code" — c'est une correction de **texte PLAN_TASK
  uniquement**, aucun fichier `CODE/` ne change pour ce point (voir §1).

## 9. Obligatoire avant restitution

1. Relire toi-même les 3 chemins de sortie de `FB_SupervisionValidation.st` (Abort, fin normale à
   `Step=0`, watchdog) et confirmer que chacun restaure bien les 4 backups + réinitialise l'alarme.
2. Relire `FB_PLC_Tests_Management.st` en entier après modification (voir §4bis, avertissement
   final) — confirme que les 6 suites préexistantes ne sont pas affectées par tes ajouts.
3. Régénérer le bundle : `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .` — doit
   se terminer par `PASS: CODE/CODE_Bundle.xml is fresh`.
4. `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --skip-codesys` — aucune NOUVELLE erreur.
5. `python TOOLS/AGENT_WORKFLOW/scripts/check_config_persistence.py .` — doit rester `PASS`.
6. Ne PAS committer — restituer le diff pour vérification.

## 10. Critères d'acceptation

- [ ] `FB_SupervisionValidation.st` créé, structure conforme à `FB_ModesValidation.st` (interface,
      watchdog, verdict, 3 chemins de sortie).
- [ ] TC-CP1/CP2/CP3 (Sync), TC-CP4 (balayage 5 domaines, lecture seule), TC-CP5 (Translation)
      implémentés exactement comme spécifié §4.
- [ ] **Les 3 chemins de sortie restaurent les 4 backups** (`BackupSyncTolerance`,
      `BackupSyncInitialized`, `BackupTranslationFreq`, `BackupTranslationInitialized`) et
      réinitialisent `ConfigRestoredFromPersistent`/`BtnAckConfigRestored` — vérifié explicitement.
- [ ] `SuiteSupervision : INT := 8;` ajoutée à `GVL_PLC_Tests_Const.st` (**pas 7**, déjà pris par
      Framework Validation).
- [ ] `ST_PlcTestsCmd.st` : `RunSupervision` ajouté. `GVL_PLC_Tests.st` :
      `SuiteSupervisionValidation` ajouté.
- [ ] `FB_PLC_Tests_Management.st` : les 10 points d'ajout du §4bis présents (déclaration, reset,
      normalisation, démarrage, watchdog/abort, surveillance fin, appel instance, centralisation,
      indicateurs IHM, agrégation compteurs) — **aucune des 6 suites existantes ni la chaîne
      `RunAll` non modifiées**.
- [ ] `TASK_CONTEXT_CONFIG-PERSIST-01.yaml` : scope réel à jour, `tests_status: "implemented"`.
- [ ] `PLAN_TASK_v1.0.md` : T65/T66/T67/T68/T69/T71 mis à jour, T76 (DrainingTime) ajouté.
- [ ] `FB_CfgPersistBridge_*.st` non modifiés.
- [ ] `check_code_style.py` non modifié.
- [ ] Bundle régénéré et frais, gates + `check_config_persistence.py` sans nouvelle erreur.
