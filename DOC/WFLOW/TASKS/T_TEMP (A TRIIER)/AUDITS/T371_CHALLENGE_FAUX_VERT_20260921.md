# 🔬 CHALLENGE AVANT TRANSMISSION — T371 « Faux vert de `ST_MotionChecklist` »

> **Tâche** : `T371` (C4) — entrée `DOC/WFLOW/TASKS.yaml:2-19`.
> **Brief challengé** : `DOC/WFLOW/CONTRACTS/BRIEF_T371_FAUX_VERT_MOTIONCHECKLIST.md` (87 l., **jamais transmis**).
> **Auteur** : orchestrateur (pré-transmission, **zéro ligne de `CODE/` écrite**, aucun commit).
> **Ancrage** : HEAD du dépôt au 2026-09-21 ; `CODE/` lu en lecture seule.
> **Méthode** : chaque affirmation du brief est rejouée en première main (`grep` + `read`, `fichier:ligne`).

---

## 1. VERDICT

🔴 **Le brief v1 n'est PAS transmissible en l'état.** Sa **borne de contrat §3 interdit précisément le
seul correctif nécessaire**, et repose sur une prémisse factuellement fausse : les sorties d'état à
« ajouter » sur `FB_WinchOutputInterlock.st` **existent déjà, sont déjà exposées, et sont déjà
routées** jusqu'à l'objet que le diagnostic lit. Le faux vert ne vient **pas** d'un défaut de
publication à la source : il vient d'une **consommation tronquée** dans `FB_TroubleshootingView.st`.

➡️ **Recommandation** : corriger le brief (v2, `BRIEF_T371_..._v2_TRANSMISSION.md`, préambule collé
en tête) puis transmettre. **Aucune modification de `FB_WinchOutputInterlock.st` n'est nécessaire.**

---

## 2. LE SYMPTÔME EST RÉEL — ET MIEUX CARACTÉRISÉ QUE DANS LE BRIEF

### 2.1 `ST_MotionChecklist` n'est pas un outil : c'est un **DUT**

| Affirmation du brief | Réalité prouvée |
|---|---|
| « l'outil de diagnostic lui-même (`ST_MotionChecklist`) » | **DUT/STRUCT**, `CODE/J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_MotionChecklist.st:6` — aucune logique exécutable |
| Producteur implicite (« son FB producteur », §4.2) | **`FB_TroubleshootingView.st:563-659`** — c'est LUI qui calcule le vert |
| Diffusé par | `GVL_Troubleshooting.st:23-25` → `N_MotionM1` / `O_MotionM2` / `P_MotionM3` |

### 2.2 Le locus exact du faux vert

`CODE/J_SUPERVISION/FB_TroubleshootingView.st` :

| Ligne | Code | Axe |
|---|---|---|
| **577** | `Step8_OutputInterlockOk := NOT WinchM1.State.FinalInterlockError;` | M1 |
| **609** | `Step8_OutputInterlockOk := NOT WinchM2.State.FinalInterlockError;` | M2 |
| **644** | `Step8_OutputInterlockOk := NOT Translation.State.FinalInterlockError;` | M3 |

Puis `AllConditionsMet` = **AND des 8 étapes** (`:579-586` M1, `:611-618` M2, `:646-653` M3), et
`AllConditionsMet` est le champ commenté **« 🟢 TRUE = TOUTES LES CONDITIONS SONT REMPLIES, LES RELAIS
DOIVENT COLLER ! »** (`ST_MotionChecklist.st:30`).

➡️ Un `Step8` faux-TRUE était donc un **indicateur qui ment**.

