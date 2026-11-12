🟡 **ADVISORY** — Le filtre « seules les sessions précédemment actives reprennent » tient sur le cas nominal, mais le démarrage force une reprise `mode="normal"` qui jette le delta de continuité sans analyse et peut rétrograder définitivement une session en pause sans aucune trace d'erreur.
**Verdict** : 🟡 ADVISORY — 2 corrections obligatoires avant clôture + 1 non-conformité littérale possible à AC-F1.4 (arbitrage propriétaire requis).
**Impact** : au premier `/start`, une session sauvée `enabled=true` peut perdre son delta vérifié et/ou être persistée `enabled=false` après un simple échec de résolution de source, sans message ni événement.
**Limite de session** : analyse **statique uniquement**, aucun test exécuté, aucune horloge/système accessible → horodatage non disponible.

---

## Niveau 1 — Invariants vérifiés (statique)

1. **Filtre nominal au démarrage : seules les sessions `saved_enabled` reprennent** — `[✅ PASS]` — Preuve : `_load` pose `session["saved_enabled"] = bool(value.get("enabled", False)) and not session["closed"]` ; la boucle `action == "start"` saute `closed`/`state=="closed"` puis `if not session.get("saved_enabled"): continue`.
2. **Session clôturée jamais rouverte** — `[✅ PASS]` — Double garde : skip dans la boucle + `_resume_session` lève `ValueError("Session clôturée / figée …")` en tête.
3. **Session en pause non réactivée implicitement (y compris après persistance)** — `[✅ PASS]` — `_load` crée la session avec `enabled=False` (`_new_session(..., False, ...)`), seule la boucle de reprise peut la repasser à `True` ; `_persist` réécrit `enabled` tel quel.
4. **Session active reprise avec une source réellement attachée** — `[❌ FAIL]` — Le test accepte `state in ("active","waiting")` : un `enabled=True` sans `watcher` (échec silencieux d'attache) passerait au vert.
5. **AC-F1.4 « une continuité rompue ne reprend jamais implicitement »** — `[❌ FAIL]` — Contradiction interne : le garde-fou `if recovery.get("status") in ("unverified","too_large") and mode is None: … return` est court-circuité par l'appelant qui impose `session_mode = "normal"` pour exactement ces statuts.
6. **Traçabilité et véracité du motif de reprise** — `[❌ FAIL]` — La reprise automatique écrit `recovery = {"status":"skipped","reason":"user_chose_normal_resume", …}` : motif attribué à l'utilisateur alors que la machine a décidé, et aucun `record_event` (contrairement à pause/reassign/set_mission).
7. **Aucune perte silencieuse d'état** — `[❌ FAIL]` — `except Exception: pass` autour de `_resume_session` : la session reste `enabled=False` **et** est persistée comme telle au `_persist_background()` final ; à la fois suivante `saved_enabled=False` → plus jamais retentée.
8. **Pas de fenêtre de crash destructrice pendant la boucle** — `[❌ FAIL]` — `_persist_background()` est appelé **avant** la boucle de reprise : toutes les sessions sont alors écrites `enabled=false` sur disque. Un arrêt brutal (ou un `OSError` du second persist) pendant la boucle rétrograde définitivement les sessions non encore traitées.
9. **`saved_enabled` non périmé dans la vie du processus** — `[❌ FAIL]` — Capturé une seule fois dans `_load`, jamais rafraîchi par `pause`/`close`/`add`. Conséquence : (a) une session ajoutée à chaud n'a **pas** la clé → jamais auto-reprise ; (b) une pause à chaud ne changerait pas le filtre (masqué aujourd'hui uniquement parce que `start` après `stop` est neutralisé par `if not self._threads:`, `stop` ne vidant pas `_threads`).
10. **Crash de reprise (`recovery.status` = `processing`/`error`)** — `[🟡 ADVISORY]` — Reprise/retry automatique du lot au démarrage sans consentement (branché sur le `else` du bloc `("processing","error")`) : boucle de retry possible à chaque redémarrage si l'erreur est déterministe.
11. **Coût de démarrage borné** — `[🟡 ADVISORY]` — Pour toute session réelle (`source_checkpoint` présent → statut converti en `pending_check`), `_preview_recovery` lit et batche jusqu'à 5 Mo de delta sous verrou… puis `mode="normal"` jette le résultat via `candidate_checkpoint` (curseur sauté). Travail payé deux fois, `/start` bloquant.
12. **Aucune action destructive / aucun commit proposé** — `[✅ PASS]`.
13. **Preuve d'exécution des tests** — `[⚪ N/A]` — Aucun test lancé dans cette session ; le verdict porte sur le code, pas sur un run.

