# 🧭 RAPPORT D'AUDIT — T183 · Preset codeur centre-plage : mise en conformité

> **Date** : 2026-08-30 · **Auteur** : Claude (orchestrateur) · **Statut** : 📋 Audit de cadrage — **aucune modification de code**
> **Complément de** : `DOC/WFLOW/TASKS.yaml` → T183 · `TROUBLESHOOTING_PresetCodeurHorsCentrePlage_20260830.md`
> **Specs cibles** : `AF_Partie-09_Fonction_Encoder_v2.4.md` (F09.08, TC-P09-070) · `AF_Partie-09_Fonction_Encoder/FB_Encoder_Homing_v1.2.md`
> **Criticité** : 🔴 sécurité mesure position treuils M1/M2 — voir §4 PRE-C (criticité à réconcilier)
> **Rôle de ce document** : figer le contexte, lever les ambiguïtés bloquantes, détailler les actions ordonnées pour rendre le code conforme à l'AF.

---

## 1 · Verdict en une page

| Question | Réponse |
|---|---|
| L'AF est-elle claire sur la règle cible ? | ✅ **Oui.** F09.08 (chapô v2.4 §5/§13 + sous-fiche v1.2 §4) définit sans ambiguïté : tout homing écrit `CentrePts = (PointsPerRev × MultiTurnRevsMax)/2` au codeur et grave `HomingRefRaw` dans le référentiel post-preset. |
| Le code est-il conforme ? | ❌ **Non.** `FB_Encoder_Homing.st:231` écrit `PresetValue := RawPos` (preset neutre, commit `73fa758d`). Divergence spec/code **ouverte et documentée** dans l'AF elle-même (v1.2 §7 alerte #1). |
| Peut-on coder tout de suite ? | ⛔ **Non.** 2 pré-requis bloquants non levés (§4) : validation matérielle du preset PDO Rx, et spec du gel des consommateurs pendant la fenêtre de saut. |
| La correction est-elle un one-liner ? | ❌ **Non.** 6 actions code + 3 actions simu/CI + 3 actions doc, sur 6 fichiers, avec un ordre imposé (§6). |
| Contrat de tâche prêt ? | ❌ `TASK_CONTRACT_T183_ENCODER_CENTRE_PLAGE.yaml` **référencé dans TASKS.yaml mais absent du disque**. À créer (§4 PRE-D). |

**Enjeu** : un référencement effectué alors que le compteur brut est proche d'une borne (0 ou 2³² du codeur multitour) permet un **wrap-around en pleine manœuvre** → `CablePosM` aberrant (~±8192 m) → `EncoderIncoherent`, faux `HomingSuspect`, cascade `FB_SyncDeviation` / `FB_Bucket` / `FB_Safety_Winch`. Le centre-plage rend ce wrap **physiquement impossible** (course réelle ~1 % de la plage 25 bits).

---

## 2 · Contexte figé — état actuel vs cible

### 2.1 · Les 4 chemins de référencement (tous fautifs aujourd'hui)

| # | Chemin | Déclencheur | Cible (m) | `PresetValue` écrit | Garde bord | Gate fiabilité |
|---|---|---|---|---|---|---|
| 1 | Nominal capteur haut (M1+M2) | Front `Home` + front `M1M2_TopPositionFree_DI` | `CfgTopSensorPosM` (déf. 8.5) | `RawPos` ❌ | ❌ | n/a |
| 2 | Forcé zéro (mise en service) | `BtnHomingAtZero` | 0.0 | `RawPos` ❌ | ❌ | ❌ |
| 3 | Unitaire MAINT_N2 | `BtnHome` | `CfgHomingTargetM` (libre) | `RawPos` ❌ | ❌ | ❌ |
| 4 | **Dynamique benne M2 à chaud** | `BtnConfirmOpenPos` / `BtnConfirmClosePos` (`PRG_02_Acquisition.st:407-418`) | `CablePosM1` ± `OffsetCloseM` | `RawPos` ❌ | ❌ | ❌ **pire cas** |

Code commun fautif — `FB_Encoder_Homing.st:229-234` :

```st
TargetPoints        := REAL_TO_DINT(TargetPositionM * UDINT_TO_REAL(PointsPerRev) / CableM_PerRev);
PendingHomingRefRaw := DINT_TO_UDINT(UDINT_TO_DINT(RawPos) - TargetPoints);   // référentiel = position physique
PresetValue         := RawPos;                                                 // ← neutre : compteur reste où il est
PresetRequest       := TRUE;
PresetVerificationActive := TRUE;
```

