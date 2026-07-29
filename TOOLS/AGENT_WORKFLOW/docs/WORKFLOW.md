# Workflow agents CODESYS

## Flux obligatoire

```text
Entrée (CODE_CHANGE ou NEW_INFORMATION)
→ 🏷️ Qualification criticité C0-C4 (Pi propose → humain valide)
→ voie adaptée (Fast / Standard / Safety)
→ artefacts obligatoires selon voie
→ avis read-only si requis → **arrêt : validation humaine du plan** → modification → gates → rapport → traçabilité
```

## 🔀 3 Voies selon criticité

### ⚡ Fast Lane — C0-C1
> Typo, renommage, doc, param mineur, refactor sans impact safety.

```text
Pre-edit Gate → Plan → **validation humaine** → Code → Gates 1-4 → ✅
```
- Pas de multi-modèle, pas de REGISTRE, pas de revue Herdr.
- Gate 5 (compilation CODESYS) optionnel.

### 🔵 Standard Lane — C2-C3
> Nouveau FB, évolution feature, mouvement/interlock.

```text
Pre-edit Gate
→ REGISTRE_ACTIONS (proposé par Pi)
→ TASK_CONTEXT.yaml (proposé par Pi)
→ 0 ou 1 avis Pi Subagent ciblé (read-only)
→ Plan → **validation humaine obligatoire** → Code → Gates 1-5
→ revue complémentaire seulement si anomalie ou demande humaine
→ ✅ Rapport
```
- REGISTRE et TASK_CONTEXT proposés, non bloquants si refusés.
- 1 seul agent en revue (pas de double).

### 🔴 Safety Lane — C4 (et C3 safety détectée)
> AU, PowerCutOff, SafeStop, frein, contacteur, redondance, homing safety, FAT/SAT.

```text
Pre-edit Gate
→ REGISTRE_ACTIONS (obligatoire)
→ TASK_CONTEXT.yaml (obligatoire)
→ TEST_DESIGN.md (obligatoire)
→ ⚠️ ALERTE RISQUES explicite
→ 🔴 DOUBLE AVIS Pi Subagents PARALLÈLES A/B (read-only, même contexte, sans se voir)
→ synthèse : consensus ✅ / divergence 🚨
→ **validation humaine obligatoire : artefacts + plan + décision safety**
→ Code ST (High Effort, un seul exécutant)
→ Gates 1-5 → CODESYS import → simulation CODESYS manuelle → Terrain
```

## 🔴 Règle Double Revue Parallèle (C4)

- **Scope** : TEST_DESIGN, ST généré, toute revue safety C4.
- **Méthode B — Parallèle** : les 2 agents reçoivent **exactement le même contexte**, sans connaissance du résultat de l'autre.
- **Résultat** :
  - Consensus (aucun blocage contradictoire) → synthèse présentée à l'humain.
  - Divergence (≥1 point contradictoire) → 🚨 alerte humain + résumé des 2 positions côte à côte.
- **Les agents ne commitent pas et ne modifient pas le code.**
- Ponytail interdit sur toute analyse safety.

## 🏷️ Qualification criticité

Pi qualifie et propose, l'humain valide en 1 mot.

| Niveau | Exemple | Artefacts |
|---|---|---|
| C0 | format, typo | aucun |
| C1 | doc non-safety | aucun |
| C2 | code métier | REGISTRE + TASK_CONTEXT (proposés) |
| C3 | mouvement/interlock | REGISTRE + TASK_CONTEXT + TEST_DESIGN (proposés) |
| C4 | safety critique | REGISTRE + TASK_CONTEXT + TEST_DESIGN (obligatoires) + alerte risques |

## Règles générales

- 📌 **Tout sous-agent (Pi worker/reviewer, Claude, Codex, antigravity) reçoit
  `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` en tête de sa tâche.** Un sous-agent
  démarre froid : sans ce préambule il ne connaît ni les règles, ni les cas d'arrêt, ni la
  vérification de liaison — c'est ce qui a laissé passer le bug `PRG_10_Outputs_LD`.
- 🤖 **Aucun lot n'est restitué sans `check_linkage.py --report`.** Bundle généré et tests Python
  verts ne prouvent jamais qu'une fonction est reliée.
- `TOOLS/` reste séparé de `DOC/` et `CODE/`.
- `ST_PLCOPENXML_GENERATOR` reste autonome ; le workflow peut l'appeler.
- Les scripts déterministes vérifient avant l'avis des modèles.
- Aucun commit automatique — validation humaine obligatoire.
- Toute modification safety exige une validation humaine.
- Ponytail est interdit dès qu'un sujet safety, norme ou redondance est détecté.
- Les avis passent par Pi Subagents et restent read-only. Ils sont toujours attendus, lus et
  synthétisés avant le plan ; aucun avis n'est lancé en arrière-plan.
- Herdr est un secours explicite uniquement. S'il est utilisé, suivre le cycle bloquant
  `start → handshake → wait → read → mission → wait → read → contrôle` décrit dans
  `INTEGRATIONS.md`.

## 🔄 Règle d'apprentissage continu (Double boucle)

Toute erreur détectée — **à n'importe quelle étape** (édition, gate, compilation, test, audit, terrain) — déclenche **deux actions** :

1. **`fix:`** — Correction locale de l'erreur (code, doc, config)
2. **`guard:`** — Garde-fou technique ajouté dans `TOOLS/AGENT_WORKFLOW/scripts/` ou templates pour que **cette classe d'erreur soit détectée automatiquement plus tôt** la prochaine fois

### Exemples de correspondance

| Origine erreur | Garde-fou ajouté |
|---|---|
| **Instance déclarée jamais appelée (`PRG_10_Outputs_LD`, 2026-07-29)** | **`check_linkage.py` — gate 2bis + hook PostToolUse** |
| **Consignes pointant des specs supprimées** | **`check_doc_links.py` (+ `--fix` automatique)** |
| **Document amputé de sa tête sans être vu (`NAMING_CONVENTION`)** | **`check_doc_links.py` D6 — titre H1 obligatoire** |
| **Sous-agent démarrant sans les règles projet** | **`prompts/subagent_preamble.md` obligatoire en tête de tâche** |
| Compilation CODESYS C0037 | Règle `check_code_style` détection écriture VAR_OUTPUT |
| Oubli homme-mort boutons | Pattern `StartStop.*DeadmanArmed` obligatoire |
| FDC sans rampe | Template `motion_fb_header` section FDC_EXTRÊMES |
| Bit safety non classifié | Template `requirement_intake` champ `safetyClassification` |
| Struct IHM incomplète | Script `doc_sync` compare AF07 ↔ CODE/SUPERVISION |

### Processus

```text
Erreur détectée
    ↓
Analyse cause racine (5 pourquoi)
    ↓
fix: correction immédiate
guard: gate/template/script ajouté dans TOOLS/
    ↓
Validation : gate suivant attrape la régression
    ↓
Commit unique : fix + guard ensemble
```

## Entrées

- `CODE_CHANGE` : modification issue du programme ou d'un bug identifié.
- `NEW_INFORMATION` : donnée client, réunion, chantier, essai ou observation terrain.

`NEW_INFORMATION` passe obligatoirement par le refinement avant toute modification DOC/CODE.

## Criticité

| Niveau | Exemple | Traitement |
|---|---|---|
| C0 | format, typo | contrôle simple |
| C1 | documentation non-safety | modèle économique + review |
| C2 | code métier | modèle code + tests |
| C3 | mouvement/interlock | modèle fort + review read-only |
| C4 | AU, PowerCutOff, redondance | plan humain obligatoire, Ponytail interdit |
