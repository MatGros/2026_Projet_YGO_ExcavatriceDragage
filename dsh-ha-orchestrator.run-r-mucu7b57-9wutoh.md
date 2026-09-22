# orchestrate run r-mucu7b57-9wutoh

- mode: fanout | agent: session-ad357a0c-e3f1-4595-bf68-fa754d42dd56 | provider: spawn
- concurrency: 6 | durationMs: 275546 | aborted: false
- startedAt: 2026-09-22T15:36:43.819Z | finishedAt: 2026-09-22T15:41:19.365Z

## Audit FB_Safety_Winch du jour [completed]

J'ai toutes les preuves. Voici le rapport d'audit.

---

# 🔍 Audit PLC — Perte de `MotorRequest` M2 à l'étape AX11 (2026-09-22)

## ⚠️ Bannière briefing agent

```text
============================================================
🎬 BRIEFING SESSION WORKFLOW PROJET / AGENTS.MD ACTIF
============================================================
Mode : Dépannage / Traçage inverse (skill `troubleshooting`)
Objet : modif FB_Safety_Winch du 22/09 → coupure M2 en AX11 ?
Machine : Excavatrice de dragage RÉELLE — rester factuel, citer les lignes.
============================================================
```

**Verdict court (détails plus bas)** : la piste crédible est la **Cause 8 MécaB** (`JoystickYNeutral` → `NOT MovementCommanded`). La **`BucketCloseAscentGrant` ne peut PAS couper M2 à AX11** (elle ne relaxe que la butée basse→haute et vaut `FALSE` à AX11). Probabilité que la modif du jour **soit** la cause directe de la coupure : **MOYENNE** — avec un doute franc à formuler (voir §5).

---

## 1. Diff exact du jour (`8ec1fa28..708a0f44`)

Commit matin `8ec1fa28` = **2026-09-22 00:14** (`Backup Chekpoi,nt`).
Commit soir `708a0f44` = **2026-09-22 14:55** (`wip(project): checkpoint qsave`).

```diff
--- a/CODE/H_TREUILS_BENNE/FB_Safety_Winch.st
+++ b/CODE/H_TREUILS_BENNE/FB_Safety_Winch.st
@@ -35,6 +35,12 @@ VAR_INPUT
     BenneHoldStillActive            : BOOL;
     BenneBusy                       : BOOL;
     OtherWinchInhibited             : BOOL;
+    BucketCloseAscentGrant          : BOOL := FALSE;   // Relaxe la butee haut MATERIELLE M2 sous fenetre benne (4 verrous)

@@ -338,7 +344,7 @@ IF NOT BypassGlobal THEN
     // Cause 8 : Méca B absence confirmation arrêt (latched)
     IF NOT (BypassSafety OR BypassMecaB) THEN
-        UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
+        UncommandedActiveB := NOT MovementCommanded AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
         TonMecaB(IN := UncommandedActiveB, PT := PostRampTimeout);
         IF TonMecaB.Q THEN MecaBFaultLatched := TRUE; END_IF;

@@ -572,9 +578,16 @@ AscentPermit := NOT (
     ((CauseTopLimitSwitchActive
     OR (NOT TopPositionSensor AND NOT InReferencingMode))
-    AND NOT BypassTopLimitSwitch)
+    AND NOT BypassTopLimitSwitch
+    AND NOT BucketCloseAscentGrant)
     OR (Homed AND NOT HomingSuspect AND NOT InReferencingMode AND (CablePosM >= TopLimitM) AND NOT (BypassGlobal OR BypassTopLimitSoftware))
 );
```

**3 modifications :**
- Déclaration `BucketCloseAscentGrant` (FB_Safety_Winch.st:38-43), câblée `FALSE` sur M1 / vraie valeur sur M2 dans PRG_04.
- **Cause 8 MécaB** : gate `JoystickYNeutral` → `NOT MovementCommanded` (FB_Safety_Winch.st:347).
- **AscentPermit** : `AND NOT BucketCloseAscentGrant` sur le premier groupe (FdC haut capteur) (FB_Safety_Winch.st:590).

---

## 2. Analyse ligne à ligne (Cause 8 MécaB) — avant / après

**Avant** (committé matin) :
```st
UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
```
**Après** (committé soir, ligne 347) :
```st
UncommandedActiveB := NOT MovementCommanded AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
```

Définitions câblées dans `PRG_04_Treuils_Benne.st` :
- M2 `JoystickYNeutral := (PRG_02_Acquisition.Data.Joystick.AxisY.Direction = 0)` — **ligne 1090**. C'est la **position physique du manche de l'opérateur**, indépendante de la commande logique.
- M2 `MovementCommanded := instWinchM2.RelayFwd OR instWinchM2.RelayRev` — **ligne 1084**. C'est la **demande de relais SORTIE de FB_Winch** (le signal que le programme émet réellement).

### ✍️ Ce que change exactement la fenêtre de détection

| Condition | Ancien gate `JoystickYNeutral` | Nouveau gate `NOT MovementCommanded` |
|---|---|---|
| Fenêtre pilotée par | position **physique du manche** (opérateur) | **relais de commande** émis par FB_Winch |
| Joystick tenu, montée commandée (relais ON) | `FALSE` → **MecaB désarmé** | `NOT(FALSE)=FALSE` → **MecaB désarmé** (identique) |
| Joystick neutre AUTOMATIQUE, montée commandée (relais ON) | `TRUE` → **MecaB armé** (faux positif possible) | `FALSE` → **désarmé** ✅ |
| **Joystick tenu, relais coupé, machine ENCORE EN MOUVEMENT (>3 s)** | `FALSE` → **MecaB désarmé** (trou) | `TRUE` → **MecaB armé, peut latcher** ⚠️ |

**Interprétation technique** : on passe d'une fenêtre définie « par le levier physique, découplée de la vraie commande » à une fenêtre « par la vraie demande de relais ». C'est conceptuellement **plus juste** pour « mouvement non commandé » (on teste la commande réelle, pas la main de l'opérateur). C'est une **correctif** dans le sens « commande émise mais non confirmée ».

**MAIS** il introduit une **boucle de rétroaction (couplage)** : `MovementCommanded` lit `instWinchM2.RelayFwd/RelayRev`, qui sont **précisément les sorties que SafeStop coupe** (FB_Winch.st:216 → ligne 285-293). Dès qu'un SafeStop (de n'importe quelle cause) fait retomber le relais, `NOT MovementCommanded` devient `TRUE`, ce qui **arme MecaB**. Si le treuil réel n'a pas confirmé l'arrêt dans `PostRampTimeout = T#3s` (ligne 55), MecaB **latche et maintient le SafeStop de façon permanente**. L'ancien code masquait ce cas tant que l'opérateur tenait le manche.

> **Conséquence en AX11** : à AX11 l'opérateur **tient le manche tiré** (`FB_CycleSemiAuto.st:1222` « AX11 - Maintenir la montee » ; `:1391` « Maintenir la montee » ; étape `E_AutoCycleStep.AX10_WAIT` « joystick tire maintenu »). Donc **l'ancien MecaB était structurellement OFF en AX11** (JoystickYNeutral=FALSE), quel que soit l'état réel du treuil. Le nouveau code réarme cette surveillance en AX11 — utile en théorie, mais il **supprime l'aveuglement antérieur** qui, par malchance, protégeait l'AX11 du latch.

---

## 3. Chaîne MécaB → SafeStop → `instWinchM2` → barrière → `MotorRequest`

Chaîne exacte, lignes numérotées :

**① Déclenchement MecaB (FB_Safety_Winch.st)**
1. `UncommandedActiveB` (ligne 347) → `TonMecaB(..., PT := PostRampTimeout/*3 s*/)` (ligne 348) → `TonMecaB.Q` → `MecaBFaultLatched := TRUE` (ligne 349).
2. `MecaBFaultLatched` → `instCauses[8].Active` (lignes 354-355) → `CauseMecaBActive` (ligne 508).
3. `CauseMecaBActive` ∈ `CausesSafeStopActive` (**ligne 524**) **et** ∈ `CausesPowerCutOffActive` (**ligne 530**).

**② Arbitrage sorties (FB_Safety_Winch.st)**
4. `SafeStop := CausesSafeStopActive OR (SyncEnable AND CauseSlackCableActive) OR OverspeedFaultLatched;` (**lignes 564-566**).
5. `PowerCutOff := CausesPowerCutOffActive;` (**ligne 597**) — ⚠️ MecaB déclenche AUSSI la coupure puissance, pas seulement un rampe.

**③ Agrégation PRG_04 (PRG_04_Treuils_Benne.st)**
6. `SafeStopM2_Raw := SafeStopM2_Raw OR instSafetyWinchM2.SafeStop;` (ligne 1127).
7. `SafeStopM2_Active := SafeStopM2_Raw OR (CoupledBoth AND SafeStopM1_Raw);` (**ligne 1170**).
8. `EffectivePermitM2_Ascent := ProcessAndSafetyPermitM2_Ascent AND NOT SafeStopM2_Active ...` (**ligne 1178**) → `M2AscentPermitApplied` (lignes 1195-1196).

**④ Câblage `instWinchM2` (PRG_04_Treuils_Benne.st)**
9. `instWinchM2(SafeStop := SafeStopM2_Active, AscentPermit := M2AscentPermitApplied, DescendPermit := ...)` (**lignes 1597-1599**).

**⑤ FB_Winch coupe la demande (FB_Winch.st)**
10. `EffectiveSafeStop := SafeStop OR DirectionConflict OR (ReqAscent AND NOT AscentPermit) OR (ReqDescend AND NOT DescendPermit);` (**lignes 169-171**).
11. `IF ... OR EffectiveSafeStop ... THEN RampTargetStep := 0;` (**ligne 216**) → `StepNumber := 0` (ligne 281) → `RelayFwd:=FALSE; RelayRev:=FALSE;` (lignes 291-292).

**⑥ Rétroaction de la barrière finale (PRG_04 + FB_WinchOutputInterlock)**
12. `WinchM2FinalInterlockRequest.RequestedRelayFwd := instWinchM2.RelayFwd;` (ligne 1690) ; `RequestedRelayRev` (1691) ; `RequestedStep := instWinchM2.StepNumber;` (**ligne 1696**).
13. Barrière : `MotorRequest := (RequestedStepClamped > 0) AND (RequestedRelayFwd XOR RequestedRelayRev);` (**FB_WinchOutputInterlock.st:182**). `StepNumber=0` → `RequestedStepClamped=0` → **`MotorRequest = FALSE`**.
14. En plus, SafeStop force la coupure dure des relais à la barrière (lignes 393-403).

**🔧 Point clé de bouclage** : le pas ⓮ (barrière/instWinchM2) retombe sur le signal lu au pas ① (`NOT MovementCommanded` = relais sortie). Le latch MecaB **entretient lui-même** son déclencheur après coupure — c'est le mécanisme « self-sustaining » décrit en §2.

---

## 4. Analyse de `BucketCloseAscentGrant` (relaxation butée haut M2) — peut-il couper la montée AX11 ?

**Non.** Preuves :

1. **Sens unique de l'effet** : `BucketCloseAscentGrant` n'apparaît que dans le groupe 1 d'`AscentPermit` sous la forme `AND NOT BucketCloseAscentGrant` (FB_Safety_Winch.st:590). Ce n'est **qu'une relaxation** (suppression d'une condition bloquante), jamais un blocage. Le pire effet possible est « la butée haut matérielle autorise la montée en plus » — pas « la montée est coupée ».

2. **Valeur pendant AX11** : le grant vaut `FALSE` hors fenêtre 4 verrous (PRG_04:971-977) :
```st
BucketFenetreWindow   := instBucket.Lifecycle.Busy AND ReqClose;   // v1 fermeture AUTO seul
BucketM1HeldCheck     := instBucket.Lifecycle.Busy;                // v2
BucketM1NotAscent     := NOT M1LogicReqAscent;                     // v3
BucketCloseNotReached := NOT instBucket.CloseReached;              // v4
BucketCloseAscentGrant := BucketFenetreWindow AND BucketM1HeldCheck
    AND BucketM1NotAscent AND BucketCloseNotReached;               // PRG_04:976-977
```
   À AX11, la benne est fermée / `ReqClose` est passé à `FALSE` (le raccordement AX10B exclut le grant, PRG_04:969) et `CloseReached` est vrai → **au moins v1 et v4 tombent → `grant = FALSE`**. Câblé `FALSE` sur M1 (PRG_04:1053), vraie valeur sur M2 (PRG_04:1123).

3. **À `grant = FALSE`, la formule est identique à avant** : `AND NOT FALSE` est un no-op. Donc l'AscentPermit d'AX11 n'est **pas modifié** par ce champ.

4. **Limite « dure » (m) non touchée** : le second terme d'`AscentPermit` (borne logicielle `CablePosM >= TopLimitM`, ligne 594) ne consomme **jamais** le grant. Une montée M2 trop haut reste bloquée par la butée logicielle indépendamment du grant.

