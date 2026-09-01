# PLAN — T204 : Enforcement des permits directionnels M3 en gate de commande

> **Livrable 2 de T204.** Ce plan est NON-CODE (phases, tests, CI, agent, DOC).
> Il détaille l'exécution autorisée par `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T204.yaml`
> (C2, strategy=patch). Aucune écriture de code ne démarre sans visa humain.
> Date : 2026-09-02 · Base : MAIN (hors worktree) · Bloqué par : [T184].

---

## 0 · Lecture obligatoire avant toute action

| # | Document | Pourquoi |
|---|---|---|
| 1 | `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T204.yaml` | Contrat (scope, AC1..AC9, alert_duty, conservation) |
| 2 | `DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md` §3ter | Modèle cible du gate (déjà rédigé pour T204) |
| 3 | `CODE/H_TREUILS_BENNE/FB_Winch.st` : 150-260 | **Modèle de référence** `EffectiveSafeStop` (l.163) |
| 4 | `CODE/I_TRANSLATION/FB_Translation.st` : 192-219 | Site d'insertion cible (§4bis Gate + §5 rampe) |
| 5 | `CODE/I_TRANSLATION/FB_Safety_Translation.st` : 65-66, 231-273 | Producteur unique des permits (INTACT) |
| 6 | `CODE/M_MAIN/PRG_05_Translation.st` : 298-324, 353-374, 416 | Liaison permits + `EffectivePermitM3_*` + `M3_SafeStop_Aggregate` |
| 7 | `DOC/STDS/NAMING_CONVENTION.md`, `DOC/AF/AF_Partie-03` | Nommage + contrats FB |
| 8 | `AGENTS.md §Auto-vérification` | Bundle / G200 / gates palier C obligatoires |

---

## 1 · ⚠️ Constat d'ingénierie structurant le plan

> Découvert pendant le cadrage (transcription dans contrat AC2/AC5) :

- **Le gate partiel existe déjà** : `FB_Translation.st` §4bis (l.202-203) calcule déjà
  `EffectiveSafeStop := SafeStop OR (Direction > 0 AND NOT TremiePermit)`. Donc le sens
  Trémie (`+1`) est **déjà bloqué** ; ce qui manque c'est le sens Maintenance (`−1`).
- **Conflit réel documenté dans le code** : le commentaire `FB_Translation.st:198-201`
  affirme explicitement que **gater `−1` sur `MaintenancePermit` bloquerait l'accès à P1**
  quand `MaintenanceM3TargetEnable=FALSE` (régression fonctionnelle du positionnement SEMI_AUTO sur P1).
- Le transit dirigé vers P1 n'est pas un transit vers Maintenance terminal : l'AC2 distingue
  explicitement « cible P1 » (à laisser passer) de « cible Maintenance » (à bloquer).

> ⛔ **Conséquence** : T204 n'est PAS « coller bêtement `NOT MaintenancePermit` sur `Direction=-1` ».
> C'est une **micro-décision métier** (comment distinguer P1 de Maintenance depuis le gate sans
> dégrader l'accès P1). Toute formulation simpliste sera refusée à la revue. Si la distinction
> P1 ne peut pas être exprimée proprement dans `FB_Translation` avec les signaux existants
> (`SlowdownSensorP1`, `PositionSensorTarget`, `Direction`), l'arbitrage d'insertion (Phase 3)
> re-bascule sur `FB_TranslationCmdArbitrationM3.st`. C'est exactement le rôle de l'ARRÊT
> VALIDATION en fin de Phase 3.

---

## 2 · Objectifs testables (repris du contrat T204)

