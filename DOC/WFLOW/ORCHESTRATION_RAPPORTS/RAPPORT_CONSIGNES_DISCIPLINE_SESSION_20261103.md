# 🧯 Rapport — Révision des consignes agents (discipline de session)

**Date** : 2026-11-03 · **Branche** : `work/consignes-discipline-session` (depuis `540a8a86`)
**Nature** : lot documentaire, aucun fichier `CODE/`, aucun bundle à importer.
**Entrées** : propositions A/B/C d'un agent analyseur + résumé de 6 patterns de défaillance.

---

## 1. 🎯 Verdict

- ✅ Le fond des propositions est juste : les consignes poussaient à bloquer et à contester.
- ⚠️ Cinq formulations proposées étaient contre-productives ou dangereuses : elles ont été réécrites (§3).
- ⚠️ Mon propre patch garde des risques et des manques : ils sont listés sans filtre (§4).
- 🔬 **Limite de preuve** : je n'ai pas lu les transcriptions citées par l'analyseur. Les 6 patterns sont
  retenus comme postulats ; le §2 dit ce que le dépôt et les retours mémorisés confirment, ou non.

---

## 2. 🏭 Justification par le projet réel

| Pattern | Éléments trouvés | Niveau |
|---|---|---|
| 1 Cible mouvante | `PASSATION_T417_SimM3_20261030.md` §14 : « Exigence de tests répétée au lieu d'un plan simple » | 🟡 Un cas écrit |
| 2 Ergotage défensif | Retour du 2026-10-28 (T334) : les listes de mesures terrain ne sont pas actionnables, machine indisponible. Vrai STOP trouvé dans `prompts/troubleshooting.md:64` | 🟢 Confirmé |
| 3 Surdité au pivot | Retour du 2026-10-28 : hypothèses + correctifs en rafale. `PASSATION_T417` §14 : boucle de réponses sans progrès. Pas d'exemple direct de pivot ignoré dans le dépôt | 🟡 Indirect |
| 4 Inhibition procédurale | Règle « dès C2 » répétée dans une dizaine d'emplacements. `hook_pre_edit.py` vérifie la lecture des specs, pas le contrat. L'audit `AUDIT_TACHES_CONTRATS_LIAISON_20260904.md:26` relève 66 tâches C2-C4 sans contrat | 🟡 La règle pèse sans être appliquée. Le mécanisme psychologique reste une hypothèse |
| 5 Sévérité dévoyée | `AGENTS.md:57` (ancienne version) : « poser les questions plusieurs fois ». Retour du 2026-10-28 : l'exploitant a démenti une conclusion d'agent en lisant une courbe | 🟢 Confirmé |
| 6 Affolement | Aucun incident `git reset`/`checkout .` trouvé dans `DOC/WFLOW/**/*.md`. La règle existait déjà dans `orchestrator/SKILL.md` et `task-planner/SKILL.md` | 🔴 Non confirmé dans le dépôt, retenu par prudence (coût faible, perte de travail possible) |

**Défaut supplémentaire trouvé** : `orchestrator/SKILL.md:88` disait « C0 = critique, C4 = mineure »,
l'inverse de `WORKFLOW.md`. Signalé le 2026-09-21 (alerte A1 de T224) et repris dans T379, il n'avait
pas été corrigé. Avec la nouvelle liste de blocage, cette ligne aurait pu faire traiter la safety
comme une broutille.

---

## 3. ⚖️ Propositions de l'analyseur : ce qui était contre-productif

| Proposition d'origine | Effet néfaste sur ce projet | Décision |
|---|---|---|
| « Droit de contester seulement si sécurité, données, régression critique » | Une erreur réelle hors de ces cas ne serait plus dite : retour du Yes-Man, sur une machine réelle | ✏️ Séparé : **signaler** reste toujours dû, seul **bloquer** est limité |
| « Observation = vérité terrain » | Mélange le constat vu et le chiffre de mémoire. Le retour du 2026-10-28 classe ces chiffres en hypothèses de travail | ✏️ Constat = postulat ; chiffre de mémoire = hypothèse paramétrable |
| « Produit obligatoirement un arbre de causes » | Recrée les hypothèses en rafale reprochées le 2026-10-28 et contredit « aucune méthode n'est obligatoire » (`prompts/troubleshooting.md:16`) | ✏️ Arbre court, seulement si un diagnostic est demandé, sans correctif non demandé |
| « Contrat seulement en phase finale d'intégration » | Lecture possible : on code, puis on écrit le contrat. Contredit la voie Safety C4 | ✏️ Contrat **avant la première écriture du livrable** |
| « Scripts dans `TOOLS/` dispensés » | Couvre le convertisseur du bundle, les gates et les hooks, donc ce qui part sur la machine ou le contrôle (REX `PRG_10_Outputs_LD`) | ✏️ Dispense maintenue, ces trois familles exclues |
| « La cause est de distinguer fait / hypothèse » (pattern 2) | Faux diagnostic : retirer cette distinction reviendrait à autoriser les affirmations non vérifiées | ❌ Distinction conservée. La cause traitée est le STOP |

