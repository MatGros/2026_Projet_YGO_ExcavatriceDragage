# T429 — Note : le point d'entrée `/workflow-project` n'oblige à rien

> **Objet** : le point d'entrée `/workflow-project` doit obliger tout agent qui passe par là à **lire quelques petits documents** (socle du projet) et à **recevoir son rôle**, avant d'agir.
> **État** : constaté sur la session `T429-MMX01` le 2026-11-13 · **à traiter par la tâche qui porte le workflow** (`T427_WORKFLOW_AGENTS`) · T429 garde la lecture de dépôt et les constats (R13/R14).
> **Mode d'emploi** : chaque ligne est un **fait observé**, avec **comment le vérifier**. Rien n'est supposé.

---

## 1. 🧭 Ce qui a été fait, et ce qui a été vu

1. `/workflow-project` a été lancé sur la session `T429-MMX01` (voie **Tâche**, task `T429`).
2. Le bloc affiché a été relu ligne à ligne, et le code du point d'entrée a été lu : `skills/workflow-project/SKILL.md`, `scripts/workflow_state.py`, `scripts/hook_workflow_attest.py`, `scripts/hook_scope_guard.py`.
3. Les hooks ont été observés **en action** (refus effectif sur `CODE/`, code de sortie 2 ; refus sur chemin hors périmètre ; dérivation d'une écriture shell non vue par le hook mais rattrapée par le cross-check).
4. **Constat central** : entre l'exploitant et le script, **il n'y a rien**. Le script écrit un état et imprime un bloc. La lecture du socle n'existe que comme **règle** d'`AGENTS.md` → elle est **probabiliste** : rien ne la prouve, rien ne l'empêche d'être sautée.

---

## 2. 📋 Écarts constatés (fait → comment le vérifier → attendu)

1. 🟡 **Aucun socle proposé** — le bloc affiche l'état, la tâche, les compteurs ; il ne dit **aucun document à lire**, ni le **rôle** de la voie choisie.
   *Vérifié* : bloc `━━ 🟢 T429 · WORKFLOW ACTIF · token ACTIF/6 …` — pas de ligne « socle ».
   *Attendu* : `📚 Socle à lire : <4 chemins>` et `🎭 Ton rôle : <obligations de la voie>` dans le bloc.

2. 🔴 **Lecture non prouvée** — un agent peut déclarer `ACTIF` sans avoir lu quoi que ce soit.
   *Vérifié* : transcript de `T429-MMX01` — tours sans aucune lecture des documents du socle.
   *Attendu* : la lecture est **prouvée par relecture du transcript** (le motif existe déjà dans `hook_pre_edit.py` : une règle « se lire » ne se déclare pas, elle se relit). Sans lecture complète → `socle_lu: false`, état non valide, barre de statut en rouge.

3. 🟡 **Les 3 champs de la skill ne sont pas remplis** — la skill exige 📍 *ce chat* · ⏸️ *en attente* · ➡️ *choix* après le bloc ; ils manquent systematically.
   *Vérifié* : `SKILL.md` §2 les liste ; les réponses observées ne les contiennent pas.
   *Attendu* : bloc complété à chaque fois, ou contrôle bloquant.

4. 🔴 **La voie est effacée à chaque entrée** — `write_state()` écrit `voie=None` lors d'un `enter` : une voie déjà choisie est perdue.
   *Vérifié* : voie mise à « Tâche », puis `/workflow-project` → `🧭 Voie : aucune (libre = réponse directe)`.
   *Attendu* : la voie **survit**, ou le menu la redemande explicitement.

5. 🟡 **Rôle auto-attribué** — un agent s'est annoncé « responsable de T427 » alors que le début du workflow n'avait pas eu lieu.
   *Vérifié* : échange du 2026-11-13 — l'affirmation précède la reconnaissance que le début n'avait pas été suivi.
   *Attendu* : le rôle vient de l'**état** (voie + étape), jamais d'une affirmation de l'agent.

6. 🟡 **Le hook de périmètre ne couvre pas le shell** — il n'intercepte que `Edit|Write|MultiEdit` ; une écriture faite en `Bash` passe dessous.
   *Vérifié* : 4 fichiers modifiés via `Bash` → refus non déclenché ; détectés **par le cross-check** (M11 : écritures réelles non tracées).
   *Attendu* : soit parsing des commandes shell, soit cross-check systématique + **mention explicite** que la garantie porte sur la visibilité.

7. 🟡 **Le Superviseur ne lit rien du dépôt et ne déclare rien** — il ne voit que le transcript et ce que l'agent cite ; il ne peut pas « aller regarder un script en cas de doute ».
   *Vérifié* : aucun accès fichier dans `supervisor_service.py` ; les constats portent la provenance de leur preuve, pas la liste des lectures.
   *Attendu* : un **dossier de lecture** borné (≤ 6 fichiers, ≤ 12 000 caractères, lecture seule) et **déclaré** dans l'argumentaire du constat.

8. 🟡 **Les agents spécialisés ne sont pas branchés** — usage réel mesuré : **0 invocation** ; ils n'étaient tracés nulle part.
   *Vérifié* : `memory_state.personas = []`.
   *Attendu* : usage tracé (**fait**) **et** invocation possible depuis le Superviseur, déclarée comme une lecture.

---

## 3. 🔧 Corrections demandées

- **C1** — `render()` : ajouter `📚 Socle à lire : <4 chemins>` et `🎭 Ton rôle : <obligations de la voie>`.
  *Où* : `scripts/workflow_state.py` · *Fin* : le bloc affiche les 4 chemins et le rôle.
- **C2** — preuve de lecture : le hook relit le **transcript** et vérifie un `Read` sur chaque document du socle → `socle_lu` dans l'état, le bloc et la 2ᵉ ligne de la barre.
  *Où* : `scripts/hook_workflow_attest.py` · *Fin* : socle non lu ⇒ état non valide, barre en rouge.
- **C3** — `write_state()` : **préserver** la voie à l'`enter` (ou la redemander par le menu).
  *Où* : `scripts/workflow_state.py` · *Fin* : une voie choisie survit à la ré-invocation.
- **C4** — la skill doit produire les 3 champs 📍 / ⏸️ / ➡️ à chaque bloc, et le rôle doit venir de l'état.
  *Où* : `skills/workflow-project/SKILL.md` · *Fin* : aucun bloc rendu sans ces 3 champs.
- **C5** — superviser : **dossier de lecture** borné + `lecture_declaree` sur chaque constat.
  *Où* : `scripts/supervisor_service.py` · *Fin* : chaque constat nomme les fichiers lus ; un fichier illisible est signalé, jamais deviné.
- **C6** — IHM : distinguer « dossier de lecture » vs « accès direct au dépôt (interdit) » et afficher l'usage des personas.
  *Où* : `ui/index.html` · *Fin* : les deux notions et l'usage sont visibles.
- **C7** — (à chiffrer) parser les commandes shell pour fermer l'écart n°6, ou décider explicitement de s'en remettre au cross-check.

---

## 4. 🧪 Protocole d'évaluation (10 min, résultat binaire)

```powershell
# 1. le socle est proposé
py -3.13 TOOLS/AGENT_WORKFLOW/scripts/workflow_state.py enter fresh --session <id>

# 2. la voie survit à une nouvelle entrée
py -3.13 TOOLS/AGENT_WORKFLOW/scripts/workflow_state.py voie 2 --session <id>
py -3.13 TOOLS/AGENT_WORKFLOW/scripts/workflow_state.py enter fresh --session <id>   # voie encore "Tâche" ?

# 3. la lecture est prouvée (aucun Read sur le socle => socle_lu false)
py -3.13 TOOLS/AGENT_WORKFLOW/scripts/workflow_state.py status --session <id>

# 4. le hook refuse bien un chemin interdit (rc attendu = 2)
echo '{"tool_name":"Edit","session_id":"<id>","tool_input":{"file_path":"C:/repo/CODE/x.st"}}' `
  | py -3.13 TOOLS/AGENT_WORKFLOW/scripts/hook_scope_guard.py ; echo "rc=$?"

# 5. le Superviseur déclare ses lectures
curl -s http://127.0.0.1:8082/api/supervision | findstr lecture_declaree

# 6. l'usage des personas est visible
curl -s http://127.0.0.1:8082/api/supervision | findstr personas

# 7. non-régression
py -3.13 -m pytest TOOLS/AGENT_WORKFLOW/tests TOOLS/AGENT_SUPERVISOR/tests -q
```

✅ **Critère de fin global** : les 7 commandes donnent un résultat **binaire**, sans interprétation. Les points 1 à 6 se vérifient **à la commande**, le 7 par les tests.

---

## 5. 🧰 Documents et outils fournis

- 📄 Le besoin, mot pour mot : échange de l'exploitant du 2026-11-13 (session `T429-MMX01`, transcript local).
- 📄 Règles du projet : `AGENTS.md` (entonnoir, discipline de session) + `TOOLS/AGENT_WORKFLOW/docs/AGENT_OUTPUT_STANDARD.md`.
- 📄 Code du point d'entrée : `skills/workflow-project/SKILL.md`, `scripts/workflow_state.py`, `scripts/hook_workflow_attest.py`, `scripts/hook_scope_guard.py`, `scripts/trace_log.py`.
- 📄 Plans et preuves T429 : `T429_AGENT_SUPERVISOR_PLAN_20261113_v1.0.md` (§3quater, §3ter), `T429_AGENT_SUPERVISOR_CONTRAT_FIABILISATION_20261109_v1.0.yaml`, `scripts/trace_log.py report`.
- 🧰 Preuve par relecture du transcript : motif déjà en place dans `scripts/hook_pre_edit.py`.