| Ref | Objectif observable (au présent) |
|---|---|
| O1 (=AC1) | `EffectiveSafeStop`=TRUE si `Direction=+1` et `TremiePermit=FALSE` → `RampTargetPct`=0, sans toucher `Direction` ni verrous bistables |
| O2 (=AC2) | `EffectiveSafeStop`=TRUE si `Direction=-1` et `MaintenancePermit=FALSE` et requête ≠ transit P1 ; le transit P1 n'est jamais bloqué par le seul `MaintenancePermit` |
| O3 (=AC3) | Segment P1→Maintenance reste protégé par la coupure dure `M3_LimitSwitchMaintenanceEffective` + ralentissement inchangés |
| O4 (=AC4) | Changement confiné au `scope.allowed` ; aucun autre FB/POU modifié |
| O5 (=AC5) | Point d'insertion documenté + justifié dans `AF_Partie-11 §3ter` (aligné `FB_Winch.st:163`) |
| O6 (=AC6) | Bits IHM `GVL_IHM.TranslationM3.Safety.*` non supprimés/renommés, cohérents avec le gate |
| O7 (=AC7) | Aucun interlock sécurité M3 (Méca A/B, LimitSwitch, SensorIncoherent, PowerCutOff, SafeStop) modifié |
| O8 (=AC8) | Structure `PRG_05` : fichier=POU, suffixe=langage ST bundle |
| O9 (=AC9) | Bundle + G200 liaison PASS + gates palier C PASS + tests CI étendus |

---

## 3 · Phases (séquencées / parallèles)

> Diagramme de dépendances. Deux voies peuvent courir en parallèle dès la Phase 2.

```text
        ┌──────────────┐
        │ Phase 1 CADRE│  ← T184 requis
        │ blocage /    │
        │ décision P1  │
        └──────┬───────┘
               ▼
        ┌──────────────┐
        │ Phase 2 SPEC │  ← Phase 3 bloquée par celle-ci
        │ AF §3ter     │
        └──────┬───────┘
               ▼
   ⛔ ARRÊT VALIDATION #1 : choix du point d'insertion + règle P1 (humain, C2)
               │
               ▼
        ┌──────────────┐           ┌──────────────┐
        │ Phase 3 IMPL  │  ──parallèle──►│ Phase 4 CI    │
        │ FB_Translation│           │ tests unit.   │  (dépend de la règle P1 figée en Ph.3)
        └──────┬───────┘           └──────┬───────┘
               ▼                          ▼
        ┌──────┴──────────────────────────┐
        │ Phase 5 VERIF MÉCA (bloquante) │
        │ bundle + G200 + gates palier C │
        └──────┬──────────────────────────┘
               ▼
   ⛔ ARRÊT VALIDATION #2 : restitution finale + visa humain avant intégration CODESYS
```

### Phase 1 — Cadrage & décision fonctionnelle (bloque_par: [T184])
- Consolider le constat P1 (§1) en décision écrite : **comment distinguer « transit P1 »
  de « transit Maintenance » depuis le gate** — options :
  (a) gater `−1` seulement si la cible n'est pas sur le chemin vers P1 ;
  (b) laisser la protection P1 côté `M3_LimitSwitchMaintenanceEffective` et **ne pas** gater `−1`
      sur `MaintenancePermit` (hypothèse : `MaintenancePermit` ne concerne que la cible terminale).
- Livrable : note de décision dans `AF_Partie-11 §3ter`.
- Ne touche aucun code.

### Phase 2 — Mise à jour de la spec AF (§3ter) — bloque_par: []
- Enrichir `AF_Partie-11_Fonction_Translation_v2.3.md` §3ter : décrire le gate effectif complet
  des deux sens, la règle P1, et référencer `FB_Winch.st:163`.
- Peut courir en parallèle de la Phase 3 après l'ARRÊT VALIDATION #1.

### ⛔ ARRÊT VALIDATION #1 — C2, visa humain obligatoire
- Valider : (a) point d'insertion retenu (`FB_Translation` vs `FB_TranslationCmdArbitrationM3`),
  (b) règle de non-blocage P1 (AC2).
- **Aucune écriture de code avant cet arrêt.**

### Phase 3 — Implémentation ST (bloque_par: ARRÊT VALIDATION #1)
- Site cible : `CODE/I_TRANSLATION/FB_Translation.st` §4bis — étendre `EffectiveSafeStop`
  au sens `−1` selon la règle P1 validée en Ph.1. (Ville autorisée : voir AC4.)