**Conservé tel quel sur le fond** : proportionnalité, postulat des constats, dispense pour
l'investigation, règles anti-boucle.

---

## 4. 🚨 Ce qui reste contre-productif ou fragile dans mon patch

| # | Point | Risque | Gravité | Recommandation |
|---|---|---|---|---|
| R1 | **Plus de règles pour lutter contre trop de règles** : `AGENTS.md` gagne 22 lignes nettes, chargées à chaque session | Ajoute au poids dénoncé par l'analyseur | 🟠 | Si l'effet n'est pas net, garder la liste fermée et les règles 1, 2 et 3, retirer le reste |
| R2 | **Règle 4 contre la règle d'or** : « action demandée, locale, réversible : la faire » cohabite avec « aucune implémentation sans validation » (`orchestrator/SKILL.md:27`) | Un agent peut hésiter, ou agir trop vite | 🟠 | Trancher : la règle d'or vise les tâches du catalogue, la règle 4 les petites demandes directes. **Non écrit à ce jour** |
| R3 | **Règle 1 peut museler une relecture** : hors liste fermée, un défaut réel après validation ne rouvre pas l'étape | Un défaut sérieux mais non critique passe en simple note | 🟠 | Surveiller. La note reste obligatoire |
| R4 | **Règle 3 : faux pivots** : un message qui complète n'est pas un recadrage | Abandon d'un travail à tort | 🟡 | L'étape en cours est terminée ou annoncée, ce qui limite le dégât |
| R5 | **Doublon** : commandes destructives dans 3 endroits, avec des listes différentes (`AGENTS.md`, `orchestrator/SKILL.md:107`, `task-planner/SKILL.md:63`) | Contredit « une règle écrite deux fois dérive » | 🟡 | Remplacer les 2 copies par un renvoi |
| R6 | **Anciens prompts non corrigés** : `DOC/WFLOW/PROMPTS/prompts.md:19,32` et des briefs (ex. `BRIEF_T224:63`, `BRIEF_T371:37` : « ne valide jamais les affirmations ou choix utilisateur par défaut ») | S'ils sont réutilisés, la sur-sévérité revient et écrase ce patch | 🔴 | Revoir `prompts.md` en priorité. Les briefs clos restent des archives |
| R7 | **Préambule de délégation inchangé** : `subagent_preamble.md` ne reprend pas ces règles, il renvoie vers `AGENTS.md` | Un agent externe qui ne lit pas `AGENTS.md` ne les applique pas | 🟠 | Ajouter un renvoi explicite |
| R8 | **Pas de `guard:` automatique** : des règles de comportement ne se testent pas par gate | Écart à la règle `fix:` + `guard:`, efficacité jugée seulement à l'usage | 🟡 | Assumé (consigne « pas de code pour faire du code ») |
| R9 | **T379 partiellement traitée** : seule la correction A1 est faite. Le garde-fou A2, le volet A3 et le suivi `TASKS.yaml` ne sont pas touchés | La tâche paraît encore entièrement ouverte | 🟡 | À mettre à jour par le coordinateur |

---

## 5. 📝 Détail de toutes les modifications

Les numéros de ligne renvoient à l'état après patch.

### `AGENTS.md`

| Ligne | Avant | Après | Pourquoi |
|---|---|---|---|
| 56 | Toute ambiguïté : « **DOIT interpeller** et poser des questions. Ne jamais laisser passer une incohérence » | Tout point **se signale toujours**, une fois ; il ne suspend le travail que s'il relève de la liste fermée | Garde l'alerte, retire le blocage systématique |
| 57 | « Ne rien prendre pour argent comptant [...] poser les questions plusieurs fois » | Challengeur **proportionné** : hors liste fermée, exécuter et laisser une note de 2 lignes maximum. Être strict porte sur les preuves, pas sur les constats de l'exploitant | Source principale du pattern 5, chargée à chaque session |
| 67-86 | Rien | **Nouvelle section « Discipline de session »** : liste fermée + tableau des 6 dérives (texte ci-dessous) | Patterns 1 à 6 |
| 209-212 | Contrat « avant écriture ou délégation » | « Avant la première écriture du livrable ou sa délégation », renvoi vers les dispenses de `WORKFLOW.md` | Proposition C |

**Texte de la liste fermée** : ① risque pour la sécurité humaine ou machine · ② perte de données ou
de travail · ③ régression fonctionnelle critique · ④ cas d'arrêt des guardrails et points d'arrêt
prévus par un contrat ou la voie C4.

