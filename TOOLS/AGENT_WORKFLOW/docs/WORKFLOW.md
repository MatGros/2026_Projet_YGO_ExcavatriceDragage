# Workflow agents CODESYS

## Flux obligatoire

```text
Entrée (CODE_CHANGE ou NEW_INFORMATION)
→ 📚 Prise de connaissance (AF + état d'ensemble du programme) — AVANT de planifier
→ 🏷️ Qualification criticité C0-C4 (Pi propose → humain valide)
→ 🔀 Stratégie patch / rebuild (Pi propose → humain valide)
→ voie adaptée (Fast / Standard / Safety)
→ 📝 CONTRAT DE TÂCHE : objectifs testables (obligatoire dès C2)
→ artefacts obligatoires selon voie
→ avis read-only si requis → **arrêt : validation humaine du plan** → modification → gates → rapport → traçabilité
```

## 🧭 Deux axes indépendants — ne pas les confondre

La criticité dit **combien de cérémonie**. La stratégie dit **quelle forme prend le travail**.
Les deux se combinent : un `C4 + rebuild` cumule la double revue A/B **et** le contrat de
conservation. La cérémonie safety n'est jamais allégée par le choix de stratégie.

| | **Patch** — modifier l'existant | **Rebuild** — reconstruire le bloc |
|---|---|---|
| **Fast C0-C1** | cas courant | n'existe pas — un C0/C1 ne justifie jamais un bloc neuf |
| **Standard C2-C3** | voie standard | + **contrat de conservation** validé avant toute coupure |
| **Safety C4** | voie safety complète | voie safety **et** contrat de conservation |

### 🔀 Quand basculer en rebuild

**Un seul critère suffit** — ce ne sont pas des points à totaliser :

- les retouches seraient **dispersées** dans plusieurs POU ;
- l'interface doit changer de toute façon (nouvelles entrées/sorties) ;
- l'encapsulation actuelle est **fausse** : producteur multiple, GVL-canal-caché, internes traversés ;
- le FB a dérivé du contrat `AF_Partie-03` et accumule des responsabilités ;
- comprendre l'existant coûte **autant** que le réécrire.

En cas d'hésitation → **patch par défaut** : il est réversible, le rebuild beaucoup moins.

### 🧱 Séquence rebuild (obligatoire si stratégie = rebuild)

```text
1. Inventaire du périmètre    → check_linkage.py donne les consommateurs
2. CONTRAT DE CONSERVATION    → ce qui doit survivre / ce qu'on abandonne sciemment
   ⛔ arrêt : validation humaine du contrat AVANT toute suppression de lien
3. Nouveau FB, interface propre
4. Remap des consommateurs
5. Preuve de non-dégradation  → chaque ligne du contrat vérifiée
6. Suppression de l'ancien    → check_linkage.py prouve zéro orphelin
```

⚠️ **Écrire ce qui doit survivre AVANT de couper.** Sans ce contrat écrit en amont,
« pas de dégradation » n'est qu'une impression.

## 📝 Contrat de tâche — la référence de toute vérification

> REX 2026-07-29 : sur 53 tâches déléguées, les critères d'acceptation étaient **3 phrases
> génériques** réutilisées telles quelles. Un agent rendait donc un rapport « conforme » à rien.
> Une vérification qui ne porte sur aucun objectif reste creuse, même rendue obligatoire.

Rédigé par l'**orchestrateur**, **avant** toute écriture ou délégation. Obligatoire dès **C2**.

- Gabarit : `TOOLS/AGENT_WORKFLOW/templates/task_contract.yaml`
- Emplacement : section `contract:` du `TASK_CONTEXT.yaml` de la tâche
- Contrôle : `python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py <fichier>`

Il porte : objectif métier · **critères testables** (chacun avec son `verified_by`) · périmètre
autorisé/interdit · contrat de conservation si rebuild · preuves attendues · modèles autorisés ·
devoir d'alerte.

🔁 **Il traverse les trois runtimes** — c'est son intérêt principal : les hooks ne couvrent que
l'orchestrateur Claude Code, le contrat s'applique aussi aux sous-agents Pi (ses critères
remplacent le boilerplate de l'*acceptance contract*) et aux agents externes.

## 🔀 3 Voies selon criticité

### ⚡ Fast Lane — C0-C1
> Typo, renommage, doc, param mineur, refactor sans impact safety.

```text
hook PreToolUse (bloque si specs non lues) → Plan → **validation humaine** → Code → Gates → ✅
```
- Pas de multi-modèle, pas de REGISTRE, pas de revue Herdr.
- Gate 5 (compilation CODESYS) optionnel.

### 🔵 Standard Lane — C2-C3
> Nouveau FB, évolution feature, mouvement/interlock.

```text
hook PreToolUse (bloque si specs non lues)
→ CONTRAT DE TÂCHE (obligatoire)
→ REGISTRE_ACTIONS (proposé par Pi)
→ TASK_CONTEXT.yaml (proposé par Pi)
→ 0 ou 1 avis Pi Subagent ciblé (read-only)
→ Plan → **validation humaine obligatoire** → Code → Gates → hook Stop
→ revue complémentaire seulement si anomalie ou demande humaine
→ ✅ Rapport
```
- REGISTRE et TASK_CONTEXT proposés, non bloquants si refusés.
- 1 seul agent en revue (pas de double).

### 🔴 Safety Lane — C4 (et C3 safety détectée)
> AU, PowerCutOff, SafeStop, frein, contacteur, redondance, homing safety, FAT/SAT.

```text
hook PreToolUse (bloque si specs non lues)
→ CONTRAT DE TÂCHE (obligatoire)
→ REGISTRE_ACTIONS (obligatoire)
→ TASK_CONTEXT.yaml (obligatoire)
→ TEST_DESIGN.md (obligatoire)
→ ⚠️ ALERTE RISQUES explicite
→ 🔴 DOUBLE AVIS Pi Subagents PARALLÈLES A/B (read-only, même contexte, sans se voir)
→ synthèse : consensus ✅ / divergence 🚨
→ **validation humaine obligatoire : artefacts + plan + décision safety**
→ Code ST (High Effort, un seul exécutant)
→ Gates → hook Stop (bloque si liaison rouge) → CODESYS import → simulation CODESYS manuelle → Terrain
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
- `ST_PLCOPENXML_GENERATOR` reste autonome ; le workflow peut l'appeler pour générer le bundle `CODE/CODE_Bundle.xml` à partir des sources ST et des POU XML natifs/CFC présents dans `CODE/`.
- Les agents ne modifient pas le XML final du bundle à la main ; ils préservent les sources ST/XML natif/CFC et la cohérence des interfaces, noms et références avant génération.
- `OUTILS_ST2PY` est un outil externe de simulation et de tests hors-PLC ; il sert à valider la logique et la non-régression, mais ne remplace ni la compilation CODESYS ni les essais terrain.
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
