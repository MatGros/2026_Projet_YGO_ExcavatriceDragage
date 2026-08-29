# B2 — Résultat du 3ᵉ challenge (plan T181 v0.1)

> Produit par un subagent Claude (general-purpose, accès dépôt) le 2026-08-29.
> Périmètre lu : `PLAN_GEL_TREUIL_T181_v0.1.md`, `T181_TASKS_YAML_BLOCK.yaml`, `subagent_preamble.md`,
> `FB_Winch.st`, `FB_SpeedStep.st`, `FB_Safety_Winch.st`, `FB_WinchOutputInterlock.st`, `FB_DiveSearch.st`,
> `FB_ExtractionSequence.st`, `PRG_04` intégral, extraits `PRG_03`/`PRG_06`, entrées `TASKS.yaml`
> T169/T169-A/T175/T176/T177/T178/T180, contrats présents. Aucune écriture.

---

## Écarts sécurité repérés en passant (devoir d'alerte)

| # | Fait avéré | Emplacement | Traité par T181 ? |
|---|---|---|---|
| S1 | **Aucun interlock de cadence dans la barrière finale.** `FB_WinchOutputInterlock` ne fait que `AuthorizedStep := RequestedStepClamped` — le `StepDelay` TON est câblé `IN := FALSE` partout, il est mort. Il n'existe rien côté `PRG_06` à « prouver FALSE ». T181-01 ne *fiabilise* pas un filet existant, il l'**invente**. | `FB_WinchOutputInterlock.st:213,219,227,233,243,246` | Oui mais sous-estimé |
| S2 | **Garde-fou survitesse totalement neutralisé** : `MeasuredSpeedBand := 0` en dur + `SpeedGuardEnableM1/M2 := FALSE` (init VAR, jamais TRUE). Bloc §6 de `FB_Winch` (l.264-269) = code mort. | `PRG_04:682,718` ; `FB_Winch.st:264-269` | D06 → T181-16 Phase B — reste mort pendant Phases 0/0b/A/C et pendant les 1ᵉʳˢ essais site |
| S3 | **Bypass du temps mort directionnel au redémarrage à chaud.** Le gate remet `CommandedDirection := 0` sans réinitialiser `FirstScanDone` ; au retour d'`Enable`, la branche « neutre→sens = immédiat » (`FB_Winch.st:211`) s'applique → relais immédiat sans délai. La barrière finale ne rattrape pas (`DeadTimePending := FALSE` au gate, `FB_WinchOutputInterlock.st:102`). Hot-restart charge en mouvement = inversion/inrush sans temps mort nulle part. | `FB_Winch.st:141-168,211` ; `FB_WinchOutputInterlock.st:97-116` | **Non** — pas d'entrée D01-D17 correspondante |
| S4 | `SpeedGuardReady := NOT instWinchSync.Fault.Error` : « vitesse validée stable » câblée sur l'absence de défaut synchro. Sémantiquement faux, deviendra actif quand T181-16 arme le garde. | `PRG_04:684,720` | Non listé |
| S5 | `WinchM1FinalInterlockRequest.SafeStop` n'entre pas dans le calcul de `AuthorizedStep`/relais de `FB_WinchOutputInterlock` (commentaire l.119-121 : coupe seulement après retombée effective à zéro). Volontaire, mais la barrière finale ne réagit pas à un `SafeStop` amont tant que la demande métier ne retombe pas seule. | `FB_WinchOutputInterlock.st:118-122` | Hors périmètre — à confirmer humain |

---

## 1 · Phasage — « corrections C4 à interface inchangée » : la digue fuit

3 des 5 corrections Phase 0/0b touchent déjà l'interface :

| Défaut | Correction | Interface ? | Preuve |
|---|---|---|---|
| D02 (TC-011) | logique pure | Non — vrai fix interne. Le `SEL` l.248 est logiquement correct aujourd'hui (nom lu « à l'envers » ≠ bug). Vrai FAIL peut-être dans la chaîne `CommandedDirection` 1ᵉʳ scan. | `FB_Winch.st:248,273-282` |
| D07 (StuckClosed→Safety) | retrait `ContactorsCheck.StuckClosed` | **Oui, sémantique de sortie.** `ContactorsCheck` publié `PRG_04:803,860 → WinchMxState`, consommé IHM/Troubleshooting. | `FB_Winch.st:72,123,292-298` |
| D09 (retrait `Mode`) — T181-05 | suppression `VAR_INPUT Mode` | **Oui.** `Mode` = `VAR_INPUT` (`FB_Winch.st:18`), appelant passe `Mode :=` (`PRG_04:671,702`). « extraction interne uniquement » est faux. | `FB_Winch.st:18` ; `PRG_04:671,702` |
| D01 — T181-01 | `FB_WinchRateInterlock` dans `FB_Winch` avec seuils | **Oui, sauf seuils en dur.** Aucune entrée de seuil de cadence aujourd'hui → nouvelle `VAR_INPUT`/`Config` en Phase 0 = 1ʳᵉ cassure d'interface avant la refonte struct = 2 cassures successives. | `FB_Winch.st:11-52` |

