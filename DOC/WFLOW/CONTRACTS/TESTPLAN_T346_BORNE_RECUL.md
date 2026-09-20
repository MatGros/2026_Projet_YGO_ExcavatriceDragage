# 🧪 DOSSIER DE TEST T346 — borne de recul `FB_Bucket`

| | |
|---|---|
| **Tâche** | T346 (C1) — contrat `TASK_CONTRACT_T346_BORNE_RECUL.yaml` |
| **Date** | 2026-09-20T22:55+02:00 · agent **DSH13** |
| **Statut** | ✅ **APPLIQUÉ ET VERT** — `N1` et `N2` sont dans `test_fb_bucket.st`, `TC-P10-029.1` réécrit ; CI FB_Bucket **38/38 PASS** ; les 2 mutations de contrôle ont été exécutées et **rendent les tests ROUGES** (voir §3 et §4) |
| **Sources** | `DIAGNOSTIC_T346_BORNE_RECUL_2026-09-20.md` · `PLAN_T346_BORNE_RECUL.md` |

> 🎯 Objet : rendre la phase 2 **mécanique** — blocs ST prêts à coller, preuve rouge→verte
> chiffrée pour chaque cas, et matrice de non-régression vérifiée sur les **36 tests existants**.

---

## 1. Référence de départ — état CI **mesuré**

Relevé dans `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/reports/FB_Bucket.json`
(rapport du lot **T339**, non commité ⇒ snapshot, pas vérité de référence) :

| | |
|---|---|
| Tests | **36** |
| PASS | **35** |
| **FAIL** | **1** — `TC-P10-029.1` |
| Assertion exacte en échec | `test_fb_bucket.st:626` · `ASSERT_FALSE` · `FB.M2_RUNREQUEST expected FALSE, got TRUE` · « Recul a M2StartPosM → M2_StartStop=FALSE (arret) » |

⇒ Le test échoue **à la seule assertion d'arrêt du recul** : c'est **l'unique rouge du fichier**, et
c'est exactement le défaut T346. Assertions des scans 2 à 5 **déjà vertes** (dont `Lifecycle.Busy` en
`test_fb_bucket.st:595`).

---

## 2. Contraintes du harnais — **vérifiées, pas supposées**

| # | Contrainte | Preuve |
|---|---|---|
| **C1** | L'instance `FB : FB_Bucket` **persiste entre les scans ET entre les tests** : les entrées non repassées conservent leur valeur | `test_fb_bucket.st:11-17` (SETUP unique) + notes `:537-539`, `:598-599` |
| **C2** | `WinchSelBucket` vaut **`TRUE` par défaut** ⇒ la branche « abandon propre » **ne tire jamais** dans la suite, sauf si un test le passe à `FALSE` | `FB_Bucket.st:40` (`:= TRUE`), garde `:468` |
| **C3** | `Mode` vaut **`DISABLE` (0) par défaut** (`E_Mode.st:9`) : il n'est posé qu'à partir de `test_fb_bucket.st:656` ⇒ les tests **antérieurs** tournent en `DISABLE`, les **postérieurs** héritent de `SEMI_AUTO` (`:724`) | C1 + `E_Mode.st:9` |
| **C4** | `MotionRequestActive` **n'est pas une entrée** : elle est calculée en interne (`:162-163`). La piloter par argument nommé produit un test **VACANT** (garde-fou `G512`) — piloter `ReqAscent`/`ReqDescend` | fiche `AF-10:298`, `G512_check_dead_ci_test_arguments.py` |
| **C5** | Relâcher un sens **sans relâcher l'autre** déclenche `MotionRequestConflict` ⇒ neutralisation de la demande | `:162-163`, note `test_fb_bucket.st:537-539` |
| **C6** | Le recul est honoré sous le **permis opposé** (`EffectivePermitBucket_Open` pendant une fermeture) | `:528` |

⚠️ **Conséquence de C1/C3 pour tout test neuf** : **passer explicitement** chaque entrée dont dépend
l'assertion (`WinchSelBucket`, `Mode`, `EffectivePermitBucket_*`) — sinon le test dépend de l'ordre
d'exécution du fichier. C'est un piège réel, déjà responsable de faux verts par le passé.

