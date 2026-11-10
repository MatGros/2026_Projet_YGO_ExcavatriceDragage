# 📊 ANALYSE T361 — VOLET B : OPTIONS DE RECALAGE DE L'ESTIMATEUR DE POSITION M3

**Date** : 21 Septembre 2026 — 06:00
**Auteur** : DSH25 (ex-DSH23 — re-tag pour collision de tag avec le lot T345-L1) — Expert Senior Automatisme Industriel / Sécurité Machine / CI-CD
**Tâche** : T361 (parent T333) — volet B du brief `DOC/WFLOW/CONTRACTS/BRIEF_T361_SIMU_RATIO_M3.md`
**Ancrage** : HEAD `276fc11e` — `git status --short -- CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st` → **VIDE** (l'estimateur n'est pas touché ; zéro ligne de code de recalage écrite)
⚠️ `CODE/I_TRANSLATION/FB_Translation.st` — **autre fichier du même dossier** — est modifié NON COMMITÉ par un autre lot : sans rapport avec ce volet, signalé ici pour éviter toute confusion de lecture du `git status`.
**Statut** : 🔴 **ANALYSE SEULE — DÉCISION UTILISATEUR REQUISE AVANT TOUT CODE**

> ⛔ Ce document ne tranche rien. Il chiffre, compare et recommande. L'implémentation d'une option
> n'a pas commencé et ne commencera pas sans validation explicite de l'option retenue.

---

## 0. 🔄 Ce que le VOLET A change dans ce débat (à lire en premier)

Le brief justifie le volet B par « de gros sauts de recalage en simulation au passage capteur ».
**Ces sauts sont un artefact de banc, et le VOLET A les a supprimés.**

| Fait | Preuve |
|---|---|
| Les sauts de 4,53 / 9,12 / 4,59 m mesurés sur la trace venaient de l'écart d'échelle banc/estimateur (rapport 4,7), pas du recalage lui-même | `AUDIT_T360_TRACE_RATIO_ESTIMATEUR_M3_20260921.md` §3 ; ratio corrigé par T361 volet A (`FullTravelTimeS` 8,0 → 37,5 s) |
| Aucun saut de recalage n'a **jamais** été mesuré sur la machine réelle | la seule trace fournie est `Suivi_74_SIMU_MAINTN1_M3` — une trace de **simulation** |
| L'amplitude résiduelle réelle d'un saut = `ε × distance depuis le dernier repère`, avec `ε` = erreur résiduelle de gain | formule §2 ci-dessous |
| `ε` est aujourd'hui **INCONNU** : le gain 0,02 est explicitement provisoire | `CODE/GVL_PERSISTENT.st:109` — « valeur PROVISOIRE estimee 2026-09-21 (observation terrain), en attente calibration rigoureuse T301 (chrono + decametre) » |

➡️ **Conséquence** : après le volet A, l'argument « saut brutal » n'est plus porté par une mesure.
Ce qui reste à décider, c'est le **risque de dérive** et le **comportement en cas de capteur parasite** —
objet des §3 à §6.

---

## 1. 🎯 Fait fondateur : à quoi sert réellement la position estimée ?

Traçabilité producteur → routeur → consommateur (règle `CODE_QUALITY_STANDARDS §3ter`) :

| Étage | Site | Contenu |
|---|---|---|
| Producteur | `CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st:45` | `PositionEstimatedM` (odométrie + recalage capteurs) |
| Publication | `CODE/M_MAIN/PRG_05_Translation.st:710` | `TranslationState.EstimatedPosM3_M := instPosEstimatorM3.PositionEstimatedM` |
| Persistance | `CODE/M_MAIN/PRG_05_Translation.st:624-629` ↔ `CODE/GVL_PERSISTENT.st:111-112` | reprise après reboot |
| Restitution | `CODE/M_MAIN/PRG_07_Supervision.st:495` | `GVL_IHM.M3Translation.State := …TranslationState` → **IHM** |
| Consommateur PLC | **AUCUN** | `grep EstimatedPosM3_M` sur `CODE/` = **2 occurrences** : la déclaration `ST_TranslationState.st:50` et l'écriture `PRG_05_Translation.st:710` |

**Ce qui pilote la machine n'est PAS la position estimée, mais les capteurs discrets décodés** :

