# 🏗️ PLAN TECHNIQUE T346 — borne de recul `FB_Bucket`

| | |
|---|---|
| **Tâche** | T346 (C1) — contrat `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T346_BORNE_RECUL.yaml` |
| **Date** | 2026-09-20T22:40+02:00 |
| **Agent** | DSH13 |
| **Statut** | ✅ **APPLIQUÉ — variante (b) + Q2 option A**, arbitrage humain du 2026-09-20 (lot livré, non commité) |
| **Diagnostic source** | `DOC/WFLOW/AUDITS/DESIGN/DIAGNOSTIC_T346_BORNE_RECUL_2026-09-20.md` |
| **Base** | HEAD `f4ca3fee`, `FB_Bucket.st` **propre** |

> 🎯 **Objectif de ce document** : rendre l'arbitrage humain **immédiat** en montrant le code
> exact des 2 variantes. Aucune ligne de `CODE/` n'est écrite.

---

## 1. 🔴 DÉCOUVERTE QUI CHANGE L'ARBITRAGE — défaut `D6`, non vu par le brief

En préparant ce plan, `M1RefPosM` a été tracée — et **elle n'est pas morte du tout** :

| Ligne | Code | Rôle |
|---|---|---|
| `:126` | `M1RefPosM : REAL;` | « Position M1 **mémorisée à l'entrée Busy** » |
| `:497` | `M1RefPosM := CablePosM1;` | capture sur `BusyEdge.Q` ← **le même front que D1** |
| `:265` | `M1SlipDetected := Lifecycle.Busy AND (ABS(CablePosM1 - M1RefPosM) > M1SlipToleranceM);` | détection de glissement M1 |
| `:266-267` | `IF M1SlipDetected THEN M1SlipFaultLatched := TRUE;` | latch |
| `:269` | `instCauses[3].Active := M1SlipFaultLatched;` | **→ `Fault` → `SevereError`** (bit 3 = 8, cause « Glissement treuil M1 pendant manœuvre benne ») |

### ⛔ Conséquence

`BusyEdge` — keyé sur `(CloseReq OR OpenReq) AND MotionRequestActive` **sans `NOT Lifecycle.Busy`**
(`:494`) — **recapture `M1RefPosM` à chaque pompage du joystick en pleine manœuvre**.

⇒ **La détection de glissement de câble M1 est RE-BASELINÉE par un simple geste opérateur.**
Un glissement réel (dérive de câble) **ne déclenchera jamais** la cause 3 tant que l'opérateur
pompe le joystick assez souvent. **C'est une défaite de détection de sécurité**, plus grave que
les coupures parasites elles-mêmes — et elle a **exactement la même cause racine** (D1).

### ✅ Ce que ça implique pour T346

1. **Corriger `BusyEdge` n'est PAS optionnel** et n'est pas lié au choix Q1 : c'est un
   **correctif de sécurité à faire dans tous les cas**.
2. **`M1RefPosM` DOIT être conservée** (contrairement aux 5 autres variables mortes) : elle est
   vivante et elle est le cœur de D6.
3. **Critère d'acceptation supplémentaire à ajouter au contrat** (voir §6).

---

## 2. Les 6 variables de `FB_Bucket.st` — tri définitif

| Variable | Ligne | Statut | Décision |
|---|---|---|---|
| `LeftStartSinceArm` | `:130` | **morte** (écrite `:501`/`:561`, jamais lue) | ❌ **PURGER** |
| `M2StartPosM` | `:127` | **chaîne morte** (lue `:560` seulement pour alimenter la morte) | ❌ **PURGER** |
| `WasOpenAtStart` | `:128` | **morte** | ❌ **PURGER** |
| `WasClosedAtStart` | `:129` | **morte** | ❌ **PURGER** |
| `BandLatchConcord` | `:115` | **morte** — grep sur tout `CODE/` = 0 lecture | ❌ **PURGER** (hors `2a307b5b`) |
| `StateOffsetM` | `:116` | **morte** — orpheline de l'ancien « filet §5a » | ❌ **PURGER** (hors `2a307b5b`) |
| **`M1RefPosM`** | **`:126`** | **VIVANTE** (`:265`) — cœur de **D6** | ✅ **CONSERVER** |

⚠️ **Correction du brief** : le brief parle de « purger ou réutiliser `LeftStartSinceArm` ». Le
périmètre réel est **6 purges + 1 conservation**, et la variable à conserver est celle que le
brief n'évoque pas.