---

## Niveau 1 bis — Argumentaire technique

**Le filtre est juste, le point dur est ailleurs.** La sélection `saved_enabled` est correcte et le test pin bien les trois cas nominaux (actif / pause / clos). Le défaut n'est pas « qui reprend » mais **comment** il reprend : pour `unverified`, `too_large` et `gap_available`, la boucle impose `mode="normal"`, ce qui fait franchir au code le garde-fou AC-F1.4 qui exige une décision explicite.

**Mécanique exacte du delta perdu.** `_preview_recovery` calcule `candidate_checkpoint` en fin de delta manqué. Le chemin `mode=="normal"` exécute `candidate=recovery.pop("candidate_checkpoint", None)` puis `session["source_checkpoint"]=candidate` : le curseur saute **par-dessus** les messages, `recovery` devient `skipped` avec `message_count` conservé mais contenu jamais analysé. Si la source a été réécrite pendant l'arrêt, le sous-`except` reconstruit un watcher neuf (`source_generation` neuf, `source_event_index` remis à l'état du checkpoint) et libelle `reason="continuity_unverified"` avec `status="skipped"` — rompant la symétrie avec le test `test_resume_without_mode_after_rewrite_never_skips_silently` qui, lui, exige `status="unverified"`.

**Deux pertes silencieuses cumulables.** (a) `except Exception: pass` avale `ValueError("Source indisponible ; reprise impossible")` quand le transcript a disparu : pas de `error`, pas d'événement, état visuel « paused » inexpliqué. (b) Le `_persist_background()` d'avant-boucle écrit `enabled=false` pour tout le monde : la rétrogradation devient durable dès la première exécution, même si la reprise échoue pour une raison transitoire. C'est le scénario « crash » que la question demandait de vérifier — il est réel, étroit mais non couvert.

**Ce que le test prouve et ne prouve pas.** Il prouve l'exclusion des sessions `enabled=false`/`closed=true` au chargement. Il ne prouve pas : l'attache effective d'une source (assertion laxiste `("active","waiting")`), l'absence de polling/juge sur la session en pause, la durabilité de la pause sur un **second** redémarrage, l'interaction avec `saved_enabled` absent (session `add` à chaud), ni aucun des statuts de continuité (`pending_check`, `gap_available`, `too_large`, `processing`, `error`). Le transcript factice `{"type":"user","message":"hello active"}` n'utilise pas la forme canonique (`message.content`), donc `normalize` le rejette probablement : la session « active » ne collecte rien, ce qui affaiblit encore la portée du vert. Enfin `context_chars=10000 + output_tokens=1600 + 4096 = 15696` frôle la borne `model_context_tokens=16384` : toute retouche de la marge casserait le test pour une raison sans rapport.

---

## Niveau 2 — Plan d'action chirurgical

1. **Corriger le contournement AC-F1.4**
   - *Localisation* : `Supervisor._command`, branche `action == "start"`, boucle `for sid, session in list(self.sessions.items())`.
   - *Ancre* : `session_mode = "normal" if rec_status in ("gap_available", "unverified", "too_large") else None`.
   - *Action exacte* : passer `mode=None` pour `unverified`/`too_large` (la session reste en pause avec `error="continuity_unverified"`, reprise explicite obligatoire) ; pour `gap_available`, soit `mode="history"` (rattrapage borné), soit `mode=None` + affichage « delta en attente ».
   - *Outil déterministe* : `python -m pytest TOOLS/AGENT_SUPERVISOR/tests/test_t429_regressions.py -q -k "resume_without_mode or auto_resume"`.
   - *Risque si ignoré* : clause d'acceptation déclarée mais non tenue ; un delta de décisions utilisateur (GO/refus) est perdu sans analyse.