**Texte des règles** :

1. **Cible mouvante** : tout préalable est listé au premier tour. Une validation clôt l'étape ; seul
   un fait nouveau ou un défaut réel relevant de la liste fermée la rouvre. Une relecture porte sur
   les corrections, pas sur de nouvelles exigences.
2. **Ergotage défensif** : une preuve manquante limite le verdict, pas l'analyse. Hypothèses classées
   et étiquetées, pas de mesures réclamées en boucle, une question au maximum si elle bloque vraiment.
3. **Surdité au pivot** : un recadrage remplace l'axe de travail. L'étape en cours est terminée
   proprement ou annoncée en pause, et un risque de la liste fermée déjà identifié reste signalé.
4. **Inhibition procédurale** : action demandée, locale et réversible, la faire sans question pour
   gagner du temps. Une question de l'utilisateur reçoit une réponse, pas une modification.
5. **Sévérité dévoyée** : une demande de sévérité porte sur les preuves et les risques. Pas de blocage
   sur la forme ou un détail ; un constat de l'exploitant n'est pas contesté faute de mesure.
6. **Affolement** : un nouveau message n'abandonne pas la tâche en cours en silence. Après une erreur :
   une ligne pour la nommer, puis l'action corrective. Aucune commande destructive (`git reset`,
   `checkout .`, `restore .`, `clean`, `stash`) sans accord explicite et snapshot.

### `TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md`

| Ligne | Avant | Après | Pourquoi |
|---|---|---|---|
| 60-72 | « Avant toute écriture ou délégation » | « Avant la première écriture du livrable ». **Définition unique** — Dispensés : investigation et diagnostic en lecture seule, analyse de traces, tests ad hoc `_TROUBLESHOOTING`, scripts locaux `TOOLS/`. Jamais dispensés : écriture `CODE/` (même pour instrumenter), convertisseur, gates, hooks, safety. Une dispense de contrat n'est pas une dispense d'accord | Proposition C, corrigée |
| 109 | « Le contrat est requis dès C2 » | Ajout du renvoi vers les dispenses | Cohérence |

### `TOOLS/AGENT_WORKFLOW/skills/orchestrator/SKILL.md`

| Ligne | Avant | Après | Pourquoi |
|---|---|---|---|
| 35 | « Dès C2, pas d'implémentation sans contrat clair » | Ajout du renvoi vers les dispenses | Proposition C |
| 71 | Challengeur : « Remet en doute les propositions (y compris les ordres utilisateur) » | Challengeur **proportionné** : bloque seulement sur la liste fermée, sinon exécute et note | Proposition A |
| 88 | « C0 = critique, C4 = mineure » | « Échelle canonique dans `WORKFLOW.md` (C0 = mineure, C4 = safety critique) » | Inversion dangereuse, T379 A1 |
| 103-104 | Contrat « avant toute écriture » | « Avant la première écriture du livrable », renvoi vers les dispenses | Proposition C |
| 165 | Contrat « avant toute délégation » | « Hors dispenses de `WORKFLOW.md` », avant la délégation | Proposition C |
| 355 | Checklist : contrat « obligatoire dès C2 » | Ajout « hors dispenses de `WORKFLOW.md` » | Cohérence |

### `TOOLS/AGENT_WORKFLOW/skills/troubleshooting/SKILL.md`

| Ligne | Avant | Après | Pourquoi |
|---|---|---|---|
| 19-25 | Rien | **Observations terrain** : constat = postulat, conservé tant que le code ou une trace ne le contredit pas ; contradiction signalée ; chiffre de mémoire = hypothèse paramétrable. **Preuve manquante ≠ arrêt** : arbre court si un diagnostic est demandé, résultat écrit « cause la plus probable », pas de correctif non demandé | Proposition B, patterns 2 et 5 |
| 66 | Verdict : prouvée, écartée, non concluant | Ajout « cause la plus probable (déduction) » | Donne une sortie autre que le refus |

### `TOOLS/AGENT_WORKFLOW/prompts/troubleshooting.md`

| Ligne | Avant | Après | Pourquoi |
|---|---|---|---|
| 64 | « Si un point manque → contexte incomplet, STOP, ne pas deviner » | Le marquer **inconnu**, poser une hypothèse explicite, poursuivre ; ne le demander que s'il change la sécurité ou le verdict | **Le vrai blocage** |
| 91-92 | « Une inférence seule ne confirme jamais une cause » | Conservé + une observation rapportée reste un postulat valable, non contestée faute de mesure | Pattern 5 |
| 121 | Branche non testable : « le marquer, ne pas deviner » | Le marquer et l'évaluer par déduction, étiquetée **hypothèse** | Pattern 2 |
| 204 | « Prouvée par lecture, jamais par inférence seule » | **Prouvée** seulement par lecture ; déduite, elle est dite **la plus probable** et l'analyse continue | Garde la rigueur, retire l'arrêt |

