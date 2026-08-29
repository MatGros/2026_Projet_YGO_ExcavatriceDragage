# B4 — Relecture croisée indépendante du triptyque B1 / B2 / B3 (gel treuil T181)

> Subagent Claude (general-purpose, accès dépôt), commit `0dae6c5c`. Tout vérifié par lecture code.
> **F** = fait avéré (`fichier:ligne`), **H** = hypothèse, **I** = incertitude.

---

## 0 · Écarts sécurité signalés d'emblée

| # | Constat | Preuve | Note |
|---|---|---|---|
| **SEC-1** | Garde-fou survitesse 100 % mort et le reste jusqu'à T181-16 (Phase B) — donc pendant **tous les 1ᵉʳˢ essais site treuil sous puissance**. | `PRG_04:682,718,73-74` ; `FB_Winch.st:264-269` ; `FB_SpeedStep.st:214-224` | F — le plan §13 S2 l'enterre dans un tableau. À mettre **en tête du plan de tir**. |
| **SEC-2** | **Deux** implémentations de garde-fou survitesse consomment les mêmes entrées mortes : `FB_SpeedStep §2ter` (l.208-224) **et** `FB_Winch §6` (l.264-269). Aucun livrable ne les réconcilie (D06/T181-16 ne parle que de « câbler MeasuredSpeedBand »). | `FB_SpeedStep.st:214` + `FB_Winch.st:264` | F — angle mort des 3 passes. Risque : réactiver l'un sans l'autre / double limitation. |
| **SEC-3** | `SpeedGuardReady := NOT instWinchSync.Fault.Error` : « vitesse validée stable » câblée sur « pas de défaut synchro ». Inerte aujourd'hui, **actif avec T181-16** ; pas dans ses objectifs. | `PRG_04:684,720` | F — à inscrire en critère explicite de T181-16. |
| **SEC-4** | Pas de temps mort directionnel au redémarrage à chaud — **confirmé**, mais **mécanisme attribué faux** (voir §1). | `FB_Winch.st:141-159,165-168,211` ; `FB_WinchOutputInterlock.st:97-116,181-183` | F (gap) / mécanisme ≠ B2. |

---

## 1 · Vérification des affirmations centrales

### B2-S1 — `StepDelay` TON mort → interlock de cadence à **créer** : CONFIRMÉ (F)
`FB_WinchOutputInterlock.st` : `StepDelay(IN := FALSE, …)` aux **6** sites (`:99,213,219,227,233,243`). `StepDelay.Q` jamais lu. `AuthorizedStep := RequestedStepClamped` direct (`:246`), commentaire `:240-242` assume que la tempo est « gérée par le métier ». **Aucun interlock de cadence côté barrière finale.** T181-01 le **crée** (nouveau FB + 2 instances + mémoire d'état dans le POU le plus critique). Le contrat T181-01 (AC1, « rendre vert 7/7 ») parle encore de *fiabiliser* — or TC-012/013/021/022 = watchdog frein / latches / temps morts, **pas** une cadence. ⇒ T181-01 mélange « réparer 4 TC C4 à interface figée » et « concevoir un nouveau FB safety 2-niveaux » sous 1 ticket.

### B2-S3 / D18 — gap CONFIRMÉ (F), mécanisme INFIRMÉ (F)
- Réel : gate `§2` de `FB_Winch` (`:141-159`) force `CommandedDirection := 0` + `RETURN` à chaque scan `Enable=FALSE`. Au retour d'`Enable`, `§5:211` `IF (CommandedDirection = 0) AND (Direction <> 0) THEN CommandedDirection := Direction` → **adoption immédiate**, `DirectionChangeDelay` (`:205`) jamais armé. Barrière : gate `:101-102` remet `DeadTimePending := FALSE` ; `§4bis:181-183` ne rearme que si `NOT MotorRequest` ≥1 scan — or `FB_Winch` sort `StepNumber:=1` + relais dès le 1ᵉʳ scan (`:261-262`) → `MotorRequest=TRUE` immédiat → **aucun temps mort, ni métier ni barrière**.
- **`FirstScanDone` n'est PAS la cause** (`:97,165-168` = flag « 1ᵉʳ scan de vie de l'instance »). B2 / §13-D18 visent la mauvaise ligne. **Si T181-05 “corrige FirstScanDone”, le gap reste ouvert.** Le correctif doit cibler le **front montant d'`Enable`** (retenir `CommandedDirection` ou armer un temps mort à la ré-activation).
- **Routage douteux** : D18 = changement de comportement sécurité C4, rattaché à T181-05 (C3, « extraction interne, interface inchangée »). Déplacer vers T181-01 (déjà C4, propriétaire du temps mort) ou tâche dédiée.