> 🔴 **CORRECTION 2026-09-21T15:50 (orchestrateur DSH29) — LA CONCLUSION INITIALE ÉTAIT FAUSSE.**
> Ce document affirmait qu'un `Step8` faux-TRUE entraînait « directement un `AllConditionsMet`
> faux-vert ». **C'EST FAUX, et c'est réfuté.** L'agent porteur l'a établi ; je l'ai vérifié
> moi-même en première main : `RelayFwd := FALSE; RelayRev := FALSE;` est posé
> **inconditionnellement** en tête de §5 (`FB_WinchOutputInterlock.st:347-348`), **avant** la
> machine d'état ELSIF. Donc dans **les 4 modes F1-F4**, `BrakeCmd := RelayFwd OR RelayRev`
> (`:487`) = FALSE → `Step7_BrakeReleased` (`FB_TroubleshootingView.st:576`) = **FALSE** →
> `AllConditionsMet` était **déjà FALSE**.
>
> **PORTÉE RÉELLE, CORRIGÉE** : le défaut n'est pas « tout vert alors que rien ne bouge », mais
> **« un indicateur ment et désigne la mauvaise cause »** — `Step8_OutputInterlockOk` affichait
> « interlock OK » pendant que la barrière refusait, tandis que `Step7` affichait rouge sur le
> **frein**, c'est-à-dire sur une **conséquence** et non sur la **cause**. Le technicien était donc
> **mal orienté**, pas faussement rassuré par le bilan global. **Sévérité plus faible que décrite
> dans ce document — c'est cette version corrigée qui fait foi.**
>
> **SECONDE CORRECTION, sur ma prescription A2 (« lire `State` ET `Reason` »)** : `Reason` est
> **mémorisé et jamais remis à `NONE`** après acquittement (`FB_WinchOutputInterlock.st:513` lève
> `ContactorStuckLatched` **sans** toucher `Reason`) → l'utiliser dans la décision aurait créé un
> **faux ROUGE permanent**. `Reason` se **publie**, il ne **décide** pas. Le cas `TC-P14-TSV-16` le prouve.
>
> Ces deux corrections sont **aussi inscrites par l'agent porteur dans l'en-tête du fichier de test**
> (`test_fb_troubleshootingview.st:98-113`) — elles ne vivent pas seulement ici.

### 2.2bis Ce qui reste vrai de ce document

Le **locus** (§2.2), la **chaîne** `FinalInterlockError` (§2.3), les **4 modes F1-F4** (§2.4, colonne
`Step8` inchangée) et la **contradiction interne du FB producteur** (§2.5) sont **confirmés** : les
17 cas de la CI rejoués par l'orchestrateur le prouvent, dont 5 qui échouaient en assertion
fonctionnelle avant correctif (`TC-P14-TSV-06..10`).

### 2.3 La chaîne prouvée `FinalInterlockError`

```
FB_WinchOutputInterlock.st:528-532   instCauses[0] = bit0 ErrorId ; cause UNIQUE = « Timeout confirmation ouverture frein treuil »
                                     Fault := instFault.Fault
FB_WinchStateProjection.st:114       WinchM1State.FinalInterlockError := InterlockM1.Fault.Error
ST_WinchState.st:40                  FinalInterlockError : BOOL
FB_TroubleshootingView.st:577        Step8 := NOT FinalInterlockError          <-- LE FAUX VERT
```

`Fault.Error` est alimenté par **une seule cause** (`ErrorId` bit0, `:516-519`). **Tout refus de la
barrière qui ne pose pas ce bit passe donc pour un vert.**

### 2.4 Les 4 modes de refus à faux vert (mesurés)

| # | Site | Condition | `State` | `Reason` | `Fault.Error` | `Step8` aujourd'hui |
|---|---|---|---|---|---|---|
| **F1** | `:357-363` | `RestartInhibit` | `FAULT` | `RESTART_INHIBITED` | **FALSE** | 🟢 **TRUE — FAUX VERT** |
| **F2** | `:364-373` | `ContactorStuckLatched` (T_max §3bis) | `FAULT` | `SENSE_DROP_TIMEOUT` | **FALSE** | 🟢 **TRUE — FAUX VERT** |
| **F3** | `:393-404` | `SafeStop OR PermitFinalBlocked` (permis directionnel refusé) | **`READY`** | `NONE` | **FALSE** | 🟢 **TRUE — FAUX VERT** |
| **F4** | `:424-429` | `RestartRequired OR DeadTimePending` | `WAIT_RESTART_DELAY` | `NONE` | **FALSE** | 🟢 **TRUE — FAUX VERT** |
| — | `:508` + `:516` | timeout confirmation frein | `FAULT` | `BRAKE_COMMAND_NOT_CONFIRMED` | TRUE | 🔴 FALSE (correct) |