- Respecter `AF_Partie-03` + `NAMING_CONVENTION` (PascalCase, polarité fail-safe `TRUE=autorisé`).
- Pas de redémarrage automatique, `Reset` sur front, `Enable > SafeStop > StartStop`.
- Si l'insertion bascule sur `FB_TranslationCmdArbitrationM3.st`, adapter les fils dans `PRG_05`.

### Phase 4 — Tests CI (bloque_par: règle P1 figée) — parallèle Ph.3
- Étendre `TOOLS/TEST_AUTO_CI/TEST_AUTO_CI_UNITARY/I_TRANSLATION/test_unitaires.py`
  (+ stimulus FB dans les registres TC-P11) : cas AC1 (Trémie bloquée), AC2 (P1 passant,
  Maintenance bloquée), AC3 (protection terminale intacte).
- Enregistrer les TC dans le registre TC (`TOOLS/TEST_AUTO_CI/scripts/registry.yaml` ou équivalent).

### Phase 5 — Vérification mécanique bloquante (bloque_par: Ph.3 + Ph.4)
- `python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .`
- `python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report`
- `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C`
- `python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T204.yaml`
- Collecte `evidence_required` du contrat (linkage, gates, bundle, diff_scope).

### ⛔ ARRÊT VALIDATION #2 — restitution finale + visa humain (C2 / C4 voie safety si touche)
- Bandeau de conformité + lecture du `git diff` réel par l'orchestrateur/humain.
- Intégration CODESYS manuelle (import ST + bundle) par l'utilisateur, jamais par l'agent.

---

## 4 · Plan de TEST

### 4.1 Cas à couvrir (matrice AC ↔ cas ↔ TC)
| Cas | Description | AC | TC / outil |
|---|---|---|---|
| T-01 | `Direction=+1`, `TremiePermit=FALSE` → `EffectiveSafeStop`=TRUE, rampe=0 | AC1 | unitaire FB_Translation (stimulus) |
| T-02 | `Direction=+1`, `TremiePermit=TRUE` → pas de blocage Trémie | AC1 | unitaire FB_Translation |
| T-03 | `Direction=-1`, `MaintenancePermit=FALSE`, cible=Maintenance → rampe=0 | AC2 | unitaire/sim (requête Maintenance) |
| T-04 | `Direction=-1`, `MaintenancePermit=FALSE`, cible=P1 → P1 atteint, non bloqué | AC2 | sim SEMI_AUTO cible P1 |
| T-05 | `Direction=-1`, `MaintenancePermit=TRUE` → pas de blocage Maintenance | AC2 | unitaire FB_Translation |
| T-06 | Coupure dure `M3_LimitSwitchMaintenanceEffective` toujours armée | AC3 | TC-P11-003/004/013, sim |
| T-07 | Interlocks sécurité M3 inchangés (Méca A/B, PowerCutOff, SafeStop) | AC7 | TC-P11-002/010/011/014 |
| T-08 | Bits IHM `TranslationM3.Safety.*` cohérents avec le gate | AC6 | test IHM (PRG_07) |
| T-09 | Diffusion du gate : verrous bistables / estimateur / PositionSensorTarget informés | AC1 | inspection + G200 |

### 4.2 TC existants de référence (ne pas casser)
`TC-P11-002, 010, 011, 014` (sécurité M3, C4) · `TC-P11-003/004/005/013` (vitesse/interlock, FB_Translation).
Ajout : nouveaux TC pour AC1/AC2/AC3 (plage TC-P11 libre, voir AF-P11 §1).

---

## 5 · Plan CI & Gates