### B2-§1.1 — `Mode` VAR_INPUT ? `ContactorsCheck.StuckClosed` sortie publique ? CONFIRMÉ (F) x2
- `FB_Winch.st:18` : `Mode : E_Mode;` sous `VAR_INPUT`, **jamais lu** (307 l.). Câblé `PRG_04:671,702`. ⇒ D09/T181-05 « suppression nette, interface inchangée » est **contradictoire** (le retrait édite `PRG_04`).
- `ContactorsCheck : ST_ContactorCheck` = `VAR_OUTPUT` (`:72`), `.StuckClosed` écrit `:296` **et relu interne** `:123` (`instCauses[1].Active` → `FB_Winch.Fault`). Publié `PRG_04:803,860` → bus `Data.WinchM1State` → IHM/Supervision. ⇒ D07/T181-03 : déplacer la **détection** vers `FB_Safety_Winch` laisse ouvert (a) le **champ de sortie** `ContactorsCheck.StuckClosed` (le supprimer casse les consommateurs ; le garder impose de le ré-alimenter depuis Safety), (b) la cause interne `instCauses[1]`. Objectif « grep corps = 0 assignation » ne couvre ni l'un ni l'autre.

### B2-§4.1 — exécution séquentielle mono-tâche PRG_02→07 : CONFIRMÉ (F/H)
`PRG_04:4` « tâche PLC position 4, après PRG_03 ». Accès symbolique direct/synchrone `PRG_03_Modes_Cycle.Data.*` (amont) **et** `PRG_06_Outputs.instWinchOutputInterlockM1.*` (aval, `:800,804`). `config.yaml` : `cycle_time_ms: 10`. Les commentaires « lag 1 scan » (`PRG_04:208-209,215-216,517`) sont **intra-`PRG_04`**. ⇒ prémisse « 3 POU / 3 tâches → latence » de plan §4.1 **fausse** ; flux `FB_DiveSearch (instancié PRG_03) → PRG_03.ReqProgram → PRG_04` = **intra-cycle**. Vrai point (bien relevé par B2) : gating sur front `DescentActive` + maintien descente joystick post-fond (`KoboldBottomTouchLatched` `PRG_04:487-504` coupe `StartStop`). **I** : config de tâches CODESYS elle-même non lue (AGENTS.md évoque 4ms/20ms/10ms — probablement safety/comm/autres POU).

### B3 — le harnais existe-t-il vraiment ? **LARGEMENT SUR-ESTIMÉ (F)**
- `FB_Main_EndToEnd.st` chaîne bien PRG_02→07 via `FB_TestHarness_PRG_0x` (`:46-51,56-131`). Entrée registre `MAIN_EndToEnd` présente. `test_main_end_to_end.st` = **96 l., 2 scénarios**. ✅ conforme.
- **MAIS `FB_TestHarness_PRG_04.st` (utilisé par le mégabloc) = 196 l., ré-implémentation manuelle simplifiée, PAS le PRG_04 réel.** `instWinchM2`, `instWinchSync`, `instBucket` **déclarés (`:39-44`) jamais appelés**. Seuls `instSafetyWinchM1/M2` + `instWinchM1` tournent. `MaxStepAscent := 5`, `CfgMaxStepDescente := 3`, `TopLimitM := 7.5` **en dur** (`:169-170,94`). **Aucun** agrégateur de clamp, **aucun** SEL M1/M2, **aucune** taxonomie de permits §5, **aucun** `FB_WinchOutputInterlock`. B3 (SPEC l.18) **confond** ce stub avec `test_prg_04_treuils_benne.st` (test unitaire PRG_04 qui, lui, embarque le corps réel via `source_prg:`).
- Conséquence : « **on l'étend, on ne le bâtit pas** » (SPEC l.7, plan §0) est **faux pour ce qui compte**. Tester clamp M1≠M2, régression M1 sous jog benne, `SyncDeviationWarn`→M1 ET M2, `FinalInterlockGoverned` exige de **reconstruire** `FB_TestHarness_PRG_04` en miroir de `PRG_04 §1-§8`. Efforts « M » de B3 §5.1/5.3 optimistes → **L**.
- **Dérive** : ce stub = copie manuelle de `PRG_04`, non gardée. Chaque phase T181 qui édite `PRG_04 §3/§6` doit ré-éditer le stub en lockstep → **pattern REX `PRG_10_Outputs_LD`** (tests verts sur code non représentatif). Non signalé par les 3 passes.

