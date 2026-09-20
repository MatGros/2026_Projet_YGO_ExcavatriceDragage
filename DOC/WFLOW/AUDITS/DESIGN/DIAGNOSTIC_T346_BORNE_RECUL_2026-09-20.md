# 🩺 DIAGNOSTIC T346 — Cause exacte des « coupures parasites » de la borne de recul `FB_Bucket`

| | |
|---|---|
| **Tâche** | T346 (C1, sécurité machine) |
| **Date** | 2026-09-20T22:34+02:00 |
| **Agent** | DSH (nouvelle session T346) |
| **Base de code** | HEAD `f4ca3fee` · `FB_Bucket.st` **propre** (aucun diff non commité) |
| **Statut** | 🔍 Diagnostic **livré** — ⏸️ **ARRÊT AVANT CODE** (plan à valider) |
| **Périmètre de cette fiche** | Lecture seule `CODE/` — **zéro ligne de code écrite** |

> 📌 Objet : `TC-P10-029.1` (ROUGE) · `AF_Partie-10 … FB_Bucket_v1.0.md:415` §8 alerte 5 (arbitrage en suspens)
> · commit `2a307b5b` (2026-09-05) qui a retiré les 2 branches d'arrêt à `M2StartPosM`.

---

## 1. Verdict

**L'hypothèse de départ du brief (« bagotement/bruit de mesure autour de `M2StartPosM` ») est
INSUFFISANTE.** Elle décrit un seul des défauts. La cause dominante est **une référence qui
se déplace en pleine manœuvre**, pas un bruit de mesure.

🔴🔴 **Et le même défaut cache pire** : la référence mobile recapture aussi `M1RefPosM`, qui porte la
**détection de glissement de câble M1** ⇒ **D6**, une **défaite de détection de sécurité** (§2.3),
plus grave que les coupures parasites. **Six défauts**, pas un seul.

Les « coupures parasites » n'étaient **pas un aléa** : c'était le comportement **déterministe** de
la borne sur tout geste opérateur normal.

**Corollaire décisif** : réintroduire la borne d'origine **avec une simple hystérésis** ne
corrigerait que `D3` et **laisserait `D1` intact** → le défaut reviendrait. Ce point conditionne
tout le plan (§6).

---

## 2. Les 5 défauts, chacun prouvé

Colonnes de preuve : `PC` = version d'avant le commit, lue par `git show 2a307b5b^:CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` ;
`AC` = fichier actuel sur disque.

| # | Défaut | PC | AC | Gravité |
|---|---|---|---|---|
| **D1** | **Référence MOBILE** : `BusyEdge` est keyé sur `(CloseReq OR OpenReq) AND MotionRequestActive` **sans clause `NOT Lifecycle.Busy`**. Un relâchement/repompage du joystick en pleine manœuvre recrée un front ⇒ **recapture de `M2StartPosM`** à la position courante | `:422` | `:494` | 🔴 |
| **D2** | Le **même** front remet `LeftStartSinceArm := FALSE` (`:428-429` PC). Le drapeau se ré-arme donc **au scan suivant**, dès **+1 incrément** au-dessus de la nouvelle référence : la borne **suit** le pompage et **n'a aucune marge** | `:424-431` | `:496-504` | 🔴 |
| **D3** | **Zéro marge** : comparaison brute `CablePosM2 <= M2StartPosM` (fermeture) / `>=` (ouverture). Aucune anticipation, alors que les arrêts **nominaux** utilisent `CloseAnticipationM`/`OpenAnticipationM` | `:491`, `:516` | `:560-562` vs `:566`, `:592` | 🔴 |
| **D4** | **Coupe NON récupérable** : la branche pose `CloseReq := FALSE` + `Done := TRUE` **alors que `MotionRequestActive` reste TRUE** ⇒ plus aucun front possible. Or `CloseReq`/`OpenReq` ne sont posés QUE par `CmdClose_IHM`/`CmdOpen_IHM` sous `NOT Lifecycle.Busy AND NOT M1_Busy AND NOT M2_Busy` ⇒ **l'opérateur est verrouillé jusqu'à réappui du bouton IHM** | arrêt `:497-499`, pose `:414-420` | pose `:484-492` | 🔴 |
| **D5** | **Falsification d'état** : à la coupe, `BucketState.IsOpen/IsClosed` sont réécrits depuis `WasOpenAtStart/WasClosedAtStart` alors que M2 a **physiquement bougé** — et ces 2 témoins sont eux-mêmes recapturés à chaque front (D1) | `:495-496`, `:520-521` | — (branches retirées) | 🟠 |
| **D6** | 🔴🔴 **DÉFAITE DE DÉTECTION DE SÉCURITÉ** : `M1RefPosM` est la référence de la **détection de glissement M1** — et elle est capturée sur **le même `BusyEdge.Q`** que D1. Un pompage joystick la **re-baseline** ⇒ glissement réel jamais détecté (voir §2.3) | `:426` | `:497` + `:265` | 🔴🔴 |