| Étape | Gate / commande | Résultat attendu |
|---|---|---|
| Après Ph.1/Ph.2 (docs seuls) | `G340_check_doc_links.py --fix` | PASS (liens AF cohérents) |
| Après Ph.3 (code) — palier A/B sur bloc isolé | `run_all_gates.py --palier A` puis `--palier B` | PASS bloc isolé + liens |
| Après Ph.4 (tests) | `pytest TOOLS/TEST_AUTO_CI/TEST_AUTO_CI_UNITARY/I_TRANSLATION` | PASS |
| Après Ph.5 — **palier C (fin de lot)** | `generate_codesys_bundle.py .` → `G200_check_linkage.py --report` → `run_all_gates.py --palier C` | Bundle frais + linkage 0 erreur + palier C 100% |
| Contrat | `check_task_contract.py TASK_CONTRACT_T204.yaml` | PASS |
| Clôture | `run_all_gates.py` (tout) + restitution diff | PASS complet |

- **Palier A/B** : G100/G110 (rapides) puis G200/G210 — sur bloc isolé avant le palier C.
- **Palier C** : G300..G420 — obligatoire avant annonce de fin de lot.

---

## 6 · Prévision d'assignation AGENT

| Rôle | Agent proposé | Tâche |
|---|---|---|
| Cadrage/Spec AF (§3ter) | DSH (DeepSeek) | Rédiger décision P1 + enrichir AF-P11 §3ter |
| Implémentation ST (FB_Translation) | DSH (DeepSeek) ou sous-agent expert FB | Extension `EffectiveSafeStop` selon règle validée |
| CI & registre TC | DSH (DeepSeek) ou spécialiste CI | Étendre tests I_TRANSLATION + registre |
| **Revue indépendante** | **Agent distinct** (ex. Codex / modèle différent, `workflow` provider override) | Relire le `git diff` réel, vérifier AC4/AC7, challenger la règle P1 |
| **Visa humain** | Humain / orchestrateur | ARRÊTS VALIDATION #1 et #2 (obligatoires, C2) |

> ⚠️ La validation finale doit toujours revenir à l'orchestrateur/à l'humain (lecture du diff réel),
> jamais à l'agent qui a écrit le code (`AGENTS.md §Délégation`).

---

## 7 · Modifications DOC à prévoir

| Doc | Nature de la modification |
|---|---|
| `DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md` §3ter | Décrire le gate effectif des 2 sens + règle P1 + référence `FB_Winch.st:163` |
| Fiches `AF_Partie-11_Fonction_Translation/FB_Translation_v1.1.md` (+ `FB_TranslationCmdArbitrationM3` si retenu) | Interface + logique gate |
| `DOC/STDS/NAMING_CONVENTION.md` | **Aucune** (hors scope, forbidden) |
| Registres (TC, `GVL_Troubleshooting`, snapshot troubleshooting) | Ajouter les nouveaux TC et les signaux gate/trace si nouveaux |
| `DOC/VERSION_HISTORY.md` | Une ligne par jalon (AF-P11 §3ter / gate T204) |
| `DOC/WFLOW/TASKS.yaml` | Statut T204 ⏳→✅ + `contrat:` renseigné + horodatages |

---

## 8 · Arrêts de validation humaine

| Arrêt | Criticité | Obligation |
|---|---|---|
| **ARRÊT VALIDATION #1** (fin Ph.2/Ph.3, avant code) | C2 | Choisir le point d'insertion + valider la règle P1 (AC2/AC5). Aucun code sans visa. |
| **ARRÊT VALIDATION #2** (fin Ph.5, restitution) | C2 / C4 voie safety | Visa humain + intégration CODESYS manuelle par l'utilisateur. Bandeau de conformité. |

> Si le gate devait toucher la logique safety de `FB_Safety_Translation` (interdit par le contrat),
> la criticité passerait à **C4** et un arrêt de validation supplémentaire voie safety serait requis.

---

## 9 · Références croisées

- Contrat : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T204.yaml`
- Spec : `DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md` §3ter
- Modèle : `CODE/H_TREUILS_BENNE/FB_Winch.st` l.163
- Site cible : `CODE/I_TRANSLATION/FB_Translation.st` §4bis/§5
- CI : `TOOLS/TEST_AUTO_CI/TEST_AUTO_CI_UNITARY/I_TRANSLATION/`