2. **Supprimer l'attribution mensongère et tracer l'auto-reprise**
   - *Localisation* : `Supervisor._resume_session`, branches `elif mode=="normal" …` et sous-`except`.
   - *Ancre* : `"reason":"user_chose_normal_resume"`.
   - *Action exacte* : renommer en `"auto_resume_at_startup"` avec `auto=True`, et ajouter `record_event(session, "startup_resume", f"{before} → {after}", timestamp())` dans la boucle `start` (une ligne par session reprise **et** par session échouée).
   - *Outil déterministe* : assertion d'un `event["kind"]=="startup_resume"` dans le test durci (action 4).
   - *Risque si ignoré* : audit trail faux ; impossible de distinguer une reprise humaine d'une reprise machine dans `session_journal`/`events`.

3. **Rendre l'échec visible et non destructif**
   - *Localisation* : `action == "start"`, `except Exception: pass` + `self._persist_background()` placé avant les threads.
   - *Action exacte* : remplacer par `except (OSError, ValueError, TypeError, KeyError) as exc:` → `session.update(enabled=False, state="paused", error="startup_resume_failed")` + `record_event(..., type(exc).__name__)` ; et déplacer le **premier** `_persist_background()` **après** la boucle (un seul persist final), pour fermer la fenêtre `enabled=false` sur disque.
   - *Outil déterministe* : test de non-régression — monkeypatcher `_resume_session` pour lever, appeler `start`, puis `json.loads(state_path)["sessions"][i]["enabled"]` doit rester `true` et `error == "startup_resume_failed"`.
   - *Risque si ignoré* : perte définitive et silencieuse d'une session surveillée après un simple incident de résolution de source.

4. **Durcir `test_t429_auto_resume_only_previously_enabled_sessions`**
   - *Localisation* : `TOOLS/AGENT_SUPERVISOR/tests/test_t429_regressions.py`.
   - *Action exacte* : (a) forme canonique du transcript (`{"type":"user","message":{"role":"user","content":[{"type":"text","text":"…"}]}}`) ; (b) `assert s_active["watcher"] is not None` (ou `source` non nul) au lieu de `state in ("active","waiting")` ; (c) compter les appels au juge injecté : 0 pour `paused` et `closed`, ≥1 pour `active` ; (d) relancer un **second** `Supervisor(...)` sur le même `state.json` et revérifier que `paused` reste `enabled=False` ; (e) cas additionnel : session `enabled=true` + source supprimée → `error` non nul, `enabled=False`, pas d'exception silencieuse ; (f) paramétrer sur `recovery.status ∈ {pending_check, gap_available, too_large}`.
   - *Outil déterministe* : `python -m pytest TOOLS/AGENT_SUPERVISOR/tests/test_t429_regressions.py -q` puis suite complète `python -m pytest TOOLS/AGENT_SUPERVISOR/tests -q`.
   - *Risque si ignoré* : vert décoratif ; le prochain refactor du filtre ou de `saved_enabled` cassera la reprise sans qu'aucun test ne rougisse.

