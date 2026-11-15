# 🧪 Plan de tests — messagerie inter-agents (modèles tiers inclus)

> v1.0 · 2026-11-14 · T000-CC10 · Complète `MESSAGERIE_INTER_AGENTS_v1.0.md` (même dossier).
> Contrainte exploitant : **pas de Remote Control** pour les sessions à configuration spéciale
> (Claude Code lancé via Ollama) → le **contrôle** se fait par lecture des historiques locaux,
> jamais par l'interface ouverte.

---

## 0. 👥 Participants

- **CC10** : cette session, Claude Code sur modèle Anthropic (`claude-opus-5-5`). Adresse : `T000-CC10 MULTITASK ORCHESTRATOR AGENT [db4cd4]`.
- **CCOL** : Claude Code sur modèle tiers. Lancement : `ollama launch claude --model deepseek-v4.1-flash:cloud` (terminal « 🐋 CC Ollama (deepseek-v4.1) »).
  ➜ Dans **son** terminal : `/rename T000-CCOL01 TEST OLLAMA DEEPSEEK` (le `/rename` **natif**, obligatoire).
- **AGY** : Antigravity relancé. Identifiant de conversation : `agy` ou Superviseur (`platform: agy`).
- **CDX** : Codex `T000-CDX02`, conversation `01a1d1a6-a3d2-7463-8e7d-615667d7d6dc`.

## 0bis. 🔎 Moyens de contrôle (sans Remote Control)

- **Claude (CC10 ou CCOL)** : `~/.claude/projects/C---MGS-DEV-2026-Projet-YGO-ExcavatriceDragage/<session>.jsonl` → champ `"model"` du tour de réponse (prouve le **vrai** modèle).
- **Codex** : `~/.codex/sessions/AAAA/MM/JJ/rollout-*-<uuid>.jsonl` → messages `role: assistant`.
- **Antigravity** : la réponse revient dans la sortie JSON de `agy --print` (`status`, `response`).
- Chaque test utilise un **marqueur unique**, cherché dans les **réponses** uniquement.

---

## 1. 🟣 CC10 ↔ CCOL (Claude Code sur DeepSeek)

- **T1 — CCOL visible ?** CC10 : `ListAgents`.
  ✅ `T000-CCOL01 TEST OLLAMA DEEPSEEK` apparaît · ❌ absent → noter « messagerie inter-sessions indisponible avec ollama launch », passer à T4.
- **T2 — CC10 → CCOL.** CC10 : `SendMessage` vers `T000-CCOL01 TEST OLLAMA DEEPSEEK`, demande « réponds RETOUR-CCOL-OK-1 par SendMessage ».
  ✅ message arrivé (vérifiable dans le transcript CCOL, ligne `cross-session-message`).
- **T3 — CCOL → CC10 (natif).** CCOL répond par `SendMessage`.
  ✅ CC10 reçoit `RETOUR-CCOL-OK-1` **et** le transcript CCOL montre `"model"` = `deepseek…` sur ce tour.
  ❌ le modèle tiers n'appelle pas l'outil → résultat à noter (limite du modèle, pas du canal).
- **T4 — CCOL → CC10 (relais, secours).** Dans le terminal CCOL, faire exécuter :
  `claude -p --model haiku --allowedTools "ListAgents,SendMessage,ToolSearch" --strict-mcp-config --disable-slash-commands "Appelle SendMessage vers « T000-CC10 MULTITASK ORCHESTRATOR AGENT [db4cd4] » avec exactement : CCOL-VERS-CC10-OK. Réponds ENVOYE ou ECHEC."`
  ✅ CC10 reçoit `CCOL-VERS-CC10-OK`.
  ⚠️ Le relais tourne sur le compte Anthropic (haiku), pas sur Ollama.

## 2. 🔵 CC10 ↔ AGY (Antigravity relancé)

- **T5 — CC10 → AGY.** `agy --conversation <id> --print-timeout 170s --output-format json --print "… réponds RETOUR-AGY-OK-1 …"`.
  ✅ `status: SUCCESS` + marqueur dans `response`.
- **T6 — AGY → CC10.** Même message : demander à AGY d'exécuter la commande relais (§T4) avec `AGY-VERS-CC10-OK`.
  ✅ CC10 reçoit le marqueur.
- **T7 — Affichage en direct (exploratoire).** AGY lancé avec `--remote-control` (ou `agy remote-control start`) : le tour de T5 apparaît-il dans la fenêtre ouverte sans rechargement ?
  ⚠️ Si Remote Control impossible avec ta configuration : le noter, le canal T5/T6 reste valable (rechargement manuel).
  ⚠️ `--sandbox` indisponible sur ce poste : la protection repose sur la consigne.

## 3. 🟢 CC10 ↔ CDX (Codex)

- **T8 — CC10 → CDX avec /rc** : `codex queue --thread 01a1d1a6-… --message "… RETOUR-CDX02-OK-3 …"`. ✅ déjà prouvé (2×).
- **T9 — CC10 → CDX sans /rc (ta contrainte)** : même commande, `/rc` désactivé.
  ✅ `Queued…` puis le message apparaît à la **reprise** de la conversation Codex (contrôle : rollout).
  Variante : ajouter `--resume` à `codex queue` et observer.
- **T10 — CDX → CC10 (relais)** : demander à CDX d'exécuter la commande relais (§T4) avec `CDX02-VERS-CC10-OK`.
  ✅ CC10 reçoit le marqueur → plus besoin de lire le rollout.

## 4. 🔀 Paires sans CC10 (même mécanique)

- **T11 — CCOL → CDX** : CCOL exécute `codex queue …` (contrôle : rollout CDX).
- **T12 — CCOL → AGY** : CCOL exécute `agy --conversation … --print …` (contrôle : sortie JSON rapportée par CCOL).
- **T13 — AGY → CDX** et **CDX → AGY** : mêmes commandes, croisées.

---

## 5. ✅ Critère de réussite global

Chaque paire testée est classée : **OK natif** · **OK par relais** · **OK sans affichage direct** · **KO** (cause notée).
Le résultat met à jour la fiche `MESSAGERIE_INTER_AGENTS` (une seule source), pas ce plan.

## 6. 🛡️ Règles pendant les tests

- Messages **sans action ni fichier** ; un tour de test ajoute un vrai tour à la conversation cible (éviter sur une session en plein travail).
- Aucun commit ; aucune demande d'action refusée ailleurs (pas de blanchiment de permission).
