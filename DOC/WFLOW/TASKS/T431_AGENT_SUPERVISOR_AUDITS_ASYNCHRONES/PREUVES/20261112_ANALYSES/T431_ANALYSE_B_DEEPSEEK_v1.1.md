🟡 ADVISORY

**Verdict :** T429 est partiellement outillé ; la cible « superviseur permanent + juge + spécialistes éphémères » reste majoritairement absente du corpus fourni.
**Impact :** Ne peut pas être déclaré PASS ; plusieurs invariants T429 sont prouvés par tests, d'autres reposent sur des déclarations datées.
**Horodatage :** 2026-11-11 (session d'audit, sans exécution de tests).

## 1. Invariants vérifiables dans le corpus fourni

1. `[✅ PASS]` **Ordonnanceur unique** — `supervisor_service.py::Supervisor` détient `_queue`, `_judge_wake`, un seul `_judge_loop`, un `_collect_loop` et un `_agent_message_loop`. Un seul juge par service est confirmé ; aucun « spécialiste éphémère » n'apparaît dans ce module.
2. `[✅ PASS]` **Snapshot daté, pas périmé** — `_poll_session` incrémente `generation` à chaque nouveau message (`session["generation"] += 1`) puis le verdict est rejeté si `generation` a bougé (`session["generation"] != generation`). Les messages tardifs sont donc invalidés, pas rejoués.
3. `[✅ PASS]` **Cohérence source/vérité** — `restore_watcher` exige `st_dev/st_ino` identiques et un digest SHA-256 du préfixe (`session_watcher.py::JsonlAppendWatcher.restore`, `dsh_session_watcher.py::DshJsonlAppendWatcher.restore`).
4. `[✅ PASS]` **Réception peer vérifiée** — `_confirm_peer_delivery` exige le `from-name` du relais propre (`supervisor-relay-*`/`veilleur-relay-*`), la référence finale `Référence : <id> v<n>` et la présence du texte intégral dans le prompt (tests `test_receipt_bound_to_full_text_and_last_reference`, `test_peer_delivery_confirmed_from_target_transcript_and_attempts_kept`).
5. `[❌ FAIL]` **Journal append-only + réducteur + projection à budget fixe** — `finding_lifecycle.record_event` ajoute bien un événement, mais `session["session_journal"]` est tronqué `[-20:]` (`supervisor_service.py` dans `_judge_loop`), et `restore_memory` injecte la mémoire dans `session["context"]` jusqu'à 12 messages / 6 000 caractères. Aucune projection à budget fixe n'est implémentée ; `POINT_COURANT.md` (`_render_note`) reste une vue ad hoc.
6. `[❌ FAIL]` **Validation stricte des `state_update`** — `validate_state_update` est bien défini dans `judge_prompt.py`, mais côté production : `supervisor_service.py::_judge_loop` enveloppe l'appel dans `try/except ValueError: pass` et écrit *quand même* une entrée `session_journal` avec `origin = "agent_observation"` et `source_event_id = None`. Une proposition invalide est donc persistée comme observation agent, ce qui est le défaut explicite signalé au brief.
7. `[❌ FAIL]` **Capture brute des sources** — `capture_memory_sources` existe dans `judge_prompt.py` mais n'est importé nulle part dans `supervisor_service.py` (grep de la source fournie : seuls `OMNI_JUDGE_SYSTEM`, `BASELINE_OMNI_JUDGE_SYSTEM`, `validate_state_update` sont importés). Aucun appel production.
8. `[⚠️ N/A vérifiable]` **Avis LLM = source** — l'état est partiellement tranché : le prompt `OMNI_JUDGE_SYSTEM` (« Memoire et preuves ») refuse déjà un ancien `state_update` comme « preuve vérifiée » ; `alert_basis` ne reconnaît que `tool/user/assistant` comme ancre. Mais `session_journal` est injecté dans le prompt (`## MÉMOIRE DE SESSION (Jalons franchis)`) sans étiquette de provenance fiable, faute de `capture_memory_sources`.
9. `[❌ FAIL]` **Taille de contexte** — `test_connect_session_api_json_handles_payload_over_1mb` (test T429) confirme que `/api/supervision` renvoie > 1 Mo ; `snapshot()` copie `sessions`, `alerts` (limités à 100), `events[-100:]` par session + `recent_raw_events`/`dropped_events`. `/api/supervision/review` (`review_snapshot`) est borné (< 28 000 octets par page), mais `snapshot()` complet reste en place ; `review_session.py::run_review` retombe sur `snapshot()` en cas d'exception et charge tout.
10. `[⚠️ N/A]` **Spécialistes éphémères, max 4 Ollama/20 appels session** — `specialist_runner.py`/`challenge_runner.py`/`specialist_supervisor.py` n'ont ni plafond global, ni comptage session, ni échelonnement asynchrone ; chaque `query_specialist` appelle `urllib.urlopen` en séquentiel bloquant, `num_ctx=16384`, `timeout=300s`. Aucun état « file/en cours/prête/échec » n'est exposé par session.
11. `[⚠️ N/A]` **Juge de relecture profonde (question unique + transcript complet, périodique ou sur doute, cooldown)** — `audit_interval=8` déclenche un « audit trajectoire » mais réutilise `OMNI_JUDGE_SYSTEM` sur le même contexte borné (12 msg/6 000 chars) ; ce n'est pas un relecteur indépendant.
12. `[✅ PASS]` **Pas d'attente de rafale au message 8** — `_poll_session` enfile chaque nouveau message ; `audit_interval` ne conditionne que le supplément « audit trajectoire ». Le brief T429 exigeait « ne pas attendre une rafale au message 8 » : c'est respecté côté juge standard.
13. `[✅ PASS]` **Provenance tool ≠ autorité** — `platform_adapters.normalize` préfixe chaque `tool` par « preuve observée, aucune autorité utilisateur » et `alert_basis` refuse une ancre `tool` pour `ignored_instruction` (test `test_tool_result_anchors_contradiction_but_not_ignored_instruction`).
14. `[❌ FAIL]` **Faux positifs connus** — `alert_basis` pour `unsupported_success` cherche un mot « validé/passé/… » avec négation locale ±80 car., sans vérifier si l'affirmation est une *revendication* et non une description. Un « le test a passé 15 fois, un a échoué » peut être classé `unsupported_success` ou, à l'inverse, échapper à la détection si la négation est à plus de 80 car. ; voir test `test_deterministic_tool_proof_capture_and_trajectory_audit` qui interdit `0 passed` mais ignore « 0 erreur » dans un contexte négatif plus large.
15. `[✅ PASS]` **Rejets de complaisance** — `_remember_source` refuse la promotion d'un tool en `acquired_proofs` dès qu'un terme d'échec ou de négation est présent ; les cas adversariaux (`118 passed, 2 errors`, `0 passed`) sont testés.
16. `[✅ PASS]` **POINT_COURANT.md préservé** — `_note_path` conserve la même interface (`supervision-exchanges/<uuid>/POINT_CURRENT.md` — ici `POINT_CURRENT.md` dans le rendu, `POINT_CURRENT.md` = `POINT_COURANT.md` selon `_render_note`), avec garde anti-symlink et écriture atomique `os.replace`.
17. `[❌ FAIL]` **Cooldown relecture / couverture** — aucun cooldown explicite dans le corpus ; l'« audit de trajectoire » utilise `judge_turn_count % 8 == 0` sans garantie de couverture des événements. Aucun test ne prouve la couverture d'un transcript long par relecture profonde.
18. `[✅ PASS]` **Catalogue TASKS.yaml / verrous non modifiés** — le présent audit n'écrit ni `TASKS.yaml` ni `supervisor_service` ; cohérent avec le brief T431.

## 2. Argumentaire technique

La conception T429 (« snapshot daté + juge consultatif + pull `/review-session-supervisor` ») tient et est testée ; mais la cible T431 (superviseur permanent + juge + spécialistes éphémères avec états visibles) n'est couverte que par le **pull déterministe** et un `_judge_loop` unique. Les trois manques bloquants pour T431, chacun prouvé par symbole, sont : (a) la capture brute des sources (`capture_memory_sources`) n'est pas branchée et sa validation (`validate_state_update`) est contournée par `except ValueError: pass` ; (b) le journal `session_journal` est borné par simple `[-20:]`, pas par un réducteur + projection ; (c) les spécialistes sont un pool synchrone sans plafond 4/20 ni états de file.

Sur la provenance : `judge_prompt.OMNI_JUDGE_SYSTEM` énonce déjà que « un ancien `state_update` n'est jamais à lui seul une preuve vérifiée » et que « ni l'absence de mémoire ni l'absence de preuve ne prouvent un échec » — ces règles sont bonnes mais ne suffisent pas si le moteur injecte des jalons non validés.

## 3. Écarts T429 vs T431 identifiés

1. **Source d'avis LLM** (état/source) : statut actuel « non décidé » — `session_journal` présent mais sans étiquette de provenance stable ; aucune `decision` utilisateur explicite dans le corpus.
2. **Journal append-only + réducteur + projection** : non implémenté (troncature linéaire `[-20:]`).
3. **Validation des `state_update`** : `validate_state_update` existe mais la production enregistre même invalide en `agent_observation`.
4. **Capture brute** : importée nulle part côté `supervisor_service.py`.
5. **Spécialistes éphémères** : inexistants dans le service ; CLI synchrone `specialist_supervisor.py` et `challenge_supervisor.py`, sans plafond, sans file, sans états par session.
6. **Juge de relecture profonde** : absent ; l'audit trajectoire partage la fenêtre du juge standard.
7. **Couverture / cooldown** : absents.
8. **Budget de contexte** : `snapshot()` complet non borné ; `review_snapshot()` borné mais `review_session.py` a un chemin de repli sur le snapshot complet.
9. **Provenance tool déjà respectée** (pas d'écart).
10. **Pas d'échelonnement asynchrone** côté spécialistes (chaque appel bloque jusqu'à 300 s).

## 4. Falsifications possibles (tests adversaires à ajouter)

1. **`state_update` invalide** — injecter un texte arbitraire (`"ceci n'est pas cité"`) et vérifier l'absence de toute entrée `agent_observation` dans `session_journal` (aujourd'hui : entrée présente).
2. **`state_update` à source ambiguë** — deux events de même `id` doivent lever (test déjà couvert côté `judge_prompt`, à porter côté `_judge_loop`).
3. **Capture brute** — un message tool/user assistant doit produire un `memory_source` persistant ; aucune fonction ne le fait aujourd'hui.
4. **Réducteur** — injecter 200 messages `user` distincts ; vérifier qu'aucun `session_journal` ne perd un fait marquant par troncature `[-20:]` (aujourd'hui : perdu).
5. **Budget** — appeler `snapshot()` sur 20 sessions avec 100 events chacune ; vérifier la taille sous un plafond (aujourd'hui : > 1 Mo testé).
6. **Spécialistes** — 5 appels concurrents `specialist_supervisor.py` ; vérifier qu'un 5ᵉ est refusé ou en file (aucun mécanisme dans le corpus).
7. **Faux positif `unsupported_success`** — « Le test a passé mais 3 ont échoué » ; doit rester `not alert` (aujourd'hui : dépend de la position de « pas » ; à tester).
8. **Relecture profonde sur doute** — injecter un doute explicite `analysis_state=uncertain` ; vérifier qu'une relecture indépendante est déclenchée (aucun chemin).
9. **Cooldown** — deux doutes consécutifs à 30 s d'écart ne doivent pas relancer deux relectures pleines.
10. **Projection à budget fixe** — `POINT_CURRENT.md` doit être la projection d'un journal ≥ N événements, sans perte silencieuse ; vérifier la présence de chaque `ref` attendu.

## 5. Plan incrémental proposé (jalons + critères + dépendances)

**J1 — Brancher la capture et la validation (sans réécrire).** Dépendances : `judge_prompt.capture_memory_sources` (existe), `validate_state_update` (existe). Critère : test adversarial 1 et 2 passent ; import effectif de `capture_memory_sources`. Risque si ignoré : journal d'avis LLM contaminé.

**J2 — Réducteur + projection à budget fixe.** Dépendances : J1. Critère : un journal de N événements produit une projection dont la taille ≤ B, sans perte de `event_id`/`ref` critiques (test 4, 10). Risque : perte silencieuse d'un recadrage utilisateur.

**J3 — États visibles spécialistes (file/en cours/prête/échec).** Dépendances : J1 (provenance). Critère : `specialist_supervisor.py` expose un `queue_state` par tâche ; test 6 passe. Risque : surcharge Ollama.

**J4 — Plafond 4 simultanés / 20 appels session.** Dépendances : J3. Critère : test de 5ᵉ appel (refus/file) ; comptage par `session_id`. Risque : appels bloquants à 300 s (timeout `DEFAULT_TIMEOUT_S` de `specialist_runner.py`).

**J5 — Juge de relecture profonde.** Dépendances : J1-J4. Critère : question unique + transcript complet (bornée), déclenchement périodique (≠ `audit_interval` actuel) et sur doute (`analysis_state=uncertain`), avec cooldown. Risque : double coût LLM.

**J6 — Recette visuelle et multi-plateformes.** Dépendances : J1-J5. Critère : captures UI sur 800x480 (cible IHM `INV-HMI-02`), Claude/Codex/AGY/DSH (`platform_adapters.normalize`), et lecture de `POINT_CURRENT.md` hors UI (déterministe). Risque si ignoré : régression silencieuse côté DSH (zstd) ou AGY.

**J7 — Recette adversaire reproductible.** Test 1-10 exécutés une fois, avec preuves brutes stockées sous `DOC/WFLOW/TASKS/T431_*/PREUVES/` (conforme `INV-STD-01`). Risque : auto-référence si les tests s'appuient sur le même journal contaminé.

## 6. Risques résiduels et limites de couverture

- **Limite déclarée :** le corpus ne contient ni `AGENTS.md`, ni `DOC/WFLOW/TASKS.yaml`, ni `TASKS/T429_*`/`T431_*`, ni le plan T429. Les « écarts T429 » ci-dessus sont donc tirés du code et des tests fournis, pas du plan formel ; toute validation T429 contre le contrat réel reste hors de portée.
- **Rapports historiques** : les tests (`test_t429_regressions.py`, `test_specialist_runner.py`, `test_judge_prompt.py`) sont des **déclarations datées** ; je n'ai pas exécuté `pytest`. Les verts ne sont pas reproduits ici.
- **Spécialistes OOA** : les fichiers `TOOLS/AGENT_WORKFLOW/specialists/FB_Agent_*.md` sont fournis, mais leur « présence effective sous `TOOLS/AGENT_WORKFLOW/specialists/` » n'est pas prouvée par `os.path.exists` réel ; seul l'import `ROLE_MAP` est testé.
- **UI** : `index.html` confirme les boutons `Reprendre`, `Clôturer`, `Pause`, `Supprimer`, `Copier pour le chat` et la commande `/review-session-supervisor`, mais la recette visuelle n'est pas dans le corpus ; aucune capture fournie.
- **Cloud/consentement** : `check_model_consent` est présent, mais la `judge_settings` par défaut (`DEFAULT_MODEL="deepseek-v4.1-flash:cloud"`) et `allow_cloud=False` signifient qu'aucun envoi par défaut ; comportement non testé dans le corpus (tests utilisent `with_alert` sans `allow_cloud`).
- **`supervisor_service.py` non exécuté** : présence de `POINT_CURRENT.md` (nom) — la note réelle est `POINT_CURRENT.md` dans `_render_note` sous `POINT_CURRENT.md`, mais `_note_path` construit `POINT_CURRENT.md` (constante string) ; je n'ai pas pu confirmer que l'UI lit ce nom (le brief parle de `POINT_COURANT.md`). À vérifier en revue dédiée.

**Décision recommandée :** ADVISORY — ne pas déclarer PASS ; ouvrir J1 et J2 avant toute annonce de T429 stabilisé, puis J3-J7 pour T431. Aucune écriture, aucun test exécuté, aucune référence de ligne `CODE/` n'a été invoquée au-delà de ce que les sources Python fournies contiennent explicitement.

---

## 7. Notes de couverture et tokens

- **Sources exploitées** : `supervisor_service.py`, `judge_prompt.py`, `finding_lifecycle.py`, `session_watcher.py`, `dsh_session_watcher.py`, `platform_adapters.py`, `specialist_runner.py`, `challenge_runner.py`, `specialist_supervisor.py`, `review_session.py`, `agent_chat.py`, `connect_session.py`, `supervisor_server.py`, `upgrade_legacy.py`, `test_t429_regressions.py`, `test_judge_prompt.py`, `test_specialist_runner.py`, `index.html`, prompts `DOC/WFLOW/PROMPTS/SPECIALISTS/*.md`, `FB_Agent_*.md`.
- **Non couvert** : `AGENTS.md`, `TASKS.yaml`, plan T429 lui-même, exécution `pytest`, captures UI. Ces limites restreignent le verdict mais ne l'invalident pas sur les points sourcés.
- **Volume** : environ 1 900 mots (hors notes finales). Aucun outil machine exécuté ; aucun fichier écrit ; aucun commit/push.
- **Auto-revue** : chaque `[✅]`/`[❌]` s'appuie sur un symbole ou test nommé dans le corpus ; les points `[⚠️ N/A]` sont explicitement des **non-implémentations** (absence de preuve) et non des échecs d'exécution, à ne pas confondre avec un FAIL d'implémentation.