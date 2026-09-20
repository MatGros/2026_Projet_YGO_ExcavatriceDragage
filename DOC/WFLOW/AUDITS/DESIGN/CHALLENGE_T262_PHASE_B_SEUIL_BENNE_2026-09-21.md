# 🔎 CHALLENGE T262 Phase B — Seuil `ExtractionStartOpening_Pct`

> 🔴 C4 · Agent `DSH16` · 2026-09-21 · **AUCUNE ligne de `CODE/` écrite à ce stade**
> (contrat obligatoire avant code, `AGENTS.md` §Contrat de tâche).
> Brief source : `DOC/WFLOW/CONTRACTS/BRIEF_T262_SEUIL_FERMETURE_BENNE.md`.
> Contrat proposé : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T262_PHASE_B_BUCKET_OPENING_THRESHOLD.yaml`.

---

## 🎯 Verdict synthétique

| # | Constat | Statut |
|---|---|---|
| 1 | La prémisse du brief (« c'est `Benne_IsRoughlyClosed` qui autorise réellement la transition ») est **fausse** : la porte AX10 est une **conjonction** avec `Benne_CloseReached`. | ❌ Brief à corriger |
| 2 | Câbler le % **uniquement** dans `Benne_IsRoughlyClosed` produit **zéro effet observable** sur toute la plage 0..50 %. Le champ resterait mort. | 🚨 Bloquant |
| 3 | La lecture littérale de AC3 (OR au niveau de la porte cycle) fait basculer M2 vers Both P1 **alors que M2 est encore en descente** (inversion de sens en charge) — ce que le plan T262 interdit lui-même. | 🚨 Bloquant |
| 4 | Un mapping %→m par **remplacement** de la tolérance 2,0 m est **non monotone** et détruit le plancher anti-blocage. | ❌ Écarté |
| 5 | Une formulation `MAX()` (plancher historique conservé) est monotone, **strictement identique à 0 %**, testable et mécaniquement sûre. | ✅ Recommandée (dérogation plan à acter) |

**Aucun code avant arbitrage humain des 3 décisions du §7.**

---

## 1. Ce qui a été vérifié sur le code réel

### 1.1 Le paramètre est bien un champ mort — mais il y a **3** occurrences, pas 2

Le brief annonce « aucune occurrence en dehors de sa déclaration et de son bornage ». Il en existe
une troisième, la **persistance** :

| Occurrence | Rôle |
|---|---|
| `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCfg.st:12` | Déclaration, `INT := 0`, commentaire « 0 = critère historique, consommé en phase B » |
| `CODE/M_MAIN/PRG_07_Supervision.st:239` | Bornage `LIMIT(0, …, 50)` |
| `CODE/GVL_PERSISTENT.st:130` | Valeur persistée `ExtractionStartOpening_Pct := 0` (pont `FB_CfgPersistBridge_CycleCfg`) |

Aucune **lecture** en logique de cycle/treuil — confirmation du diagnostic du brief sur le fond.

### 1.2 Chaîne d'impact complète (exigence « traçabilité d'impact »)

```text
FB_Bucket  ──publie──▶  PRG_04.Data.BucketCloseReached       (PRG_04:1764)
FB_Bucket  ──publie──▶  PRG_04.Data.BucketState.MechState    (PRG_04:1736)  .IsClosed
PRG_04     ──calcule──▶ Data.Benne_IsRoughlyClosed           (PRG_04:1789-1794, :1924)
        │
        ▼
PRG_03_Modes_Cycle  (PRG_03:246/248/249)  ──▶  FB_CycleSemiAuto (VAR_INPUT)
        │
        ▼
