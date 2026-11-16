🟡 ADVISORY

Verdict : audit statique partiel — les verrous A-F sont identifiés et des patchs ST sont proposés, mais PASS impossible sans dépôt complet, mapping IHM M1/M2/Both, interface réelle des FB et essais automate.

Impact : en l’état, `MAINT_N2` ne garantit ni M1 seul, ni M2 seul, ni Both en présence de défaut. Plusieurs coupures process/safety restent actives.

Horodatage : 2026-04-26 — Durée : audit statique sur extraits fournis, aucune exécution.

## Niveau 1 — Invariants auditables

1. [✅ PASS] Les verrous A-F sont listés à partir des extraits fournis.
2. [✅ PASS] La distinction « à lever automatiquement en `MAINT_N2` » / « barrière ultime à conserver » est explicite.
3. [✅ PASS] Des patchs ST sont proposés pour `FB_Modes.st`, `PRG_03_Modes_Cycle.st`, `FB_WinchCmdArbitrationM1/M2.st`, `PRG_04_Treuils_Benne.st`, `FB_Safety_Winch.st` et `PRG_06_Outputs.st`.
4. [❌ FAIL] Aucun patch n’est compilé ni testé. Aucune preuve d’exécution automate.
5. [❌ FAIL] Le mapping IHM M1/M2/Both n’est pas fourni. `JoystickWinchSelectRequest` n’est pas prouvé comme source consolidée joystick + IHM.
6. [❌ FAIL] Les lignes M2 972-991, les appels réels des FB et le corps exact de `PRG_06_Outputs.st` ne sont pas fournis verbatim. Les patchs PRG_06 sont donc des transformations exactes de conditions, pas des remplacements de lignes complètes.
7. [✅ PASS] `PowerContactorEngaged_DI`, homme-mort joystick, `TopPositionSensor` et `MecaD` sont explicitement conservés dans la proposition.
8. [❌ FAIL] `CauseOppositeDirActive` et `CauseNoMovementActive` n’ont pas de bypass visible dans les extraits. Ils peuvent rester bloquants même avec `BypassEncoderFault`.
9. [⚪ N/A] Tests terrain M1 seul / M2 seul / Both avec défauts simulés : non exécutés.

## Niveau 1 bis — Inventaire exhaustif des verrous

### A — `FB_Modes.st`, lignes 364-400

1. [À LEVER AUTO] `M3AtTremie AND NOT AllowWinchMoveAtTremie` force `Auth.JoystickWinchSelectArbitrated := 2`. Bloque M1 seul et Both à la trémie.
2. [À LEVER AUTO] `CoupledBucketSeqEnable AND JoystickWinchSelectRequest=0 AND (JoystickPull XOR JoystickPush)` force `JoystickWinchSelectArbitrated := 2` tant que la séquence godet n’est pas satisfaite. Bloque M1/Both.
3. [À LEVER AUTO] `Auth.CoupledBucketPhaseLocked := TRUE` peut rester latché. Aucun reset explicite en `MAINT_N2` dans l’extrait.
4. [PREUVE MANQUANTE] Mapping des boutons IHM M1/M2/Both vers `JoystickWinchSelectRequest`. Si les boutons IHM ne sont pas déjà fusionnés dans cette variable, le patch A seul ne suffit pas.

### B — `PRG_03_Modes_Cycle.st`, lignes 511-516

1. [À LEVER AUTO] `WinchDescentAuth_M3 := FALSE` si `TglEnableWinchDescentLock_M3` est vrai et que M3 n’est ni en P1, ni en maintenance, ni bypassé. Bloque la descente M1 et, sauf exceptions godet, M2.

### C — `FB_WinchCmdArbitrationM1.st` / `M2.st`

1. [À DÉCIDER / RECOMMANDÉ CONSERVER] `RequestConflict := ReqAscent AND ReqDescend` bloque `RunRequest`. Un ordre contradictoire ascent+descend ne doit pas être autorisé sans acceptation de risque.
2. [À LEVER AUTO] `NOT Context.BucketBusy`.
3. [À LEVER AUTO] `NOT Context.WinchBothMotionBlockedByBucket`.
4. [À LEVER AUTO] `NOT ((Context.SyncBlocksAscent AND ReqAscent) OR (Context.SyncBlocksDescent AND ReqDescend))`.
5. [CONSERVER] `(NOT TglJoystickMaster OR Joystick.DeadmanArmed)` : homme-mort.
6. [À LEVER AUTO SI EXIGENCE LITTÉRALE] `(NOT TglJoystickMaster OR (Joystick.AxisX.Direction = 0))`. Si cette condition est une sécurité mécanique, la conserver.
7. [À LEVER AUTO] `BothDirectionAuthorized` quand `BothIntent.Active` et que les permis M1/M2 ne sont pas tous vrais.
8. [PREUVE MANQUANTE] `BothIntent.Active` : mapping exact depuis `WinchSel=0`, `WinchSel=1`, `WinchSel=2` et boutons IHM.