---

## 3. 🔴 Preuve de `D6` — démonstration scan par scan

`D6` = la **détection de glissement M1** (`:265`) est **re-baselinée** par `BusyEdge.Q` (`:497`), car
`BusyEdge` (`:494`) n'a pas de clause `NOT Lifecycle.Busy`.

Paramètres : `M1SlipToleranceM = 1.0` (`:51`), `Config.CoherenceLimitM = 5.0` (config de test),
`WinchSelBucket` défaut `TRUE` (C2) ⇒ pas d'abandon parasite.

| Scan | Entrées | `M1RefPosM` **avant** | Calcul `M1SlipDetected` | `M1RefPosM` après `:497` | État |
|---|---|---|---|---|---|
| 2 | `CmdClose_IHM`, `ReqAscent`, M1=0.0 | — | — | **0.0** (armement) | Busy |
| 3 | relâchement, M1=**0.8** | 0.0 | `ABS(0.8-0.0)=0.8` ≤ 1.0 → **FALSE** ✅ | 0.0 | Busy |
| 4 | **re-press**, M1=0.8 | 0.0 | 0.8 → FALSE | **0.8** ⛔ **re-baseline** | Busy |
| 5 | relâchement, M1=**1.6** | 0.8 | `ABS(1.6-0.8)=0.8` → **FALSE** ⛔ | 0.8 | Busy |
| 6 | **re-press**, M1=1.6 | 0.8 | 0.8 → **FALSE** ⛔ | **1.6** ⛔ | Busy |

**Dérive cumulée depuis le vrai début de manœuvre = 1.6 m > tolérance 1.0 m — et jamais détectée.**
Tout est dans « 0.8 ≤ 1.0 » : chaque pompage **découpe la dérive en tranches sous le seuil**.

**Avec le correctif** (`BusyEdge(CLK := … AND NOT Lifecycle.Busy)`), scans 4 et 6 **ne recapturent
plus** ⇒ `M1RefPosM` reste **0.0** ⇒ au scan 5, `ABS(1.6-0.0)=1.6 > 1.0` ⇒ **`M1SlipDetected := TRUE`**
⇒ `M1SlipFaultLatched` ⇒ `instCauses[3]` ⇒ `Fault.Error` ⇒ coupe M2.

### Bloc ST prêt à coller — **`N2`** (rouge avant / vert après)

```st
TEST 'TC-P10-T346-N2 Glissement M1 cumule non contournable par repompage du joystick (D6)'
    (* T346 D6 : M1RefPosM (FB_Bucket.st:126) est la reference de la DETECTION DE GLISSEMENT M1
       (FB_Bucket.st:265 -> :269 instCauses[3]). Elle est capturee sur BusyEdge.Q (:497), dont le
       CLK (:494) n'a PAS de clause NOT Lifecycle.Busy : chaque relachement/repompage du joystick
       RE-BASELINE la reference et decoupe la derive en tranches sous la tolerance (1.0 m).
       Chaque re-press passe donc a cote du seuil (0.8 m), et une derive cumulee de 1.6 m n'est
       JAMAIS detectee. Le correctif (NOT Lifecycle.Busy) fige la reference : la derive cumulee
       franchit le seuil au scan 5. *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 3.0;
    Config.CoherenceLimitM := 5.0;
    Config.CloseAnticipationM := 0.2;
    Config.OpenAnticipationM := 0.2;
    BucketState.IsOpen := TRUE;
    BucketState.IsClosed := FALSE;

    (* Scan 1 : regime nominal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, WinchSelBucket := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, WinchSelBucket := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState);

    (* Scan 2 : armement fermeture — M1RefPosM capture a 0.0 *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, WinchSelBucket := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'N2 fermeture engagee -> Busy');

    (* Scan 3 : PAUSE operateur, derive M1 = 0.8 m (< tolerance 1.0) -> pas de faux defaut *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, WinchSelBucket := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := FALSE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.8, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState);
    ASSERT_FALSE(FB.M1SlipDetected, 'N2 derive 0.8 m < 1.0 -> aucun faux defaut');

    (* Scan 4 : REPOMPAGE du joystick a position constante -> ne doit PAS re-baseliner *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, WinchSelBucket := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.8, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'N2 repompage -> manoeuvre toujours en cours');

    (* Scan 5 : derive cumulee 1.6 m > tolerance -> DETECTION ATTENDUE (ECART ESCALADE avant correctif) *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, WinchSelBucket := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := FALSE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 1.6, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.M1SlipDetected, 'N2 derive cumulee 1.6 m -> M1SlipDetected (reference NON recapturee)');
    ASSERT_TRUE(FB.Fault.Error, 'N2 glissement M1 -> Error (cause 3)');

    (* Scan 6 : 2e repompage -> la reference reste figee, le latch tient *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, WinchSelBucket := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 1.6, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.M1SlipDetected, 'N2 2e repompage -> detection toujours active');
    ASSERT_FALSE(FB.M2_RunRequest, 'N2 glissement M1 -> M2 coupe');
END_TEST
```