💡 **Seul risque résiduel (secondaire/spéculatif, pas la coupure d'AX11)** : pendant la **fermeture** (grant actif), M2 peut monter au-delà du FdC matériel ; si `CloseReached` n'est pas posé correctement, le grant s'éteint et la butée reprend « en surplomb » — mais c'est un effet du câblage fenêtre, **hors AX11**, et inverse (il pourrait *bloquer le départ* AX11, pas *couper pendant* AX11). Sans preuve terrain, je le signale comme hypothèse faible, pas comme la cause.

---

## 5. Verdict de probabilité — avec doute franc

### Probabilité : **MOYENNE** (la modif est un facteur aggravant probable, cause directe seulement dans un scénario précis)

| Critère | Évaluation | Justification |
|---|---|---|
| `BucketCloseAscentGrant` cause la coupure AX11 ? | **Non (quasi exclu)** | Ne relaxe que le FdC matériel, vaut `FALSE` à AX11, `AND NOT grant` no-op quand FALSE. §4. |
| Cause 8 MécaB : effet sur la fenêtre AX11 | **Réel** | Supprime l'aveuglement « manche tenu » qui désarmait MecaB en AX11 (§2). |
| Cause 8 MécaB : **graine initiale** de la coupure | **Douteux seul** | Nécessite une fenêtre relais-coupé + « pas d'arrêt confirmé » **> 3 s** à AX11. En montée continue AX11 le relais reste ON → MecaB off. |
| Cause 8 MécaB : **amplificateur / stabilisateur de coupure** | **Oui, net** | Une coupure transitoire (n'importe quelle cause) → relais tombe → `NOT MovementCommanded`=TRUE → si arrêt non confirmé en 3 s → **MecaB latche → SafeStop + PowerCutOff permanents** (auto-entretenu). L'ancien code laissait ce transitoire s'effacer (manche tenu). |

**Chaîne exacte de mise en cause (si la modif est en cause)** :
```
FB_Safety_Winch.st:347 NOT MovementCommanded        (fenêtre élargie au « manche tenu, relais coupé »)
            :348 TonMecaB PT=T#3s
            :349 MecaBFaultLatched := TRUE
            :508 CauseMecaBActive
            :524/530 CausesSafeStopActive / CausesPowerCutOffActive
            :564-566 SafeStop := TRUE        (+ :597 PowerCutOff)
PRG_04:1127 → :1170 SafeStopM2_Active
      :1178 → :1195-1196 M2AscentPermitApplied := FALSE
      :1597-1599 instWinchM2(SafeStop/AscentPermit)
FB_Winch.st:169-171 EffectiveSafeStop → :216 RampTargetStep:=0 → :281 StepNumber:=0 → :291-292 Relay:=FALSE
PRG_04:1690-1696 Requested* → FB_WinchOutputInterlock.st:182 MotorRequest := FALSE
```

### ⚠️ Doubt franc (à trancher sur le terrain)
1. **Le relais M2 retombe-t-il réellement +3 s pendant AX11 ?** En montée continue, non — sauf : collision de pas P1→P2 mal gérée, ou coupure transitoire d'un **autre** permis/SafeStop (ex. MecaE écart M1/M2, car AX11 surveille l'écart vitesse). Si c'est une **première cause transitoire** (pas MécaB) qui initie la coupure, alors **la modif n'est pas la cause racine** : elle est seulement ce qui **verrouille** la coupure en latch. Il faut l'historique des défauts pour distinguer « MecaB a initié » vs « MecaB a amplifié ».
2. **Sens inverse de protection** : dans les modes où l'opérateur relâche le manche pendant une montée commandée automatique, l'ancien `JoystickYNeutral` créait un **faux positif MecaB** que le nouveau code **corrige**. La modif peut donc aussi *réduire* les coupures dans d'autres étapes. L'effet n'est pas univoque.

**Recommandation d'arbitrage factuel** : vérifier sur l'IHM/diag (`FB_TroubleshootingView`, `TraceM2.SafeStopActive` PRG_04:1961, `MecaBElapsedTime` FB_Safety_Winch:104) si au moment de la perte en AX11, `MecaBFaultLatched` bit8 est posé et si `M2_ContactorsReleased_DI` / `M2_BrakeIsOpen_DI` confirmaient ou non l'arrêt. Si bit8 est **le premier** défaut posé → modif = cause directe (moi → **HAUTE**). Si bit8 apparaît **après** un autre défaut/permis → modif = verrouillage (moi → **BASSE**).

---

## Fichiers consultés
- `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` (cause 8 : 345-356 ; AscentPermit : 580-595)
- `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (grant : 971-977 ; câblages : 1056-1124 ; SafeStop : 1126-1178 ; instWinchM2 : 1593-1699)
- `CODE/H_TREUILS_BENNE/FB_Winch.st` (169-171, 216, 281, 284-293)
- `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` (182, 393-403)
- `CODE/G_CYCLE/FB_CycleSemiAuto.st` (1381-1395) & `E_AutoCycleStep.st` (AX11)

## Audit PRG_04 du jour [completed]

J'ai maintenant tous les éléments factuels. Je rédige le rapport d'audit.

---

# 🔍 AUDIT DIFF 2026‑09‑22 — `PRG_04_Treuils_Benne.st` → impact sur `InterlockM2.MotorRequest` à AX11

**Comparaison** : `8ec1fa28` (2026‑09‑22 00:14, checkpoint) → `708a0f44` (2026‑09‑22 14:55, checkpoint qsave). Le lot effectif est **`dff0b535` « T387 – fenêtre benne, bornes relatives sans datum et alarme codeurs homing »** (14:54:50). Toute la journée porte sur la **fenêtre benne** (fermeture AUTO au FDC haut) et le bridage homing.

> ⚠️ **Constat n°1 — le bloc « Défense en profondeur » (lignes 1731–1748) n'est PAS modifié dans ce diff.** Il est **préexistant**. La neutralisation `RequestedRelay/Step := 0` en `SEMI_AUTO AND WinchBothMotionActive AND (NOT WinchBothMotionReady OR NOT WinchBothFinalRequestsCoherent)` est donc un *symptôme*, pas une modif du jour. La vraie question est : un hunk du jour peut‑il rendre `WinchBothMotionReady=FALSE` ou `WinchBothFinalRequestsCoherent=FALSE` **à AX11** ?

---

## 📋 Inventaire des hunks du jour

| # | Hunks (lignes diff) | Variables/mécanismes touchés | Portée |
|---|---|---|---|
| H1 | `@15` VAR_OUTPUT | `BucketWaitingForOperator` (déclaration + pub §8 `@1843`) | Sortie IHM diag | 
| H2 | `@210` VAR | `AutoBucketCloseActiveForTopLimit`, `BucketFenetreWindow`, `BucketM1HeldCheck`, `BucketM1NotAscent`, `BucketCloseNotReached`, `BucketCloseAscentGrant` (déclarations) | Fenêtre benne AUTO |
| H3 | `@786` `ManualBucketLimitsActive` | **ajoute** `AND EncoderM1.HomedAndReliable AND EncoderM2.HomedAndReliable` | Jog benne unitaire |
| H4 | `@823` `M2JogApproachOpen/Close` | **ajoute** `AND ManualBucketLimitsActive` | Jog benne unitaire |
| H5 | `@908→930` `TopLimitM2_M` | Exemption étendue à `AutoBucketCloseActiveForTopLimit` + garde homed | Fermeture AUTO / jog benne |
| H6 | `@950→976` | `BucketCloseAscentGrant` (4 verrous) | Relâche butée **matérielle** M2 en fermeture AUTO |
| H7 | `@1046/1116` instSafety | `BucketCloseAscentGrant:=FALSE` (M1) / `:=grant` (M2) | Paramétrage FB_Safety_Winch |
| H8 | `@1309→1312` **Cycle homing machine** | `IF MachineHoming.Active THEN CommonMaxStepAscent:=1; CommonMaxStepDescent:=1` | **Commun M1+M2, touche la montée couplée** |
| H9 | `@1843` | `BucketWaitingForOperator` (pub) | Sortie IHM | 

---

## 🎯 Corrélation avec les variables cibles

| Variable cible | Touchée ce jour ? | Détail |
|---|---|---|
| `WinchBothMotionReady` (1475, 1611) | **NON** | `NOT DirectionChangePending M1/M2 AND NOT Fault.Latched M1/M2` — aucun hunk ne modifie ces sources |
| `WinchBothFinalRequestsCoherent` (1718) | **NON** | Égalité RequestedRelay/Contacteurs/Step M1=M2 — la logique elle‑même n'est pas touchée |
| `WinchBothMotionActive` (304) | NON | Non modifié |
| `ReqM2Winch.*` (1543–1562) | NON (direct) | La struct M2 est réécrite tel quel ; **`TopLimitM2_M`** alimenté par H5 |
| `CommonMaxStepAscent` (1290) | **OUI (H8)** | Nouveau plafond strict `:=1` si `MachineHoming.Active` |
| `M2MaxStepUp` (1363) | Hérite de H8 | `M2MaxStepUp := CommonMaxStepAscent` puis surcharge benne (non activée en montée couplée) |
| `TopLimitM1_M` (905) | NON | Intact |
| `TopLimitM2_M` (908) | **OUI (H5)** | Exemption relative + `+2.0` — **mais conditionnée à jog benne / fermeture AUTO** |
| `SafeStopM1/M2_Active` (1169–1170) | NON (direct) | Agrège instSafety + couplage ; H6/H7 modifient le permis ascent, pas le SafeStop |
| `M2AscentPermitApplied` (1195) | NON (direct) | hérite de `EffectivePermitM2_Ascent` ; H6/H7 agissent sur `SafeStop`/permit **uniquement sous fenêtre benne** |

---

## 🔬 Analyse mécanistique — chaque hunk à AX11 (montée contrôlée P1/P2 couplée)

### Clé de lecture : qu'est‑ce qui est VRAI à AX11 ?
- `Mode = SEMI_AUTO` ✅ , `SequenceState.Step = AX11_CTRL_ASCENT`, `WinchBothMotionActive=TRUE`.
- **`ReqBucket.ReqClose = FALSE` à AX11** : posé à `FALSE` par défaut en AX10B (`FB_CycleSemiAuto.st:1348`) et **jamais re‑déclaré TRUE en AX11** (ligne 1381+). C'est la prémisse qui **verrouille tout le lot T387 hors d'AX11**.
- `ManualBucketJogActive = FALSE` : exige `JoystickWinchSelectArbitrated = 2` (unitaire benne), or AX11 est une montée couplée (selection arbitrée `0`).

### H1, H2, H9 — déclarations + sortie IHM
🔵 **FAIBLE.** Aucune logique de commande. `BucketWaitingForOperator` est une ré‑agrégation de lecture seule.

### H3, H4 — gating jog benne par `HomedAndReliable`
🔵 **FAIBLE.** `ManualBucketLimitsActive`, `M2JogApproachOpen/Close` ne servent **que** le jog benne unitaire (WinchSel=2). **Hors périmètre AX11.** La règle produit « on ne borne JAMAIS la benne si M1/M2 non homed » (commit `01b5e991`) est sans effet sur une montée couplée.

### H5 — `TopLimitM2_M` exemption étendue
🔵 **FAIBLE pour AX11.** La branche `TopLimitM2_M := M1_CablePosM + OffsetCloseM + 2.0` ne s'exécute que si `(ManualBucketJogActive OR AutoBucketCloseActiveForTopLimit)`. 
- `ManualBucketJogActive = FALSE` à AX11.
- `AutoBucketCloseActiveForTopLimit := instBucket.Lifecycle.Busy AND ReqClose`. À AX11 `ReqClose=FALSE` → **`FALSE`** → la branche est INACTIVE.
- À AX11 on tombe dans le `ELSIF WinchBothMotionActive` préexistant : `TopLimitM2_M = CfgCableLimitAscent_M + M2_LimitShift + 0.50` — **inchangé** par le diff.
- Impact : **aucun sur le plafond/RequestedStep de M2 à AX11**. Risque résiduel si `ReqClose` devenait TRUE par défaut (scénario anormal), voir verdict.

### H6 + H7 — `BucketCloseAscentGrant` (relâche butée **matérielle** M2)
🔵 **FAIBLE pour AX11.** Le grant exige `BucketFenetreWindow := instBucket.Busy AND ReqClose` → **FALSE à AX11** (ReqClose=FALSE) → `grant = FALSE` → **la butée matérielle M2 reste active**, aucun Bypass réutilisé. Câblé **FALSE sur M1** (barrière M1 jamais relâchée → `SafeStopM1` intact). Ce mécanisme est confiné à la **fermeture AUTO** (AX10), hors montée couplée.

### H8 — ⭐ **Cycle homing machine : palier 1 MAX strict (lignes 1312–1316)**
🔴 **C'est le SEUL hunk qui agit sur le canal commun M1+M2 de la montée couplée.**
```st
IF PRG_02_Acquisition.Data.MachineHoming.Active THEN
    CommonMaxStepAscent  := 1;
    CommonMaxStepDescent := 1;
END_IF;
```
- S'il s'applique **pendant AX11**, `CommonMaxStepAscent:=1` → `M2MaxStepUp:=1` **et** `ReqM1Winch.MaxStepUp:=1`. Les **deux** treuils plafonnent à P1.
- **Effet : bridage de vitesse** (P1 max), **PAS une mise à 0 de RequestedStep**. Et parce qu'il bride **M1 ET M2 symétriquement**, il préserve `WinchBothFinalRequestsCoherent` (M1=P1, M2=P1 → cohérent) et donc ne déclenche **pas** le bloc Défense en profondeur.
- ⚠️ Toutefois : `MachineHoming.Active` est TRUE pendant le **cycle homing machine complet (HX1..HX6)**, exécuté en mode MAINT/commissioning — **normalement jamais simultané avec un cycle semi‑auto AX11**. L'activation pendant AX11 impliquerait une **incohérence de séquence** (homing déclenché pendant qu'un cycle semi‑auto tourne), déjà surveillée par `FB_Modes:161 SemiAutoCycleNotReadyMachineHoming` (blocage de sélection si `NOT MachineHomed`).

---

## ✅ Réponse à la question 5 — le diff peut‑il faire tomber RequestedStep M2 à 0 / `WinchBothMotionReady`→FALSE à AX11 ?

**Non en conditions nominales.** Tous les mécanismes T387 (`AutoBucketCloseActiveForTopLimit`, `BucketCloseAscentGrant`, `ManualBucketLimitsActive`) sont **verrouillés hors d'AX11** par la seule prémisse `ReqClose=FALSE` à AX11. `WinchBothMotionReady` et `WinchBothFinalRequestsCoherent` ne sont **pas modifiés** par le diff.

**Scénario crédible unique (H8)** : si `MachineHoming.Active` était TRUE pendant AX11 (état anormal), les deux treuils sont bridés à P1 — bridage symétrique, cohérent, **sans neutralisation finale**. Donc même ce cas ne casse pas `InterlockM2*`.

---

## ⚖️ Verdict de probabilité

| Mécanisme de perte supposé | Verdict |
|---|---|
| `RequestedStep M2 → 0` causé par un hunk du jour à AX11 nominal | 🔵 **BASSE** — aucun hunk ne met M2 à 0 ; les mécanismes T387 sont exclus car `ReqClose=FALSE` |
| `WinchBothMotionReady → FALSE` causé par le diff à AX11 | 🔵 **BASSE** — H1..H9 ne touchent ni `DirectionChangePending` ni `Fault.Latched` |
| `WinchBothFinalRequestsCoherent → FALSE` à AX11 | 🔵 **BASSE** — le bridage H8 est symétrique M1=M2 (préserve la cohérence, cf. fix P1/P5 déjà présent lignes 1333–1338) |
| Perte via **bloc Défense en profondeur** (1731) | 🔵 **BASSE** — bloc **préexistant**, non modifié ce jour |
| Perte si **état anormal** (`MachineHoming.Active` actif pendant AX11) | 🟠 **MOYENNE** — H8 bridait alors M2 à P1 (ralentissement, pas 0) ; à écarter/confirmer au runtime |

**Conclusion factuelle** : sur la base du code **à jour**, la perte de `InterlockM2.MotorRequest` à AX11 **n'est pas expliquée par le diff du 2026‑09‑22** en conditions nominales. Toute la conception de T387 s'auto‑exclut de la montée couplée via `ReqClose=FALSE`. 

---

## 🎯 Recommandations pour la machine réelle (à vérifier au runtime, je ne peux que pointer)

1. **Tracer la vraie cause dans les traces PRG_04 (§8)** : `TraceM2.FinalPermitBlocked` (1959), `TraceM2.AscentPermitEffective` (1956), `TraceM2.SafeStopActive` (1961), et `Data.BothActive`. Ce sont les signaux qui décident si la neutralisation bascule.
2. **Vérifier `MachineHoming.Active`** à l'instant de la perte AX11 (trace `Data.MachineHoming`). Si TRUE → H8 est en cause (bridage P1). Si FALSE → cause ailleurs.
3. **Vérifier `ReqBucket.ReqClose` à AX11** : c'est la prémisse verrouillante. S'il est TRUE à tort pendant AX11, alors H5 (`TopLimitM2_M` relatif) et H6 (grant butée M2) deviendraient **actifs à AX11** → 🟠 risque réel. **À contrôler en priorité** : c'est le seul point de bascule qui "arme" tout le lot T387 hors de son périmètre voulu (AX10).
4. **Vérifier Fault.Latched / DirectionChangePending M1/M2** au moment de la perte (source de WinchBothMotionReady) — cause la plus probable d'une neutralisation par le bloc Défense (préexistant).

*Audit statique sur le code versionné (`CODE/*.st`). Je n'ai pas d'accès au runtime PLC ni aux traces de la machine.*

## Audit FB_CycleSemiAuto du jour [completed]

# 📋 Audit T383 — Coupure M2 à AX11 sur FB_CycleSemiAuto

## 1. Diff du jour — `8ec1fa28..708a0f44`

Commit du jour : `0358c631` — *« feat(cycle,ihm,outillage): T383 - micro-step benne decharge AX15D (23), retrait saut non declare AX15B->AX10, amendement GEL, garde-fous G517/G523 [NON TESTE MACHINE] »*

## 2. Liste des hunks (8 au total, tous hors zone AX10-AX11)

| Hunk | Lignes (cible) | Contenu |
|---|---|---|
| 1 | `-282/+282,10` | `CST_StepForceMax` 22→23 + commentaire enum |
| 2 | `-470/+470,10` | `instCauses[1]` : ajout exclusion sync `AX15D` |
| 3 | `-736/+739,7` | Commentaire plage `[0..22]`→`[0..23]` |
| 4 | `-768/+771,7` | CASE force-step : ajout `case 23` = `AX15D` |
| 5 | `-794/+798,7` | Message rejet « 0..23 » |
| 6 | `-1541/+1545,7` | Texte `OperatorAction` AX15B |
| 7 | `-1553/+1557,15` | **AX15B** : retrait du saut `AX15B→AX10`, remplacé par `→AX15D` |
| 8 | `-1574/+1573,44` | **Nouveau bloc** `E_AutoCycleStep.AX15D_DUMP_BUCKET_JOG` |

## 3. Zone AX10–AX11 (~1301–1409) — ✅ CONFIRMÉE NON MODIFIÉE

Aucun hunk du diff ne touche les lignes 1301–1409. Lecture directe de la cible `708a0f44` :

- **`AX10_CLOSE_BUCKET`** (1301–1329) : intact — neutralise M1/M2, `ReqOpen:=FALSE`, transition `→AX10B` ligne 1328 inchangée.
- **`AX10B_RACCORDEMENT_P1`** (1331–1379) : intact — transfert atomique M1/M2 P1/P1, transitions `→AX11` lignes 1369 & 1377 inchangées.
- **`AX11_CTRL_ASCENT`** (1381–1411) : intact — commandes montée, transition `→AX12` sur distance + `NOT WinchSyncError` inchangée.

**Continuité AX10→AX10B→AX11 100 % préservée.** T383 n'altère en rien le chemin nominal.

## 4. AX15D + retrait du saut AX15B→AX10 — ✅ HORS ZONE

Tout se situe lignes **1538–1612** (blocs `AX15B` et `AX15D_DUMP_BUCKET_JOG`), soit à ~**130 lignes après** la fin de la zone AX10-AX11 (~1411). Confirmation topologique : le retrait du saut (ligne 1568 `State := AX15D`) et le nouveau bloc (1576–1612) sont strictement dans la phase **vidage** (AX15).

## 5. Exclusion de synchronisme `instCauses[1]` (467–476) — ✅ AUCUN EFFET sur AX10/AX11

```st
467: instCauses[1].Active := WinchSyncError
468:   AND (State <> AX0_REPOS) ...
470:   AND (State <> AX8_BOTTOM_CONFIRMED)
471:   AND (State <> AX9_RAISE_OFF_BOTTOM)
472:   AND (State <> AX10_CLOSE_BUCKET)      ← déjà présent avant T383
473:   AND (State <> AX11_CTRL_ASCENT)       ← déjà présent avant T383 (inchangé)
476:   AND (State <> AX15D_DUMP_BUCKET_JOG); ← SEUL ajout T383
```

Le diff **ajoute uniquement la ligne 476**. Les exclusions AX10 (472) et AX11 (473) figuraient déjà et restent **strictement identiques**. La surveillance de synchronisme des treuils pendant AX10/AX11 est donc **inchangée**. L'exclusion AX11 du *défaut vitesse confirmé* (`instCauses[5]`, 494–495) n'est pas touchée non plus.

⚠️ Note sécurité : AX15D est désormais exclu du repli sync (fenêtre de purge étendue au vidage, « identique à AX10 »). Cela concerne la **phase tremie**, sans aucun lien avec AX11.

## 6. Bloc force-step — ✅ NE PEUT PAS écrire AX10→AX11

- `CST_StepForceMax` 22→23 (ligne 285) : étend la plage coercible de 1 seul membre (`AX15D`).
- `case 23` (ligne 774) pointe **uniquement** vers `AX15D_DUMP_BUCKET_JOG`.
- Le force-step écrit une cible **unique** (`ForceStepCandidate` = une valeur d'enum → `State`), un saut ponctuel **mono-état**. Ce n'est pas un moteur de transition : il ne peut pas engendrer le couple `AX10→AX11`, qui n'existe que dans le flow nominal `CASE State` (1324–1380, non modifié).
- Les valeurs de force `10→AX10`, `11→AX11`, `22→AX10B`, `23→AX15D` restent bornées `[0..23]` avec rejet hors plage (ligne 802).

## 🎯 VERDICT — Probabilité que T383 cause la coupure M2 à AX11 : **BASSE**

| Critère | État | Conclusión |
|---|---|---|
| Blocs AX10/AX10B/AX11 modifiés ? | **NON** | continuité intacte |
| Retrait saut `AX15B→AX10` | **HORS ZONE** | réduit **les chemins vers** AX10/AX11 |
| Ajout AX15D | **HORS ZONE** (vidage) | sans lien AX11 |
| Surveill. sync AX10/AX11 (`instCauses[1]`, `[5]`) | **INCHANGÉE** | seul `AX15D` ajouté |
| Force-step → écriture AX10→AX11 | **IMPOSSIBLE** | saut mono-état, borne [0..23], cible = AX15D |

**Conclusion factuelle :** T383 est **exogène** à la chaîne AX10→AX10B→AX11. Il ne modifie ni la logique de ces étapes, ni leur surveillance de synchronisme, ni les commandes treuils M1/M2 de montée, ni le chemin de transition. Le changement le plus permissif touchant M2 reste **hors de la zone** (phase vidage à la tremie). Une coupure M2 à AX11 n'est **pas attribuable** à T383 sur la base du diff examiné. **Verdict : BASSE** — la cause d'une coupure M2 à AX11 est à chercher ailleurs (commande treuils amont, `instCauses[5]` écart vitesse confirmé, conditions physiques `M1_CablePosM` / `M2_CablePosM`, homme-mort, ou autre lot).

---
*Vérification sur `git diff 8ec1fa28..708a0f44 -- CODE/G_CYCLE/FB_CycleSemiAuto.st` + lecture cible `708a0f44` (zone 1301–1409, 455–504, 1530–1619).*

## Audit FB_Bucket du jour [completed]

## 🎬 BRIEFING SESSION WORKFLOW PROJET / AGENTS.MD ACTIF
*Briefing session YGO Excavatrice — reprise par agent audit FB_Bucket T387.*

Audit terminé. Voici le rapport factuel (machine réelle, source de vérité = `CODE/*.st` versionné).

---

# 🔍 AUDIT T387 — FB_Bucket : fenêtre benne / gel timeout permis nul / cause 4 / WaitingForOperator

**Périmètre** : `git diff 8ec1fa28..708a0f44 -- CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` (T387 incorporé au checkpoint `708a0f44`, commit métier `dff0b535`).
**Question** : le gel du budget timeout quand permis nul peut-il (a) retarder `CloseReached`, (b) briser le raccordement AX10B → AX11 (continuité), (c) faire perdre `InterlockM2.MotorRequest` à AX11 ?

---

## 1. Résumé du diff — 6 hunks, 3 changements fonctionnels

| # | Position (lignes NEW) | Type | Contenu |
|---|---|---|---|
| H1 | `:78` | Décl. sortie | `WaitingForOperator : BOOL` (STAT) |
| H2 | `:110` | Décl. locale | `ClosePermitDeniedWhileRequested : BOOL` |
| H3 | `:233–240` | **Fonctionnel** | `IF ClosePermitDeniedWhileRequested THEN TimeoutEngaged := FALSE; END_IF` |
| H4 | `:292` | Commentaire | Cause 4 « non latchante, ne bloque pas le mouvement » |
| H5 | `:314` | **Fonctionnel** | `WaitingForOperator := Lifecycle.Busy AND CloseReq AND (NOT EffectivePermitBucket_Close)` |
| H6 | `:346` | Nettoyage | `WaitingForOperator := FALSE` en tête de bloc `IF NOT Enable OR NOT PowerContactorEngaged THEN` |

⚠️ Seul **H3** touche la logique de mouvement/timeout. H4 est un **commentaire pur** (le `Latching := FALSE` de la cause 4 existait déjà avant → aucune dérive fonctionnelle). H1/H5/H6 ne font que **publier** un état, sans rétroalimenter un verrou.

---

## 2. Analyse des hunks fonctionnels

### H3 — le gel du timeout (le seul point à risque)
```st
ClosePermitDeniedWhileRequested := CloseReq AND (NOT EffectivePermitBucket_Close);  // :237
IF ClosePermitDeniedWhileRequested THEN                                              // :238
    TimeoutEngaged := FALSE;                                                        // :239
END_IF;                                                                             // :240
```
- Condition d'activation **stricte** : `CloseReq=TRUE ET permis NUL`.
- Effet : `TimeoutEngaged` forcé à FALSE → le TON `TonTimeout` s'arrête → `TimeoutFaultLatched` (cause 2) ne latche pas.
- **Le vrai grippage (permis OK mais aucun mouvement) conserve `TimeoutEngaged`** → `ErrorID:03` latché (protégé, cf. commentaire `:235–236`). **Aucune régression de détection de panne.** ✅

### H5 — l'état publié
```st
WaitingForOperator := Lifecycle.Busy AND CloseReq AND (NOT EffectivePermitBucket_Close);  // :314
```
- Consommé PRG_04 `:1847` → `BucketWaitingForOperator`, **exclusivement observé IHM** (grep : uniquement décl `:23` + assign `:1847`). **Aucun verrou/interlock ne le lit.** ✅

### H6 — cleanup
```st
CloseReached := FALSE; CloseReq := FALSE; OpenReq := FALSE; WaitingForOperator := FALSE;  RETURN;  // :343–347
```
- Simple remise à zéro cohérente en état hors alimentation ; sans effet sur la logique nominale.

---

## 3. Tracé sur `CloseReached` et la continuité AX10 / AX10B

**CloseReached** (détection d'arrivée) — **NON touché par T387** :
```st
IF CablePosM2 >= (CablePosM1 + Config.OffsetCloseM - Config.CloseAnticipationM)
   OR instCloseThreshold.Reached THEN          // :639
    ...
    CloseReached := TRUE;                      // :650
```
La condition est purement **géométrique + seuil qualifié** (`:627–637`). Le hunk H3 n'agit que sur `TimeoutEngaged`/cause 2, jamais sur `CloseReached`. 

**Raccordement AX10B** (`:540–545`, HoldAscentP1AfterClose) :
```st
ELSIF Lifecycle.Busy AND CloseReached AND HoldAscentP1AfterClose THEN      // :540
    M2_RunRequest := MotionRequestActive AND ReqAscent AND EffectivePermitBucket_Close;  // :543
```
Point clé : **après `CloseReached`, `CloseReq := FALSE` (`:649`)** → dans la fenêtre AX10B/AX11, `CloseReq=TRUE` est **faux**, donc `ClosePermitDeniedWhileRequested` est **FALSE** → **H3 est inactif pendant tout le raccordement**. La fenêtre AX10B→AX11 ne subit **aucune** dérive par rapport à l'état pré-T387.

**Continuité M2 vers AX11** (chaîne) :
- `EffectivePermitBucket_Close` (`PRG_04 :1187–1191`) = `EffectivePermitM2_Ascent AND ... AND NOT instBucket.Fault.Error`.
- `M2AscentPermitApplied` (`:1195`) = `EffectivePermitM2_Ascent AND (NOT M2_RunRequest OR EffectivePermitBucket_Close)` → consommé en `AscentPermit` de `FB_WinchM2` (`:1599`) et du verrou final (`:1698`).

Le seul point où T387 touche cette chaîne : `NOT instBucket.Fault.Error`. Or H3 **empêche** un faux latch de `TimeoutFaultLatched` (cause 2) → il maintient `NOT Fault.Error = TRUE` → **protège** la continuité du permis, il ne la coupe pas.

---

## 4. Réponse ciblée à la question du gel timeout

**« Peut-il faire rester la benne busy plus longtemps / retarder CloseReached / gêner la reprise AX10B/AX11 ? »**

| Question | Réponse factuelle |
|---|---|
| Retarde-t-il `CloseReached` en situation nominale ? | **NON.** Si permis OK durant AX10, `ClosePermitDeniedWhileRequested=FALSE` → H3 n'agit jamais → comportement **identique à l'ancien** (verdict ci-dessous). |
| Peut-il prolonger l'état Busy ? | **OUI, mais uniquement dans le cas d'attente de permis** (CloseReq + permis nul). Avant T387, un permis nul prolongé faisait **latch ErrorID:03** au bout de `CfgTimeoutDuration` → arrêt + Reset. Après T387, la benne **attend indéfiniment** l'opérateur (état `WaitingForOperator`). C'est le **comportement voulu** du hunk, pas une perturbation. |
| Est-ce un danger physique ? | **NON.** Permis nul ⇒ `M2_RunRequest` **déjà FALSE** (`:550`, gated par permis) ⇒ **aucun mouvement commandé**, benne épinglée, IHM claire (`BucketWaitingForOperator`). C'est un **arrêt contrôlé**, pas une perte de commande. |
| Peut-il gêner AX10B/AX11 ? | **NON.** En AX10B, `CloseReq=FALSE` ⇒ H3 inactif ⇒ `TimeoutEngaged` strictement identique à l'avant-T387 dans toute la fenêtre du raccordement. |

**Changement de signature de défaut** (à connaître, non destructif) : en attente de permis longue, la machine passe de *« auto-défaut + Reset requis »* à *« attente opérateur (WaitingForOperator) »*. La reprise dépend donc d'une **action humaine** (débloquer le permis ou reset) ; sans action, la séquence reste en attente au palier de fermeture — mais c'est un **stop sûr, visible IHM, sans interruption de la commande M2 déjà servie** (AX11 n'est de toute façon pas atteignable tant que le permis est nul ; le blocage est **en amont**, à AX10).

---

## 5. 🔎 Verdict de probabilité

> **Probabilité d'impact sur la perte de `InterlockM2.MotorRequest` à AX11 : 🟢 BASSE (LOW).**

Justification en 4 points factuels :
1. **H3 n'agit jamais en nominal ni en AX10B** : conditionnné par `CloseReq AND NOT EffectivePermitBucket_Close`, or en AX10B `CloseReq=FALSE`. Aucune dérive possible dans la fenêtre AX10B→AX11.
2. **Aucun chemin vers une coupe M2** : H3 ne modifie ni `M2_RunRequest`, ni `CloseReached`, ni `EffectivePermitM2_Ascent`, ni `M2AscentPermitApplied`. Le seul lien (`NOT instBucket.Fault.Error`) est **protégé**, pas coupé.
3. **`WaitingForOperator` est observationnel** : consommé uniquement par l'IHM, jamais par un verrou ou la barrière finale.
4. **L'extension de durée Busy n'est pas une perte de commande** : permis nul = pas de consigne servie = stop sûr, non coupure. Le « plus longtemps busy » est l'état `WaitingForOperator` voulu.

**Réserve résiduelle (qualitative, non bloquante)** : en supprimant le filet de sécurité qu'était le timeout en attente de permis, T387 dépend plus de l'action opérateur pour débloquer une séquence bloquée par permis nul. Risque **process/humain**, pas interlock ; à couvrir par supervision du séquenceur si l'on veut un filet. **Aucune action corrective obligatoire sur le code à ce stade.**

---

**Rappel réglementaire (AGENTS.md)** : ceci est un **audit/documentaire**, aucun `CODE/*.st` n'a été modifié → pas de bundle/gates requis. Aucune édition effectuée dans cette session.

## Audit modifs non committées [completed]

J'ai tous les éléments factuels. Voici le rapport d'audit.

---

# 🔒 Audit sécurité — Bypass MécaB par défaut (working tree non committé)

**Contexte** : diagnostic perte de `InterlockM2.MotorRequest` à AX11. **Deux modifs NON COMMITTÉES** neutralisent la cause **MécaB** (absence de confirmation d'arrêt contacteurs/frein) par défaut, pour **M1 (Treuil Retenue)** et **M2 (Treuil Benne)**.

---

## 1️⃣ Diff NON COMMITTÉ (working tree vs HEAD)

### `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_BypassWinch.st` — ligne 30

```diff
     (* ⚙️ 3. Sécurité Mécanique (Méca A-E) *)
     MecaA             : BOOL; (* 🔄 Bypass Méca A : mouvement non commandé à l'arrêt *)
-    MecaB             : BOOL; (* 🛑 Bypass Méca B : absence confirmation arrêt (frein/contacteurs) *)
+    MecaB             : BOOL := TRUE; (* 🛑 Bypass Méca B : absence confirmation arrêt (frein/contacteurs) *)
     MecaC             : BOOL; (* 🏋️ Bypass Méca C : glissement de charge (benne M1) *)
```

**Initialiseur par défaut `:= TRUE`** sur le DUT struct : **tout** treuil créé depuis cette struct démarre avec MécaB **déjà bypasse**, sans aucun appui exploitant.

### `CODE/M_MAIN/PRG_07_Supervision.st` — lignes 291 & 299 (à l'initialisation des deux bypass)

```diff
 IF NOT GVL_IHM.M1TreuilRetenue.Bypass.Initialized THEN
     IF BypassWinchM1Global THEN
         GVL_IHM.M1TreuilRetenue.Bypass.Global := TRUE;
     END_IF;
+    GVL_IHM.M1TreuilRetenue.Bypass.MecaB := TRUE;
     GVL_IHM.M1TreuilRetenue.Bypass.Initialized := TRUE;
 END_IF;
```

```diff
 IF NOT GVL_IHM.M2TreuilBenne.Bypass.Initialized THEN
     IF BypassWinchM2Global THEN
         GVL_IHM.M2TreuilBenne.Bypass.Global := TRUE;
     END_IF;
+    GVL_IHM.M2TreuilBenne.Bypass.MecaB := TRUE;
     GVL_IHM.M2TreuilBenne.Bypass.Initialized := TRUE;
 END_IF;
```

**Double blindage** : même si l'initialiseur struct était corrigé, `PRG_07` réécrit `MecaB := TRUE` à chaque première exécution après écrasement de la GVL_IHM (réarmement, restauration, première montée). La neutralisation est **systématique et auto-réappliquée**.

📌 D'autres fichiers working tree sont modifiés (bundles XML cohérents avec le ST, 2 registres, rapports CI) → cohérents, pas d'écart. Fichiers cibles : mtime **22/09/2026 16:51–16:52**.

---

## 2️⃣ Ce que la détection MécaB protège — `FB_Safety_Winch.st` (cause 8, bit8, latched)

Ligne 346–349 :
```st
// Cause 8 : Méca B absence confirmation arrêt (latched)
IF NOT (BypassSafety OR BypassMecaB) THEN
    UncommandedActiveB := NOT MovementCommanded AND NOT BenneHoldStillActive
                        AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
    TonMecaB(IN := UncommandedActiveB, PT := PostRampTimeout);   // PT = 3 s
    IF TonMecaB.Q THEN MecaBFaultLatched := TRUE; END_IF;
ELSE
    TonMecaB(IN := FALSE);
END_IF;
```

**Ce que protège MécaB** — c'est la **preuve de l'arrêt physique réel** après une commande d'arrêt :
- 🚫 **Aucune commande de mouvement** n'est active (`NOT MovementCommanded`).
- 🚫 La benne n'est pas en maintiens actif (`NOT BenneHoldStillActive`).
- ❗ **On exige la confirmation électromécanique** que l'axe est réellement arrêté : `FwdRevSpeedFeedbackOff` **ET** `BrakeFeedback NOT` (frein appliqué = retombé).
- ⏱️ Si, **3 s après l'arrêt demandé** (`PostRampTimeout`), les contacteurs ne sont pas retombés **ou** le frein n'est pas appliqué → **MecaBFaultLatched := TRUE** (latché, `Latching := TRUE`, rearmement uniquement sur `Reset` sur front + cause disparue).

**Sémantique de la condition d'arrêt confirmé** `NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback)` :
- La confirmation n'est bonne **que si** vitesse nulle **ET** frein fermé.
- Donc MécaB déclenche si : le variateur tourne encore (vitesse non nulle) **ou** le frein reste ouvert (levier pas retombé / contacteur de confirmation absent).

**Impact de la neutralisation** dans la chaîne aval (`FB_Safety_Winch.st` lignes 490, 508, 522–531) :
- `ContactorStuck := MecaBFaultLatched` → **détection de contacteur collé** également neutralisée.
- `CauseMecaBActive` alimente à la fois `CausesSafeStopActive` **et** `CausesPowerCutOffActive` → l'**AU / coupure puissance** ne part plus sur cette cause.

**Risque couvert par la détection (ce qu'on perd en la bypassant)** :
| Phénomène | Protégé par MécaB ? |
|---|---|
| **Mouvement non commandé résiduel après commande d'arrêt** (rampe qui ne finit pas, entraînement qui "flotte") | ✅ OUI — c'est le cœur |
| **Absence de confirmation de retour** (contacteur de confirmation frein/contacteurs défaillant) | ✅ OUI |
| **Frein qui ne retombe pas** (contacteur de frein reste ouvert, ou confirmation pas renvoyée) | ✅ OUI — danger de chute de charge suspendue |
| **Contacteur de puissance collé/colle** (`ContactorStuck`) | ✅ OUI |
| Patinage / glissement de charge (benne) | ❌ **NON** — c'est Méca C (`DriftGuardC`, cause 9) |
| Dérive à l'arrêt | ❌ **NON** — c'est Méca A (cause 7) |

> ⚠️ MécaB n'est **pas** la détection de patinage (c'est Méca C). Mais MécaB et le patinage **partagent la même exigence** : que l'axe soit réellement immobilisé frein appliqué quand aucune commande n'ordonne de mouvement.

---

## 3️⃣ Date / commit de création du vrai défaut

```
git log --all --oneline -S 'MecaB := TRUE' -- CODE/M_MAIN/PRG_07_Supervision.st CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_BypassWinch.st
→ VIDE (aucun commit)
```

- 🔍 **`MecaB := TRUE` sur les 2 fichiers cibles n'existe dans AUCUN commit** de l'historique complet (`--all`). La modif est **100 % working tree UNCOMMITTED**.
- Le seul commit matché (`cc682aa6`, 2026-09-20 15:48, Mathieu Gros) est un **faux positif** : il n'ajoute `ErrorMecaB := TRUE` que dans un **test de bandeau IHM** (`BRIEF_T375`), pas dans le bypass.
- ✅ **Commited base** : `HEAD` a `MecaB : BOOL;` (sans initialiseur, ligne 30) et **aucune ligne `MecaB`** dans `PRG_07`.

**Conclusion (point 4)** : le bypass n'est **pas antérieur** — il est introduit **aujourd'hui** (mtime 22/09/2026 16:51–16:52), c'est-à-dire **pendant la campagne d'essai du 22/09**, en même temps que le ré-exécution CI à 16:51. **Il n'y a pas de "vrai défaut" committé plus tôt : la neutralisation elle-même est la modif non committée du jour.**

---

## 4️⃣ Avis — le bypass MécaB masque-t-il la cause de la coupure à AX11 ?

**Verdict : 🔴 HAUTE probabilité que le bypass de la cause MécaB ait été activé pour contourner un défaut MécaB réel, et qu'il masque la coupure de `InterlockM2.MotorRequest` à AX11.**

### Preuves factuelles (lignes exactes) :

1. **Registre `REGISTRE_Suivi_MiseEnService_20260921.md`** (modifié aujourd'hui, entrée `2026-09-22`) :
   > « Essai du jour, `BypassMecaB` **actif** — **Sans le bypass : erreur MecaB systématique** ("absence confirmation arrêt contacteurs/frein", `FB_Safety_Winch.st`, cause 8, latched) — **bloque l'essai** … **NON TRANCHÉ — bypass utilisé faute d'alternative, cause racine non identifiée** »

   → **Admis par écrit** : le bypass sert à faire passer un essai qui sinon déclenche MécaB en permanence. C'est exactement le scénario de **masquage** d'une cause.

2. **`FB_Hmi_BannerFormatter.st:549-568`** : la voie MécaB produit `[M1]/[M2]/[M3] MecaB (arrêt non confirmé)` et `ErrorID:09`. Le message est **non qualifié** (on ne sait pas si c'est contacteur ou frein) — l'orchestrateur le note lui-même dans le registre.

3. **Gravité de la perte à AX11** : `MecaB` alimente `CausesPowerCutOffActive`. Neutraliser la confirmation d'arrêt **par défaut** signifie que, sur l'automate, un **retour de confirmation d'arrêt absent/faux est ignoré** → la protection machine ne s'oppose plus à `MotorRequest` lorsqu'il n'y a pas de preuve d'arrêt. Sur un treuil de benne **suspendue** (charge grave), c'est une perte de barrière de sécurité ISO 13849.

### Deux lectures possibles (à trancher par l'exploitant, non tranchées dans le working tree) :
| Hypothèse | Implication | Risque |
|---|---|---|
| **1. Faux positif logiciel** : `PostRampTimeout`=3 s trop court, ou retour DI `M1/M2 (…)Released_DI` / `BrakeIsOpen_DI` mal câblé/lent | Correctif logiciel/câblage à qualifier — **cause = wiring/param**, pas la mécanique | Moyen |
| **2. Vrai défaut mécanique** : contacteurs ou frein qui **ne retombent pas** dans les temps (collage, ressorts, hydraulique de frein) | **Le bypass masque un risque réel** de chute de charge / mouvement résiduel → l'essai **ne doit pas être considéré validant** | 🔴 Élevé |

### Conclusion d'audit
- Le bypass MécaB par défaut (struct `:= TRUE` **+** ré-initialisation dans `PRG_07`) est un **contournement de sécurité actif par défaut**, sans garde d'appui conscient ni trace de causalité.
- Il **masque la cause réelle** de la coupure à AX11 (absence de confirmation d'arrêt contacteur/frein latched) : tant qu'il est actif, on ne peut **pas** observer le défaut MécaB, donc on ne peut pas savoir si la coupure vient d'un vrai non-retombé de contacteur/frein ou d'un câblage/tempo.
- ⚠️ **Alerte sécurité factuelle** : je recommande (i) de **retirer** les 2 lignes `PRG_07` et l'initialiseur `:= TRUE`, (ii) de **ne plus réécrire `MecaB := TRUE`** par défaut, (iii) de **qualifier le retour réel de confirmation** (contacteur de frein vs retombée de contacteur de puissance) avant tout nouvel essai, conformément aux règles projet `Enable > SafeStop > StartStop` et « jamais de redémarrage auto après défaut ».

---

## 📋 Synthèse

| Point | Résultat |
|---|---|
| Files modifiés (working tree) | `ST_BypassWinch.st:30`, `PRG_07_Supervision.st:291,299` |
| Nature | Bypass **MécaB** (absence confirmation arrêt frein/contacteurs) **par défaut** |
| Création | **Uniquement aujourd'hui (22/09 16:51)**, ZÉRO commit antérieur sur ces fichiers |
| Ce que ça désactive | Confirmation d'arrêt réel + `ContactorStuck` + contribution à SafeStop & PowerCutOff |
| Masque-t-il la cause AX11 ? | 🔴 **HAUTE probabilité OUI** (admis dans le registre : bypass utilisé car MécaB bloquait l'essai) |
| Action recommandée | Retirer le bypass par défaut + qualifier le retour de confirmation (contacteur vs frein) avant essai |

## summary

编排完成，共 5 个子任务：
- Audit FB_Safety_Winch du jour [completed]: J'ai toutes les preuves. Voici le rapport d'audit.

---

# 🔍 Audit PLC — Perte de `MotorRequest` M2 à l'étape AX11 (2026-09-22)

## ⚠️ Bannière briefing agent

```text
============================================================
🎬 BRIEFING SESSION WORKFLOW PROJET / AGENTS.MD ACTIF
============================================================
Mode : Dépannage / Traçage inverse (skill `troubleshooting`)
Objet : modif FB_Safety_Winch du 22/09 → coupure M2 en AX11 ?
Machine : Excavatrice de dragage RÉELLE — rester factuel, citer les lignes.
============================================================
```

**Verdict court (détails plus bas)** : la piste crédible est la **Cause 8 MécaB** (`JoystickYNeutral` → `NOT MovementCommanded`). La **`BucketCloseAscentGrant` ne peut PAS couper M2 à AX11** (elle ne relaxe que la butée basse→haute et vaut `FALSE` à AX11). Probabilité que la modif du jour **soit** la cause directe de la coupure : **MOYENNE** — avec un doute franc à formuler (voir §5).

---

## 1. Diff exact du jour (`8ec1fa28..708a0f44`)

Commit matin `8ec1fa28` = **2026-09-22 00:14** (`Backup Chekpoi,nt`).
Commit soir `708a0f44` = **2026-09-22 14:55** (`wip(project): checkpoint qsave`).

```diff
--- a/CODE/H_TREUILS_BENNE/FB_Safety_Winch.st
+++ b/CODE/H_TREUILS_BENNE/FB_Safety_Winch.st
@@ -35,6 +35,12 @@ VAR_INPUT
     BenneHoldStillActive            : BOOL;
     BenneBusy                       : BOOL;
     OtherWinchInhibited             : BOOL;
+    BucketCloseAscentGrant          : BOOL := FALSE;   // Relaxe la butee haut MATERIELLE M2 sous fenetre benne (4 verrous)

@@ -338,7 +344,7 @@ IF NOT BypassGlobal THEN
     // Cause 8 : Méca B absence confirmation arrêt (latched)
     IF NOT (BypassSafety OR BypassMecaB) THEN
-        UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
+        UncommandedActiveB := NOT MovementCommanded AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
         TonMecaB(IN := UncommandedActiveB, PT := PostRampTimeout);
         IF TonMecaB.Q THEN MecaBFaultLatched := TRUE; END_IF;

@@ -572,9 +578,16 @@ AscentPermit := NOT (
     ((CauseTopLimitSwitchActive
     OR (NOT TopPositionSensor AND NOT InReferencingMode))
-    AND NOT BypassTopLimitSwitch)
+    AND NOT BypassTopLimitSwitch
+    AND NOT BucketCloseAscentGrant)
     OR (Homed AND NOT HomingSuspect AND NOT InReferencingMode AND (CablePosM >= TopLimitM) AND NOT (BypassGlobal OR BypassTopLimitSoftware))
 );
```

**3 modifications :**
- Déclaration `BucketCloseAscentGrant` (FB_Safety_Winch.st:38-43), câblée `FALSE` sur M1 / vraie valeur sur M2 dans PRG_04.
- **Cause 8 MécaB** : gate `JoystickYNeutral` → `NOT MovementCommanded` (FB_Safety_Winch.st:347).
- **AscentPermit** : `AND NOT BucketCloseAscentGrant` sur le premier groupe (FdC haut capteur) (FB_Safety_Winch.st:590).

---

## 2. Analyse ligne à ligne (Cause 8 MécaB) — avant / après

**Avant** (committé matin) :
```st
UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
```
**Après** (committé soir, ligne 347) :
```st
UncommandedActiveB := NOT MovementCommanded AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
```

Définitions câblées dans `PRG_04_Treuils_Benne.st` :
- M2 `JoystickYNeutral := (PRG_02_Acquisition.Data.Joystick.AxisY.Direction = 0)` — **ligne 1090**. C'est la **position physique du manche de l'opérateur**, indépendante de la commande logique.
- M2 `MovementCommanded := instWinchM2.RelayFwd OR instWinchM2.RelayRev` — **ligne 1084**. C'est la **demande de relais SORTIE de FB_Winch** (le signal que le programme émet réellement).

### ✍️ Ce que change exactement la fenêtre de détection

| Condition | Ancien gate `JoystickYNeutral` | Nouveau gate `NOT MovementCommanded` |
|---|---|---|
| Fenêtre pilotée par | position **physique du manche** (opérateur) | **relais de commande** émis par FB_Winch |
| Joystick tenu, montée commandée (relais ON) | `FALSE` → **MecaB désarmé** | `NOT(FALSE)=FALSE` → **MecaB désarmé** (identique) |
| Joystick neutre AUTOMATIQUE, montée commandée (relais ON) | `TRUE` → **MecaB armé** (faux positif possible) | `FALSE` → **désarmé** ✅ |
| **Joystick tenu, relais coupé, machine ENCORE EN MOUVEMENT (>3 s)** | `FALSE` → **MecaB désarmé** (trou) | `TRUE` → **MecaB armé, peut latcher** ⚠️ |

**Interprétation technique** : on passe d'une fenêtre définie « par le levier physique, découplée de la vraie commande » à une fenêtre « par la vraie demande de relais ». C'est conceptuellement **plus juste** pour « mouvement non commandé » (on teste la commande réelle, pas la main de l'opérateur). C'est une **correctif** dans le sens « commande émise mais non confirmée ».

**MAIS** il introduit une **boucle de rétroaction (couplage)** : `MovementCommanded` lit `instWinchM2.RelayFwd/RelayRev`, qui sont **précisément les sorties que SafeStop coupe** (FB_Winch.st:216 → ligne 285-293). Dès qu'un SafeStop (de n'importe quelle cause) fait retomber le relais, `NOT MovementCommanded` devient `TRUE`, ce qui **arme MecaB**. Si le treuil réel n'a pas confirmé l'arrêt dans `PostRampTimeout = T#3s` (ligne 55), MecaB **latche et maintient le SafeStop de façon permanente**. L'ancien code masquait ce cas tant que l'opérateur tenait le manche.

> **Conséquence en AX11** : à AX11 l'opérateur **tient le manche tiré** (`FB_CycleSemiAuto.st:1222` « AX11 - Maintenir la montee » ; `:1391` « Maintenir la montee » ; étape `E_AutoCycleStep.AX10_WAIT` « joystick tire maintenu »). Donc **l'ancien MecaB était structurellement OFF en AX11** (JoystickYNeutral=FALSE), quel que soit l'état réel du treuil. Le nouveau code réarme cette surveillance en AX11 — utile en théorie, mais il **supprime l'aveuglement antérieur** qui, par malchance, protégeait l'AX11 du latch.

---

## 3. Chaîne MécaB → SafeStop → `instWinchM2` → barrière → `MotorRequest`

Chaîne exacte, lignes numérotées :

**① Déclenchement MecaB (FB_Safety_Winch.st)**
1. `UncommandedActiveB` (ligne 347) → `TonMecaB(..., PT := PostRampTimeout/*3 s*/)` (ligne 348) → `TonMecaB.Q` → `MecaBFaultLatched := TRUE` (ligne 349).
2. `MecaBFaultLatched` → `instCauses[8].Active` (lignes 354-355) → `CauseMecaBActive` (ligne 508).
3. `CauseMecaBActive` ∈ `CausesSafeStopActive` (**ligne 524**) **et** ∈ `CausesPowerCutOffActive` (**ligne 530**).

**② Arbitrage sorties (FB_Safety_Winch.st)**
4. `SafeStop := CausesSafeStopActive OR (SyncEnable AND CauseSlackCableActive) OR OverspeedFaultLatched;` (**lignes 564-566**).
5. `PowerCutOff := CausesPowerCutOffActive;` (**ligne 597**) — ⚠️ MecaB déclenche AUSSI la coupure puissance, pas seulement un rampe.

**③ Agrégation PRG_04 (PRG_04_Treuils_Benne.st)**
6. `SafeStopM2_Raw := SafeStopM2_Raw OR instSafetyWinchM2.SafeStop;` (ligne 1127).
7. `SafeStopM2_Active := SafeStopM2_Raw OR (CoupledBoth AND SafeStopM1_Raw);` (**ligne 1170**).
8. `EffectivePermitM2_Ascent := ProcessAndSafetyPermitM2_Ascent AND NOT SafeStopM2_Active ...` (**ligne 1178**) → `M2AscentPermitApplied` (lignes 1195-1196).

**④ Câblage `instWinchM2` (PRG_04_Treuils_Benne.st)**
9. `instWinchM2(SafeStop := SafeStopM2_Active, AscentPermit := M2AscentPermitApplied, DescendPermit := ...)` (**lignes 1597-1599**).

**⑤ FB_Winch coupe la demande (FB_Winch.st)**
10. `EffectiveSafeStop := SafeStop OR DirectionConflict OR (ReqAscent AND NOT AscentPermit) OR (ReqDescend AND NOT DescendPermit);` (**lignes 169-171**).
11. `IF ... OR EffectiveSafeStop ... THEN RampTargetStep := 0;` (**ligne 216**) → `StepNumber := 0` (ligne 281) → `RelayFwd:=FALSE; RelayRev:=FALSE;` (lignes 291-292).

**⑥ Rétroaction de la barrière finale (PRG_04 + FB_WinchOutputInterlock)**
12. `WinchM2FinalInterlockRequest.RequestedRelayFwd := instWinchM2.RelayFwd;` (ligne 1690) ; `RequestedRelayRev` (1691) ; `RequestedStep := instWinchM2.StepNumber;` (**ligne 1696**).
13. Barrière : `MotorRequest := (RequestedStepClampe
- Audit PRG_04 du jour [completed]: J'ai maintenant tous les éléments factuels. Je rédige le rapport d'audit.

---

# 🔍 AUDIT DIFF 2026‑09‑22 — `PRG_04_Treuils_Benne.st` → impact sur `InterlockM2.MotorRequest` à AX11

**Comparaison** : `8ec1fa28` (2026‑09‑22 00:14, checkpoint) → `708a0f44` (2026‑09‑22 14:55, checkpoint qsave). Le lot effectif est **`dff0b535` « T387 – fenêtre benne, bornes relatives sans datum et alarme codeurs homing »** (14:54:50). Toute la journée porte sur la **fenêtre benne** (fermeture AUTO au FDC haut) et le bridage homing.

> ⚠️ **Constat n°1 — le bloc « Défense en profondeur » (lignes 1731–1748) n'est PAS modifié dans ce diff.** Il est **préexistant**. La neutralisation `RequestedRelay/Step := 0` en `SEMI_AUTO AND WinchBothMotionActive AND (NOT WinchBothMotionReady OR NOT WinchBothFinalRequestsCoherent)` est donc un *symptôme*, pas une modif du jour. La vraie question est : un hunk du jour peut‑il rendre `WinchBothMotionReady=FALSE` ou `WinchBothFinalRequestsCoherent=FALSE` **à AX11** ?

---

## 📋 Inventaire des hunks du jour

| # | Hunks (lignes diff) | Variables/mécanismes touchés | Portée |
|---|---|---|---|
| H1 | `@15` VAR_OUTPUT | `BucketWaitingForOperator` (déclaration + pub §8 `@1843`) | Sortie IHM diag | 
| H2 | `@210` VAR | `AutoBucketCloseActiveForTopLimit`, `BucketFenetreWindow`, `BucketM1HeldCheck`, `BucketM1NotAscent`, `BucketCloseNotReached`, `BucketCloseAscentGrant` (déclarations) | Fenêtre benne AUTO |
| H3 | `@786` `ManualBucketLimitsActive` | **ajoute** `AND EncoderM1.HomedAndReliable AND EncoderM2.HomedAndReliable` | Jog benne unitaire |
| H4 | `@823` `M2JogApproachOpen/Close` | **ajoute** `AND ManualBucketLimitsActive` | Jog benne unitaire |
| H5 | `@908→930` `TopLimitM2_M` | Exemption étendue à `AutoBucketCloseActiveForTopLimit` + garde homed | Fermeture AUTO / jog benne |
| H6 | `@950→976` | `BucketCloseAscentGrant` (4 verrous) | Relâche butée **matérielle** M2 en fermeture AUTO |
| H7 | `@1046/1116` instSafety | `BucketCloseAscentGrant:=FALSE` (M1) / `:=grant` (M2) | Paramétrage FB_Safety_Winch |
| H8 | `@1309→1312` **Cycle homing machine** | `IF MachineHoming.Active THEN CommonMaxStepAscent:=1; CommonMaxStepDescent:=1` | **Commun M1+M2, touche la montée couplée** |
| H9 | `@1843` | `BucketWaitingForOperator` (pub) | Sortie IHM | 

---

## 🎯 Corrélation avec les variables cibles

| Variable cible | Touchée ce jour ? | Détail |
|---|---|---|
| `WinchBothMotionReady` (1475, 1611) | **NON** | `NOT DirectionChangePending M1/M2 AND NOT Fault.Latched M1/M2` — aucun hunk ne modifie ces sources |
| `WinchBothFinalRequestsCoherent` (1718) | **NON** | Égalité RequestedRelay/Contacteurs/Step M1=M2 — la logique elle‑même n'est pas touchée |
| `WinchBothMotionActive` (304) | NON | Non modifié |
| `ReqM2Winch.*` (1543–1562) | NON (direct) | La struct M2 est réécrite tel quel ; **`TopLimitM2_M`** alimenté par H5 |
| `CommonMaxStepAscent` (1290) | **OUI (H8)** | Nouveau plafond strict `:=1` si `MachineHoming.Active` |
| `M2MaxStepUp` (1363) | Hérite de H8 | `M2MaxStepUp := CommonMaxStepAscent` puis surcharge benne (non activée en montée couplée) |
| `TopLimitM1_M` (905) | NON | Intact |
| `TopLimitM2_M` (908) | **OUI (H5)** | Exemption relative + `+2.0` — **mais conditionnée à jog benne / fermeture AUTO** |
| `SafeStopM1/M2_Active` (1169–1170) | NON (direct) | Agrège instSafety + couplage ; H6/H7 modifient le permis ascent, pas le SafeStop |
| `M2AscentPermitApplied` (1195) | NON (direct) | hérite de `EffectivePermitM2_Ascent` ; H6/H7 agissent sur `SafeStop`/permit **uniquement sous fenêtre benne** |

---

## 🔬 Analyse mécanistique — chaque hunk à AX11 (montée contrôlée P1/P2 couplée)

### Clé de lecture : qu'est‑ce qui est VRAI à AX11 ?
- `Mode = SEMI_AUTO` ✅ , `SequenceState.Step = AX11_CTRL_ASCENT`, `WinchBothMotionActive=TRUE`.
- **`ReqBucket.ReqClose = FALSE` à AX11** : posé à `FALSE` par défaut en AX10B (`FB_CycleSemiAuto.st:1348`) et **jamais re‑déclaré TRUE en AX11** (ligne 1381+). C'est la prémisse qui **verrouille tout le lot T387 hors d'AX11**.
- `ManualBucketJogActive = FALSE` : exige `JoystickWinchSelectArbitrated = 2` (unitaire benne), or AX11 est une montée couplée (selection arbitrée `0`).

### H1, H2, H9 — déclarations + sortie IHM
🔵 **FAIBLE.** Aucune logique de commande. `BucketWaitingForOperator` est une ré‑agrégation de lecture seule.

### H3, H4 — gating jog benne par `HomedAndReliable`
🔵 **FAIBLE.** `ManualBucketLimitsActive`, `M2JogApproachOpen/Close` ne servent **que** le jog benne unitaire (WinchSel=2). **Hors périmètre AX11.** La règle produit « on ne borne JAMAIS la benne si M1/M2 non homed » (commit `01b5e991`) est sans effet sur une montée couplée.

### H5 — `TopLimitM2_M` exemption étendue
🔵 **FAIBLE pour AX11.** La branche `TopLimitM2_M := M1_CablePosM + OffsetCloseM + 2.0` ne s'exécute que si `(ManualBucketJogActive OR AutoBucketCloseActiveForTopLimit)`. 
- `ManualBucketJogActive = FALSE` à AX11.
- `AutoBucketCloseActiveForTopLimit := instBucket.Lifecycle.Busy AND ReqClose`. À AX11 `ReqClose=FALSE` → **`FALSE`** → la branche est INACTIVE.
- À AX11 on tombe dans le `ELSIF WinchBothMotionActive` préexistant : `TopLimitM2_M = CfgCableLimitAscent_M + M2_LimitShift + 0.50` — **inchangé** par le diff.
- Impact : **aucun sur le plafond/RequestedStep de M2 à AX11**. Risque résiduel si `ReqClose` devenait TRUE par défaut (scénario anormal), voir verdict.

### H6 + H7 — `BucketCloseAscentGrant` (relâche butée **matérielle** M2)
🔵 **FAIBLE pour AX11.** Le grant exige `BucketFenetreWindow := instBucket.Busy AND ReqClose` → **FALSE à AX11** (ReqClose=FALSE) → `grant = FALSE` → **la butée matérielle M2 reste active**, aucun Bypass réutilisé. Câblé **FALSE sur M1** (barrière M1 jamais relâchée → `SafeStopM1` intact). Ce mécanisme est confiné à la **fermeture AUTO** (AX10), hors montée couplée.

### H8 — ⭐ **Cycle homing machine : palier 1 MAX strict (lignes 1312–1316)**
🔴 **C'est le SEUL hunk qui agit sur le canal commun M1+M2 de la montée couplée.**
```st
IF PRG_02_Acquisition.Data.MachineHoming.Active THEN
    CommonMaxStepAscent  := 1;
    CommonMaxStepDescent := 1;
END_IF;
```
- S'il s'applique **pendant AX11**, `CommonMaxStepAscent:=1` → `M2MaxStepUp:=1` **et** `ReqM1Winch.MaxStepUp:=1`. Les **deux** treuils plafonnent à P1.
- **Effet : bridage de vitesse** (P1 max), **PAS une mise à 0 de RequestedStep**. Et parce qu'il bride **M1 ET M2 symétriquement**, il préserve `WinchBothFinalRequestsCoherent` (M1=P1, M2=P1 → cohérent) et donc ne déclenche **pas** le bloc Défense en profondeur.
- ⚠️ Toutefois : `MachineHoming.Active` est TRUE pendant le **cycle homing machine complet (HX1..HX6)**, exécuté en mode MAINT/commissioning — **normalement jamais simultané avec un cycle semi‑auto AX11**. L'activation pendant AX11 impliquerait une **incohérence de séquence** (homing déclenché pendant qu'un cycle semi‑auto tourne), déjà surveillée par `FB_Modes:161 SemiAutoCycleNotReadyMachineHoming` (blocage de sélection si `NOT MachineHomed`).

