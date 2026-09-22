# AUDIT — Triage CI `WINCH_INTEG` (27 échecs) + convergence `T169-A S3`

> **Date** : 2026-09-22 · **Auteur** : DSH01 (sous-agent, read-only strict) · **Relecture** : orchestrateur
> **Portée** : entrée CI `WINCH_INTEG` (5 PASS / 27 FAIL) + `MAIN_GLOBAL` (1 FAIL) + `FB_CycleSemiAuto` TC-P04-020 (1 FAIL)
> **Contrat** : trier et PROUVER, ne pas corriger. Aucune écriture hors ce fichier. Aucun commit.
> **Standards de preuve** : ✅ vérifié (lecture directe fichier:ligne) · 🔸 déduit (enchaînement) · ⚠️ non tranchable en lecture → INDÉTERMINÉ.

---

## 0 · Contexte mesuré

- Après purge de l'argument mort `SetOffsetM` (commit `ecce6a5a`, supprime la VAR_INPUT déjà retirée par `ffc811c1` dans `FB_TestHarness_PRG_03.st:96-100`), l'entrée `WINCH_INTEG` **compile et s'exécute** :
  `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/reports/WINCH_INTEG.json` → 32 tests, 5 PASS / 27 FAIL.
- **Observation structurante** : 22 des 27 échecs sont des **préconditions qui tombent** (« M1_StepNumber >= 1 got 0 », « M1RelayFwd got FALSE »). Le mouvement **ne s'établit jamais** dans le harnais. Ce n'est pas 22 défauts indépendants : c'est **une cause racine de harnais** qui cascade, + 1 défaut réel + 4 cibles ROUGE-baseline.

---

## 1 · Tableau des 27 échecs

Verdicts : 🧯 **HARNAIS PÉRIMÉ** · 🐞 **DÉFAUT RÉEL** · ⚠️ **INDÉTERMINÉ** · 🔴 cible ROUGE-baseline (tâche aval non livrée). Harnais de référence : `FB_TestHarness_PRG_04.st` (miroir PRG_04) ; suite : `test_winch_integ.st`.