**Correctif** : Phase 0 = « interface en réduction / additive contrôlée uniquement, 2 sites `PRG_04` au même commit », pas « inchangée ».

### T181-08 = big-bang résiduel

Empile au même commit : 3 DUT + réinterfaçage `FB_Winch` + 2 sites `PRG_04` + `FB_SimBench` + `test_fb_winch` + assertion shadow. « 2 sites d'appel » honnête sur les **entrées** ; les lectures de sorties (~40 accès `PRG_04:740-903` + `FB_WinchSync` + `MovementCommanded`) ne bougent pas si seules les entrées passent en struct. **Mais** 08 bundle la sémantique clamp unifié + `MinStepNumber` → l'assertion « ancien == nouveau sur 100 % des vecteurs » **ne peut pas tenir** dès que 12/13 injectent un plancher.

**Correctif** : scinder 08 → **08a** (plomberie struct pure, bit-identique, shadow-equal, `MinStepNumber` câblé = 1 partout) + **08b** (bascule calcul clamp → agrégateur `PRG_04`, fin du shadow).

### `bloque_par` — dépendances cachées

| Arête manquante | Fait |
|---|---|
| T181-00 → T169-A | T169-A existe (`TASKS.yaml:2474`, ⏳, AGY-01, contrat présent) et modifie **le même** `FB_Main_EndToEnd`. T181-00 est `bloque_par: []`. |
| T181-01 → T175 | T175 (⏳ C4, `bloque_par: []`, déléguée) porte AC2 temps mort TC-021/022, scope `CODE/H_TREUILS_BENNE/**`. |
| T181-05 → PRG_04 | 05 édite `PRG_04` (retrait `Mode :=`) mais scope affiché « extraction interne ». |

---

## 2 · Shadow comparison

| Question | Réponse |
|---|---|
| Coût CPU MainTask 10 ms | Négligeable (MIN/MAX/SEL sur INT + LIMIT, <1 µs). Pas le sujet. |
| N cycles avant bascule | **Non spécifié** → critère non mesurable. Doit être « 100 % des vecteurs T181-00, chacun rejoué jusqu'à stabilisation », pas un compteur. |
| Écart après bascule → rollback runtime ? | **Il n'y en a pas.** Application manuelle ⇒ « rollback runtime » = mot creux. Reformuler : « point de retour = tag Git + procédure de ré-import documentée » + garder l'ancien calcul en shadow inactif jusqu'à fin Phase A. |
| Shadow masque-t-il les vecteurs jamais exercés ? | **Oui, trou central.** Oracle « nouveau == ancien » : (a) faux comme objectif là où 10/12/13 changent volontairement le résultat ; (b) aveugle hors des vecteurs du harnais neuf « mince » ; (c) l'ancien calcul est **connu buggé** (D05/D08/D13) → prouver l'égalité à un référentiel faux ne prouve rien. |

**Correctif** : oracle shadow = « égalité SAUF cas plancher/précédence active, comparés à un attendu écrit à la main ». Fermer le shadow **avant** T181-10.

---

## 3 · Preuve `FinalInterlockGoverned = FALSE` sans HIL

- Le mécanisme comparé n'existe pas (S1) → on **crée** `FB_WinchRateInterlock` + 2 instances + mémoire d'état dans la barrière = surface de test accrue sur le composant le plus critique.
- Critère 1 (« FALSE sur 100 % des vecteurs nominaux ») **circulaire** : vecteurs définis par le même harnais T181-00 neuf.
- Critère 3 (injection en stubant `FB_Winch`) **réaliste en STruCpp** pour l'instance `PRG_06` isolée (TC unitaire honnête).
- Ce qu'un TC STruCpp ne prouvera jamais : priorité temporelle réelle (interne avant barrière), capteur `MeasuredSpeedBand`, frein/contacteurs/coast-down, **indépendance** des 2 instances (config partagée corrompue → redondance nulle).

