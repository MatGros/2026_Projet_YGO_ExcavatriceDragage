# Contrat inter‑PRG — PRG_03 Modes & Cycle (v1.0)

> **Interface appliquée (refactor).** Le contrat décrit l'interface **actuelle** de `PRG_03_Modes_Cycle`
> après le refactor : source unique `WinchBothIntent`, suppression de la couche `ST_fbCycle_*CmdDemand`,
> câblage des permis assistants. Il ne valide ni le GRAFCET métier ni le déplacement des assistants
> Dive/Extraction (décision séparée, voir § DiveSearch / Extraction).

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

## 📦 Sortie publique

```iecst
VAR_OUTPUT
    Data : ST_ModesCycleInterPrg;
END_VAR
```

```iecst
TYPE ST_ModesCycleInterPrg :
STRUCT
    Auth            : ST_fbModes_Autorisations;   // Bus d'autorisations machine (FB_Modes)
    WinchBothIntent : ST_WinchBothIntent;         // 🎮 Intention both continue opérateur (source unique PRG_03, TOUS modes)
    ReqProgram      : ST_ProgramRequest;          // Demandes programme vers PRG_04 / PRG_05
    SequenceState   : ST_SequencePublicState;     // État public de la séquence
    ModesFault      : ST_Fault;                   // 🚨 Défauts d'arbitrage de mode (consommé PRG_07 → IHM)
END_STRUCT
END_TYPE
```

> **`WinchBothIntent`** est un champ direct de `ST_ModesCycleInterPrg` (source unique, publié
> inconditionnellement, TOUS modes) — **plus** dans `ReqProgram`. Il est produit par `PRG_03`
> (qualification homme-mort + joystick/boutons) et consommé par `PRG_04` et l'arbitrage treuil.
> `ModesFault` publie les refus de l'arbitre de mode (refus Semi-Auto, changement de mode refusé).

### `ProgramRequest`

Le contrat est une **demande**, pas une commande effective :

```iecst
TYPE ST_ProgramRequest :
STRUCT
    ReqWinchM1            : ST_ProgramWinchRequest;
    ReqWinchM2            : ST_ProgramWinchRequest;
    ReqTranslation        : ST_ProgramTranslationRequest;
    ReqBucket             : ST_ProgramBucketRequest;
END_STRUCT
END_TYPE
```

> L'intention couplée continue opérateur n'est **plus** dans `ReqProgram` : elle vit dans
> `ST_ModesCycleInterPrg.WinchBothIntent` (source unique, voir ci-dessus).

### `WinchBothIntent`

Intention de mouvement both (2 treuils ensemble, homme-mort / boutons), produite
inconditionnellement par `PRG_03` vers `PRG_04` et l'arbitrage (tous modes). Source **unique**
de la décision both.

```iecst
TYPE ST_WinchBothIntent :
STRUCT
    Active    : BOOL; // Intention both active (homme-mort qualifié + Select=0 OU boutons BothUp/BothDown)
    Direction : INT;  // Sens d'intention (-1: Descending, 0: Neutre, +1: Ascending)
END_STRUCT
END_TYPE
```

Types exacts, en conservant le `%` actuel :

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
    ReqOpen                     : BOOL; // Demande ouverture benne
    ReqClose                    : BOOL; // Demande fermeture benne
    ReqKoboldMeasureEnable      : BOOL; // Demande activation mesure/contacteur Kobold
    DescendPermitDiveBucketOpen : BOOL; // Autorisation de descente conditionnée benne ouverte (DiveSearch)
    ExtractionControlActive     : BOOL; // Plafond palier 1 pendant la montée contrôlée
    AscentPermit                : BOOL; // Autorisation de remontée assistée (ExtractionAssist)
    MinStepDown                 : INT;  // Palier plancher de descente imposé pendant la plongée (FB_DiveSearch, 0 = aucun)
