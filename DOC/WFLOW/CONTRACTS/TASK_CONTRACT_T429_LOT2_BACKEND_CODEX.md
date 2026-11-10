# CONTRAT D'EXÉCUTION T429 — LOT 2 : BACKEND PERSISTANT & NOTIFICATIONS VS CODE

Destinataire : Agent Codex (Persona : Senior Backend & Systems Engineer)
Responsable / Orchestrateur : Antigravity (T429)
Branche Git : main (travail collaboratif sur le clone local)

---

## 1. Périmètre strict des fichiers

### Fichiers sous ta responsabilité exclusive (Écriture autorisée) :
- `TOOLS/AGENT_SUPERVISOR/scripts/supervisor_service.py`
- `TOOLS/AGENT_SUPERVISOR/scripts/supervisor_server.py`
- `TOOLS/AGENT_SUPERVISOR/poc/vscode-notifier/**`

### Fichiers strictement INTERDITS en écriture :
- AUCUN fichier Frontend (`TOOLS/AGENT_SUPERVISOR/ui/index.html` : formellement interdit)
- AUCUN fichier client ou prompt (`review_session.py`, `judge_prompt.py` : réservés à l'Orchestrateur)
- AUCUN fichier de code automate PLC (`CODE/**`)

---

## 2. Objectifs techniques détaillés

### Objectif 1 : Action API `test_notification` dans `supervisor_service.py` (D07)
Dans `Supervisor.command(command)` et `Supervisor._command(command)` :
- Prendre en charge `command["action"] == "test_notification"`.
- Permettre un payload optionnel `severity` ("warning" par défaut) et `id` (session cible, ou première active).
- Générer un constat système temporaire d'alerte avec :
  - `id`: `"test-notif-" + uuid`
  - `category`: `"system_test"`
  - `disposition`: `"new"`
  - `business_state`: `"new"`
  - `reason`: `"[TEST] Notification Agent Supervisor (test sonore et VS Code). Ce constat est un test temporaire."`
- **Garde-fou critique anti-pollution du juge LLM** :
  - Ce constat de test DOIT porter le marquage `category: "system_test"`.
  - Dans `_select_for_analysis()` ou lors de la composition des requêtes du juge, les constats de catégorie `system_test` doivent être **strictement ignorés par le juge LLM** pour ne pas fausser l'historique de mission.
  - Prévoir un auto-nettoyage ou un TTL (ou fermeture automatique après 60s) pour que le constat test ne reste pas indéfiniment ouvert.

### Objectif 2 : Extension VS Code (`poc/vscode-notifier/`)
Dans l'extension VS Code qui scrute l'API du Veilleur :
- Vérifier que lors de la détection d'un constat `category === "system_test"` avec `kind === "new"`, le toast natif Windows de VS Code est immédiatement déclenché (`vscode.window.showWarningMessage` ou `showInformationMessage`).
- Le bouton d'action du toast doit ouvrir directement la session dans le navigateur vers `http://127.0.0.1:8082/?session=<id>&alert=<id>`.
- S'assurer que le test de notification fonctionne parfaitement même si la fenêtre du navigateur Web est réduite ou en arrière-plan.

### Objectif 3 : Route HTTP allégée `GET /api/supervision/review` (D19)
Dans `supervisor_server.py` (handler HTTP) :
- Actuellement, l'appel à `/api/supervision` renvoie le snapshot complet de 899 Ko contenant l'historique complet de toutes les sessions, ce qui cause la latence de `review_session.py`.
- Créer une nouvelle route ciblée et légère :
  `GET /api/supervision/review?session=<sessionId>`
- Cette route extrait uniquement :
  - Les métadonnées d'identification de la session demandée (id, alias, platform, state).
  - La liste de ses constats ouverts (`business_state != 'closed'`) avec leur citation (`evidence`), titre, motif, sévérité, date.
  - Le résumé des compteurs de la session.
- **Exigence de performance** :
  - La taille de réponse HTTP doit être inférieure à 30 Ko (au lieu de 899 Ko).
  - Le temps d'exécution serveur doit être inférieur à 50 ms.

---

## 3. Critères de tests orientés utilisation réelle (Obligatoires)

Tout test basé sur des mocks statiques ou des assertions triviales sera refusé. Tu dois fournir la preuve brute des tests suivants :

1. **Test d'intégration API réelle (pytest)** :
   - Tester l'action `test_notification` : envoi de la commande via `service.command()`, vérification de la présence du constat `disposition == 'new'`, et vérification qu'il n'est PAS sélectionné dans les lots soumis au juge.
   - Commande d'exécution : `py -3.13 -m pytest TOOLS/AGENT_SUPERVISOR/tests/test_t429_regressions.py -q`.
   - **Garde-fou SRE** : Les tests unitaires doivent impérativement utiliser un port dynamique `port=0` et un dossier temporaire `tempfile` (interdiction stricte de bloquer le port 8082 en test).

2. **Mesure de performance de la route `/review`** :
   - Mesurer le temps d'exécution et le volume en Ko sur une session chargée (ex: avec plusieurs constats).
   - Prouver par mesure réseau que le payload renvoyé est bien inférieur à 30 Ko.

---

## 4. Règles d'or de discipline

- Conserve tes modifications dans le checkout local.
- **NE FAIS AUCUN COMMIT NI PUSH DIRECT SUR MAIN.**
- Restitue ton rapport avec le `git diff` exact et les sorties brutes de test.