**Mutation qui doit faire échouer ce test** : retirer `AND NOT Lifecycle.Busy` du `CLK` de
`BusyEdge` (`FB_Bucket.st:494`) ⇒ `M1SlipDetected` redevient FALSE au scan 5.

---

## 4. Bloc ST prêt à coller — **`N1`** (garde anti-réintroduction d'une référence mobile)

Objet : prouver que **le repompage du joystick ne redonne pas accès au recul une fois la limite
atteinte**. Sous une implémentation de type (a) avec référence recapturée, le re-press re-baselinerait
la borne et **rendrait le recul possible** ⇒ ce test échouerait. Il verrouille donc `D1`.

```st
TEST 'TC-P10-T346-N1 Limite de recul : frontiere physique, relache, pas de re-armement (D1)'
    (* T346 D1 + variante (b). La limite de recul s appuie sur MinAllowedOffset
       (FB_Bucket.st:194 = OffsetOpenM - CoherenceLimitM), la MEME frontiere que TooOpen (:434)
       et que le defaut cause 1 (:198-202, OffsetMaxViolNow confirme 500 ms).
       ⚠️ PIEGE EVITE : OffsetMaxViolNow est STRICT (< frontiere) et latche un FAUT en 500 ms.
       Ce test ne reste JAMAIS hors frontiere plus de 20 ms et revient dedans, sinon il passerait
       VERT pour la MAUVAISE raison (defaut cause 1, et non la borne).
       Ce test verrouille l INVARIANT D1 : un relachement/repompage NE DOIT PAS re-armer la limite. *)
    Config.OffsetOpenM := 0.0;
    Config.OffsetCloseM := 15.0;
    Config.CoherenceLimitM := 1.0;
    Config.CloseAnticipationM := 1.2;
    Config.OpenAnticipationM := 1.3;
    BucketState.IsOpen := FALSE;
    BucketState.IsClosed := FALSE;

    (* Scan 1-2 : regime nominal *)
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, WinchSelBucket := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, WinchSelBucket := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 0.0,
       Config := Config, BucketState := BucketState);

    (* Scan 3 : fermeture engagee en zone intermediaire (Delta = 7.0, cible 13.8) *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, WinchSelBucket := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE, EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := 7.0,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.Lifecycle.Busy, 'N1 fermeture engagee -> Busy');

    (* Scan 4 : recul commande jusqu a la frontiere EXACTE (Delta = -1.0) -> limite ACTIVE *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, WinchSelBucket := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := FALSE, ReqDescend := TRUE,
       EffectivePermitBucket_Open := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := -1.0,
       Config := Config, BucketState := BucketState);
    ASSERT_FALSE(FB.M2_ReqDescend, 'N1 recul a la frontiere -> recul inhibe');
    ASSERT_FALSE(FB.M2_RunRequest, 'N1 recul a la frontiere -> aucun ordre M2 (recul seul demande)');
    ASSERT_FALSE(FB.Fault.Error, 'N1 a la frontiere exacte -> AUCUN defaut cause 1 (comparaison stricte)');

    (* Scan 5 : 1 seul scan AU-DELA (Delta = -1.2, 10 ms) -> observabilite IHM, toujours < 500 ms *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, WinchSelBucket := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := FALSE, ReqDescend := TRUE,
       EffectivePermitBucket_Open := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := -1.2,
       Config := Config, BucketState := BucketState);
    BucketState := FB.BucketState;
    ASSERT_TRUE(BucketState.TooOpen, 'N1 au-dela -> TooOpen publie (IHM Idx109, geste correctif affiche)');
    ASSERT_FALSE(FB.Fault.Error, 'N1 10 ms au-dela -> defaut cause 1 NON latche (< 500 ms)');
    ASSERT_FALSE(FB.M2_ReqDescend, 'N1 au-dela -> recul toujours inhibe');

    (* Scan 6 : retour DANS la zone (Delta = -0.9), recul toujours demande -> la limite RELACHE *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, WinchSelBucket := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := FALSE, ReqDescend := TRUE,
       EffectivePermitBucket_Open := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := -0.9,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.M2_ReqDescend, 'N1 retour dans la zone -> recul de nouveau autorise (pas de verrou collant)');

    (* Scan 7-8 : RELACHEMENT puis REPOMPAGE du joystick a la frontiere -> la limite NE DOIT PAS
       se re-armer. Sous l ancienne borne (reference recapturee a chaque front), le re-press
       re-baselinait la reference et rendait le recul possible : ce test echouerait. *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, WinchSelBucket := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := FALSE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := -1.0,
       Config := Config, BucketState := BucketState);
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, WinchSelBucket := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := FALSE, ReqDescend := TRUE,
       EffectivePermitBucket_Open := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := -1.0,
       Config := Config, BucketState := BucketState);
    ASSERT_FALSE(FB.M2_ReqDescend, 'N1 repompage -> recul TOUJOURS inhibe (reference non recapturee)');
    ASSERT_FALSE(FB.M2_RunRequest, 'N1 repompage -> aucun ordre M2');

    (* Scan 9 : le sens VERS LA CIBLE doit rester servi (borne directionnelle, AX10B preserve) *)
    ADVANCE_TIME(10000000);
    FB(Enable := TRUE, Reset := FALSE, PowerContactorEngaged := TRUE, WinchSelBucket := TRUE,
       CmdClose_IHM := TRUE, ReqAscent := TRUE, ReqDescend := FALSE,
       EffectivePermitBucket_Close := TRUE,
       HomedM1 := TRUE, HomedM2 := TRUE, CablePosM1 := 0.0, CablePosM2 := -1.0,
       Config := Config, BucketState := BucketState);
    ASSERT_TRUE(FB.M2_ReqAscent, 'N1 montee VERS LA CIBLE toujours commandee (borne directionnelle)');
    ASSERT_TRUE(FB.M2_RunRequest, 'N1 ordre M2 servi vers la cible');
    ASSERT_TRUE(FB.Lifecycle.Busy, 'N1 Lifecycle intact -> reprise SANS reappui IHM (Q2 option A)');
END_TEST
```