END_STRUCT
END_TYPE
```

> **Permis assistants** : `DescendPermitDiveBucketOpen`, `AscentPermit`, `MinStepDown` et
> `ReqKoboldMeasureEnable` sont produits par les assistants `FB_DiveSearch` / `FB_ExtractionAssist`
> (instanciés dans `PRG_03`) et publiés via `ReqBucket` — consommés par `PRG_04` (§5/§5ter) et `PRG_06`
> (contacteur Kobold). En SEMI_AUTO, `FB_Cycle` fournit ces champs à leurs valeurs neutres
> (`DescendPermitDiveBucketOpen=TRUE`, `ExtractionControlActive=FALSE`, `AscentPermit=FALSE`,
> `MinStepDown=0`).

| Sous-demande | Champs | Interdits |
|---|---|---|
| Winch M1/M2 | `ReqStartStop`, `ReqDirection`, `SpeedTgtPct` | `Permit`, `SafeStop`, relais, frein |
| Translation | `ReqStart`, `PositionTgt` | mot commande variateur, interlock final |
| Bucket | `ReqOpen`, `ReqClose`, `ReqKoboldMeasureEnable`, `DescendPermitDiveBucketOpen`, `ExtractionControlActive`, `AscentPermit`, `MinStepDown` | sortie contacteur physique directe |

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
    OperatorActionId    : WORD;
    OperatorAction      : STRING(120);
    ExpectedAxis        : E_OperatorAxis;
    ExpectedDirection   : INT;
    WaitingForOperator  : BOOL;
    WaitingForProcess  : BOOL;
    RequestActive       : BOOL;
    StepStr             : STRING(80);
    SpeedMismatchMps    : REAL;
    SpeedMismatchActive : BOOL;
    SpeedMismatchConfirmed : BOOL;
    // États assistants de dragage (centralisés PRG_03)
    DiveReady                   : BOOL;
    DiveBusy                    : BOOL;
    DiveDone                    : BOOL;
    DiveError                   : BOOL;
    DiveErrorId                 : WORD;
    DiveState                   : E_DiveSearchState;
    DiveStepAtFault             : E_DiveSearchState;
    BottomTouchConfirmed        : BOOL;
    ExtractionReady             : BOOL;
    ExtractionBusy              : BOOL;
    ExtractionDone              : BOOL;
    ExtractionError             : BOOL;
    ExtractionErrorId           : WORD;
    ExtractionState             : E_ExtractionAssistState;
    ExtractionStepAtFault       : E_ExtractionAssistState;
    DumpAtTremieArmed           : BOOL;
    DumpAtTremieAssistActive    : BOOL;
    DumpAtTremieAtTremie        : BOOL;
    DumpAtTremieBucketOpenArmed : BOOL;
    DumpAtTremieDescentLocked   : BOOL;
    BypassDiveActive            : BOOL;
    BypassKoboldBottomTouched   : BOOL;
END_STRUCT
END_TYPE
```

Les textes IHM restent une projection `PRG_07`; le bus expose des identifiants stables et des faits,
pas une multiplication de chaînes.

**Précondition :** ces champs viennent des sorties publiques d'un `FB_Cycle` au profil AF‑03
(`Ready`, `Lifecycle`, `Fault`, `CycleStep`, `CycleStepAtError`, `OperatorActionId`,
`OperatorAction`, `ExpectedAxis`, `ExpectedDirection`, `WaitingForOperator`, `WaitingForProcess`,
`RequestActive`, `SpeedMismatch*`) et des assistants `FB_DiveSearch` / `FB_ExtractionAssist`
(états Dive/Extraction, DumpAtTremie, Bypass). `PRG_03` ne reconstitue pas ces faits par logique
métier locale.

## 🔄 Ordre intra-PRG

1. appeler `FB_Modes` ;
2. publier `Data.Auth := instModes.Auth` et `Data.ModesFault := instModes.Fault` ;
3. qualifier l'intention both opérateur et publier `Data.WinchBothIntent` (inconditionnel, TOUS modes) ;
4. appeler les séquences (`FB_Cycle`, `FB_DiveSearch`, `FB_ExtractionAssist`) avec `Data.Auth` courant
   et retours procédé N‑1 ;
