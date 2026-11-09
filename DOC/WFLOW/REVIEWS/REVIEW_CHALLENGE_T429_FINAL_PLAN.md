**Note de méthode** — Je n'ai pas relu `supervisor_service.py` ni relancé la suite dans cette session : tout ce qui dépend du code est marqué **[H]** (hypothèse à vérifier). Aucun PASS n'est revendiqué ici ; ce sont des verdicts de risque, pas des preuves d'exécution.

---

## 1. Risques résiduels pouvant bloquer la clôture

| Réf | Risque | Gravité |
|---|---|---|
| **R1** | **Chemin nominal cassé** : `recovery_batch_exceeds_judge_budget` n'est pas un cas limite, c'est une reprise avec historique *ordinaire* qui échoue. Le 143/143 est donc un **trou de couverture structurel** : aucun test ne dépasse le budget. | **P0** |
| **R2** | **Non-progrès** : tout correctif qui « réessaie plus petit » sans borne transforme un abandon brutal en boucle infinie. Un message seul > budget n'est pas découpable → sans politique explicite, on remplace une erreur par un livelock. | **P0** |
| **R3** | **Starvation Alarm > Warning** : un Alarm non résolu (en attente de preuve humaine) monopolise le tour et masque indéfiniment tous les Warnings. Défaut de conception, pas d'ergonomie. | P1 |
| **R4** | **Fix encodage partiel [H]** : `reconfigure` couvre stdout/stderr, pas les pipes `subprocess`, les writers de log, ni les `open()` sans `encoding`. Double risque : mojibake résiduel sur AC-F1.8, et exception au démarrage si le stream est déjà wrappé. | P1 |
| **R5** | **PULL dupliqué ×3** (Antigravity/Claude Code/DSH) sans test de contrat → dérive silencieuse du payload. Et **aucun test ne prouve la mort du chemin push** (`Confirm send`) : un chemin worker orphelin peut resurgir = réintroduction d'injection aveugle. | P1 |
| **R6** | **AC-F3.5 / AC-F3.9 sont des critères humains non rejouables** : risque de PASS déclaratif, et fragilité OS (toast avalé par Ne pas déranger / Focus Assist → faux négatif). | P1 |
| **R7** | **Preuve F2 non reproductible** (dédup prouvée sur DeepSeek V4.1 réel) : aucune non-régression en CI. | P2 |
| **R8** | **Regex `TXXX[-X]-AGENT` trop stricte** : faux négatifs sur variantes légitimes ; handover non atomique (crash entre écriture et journal). | P2 |
| **R9** | **`+4800` = constante magique** non reliée à la fenêtre réelle du juge. [H] vérifier qu'il n'y a pas confusion enveloppe/budget (comparaison inversée) : ce serait une explication alternative à R1. | P2 |
| **R10** | **DSH headless** est une *exception déclarée*, pas un PASS : doit figurer au dossier de clôture, sinon la traçabilité est fausse. | P2 |

Le vrai bloquant est **R1 + R2 ensemble** : ils forment un couple qu'on ne peut pas traiter l'un sans l'autre, et le 143/143 donne un faux signal de sécurité.

---

## 2. Rattrapage : découpage dynamique — verdict et design

**Verdict : oui au partitionnement adaptatif, non à la bisection comme mécanisme primaire, et surtout non à l'augmentation de `+4800`.**

Pourquoi pas l'inflation du plafond : elle déplace le mur et fait échouer *silencieusement* en aval (troncature côté modèle). Le découpage échoue *bruyamment et par unité*. Le guardrail F1 (« rupture signalée sans saut silencieux ») impose le second.

Pourquoi pas la bisection seule : elle suppose coût monotone et **additif**. Or l'enveloppe de prompt est fixe → un sous-lot peut encore dépasser après split → descente non bornée. Et elle ne dit rien du cas « message insécable ».

**Pipeline cible :**