---

## ✅ Réponse à la question 5 — le diff peut‑il faire tomber RequestedStep M2 à 0 / `WinchBothMotionReady`→FALSE à AX11 ?

**Non en conditions nominales.** Tous les mécanismes T387 (`AutoBucketCloseActiveForTopLimit`, `BucketCloseAscentGrant`, `ManualBucketLimitsActive`) sont **verrouillés hors d'AX11** par la seule prémisse `ReqClose=FALSE` à AX11. `WinchBothMotionReady` et `WinchBothFinalRequestsCoherent` ne sont **pas modifiés** par le diff.

**Scénario crédible unique (H8)** : si `MachineHoming.Active` était TRUE pendant AX11 (état anormal), les deux treuils sont bridés à P1 — bridage symétrique, cohérent, **sans neutralisation finale**. Donc même ce cas ne casse pas `InterlockM2*`.

---

## ⚖️ Verdict de probabilité

| Mécanisme de perte supposé | Verdict |
|---|---|
| `RequestedStep M2 → 0` causé par un hunk du jour à AX11 nominal | 🔵 **BASSE** — aucun hunk ne met M2 à 0 ; les mécanismes T387 sont exclus car `ReqClose=FALSE` |
| `WinchBothMotionReady → FALSE` causé par le diff à AX11 | �
- Audit FB_CycleSemiAuto du jour [completed]: # 📋 Audit T383 — Coupure M2 à AX11 sur FB_CycleSemiAuto

