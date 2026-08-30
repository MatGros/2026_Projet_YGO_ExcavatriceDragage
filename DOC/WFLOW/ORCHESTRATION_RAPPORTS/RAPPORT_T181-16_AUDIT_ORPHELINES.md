# RAPPORT T181-16 — Audit des FB orphelins (FB_WinchSpeedLearning, FB_Winch_Symmetry, FB_Acquisition_Preflight)

> **Agent** : T181-16 (audit orphelines) · **Date** : 2026-08-30
> **Périmètre** : 3 FB listés dans `TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py` → `KNOWN_ORPHANS_PENDING_DECISION`
> **Mode** : 🔍 AUDIT SEUL — aucun fichier modifié, aucun commit.
> **Méthode** : lecture des `.st` + specs `AF_Partie-10`/`AF_Partie-06` + grep `CODE/` + croisement `TASKS.yaml` + exécution G200 (lecture seule).

---

## ⚠️ Correction de prémisse (à lire en premier)

La tâche supposait que les 3 FB figuraient dans `KNOWN_ORPHANS_PENDING_DECISION`. **Vérification G200 réelle** :

| FB | Statut G200 réel | Dans le dict d'exemption ? |
|---|---|---|
| `FB_WinchSpeedLearning` | **ERROR L13** (orphelin) | ❌ **NON** — pas dans le dict |
| `FB_Winch_Symmetry` | **WARN L13** (orphelin, exempté) | ✅ OUI |
| `FB_Acquisition_Preflight` | **PAS signalé orphelin** (câblé) | ✅ OUI (entrée **périmée**) |

**Conséquence** : `FB_WinchSpeedLearning` est le seul vrai orphelin **bloquant** (ERROR G200). L'entrée `FB_Acquisition_Preflight` du dict est un **faux positif** (le FB est câblé). L'entrée `FB_Winch_Symmetry` est un vrai orphelin mais **non bloquant** (WARN).

---

## 1 · `FB_WinchSpeedLearning` — `CODE/H_TREUILS_BENNE/FB_WinchSpeedLearning.st`

### Verdict : ✅ **À INSTANCIER** (dans le cadre de T181-16, actuellement **gelée**)

### Justification
- **Fonctionnalité nécessaire et non couverte ailleurs** : collecteur passif des vitesses réelles par palier (table RETAIN `{M1/M2 × sens × charge/vide × palier 1-5}`). C'est la **source de données de la surveillance survitesse** (T181-16). Aucun autre FB ne produit cette table.
- **Spec active** : `AF_Partie-10_Fonction_Winch_v2.1.md` §7.3 (apprentissage vitesse par palier). T181-15 a absorbé T096 et livré le FB + DUTs + table RETAIN.
- **Orphelin par conception, pas par oubli** : le contrat `TASK_CONTRACT_T181-15_SPEED_LEARNING.yaml` **interdit explicitement** le câblage dans T181-15 (`forbidden: CODE/M_MAIN/PRG_04_Treuils_Benne.st — câblage = T181-16`). Le câblage est assigné à **T181-16**.
- **T181-16 est gelée (⏸️)** : `TASKS.yaml` T181-16 « Surveillance survitesse FB_Safety_Winch » — gelée car le harnais ne restitue pas `VAR_IN_OUT` (STruCpp), la moyenne `SpeedMps`/RETAIN de T181-15 n'est pas prouvée. **Ne pas armer une survitesse sur cette table avant adaptateur/copy-out + TC intégration persistant.**
- **Sécurité machine** : c'est un FB **passif** (aucune commande moteur, aucune surveillance survitesse — AC1/AC7 du contrat). Son absence n'est **pas** un danger latent immédiat : la survitesse reste inactive (garde-fou mort `MeasuredSpeedBand:=0`, `SpeedGuardEnable=FALSE` — D06). Le danger serait d'**armer** la survitesse sur une table non prouvée — c'est précisément pourquoi T181-16 est gelée.

### Point d'appel exact proposé
- **Programme** : `PRG_04_Treuils_Benne` (câblage assigné à T181-16 par le contrat T181-15).
- **Emplacement** : nouvelle région dédiée (ex. `§Apprentissage vitesse`) — à ajouter lors de la livraison T181-16.
- **Câblage à prévoir** (une instance, appelée par axe via `WinchId`, ou deux appels) :
  - `Enable` ← autorisation générale (TRUE en mode apprentissage)
  - `LearnStart` ← `GVL_IHM.<...>.Cmd` bit IHM « lancer apprentissage »
  - `WinchId` ← axe actif (1=M1, 2=M2)
  - `Direction` / `StepNumber` ← `PRG_04_Treuils_Benne.Data.WinchM1State/WinchM2State` (sens + palier actif)
  - `MeasuredSpeedMps` / `MeasuredSpeedValid` ← `PRG_02_Acquisition.Data.Encoders.M1/M2` (vitesse mesurée)
  - `LoadPresent` ← détection charge (benne)
  - `StableForLearn` ← conditions stables (fenêtre de stabilité)
  - `Config` ← `ST_fbWinchSpeedLearning_Cfg` (enveloppes de plausibilité par palier)
  - `Table` (VAR_IN_OUT) ← `GVL_PERSISTENT._WinchSpeedLearnTable` (déjà déclaré, ligne 155)