5. **Assainir `saved_enabled` (dette de conception, à cadrer avant d'agir)**
   - *Localisation* : `Supervisor._load` (pose), `_command` branches `pause`/`close`/`add`/`stop`.
   - *Action exacte* : soit le maintenir à jour à chaque transition (`pause` → `saved_enabled=False`, `add` → `saved_enabled=True`), soit le remplacer par une projection explicite `persisted_enabled` lue au démarrage. Décision produit nécessaire : « start après stop doit-il reprendre ? » (aujourd'hui : non, à cause de `if not self._threads:`).
   - *Outil déterministe* : test `add` → `stop` → `start` → comportement attendu figé, et `add` → `pause` → `close` → `start` → la session ne doit pas ressusciter.
   - *Risque si ignoré* : asymétries invisibles (session ajoutée à chaud jamais reprise, pause à chaud non reflétée) selon l'ordre des actions UI.

*Inconnues à lever côté propriétaire* : (i) les numéros de ligne 551-554 / 1283-1296 n'étant pas vérifiables sur le texte fourni (fichier non numéroté), j'ai ancré l'audit sur les extraits de code identifiés, pas sur les numéros ; (ii) comportement pré-T429 inconnu (pas de diff fourni) ; (iii) AC-F1.4 considère-t-il une reprise auto au démarrage comme « explicite » ? Toute la gravité de l'invariant 5 dépend de cette réponse.

```yaml
challenge_evaluation:
  version: "1.0"
  subject: "T429 — auto-resume sélectif au démarrage du superviseur"
  prompt_status: "HARDENED"
  verdict: "ADVISORY"
  target_goal: "Seules les sessions laissées enabled reprennent au démarrage, sans jamais ressusciter pause/clôturée ni rompre implicitement la continuité."
  non_goals:
    - "Ne pas modifier le filtre pour inclure les sessions en pause ou clôturées"
    - "Ne pas relancer automatiquement une continuité unverified/too_large sans décision utilisateur"
    - "Aucun commit/push, aucun test exécuté dans cette expertise"
  emergent_ideas:
    - title: "Motif d'auto-reprise dédié + événement de journal"
      gain: "Audit trail véridique, distinction humain/machine dans session_journal"
      safety_guard: "record_event('startup_resume') émis avant tout persist"
    - title: "Rendre la reprise atomique vis-à-vis du disque"
      gain: "Ferme la fenêtre de crash qui persiste enabled=false avant la boucle"
      safety_guard: "Un seul _persist_background() après la boucle de reprise"
    - title: "Réutiliser le preview au lieu de le jeter"
      gain: "Supprime une double lecture de 5 Mo par session et un blocage de /start"
      safety_guard: "mode='history' borné ou conservation du gap_available affiché"
  identified_indirect_risks:
    - risk: "Contournement local de AC-F1.4 : reprise implicite d'une continuité rompue via mode='normal' forcé au démarrage"
      severity: "HIGH"
      mitigation: "mode=None pour unverified/too_large ; choix explicite ou mode='history' pour gap_available"
    - risk: "Perte définitive et silencieuse d'une session surveillée (except Exception: pass + enabled=false persisté)"
      severity: "HIGH"
      mitigation: "except typé, error='startup_resume_failed', record_event, persist unique après la boucle"
    - risk: "Delta de décisions utilisateur (GO/refus pendant l'arrêt) compté mais jamais analysé"
      severity: "MEDIUM"
      mitigation: "Ne pas sauter candidate_checkpoint en silence ; exposer le gap et proposer le rattrapage"
    - risk: "Vert décoratif du test (state in ('active','waiting'), transcript non canonique, mock de _validate_assignment)"
      severity: "MEDIUM"
      mitigation: "Assertions watcher/juge, forme canonique, second redémarrage, cas source supprimée"
    - risk: "saved_enabled périmé dans la vie du processus (pause à chaud, add à chaud, start après stop neutralisé)"
      severity: "MEDIUM"
      mitigation: "Mettre à jour saved_enabled sur pause/close/add ou le remplacer par une projection dérivée explicite"
  recommended_action:
    - file: "TOOLS/AGENT_SUPERVISOR/scripts/supervisor_service.py"
      summary: "Branche start : session_mode=None pour unverified/too_large ; record_event par session reprise/échouée ; except typé au lieu de pass"
    - file: "TOOLS/AGENT_SUPERVISOR/scripts/supervisor_service.py"
      summary: "Déplacer _persist_background() après la boucle de reprise pour supprimer la fenêtre enabled=false sur disque"
    - file: "TOOLS/AGENT_SUPERVISOR/scripts/supervisor_service.py"
      summary: "Remplacer reason='user_chose_normal_resume' par 'auto_resume_at_startup' + flag auto dans _resume_session"
    - file: "TOOLS/AGENT_SUPERVISOR/tests/test_t429_regressions.py"
      summary: "Durcir test_t429_auto_resume_only_previously_enabled_sessions (watcher, compteur de juges, second redémarrage, source supprimée, statuts de recovery)"
    - command: "python -m pytest TOOLS/AGENT_SUPERVISOR/tests/test_t429_regressions.py -q"
      summary: "Preuve déterministe à exécuter par le responsable avant clôture ; non exécutée ici"
```