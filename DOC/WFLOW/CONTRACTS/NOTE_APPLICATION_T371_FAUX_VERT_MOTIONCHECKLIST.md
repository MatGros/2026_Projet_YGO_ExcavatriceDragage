# NOTE D'APPLICATION — T371 « Faux vert du diagnostic mouvement »

> **Tâche** : `T371` (C4, patch, `TASK_CONTRACT_T371_FAUX_VERT_MOTIONCHECKLIST.yaml`) — agent **DSH29**.
> **Ancrage** : HEAD `bb9436e1` (2026-09-21). **Aucun commit, aucun push.**
> **Objet** : `Step8_OutputInterlockOk` du diagnostic `ST_MotionChecklist` (MotionM1 / MotionM2 /
> MotionM3) cessait de refléter le refus RÉEL de la barrière finale : il était dérivé du **seul**
> `FinalInterlockError`, alimenté par **une seule cause** (ErrorId bit0 = timeout confirmation frein).
> **État** : correctif livré, **ROUGE et VERT mesurés en CI** (12 cas, 0 échec après correctif),
> garde-fou `G522` en place, **2 incidents de revue corrigés** (§2.2 et §5bis).

---

## 1. Ce qui a été corrigé (et ce qui ne l'est PAS)

| Fait | Statut |
|---|---|
| `FB_WinchOutputInterlock.st` publiant déjà `State` (:54) / `Reason` (:56) / `StateAtError` (:55) / `Fault` (:53) | **confirmé** — rien à ajouter à la source |
| Ces sorties déjà routées : `FB_WinchStateProjection.st:112-115` (M1), `:179-182` (M2), `PRG_05_Translation.st:756-758` (M3) | **confirmé** |
| Faux vert localisé en **consommation tronquée** : `FB_TroubleshootingView.st` (3 sites M1/M2/M3) | **confirmé** |
| `Fault.Error` alimenté par une cause unique (bit0) : `FB_WinchOutputInterlock.st:516-519` → `:528-532` | **confirmé** |
| Le même FB publiait déjà la vérité à côté : `:222-223` (M1), `:301-302` (M2), `:417-418` (M3) | **confirmé** → le diagnostic se contredisait à l'écran |
| **5ᵉ mode de refus non couvert** | **AUCUN trouvé** (machine d'état §5, lignes 346-475 énumérée branche par branche) |
| **Sortie réellement manquante à la source** | **AUCUNE** (cf. §2.5 pour la limite M3, qui n'est pas un manque côté source) |

### Les 4 modes de refus (preuve statique, `fichier:ligne`)

| # | Site `FB_WinchOutputInterlock.st` | Condition | `State` (l.) | `Reason` (l.) | `Fault.Error` | `Step8` avant |
|---|---|---|---|---|---|---|
| **F1** | `:357-363` | `RestartInhibit` | `FAULT` (:363) | `RESTART_INHIBITED` (:362) | FALSE | 🟢 TRUE — faux |
| **F2** | `:364-373` | `ContactorStuckLatched` | `FAULT` (:373) | `SENSE_DROP_TIMEOUT` (:372) | FALSE | 🟢 TRUE — faux |
| **F3** | `:393-404` | `SafeStop OR PermitFinalBlocked` | **`READY`** (:404) | **`NONE`** | FALSE | 🟢 TRUE — faux |
| **F4** | `:424-429` | `RestartRequired OR DeadTimePending` | `WAIT_RESTART_DELAY` (:429) | **`NONE`** | FALSE | 🟢 TRUE — faux |
| — | `:508` + `:516` | timeout confirmation frein | `FAULT` | `BRAKE_COMMAND_NOT_CONFIRMED` | **TRUE** | 🔴 FALSE — correct |

---

## 2. Correctif livré (côté consommateur SEUL)

**`CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` : ZÉRO LIGNE.** Borne A1 tenue
(`git diff --numstat` **VIDE**, blob identique à HEAD — §6).

### 2.1 `CODE/J_SUPERVISION/FB_TroubleshootingView.st` — prédicat final (M1/M2)

```st
Step8_OutputInterlockOk := NOT <axe>.State.FinalInterlockError
                       AND NOT (<axe>.State.FinalInterlockState = E_WinchFinalInterlockState.FAULT)
                       AND NOT (<axe>.State.FinalInterlockState = E_WinchFinalInterlockState.DISABLED)
                       AND NOT (<axe>.State.FinalInterlockState = E_WinchFinalInterlockState.WAIT_RESTART_DELAY)
                       AND NOT (<axe>.State.FinalMotorRequest AND NOT <axe>.State.BrakeCmd);
```

| Terme | Couvre | Source publiée |
|---|---|---|
| `NOT FinalInterlockError` | cause historique (timeout frein) — **conservée** | `FB_WinchStateProjection.st:114` |
| `State = FAULT` | **F1**, **F2** (`:363`, `:373`) | `:112-113` |
| `State = DISABLED` | gate `Enable`/`PowerContactorEngaged` (`:169`) | `:112` |
| `State = WAIT_RESTART_DELAY` | **F4** (`:429`) | `:112` |
| `FinalMotorRequest AND NOT BrakeCmd` | **F3** (`:402-403`) | `:118` + `:108` |

### 2.2 🔴 INCIDENT DE REVUE n°1 (verdict BLOCK) — le témoin F3 a d'abord été **tautologique**

Première version du terme F3 : `FinalMotorRequest AND NOT (State.RelayFwd OR State.RelayRev)`.
**Elle ne pouvait JAMAIS s'armer** :

1. `State.RelayFwd/RelayRev` sont recopiés de **FB_Winch** (`FB_WinchStateProjection.st:102-103`
   ← `WinchM1Ref : FB_Winch`, projection l.23) : ce sont les **DEMANDES**.
2. La barrière reçoit exactement ces signaux : `WinchM1FinalInterlockRequest.RequestedRelayFwd :=
   instWinchM1.RelayFwd` (`PRG_04_Treuils_Benne.st:1603-1604`).
3. `MotorRequest := (RequestedStepClamped > 0) AND (RequestedRelayFwd XOR RequestedRelayRev)`
   (`FB_WinchOutputInterlock.st:182`) implique donc déjà `RelayFwd XOR RelayRev` → le terme
   `(XOR) AND NOT (OR)` est **toujours FAUX** ⇒ **F3 restait vert**.

✅ **Correctif** : le témoin s'appuie désormais sur `State.BrakeCmd`, recopié de la **SORTIE VALIDÉE**
de la barrière (`FB_WinchStateProjection.st:108` et `:175` ← `InterlockMx.BrakeCmd`, soit
`RelayFwd OR RelayRev` **validés**, `FB_WinchOutputInterlock.st:487`).
Le cas de test `TC-P14-TSV-08` a été **rendu réaliste** (demande présente `RelayFwd := TRUE`
**ET** sortie coupée `BrakeCmd := FALSE`) : il **échoue** maintenant si le témoin redevient une
tautologie. `G522` interdit explicitement `RelayFwd`/`RelayRev` dans ce terme.

### 2.3 `Reason` est PUBLIÉ mais **volontairement hors de la décision**

`Reason` est une cause **MÉMORISÉE**, pas un refus **actif** :
- M1/M2 : le `Reset` efface `ContactorStuckLatched` (`:513`) **sans** remettre `Reason` à `NONE`
  (seul le chemin `:210` le fait) → l'utiliser dans la décision créerait un **faux ROUGE PERMANENT** ;
- M3 : même constat (`FB_TranslationOutputInterlock.st:123-130` lève `RestartInhibit` sans toucher
  `Reason` ; seul le gate `:80` le remet à `NONE`).

Il est donc exposé au technicien (`Step8_InterlockReason`) sans servir de preuve de refus actif.
*(Analyse confirmée exacte par la revue indépendante.)*

### 2.4 `CODE/J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_MotionChecklist.st` — 2 champs de LECTURE

- `Step8_InterlockState : E_WinchFinalInterlockState` et
  `Step8_InterlockReason : E_WinchFinalInterlockReason` — **ajoutés en FIN de STRUCT** (aucun champ
  existant décalé : mapping IHM/SCADA + online change préservés). `Step8_OutputInterlockOk` est
  **CONSERVÉ** (aucun renommage).
- **Vocabulaire commun aux 3 axes** (famille `E_WinchFinalInterlock*`) plutôt qu'un `INT` :
  cela **évite toute conversion de type** et donne une **table de valeurs unique** au technicien.
  M1/M2 recopient l'énumération publiée **directement** ; M3 projette explicitement
  (`E_State.READY → READY`, `E_State.ERROR → FAULT`, raisons identiques, cf. §2.5).
  > Pourquoi pas `INT` + `TO_INT(...)` (version initiale, abandonnée) : un membre d'énumération lu
  > dans un `IEC_STRUCT` n'est pas convertible par `TO_INT` dans la chaîne de test
  > (`invalid static_cast from IEC_ENUM_Var<...> to short int`), et `INT := <énumération>` est
  > **interdit** par `DOC/STDS/CODE_QUALITY_STANDARDS.md:555` (« conversion explicite, jamais
  > implicite »). Un `INT` aurait en outre rendu la table **dépendante de l'axe** (READY = 1 pour M1/M2,
  > = 2 pour M3).

### 2.5 Axe M3 — ce qui est fait, et la limite **corrigée**

Fait : publication de `Step8_InterlockState` / `Step8_InterlockReason` en vocabulaire commun, et
lecture explicite de l'état publié dans la décision (`NOT (State = E_State.ERROR)`).

**Limite (rectifiée après revue)** : l'analogue M3 de F3 (`PermitFinalBlocked`,
`FB_TranslationOutputInterlock.st:146`) reste invisible **non pas parce que le témoin n'est pas
publié — il l'est** (`PRG_06_Outputs.st:458` `M3_CommandWord := instTranslationOutputInterlockM3.DriveControlWord`
→ `PRG_07_Supervision.st:576` `GVL_IHM.IoHw.Out.M3_CommandWord`) — **mais parce que
`FB_TroubleshootingView` n'a AUCUNE entrée `IoHw`** : l'atteindre exige d'ajouter
`IoHw : ST_IoHw` en `VAR_INPUT` **et** un argument dans `PRG_07_Supervision.st`, hors du périmètre
T371 (et fichier en cours d'édition par un autre lot). **Remonté à l'orchestrateur, non fait.**
Conséquence assumée : sur M3, `Step8_OutputInterlockOk` reste **équivalent à `NOT FinalInterlockError`**
(aucun faux rouge introduit, mais aucune détection nouvelle). `Step5_NoSafetyFault` /
`Step6_DirectionAllowed` y couvrent déjà SafeStop et permis.

### 2.6 Résidus connus, déclarés (énumération exhaustive de la machine d'état §5)

Les 11 branches de `FB_WinchOutputInterlock.st:346-475` ont été énumérées une par une
`(State, Reason, MotorRequest, BrakeCmd)` → nouveau `Step8` M1/M2 :

| Branche | Site | `State` | Demande / sortie validée | Nouveau `Step8` | Juste ? |
|---|---|---|---|---|---|
| Gate `Enable`/AU | `:148-175` | `DISABLED` | sortie coupée | **FALSE** | ✅ refus réel |
| Défaut frein | `:351-356` | `FAULT` | coupée | **FALSE** | ✅ |
| **F1** `RestartInhibit` | `:357-363` | `FAULT` | coupée | **FALSE** | ✅ corrigé |
| **F2** `ContactorStuckLatched` | `:364-373` | `FAULT` | coupée | **FALSE** | ✅ corrigé |
| Ordre de relâchement | `:374-392` | `READY` | sens tenu (`BrakeCmd` TRUE) | **TRUE** | ✅ séquence nominale volontaire |
| … fin de relâchement | `:386-390` | `READY` | demande retombée | **TRUE** | ✅ plus rien à délivrer |
| **F3** `SafeStop`/`PermitFinalBlocked` | `:393-404` | `READY` | demande vive, `BrakeCmd` FALSE | **FALSE** | ✅ corrigé |
| Maintien §3bis | `:405-416` | `WAIT_SENSE_DROP_CONFIRM` | `RequestedStep = 0` | **TRUE** | ✅ pas un refus |
| Aucune demande | `:417-423` | `READY` | coupée | **TRUE** | ✅ |
| **F4** tempos | `:424-429` | `WAIT_RESTART_DELAY` | demande retenue | **FALSE** | ✅ corrigé |
| Nominal (dont `WAIT_BRAKE_COMMAND_CONFIRMATION` `:469-471`) | `:431-475` | `READY` / `WAIT_BRAKE_…` | `BrakeCmd` TRUE | **TRUE** | ✅ |

➡️ **Aucun FAUX ROUGE permanent** trouvé (revue indépendante : confirmé).

⚠️ **Résidu assumé** : `SafeStop` actif **sans demande de mouvement** (`FinalMotorRequest = FALSE`)
→ `Step8 = TRUE`. Le témoin publié ne voit alors aucune demande à délivrer. Décision : **ne pas
ajouter `NOT SafeStop`** (dupliquerait `Step5_NoSafetyFault` et mélangerait deux responsabilités).

### 2.7 F3 : ce qui est couvert (transitoire de refus) et ce qui ne l'est pas (demande retirée)

Point soulevé par la revue indépendante — traité factuellement, pas écarté :

| Phase | Ce qui se passe | `MotorRequest` (barrière) | `BrakeCmd` (sortie validée) | `Step8` | Honnête ? |
|---|---|---|---|---|---|
| **Refus pendant que la demande est vivante** | l'opérateur demande, la barrière coupe (SafeStop/permis) ; `FB_Winch` n'a pas encore ramené son palier | **TRUE** | **FALSE** | **FALSE** | ✅ **c'est le moment où le technicien constate que rien ne bouge** — couvert |
| **Régime établi** | `FB_Winch` a **lui aussi** vu le SafeStop/le permis refusé (`EffectiveSafeStop`, `FB_Winch.st:169`) et a ramené son palier → `StepNumber = 0` (`:216`, `:281`) → `RequestedStep = 0` (`PRG_04:1609`) | **FALSE** | FALSE | **TRUE** | ✅ **honnête** : la barrière n'est plus en F3 mais en `NOT MotorRequest` (`:417-423`) : **il n'y a plus aucune demande à délivrer**. SafeStop et permis sont portés par `Step5_NoSafetyFault` et `Step6_DirectionAllowed` (`FB_TroubleshootingView.st` §9/§10) |

➡️ Le témoin `FinalMotorRequest AND NOT BrakeCmd` couvre **le refus réellement opposé à une demande**
(dont le transitoire F3, seul moment où `Step8` mentait). En régime établi sans demande, `Step8 = TRUE`
ne dit pas « tout va bien » mais « aucun interlock ne retient un mouvement demandé » — ce qui est vrai.

🔧 **Alternative explicitement laissée à l'arbitrage** : ajouter `AND NOT <axe>.Safety.SafeStop`
(donnée publiée, `FB_WinchStateProjection.st:231`) rendrait `Step8` FALSE dès que SafeStop est actif,
même sans demande. **Non retenue** : elle duplique `Step5_NoSafetyFault` (qui porte déjà SafeStop) et
fait porter à l'étape 8 une responsabilité qui n'est pas la sienne. À trancher si le terrain juge le
comportement actuel ambigu.

---

## 3. ⚠️ Correction du diagnostic initial : `AllConditionsMet` n'était PAS faux-vert

`Step7_BrakeReleased := BrakeCmd AND BrakeCommandOpenConfirmed`. La barrière coupe `RelayFwd`/`RelayRev`
dans les 4 modes F1-F4 (`:347-348`, `:402-403`) donc `BrakeCmd = FALSE` → **`Step7 = FALSE`** →
`AllConditionsMet` était **DÉJÀ FALSE**. *(Confirmé exact par la revue indépendante.)*

➡️ **Le défaut réel est un indicateur `Step8` QUI MENT** (et une auto-contradiction à l'écran avec
`Control_400.Idx405/406`), pas une invitation à faire coller les relais. Le volet « ni
`AllConditionsMet = TRUE` » des AC était donc **déjà satisfait avant correctif**.

---

## 4. Latence N-1 — usage DIAGNOSTIC UNIQUEMENT (AC12)

`WinchM1.State` / `WinchM2.State` / `Translation.State` proviennent de la projection
`FB_WinchStateProjection`, appelée en **`PRG_04_Treuils_Benne.st:1688-1696`**, qui lit l'instance
`PRG_06_Outputs` : l'état lu est daté **d'un scan** (~10 ms) — `N-1` **assumé**.

- ✅ Usage : **diagnostic / dépannage** (GVL_Troubleshooting, Watch CODESYS, export SCADA).
- ⛔ **INTERDIT** : toute ligne de **CONDUITE** consommant `Step8_InterlockState` /
  `Step8_InterlockReason` — vérifié mécaniquement par **G522**.
- Ne **jamais** présenter ces champs comme une mesure temps réel.

---

## 5. Garde-fou automatique (règle `fix:` + `guard:`)

**`TOOLS/AGENT_WORKFLOW/scripts/G522_check_step8_interlock_not_truncated.py`** (numéro libre, plus
haut vu = G521) + ligne `PLANS` palier **C** de `run_all_gates.py`.

Il refuse **14 mutations** au `--selftest` (0 faux positif sur l'arbre réel), dont les **incidents
réellement survenus** et les **trous trouvés par la revue** :
1. retour au `NOT FinalInterlockError` seul (incident d'origine) ;
2. **reconstruction du témoin F3 sur la DEMANDE `RelayFwd`/`RelayRev`** (tautologie — incident n°1, §2.2) ;
3. disparition du témoin F3, des termes `FAULT` / **`DISABLED`** / `WAIT_RESTART_DELAY` / `E_State.ERROR`
   (le terme `DISABLED` — seul terme qui bascule `Step8` en situation semi-nominale — **n'était pas
   protégé** dans la v1 : trou relevé par la revue, désormais couvert) ;
4. **injection de `FinalInterlockReason` dans la DÉCISION** (cause mémorisée ⇒ **faux ROUGE permanent**
   après acquittement — la décision de §2.3 n'était pas protégée non plus) ;
5. disparition d'une publication ou d'un champ de lecture du DUT (dont renommage de
   `Step8_OutputInterlockOk`) ;
6. **consommation de CONDUITE** injectée dans un PRG (latence N-1) ;
7. disparition / vacuité du cas de test F3, **ou pilotage de F3 sur un état impossible en
   exploitation** (demande retirée) — c'est ainsi qu'une tautologie passe inaperçue.

---

## 5bis. 🔴 INCIDENT DE REVUE n°2 — garde-fou inerte (corrigé)

La revue a montré que la **v1** de `G522` était un **overfit** : elle passait avec un témoin
tautologique, ne contrôlait pas l'origine du témoin, et son `--selftest` devenait **ROUGE**
(« ancre introuvable ») au moindre reformatage de l'expression (les mutations v1 utilisaient des
ancres littérales multi-lignes, et `_re_sub` avait été écrit **sans `re.DOTALL`**, donc les
substitutions multi-lignes ne s'appliquaient pas — bug silencieux du garde-fou lui-même).
➡️ **v2** : ancres **regex** + `DOTALL`, contrôles anti-tautologie et anti-état-impossible, 12 mutations.

---

## 6. Vérifications mécaniques et preuves

| Preuve | Résultat |
|---|---|
| `git diff --numstat -- CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` | **VIDE** (borne A1) |
| blob de la barrière vs HEAD | identiques : `14aa2c20aaae8a5890e20584041df4d7817c3617` |
| Chaîne de compilation de la barrière (6 fichiers, `registry.yaml:310-317`) | aucune de mes modifications dedans → suite **identique à HEAD** |
| Suite CI barrière `FB_WinchOutputInterlock` | **7/11** PASS, 4 FAIL **préexistants** (TC-P10-013, -021, -022, -023a) — inchangés |
| **ROUGE (avant correctif)** | **5 FAIL fonctionnels** : TC-P14-TSV-06/-07/-08/-09/-10 — `ASSERT_FALSE: …STEP8_OUTPUTINTERLOCKOK expected FALSE, got TRUE` (baseline 01-05 PASS, 11-12 PASS) |
| **VERT (après correctif)** | **17/17 PASS**, `exit=0`, baseline préservée — couverture étendue après revue : M2/F1, M2/F4, gate `DISABLED`, « cause mémorisée après acquittement → reste VERT », verts nominaux M2/M3 |
| `G522 --selftest` | **PASS** — 14 mutations refusées, 0 faux positif |
| `G522` (arbre réel) | **PASS** |
| Bundle + diff bundle + `G200 --report` | PASS — 0 erreur, 2048 instances ; diff bundle 2 objets |
| Palier C — 60 gates | 5 en échec, **tous préexistants** (G300/G340/G430/G483 + G521 dont l'ancre `BootInputTransientDone` est **absente à HEAD**) ; **`G522` PASS** |
| Aucune de mes modifications citée dans un échec de gate | 0 occurrence dans le log palier C |
| Contenu réel des bundles | `CODE_Bundle.xml` et `CODE_DiffBundle.xml` portent les 2 nouveaux champs **et** le corps corrigé |
| G300 — 2 erreurs « unexpected AGENT_WORKFLOW directory » | **préexistantes** : `TOOLS/AGENT_WORKFLOW/.tmp` (14/09/2026, gitignoré) et `prototypes` (18/09/2026, suivi Git) |

### Ce qui a fallu lever pour rendre AC1/AC2 exécutables (dette CI préexistante)

1. **8 types manquants** dans l'entrée `FB_TroubleshootingView` de `registry.yaml` → **8 lignes additives**.
2. **STruCpp v0.6.2 ne supporte pas le namespace GVL CODESYS** (`GVL_Troubleshooting.X`) :
   `VAR_GLOBAL Foo:INT;` + `GVL_T.Foo` → `error: Undeclared variable 'GVL_T'` ; accès direct `Foo` → OK ;
   `GVL_T` déclaré comme **variable** d'un STRUCT miroir → **OK** (sondes compilateur).
   → levé par **2 MOCKS miroirs** : `TOOLS/TEST_AUTO_CI/MOCKS/MOCK_GVL_IHM.st` et
   `MOCK_GVL_Troubleshooting.st` (transcription des listes de membres de `GVL_IHM.st:8-24` et de
   `GVL_Troubleshooting.st`), + **2 lignes** dans la même entrée `registry.yaml`.
3. **Bogue préexistant du fichier de test** : 5 références à des membres de GVL **inexistants**
   (`GVL_Troubleshooting.ContexteMachineGlobal`, `…LevageSynchroniseM1M2`, `…LevageUnitaireM1`,
   `…BenneOuvertureFermeture`, `…TranslationPontM3` — les vrais noms portent leur préfixe `A_`/`H_`/
   `I_`/`K_`/`L_`). **Invisible jusqu'ici parce que le harnais ne compilait jamais.** Corrigé.

⚠️ **DETTES DÉCLARÉES** : les 2 mocks sont un **miroir** — une évolution de `GVL_IHM.st` /
`GVL_Troubleshooting.st` non répercutée produira une **erreur de compilation** du harnais (bruit),
jamais un faux résultat silencieux. `registry.yaml` porte désormais **10 lignes de moi**
(8 + 2 mocks) dans la seule entrée `FB_TroubleshootingView`.

---

## 7. Application en CODESYS (manuelle, par l'utilisateur)

1. **Copier-coller** le ST de `CODE/J_SUPERVISION/FB_TroubleshootingView.st` (régions §9, §10, §11).
2. **Copier-coller** le ST de `CODE/J_SUPERVISION/_TYPES/6_DIAG_ET_CHAINES/ST_MotionChecklist.st`
   (2 champs ajoutés en fin de STRUCT → online change possible).
3. Importer `CODE_XML/CODE_DiffBundle.xml` (ou `CODE_XML/CODE_Bundle.xml`).
4. **Aucune action** sur `FB_WinchOutputInterlock.st` : fichier **non livré** (inchangé).
5. ⛔ **Ne PAS importer** les fichiers `TOOLS/TEST_AUTO_CI/MOCKS/MOCK_GVL_*.st` : ce sont des
   artefacts de test (jamais compilés dans CODESYS).
6. Au banc : provoquer un refus (tempo anti-court-cycle, latch §3bis, SafeStop ou permis refusé) et
   vérifier que `MotionM1/M2` affichent `Step8_OutputInterlockOk = FALSE` **avec**
   `Step8_InterlockState` / `Step8_InterlockReason` renseignés — au lieu du vert mensonger.

---

## 8. DÉCISIONS PRISES FAUTE DE RÉPONSE

1. **Extension de périmètre CI (mocks GVL)** : la 2ᵉ extension de scope (2 mocks + 2 lignes registry)
   a été **réalisée** — sans elle, AC1/AC2 restaient non exécutables et le lot n'aurait aucune preuve
   d'exécution. Patron prouvé par sonde compilateur, fichiers **strictement de test**, hors CODESYS.
   ➡️ **À ratifier ou retirer par l'orchestrateur** (2 fichiers + 2 lignes, retrait trivial).
2. **A2 « State + Reason » insuffisant pour F3** : témoin publié ajouté (cf. §2.1/§2.2).
3. **`Reason` hors décision** (§2.3) : motif = faux ROUGE permanent prouvé ; `Reason` reste publié.
4. **M3** : témoin validé publié mais **non accessible** depuis ce FB (pas d'entrée `IoHw`) →
   limite déclarée et remontée (§2.5).
5. **TC-P14-TSV-06..12** absents de `DOC/AF/AF_Partie-14` (qui s'arrête à `-05`) ; `DOC/AF/**` étant
   interdit à l'écriture, le contrôle de couverture AF produit un **WARN non bloquant**. Régularisation =
   lot documentaire séparé.

---

## 9. Suivi des findings de la revue indépendante (verdict BLOCK)

La revue a porté sur une **révision antérieure** aux corrections (§2.2 et §5bis) ; le tableau
ci-dessous donne l'état **après** traitement, finding par finding.

| # | Sévérité | Objet | Traitement |
|---|---|---|---|
| **F1** | BLOCK | témoin F3 tautologique (demande comparée à elle-même) | ✅ **CORRIGÉ** — témoin sur `BrakeCmd` (sortie validée), §2.2 ; couvert par `G522` (mutation dédiée) |
| **F2** | MAJOR | cas de test F3 vacue (état impossible) | ✅ **CORRIGÉ** — cas réalistes (`RelayFwd := TRUE` + `BrakeCmd := FALSE`), + couverture M2/F1, M2/F4, `DISABLED`, cause mémorisée, verts nominaux M2/M3 (17 cas) |
| **F3** | MAJOR | `G522` overfit, `--selftest` rouge, `DISABLED` non protégé, `Reason` injectable, ancres fragiles | ✅ **CORRIGÉ** — v3 : ancres **regex + DOTALL**, 14 mutations, terme `DISABLED` exigé, `FinalInterlockReason` **interdit** dans la décision |
| **F4** | MAJOR | « ordres validés M3 non publiés » — affirmation fausse | ✅ **CORRIGÉ** — §2.5 : le témoin **est publié** (`PRG_06:458` → `PRG_07:576`) mais **n'est pas une entrée** de ce FB ; arbitrage demandé |
| **F5** | MINOR | terme M3 redondant avec `NOT FinalInterlockError` | ⚖️ **ASSUMÉ/DOCUMENTÉ** — §2.5 et §2.6 (résidu 2) : décision inchangée, le gain M3 est la publication |
| **F6** | MINOR | entrées mortes / collisions de valeurs dans la table du DUT | ✅ **TRAITÉ** — champs **typés énumération** en vocabulaire commun (plus de collision inter-axes) ; `WAIT_STEP_DELAY` explicitement annoté « jamais produit » dans le DUT |
| **F7** | MINOR | en-tête du test annonçant les cas non exécutables | ✅ **CORRIGÉ** — en-tête réécrit, cas exécutés et collés (§6) |
| **F8** | MINOR | HEAD annoncé faux dans la note | ✅ **CORRIGÉ** — ancrage `bb9436e1` |
| **F9** | MINOR | faux rouge transitoire en fin de mouvement (skew N-1) | ✅ **RÉSOLU** par F1 — le témoin et `MotorRequest` viennent désormais de la **même source** (barrière), donc plus de décalage |
| **F10** | MINOR | contrat : méthode AC4 substituée, sites AC5 périmés, AC10 sans trace G200/palier C | ✅ **CORRIGÉ** — contrat mis à jour avec les preuves réellement produites (ROUGE/VERT/G200/palier C), sites courants |

**Non retenu, avec motif** : l'ajout de `AND NOT <axe>.Safety.SafeStop` au prédicat (cf. §2.7) —
dupliquerait `Step5_NoSafetyFault`. **Remonté comme arbitrage**, pas tranché unilatéralement.

**Attribution corrigée** : la revue a classé les 2 `MOCK_GVL_*.st` et les 2 lignes `registry.yaml`
comme « non attribuables à DSH29 » (apparus après la 1re clôture). Ils sont **bien de DSH29** : créés
pendant la reprise, sur le même lot, et déclarés en §6 et §8. Aucun tiers n'est en cause.

---

*Fin de la note d'application T371 — aucun commit, aucun push.*
