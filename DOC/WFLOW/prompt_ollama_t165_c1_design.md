# Préambule obligatoire — sous-agent Ollama
Automate CODESYS 3.5, machine de dragage en carrière noyée. Code ST dans `CODE/`, appliqué manuellement par l'utilisateur. Sécurité machine réelle.

Expert Senior Automatisme Industriel. Style TDAH-Friendly. Réponds en français. Rigueur, zéro blabla.

---

# MISSION T165-C1 : Conception et génération des DUTs + publication PRG_03.Data

## Contrat (TASK_CONTRACT_T165-C1_PRG03_PUBLICATION.yaml)
- **Criticité** : C4
- **Objectif** : Créer le bus public `PRG_03.Data` contenant `Auth`, `ReqProgram`, `SequenceState` et publier les sorties existantes de `FB_Modes` et `instCycleSemiAuto` sans exposer l'instance `instCycleSemiAuto` ni modifier la logique métier.

## Référentiels
- Contrat inter-PRG : `DOC/WFLOW/CONTRACTS/INTERPRG_CONTRACT_PRG03_MODES_CYCLE_v1.0.md`
- Contrat de composant AF-03 : `DOC/AF/AF_Partie-03_Contrats_Composants_v2.3.md`

## 1. Nouveaux DUTs à créer dans `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/`

### 1.1 `E_ProgramSequence.st`
```iecst
TYPE E_ProgramSequence :
(
    NONE        := 0,
    MAIN_CYCLE  := 1,
    DIVE_SEARCH := 2,
    EXTRACTION  := 3
);
END_TYPE
```

### 1.2 `ST_ProgramWinchRequest.st`
```iecst
TYPE ST_ProgramWinchRequest :
STRUCT
    ReqStartStop : BOOL; // Ordre marche/arrêt demandé par le programme (TRUE=Marche)
    ReqDirection : INT;  // Sens demandé (-1: Descente, 0: Stop, 1: Montée)
    SpeedTgtPct  : REAL; // Consigne de vitesse cible demandée (0.0 à 100.0 %)
END_STRUCT
END_TYPE
```

### 1.3 `ST_ProgramTranslationRequest.st`
```iecst
TYPE ST_ProgramTranslationRequest :
STRUCT
    ReqStart    : BOOL; // Demande de démarrage mouvement translation
    PositionTgt : INT;  // Cible de position demandée (1=Trémie, 2=P2, 3=P1, 4=Maintenance)
END_STRUCT
END_TYPE
```

### 1.4 `ST_ProgramBucketRequest.st`
```iecst
TYPE ST_ProgramBucketRequest :
STRUCT
    ReqOpen                : BOOL; // Demande ouverture benne
    ReqClose               : BOOL; // Demande fermeture benne
    ReqKoboldMeasureEnable : BOOL; // Demande activation mesure/contacteur Kobold
END_STRUCT
END_TYPE
```

### 1.5 `ST_ProgramRequest.st`
```iecst
TYPE ST_ProgramRequest :
STRUCT
    ReqWinchM1     : ST_ProgramWinchRequest;
    ReqWinchM2     : ST_ProgramWinchRequest;
    ReqTranslation : ST_ProgramTranslationRequest;
    ReqBucket      : ST_ProgramBucketRequest;
END_STRUCT
END_TYPE
```

### 1.6 `ST_SequencePublicState.st`
```iecst
TYPE ST_SequencePublicState :
STRUCT
    Ready               : BOOL;             // Séquenceur disponible
    Lifecycle           : ST_Lifecycle;     // Cycle de vie (Busy, Done)
    Fault               : ST_Fault;         // Défaut transverse
    SequenceId          : E_ProgramSequence;// Séquence active (MAIN_CYCLE, etc.)
    Step                : E_CycleStep;      // Étape active du Grafcet
    StepAtFault         : E_CycleStep;      // Étape mémorisée au défaut
    OperatorActionId    : UINT;             // Identifiant action opérateur attendue
    ExpectedAxis        : E_OperatorAxis;   // Organe joystick/bouton attendu
    ExpectedDirection   : INT;              // Sens attendu (-1, 0, +1)
    WaitingForOperator  : BOOL;             // En attente action opérateur
    WaitingForProcess   : BOOL;             // En attente condition procédé
    RequestActive       : BOOL;             // Demande de mouvement active
END_STRUCT
END_TYPE
```

### 1.7 `ST_ModesCycleInterPrg.st`
```iecst
TYPE ST_ModesCycleInterPrg :
STRUCT
    Auth          : ST_fbModes_Autorisations; // Bus d'autorisations machine
    ReqProgram    : ST_ProgramRequest;        // Demandes programme vers PRG_04 / PRG_05
    SequenceState : ST_SequencePublicState;   // État public de la séquence
END_STRUCT
END_TYPE
```

