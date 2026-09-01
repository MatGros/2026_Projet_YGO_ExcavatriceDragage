# 🕵️ Session de Troubleshooting — Recherche de Blocage et de Panne — Treuils Both descente : frein non ouvert / aucun contacteur de puissance

> 📌 `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_TreuilsBoth_FreinNonOuvert_20260901.md`
> 📅 Date : 2026-09-01 · 🧊 Situation : [SIMULATION BANC] (SimulationEnabled=TRUE, SimSafetyActive=TRUE) · 📄 Statut : CAUSE RACINE PROUVÉE — correction P0 validée mais GELÉE (attente fin agent + état des lieux)

> ⚠️ **Base de code mouvante** : le snapshot et les lectures Watch (`CommandedDirection`,
> `DeadTimeArmed`, `LastDirection`, `M1DriveRequest.Direction`) proviennent du **runtime AVANT
> refactor**. Le working tree en cours (agent) a déjà migré `FB_WinchDirectionInterlock` vers des
> booléens explicites : `WinchRequest.ReqAscent` / `ReqDescend` / `RunRequest`,
> `DirectionInterlock.CommandedAscent` / `CommandedDescend` / `RequestConflict`. Les numéros de
> ligne et noms de champs cités plus bas sont **pré-refactor** — à réconcilier avec le code final
> lors de l'état des lieux. Le **mécanisme** (inversion en attente + palier mini forcé) reste valide.

## 1. 🧊 Contexte figé (horodaté)

### Texte de contexte
- Mode `MAINT_N1`, joystick sélectionné, `JoystickCommOk=TRUE`, deadman armé.
- Commande **descente couplée M1+M2** ("both"). IHM affiche « déplacement en cours » + « joystick armed ».
- **Aucun contacteur de puissance moteur enclenché** (relais sens + contacteurs vitesse tous à 0).
- `PowerContactorEngaged=TRUE`, aucun défaut actif (tous `ErrorMeca*`, `SafetyError`, `ThermalFault`, `SafeStop` = FALSE).
- Position câble M1=M2 ≈ **7.509 m**, juste au-dessus du FDC logiciel haut `CfgTopLimitM = 7.5 m`.
- Snapshot : `Snapshot_Troubleshooting_20260901_091340.csv` (499/499 lues).

### Variables & valeurs (extrait décisif)
| Élément | Variable complète | Valeur | Horodatage |
|---|---|---|---|
| Permis descente M1 | `I_LevageUnitaireM1.Safety_300.Idx309_DescendPermitEffective` | **TRUE** | 09:13:40 |
| Permis descente M2 | `J_LevageUnitaireM2.Safety_300.Idx309_DescendPermitEffective` | **TRUE** | 09:13:40 |
| Permis montée M1/M2 (bloqué FDC haut) | `Idx306_AscentPermitEffective` | FALSE (attendu) | 09:13:40 |
| FDC haut atteint | `Idx323_TopLimitReached` / `Idx324_AscentBlockedByTopLimit` | TRUE / TRUE (bloque **montée** uniquement) | 09:13:40 |
| Palier calculé M1 (FB_Winch) | `I_LevageUnitaireM1.Control_400.Idx402_SpeedStepCalculated` (`WinchM1.State.StepNumber`) | **INT#1** | 09:13:40 |
| Relais sens montée M1 | `Idx501_CmdRelayAscent_DQ` (`WinchM1.State.RelayFwd`) | **FALSE** | 09:13:40 |
| Relais sens descente M1 | `Idx502_CmdRelayDescent_DQ` (`WinchM1.State.RelayRev`) | **FALSE** | 09:13:40 |
| Ordre frein M1 (barrière finale) | `Idx404_BrakeReleaseAuthorized` (`InterlockM1.BrakeCmd`) | **FALSE** | 09:13:40 |
| État barrière finale M1 | `Idx405_FinalInterlockState` | `READY` | 09:13:40 |
| Direction arbitrée M1 | `I_LevageUnitaireM1.Demandes_200.Idx209_ArbitratedDirection` (`M1LogicRequestDirection`) | **INT#-1** | 09:13:40 |
| Requête couplée both active / sens | `Idx211_CoupledUserRequestActive` / `Idx210_CoupledUserRequestDirection` | TRUE / **-1** | 09:13:40 |
| Vitesse arbitrée M1 | `Idx208_ArbitratedSpeed_Pct` | REAL#20 | 09:13:40 |
| **Joystick Y brut** | `D_Joystick.RawY` (`HwIn.Operator.JoyYRaw_ANA2`) | **INT#0** | 09:13:40 |
| Joystick Y déflexion | `D_Joystick.DeflectionY_Pct` (`JoystickHMI.State.AxisCmdY.Deflection`) | **REAL#-100** | 09:13:40 |
| Joystick neutre Y | `D_Joystick.NeutralYAct` | **FALSE** | 09:13:40 |
| Joystick neutre acquis | `D_Joystick.Step4_NeutralAcquired` (`JoystickHMI.State.AtNeutral`) | **FALSE** | 09:13:40 |
| Joystick armé | `D_Joystick.DeadmanArmed` / `AllConditionsMet` | TRUE / TRUE | 09:13:40 |
| SafeStop M1 / PowerCutOff M1 | `Q_TraceWinchM1.SafeStopActive` / `.PowerCutOffActive` | FALSE / FALSE | 09:13:40 |
| Erreur sens opposé / pas de mvt M1 | `Idx319_ErrorOppositeDir` / `Idx320_ErrorNoMovement` | FALSE / FALSE | 09:13:40 |