1. **Modèle de coût mesuré** — `cost(m) = overhead_fixe + len(payload)` ; budget utile `B = context_chars − enveloppe_prompt_réellement_comptée`. Remplacer `+4800` par une constante nommée, justifiée et dérivée de la fenêtre du juge.
2. **Partition gloutonne déterministe** en sous-lots visant ~60–70 % de `B`, ordre d'origine préservé.
3. **Bisection en repli uniquement**, sur le sous-lot fautif, profondeur bornée (ex. 4).
4. **Cas dégénéré (message seul > B) — décision explicite requise** : troncature avec marqueur + référence à l'original, ou file « revue manuelle ». Dans les deux cas **le curseur avance**. Sinon → échec terminal *non-retryable* avec marqueur durable (pas de skip silencieux).
5. **Sémantique par unité, pas globale** : un échec d'unité n'annule pas la progression des autres. Passage de all-or-nothing à « progrès durable + curseur ».
6. **Idempotence** : `batch_id = hash(source, first_seq, last_seq, content_digest)` + ledger des unités *done*. Une unité rejouée après crash ne doit produire **aucun doublon de constat** (interaction directe avec la dédup F2 : la clé de dédup doit être message/content, pas batch).
7. **Observabilité** : event `recovery.partition {parent, children, sizes, reason, model_window}` + `run_id` corrélant les lignes. Côté opérateur c'est une **information**, plus une erreur.
8. **Travail borné par tour** : N sous-lots max par invocation (cohérent avec le modèle PULL 1 constat/tour), affichage `k/n`, reprise au tour suivant. Évite de bloquer le CLI plusieurs minutes.

**Tests obligatoires (sinon le fix n'est pas démontré)** — property-based sur histoires générées : 0, 1, exactement `B`, `B+1`, `B×k`, 1 message géant, 10k messages minuscules. Invariants : `set(traités) == set(entrée)`, ordre préservé, zéro perte, **borne d'itérations assertée**, et injection de faute « coût sous-estimé ×2 » → convergence garantie. Plus un **test négatif** : `recovery_batch_exceeds_judge_budget` n'est plus atteignable sur entrée valide.

---

## 3. Plan de clôture ordonné

**Étape 0 — Gel de référence (0,5 j).** SHA git, `pytest → 143/143` noté, hash du build plugin 0.2.0, OS/VS Code/Python, dossier de preuves horodaté.

**Étape 1 — Fix P0 rattrapage + tests (§2).** *Seul vrai bloquant.* Suite complète relancée (143 + N). Sortie : reprise d'un historique > budget menée au bout, 0 perte, 0 doublon, erreur historique non atteignable, tests de non-progrès verts.

**Étape 2 — Durcissement P1 (1 lot parallélisable).** (a) politique anti-starvation Alarm (aging ou état `blocked`) ; (b) audit exhaustif des chemins d'encodage ; (c) test de contrat sur le payload `/review-session-supervisor` des 3 CLI ; (d) test prouvant l'absence du chemin push. Un item = un test.

**Étape 3 — Rendre la preuve F2 rejouable** (cassette/fixture) → test de non-régression dédup.

**Étape 4 — Recette AC-F3.5 / F3.9 sur le build final.** Une passe exploratoire tôt est utile, mais **la signature formelle doit porter sur l'artefact post-fix**, sinon on homologue un build périmé. Protocole écrit : scénario, prérequis (Focus Assist/DND off, volume, version VS Code), capture écran/vidéo + extrait de journal horodaté, signé par l'exploitant.

**Étape 5 — Clôture formelle.** T429 → DONE dans `TASKS.yaml` avec **un lien de preuve par AC** ; exceptions déclarées (DSH headless, modèle réel non déterministe) ; risques résiduels acceptés listés ; commit d'intégration unique par le coordinateur après relecture du diff ; plan de rollback.

**Critère no-go** : si l'étape 1 n'est pas démontrée par un test rejouable, T429 reste OPEN **même si la recette IHM passe**. Un PASS ergonomique ne compense pas un chemin de reprise cassé.

**Décisions à trancher par l'exploitant :** (1) message insécable → troncature marquée ou file manuelle ; (2) aging Alarm vs starvation assumée ; (3) qui signe AC-F3.5/F3.9 et sur quel build ; (4) acceptation formelle de l'exception DSH.