## 1. Diff du jour — `8ec1fa28..708a0f44`

Commit du jour : `0358c631` — *« feat(cycle,ihm,outillage): T383 - micro-step benne decharge AX15D (23), retrait saut non declare AX15B->AX10, amendement GEL, garde-fous G517/G523 [NON TESTE MACHINE] »*

## 2. Liste des hunks (8 au total, tous hors zone AX10-AX11)

| Hunk | Lignes (cible) | Contenu |
|---|---|---|
| 1 | `-282/+282,10` | `CST_StepForceMax` 22→23 + commentaire enum |
| 2 | `-470/+470,10` | `instCauses[1]` : ajout exclusion sync `AX15D` |
| 3 | `-736/+739,7` | Commentaire plage `[0..22]`→`[0..23]` |
| 4 | `-768/+771,7` | CASE force-step : ajout `case 23` = `AX15D` |
| 5 | `-794/+798,7` | Message rejet « 0..23 » |
| 6 | `-1541/+1545,7` | Texte `OperatorAction` AX15B |
| 7 | `-1553/+1557,15` | **AX15B** : retrait du saut `AX15B→AX10`, remplacé par `→AX15D` |
| 8 | `-1574/+1573,44` | **Nouveau bloc** `E_AutoCycleStep.AX15D_DUMP_BUCKET_JOG` |