### `SEL` `FB_Winch.st:248` — B2 a raison (F)
`SEL(CommandedDirection = -1, DelayAscent, DelayDescent)` : garde vraie (descente) → IN1 = `…Descent` ✅. **Valeur correcte** ; seul le nom se lit à l'envers. Revue #1 **sur-estime** (smell de lisibilité, pas un bug). **En revanche D10 est réel (F)** : `:248` réutilise `DirectionInterlockDelay{Ascent,Descent}` pour `EffectiveStepDelay` (tempo de rampe palier `BusinessStepDelay` `:250-253`), distincte du vrai interlock direction (`:199-208`). Couplage caché + `+ T#100ms` en dur.

### Autres P0 vérifiés
- **D05 (F)** : clamp M1 (`PRG_04:679-681`) ≠ M2 (`:716-717`). Comptes réels : M1 asc = 5 cond / desc = 1 ; M2 asc = 7 / desc = 3. Plan §0 dit « ≈2 vs ≈4 » — **chiffres imprécis**, qualitatif OK.
- **D13 (F)** : `IF instBucket.M2_ForceSlowSpeed THEN` reconstruit `M2_SpeedStepTableActive` ~24 affectations `PRG_04:405-429`.
- **`M2_ForceSlowSpeed` — rename sous-compté (F)** : plan §6 + T181-09 listent `PRG_04:285-288,716-717 + FB_Bucket`. Grep réel : **aussi** `:405,710,717,969` + champ `ST_BucketHMIState` + sortie `FB_Bucket`. (Le grep-guard rattraperait, mais périmètre affiché faux.) `ForceMinSpeedStep`, lui, est complet.
- **FB_SpeedStep (F)** : `MaxStepNumber` seul (`:24`), pas de `MinStepNumber` ; plafond `:203-205` ; `CASE 0..5` + `ELSE→0`. L'ajout `LIMIT(1, MinStepNumber, MaxStepClamped)` après plafond, avant CASE est cohérent. ✅

---

## 2 · Cohérence inter-livrables

### 2.1 Plan §13 ↔ bloc TASKS.yaml — incohérences restantes

