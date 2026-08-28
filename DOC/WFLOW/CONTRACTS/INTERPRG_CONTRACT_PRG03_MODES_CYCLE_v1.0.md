# Contrat inter‑PRG — PRG_03 Modes & Cycle (v1.0-proposal)

> **À FIGER PAR VISA HUMAIN.** Le contrat prépare l'interface ; il ne valide ni le GRAFCET métier
> actuel ni le déplacement des assistants Dive/Extraction.

## 🎯 Responsabilité

`PRG_03_Modes_Cycle` :

- arbitre le mode et publie les autorisations logiques positives ;
- exécute les séquences de programme ;
- publie ce que le programme demande et ce qu'il attend de l'opérateur ;
- publie un état lisible de la séquence.

Il ne fusionne pas la demande avec le geste courant, ne calcule pas de sécurité axe, ne produit pas
de `Cmd`/`Act` physique et ne porte pas les interlocks treuil/benne/translation.

## 📥 Entrées contractuelles

| Producteur | Données | Fraîcheur | Usage |
|---|---|---|---|
| `PRG_02` | `Data`, `HwIn` | courant | faits qualifiés, mesures, états machine |
| IHM | `Cmd` de modes/cycle | courant | sélection et validation opérateur |
| `PRG_04.Data` | états treuils/benne/safety | N‑1 | transition de séquence et diagnostic |
| `PRG_05.Data` | état translation/safety | N‑1 | transition de séquence et diagnostic |

Le geste joystick n'est pas converti en permit générique par `PRG_03`. Le programme publie
l'attente ; `PRG_04/05` réalisent la concordance avec `PRG_02.Data.Joystick` au scan courant.

## 📦 Sortie publique cible

```iecst
VAR_OUTPUT
    Data : ST_ModesCycleInterPrg;
END_VAR
```

```iecst
TYPE ST_ModesCycleInterPrg :
STRUCT
    Auth            : ST_fbModes_Autorisations;
    ReqProgram      : ST_ProgramRequest;
    SequenceState   : ST_SequencePublicState;
END_STRUCT
END_TYPE
```

### `ProgramRequest`

Le contrat est une **demande**, pas une commande effective :

```iecst
TYPE ST_ProgramRequest :
STRUCT
    ReqWinchM1            : ST_ProgramWinchRequest;
    ReqWinchM2            : ST_ProgramWinchRequest;
    ReqTranslation        : ST_ProgramTranslationRequest;
    ReqBucket             : ST_ProgramBucketRequest;
    OperatorCoupledIntent : ST_OperatorCoupledIntent; // Intention couplée continue opérateur (joystick/boutons), TOUS modes
END_STRUCT
END_TYPE
```

Types exacts proposés pour le premier gel, en conservant le `%` actuel :

```iecst
TYPE ST_ProgramWinchRequest :
STRUCT
    ReqStartStop : BOOL;
    ReqDirection : INT;   // -1 descente, 0 neutre, +1 montée
    SpeedTgtPct  : REAL;  // 0.0..100.0 %, non signée
END_STRUCT
END_TYPE

TYPE ST_ProgramTranslationRequest :
STRUCT
    ReqStart    : BOOL;
    PositionTgt : INT;    // codes cible existants, migration enum séparée
END_STRUCT
END_TYPE

TYPE ST_ProgramBucketRequest :
STRUCT
    ReqOpen                : BOOL;
    ReqClose               : BOOL;
    ReqKoboldMeasureEnable : BOOL;
END_STRUCT
END_TYPE
```

| Sous-demande | Champs | Interdits |
|---|---|---|
| Winch M1/M2 | `ReqStartStop`, `ReqDirection`, `SpeedTgtPct` | `Permit`, `SafeStop`, relais, frein |
| Translation | `ReqStart`, `PositionTgt` | mot commande variateur, interlock final |
| Bucket | `ReqOpen`, `ReqClose`, `ReqKoboldMeasureEnable` | sortie contacteur physique directe |

Les noms suivent `Req → Tgt → Cmd → Act` : aucune nouvelle variable `*Ref` pour une consigne,
aucun `MotionPermit` ambigu.

### `SequenceState`

Types exacts proposés :

