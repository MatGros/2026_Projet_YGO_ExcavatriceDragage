# RAPPORT T328 — Fichiers touchés, changements et preuves

> **Lot** : T328 — SimBench : couplage mécanique M1/M2 + rattrapage anti-blocage des mâchoires
> **Date** : 2026-09-20 · **Implémentation** : `DSH01` · **Plan/contrat amendés par** `CC01` (verifier) puis `DSH01`
> **Artefacts** : `PLAN_T328_SIMBENCH_COUPLAGE_MECANIQUE_M1M2.md` · `TASK_CONTRACT_T328_SIMBENCH_COUPLAGE_M1M2.yaml`

---

## 1. 📋 Fichiers touchés (liste exhaustive)

| # | Fichier | Nature du changement | In-scope ? |
|---|---|---|---|
| 1 | `CODE/L_SIMULATION/FB_SimBench.st` | **+5 entrées** (`SimWinchCouplingModelActive`, `SimBucketJamActive`, `M2_CablePos_M`, `BucketOffsetCloseM`, `BucketCoherenceLimitM`) · **+2 sorties** (`WinchCouplingActive`, `WinchCouplingCorrectionPts`) · **+4 constantes** (`CST_SimWinchCouplingTauS`, `CST_SimWinchCouplingStepMax_M`, `CST_SimWinchCouplingPtsPerM`, `CST_SimBucketJamLoadFrac_Ratio`) · **+7 locales** · **1 région `§2bis`** (le rattrapage) · charge forcée sur blocage (`LoadFrac_Ratio` ×2) · correction d'un commentaire faux (T317) | ✅ oui |
| 2 | `CODE/L_SIMULATION/GVL_Simulation.st` | **+2 stimuli** : `SimWinchCouplingModelActive` (défaut `TRUE`), `SimBucketJamActive` (défaut `FALSE`) | ✅ oui |
| 3 | `CODE/M_MAIN/PRG_02_Acquisition.st` | **+5 paramètres nommés** vers `instSimBench` (dont `Data.EncoderM2.Measurement.CablePosM` et `_BucketCfgPersist.Config.OffsetCloseM/CoherenceLimitM`) | ✅ oui |
| 4 | `DOC/WFLOW/CONTRACTS/T314_SIMBENCH_PARITY.yaml` | **+5 motifs** dans le groupe `winch_scenarios` (le gate exige la classification de **chaque** `VAR_INPUT` : 77 → 82) | ⚠️ **hors scope déclaré** — requis par le gate |
| 5 | `TOOLS/TEST_AUTO_CI/RESULTS/L_SIMULATION/tests/test_fb_simbench.st` | **+9 tests** (`TC-P13-060` → `068`) | ✅ oui |
| 6 | `DOC/WFLOW/CONTRACTS/PLAN_T328_…md` | amendements §9 (challenge effets de bord), §11 (challenge modèle), §12 (limites), §13 (incident concurrence) | ✅ oui |
| 7 | `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T328_….yaml` | AC6/AC7 renumérotés en AC8/AC9 (doublons) · AC2/AC3/AC6/AC7 reformulés · prérequis périmé retiré · **scope inchangé** | ✅ oui |
| 8 | `DOC/WFLOW/REGISTRES/REGISTRE_VALEURS_TREUIL_STATUTS_v1.0.md` | **inconnue n°10** : raideur + constante de temps du couplage M1/M2 (`ESTIMÉE (HYPOTHÈSE ASSUMÉE)`, τ ∈ [0,2 ; 2] s, non bornable par les traces) | ✅ oui |
| 9 | `DOC/WFLOW/CONTRACTS/PLAN_T320_….md` | correction de **3 liens morts** (fichiers à créer) — dette G340 | ⚠️ correction de dette |
| — | `CODE_XML/CODE_Bundle.xml` · `CODE_XML/CODE_DiffBundle.xml` | artefacts générés | — |

🚫 **Non touchés** : `GVL_PERSISTENT.st`, `FB_Bucket.st`, `PRG_03/04/05/06/07`, `FB_WinchSync.st`, `DOC/STDS/*`, `Device.export`.

---

## 2. 🎯 Ce que fait le modèle (résumé vérifiable)

```text
Montée couplée réelle (relais de sens identiques + freins sim desserrés)
  ET câble tendu ET benne pas au fond ET hors preset/homing ET pas de blocage
  → la position Δ = PosM2 − PosM1 est reportée vers l'ENTRÉE DE LA BANDE FERMÉE
    (OffsetCloseM − ½ × CoherenceLimitM = 14,5 m avec la config actuelle)
  → corrigée par un 1er ordre borné (τ = 1,0 s, max 0,02 m/scan = 82 points)
  → appliquée UNIQUEMENT à l'image publiée (Winch.COD2_PosValue)
  → accumulée dans WinchCouplingAccumPts, purgée sur preset/homing,
    relâchée à l'ouverture commandée, jamais reportée quand le modèle est OFF
```