### D — `PRG_04_Treuils_Benne.st`

1. [À LEVER AUTO] `ProcessPermitM1_Descend` bloqué par `KoboldBottomTouchLatched OR BypassKoboldBottomTouched` et `DescendPermitDiveBucketOpen`.
2. [À LEVER AUTO] `ProcessPermitM2_Descend` bloqué par bottom touch, bucket non ouvert, `ManualBucketLimitsActive`, `T248BucketJogActive`.
3. [À LEVER AUTO] `ProcessPermitM1_Ascent` bloqué par `ExtractionAssistActive` sans `ReqBucket.AscentPermit`.
4. [À LEVER AUTO] `ProcessPermitM2_Ascent` bloqué par extraction assist, `ManualBucketLimitsActive`, `T248BucketJogActive`.
5. [À LEVER AUTO] Lignes 1083-1090 : `NOT WinchDescentAuth_M3` force `ProcessAndSafetyPermitM1_Descend := FALSE` et coupe M2 sauf jog/open/close.
6. [À LEVER AUTO EN SÉLECTION SÉPARÉE] `CoupledBoth := instWinchSync.SyncActive OR WinchBothMotionActive`. En `MAINT_N2`, si `WinchSel=1/2`, un défaut de l’autre treuil ne doit pas couper le treuil sélectionné.
7. [À LEVER AUTO SI D6] `SafeStopM1_Active := SafeStopM1_Raw OR (CoupledBoth AND SafeStopM2_Raw)`.
8. [À LEVER AUTO SI D6] `SafeStopM2_Active := SafeStopM2_Raw OR (CoupledBoth AND SafeStopM1_Raw)`.
9. [À LEVER AUTO SI D6] `EffectivePermitM1/M2_*` exige le permis de l’autre treuil quand `CoupledBoth`.
10. [À LEVER AUTO] Bypass non forcés : `EncoderFaultBypass`, `BypassProcess` / `SlackCable`, `BypassMecaA/B/C/E`.
11. [À DÉCIDER / DANGER] Bypass non forcés : `BypassOperatorComm`, `BypassPhaseRotation`, `BypassBrakeThermal`, `BypassMotorThermal`.
12. [CONSERVER SAUF BYPASS EXPLICITE IHM] `BypassTopLimitSwitch`, `BypassLimitLegal`, `BypassCableLimitSwitch`, `BypassMecaD`, `BypassGlobal`, `BypassSafety`.

### E — `FB_Safety_Winch.st`

1. [À LEVER AUTO VIA BYPASS] `CauseOperatorCommActive` -> SafeStop.
2. [À LEVER AUTO VIA BYPASS] `CauseEncoderActive` -> SafeStop.
3. [À DÉCIDER] `CauseMotorThermalActive` -> SafeStop + PowerCutOff.
4. [À DÉCIDER] `CausePhaseRotationActive` -> SafeStop.
5. [À LEVER AUTO] `CauseMecaAActive`, `CauseMecaBActive`, `CauseMecaCActive`, `CauseMecaEEscaladeActive`.
6. [CONSERVER] `CauseMecaDActive` sauf bypass explicite.
7. [À DÉCIDER] `CauseBrakeThermalActive` -> SafeStop + PowerCutOff.
8. [PATCH FB MANQUANT] `CauseOppositeDirActive` -> SafeStop. Pas de bypass visible.
9. [PATCH FB MANQUANT] `CauseNoMovementActive` -> SafeStop. Pas de bypass visible.
10. [CONSERVER] `AscentPermit` vérifie `TopPositionSensor` via `NOT BypassTopLimitSwitch`.
11. [CONSERVER SAUF BYPASS EXPLICITE] `AscentPermit` vérifie `TopLimitM` via `NOT (BypassGlobal OR BypassTopLimitSoftware)`.
12. [CONSERVER OU DÉCIDER] `DescendPermit` vérifie `CauseCableLimitActive`, `LimitLegalReached`.
13. [À LEVER AUTO VIA BYPASS] `DescendPermit` vérifie `CauseSlackCableActive` via `BypassProcess OR BypassGlobal`.

