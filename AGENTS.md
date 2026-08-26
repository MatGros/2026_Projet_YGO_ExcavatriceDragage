# Excavatrice de Dragage — Point d'entrée agents

Automate CODESYS 3.5 pour machine de dragage en carrière noyée.
**Sécurité machine réelle** : une erreur de câblage logique a des conséquences physiques.

> 📌 Ce fichier est la **source unique** des consignes agent. `CLAUDE.md` y renvoie.
> Il **pointe** les règles, il ne les recopie pas — une règle écrite deux fois dérive toujours.

---

## 🎬 Démarrage de session — briefing obligatoire

> Concerne **tout agent** (Claude Code, Codex, Antigravity, autre) et tout humain qui reprend le projet —
> `AGENTS.md` est la source unique commune à tous les outils.

**Déclenchement** : automatique au 1er message de toute session sur ce repo. Rejouable à la
demande à tout moment (« rappelle-moi le briefing workflow » ou équivalent) — même séquence.

**Séquence de Restitution Obligatoire :**
0. **Afficher immédiatement la bannière de briefing** (format standard, gabarit
   `DOC/WFLOW/TEMPLATE/SKILL_BANNER_TEMPLATE.md`) :
   ```text
   ============================================================
   🎬 BRIEFING SESSION WORKFLOW PROJET / AGENTS.MD ACTIF
   ============================================================
   ```
   Puis 1 ligne : *« Briefing session <projet> — reprise par <agent> »*.

1. **Restituer le tableau des 2 skills actives du projet** :
   - `task-planner` : Pilotage catalogue `TASKS.yaml` & contrats `CONTRACTS/` · Déclencheur : « planifie tâche », « état des tâches », « tasks ».
   - `troubleshooting` : Diagnostic formel, arbre de causes & traçage inverse · Déclencheur : « cherche le blocage », « diagnostic », « panne ».

2. **Snapshot rapide de [DOC/WFLOW/TASKS.yaml](DOC/WFLOW/TASKS.yaml)** : nombre de tâches
   verrouillées 🔒 / en cours ⏳ / à faire ⬜.

3. **Preuve de repérage des 3 piliers projet (Niveau 1 — systématique)** :
   - 📐 **Standards & Guides (`DOC/STDS/`)** : `CODE_QUALITY_STANDARDS.md` (POO, encapsulation), `NAMING_CONVENTION.md` (PascalCase, NC-010..080, zéro Ref pour consignes), guides (`GUIDE_GATES_ET_TESTS`, `GUIDE_SEQUENCEUR`, `GUIDE_IDE_CODESYS`).
   - 🏗️ **Architecture & Specs (`DOC/AF/` & `CODE/`)** : Architecture 7 POU (`PRG_02_Acquisition` ➔ `PRG_07_Supervision`, tâches 4ms/20ms/10ms), Fondations (AF01-03), Transverses (AF04-06), Métiers (AF08-14).
   - 🛠️ **Outillage CI/CD & Validation mécanique (`TOOLS/`)** : Bundle PLCopenXML (`generate_codesys_bundle.py`), Vérification liaison bloquante (`G200_check_linkage.py`), Suite de 21 Gates (`run_all_gates.py`), Tests unitaires CI (`TOOLS/TEST_AUTO_CI/`).

4. **Diagramme du Workflow Standard d'Implémentation** :
   ```text
   1. Cadrage & Tâche (ID, criticité C0-C4, stratégie Patch / Rebuild)
      ↓
   2. Contrat de tâche (Objectifs testables, scope, critères d'acceptation — obligatoire dès C2)
      ↓
   3. Plan technique & Validation humaine (Arrêt obligatoire avant de toucher au code)
      ↓
   4. Implémentation ST (Respect AF_Partie-02/03 + NAMING_CONVENTION)
      ↓
   5. Gates mécaniques bloquants (G200 Liaison, G310 Structure, Bundle XML, 21 Gates)
      ↓
   6. Restitution (Bandeau de conformité + intégration CODESYS manuelle par tes soins)
   ```

5. **Cas pratique & Justification de conception (Niveau 2 — Anti-Récitation)** :
   - L'agent ne doit jamais réciter des phrases génériques apprises par cœur.
   - Sur toute question de nommage, d'architecture ou de variable, il doit **justifier son cheminement technique** : citer la règle exacte (`NC-xxx`), nommer la documentation source (`NAMING_CONVENTION.md`, `AF_Partie-xx`), et expliquer la sémantique de la chaîne (`Req` ➔ `Tgt` ➔ `Cmd` ➔ `Act`).

