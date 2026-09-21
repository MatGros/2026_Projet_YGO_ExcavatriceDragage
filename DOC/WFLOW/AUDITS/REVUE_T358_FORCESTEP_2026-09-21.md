# 🕵️ Revue indépendante — T358 · Forçage de step : saut immédiat, sans garde

> **Verdict** : `MINOR` · **Date** : 2026-09-21 · **Lot** : T358 (C4)
> **Reviewer** : agent à contexte frais (mandat LECTURE SEULE STRICTE), lancé par DSH21 (porteur du lot)
> **Objet revu** : `CODE/G_CYCLE/FB_CycleSemiAuto.st` + 8 fichiers de chaîne + gates + tests + contrat + note
> **Références** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T358_FORCESTEP_SANS_GARDE.yaml`,
> `DOC/WFLOW/CONTRACTS/NOTE_APPLICATION_T358_FORCESTEP_SANS_GARDE.md`,
> `DOC/WFLOW/CONTRACTS/BRIEF_T358_FORCESTEP_SIMPLIFICATION_SANS_GARDE.md`
> **Ancrage** : `HEAD = c9e1fbfe` à la prise (arbre `CODE/` propre vs HEAD pour `FB_CycleSemiAuto.st`,
> dernier commit le touchant : `d6e54377` / T347). Le reviewer n'a modifié AUCUN fichier du dépôt.

---

## 1. 🎯 Mandat et méthode

Le reviewer a reçu 10 affirmations à vérifier **par fichier:ligne réel**, plus 5 axes d'attaque imposés
(boucle de forçage, perte d'un garde-fou de sécurité indépendant, traçabilité du gate, régression de gate,
tests de complaisance). Il devait rendre `BLOCK | MAJOR | MINOR | PASS` avec, pour chaque constat,
fichier:ligne + preuve, puis (a) affirmations confirmées, (b) réfutées, (c) non vérifiables.

Gates qu'il a été autorisé à lancer (lecture seule) : `G517 . --selftest` → **PASS 13/13**,
`G517 .` → **PASS**, `G495 .` → **PASS**.
Interdits (écriture d'artefacts) : CI `run_tests.py`, bundlisation, `G200 --report`, `run_all_gates.py`.

---

## 2. ✅ Affirmations confirmées — 10/10, preuve ligne à ligne

| # | Affirmation vérifiée | Preuve rendue par le reviewer |
|---|---|---|
| 1 | Bloc de forçage sans les 6 gardes, **placé après la porte §2** et avant le repli `ErrorEdge` | bloc `FB:725-791` ; porte `:661` → `RETURN :722` → forçage `:741` → `IF ErrorEdge.Q THEN … State := AX_STAB` `:838-842` ; diff : **aucune ligne** de la porte §2 ni du `RETURN` touchée |
| 2 | Scan du forçage **sans aucune commande** + étape cible exécutée au scan suivant | neutralisation des 4 familles `:779-782` + `StateExecutionInhibit := TRUE` `:773` ⇒ CASE inhibé `:867`, remis à FALSE `:304` ; confirmé empiriquement par `TC-P04-027` |
| 3 | Abort **et** Reset neutralisent la consigne du même scan | `StepForceConsigne := StepForceTgt` `:615`, puis `:= CST_StepForceNone` sur Abort `:623` et Reset `:633`, tous deux **avant** `:741` ; fronts R_TRIG en tête de scan `:293`, `:296` |
| 4 | Table 23/23 **sans trou**, un trou serait un refus et jamais un AX0 silencieux | 23 branches `:745-767` pour 23 membres 0..22 (`E_AutoCycleStep.st:15-45`), `ForceStepCandidateValid := FALSE` avant le CASE `:742`, `ELSE` = rejet `:785-787`, 18 et 19 présents `:763-764` |
| 5 | Seule validation restante : la plage ; hors plage = pas de plantage | `:743` + `CST_StepForceMax := 22` `:286` ; test `TC-P04-030` avec 40 |
| 6 | Consigne jamais écrite par le FB, défaut sentinelle aux deux bouts, pas de boucle | `SetForceStepTgt` : 2 occurrences seulement (lecture `PRG_03:265`, acquittement `:294`) ; `ST_CycleCmd.st:24` et `FB:93` ; acquittement hors de tout `IF` de mode |
| 7 | `WaitingResume` intact (écrit + consommé) et forçage qui ne gèle pas l'étape | `:658`, `:695` (écriture) ; `:808-816` (consommation) ; `:775` (annulation par le forçage) |
| 8 | Signaux partagés retirés de la garde **toujours vivants ailleurs** | `KoboldImmersionQualified` : calcul `:1139` + consommateurs `:430, :874, :1168, :1171, :1175` ; `Fault.Latched` : `:547, :580, :793, :897, :913, :929` ; `BottomContextValid` : **0 occurrence** dans tout `CODE/` |
| 9 | Aucune donnée **persistée** n'alimente la consigne | `GVL_IHM.st:7` `VAR_GLOBAL` non RETAIN ; `GVL_PERSISTENT` sans `SetForceStepTgt` ; `ST_CycleCfg.st:13` inerte et sans lecteur |
| 10 | Contrat et note conformes au code livré (numéros d'origine compris) | `git show d6e54377` reproduit littéralement `:206`, `:625`, `:626`, `:628`, `:653`, `:656` ; les écarts relevés sont dans le **contrat** (AC2, objectif), pas dans la note |

### Défenses indépendantes non contournées (vérification exhaustive)

- **Chaîne AU et contrôle codeur intacts** : porte §2 inchangée, forçage après le `RETURN`.
- **Aucun mouvement créé par le forçage** : le scan du forçage n'émet aucune demande ; toutes les commandes
  de mouvement du CASE restent gatées — vérifié site par site (`RunRequest := DeadmanArmed AND JoystickPush/Pull`
  `:1069-1160`, `:1243-1277`, `:1380-1414` ; `:= CycleMotionPermit` `:799/1559/1562` ; `:= TRUE` uniquement
  sous geste `:1345-1349` ; `BucketCmd.ReqOpen := TRUE` sous geste `:1014-1015` ; `ReqClose/ReqStart` gatés
  `:1306, :1521, :992, :1465` ; gate continu §4 `:1653-1659`).
- **Frontière exacte du risque résiduel** : le **seul** interlock réellement perdu est celui de sortie de
  `AX_STAB` (`ResumeAfterFaultAvailable`, `:546-552` : cause disparue + AU + `DiveStartStopped` + joystick au
  neutre) — remplacé par une sortie à une valeur sans acquittement de cause. C'est le risque **documenté et
  accepté** (note §2 G2, contrat, et `TC-T358-002` qui le démontre).
- **Traçabilité outillage** : G517 branché en palier C (`run_all_gates.py:191`), **sans exemption ni
  allowlist** ; G495 **renforcé** (4 motifs interdits ajoutés, aucun contrôle supprimé sans remplacement).
- **Tests non complaisants sur le cœur** : joystick volontairement défléchi + homme-mort absent, hors plage 40,
  `Fault.Latched` établi puis saut réellement obtenu, sentinelle seule. Rapports : `HEAD` = 33/28/5 vs arbre
  = 36/31/5 avec **exactement les mêmes 5 échecs** ⇒ « zéro régression, +3 tests » **exact**.

---

## 3. 🚩 Constats du reviewer (13 · tous MINOR)

| # | Constat | Preuve citée | Traitement |
|---|---|---|---|
| 1 | Le contrat attribue l'acquittement au **FB** alors qu'il n'écrit jamais la consigne (G517 le lui interdit) | `AC2:70-71` vs `FB:789` et `PRG_03:294` ; idem `run_all_gates.py:189` | ✅ **Corrigé** (AC2 réécrit, commentaire du gate corrigé) |
| 2 | L'AC2 est « vérifié » par le test lui-même (le harnais écrit la sentinelle) : l'assertion annoncée n'existe pas | `contrat:76-77` vs `test:2004-2005` | ✅ **Corrigé** (le `verified_by` décrit ce qui est réellement observable ; l'acquittement réel est couvert **statiquement** par G517 — le harnais unitaire ne connaît pas PRG_03) |
| 3 | **« aucune course d'écriture IHM/PLC » est FAUX** : fenêtre entre la lecture du FB (`:615`) et l'acquittement (`PRG_03:294`) ⇒ **ordre opérateur perdu** | `FB:616` mémorisé avant le corps ; `PRG_03:293-295` écrit sans relire | ✅ **Corrigé dans le code** : acquittement par **compare-et-efface** (`PRG_03:206` lecture unique + `:294-300` effacement conditionné à l'égalité) ⇒ plus aucune perte |
| 4 | Objectif « rejetée **en silence** » contredit l'AC8 (« motif publié ») et le code | `contrat:45` vs `:149`, `FB:786-787` | ✅ **Corrigé** |
| 5 | La note annonce « 2 noms de tests » périmés : il y en a **4** | `:384`, `:408`, `:440`, `:465` | ✅ **Corrigé** (+ constat C3 enrichi) |
| 6 | Test unitaire de G495 incohérent après réécriture (rouge garanti) ; **préexistant**, non joué par défaut | `tests/test_g495_cycle_sat_contract.py:31,34,36` ; `run_all_gates.py:235-236` | 📋 **Documenté C9** — fichier **hors périmètre d'écriture** du lot ⇒ décision humaine |
| 7 | **G517 ne peut pas échouer** sur plusieurs classes : C4 comptage (permutation 18↔19 passe), C9 comptage, C1 liste noire, C6 4 jetons | `G517:129-130, 182-183, 106-108, 155-157` | ✅ **Gate durci** : liste blanche de conditions, table vérifiée contre l'énum, neutralisation intégrale, ancrage du calcul ⇒ `--selftest` **19/19** |
| 8 | Neutralisation par **Abort** sans aucun test | `FB:619-623` vs `TC-P04-032` | ✅ **Test ajouté** : `TC-T358-004` |
| 9 | AX18 forçable ⇒ **totalisateur** incrémentable depuis l'IHM sans passe réelle, aucun gate/test | `FB:1593-1595` | 📋 **Documenté C7/G7** — conséquence assumée ; garde-fou à décider |
| 10 | Aucun front sur la consigne : toute **réémission** IHM re-déclenche un saut (voulu) mais aucun gate ne borne ce risque | `FB:741-743` | 📋 **Documenté** (propriété voulue : re-jouabilité) — borne IHM à décider |
| 11 | **Hors lot** : `DivingRetryTrig := FALSE;` seule écriture ⇒ branche `AX_DIVING_RETRY` **morte** ; le forçage (20) en devient le seul chemin | `FB:428 + 848` | 📋 **Documenté C8** |
| 12 | **Hors lot** : suppression `G499_check_t291b_top_authority.py` dans `git status` (renommage T291-B) — aucune suppression de ce lot | `run_all_gates.py:150` pointe G505 | 📋 **Signalé** — exclu du commit T358 |
| 13 | `status: IN_PROGRESS` vs `execution.status: COMPLETED` vs `validation.status: PENDING` | `contrat:272` | ✅ **Corrigé** (`status: COMPLETED`) |

---

## 4. ⛔ Réfutées / non vérifiables (déclaration du reviewer)

- **RÉFUTÉ (forme, pas de code)** : AC2 « acquittement par le FB » ; note « aucune course d'écriture » ;
  objectif « rejetée en silence » ; note « 2 noms de tests ». *Le corps de code était conforme — ce sont des
  affirmations écrites qui étaient fausses.*
- **NON VÉRIFIABLE dans son mandat** : `G200_check_linkage.py --report`, `run_all_gates.py --palier C`,
  bundlisation, CI (écriture d'artefacts interdite). Seule la **fraîcheur du bundle par contenu** a été
  confirmée (`CODE_XML/CODE_Bundle.xml:54202` et `:54231` portent le nouveau câblage et l'acquittement).

## 5. ❓ Limites déclarées par le reviewer

1. **Course d'écriture en conditions réelles** : impossible de déterminer où et à quelle cadence l'IHM écrit
   (`GVL_IHM` est écrite par le panneau, aucun écrivain PLC dans `CODE/`) — la réfutation portait sur la
   **structure**, pas sur une mesure.
2. **Effet machine réel** du forçage sous défaut latché : non testable sans banc (la chaîne AU physique n'est
   pas modélisée par les tests STruC++).
3. **Test unitaire G495** : non exécuté (artefacts) — conclusion **déduite statiquement**.
4. **Comportement IHM** (réémission, bloc d'écriture) : dépend du panneau, hors dépôt.
5. `TOOLS/AGENT_WORKFLOW/tests/` n'est pas couvert par le palier C par défaut.

---

## 6. 🧾 Verdict de l'orchestrateur sur la revue

`MINOR` **accepté** : aucune des 10 affirmations du lot n'est réfutée sur le fond, aucune défense
indépendante n'est contournée, et les 3 constats de fond (perte d'ordre opérateur, contrat inexact,
gate contournable) ont été **corrigés dans le lot**, avec preuve de non-régression régénérée
(CI 32/37 dont 5 dettes préexistantes, `G200` PASS 0 KO / 2045 instances, palier C 50/55 dont 5 dettes
préexistantes, `G517` PASS `--selftest` 19/19).
Les constats 6, 9, 10, 11, 12 restent **ouverts et tracés** (dont 3 appelant une décision humaine) — ils ne
sont ni corrigés spontanément ni enterrés.