### F — `PRG_06_Outputs.st`

1. [À LEVER AUTO VIA MAINT_N2] `NOT Enable` / `PowerCutOff`.
2. [À LEVER AUTO VIA MAINT_N2] `SafeStop`.
3. [À LEVER AUTO VIA MAINT_N2] `PermitFinalBlocked`.
4. [À DÉCIDER] `Error` timeout frein 500 ms.
5. [À LEVER AUTO VIA MAINT_N2] `RestartInhibit`.
6. [CONSERVER] `ContactorStuckLatched`. Un contacteur physiquement collé ne peut pas être commandé par logiciel.
7. [À LEVER AUTO EN SÉLECTION SÉPARÉE] `instSyncContactorFinal` : concordance M1/M2 quand `WinchOutputCoupled`, sauf `BypassGlobal`.

## Niveau 2 — Plan d’action chirurgical

### Patch 0 — Définir `MaintN2`

Localisation : `PRG_04_Treuils_Benne.st` et `PRG_06_Outputs.st`, section `VAR`.

Action exacte :

```iecst
MaintN2 : BOOL;
```

Puis avant la première utilisation :

```iecst
MaintN2 := (PRG_03_Modes_Cycle.Data.Auth.Mode = E_Mode.MAINT_N2);
```

Outil déterministe associé : compilation CODESYS, revue statique, test automate.

Risque si ignoré : patchs non actifs ou non compilables.

### Patch A — `FB_Modes.st`, lignes 364-400

Localisation : bloc d’arbitrage `JoystickWinchSelectArbitrated`.

Action exacte : remplacer le bloc par :

```iecst
IF (Auth.Mode = E_Mode.MAINT_N2) OR (Auth.Mode = E_Mode.MAINT_N1) THEN
    IF Auth.Mode = E_Mode.MAINT_N2 THEN
        // MAINT_N2 : priorité absolue à la sélection opérateur.
        // Pas d'arbitrage trémie ni séquence godet.
        Auth.CoupledBucketPhaseLocked := FALSE;
        BucketSeqSatisfied := FALSE;
        Auth.JoystickWinchSelectArbitrated := JoystickWinchSelectRequest;
    ELSE
        IF M3AtTremie AND NOT AllowWinchMoveAtTremie THEN
            Auth.JoystickWinchSelectArbitrated := 2;
            BucketSeqSatisfied := FALSE;
        ELSIF CoupledBucketSeqEnable
           AND (JoystickWinchSelectRequest = 0)
           AND (JoystickPull XOR JoystickPush) THEN
            Auth.CoupledBucketPhaseLocked := TRUE;
            IF (JoystickPull AND BucketIsClosed) OR (JoystickPush AND BucketIsOpen) THEN
                BucketSeqSatisfied := TRUE;
            END_IF;
            IF BucketSeqSatisfied THEN
                Auth.JoystickWinchSelectArbitrated := 0;
            ELSE
                Auth.JoystickWinchSelectArbitrated := 2;
            END_IF;
        ELSE
            Auth.JoystickWinchSelectArbitrated := JoystickWinchSelectRequest;
        END_IF;
    END_IF;
ELSE
    Auth.JoystickWinchSelectArbitrated := 0;
    BucketSeqSatisfied := FALSE;
END_IF;
```

Preuve manquante : si les boutons IHM M1/M2/Both ne sont pas déjà fusionnés dans `JoystickWinchSelectRequest`, remplacer la ligne `Auth.JoystickWinchSelectArbitrated := JoystickWinchSelectRequest;` par le mux IHM réel. Les tags IHM exacts ne sont pas fournis.

Risque si ignoré : M1 et Both restent forcés sur M2 à la trémie ou pendant la séquence godet.

### Patch B — `PRG_03_Modes_Cycle.st`, lignes 511-516

Action exacte : remplacer l’affectation par :

```iecst
Data.SequenceState.WinchDescentAuth_M3 :=
    (Data.Auth.Mode = E_Mode.MAINT_N2)
    OR NOT GVL_IHM.Commun.Cfg.TglEnableWinchDescentLock_M3
    OR GVL_IHM.M3Translation.State.AtP1
    OR GVL_IHM.M3Translation.State.AtMaintenance
    OR GVL_IHM.M3Translation.Bypass.LimitSwitch
    OR GVL_IHM.M3Translation.Bypass.Global;
```