## 2. Structure cible de `CODE/M_MAIN/PRG_03_Modes_Cycle.st`

Publier `Data : ST_ModesCycleInterPrg` en `VAR_OUTPUT` (tout en conservant `Auth` et `instCycleSemiAuto` temporairement pour compatibilité tant que C2 n'a pas migré les consommateurs).

Recopie des demandes et états :
```iecst
// Publication du bus Data
Data.Auth := instModes.Auth;

// Publication des demandes programme (actives si SEMI_AUTO)
IF Auth.Mode = E_Mode.SEMI_AUTO THEN
    Data.ReqProgram.ReqWinchM1.ReqStartStop := instCycleSemiAuto.WinchM1Cmd.StartStop;
    Data.ReqProgram.ReqWinchM1.ReqDirection := instCycleSemiAuto.WinchM1Cmd.Direction;
    Data.ReqProgram.ReqWinchM1.SpeedTgtPct  := instCycleSemiAuto.WinchM1Cmd.SpeedPct;

    Data.ReqProgram.ReqWinchM2.ReqStartStop := instCycleSemiAuto.WinchM2Cmd.StartStop;
    Data.ReqProgram.ReqWinchM2.ReqDirection := instCycleSemiAuto.WinchM2Cmd.Direction;
    Data.ReqProgram.ReqWinchM2.SpeedTgtPct  := instCycleSemiAuto.WinchM2Cmd.SpeedPct;

    Data.ReqProgram.ReqTranslation.ReqStart    := instCycleSemiAuto.TranslationCmd.Start;
    Data.ReqProgram.ReqTranslation.PositionTgt := instCycleSemiAuto.TranslationCmd.Target;

    Data.ReqProgram.ReqBucket.ReqOpen                := instCycleSemiAuto.BucketCmd.Open;
    Data.ReqProgram.ReqBucket.ReqClose               := instCycleSemiAuto.BucketCmd.Close;
    Data.ReqProgram.ReqBucket.ReqKoboldMeasureEnable := instCycleSemiAuto.BucketCmd.KoboldContactorCmd;

    Data.SequenceState.SequenceId := E_ProgramSequence.MAIN_CYCLE;
ELSE
    // Neutralisation complète
    Data.ReqProgram.ReqWinchM1.ReqStartStop := FALSE;
    Data.ReqProgram.ReqWinchM1.ReqDirection := 0;
    Data.ReqProgram.ReqWinchM1.SpeedTgtPct  := 0.0;

    Data.ReqProgram.ReqWinchM2.ReqStartStop := FALSE;
    Data.ReqProgram.ReqWinchM2.ReqDirection := 0;
    Data.ReqProgram.ReqWinchM2.SpeedTgtPct  := 0.0;

    Data.ReqProgram.ReqTranslation.ReqStart    := FALSE;
    Data.ReqProgram.ReqTranslation.PositionTgt := 0;

    Data.ReqProgram.ReqBucket.ReqOpen                := FALSE;
    Data.ReqProgram.ReqBucket.ReqClose               := FALSE;
    Data.ReqProgram.ReqBucket.ReqKoboldMeasureEnable := FALSE;

    Data.SequenceState.SequenceId := E_ProgramSequence.NONE;
END_IF;

Data.SequenceState.Ready              := instCycleSemiAuto.Ready;
Data.SequenceState.Lifecycle          := instCycleSemiAuto.Lifecycle;
Data.SequenceState.Fault              := instCycleSemiAuto.Fault;
Data.SequenceState.Step               := instCycleSemiAuto.CycleStep;
Data.SequenceState.StepAtFault        := instCycleSemiAuto.CycleStepAtError;
Data.SequenceState.OperatorActionId   := instCycleSemiAuto.OperatorActionId;
Data.SequenceState.ExpectedAxis       := instCycleSemiAuto.ExpectedAxis;
Data.SequenceState.ExpectedDirection  := instCycleSemiAuto.ExpectedDirection;
Data.SequenceState.WaitingForOperator := instCycleSemiAuto.WaitingForOperator;
Data.SequenceState.WaitingForProcess  := instCycleSemiAuto.WaitingForProcess;
Data.SequenceState.RequestActive      := instCycleSemiAuto.RequestActive;
```

## TA MISSION
1. **Auditer** cette proposition de DUTs et de publication.
2. **Vérifier** la conformité stricte avec `NAMING_CONVENTION.md` (PascalCase, NC-050/060/070/100/110).
3. **Vérifier** l'absence totale de Safety/PowerCutOff/Permit dans `ReqProgram`.
4. **Valider** l'ordre d'évaluation `Modes -> instCycleSemiAuto -> Publication Data`.
5. Donner ton **verdict formel (PASS / BLOCK)** avec tes recommandations.