> ⚠️ M2 : valeurs symétriques identiques (mêmes verdicts).

## 2. 🎯 Symptôme

Descente couplée M1+M2 commandée, permis + arbitrage OK, **le frein ne s'ouvre pas et aucun contacteur de sens/puissance ne s'enclenche** — permanent tant que la commande descente est maintenue. Ce n'est **pas** dû au FDC logiciel haut (il ne bloque que la montée). Un reset défaut "débloque" temporairement (rapporté).

## 3. 🧩 Indices / historique

- Changements récents : chantier permis directionnels uniques (commits `ec99f20f`, `b5aa33a6`) + refactor barrière finale `FB_WinchOutputInterlock`.
- Déjà essayé : reset défaut → repart (indice fort : la cause est un **latch acquittable au Reset**).
- Conditions : position en zone de ralentissement haut (`InTopSlowdownZone=TRUE`), joystick Y **jamais passé par le neutre** depuis le début de session (raw=0).
- Alarmes : aucune.

## 3bis. 🔬 Valeurs live complémentaires (2026-09-01, 2e lecture — Watch)

| Variable | Valeur | Lecture |
|---|---|---|
| `instWinchM1.DirectionInterlock.CommandedDirection` | **INT#0** | jamais adopté à -1 |
| `instWinchM1.DirectionInterlock.DirectionChangePending` | **TRUE** | changement de sens en attente |
| `instWinchM1.DirectionInterlock.DeadTimeArmed` | **FALSE** | ⛔ invalide l'hypothèse "latch DeadTimeArmed" |
| `instWinchM1.DirectionInterlock.DirectionChangeDelay.ET` | **0 ms** | ⚠️ le timer de temps mort **ne compte pas** → `Enable = FALSE` |
| `instWinchM1.DirectionInterlock.LastDirection` | **INT#1** | dernière adoption = **montée** (position haute) → reprise en sens **opposé** |
| `M1DriveRequest.Direction` | INT#-1 | descente demandée |
| `M1DriveRequest.StartStop` | TRUE | commande maintenue |
| `M1DriveRequest.SpeedStepReq` | INT#1 | palier 1 |
| `instWinchM1.RampTargetStep` | **INT#1** | ⚠️ non nul **malgré** `DirectionChangePending=TRUE` |

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue | Verdict |
|---|---|---|---|---|---|
| 1 | FDC logiciel haut bloque la descente | `Idx309_DescendPermitEffective` | TRUE (AF-10 : FDC haut → bloque montée seule) | TRUE | ✅ écarté |
| 2 | Permis descente refusé en amont | `M1/M2DescendPermitUse` → `Idx309` | TRUE | TRUE | ✅ écarté |
| 3 | Défaut / SafeStop / PowerCutOff actif | `SafeStopActive`, `PowerCutOffActive`, `Fault.Error` | tous FALSE | tous FALSE | ✅ écarté |
| 4 | Puissance non réarmée | `Idx302_PowerContactorEngaged` | TRUE | TRUE | ✅ écarté |
| 5 | Barrière finale `FB_WinchOutputInterlock` neutralise | `Idx405_FinalInterlockState` / `Reason` | READY / NONE si pas de blocage propre | READY / NONE | ✅ écarté (ne bloque pas de son fait) |
| 6 | Arbitrage ne transmet pas la demande | `Idx209_ArbitratedDirection`, `Idx208_Speed`, `Idx402_Step` | -1 / 20 / 1 | -1 / 20 / 1 | ✅ écarté (demande présente) |
| 7 | **FB_Winch ne pose pas `RelayRev` alors que `StepNumber>0`** | `WinchM1.State.RelayRev` avec `StepNumber=1` | TRUE (FB_Winch §5 : `StepNumber>0 AND CommandedDirection=-1`) | FALSE | ❌ **BLOCAGE** |
| 8 | `CommandedDirection` reste ≠ -1, `DirectionChangePending=TRUE` | `DirectionInterlock.CommandedDirection` / `DirectionChangePending` | -1 après temps mort | **0 / TRUE** | ❌ **BLOCAGE confirmé** |
| 9 | Latch `DeadTimeArmed` jamais purgé | `DirectionInterlock.DeadTimeArmed` | — | **FALSE** | ✅ **écarté** (hypothèse abandonnée) |
| 10 | Temps mort `DirectionChangeDelay` ne compte pas → `Enable=FALSE` | `DirectionChangeDelay.ET` ; `Enable := (StepNumber=0) AND ContactorsAllOff` | ET compte si treuil arrêté | **ET=0** ; `ContactorsReleased_DI=TRUE` ⇒ `StepNumber ≠ 0` | ❌ **maillon** |
| 11 | **`StepNumber` forcé >0 par le plancher descente `MinStepDown`, malgré `DirectionChangePending`** | `PRG_04:927 CommonMinStepDown := MAX(1,…)` → `FB_Winch:244-246` | plancher 0 hors plongée (`MinStepDown : INT := 0`) | **`MAX(1,…)` ⇒ toujours ≥ 1** ; floor appliqué en descente **sans garde** `DirectionChangePending` | ❌ **CAUSE RACINE** |
| 12 | Reprise sens opposé depuis neutre sans repli timer | `FB_WinchDirectionInterlock` §80-88 | adoption via `DirectionChangeDelay.Q` | Q dépend de `Enable` (bloqué par #11) ; seule purge = `Reset` (→ `LastDirection:=0`) | ❌ **amplificateur** — explique « Reset débloque » |
| 13 | Joystick Y : entrée analogique morte lue comme -100 % | `D_Joystick.RawY` vs `DeflectionY_Pct` | raw 0 → défaut fil coupé | raw 0 → **-100 %**, aucun défaut | ❌ **bug secondaire indépendant** |

## 5. 📊 Arbre vertical (flux de données) — RÉVISÉ après 2e lecture

```text
Commande descente couplée : M1DriveRequest.Direction = -1, StartStop = TRUE, SpeedStepReq = 1
LastDirection = 1  (dernier mouvement = MONTÉE vers position haute)  → reprise en sens OPPOSÉ
  ▼
PRG_04:927  CommonMinStepDown := MAX(1, ReqBucket.MinStepDown)  →  TOUJOURS ≥ 1   ❌ (attendu 0 hors plongée)
  │         M1DriveRequest.MinStepDown = 1
  ▼
FB_Winch §5 :
   ligne 205 : DirectionChangePending=TRUE  →  RampTargetStep := 0        ✅ (garde correcte)
   ligne 244 : StartStop AND Direction=-1 AND MinStepDown>0 AND NOT SafeStop
               →  RequestedStep := MinStepDown = 1   ❌ CONTOURNE la garde ligne 205
  ▼
StepShaper  →  StepNumber = 1
  ▼
FB_WinchDirectionInterlock.Enable := (StepNumber = 0) AND ContactorsAllOff
   StepNumber = 1  →  Enable = FALSE
  ▼
DirectionChangeDelay(IN := Enable AND …)  →  IN = FALSE  →  ET = 0 ms   ❌ le temps mort ne s'écoule jamais
  ▼
adoption §80-88 : CommandedDirection=0 ET ReqDirection=-1 ET (LastDirection=1 ≠ -1)
   →  DirectionChangePending := TRUE   ;  aucune branche n'adopte -1
      (ligne 75 `ELSIF DirectionChangeDelay.Q` inatteignable : Q reste FALSE)
  ▼
CommandedDirection : INT = 0   (verrouillé — seule sortie : Reset → LastDirection:=0 → adoption immédiate §83)
  ▼
FB_Winch relais §269-278 : `StepNumber>0 AND CommandedDirection = -1` → FAUX
  ▼
RelayFwd = FALSE , RelayRev = FALSE   ❌
  ▼
FB_WinchOutputInterlock : RequestedRelayFwd/Rev = FALSE
   MotorRequest = (Step>0) AND (Fwd XOR Rev) = FALSE
  ▼
BrakeCmd = RelayFwd OR RelayRev = FALSE   ❌  frein fermé, aucun contacteur, machine immobile
                                              (IHM « déplacement en cours » = StepNumber=1 sans sens)
```

**Résumé une ligne** : `[MinStepDown=MAX(1,…)=1] → [RequestedStep floor=1] → [StepNumber=1] → [Interlock.Enable=0] → [DirChangeDelay.ET=0] → [CommandedDirection=0] → [RelayRev=0] → [BrakeCmd=0] ❌`

> 🔁 **Asymétrie** : le plancher §244 ne concerne que la **descente** (`Direction = -1`). En montée, `RequestedStep` suit `RampTargetStep` qui respecte `DirectionChangePending` → pas de blocage. D'où le « départ asymétrique » (fiche sœur `TROUBLESHOOTING_TreuilsBoth_DepartAsymetrique_20260901.md`).
> 🔓 **« Reset débloque »** : `FB_WinchDirectionInterlock` §37-43 remet `LastDirection := 0` → au scan suivant §83 `(LastDirection = 0)` → `CommandedDirection := ReqDirection` **immédiatement**, sans passer par le temps mort gelé.
> 🕹️ **Joystick Y** : `RawY = 0` (fil coupé/étalonnage) traduit en `-100 %` sans défaut — **bug indépendant**, aggrave (jamais de retour neutre) mais n'est pas la cause : le blocage se produirait aussi avec un vrai appui descente maintenu.

## 6. 📊 Données / interactions

### Lectures & essais
- Snapshot 09:13:40 : chaîne permis/arbitrage 100 % verte jusqu'à `RelayRev`, qui reste FALSE avec `StepNumber=1`.
- Reset défaut → mouvement repart : cohérent avec purge de `DeadTimeArmed` (FB_WinchDirectionInterlock §Front Reset, lignes 37-43) et des latches barrière finale.

### Lecture live 2 (2026-09-01, Watch) — confirme la cause
`CommandedDirection=0`, `DirectionChangePending=TRUE`, `DeadTimeArmed=FALSE`,
`DirectionChangeDelay.ET=0ms`, `LastDirection=1`, `M1DriveRequest.Direction=-1`,
`StartStop=TRUE`, `SpeedStepReq=1`, `RampTargetStep=1`.
→ `DeadTimeArmed=FALSE` : hypothèse « latch DeadTimeArmed » **abandonnée**.
→ `ET=0` avec `ContactorsReleased_DI=TRUE` ⟹ `StepNumber ≠ 0` ⟹ `Interlock.Enable=FALSE` ⟹ temps mort gelé.
→ `RampTargetStep=1` malgré pending : injecté par le plancher `MinStepDown` (`FB_Winch:244`).

### Trace amont du plancher `MinStepDown`
`FB_DiveSearch:280-284` — `MinStepDown := CfgDiveFloorStep (≈4)` UNIQUEMENT si `DescentActive`
ET état ∈ {SEARCHING_IMMERSION, SEARCHING_BOTTOM} ; sinon `0`.
`PRG_03:365` relaie tel quel ; `PRG_03:450` (défaut) = `0`.
➡️ **L'amont est correct** : `0` hors diving, `4` en recherche de fond.
Seul `PRG_04:927` `MAX(1, …)` casse ça (→ `1` en permanence hors diving).

## 7. 🏁 Conclusion

- **Cause racine (confirmée par lecture)** : `PRG_04_Treuils_Benne.st:927`
  `CommonMinStepDown := MAX(1, PRG_03_Modes_Cycle.Data.ReqProgram.ReqBucket.MinStepDown);`
  Le `MAX(1, …)` rend le **plancher de palier descente inconditionnel** (toujours ≥ 1), alors que
  le type prévoit `MinStepDown : INT := 0` = « aucun plancher » hors plongée Kobold.
  Conséquence dans `FB_Winch.st:244-246` : à **toute** commande de descente maintenue, `RequestedStep`
  est forcé à 1 **même quand `DirectionChangePending = TRUE`** — ce qui contourne la garde
  `RampTargetStep := 0` de la ligne 205. `StepNumber` monte à 1.
- **Verrou secondaire** : `FB_WinchDirectionInterlock` — `StepNumber ≠ 0` force `Enable = FALSE`,
  ce qui **gèle `DirectionChangeDelay`** (ET = 0). Or, pour une reprise en sens **opposé** à
  `LastDirection` depuis le neutre (§80-88), la **seule** voie d'adoption est
  `DirectionChangeDelay.Q` (§75). Timer gelé → `CommandedDirection` reste à 0 → `RelayFwd/Rev` = FALSE
  → `BrakeCmd = RelayFwd OR RelayRev` = FALSE. Immobile, aucun contacteur. Seule sortie : `Reset`
  (§37-43 remet `LastDirection := 0` → adoption immédiate §83).
- **Bug indépendant** : mise à l'échelle joystick Y — `JoyYRaw_ANA2 = 0` (fil coupé / étalonnage)
  traduit en `-100 %` sans lever `ErrorOperatorComm`. Aggrave (aucun retour au neutre) mais n'est
  pas la cause : le blocage se reproduit avec un vrai appui descente maintenu après une montée.
- **Non concerné** : FDC logiciel haut (bloque la montée seule, `DescendPermit` = TRUE), permis,
  puissance, barrière finale, arbitrage, défauts.
- **Statut** : cause racine **prouvée** ; correction **NON implémentée** — attente fin de travail
  de l'agent en cours, puis état des lieux global avant d'implémenter (décision utilisateur 2026-09-01).

## 7bis. 📖 Spec cible du palier mini / ralentissements (arbitrée avec l'utilisateur, 2026-09-01)

> Deux mécanismes **distincts** à ne pas confondre :
> - **Plancher** (`MinStepDown`) = force `RequestedStep` vers le **haut** (remplace la demande joystick si plus basse). `FB_Winch:244-246`.
> - **Plafond de ralentissement** (`SlowdownMaxStep`) = borne `ActiveMaxStep` vers le **bas** en zone de fin de course. `FB_Winch:165-184`. C'est un `MIN`, pas un plancher.

| Cas | Attendu | Mécanisme | État |
|---|---|---|---|
| Hors mode de fonctionnement | **aucun plancher** (`MinStepDown = 0`) | `FB_DiveSearch`→`PRG_03` | ✅ amont OK — ❌ cassé par `PRG_04:927 MAX(1,…)` |
| Descente, ~1 m avant FDC bas logiciel | ralentir à **palier 1** (petite vitesse) | plafond `InBottomSlowdownZone` | ✅ garder |
| **Montée**, approche FDC haut logiciel | **PAS de ralentissement** (le moteur cale). Garder la fonction mais **distance haut = 0 m** | plafond `InTopSlowdownZone` (agit seulement en montée) | 🔵 **hors P0** — évolution métier à spécifier : scinder `SlowdownDistance_M` haut/bas (haut=0, bas=1 m) |
| Benne : approche FDC ouvert / fermé | ralentir à **palier 1** ; entre les deux, **jusqu'au palier 5** | plafond M2 `M2_BucketJogLimit` | ✅ garder |
| **Diving descente** (Kobold) | **imposer palier 4** (`CfgDiveFloorStep`) — le Kobold a besoin du débit ; ne doit pas gêner la manœuvre | plancher `MinStepDown` (dive actif seulement) | ✅ intention OK ; l'intégration doit garder « sens descente adopté + pas d'inversion en attente » |

**Note comportement plancher** : quand il s'applique, le dosage joystick sous la valeur plancher
est **perdu** (petit coup de joystick ⇒ cible = palier plancher). Le StepShaper rampe quand même
`0→…→plancher` à 500 ms/palier (contacteurs commutés un à un), l'interlock de sens garde ses tempos.
C'est acceptable en diving ; c'est le **caractère inconditionnel** (hors diving) qui est le défaut.

## 8. 🛠️ Correction — P0 VALIDÉE, IMPLÉMENTATION GELÉE

> ⏸️ Geler jusqu'à la fin du travail agent + état des lieux. Périmètre **restreint** au strict P0
> (revue 2026-09-01). « Petit patch, mauvaise intégration du palier mini » — pas de refactor.

**Palliatif immédiat (sans code)** : `Reset` défaut machine → repart. La panne revient à chaque
descente qui suit une montée (inversion en attente + palier mini forcé).

### Périmètre P0 (validé)

| # | Fichier | Change | Objectif testable |
|---|---|---|---|
| 1 | `PRG_04` (agrég. `CommonMinStepDown`) | Remplacer le plancher global `MAX(1, …)` par un plancher **autorisant 0** (`MAX(0, ReqBucket.MinStepDown)` / `LIMIT(0,…,5)`). | Hors diving : `WinchRequest.MinStepDown = 0`. |
| 2 | `FB_Winch` (injection `MinStepDown`) | N'appliquer `MinStepDown` **que si** : descente demandée (`ReqDescend AND NOT ReqAscent`) **ET** permis effectif descente valide **ET** aucune inversion en attente (`NOT DirectionChangePending`) **ET** sens descente **réellement adopté** (`CommandedDescend`). | Pendant `DirectionChangePending` : `RequestedStep` suit `RampTargetStep` (=0), pas de palier forcé. |
| 3 | — | **Ne pas** contourner ni réinitialiser artificiellement le délai d'inversion (`DirectionChangeDelay`). | Le temps mort d'inversion s'écoule normalement, treuil à l'arrêt. |
| 4 | Fiche (ce doc) | Réviser les libellés : `M1DriveRequest.Direction` **obsolète** post-refactor. Utiliser : bits explicites `ReqAscent` / `ReqDescend`, `RunRequest`, `DirectionChangePending`, sens adopté (`CommandedAscent` / `CommandedDescend`), palier demandé (`SpeedStepReq`). | Fiche alignée sur le code final. |

Résultat P0 : `StepNumber` reste 0 tant que l'inversion est en attente → l'interlock de sens n'est
plus gelé → `CommandedDescend` s'adopte après le temps mort → relais descente + frein → mouvement.
Diving inchangé (`MinStepDown = 4` s'applique **après** adoption du sens descente).

### HORS périmètre de ce patch (à traiter séparément)

- **Séparation ralentissement haut / bas** (`SlowdownDistance_M` commun → distance haut = 0 pour
  éviter le calage moteur en approche FDC haut) : **évolution métier**, à spécifier à part.
- **Joystick brut `JoyYRaw_ANA2 = 0` → `-100 %`** : à **investiguer côté acquisition** (échelle,
  offset, détection hors plage) **avant** de conclure à une rupture de fil. Bug indépendant, n'est
  pas la cause du blocage.
- **Tests CI** (`_TROUBLESHOOTING/` : montée puis descente maintenue hors diving ⇒ pas de palier
  pendant l'attente d'inversion, puis adoption + relais + frein ; variante diving palier 4) :
  **après** le correctif.
- **Observabilité** `GVL_Troubleshooting` (bits de sens explicites, `DirectionChangePending`,
  `MinStepDown`) : souhaitable, non bloquant P0.

- **⚠️ Validation requise** : [humaine] — aucun code modifié / variable forcée sans accord explicite.

## 9. ✅ Vérification de la correction / non-régression

> À remplir après validation humaine et application. Points de non-régression :
> - Descente / montée depuis neutre : départ après temps mort, sans blocage.
> - Inversion de sens directe : temps mort opposé respecté.
> - FDC logiciel haut : bloque toujours la montée seule, l'échappement descente reste libre.
> - Joystick Y fil coupé simulé : `ErrorOperatorComm` levé, pas de commande fantôme.