Risque si ignoré : descente M1 bloquée, descente M2 bloquée hors jog godet.

### Patch C — `FB_WinchCmdArbitrationM1.st` et `M2.st`

Localisation : déclaration `VAR_INPUT` et calcul `RunRequest`.

Action exacte : ajouter une entrée :

```iecst
MaintN2 : BOOL;
```

Puis remplacer le calcul par :

```iecst
RequestConflict := ReqAscent AND ReqDescend;

BothDirectionAuthorized := (NOT BothIntent.Active)
    OR ((ReqAscent AND NOT ReqDescend) AND Context.M1AscentAllowed AND Context.M2AscentAllowed)
    OR ((ReqDescend AND NOT ReqAscent) AND Context.M1DescendAllowed AND Context.M2DescendAllowed);

IF MaintN2 THEN
    BothDirectionAuthorized := TRUE;
END_IF;

RunRequest := (ReqAscent OR ReqDescend)
          AND NOT RequestConflict
          AND (MaintN2 OR NOT Context.BucketBusy)
          AND (MaintN2 OR NOT Context.WinchBothMotionBlockedByBucket)
          AND (MaintN2 OR NOT ((Context.SyncBlocksAscent AND ReqAscent)
                            OR (Context.SyncBlocksDescent AND ReqDescend)))
          AND (NOT TglJoystickMaster OR Joystick.DeadmanArmed)
          AND (MaintN2 OR NOT TglJoystickMaster OR (Joystick.AxisX.Direction = 0))
          AND BothDirectionAuthorized;
```

Puis aux appels de `instWinchCmdArbitrationM1` et `instWinchCmdArbitrationM2`, ajouter :

```iecst
MaintN2 := MaintN2,
```

Si l’exigence littérale impose même les ordres contradictoires, remplacer `AND NOT RequestConflict` par `AND (MaintN2 OR NOT RequestConflict)`. Non recommandé sans acceptation de risque.

Risque si ignoré : blocage par bucket busy, blocage sync, blocage BothDirectionAuthorized.

### Patch D1 — `PRG_04_Treuils_Benne.st`, permis process

Localisation : après la dernière affectation de `ProcessPermitM1/M2_Ascent/Descend`, avant le calcul de `ProcessAndSafetyPermit...`.

Action exacte :

```iecst
IF MaintN2 THEN
    ProcessPermitM1_Descend := TRUE;
    ProcessPermitM2_Descend := TRUE;
    ProcessPermitM1_Ascent  := TRUE;
    ProcessPermitM2_Ascent  := TRUE;
END_IF;
```

Risque si ignoré : bottom touch, godet non ouvert, extraction assist, manual bucket limits et T248 continuent de bloquer.

### Patch D2 — `PRG_04_Treuils_Benne.st`, bypass safety M1

Localisation : `instSafetyWinchM1`, lignes 941 et 972-991.

Action exacte : remplacer les expressions par :

```iecst
EncoderFaultBypass     := GVL_IHM.M1TreuilRetenue.Bypass.EncoderFault OR MaintN2,
BypassProcess          := (GVL_IHM.M1TreuilRetenue.Bypass.Process OR GVL_IHM.Commun.Bypass.SlackCable) OR MaintN2,
BypassOperatorComm     := GVL_IHM.M1TreuilRetenue.Bypass.OperatorComm OR MaintN2,
BypassPhaseRotation    := GVL_IHM.M1TreuilRetenue.Bypass.PhaseRotation OR MaintN2,
BypassBrakeThermal     := GVL_IHM.M1TreuilRetenue.Bypass.BrakeThermal OR MaintN2,
BypassMotorThermal     := GVL_IHM.M1TreuilRetenue.Bypass.MotorThermal OR MaintN2,
BypassMecaA            := GVL_IHM.M1TreuilRetenue.Bypass.MecaA OR MaintN2,
BypassMecaB            := GVL_IHM.M1TreuilRetenue.Bypass.MecaB OR MaintN2,
BypassMecaC            := GVL_IHM.M1TreuilRetenue.Bypass.MecaC OR MaintN2,
BypassMecaE            := GVL_IHM.M1TreuilRetenue.Bypass.MecaE OR MaintN2,
```

Conserver inchangés :