**Manques bloquants pour signer** : indépendance des 2 jeux de seuils (sources distinctes, zéro variable partagée) ; non-bypassabilité de l'instance interne par `GVL_IHM.M1TreuilRetenue.Bypass.Global` (`PRG_04:695`) ; argument PL/SIL documenté ; critère site chiffré (cadence 1→5 chronométrée, barrière ne mord pas). **Écrire que la signature sécurité exige l'essai site — la CI ne la délivre pas.**

---

## 4 · Interconnexion — trous résiduels

### 4.1 Flux `MinStepDescent` — prémisse « 3 POU / 3 tâches » fausse
`PRG_02…07` s'exécutent **séquentiellement dans la même MainTask 10 ms**. `FB_DiveSearch` instancié dans `PRG_03` (`PRG_03:30,103`). `FB_DiveSearch → PRG_03.Data.ReqProgram → PRG_04` = **intra-cycle, zéro latence**. Réel : lags 1 scan documentés sur croisements `PRG_04` internes (`PRG_04:208-209,215-216`). Front de sortie plongée : `DescendPermit`/`KoboldMeasureEnable` retombent le même cycle gatés sur `DescentActive` ; si `MinStepDescent` gaté pareil → retombe proprement. Risque résiduel : maintien descente joystick post-fond → `KoboldBottomTouchLatched` force `ProcessPermitM1_Descend = FALSE` (`PRG_04:504`) → `StartStop` coupé → plancher inopérant. **Correctif** : corriger la justification (« gating sur `DescentActive`, TC front + TC maintien descente post-fond »).

### 4.2 Continuité gestuelle plancher discret 3-4
Trade-off assumé (décision Q). Sur-course benne : 2-3 s aux paliers 1-2 = ~0,3-0,9 m câble. Effleurement accidentel → descente parasite 2-3 s, s'annule au relâcher. Vraie régression ergo : plus de dosage « creep » d'une descente lente prolongée. À tracer AF-04 (T181-13) comme limitation connue + critère « relâche → palier 0 au cycle suivant ».

### 4.3 Override benne (`instBucket.Busy`) — tranche proposée (à inscrire dans le contrat T181-06)