---

## 3. 🥇 VARIANTE (b) — RECOMMANDÉE : frontière physique déjà calculée

### 3.1 Principe

`FB_Bucket` **calcule déjà** les frontières physiques de la benne sur `Δ = M2 − M1 = DeltaPosition_M`
(`:419`) :

```st
:424  NearClosed := ClassCanRun AND (ABS(DeltaPosition_M - Config.OffsetCloseM) <= Config.CoherenceLimitM);
:425  NearOpen   := ClassCanRun AND (ABS(DeltaPosition_M - Config.OffsetOpenM)  <= Config.CoherenceLimitM);
:434  BucketState.TooOpen   := DeltaPosition_M < (Config.OffsetOpenM  - Config.CoherenceLimitM);
:435  BucketState.TooClosed := DeltaPosition_M > (Config.OffsetCloseM + Config.CoherenceLimitM);
```

**Et ces 2 drapeaux sont VIVANTS et DÉJÀ CONSOMMÉS** :
- `:755` — filet §5a : `TonOffsetMismatch(IN := ClassCanRun AND (BucketState.TooOpen OR BucketState.TooClosed), PT := T#2s)` → `OffsetStateMismatchWarn` (**avertit seulement, n'arrête rien**) ;
- `FB_TroubleshootingView.st:335-336` → **IHM** `Idx109_BucketTooOpen` / `Idx110_BucketTooClosed`, avec le **geste correctif déjà affiché** (`ST_ChainBucket.st:11-12`) :
  - `Idx109` TooOpen → « Dépassement ouverture : **Enrouler M2** » (= monter = fermer) ;
  - `Idx110` TooClosed → « Dépassement fermeture : **Dérouler M2** » (= descendre = ouvrir).

### 3.2 La borne = « le recul ne franchit pas la frontière que la machine diagnostique déjà »

| Manœuvre | Recul = sens | Frontière à ne pas franchir |
|---|---|---|
| **Fermeture** (`CloseReq`, cible Δ↑) | `ReqDescend` (Δ↓) | `TooOpen` → Δ < `OffsetOpenM − CoherenceLimitM` |
| **Ouverture** (`OpenReq`, cible Δ↓) | `ReqAscent` (Δ↑) | `TooClosed` → Δ > `OffsetCloseM + CoherenceLimitM` |

**Symétrique, physique, absolue — et totalement insensible au geste opérateur** ⇒ **D1 éliminé par
construction** (il n'y a plus aucune référence à `M2StartPosM`).

### 3.2bis 🎯 La frontière **existe déjà à TROIS endroits** — la variante (b) n'ajoute aucun concept

Vérifié ligne à ligne : la même frontière physique est **déjà** exprimée trois fois dans `FB_Bucket` :

| Ligne | Expression | Rôle actuel |
|---|---|---|
| `:194` | `MinAllowedOffset := Config.OffsetOpenM - Config.CoherenceLimitM;` | borne basse de plausibilité |
| `:198-200` | `OffsetMaxViolNow := HomingPositionValid AND (… OR (CablePosM2 < (CablePosM1 + MinAllowedOffset)))` | **détection d'écart maximum** |
| `:434` | `BucketState.TooOpen := DeltaPosition_M < (Config.OffsetOpenM - Config.CoherenceLimitM);` | état publié IHM (`Idx109`) |

### 🔴 Conséquence qui **renforce** la recommandation et change l'argumentation

`:202` `TonOffsetMaxViol(IN := OffsetMaxViolNow, PT := T#500ms)` → `OffsetMaxFaultLatched` →
`instCauses[1]` (bit 1 = 2) → **`Fault` → `SevereError`** (`:414`), **latche**.

⇒ **Aujourd'hui, un recul prolongé n'est pas « non borné » : il est borné par un DÉFAUT MACHINE
LATCHÉ 500 ms après avoir franchi la frontière** — exactement la même critique que le timeout 60 s.

⇒ **La variante (b) ne crée donc AUCUNE limite nouvelle : elle empêche un défaut déjà défini**, en
inhibant proprement le sens du recul au lieu de laisser l'opérateur piloter dans le défaut. C'est la
justification la plus forte possible : *même seuil, même physique, mais un arrêt propre et reprenable
au lieu d'un latch + Reset.*

### ⚠️ Piège de test évité (et corrigé dans `TESTPLAN` §4)

`OffsetMaxViolNow` est **strict** (`<` frontière) alors que la borne est **large** (`<=` frontière) :
à la frontière **exacte** (`Δ = OffsetOpenM − CoherenceLimitM`), la borne mord mais **aucun défaut ne
s'arme** ⇒ c'est le point de test **idéal**.

Conséquence pratique retenue dans `N1` : ne **jamais** rester au-delà de la frontière plus de
**20 ms** sur l'ensemble du test, et revenir dedans — sinon les assertions « recul inhibé »
passeraient **VERTES pour la mauvaise raison** (défaut cause 1, et non la borne).

### 3.3 Anti-bagotement : **sans inventer aucun chiffre**

Le brief demande « une marge/hystérésis » et interdit d'inventer une valeur. **Les deux pièges sont
évités** :

| Mécanisme | Pourquoi il suffit |
|---|---|
| **Frontière FIXE** | `TooOpen`/`TooClosed` ne bougent pas avec le geste ⇒ il n'y a **rien à hystéréser** (comparer `D3` : l'ancienne comparait à une référence *mobile*, d'où le chatter) |
| **Debounce `CST_BandStableTime` (`T#200ms`)** | constante **déjà déclarée** (`:146`) et **déjà documentée « anti-chatter au bord »** — c'est **le** mécanisme anti-chatter du projet, déjà utilisé pour la confirmation de bande |
| **Hystérésis d'ÉTAT, pas de distance** | l'inhibition tombe d'elle-même dès que Δ revient dans la zone saine ⇒ **aucune distance de marge à inventer** |

✅ Répond exactement à la contrainte §4 du brief : **zéro nouvelle constante, zéro chiffre inventé,
une constante existante réutilisée.**

### 3.4 Patch exact — 3 emplacements

**① `VAR` — 1 TON + 2 témoins** (après `TonBandOpen`, `:104`) :
```st
    TonRecoilLimit                  : TON;                            // . [LOC] Anti-chatter de la limite de recul benne (meme base que TonBand*)
    RecoilLimitReachedNow           : BOOL;                           // . [LOC] Recul au bord de la frontiere physique benne (instantane)
    RecoilLimitActive               : BOOL;                           // . [LOC] Limite de recul ACTIVE (confirmee CST_BandStableTime)
```
＋ ⛔ **AUCUNE sortie nouvelle n'est nécessaire — vérifié.** Le besoin d'observabilité (exigence R5) est
**déjà couvert par l'existant** : la condition d'arrêt **EST** `BucketState.TooOpen` / `TooClosed`,
déjà lus par le filet §5a (`:755`) et **déjà publiés à l'IHM** (`Idx109_BucketTooOpen` /
`Idx110_BucketTooClosed`, `FB_TroubleshootingView.st:335-336`) avec le **geste correctif affiché**
(`ST_ChainBucket.st:11-12`). L'opérateur voit donc la cause *et* la manœuvre à faire, **sans aucun
champ d'interface nouveau**.

Cette vérification a évité une **dilatation de périmètre** : exposer un champ de diagnostic par la
chaîne IHM aurait exigé `WinchM2.Bucket.State.MechState` (type `ST_WinchBenneHMI` hors périmètre) —
`ST_fbBucket_State.st` ne contient d'ailleurs **pas** `M2BucketJogLimit` (contrôle : la chaîne IHM est
`séparée`). Bénéfices : **zéro impact `G330_check_type_safety.py`**, **zéro nouveau témoin mort**,
et `RecoilLimitActive` reste **local ET lu** par la branche d'inhibition ⇒ **`G514` reste vert**.