## 3. Zone AX10–AX11 (~1301–1409) — ✅ CONFIRMÉE NON MODIFIÉE

Aucun hunk du diff ne touche les lignes 1301–1409. Lecture directe de la cible `708a0f44` :

- **`AX10_CLOSE_BUCKET`** (1301–1329) : intact — neutralise M1/M2, `ReqOpen:=FALSE`, transition `→AX10B` ligne 1328 inchangée.
- **`AX10B_RACCORDEMENT_P1`** (1331–1379) : intact — transfert atomique M1/M2 P1/P1, transitions `→AX11` lignes 1369 & 1377 inchangées.
- **`AX11_CTRL_ASCENT`** (1381–1411) : intact — commandes montée, transition `→AX12` sur distance + `NOT WinchSyncError` inchangée.

**Continuité AX10→AX10B→AX11 100 % préservée.** T383 n'altère en rien le chemin nominal.

## 4. AX15D + retrait du saut AX15B→AX10 — ✅ HORS ZONE

Tout se situe lignes **1538–1612** (blocs `AX15B` et `AX15D_DUMP_BUCKET_JOG`), soit à ~**130 lignes après** la fin de la zone AX10-AX11 (~1411). Confirmation topologique : le retrait du saut (ligne 1568 `State := AX15D`) et le nouveau bloc (1576–1612) sont strictement dans la phase **vidage** (AX15).