### 2.2 · Les 3 couches de problème (rappel condensé du troubleshooting)

1. **Risque de bord** — aucun chemin ne contrôle la distance du compteur aux bornes. Wrap possible en manœuvre.
2. **Verrou preset devenu tautologique** — `FB_Encoder_Abs.st:141` teste `ABS(RawPos − PresetValueOut) ≤ PresetTolerancePts`. Avec le neutre, `PresetValueOut = RawPos` **par construction** → écart nul dès le 1ᵉʳ scan → `PresetCompleted` garanti **même si le codeur physique ignore l'ordre preset**. Le verrou ne prouve plus rien du matériel.
3. **Le design centre-plage d'origine (`26217dd9`) était lui-même incohérent** — il écrivait le centre au codeur mais calculait `HomingRefRaw` sur la position physique. S'il avait été réellement appliqué : saut `CablePosM` de ~8000 m. Le neutre est le **pansement** de ce bug, pas une régression isolée. → la correction doit traiter **les deux** : centre au codeur **ET** `HomingRefRaw` dans le référentiel post-preset.

### 2.3 · Cible AF (F09.08) — ce que le code doit faire

```st
CentrePts           := (PointsPerRev * MultiTurnRevsMax) / 2;    // 8192 × 4096 / 2 = 16 777 216 pts (16#1000000)
PresetValue         := CentrePts;                                // écrit au codeur (PDO Rx, séquence FB_Encoder_Abs)
PendingHomingRefRaw := CentrePts - TargetPoints;                 // référence DANS LE RÉFÉRENTIEL POST-PRESET
```