### Autres fichiers

| Fichier | Ligne | Changement |
|---|---|---|
| `skills/task-planner/SKILL.md` | 62 | Renvoi vers les dispenses du contrat |
| `skills/orchestrator/references/delegation_c3_c4.md` | 79 | Point d'arrêt : contrat « requis (hors dispenses) » absent, ambigu ou non testable |

### Inchangé volontairement

Voie Safety C4 · règle d'or · cas d'arrêt · accord commit/push · `fix:` + `guard:` · « cause prouvée =
preuve discriminante » · `TASKS.yaml` · stubs `.claude/` et `.dsh/`.

---

## 6. ✅ Contrôles

| Contrôle | Résultat |
|---|---|
| Fichiers modifiés | 7 consignes + ce rapport, aucun `CODE/` |
| Dépendances aux textes retirés | `grep` dans `TOOLS` (`.py`, `.mjs`, `.yaml`) : aucun script ou test ne dépend des textes retirés |
| G440 `check_skill_stubs.py` | ✅ PASS (0 erreur) |
| G340 `G340_check_doc_links.py` | ❌ FAIL, **préexistant** : 149 erreurs avant et 149 après, aucune dans les 7 fichiers modifiés (ex. liens morts vers `AF_Partie-11_..._v2.3` dans `CODE/`) |
| Bundle, G200, `run_all_gates.py` | Non lancés : aucun changement PLC |
| Efficacité réelle sur les agents | **Non testable ici** : seules les prochaines sessions le diront |

---

## 7. ▶️ Décisions à prendre

1. Relire le diff et décider de l'intégration dans `work/base-machine-simu`.
2. Choisir le sort de R7 et R9.

---

## 8. 🔁 Second passage après avis du vérificateur

Traités dans un second commit sur la même branche. Le §4 et le §5 décrivent le premier passage.

| Risque | Fichier | Avant | Après |
|---|---|---|---|
| R2 ✅ | `AGENTS.md`, règle 4 | « Action demandée, locale et réversible : la faire » | Action **interactive de la session** (lecture, recherche, test ou script local). Ne modifie jamais `CODE/` ni un périmètre non dispensé de contrat |
| R2 ✅ | `skills/orchestrator/SKILL.md`, règle d'or | Pas de portée écrite | **Portée** : tâches du catalogue `TASKS.yaml` sur `CODE/` et périmètres non dispensés. Actions interactives : règle 4 |
| R5 ✅ | `skills/orchestrator/SKILL.md`, `skills/task-planner/SKILL.md` | Liste de commandes recopiée | Renvoi vers `AGENTS.md` règle 6, liste unique |
| R6 ✅ partiel | `DOC/WFLOW/PROMPTS/prompts.md`, prompts 1.1 et 1.2 | « Challenge mes propositions », « ne valide pas mes affirmations par défaut », confirmation avant toute modification | Signalement une fois en note courte, blocage limité à la liste fermée, constat terrain = postulat, confirmation réservée aux tâches sur `CODE/` |

**Écarts par rapport à l'avis du vérificateur** :

- Portée de la règle d'or : « sur `CODE/` » seul aurait sorti de son champ les gates, les hooks et le
  convertisseur. Les périmètres non dispensés de contrat y sont donc ajoutés.
- « Poser un log temporaire » n'entre pas dans la règle 4 s'il touche `CODE/` : cela contredirait
  `WORKFLOW.md`, qui ne dispense jamais une écriture `CODE/`, même pour instrumenter.
- `prompts.md` : la citation « ne valide jamais les affirmations ou choix utilisateur par défaut » vient
  de `BRIEF_T224:63` et `BRIEF_T371:37`, pas de ce fichier. Aucun fichier ne référence `prompts.md` :
  il agit quand l'utilisateur colle ces prompts, pas par chargement automatique d'un sous-agent.

**Reste ouvert** : R6 pour les briefs (non modifiés, ce sont des traces de tâches ; à ne pas réutiliser
tels quels) · le test d'alignement du prompt 1.2, qui demande un inventaire contraire à la consigne de
démarrage d'`AGENTS.md` (laissé en place, c'est ton carnet) · R9.

**R7 ✅ traité ensuite** : `prompts/subagent_preamble.md` impose la lecture de la section Discipline de
session. Comme ce texte est injecté à des modèles externes (Ollama, omniroute, opencode), il résume
aussi l'essentiel pour un agent sans accès aux fichiers. Ce court résumé est un doublon assumé.