| # | Cas (ligne d'échec) | Famille | Verdict | Preuve harnais | Preuve code PRODUCTION |
|---|---|---|---|---|---|
| 1 | **HARN-10** `:122` (Step 0 vs 3) | paliers | 🧯 HARNAIS | miroir ne consomme pas `ReqProgram`/`SeqReq*` : `FB_TestHarness_PRG_04.st:10-41` (VAR_INPUT sans entrée bus) ; `reqProgramLocal` rempli puis jeté `FB_Main_EndToEnd.st:366-368,376-401` | prod utilise l'arbitrage POO : `CODE/M_MAIN/PRG_04_Treuils_Benne.st:534` (M1) / `:557` (M2) |
| 2 | **HARN-11** `:170` (0 vs 1) | paliers | 🧯 HARNAIS | idem cause racine ; joystick non routé en couplé (`FB_TestHarness_PRG_04.st:78,84` exigent `Arbitrated=1/2`) | prod : `FB_TestHarness` ne pilote jamais le couplé ; prod arbitre via `FB_WinchCmdArbitrationM1.st:56-61,93/98` |
| 3 | **HARN-12** `:220` (précond 0) | paliers | 🧯 HARNAIS | idem cause racine | idem |
| 4 | **HARN-13a** `:269` (0 vs 2) | paliers | 🧯 HARNAIS + 🔴 oracle | idem + oracle calé table 10/30/50/70/90 (`test_winch_integ.st:52-54`, `FB_Main_EndToEnd.st:223-227`) ≠ prod | prod : table 20/40/60/80/100 (`AF-08:370`, `GVL_PERSISTENT.st:22`) |
| 5 | **HARN-13b** `:313` (0 vs 3) | paliers | 🧯 HARNAIS + 🔴 oracle | idem | idem |
| 6 | **HARN-13c** `:356` (0 vs 5) | paliers | 🧯 HARNAIS + 🔴 oracle | idem | idem |
| 7 | **HARN-20** `:402` (1 vs 4) | paliers | 🧯 HARNAIS | `FB_TestHarness_PRG_04.st:81` `StepTgt := SEL(run,0,1)` → jamais >1 | prod : palier = `SpeedStepReq` direct (`FB_SpeedStep.st:71`) ; joystick → `StepTgt` (`FB_Joystick.st:285-288`, `FB_WinchCmdArbitrationM1.st:93/98`) |
| 8 | **HARN-23** `:493` (1 vs 0) | homme-mort | 🧯 HARNAIS (winch-level) | miroir câble `BrakeFeedback := M1_BrakeFeedbackOpen` statique `FB_TestHarness_PRG_04.st:161` ; winch jamais >1 | prod : relâche → `RampTargetStep:=0` (`FB_Winch.st:216`), `StepNumber:=0` (`:281`) ; AF-10:508 coupure instantanée |
| 9 | **HARN-30** `:528` (Immersion=F) | Kobold/fond | 🧯 HARNAIS | `KoboldImmersionConfirmed` forcé FALSE `FB_Main_EndToEnd.st:403-404` ; entrée `KoboldImmersed` non consommée `:61` | prod : logique immersion **existe et correcte** `PRG_04_Treuils_Benne.st:733-750,771/785` |
| 10 | **HARN-31** `:563` (0) | Kobold/fond | 🧯 HARNAIS + 🔴 T181-12 N.L. | cause racine (couplé non routé) | prod : `MinStepDown:=0` (`PRG_03_Modes_Cycle.st:453,540`) ; plafond 4 absent car T181-12 non livré |
| 11 | **HARN-32** `:590` (précond 0) | homme-mort | 🧯 HARNAIS + 🔴 T181-12 N.L. | cause racine | idem |
| 12 | **HARN-33** `:626` (0 vs 1) | précédence | 🧯 HARNAIS + 🔴 T181-12 N.L. | cause racine | prod : précédence plancher/plafond correcte (`FB_Winch.st:257-265`, `FB_SpeedStep.st:71`) mais non exercée |
| 13 | **HARN-40** `:657` (1 vs 4) | anti-traversée | 🧯 HARNAIS | cause racine ; `instBucket` déclaré `FB_TestHarness_PRG_04.st:49` jamais invoqué | prod : `instBucket(` invoqué `PRG_04_Treuils_Benne.st:340` |
| 14 | **HARN-41** `:693` (SyncWarn=F) | sync | 🧯 HARNAIS | `instWinchSync` déclaré `FB_TestHarness_PRG_04.st:48` **jamais invoqué** ; `SyncState` jamais écrit (corps `:154-177`) | prod : `instWinchSync(` invoqué `PRG_04_Treuils_Benne.st:627`, publié `:1735,1945` |
| 15 | **HARN-42** `:726` (1 vs 5) | anti-traversée | 🧯 HARNAIS | `StepTgt` figé à 1 `FB_TestHarness_PRG_04.st:81` ; `instWinchM2` jamais invoqué | prod : `instWinchM2(` invoqué `PRG_04_Treuils_Benne.st:1523` |
| 16 | **HARN-50** `:755` (RelayFwd=F) | interlock | 🧯 HARNAIS | montée couplée (select=0) non routée `FB_TestHarness_PRG_04.st:78,84` | prod : couplé arbitré `FB_WinchCmdArbitrationM1/M2` |
| 17 | **HARN-51** `:788` (RelayFwd=F) | interlock | 🧯 HARNAIS + 🔴 T181-01 N.L. | test SANS purge neutre ≥1500 ms (`test_winch_integ.st:780-788`, cf. commentaire `:782` ; purge identique HARN-50 `:746`) → `RestartRequired` jamais purgé | prod : barrière `RestartRequired` (`FB_WinchOutputInterlock.st:170,205,222`) |
| 18 | **HARN-52** `:827` (Governed=F→vrai) | interlock | ⚠️ INDÉTERMINÉ | mouvement partiel (select=1) mais barrière gouverne en nominal ; champ `Requested≠Output` non identifié | prod : `FinalInterlockGoverned` = `Requested ≠ Output` (`FB_Main_EndToEnd.st:451-457`) — à mesurer |
| 19 | **HARN-60** `:857` (écart>0.10=F) | sync | 🧯 HARNAIS | pas de mouvement + `SyncState` jamais écrit | prod : `FB_SyncDeviation.st:66-72,81-82` exige `HomedAndReliable AND Delta>Tol` ; fallback `SyncToleranceM:=0.10` (`FB_Main_EndToEnd.st:265`) jamais transmis (FB défaut 3.0 `FB_WinchSync.st:28`) |
| 20 | **HARN-61** `:895` (écart<0.10=F) | sync | 🧯 HARNAIS | idem + écart figé 0.3 sans mouvement | idem |
| 21 | **HARN-70** `:923` (RelayFwd=F) | sécurité | 🧯 HARNAIS | montée couplée non routée | prod : coupure AU = `FB_Main_EndToEnd` modèle (`:494-499`), relayé si mvt réel |
| 22 | **HARN-71** `:969` (redémarrage auto) | sécurité | ⚠️ INDÉTERMINÉ | code contient D18 (`FB_WinchDirectionInterlock.st:104-143`, `RestartRequired` `FB_WinchOutputInterlock.st:148-228`) mais CI observe `RelayFwd=TRUE` ; à mesurer `Enable` au scan DISABLE (`test_winch_integ.st:958,964`) | prod : le dialecte STruCpp réinitialise `CmdMode` omis → MAINT_N1 (`FB_Main_EndToEnd.st:252-256`) |
| 23 | **HARN-73** `:1033` (temps mort) | sécurité | 🧯 HARNAIS (D18 présent) | DeadTime arme sous `NOT BrakeFeedback` (`FB_WinchOutputInterlock.st:224,250`) ; miroir câble `BrakeFeedback`=TRUE statique `FB_TestHarness_PRG_04.st:161` → jamais observable | prod : DeadTime existe `FB_WinchOutputInterlock.st:230-270` |
| 24 | **HARN-75** `:1128` (hot-restart) | sécurité | 🧯 HARNAIS (D18 présent) | champs `DirectionChangePending/FinalRestartInhibit` jamais écrits par le miroir (projection absente) | prod : projection `FB_WinchStateProjection.st:147,116`, câblée `PRG_04_Treuils_Benne.st:1688,1725-1726` |
| 25 | **HARN-80** `:1162` (CAS-001) | sécurité | 🐞 **DÉFAUT RÉEL** (+ harnais inapte à l'observer) | miroir n'écrit **jamais** `WinchM1Safety.Error` (seulement `SafeStop/PowerCutOff/AscentPermit/DescendPermit` `FB_TestHarness_PRG_04.st:168-171`) → champ lu mais jamais produit | `FB_Safety_Winch.st` : **aucune cause CAS-001** (rétombée en marche). Causes présentes 0..15 (MecaA-E, thermal, codeur, comm, FDC, limites, opposé, no-movement) `:269-447` ; aucun « retard de contacteur en marche ». Audit → C4 exigé `AUDIT_29_CAS_LIMITES...:100`. Prod `WinchM1Safety := instWinchStateProjection.WinchM1Safety` `PRG_04:1727` |
| 26 | **HARN-81** `:1186` (précond 0) | sécurité | 🧯 HARNAIS | couplé non routé | prod : pas de mouvement dans le harnais |
| 27 | **HARN-82** `:1223` (précond) | sécurité | 🧯 HARNAIS | SeqReq non consommé → aucun mvt SEMI_AUTO | prod : `ReqWinch := ...ReqProgram.ReqWinchM1` `PRG_04_Treuils_Benne.st:534` |

**Bilan : 21 🧯 HARNAIS PÉRIMÉ · 1 🐞 DÉFAUT RÉEL (HARN-80) · 2 ⚠️ INDÉTERMINÉ (HARN-52, HARN-71) · 3 🔴 cibles ROUGE-baseline documentées hors DÉFAUT (31/33/51/73/75).**

---

## 2 · Thèse centrale : le miroir `FB_TestHarness_PRG_04.st` est un stub d'un PRG_04 pré-refactor POO

> ⚠️ Contrôle orchestrateur : 8 844 octets, daté 14/09 16:47. **La taille n'est PAS l'argument** (elle serait trompeuse). Je le prouve par l'**interface**, pas par la taille.

### 2.1 Comparaison d'interface (décisif)

| Dimension | Harness `FB_TestHarness_PRG_04.st` (miroir) | Production `PRG_04_Treuils_Benne.st` |
|---|---|---|
| **Taille / structure** | 8 844 B, **179 lignes**, 1 FB | 126 466 B, **>1 955 lignes**, 8 régions (§1–§8) |
| **FBs instanciés** | `instWinchSync :48`, `instBucket :49`, `instSafetyWinchM1/M2 :50-51`, `instWinchM1 :52`, `instWinchM2 :53` — **dont seulement 2 invoqués** : `instSafetyWinchM1(:90)`, `instWinchM1(:142)` | `instBucket(:340)`, `instWinchSync(:627)`, `instSafetyWinchM1/M2(:926,...)`, `instWinchM1/:1523/:1457` — **tous invoqués** |
| **Entrées bus séquenceur** | **AUCUNE** : VAR_INPUT `:10-41` sans `ReqProgram`/`SeqReq*`/`SeqBottomTouchConfirmed` | `ReqWinch := ...ReqProgram.ReqWinchM1` `:534`, `:557` ; `:367-369` |
| **Arbitrage POO** | **ABSENT** (pas de `FB_WinchCmdArbitrationM1/M2`) | présents (`FB_WinchCmdArbitrationM1.st:56-61,93/98`) |
| **Sorties `Data` écrites** | **Uniquement M1** : `WinchM1FinalInterlockRequest :154`, `WinchM1Safety :168-171`, `WinchM1State.StepNumber :175`. **`WinchM2*`, `SyncState`, `BucketState` JAMAIS écrits** | **M1 et M2** : `Data.WinchM1State :1941`, `Data.WinchM2State :1942`, `Data.WinchM2Safety :1944`, `Data.SyncState :1945`, `Data.BucketState :1955`, `Data.WinchM2FinalInterlockRequest :1937` |
| **Palier demandé** | FIGÉ à 1 : `M1LogicRequestStepTgt := SEL(M1LogicRunRequest,0,1)` `:81` (M2 `:87`) | arbitré + clampé (`FB_SpeedStep.st:71`) |
| **Joystick** | routé QUE si `Arbitrated∈{1,2}` `:78,84` ; couplé (=0) jamais | couplé arbitré `FB_WinchCmdArbitrationM1/M2` |

### 2.2 Conclusion thèse

✅ **Vérifiée par l'interface** : le miroir expose un **sous-ensemble tronqué** de l'interface réelle de PRG_04 (M1-seul, sans bus séquenceur, sans POO, sans M2/sync/benne, palier figé à 1). Il ne « consomme » pas ce que `FB_Main_EndToEnd` lui fournit (`reqProgramLocal` est **jeté** `:366-368` ∉ `:376-401`). La thèse « stub antérieur au refactor POO » est **confortée** par : l'absence de `FB_WinchCmdArbitration*`, le fait que `instWinchSync/instBucket/instWinchM2` soient des **déclarations mortes**, et le fait que le type de sortie `Data : ST_WinchInterPrg` n'est rempli que partiellement. La **date 14/09** n'invalide pas la thèse : le fichier est un artefact de harnais qui n'a pas été recompilé/représentatif après le passage production en POO (le code prod a lui été modifié jusqu'au 21/09, 126 ko).

⚠️ **Réserve honnête** : je ne peux pas prouver la *date exacte* de la version POO de PRG_04 ni quel commit précis a créé l'écart (pas de `git log -S` probant isolé) — ce point de datation exacte reste **en partie non-prouvé** (voir §7). L'écart d'interface, lui, est **vérifié** ligne à ligne.

---

## 3 · Convergence `T169-A S3` — verdict UNIQUE

### 3.1 Les 3 occurrences échouent à des points DIFFÉRENTS (mesuré)

| Entrée | Assertion qui échoue réellement | Point d'échec |
|---|---|---|
| **FB_CycleSemiAuto TC-P04-020** | `:886` « Etabli en AX4_DESCEND_DIVING » → got FALSE | **Progression vers X4**. L'assertion du relâchement (`:904-907`) n'est **jamais atteinte**. Échec ≠ homme-mort. |
| **MAIN_GLOBAL** | `:152` `CycleStep <> AX1_INIT OR stepBefore=AX0` → got FALSE | **Bloqué à AX1_INIT** : le méga-bloc ne câble PAS `InitPositionOk`/`WinchesAtTopWindow` (absents `FB_TestHarness_PRG_03.st:10-43` → défaut FALSE) → cycle ne quitte jamais AX1. |
| **WINCH_INTEG HARN-23** | `:493` `StepNumber = 0` attendu → got 1 | **Couche treuil**, mode `MAINT_N1` joystick, **hors cycle**. |

### 3.2 Verdict

**⚠️ NON — ce n'est PAS le même défaut de code.** Ce sont **3 harnais/tests indépendants** qui échouent **chacun avant** (ou hors de) l'exercice du comportement homme-mort cycle :
- TC-P04-020 échoue sur la **progression AX1→AX4**, pas sur le relâchement.
- MAIN_GLOBAL échoue sur le **câblage e2e `InitPositionOk`**, pas sur le relâchement.
- HARN-23 teste le **palier treuil MAINT_N1**, pas l'étape cycle.

### 3.3 Ce qui est EXIGÉ (spec + tâche) → le code LE FAIT

- **Spec `AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md`** :
  - `:181` : « Relâchement manche (retour centre) ⇒ `StartStop=FALSE`, **étape conservée**, **pas de reprise automatique**. »
  - `:279-280` : reprise exige **geste conscient** (BtnStart), l'armement homme-mort **n'est pas** un geste de reprise.
- **Tâche T169-A** (archive `DOC/WFLOW/ARCHIVES/TASKS_SNAPSHOT_20260915/TASKS_20260915_234600.yaml`) :
  - `:2766` objectif : « Scénario 3 : homme-mort en cours d'étape (**maintien étape**, **non-redémarrage sans réarmement**) ».
  - ✅ statut `:2750`, C4, agent AGY-01, `completed_at` 2026-08-30.
- **Code production** (`CODE/G_CYCLE/FB_CycleSemiAuto.st:1064-1091`, étape `AX4_DESCEND_DIVING`) :
  - `:1079-1082` : `WinchM1Cmd.RunRequest := DeadmanArmed AND JoystickPush` (relâchement → **coupe la demande**), `StepTgt := CST_StepDive` (reste palier 4).
  - `:1088-1090` : la transition X4→X5 exige `DeadmanArmed AND JoystickPush` → **pas de redémarrage auto au relâchement**.

**⇒ Le comportement exigé (étape MAIN TENUE, commandes neutralisées, PAS de redémarrage auto) est IMPLÉMENTÉ et CONFORME dans le code.** Aucun correctif de code n'est exigé par la convergence T169-A S3. Les 3 occurrences sont des problèmes de harnais indépendants (progression X4, câblage `InitPositionOk`, couche treuil).

---

## 4 · Défaut réel annoncé `HARN-80 / CAS-001` — vérification

### 4.1 Assertion du harnais

`test_winch_integ.st:1162` : `ASSERT_TRUE(machine.BusWinch.WinchM1Safety.Error, 'HARN-80: CAS-001 detecte (defaut Error, cible T180)')`.

Le test force `ModelContactorsReleaseFaultM1 := TRUE` (`test_winch_integ.st:1145`) puis demande une montee, et attend que le FB de sécurité lève `Error`.

### 4.2 Ce que fait le harnais (défaut d'observabilité)

Le miroir `FB_TestHarness_PRG_04.st` **n'écrit JAMAIS `Data.WinchM1Safety.Error`** : il ne renseigne que `SafeStop/PowerCutOff/AscentPermit/DescendPermit` (`:168-171`). Le champ `.Error` du DUT `ST_SafetyWinch.st:8` (BOOL) reste à sa valeur initiale FALSE. Donc **même si le code CB produisait un défaut, le harnais tel quel ne peut pas le propager** à l'assertion → l'assertion est structurellement inobservable dans ce harnais.

### 4.3 Ce que dit le code production

`CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` déclare **16 causes** (index 0..15), listées `:269-447` :
- 0 perte comm · 1 codeur · 2 thermique moteur · 3 mou de cable · 4 rotation phases · 5 FDC haut · 6 limite basse · 7 MecaA dérive non commandée · 8 **MecaB** absence confirmation arrêt · 9 MecaC glissement · 10 thermique frein · 11 MecaD escalade FDC · 12 MecaE écart sync · 13 MecaE escalade · 14 sens opposé · 15 absence mouvement.

**Aucune cause « rétombée contacteur EN MARCHE » (feedback incohérent pendant commande de sens), c'est-à-dire CAS-001.** Le seul mécanisme qui lit `FwdRevSpeedFeedbackOff` pendant commande est MecaB, et il n'arme QUE si `JoystickYNeutral` (`:341`) — donc **inopérant sous commande de sens**. `ContactorStuck := MecaBFaultLatched` (`:484`) ne couvre pas la rétombée en marche.

### 4.4 La spec exige-t-elle CAS-001 ? → OUI

- `DOC/WFLOW/AUDITS/AUDIT_29_CAS_LIMITES_SECURITE_AF_20260829.md:100` : CAS-001 (rétombée contacteur en marche) = **🔴 C4 immédiat**.
- `DOC/WFLOW/AUDITS/DESIGN/SPEC_HARNESS_INTEG_TREUIL_T181-00_v0.1.md:178` : HARN-80 = CAS-001, « retombée d'un contacteur de sens **en marche** (feedback incohérent) → défaut détecté, mouvement neutralisé ».
- `DOC/WFLOW/AUDITS/DESIGN/PLAN_GEL_TREUIL_T181_v0.1.md:79` : **T180 = ⬜ C4** « Audit 29 cas limites sécurité », croisement CAS-001/012.

### 4.5 Verdict HARN-80

**🐞 DÉFAUT RÉEL** (safety) : le code `FB_Safety_Winch` **n'implémente pas CAS-001** (aucune cause de rétombée contacteur en marche), alors qu'il est **exigé au niveau C4** par l'audit T180. → **Le code DOIT implémenter CAS-001** (nouvelle cause/condition sur `FwdRevSpeedFeedbackOff` pendant commande de sens active, hors standstill).
⚠️ **Mais** : le harnais, lui aussi, est **inapte à l'observer** (il n'écrit jamais `WinchM1Safety.Error`, `:168-171`). Il faut donc **corriger le code ET le harnais** pour ce vecteur. Ce point est **safety-adjacent** : le verdict DÉFAUT RÉEL repose sur (a) l'exigence C4 documentée et (b) l'absence de cause correspondante dans `FB_Safety_Winch` — les deux vérifiés. Il reste **à confirmer sur machine** le comportement physique (voir §7).

---

## 5 · Correctifs CODE à prévoir (par gravité) — NON implémentés

| # | Cible | Gravité | Justification (preuve) |
|---|---|---|---|
| 1 | `FB_Safety_Winch.st` — **implémenter CAS-001** (rétombée contacteur en marche) + `WinchM1Safety.Error` productible | **C4 (safety)** | exigé audit T180 (`AUDIT_29...:100`) ; absent des 16 causes `:269-447` ; MecaB inopérant sous commande `:341` |
| 2 | `T181-12 / MinStepDown` (palier ≤4 en Kobold, plancher plongée) | C3 | `MinStepDown:=0` `PRG_03_Modes_Cycle.st:453,540` → cible non livrée, bloque HARN-31/32/33 |
| 3 | `T181-16` survitesse (`SpeedGuard`) | C4 (gelée) | `SpeedGuardEnable:=FALSE` `PRG_04_Treuils_Benne.st:1441,1509` + commentaire gel `:1551` |

*NB : aucun de ces correctifs ne concerne la convergence T169-A S3 (le code cycle est conforme, voir §3).*

---

## 6 · Harnais à réaligner (par ordre) — NON modifiés

| # | Cible | Raison (preuve) |
|---|---|---|
| 1 | **`FB_TestHarness_PRG_04.st` — reconstruire le miroir sur les FB POO** + passer `ReqProgram` à `prg04()` + consommer `Joystick.AxisY.StepTgt` + écrire `WinchM2State/SyncState/BucketState/WinchM2*` | cause racine de 21 échecs (§1 et §2) ; `FB_Main_EndToEnd.st:366-401` |
| 2 | **`FB_Main_EndToEnd.st:403-404`** — ne plus forcer `KoboldImmersionConfirmed/BottomTouchLatched := FALSE` ; câbler `KoboldImmersed` `:61` | HARN-30/31/32 (logique prod correcte `PRG_04:733-750` mais coupée côté banc) |
| 3 | **`FB_Main_EndToEnd.st:223-227`** — aligner table repli sur production 20/40/60/80/100 | oracles HARN-13a/13b (`AF-08:370`) |
| 4 | **`FB_TestHarness_PRG_03.st`** — câbler `InitPositionOk`/`WinchesAtTopWindow` | MAIN_GLOBAL:152, SEMI_AUTO (§3) |
| 5 | **Harness `WinchM1Safety.Error`** pour HARN-80 | champ lu `:1162` jamais écrit `:168-171` |
| 6 | **oracle HARN-41/60/61/73/75** | sync absente, BrakeFeedback statique `:161`, projection absente (§1) |

---

## 7 · Non tranché (INDÉTERMINÉ) et mesures nécessaires

1. **HARN-52** (`:827`) : la barrière gouverne en nominal alors qu'aucun interlock ne devrait → **mesurer au scan** quel champ `Requested ≠ Output` (`FB_Main_EndToEnd.st:451-457`) et l'état `RestartRequired/DeadTimePending` (`FB_WinchOutputInterlock.st:148-228`).
2. **HARN-71** (`:969`) : le code contient le temps mort D18 mais la CI voit `RelayFwd=TRUE` → **mesurer** `BusModes.Mode`/`instWinchM1.Enable` au scan `CmdMode:=DISABLE` (`test_winch_integ.st:958` vs `:964`) — le dialecte STruCpp réinitialise les entrées omises à zéro entre appels `machine()` (`FB_Main_EndToEnd.st:252-256`), ce qui fausse probablement D18.
3. **Progression AX4 (TC-P04-020/021/023/026)** : pré-séquence, non le relâchement. **Rejouer avec trace** de `DiveStartStopped`/`DiveStartStopTimer` (`FB_CycleSemiAuto.st:310-316`) et des conditions X2→X3→X3_WAIT→X4.
4. **CAS-001 / HARN-80** : verdict code DÉFAUT RÉEL (C4) fondé sur l'absence de cause dans `FB_Safety_Winch` — mais le **comportement physique réel** (machine) doit être validé par essai ; et le harnais doit être réparé pour l'observer.
5. **Datation exacte de l'écart POO du miroir** : je prouve l'écart d'interface ($2) mais **pas** le commit précis qui l'a introduit (pas de `git log -S` isolé probant en une passe) → non tranché côté historique de versioning.

---

## 8 · Hors scope constaté

- **Contradiction docs** : `AF_Partie-04:346` annonce « validation 100% TC-P04-001..021 » alors que TC-P04-020/021/023/026 sont rouges ; `AF_Partie-04:137` définit TC-P04-020 comme « FB_ExtractionAssist READY→CLOSING » alors que le test éponyme teste la plongée X4 (dérive nomenclature).
- **Enums divergents** : spec `AF-04:286-302` décrit `E_CycleStep` (X0..X13) ; code utilise `E_AutoCycleStep` (AX0..AX15, AX10B_RACCORDEMENT_P1, AX_STAB).
- **Rapport périmé** : `WINCH_INTEG.txt` encore sur l'ancienne erreur `SETOFFSETM` (compile-fail) alors que le `.json` est le run frais.
- **Dette compilation** : `E_CycleDepthStopMode` manquant dans l'entrée `PRG_03_Modes_Cycle` (dette T299, documentée ailleurs).
- **T382 (2026-09-22, ⬜ C3)** : AX3 pilotage benne annonce bidirectionnel alors que le code ne génère jamais `ReqClose` (`FB_CycleSemiAuto.st:1005-1035` vs `:1316`) — hors scope WINCH_INTEG mais même zone GRAFCET.

---

## 9 · Limites du présent audit

- Read-only : aucun verdict n'a été validé par essai machine ni par trace 10 ms.
- Les verdicts « HARNAIS » signifient « le harnais ne teste pas le comportement », **pas** la preuve du bon fonctionnement physique.
- Les cas INDÉTERMINÉ (HARN-52, HARN-71, progression AX4) exigent une instrumentation ; aucune conclusion inventée.
- Le statut catalogue de T169-A n'est vérifiable que dans l'**archive** `TASKS_SNAPSHOT_20260915` (le `TASKS.yaml` vivant n'a plus d'entrée `T169/T169-A`) — signalé, non corrigé.