- `CODE/M_MAIN/PRG_03_Modes_Cycle.st:101` → `M3AtTremie := …TranslationState.LimitSwitchTremie`
- `CODE/M_MAIN/PRG_07_Supervision.st:764` → `M3AtTremieStable := …LimitSwitchTremie`
- `CODE/M_MAIN/PRG_02_Acquisition.st:238` → `…TranslationState.Busy`
- bits de position : `PRG_05_Translation.st:713-717` (mot thermomètre décodé), pas `EstimatedPosM3_M`

➡️ **Verdict factuel** : à HEAD, `EstimatedPosM3_M` est une **grandeur d'affichage/diagnostic IHM**.
Aucun interlock, aucune autorisation de mouvement, aucune étape de cycle ne la consomme.
Décider du recalage est donc **possible sans toucher à la sécurité machine** — mais une position
affichée fausse reste un **piège opérateur** (l'exploitant lit cette valeur pour situer le chariot).

---

## 2. 📐 Physique : la dérive n'est PAS proportionnelle au chemin parcouru

L'estimateur intègre `dx = sens × f × G_cfg × dt` (`FB_Translation_PositionEstimator.st:151-157`).
Si la machine parcourt réellement un déplacement **signé** `D` depuis le dernier repère absolu,
la position affichée vaut :

```text
x_est = x_ref + (G_cfg / G_reel) × D        →        erreur = ε × |D| ,  ε = G_cfg/G_reel − 1
```

**Trois conséquences non intuitives, et décisives pour le choix :**

1. Les allers-retours **n'accumulent pas** l'erreur : elle ne dépend que du déplacement signé
   depuis le dernier repère. Refaire 20 fois Trémie↔P1 ne dérive pas 20 fois.
2. La borne de dérive d'une option = `ε × (écart maximal entre deux repères absolus)`.
3. `LIMIT(−0,5 ; x_est ; 30,5)` (`FB_Translation_PositionEstimator.st:163`) borne la valeur
   affichée mais **ne corrige pas** l'erreur : au retour, l'estimation repart de la valeur bornée.

### Géométrie M3 et intervalles entre repères

| Repère | Position | Preuve | Écart au repère suivant |
|---|---|---|---|
| Trémie | 0,0 m | `GVL_PERSISTENT.st:104` / `FB_Sim_Translation.st:124` | 5,0 m |
| PV | 5,0 m | `GVL_PERSISTENT.st:105` / `FB_Sim_Translation.st:128` | **10,0 m** ⬅ écart max |
| P2 | 15,0 m | `GVL_PERSISTENT.st:106` / `FB_Sim_Translation.st:129` | 5,0 m |
| P1 | 20,0 m | `GVL_PERSISTENT.st:107` / `FB_Sim_Translation.st:130` | **10,0 m** ⬅ écart max |
| Maintenance | 30,0 m | `GVL_PERSISTENT.st:108` / `FB_Sim_Translation.st:131` | — |
| Course totale | 30,0 m | idem | — |

---

## 3. 📊 Tableau 1 — dérive maximale affichée, par option et par erreur de gain

`ε` = erreur résiduelle du gain odométrique après calibration T301.

| Option | Repères absolus | Déplacement max sans repère | ε = 1 % | ε = 2 % | ε = 5 % | ε = 10 % |
|---|---|:---:|:---:|:---:|:---:|:---:|
| **A — statu quo** (5 capteurs) | 0 / 5 / 15 / 20 / 30 m | **10,0 m** | 0,10 m | 0,20 m | 0,50 m | 1,00 m |
| **B — Trémie seul** (proposition utilisateur) | 0 m | **30,0 m** | 0,30 m | 0,60 m | **1,50 m** | **3,00 m** |
| **B′ — Trémie + Maintenance** (variante) | 0 / 30 m | **15,0 m** | 0,15 m | 0,30 m | 0,75 m | 1,50 m |
| **C — 5 capteurs + seuil `T`** | 0 / 5 / 15 / 20 / 30 m | 10,0 m | `max(T ; 0,10)` | `max(T ; 0,20)` | `max(T ; 0,50)` | `max(T ; 1,00)` |

**Lecture** : le passage de 5 repères à 1 seul **multiplie la dérive par 3** — exactement le facteur
annoncé dans le brief (10 m → 30 m). Le seuil de l'option C **n'aggrave pas** la borne tant que
`T ≤ 10 ε` (c'est-à-dire tant que `T ≤ 0,10 m` à 1 %), il **supprime les recalages inutiles**.

### Sensibilité : quel `ε` est réaliste aujourd'hui ?

| Question | Réponse chiffrée |
|---|---|
| Distance pour dériver de 10 cm à ε = 1 % | `0,10 / 0,01` = **10,0 m** (cohérent avec AUDIT T360 §5) |
| Dérive sur la course complète 0 → 30 m à ε = 1 % | **0,30 m** |
| Dérive si le gain provisoire 0,02 est faux de ±10 % | **1,00 m** en option A, **3,00 m** en option B |
| État de la calibration du gain | **NON FAITE** — `GVL_PERSISTENT.st:109` : valeur estimée par observation terrain, calibration T301 (chrono + décamètre) en attente |

⚠️ **Alerte** : tant que T301 n'a pas mesuré le gain, tout choix d'option se fait avec un `ε` **non borné**.
L'option B place 3,00 m d'erreur d'affichage possible sur une course de 30 m (10 %), sans aucun repère
intermédiaire pour la rattraper avant le retour à la Trémie.

---

## 4. 📊 Tableau 2 — comparaison multicritère

| Critère | A — 5 capteurs (actuel) | B — Trémie seul | C — 5 capteurs + seuil de plausibilité |
|---|---|---|---|
| Dérive max (ε = 2 %) | **0,20 m** | 0,60 m | 0,20 m (si `T ≤ 0,20`) |
| Nombre de repères absolus | 5 | 1 | 5 |
| Correction de l'erreur accumulée | à chaque capteur franchi | une fois par retour à la Trémie | à chaque capteur, si l'écart est significatif |
| Référence absolue au démarrage à froid hors Trémie | **acquise au 1er capteur vu** (`FB_Translation_PositionEstimator.st:139-146`) | **impossible avant la Trémie** — `Initialized` reste FALSE, l'odométrie pure tourne sans référence | acquise au 1er capteur vu |
| Effet d'un front parasite (rebond, blip T300) | recalage faux, **corrigé au capteur suivant** | recalage faux, **corrigé seulement au retour Trémie** | recalage **rejeté** si l'écart est implausible |
| Micro-sauts d'affichage (< seuil) | visibles à chaque franchissement | aucun entre deux retours Trémie | **supprimés** (bande morte) |
| Détection d'un capteur collé/HS | possible par recoupement des 5 mots (déjà en place : `FB_Translation_PositionDecoder.Incoherent`) | **aucun recoupement** | recoupement conservé |
| Visibilité du défaut pour l'exploitant | saut visible + `RecalibratedSensorId` (non publié) | dérive lente, **invisible** | saut évité, écart signalable |
| Complexité du changement | aucun code | suppression de 4 branches (`:115-130`) + revue de l'initialisation (`:139-146`) | ajout d'un seuil + d'une garde de plausibilité |
| Risque de régression | nul | **moyen** (perte de 4 références, démarrage à froid) | faible (branche additive) |
| Testabilité CI | déjà couverte | cas neufs à écrire | cas neufs à écrire |
| Réversibilité | — | oui (constante) | oui (seuil `T`) |

---

## 5. 🧩 Les options, en détail

### Option A — statu quo : recalage forcé sur les 5 capteurs (fronts montant **et** descendant)

- **Code actuel** : `FB_Translation_PositionEstimator.st:112-136` (5 branches `IF/ELSIF`, front montant
  **ou** descendant — correctif T333), initialisation `:139-146`, intégration `:151-157`.
- ✅ Borne de dérive la plus faible (10 m), **auto-correction** à chaque capteur, `Incoherent` du décodeur
  conserve un recoupement, référence absolue acquise au démarrage au premier capteur rencontré.
- ⚠️ Chaque franchissement produit un **saut visible** dans la trace et à l'IHM. Après le volet A, ce saut
  vaut `ε × 10 m` (cm, pas mètres) — c'est le comportement **attendu et sain** d'un repère absolu.
- ⚠️ Un front parasite force un recalage faux (rattrapé au capteur suivant).

### Option B — recalage forcé uniquement à la Trémie (proposition utilisateur)

- **Code à écrire (PAS écrit)** : ne conserver que la branche Trémie (`:131-135`), retirer les 4 autres.
- ✅ Zéro saut entre deux passages à la Trémie ; lecture de trace « lisse » ; plus simple.
- ❌ Dérive ×3 (§3) : jusqu'à **3,00 m** si le gain provisoire est faux de 10 %.
- ❌ **Perte de la référence absolue au démarrage à froid hors Trémie** : `Initialized` ne peut plus
  s'acquérir qu'à la Trémie (`:139-146`). Une machine garée en Maintenance démarrerait sur une
  odométrie pure sans référence, à partir de la valeur persistée (`GVL_PERSISTENT.st:111-112`).
- ❌ Perte du recoupement : un capteur Trémie collé/HS n'est plus détectable par les 5 mots.
- ❌ Un front parasite à la Trémie fausse la position **pour tout le trajet** (jusqu'à 30 m d'écart),
  au lieu d'être rattrapé au capteur suivant.
- ➡️ Cette option supprime le **symptôme le plus visible** mais **augmente le risque réel** : elle échange
  une erreur bornée et auto-corrigée contre une erreur 3× plus grande et rarement corrigée.

### Option B′ — variante : Trémie **+** Maintenance (2 repères fixes)

- Garde les deux extrémités physiques (là où la machine stationne naturellement) et supprime les 3 repères
  intermédiaires. Borne = 15 m → dérive 0,30 m à ε = 2 %, 1,50 m à ε = 10 %.
- ✅ Compromis : dérive ×1,5 seulement ; le repère de Maintenance est atteint à chaque cycle de
  maintenance, celui de Trémie à chaque cycle de chargement.
- ❌ Mêmes réserves résiduelles que B (recoupement réduit, initialisation limitée aux 2 extrémités).
- 🔎 **À considérer si — et seulement si — l'objectif réel est de supprimer les recalages « en cours de
  trajet » sans perdre les deux points physiques sûrs.**

### Option C — 5 capteurs **+ seuil de plausibilité** (3e option demandée par le brief)

Trois variantes, **cumulables** :

| Variante | Principe | Effet | Coût |
|---|---|---|---|
| **C1 — bande morte `T`** | ne recaler que si `|x_est − x_capteur| > T` (ex. T = 0,05 m) | supprime les micro-sauts et les recalages pour du bruit ; borne inchangée tant que `T ≤ 10 ε` | 1 comparaison dans chaque branche |
| **C2 — convergence bornée** | au lieu d'un saut instantané, ramener la position vers le repère à vitesse bornée (ex. 0,2 m/s) | plus de discontinuité d'affichage ; ⚠️ position fausse pendant la convergence, et **erreur figée** si l'arrêt/reboot survient avant la fin | machine à états + garde |
| **C3 — garde de plausibilité** | rejeter un recalage géométriquement impossible depuis le scan précédent (`|Δ| > v_max × dt + marge`) et le **signaler** | neutralise un front parasite isolé | 1 garde + 1 diagnostic |

- ✅ Conserve les 5 repères, la borne de 10 m, l'auto-correction et le recoupement.
- ✅ Traite la vraie nuisance (recalages inutiles, fronts parasites) **sans** dégrader la dérive.
- ⚠️ C2 est le seul point discutable : un repère absolu qui « converge » n'est plus un repère absolu.

---

## 6. 🧭 Recommandation (à valider, pas à appliquer)

> **Recommandation : A (statu quo) + C1 + C3. Écarter B. Considérer B′ uniquement comme repli si le besoin
> réel est « ne plus recaler en cours de trajet ».**

Justification chiffrée :

1. Le motif du volet B — les sauts de 4,5 à 9,1 m — est **déjà traité par le volet A** : c'était un écart
   d'échelle du banc (rapport 4,7), pas un défaut de recalage (§0).
2. L'option B **multiplie la dérive par 3** (§3) et **supprime l'acquisition de la référence absolue au
   démarrage à froid hors Trémie** (§5) — deux régressions fonctionnelles pour un gain esthétique.
3. Ce que le brief cherche vraiment à éviter (le saut brutal) se traite par **C1 + C3** : bande morte
   `T = 0,05 m` (≤ `10 ε` à 1 %, donc borne de dérive inchangée) et rejet des recalages impossibles.
4. `RecalibratedSensorId` (`FB_Translation_PositionEstimator.st:48`) n'est **publié nulle part** : aucun
   diagnostic ne permet aujourd'hui de savoir quel capteur a recalé. Le publier (IHM/diagnostic) serait
   le complément utile de l'option A — **hors périmètre de ce lot, à ouvrir en tâche séparée**.

### 🔴 Décisions demandées à l'utilisateur (aucune n'est prise ici)

| # | Décision | Options |
|---|---|---|
| **D1** | Option de recalage retenue | **A** (recommandé) · B · B′ · C |
| **D2** | Si C : valeur de la bande morte `T` et activation de C2 | `T` = 0 · 0,05 m · 0,10 m ; C2 oui/non |
| **D3** | Calibration du gain (T301) avant ou après ce lot | le gain 0,02 est **provisoire** (`GVL_PERSISTENT.st:109`) |
| **D4** | Faut-il publier `RecalibratedSensorId` (diagnostic du repère utilisé) ? | oui / non / tâche séparée |

---

## 6bis. ✅ DÉCISION UTILISATEUR DU 2026-09-21 (arbitrage rendu, enregistré ici)

| # | Question | Décision utilisateur |
|---|---|---|
| **D1** | Option de recalage | ✅ **OPTION A** — statu quo 5 capteurs **+ bande morte + garde de plausibilité**. Proposition initiale « Trémie seule » **ABANDONNÉE** (dérive ×3 à ×15 selon le gain réel, compromis jugé non rentable). |
| **D2** | Paramètres de la bande morte | à figer dans le lot d'implémentation (§6ter) |
| **D3** | Calibration du gain avant décision ? | ✅ **NON — décider maintenant, calibrer ensuite** (le comportement de recalage ne dépend pas de la valeur exacte du gain) |
| **D4** | Publier `RecalibratedSensorId` ? | non tranché |

➡️ Le volet B n'est donc plus une analyse : **il devient un lot d'implémentation** (§6ter).
⛔ Aucune ligne n'a encore été écrite : le code attend l'arbitrage de D2, pour les raisons du §6ter.

---

## 6ter. 🔴 DEUX CONSTATS BLOQUANTS APPARUS EN PRÉPARANT LE CODE (devoir d'alerte)

### (a) La « garde de plausibilité » telle que je l'ai écrite au §5 est FAUSSE — auto-challenge

J'ai écrit au §5 : *« rejeter un recalage géométriquement impossible depuis le scan précédent
(`|Δ| > v_max × dt + marge`) »*. **Cette formulation rejetterait TOUS les recalages utiles.**

Démonstration : un recalage n'a de sens que quand l'odométrie a dérivé. Sur un scan à 40 Hz et
0,02 m/(Hz·s), le déplacement maximal d'un scan vaut `40 × 0,02 × 0,010` = **0,008 m**. Une dérive
réelle au franchissement d'un capteur vaut `ε × 10 m`, soit 0,10 m à 1 % — **12 fois** le seuil
proposé. La garde aurait donc refusé exactement les corrections qu'on veut appliquer.

**Formulation corrigée — un COULOIR à deux bornes, pas un simple rejet :**

| Zone | Écart `|x_est − x_capteur|` | Comportement |
|---|---|---|
| Bruit | `≤ T` (bande morte) | **aucune correction** — l'écart est sous le bruit de capteur / la gigue / le retard électrique ; corriger n'ajouterait qu'une discontinuité |
| Nominal | `T < |Δ| ≤ M` | **correction appliquée** — c'est le recalage utile |
| Suspect | `> M` | **correction appliquée ET anomalie signalée** — le capteur reste la meilleure référence absolue disponible ; refuser la correction laisserait une position fausse *et* non corrigée. `M` sert à rendre l'anomalie VISIBLE (c'est exactement ce qui a manqué sur la trace Suivi_74 : les sauts de 9 m n'ont été vus qu'en post-mortem) |

Valeurs proposées, justifiées par la géométrie (§3) : **`T` = 0,05 m** (au-dessus du bruit/jigue
constatés) et **`M` = 0,50 m** = 5 % de l'écart maximal entre deux repères (10 m) → signale toute
erreur de gain dépassant 5 %, c'est-à-dire le niveau auquel le gain provisoire doit être remis en
cause.

### (b) Le volet B entre en CONFLIT avec une décision explicite du lot T333, verrouillée par un test CI

`TOOLS/TEST_AUTO_CI/RESULTS/I_TRANSLATION/tests/test_fb_translation_positionestimator.st:318-377`
(cas **TC-P11-EST-007**) porte, noir sur blanc, la décision **Q2** du lot T333 :

> « Re-calibrer **SANS gate** (le gate de plausibilité est inexploitable avant T301, le gain
> configure etant ÷6,6 trop lent) »

et le test **exige** qu'un blip de 2 cm soit recalé : `ASSERT_NEAR(PositionEstimatedM, 0.0, 0.005)`
après un écart de ~0,02 m. Avec `T` = 0,05 m, **ce cas de test passe au rouge** — et il faudrait
donc réécrire une décision prise il y a moins de 24 h par un autre lot.

📌 Les deux positions sont défendables, mais elles sont **incompatibles** : la bande morte dit
« ne corrige pas le bruit », la décision Q2 dit « corrige même 2 cm ». **C'est un arbitrage
utilisateur, pas une décision d'agent.**

### (c) 🔥 ALERTE MAJEURE — deux valeurs incompatibles du gain odométrique coexistent dans le dépôt

| Source | Valeur | Origine | Preuve |
|---|---|---|---|
| Valeur **de production** | **0,02 m/(Hz·s)** | observation terrain 2026-09-21, déclarée **provisoire** | `CODE/GVL_PERSISTENT.st:109` |
| Valeur **déduite de trace** | **0,0551 m/(Hz·s)** | audit T300 du 2026-09-04 (référence « R2-O1 ») | `DOC/WFLOW/AUDITS/DESIGN/AUDIT_T300_TRACE_20260904_v1.0.md:190` ; consommée par `test_fb_sim_translation.st:312` (`FullTravelTimeS := 13.6`) et citée par `TOOLS/TEST_AUTO_CI/RESULTS/I_TRANSLATION/tests/test_fb_translation_positionestimator.st:326` (« le gain configure etant ÷6,6 trop lent » : 0,008333 × 6,6 ≈ 0,055) |

**Conséquence chiffrée si 0,0551 est la vraie valeur** : l'estimateur ne compterait que
`0,02 / 0,0551` = **36 %** de la distance réelle. Sur les 10 m entre deux capteurs, l'écart au
franchissement vaudrait **6,4 m** — c'est-à-dire, sur la machine réelle, **le même saut de plusieurs
mètres que celui observé en simulation**. Le volet A rend le banc cohérent avec la valeur de
production ; il ne dit **pas** que cette valeur est juste.

➡️ Ce constat ne remet pas en cause la décision D3 (« calibrer ensuite ») : il la **rend urgente**.
Tant que la calibration T301 n'a pas tranché entre 0,02 et 0,0551, **aucune** des options du §4 ne
garantit des sauts de recalage centimétriques sur la machine réelle.

### (d) Impact sur les tests CI si le volet B est implémenté tel quel

| Cas de test existant | Effet d'une bande morte `T` = 0,05 m | Verdict |
|---|---|---|
| `TC-P11-EST-002` (recalage P1, écart 2,0 m) | `2,0 > 0,05` → correction appliquée | ✅ inchangé |
| `TC-P11-EST-004` / `-005` (5 capteurs, écart ~0,133 m après 40 scans) | `0,133 > 0,05` → correction appliquée | ✅ inchangé |
| `TC-P11-EST-006` (continuité hors front) | aucune correction hors front | ✅ inchangé |
| **`TC-P11-EST-007`** (blip Tremie, écart ~0,02 m) | `0,02 < 0,05` → **AUCUNE correction** → `Recalibrated` reste FALSE | ❌ **ROUGE** — réécriture de la décision Q2 requise |

---

## 6quater. ✅ DÉCISION FINALE (2026-09-21) ET IMPLÉMENTATION DU VOLET B

| Point | Décision utilisateur | Implémentation retenue |
|---|---|---|
| **Bande morte `T` = 0,05 m** | ❌ **RETIRÉE** — « retire la bande morte, garde uniquement le seuil d'anomalie » | **aucune**. La décision Q2 du lot T333 et son cas `TC-P11-EST-007` restent **intacts** : le conflit (b) est levé sans rien rouvrir |
| **Seuil d'anomalie `M` = 0,50 m** | ✅ **GO, simplifié** : « correction toujours appliquée, l'anomalie n'est qu'un signal, jamais un blocage » | `CST_RecalibrationAnomalyM` + `RecalibrationAnomaly` (pulse) + `RecalibrationCorrectionM` (amplitude maintenue) |
| **Calibration T301** | ✅ **priorité absolue** dès 5 minutes sur site — l'écart possible ×2,75 entre 0,02 et 0,0551 est trop grand pour continuer à deviner | alerte maintenue (§6ter-c) |

### Implémentation (fichiers et invariants)

| Élément | Site | Rôle |
|---|---|---|
| `CST_RecalibrationAnomalyM : REAL := 0.50` | `FB_Translation_PositionEstimator.st:91` | seuil = 5 % de l'écart max entre deux repères (10,0 m) |
| `PositionBeforeM` | `:76` (déclaration) / `:141` (capture) | mesure prise **AVANT** tout recalage du scan |
| Bloc `2bis` | `:168-181` | mesure la correction **réellement appliquée** et lève le témoin — **aucune affectation de position** |
| `RecalibrationAnomaly` (pulse) | `:53` | remis à zéro à chaque scan (`:100`, `:114`), comme `Recalibrated` |
| `RecalibrationCorrectionM` (hold) | `:57` | amplitude de la dernière correction, conservée entre deux recalages |

🔒 **Invariant du lot** : la chaîne de recalage (`:142-166`) est **inchangée** — 5 repères, correction inconditionnelle. Le seuil n'y entre jamais ; c'est ce que le gate **G520** interdit statiquement.

### Preuves CI

| Cas | Ce qu'il verrouille | Résultat |
|---|---|---|
| `TC-T361-ANOM-001` | correction nominale (~2 mm après 5 m d'odométrie) → témoin **non** levé | ✅ PASS |
| `TC-T361-ANOM-002` | correction de 10,0 m → **position RECALÉE quand même** + témoin levé | ✅ PASS |
| `TC-T361-ANOM-003` | témoin = **pulse**, amplitude **maintenue** | ✅ PASS |
| `TC-T361-ANOM-004` | blip de 2 cm recalé **sans** témoin → **aucune zone morte** (scénario Q2/T333 rejoué) | ✅ PASS |
| `TC-P11-EST-001/002/004/005/006/007` (T333) | non-régression, décision Q2 **intacte** | ✅ PASS (10/10) |
| **Mutation** : seuil porté à 20,0 m | ANOM-002 **et** ANOM-003 échouent → oracle non tautologique | 🔴 8/10, puis ✅ 10/10 après retour à 0,50 |
| **G520 --selftest** | 8 mutations refusées (dont « seuil transformé en garde »), 0 faux positif | ✅ PASS |

---

## 7. ⛔ Ce qui n'a PAS été fait dans ce volet (et ne le sera pas sans validation)

| Interdit du brief | État vérifié |
|---|---|
| Écrire du code de recalage | ✅ **écrit sur décision explicite de l'utilisateur** (2026-09-21) — et **uniquement** le témoin d'anomalie : la chaîne de recalage elle-même est INCHANGÉE |
| Modifier le comportement de recalage | ❌ aucun changement : 5 repères, correction inconditionnelle (gate G520 + cas ANOM-002/004) |
| Rouvrir la décision Q2 du lot T333 | ❌ `TC-P11-EST-007` ni modifié ni affaibli — toujours vert |
| Modifier le gain persistant | ❌ non modifié (référence de l'analyse) |
| Trancher seul | ❌ 2 arbitrages demandés et obtenus (opération retenue + garde) |

**Alertes hors périmètre, non corrigées** (devoir d'alerte) :

1. `FB_Translation_PositionEstimator.st:35` déclare encore `GainMetersPerHzSec := 0,008333` alors que le
   gain persistant vaut `0,02` : sans effet en production (`PRG_05_Translation.st:591` injecte la valeur
   persistante) mais toute instanciation de test qui ne câble pas le gain utilise une échelle périmée.
2. Les 2 nouvelles sorties de diagnostic (`RecalibrationAnomaly`, `RecalibrationCorrectionM`) ne sont
   **câblées nulle part** : elles sont disponibles pour une trace ou une IHM, mais leur publication
   exigerait `PRG_05_Translation.st` (SALE — lot T345-L1 en vol) et `ST_TranslationState.st`. **Non fait
   ici** : hors périmètre. Même situation que `RecalibratedSensorId`, déjà non publié.
3. La fiche `DOC/AF/AF_Partie-11_Fonction_Translation/FB_Translation_PositionEstimator_v1.0.md` est
   **modifiée non committée par un autre lot** : elle n'a **pas** été touchée. L'interface (2 sorties
   ajoutées) y reste donc non documentée — à régulariser après commit du lot T345-L1.
4. Le gain 0,02 est **provisoire** : toute conclusion de dérive reste conditionnée à T301 (§3, §6ter-c).