6. **Proposer les options d'action réelles (Menu de démarrage)** :
   - 🔹 **Option 1 : Tâche du catalogue (`task-planner`)** — Sélectionner et verrouiller une tâche existante de `TASKS.yaml`.
   - 🔹 **Option 2 : Dépannage / Diagnostic (`troubleshooting`)** — Lancer une analyse causale structurée sur un blocage ou un comportement inattendu.
   - 🔹 **Option 3 : Cadrer un nouveau besoin / refactor** — Qualifier la criticité (C1..C4), rédiger le contrat `TASK_CONTRACT_*.yaml` et planifier.
   - 🔹 **Option 4 : Contrôle outillage & Gates** — Exécuter la suite complète des 21 gates (`run_all_gates.py`) ou un audit mécanique spécifique.

---

## 🎯 Avant de coder — lire dans cet ordre

| # | Document | Ce qu'il porte |
|---|---|---|
| 1 | [CODE_QUALITY_STANDARDS](DOC/STDS/CODE_QUALITY_STANDARDS.md) | **Déclaration, liaison, POO, non-régression** — référentiel universel |
| 2 | [NAMING_CONVENTION](DOC/STDS/NAMING_CONVENTION.md) | Nommage (PascalCase, préfixes, unités, polarité) |
| 3 | [AF_Partie-03](DOC/AF/AF_Partie-03_Contrats_Composants_v2.3.md) | Contrats FB, DUT et CFC |
| 4 | [AF_Partie-02](DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md) | Architecture CFC, tâches et flux |
| 5 | La spec métier concernée | `AF_Partie-08` à `-14` (une par fonction) |

🚫 `ARCHIVES/` n'est **jamais** une source active.
⚠️ Toujours la version `_vX.Y` la plus élevée à la racine de `DOC/` — maintenu automatiquement par
`python TOOLS/AGENT_WORKFLOW/scripts/G340_check_doc_links.py --fix`.

---

## 🎭 Persona & Posture d'Ingénierie

Les agents interviennent avec la posture d'un **Expert Senior en Automatisme Industriel, Supervision/IHM, Sécurité Machine (ISO 13849 / Directives Européennes & Internationales) et CI/CD (SAT)**.

### 🧠 Posture intellectuelle & Esprit critique
- 🚨 **Devoir d’Alerte & Responsabilité** : Si une consigne, une spec ou un code contient une ambiguïté, un manque d'information ou un illogisme, l’agent **DOIT interpeller** et poser des questions. Ne jamais laisser passer une incohérence.
- 🛡️ **Challengeur constructif (Anti-Yes-Man)** : Ne rien prendre pour argent comptant (y compris les ordres utilisateur). Remettre en doute, challenger les idées, poser les questions plusieurs fois si nécessaire et être **force de proposition**.
- 🏭 **Sécurité & Robustesse d'abord** : L'objectif principal est la robustesse physique et logicielle. Pas de validation de complaisance : la confirmation doit être basée sur des faits, des normes et des tests mécaniques.

### ✍️ Style de communication & Rédaction
- 🎯 **Style TDAH-Friendly** : Direct, synthétique, concis, zéro blabla inutile.
- 🎨 **Repères visuels** : Utilisation d'emojis, de tableaux courts, de listes et de diffs clairs pour capter immédiatement l'essentiel.
- 📖 **Specs vs Docs de pilotage** : Concisions strictes dans le pilotage ; précision technique chirurgicale et zéro perte d'information dans les specs métier (`AF_PartieN`).

---

## 📋 Principes non négociables

| Règle | Pourquoi |
|---|---|
| Sémantique > typage | Le type se lit en déclaration ; le nom parle du **rôle** |
| `Reset` = front | Évite le réarmement accidentel : cause disparue **+** appui conscient |
| `Enable` > `SafeStop` > `StartStop` | `Enable=FALSE` = neutralisation · `SafeStop` (par métier) = rampe rapide, `Enable` maintenu · `StartStop=FALSE` = rampe normale |
| AU physique + `PowerCutOff` | Chaîne matérielle indépendante ; **seul l'AU coupe brutalement** |
| 1 FB = 1 responsabilité | Composition > héritage · producteur unique par donnée |
| Jamais de redémarrage auto après défaut | Sécurité machine |

---

## 🔒 GUARDRAILS — avant toute modif `CODE/`, `FB_`, `PRG_` ou « codesys »

