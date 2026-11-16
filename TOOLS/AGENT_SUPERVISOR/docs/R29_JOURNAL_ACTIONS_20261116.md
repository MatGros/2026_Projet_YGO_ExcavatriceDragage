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
  l'inventaire des problèmes, pas de spéculation.