**Consommateur final (chaîne §3ter)** : `FB_SimBench` → `PRG_02` (sélecteur d'image) → `HwIn` → `FB_Bucket` (`Δ` → `IsClosed`) → `PRG_04:1224` (`BucketNotClosedAscentCapStep1`) ⇒ **le palier autorisé remonte**.

🔒 **Garantie structurelle** : `RawPosM2` (**mémoire persistante** `GVL_PERSISTENT._SimEncoderRawPosM2`) **n'est jamais écrite** — `FB_Sim_Encoder` en reste l'unique producteur.

---

## 3. ✅ Preuves (rejouées après les corrections)

| Vérification | Résultat |
|---|---|
| Tests CI `FB_SimBench` | **PASS 38/38** (dont **9 tests de ce lot**, `TC-P13-060`→`068`) |
| **G200 liaison (bloquant)** | **PASS — 0 erreur**, 1983 instances vérifiées |
| Bundle PLCopenXML | **fresh** ✅ |
| Diff bundle | `FB_SimBench`, `GVL_Simulation`, `PRG_02_Acquisition` ✅ |
| Gate parité SimBench | **PASS — 82 entrées** (77 + 5) |
| G315 interface FB | PASS (73 FB) |
| Encapsulation (défaut ligne fusionnée) | **PASS** ✅ (corrigé) |
| Gate contrat | **PASS** (0 erreur) |
| Gates **palier C** | **35/40 PASS** — 5 rouges **tous préexistants/hors lot** (voir §5) |

**Couverture des critères** : AC1 (montée couplée + convergence dans la bande → `TC-P13-060`/`066`) · AC2 (blocage → `TC-P13-062`) · AC3 (modèle OFF → `TC-P13-063`/`068`) · AC4 (borne de pente → asservie dans `066`) · AC5 (aucun effet métier → G200 + diff) · AC6 (arrêt/jog/câble mou → `TC-P13-061`/`064`) · AC7 (non-masquage → `TC-P13-063`) · AC8 (métier non modifié) · AC9 (preuves structurelles PRG_02 → bundle + diff).

---

## 4. 🧠 Challenges indépendants (2 avant écriture, 1 après)

| Agent | Verdict | Corrections intégrées |
|---|---|---|
| **Effets de bord** | 4 blockers | ① ne jamais écrire `RawPosM2` (RETAIN) → **image seulement** ② interrupteur maître obligatoire ③ gate preset/homing ④ manifeste de parité (scope) |
| **Modèle physique** | « **ne pas implémenter en l'état** » | ① AC7 contredit (184 scans 2 relais, trace 70) → non-masquage par le switch OFF ② cible = entrée de bande, pas la butée ③ gate étendu (câble tendu, benne au fond, preset) ④ montée seule (pas de double modèle descente) ⑤ τ en HYPOTHÈSE |
| **Revue du code (R1→R9)** | « **à corriger** » | ① **report de l'accumulateur gaté + purge preset** (corrompait homing/preset) ② **3 tests ajoutés** (convergence multi-scan, preset, mode OFF après session) ③ ligne de déclaration fusionnée rétablie ④ commentaires de lot nettoyés |

---

## 5. ⚠️ Dettes PRÉEXISTANTES (hors lot, attribuées une par une)

| Gate | Cause | Responsable |
|---|---|---|
| **G300** | répertoires inattendus `AGENT_WORKFLOW/.tmp` et `prototypes` | outillage |
| **G340** | 106 liens morts/versions périmées dans des plans antérieurs (mes 3 ont été corrigés) | documents antérieurs |
| **G408** | `FB_CycleSemiAuto.st:1543` — message IHM 75 car. (plafond 70) | lot AX2 antérieur |
| **G430** | 89 commentaires citant des numéros de lot, majoritairement `T317` dans `FB_SimBench` (mes ajouts sont nettoyés) | dette historique |
| **G483** | matrice maintenance N1/N2 (T181-14) | lot T181 |

---

## 6. ❓ Points ouverts (à trancher par l'humain)

1. 🔴 **Concurrence sur T328** : `CDX01` détient le verrou depuis 03:42 et implémentait la même tâche en parallèle — son `git restore` a effacé mes modifications à ~03:50 (ré-appliquées depuis). **Qui livre T328 ?**
2. **Défaut `SimWinchCouplingModelActive`** : j'ai retenu **`TRUE`** (le banc reproduit la réalité) ; le challenger recommandait `FALSE` par prudence de non-régression.
3. **Extension de scope** : le manifeste de parité a été modifié (**hors scope déclaré**) car le gate l'exige.

---

## 7. 🚫 Limites assumées (anti-validation de complaisance)

Un test CI vert **ne prouve rien sur la machine réelle** : il prouve que **le modèle sim, avec τ = 1,0 s choisi**, rattrape. Le trou métier T327 n'est **pas corrigé** par ce lot ; le blocage des mâchoires n'a qu'un effet **cinématique + diagnostic** (aucun rebouclage effort→vitesse) ; l'asymétrie 1:1 / 3:1 et les couches de câble ne sont **pas** modélisées.