| Élément | Où | Justification |
|---|---|---|
| Sélection producteur M2 (benne/joystick/cycle) + `Direction` benne | **Reste `PRG_04` §3**, branche `IF instBucket.Busy` écrit `DriveRequest.{StartStop,Direction}` de M2 | Règle d'or : arbitrage reste §3, jamais dans `FB_Winch` |
| Le `15.0` magique (`PRG_04:288`) | → `DriveRequest.SpeedTgt_Pct := Config.BucketJogSpeedPct` | Zéro magic number dans la chaîne de consigne |
| `M2_ForceSlowSpeed` (→ `M2_BucketJogLimit`) | → **agrégateur clamp `PRG_04`, branche M2-only** (`MaxStep{Asc,Desc}:=1`) | Plafond, pas consigne ; M2 uniquement (challenge #2-A) |
| Swap table `PRG_04:405-429` (D13) | **Supprimée** si `MaxStepDescent:=1` suffit ; décision dans **T181-06 (arrêt humain)**, pas enterrée dans T181-10 | 2ᵉ mécanisme au même effet |

T181-06 `objectifs` ne cite pas `instBucket.Busy`, le `15.0`, ni D13 → **contrat à compléter avant lancement**.

---

## 5 · Réconciliation T175/T177/T178/T169/T180

| Point | Verdict |
|---|---|
| T169-A existe | ✅ (`TASKS.yaml:2474`, contrat `TASK_CONTRACT_T169-A_HARNESS_TESTS_CYCLES_CI.yaml`). Greffe réaliste sur le principe mais **T169-A ⏳ en cours (AGY-01)** sur le même fichier, T181-00 sans arête `bloque_par` → collision. **Correctif : `T181-00 bloque_par: [T169-A]`.** |
| T175 | Chevauchement **non résolu**. AC2 (temps mort) + T181-01 « partagent l'implémentation » sans séquençage. **Correctif : `T181-01 bloque_par: [T175]`.** AC3 = D04 (retirée ✅), AC4 dans T181-14 ✅. |
| T177 | ✅ Propre. `T181-16 bloque_par` inclut T177. |
| T178 | ✅ sur le principe. **Mais** T178 change l'armement vers `FwdRevSpeedFeedbackOff AND NOT BrakeFeedback` → T181-00 doit **modéler retour frein + contacteurs retombés** pour le croisement CAS-001 ; ses `objectifs` ne citent que `MeasuredSpeedBand`/position/`FinalInterlockGoverned`. **Modélisation harnais sous-spécifiée.** |
| T180 | Croisement CAS-001/012 listé ✅. |
| T130/T131/T135 (⏸️), T096 | « Supersédées » / « absorbée » mais **jamais clôturées** dans `TASKS.yaml`. Housekeeping : ❌ avec renvoi T181-06/07/13/15. |

---

## 6 · Sur / sous-découpage

| Action | Tâches | Raison |
|---|---|---|
| **SCINDER (prioritaire)** | T181-08 → 08a (plomberie struct, shadow-equal, `MinStep=1`) + 08b (bascule clamp → agrégateur, fin shadow) | Big-bang + oracle shadow contradictoire. **La** tâche-piège. |
| **SCINDER** | T181-14 → 14a (matrice bypass ~20 `Bypass*`) + 14b (override FDC N1 8,5 m + re-homing) | 4 scopes hétérogènes sous 1 C3 ; l'override FDC = géométrie sécurité à isoler |
| **DÉPLACER décision** | D13 : de T181-10 (codage) → T181-06 (cadrage, arrêt humain) | Une décision d'archi ne se tranche pas dans un ticket de code |
| **FUSIONNER** | T181-02 + T181-03 → « `FB_Winch` corrections C4 Phase 0 » | 2 micro-fix même fichier, même `bloque_par` |
| **FUSIONNER** | T181-18 + T181-19 → « Dette Phase D » | 2 petites tâches dette |
| **Critères non mesurables** | 08 « ≥ N cycles » (N indéfini) ; 00 « modèle physique minimal » (fidélité non chiffrée) ; 13 « acceptable pour l'opérateur » → « relâche → palier 0 au cycle N+1 » + « ΔStepNumber ≤ +1/cycle » | Critère sans moyen de vérif = creux (préambule projet) |

---

## 7 · Verdict

**Le plan v0.1 ne donne PAS encore « un winch qui fonctionne du premier coup ».** Il en est proche : structure saine (harnais d'abord, C4 d'abord, arrêts humains, réconciliation). Mais **le shadow comparison est mal spécifié**, la **digue « interface figée » fuit**, **T181-08 est un big-bang assumé** qui reproduira le REX `PRG_10_Outputs_LD`. Plus 2 angles morts sécurité (S1 : le filet n'existe pas, on l'invente ; S3 : temps mort bypassé au hot-restart).

### Changements structurants restants — priorisés

| # | Changement | Effort |
|---|---|---|
| 1 | **Scinder T181-08** en 08a/08b. Redéfinir l'oracle shadow = « égalité sauf cas plancher/précédence, comparés à un attendu écrit ». Fixer N = « 100 % vecteurs T181-00, chacun à convergence ». | M |
| 2 | **Requalifier Phase 0/0b** : « interface `FB_Winch` en réduction / additive contrôlée, 2 sites `PRG_04` au même commit ». Tracer D07 (sortie `ContactorsCheck`), D09 (retrait `VAR_INPUT Mode` → `PRG_04`), D01 (ajout `Config` seuils). | S |
| 3 | **Ajouter D18** : bypass du temps mort directionnel au redémarrage à chaud. Rattacher à T181-01 ou T181-05. Critère : hot-restart `Direction≠0` maintenu → temps mort appliqué par au moins un des 2 niveaux. | M |
| 4 | **Renforcer §5** : indépendance des 2 jeux de seuils, non-bypassabilité de l'instance interne par `Bypass.Global`, argument PLr, critère site chiffré. Écrire que la signature sécurité exige l'essai site. | S |
| 5 | **Corriger les arêtes `bloque_par`** : `T181-00 bloque_par:[T169-A]` ; `T181-01 bloque_par:[T175]`. Compléter le contrat **T181-06** : place de l'override `instBucket.Busy` (§3), `15.0` → config, décision D13 (arrêt humain). Étendre objectifs **T181-00** à la modélisation frein/contacteurs. | S |

### Faits / hypothèses / incertitudes
- **Faits** : S1-S5 (lecture code) ; T169-A existe ; exécution séquentielle mono-tâche PRG_02→07 ; `Mode`/`ContactorsCheck` = I/O publiques ; `StepDelay` barrière mort ; `SpeedGuardEnable`/`MeasuredSpeedBand` neutralisés.
- **Hypothèses** : le vrai FAIL TC-011 n'est pas dans le `SEL` l.248 mais dans la chaîne `CommandedDirection` 1ᵉʳ scan (à confirmer en lisant le TC). Coût CPU shadow négligeable (borné, non mesuré).
- **Incertitudes** : contenu exact des `.yaml` T181-01/-06 (lus par titre/objectifs) ; comportement réel `FB_WinchStepShaper` (non écrit) ; fidélité du « modèle physique minimal paire » ; existence d'un `Config` partagé cassant l'indépendance des 2 interlocks.