### 2.1 Preuve que D1 n'est pas théorique — le geste est documenté

> « **Relâchement joystick à mi-close** = Timeout 60 s (pas de sortie propre) … aucun des 2 agents
> ne couvre ce « cancel manquant » … Exploitant **« bloqué »** 60 s sur une simple pause »
> — `DOC/WFLOW/AUDITS/DESIGN/CHALLENGE_T175-01_02_M2_BUCKET_SAFETY.md:51` (constat **F06**)

Le relâchement/repompage du joystick en cours de manœuvre est donc un geste **réel, observé sur
site**. Combiné à D1+D2, chaque pompage **déplace la borne vers le haut** ; la moindre redescente
au niveau de la nouvelle référence **coupe la manœuvre** — puis D4 interdit toute reprise sans
réappui IHM. C'est exactement le message de commit : « coupures … **pour ouverture et fermeture
complètes** ».

### 2.2 Ce qui reste comme « borne » aujourd'hui

Rien, sinon un **défaut machine** :
`CfgTimeoutDuration := T#60s` (`:50`) → `TimeoutEngaged := Lifecycle.Busy AND MotionRequestActive`
(`:221`) → budget `:239-244` → `TonTimeout.Q` (`:251`) → `TimeoutFaultLatched` (`:252`) →
`instCauses[2]` (`:260-262`) → `instFault(...)` (`:294-295`) → `Fault` → **`SevereError := Fault.Error`**
(`:414`) → coupure totale (`:453-461`) **+ Reset requis** (`Ready := Enable AND NOT Fault.Latched`, `:326`).

⛔ **60 s de câble déroulé puis un défaut machine n'est pas une borne de recul.**

### 2.3 🔴🔴 D6 — découverte tardive, et **plus grave que les coupures parasites**

Trouvée en préparant le plan technique, en traçant `M1RefPosM` — que le brief ne mentionne pas.

| Ligne | Code | Rôle |
|---|---|---|
| `:126` | `M1RefPosM : REAL;` | « Position M1 **mémorisée à l'entrée Busy** » |
| `:497` | `M1RefPosM := CablePosM1;` | **capture sur `BusyEdge.Q`** ← le **même** front que D1 |
| `:265` | `M1SlipDetected := Lifecycle.Busy AND (ABS(CablePosM1 - M1RefPosM) > M1SlipToleranceM);` | **détection de glissement de câble M1** |
| `:266-267` | `IF M1SlipDetected THEN M1SlipFaultLatched := TRUE;` | latch |
| `:269` | `instCauses[3].Active := M1SlipFaultLatched;` | **→ `Fault` → `SevereError`** (bit 3 = 8) |

**Chaîne du défaut** : `BusyEdge` (`:494`) est keyé sur
`(CloseReq OR OpenReq) AND MotionRequestActive` **sans `NOT Lifecycle.Busy`** ⇒ chaque
relâchement/repompage du joystick en pleine manœuvre **recapture `M1RefPosM`** à la position M1
courante ⇒ **la détection de glissement M1 est re-baselinée par un simple geste opérateur**.

⇒ Un glissement réel de câble M1 (dérive, patinage du treuil) **ne déclenchera jamais** la cause 3
tant que l'opérateur pompe le joystick assez souvent. **C'est une défaite de détection de sécurité**,
et elle est **plus grave** que les coupures parasites — tout en ayant **exactement la même cause
racine** que D1 (la clause `NOT Lifecycle.Busy` manquante).

| Conséquence pour T346 | |
|---|---|
| Corriger `BusyEdge` | **NON optionnel**, et **indépendant** du choix d'ancrage Q1 : c'est un correctif de sécurité à faire dans tous les cas |
| `M1RefPosM` | **DOIT être conservée** — elle est **vivante** (`:265`), contrairement aux 6 autres |
| Contrat | **AC12** ajouté (glissement M1 réel détecté malgré le pompage) ; **AC13** (les 6 purgées, celle-ci conservée) |

