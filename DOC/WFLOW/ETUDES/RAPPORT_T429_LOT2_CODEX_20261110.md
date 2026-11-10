# T429 — Lot 2 backend et notifications VS Code

Responsable : Codex. Exécution 2026-11-09 / 2026-11-10. Orchestrateur global : Antigravity.

**Verdict : implémentation et contrôles automatisés du lot livrés dans le checkout ; qualification visuelle/sonore réelle VS Code encore non réalisée. Aucun commit, push, redémarrage du service 8082 ni installation d'extension.**

## Résultats et preuves

| Critère | Résultat observé | Preuve |
|---|---|---|
| `test_notification` | Action transactionnelle, cible explicite ou première active, sévérité contrôlée, ID UUID, catégorie `system_test`, TTL persistant 60 s | `test_lot2_notification_is_local_and_excluded_from_real_judge_batches` |
| Isolation du juge | Le payload réellement construit par collecte/jugement ne contient ni le test ni son commentaire ; un constat métier demeure présent | Même test, callable enregistreur de payload, pas un modèle réel |
| Isolation messagerie | Envoi vers agent interdit pour `system_test` ; filtre aussi les projections de constats du chat | Code et garde d'intégration |
| Expiration réelle | **PASS après 60,593 s**, service fermé entre création et reprise, compteur follow_up=0 | `T429_LOT2_TTL_REEL_20261110.txt` |
| Expiration/reprise | Rechargement du service arrêté ferme un test dont l'échéance est passée ; compteurs remis à zéro | `test_lot2_notification_expiry_survives_restart_while_stopped` ; échéance vieillie pour test rapide |
| Extension | Toast de test au premier poll et par polling automatique réel à 5 s, clic session/constat, pas de rejeu des anciens problèmes ni de doublon | Node 16/16, test extension avec API VS Code simulée et vrai serveur HTTP local |
| `/review` | 80 constats, 5 pages, citations intégrales, historique volumineux exclu, constat clos exclu | Vrai serveur `create_server(port=0)` et vrai réseau loopback avec stockage `tempfile` |
| Performance finale | Corps JSON max **27 991 octets** ; projection serveur max **0,848 ms** ; requête réseau complète max **42,623 ms** | `T429_LOT2_GUARD_20261110.txt` ; mesures de cette machine, pas garantie sous toute charge |
| Pagination concurrente | Révision modifiée entre pages : erreur explicite, pas d'omission silencieuse | Test de fermeture entre pages, revue indépendante et contre-revue |
| Régressions ciblées | **46 passed in 3.20s** avant dernière correction de pagination ; puis **3 passed, 43 deselected in 1.73s** après correction + **16/16 Node** | Sortie initiale du tour ; garde final conservé |
| Suite générale | **220 passed, 6 failed** | `T429_LOT2_REGRESSIONS_20261109.txt` |
| Attribution des 6 échecs | Même série reproduite sans modifications du lot : **41 passed, 6 failed** | `T429_LOT2_BASELINE_20261110.txt` ; HEAD + trois hunks préexistants settings/audit_interval chargés en mémoire |
| Relecture du diff | Effectuée ; `git diff --check` sans erreur | `T429_LOT2_DIFF_20261110.diff` |

## Interface pour l'orchestrateur et le lot client

Commande POST existante `/api/supervision` avec token local :

```json
{"action":"test_notification","id":"<session-id>","severity":"warning"}
```

`id` absent sélectionne la première session enabled et active ; absence de cible ou sévérité invalide = erreur.
Le snapshot expose `disposition=new` et `business_state=new` pour ce test. Le cycle métier interne et les compteurs conservent leur normalisation existante `open` ; aucune modification globale du cycle de vie.

Première page : `GET /api/supervision/review?session=<id>`.
Réponse : `id, alias, platform, state, counts, alerts, total, next_offset, revision`.
Chaque constat contient identité, titre, motif, sévérité, catégorie, citation complète, date et état.
Si `next_offset` est non nul, continuer avec **offset ET revision** :
`GET /api/supervision/review?session=<id>&offset=<next_offset>&revision=<revision>`.
Si HTTP 400 « Revue modifiee », jeter les pages accumulées et recommencer à zéro ; HTTP 404 si session absente.
Une citation individuelle trop volumineuse produit une erreur explicite avec renvoi au snapshot complet : aucune citation tronquée n'est présentée comme complète.
Le client `review_session.py` reste réservé à l'orchestrateur : sa migration vers cette route n'est pas effectuée dans ce lot.