| Sujet | §13 dit | Bloc TASKS dit | Verdict |
|---|---|---|---|
| T181-08 scindé 08a/08b | à scinder | 1 seule entrée, « ≥ N cycles » toujours là | ❌ |
| D18 | ajouter au registre → T181-05 (+garde T181-01) | **absent**, T181-05 + T181-01 inchangées | ❌ |
| Phase 0/0b « interface inchangée » | requalifier « réduction/additive contrôlée » | en-tête bloc OK, **mais** T181-05 corps + objectif « diff VAR = suppression nette » ; T181-02/03 « interface strictement inchangée » | ⚠️ auto-contradictoire |
| `bloque_par` | `T181-00←[T169-A]`, `T181-01←[T181-00, T175]` | `T181-00←[T169-A]` ✅ ; `T181-01←[T181-00]` — **T175 manquant** | ⚠️ moitié fait |
| T181-14 scindé 14a/14b | à scinder | 1 entrée | ❌ |
| T130/T131/T135/T096 housekeeping | passer ❌ | ⏸️/🔍 non clôturés | ❌ (§13 dit « à l'insertion ») |
| D13 en arrêt humain T181-06 | change #5 | **contrat T181-06 : DÉJÀ FAIT** (AC7b/AC7c). Mais TASKS T181-10 porte encore « D13 tranchée » comme objectif | ⚠️ contrat en avance sur plan ET TASKS |

**Le bloc TASKS n'intègre quasiment aucun des 5 changements structurants de §13.** Fondre §13 dans le corps (v0.2) **avant** de régénérer les entrées.

### 2.2 B3 couvre-t-il les vecteurs que B2 dit manquants ?

| Vecteur B2 | Dans B3 ? |
|---|---|
| Modèle frein + contacteurs retombés (T178 / T180 CAS-001) | ✅ **écrit** (SPEC §2.2, HARN-74/80) — mais base de départ (stub) ne pilote rien de tout ça. Papier ≠ réalité. |
| Hot-restart D18 | ✅ HARN-75 — mais **mauvais mécanisme** (`FirstScanDone`). Oracle bon, libellé trompeur. |
| Non-bypass interlock interne par `Bypass.Global` (`PRG_04:695`) | ❌ **absent** |
| Indépendance des 2 jeux de seuils de cadence | ❌ **absent** |

### 2.3 Contrats

- **T181-06** : **bon**, en avance sur le plan (AC7b/AC7c/AC5 intègrent B2-§4.3). Seul point : AC4 « latence en cycles » repose sur la prémisse 3-tâches → reformuler « intra-cycle + gating front `DescentActive` ».
- **T181-01** : **incomplet vs §13 #4**. AC3 « paramètres nommés distincts » < « zéro variable/GVL partagée ». Manque : argument PLr, critère site chiffré, « signature sécurité = essai site », non-bypassabilité par `Bypass.Global`, D18/hot-restart. `scope.allowed` inclut `FB_Winch.st` « pas d'interface » — or ajouter des seuils de cadence à `FB_Winch` (qui n'en a aucun) = constantes en dur (à acter) **ou** nouvelle entrée = cassure d'interface avant la refonte struct. Non tranché.
- **T181-11** : **bon**. Couvre D15. RAS.
- **Contrats manquants** : **T181-08** (C4, refonte interface + shadow — le plus risqué, sans contrat), **T181-10** (C4, agrégateur clamp), **T181-16** (C4, survitesse). 3× C4 sans objectifs testables formels → viole « contrat obligatoire dès C2 ». Le plan §8 ne prévoit de contrat que pour 01/06/11.

---

## 3 · Ce que les 3 passes ont TOUS manqué

1. **`FB_TestHarness_PRG_04` est une ré-implémentation manuelle divergente de `PRG_04`** (196 l., M2/sync/bucket déclarés jamais appelés). La thèse « étendre, pas bâtir » de B1/B3 tombe. Copie manuelle non gardée ⇒ dérive garantie = REX `PRG_10_Outputs_LD`. **Le plus grave.**
2. **`FB_WinchSync` / `FB_Winch_Symmetry` jamais dans le périmètre d'interface.** Le clamp `SyncDeviationWarn` (`PRG_04:679,681,716,717`), `SafeStopMx_Active` couplé (`:653-654`), `EffectivePermit` (`:656-659`) dépendent de `instWinchSync.SyncActive/.SyncDeviationWarn/.Fault`. La refonte `DriveRequest` spécifie `FB_Winch` isolé ; l'**arbitrage** sync reste `PRG_04` et n'est pas cadré. `FB_Winch_Symmetry` n'apparaît dans aucune des 21 tâches.
3. **`GVL_PERSISTENT` / RETAIN pour la table d'apprentissage** (~40 REAL) : T181-15 ne dit rien sur migration (ajout champs RETAIN → CODESYS peut réinitialiser toute la zone selon l'ordre de déclaration), init 1ʳᵉ mise en service, détection corruption (valeur apprise absurde → seuil `appris+1,5` → `SafeStop` intempestif, ou seuil trop haut = danger). `grep learn GVL_PERSISTENT.st` = 0. `GVL_PERSISTENT` est en `M` dans `git status`. Aucun garde-fou de plausibilité spécifié.
4. **Ordre d'import CODESYS face au changement de DUT** : `ST_ContactorCheck`, `ST_WinchState`, `ST_WinchInterPrg`, `ST_SafetyWinch` partagés avec `PRG_07`, `GVL_Troubleshooting`, IHM. Le plan §10 ne mentionne pas `PRG_07` ni les `_TYPES` supervision dans l'ordre → build cassé entre 2 imports.
5. **Appelants transverses diag treuil** : `PRG_04:800-892` publie ~90 champs lus par `PRG_07` / `GVL_Troubleshooting` (**les deux en `M` dans `git status` — travail en cours**). `ST_SafetyChecklist.st` + `FB_TroubleshootingView.st` modifiés HEAD. Collision non tracée dans le §2 de réconciliation.
6. **`FB_SimBench` / `FB_Sim_*`** (en `M`) : T181-08 « + SimBench » en 1 ligne, aucun objectif testable. `FB_Sim_Translation` suggère un `FB_Sim_Winch` équivalent — non audité.
7. **2 agents actifs sur la zone** : T175 (⏳, C4, scope `CODE/H_TREUILS_BENNE/**`) et T169-A (⏳ AGY-01, `FB_Main_EndToEnd`). `git status` HEAD : `FB_Safety_Emergency*`, `FB_Winch.xml`, `FB_Winch_Symmetry.xml`, `PRG_04..07.xml` déjà modifiés non commités. **Pas de point de départ figé.**

