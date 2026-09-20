# 🎯 BRIEF — T255-D : défaut silencieux « FDC logiciel BAS » (AnyFault allumé, bandeau muet)

> **À copier-coller en tête de la mission déléguée :** le contenu **intégral** de
> `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` (préambule obligatoire du projet).
> Ce brief **ne le remplace pas**.

```
════════════════════════════════════════════════════════════
MISSION T255-D — Défaut silencieux FDC logiciel BAS
Criticité C2 · Domaine SUPERVISION_IHM / SECURITE_LIMITES_TREUILS
Orchestrateur : CC01 · Date : 2026-09-20
Parent : T255 (Guidage dynamique précis des messages opérateur et conditions IHM)
════════════════════════════════════════════════════════════
```

---

## 0 · PRÉREQUIS D'ENTRÉE — ⚠️ **DEUX BLOQUANTS À LEVER AVANT DE CODER**

| # | Prérequis | État vérifié 2026-09-20 | Action |
|---|---|---|---|
| 1 | 🔒 **Verrou de travail** sur `T255-D` | ❌ **ABSENT** — `agent: '—'`, aucun `work_locks` | **STOP** : l'orchestrateur doit **poser le 🔒 et nommer l'agent** avant démarrage |
| 2 | 🔴 **Contrat C2** `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T255-D_SILENT_LOW_LIMIT_FAULT.yaml` | ❌ **ABSENT** (seul le contrat **parent** `TASK_CONTRACT_T255_DYN_USER_MESSAGES_IHM.yaml` existe) | **STOP** : **rédiger le contrat d'abord** (gabarit `TOOLS/AGENT_WORKFLOW/templates/task_contract.yaml`, contrôle `check_task_contract.py`) — **C2 ⇒ contrat obligatoire avant toute écriture** |
| 3 | Lire `AGENTS.md`, `CODE_QUALITY_STANDARDS.md`, `NAMING_CONVENTION.md` | — | — |
| 4 | ⚠️ **T330 P3 attend T255-D** : les deux lots écrivent dans **`PRG_07_Supervision.st`** et **`FB_Hmi_BannerFormatter.st`** | — | **sérialiser** (voir §7) |

> ⛔ Sans 🔒 **et** contrat, **ne pas commencer** — remonter à l'orchestrateur.

---

## 1 · POSTURE (non négociable)

- 🛡️ **Anti-Yes-Man** : ne valide **aucune** hypothèse par défaut, **y compris celles de ce brief**.
  Toutes les ancres du §3 sont **vérifiables** : **revérifie-les `fichier:ligne`**.
- 🎯 **Cause racine d'abord**, correctif ensuite. Un correctif sans cause racine **prouvée** est refusé.
- 🔬 **Distingue** FAIT PROUVÉ / HYPOTHÈSE / INCERTAIN dans ta restitution.
- 🚨 **Devoir d'alerte** : toute incohérence ou risque hors scope remonte **immédiatement**.
- ✍️ **Signaler n'est pas élargir** : on attend le signalement, **pas** la correction spontanée.

---

## 2 · CONTEXTE

**Constat terrain MES** (demande utilisateur 2026-09-20) : à l'arrivée en **fin de course logicielle
basse**, le voyant **`AnyFault` s'active** mais le **bandeau IHM n'affiche ni alarme ni action autorisée**.

**Besoin transversal** : *tout `SafetyFault`, limite basse / légale ou blocage process doit produire une
information opérateur **avec l'action autorisée***.

---

## 3 · ANCRES VÉRIFIÉES (point de départ de la trace — **à revérifier**)

### 3.1 ⚠️ Référence **périmée** à corriger

Le tableau des chantiers indique « `PRG_07 AnyFault :424-427` ».
❌ **FAUX aujourd'hui** : `PRG_07:424-427` = publications **`WinchSymmetry`**.
✅ **`AnyFaultActive` est en `PRG_07:537-547`**.

### 3.2 `AnyFaultActive` — agrégat de **11 sources** (`PRG_07:537-547`)

```
GVL_IHM.Modes.State.AnyFaultActive := PRG_06_Outputs.EmergencyDiag.Error
    OR PRG_02_Acquisition.Data.InputModules.Fault
    OR PRG_03_Modes_Cycle.Data.ModesFault.Error
    OR PRG_03_Modes_Cycle.Data.ModesFault.Latched
    OR GVL_IHM.M1TreuilRetenue.Safety.Error
    OR GVL_IHM.M2TreuilBenne.Safety.Error
    OR GVL_IHM.M3Translation.Safety.Error
    OR GVL_IHM.M1M2Sync.State.Error
    OR GVL_IHM.M2TreuilBenne.Bucket.State.Error
    OR GVL_IHM.CycleSemiAuto.State.Error
    OR GVL_IHM.JOY1Joystick.State.Error;
```