⚠️ Aucune sortie nouvelle : l'observabilité passe par `BucketState.TooOpen`, **déjà publié** (§`PLAN` §3.4).
⚠️ `BucketState := FB.BucketState;` avant lecture = **copy-out VAR_IN_OUT**, pattern imposé par le
harnais (cf. `T181-21`, `test_fb_bucket.st:632`).

---

## 5. Réécriture de `TC-P10-029.1` — 2 modifications obligatoires

| Ligne | Actuel | Problème | Action |
|---|---|---|---|
| `:633-634` | `ASSERT_TRUE(BucketState.IsOpen)` / `ASSERT_FALSE(BucketState.IsClosed)` | assère la **RESTAURATION d'état** depuis `WasOpenAtStart` = **défaut `D5`** qu'on ne veut **pas** réintroduire | ⛔ **REMPLACER** par : l'état est **inchangé** par l'activation de la limite (AC5) |
| `:619-626` | recul à `CablePosM2 = 0.0` arrête le mouvement | **ROUGE** — c'est le défaut à corriger | ✅ **CONSERVER** : c'est le rouge→vert de l'AC1 |

**Réserve** : le scénario assère un arrêt à la **frontière physique** (variante b) et non plus « à
`M2StartPosM` ». Le **libellé** du test (« arret reel a M2StartPosM ») et son **jeu de données**
(`CoherenceLimitM := 5.0`) devront suivre la variante retenue en Q1.