⚠️ **Pas** de slot `instCauses[]` : vérifié, tout slot alimente `FB_FaultCore` (`:294-295`) ⇒
`Fault` ⇒ `SevereError` (`:414`) ⇒ **arrêt + Reset**. Une borne n'est pas un défaut machine.

**② `:494` — correctif `D1` / `D6` (sécurité, indépendant de Q1)** :
```st
- BusyEdge(CLK := (CloseReq OR OpenReq) AND MotionRequestActive);
+ BusyEdge(CLK := (CloseReq OR OpenReq) AND MotionRequestActive AND NOT Lifecycle.Busy);
```
⇒ **plus aucune recapture** de `M1RefPosM` (D6 fermé ✅) ni des 3 témoins (D1 fermé ✅).
*Vérifié sur l'ordre d'exécution* : `Lifecycle.Busy := TRUE` est posé **après** (`:502`), donc au scan
d'armement `Lifecycle.Busy` vaut encore `FALSE` → le front d'armement est **préservé**.

**③ `:560-562` — REMPLACER le latch mort par la limite de recul** :
```st
// AVANT (code mort : ecrit, jamais lu)
IF (CloseReq AND (CablePosM2 > M2StartPosM)) OR (OpenReq AND (CablePosM2 < M2StartPosM)) THEN
    LeftStartSinceArm := TRUE;
END_IF;

// APRES (T346) — limite de recul : frontiere PHYSIQUE benne, directionnelle, observable
RecoilLimitReachedNow := (CloseReq AND BucketState.TooOpen)
                         OR (OpenReq  AND BucketState.TooClosed);
TonRecoilLimit(IN := RecoilLimitReachedNow, PT := CST_BandStableTime);
RecoilLimitActive := TonRecoilLimit.Q;

IF RecoilLimitActive THEN
    IF CloseReq THEN
        M2_ReqDescend := FALSE;                                    // recul vers l'ouverture interdit
    ELSE
        M2_ReqAscent  := FALSE;                                    // recul vers la fermeture interdit
    END_IF;
    M2_RunRequest := M2_ReqAscent OR M2_ReqDescend;                // le sens VERS LA CIBLE reste servi
END_IF;
```