🔴 **FAIT CAPITAL** : `AnyFaultActive` agrège **`.Error` (défauts latchés)** — il **ne contient PAS** les
**causes vives de permis** (`CableLimitDescent`, `LimitLegalReached`, `CauseTopLimitSwitchActive`) qui
agissent sur `DescendPermit` / `AscentPermit` (`FB_Safety_Winch.st:563-582`).
⇒ **Une limite basse seule n'allume donc PAS `AnyFault`** : si le voyant s'allume, c'est qu'un **défaut
latché** s'est ajouté **en plus** du blocage de permis. **C'est ce défaut-là qu'il faut identifier.**

### 3.3 Le mécanisme du bandeau — **`AlarmCount`**, et pourquoi il peut tomber à **0**

`FB_Hmi_BannerFormatter.st` :
- `AlarmCount := 0` (`:775`) puis **~130 entrées** conditionnelles (`:778-1165`) ;
- 🔴 **CHAQUE entrée est gardée par un flag de validité** (`EncM1Valid`, `EncM2Valid`, `LocalIoValid`,
  `Joy1Valid`, `Vh0800Valid`, `EcatBusValid`, `VarM3Valid`…) — **exemples** : `:835`
  `IF WinchM1Safety.ErrorMecaD AND LocalIoValid AND EncM1Valid`, `:820` `… AND EncM1Valid`,
  `:817` `… AND Joy1Valid` ;
- 🔴 **`IF AlarmCount = 0 THEN` en `:1175`** ⇒ **c'est le chemin du « bandeau vide »** ;
- l'action opérateur est une **cascade `ELSIF`** indépendante : `DirectionBlocked` (`:648`) →
  sous-branches descente `:652-669` avec **repli générique** `:668` `'[TREUIL] Descente interdite'` ;
- `DirectionBlocked := (CurrentDirection < 0 AND NOT DescendPermit) …` (`:408`) ⇒ la cascade
  **n'émet rien si l'opérateur ne commande pas la descente** ;
