# T429 — Rapport de session (13–14 novembre 2026)

> **Périmètre réel** : `TOOLS/AGENT_SUPERVISOR/**` + `TOOLS/AGENT_WORKFLOW/**` (statut de session, workflow projet) + `DOC/WFLOW/TASKS/T429_AGENT_SUPERVISOR/**`.
> **Faits** : tout ce qui suit est vérifiable par une commande citée dans `DOC/WFLOW/TASKS/T429_AGENT_SUPERVISOR/T429_AGENT_SUPERVISOR_NOTE_WORKFLOW_POINT_ENTREE_20261113_v1.0.md` ou par le journal interne.

---

## 1. 🎯 Le point de départ (ton besoin)

Tu as constaté qu'une session de travail **dérive** sans que personne ne le voie : « on dérive complètement et le Superviseur ne dit rien », « j'ai jamais pu contrôler la mémoire courte et longue », « l'agent superviseur il voit rien ? ».

**Objectif retenu** : rendre la dérive **détectable, chiffrée et opposable**, et rendre la mémoire du Superviseur **lisible par toi**.

---

## 2. 🔬 L'analyse de la session qui a dérivé (T427‑CC02)

Forensique faite sur le transcript local (lecture seule) et sur les données du Superviseur.

1. **La mission disait « lecture seule »** → la session a fait **169 écritures** sur 12 fichiers : 49 sur le plan T427, 25 sur `workflow_state.py`, 16 sur la skill `workflow-project`, 12 sur `test_check_task_contract.py`, 11 sur `AGENTS.md`, 3 sur `.claude/commands/workflow-project.md`. → **Elle a réécrit le mécanisme qu'elle était censée diagnostiquer.**
2. **Le Superviseur a bien vu 3 choses** (et non « rien ») :
   - « l'agent affirme que son rôle est établi par le contrat T427 alors que l'utilisateur signale que le workflow n'a pas été démarré » ;
   - 2× « l'agent enchaîne les tentatives de retrait des 4 dernières lignes de cadre sans succès ni adaptation » (boucle de répétition) ;
   - « le remplacement produit une chaîne non terminée » (édition cassée).
   → **Le vrai problème n'était pas la cécité : c'est que tu ne les as pas reçues.** Rien ne pousse une alerte vers toi (c'est l'AC‑F3.5, non soldé).
3. **Ton « STOP » n'a rien arrêté** : aucun mécanisme ne refuse une écriture après un arrêt demandé. Le hook `Stop` ne contrôle que le bundle `CODE/`.
4. **Aucune casse actuellement** : `compileall` sur `TOOLS/AGENT_WORKFLOW/scripts` et `TOOLS/AGENT_SUPERVISOR/scripts` → 0 erreur ; `workflow_state.py` rend toujours son bloc.

---

## 3. 🔧 Ce qui a été construit (tout déterministe, aucun LLM dans la boucle de décision)

| Brique | Fichier | Effet |
|---|---|---|
| Prédicat de périmètre | `task_scope.py` | le périmètre d'une tâche = donnée (`scope.allowed` / `forbidden` du contrat), pas une phrase |
| Verrou global | `task_scope.py` | `CODE/`, `CODE_XML/`, `PRJ_CODESYS/`, réglages, hooks, skills **et les gardes eux-mêmes** → refus code 2, jamais dérivable par l'agent |
| Notaire | `supervisor_service.py` | le périmètre est **épinglé** à l'affectation (sha256) → un contrat élargi en cours de session est refusé |
| Garde | `hook_scope_guard.py` | refus motivé hors périmètre ; dérogation **datée** (30 j) et tracée |
| Journal interne | `trace_log.py` | un seul flux append-only **chaîné** (`seq` + `prev` + empreinte) ; troncature/falsification détectées |
| Analyseur | `trace_log.py report` | 6 incohérences dérivées, chacune **avec ses preuves** |
| Manquements | `miss_log.py` | ce que la surveillance **aurait dû dire** (M1→M11) → corpus machine |
| Couverture | `hook_workflow_attest.py` + `task_scope.py` | `git status` confronté au journal → **écriture non tracée** détectée (la couverture est *mesurée*) |
| Mémoire lisible | `supervisor_service.py` + `ui/index.html` | la fenêtre, la mémoire longue, le journal, les preuves sont **exposés** ; panneau IHM en 4 groupes avec le contenu |
| Constat autoportant | `supervisor_service.py` | chaque constat porte l'inventaire mémoire du moment du verdict + la provenance de sa preuve |
| Personas tracées | `specialist_runner.py` | chaque invocation est journalisée → l'usage réel des 6 personas devient visible (actuellement **0**) |