**④ Purgation** — retirer `:127-130` (`M2StartPosM`, `WasOpenAtStart`, `WasClosedAtStart`,
`LeftStartSinceArm`), les retirer du bloc `BusyEdge.Q` (`:498-501`), et purger `:115-116`
(`BandLatchConcord`, `StateOffsetM`).

### 3.5 Propriétés obtenues — correspondance avec les défauts

| Défaut | Traitement | Comment |
|---|---|---|
| **D1** référence mobile | ✅ **éliminé** | plus aucune référence au geste ; `BusyEdge` corrigé |
| **D2** ré-armement à +1 incrément | ✅ **éliminé** | `LeftStartSinceArm` **purgée** : plus rien à ré-armer |
| **D3** zéro marge / chatter | ✅ **traité** | frontière **fixe** + debounce **`CST_BandStableTime`** existant |
| **D4** coupe non récupérable | ✅ **éliminé** | `CloseReq`/`OpenReq` **jamais** relâchés, `Lifecycle` **jamais** touché ⇒ reprise immédiate au joystick (Q2 **option A**) |
| **D5** falsification d'état | ✅ **éliminé** | `BucketState` **jamais** écrit par la borne |
| **D6** détection glissement M1 contournable | ✅ **fermé** | `M1RefPosM` n'est plus recapturée |
| AX10B `HoldAscentP1AfterClose` | ✅ **préservé** | borne **directionnelle** ; AX10B force déjà `M2_ReqDescend := FALSE` (`:519`) |

### 3.6 ⚠️ Réserve honnête sur la variante (b)

En valeurs de **production** (`OffsetOpenM = 0.0`, `OffsetCloseM = 15.0`, `CoherenceLimitM = 1.0`,
`AF-10:307`), la frontière « trop ouvert » est `Δ < −1.0`. Une **fermeture** engagée depuis la bande
ouverte (`Δ ≈ 0`) autoriserait un recul normal jusqu'à `Δ = −1.0` — **c'est le comportement voulu**
(on peut toujours ouvrir la benne), mais :
- la **sémantique change** par rapport à l'ancienne borne (qui interdisait de revenir au point de départ) ;
- **`TC-P10-029`** (VERT, exerce un recul à `Δ = 0.0` avec `CoherenceLimitM := 5.0`) **reste vert**
  car `Δ = 0.0 > −5.0` → ✅ compatible, mais à **confirmer par exécution**.

👉 **Si l'intention métier est « un recul qui revient au point de départ = manœuvre échouée, on
s'arrête »**, alors la variante (b) ne l'exprime **pas** — c'est la variante (a). **C'est LA question Q1.**

---

## 4. 🥈 VARIANTE (a) — si l'intention métier est « retour au départ = abandon »

Ancrage conservé sur `M2StartPosM`, mais **en corrigeant les 4 défauts** :