- **aucune entrée d'alarme** n'existe pour la **limite basse câble / FDC logiciel bas** — cohérent
  (c'est un **permis**, pas un défaut) mais **à prouver**, pas à supposer.

### 3.4 🎯 Deux mécanismes candidats — **à trancher par la trace**, jamais recopiés

| # | Mécanisme | Signature |
|---|---|---|
| **A** | Un défaut **latché** est **bien** dans `AlarmArray` mais **masqué par un flag `*Valid` = FALSE** (module / codeur / joystick non détecté) ⇒ `AlarmCount = 0` ⇒ **bandeau vide** alors qu'`AnyFault` est allumé | `AnyFault=TRUE` **et** un `*Valid` à `FALSE` au même scan |
| **B** | Une source d'`AnyFaultActive` (`:537-547`) **n'a aucune entrée d'alarme** correspondante — **piste à vérifier en priorité : `GVL_IHM.JOY1Joystick.State.Error` (`:547`)** | `AnyFault=TRUE`, tous les `*Valid` à `TRUE`, `AlarmCount = 0` |

### 3.5 🔁 **REX IDENTIQUE DÉJÀ CONNU** — à réutiliser, pas à redécouvrir

Le projet a **déjà** rencontré **exactement ce motif** : **`ErrorBrakeThermal`** présent dans
`AnyFaultActive` mais **non collecté** dans le bandeau, **classe warning exclue**, et **aucune branche de
repli** quand `Safety.Error` est vrai **sans bit bloquant connu** ⇒ **`AlarmCount = 0` ⇒ bandeau vide**
(motif **REX 2026-07-29**).

**Sources** : entrée `MES-032` du registre de mise en service · entrée `C1-ANYFAULTACTIVE-EXHAUSTIF` du
registre d'orchestration · fiche liée `DESIGN-BANDEAU-IHM`.
⚠️ **Les numéros de ligne cités dans ces entrées sont ceux de l'époque** : le fichier a **évolué**
(§3.3 ci-dessus reflète l'état **vérifié le 2026-09-20**) ⇒ **revérifier avant de citer**.

> 🎯 **Conséquence directe** : la correction attendue n'est probablement **pas** « ajouter un message pour
> la limite basse », mais **supprimer la possibilité d'un `AlarmCount = 0` alors qu'`AnyFault` est vrai** —
> c'est-à-dire une **branche de repli exhaustive**. **À confirmer par la trace.**

---

## 4 · OBJECTIFS (issus du catalogue — ta restitution se juge **contre eux**)

| # | Objectif |
|---|---|
**O1** | **Cause racine sourcée `fichier:ligne`** : le défaut est-il (a) dans `AnyFaultActive` **sans entrée bandeau**, ou (b) **filtré** par le formatter (flag `*Valid`, classe exclue) ? |
**O2** | À l'arrivée en **FDC logiciel bas** : **message d'alarme explicite** (cause **+** treuil) **ET** texte d'**action autorisée**, affichés **au même scan** que `AnyFault` |
**O3** | **Test CI ciblé** (harnais `PRG_07` / `FB_Hmi_BannerFormatter`) qui **échoue avant** le correctif et **passe après** |
**O4** | **Garde-fou `guard:`** dans `TOOLS/AGENT_WORKFLOW/scripts/` : **aucune cause agrégée dans `AnyFaultActive` sans libellé bandeau** |
**O5** | **Inventaire des autres défauts muets** rencontrés : **signalés** (T243/T220), **non corrigés** dans ce lot |

---

## 5 · PÉRIMÈTRE

| Attendu (cible du correctif) | Interdit |
|---|---|
`CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st` · `CODE/M_MAIN/PRG_07_Supervision.st` · le **contrat T255-D** (à créer) · tests CI (`TOOLS/TEST_AUTO_CI/`) · le **nouveau gate** (`TOOLS/AGENT_WORKFLOW/scripts/`) | ⛔ `CODE/M_MAIN/PRG_04_Treuils_Benne.st` (**T291-B B2**) · ⛔ `CODE/L_SIMULATION/*` (**T300 P-A / T328**) · ⛔ `PRJ_CODESYS/**/Device.export` · ⛔ tout autre fichier **sans justification `fichier:ligne`** |

⚠️ `CODE/J_SUPERVISION/_TYPES/*` : **ne pas ajouter de champ IHM** sans arbitrage orchestrateur.

---

## 6 · TRAVAIL DEMANDÉ

1. **Tracer la chaîne complète**, `fichier:ligne`, **de bout en bout** :
   `producteur du défaut` → `AnyFaultActive (PRG_07:537-547)` → `FB_Hmi_BannerFormatter` (`AlarmCount`,
   `AlarmArray`, `OperatorActionCandidate`) → `GVL_IHM` (bandeau) → **opérateur**.
   ⚠️ **Traçabilité d'impact obligatoire** (`CODE_QUALITY_STANDARDS §3ter`) : nommer le **consommateur
   final**, ne pas s'arrêter au premier maillon.
2. **Prouver la cause racine** par une **trace réelle** (snapshot/watch CODESYS fourni par l'humain) **ou**
   par un **test CI qui reproduit le symptôme** (`AnyFault=TRUE` **et** `AlarmCount=0`).
   ⛔ **Ne pas** livrer un correctif fondé sur une **hypothèse** non reproduite.
3. **Corriger** — au minimum : **branche de repli exhaustive** garantissant qu'`AnyFault` vrai ⇒ **au
   moins un** message. Préserver le **tri par priorité** existant (§5 du formatter) : **ne jamais masquer**
   une cause racine (AU / puissance / SafeStop / direction priment — cf. commentaires `:619-633`).
4. **Garde-fou** (`fix:` + `guard:`) — **deux livrables obligatoires** : le **correctif** *et* le gate.
5. **Inventorier** les autres défauts muets (**signalés**, non corrigés — O5).

---

## 7 · CHANTIERS CONCURRENTS — ⚠️ **sérialisation obligatoire**

| Tâche | Agent | Fichiers | État | Conflit |
|---|---|---|---|---|
| 🔴 **T330 P3** | DSH01 🔒 | **`FB_Hmi_BannerFormatter.st`**, **`PRG_07_Supervision.st`** | plan v1.2 en cours (P1/P2) | **MÊMES 2 FICHIERS** ⇒ **T330 P3 ne démarre qu'après livraison de T255-D** |
| T291-B | AGY01 | `PRG_04`, `G499`→`G505` | B2 attend T330 | `PRG_04` interdit ici |
| T300 P-A | CDX01 🔒 | `L_SIMULATION` | en cours | interdit ici |
| T333 | verrou à venir | `FB_Translation_PositionEstimator` | en cours | — |
| T328 | DSH01 🔒 | `FB_SimBench.st` | ⏳ **non livrée** | — |
| T327 | CC01 🔒 | `ManualBucketLimits` | ⏳ **non livrée** | — |

> 🎯 **Ordre acté** : `T255-D` **d'abord**, puis `T330 P3`. T255-D touche la **même région** de `PRG_07`
> (`AnyFaultActive`) et **le même FB** que T330 (§7). Toute écriture simultanée = conflit garanti.

---

## 8 · CRITÈRES TESTABLES

| AC | Critère | Preuve exigée |
|---|---|---|
**AC1** | **Cause racine identifiée et sourcée** `fichier:ligne`, **reproduite** (trace ou test) — mécanisme **A** ou **B** du §3.4 **tranché** | extrait de trace **ou** test rouge avant / vert après |
**AC2** | À l'arrivée en **FDC logiciel bas** : **alarme + action autorisée** affichées **au même scan** que `AnyFault` | test CI + capture IHM |
**AC3** | **`AnyFault` vrai ⇒ `AlarmCount ≥ 1`** dans **tous** les cas (garantie structurelle) | test couvrant **chaque** source de `PRG_07:537-547` |
**AC4** | **Garde-fou** présent et **branché** dans `run_all_gates.py` (`PLANS`) — ⚠️ cf. REX ci-dessous | ligne `PLANS` + exécution |
**AC5** | **Test CI** qui **échoue avant** / **passe après** | sortie brute des deux états |
**AC6** | **Aucun fichier hors périmètre** dans `git status --short` | sortie brute |
**AC7** | Les **autres défauts muets** sont **signalés** (pas corrigés) | liste |

### 🚨 REX À NE PAS REPRODUIRE — « garde-fou mort-né »

Deux garde-fous du dépôt **existent mais ne s'exécutent JAMAIS** car **absents de `PLANS`** :
`G490_check_ihm_bindings.py` et `G499_check_t291b_top_authority.py`
(⚠️ `PLANS` ne contient qu'**une** entrée `"499"`, pointant sur **T289**).
⇒ **AC4 exige explicitement la ligne `PLANS`** : un gate non branché produit une **assurance fallacieuse**.
⛔ **Choisir un identifiant LIBRE** (`G504` et `G505` sont **réservés par T330** ⇒ prendre **`G506`** ou
au-delà, **après vérification**).

---

## 9 · PREUVES MÉCANIQUES À PRODUIRE (règle projet, aucune exception)

Ce lot **modifie du code** ⇒ **minimum obligatoire** :
```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_diff_bundle.py . <fichiers CODE touchés>
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report     # BLOQUANT
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C --pytest --full-ci
```
- ⛔ **Sans `--full-ci`**, `G460` (harnais `TEST_AUTO_CI`) **n'est pas exécuté** (`run_all_gates.py:194-195`).
- ⛔ **Sans `--pytest`**, `G420` ne tourne pas.
- Le bloc **`Auto-vérification liaison`** de `G200 --report` est **collé dans la restitution** — sans lui,
  le lot est **incomplet**.
- **Bandeaux** obligatoires : bundle · **diff bundle avec la liste des objets** · bandeau 2 si gates verts.

---

## 10 · RESPONSABILITÉ ET FORMAT DE RESTITUTION

- ⛔ **Aucun commit, aucun push.**
- 📊 **Checkpoint `agent_heartbeat.py`** (session `T255-D`, agent **ton trigramme**, ex. `CDX01`) :
  `python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py record T255-D <ETAPE> <etat> --agent <TRIGRAMME> --msg "<résumé>"`
- 🔁 **Règle `fix:` + `guard:`** : le bug **et** son garde-fou automatique.

### Restitution attendue
1. **Verdict** (`PASS` / `ALERTE` / `BLOCK`)
2. **Traçabilité d'impact** : `producteur → route → consommateur final` (consommateur **nommé**)
3. **Cause racine** prouvée (`fichier:ligne` + trace/test) — mécanisme **A** ou **B**
4. **AC1 → AC7** avec preuve
5. **Bloc `Auto-vérification liaison` (G200)** collé
6. **Objets du diff bundle** listés
7. **Autres défauts muets** inventoriés (O5)
8. **Risques résiduels** et **fichiers modifiés** (chemins exacts)

---

## 11 · ⛔ CAS D'ARRÊT — demander, ne pas deviner

- 🔒 **Verrou absent** sur `T255-D` → **STOP** (prérequis 1)
- 📄 **Contrat C2 absent** → **STOP** (prérequis 2)
- Cause racine **non reproduite** → **ne pas** livrer de correctif (O1/AC1)
- Le correctif exigerait un **nouveau champ IHM** → **arbitrage orchestrateur** (jamais décidé par l'agent)
- Un **gate** existant échoue et la correction exige une **allowlist** → **remonter** (une exemption
  n'est **jamais** une décision d'agent, `subagent_preamble.md:44`)