⚠️ **F3 est le cas le plus trompeur** : la barrière **coupe les 6 ordres** (`:402-403`) en laissant
`State = READY` (`:404`) et `Reason = NONE` — un technicien lit « barrière PRÊTE, aucune raison » et
rien ne bouge. **F4 montre que `Reason` seul ne suffira pas** (il reste `NONE`) : il faut lire `State`
**ET** `Reason`.

### 2.5 Découverte supplémentaire : **contradiction interne au même FB producteur**

`FB_TroubleshootingView.st:222-223` publie **déjà** dans la même GVL :

```st
I_LevageUnitaireM1.Control_400.Idx405_FinalInterlockState  := WinchM1.State.FinalInterlockState;
I_LevageUnitaireM1.Control_400.Idx406_FinalInterlockReason := WinchM1.State.FinalInterlockReason;
```

(idem M2 `:301-302`, M3 `:417-418`). ➡️ **Le même FB affiche la vérité dans la chaîne `Control_400`
et le faux vert dans `MotionM1`** : le diagnostic se contredit lui-même à l'écran. C'est un argument
plus fort que celui du brief et il est **prouvable en une passe de grep**.

---

## 3. LA BORNE §3 DU BRIEF EST MAL ARBITRÉE

### 3.1 Prémisse fausse : rien à ajouter à la source

| Affirmation du brief | Réalité prouvée |
|---|---|
| « ajouter/exposer des sorties qui publient l'état réel déjà calculé en interne (Reason, Fault.Error, State) » | **Déjà en `VAR_OUTPUT`** : `Reason` **`FB_WinchOutputInterlock.st:56`** · `State` **`:54`** · `StateAtError` **`:55`** · `Fault` **`:53`** |
| §5.2 « confirmer qu'il n'existe pas déjà une sortie similaire ailleurs » | ❌ **Elle existe** — et elle est **déjà consommée** : `FB_WinchStateProjection.st:112-115` (M1) et `:179-182` (M2) |
| « les 4 `Reason` déjà posés » | **3 causes** dans l'enum (`E_WinchFinalInterlockReason.st:10-13`) + **4 sites d'affectation** (`:210` remise à `NONE`, `:362`, `:372`, `:508`) — formulation à corriger |

### 3.2 L'« alternative écartée » est en fait **le correctif correct**

Le brief écarte « corriger uniquement côté IHM en faisant lire à `Step8` un état approximatif ».
Mais `FinalInterlockState` / `FinalInterlockReason` **ne sont pas approximatifs** : ce sont les
`VAR_OUTPUT` du FB de sécurité lui-même, recopiés une pour une par `FB_WinchStateProjection.st:112-113`.
Faire lire `Step8` **n'est pas interpréter un état ambigu : c'est cesser de le tronquer**.

### 3.3 Ce que la borne §3 interdirait si on la lisait littéralement

Ajouter une sortie agrégée neuve (`MotionRefused`) exigerait **d'écrire une ligne de plus dans un FB
de sécurité** — exactement le geste que le revert `263fae18` (T228, cité verbatim dans
`TASKS.yaml:41`) a sanctionné : *« 3 rounds de correctifs sur des FB SECURITE »*, leçon n°1
« ne pas patcher les FB de SECURITE pour obtenir une information de disponibilité ».
➡️ **Option B déconseillée** tant que l'option A (lire ce qui est publié) suffit.

---

## 4. COLLISIONS DE VERROU — VÉRIFIÉ