```iecst
TYPE E_OperatorAxis : (NONE := 0, JOYSTICK_X := 1, JOYSTICK_Y := 2, BUTTON := 3); END_TYPE
TYPE E_ProgramSequence : (NONE := 0, MAIN_CYCLE := 1, DIVE_SEARCH := 2, EXTRACTION := 3); END_TYPE

TYPE ST_SequencePublicState :
STRUCT
    Ready               : BOOL;
    Lifecycle           : ST_Lifecycle;
    Fault               : ST_Fault;
    SequenceId          : E_ProgramSequence;
    Step                : E_CycleStep;
    StepAtFault         : E_CycleStep;
    OperatorActionId    : UINT;
    ExpectedAxis        : E_OperatorAxis;
    ExpectedDirection   : INT;
    WaitingForOperator  : BOOL;
    WaitingForProcess   : BOOL;
    RequestActive       : BOOL;
END_STRUCT
END_TYPE
```

Les textes IHM restent une projection `PRG_07`; le bus expose des identifiants stables et des faits,
pas une multiplication de chaînes.

**Précondition :** ces champs doivent venir des sorties publiques d'un `FB_Cycle` au profil AF‑03.
Le code actuel n'a pas encore `Fault`, `Lifecycle` ni `OperatorActionId`; `PRG_03` ne doit pas les
reconstituer par logique métier locale.

## 🔄 Ordre intra-PRG cible

1. appeler `FB_Modes` ;
2. publier `Data.Auth := instModes.Auth` ;
3. appeler les séquences avec `Data.Auth` courant et retours procédé N‑1 ;
4. recopier leurs demandes dans `Data.ReqProgram` ;
5. recopier lifecycle, étape et attente dans `Data.SequenceState` ;
6. neutraliser toutes les demandes si mode/sequence non actifs.

## ⚖️ Arbitrage aval

`PRG_04/05` reçoivent en parallèle :

- le geste courant `PRG_02.Data.Joystick` ;
- `PRG_03.Data.Auth` ;
- `PRG_03.Data.ReqProgram`.

Ils choisissent la source selon le mode, vérifient deadman/axe/sens attendu, appliquent interlocks et
safety, puis publient les demandes finales et la raison de refus. En manuel, la demande programme
peut rester entièrement neutre.

## 🌊 DiveSearch / Extraction — décision séparée

Le bus est conçu pour recevoir leurs demandes futures, mais T165 ne déplace pas leurs instances.
L'AF‑02 active les maintient dans `PRG_04` pour la maintenance, alors que la préférence humaine est
de les rapprocher des cycles. Un lot C4 séparé devra :

1. décider propriétaire et cas maintenance ;
2. amender AF‑02/AF‑04/AF‑10 ;
3. conserver toutes les préconditions, lenteurs, limites, Kobold et diagnostics ;
4. démontrer que la safety reste courante dans `PRG_04`.

## 🛡️ Conservation fonctionnelle PRG_03

- mêmes modes, priorités et inhibitions avant toute évolution fonctionnelle ;
- mêmes demandes cycle pendant le seul remappage d'interface ;
- aucune correction opportuniste de X1/X11 ou des vitesses ;
- demandes neutralisées hors mode actif ;
- aucun accès direct à une instance d'un autre PRG ;
- aucun accès aval à `instCycleSemiAuto` après migration ;
- retours procédé N‑1 explicitement nommés ;
- arrêt courant sur neutre/deadman/safety réalisé en `PRG_04/05`, pas au scan suivant.

## ✅ Critères de gel du contrat

1. `Data.Auth`, `Data.ReqProgram`, `Data.SequenceState` ont types, unités, polarités et invalidité ;
2. l'ordre `Modes → Auth courant → Cycle → publication` est testé ;
3. chaque consommateur actuel de `instCycleSemiAuto` a un chemin public équivalent ;
4. `instCycleSemiAuto` est privé après `rg` zéro consommateur ;
5. l'interface ne contient ni sécurité axe ni commande physique ;
6. les scénarios manuel existants sont identiques avant/après ;
7. les scénarios semi-auto vérifient geste neutre, sens opposé, perte deadman et sécurité locale ;
8. G200, palier C, tous gates, bundle frais et tests ST2C/StruCpp ciblés sont verts.
