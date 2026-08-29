# BRIEF B1 — Rédiger le plan T181 + entrées TASKS.yaml + contrats de cadrage

> À COLLER TEL QUEL en tête de la tâche de l'agent externe. Les 2 fichiers de référence sont
> **versionnés dans le dépôt** — l'agent les lit directement :
> 1. `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` (préambule projet obligatoire)
> 2. `DOC/WFLOW/AUDITS/DESIGN/PLAN_GEL_TREUIL_T181_CONSOLIDE.md` (le brief maître, SOURCE de vérité)
>
> Si l'agent n'a pas accès au dépôt : coller le contenu intégral de ces 2 fichiers à la suite de ce brief.

---

## Préambule

Lis d'abord `subagent_preamble.md` (joint). Tu es Expert Senior Automatisme CODESYS 3.5 /
sécurité machine. Style FR, concis, tableaux. Tu ne touches **aucun fichier `CODE/`**.
Tu produis **uniquement de la documentation de pilotage**. Aucun commit.

## Contexte

Machine de dragage, sous-système treuil (M1 retenue + M2 benne, câble commun). Un plan de gel
complet a été consolidé à partir de 6 sources (2 revues expertes, 2 challenges indépendants,
rapports CI, décisions utilisateur). Ce plan est dans `PLAN_GEL_TREUIL_T181_CONSOLIDE.md` (joint).
**Il fait autorité. Tu ne le remets pas en cause, tu le mets en forme aux formats du repo.**

## Ta mission — 3 livrables

### Livrable 1 — plan formaté `PLAN_GEL_TREUIL_T181_v0.1.md` (À CRÉER dans le dossier `DOC/WFLOW/AUDITS/DESIGN/`)

Reprends l'intégralité de `PLAN_GEL_TREUIL_T181_CONSOLIDE.md` en document de pilotage propre :
- En-tête : titre, chapô T181, date, statut « plan validé — exécution Phase -1 », liste des 6 sources.
- Toutes les sections §0 à §12 du brief consolidé, **zéro perte d'information**.
- Ajoute un sommaire cliquable.
- Style : concis, TDAH-friendly, emoji comme repères, tables > prose (cf. AGENTS.md § Style de rédaction).
- Ne réécris pas le fond, ne « améliore » pas les décisions : mise en forme + cohérence des renvois.

### Livrable 2 — Bloc d'entrées pour `DOC/WFLOW/TASKS.yaml`

Produis les **20 entrées** T181-00 → T181-19 du registre §7 du brief, **au format exact**
des entrées existantes de `TASKS.yaml` (va lire 3-4 entrées récentes pour copier la structure :
champs `id`, `titre`, `criticite`, `statut`, `lock_agent`, `bloque_par`, `contrat`, `updated_at`,
description, etc. — respecte les clés réellement présentes, n'en invente pas).
- `statut` : ⬜ à faire pour toutes.
- `chapô` T181 : crée aussi l'entrée parente si le fichier en utilise (regarde comment T168 / T167
  gèrent leurs sous-tâches).
- `bloque_par` : reprends EXACTEMENT le DAG §6 + colonne `bloque_par` du §7.
- `contrat:` : pointe vers les 3 fichiers du livrable 3 pour T181-01 / T181-06 / T181-11 ;
  pour les autres, `contrat: null` ou l'usage du repo pour une tâche sans contrat dédié.
- `absorbe:` / mention : T181-01→T177, T181-13→T096(partiel), T181-15→T096, T181-16→T175,
  T181-17→T178(=T054), T181-06→T131(partiel). Superséder T130/T131/T135.
- **Livre ce bloc SÉPARÉMENT** (fichier `T181_TASKS_YAML_BLOCK.yaml`), ne modifie pas `TASKS.yaml`
  toi-même : un agent dédié à la doc/CI travaille dessus, l'orchestrateur fera l'insertion.

### Livrable 3 — 3 contrats de cadrage

Format : `TOOLS/AGENT_WORKFLOW/templates/task_contract.yaml` (va le lire). Un fichier chacun :
- `TASK_CONTRACT_T181-01_AUTORITE_2_INTERLOCKS.yaml` — objet §4 du brief : contrat formel
  d'autorité des 2 instances `FB_WinchRateInterlock` + les 4 critères d'acceptation
  `FinalInterlockGoverned=FALSE` sans HIL. Criticité C4.
- `TASK_CONTRACT_T181-06_DRIVEREQUEST_CADRAGE.yaml` — objet §3 : interface `ST_fbWinch_DriveRequest`,
  les 4 amendements bloquants (A clamp par instance vs commun / B précédence Min/Max / C producteur
  `MinStepDescent` / D `MinStepNumber` sur la cible), matrice d'interconnexion §3-D comme critères
  testables. Arrêt validation humaine. Criticité C4.
- `TASK_CONTRACT_T181-11_MATRICE_MAINT_N1_N2.yaml` — objet Phase C : matrice bypass N1/N2,
  override FDC N1 borné 8,5 m, re-homing, « tout à l'arrêt ». Arrêt validation humaine. Criticité C3.

Chaque contrat : `objectifs_testables` = liste de critères **vérifiables mécaniquement**
(gate, TC CI, grep, invariant), PAS de phrase générique. Vérifie ta sortie avec la logique de
`check_task_contract.py` (T1 : contrat existe ≥ C2 ; T8 : si scope `CODE/MAIN/` → nom fichier =
nom POU + suffixe langage).

## Format de restitution

1. Les 3 fichiers (contenu complet, prêts à écrire).
2. Le bloc `T181_TASKS_YAML_BLOCK.yaml`.
3. Le `PLAN_GEL_TREUIL_T181_v0.1.md` complet.
4. Une note « points où j'ai dû interpréter / clés TASKS.yaml incertaines » → pour l'orchestrateur.

Aucun commit. Aucune écriture dans `TASKS.yaml` ni `CODE/`.
