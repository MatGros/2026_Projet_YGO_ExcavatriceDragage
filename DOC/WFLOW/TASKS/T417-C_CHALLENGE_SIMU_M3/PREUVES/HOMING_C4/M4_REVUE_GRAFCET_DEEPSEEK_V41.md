🟥 **BLOCK — FB_CycleMachineHoming v1 : NON INTÉGRABLE EN L'ÉTAT**

**Verdict :** 7 constats bloquants (dont 1 erreur de compilation) + 11 avis. Revue strictement statique.
**Impact en une phrase :** le bloc ne compile pas (`PendingClose` non déclaré) et, une fois compilé, peut latcher un défaut « perte de datum » et forcer `MachineHomed := FALSE` après une simple bascule `Enable`, sans qu'aucun mouvement n'ait eu lieu.
**Horodatage :** non fourni par l'environnement. **Durée :** revue statique unique, outillage non exécuté (source reçue en texte, pas de dépôt ni de compilateur accessible dans ce tour).

---

## Niveau 1 — Invariants vérifiables

1. **Le bloc compile** — ❌ FAIL. `PendingClose := FALSE;` en région §7 n'est déclaré ni en `VAR_INPUT`, `VAR_OUTPUT`, `VAR` ni `VAR CONSTANT`.
2. **`CommitPublished` et `MachineHomed` ne dépendent pas de l'autorisation `Enable`** — ❌ FAIL. §7 force `CommitPublished := FALSE` et `MachineHomed := FALSE` sur `Enable = FALSE`.
3. **Aucun faux défaut « perte de datum » sur désactivation** — ❌ FAIL. Le reset de `CommitPublished` en §7 fait retomber `MachineHomedRaw` au scan suivant ; §3 latche alors `ReHomingAckRequired := TRUE` et §5 active la cause latching `CST_CauseHomingLostInMotion` alors que `WinchesMechanicallyStopped = TRUE` et que rien n'a bougé (cas `BucketOffsetValid = FALSE`).
4. **`ReHomingAckRequired` est acquittable par un re-homing réussi** — ❌ FAIL. Seul `ResetEdge.Q AND WinchesMechanicallyStopped` (§3) l'efface ; un commit HX4 réussi ne l'efface pas et l'entrée HX0 ne teste pas `NOT ReHomingAckRequired`.
5. **« M2 seul » en HX1 est imposé sur les permis** — ❌ FAIL. `AllowAscent/AllowDescend := NOT Step1MoveCutoff` sans terme `JoystickWinchSelectArbitrated = 2` (§8 HX1 et §9). `CouplingViolationTimer` ne couvre que HX2/HX3 → aucune détection d'un mouvement M1+M2 en HX1.
6. **`MachineHomingLossSafeStop` n'est pas masquable par `Enable`** — ❌ FAIL. §7 force l'output à `FALSE` ; un signal de sécurité ne doit pas être supprimé par l'autorisation interne du bloc.
7. **Chaque instance de timer IEC est invoquée une seule fois par scan** — ❌ FAIL. `Step3Timer` est appelé jusqu'à 3 fois dans le même scan de HX3, plus en §1, §4 et §7.
8. **Les ordres treuils sont effectivement produits (ou supprimés du contrat)** — ❌ FAIL / non démontrable. `CmdWinchM1/M2` (`RunRequest`, `ReqAscent`, `ReqDescend`, `StepTgt`) et `CmdBucketOpen/Close` sont remis à zéro en tête de scan et **jamais** mis à `TRUE` nulle part.
9. **Un capteur TOP collé est détecté** — ❌ FAIL. Avec `TopPositionSensor` bloqué à `TRUE` : HX2 → HX3 en un scan, HX3 remet `Step3AccumTime := T#0s` à chaque scan → accumulation impossible, `ClimbTimer` jamais actif (HX2 quitté immédiatement) → boucle sans défaut ni sortie.
10. **Un timeout couvre HX3 et le cycle global** — ❌ FAIL. HX3 dépend d'une descente manuelle cumulée ~4 s, sans aucun timeout ; HX1 et HX4 n'ont pas non plus de timeout de séjour.
11. **Les fronts opérateur ne sont pas perdus silencieusement** — ❌ FAIL. `ValidatePressed` et `StartEdge` sont des pulses d'un scan, ET-és avec des conditions instantanées (`WinchesMechanicallyStopped`, `NOT JoystickDeflected`, `CouplingSettleTimer.Q`) — appui non satisfait = appui consommé sans retour.
12. **`CASE SeqStep` est exhaustif** — ❌ FAIL. Aucun `ELSE` ; tout état non listé (HX5/HX6 si présents dans l'enum) fige le bloc sans permis ni transition.
13. **Le forçage de step est soumis à `Enable` et à des préconditions** — ❌ FAIL. §4 s'exécute **avant** la gate §7 : le front `ForceStepApplyEdge` est consommé et le step réécrit en HX0 par §7. Aucun contrôle `WinchesMechanicallyStopped` / `NOT TopPositionSensor` avant forçage vers HX3/HX4.
14. **La table de causes est bornée et initialisée** — 🟡 ADVISORY. `instCauses[7..15]` jamais renseignées (structs par défaut) ; comportement dépendant de `FB_FaultCore`.
15. **Les sorties de cycle de vie sont cohérentes** — 🟡 ADVISORY. `Lifecycle.Done := CommitPublished AND (SeqStep = HX0)` reste `TRUE` en permanence après le premier commit ; `Lifecycle.Busy := TRUE` en HX7 alors que `MachineHomingActive = FALSE`.
16. **Aucune sortie morte** — 🟡 ADVISORY. `HomingModeBActive` n'est jamais mise à `TRUE` ; `CablePosM1/M2` et `CoherenceLimitM` sont déclarées et jamais lues (aucun contrôle de cohérence M1/M2 pendant la montée couplée).
17. **`MachineHomingStepAtError` capture bien l'étape au latching** — 🟡 ADVISORY. `LatchedEdge` est calculé en §1 sur la valeur `Fault.Latched` du scan précédent (assignée en §5) → capture décalée d'un scan ; jamais capturée du tout quand `Enable = FALSE` (RETURN en §7 avant §10).
18. **La conformité aux documents métier est démontrée** — ❌ FAIL / non prononçable. `DOC/WFLOW/MISE_EN_SERVICE/PLAN_REFONTE_GRAFCET_HOMING_20261118_v1.0.md` et `DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md` (F09.08) ne sont pas accessibles dans ce tour : les règles de persistance `CommitPublished`, le contrat exact de `ST_ProgramWinchRequest` et la sémantique « palier 1 » restent non vérifiées.

---

## Niveau 1 bis — Argumentaire technique

1. **Compilation.** Le seul identifiant non déclaré est `PendingClose`. Le reste des locaux est couvert. Correction triviale mais bloquante pour tout build.

2. **Perte de datum fantôme — scénario exact.** Scan N : machine homée, `CommitPublished = TRUE`. Scan N+1, `Enable := FALSE` : §3 s'exécute avant §7 et voit encore `CommitPublished = TRUE` → pas de perte ; §7 efface `CommitPublished` et sort. Scan N+2 : §3 recalcule `CommitOrOffsetValid = BucketOffsetValid`. Si cet offset externe est `FALSE`, `MachineHomedRaw` tombe, `MachineWasHomed` était `TRUE` → `ReHomingAckRequired := TRUE`, puis §5 active la cause latching `CST_CauseHomingLostInMotion` avec le texte « perte de datum **en mouvement** » alors que `WinchesMechanicallyStopped = TRUE`. Au réarmement, `Fault.Latched` bloque HX0 : Reset obligatoire. Un simple cycle Enable produit un défaut latché.

3. **`ReHomingAckRequired` sans issue interne.** Rien ne l'efface hors `ResetEdge.Q AND WinchesMechanicallyStopped`. Un re-homing complet aboutit à `CommitPublished := TRUE` mais `MachineHomingRaw` reste `FALSE` (terme `NOT ReHomingAckRequired`), donc `MachineHomed = FALSE` et `M3Locked = TRUE` en N1. L'acquittement passe aujourd'hui uniquement par le fault latching induit — couplage implicite et fragile.

4. **Permis HX1.** §8 HX1 vérifie `JoystickWinchSelectArbitrated = 2` **uniquement** pour le compteur de garde 20 s (`Step1MovingCmd`). Les permis diffusés (`AllowAscent/AllowDescend`) n'ont pas ce terme, alors que `CmdWinchSelect := 2` n'est qu'une *demande*. Si l'aval suit le sélecteur arbitré (0 = couple), M1+M2 bougent en HX1 hors spécification, sans `CouplingViolationTimer` (limité à HX2/HX3) pour le détecter.

5. **`Step3Timer` multi-appel.** En HX3 le timer est appelé avec `IN := FALSE` puis `IN := TRUE` dans le même scan (branche `Step3DescendEngaged`), et aussi avec `IN := TRUE` dans la branche de désengagement. Le démarrage repose sur la détection de front antérieur par la mémoire interne de l'instance : comportement conforme au compilateur CODESYS standard, mais non garanti par la norme et fragile. À consolider en un appel unique avec `IN` et `PT` composés, et capture de `ET` en un seul point.

6. **Ordres treuils.** Les deux structures de commande sont zéroées en tête de scan et en §7 mais jamais armées : soit la commande réelle est construite dans PRG_03/PRG_04 à partir des permis (dans ce cas `CmdWinchM1/M2` et `CmdBucketOpen/Close` sont des sorties mortes à retirer du contrat), soit le homing ne peut physiquement pas bouger. Point à trancher sur `ST_ProgramWinchRequest`, non démontrable ici.

7. **Capteur TOP collé / absence de timeout.** `ClimbTimedOut` exige `ClimbCommandActive` (HX2 + homme-mort + traction). Un TOP collé vide HX2 en un scan : le timeout de montée est structurellement inatteignable. HX3 n'a aucun garde-temps. Aucun compteur d'itérations HX2→HX3→HX1. Une défaillance capteur ou une butée mal réglée produit un cycle infini avec message opérateur figé sur « TOP touche ! Descendre ».

8. **Fronts opérateur perdus.** `ValidatePressed` (front de `BtnValidation` OU `BtnConfirmHomingBucket`) est un pulse d'un scan. En HX4, il est ET-é avec `WinchesMechanicallyStopped` et `NOT JoystickDeflected` : un appui pendant la décélération est consommé sans effet ni message. Comportement identique pour `StartEdge` en HX0 N2.

9. **Divergence §8 / §9.** Les sorties de permis sont recalculées deux fois (branches CASE puis bloc §9). C'est déjà divergent sur HX1 (le bloc §9 ne teste pas le sélecteur). Toute évolution future d'un seul des deux blocs crée une incohérence silencieuse.

---

## Niveau 2 — Plan d'action chirurgical

**A1 — Déclarer ou supprimer `PendingClose`**
Localisation : `VAR` (déclarations) ou §7.
Ancre : `    CommitPublished := FALSE;` puis `    PendingClose    := FALSE;`
Action exacte : si `PendingClose` est requis par un consommateur aval, le déclarer en `VAR` (`PendingClose : BOOL;`) et lui donner une sémantique écrite ; sinon supprimer la ligne.
Outil déterministe : `rg -n "PendingClose" <fichier>` puis compilation CODESYS/MATIEC du POU.
Risque si ignoré : build refusé, aucun test possible.

**A2 — Rendre le datum indépendant de `Enable`**
Localisation : §7 (`IF NOT Enable THEN … RETURN;`).
Ancre : `    CommitPublished := FALSE;` / `    MachineHomed   := FALSE;`
Action exacte : retirer ces deux affectations de la gate `Enable`. `CommitPublished` ne doit être remis à zéro que par `ResetEdge` (ou par invalidation explicite de la référence benne). `MachineHomed` étant recalculé en §9 hors `Enable`, ne plus le forcer.
Outil déterministe : test unitaire TcUnit — `Enable := FALSE` sur 2 scans, vérifier `MachineHomed` stable et `ReHomingAckRequired = FALSE`.
Risque si ignoré : défaut latché fantôme après chaque désactivation (blocage exploitation).

**A3 — Neutraliser la détection de perte pendant `NOT Enable`**
Localisation : §3.
Ancre : `IF FirstScanDone AND NOT MachineHomedRaw AND MachineWasHomed THEN`
Action exacte : conditionner par `AND Enable` et geler `MachineWasHomed` quand `NOT Enable` (`MachineWasHomed := MachineWasHomed;` sinon mise à jour).
Outil déterministe : scénario de test A2 avec `BucketOffsetValid = FALSE`.
Risque si ignoré : cause latching « perte de datum en mouvement » alors qu'aucun axe n'a bougé.

**A4 — Acquitter `ReHomingAckRequired` par un re-homing réussi**
Localisation : §8 HX4 (branche commit) ou §3.
Ancre : `            BucketCommit.CommitClose := TRUE;`
Action exacte : ajouter `ReHomingAckRequired := FALSE;` au commit réussi (le re-homing vaut acquittement), et/ou exiger `NOT ReHomingAckRequired` dans la condition d'entrée HX0 pour forcer un Reset explicite.
Outil déterministe : test — perte de datum, re-homing complet, vérifier `MachineHomed = TRUE` sans Reset intermédiaire (ou message explicite si Reset exigé).
Risque si ignoré : machine définitivement non référencée après un re-homing pourtant réussi.

**A5 — Imposer « M2 seul » sur les permis HX1**
Localisation : §8 HX1 et §9 `ELSIF (SeqStep = HX1)`.
Ancre : `        AllowAscent  := NOT Step1MoveCutoff;` / `        AllowDescend := NOT Step1MoveCutoff;`
Action exacte : `AllowAscent := NOT Step1MoveCutoff AND (JoystickWinchSelectArbitrated = 2);` idem `AllowDescend` ; idem dans §9. Étendre `CouplingViolationTimer` à HX1 pour détecter un sélecteur couplé pendant une sollicitation.
Outil déterministe : test d'état — HX1, sélecteur arbitré = 0, traction : vérifier `AllowAscent = FALSE`.
Risque si ignoré : M1 entraîné en HX1, hors spécification, sans détection.

**A6 — Découpler `MachineHomingLossSafeStop` de `Enable`**
Localisation : §7.
Ancre : `    MachineHomingLossSafeStop := FALSE;`
Action exacte : supprimer l'affectation de §7 ; recalculer l'output en dehors de la gate (`MachineHomingLossSafeStop := HomingLossLatched AND NOT WinchesMechanicallyStopped;` en fin de bloc, après §9).
Outil déterministe : test — `Enable := FALSE` avec `HomingLossLatched = TRUE` et axes en mouvement : l'output doit rester `TRUE`.
Risque si ignoré : suppression d'un ordre d'arrêt contrôlé sur simple désactivation.

**A7 — Un seul appel de `Step3Timer` par scan**
Localisation : §8 HX3.
Ancre : `                    Step3Timer(IN := FALSE, PT := T#0s);` puis `                    Step3Timer(IN := TRUE, PT := Step3RemainingTime);`
Action exacte : calculer `Step3TimerIn` et `Step3TimerPt` en variables locales dans la branche, puis un unique `Step3Timer(IN := Step3TimerIn, PT := Step3TimerPt);` en fin de branche, et reconstruire l'accumulation sur ce `ET` unique (accumulation au relâchement, mise à zéro sur `TopPositionSensor`).
Outil déterministe : test temporel — descente 2 s, relâchement, descente 2 s, vérifier `Step3ClearanceDone = TRUE` à ~4 s cumulées et pas avant.
Risque si ignoré : accumulation dépendante du compilateur, dégagement TOP non conforme.

**A8 — Trancher le contrat de commande treuil/benne**
Localisation : `VAR_OUTPUT` `CmdWinchM1/M2`, `CmdBucketOpen/Close`.
Ancre : `    CmdWinchM1.RunRequest := FALSE; CmdWinchM1.ReqAscent := FALSE;` (seule affectation existante)
Action exacte : si PRG_03/PRG_04 construisent la requête depuis `AllowAscent/AllowDescend/SoftLimitsOff/CmdWinchSelect`, retirer ces sorties du contrat et documenter ; sinon les armer dans chaque phase et vérifier la sémantique de `StepTgt` (« palier 1 » non exprimé aujourd'hui : `StepTgt := 0` partout).
Outil déterministe : `rg -n "CmdWinchM1|CmdWinchM2|CmdBucketOpen|CmdBucketClose" <projet>` pour cartographier les lecteurs réels.
Risque si ignoré : soit sorties mortes trompeuses, soit homing physiquement impossible.

**A9 — Détecter TOP collé et borner HX3**
Localisation : §2 et §8 HX3.
Ancre : `        IF TopPositionSensor THEN` (reset systématique de `Step3AccumTime`)
Action exacte : ajouter un `TON` de séjour HX3 (ex. 60 s) → `TransactionAbort` ; ajouter un compteur d'itérations HX2→HX3 (max N) → `HX7_FAILED` avec message dédié ; ne plus remettre `Step3AccumTime` à zéro que sur une transition `FALSE → TRUE` du capteur, pas à chaque scan.
Outil déterministe : test — `TopPositionSensor := TRUE` forcé, vérifier sortie en défaut sous le délai configuré.
Risque si ignoré : cycle infini sans diagnostic sur défaillance capteur ou butée.

**A10 — Mémoriser les appuis opérateur**
Localisation : §1 (fronts) et usages HX1/HX2/HX4.
Ancre : `ValidatePressed := BtnValidationEdge.Q OR HomingBucketConfirmEdge.Q;`
Action exacte : remplacer le pulse par un latch `ValidatePending` remis à zéro à la consommation effective ou au relâchement du bouton, et afficher « relâcher puis valider » quand la condition n'est pas remplie.
Outil déterministe : test — appui pendant `WinchesMechanicallyStopped = FALSE`, vérifier la prise en compte dès l'arrêt.
Risque si ignoré : appuis perdus, opérateur bloqué sans explication.

**A11 — Advisories groupés**
Localisation : §4 (forçage), §8 CASE, §5, §9, §10.
Ancre : `IF CfgCommissioningEnable AND ModeIsMaint2 AND ForceStepApplyEdge.Q THEN` ; `CASE SeqStep OF` (sans `ELSE`) ; `instCauses : ARRAY[0..15] OF ST_FaultCause`.
Action exacte : déplacer le bloc de forçage après la gate `Enable` et ajouter `WinchesMechanicallyStopped` + `NOT TopPositionSensor` pour les cibles 3/4 ; ajouter `ELSE` → `HX7_FAILED` ; dimensionner `instCauses` à `0..6` ou initialiser `[7..15]` ; `Lifecycle.Busy := CycleRunning AND NOT MachineHomingFailed` ; `Lifecycle.Done` en pulse ; `HomingModeBActive := ModeIsMaint2 AND CycleRunning` ou suppression ; suppression ou implémentation du contrôle `CablePosM1/M2` vs `CoherenceLimitM`.
Outil déterministe : revue de diff ciblée + compilation avec warnings d'initialisation activés.
Risque si ignoré : forçage en mise en service sans précondition d'arrêt, états figés silencieux, faux positifs de cohérence treuils.

---

**Limites de ce verdict :** aucun outil déterministe n'a été exécuté (pas de dépôt ni de compilateur dans ce tour) ; les deux documents métier cités en en-tête n'ont pas été lus. Les constats 1 à 7 sont démontrables par lecture du source fourni ; les constats 8 et 18 dépendent de l'aval (PRG_03/PRG_04) et de la spec, et limitent le verdict sans l'invalider.