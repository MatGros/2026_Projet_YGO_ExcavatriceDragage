# 🎯 BRIEF — T330 PHASES P1/P2 : plan v1.2 + matrice de tests figée (ZÉRO code ST)

> **À copier-coller en tête de la mission déléguée :** le contenu **intégral** de
> `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` (préambule obligatoire du projet).
> Ce brief **ne le remplace pas**.

```
════════════════════════════════════════════════════════════
MISSION T330 — PHASES P1/P2 : plan v1.2 + spécification des tests
Criticité C2→C3 · Verrou 🔒 T330 = DSH01 · Orchestrateur : CC01
Date : 2026-09-20
Rédigé par : DSH01 (titulaire du verrou T330, auteur du cadrage et du plan v1.1)
════════════════════════════════════════════════════════════
```

---

## 0 · PRÉREQUIS D'ENTRÉE — à vérifier AVANT de commencer

| # | Prérequis | Où | Si absent |
|---|---|---|---|
| 1 | **Verrou `T330` = toi.** Si tu n'es pas `DSH01` → **STOP**, remonte (`DOC/WFLOW/TASK_LOCKS.json`) | `work_locks.T330` | STOP |
| 2 | Lire `AGENTS.md`, `CODE_QUALITY_STANDARDS.md`, `NAMING_CONVENTION.md` | — | — |
| 3 | **Cadrage** : `DOC/WFLOW/AUDITS/DESIGN/CADRAGE_T330_INVARIANT_HAUT_v1.0.md` (§0bis décisions, §0ter pièges, §2.3/§2.3bis/§2.3ter) | — | STOP |
| 4 | **Plan à réviser** : `DOC/WFLOW/AUDITS/DESIGN/PLAN_T330_C3_INVARIANT_HAUT_v1.0.md` — **révision interne v1.1**, journal d'audit **§11** | — | STOP |
| 5 | **Contrat** : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T330_HOMING_TOP_SOFT_LIMIT_INVARIANT.yaml` (AC1→AC7) | — | STOP |

**Maintien T291-B : LEVÉ** (B1 remis, commit `55700932`, validation utilisateur 2026-09-20). T291-B B2 attend T330.

---

## 1 · POSTURE (non négociable)

- 🛡️ **Tu challenges les arbitrages ci-dessous.** Si l'un contredit le **code réel** ou une **règle de
  sécurité**, tu le **prouves `fichier:ligne`** et tu **t'arrêtes**. Tu ne les recopies **jamais** comme
  des faits.
- ⛔ **Zéro code ST, zéro `CODE_XML/`, zéro IHM, zéro `Device.export`** dans ce lot. **Zéro modification
  non nécessaire.**
- ✍️ **Un seul écrivain : toi**, sur les **docs T330 uniquement**.
- 🚨 **Devoir d'alerte** : toute incohérence remonte **immédiatement**, jamais à la fin, jamais en silence.
- 🔬 **Signaler n'est pas élargir.** On attend le signalement, pas la correction spontanée.

---

## 2 · ARBITRAGES HUMAINS 2026-09-20 (à intégrer, et à **challenger**)

| # | Arbitrage | Statut |
|---|---|---|
| **Q17** | **Préserver le TOP** (`CfgTopSensorPos_M`) ; corriger le FDC : `CfgCableLimitAscent_M := TOP − 1,00` | ✅ retenu |
| **Q23** | **Option A** : normalisation **AVANT** les bridges, référence lue sur le **persistant** (pattern `PRG_07:187-196`) ⇒ **Q19 et Q20 sans objet** | ✅ retenu |
| **Q21** | **Bornes absolues** : `FDC ∈ [0 ; 10 m]`, `TOP ∈ [1 ; 10 m]`. ⚠️ **Confronter aux bornes existantes** (cadrage §2.1) ; **conflit ⇒ remonter, ne pas trancher seul** | ⚠️ **voir §3.1 — CONFLIT PROUVÉ** |
| **Q22** | **Aucune inhibition pendant homing** : « le TOP n'est jamais déplacé par la normalisation » | ⚠️ **voir §3.2 — CONTRADICTION INTERNE** |
| **Q24** | Correction **à sens unique** ⇒ pas de rebond ; **à PROUVER par un test 2 scans** | ✅ retenu (voir §3.3) |
| **Q27** | **AUCUNE tolérance `eps`** ; règle **stricte** `Δ ≥ 1,00 m` (Sterbenz ⇒ différence **exacte**) | ✅ retenu |
| **Q18** | Bande `0,50 m` **non mesurée** : risque **accepté**, mesure en **recette P5** | ✅ retenu |
| **Q28** | **Résolu** (B1 remis) | ✅ fermé |

---

## 3 · ⚠️ CHALLENGES À TRAITER — déjà identifiés par l'orchestrateur (à **revérifier** puis trancher/remonter)

> Ces deux points ont été **prouvés par l'orchestrateur rédacteur** avant rédaction du brief. **Vérifie-les
> toi-même** : s'ils tiennent, **remonte-les** — ils **bloquent P1/P2** tant qu'ils ne sont pas arbitrés.

### 3.1 🔴 Q21 : la borne `FDC ∈ [0 ; 10]` est **mathématiquement incompatible** avec Q1

L'invariant Q1 impose `TOP − FDC ≥ 1,00 m`, soit `FDC ≤ TOP − 1,00`.
Avec la borne Q21 `TOP ≤ 10,00 m` :

```
FDC ≤ TOP − 1,00  et  TOP ≤ 10,00   ⇒   FDC ≤ 9,00 m
```

⇒ **`FDC = 10,00` est IMPOSSIBLE** (il exigerait `TOP ≥ 11,00`, hors borne).
⇒ **Conséquence sur R2** (arbitrage Q17 : `TOP := FDC + 1,00`) : dès que `FDC > 9,00`,
**R2 produit un TOP hors de la borne déclarée** ⇒ soit violation de la borne, soit boucle non bornée.

**Borne cohérente proposée** : `FDC ∈ [0 ; 9,00 m]` **et** `TOP ∈ [1 ; 10,00 m]` (avec l'invariant).
⛔ **Ne tranche pas seul** : c'est une **borne de sécurité** ⇒ remonter à l'orchestrateur.

### 3.2 🔴 Q22 : « le TOP n'est **jamais** déplacé » **contredit R2**

Q22 justifie « aucune inhibition pendant homing » par le fait que *le TOP n'est jamais déplacé*.
Or **R2 déplace précisément le TOP** : quand l'opérateur saisit un TOP trop bas,
`CfgTopSensorPos_M := CfgCableLimitAscent_M + 1,00`.

Or `CfgTopSensorPos_M` **est la cible de homing** : `PRG_02:529` (`CfgTopHomingTarget_M`),
`:601` (M1), `:655` (M2), lues **chaque scan** sur le **persistant**.

⇒ **Deux lectures possibles — il faut trancher** :
- **(a)** R2 **doit être inhibé** pendant `InReferencingMode` / transaction preset en cours ;
- **(b)** l'énoncé Q22 est **inexact** et doit être reformulé (« le TOP n'est déplacé **que** par R2, sur
  saisie opérateur explicite »), en assumant le déplacement de cible.

⚠️ Rappel : la cible de `FB_Encoder_Homing` est **capturée au déclenchement** (`:216-223`) — le risque
porte sur le **prochain** homing et sur `FB_CycleMachineHoming` (séquence HX0..HX6 **distincte**) → **Q13**.

### 3.3 ⚠️ Q24 : le test « 2 scans » **ne couvre pas** le rebond réel

Le test 2 scans prouve la **non-récorrection interne** (R1 abaisse le FDC ⇒ `Δ = 1,00` ⇒ condition fausse
⇒ pas de 2ᵉ passe). ✅ Suffisant **avec Q27** (aucun `eps`, donc égalité **exacte**).
⛔ **Mais il ne couvre PAS** le rebond par **guerre d'écriture IHM** (panneau qui réécrit la valeur
invalide ⇒ nouveau front ⇒ correction + message **en boucle**). **Q12 reste ouverte** ⇒ l'exigence
d'**idempotence** (§2.4 du plan) est **indémontrable en l'état**. À **tracer comme limite** du test.

### 3.4 ⚠️ Référence périmée à corriger

Le tableau des chantiers concurrents indique « `PRG_07 AnyFault :424-427` ».
**Vérifié** : `:424-427` = publications **`WinchSymmetry`** ; `AnyFaultActive` est en **`PRG_07:537-547`**.
⇒ **corriger la référence** partout où elle est recopiée.

---

## 4 · OBJECTIF

**Plan v1.2 exécutable** et **matrice de tests figée**, tels qu'
- un **implémenteur** puisse coder **P3 sans aucune question ouverte** ;
- un **reviewer** puisse juger **chaque AC** sur une **preuve**.

---

## 5 · PÉRIMÈTRE

| Autorisé (écriture) | Interdit |
|---|---|
`DOC/WFLOW/AUDITS/DESIGN/PLAN_T330_C3_INVARIANT_HAUT_v1.0.md` — **remplacé en place**, révision interne **v1.2** (⚠️ **ne pas** créer de `v1.2` en fichier séparé : une règle écrite deux fois dérive) | `CODE/` · `CODE_XML/` · types IHM · `Device.export` |
`CADRAGE_T330_INVARIANT_HAUT_v1.0.md` **si un fait change** | **G483 / G504** — **spécifiés, jamais écrits** |
`DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T330_*.yaml` | `TOOLS/` (tout) |
`af_traceability_matrix.yaml` — **lignes T330 uniquement** | `PRG_04_Treuils_Benne.st` (T291-B B2) |
`DOC/WFLOW/TASKS.yaml` — **champ `avancement` de T330 uniquement** (🚩 d'édition obligatoire) | Tout autre fichier |

🔒 **Protocole `task-planner`** pour toute écriture dans `TASKS.yaml` : lire `TASK_LOCKS.json`, vérifier
qu'aucun 🚩 d'un autre acteur n'est posé, poser le 🚩 **à ton nom**, écrire, **retirer le 🚩**.

---

## 6 · PHASES ET POINTS D'ARRÊT

| # | Contenu |
|---|---|
**1** | **Relire le code réel** (ne jamais croire le plan sur parole) : `PRG_07_Supervision.st:140-196` (bridges, miroir M2 `:154-155`, pattern pré-bridge `:187-196`) · `CODE/J_SUPERVISION/_BRIDGES/FB_CfgPersistBridge_CommunCfg.st` (⚠️ **chemin réel**, pas `J_SUPERVISION/` racine) · `ST_WinchCfg.st` · `ST_CommunCfg.st` · `G483` (`:15-16` docstring `MIN`, `:164-175` AC2b, `:166-170` helper mort) · `run_all_gates.py` `PLANS` (⚠️ paliers, `--full-ci`, G460) |
**2** | **Intégrer les arbitrages** ; **fermer Q17→Q28** ; **retirer les options mortes** (option B, `eps`, Q19/Q20) ; **ré-ouvrir toute question que le code réel contredit** |
**3** | **Matrice `Q → TC → oracle → preuve`**, IDs canoniques **`TC-P10-<NNN>`** (format `TC-P\d+-\d+`, `extract_functions_matrix.py:34`). **Cas minimum exigés** : boot NVRAM invalide (**2 champs au même scan**) · saisie FDC trop haut · saisie TOP trop bas · slowdown `< 0,50` · bornes `FDC = 0` / `TOP = 10` · **homing en cours pendant correction** · **non-rebond 2 scans** · **miroir M2 = M1 corrigé dès le 1er scan** · **état FDC et sorties PENDANT un mouvement** |
**4** | **Spécifier `G504`** (2 règles **séparées** ; enregistrement `PLANS` = **critère d'acceptation**) et le **plan de nettoyage complet de `G483`** (AC2b **+** docstring `:15-16` **+** helper mort) |
**5** | `check_task_contract.py` **PASS** · ⛔ **ARRÊT — restitution à l'orchestrateur** ; **P3 attend un GO distinct** |

---

## 7 · CRITÈRES TESTABLES (ta restitution se juge **contre eux**)

| AC | Critère | Preuve exigée |
|---|---|---|
**AC1** | Plan **v1.2 sans question bloquante ouverte** ; chaque décision **Q17→Q28 tracée avec sa source** | tableau de traçabilité dans le plan |
**AC2** | **Matrice complète** : chaque AC du contrat ↔ **≥ 1 TC** avec **oracle numérique** et **preuve** | matrice `AC → TC` |
**AC3** | **IDs conformes `G470`** ; unicité vérifiée ; `af_traceability_matrix.yaml` **à jour** | sortie de contrôle + diff |
**AC4** | **`G504` spécifié** (entrées, règles, sortie, enregistrement `PLANS`) ; **`G483` : liste EXACTE des lignes à retirer** | spécification numérotée |
**AC5** | `check_task_contract.py` **PASS** | sortie brute collée |
**AC6** | **Aucun fichier hors périmètre** dans `git status --short` | sortie brute collée |

⚠️ Un **critère sans moyen de vérification n'est pas un critère** → le **signaler**, ne pas deviner.

---

## 8 · PREUVES MÉCANIQUES À PRODUIRE

Ce lot **ne produit pas de code** ⇒ **pas de bundle, pas de `G200`** (un cadrage n'en exige pas).
✅ En revanche : **`check_task_contract.py` PASS** + **`git status --short`** (AC5/AC6), sorties **brutes**.

---

## 9 · SOUS-AGENTS AUTORISÉS

**1 challenger `read-only`, contexte frais, sur le plan v1.2** — comme pour la v1.0 (il avait trouvé
**8 erreurs**). Consignes à lui donner : préambule + plan v1.2 + cadrage + contrat ; demander
explicitement de chercher : **affirmations non prouvées sur le code**, **arithmétique fausse**,
**cas de test manquants**, **questions à ajouter**, **incohérences contrat ↔ plan**, **contradictions
avec le code réel**. ⚠️ **Ses dires ne sont pas des preuves** : tu les **vérifies sur le code** et tu
**arbitres**.

---

## 10 · CHANTIERS CONCURRENTS — **ne pas écrire dans ces fichiers**

| Tâche | Agent | Fichiers | État | Impact T330 |
|---|---|---|---|---|
| **T255-D** | ⚠️ **verrou à poser** | `FB_Hmi_BannerFormatter.st`, `PRG_07` (`AnyFaultActive` **`:537-547`** ⚠️ réf. `:424-427` **périmée**) | ⏳ | 🔴 **même `PRG_07`** ⇒ **T330 P3 ne démarre qu'après sa livraison** |
| **T291-B** | AGY01 | `PRG_04`, `G499`→`G505` | B2 **attend T330** | 🔴 `PRG_04` interdit |
| **T300 P-A** | CDX01 🔒 | `L_SIMULATION` | en cours | — |
| **T333** | verrou à venir | `FB_Translation_PositionEstimator` | en cours | — |
| **T328** | DSH01 🔒 | `FB_SimBench.st` | ⏳ **non livrée** | — |
| **T327** | CC01 🔒 | (`ManualBucketLimits`) | ⏳ **non livrée** | — |
| **T332** | en cours | hooks | outillage | — |

---

## 11 · RESPONSABILITÉ ET FORMAT DE RESTITUTION

- Tu es **garant du plan et des preuves** ; tu **vérifies les dires du challenger sur le code réel**.
- ⛔ **Aucun commit, aucun push.**
- 📊 **Checkpoint `agent_heartbeat.py`** — session `T330-P1P2`, agent **`DSH01`** :
  `python TOOLS/AGENT_WORKFLOW/scripts/agent_heartbeat.py record T330-P1P2 <ETAPE> <etat> --agent DSH01 --msg "<résumé>"`

### Restitution attendue
1. **Verdict** (`PASS` / `ALERTE` / `BLOCK`)
2. **Fichiers touchés** (chemins exacts)
3. **AC1 → AC6** avec **preuve** pour chacun
4. **Questions ré-ouvertes** si le code contredit un arbitrage (dont §3.1 et §3.2)
5. **Risques résiduels** (dont **Q18** bande `0,50 m` non mesurée, **Q12** guerre d'écriture, **Q5** datum)
6. **Bandeau** de fin explicite

---

## 12 · RAPPEL DES DÉCISIONS Q1/Q2 (ne pas les rediscuter)

```
Q1 : ReserveTop_M = CfgTopSensorPos_M − CfgCableLimitAscent_M ≥ 1,00 m
     ET WinchSlowdownDistanceTop_M ≥ 0,50 m   (deux règles DISTINCTES, contrôlées séparément)
     ⛔ règle historique « réserve ≤ ralentissement » ABROGÉE

Q2 : NORMALISATION (ni refus, ni état invalide)
     FDC trop haut  => CfgCableLimitAscent_M := CfgTopSensorPos_M − 1,00
     TOP trop bas   => CfgTopSensorPos_M     := CfgCableLimitAscent_M + 1,00
     slowdown < 0,50=> WinchSlowdownDistanceTop_M := 0,50
     + message IHM non alarmant, immédiat
     ⛔ PRÉSERVER le réglage NON modifié
```