| Contrôle | Résultat prouvé |
|---|---|
| Entrée `T371` dans `TASK_LOCKS.json` | **AUCUNE** (grep `"T37` = 0 occurrence de verrou T371/T370) |
| `edit_flags` | **VIDE** — `TASK_LOCKS.json:216` : `"edit_flags": {}` |
| Verrou `T224`/DSH28 (même investigation) | **VIF**, mais **read-only `CODE/`** — périmètre disjoint de tout fichier visé ici |
| Verrou sur les 3 fichiers candidats | **AUCUN vif** — `FB_TroubleshootingView.st` / `FB_WinchOutputInterlock.st` / `FB_WinchStateProjection.st` n'apparaissent que dans des textes de verrous **périmés** (T358/DSH21 libéré 07:10) |
| `T371` dans `TASKS.yaml` | Existe (`:2-19`), `agent: '—'`, **aucun champ `contrat:`** → contrat C4 à écrire avant code (obligatoire dès C2) |
| `bloque_par` de T371 | **VIDE** alors que la trace T224 est citée comme précondition par le registre (`TASKS_ORCHESTRATOR.yaml:2626` a1) — **à trancher** |

---

## 5. ARBITRAGES DEMANDÉS AVANT TRANSMISSION

| # | Question | Recommandation orchestrateur |
|---|---|---|
| **A1** | **Qui corrige ?** Source (`FB_WinchOutputInterlock.st`) ou consommateur (`FB_TroubleshootingView.st:577/609/644`) ? | 🔵 **Consommateur seul** — la source publie déjà ; `FB_WinchOutputInterlock.st` reste **intouché** (`git diff` vide sur ce fichier = preuve mécanique de non-régression des 3 causes) |
| **A2** | **Comment lire ?** `State` + `Reason` suffisent-ils, ou faut-il un champ dédié dans `ST_MotionChecklist` ? | 🔵 Ajouter 2 champs **de lecture** dans le DUT : `Step8_InterlockState` + `Step8_InterlockReason`, et **garder** `Step8_OutputInterlockOk` dérivé des 3 (F1-F4 ⇒ FALSE) — lisible et rétro-compatible IHM |
| **A3** | **Portée** : les 3 axes (M1 `:577`, M2 `:609`, M3 `:644`) ou M1/M2 seulement ? | 🔵 **Les 3 axes** — M3 a la même structure (`Translation.State.FinalInterlockState/FinalInterlockReason` déjà publiés, `PRG_05:756`) ; traiter M3 seul serait créer la même dette une 2ᵉ fois |
| **A4** | **Latence** `N-1` assumée ? | 🔵 **Oui et à documenter** : `FB_WinchStateProjection` est appelé en `PRG_04` (`PRG_04_Treuils_Benne.st:1688-1696`) et lit l'instance `PRG_06_Outputs` → état daté d'un scan (~10 ms). Acceptable pour un outil de diagnostic, **inacceptable** pour toute logique de conduite — donc **aucune ligne de conduite ne doit consommer ces champs** |

---

## 6. LIMITES DE CE CHALLENGE

- **Aucun test exécuté** : la preuve « rouge » du faux vert (§4.3 du brief) reste **à produire** par
  l'agent porteur, dans `TOOLS/TEST_AUTO_CI/RESULTS/J_SUPERVISION/tests/test_fb_troubleshootingview.st`
  (fichier existant, 77 l., harnais `FB_TroubleshootingView` déjà en place).
- Le challenge est **statique** (`read`/`grep`) : il prouve la **condition** du faux vert (F1-F4),
  pas son observation sur banc. C'est un devoir d'alerte, pas une mesure terrain.
- **Hors scope signalé, non corrigé** : `TASKS_ORCHESTRATOR.yaml:2626` relève que `T370` et `T371`
  n'ont **aucune entrée** dans le registre des actions, et que le `bloque_par` de T371 est vide.

---

*Fin du challenge T371 — aucune ligne de `CODE/` écrite, aucun commit, brief v1 conservé tel quel
(ni déplacé ni supprimé).*
