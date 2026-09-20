# PLAN_T320 — SimBench : miroir de l'apprentissage vitesse par palier

**Statut** : 🟡 **PROPOSITION — en attente de validation humaine** (workflow §3 : arrêt obligatoire avant tout code).
**Aucun fichier de `CODE/` n'a été modifié.** Date : 2026-09-20.

---

## 1. Origine & constat

💡 **Idée validée par l'humain** : le modèle simulé doit publier ses vitesses avec **la même indexation que la table d'apprentissage réelle**, pour que la comparaison **sim ↔ réel** soit automatique le jour où l'apprentissage terrain sera fait.

⚠️ **Constat moteur (correction humaine du 2026-09-20)** : `_WinchSpeedLearnTable` (RETAIN) **existe et est câblée**, mais **l'apprentissage n'a JAMAIS été lancé** → la table est **vide**.
⇒ Le modèle ne peut **pas** être validé aujourd'hui. Il doit simplement être **prêt** à l'être, et **rempli de valeurs théoriques** en attendant (d'où le brief de recherche `DOC/WFLOW/PROMPTS/05_brief_recherche_moteur_treuil_benne.md`).

🎯 Principe directeur : **le simulé d'aujourd'hui prépare la mesure de demain**, sans jamais se faire passer pour elle.

---

## 2. Objectifs testables

| # | Objectif | Critère de vérification |
|---|---|---|
| O1 | Le banc publie, par cellule `{axe × sens × charge/vide × palier}`, l'**enveloppe de vitesse modélisée** (min / max / moyenne / nb d'échantillons) | Structure `ARRAY[1..2,1..2,1..2,1..5]` identique à `ST_fbWinchSpeedLearning_Table` |
| O2 | Le jour J, la comparaison cellule par cellule s'obtient **sans adaptation de structure** | **Même clé d'indexation** (mêmes bornes de tableau) — ⚠️ **la sémantique de `Valid` DIFFÈRE volontairement** : le miroir **n'applique PAS** le filtre de plausibilité (§3) ⇒ `Valid` miroir ≠ `Valid` réel. Le comparateur (lot 2) doit comparer les **valeurs**, pas les drapeaux `Valid` |
| O3 | 🔒 **Aucune écriture dans `_WinchSpeedLearnTable`** — le sim ne pollue JAMAIS la donnée terrain | Gate statique : `FB_Sim_*` n'écrit aucune variable `_WinchSpeedLearn*` |
| O4 | **Aucun effet métier** : sim inopérant sur machine réelle, aucun nouveau consommateur hors diagnostic | `Enable` = `SimulationModeActive` ; G200 : aucune lecture par `PRG_03..PRG_07` |
| O5 | La **vitesse modèle en m/s est traçable** (aujourd'hui elle est interne, non observable) | Nouveau `VAR_OUTPUT` sur `FB_Sim_Encoder` |

---

## 3. Principe : miroir **passif** et **symétrique**

Réplique de `FB_WinchSpeedLearning` (mêmes conditions de collecte, mêmes index, mêmes bornes de comptage), avec **une seule différence** : la source de vitesse est la **vitesse modèle** au lieu de la **mesure codeur**.

⚠️ **Écart volontaire sur la fenêtre de plausibilité** : le réel **rejette** une vitesse hors de l'enveloppe du palier (`Min/MaxSpeedMps`) ; le miroir sim **n'applique pas** ce filtre et enregistre les **min/max observés**.
**Pourquoi** : si le modèle sort de la fenêtre de plausibilité réelle, c'est précisément **l'écart à révéler**. Filtrer l'effacerait au lieu de le montrer. C'est le **comparateur** (lot 2) qui appliquera la fenêtre.

---

## 4. Symétrie des conditions de collecte (indispensable pour que la comparaison ait un sens)

| Condition | Réel — `FB_WinchSpeedLearning` | Modèle — `FB_Sim_WinchSpeedEnvelope` (proposé) |
|---|---|---|
| Enable | mode ≠ `DISABLE` et axe non inhibé | `SimulationModeActive` **ET** diagnostic électrique actif |
| Sens | `ReqAscent` / `ReqDescend` métier, **conflit interdit** | `Mx_RelayFwd` / `Mx_RelayRev` (exclusifs par interlock) |
| Palier | `instWinchMx.StepNumber` (1..5) | `Mx_StepNumber` — **même source PRG_04**, déjà une entrée de `FB_SimBench` |
| Validité vitesse | `Measurement.SpeedValid` (codeur) | `SpeedModelMps` + validité modèle (nouveau) |
| Stabilité | `StepNumber > 0` **ET** sans défaut | `StepNumber > 0` **ET** modèle armé |
| Charge | `EstimatedLoadPct ≥ 50 %` | ⛔ **INDISPONIBLE en v1** (charge non câblée, registre T317) → voir §6 |
| Fenêtre plausibilité | appliquée (`_WinchSpeedLearnCfg`) | **non appliquée** (voir §3) |
| Agrégation | moyenne glissante, `Valid ≥ MinSamples` | min / max / moyenne + `SampleCount`, `Valid ≥ MinSamples` |

`MinSamples` et la constante d'indexation (`1=montée, 2=descente, 1=vide, 2=chargé`) sont **recopiés** de la table réelle, pas réinventés.

---

## 5. Interface proposée

### 5.1 DUT `ST_SimWinchSpeedCell` (nouveau)
```text
Valid             : BOOL;    // Cellule exploitable (SampleCount >= MinSamples)
SpeedModelMinMps  : REAL;    // Vitesse modèle minimale observée (m/s)
SpeedModelMaxMps  : REAL;    // Vitesse modèle maximale observée (m/s)
SpeedModelMeanMps : REAL;    // Moyenne glissante des vitesses modèle (m/s)
SampleCount       : UDINT;   // Nombre d'échantillons collectés
```

### 5.2 DUT `ST_SimWinchSpeedEnvelope` (nouveau)
```text
// [axe][sens][charge][palier] — indexation RECOPIÉE de ST_fbWinchSpeedLearning_Table
//   axe    : 1=M1, 2=M2       sens   : 1=montée, 2=descente
//   charge : 1=vide, 2=chargé  palier : 1..5
Cell : ARRAY[1..2, 1..2, 1..2, 1..5] OF ST_SimWinchSpeedCell;
LoadSourceValid : BOOL;   // ⚠️ FALSE aujourd'hui : la tranche « chargé » est vide (charge non câblée)
```

### 5.3 FB `FB_Sim_WinchSpeedEnvelope` (nouveau)
| Sens | Variables |
|---|---|
| `VAR_INPUT` | `Enable`, `AxisId` (1=M1, 2=M2), `ReqAscent`, `ReqDescend`, `StepNumber`, `SpeedModelMps`, `SpeedModelValid`, `LoadPresent`, `StableForModel`, `MinSamples` |
| `VAR_OUTPUT` | `Ready`, `Collecting`, `CellsFilled`, `CellsTotal` |
| `VAR_IN_OUT` | `Envelope : ST_SimWinchSpeedEnvelope` |

Mêmes garde-fous que le réel : axe dans 1..2, palier dans 1..5, **conflit de sens interdit**, agrégation seulement si `Enable`.

### 5.4 Publication
- `FB_Sim_Encoder` : **+1 `VAR_OUTPUT` `SpeedModelMps : REAL`** → expose en m/s le `SpeedMps` **déjà calculé** (aujourd'hui variable interne, donc **non traçable**).
- `FB_SimBench` : **+2 instances** `instSimSpeedEnvelopeM1/M2`, **+1 `VAR_OUTPUT`** `SpeedEnvelope : ST_SimWinchSpeedEnvelope`.
- Appels **après** les modèles codeurs du scan (source = palier et relais du scan courant).

---

## 6. Ce que la v1 ne fait PAS (à acter explicitement)

| Hors lot v1 | Raison |
|---|---|
| ❌ **Comparateur sim ↔ réel** | Lot 2 dédié (FB `FB_SimSpeedEnvelopeCompare` **ou** test CI Python). Le présent lot ne fait que **capturer**. |
| ❌ **Tranche « chargé »** | Charge non câblée (registre T317) ⇒ `LoadSourceValid := FALSE` **publié**, plutôt qu'un zéro silencieux |
| ❌ **Persistance** | Enveloppe = donnée de **session de banc** (remise à zéro au download). Volontaire : ne pas polluer les `RETAIN` |
| ❌ **Toute modification** de `FB_WinchSpeedLearning`, de `_WinchSpeedLearnTable` ou de la surveillance survitesse (`SpeedGuardEnable` **reste FALSE**) | Sécurité + producteur unique par donnée |
| ❌ **Vitesse moteur (`SpeedAct_Rpm`)** dans le miroir | La grandeur apprise est la **vitesse câble** en m/s → seule comparable. Le moteur reste traçable par instance. |

---

## 7. Fichiers touchés

| Fichier (créé dans `CODE/L_SIMULATION/`) | Nature | Risque |
|---|---|---|
| `ST_SimWinchSpeedCell.st` | nouveau DUT | nul |
| `ST_SimWinchSpeedEnvelope.st` | nouveau DUT | nul |
| `FB_Sim_WinchSpeedEnvelope.st` | nouveau FB | faible |
| `CODE/L_SIMULATION/FB_Sim_Encoder.st` | +1 `VAR_OUTPUT` (**additif**) | faible |
| `CODE/L_SIMULATION/FB_SimBench.st` | +2 instances, +1 `VAR_OUTPUT`, + appels | faible |
| `TOOLS/TEST_AUTO_CI/…/test_fb_sim_winchspeedenvelope.st` | nouveau test | — |
| `DOC/AF/AF_Partie-13_Fonction_Simulation_v2.5.md` | ajout d'une entrée spec | — |

🗂️ **Emplacement des DUT** : `CODE/L_SIMULATION/` est **plat** aujourd'hui (aucun `_TYPES`), contrairement aux autres domaines.

- **Option A (recommandée)** : fichiers **plats** dans `L_SIMULATION/` → conforme à l'existant, **0 risque structurel**, conforme au gate de nommage (nom de fichier = nom du DUT).
- **Option B** : créer `L_SIMULATION/_TYPES/` → plus conforme à la convention générale, mais **ajoute un groupe à l'import CODESYS** (opération manuelle humaine) et un dossier neuf à valider.

---

## 8. Vérification mécanique prévue (standard projet, non négociable)

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_diff_bundle.py . ST_SimWinchSpeedCell.st ST_SimWinchSpeedEnvelope.st FB_Sim_WinchSpeedEnvelope.st FB_Sim_Encoder.st FB_SimBench.st
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report   # BLOQUANT
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C
```

**Cas de test CI prévus** : gate OFF → aucune collecte · palier hors 1..5 → non collecté · **sens conflictuel → non collecté** · axe hors 1..2 → non collecté · min/max/moyenne corrects sur séquence connue · **isolation M1 ↔ M2** · `Valid` seulement à `SampleCount ≥ MinSamples` · aucune écriture hors enveloppe.

---

## 9. Risques & mitigations

| Risque | Mitigation |
|---|---|
| **Confusion sim / réel** (le plus grave) | Nommage `Sim…` · structure **distincte** · **interdiction d'écrire** dans la table RETAIN (O3) · flag `LoadSourceValid` |
| **Faux espoir de validation** : croire le modèle validé | Limite écrite dans le code **et** dans `AF_Partie-13` : le miroir **n'est pas** une mesure |
| Tranche « chargé » vide → comparaison partielle | Flag publié + documenté, **pas** de zéro silencieux |
| Coût cycle (2 FB passifs, tâche 10 ms) | Comparaisons entières min/max → négligeable ; à confirmer par mesure de charge si doute (pratique T300 Q14) |
| Dérive future : quelqu'un « branche » le miroir dans la sécurité | G200 + revue : aucun consommateur métier autorisé (O4) |

---

## 10. Décisions à valider par l'humain (avant toute écriture)

| # | Question | Recommandation |
|---|---|---|
| D1 | **v1** (enveloppe 4D + min/max/moyenne) ou **v0 dégradé** (`ARRAY[1..2,1..2,1..5] OF REAL` = dernière vitesse stable) ? | **v1** — le min/max est ce qui révélera les écarts ; v0 ne permettrait qu'une comparaison ponctuelle |
| D2 | Emplacement des DUT : **A** (plat) ou **B** (`_TYPES`) ? | **A** — 0 risque, conforme à l'existant |
| D3 | Tranche « chargé » : publier `LoadSourceValid=FALSE` ou **attendre** le câblage de la charge (T317) ? | **Publier FALSE** — la structure est prête, le flag dit la vérité |
| D4 | Criticité : **C2** (diagnostic pur, aucun effet machine) ? | **C2** — contrat de tâche obligatoire dès C2 |
| D5 | Comparateur : **lot 2** séparé ? | **Oui** — ne pas sur-dimensionner la v1 |

---

## 11. Effort & suite

- **Effort v1** : ~½ journée (3 fichiers neufs + 2 retouches additives + test CI + vérification mécanique), hors rédaction `AF_Partie-13`.
- **Suite** : après validation → création de la tâche **T320** dans `DOC/WFLOW/TASKS.yaml` + `TASK_CONTRACT_T320_…yaml` (criticité C2, objectifs = O1..O5).

---

## 12. Hors scope — devoir d'alerte

1. 🚩 `DOC/WFLOW/CONTRACTS/PLAN_T317_SIMBENCH_TREUIL_ELECTRIQUE.md` est **périmé** sur un point factuel (« `FB_Sim_WinchElectrical` pas encore écrit » → il l'est, câblé, actif par défaut).
2. 🚩 `FB_SimBench.st:134` porte un **commentaire faux** (« `ResistiveTorque_Nm` reste à 0.0 » → vaut ≥ 80 Nm).
3. 🚩 Ces deux dettes sont **indépendantes de T320** : à traiter séparément (aucune correction spontanée).