```iecst
BypassGlobal           := GVL_IHM.M1TreuilRetenue.Bypass.Global,
BypassSafety           := GVL_IHM.M1TreuilRetenue.Bypass.Safety,
BypassTopLimitSwitch   := BypassM1TopLimitSwitchEff,
BypassTopLimitSoftware := BypassM1TopLimitSoftwareEff,
BypassCableLimitSwitch := BypassM1CableLimitSwitchEff,
BypassLimitLegal       := BypassM1LimitLegalEff,
BypassMecaD            := BypassM1MecaDEff,
```

Appliquer la même transformation à `instSafetyWinchM2` avec les tags M2. Les lignes M2 exactes ne sont pas fournies verbatim.

Risque : `BypassBrakeThermal`, `BypassMotorThermal` et `BypassPhaseRotation` en `MAINT_N2` suppriment des protections thermiques/ordre de phase. À valider formellement. Si refus, retirer les `OR MaintN2` correspondants : l’exigence « quoi qu’il arrive » ne sera alors pas satisfaite.

### Patch D3 — `PRG_04_Treuils_Benne.st`, cross-coupling lignes 1103-1114

Option recommandée, isole M1/M2 en sélection séparée mais conserve l’arrêt croisé en Both :

```iecst
CoupledBoth := (instWinchSync.SyncActive OR WinchBothMotionActive)
    AND NOT (MaintN2 AND (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated <> 0));
```

Option stricte pour autoriser Both malgré défaut de l’autre treuil :

```iecst
CoupledBoth := (NOT MaintN2) AND (instWinchSync.SyncActive OR WinchBothMotionActive);
```

Risque : l’option stricte supprime l’arrêt croisé M1/M2 en `MAINT_N2`. Si les deux treuils sont mécaniquement couplés, le mouvement d’un seul peut créer une contrainte mécanique.

### Patch E — `FB_Safety_Winch.st`, `OppositeDir` / `NoMovement`

Localisation : calcul de `CausesSafeStopActive`.

Action exacte : ajouter une entrée `MaintN2 : BOOL;` puis neutraliser les deux causes sans bypass visible :

```iecst
CauseOppositeDirActive := RawOppositeDirActive AND NOT MaintN2;
CauseNoMovementActive  := RawNoMovementActive  AND NOT MaintN2;
```

Les noms `RawOppositeDirActive` / `RawNoMovementActive` sont à adapter au code réel. Sans ce patch, `BypassEncoderFault` peut ne pas suffire.

Risque : masque un vrai défaut de direction ou d’absence de mouvement. À réserver à `MAINT_N2`.

### Patch F — `PRG_06_Outputs.st`, interlock sortie

Localisation : condition de coupure de `instWinchOutputInterlockM1` / `M2`.

Action exacte : appliquer la transformation suivante aux noms du snippet :

```iecst
StopOutput := (NOT (Enable OR MaintN2))
           OR (SafeStop AND NOT MaintN2)
           OR (PermitFinalBlocked AND NOT MaintN2)
           OR (Error AND NOT MaintN2)
           OR (RestartInhibit AND NOT MaintN2)
           OR ContactorStuckLatched;
```

`ContactorStuckLatched` reste conservé. Un contacteur collé est une barrière matérielle, pas un verrou process.

Pour `instSyncContactorFinal` :

```iecst
instSyncContactorFinal(
    ...
    BypassGlobal := GVL_IHM.Commun.Bypass.Global
        OR (MaintN2 AND (PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated <> 0)),
    ...
);
```

Pour l’exigence littérale Both malgré défaut, remplacer par `OR MaintN2`. Risque : perte de surveillance de concordance des contacteurs.

`PowerContactorEngaged_DI` doit rester en série et ne doit pas être forcé par `MaintN2`. Son chemin exact n’est pas fourni dans les extraits : preuve manquante.

## Auto-revue

1. Le patch répond à M1 seul / M2 seul / Both en `MAINT_N2` pour les verrous process et sync.
2. Les barrières conservées sont : `PowerContactorEngaged_DI`, homme-mort joystick, `TopPositionSensor`, `MecaD`, `ContactorStuckLatched`.
3. Les points `MotorThermal`, `BrakeThermal`, `PhaseRotation`, `OppositeDir`, `NoMovement` sont les plus dangereux à lever. Ils sont inclus pour satisfaire l’exigence littérale, mais nécessitent une acceptation de risque formelle.
4. Sans les tags IHM M1/M2/Both et le corps exact de `PRG_06`, les patchs ne peuvent pas être déclarés compilables ni PASS.
5. Aucun fichier modifié, aucun commit, aucun test automate exécuté.