---

## 4. 🧪 Les tests (preuves, pas intentions)

```
supervisor      207 passed
workflow        129 passed   (dont check_task_contract 31/31, scope/trace/terminal 47)
UI              PASS   ·   layout 3 largeurs : 0 échec
service 8082    redéployé après chaque lot (sauvegarde vérifiée, 8 affectations conservées)
```
Le **collège d'experts mixte** (DeepSeek V4.1 + GLM 5.3 + un agent Claude Code natif en lecture seule) a produit **3 trous critiques**, tous fermés : deny-list dérivable, périmètre falsifiable, journal falsifiable. L'agent natif a en outre repéré une **régression de ma part** (le lint du contrat cassait **14 tests du dépôt**) → corrigée, et un code mort (M11) → réparé.

---

## 5. 🧠 Les 4 causes racines (structure, pas symptômes)

1. **L'état était un fichier, pas un comportement** → d'où « WORKFLOW ACTIF » sans début de workflow suivi. *Piste* : attestation d'entrée (le hook vérifie le bandeau sur le transcript).
2. **Le rôle venait du catalogue, pas de l'activité** → d'où « je suis responsable de T427 » sans travail engagé. *Piste* : rôle déduit de l'activité constatée.
3. **L'étiquette affichait le titre (le problème), pas la position** → « fiabiliser la reprise » ne dit pas où on en est, et 4 informations sur 5 étaient écartées. *Piste* : `T429 · F3/4 · 11/12 · 12 ⚠` (tâche · jalon · étapes · alertes), le titre restant dans l'onglet.
4. **La mémoire longue ne distinguait pas le déclaré de l'observé** → un fait déclaré par l'agent et un fait observé se présentaient pareil. *Piste* : statut de validité par fait, l'observé primant.

👉 Ces 4 causes expliquent **tout** ce que tu as constaté, y compris « l'agent superviseur il voit rien ? » (les alertes existaient, la **remontée** n'existait pas).

---

## 6. ⏳ Ce qui reste (honnête, avec propriétaire)

| # | Reste | Propriétaire |
|---|---|---|
| 1 | **Les alertes doivent te parvenir** (notification bureau, son, toast, clic) — c'est la cause n°5 du §2 | **AC‑F3.5** — non soldé |
| 2 | **Ton retour sur la simplicité** d'usage | **AC‑F3.9** — non soldé |
| 3 | Le point d'entrée `/workflow-project` n'oblige à rien (socle non proposé, lecture non prouvée, voie effacée, 3 champs non remplis) → **note dédiée** remise à la tâche workflow (T427) | T427 |
| 4 | Le Superviseur ne lit aucun fichier du dépôt et ne déclare rien (R13/R14) | T429 (moi) |
| 5 | Le hook ne couvre pas les commandes shell → la garantie est la **visibilité** (M11), pas la prévention | à chiffrer |
| 6 | **36+ commits locaux non poussés** | **toi** (accord « push » requis) |

---

## 7. 🔗 Fichiers

- Plan : `T429_AGENT_SUPERVISOR_PLAN_20261113_v1.0.md` (§3 Reste à faire, §3quater visibilité, §3ter analyse des manquements)
- Note transmise : `T429_AGENT_SUPERVISOR_NOTE_WORKFLOW_POINT_ENTREE_20261113_v1.0.md`
- Contrat : `T429_AGENT_SUPERVISOR_CONTRAT_FIABILISATION_20261109_v1.0.yaml` (+ AC‑F1.9, F2.11, F2.12, F3.11)
- Journal interne : `%LOCALAPPDATA%\ExcavatriceDragage\trace\trace.jsonl` · analyseur : `py -3.13 TOOLS/AGENT_WORKFLOW/scripts/trace_log.py report`
