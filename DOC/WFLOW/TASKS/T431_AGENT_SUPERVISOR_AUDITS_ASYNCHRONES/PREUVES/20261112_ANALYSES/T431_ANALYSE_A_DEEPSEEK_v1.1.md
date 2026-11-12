🟡 **ADVISORY** — T429 n'est pas dans l'état que son contrat déclare : les rapports historiques affirment un PASS quasi-général, mais le corpus fourni contient des preuves exécutées qui contredisent cet état (baseline « 6 failed, 41 passed », revue finale A en HOLD, AC-F3.5 FAIL démontré). Pour T431 (superviseur permanent + juge contexte récent + spécialistes éphémères + mémoire longue), la matière existe à l'état de **prompts de challenge**, jamais de spécification validée. Décision recommandée : ne pas clore T429, ne pas démarrer T431 sur cette base sans lever 4 points bloquants nommés ci-dessous.

Durée/horodatage : non disponibles (aucun accès horloge machine, analyse sur corpus fermé).

## Niveau 1 — Invariants audités

1. **État réel T429 vs auto-déclaration du contrat** — `[❌ FAIL]` — `T429_AGENT_SUPERVISOR_CONTRAT_FIABILISATION_20261109_v1.0.yaml` §tracking.established affirme « AC-X.2 PASS : pytest 171/171 passed » ; la preuve `PREUVES/20261110_SESSION_LOT2_CODEX/T429_PREUVE_LOT2_REGRESSIONS_20261109_v1.0.txt` affiche « 6 failed, 220 passed in 27.66s », et `T429_PREUVE_LOT2_BASELINE_20261110_v1.0.txt` reproduit « 6 failed, 41 passed in 9.88s » sans le lot. Les 6 échecs sont attribués par `RAPPORT_LOT2_CODEX_20261110` §Limites à des causes préexistantes (persistance transcriptions ×2, reprise source, budget 6000→12000, rollback, constat acquitté) — attribution plausible, non vérifiée depuis l'extérieur.