⚠️ À rapprocher de `AF_Partie-10 §8` **alerte 6** (perte de la détection d'état contradictoire) :
**deux** filets de sécurité ont été affaiblis sans arbitrage tracé. **Signalé, non corrigé au-delà
du strict périmètre T346.**

---

## 3. Le nettoyage est plus incomplet que le brief ne le dit : **6 variables mortes, pas 1**

### 3.1 Chaîne morte issue du commit `2a307b5b` — 4 variables

| Variable | Déclaration | Écrite | Lue |
|---|---|---|---|
| `LeftStartSinceArm` | `:130` | `:501`, `:561` | **jamais** |
| `M2StartPosM` | `:127` | `:498` | `:560` **uniquement** ⇒ alimente la variable morte ⇒ **chaîne morte** |
| `WasOpenAtStart` | `:128` | `:499` | **jamais** |
| `WasClosedAtStart` | `:129` | `:500` | **jamais** |

### 3.2 🔴 Découverte supplémentaire — 2 variables mortes **hors** `2a307b5b`

Mesure systématique (voir §3.3), puis **contre-vérification par grep sur l'intégralité de `CODE/`** :
seule la ligne de **déclaration** apparaît — **aucune autre occurrence, nulle part**.

| Variable | Déclaration | Constat |
|---|---|---|
| `BandLatchConcord` | `:115` | déclarée « État latché ET bande mesurée concordent → offset benne fiable », **jamais utilisée** |
| `StateOffsetM` | `:116` | déclarée « Offset issu de l'**ÉTAT LATCHÉ seul** (référence du **filet §5a**, indépendant du recalage) », **jamais utilisée** |

⚠️ **`StateOffsetM` est le plus préoccupant** : sa déclaration désigne explicitement une **référence
de filet de sécurité (§5a)**. Ce filet a donc été **retiré sans que sa référence ne soit nettoyée**.
Les deux sont **indépendantes** de `2a307b5b` → **remontées séparément** (T339 les aurait classées
« tests obsolètes » alors que le code mort est bien réel).

Ces 6 champs sont dans un bloc `VAR` **local** (`:89` → `:144`) : aucune lecture externe possible.

### 3.3 Mesure du garde-fou — et pourquoi il n'est pas trivial

Balayage des **261 fichiers `.st` de `CODE/`** (commentaires et cibles d'écriture retirés, lignes de
déclaration exclues) :

| Résultat | Valeur |
|---|---|
| Fichiers analysés | 261 |
| Fichiers avec ≥1 variable locale écrite et jamais lue | **~10** |
| Occurrences candidates | **~70** |

**⚠️ MAIS le chiffre brut est trompeur — majorité de FAUX POSITIFS** : une `VAR` locale de
**PROGRAM** est lisible depuis l'extérieur (`PRG_XX.Var`). Preuve :
`CODE/M_MAIN/PRG_02_Acquisition.st:285` lit `PRG_06_Outputs.M1RelayFwd`, et
`CODE/M_MAIN/PRG_04_Treuils_Benne.st:1684` lit `PRG_06_Outputs.instWinchOutputInterlockM1` —
tous deux comptés « morts » par une analyse fichier-local. Le gros du volume vient de
`PRG_06_Outputs.st` (≈50 candidats), pour cette seule raison.

⇒ **Une gate bloquante « tout `CODE/` » serait ROUGE sur des sites hors périmètre T346.**
Et « une exemption de gate ou une allowlist n'est **jamais** une décision d'agent » (préambule projet)
⇒ **l'arbitrage du périmètre remonte à l'orchestrateur** (voir §6, **Q4**).

**Aucune gate ne couvre ce cas aujourd'hui.** Vérifié par grep :
`G200` traite les POU/instances orphelins (`G200_check_linkage.py:410`), `G490` les liaisons IHM
(`:299`, `:354`), `G512` les **arguments nommés morts** de test (`G512_check_dead_ci_test_arguments.py`,
livré par T339). **Aucun détecteur « variable locale écrite et jamais lue » n'existe** → c'est le
livrable `guard:` qu'impose la règle projet `fix:` + `guard:`.

---

## 4. Réponse aux questions de challenge du brief (§5)

### 4.1 Base de test rouge→vert : **OUI**, `TC-P10-029.1` est la base exacte

`TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_bucket.st:551-635`.
Le scénario est **déjà écrit** et couvre précisément le cas :

| Scan | Entrées | Assertion | État |
|---|---|---|---|
| 2 | `CmdClose_IHM`, `ReqAscent`, `CablePosM2 := 0.0` | `Lifecycle.Busy` | vert |
| 3 | idem, `CablePosM2 := 1.0` (> départ ⇒ armement) | `Lifecycle.Busy` | vert |
| 4 | `ReqDescend` (recul), `CablePosM2 := 1.0` | `M2_ReqDescend`, `M2_RunRequest` | vert |
| 5 | `CablePosM2 := 0.5` (recul **pas** encore à la borne) | `M2_RunRequest` **TRUE** | vert |
| 6 | `CablePosM2 := 0.0` (recul **à** la borne) | `M2_RunRequest` **FALSE**, `M2_ReqDescend` FALSE, `Busy` FALSE, `Done` TRUE | ⛔ **ROUGE** |
| 6b | recopie d'état | `IsOpen` **TRUE**, `IsClosed` FALSE (restauration) | ⛔ **ROUGE** |

⚠️ **Deux réserves sur la réutilisation telle quelle** (à trancher, voir §6) :
1. Le scan 6b assère la **restauration d'état** (`BucketState.IsOpen := WasOpenAtStart`) — c'est
   précisément `D5`, défaut qu'on ne veut **pas** réintroduire. Cette assertion devra être
   **remplacée**, pas satisfaite.
2. Le scénario **ne teste pas `D1`** (aucun pompage joystick) : il faut **ajouter** un cas qui
   prouve que `M2StartPosM`/la borne **ne bouge pas** quand l'opérateur relâche et represse.
   Sans ce cas, on ne prouve pas la non-régression du défaut d'origine.

### 4.2 `HoldAscentP1AfterClose` (AX10B) dépend-il implicitement de l'absence de borne ? **NON — prouvé**

`:514-519` :
```st
ELSIF Lifecycle.Busy AND CloseReached AND HoldAscentP1AfterClose THEN
    M2_BucketJogLimit := TRUE;
    M2_RunRequest := MotionRequestActive AND ReqAscent AND EffectivePermitBucket_Close;
    M2_ReqAscent := M2_RunRequest;
    M2_ReqDescend := FALSE;                       // ⬅️ le recul est FORCÉ À ZÉRO
```
Cette branche **ne peut émettre qu'une montée** (`ReqAscent`) et **force le recul à `FALSE`**.
Une borne **directionnelle** (qui n'inhibe que le recul) est donc **orthogonalement sans effet**
sur AX10B. ✅ Aucune dépendance cachée dans ce sens.

→ **Contrainte de conception qui en découle (nouvelle, non présente dans le brief)** : la borne
**doit être directionnelle** — elle ne doit **jamais** inhiber le sens *vers la cible*, sous peine
de casser la fermeture/ouverture nominale et AX10B.

### 4.3 Vérification des verrous (§6 du brief) : ⚠️ **le brief est FAUX sur un point**

`DOC/WFLOW/TASK_LOCKS.json` — état vérifié 2026-09-20T22:34 :

| Verrou | Acteur | `FB_Bucket.st` | `test_fb_bucket.st` | Lecture |
|---|---|---|---|---|
| **T295** | DSH08 | **dans le périmètre d'ÉCRITURE** (`:66`) | dans le périmètre (`:66`) | fichier **propre** sur disque ⇒ travail commité + revu CC01 (`TASKS.yaml:1341`) ⇒ verrou **périmé en pratique** mais **formellement posé** |
| **T339** | DSH11 (⏳) | INTERDIT (lecture seule) | **dans le périmètre d'ÉCRITURE** | ⚠️ **`test_fb_bucket.st` est MODIFIÉ NON COMMITÉ** (`git status`) |
| **T331** | DSH09 | INTERDIT | — | ok |

🚨 **Collision d'écriture RÉELLE sur `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_bucket.st`** :
T339/DSH11 est **en cours** (`⏳`) et détient ce fichier, **avec des modifications non commitées**.
Le brief affirme « pas de collision d'écriture » ⇒ **à corriger : il y en a une**, sur le fichier de
test exact dont T346 a besoin. **Arbitrage orchestrateur requis** (attendre T339, ou périmètre
séquencé). `FB_Bucket.st` lui-même est **libre** (T295 commité/revu).

---

## 5. Contradiction de doctrine à trancher — **la piste du brief heurte un REX documenté**

Le brief (§4) suggère de réutiliser `CloseAnticipationM` comme marge. **Vérification faite : c'est
possible, MAIS le projet a déjà explicitement refusé cette base dans un cas voisin.**

`CODE/M_MAIN/PRG_04_Treuils_Benne.st:761-766` (doctrine T248, écrite noir sur blanc) :
> « Phase JOG du séquencement benne-auto couplé … : borne alignée sur la frontière
> **RÉELLE** IsClosed/IsOpen (**`CoherenceLimitM`**, même seuil que `FB_Bucket`),
> **jamais sur l'anticipation** — sans mouvement pour « coaster » le reste du trajet,
> **une coupure à l'anticipation laisse un trou permanent** avant l'état franc. »

Et ce n'est pas qu'un commentaire : **le code l'applique** (`:774-788`, formule identique à la
frontière réelle) :

| Sens | Borne « anticipation » | Borne « frontière réelle » (doctrine T248) |
|---|---|---|
| Descente M2 | `M1 + OffsetOpenM + OpenAnticipationM` (`:776`) | `M1 + OffsetOpenM + CoherenceLimitM` (`:777`) |
| Montée M2 | `M1 + OffsetCloseM − CloseAnticipationM` (`:787`) | `M1 + OffsetCloseM − CoherenceLimitM` (`:788`) |

⇒ **Il existe déjà, en production, une borne de recul M2 à marge** — mais elle est **optionnelle** :
gardée par `ManualBucketLimitsActive` (`:756-758`), un toggle IHM (`TglManualBucketLimits`)
**désactivé par défaut**.

### 5.1 Conséquence : deux doctrines d'ancrage possibles, non équivalentes

| | **Ancrage (a) — position de DÉPART** | **Ancrage (b) — frontière RÉELLE opposée** |
|---|---|---|
| Formule | `M2StartPosM ∓ marge` | fermeture : `Δ >= OffsetOpenM + marge` · ouverture : `Δ <= OffsetCloseM − marge` |
| Sémantique | « une manœuvre qui recule jusqu'à son point de départ a échoué ⇒ on s'arrête » | « M2 ne peut pas franchir la frontière d'état OPPOSÉE » |
| Nature de l'ancre | **arbitraire** (dépend de quand l'opérateur a appuyé) | **physique et absolue** (`BucketState.IsOpen/IsClosed`) |
| Sensible à D1 | **oui** (même figée, elle reste liée au geste) | **non** — totalement insensible au pompage joystick |
| Précédent projet | code retiré `2a307b5b` (le défaut) | **`PRG_04:774-788`** (doctrine T248 validée) |
| Constante | nouvelle, ou détournement de `CloseAnticipationM`/`OpenAnticipationM` (**contre la doctrine**) | **`CoherenceLimitM` + offsets existants — zéro constante nouvelle** |