---

## 4 · Verdict

**Une fois §13 fondu, le triptyque ne donne pas encore un plan exécutable « du premier coup ».** Gouvernance saine (harnais d'abord, C4 d'abord, 3 arrêts humains, réconciliation, `fix:`+`guard:`). Mais 3 défauts bloquants, et §13 lui-même non intégré (le bloc TASKS ignore 4 des 5 changements).

### Les 3 changements restants, priorisés

| # | Changement | Pourquoi bloquant | Effort |
|---|---|---|---|
| **1** | **Refaire le socle T181-00 sur la réalité du harnais.** Acter que `FB_TestHarness_PRG_04` est un **stub à reconstruire** (miroir fidèle de `PRG_04 §1-§8`), pas à étendre + **gate d'égalité logique stub ↔ `PRG_04`** (ou stub généré) pour tuer la dérive. Corriger B3. Rebaser sur un HEAD propre (commiter/stasher les `M`, coordonner T169-A / T175). | Sinon tout teste du code non représentatif = REX `PRG_10_Outputs_LD`. | L (vs « M » annoncé) |
| **2** | **D18 : reformuler et re-router.** Cible = **front montant d'`Enable`** de `FB_Winch` (retenir `CommandedDirection` / armer un temps mort à la ré-activation), **pas** `FirstScanDone`. Rattacher à T181-01 (C4) ou tâche dédiée. Corriger HARN-75. | Gap sécurité C4 + le fix spécifié ne le ferme pas. | M |
| **3** | **Compléter T181-01 + créer les contrats T181-08 / -10 / -16.** T181-01 : indépendance physique des 2 jeux de seuils (zéro GVL/var partagée), non-bypassabilité par `Bypass.Global`, où vivent les seuils (constantes FB vs entrée — trancher), argument PLr, critère site chiffré, « signature sécurité = essai site ». T181-08/10/16 = C4 sans objectifs testables. | 4 tâches C4 sans contrat ; l'interlock le plus critique cadré à la louche. | S-M |

### Sur-ingénierie à retirer

- **Shadow comparison (T181-08b, HARN-43)** : oracle « ancien == nouveau » compare à un référentiel **connu buggé** (D05/D08/D13), faux dès que T181-12/13 injectent un plancher. **Remplacer par** table d'attendus écrite à la main (déjà prévue SPEC §4). Garder juste un tag Git avant bascule.
- **`FB_WinchStepShaper` en FB extrait séparé** : la tempo de rampe existe (`BusinessStepDelay` TON `:250-253`). Extraire FB + interface + TC isolés = cérémonie. **Suffit** : renommer le paramètre (découpler de `DirectionInterlockDelay*`), garder le TON inline. `FB_WinchDirectionInterlock` (logique `§5` réelle), lui, se justifie.
- **`FB_WinchRateInterlock` en 2 instances paramétrables** : pour un filet « ne doit jamais agir en nominal », **2 constantes en dur** (safety nu / safety+marge) suffisent et **renforcent** l'indépendance (rien à corrompre). Éviter le FB paramétrable riche.
- **T181-19 (`SyncCoupled` diag) en tâche C2 séparée** : 1 affectation + 1 grep-guard → fusionner dans T181-08.

### Faits / hypothèses / incertitudes
- **Faits** : tout ce qui est marqué (F) ci-dessus, vérifié par lecture code.
- **Hypothèses** : exécution mono-tâche PRG_02→07 (config de tâches CODESYS non lue directement).
- **Incertitudes** : `test_prg_04_treuils_benne.st` embarque-t-il vraiment le corps complet de `PRG_04` via `source_prg:` (rapport archivé le suggère) — à confirmer ; existence d'un `FB_Sim_Winch`.