```st
RecoilLimitReachedNow := (CloseReq AND (CablePosM2 <= (M2StartPosM - CST_RecoilMarginM)))
                         OR (OpenReq  AND (CablePosM2 >= (M2StartPosM + CST_RecoilMarginM)));
TonRecoilLimit(IN := RecoilLimitReachedNow, PT := CST_BandStableTime);
RecoilLimitActive := TonRecoilLimit.Q;
IF RecoilLimitActive THEN
    IF CloseReq THEN M2_ReqDescend := FALSE; ELSE M2_ReqAscent := FALSE; END_IF;
    M2_RunRequest := M2_ReqAscent OR M2_ReqDescend;
END_IF;
```
＋ **correctif `BusyEdge` obligatoire** (§3.4 ②) pour figer la référence, et **purge** de
`LeftStartSinceArm`/`WasOpenAtStart`/`WasClosedAtStart`.

| | Variante (a) |
|---|---|
| Défauts corrigés | D1 (via `BusyEdge`), D2, D3 (marge + debounce), D4, D5, D6 |
| **Constante nouvelle** | ⚠️ **`CST_RecoilMarginM` à créer ⇒ VALEUR À ARBITRER** (le brief l'interdit sans base) |
| Ancre | reste **liée au geste** (donc sensible au moment où l'opérateur appuie) |
| Doctrine projet | ⚠️ contraire à `PRG_04:761-766` (« jamais sur l'anticipation ») si la marge réutilise `CloseAnticipationM` |

🚫 **Non recommandée** : elle **impose de choisir un chiffre de sécurité** que le brief interdit
d'inventer, là où la variante (b) n'en demande aucun.

---

## 5. Plan de test (rouge → vert)

> 📄 **Blocs ST prêts à coller, preuve chiffrée de `D6` et matrice de non-régression des 36 tests
> existants : `DOC/WFLOW/CONTRACTS/TESTPLAN_T346_BORNE_RECUL.md`.** Le présent paragraphe n'en
> garde que la vue d'ensemble.

### 5.1 Base existante — `TC-P10-029.1` (`test_fb_bucket.st:551-635`)

| Scan | Rôle | Action T346 |
|---|---|---|
| 2-3 | armement + montée au-dessus du départ | **réécrit** (plus de `M2StartPosM` en (b)) |
| 4-5 | recul commandé, avant la borne → `M2_RunRequest` TRUE | **conservé** (cœur de l'AC1) |
| 6 | recul **à** la borne → arrêt attendu | **conservé** — c'est le **ROUGE** à faire passer au VERT |
| 6b | `IsOpen`/`IsClosed` **restaurés** depuis `WasOpenAtStart` | ⛔ **À REMPLACER** : assère **D5**, qu'on ne veut **pas** réintroduire → devient « `BucketState` **inchangé** » |

### 5.2 Cas neufs — chacun doit **échouer sous mutation**

| # | Cas | Prouve | Mutation qui doit le faire échouer |
|---|---|---|---|
| N1 | **Pompage joystick** : position constante, `MotionRequestActive` FALSE puis TRUE (×3) pendant `Busy` → `M2_RunRequest` reste TRUE, `Lifecycle.Busy` reste TRUE | **D1/D2 non réintroduits** | retirer `NOT Lifecycle.Busy` du `CLK` |
| N2 | **Glissement M1 après pompage** : `CablePosM1` dérive de > `M1SlipToleranceM`, avec pompage entre-temps → `M1SlipDetected` devient TRUE | **D6 fermé** (sécurité) | retirer `NOT Lifecycle.Busy` du `CLK` |
| N3 | **Bagotement** : Δ oscille de ±1 incrément autour de la frontière, **pendant moins que `CST_BandStableTime`** → pas de coupe | **D3 non réintroduit** | passer `PT := T#0ms` |
| N4 | **Reprise sans réappui IHM** : borne atteinte, opérateur maintient `ReqDescend` puis bascule sur `ReqAscent` → `M2_RunRequest` redevient TRUE **sans toucher `CmdClose_IHM`** | **D4 non réintroduit** (option A) | toucher `CloseReq := FALSE` dans la branche de borne |
| N5 | **État intact** : capture `BucketState` avant/après activation de la borne → `IsOpen`/`IsClosed` identiques | **D5 non réintroduit** | ajouter `BucketState.IsOpen := WasOpenAtStart` |
| N6 | **Symétrie** : même cas N4 en **ouverture** (`OpenReq`, `ReqAscent` en recul) | **AC7** | retirer la branche ouverture |
| N7 | **Directionnel** : borne active → le sens **vers la cible** reste commandé (`M2_ReqAscent` TRUE en fermeture) | **AX10B / AC6** | inhiber les deux sens |

⚠️ **Piège harnais à respecter** (documenté `AF-10 §8` alerte 8 + commentaires des tests) : STruCpp
**ne remet pas à zéro** les entrées non repassées entre 2 appels (instance persistante).
⇒ Dans N1/N4, `ReqAscent` doit être **explicitement relâché** sinon `MotionRequestConflict` neutralise.

---

## 6. Garde-fou `fix:` + `guard:` — **LIVRÉ**, et son périmètre (**Q4**)

**Règle projet** : tout bug ⇒ correction **+** garde-fou automatique.

### 6.1 ✅ Livré : `G514_check_dead_local_variable.py`

`TOOLS/AGENT_WORKFLOW/scripts/G514_check_dead_local_variable.py`

| Règle | Contenu |
|---|---|
| **A** | dans un bloc `VAR` nu (jamais `VAR CONSTANT`/`_INPUT`/`_OUTPUT`/`_IN_OUT`/`_GLOBAL`/`_TEMP`), toute variable absente du **texte des lectures** est signalée |
| **B** | une `VAR` de **`PROGRAM`** est lisible de l'extérieur (`<POU>.<Variable>`) : la référence croisée compte comme lecture. **Sans cette règle le détecteur produisait ~50 faux positifs** sur `PRG_06_Outputs.st` |

Neutralisés avant analyse (ce ne sont pas des lectures) : commentaires `//` et `(* … *)` multi-lignes,
lignes de déclaration, cibles d'affectation (`Nom :=`, `Nom[i] :=` — **contenu du crochet conservé**).
Les commentaires ne comptent jamais comme lecture.

`--selftest` **PASS** — 6 cas : forme réelle de `FB_Bucket.st` (**5/6 détectées**, `M2StartPosM`
correctement **non** signalée = chaîne morte, limite prouvée et non subie) · contre-preuve écrite-puis-relue ·
règle B (lecture croisée reconnue / jamais lue détectée) · commentaire seul · **indice de boucle
`AlarmArray[i] := …` non signalé** (faux positif réel corrigé, cas `FB_Hmi_BannerFormatter.st:174-176`).

### 6.2 🔴 Mesure réelle — `24` sites dans `9` fichiers (Q4 devient décidable)

```text
6  CODE/G_CYCLE/FB_CycleSemiAuto.st
5  CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st      ← périmètre T346
4  CODE/M_MAIN/PRG_04_Treuils_Benne.st
3  CODE/M_MAIN/PRG_03_Modes_Cycle.st
2  CODE/M_MAIN/PRG_05_Translation.st
1  CODE/A_COMMUN/FB_Brake.st
1  CODE/C_DIAG_RESEAUX/FB_Diag_IhmHeartbeat.st
1  CODE/E_CODEURS/FB_Encoder_Abs.st
1  CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st
```

**Contre-vérifiés ligne à ligne, 4 cas tirés au hasard — tous authentiques :**

| Cas | Constat |
|---|---|
| **`ContactorIncoherentError`** `FB_Brake.st:48` | « **Défaut mémorisé** incohérence contacteur » — écrit `:62`, `:119`, **jamais lu** ⇒ **un défaut latché qui ne remonte nulle part** |
| **`IhmEdgeSeen`** `FB_Diag_IhmHeartbeat.st:30` | « Verrou front vu (**interdit RETAIN au boot**) » — écrit `:44`, `:56`, **jamais lu** ⇒ **protection de boot morte** |
| **`StepDelayTarget`** `FB_WinchOutputInterlock.st:106` | écrit **9 fois** (`:354`→`:445`), **jamais lu** ⇒ cible de palier mémorisée pour rien |
| **`PresetCompleted`** `FB_Encoder_Abs.st:60` | « Fait de fin de maintien preset (un scan) » — écrit 3 fois, **jamais lu** |

⚠️ Les 2 premiers appartiennent à la **même famille que D6** (« témoin de sécurité qui ne sert plus »)
⇒ **remontés séparément, hors scope T346**.

### 6.3 Décision de branchement — **reportée, pour 2 raisons concrètes**

| Raison | Détail |
|---|---|
| **Q4 non tranché** | branché bloquant sur tout `CODE/`, il rend la suite **rouge sur 19 sites hors périmètre T346** — inacceptable en l'état |
| **Collision d'écriture** | `TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py` est dans le **périmètre d'écriture actif de T339/DSH11** |

⇒ Le **script + son selftest sont livrés et autonomes** ; le branchement d'une ligne dans les `PLANS`
est **prêt mais non appliqué** (pas d'allowlist, pas de gate rouge introduite en douce).

### 6.4 Options (**Q4**) — la décision n'appartient **pas** à l'agent

| Option | Effet | Verdict |
|---|---|---|
| **Bloquant sur tout `CODE/`** | rouge sur **24** sites, dont **19 hors T346** | ⚠️ impose un lot de nettoyage dédié |
| **Bloquant, `--files` = fichiers du lot** | cible exactement `FB_Bucket.st` | ✅ **recommandé** — 1 ligne, zéro allowlist |
| **Bloquant, périmètre dérivé des fichiers modifiés** | ratchet automatique | 🟠 le plus élégant, mais nécessite `git` en sous-processus |
| **Non bloquant** | informe sans bloquer | 🟠 contraire à l'esprit « garde-fou » |

🚫 **Aucune allowlist ne sera créée par l'agent** (interdiction explicite du préambule projet).

---

## 7. Critères d'acceptation — mise à jour du contrat

Le contrat `TASK_CONTRACT_T346_BORNE_RECUL.yaml` (11 AC, `check_task_contract.py` **PASS 0 erreur**)
**doit être complété** par :

| # | Nouveau critère (défaut `D6`) |
|---|---|
| **AC12** | `M1RefPosM` n'est **plus recapturée** par un relâchement/repompage du joystick en pleine manœuvre : un glissement réel de M1 pendant la manœuvre déclenche `M1SlipDetected` puis la cause 3, **même si l'opérateur pompe le joystick**. `verified_by` : cas CI **N2**, qui doit échouer si `NOT Lifecycle.Busy` est retiré du `CLK` de `BusyEdge`. |
| **AC13** | `M1RefPosM` est **conservée** (elle est vivante) et les **6 autres** variables sont purgées. `verified_by` : recherche des 7 identifiants dans `CODE/`. |

---

## 8. Ordre d'exécution proposé (après arbitrages)

```text
1. Q1 → Q4 tranchés par l'humain
2. Correctif sécurité D1/D6 (BusyEdge) + tests N1/N2 → ROUGE avant / VERT après
3. Borne de recul (variante retenue) + tests N3/N4/N5/N6/N7 + réécriture TC-P10-029.1
4. Purge des 6 variables mortes + AC13
5. Garde-fou G5xx + --selftest + PLANS palier C
6. Bundle + diff bundle + G200 --report + gates palier C
7. Clôture AF-10 §8 alerte 5 + mentions :139/:288/:326 + statut TC-P10-029.1
8. Contrat → COMPLETED, TASKS.yaml → avancement, verrou DSH13
9. ⛔ COMMIT : seulement sur accord humain EXPLICITE et distinct du GO d'implémentation
```

---

## 9. Ce qui est demandé à l'humain — 4 réponses

| # | Question | Recommandation agent |
|---|---|---|
| **Q1** | Frontière **physique** (b) ou **point de départ** (a) ? | **(b)** — aucun chiffre à inventer, insensible au geste, conforme à la doctrine écrite |
| **Q2** | Comportement à la limite ? | **(A)** coupe + reprise au joystick, `Lifecycle`/`Busy` intacts |
| **Q3** | Collision `test_fb_bucket.st` avec **T339/DSH11** (en cours, modifs non commitées) ? | séquencer : clôturer T339 d'abord, ou autoriser l'édition du seul bloc `TC-P10-029.1` |
| **Q4** | Périmètre du garde-fou (§6.2) ? | **bloquant, limité aux fichiers du lot** |

> ⚠️ **Q1 reste la seule vraie question de conception.** Si l'intention métier est « revenir au point
> de départ = la manœuvre a échoué, on s'arrête », c'est (a) — mais cela **impose de choisir un
> chiffre de sécurité**, ce que le brief interdit de deviner. Si l'intention est « protéger la
> machine contre un recul hors zone physique », c'est (b), **sans aucun chiffre**.

---

**Aucun fichier `CODE/` modifié · aucun bundle généré · aucun commit.**
