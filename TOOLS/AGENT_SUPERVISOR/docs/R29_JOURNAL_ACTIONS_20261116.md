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

---

## 12:07 → 12:16 · Logs debug + P7 + restart réel (A12-A16)

### A12 — 12:07 · Logs de debug du serveur (demande exploitant)
- Fichier : `supervisor_server.py` — requêtes HTTP (POST + erreurs ; polls GET 200 muets),
  commandes API (action, cible, ok/ECHEC), PRET avec build/python, chemin d'état persisté,
  rotation du journal à 2 Mo
- Preuve live : les nouveaux logs ont tout de suite servi — `commande -> ECHEC :
  JSONDecodeError` (mon POST mal échappé) visible dans le journal
- Commit `80986343` (rapide checkpoint, à la demande)

### A13 — 12:12 · P7 : re-rattachement de session clôturée (id conservé)
- Fichier : `supervisor_service.py` (handler add) — session clôturée du même native_id
  relancée SUR L'ID EXISTANT (au lieu d'inventer un assignment_id neuf à chaque fois) ;
  événement `session_reattached` tracé
- Preuves : `test_connect_session 11 passed` avec le service réel en marche (gardes
  conftest actifs, états isoles dans %TEMP%\pytest) ; journal : `purge ignoree`
- Commit `dc088b5f`

### A14 — 12:14 · Découverte : `restart_service` répond "ok" mais ne relance JAMAIS
- Preuves journal : `action=restart_service -> ok` puis aucun `SCRIPT LANCE` derrière
- Cause : `os.execv` non fiable sous Windows + chemin de script relatif
- Fix : spawn détaché du même script (chemin absolu, `CREATE_NEW_PROCESS_GROUP` +
  `DETACHED_PROCESS`) puis `os._exit(0)` de l'ancien
- **Preuve en réel** : commande 12:16:10 → nouveau pid 21796 (`SCRIPT LANCE` 12:16:20)
  → `VERDICT libere (killed=[5640])` → PRET, état conservé
- Commit `6c33499d` (erreur corrégée au passage : un vidage du journal dans un premier
  jet du patch a été retiré avant commit — le journal est une archive)

### A15 — 12:16 · État machine final
- 8082 : process auto-relancé pid 21796, build `aaba0ba8c629`, `update_available: false`
- 8081 : TM de l'exploitant en marche
- Exploit prêt pour un essai réel de `/connect-session-supervisor` (P7 en service)

---

## 2026-11-17 · Consigne T427-CC02 (TORC, fiche, inactivité) — A16-A19

### A16 — RECU à T427-CC02 (PE 2026-11-17) + plan approuvé exploitant
- 3 constats : TORC pas reconnu coordination · fiche vide muette · 0 veille d'inactivité
- Approbation exploitant : plan 3 correctifs + forme alerte = constat mécanique seul par défaut

### A17 — Implémentation (commit `3aef23a3`, 18 tests verts)
- B : `is_coordination_session` reconnait T000*/TORC* (+ notice juge TORC)
- C : `_detect_inactive_sessions` au cycle de poll (fingerprint, idempotent), seuils 4 h
  coordination / criticité contrat (cache mtime, C2=12 h, défaut 24 h)
- A : fiche jamais vide — règle exploitant « N/A — raison » pour tout champ non rempli ;
  TEMPLATE COORDINATION auto-rempli pour T000*/TORC* (objectif + 5 critères de gouvernance,
  les mêmes que la notice) ; backfill des fiches vides héritées au re-rattachement
  (`fiche_completee: true`) ; PAS de constat cadrage redondant quand la fiche porte son état
- Preuve live (essai isolé 8093, coupé après) : attach TORC → fiche remplie ;
  `is_coordination_session("TORC-CC10") == True`
- Correctif au passage : `structure_quality.contract_for` invisible pour T432 (CONTRACT/rglob)

### A18 — Relai restart : de la mort muette au cycle complet
- Enfants du relai mouraient SANS TRACE (`can't open file ...AGENT_SUPERVISOR...` —
  chemin erroné, sans TOOLS/ ; trouvé grace au journal enfant→journal du relai v2)
- Fix `task_server.py` (dérogation « ok ») : chemin correct ; + journal des enfants
  dirigé dans le journal service ; + drapeau consommé (pas de boucle 20 s)
- PREUVE réelle complète : 1-clic → `[TM] RESTART : enfant relai lance` → purge de
  l'ancien (VERDICT libere) → `PRET build=2965f79ee90a`, `update_available: false`
- État final : 8082 pid 41576 (build final), 8081 TM pid 13960 (relai actif, caché)

### Reste à l'exploitant
- Fermer la 1 le constat `Session de coordination sans cadrage` de TORC (règle 10 : un clic) ;
  une re-attach TORC posera la fiche template complète désormais.