## 5. Exclusion de synchronisme `instCauses[1]` (467–476) — ✅ AUCUN EFFET sur AX10/AX11

```st
467: instCauses[1].Active := WinchSyncError
468:   AND (State <> AX0_REPOS) ...
470:   AND (State <> AX8_BOTTOM_CONFIRMED)
471:   AND (State <> AX9_RAISE_OFF_BOTTOM)
472:   AND (State <> AX10_CLOSE_BUCKET)      ← déjà présent avant T383
473:   AND (State <> AX11_CTRL_ASCENT)       ← déjà présent avant T383 (inchangé)
476:   AND (State <> AX15D_DUMP_BUCKET_JOG); ← SEUL ajout T383
```

Le diff **ajoute uniquement la ligne 476**. Les exclusions AX10 (472) et AX11 (473) figuraient déjà et restent **strictement identiques**. La surveillance de synchronisme des treuils pendant AX10/AX11 est donc **inchangée**. L'exclusion AX11 du *défaut vitesse confirmé* (`instCauses[5]`, 494–495) n'est pas touchée non plus.

⚠️ Note sécurité : AX15D est désormais exclu du repli sync (fenêtre de purge étendue au vidage, « identique à AX10 »). Cela concerne la **phase tremie**, sans aucun lien avec AX11.