- **Sorties** : `Ready`, `Learning`, `TableComplete`, `LampLearn`, `CellsFilled`, `CellsTotal` → projection IHM.

### Alerte
- **Bloquant G200** : `FB_WinchSpeedLearning` est le **seul ERROR L13** actuel. Il n'est **pas** dans le dict d'exemption. Deux options :
  1. **Le laisser en ERROR** tant que T181-16 est gelée (honnête : c'est un vrai orphelin en attente de câblage) — recommandé, mais G200 restera rouge.
  2. **L'ajouter au dict** `KNOWN_ORPHANS_PENDING_DECISION` avec justification « câblage assigné à T181-16 (gelée) » pour passer G200 en WARN — à trancher par l'orchestrateur.
- **Arbitrage humain requis** : débloquer T181-16 (adaptateur/copy-out harnais + TC persistant) pour pouvoir câbler ce FB et armer la survitesse en sécurité.

---

## 2 · `FB_Winch_Symmetry` — `CODE/H_TREUILS_BENNE/FB_Winch_Symmetry.st`

### Verdict : ✅ **À INSTANCIER** (diagnostic passif, spec active — **aucune tâche assignée** → arbitrage humain sur la priorité)

### Justification
- **Fonctionnalité nécessaire et non couverte ailleurs** : observateur passif de symétrie/synchronisme M1/M2 (décalages de démarrage, temps de desserrage/serrage freins, distance/temps d'arrêt, écart max de synchro). **Distinct de `FB_WinchSync`** (asservissement actif de synchro, zones 1-3) : c'est un **diagnostic maintenance** (MES-008), pas une commande.
- **Spec active, non TBD** : `AF_Partie-10_Fonction_Winch_v2.1.md` §7.3bis « Surveillance de symétrie M1/M2 (`FB_Winch_Symmetry` — MES-008 & Diagnostic) ». Spécifie explicitement : *« exécuté dans `PRG_07_Supervision`, en lecture seule stricte »* et *« alimente `ST_WinchSymmetryHMI` et la page Diagnostic de l'IHM »*.
- **Structures déjà en place** : `_WinchSymmetryCfgPersist` + `_WinchSymmetryDataPersist` (GVL_PERSISTENT lignes 31-32) et `ST_WinchSymmetryHMI` (IHM) — mais **jamais alimentés** car le FB n'est pas instancié.
- **Orphelin réel** : jamais instancié, jamais câblé. Exempté (WARN) dans le dict G200.
- **Sécurité machine** : FB **passif** (aucune commande, aucun SafeStop). Son absence n'est **pas** un danger latent — c'est une perte de **capacité de diagnostic maintenance**, pas une perte de protection.

### Point d'appel exact proposé
- **Programme** : `PRG_07_Supervision` (conforme spec §7.3bis, lecture seule stricte).
- **Emplacement** : nouvelle région `§Diagnostic symétrie M1/M2` (à côté du §3c Preflight existant).
- **Câblage à prévoir** :
  - `Reset` ← `FaultMachineReset_IHM` (front)
  - `M1CommandActive`/`M2CommandActive`, `M1Direction`/`M2Direction` ← `PRG_04_Treuils_Benne` (commandes/consignes)
  - `M1BrakeCmd`/`M2BrakeCmd`, `M1BrakeApplied`/`M2BrakeApplied` ← `PRG_04`/`PRG_02` (freins)
  - `M1Position_M`/`M2Position_M`, `M1Speed_Mps`/`M2Speed_Mps` ← `PRG_02_Acquisition.Data.Encoders.M1/M2`
  - `SyncDeviation_M` ← `PRG_04_Treuils_Benne.Data.SyncState` (écart synchro)
  - `Config` ← `GVL_PERSISTENT._WinchSymmetryCfgPersist`
  - `Data` (VAR_IN_OUT) ← `GVL_PERSISTENT._WinchSymmetryDataPersist`
- **Sorties** : `SymmetryOk`, `SymmetryValid` → `GVL_IHM.Commun.WinchSymmetry` (`ST_WinchSymmetryHMI`).

### Alerte
- **Aucune tâche de câblage n'existe** dans `TASKS.yaml` (seule mention : T182, migration doc, « fiche sans §2 tableau »). C'est une fonctionnalité spec'd mais **jamais planifiée**.
- **Arbitrage humain requis** : priorité de câblage. C'est un **diagnostic maintenance non critique** (pas de sécurité). Options :
  1. **À instancier** dans PRG_07 (recommandé — spec active, structures prêtes, coût faible, gain diagnostic terrain réel).
  2. **À supprimer** si la fonctionnalité de diagnostic symétrie est jugée non prioritaire / non demandée par l'exploitant (mais la spec §7.3bis est active et non retirée → suppression = retrait de spec, à trancher).
  3. **À geler** (garder orphelin exempté) en attendant une décision.

---

## 3 · `FB_Acquisition_Preflight` — `CODE/A_COMMUN/FB_Acquisition_Preflight.st`

### Verdict : ✅ **À CONSERVER — DÉJÀ INSTANCIÉ ET CÂBLÉ** (faux positif dans le dict G200)

### Justification
- **Le FB n'est PAS orphelin** : il est instancié et **entièrement câblé** dans `PRG_07_Supervision` :
  - Déclaration : `PRG_07_Supervision.st:36` → `instPreflight : FB_Acquisition_Preflight`
  - Appel complet : `PRG_07_Supervision.st:312-340` (toutes les entrées câblées depuis `PRG_02`/`PRG_04`/`PRG_05`, sorties projetées vers `GVL_IHM.Commun.Preflight.*`)
- **Spec active et conforme** : `AF_Partie-06_Acquisition_Qualification_IO_v2.4.md` §7 — *« Instance : `PRG_07_Supervision.instPreflight` (ST pur, en lecture seule stricte) »*. Le code correspond exactement à la spec (16 contrôles, `PreflightErrorId` 16 bits).
- **G200 ne le signale plus orphelin** : l'exécution réelle ne produit **aucun** L13 pour ce FB (seulement des WARN L10 bénins de multi-affectation — normal pour une machine d'état qui assigne ses sorties dans plusieurs branches).
- **L'entrée du dict est périmée** : ajoutée 2026-08-05 (avant câblage), elle est devenue obsolète. Elle est **inoffensive** (le FB n'étant plus orphelin, G200 ne l'affiche même pas en WARN), mais doit être **retirée** du dict pour éviter toute confusion.

### Action recommandée
- **Retirer `FB_Acquisition_Preflight` de `KNOWN_ORPHANS_PENDING_DECISION`** (housekeeping G200). Aucun câblage à faire — déjà fait.

### Alerte
- Aucune. Fonctionnalité de qualification machine arrêtée, active, câblée, spec'd. **Pas un danger latent.**

---

## 📊 Synthèse des 3 verdicts

| FB | Verdict | Point d'appel | Bloquant G200 ? | Action |
|---|---|---|---|---|
| `FB_WinchSpeedLearning` | ✅ **À INSTANCIER** (T181-16, gelée) | `PRG_04_Treuils_Benne` | **ERROR** (seul) | Débloquer T181-16 (harnais VAR_IN_OUT) puis câbler ; sinon ajouter au dict |
| `FB_Winch_Symmetry` | ✅ **À INSTANCIER** (diagnostic, spec active) | `PRG_07_Supervision` | WARN (exempté) | Créer une tâche de câblage ; arbitrage priorité |
| `FB_Acquisition_Preflight` | ✅ **À CONSERVER** (déjà câblé) | — (déjà en place) | Aucun | Retirer l'entrée périmée du dict G200 |

## 🚨 Points nécessitant un arbitrage humain
1. **T181-16 gelée** : débloquer le harnais (adaptateur/copy-out + TC persistant) pour câbler `FB_WinchSpeedLearning` et armer la survitesse en sécurité. Tant que gelée, `FB_WinchSpeedLearning` reste un ERROR G200 (ou à exempter dans le dict avec justification).
2. **`FB_Winch_Symmetry`** : aucune tâche de câblage n'existe. Décider priorité (instancier en diagnostic / geler / supprimer avec retrait de spec §7.3bis).
3. **Housekeeping G200** : retirer l'entrée périmée `FB_Acquisition_Preflight` du dict.

## 🔒 Note sécurité machine
- Aucun des 3 FB n'est un FB de sécurité actif : tous sont **passifs** (observateurs/collecteurs). Leur absence ne crée **pas** de danger latent immédiat.
- Le **seul risque réel** est l'**armement prématuré de la survitesse** sur une table d'apprentissage non prouvée (T181-16) — c'est exactement ce que le gel T181-16 empêche. **Ne pas lever le gel sans le harnais VAR_IN_OUT.**