---

## 6. Matrice de non-régression — **36 tests existants**

Analyse par mécanisme touché. La clause `BusyEdge` (`NOT Lifecycle.Busy`) est le **seul** changement
à effet transverse : elle supprime une **recapture** qui n'était possible **que lorsque `Busy` était
déjà TRUE**.

| Ce que la clause `BusyEdge` touche | Effet | Tests concernés |
|---|---|---|
| `M1RefPosM` (`:497`) → glissement M1 (`:265`) | **voulu** : `D6` fermé | `TC-P10-026`, `TC-P10-027`, `TC-P10-028` |
| `M2StartPosM` / `WasOpenAtStart` / `WasClosedAtStart` / `LeftStartSinceArm` | **sans effet** : variables mortes / purgées | `TC-P10-029.1` |
| `Lifecycle.Busy := TRUE` (déjà TRUE) | **sans effet** | tous |
| `Lifecycle.Done := FALSE` (déjà FALSE car `Busy` TRUE) | **sans effet** | tous |
| Cumul de timeout `:226` (`ResetEdge.Q`) et `:256` (`NOT Lifecycle.Busy`) | **non atteints** : la clause ne change **pas** `Lifecycle.Busy` | `TC-P10-046.1` à `TC-P10-046.4` |
| `TimeoutEngaged := Lifecycle.Busy AND MotionRequestActive` (`:221`) | **non atteint** | idem |

| Test | Verdict attendu | Justification |
|---|---|---|
| `TC-P10-026` glissement M1 | ✅ **reste vert** | la détection est **renforcée**, pas affaiblie ; `M1SlipDetected` est publié **avant** la recapture dans le même scan |
| `TC-P10-046.2` pause opérateur | ✅ **reste vert** | n'effectue **aucun re-press** (le joystick reste relâché jusqu'à la fin, `:929`) ⇒ aucun re-arm avant/après |
| `TC-P10-046.3` 2 × 600 ms + relâchements | ✅ **reste vert** | dépend de `MotionRequestActive` et de `Lifecycle.Busy`, **inchangés** par la clause |
| `TC-P10-046.1` / `.4` | ✅ **restent verts** | idem |
| `TC-P10-023` / `TC-P10-024` / `TC-P10-025.x` / `T196-*` / `T262-001` | ✅ **restent verts** | aucun re-arm en cours de manœuvre |
| `TC-P10-029` (recul = sens inverse) | ✅ **reste vert** | recul à `Δ = 0.0` avec `CoherenceLimitM := 5.0` ⇒ frontière à `−5.0`, non atteinte |
| **`TC-P10-029.1`** | 🔴 **ROUGE → VERT** (AC1) | seule assertion en échec : `:626` |
| 20 autres tests (`T323-*`, `TC-P10-03x`, `TC-P10-045.1`, `TC-P10-047.x`, `TC-P10-048.1`, `T181-21`, `T291-B`) | ✅ **restent verts** | n'exercent ni `BusyEdge` en cours de manœuvre, ni le recul |

⚠️ `TC-P10-029.1` étant **dans le périmètre d'écriture de T339/DSH11** (modifs non commitées), les
`N1`/`N2` et la réécriture **ne peuvent pas être appliqués** avant l'arbitrage **Q3**.

---

## 7. Ce qui reste à trancher (rappel)

| # | Question | Bloque |
|---|---|---|
| **Q1** | Ancrage : frontière **physique** (b) ou **point de départ** (a) ? | §5 (libellé et données de `TC-P10-029.1`), nom de la sortie |
| **Q2** | Comportement à la limite : **(A)** reprise au joystick / **(B)** `Done` propre / **(C)** diagnostic | assertions de `N1` scan 6 |
| **Q3** | Collision `test_fb_bucket.st` avec **T339** | application des blocs §3, §4, §5 |
| **Q4** | Périmètre du garde-fou `G514` | branchement `PLANS` |

**Indépendant de Q1/Q2/Q3** : le correctif `BusyEdge` (§3) et la purge des 6 variables mortes.

---

**Aucun fichier `CODE/` modifié · aucun test écrit · aucun bundle · aucun commit.**
