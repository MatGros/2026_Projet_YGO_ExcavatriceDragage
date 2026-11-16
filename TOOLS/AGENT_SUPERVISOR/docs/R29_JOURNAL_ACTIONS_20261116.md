# R29 — Journal des actions (T429-MMX01) · 2026-11-16

Journal tenu à la demande de l'exploitant ("trace bien ce que tu fais"). Chaque entrée :
horodatage, action, périmètre, preuve/fichier. Complète les commits git et le journal du
service (`%LOCALAPPDATA%\ExcavatriceDragage\agent-supervisor-server.log`).

---

## 2026-11-16 · 11:48 → en cours

### A1 — 11:47 · Diagnostic du crash des serveurs (lecture seule)
- Investigation agent Explore : journal WER Windows (0 crash applicatif), journal du
  service (listes de PIDs tués), code fautif identifié
- Preuve : `supervisor_server.py:149` — filtre sous-chaîne `':0 '` matchait la colonne
  DISTANTE `0.0.0.0:0` de toute ligne LISTENING → massacre des listeners réels à chaque
  serveur de test
- Journal du service : lignes archivées `11:21:05` et `11:44:19` (`killed=[...8744, 27672...]`)

### A2 — 11:50 (plan approuvé) · Correctif kill_port_listeners
- Fichier : `TOOLS/AGENT_SUPERVISOR/scripts/supervisor_server.py`
- Parsing par colonnes netstat ; colonne 1 = adresse locale ; purge refusée si port <= 0
- Re-vérif du verdict (netstat post-kill) mise au même parsing par colonnes

### A3 — 11:51 · create_server : pas de purge pour port éphémère (0)
- Fichier : `TOOLS/AGENT_SUPERVISOR/scripts/supervisor_server.py`
- `port <= 0` → log "bind ephemere (port 0) : purge ignoree", aucun kill

### A4 — 11:52 · Garde-fou tests (fix:+guard)
- Fichier : `TOOLS/AGENT_SUPERVISOR/tests/test_purge_guard.py` (nouveau, 3 tests)
- netstat factice reproduisant les lignes de l'incident ; pid simulé (999999) ;
  os.kill intercepté — vérifié : aucun kill réel pendant les tests
- RUN ciblé : `pytest .../test_purge_guard.py -q -x` → **3 passed** (journal : verdicts
  factices `killed=[27672, 27672]`, service réel non touché)

### A5 — 11:52 · Taisement du bruit client (aborts de pollers)
- Fichier : `supervisor_server.py` — `_silence_client_abort` : ConnectionAborted/
  ConnectionReset/BrokenPipe silencieux, tout autre défaut reste tracé
- Motif : spam `WinError 10053/10054` dans la console de l'exploitant, pas un défaut

### A6 — 11:54 · Run de non-régression ciblé (en cours, arrière-plan)
- `pytest test_purge_guard.py test_connect_session.py -q -x --tb=short` (2 fichiers ciblés,
  état tmp_path, garde conftest actif) — service réel 8082 en marche pendant le run
  (c'est le point du plan de correction : il doit SURVIVRE au run)

### A7 — État machine au moment A6
- 8082 : pid 31720 (build 1d44bc96223e = code corrigé purge, SANS le taisement A5)
- 8081 : pid 45304 (TM)
- Reste à faire après A6 : restart 8082 pour A5, commit A2-A5, inventaire P1→P5

### Question ouverte (Q1)
- Mort de l'ancien serveur 46508 entre 11:48:35 et 11:53:03 : mon run de test n'a tué
  personne (preuve journal factice ci-dessus) — cause non tranchée, notée dans
  l'inventaire des problèmes, pas de spéculation. (Exploitant : « on verra après »)

---

## 11:54 → 11:58 · Clôture de l'incident (A8-A11)

### A8 — 11:54 · main() restructuré
- Le thread serveur s'appelle via `run_forever()` : toute mort du thread est journalisée
  (« THREAD SERVEUR MORT : + traceback ») — fini les morts sans explication
- `shutdown()` n'est appelé que si le thread est encore vivant (sinon blocage infini,
  preuve console exploitant : traceback dans `socketserver.shutdown.wait`)

### A9 — 11:55 · Preuves du correctif en conditions réelles
- Run pytest ciblé (2 fichiers) pendant que le service réel tournait : **exit 0, service
  survivant** — journal live `11:53:55 bind ephemere (port 0) : purge ignoree`
- Le garde conftest + le fix purge ont tenu ensemble

### A10 — 11:55 · Bascules du service
- 46508 → 46588 → 28624 → 41768 → **42168**, chaque purge tracée avec `VERDICT port 8082 :
  libere (killed=[pid])` (parsing colonnes confirmé live)
- État final : 8082 pid 42168, build `49f3ac4aa683`, `update_available: false`

### A11 — 11:56 · Commit incident
- `3dce9dce` : fix purge + re-verif par colonnes + run_forever journalisé + taisement
  aborts + conftest garde + test_purge_guard (3 tests) + journal d'actions + RECU T432