Le test explicite déclenche un avertissement VS Code même lorsque les notifications ordinaires sont désactivées. Il reste soumis au polling (5 à 30 s, 8 s par défaut) ; pas de dépendance au navigateur. Aucun délai instantané après POST n'est revendiqué. Les anciennes valeurs supérieures à 30 s sont bornées à 30 s pour éviter de manquer une notification dont le TTL est de 60 s. Dernière exécution Node après cette correction : **16 passed, 0 failed**, durée 5793,854 ms ; test automatique de polling 5585,677 ms.

## Challenge indépendant et arbitrage

DeepSeek V4.1 via Ollama : revue du diff réel, puis contre-revue ciblée de la correction (`REVIEW_T429_LOT2_CODEX_20261109.md`). Le risque d'offset instable a été corrigé par vérification de révision et test adversaire. Le choix notifications=false a été verrouillé dans le test Node. La contre-revue cite à tort le test HTTP comme preuve de ce dernier choix : la preuve correcte est `extension.test.js` avec `mockVscode(port, false)` ; cette attribution du reviewer n'est pas retenue.
Deux réponses initiales vides du runner ne constituent aucune preuve de revue. La revue enregistrée a été obtenue via API Ollama avec `think=false`.

## Limites et périmètre préservé

- Toast visible dans une vraie fenêtre VS Code et son Windows **non observés**. Les tests automatisés prouvent l'appel de l'API, la déduplication et l'URL ; ils ne prouvent pas le rendu natif, le son, ni les réglages Windows. Le test du navigateur réduit n'est donc pas qualifié visuellement.
- L'expiration est évaluée à l'accès aux projections ou à un cycle collecteur ; après arrêt du processus, aucun traitement ne s'exécute avant rechargement/lecture. Pas de suppression de données : fermeture seulement.
- Les six échecs généraux portent sur persistance de transcriptions (2), reprise source (1), budget 6000 devenu 12000 (1), rollback de reprise (1), répétition d'un constat acquitté (1). Ils ne sont pas corrigés par élargissement du lot.
- L'isolation du payload juge est prouvée mécaniquement ; le comportement d'un modèle réel n'est pas évalué dans ces tests.
- Les modifications préexistantes de `supervisor_service.py` (context_chars, model_context_tokens, max_visible_closed_findings, audit_interval) sont conservées, et figurent dans le diff Git joint, sans être attribuées au lot.
- Frontend, clients, prompts, CODE/ et Task Manager non édités par Codex. Autres modifications/suppression préexistantes ou concurrentes laissées intactes, notamment `.claude/settings.json`, frontend/tests UI, plan et transcription supprimée.
- Premier essai pytest sandbox : erreurs d'accès TEMP (3 failed, 12 passed, 28 errors), relancé hors sandbox puis 43/43 ; premier Node sandbox : spawn EPERM, relance hors sandbox verte. Deux échecs de nos nouveaux tests ont révélé des champs persistants manquants : correction et gardes livrés.

## Rejouer

```powershell
py -3.13 -m pytest TOOLS/AGENT_SUPERVISOR/tests/test_t429_regressions.py -q -p no:cacheprovider
py -3.13 TOOLS/AGENT_WORKFLOW/scripts/check_t429_lot2.py
```

Le garde lance les trois tests d'intégration du lot et les tests de l'extension, avec état Git avant/après. Les tests HTTP utilisent un port dynamique et un stockage temporaire, jamais 8082. Les preuves et scratchs sont conservés ; aucun nettoyage automatique du dépôt.


## Arbitrage orchestrateur reçu le 2026-11-10

**Lot 2 accepté au niveau BACKEND & PROTOCOLES.** L'orchestrateur valide l'action de notification, l'isolation du juge, le TTL et la route allégée. Il confirme avoir raccordé avec succès son client `review_session.py` à cette route ; ce raccordement est un résultat rapporté par l'orchestrateur, non revérifié par Codex dans ce tour.

**Extension VS Code : statut partiel accordé.** La recette visuelle du toast Windows est prise en charge par l'exploitant via le bouton IHM « Test VS Code ». La recette finale reste en attente de sa confirmation ; aucune observation visuelle n'est ajoutée aux preuves automatisées.

Correction de restitution effectuée : accents restaurés dans ce rapport et enregistrement UTF-8 vérifié. Code, tests, configuration et checkout applicatif conservés sans intervention supplémentaire. Aucun commit ni push.