FB_CycleSemiAuto.st:1298  ── SEULE porte de sortie AX10 → AX10B  (aucune autre : zone 1274-1303)
```

Consommateur unique confirmé : `Benne_IsRoughlyClosed` n'est lu que par la porte AX10
(`FB_CycleSemiAuto.st:1298`). Aucun autre usage dans `CODE/`.

### 1.3 La porte de sortie AX10 est une **conjonction**

```st
// CODE/G_CYCLE/FB_CycleSemiAuto.st:1298
IF DeadmanArmed AND JoystickPull AND Benne_CloseReached AND (Benne_IsClosed OR Benne_IsRoughlyClosed) THEN
```

`Benne_CloseReached` est **obligatoire**. Or `CloseReached` n'est posé qu'en un seul endroit :

```st
// CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st:592, :598, :602
IF CablePosM2 >= (CablePosM1 + Config.OffsetCloseM - Config.CloseAnticipationM) THEN
    BucketState.IsClosed := TRUE;     // :598  état fermé FORCÉ, dans le MÊME scan
    CloseReq := FALSE;
    CloseReached := TRUE;             // :602
```

`CloseReached` est remis à FALSE uniquement sur la porte sécurité (`FB_Bucket.st:317`) ou sur
acceptation d'une nouvelle commande benne à l'arrêt (`FB_Bucket.st:484`, `:488`). En AX10, la
demande de fermeture programme remonte par `FB_BucketCmdArbitration.st:62-71` → `CmdClose_IHM`
→ donc `CloseReached` est bien ré-armé à neuf pour chaque cycle.

### 1.4 Table des seuils réels (valeurs persistées `GVL_PERSISTENT.st:66-70`, `:75`)

`OffsetOpenM = 0,0` · `OffsetCloseM = 15,0` · `CoherenceLimitM = ±1,0` · `CloseAnticipationM = 1,2`

| Signal | Condition en `Delta` | Ouverture équivalente (`BucketOpening_Pct`) |
|---|---|---|
| `IsClosed` (classification continue `FB_Bucket.st:421,425-426`) | `Delta ≥ 14,0 m` | **≤ 6,67 %** |
| `Benne_CloseReached` (anticipation `FB_Bucket.st:592`) | `Delta ≥ 13,8 m` | **≤ 8,00 %** |
| Tolérance matière 2,0 m (`PRG_04:1794`) | `Delta ≥ 13,0 m` | **≤ 13,33 %** |

Conversion déjà **produite par le projet**, aucune échelle nouvelle à inventer
(`FB_Bucket.st:669-681`) :

```text
BucketOpening_Pct = 100 × (OffsetCloseM − Delta) / (OffsetCloseM − OffsetOpenM)
0 % = fermée (Delta = OffsetCloseM) ; 100 % = ouverte (Delta = OffsetOpenM) ; NON bornée volontairement
```

---

## 2. 🚨 Constat n°2 — câbler le % dans `Benne_IsRoughlyClosed` seul = **aucun effet**

Preuve par la conjonction de `FB_CycleSemiAuto.st:1298` :

1. La porte exige `Benne_CloseReached`, donc `Delta ≥ 13,8 m` (ouverture ≤ 8,00 %).
2. `IsRoughlyClosed` ne peut être vrai, au mieux, qu'à `Delta ≥ 13,0 m`.
3. Élargir la tolérance (2,0 m → `p %` du débattement) abaisse le seuil de `IsRoughlyClosed`
   vers de plus grands `Delta`… **mais ne déplace pas `CloseReached`**, qui reste le terme
   contraignant à 13,8 m.
4. Au scan d'arrivée à 13,8 m, `FB_Bucket.st:598` force `IsClosed := TRUE` dans le **même scan** :
   le terme `(IsClosed OR IsRoughlyClosed)` est donc **déjà** vrai à l'instant où `CloseReached`
   bascule.

⇒ **Conclusion : pour toute valeur `ExtractionStartOpening_Pct` de 0 à 50, la transition
AX10→AX10B continue de se produire à 8,00 % d'ouverture.** Le champ resterait un champ mort —
le brief serait « livré » sans aucun effet machine. C'est exactement le livrable à ne pas produire.

Rôle réel de la tolérance 2,0 m (à ne pas casser, mais à ne pas surestimer) : après le scan
d'arrivée, la classification continue `FB_Bucket.st:425-445` rejette la mesure à 13,8 m hors de la
bande `±1,0 m` (`|13,8 − 15| = 1,2 > 1,0`) → `IsClosed` retombe. La tolérance 2,0 m est ce qui
**maintient la porte ouverte** sur les scans suivants (bande `Delta ∈ [13,0 ; 13,8[`) si le geste
n'était pas présent au scan exact. Élargir le % ne déplace donc **pas** l'instant de franchissement —
il élargit seulement la fenêtre de rattrapage.

---

## 3. 🚨 Constat n°3 — le « OU » littéral de AC3 est mécaniquement hazardous **en l'état**

`AC3` du contrat T262 (`TASK_CONTRACT_T262_AX10_CLOSE_BUCKET_THRESHOLD.yaml:22`) demande :
« préparer le transfert lorsque `BucketOpening_Pct` valide <= Cfg **OU** lorsque la fin de
fermeture historique est atteinte ». Appliqué tel quel à la porte `FB_CycleSemiAuto.st:1298`,
cela **retire `Benne_CloseReached` de la conjonction** dès que le seuil est franchi — donc
**pendant que M2 est encore en descente** (fermeture en cours, ouverture restante = Cfg %).

Or AX10B suppose explicitement l'inverse :

```st
// FB_CycleSemiAuto.st:1300
// M2 est deja maintenu a P1 par FB_Bucket ; AX10B prepare le transfert couple.
// FB_CycleSemiAuto.st:1322
BucketCmd.ReqHoldAscentP1AfterClose := DeadmanArmed AND JoystickPull AND NOT Ax10bFallbackStopActive;
```

et ce maintien n'existe **que** derrière `CloseReached` :

```st
// FB_Bucket.st:513-517
ELSIF Lifecycle.Busy AND CloseReached AND HoldAscentP1AfterClose THEN
    M2_BucketJogLimit := TRUE;
    M2_ReqAscent := M2_RunRequest;      // ← montée P1
```

Sans `CloseReached`, le FB reste dans la branche de fermeture (`FB_Bucket.st:519+`) : M2 reste en
**descente**, puis AX10B transfère M2 à Both P1 **en montée** → **inversion de sens de M2 sous
charge**, frein/contacteurs pilotés au pire moment. Le plan T262 l'interdit explicitement
(`PLAN_T262_TRANSFERT_AX10_AX11_20260915.md:244-250`) :

> « En nominal, M2 conserve le sens montée et le frein ouvert ; aucun passage forcé à zéro
> entre fermeture et P1 commun. »
> « Pré-aligner M2 à P1 avant l'intention Both ».
> « Ne jamais déclarer que la benne “finit de se fermer” pendant Both sans preuve terrain. »

Le même plan précise aussi que le transfert « **ne fabrique pas `IsClosed`** ni un `Done` de
fermeture complète » (`PLAN…:110-111`), et interdit de modifier l'anticipation et la tolérance
(`PLAN…:71-74`) : « Le nouveau seuil d'ouverture ne doit pas modifier `OffsetCloseM`, la bande de
cohérence, **l'anticipation de fermeture ou la tolérance matière** ; il ajoute seulement un critère
de préparation du transfert avant cette fin actuelle. »

⇒ Le « OU » de AC3 **suppose le lot plan T262 phases C/D complet** (`FB_Bucket` : sortie de
transfert distincte de `Done`, `ST_WinchInterPrg`, `ST_OutputsInterPrg`, `PRG_06`, cycle), pas un
câblage de 3 lignes. Il n'est pas livrable en « Phase B » sans conception dédiée du cas
« benne encore en fermeture pendant AX10B/AX11 ».

---

## 4. ❌ Mapping écarté : remplacement de la tolérance 2,0 m

Un mapping naïf « tolérance = `Cfg %` du débattement » donne `Cfg = 0` → `Delta ≥ 15,0 m`
(fermeture stricte), donc :

- à `0 %` le comportement **change** (contraire à `ST_CycleCfg.st:12`, `IHM_FREEZE_T262…:20`,
  `AC2` et à la non-régression exigée par le brief §5) ;
- `Cfg = 1 %` devient **plus strict** que `Cfg = 0 %` → **non monotone** ;
- le plancher anti-blocage matière dense disparaît.

Écarté sans ambiguïté.

---

## 5. ✅ Formulation recommandée — plancher historique conservé (`MAX`)

Une **seule** grandeur dérivée du seuil, réutilisée par les deux endroits qui la contraignent :

```text
DistancePartielle_M := (ExtractionStartOpening_Pct / 100) × (OffsetCloseM − OffsetOpenM)
   avec la plage VIVANTE (jamais 15,0 en dur : valeurs persistantes modifiables, plan:39-41)

AnticipationEff_M := MAX(Config.CloseAnticipationM, DistancePartielle_M)   // 0 % → 1,2 m : historique exact
ToleranceEff_M    := MAX(2,0 m,                   DistancePartielle_M)    // 0 % → 2,0 m : historique exact
```

Propriétés :

| Propriété | Démonstration |
|---|---|
| **0 % strictement identique** | Les deux `MAX` retournent exactement les constantes historiques → table de vérité exhaustive du FB de décision. |
| **Monotone** | `p` croissant ⇒ distance croissante ⇒ fermeture déclarée atteinte plus tôt (ouverture restante plus grande). Aucune discontinuité à `0 → 1`. |
| **Plancher anti-blocage préservé** | `MAX` : la contrainte historique ne peut jamais être resserrée par l'IHM. |
| **Pas de faux `IsClosed` nouveau** | Le transitoire « `IsClosed` forcé 1 scan » de `FB_Bucket.st:598` existe déjà aujourd'hui ; il est simplement déplacé à l'ouverture choisie. La classification continue (`:425-445`) reprend la main au scan suivant : `AX12` reste au **palier lent** tant que `IsClosed` est faux (`FB_CycleSemiAuto.st:1399-1402`, `AC10` conservé). |
| **Aucune inversion de sens M2** | `CloseReached` bascule normalement → branche `FB_Bucket.st:513-517` → M2 part en montée P1 : chaîne AX10B → AX11 → AX12 **inchangée**. |
| **Pas de deadlock AX10** | Le maintien de `CloseReached` + `ToleranceEff_M` couvre en permanence l'ouverture choisie : si le geste n'est pas présent au scan exact, la porte reste vraie aux scans suivants (rôle déjà joué par la tolérance 2,0 m aujourd'hui). Sans l'extension de tolérance, un arrêt partiel à 12,0 m (`Cfg = 20 %`) rendrait la porte **définitivement fausse** après le scan d'arrivée : blocage en AX10. |

Exemples avec la géométrie persistée actuelle (débattement 15,0 m) :

| `Cfg` | Distance dérivée | Ouverture de transition | Effet |
|---:|---:|---:|---|
| 0 | 1,2 m (histo.) | 8,00 % | **identique à aujourd'hui** |
| 0..8 | 1,2 m (plancher) | 8,00 % | inerte — l'IHM doit l'écrire |
| 20 | 3,0 m | 20,00 % | transition anticipée de 1,8 m de débattement |
| 50 | 7,5 m | 50,00 % | borne haute (max à valider humainement, `AC1`) |

**Dérogation à acter** : cette formulation touche l'anticipation de fermeture et la tolérance
matière, ce que `PLAN…:71-74` interdit. Elle n'est donc livrable **qu'avec un GO humain explicite
de dérogation**, tracé dans le plan et le contrat.

---

## 6. Testabilité — pourquoi un FB de décision dédié

Fait vérifié : `TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/FB_TestHarness_PRG_04.st` **ne contient pas le
corps de `PRG_04`** : il recâble une partie de la logique M1 pour tests unitaires. Aucune
modification inline de `PRG_04` ne peut donc produire un test unitaire rouge→vert réel — un test
qui recopierait l'expression testerait une **copie** (tautologique).

Solution retenue : extraire la décision dans un FB **pur** (sans état, sans timer) testable,
exactement le pattern déjà appliqué par T341 (`FB_CfgT330Normalizer` extrait de `PRG_07`,
`registry.yaml:1237-1244`). Le test devient un vrai rouge→vert : écrit contre l'interface du FB
avant qu'il existe, il échoue d'abord à la compilation.

Le FB ne produit **aucune** donnée existante : il ne fait que dériver la configuration. Les
producteurs restent uniques (`BucketOpening_Pct` reste produit par `FB_Bucket`).

---

## 7. ⏳ Décisions demandées (bloquantes)

| # | Décision | Options |
|---|---|---|
| **D1** | **Formulation du seuil** | **A (recommandée)** plancher `MAX`, anticipation + tolérance effectives — dérogation au plan `:71-74` requise · **B** lecture littérale AC3 (OR sur la porte cycle) → exige le lot plan C/D complet (sortie de transfert distincte de `Done`) et un essai banc avant tout code · **C** assumer que le champ reste inerte et le documenter (contredit la décision utilisateur `TASKS.yaml:3720-3722`) |
| **D2** | **Borne maximale 50 %** (`AC1` : « borne maximale à valider humainement ») | 50 % = 7,5 m d'ouverture au départ de la remontée. Confirmer, ou resserrer (le plan propose un essai machine à 10 %, `PLAN…:280`). |
| **D3** | **Périmètre du lot** | A minimal : `FB_Bucket.st` + `PRG_04.st` + 1 FB de décision + 1 gate `G515` + tests. Ajouter `FB_CycleSemiAuto.st` / `PRG_03` uniquement si D1 = B. |

---

## 8. ⚠️ Signalements hors scope (devoir d'alerte)

| # | Constat | Preuve | Action |
|---|---|---|---|
| S1 | `PLAN_T262…:55-62` documente une « condition exacte actuelle » avec `Benne_Done` — le code réel utilise `Benne_CloseReached` (`FB_CycleSemiAuto.st:1298`). La divergence est **justifiée et nécessaire** : en AX10, `HoldAscentP1AfterClose` est armé (`FB_CycleSemiAuto.st:1295`), donc `FB_Bucket.st:603-605` maintient `Lifecycle.Busy := TRUE` et ne pose **jamais** `Done := TRUE` — suivre le plan à la lettre **bloquerait AX10**. | `FB_CycleSemiAuto.st:1295,1298` · `FB_Bucket.st:603-611` | Plan T262 obsolète sur ce point : **à corriger par l'orchestrateur**, pas corrigé ici. |
| S2 | Commentaire de `ClassCanRun` inexact : `FB_Bucket.st:113` décrit « tout arrêté + référence + hors homing », le code réel (`FB_Bucket.st:418-419`) est `HomedM1 AND HomedM2 AND NOT SevereError` (aucune condition d'arrêt). | `FB_Bucket.st:113` vs `:418-419` | Dette documentaire, hors scope. |
| S3 | L'ancien garde-fou T291-B `G499` (renommé `G505`) est **supprimé** dans le diff de travail non commité, et la voie de fait est antérieure à ce lot. | `git status --porcelain` → ligne ` D` sur `TOOLS/…/G499…py` | Signé à l'orchestrateur. **Aucune restauration, aucun déplacement, aucune suppression** de ma part. |
| S4 | `BucketOpening_Pct` retourne `0,0` quand la géométrie est invalide (`FB_Bucket.st:676-681`) **et** quand la porte sécurité est fermée (`FB_Bucket.st:297-308`). Un `opening ≤ Cfg` naïf autoriserait donc un transfert sur une mesure **invalide** — exigence `AC15` / `PLAN…:120-122`. | `FB_Bucket.st:308,676-681` | Traité dans la conception : branche seuil conditionnée par `instBucket.ActiveOffsetValid` (`FB_Bucket.st:771-775`) **et** `_BucketState.IsIntermediate`. Aucun prédicat nouveau inventé. |

---

## 9. État de la tâche à cet instant

| Élément | État |
|---|---|
| Lignes de `CODE/` écrites | **0** |
| Fichiers `CODE_XML/` régénérés | **0** |
| Commit | **aucun** |
| Verrou `T262` | pris sous tag `DSH16` (verrou précédent `CDX01`, `since 2026-09-19`, non usurpé) |
| Prochaine étape | arbitrage D1/D2/D3 → **ARBITRÉ le 2026-09-21 (cf. §10)** → code → tests → bundle → gates |

---

## 10. ✅ Décisions arbitrées par l'humain (2026-09-21)

| # | Décision retenue | Conséquence |
|---|---|---|
| **D1** | **A′** — et non A | L'humain a d'abord retenu A (dérogation au plan), puis a validé A′ sur instruction de la branche 2 de sa propre question. A′ livre le **même comportement machine** que A, mais par une **branche additive en OR** : les lignes historiques (`Delta ≥ OffsetCloseM − 2,0` dans PRG_04, `CablePosM2 ≥ CablePosM1 + OffsetCloseM − CloseAnticipationM` dans FB_Bucket) **restent intactes**. ⇒ **aucune dérogation** à `PLAN…:71-74` n'est nécessaire : le plan dit « ajoute seulement un critère », c'est littéralement ce qui est livré. |
| **D2** | **Borne maximale = 20 %** (resserrée depuis les 50 % du contrat parent) | Cohérent avec le mail GCAM et `IHM_FREEZE_T262…` (exemple 20 %). Ouverture de départ de la remontée plafonnée à **3,0 m** avec la géométrie persistée actuelle. ⇒ impact IHM à tracer : `PRG_07_Supervision.st:239`, commentaire `ST_CycleCfg.st:12`, `IHM_FREEZE_T262…` (plage 0..50 → 0..20). |
| **D3** | **Périmètre minimal** | `FB_BucketCloseThreshold` (nouveau), `FB_Bucket.st`, `PRG_04_Treuils_Benne.st`, G515 + PLANS, registry + tests. **`FB_CycleSemiAuto.st` et `PRG_03_Modes_Cycle.st` non touchés.** |

### Ce que A′ ne change PAS par rapport au constat du §2

Le levier reste **l'instant d'arrivée de fermeture** : quelle que soit la formulation, un critère qui
n'agit pas sur `CloseReached` est inerte. A′ ajoute donc **deux** branches en OR, jamais une seule :

```st
// FB_Bucket — arrivée de fermeture : branche AJOUTÉE, ligne historique intacte
IF CablePosM2 >= (CablePosM1 + Config.OffsetCloseM - Config.CloseAnticipationM)
   OR PartialCloseReached THEN

// PRG_04 — Benne_IsRoughlyClosed : branche AJOUTÉE, ligne historique intacte
Benne_IsRoughlyClosed := _BucketState.IsClosed
    OR (_BucketState.IsIntermediate AND (instBucket.DeltaPosition_M >= (_BucketCfgPersist.Config.OffsetCloseM - 2.0)))
    OR PartialCloseReached;
```

`PartialCloseReached` est **le même signal** aux deux endroits, produit par le FB de décision — donc
aucune duplication de critère, et `0 %` rend la branche inactive **par construction** (et non par un
`MAX` qui retombe sur la constante) : la preuve de non-régression est plus forte qu'en option A.

### Plage utile après D2

| Réglage `p` | Distance équivalente | Ouverture de transition | Effet |
|---:|---:|---:|---|
| 0 | 0,0 m (branche inactive) | 8,00 % | **historique strict** |
| 1..8 | 0,15 .. 1,20 m | 8,00 % | inerte (plancher d'anticipation 1,2 m) — **à écrire sur l'IHM** |
| 9..13 | 1,35 .. 1,95 m | p % | transition avancée ; la tolérance historique 2,0 m couvre encore la fenêtre de rattrapage |
| 14..20 | 2,10 .. 3,00 m | p % | transition avancée **et** branche de tolérance active (évite le blocage en AX10) |