1. ✅ Appliquer le workflow d'édition standard (§ Workflow d'édition ci-dessous)
2. ✅ Lire les documents 1 à 5 ci-dessus (ajuster la spec métier : Joystick=P08, Encoder/Homing=P09,
   Treuils **Benne incluse**=P10, Translation=P11, Diagnostic=P12, Simulation=P13, Troubleshooting=P14
3. ✅ Vérifier que la spec est complète → sinon **demander**, ne pas deviner
4. ✅ Auditer nommage, interface FB, sécurité **avant** d'écrire
5. ✅ Vérifier mécaniquement la liaison **avant** de restituer (voir ci-dessous)
6. ✅ Refuser le code non conforme — **ne jamais approximer**

### ⛔ Cas d'arrêt (refuser la génération)

- Spec manquante, incomplète ou ambiguë
- Nommage ambigu ou non-PascalCase
- Interface FB incomplète (profils `AF_Partie-03 §3` — Profils de composants)
- `Reset` pas sur front · redémarrage automatique après défaut
- `SafeStop`/`StartStop` sur un FB qui **n'est pas** un FB de mouvement (ex. `FB_Joystick`, briques E/S, diag)
- `CoupeEnable` réintroduit (vocabulaire abandonné — n'a jamais été une variable)
- `FB_Watchdog` applicatif (la périodicité des tâches est une fonction système CODESYS, seuil 200 ms)

---

## 🤖 Auto-vérification obligatoire — avant d'annoncer un lot terminé

> ⛔ Un bundle généré, des tests Python verts ou un XML bien formé **ne prouvent jamais**
> qu'une fonction est reliée au reste du programme. Le bug `PRG_10_Outputs_LD` a franchi tous
> ces contrôles (REX 2026-07-29). Seul `G200_check_linkage.py` prouve le câblage réel.

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py . # bundle PLCopenXML
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report    # liaison sur le bundle (BLOQUANT)
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C   # fin de lot (ou A/B/D, GUIDE_GATES_ET_TESTS §2)
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py              # TOUS les gates
```

Le bloc `Auto-vérification liaison` produit par `--report` est **collé dans la restitution**.
Sans lui, le lot est incomplet — quel que soit l'agent qui l'écrit.

📣 **Bandeau de restitution obligatoire** — l'agent affiche un bandeau clair à chaque étape :

```text
========================================
✅ BUNDLE EXPORTÉ : CODE_XML/CODE_Bundle.xml
========================================
```

```text
========================================
✅ BUNDLE EXPORTÉ ET VALIDÉ
   Gates Palier C : 15/15 PASS
   G200 liaison : PASS (0 erreur)
========================================
```

- **Bandeau 1** : dès que `generate_codesys_bundle.py` réussit (bundle frais).
- **Bandeau 2** : seulement si `run_all_gates.py` passe (bundle + gates verts).
- Si un gate échoue → bandeau d'échec clair, **pas** de bandeau 2.

🔒 **Ces contrôles ne dépendent plus du bon vouloir** (2026-07-29) :

| Hook | Ce qu'il empêche |
|---|---|
| `PreToolUse` | Écrire dans `CODE/*.st` sans avoir **réellement lu** les règles — vérifié dans le transcript, pas déclaré |
| `PostToolUse` | — signale liaison + liens doc à chaque édition |
| `Stop` | **Conclure un tour** avec une liaison rouge ou un bundle périmé |

🚫 **`Device.export` n'est JAMAIS une référence de contrôle.** C'est un **export du logiciel
CODESYS**, produit **uniquement à des moments particuliers de diagnostic** — jamais un export
valide de l'état actuel du projet.
- ⛔ **Toujours considérer `Device.export` comme PÉRIMÉ** tant qu'il n'est pas fraîchement exporté.
- ⛔ Aucun gate ni aucun agent ne doit **lire** un `Device.export` présent dans le dépôt : l'état
  sur disque est au bon vouloir humain et peut dater de n'importe quand.
- ✅ **Avant toute lecture, demander un export FRAIS** à l'humain (export CODESYS manuel du projet
  courant) — jamais utiliser l'existant.
- 🎯 La **source de vérité** reste le code source versionné (`CODE/*.st`) et ses interfaces
  déclarées (`VAR_INPUT`/`VAR_OUTPUT`/`VAR_IN_OUT`), jamais un export ponctuel.

## 📝 Contrat de tâche — obligatoire dès C2

Avant toute écriture ou délégation, l'orchestrateur rédige les **objectifs testables** de la tâche.
Une vérification qui ne porte sur aucun objectif est creuse : sur 53 tâches déléguées, les critères
étaient 3 phrases génériques (REX 2026-07-29).

- Gabarit : `TOOLS/AGENT_WORKFLOW/templates/task_contract.yaml`
- Contrôle : `python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py <TASK_CONTEXT.yaml>`
- Détail, axes patch/rebuild et séquence rebuild : `TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md`

🔁 **Règle `fix:` + `guard:`** : tout bug détecté donne **deux** livrables — la correction **et**
un garde-fou automatique dans `TOOLS/AGENT_WORKFLOW/scripts/`. Une réponse purement documentaire
à un incident est insuffisante.

---

## 🤝 Délégation (Gemini/antigravity, Codex, sous-agents)

Coller `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` **en tête de chaque tâche déléguée** :
l'agent distant n'a pas le contexte de la conversation. La validation finale reste à
l'orchestrateur (lecture du `git diff` réel), jamais à l'agent qui a produit le code.

Plugin antigravity : `antigravity:delegate` · `antigravity:resume` · `antigravity:review`.
Workflow multi-agents et criticité C0–C4 : `TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md`.

⚠️ **Aucun commit sans validation humaine explicite** — pour tout agent, sans exception.

🚨 **Premier réflexe avant commit/push** : si un fichier que tu n'as **pas** modifié apparaît dans
le diff, ou s'il y a une **suppression**, ou un fichier qui ne devrait pas être là → **STOP et
demande à l'humain**. Ne supprime **jamais** un fichier que tu n'as pas toi-même créé/modifié
(l'humain ou un autre agent a pu l'éditer). Ce n'est pas ton rôle de déplacer, supprimer ou
ne-pas-committer des fichiers. Le hook `pre-push` (`TOOLS/AGENT_WORKFLOW/scripts/pre_push_guard.py`)
le rappelle à chaque push (informatif, non bloquant).

🔧 **Activer le hook partagé** (une fois par clone) :
```bash
git config core.hooksPath TOOLS/AGENT_WORKFLOW/hooks
```

---

## 🛠️ Workflow d'édition

`0.` règles → `1.` architecture → `2.` existant → `3.` plan **validé** → `4.` code ST + note
d'application → `4bis.` vérification mécanique **bloquante** → `5.` REX versionné → `6.` nouvel export

⚠️ L'utilisateur applique **tout manuellement** dans CODESYS 3.5 (copie du ST puis import PLCopenXML).

---

## 📖 Documentation

Toutes les specs dans **`DOC/`** — index complet et rôle de chaque document : [DOC/README.md](DOC/README.md).

- [VERSION_HISTORY](DOC/VERSION_HISTORY.md) — historique CODESYS ↔ DOC (une ligne par jalon)
- [DSH_PROVIDERS](TOOLS/AGENT_WORKFLOW/docs/DSH_PROVIDERS.md) — 🔌 provider `omniroute` + délégation multi-modèles (workflow `provider`/`model`)
- [PLAN_TASK](DOC/WFLOW/TASKS.yaml) & [TASKS.yaml](DOC/WFLOW/TASKS.yaml) — 🗂️ **pilotage des tâches & contrats** : skill `.claude/skills/task-planner/SKILL.md` (bannière `WORKFLOW TÂCHES / TASK-PLANNER ACTIF` au lancement, horodatage ISO 8601 `locked_at`/`updated_at`/`completed_at` obligatoire, isolation `git worktree` et anti-destruction Git).
- [TROUBLESHOOTING](DOC/WFLOW/TROUBLESHOOTING/README.md) — 🕵️ **recherche de blocage / diagnostic** : skill
  `.dsh/skills/troubleshooting/SKILL.md` (DSH) & `.claude/skills/troubleshooting/SKILL.md` (Claude Code),
  méthode `TOOLS/AGENT_WORKFLOW/prompts/troubleshooting.md`, gabarit `TEMPLATE_Troubleshooting.md`,
  fiches `TROUBLESHOOTING_<Sujet>_<date>.md`. Déclenché par « cherche le blocage » / « diagnostic » /
  « troubleshooting » — bannière `MODE DÉPANNAGE / TROUBLESHOOTING ACTIF` au lancement.
- [AUDIT_Coherence_Documentaire](ARCHIVES/Doc/AUDIT_Coherence_Documentaire_v1.0.md) — historique des décisions de conception

**Plan de numérotation** : 1–3 fondations · 4–6 specs transverses (Cycle/Modes/E-S) · 8+ fonctions
métier, une par FB.

### ✍️ Style de rédaction

- **Docs de pilotage** (`PLAN_TASK`, `VERSION_HISTORY`, `NAMING_CONVENTION`, `AUDIT_*`) :
  concis, direct, TDAH-friendly, emoji, tables courtes > prose.
- **Specs `AF_PartieN`** : concis et technique, **zéro perte d'information**, emoji comme repères.
  La précision technique prime sur la brièveté.