## 6. Bloc force-step — ✅ NE PEUT PAS écrire AX10→AX11

- `CST_StepForceMax` 22→23 (ligne 285) : étend la plage coercible de 1 seul membre (`AX15D`).
- `case 23` (ligne 774) pointe **uniquement** vers `AX15D_DUMP_BUCKET_JOG`.
- Le force-step écrit une cible **unique** (`ForceStepCandidate` = une valeur d'enum → `State`), un saut ponctuel **mono-état**. Ce n'est pas un moteur de transition : il ne peut pas engendrer le couple `AX10→AX11`, qui n'existe que dans le flow nominal `CASE State` (1324–1380, non modifié).
- Les valeurs de force `10→AX10`, `11→AX11`, `22→AX10B`, `23→AX15D` restent bornées `[0..23]` avec rejet hors plage (ligne 802).

## 🎯 VERDICT — Probabilité que T383 cause la coupure M2 à AX11 : **BASSE**

| Critère | État | Conclusión |
|---|---|---|
| Blocs AX10/AX10B/AX11 modifiés ? | **NON** | continuité intacte |
| Retrait saut `AX15B→AX10` | **HORS ZONE** | réduit **les chemins vers** AX10/AX11 |
| Ajout AX15D | **HORS ZONE** (vidage) | sans lien AX11 |
| Surveill. sync AX10/AX11 (`instCauses[1]`, `[5]`) | **INCHANGÉE** | seul `AX15D` ajouté |
| Force-step → écriture AX10→AX11 | **IMPOSSIBLE** | saut mono-état, borne [0..23], cible = AX15D |

**Conclusion factuelle :** T383 est **exogène** à la chaîne AX10→AX10B→AX11. Il ne modifie ni la logique de ces étapes, ni leur surveillance de synchronisme, ni les commandes treuils M1/M2 de montée, ni le chemin de transition. Le changement le plus permissif touchant M2 reste **hors de la zone** (phase vidage à la tremie). Une coupure M2 à AX11 n'est **pas attribuable** à T383 sur la base du diff examiné. **Verdict : BASSE** — la cause d'une coupure M2 à AX11 est à chercher ailleurs (commande treuils amont, `instCauses[5]` écart vitesse confirmé, conditions physiques `M1_CablePosM` / `M2_CablePosM`, homme-mort, ou autre lot).

---
*Vérification sur `git diff 8ec1fa28..708a0f44 -- CODE/G_CYCLE/FB_CycleSemiAuto.st` + lecture cible `708a0f44` (zone 1301–1409, 455–504, 1530–1619).*
- Audit FB_Bucket du jour [completed]: ## 🎬 BRIEFING SESSION WORKFLOW PROJET / AGENTS.MD ACTIF
*Briefing session YGO Excavatrice — reprise par agent audit FB_Bucket T387.*

Audit terminé. Voici le rapport factuel (machine réelle, source de vérité = `CODE/*.st` versionné).

---

# 🔍 AUDIT T387 — FB_Bucket : fenêtre benne / gel timeout permis nul / cause 4 / WaitingForOperator

**Périmètre** : `git diff 8ec1fa28..708a0f44 -- CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` (T387 incorporé au checkpoint `708a0f44`, commit métier `dff0b535`).
**Question** : le gel du budget timeout quand permis nul peut-il (a) retarder `CloseReached`, (b) briser le raccordement AX10B → AX11 (continuité), (c) faire perdre `InterlockM2.MotorRequest` à AX11 ?

---

## 1. Résumé du diff — 6 hunks, 3 changements fonctionnels

| # | Position (lignes NEW) | Type | Contenu |
|---|---|---|---|
| H1 | `:78` | Décl. sortie | `WaitingForOperator : BOOL` (STAT) |
| H2 | `:110` | Décl. locale | `ClosePermitDeniedWhileRequested : BOOL` |
| H3 | `:233–240` | **Fonctionnel** | `IF ClosePermitDeniedWhileRequested THEN TimeoutEngaged := FALSE; END_IF` |
| H4 | `:292` | Commentaire | Cause 4 « non latchante, ne bloque pas le mouvement » |
| H5 | `:314` | **Fonctionnel** | `WaitingForOperator := Lifecycle.Busy AND CloseReq AND (NOT EffectivePermitBucket_Close)` |
| H6 | `:346` | Nettoyage | `WaitingForOperator := FALSE` en tête de bloc `IF NOT Enable OR NOT PowerContactorEngaged THEN` |

⚠️ Seul **H3** touche la logique de mouvement/timeout. H4 est un **commentaire pur** (le `Latching := FALSE` de la cause 4 existait déjà avant → aucune dérive fonctionnelle). H1/H5/H6 ne font que **publier** un état, sans rétroalimenter un verrou.

---

## 2. Analyse des hunks fonctionnels

### H3 — le gel du timeout (le seul point à risque)
```st
ClosePermitDeniedWhileRequested := CloseReq AND (NOT EffectivePermitBucket_Close);  // :237
IF ClosePermitDeniedWhileRequested THEN                                              // :238
    TimeoutEngaged := FALSE;                                                        // :239
END_IF;                                                                             // :240
```
- Condition d'activation **stricte** : `CloseReq=TRUE ET permis NUL`.
- Effet : `TimeoutEngaged` forcé à FALSE → le TON `TonTimeout` s'arrête → `TimeoutFaultLatched` (cause 2) ne latche pas.
- **Le vrai grippage (permis OK mais aucun mouvement) conserve `TimeoutEngaged`** → `ErrorID:03` latché (protégé, cf. commentaire `:235–236`). **Aucune régression de détection de panne.** ✅

### H5 — l'état publié
```st
WaitingForOperator := Lifecycle.Busy AND CloseReq AND (NOT EffectivePermitBucket_Close);  // :314
```
- Consommé PRG_04 `:1847` → `BucketWaitingForOperator`, **exclusivement observé IHM** (grep : uniquement décl `:23` + assign `:1847`). **Aucun verrou/interlock ne le lit.** ✅

### H6 — cleanup
```st
CloseReached := FALSE; CloseReq := FALSE; OpenReq := FALSE; WaitingForOperator := FALSE;  RETURN;  // :343–347
```
- Simple remise à zéro cohérente en état hors alimentation ; sans effet sur la logique nominale.

---

## 3. Tracé sur `CloseReached` et la continuité AX10 / AX10B

**CloseReached** (détection d'arrivée) — **NON touché par T387** :
```st
IF CablePosM2 >= (CablePosM1 + Config.OffsetCloseM - Config.CloseAnticipationM)
   OR instCloseThreshold.Reached THEN          // :639
    ...
    CloseReached := TRUE;                      // :650
```
La condition est purement **géométrique + seuil qualifié** (`:627–637`). Le hunk H3 n'agit que sur `TimeoutEngaged`/cause 2, jamais sur `CloseReached`. 

**Raccordement AX10B** (`:540–545`, HoldAscentP1AfterClose) :
```st
ELSIF Lifecycle.Busy AND CloseReached AND HoldAscentP1AfterClose THEN      // :540
    M2_RunRequest := MotionRequestActive AND ReqAscent AND EffectivePermitBucket_Close;  // :543
```
Point clé : **après `CloseReached`, `CloseReq := FALSE` (`:649`)** → dans la fenêtre AX10B/AX11, `CloseReq=TRUE` est **faux**, donc `ClosePermitDeniedWhileRequested` est **FALSE** → **H3 est inactif pendant tout le raccordement**. La fenêtre AX10B→AX11 ne subit **aucune** dérive par rapport à l'état pré-T387.

**Continuité M2 vers AX11** (chaîne) :
- `EffectivePermitBucket_Close` (`PRG_04 :1187–1191`) = `EffectivePermitM2_Ascent AND ... AND NOT instBucket.Fault.Error`.
- `M2AscentPermitApplied` (`:1195`) = `EffectivePermitM2_Ascent AND (NOT M2_RunRequest OR EffectivePermitBucket_Close)` → consommé en `AscentPermit` de `FB_WinchM2` (`:1599`) et du verrou final (`:1698`).

Le seul point où T387 touche cette chaîne : `NOT instBucket.Fault.Error`. Or H3 **empêche** un faux latch de `TimeoutFaultLatched` (cause 2) → il maintient `NOT Fault.Error = TRUE` → **protège** la continuité du permis, il ne la coupe pas.

---

## 4. Réponse ciblée à la question du gel timeout

**« Peut-il faire rester la benne busy plus longtemps / retarder CloseReached / gêner la reprise AX10B/AX11 ? »**

| Question | Réponse factuelle |
|---|---|
| Retarde-t-il `CloseReached` en situation nominale ? | **NON.** Si permis OK durant AX10, `ClosePermitDeniedWhileRequested=FALSE` → H3 n'agit jamais → comportement **identique à l'ancien** (verdict ci-dessous). |
| Peut-il prolonger l'état Busy ? | **OUI, mais uniquement dans le cas d'attente de permis** (CloseReq + permis nul). Avant T387, un permis nul prolongé faisait **latch ErrorID:03** au bout de `CfgTimeoutDuration` → arrêt + Reset. Après T387, la benne **attend indéfiniment** l'opérateur (état `WaitingForOperator`). C'est le **comportement voulu** du hunk, pas une perturbation. |
| Est-ce un danger physique ? | **NON.** Permis nul ⇒ `M2_RunRequest` **déjà FALSE** (`:550`, gated par permis) ⇒ **aucun mouvement commandé**, benne épinglée, IHM claire (`BucketWaitingForOperator`). C'est un **arrêt contrôlé**, pas une perte de commande. |
| Peut-il gêner AX10B/AX11 ? | **NON.** En AX10B, `CloseReq=FALSE` ⇒ H3 inactif ⇒ `TimeoutEngaged` strictement identique à l'avant-T387 dans toute la fenêtre du raccordement. |

**Changement de signature de défaut** (à connaître, non destructif) : en attente de permis longue, la machine passe de *« auto-défaut + Reset requis »* à *« attente opérateur (WaitingForOperator) »*. La reprise dépend donc d'une **action humaine** (débloquer le permis ou reset) ; sans action, la séquence reste en attente au palier de fermeture — mais c'est un **stop sûr, visible IHM, sans interruption de la commande M2 déjà servie** (AX11 n'est de toute façon pas atteignable tant que le permis est nul ; le blocage est **en amont**, à AX10).

---

## 5. 🔎 Verdict de probabilité

> **Probabilité d'impact sur la perte de `InterlockM2.MotorRequest` à AX11 : 🟢 BASSE (LOW).**

Justification en 4 points factuels :
1. **H3 n'agit jamais en nominal ni en AX10B** : conditionnné par `CloseReq AND NOT EffectivePermitBucket_Close`, or en AX10B `CloseReq=FALSE`. Aucune dérive possible dans la fenêtre AX10B→AX11.
2. **Aucun chemin vers une coupe M2** : H3 ne modifie ni `M2_RunRequest`, ni `CloseReached`, ni `EffectivePermitM2_Ascent`, ni `M2AscentPermitApplied`. Le seul lien (`NOT instBucket.Fault.Error`) est **protégé**, pas coupé.
3. **`WaitingForOperator` est observationnel** : consommé uniquement par l'IHM, jamais par un verrou ou la barrière finale.
4. **L'extension de durée Busy n'est pas une perte de commande** : permis nul = pas de consigne servie = stop sûr, non coupure. Le « plus longtemps busy » est l'état `WaitingForOperator` voulu.

**Réserve résiduelle (qualitative, non bloquante)** : en supprimant le filet de sécurité qu'était le timeout en attente de permis, T387 dépend plus de l'action opérateur pour débloquer une séquence bloquée par permis nul. Risque **process/humain**, pas interlock ; à couvrir par supervision du séquenceur si l'on veut un filet. **Aucune action corrective obligatoire sur le code à ce stade.**

---

**Rappel réglementaire (AGENTS.md)** : ceci est un **audit/documentaire**, aucun `CODE/*.st` n'a été modifié → pas de bundle/gates requis. Aucune édition 
- Audit modifs non committées [completed]: J'ai tous les éléments factuels. Voici le rapport d'audit.

---

# 🔒 Audit sécurité — Bypass MécaB par défaut (working tree non committé)

**Contexte** : diagnostic perte de `InterlockM2.MotorRequest` à AX11. **Deux modifs NON COMMITTÉES** neutralisent la cause **MécaB** (absence de confirmation d'arrêt contacteurs/frein) par défaut, pour **M1 (Treuil Retenue)** et **M2 (Treuil Benne)**.

---

## 1️⃣ Diff NON COMMITTÉ (working tree vs HEAD)

### `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_BypassWinch.st` — ligne 30

```diff
     (* ⚙️ 3. Sécurité Mécanique (Méca A-E) *)
     MecaA             : BOOL; (* 🔄 Bypass Méca A : mouvement non commandé à l'arrêt *)
-    MecaB             : BOOL; (* 🛑 Bypass Méca B : absence confirmation arrêt (frein/contacteurs) *)
+    MecaB             : BOOL := TRUE; (* 🛑 Bypass Méca B : absence confirmation arrêt (frein/contacteurs) *)
     MecaC             : BOOL; (* 🏋️ Bypass Méca C : glissement de charge (benne M1) *)
```

**Initialiseur par défaut `:= TRUE`** sur le DUT struct : **tout** treuil créé depuis cette struct démarre avec MécaB **déjà bypasse**, sans aucun appui exploitant.

### `CODE/M_MAIN/PRG_07_Supervision.st` — lignes 291 & 299 (à l'initialisation des deux bypass)

```diff
 IF NOT GVL_IHM.M1TreuilRetenue.Bypass.Initialized THEN
     IF BypassWinchM1Global THEN
         GVL_IHM.M1TreuilRetenue.Bypass.Global := TRUE;
     END_IF;
+    GVL_IHM.M1TreuilRetenue.Bypass.MecaB := TRUE;
     GVL_IHM.M1TreuilRetenue.Bypass.Initialized := TRUE;
 END_IF;
```

```diff
 IF NOT GVL_IHM.M2TreuilBenne.Bypass.Initialized THEN
     IF BypassWinchM2Global THEN
         GVL_IHM.M2TreuilBenne.Bypass.Global := TRUE;
     END_IF;
+    GVL_IHM.M2TreuilBenne.Bypass.MecaB := TRUE;
     GVL_IHM.M2TreuilBenne.Bypass.Initialized := TRUE;
 END_IF;
```

**Double blindage** : même si l'initialiseur struct était corrigé, `PRG_07` réécrit `MecaB := TRUE` à chaque première exécution après écrasement de la GVL_IHM (réarmement, restauration, première montée). La neutralisation est **systématique et auto-réappliquée**.

📌 D'autres fichiers working tree sont modifiés (bundles XML cohérents avec le ST, 2 registres, rapports CI) → cohérents, pas d'écart. Fichiers cibles : mtime **22/09/2026 16:51–16:52**.

---

## 2️⃣ Ce que la détection MécaB protège — `FB_Safety_Winch.st` (cause 8, bit8, latched)

Ligne 346–349 :
```st
// Cause 8 : Méca B absence confirmation arrêt (latched)
IF NOT (BypassSafety OR BypassMecaB) THEN
    UncommandedActiveB := NOT MovementCommanded AND NOT BenneHoldStillActive
                        AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
    TonMecaB(IN := UncommandedActiveB, PT := PostRampTimeout);   // PT = 3 s
    IF TonMecaB.Q THEN MecaBFaultLatched := TRUE; END_IF;
ELSE
    TonMecaB(IN := FALSE);
END_IF;
```

**Ce que protège MécaB** — c'est la **preuve de l'arrêt physique réel** après une commande d'arrêt :
- 🚫 **Aucune commande de mouvement** n'est active (`NOT MovementCommanded`).
- 🚫 La benne n'est pas en maintiens actif (`NOT BenneHoldStillActive`).
- ❗ **On exige la confirmation électromécanique** que l'axe est réellement arrêté : `FwdRevSpeedFeedbackOff` **ET** `BrakeFeedback NOT` (frein appliqué = retombé).
- ⏱️ Si, **3 s après l'arrêt demandé** (`PostRampTimeout`), les contacteurs ne sont pas retombés **ou** le frein n'est pas appliqué → **MecaBFaultLatched := TRUE** (latché, `Latching := TRUE`, rearmement uniquement sur `Reset` sur front + cause disparue).

**Sémantique de la condition d'arrêt confirmé** `NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback)` :
- La confirmation n'est bonne **que si** vitesse nulle **ET** frein fermé.
- Donc MécaB déclenche si : le variateur tourne encore (vitesse non nulle) **ou** le frein reste ouvert (levier pas retombé / contacteur de confirmation absent).

**Impact de la neutralisation** dans la chaîne aval (`FB_Safety_Winch.st` lignes 490, 508, 522–531) :
- `ContactorStuck := MecaBFaultLatched` → **détection de contacteur collé** également neutralisée.
- `CauseMecaBActive` alimente à la fois `CausesSafeStopActive` **et** `CausesPowerCutOffActive` → l'**AU / coupure puissance** ne part plus sur cette cause.

**Risque couvert par la détection (ce qu'on perd en la bypassant)** :
| Phénomène | Protégé par MécaB ? |
|---|---|
| **Mouvement non commandé résiduel après commande d'arrêt** (rampe qui ne finit pas, entraînement qui "flotte") | ✅ OUI — c'est le cœur |
| **Absence de confirmation de retour** (contacteur de confirmation frein/contacteurs défaillant) | ✅ OUI |
| **Frein qui ne retombe pas** (contacteur de frein reste ouvert, ou confirmation pas renvoyée) | ✅ OUI — danger de chute de charge suspendue |
| **Contacteur de puissance collé/colle** (`ContactorStuck`) | ✅ OUI |
| Patinage / glissement de charge (benne) | ❌ **NON** — c'est Méca C (`DriftGuardC`, cause 9) |
| Dérive à l'arrêt | ❌ **NON** — c'est Méca A (cause 7) |

> ⚠️ MécaB n'est **pas** la détection de patinage (c'est Méca C). Mais MécaB et le patinage **partagent la même exigence** : que l'axe soit réellement immobilisé frein appliqué quand aucune commande n'ordonne de mouvement.

---

## 3️⃣ Date / commit de création du vrai défaut

```
git log --all --oneline -S 'MecaB := TRUE' -- CODE/M_MAIN/PRG_07_Supervision.st CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_BypassWinch.st
→ VIDE (aucun commit)
```

- 🔍 **`MecaB := TRUE` sur les 2 fichiers cibles n'existe dans AUCUN commit** de l'historique complet (`--all`). La modif est **100 % working tree UNCOMMITTED**.
- Le seul commit matché (`cc682aa6`, 2026-09-20 15:48, Mathieu Gros) est un **faux positif** : il n'ajoute `ErrorMecaB := TRUE` que dans un **test de bandeau IHM** (`BRIEF_T375`), pas dans le bypass.
- ✅ **Commited base** : `HEAD` a `MecaB : BOOL;` (sans initialiseur, ligne 30) et **aucune ligne `MecaB`** dans `PRG_07`.

**Conclusion (point 4)** : le bypass n'est **pas antérieur** — il est introduit **aujourd'hui** (mtime 22/09/2026 16:51–16:52), c'est-à-dire **pendant la campagne d'essai du 22/09**, en même temps que le ré-exécution CI à 16:51. **Il n'y a pas de "vrai défaut" committé plus tôt : la neutralisation elle-même est la modif non committée du jour.**

---

## 4️⃣ Avis — le bypass MécaB masque-t-il la cause de la coupure à AX11 ?

**Verdict : 🔴 HAUTE probabilité que le bypass de la cause MécaB ait été activé pour contourner un défaut MécaB réel, et qu'il masque la coupure de `InterlockM2.MotorRequest` à AX11.**

### Preuves factuelles (lignes exactes) :

1. **Registre `REGISTRE_Suivi_MiseEnService_20260921.md`** (modifié aujourd'hui, entrée `2026-09-22`) :
   > « Essai du jour, `BypassMecaB` **actif** — **Sans le bypass : erreur MecaB systématique** ("absence confirmation arrêt contacteurs/frein", `FB_Safety_Winch.st`, cause 8, latched) — **bloque l'essai** … **NON TRANCHÉ — bypass utilisé faute d'alternative, cause racine non identifiée** »

   → **Admis par écrit** : le bypass sert à faire passer un essai qui sinon déclenche MécaB en permanence. C'est exactement le scénario de **masquage** d'une cause.

2. **`FB_Hmi_BannerFormatter.st:549-568`** : la voie MécaB produit `[M1]/[M2]/[M3] MecaB (arrêt non confirmé)` et `ErrorID:09`. Le message est **non qualifié** (on ne sait pas si c'est contacteur ou frein) — l'orchestrateur le note lui-même dans le registre.

3. **Gravité de la perte à AX11** : `MecaB` alimente `CausesPowerCutOffActive`. Neutraliser la confirmation d'arrêt **par défaut** signifie que, sur l'automate, un **retour de confirmation d'arrêt absent/faux est ignoré** → la protection machine ne s'oppose plus à `MotorRequest` lorsqu'il n'y a pas de preuve d'arrêt. Sur un treuil de benne **suspendue** (charge grave), c'est une perte de barrière de sécurité ISO 13849.

### Deux lectures possibles (à trancher par l'exploitant, non tranchées dans le working tree) :
| Hypothèse | Implication | Risque |
|---|---|---|
| **1. Faux positif logiciel** : `PostRampTimeout`=3 s trop court, ou retour DI `M1/M2 (…)Releas
