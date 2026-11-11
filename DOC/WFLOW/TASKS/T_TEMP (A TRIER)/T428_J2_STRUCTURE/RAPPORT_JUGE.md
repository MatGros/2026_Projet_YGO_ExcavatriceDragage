# Revue J2 T428 : table de correspondance

**Verdict global : retraits sûrs, table non validable en l'état.**
- Les 109 retraits sont justes.
- 5 ancres de sortie et les 4 permis « Safety » sont trompeurs.
- 42 doublons n'ont pas été vus, parce que le générateur ne traverse pas les structures ni les FB.
- Aucune écriture dans le dépôt. Scripts dans `...\tmp\j2\juge\`.

## Verdicts

| # | Critère | Verdict | Portée réelle |
|---|---|---|---|
| 1 | Retraits | **PASS** | **109 lignes, pas 111** : 101 + 4 + 3 + 1 |
| 2 | Panne perdue | **PASS** | Aucune panne perdue par retrait pur ; réserve au §A |
| 3 | Zones | **KO** | Voir §C |
| 4 | Consommateurs | **PASS code et gates, KO colonne `nb_traces`** | Voir §D |
| 5 | Refus d'agents | **KO sur 5 lignes, PASS sur freins** | `L.Idx101..105` à fusionner |
| 6 | Fiche et doublons | **Fiche PASS, doublons KO** | 42 retraits manquants |

### Critère 1
- 86 lignes ont une expression résolue identique (`c1.py`, liaison FB `PRG_07:907-987` traversée).
- 23 lignes vérifiées à la main :
  - `Q/R/S` contre `T` (13) : égalité, `PRG_07:878-897`.
  - `Idx328` contre `Idx305` (2) : égalité inconditionnelle, `PRG_07:500`.
  - `BrakeApplied` (2) : négation pure, vue 175 et 251.
  - `G.Idx104` (1) : égalité, `PRG_07:644`.
  - `P.SpeedContactor1Active` (1) : constante, vue 730.
  - R5 (4) : jamais écrites.
- Aucune variable retirée n'a d'affectation multiple ou conditionnelle.
- Aucune ancre n'est absente ou elle-même retirée.

### Critère 2 : points demandés, tous PASS
AU/Power, `A.Idx304`, permis `Q/R/S` contre `T`, positions `Idx102/322`, bypass communs, `Idx216`, `G.Idx102` (contacteur seul, vue 742).

`Idx404` et `BrakeCmd` sont égaux, mais voir §A.

## A. Faits graves : mauvaises ancres

| Fait observé | Preuve | Mécanisme |
|---|---|---|
| `I/J.Idx505` n'est pas la sortie frein physique | Lit `State.BrakeCmd`, soit `InterlockM1.BrakeCmd` à N-1 (`FB_WinchStateProjection:108`). La vraie sortie vient de `PRG_06:261,307,330,375` | Forçage MAINT_N2 : frein desserré alors que `Idx505=FALSE`. Regate §2ter : l'écart existe aussi en sens inverse |
| `L.Idx501` est une demande | `PRG_05:744`, commentaire vue 690-693. Réel : `PRG_06:458` | Hard stop ou barrière : mot affiché ≠ 0, mot réel = 0 |
| `L.Idx503` est une demande | `PRG_05:739`. Réel : `PRG_06:453` | Même mécanisme |
| `M3_TremieHardStopActive` absent de la vue | `PRG_06:431,441-449` ; 0 occurrence dans `J_SUPERVISION` | M3 coupée sans variable visible |
| `T.M1/M2Safety*Permit` ne sont pas Safety | `PRG_07:874`, `FB_WinchStateProjection:232`, `PRG_04:1113`. Le vrai permis `SafetyPermitM1_Ascent` (`PRG_04:1067`) n'est pas publié | Un permis Process absent fait aussi tomber le « Safety » : fausse accusation. 94/94 snapshots égaux à Effective |

## B. Lignes à changer

### Corrections

| Chemin | Actuel | Proposé | Preuve |
|---|---|---|---|
| `I/J.Outputs_500.Idx505` | GARDER ét9 | CABLER_J3 sur `Outputs.M1BrakeCmd` / `M2BrakeCmd` | `PRG_06:393,402` |
| `I/J.Control_400.Idx404` | RETRAIT_COPIE | GARDER ét8 | `FB_WinchStateProjection:108,175` |
| `N/O.Cmd_BrakeRelease` | RETRAIT vers Idx505 | RETRAIT vers Idx404 | Vue 225, 571, 304, 633 |
| `L.Outputs_500.Idx501` | GARDER ét9 | CABLER_J3 sur `M3_CommandWord` | `PRG_06:458` |
| `L.Control_400.Idx403` | RETRAIT_COPIE | GARDER ét5 | `PRG_05:744` |
| `L.Outputs_500.Idx503` | GARDER ét9 | CABLER_J3 sur `Outputs.TranslationBrakeCmd` | `PRG_06:462` |
| `P.Cmd_BrakeRelease` | RETRAIT_COPIE | GARDER ét5 | `PRG_05:739` |
| Nouvelle : `M3_TremieHardStopActive` | absente | AJOUT_J3 ét8 | `PRG_06:431` |
| `T.M1/M2Safety{Ascent,Descend}Permit` (4) | GARDER | A_VALIDER : câbler `SafetyPermitMx_*` | `PRG_04:1067-1068` |

Le chemin de publication de `M3_CommandWord` vers la vue reste à définir.

### Retraits manquants (42)

| Chemin | Proposé | Ancre | Preuve |
|---|---|---|---|
| `L.Idx101..105` (5) | RETRAIT_COPIE | `B_Inputs.Translation.M3_Pos*_DI` | `FB_Translation_PositionDecoder:94-98`, `PRG_05:116-120,753-757` |
| `L.Idx109` | RETRAIT_COPIE | `B.Translation.M3_ThermalOK_DI` | `PRG_05:784` |
| `L.Idx108` | RETRAIT_NEGATION | `B.Translation.M3_BrakeIsOpen_DI` | `PRG_05:742` |
| `I/J.Idx408` (2) | RETRAIT_COPIE | `B.Winch.Mx_BrakeIsOpen_DI` | `FB_WinchStateProjection:109,176` |
| `I/J.Idx306`, `Idx309` (4) | RETRAIT_COPIE | `T.EffectivePermitMx_*` | `FB_WinchStateProjection:232-233,259-260` |
| `Q/R/S.SafeStopActive` (3) | RETRAIT_COPIE | `I/J/L.Idx302` | `PRG_04:1842`, `FB_WinchStateProjection:231`, `PRG_05:805,832` |
| `Q/R/S.PowerCutOffActive` (3) | RETRAIT_COPIE | `I/J/L.Idx303` | `PRG_04:1849,1895`, `PRG_05:806,835` |
| `Q/R.StepNumber` (2) | RETRAIT_COPIE | `I/J.Idx402` | `PRG_04:1854,1900` |
| `G.Idx307/308` (2) | RETRAIT_COPIE, traces 11 et 12 à migrer | `I/J.Idx402` | `PRG_07` liaison, `FB_WinchStateProjection:89,156` |
| `Q/R.FinalInterlockReason` (2) | RETRAIT_COPIE | `I/J.Idx406` | `PRG_04:1853,1899` |
| `I/J.Idx403` (2) | RETRAIT_COPIE | `I/J.Idx208` | `PRG_04:547-549,1702,1938` |
| `L.Idx308` | RETRAIT_COPIE | `S.HeightInterlockBlocking` | `PRG_05:142,836` |
| `L.Idx318/319` (2) | RETRAIT_COPIE | `T.EffectivePermitM3_*` | `PRG_05:820-821,840-842` |
| `K.Idx206/207/208` (3) | RETRAIT_COPIE | `T.BucketClose/Open/MotionBlocked` | `PRG_04:1782-1783,1796`, `PRG_07:518,901-903` |
| `I.Idx211` | RETRAIT_COPIE | `T.BothActive` | `PRG_04:284,1977` |
| `A.Idx103` | RETRAIT_COPIE | `D.Step2_JoystickOperational` | Vue 137, 529 |
| `C.PowerCutOffRequest` | RETRAIT_COPIE | `C.PowerCutOffActive` | `PRG_06:539,548` |
| `PRG_06...Status.State.Step`, `Diag.Error/LastAbortStep/LastAbortCause` (4) | RETRAIT_COPIE | `C.ArmingStep/SafetyError/LastAbort*` | `PRG_06:542-543` |
| `J.Idx307` | RETRAIT_NEGATION | `B.Winch.M2_TensionedCable_DI` | Vue 275 |
| `E.TopPositionSensorActive` | RETRAIT_NEGATION | `B.Winch.M1M2_TopPositionFree_DI` | `PRG_07:419` |

### Ancres à rediriger
- `H.Idx303/304` vers `T.EffectivePermitM1/M2_Ascent`.
- `N/O.RequestedSpeedPct` vers `I/J.Idx208`.
- `J.Idx211` vers `T.BothActive`.
- `I.Idx307` vers `B.Winch.M2_TensionedCable_DI`.
- `F.TopPositionSensorActive` vers `B.Winch.M1M2_TopPositionFree_DI`.

### Doublons à garder
`Idx405/406/407/416/505` contre `PRG_06.instWinchOutputInterlockMx.*` : décalage réel d'un scan.

## C. Zones

| Chemin | Actuel | Proposé | Preuve |
|---|---|---|---|
| `I/J.Idx402` | ét8 | ét5 | `FB_WinchStateProjection:89,156` (FB_Winch, avant barrière) |
| `L.Idx401/402` | ét8 | ét5 | `PRG_05:745` pour 402 ; 401 est une inférence |
| `P.RelayFwd/RevActive` | ét9 | ét5 | Vue 726-729 |
| `PRG_06.Data.ContactorMismatch` | GENERAL.Puissance | FONCTION.Couplage | `PRG_04:712` |
| `B.Machine.TremieFull_OR_GateRaised_DI` | GENERAL.Puissance | AXE.M3 ét2 | `PRG_05:176-180` |
| `B.Winch.M2_TensionedCable_DI` | AXE.M2 ét2 | GENERAL.CapteursCommuns | Vue 196 (capteur unique) |
| `K.Idx113-117,119,120` | FONCTION.Benne | FONCTION.Referencement | `PRG_04:1789-1790` pour 113-114, reste par nom (inférence) |

Inférence, source non lue : `I/J.Idx401` et `Idx412-414` ne semblent pas appartenir à l'étape 8.

Toutes les lignes `T_`, `H_`, `K_`, `PRG_06`, `PRG_04` sont lues. Hors §C, elles sont bien placées. L'échantillon de 40 est dépassé : toutes les lignes conservées `A..G`, `I..Q`, `S`, soit plus de 400, ont été lues. Les `R_` conservées n'ont pas été relues une à une : elles sont supposées symétriques de `Q_`.

## D. Consommateurs
- **Code ST** : aucun lecteur de la GVL hors vue. La vue ne relit aucune variable retirée (448-452, 474-478, 537-539, 579, 613-620, 641, 656-663, 687, 717-724).
- **Gates** : aucun script de `TOOLS/AGENT_WORKFLOW/scripts` ne cite un nom retiré. G522 lit des `Step8` conservés.
- **`nb_traces` faux** : 0 dans la table, mais `trace_cyclehoming_debug_v1.txt` lit 5 variables retirées :
  - `E.HwIn_ContactorsReleased_DI`, `E.HwIn_BrakeIsOpen_DI`
  - `F.HwIn_ContactorsReleased_DI`, `F.HwIn_BrakeIsOpen_DI`
  - `F.TopPositionSensorActive`
- **Test à migrer** : `TOOLS/TEST_AUTO_CI/RESULTS/J_SUPERVISION/tests/test_fb_troubleshootingview.st`, 6 asserts : `H.Idx501`, `N.RelayFwdActive`, `N.SpeedContactor1Active`, `O.RelayRevActive`, `K.Idx501`, `I.Idx307`.
- **Autres fichiers à migrer** :
  - `MOCK_GVL_Troubleshooting.st` et les types `ST_Chain*`.
  - `AF_Partie-14`.
  - `PRG_T409_M3_FmuBridge_IMPLEMENTATION.st` lit `L.Idx403`.
  - `codesys_m3_roundtrip_poc.py` lit `L.Idx107`.

## E. Refus d'agents

| Proposition | Refus | Preuve |
|---|---|---|
| `L.Idx101..105` vers `B_Inputs` | **Injuste** | Passthrough pur, voir §B |
| Freins et contacteurs en étape 2 | Juste | Ordre ét9 puis retour ét10 ; `p_m1`, `p_m2`, `p_m3` |
| `F.Step4/5` vers `B_Inputs` | Juste | Lus par `AllConditionsMet`, vue 477-478 (R4) |
| Avocat, tout garder | Juste | La panne reste lisible sur l'ancre |

`p_m3` et `avocat` lus en entier. `p_m1` et `p_m2` comparés par script. Seul le début de `b_automaticien` et de `a_mainteneur` a été lu.

## F. Fiche
10 étapes suffisent. Le défaut est dans le contenu des étapes 8 et 9, pas dans leur nombre. Sur M1/M2, l'étape 9 n'expose pas les contacteurs de palier 2 et 3, faute de variable dans la vue (`PRG_06:371-374`).

## Faits, inférences, inconnues
- **Faits** : égalités par le code, avec les références ci-dessus.
- **Preuve snapshot** : 0 écart dans le même lot sur tous les doublons testés (37 paires), mais la plupart n'ont aucune paire dans le même lot. L'égalité repose donc d'abord sur le code. Écarts entre lots : 1 sur `Q.StepNumber`, 1 sur `I.Idx211`, 6 sur `J.Idx307`.
- **Inférences** : l'écart joystick 4847/4849 vient d'une lecture snapshot non atomique ; les zones marquées inférence ci-dessus.
- **Inconnues** :
  - Ordre réel de la MainTask en ligne : l'AF-02 (lignes 532 et 578) dit qu'il reste à confirmer.
  - Validité du seuil M2 : `Idx321` ne porte pas `M2_LimitShift` (`FB_WinchStateProjection:226`), à traiter en J3.
  - Comportement sur machine : aucun test exécuté.