Cohérence de bout en bout après application : `RawPos → CentrePts` ⇒
`CandidateCablePosM = (CentrePts − (CentrePts − TargetPoints)) × k = TargetPositionM` ✓
→ le readback ±0.010 m de `FB_Encoder_Homing.st:246-252` **reste valide tel quel**, et devient un **vrai test matériel** (l'écart initial |position physique − centre| est quelconque, seul un chargement réel du centre par le codeur le résorbe).

Règles AF associées, non optionnelles :

- **Même politique M1 et M2**, systématiquement (v2.4 §5). *(N.B. ce n'est pas une fusion de config — `DECISION_ENCODER_CFG_OWNERSHIP` pt 3 interdit la fusion des cibles homing M1/M2, ici on parle d'une règle de comportement identique, pas d'un DUT partagé.)*
- **Cible dynamique benne M2** acceptée **uniquement si M1 est `HomedAndReliable`** — sinon homing refusé, `ErrorId` dédié (v2.4 §5, v1.2 TC-P09-070.3).
- **Fenêtre de saut** — entre l'ordre preset et sa prise en compte, `RawPos` transite de la position physique au centre. Pendant cette fenêtre les consommateurs de position (`FB_SyncDeviation`, `FB_Bucket`, interlocks hauteur M3) doivent **figer/ignorer** la mesure via `Measurement.HomingStatus.Busy` (v2.4 §13). Les protections du pipeline treuil restent actives (le homing exige déjà l'arrêt confirmé des treuils).
- **Aucun commit RETAIN avant readback confirmé** — `Calib.HomingRefRaw` / `Calib.Homed` ne sont écrits qu'après `PresetConfirmed` (déjà le cas, `FB_Encoder_Homing.st:263-270` — à préserver).

---

## 3 · Décisions déjà actées, applicables telles quelles

| Doc | Décision | Effet sur T183 |
|---|---|---|
| `DECISION_ENCODER_PRESET_TRANSACTION.md` | **Variante C** (visa humain 2026-08-27) — le preset est une transaction dont le succès conditionne le commit RETAIN, via readback (`PresetConfirmMode`) | Le squelette transactionnel T164-4C **est en place** et correct. T183 ne le refait pas — il corrige la **valeur** presettée et le **référentiel** de la référence. |
| `DECISION_ENCODER_CFG_OWNERSHIP.md` | `Calib` en `VAR_IN_OUT` (`_CalibM1`/`_CalibM2`), `PointsPerRev`/`CableM_PerRev`/`MultiTurnRevsMax` = constantes techniques, non éditables IHM | `CentrePts` se calcule à partir de constantes déjà câblées par la façade. **Aucun nouveau réglage IHM.** `MultiTurnRevsMax` (déf. 4096), aujourd'hui port mort, redevient utile. |

---

## 4 · Pré-requis bloquants — à lever AVANT toute écriture de code

### 🔴 PRE-A — Validation matérielle du preset PDO Rx

**Fait** : le verrou Abs tautologique (§2.2 pt 2) nous rend aveugles sur une question de fond : **le codeur absolu EtherCAT réel accepte-t-il `PresetTriggerCmd = 2` + `PresetValueOut` en PDO Rx, et applique-t-il réellement la valeur ?**

- Si **oui** → option centre-plage viable.
- Si **non** → `PresetNak` / readback en échec **systématique** après correction → **plus aucun homing possible**. C'est possiblement la raison de fond du passage au neutre (`73fa758d`) — jamais explicitée dans le commit.

**Action** : qualification sur le codeur physique (banc ou machine), documentée. Tant que non fait : **ne pas merger la correction ACT-1 sur une cible qui bougera en réel.**

### 🔴 PRE-B — Spécifier le *comment* du gel des consommateurs (fenêtre de saut)

L'AF dit **que** `FB_SyncDeviation` / `FB_Bucket` / interlocks doivent figer sur `HomingStatus.Busy`. Elle ne dit **pas** :

- valeur gelée = dernière valeur valide ? ou `PositionValid := FALSE` propagé ?
- durée max de la fenêtre + comportement si dépassement (la transaction a un timeout `PresetTimeout` côté Abs + `T#500MS` visuel — à relier) ;
- qui consomme `HomingStatus.Busy` exactement, et par quel chemin (`ST_EncoderMeasurements` AF06 §3ter ?).

**Action** : micro-spec (½ page) à ajouter au contrat T183 ou en annexe AF09 §13, validée humain, **avant** ACT-3/ACT-4.

### 🟠 PRE-C — Réconcilier la criticité

- `TASKS.yaml` T183 : **C3**
- `TROUBLESHOOTING_...20260830.md` : **C0** (sécurité mesure, tous chemins de référencement, cascade sécurité treuil)

Un écart de 3 crans change le niveau de gates, la revue et l'exigence de contrat. **Proposition : C1 minimum** (sécurité machine indirecte : mesure fausse → interlocks hauteur/benne faux → mouvement non maîtrisé). À trancher humain avant lock.

### 🟠 PRE-D — Créer le contrat de tâche

`TASK_CONTRACT_T183_ENCODER_CENTRE_PLAGE.yaml` est référencé mais absent. Gabarit : `TOOLS/AGENT_WORKFLOW/templates/task_contract.yaml`. Reprendre les objectifs testables de TASKS.yaml + critères §7 ci-dessous. Contrôle : `python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py`.

---

## 5 · Actions de mise en conformité

> Convention : `fix:` = correction · `guard:` = garde-fou automatique (règle AGENTS.md).
> État cible = conformité `AF_Partie-09 v2.4` + `FB_Encoder_Homing v1.2`.

### 🔧 Bloc CODE

| ID | Fichier · point | Action | Détail |
|---|---|---|---|
| **ACT-1** `fix:` | `CODE/E_CODEURS/FB_Encoder_Homing.st:229-234` | Centre-plage cohérent | `CentrePts := (PointsPerRev * MultiTurnRevsMax) / 2;` (UDINT, garde `MultiTurnRevsMax<>0`) · `PresetValue := CentrePts;` · `PendingHomingRefRaw := DINT_TO_UDINT(UDINT_TO_DINT(CentrePts) - TargetPoints);` · **supprimer** `PresetValue := RawPos`. Vérifier types : `PointsPerRev`/`MultiTurnRevsMax` = `UDINT` → produit possible overflow UDINT ? `8192 × 4096 = 33 554 432` < 2³² ✓, `/2 = 16 777 216` ✓. |
| **ACT-2** `fix:` | `FB_Encoder_Homing.st` interface + logique §4 · `PRG_02_Acquisition.st:428-438` | Gate M1 fiable sur cible dynamique M2 | **Option retenue (traçable)** : ajouter `VAR_INPUT DynamicTargetReliable : BOOL;` à `FB_Encoder_Homing`, câblé par la façade depuis `PRG_02` = `Data.M1_HomedAndReliable` (déjà publié `PRG_02_Acquisition.st:400`). Dans `FB_Encoder_Homing` : si `DynamicHomingTrigger AND NOT DynamicTargetReliable` → `ErrorId` bit libre (1-3/6-8, cf. v1.2 §6), **pas** d'écriture RETAIN, pas de `PresetRequest`. Rejet visible, pas un silence. |
| **ACT-3** `fix:` | `FB_Encoder_Homing.st:284` (région §6 sorties) | Publier la fenêtre de saut | `Lifecycle.Busy` est déjà = `PresetVerificationActive`. Exposer un signal dédié `HomingStatus.Busy` (ou réutiliser `Lifecycle.Busy`) **remonté jusqu'à `ST_EncoderMeasurements`** (AF06 §3ter) pour consommation aval. Dépend de **PRE-B**. |
| **ACT-4** `fix:` | `FB_SyncDeviation`, `FB_Bucket`, interlocks hauteur M3 | Figer sur fenêtre de saut | Selon micro-spec PRE-B : ignorer/geler `CablePosM` tant que `HomingStatus.Busy` (instance concernée). **Ne pas** basculer le treuil en référencement de sécurité (AF09 §13 : arrêt treuils déjà exigé). |
| **ACT-5** `fix:` | `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st:203-217` | Gate fiabilité sur forçage état benne | `ConfirmOpenEdge.Q` / `ConfirmCloseEdge.Q` : ajouter condition `HomedAndReliable` (M2) **ET** `NOT EncoderFault` avant d'écrire `BucketState.LastPosM2Open/Close := CablePosM2`. Sinon `StateIncoherent := TRUE`, pas de mémorisation. Aligne avec v1.2 TC-P09-070.3 (une référence ne se bâtit pas sur une mesure non fiable). ⚠️ arbitrer avec l'usage « sans codeur » documenté `ST_HomingChecklist.st:24` — si cet usage reste voulu, prévoir un chemin explicite gardé (bouton mise en service dédié), pas le chemin normal. |
| **ACT-6** `guard:` | `CODE/L_SIMULATION/FB_Sim_Encoder.st:111-116` | Wrap réel au lieu du clamp | Remplacer `IF RawPos >= Increment THEN RawPos := RawPos - Increment; ELSE RawPos := 0; END_IF;` par un enroulement modulo 2³² (`RawPos := RawPos - Increment;` en UDINT enroule nativement ; retirer le clamp à 0). Sans ça, TC-P09-070.2 est **intestable**. Coord. AF13 (`AF_Partie-13` v2.4). |
| **ACT-7** `guard:` | `CODE/GVL_PERSISTENT.st:148-149` | Départ simu près du centre | `_CalibM1/_CalibM2` ou l'init `FB_Sim_Encoder` : démarrer `RawPos` proche de `CentrePts` (16 777 216) et non ~1 M pts, pour que la simu reflète l'état post-homing réel. |

### 🧪 Bloc CI / TESTS

| ID | Cible | Action |
|---|---|---|
| **ACT-8** `guard:` | `TOOLS/TEST_AUTO_CI/RESULTS/E_CODEURS/tests/test_fb_encoder.st` | Ajouter **TC-P09-070.1** (preset centre : `RawPos=40 000` → `PresetValue=16 777 216`, readback `CablePosM = cible ±0.010 m`, `Homed=TRUE`, `PresetValueOut ≠ position physique`). |
| **ACT-9** `guard:` | idem (nécessite ACT-6) | **TC-P09-070.2** — descente course complète (~20 m) + remontée depuis le centre → compteur reste dans `[CentrePts − 0.5M ; CentrePts + 0.5M]`, **aucun** `EncoderIncoherent`, **aucun** faux `HomingSuspect` au boot suivant. |
| **ACT-10** `guard:` | idem | **TC-P09-070.3** — M1 non `HomedAndReliable` + demande réf. dynamique M2 → `ErrorId` bit dédié, **aucune** écriture RETAIN, **aucun** `PresetRequest`. |
| **ACT-11** | `test_fb_encoder.st:33-193` (série TC-P09-01x) | **Re-vérifier non-régression** : avec le centre-plage, l'écart initial `|RawPos − PresetValueOut|` n'est plus nul → les TC de readback/timeout doivent toujours passer (le stub simu doit appliquer le preset — vérifier le harnais). |

### 📄 Bloc DOCUMENTATION

| ID | Cible | Action |
|---|---|---|
| **ACT-12** | `AF_Partie-09_Fonction_Encoder_v2.4.md` + `AF_Partie-09_Fonction_Encoder/FB_Encoder_Homing_v1.2.md` | **Committer** (aujourd'hui non versionnés). Passer les états TC de `NV` → `V-I` au fur et à mesure de l'implémentation. |
| **ACT-13** | `DOC/VERSION_HISTORY.md` | Ligne jalon : « T183 — restauration garde anti-dépassement codeur (preset centre-plage F09.08), AF09 v2.3→v2.4 ». |
| **ACT-14** | `CODE/E_CODEURS/FB_Encoder_Homing.st` en-tête + `ST_HomingChecklist.st` | Commentaire invariant anti-régression (« ne jamais réintroduire `PresetValue := RawPos` — cf. `73fa758d` / troubleshooting 20260830 »). MAJ note usage forçage benne si ACT-5 change la procédure. |
| **ACT-15** `guard:` | `TOOLS/AGENT_WORKFLOW/scripts/` (nouveau gate G4xx) | Gate mécanique : refuser tout `PresetValue :=` dans `FB_Encoder_Homing.st` qui ne soit pas `CentrePts` / une expression centre-plage (grep ciblé + AST léger). Règle `fix:`+`guard:` de l'incident. |

---

## 6 · Séquencement recommandé

```text
PRE-C (criticité)  ─┐
PRE-D (contrat)     ─┼─► [plan technique validé humain]  ← arrêt obligatoire AGENTS.md
PRE-B (spec gel)   ─┘
                         │
PRE-A (valid. HW) ──────►│  (peut avancer en //, bloquant AVANT merge réel)
                         ▼
   ACT-6 + ACT-7  (simu wrap + départ centre)     ← rend les TC possibles
                         ▼
   ACT-1  (centre-plage cohérent)                 ← cœur du fix
                         ▼
   ACT-2  (gate M1 dynamique + ErrorId)
                         ▼
   ACT-11 (non-régression TC-P09-01x)  ─► ACT-8/9/10 (nouveaux TC)
                         ▼
   PRE-B validée ─► ACT-3 (publier Busy) ─► ACT-4 (figer consommateurs)
                         ▼
   ACT-5  (gate forçage benne)                     ← arbitrage usage « sans codeur »
                         ▼
   ACT-12..15 (docs + gate G4xx)
                         ▼
   Bundle + G200 + gates palier (C1/C0 selon PRE-C)  ─► restitution
```

**Checkpoint git** après ACT-1+ACT-2 (`wip(codeur): preset centre-plage cohérent [NON TESTE]`), puis après CI verte (`test(codeur): ...`). Aucun commit sans validation humaine.

---

## 7 · Critères d'acceptation consolidés

Repris de `TASKS.yaml` T183 + complétés :

1. ✅ Tout homing (nominal, unitaire, forcé zéro, dynamique benne) écrit `CentrePts` au codeur et grave `HomingRefRaw` dans le **même référentiel** (post-preset).
2. ✅ Readback ±0.010 m vérifie le chargement **réel** du centre — le verrou n'est plus tautologique (écart initial non nul démontré en test).
3. ✅ Descente course complète + remontée depuis le centre : **aucun** wrap, **aucun** `EncoderIncoherent`, **aucun** faux `HomingSuspect` (TC-P09-070.2, simu wrap réelle).
4. ✅ Cible dynamique benne M2 **refusée** avec `ErrorId` dédié si M1 non `HomedAndReliable` (TC-P09-070.3) — rejet visible, pas silencieux.
5. ✅ Forçage état benne (`FB_Bucket`) ne mémorise plus de position issue d'une mesure non fiable (ACT-5) — ou chemin « sans codeur » explicitement gardé.
6. ✅ Consommateurs de position figés pendant la fenêtre de saut (selon micro-spec PRE-B).
7. ✅ Pas de régression CI AF-09 / AF-10 ; `G200` + bundle + gates du palier (selon PRE-C) **PASS**.
8. ✅ Gate G4xx anti-réintroduction du preset neutre en place.
9. ✅ AF09 v2.4 + sous-fiche v1.2 committées, états TC à jour, `VERSION_HISTORY` renseigné.
10. ✅ PRE-A tranchée et consignée **avant** exécution sur matériel réel.

---

## 8 · Risques & points de vigilance

| Risque | Impact | Parade |
|---|---|---|
| Le codeur réel n'applique pas le preset (PRE-A = non) | Plus aucun homing possible après merge | Ne pas merger sans PRE-A ; sinon basculer sur **Option B** du troubleshooting §8 (neutre + garde anti-bord `marge ≤ RawPos ≤ plage−marge`) — pansement, mais réversible |
| ACT-1 mergé sans ACT-3/ACT-4 | `FB_SyncDeviation` / `FB_Bucket` voient `CablePosM` aberrant pendant la fenêtre de saut → faux défaut à chaque homing | Ordre §6 strict : Busy publié + consommateurs figés **avant** de considérer ACT-1 « fini » |
| ACT-6 (wrap simu) change le comportement d'autres TC simu | Régression CI AF-13 | Lancer la suite AF-13 complète après ACT-6, isoler l'impact |
| `MultiTurnRevsMax` mal câblé par la façade (port mort réactivé) | `CentrePts` faux → tout décalé | Vérifier `FB_Encoder.st` transmet bien `MultiTurnRevsMax` (déf. 4096) à `instHoming` ; TC dédié sur la valeur de `CentrePts` |
| Usage « forçage benne sans codeur » (mise en service) cassé par ACT-5 | Procédure terrain bloquée | Arbitrage humain PRE-B/PRE-D : garder un chemin dédié gardé, pas le chemin normal |
| Criticité sous-évaluée (C3) | Revue/gates insuffisants pour un défaut sécurité mesure | PRE-C avant lock |

---

## 9 · Annexe — preuves référencées (vérifiables)

| Localisation | Contenu |
|---|---|
| `CODE/E_CODEURS/FB_Encoder_Homing.st:229-234` | Formule preset neutre actuelle (`PresetValue := RawPos`) |
| `CODE/E_CODEURS/FB_Encoder_Homing.st:246-252` | Readback T164-4C — cohérent neutre, **reste valide** avec centre-plage cohérent |
| `CODE/E_CODEURS/FB_Encoder_Homing.st:263-278` | Commit RETAIN post-`PresetConfirmed` — à préserver tel quel |
| `CODE/E_CODEURS/FB_Encoder_Abs.st:140-148` | Séquence preset — `ABS(RawDiff) ≤ PresetTolerancePts` : tautologique en neutre |
| `CODE/E_CODEURS/FB_Encoder_Homing.st` interface | `MultiTurnRevsMax` déclaré, **non utilisé** aujourd'hui (port mort à réactiver) |
| `CODE/M_MAIN/PRG_02_Acquisition.st:400` | `Data.M1_HomedAndReliable` publié — source de la gate ACT-2 |
| `CODE/M_MAIN/PRG_02_Acquisition.st:407-438` | Référencement dynamique M2 benne, `UseDynamicTarget := M2BucketRefRequested` sans gate fiabilité |
| `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st:203-217` | Forçage état benne + mémorisation `LastPosM2Open/Close` sans gate |
| `CODE/L_SIMULATION/FB_Sim_Encoder.st:106,111-116` | Applique le preset, **clampe à 0** au lieu d'enrouler |
| `CODE/GVL_PERSISTENT.st:148-149` | Départ simu ~1 M pts (3 % de la plage) |
| `git show 26217dd9:CODE/E_CODEURS/FB_Encoder_Homing.st` | Centre-plage d'origine + référence physique (incohérence §2.2 pt 3) |
| `git show 73fa758d -- CODE/E_CODEURS/FB_Encoder_Homing.st` | Bascule vers le neutre |
| `DOC/WFLOW/CONTRACTS/DECISION_ENCODER_PRESET_TRANSACTION.md` | Variante C actée — transaction readback |
| `DOC/WFLOW/CONTRACTS/DECISION_ENCODER_CFG_OWNERSHIP.md` | `Calib` IN_OUT, constantes non IHM |
| `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_PresetCodeurHorsCentrePlage_20260830.md` | Diagnostic complet (scénarios wrap, options A/B/C, chronologie git) |

---

## 10 · Suivi

- [ ] PRE-C tranchée (criticité) → MAJ `TASKS.yaml`
- [ ] PRE-D : `TASK_CONTRACT_T183_ENCODER_CENTRE_PLAGE.yaml` créé + `check_task_contract.py` PASS
- [ ] PRE-B : micro-spec gel consommateurs validée humain
- [ ] PRE-A : qualification matérielle preset PDO Rx consignée
- [ ] Plan technique détaillé validé humain (arrêt AGENTS.md avant code)
- [ ] ACT-1..15 exécutées dans l'ordre §6
- [ ] Bundle + G200 + gates palier PASS → restitution avec bandeaux de conformité
