# Troubleshooting — AX15/AX18 simulation — 2026-10-15

Statut : EN COURS · Situation : SIMULATION BANC

## Contexte figé

- Lot joystick T418 chargé ; l'opérateur simulé fonctionne sans lancement parasite de homing.
- Référencement réalisé en HX0.
- Symptôme rapporté : à la trémie, AX15 passe à AX18 alors que la benne paraît non ouverte ; au mouvement suivant vers P1, `Cycle ErrorID:08`.

## Faits établis par analyse statique

| Fait | Preuve source | Force |
|---|---|---|
| AX15B ne passe à AX18 que si `DeadmanArmed AND JoystickPush AND Benne_Done AND Benne_IsOpen`. | `FB_CycleSemiAuto.st:1573-1575` | verte — logique source |
| ErrorID 08 est la cause `NOT WinchesAtTopWindow` exclusivement pendant AX2 vers P1. | `FB_CycleSemiAuto.st:508-515` | verte — logique source |
| La fenêtre haute attend une limite haute M1/M2 ou une position M1 dans la tolérance de la cote de configuration, et un état de benne qualifié. | `PRG_03_Modes_Cycle.st:172-176` | verte — logique source |

## Snapshot 2026-10-15 03:37:56

| Hypothèse | Variable de décision | Valeur lue | Verdict |
|---|---|
| La simulation publie prématurément la benne ouverte/terminée. | `K_BenneOuvertureFermeture.Idx101_BucketIsOpen`, `Idx401_BucketBusy`, `Idx402_BucketDone` | `FALSE`, `FALSE`, `TRUE`; delta M2-M1 = `1.02270508 m` | Confirmée : `Done` reste vrai alors que la benne est intermédiaire. |
| La fenêtre haute est perdue avant AX2 (limite ou position M1/configuration). | `I_LevageUnitaireM1.Safety_300.Idx321_CfgTopLimitM`, `Idx322_CablePosM`, `Idx323_TopLimitReached` | `7.5 m`, `7.85864258 m`, `TRUE` | Écart permanent écarté au moment du snapshot; un snapshot après défaut ne restitue pas le booléen historique `WinchesAtTopWindow`. |
| Le cycle a bien mémorisé la cause 08 à AX2. | `G_CycleSemiAuto.Idx205_ErrorId`, `Idx208_StepAtError` | `0`, `AX2_TRANSLATE_P1` | Le défaut a été acquitté avant le snapshot, mais AX2 est bien l'étape mémorisée au défaut. |

## AX15 vers AX18 — comportement de référence

Configuration par défaut : `OffsetOpenM = 0.0 m`, `CoherenceLimitM = 1.0 m`,
`OpenAnticipationM = 1.3 m` (`GVL_PERSISTENT.st`).

`FB_Bucket` termine l'ouverture à `Delta <= OffsetOpenM + OpenAnticipationM`, force alors
`IsOpen := TRUE` et `Done := TRUE` dans le même scan. `FB_CycleSemiAuto` peut donc entrer
en AX18 dans ce scan. Au scan suivant, la classification physique recalcule `IsOpen` sur
la bande plus stricte `ABS(Delta - OffsetOpenM) <= CoherenceLimitM`.

Le snapshot donne `Delta = 1.02270508 m` : il est inférieur à la frontière d'anticipation
`1.3 m`, mais supérieur à la frontière d'état ouvert `1.0 m`. C'est exactement une benne
intermédiaire terminée, compatible avec le saut AX15/AX18 observé.

Correction de compréhension, apportée par l'exploitant le 2026-10-15 : sur la machine réelle,
l'ouverture ne franchit pas immédiatement AX15 vers AX18. Le passage quasi immédiat observé
au banc est donc un écart de simulation. Le code métier reste une référence inchangée; toute
correction doit rester dans `FB_SimBench` et ses stimuli, sans modifier le cycle, `FB_Bucket`
ni le joystick réel.

## Contre-épreuve benne ouverte — snapshot 03:54:13

La contre-épreuve écarte l'état de benne comme cause du défaut 08 :

| Valeur | Snapshot 03:37:56 | Snapshot 03:54:13 |
|---|---:|---:|
| `BucketIsOpen` | FALSE | TRUE |
| `DeltaPosition_M` | 1.02270508 m | 0.9484863 m |
| M1 `CablePosM` | 7.85864258 m | 7.85864258 m |
| M1 `CfgTopLimitM` | 7.5 m | 7.5 m |
| `StepAtError` | AX2 | AX2 |

Dans la seconde capture, `BucketIsOpen=TRUE` et `ABS(Delta)=0.9484863 m <= 1.0 m` : la
benne est bien dans sa bande ouverte. M1 et M2 sont également au-dessus de la limite haute
publiée. Le défaut 08 ne dépend donc ni de l'ouverture de la benne, ni d'un écart permanent
des cotes après retour au repos.

Le snapshot est pris après disparition/acquittement du défaut (`ErrorId=0`, `FaultLatched=FALSE`).
Il ne publie pas le booléen effectif `CycleWinchesAtTopOk` consommé par AX2; la cause du
transitoire ne peut donc pas être affirmée sans une acquisition pendant le défaut actif.

## Trace `Suivi_93_SIMU_Cycle_20261015.trace`

Conversion locale sans modification de la trace source : 296 échantillons, de 98 ms à
31 403 ms. La trace contient AX14 (14), AX15 (15), puis AX18 (18), et `Fault.Error=0`
sur toute la fenêtre. Aucun échantillon AX2 n'est présent; le geste vers P1 n'est pas
capturé (en AX18, `JoyXRaw=5000`, neutre). Cette trace valide le parcours jusqu'à AX18,
mais ne permet pas d'analyser ErrorID 08.

## Journal

- 2026-10-15 : diagnostic ouvert sur rapport de recette utilisateur ; aucune modification de code.
- 2026-10-15 03:37:56 : snapshot unique lu; cause AX15/AX18 prouvée par les valeurs et les deux frontières source.
- 2026-10-15 : correction exploitant : passage AX15→AX18 quasi immédiat non conforme au réel; diagnostic limité à SimBench, aucun changement de code métier.
- 2026-10-15 03:54:13 : contre-épreuve benne ouverte; défaut AX2 reproductible, benne écartée comme cause.
- 2026-10-15 : trace Suivi_93 convertie en CSV; fenêtre insuffisante, aucune transition AX18 vers AX2.