5. recopier leurs demandes dans `Data.ReqProgram` — `FB_Cycle` produit **directement** les types de
   contrat inter-PRG (`WinchM1Cmd`, `WinchM2Cmd`, `TranslationCmd`, `BucketCmd` de type
   `ST_Program*Request`) : plus de couche `ST_fbCycle_*CmdDemand` ni de re-mapping champ-à-champ (NC-090) ;
6. recopier lifecycle, étape et attente dans `Data.SequenceState` ;
7. neutraliser toutes les demandes si mode/sequence non actifs.

## ⚖️ Arbitrage aval

`PRG_04/05` reçoivent en parallèle :

- le geste courant `PRG_02.Data.Joystick` ;
- `PRG_03.Data.Auth` ;
- `PRG_03.Data.WinchBothIntent` (intention both continue opérateur, source unique) ;
- `PRG_03.Data.ReqProgram`.

Ils choisissent la source selon le mode, vérifient deadman/axe/sens attendu, appliquent interlocks et
safety, puis publient les demandes finales et la raison de refus. En manuel, la demande programme
peut rester entièrement neutre.

## 🌊 DiveSearch / Extraction — décision séparée

Les assistants `FB_DiveSearch` et `FB_ExtractionAssist` sont **instanciés dans `PRG_03`** et leurs
sorties (permis, contacteur Kobold, états) sont publiées via `Data.ReqProgram.ReqBucket` et
`Data.SequenceState`. Leur migration fonctionnelle complète (propriétaire, cas maintenance,
amendment AF‑02/AF‑04/AF‑10) reste une décision séparée, hors périmètre de ce contrat d'interface.

## 🛡️ Conservation fonctionnelle PRG_03

- mêmes modes, priorités et inhibitions avant toute évolution fonctionnelle ;
- mêmes demandes cycle pendant le seul remappage d'interface ;
- aucune correction opportuniste de X1/X11 ou des vitesses ;
- demandes neutralisées hors mode actif ;
- aucun accès direct à une instance d'un autre PRG ;
- `instCycleSemiAuto` est privé (zéro consommateur aval) : les demandes transitent par
  `Data.ReqProgram` (types `ST_Program*Request` produits directement par `FB_Cycle`) ;
- intention both opérateur publiée par `Data.WinchBothIntent` (source unique, TOUS modes) ;
- permis assistants (`DescendPermitDiveBucketOpen`, `AscentPermit`, `MinStepDown`,
  `ReqKoboldMeasureEnable`) produits par `FB_DiveSearch` / `FB_ExtractionAssist` et publiés via
  `Data.ReqProgram.ReqBucket` ;
- retours procédé N‑1 explicitement nommés ;
- arrêt courant sur neutre/deadman/safety réalisé en `PRG_04/05`, pas au scan suivant.

## ✅ Critères de gel du contrat

1. `Data.Auth`, `Data.WinchBothIntent`, `Data.ReqProgram`, `Data.SequenceState`, `Data.ModesFault`
   ont types, unités, polarités et invalidité ;
2. l'ordre `Modes → Auth courant → WinchBothIntent → Cycle → publication` est testé ;
3. `FB_Cycle` produit directement les `ST_Program*Request` (plus de `ST_fbCycle_*CmdDemand`) ;
4. chaque consommateur actuel de `instCycleSemiAuto` a un chemin public équivalent ;
5. `instCycleSemiAuto` est privé après `rg` zéro consommateur ;
6. l'interface ne contient ni sécurité axe ni commande physique ;
7. les scénarios manuel existants sont identiques avant/après ;
8. les scénarios semi-auto vérifient geste neutre, sens opposé, perte deadman et sécurité locale ;
9. G200, palier C, tous gates, bundle frais et tests ST2C/StruCpp ciblés sont verts.