2. **Cohérence des revues finales entre elles** — `[❌ FAIL]` — `REVUE_FINALE_AGENT_A_20261109` : HOLD, aucun critère validé (absence d'accès). `REVUE_FINALE_GLM_20261109` : AC-F1.7/F3.5/X.1 PASS, clôture recommandée. `REVUE_FINALE_DEEPSEEK_20261109` : « ne pas clore T429 sur ce dossier », AC-F3.5 « insuffisant », AC-X.2 « preuve absente ». `REVUE_FINALE_AGENT_B_20261109` : « GO conditionnel » sous condition C1. **Deux sur quatre recommandent la clôture, deux la refusent** : ce désaccord n'est arbitré nulle part dans le corpus. Le contrat §validation.status reste `PENDING`, cohérent avec ce désaccord.

3. **AC-F3.5 (notification + son + clic cible)** — `[❌ FAIL]` sur la branche notification bureau — `REVUE_CHALLENGE_A_DEEPSEEK` §3.1 analyse `ui/index.html` l.472-478 : `note.onclick = () => { window.focus(); note.close(); }` ne propage ni `session` ni `alert`. `REVUE_FINALE_DEEPSEEK` §3 confirme : la preuve `VEILLEUR_UI_DEEP_LINK=1` produit une sortie « strictement identique au run standard », donc le chemin deep-link n'est pas exercé. `REVUE_FINALE_GLM` accorde néanmoins PASS en notant cette même faiblesse « non bloquante ». Preuve E2E `T429_PREUVE_NOTIFICATION_E2E_20261109_v1.0.json` §limits : « Rendu de la notification Windows, son audible et toast dans une fenêtre VS Code réelle : à confirmer par l'exploitant ». **Le PASS contractuel repose sur une déclaration exploitant absente du dossier fourni.**

4. **AC-F3.9 (ergonomie globale « un utilisateur trouve, comprend et traite sans aide »)** — `[⚪ N/A / non instruit]` — `REVUE_FINALE_GLM` §1 : « disparu des questions posées, aucun mappage de preuve ». `REVUE_FINALE_DEEPSEEK` §5 : « non instruit ». `REVUE_CHALLENGE_ERGONOMIE_DEEPSEEK` §0 : « je n'ai pas ouvert `TOOLS/AGENT_SUPERVISOR/ui/index.html` dans ce tour ». Aucun verdict fiable possible.

5. **Garde anti-faux-PASS (AC-F2.8/C1)** — `[🟡 ADVISORY]` — `REVUE_FINALE_AGENT_B` §2 démontre statiquement l'évasion pluriels (`12 échecs, 0 passed`, `118 passed, 2 errors`, `interrompue : 5 passed`). `DOSSIER_PREUVES_AUDIT_T429_20261109` §1 cite le correctif (regex `\b(?:non|not|failed|échec|echec|erreur|error|exception|traceback|interrompu)\b`). Le dossier ne contient ni la sortie des « 5 tests adversaires PASS » annoncés par le contrat, ni la version post-durcissement du regex (`erreurs?|échecs?|interrompue?`). L'assertion du contrat (§established, « C1 résolue ») est donc **déclarative, non prouvée sur le corpus**.

6. **Baseline LOT2 mal cadrée** — `[❌ FAIL]` méthodologiquement — `T429_PREUVE_LOT2_BASELINE_20261110_v1.0.txt` commence par « BASELINE RECONSTRUITE: HEAD + trois hunks settings/audit_interval présents avant lot2; aucun fichier source remplacé ». Ce n'est donc **pas une baseline neutre** : elle charge les hunks en mémoire, ce qui change les seuils (budget 6000→12000). Le rapport Codex reconnaît cette dette (§Limites) mais la compte comme « attribution des 6 échecs » — la démonstration est circulaire.

7. **Régressions auto-resume (ADR Challenge AUTO_RESUME)** — `[🟡 ADVISORY]` sérieux — `T429_REVUE_CHALLENGER_AUTO_RESUME_v1.0` §Niveau 1 invariants 4 à 9 démontre statiquement : (a) contournement AC-F1.4 par `session_mode="normal"` imposé au démarrage pour `unverified`/`too_large` ; (b) motif `user_chose_normal_resume` mensonger ; (c) `except Exception: pass` + `_persist_background()` **avant** boucle → session `enabled=false` persistée durablement ; (d) `saved_enabled` jamais rafraîchi après `add`. Limite de session : « analyse statique uniquement, aucun test exécuté ». Vérification indépendante impossible depuis ce corpus.

8. **Bug `_remember_source` / `state_update` invalide** — `[❌ FAIL]` selon la mission utilisateur — `DOSSIER_PREUVES_AUDIT` §2.2 cite le code actuel : `try: validate_state_update(...) except (ValueError, KeyError): pass` puis **append inconditionnel** dans `session_journal` avec `origin="agent_observation"`. Le `pass` signifie qu'une proposition invalide est **acceptée silencieusement** en observation. C'est un écart direct au besoin T429 (« état/source des avis LLM à décider ») et il est visible dans la source fournie.

9. **`capture_memory_sources` appelée en production** — `[⚪ N/A / non vérifiable]` — la fonction n'apparaît dans aucun extrait du corpus. Le rapport Codex §Limites dit « isolation du payload juge est prouvée mécaniquement ; le comportement d'un modèle réel n'est pas évalué ». La mission demande explicitement de signaler cet état — **le corpus ne permet pas de le trancher**.

10. **POINT_COURANT.md (projection potentielle)** — `[⚪ N/A]` — le fichier n'est pas joint, seulement mentionné. Aucune analyse possible.

## Niveau 1 bis — Argumentaire technique court

**Sur T429 — les trois rapports historiques n'ont pas la même valeur de preuve.** Le contrat §tracking.established liste 20 PASS en affirmant « 171/171 ». La preuve exécutée fournie (`REGRESSIONS_20261109_v1.0.txt`) montre 220 passed + 6 failed. Le rapport Codex dit que ces 6 échecs préexistaient (baseline 6 failed aussi). Sur le principe ce raisonnement est valide : 6 échecs préexistants ≠ régression introduite. Mais la baseline est **explicitement une reconstruction** (« HEAD + trois hunks »), pas un run sur HEAD nu. Donc on ne sait pas si les 6 échecs existaient avant les hunks. C'est exactement le type de « vert décoratif » que la revue finale B dénonçait pour `test_t429_auto_resume` — et que Codex applique à sa propre preuve LOT2.

**Sur AC-F3.5, le FAIL est solide.** Trois reviewers indépendants (Challenge A, Finale DeepSeek, Finale GLM en réserve) analysent le même `note.onclick` qui ne propage rien. Le patch correctif proposé par A (§5.1) n'apparaît pas dans le diff LOT2 fourni. Le PASS final repose sur une preuve [REEL] (observation exploitant) **absente du dossier**. C'est une validation par affirmation.

**Sur la mission T431, rien n'est mûr.** Le besoin utilisateur est explicite : superviseur permanent + juge contexte récent + N spécialistes éphémères + audits + 4 Ollama max/20 appels + états visibles + relecteur profond neuve + mémoire longue journal append-only. Les sources fournies contiennent trois artefacts **directement pertinents mais non validés** : (a) `T429_REVUE_CHALLENGE_MEMOIRE_LONG_TERME_DRIFT.md` §1-§4 — architecture append-only + réducteur + projection, avec budgets token ; (b) `TXXX_REVUE_CHALLENGE_INTEGRATION_MEMOIRE_LOT_C1.md` §2 — découpage C1 (prompt) / C2 (moteur) ; (c) `T429_REVUE_CHALLENGE_ERGONOMIE_DEEPSEEK` §4 — tableau exigences→critères. Ces trois textes sont des **revues de challenge** (rôle « reviewer indépendant, lecture seule »), pas des specs approuvées. Le besoin utilisateur est par ailleurs explicite sur un point que (a) ne traite pas : le rejet du résumé MD comme canonique (« tap unique inexistant », « epoch globale contestable ») — ce qui **invalide partiellement (a)**, dont tout le §3 repose sur `epoch` comparée.

## Niveau 2 — Plan INC rémental T431 (jalons, critères, tests adversaires, challenges, risques, dépendances, coordination, recette visuelle/multi-plateformes)

**Jalon J0 — préalable non négociable (bloque tout le reste)**
- Fermer ou requalifier T429. Deux issues possibles, à trancher par CDX05 (coordinateur) et l'exploitant : (i) **clore sur PASS avec dette listée** — le corpus l'autorise uniquement si l'exploitant fournit (a) observation [REEL] AC-F3.5, (b) hash `agent-supervision.json` avant/après baseline pour AC-X.2, (c) sortie brute du patch C1 sur les 3 cas adversaire. (ii) **rouvrir sur les 4 bloquants** : `note.onclick` AC-F3.5, `validate_state_update` silent-pass, `except Exception: pass` auto-resume, baseline LOT2 non neutre.
- Critère d'acceptation : décision écrite et horodatée, avec preuves attachées, dans `TASKS.yaml` (via API Task Manager, pas édition directe). Aucun jalon T431 ne démarre avant.
- Risque si ignoré : T431 héritera des mêmes patterns (`pass` silencieux, baseline reconstruite, PASS déclaratif) dans un outil plus large et plus difficile à auditer.

**Jalon J1 — contrat d'interface mémoire longue (spec figée avant code)**
- Livrable : schéma append-only `session/events.jsonl` (champs minimaux : `seq`, `ts`, `kind`, `source`, `payload_sha`, `payload_path`), réducteur pur, projection à budget fixe (§1 du challenge mémoire). Décision à acter explicitement : ce que remplace l'**« epoch globale contestable »** — proposition alternative : `source_generation` + `file_hash_prefix` versionnés par source, pas une epoch unique.
- Test adversaire obligatoire : replay 200 événements → projection ≤ 1000 tokens (mesurée avec le tokenizer réel du juge, pas `len()/4`), CAP jamais tronqué. Golden file commité.
- Dépendance : validation que `capture_memory_sources` (mentionnée par la mission, absente du corpus) sera branchée sur ce journal ou remplacée.
- Critère observable : un test de non-régression qui rejoue `capture_memory_sources` sur corpus et vérifie que chaque preuve promue est sourcée à un `event_id` existant.

**Jalon J2 — registre de preuves et anti-faux-PASS durci (héritage C1 + dette T429)**
- Livrable : version corrigée de `_remember_source` avec regex `erreurs?|échecs?|errors?|fail(?:ures|ed)|interrompues?` (reprise de la proposition B §2), et `validate_state_update` qui **refuse** explicitement au lieu de `pass` (log + refus traçable, pas d'append conditionnel).
- Tests adversaires obligatoires (3 cas B + 1 cas `state_update` invalide + 1 cas `state_update` valide) avec assertion sur l'état final du journal, pas seulement absence d'exception.
- Challenge : rejouer en aveugle `REVUE_FINALE_AGENT_B` sur la version corrigée — il doit **ne plus pouvoir** démontrer les évasions ; sinon le correctif est incomplet.
- Risque : élargir la regex peut rejeter des preuves légitimes contenant « error » en contexte neutre. Mitigation : test de non-régression sur les 26 tests `judge_behavior` actuels.

**Jalon J3 — superviseur permanent + juge contexte récent + spécialistes éphémères**
- Livrable : découpage explicite en 3 composants (reprenant `TXXX_REVUE_CHALLENGE_INTEGRATION_MEMOIRE_LOT_C1` Option 2) — juge permanent *stateless* / juge contexte récent *stateful court* / spécialistes éphémères à la demande.
- Sélection du spécialiste : sur **nouveau message utile** uniquement, jamais sur « rafale au message 8 » (exigence utilisateur explicite). Spécifier la définition d'« utile » dans le contrat d'interface, faute de quoi le critère est inobservable.
- Limites Ollama : 4 simultanés, 20 appels/session. Test adversaire = simuler 25 appels dont 4 déjà en cours → les 21ᵉ+ doivent être refusés avec message explicite, pas silencieusement jetés.
- États visibles : file / en cours / réponse prête / échec. Test DOM : chaque état rendu avec libellé et couleur distincte (reprise de la règle R6 ergonomie).
- Risque : starvation. `REVUE_CHALLENGE_FINAL_PLAN_20261109` §1 R3 nomme déjà la **starvation Alarm > Warning** ; le même défaut se répliquera entre spécialistes si la file n'a pas de politique d'aging. À cadrer dans ce jalon.
- Recette multi-plateformes : reprendre la méthodologie `T429_PREUVE_PLATEFORMES_REEL_20261109` (Codex/Claude/AGY PASS, DSH LIMIT) mais **déclarer DSH headless comme exception assumée** et le consigner dans le dossier de clôture. Multi-plateformes = Claude/Codex/AGY/DSH au moins en lecture.

**Jalon J4 — relecteur profond neuve (question unique + transcript complet)**
- Livrable : invocation `reviewer_neuf(question, transcript_path)` avec cooldown et couverture. Non déclenchable si cooldown actif (test : deux appels rapprochés → second refusé, motif affiché).
- Question unique : vérifier qu'une question multiple est **rejetée** par le validateur, pas concaténée silencieusement.
- Transcript complet : bornage mémoire obligatoire ; test sur transcript 10 Mo (`T429_PLAN_REPRISE...` §Intégrité mentionne 51 ms pour 50 Mo — à reconfirmer côté T431).
- Risque : le corpus T429 fournit plusieurs exemples où « transcript complet » n'est pas fourni (`REVUE_FINALE_AGENT_A` §0, `REVUE_CHALLENGE_C` §0 — « aucun accès »). Le contrat J4 doit imposer que la preuve [REEL] soit un chemin de fichier + hash, jamais une paraphrase.

**Jalon J5 — POINT_COURANT.md (projection) — préséance sur l'existant**
- Livrable : `POINT_COURANT.md` éventuellement dérivé du journal append-only, sans casser l'interface actuelle. Interdiction explicite : aucun contenu canonique **uniquement** dans `POINT_COURANT.md` ; le journal reste source de vérité (rejet utilisateur du « résumé LLM comme vérité canonique »).
- Test adversaire : si le journal et `POINT_COURANT.md` divergent, c'est `POINT_COURANT.md` qui est réputé faux — test qui injecte une divergence et vérifie que l'IHM signale l'écart, pas qu'elle l'écrase.
- Risque : la mission dit « POINT_COURANT.md est projection potentielle, préserver interface existante ». Sans le fichier, impossible de concevoir la migration. **Prérequis J5 : joindre `POINT_COURANT.md` au prochain tour.**

**Jalon J6 — recette visuelle multi-plateformes**
- Protocole écrit (capture écran + horodatage + version) pour chaque état (file, en cours, réponse prête, échec) sur 3 largeurs (1440/390/360 px, méthode `ui_layout_check.mjs` T429) et 4 plateformes (Claude/Codex/AGY/DSH).
- Déclaration **obligatoire** de ce qui n'est pas observé (repris de `T429_PREUVE_NOTIFICATION_E2E` §limits : « son audible non observable par un agent »).
- Signature : exploitant uniquement. Aucun agent ne s'auto-attribue AC-F3.5-equivalent.

**Coordination**
- Coordinateur : CDX05 (désigné par la mission).
- Aucun écrivain concurrent : un seul écrivain de code par jalon, règle reprise de `T429_CONTRAT_LOT1/LOT2`.
- Revue par lot : 2 challenges indépendants minimum, conformément à la doctrine T429. La mission T431 impose des spécialistes éphémères : ne pas confondre « spécialistes éphémères » (audit interne) et « challenges indépendants » (revue externe). Les deux sont nécessaires et ne peuvent pas être le même artefact.

**Risques transverses**
- (a) **Héritage T429** : les six échecs de baseline + les 4 bloquants J0 se propageront dans T431 si le code est réutilisé. Mitigation : J0 fermé avant J3.
- (b) **« Tap unique » inexistant** (mission utilisateur, rejet explicite du challenge mémoire §1) : sans point de passage unique des outils, le journal append-only mentira par omission (`T429_REVUE_CHALLENGE_MEMOIRE_LONG_TERME_DRIFT` §Risques 1 & 5 : « Décision à prendre avant T429-1 : le point de passage unique existe-t-il ? »). **À trancher avant J1.**
- (c) **Epoch globale contestable** : à remplacer par `source_generation` par source. Si non tranché, le test golden du J1 ne pourra pas être écrit.
- (d) **Dérive des rapports historiques** : le corpus T429 abonde en « déclarations datées, pas preuves d'état courant » (contrat YAML §tracking.established notamment). T431 doit imposer qu'un rapport sans chemin:ligne + sortie brute n'est pas une preuve.

**Dépendances à lever avant démarrage T431**
1. Décision J0 (clore ou rouvrir T429).
2. Présence du point de passage unique des outils (sinon chantier préalable).
3. `POINT_COURANT.md` joint.
4. `capture_memory_sources` : état réel d'appel production.
5. Version post-durcissement du regex C1 (absente du corpus).
6. Sortie brute des 6 échecs LOT2 sur HEAD **sans** les hunks settings/audit_interval.

## Limites de couverture et tokens

- **Couverture documentaire : partielle.** Le corpus contient 26 sources. Absents : `TOOLS/AGENT_SUPERVISOR/ui/index.html` (cité, jamais lu), `supervisor_service.py` ligne:ligne (extraits partiels seulement via `DOSSIER_PREUVES_AUDIT`), `POINT_COURANT.md`, `capture_memory_sources`, `TASKS.yaml`, `AGENTS.md`, la version finale du regex C1, la sortie des 5 tests adversaires annoncés par le contrat, la preuve [REEL] exploitant AC-F3.5 et AC-F3.9.
- **Couverture d'exécution : nulle.** Aucun test rejoué, aucun `pytest`, aucun `node`, aucun hash recalculé. Toutes les conclusions sur du code sont tirées d'extraits fournis par des tiers ou de citations verbatim des rapports.
- **Ce que ce rapport ne peut pas faire** : prononcer un PASS ou un FAIL terrain sur un critère T429 ; valider l'absence de régression LOT2 ; confirmer l'état actuel de `capture_memory_sources`.
- **Ce que ce rapport peut faire** : identifier les contradictions **internes au corpus** (contrat vs preuves exécutées, revues finales entre elles), distinguer les preuves exécutées des déclarations historiques, et proposer une architecture T431 minimale dont les jalons J1–J6 correspondent à des critères observables et à des tests adversaires nommés.
- **Tokens** : la restitution est produite sous contrainte de 1200–2000 mots ; aucun compteur token réel n'est disponible dans cette session.

**Restitution au coordinateur CDX05** : décision prioritaire attendue sur J0 (clore ou rouvrir T429) et sur les 6 levées de dépendance avant démarrage T431. Aucune écriture effectuée, aucun catalogue modifié.