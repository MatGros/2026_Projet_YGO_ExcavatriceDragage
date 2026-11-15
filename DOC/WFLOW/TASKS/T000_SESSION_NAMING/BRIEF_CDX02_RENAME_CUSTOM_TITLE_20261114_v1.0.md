→ RELAIS : T000-CDX02 COMMANDS SESSION SUPERVISOR

> Émetteur : T000-CC10 (orchestrateur) · 2026-11-14 · Criticité : C1 (outillage poste, aucun `CODE/`)
> Coller avant ce brief : `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md`.

# Brief — `/rename-session` doit poser un nom humain (`custom-title`)

## 1. OBJECTIF

Après `/rename-session <Txxx-ACTEUR> <titre>` dans une session **Claude Code**, cette session doit
être **adressable par son nom** dans `ListAgents` / `SendMessage`, comme après un `/rename` natif.
Si la session ouverte ne peut pas être mise à jour par le script, l'utilisateur doit en être
**averti explicitement** (pas de faux succès).

Contexte prouvé :
- `rename_session.py:377-388` (`update_claude_transcript_title`) ajoute `{"type":"ai-title","aiTitle":…}`
  au transcript. `ai-title` = titre **généré par l'IA**.
- Le `/rename` natif écrit `{"type":"custom-title","customTitle":…,"sessionId":…}` (constaté dans
  `~/.claude/projects/…/07fc7657-5975-44dc-9236-832e332adfe7.jsonl`).
- `ListAgents` masque les noms « not chosen by a human » → sessions renommées par script =
  « (unnamed session) ». Contre-preuve : 🐋 T427-CC02 devenue adressable 20 s après un `/rename`
  natif ; aller-retour `SendMessage` CC10 ↔ T427-CC02 réussi.
- Bug lié : `session_statusline.py` → `get_session_info`, repli (Superviseur muet) : lit seulement
  `ai-title`, jamais `custom-title` → affiche le titre IA au lieu du nom humain.

## 2. PÉRIMÈTRE / INTERDITS

Autorisé :
- `TOOLS/AGENT_WORKFLOW/scripts/rename_session.py`
- `TOOLS/AGENT_WORKFLOW/scripts/session_statusline.py` (repli de titre uniquement, cf. §9)
- `TOOLS/AGENT_WORKFLOW/tests/test_rename_session.py`, `TOOLS/AGENT_WORKFLOW/tests/test_session_statusline.py`

Interdit :
- `CODE/`, `TASKS.yaml`, tout autre fichier ; aucun nettoyage ou refactor opportuniste.
- Aucune commande destructive (`git stash`, `checkout .`, `restore`, `reset`, `clean`).
- Aucun commit sans validation humaine explicite.

Hors scope : Codex / agy / DSH (leurs titres ne changent pas) ; serveur Superviseur.

## 3. PHASES ET POINTS D'ARRÊT

1. Lire les deux fonctions et leurs tests existants.
2. **Test préalable (avant tout code)** : dans une session Claude ouverte et non renommée, ajouter
   à la main une ligne `custom-title` au transcript, puis regarder `ListAgents` depuis une autre session.
   Ce test tranche le §5-AC4. ⛔ **ARRÊT** : rendre le résultat à l'exploitant / CC10 avant de coder.
3. Implémenter après GO.
4. Tests ciblés + non-régression (§5).
5. Restituer (§8) ; la clôture revient à l'exploitant.

## 4. SOUS-AGENTS AUTORISÉS

Relecteur en lecture seule uniquement. Un seul écrivain : toi.

## 5. CRITÈRES TESTABLES (= comment on évalue)

- **AC1** — `update_claude_transcript_title` écrit exactement une ligne
  `{"type":"custom-title","customTitle":<titre>,"sessionId":<id>}`.
  *verified_by* : pytest (transcript temporaire, lecture de la dernière ligne).
- **AC2** — le script n'écrit plus aucune ligne `ai-title`.
  *verified_by* : pytest (aucune ligne `"type":"ai-title"` ajoutée).
- **AC3** — repli de `get_session_info` (Superviseur sans entrée pour la session) :
  dernier `customTitle` prioritaire ; `aiTitle` seulement s'il n'y a aucun `customTitle`.
  *verified_by* : 2 tests pytest (avec et sans `custom-title`).
- **AC4** — test réel, résultat binaire :
  - soit une session Claude **ouverte**, renommée par `/rename-session`, apparaît sous son nom
    dans `ListAgents` → *verified_by* : sortie `ListAgents` collée ;
  - soit elle n'apparaît pas → le script affiche « Tape aussi : /rename <titre> » et ne se déclare
    pas « renommé avec succès » côté chat → *verified_by* : pytest + sortie réelle collée.
- **AC5** — non-régression : `python -m pytest -q TOOLS/AGENT_WORKFLOW/tests/test_rename_session.py
  TOOLS/AGENT_WORKFLOW/tests/test_session_statusline.py TOOLS/AGENT_WORKFLOW/tests/test_statusline_workflow_git.py`
  entièrement vert (référence avant ton lot : 48 passed).
- **AC6** — `git diff --stat` limité aux fichiers du §2 ; aucune suppression.

Évaluation : CC10 relit le `git diff` réel et relance AC5 ; l'exploitant valide AC4 et clôt.

## 6. PREUVES ATTENDUES

Diff réel, sortie pytest complète, sortie `ListAgents` (AC4), `git status --short` avant/après.

## 7. RESPONSABILITÉ DU PRINCIPAL

Tu es garant du résultat. Toute affirmation sans preuve brute dans le même message = hypothèse.

## 8. FORMAT DE RESTITUTION

Verdict court · fichiers touchés · AC1→AC6 un par un avec preuve · risques résiduels · hors scope constaté.

## 9. CHANTIERS CONCURRENTS

- `session_statusline.py` est **déjà modifié, non commité** par CC10 (lot « faux Offline » :
  `fetch_supervisor_summary()` unique, timeout 0.6 s, « Offline » seulement si connexion refusée,
  5 tests). **Travaille par-dessus l'état disque actuel**, ne restaure rien. Ne touche que le bloc
  « 2. Si Claude Code : lire le dernier ai-title » de `get_session_info`.
- `supervisor_server.py` (file d'écoute 5 → 128) : en attente de dérogation, **ne pas toucher**.