**Recommandation de l'agent : (b)**, pour 4 raisons vérifiables :
1. elle **supprime `D1` par construction** (aucune référence au geste) — une hystérésis sur (a)
   ne le ferait pas ;
2. elle **n'invente aucun chiffre** (§4 du brief) : `CoherenceLimitM` existe, est documentée
   (`AF-10:307` : `CoherenceLimitM=1.0` en production) et a un **précédent d'usage identique** ;
3. elle suit la doctrine projet **écrite** et non l'inverse ;
4. elle reste **directionnelle** (§4.2) et donc sans effet sur AX10B.

⚠️ **Point de vigilance honnête sur (b)** : en valeurs de production (`OffsetOpenM=0.0`,
`CoherenceLimitM=1.0`, `AF-10:307`), une manœuvre de fermeture démarrée dans la bande « ouverte »
(`Δ ≈ 1,0`) serait **immédiatement** à la borne ⇒ recul interdit d'emblée. C'est **correct
physiquement** (on ne recule pas quand on est déjà au bout de l'ouverture) mais **change le
comportement observable** et **impacte `TC-P10-029`** (actuellement VERT, qui exerce un recul à
`Δ=0.0` avec `CoherenceLimitM := 5.0`). **À arbitrer** — voir §6, question Q2.

---

## 6. ⏸️ ARRÊT — 3 arbitrages humains requis avant toute ligne de code

### Q1 — Quelle doctrine d'ancrage ?
- **(b) frontière réelle opposée + `CoherenceLimitM`** — recommandé (voir §5.1).
- **(a) position de départ + marge figée** — plus proche du brief, mais l'ancre reste liée au geste.

### Q2 — Comportement quand la borne mord (le brief n'en parle pas)
- **A** : coupe M2, `CloseReq` reste armé ⇒ **repart dès que l'opérateur repousse vers la cible** (geste continu, zéro verrou) — recommandé.
- **B** : coupe + fin de manœuvre propre (`Done := TRUE`) **sans toucher `BucketState`**, reprise par nouvel appui IHM.
- **C** : coupe + **diagnostic nommé**.
  ⚠️ Contrainte vérifiée : tout slot `instCauses[]` alimente `FB_FaultCore` (`:294-295` → `:414`),
  donc ⇒ `SevereError` + **Reset** si latché. Le seul précédent non-latchant est `instCauses[4]`
  (`:277-279`) — mais ça reste un **défaut machine**. Si vous voulez « borne atteinte =
  signalement », il faut une **`VAR_OUTPUT` dédiée** (précédent : `M2_BucketJogLimit`, exposée
  `PRG_04:1749`), **pas** un slot `instCauses`.

### Q3 — Collision d'écriture avec T339 sur `test_fb_bucket.st`
Séquencer (attendre la clôture T339), ou autoriser T346 à éditer uniquement le **bloc
`TC-P10-029.1`** en cohabitation ? Le brief affirme l'absence de collision : **c'est inexact**.

### Q4 — Périmètre du garde-fou « variable locale écrite et jamais lue » (voir §3.3)
Le garde-fou est **bloquant sur tout `CODE/`** ⇒ rouge sur ≈70 sites dans ~10 fichiers, dont une
majorité de faux positifs (PROGRAM). Ou : **limité aux fichiers du lot** / **détection des références
croisées `PRG_XX.Var`** / **mode avertissement non bloquant** ?
⚠️ Le choix **ne peut pas** être tranché par un agent (interdiction des allowlists côté agent).

---

## 7. Critères d'acceptation proposés (base du contrat `TASK_CONTRACT_T346_*.yaml`)

| # | Critère testable | Preuve |
|---|---|---|
| AC1 | `TC-P10-029.1` **ROUGE avant / VERT après** sur l'assertion d'**arrêt du recul** | CI `test_fb_bucket.st:626-629` |
| AC2 | **`D1` non réintroduit** : un relâchement/repompage joystick en pleine manœuvre **ne déplace pas** la borne ⇒ **pas de coupe** ; test neuf, **échoue sous mutation** (réintroduction de la recapture) | test neuf |
| AC3 | **`D3` non réintroduit** : aucune coupe pour un bagotement de ±1 incrément **à l'intérieur** de la marge | test neuf |
| AC4 | **`D4` non réintroduit** : après coupe, la commande **reprend** sans réappui IHM (si Q2=A) — ou `Done` propre `BucketState` **intact** (si Q2=B) | test neuf |
| AC5 | **`D5` non réintroduit** : la coupe **ne modifie ni** `BucketState.IsOpen` **ni** `IsClosed` | test neuf |
| AC6 | La borne est **directionnelle** : le sens *vers la cible* reste **toujours** commandé (non-régression `TC-P10-023/024`, AX10B `TC-P10-046.x`) | CI existante + test neuf |
| AC7 | `TC-P10-029` (recul = sens inverse sous permis opposé) **reste VERT** — ou son jeu de données est explicitement requalifié avec justification | CI existante |
| AC8 | Les **6** variables mortes (§3.1 + §3.2) sont **purgées ou réutilisées** — **zéro variable à moitié morte** | grep `CODE/` |
| AC9 | **Garde-fou** (règle `fix:` + `guard:`) : gate « variable locale écrite et jamais lue » + `--selftest` + branchement PLANS palier C — **périmètre à arbitrer (Q4)** | `run_all_gates.py` |
| AC10 | `AF_Partie-10 … FB_Bucket_v1.0.md:415` §8 alerte 5 **close**, `:139`/`:288`/`:326` réalignés | diff doc |
| AC11 | Bundle + diff bundle + `G200 --report` PASS + gates palier C (dettes préexistantes identifiées) | sortie gates |

---

## 8. Devoir d'alerte — éléments hors scope, remontés

1. **`PRG_04:787` : « la coupure à l'anticipation laisse un trou permanent »** — ce REX n'est tracé
   que **dans un commentaire de code**. Il mériterait une trace en documentation de conception :
   c'est la justification d'un choix qui vient d'être re-découvert 3 mois plus tard.
2. **Le verrou T295 est formellement posé alors que son lot est commité + revu CC01**
   (`TASKS.yaml:1341-1345`) ⇒ verrou périmé à nettoyer (décision **humaine**, non faite ici).
3. **Zéro gate sur les variables locales mortes** (§3) alors que **6** existent dans **un seul** FB.
   Le lot T341 a purgé `T330PrevSlowdownTopM` « à la main », sur revue humaine — non mécanisable
   aujourd'hui ⇒ confirme l'utilité du garde-fou AC9, **à condition d'arbitrer son périmètre (Q4)**.
4. **`D2`/`D4` sont des défauts de *forme* réutilisables** : le motif « coupe qui remet à FALSE un
   latch dont dépend le seul chemin de réarmement » peut exister ailleurs. **Hors scope T346**
   → remonté, non corrigé.
5. 🔴 **`StateOffsetM` (`:116`) désigne une « référence du filet §5a » qui n'existe plus.** Un
   **filet de sécurité** a disparu sans nettoyage de sa référence, et sans trace d'arbitrage.
   **Hors scope T346** (indépendant de `2a307b5b`) → remonté, non corrigé. À rapprocher de
   `AF_Partie-10 §8` **alerte 6** (perte de la détection d'état contradictoire, également escaladée).
6. ⚠️ **Anomalie d'horodatage** : l'entrée T346 de `TASKS.yaml` porte `date: 2026-09-20T23:10:00+02:00`
   alors que l'horloge système au moment de ma prise était `2026-09-20T22:36:25+02:00` — soit un
   **timestamp ~34 min dans le futur**. J'ai posé `locked_at`/`updated_at` à l'heure **réelle**.
   À vérifier côté orchestrateur (dérive d'horloge ou valeur estimée).
7. ⚠️ **`FB_Bucket.st` est édité par plusieurs lots successifs sans relecture consolidée** : T295
   (timeout), T339 (constats), T346 (borne). Les 6 variables mortes en sont le symptôme direct.
   **Suggestion hors scope** : une revue de cohérence globale du FB après clôture des 3 lots.

---

## 9. État du lot T346

| Étape | État |
|---|---|
| 1. Diagnostic prouvé | ✅ **livré** (cette fiche) — 6 défauts `D1`→`D6` |
| 2. Plan technique | ✅ **livré** : `DOC/WFLOW/CONTRACTS/PLAN_T346_BORNE_RECUL.md` — 2 variantes avec le **code exact**, plan de test 7 cas, garde-fou — ⏸️ **en attente Q1/Q2/Q3/Q4** |
| 3. Validation humaine | ⏸️ **BLOQUANT** |
| 4. Contrat `TASK_CONTRACT_T346_BORNE_RECUL.yaml` | ✅ **livré** — `check_task_contract.py` **PASS (0 erreur**, 1 avertissement attendu : contrat facultatif en C1**)**, **13 critères AC1..AC13** |
| 5. `TASKS.yaml` | ✅ entrée T346 mise à jour (`agent: DSH13`, `contrat:`, `avancement:`) — YAML revalidé, 137 tâches |
| 6. `TASK_LOCKS.json` | ✅ verrou **T346 / DSH13** posé — JSON revalidé, 21 verrous |
| 7. Implémentation ST | ⏸️ non commencée (arrêt volontaire avant code) |
| 8. Tests rouge→vert + garde-fou | ⏸️ non commencé (périmètre garde-fou = **Q4**) |
| 9. Bundle + G200 + gates palier C | ⏸️ non commencé |
| 10. Clôture `AF-10 §8` alerte 5 | ⏸️ après validation (doc **en cours d'édition par T339**) |

**Aucun fichier `CODE/` modifié · aucun bundle généré · aucun commit.**
Fichiers écrits par T346 : cette fiche, `PLAN_T346_BORNE_RECUL.md`, le contrat,
`TASKS.yaml` (champs T346 uniquement), `TASK_LOCKS.json` (entrée T346 + `updated_at`).
