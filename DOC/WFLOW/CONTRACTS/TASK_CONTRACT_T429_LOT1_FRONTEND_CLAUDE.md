# CONTRAT D'EXÉCUTION T429 — LOT 1 : IHM FRONTEND WEB

Destinataire : Agent Claude Code (Persona : Expert Frontend UI/UX & Web Audio)
Responsable / Orchestrateur : Antigravity (T429)
Branche Git : main (travail collaboratif sur le clone local)

---

## 1. Périmètre strict des fichiers

### Fichiers sous ta responsabilité exclusive (Écriture autorisée) :
- `TOOLS/AGENT_SUPERVISOR/ui/index.html`
- `TOOLS/AGENT_SUPERVISOR/tests/test_ui.mjs`
- `TOOLS/AGENT_SUPERVISOR/tests/ui_layout_check.mjs`

### Fichiers strictement INTERDITS en écriture :
- AUCUN fichier Python (`TOOLS/AGENT_SUPERVISOR/scripts/*.py` : formellement interdit)
- AUCUN fichier dans `poc/vscode-notifier/`
- AUCUN fichier de code automate PLC (`CODE/**`)

---

## 2. Objectifs techniques détaillés

### Objectif 1 : Accès rapide dans la barre latérale gauche (D06 & D07)
Dans la barre latérale gauche fixe (sous `#notification-status` et avant `#side-sessions`) :
- Créer un conteneur d'accès rapide `.sidebar-quick-tests`.
- Insérer 3 boutons d'action rapide visibles en permanence quelle que soit la vue active (Suivi, Connecter, Paramètres) :
  1. `🔊 1 bip` (id: `side-test-1bip`) : joue immédiatement le son 1 bip (Warning 880 Hz).
  2. `🚨 2 bips` (id: `side-test-2bips`) : joue immédiatement le son 2 bips (Alarm / 3+ Warnings avec pause).
  3. `🔔 Test VS Code` (id: `side-test-vscode`) : déclenche l'appel API `mutate({action: 'test_notification'})`.
- Le style doit être compact, responsive, sans déborder sur mobile (largeur 250px de la sidebar).

### Objectif 2 : Ergonomie visuelle & repères couleur immédiats (D12, D13, D14)
- **Étiquette d'état de collecte** : Remplacer l'icône/texte brut par des pastilles colorées explicites :
  - 🟢 Vert pour `Lecture active`
  - 🟠 Orange pour `En pause`
  - 🔴 Rouge pour `Rupture de source` ou `Erreur de lecture`
- **Espacement du compteur de constats** :
  - Insérer un espacement insécable net entre le nombre et le statut (ex: `Constats · 0   ✓ rien à suivre`) pour éviter toute confusion visuelle.
- **Jauge de complétude de mission (xx/xx)** :
  - Ajouter un badge coloré dynamique selon le ratio :
    - Moins de 8/12 : 🔴 Rouge
    - Exactement 8/12 : 🟠 Orange
    - 9/12 ou plus : 🟢 Vert

### Objectif 3 : Réduction de l'encombrement & masquage accordéon (D11 & D15)
- **Masquage des constats traités** :
  - Au-delà d'un seuil de 5 constats clos/résolus, masquer automatiquement les plus anciens dans un accordéon replié `<details>` (« X anciens constats traités archivés ») pour que la page reste dégagée et lisible.
- **Chat Superviseur** :
  - Reléguer le panneau de chat en toute fin de page sous la zone des sessions ou le garder replié par défaut.

### Objectif 4 : Sécurité opérationnelle — Alerte Déconnexion Sticky (D16)
- **Problème à résoudre** : Quand le service 8082 est coupé, l'avertissement en haut disparaît dès qu'on scrolle vers le bas. L'utilisateur peut croire à tort qu'il est surveillé.
- **Solution** :
  - Dès que l'appel `fetch('/api/supervision')` échoue (déconnexion ou redémarrage du service) :
    - Appliquer immédiatement la classe `.is-disconnected` sur `.app-sidebar` (menu latéral fixe).
    - Teinte de fond rouge pastel contrastée sur toute la hauteur du menu gauche.
    - Afficher un bandeau fixe bien visible : `⚠️ SUPERVISION INTERROMPUE — DÉCONNECTÉ`.
  - Dès que le service 8082 redevient joignable, le menu reprend automatiquement son aspect normal sans rechargement forcé de la page.

---

## 3. Critères de tests orientés utilisation réelle (Obligatoires)

Tout test cosmétique ou superficiel sera refusé. Tu dois fournir la preuve brute des tests suivants :

1. **Test unitaire Puppeteer/Node (`test_ui.mjs`)** :
   - Tester le clic réel sur les 3 boutons rapides de la sidebar.
   - Tester que le payload envoyé sur le clic `🔔 Test VS Code` est bien `{"action": "test_notification"}`.
   - Tester que la bascule de statut de connexion applique bien `.is-disconnected`.
   - Commande d'exécution : `node TOOLS/AGENT_SUPERVISOR/tests/test_ui.mjs` (doit être 100% PASS).

2. **Test d'affichage et non-débordement (`ui_layout_check.mjs`)** :
   - Vérifier le rendu sur Desktop (1440px), Mobile large (390px) et Mobile compact (360px).
   - Zéro overflow horizontal (`no_horizontal_scroll: true`).
   - Commande d'exécution : `node TOOLS/AGENT_SUPERVISOR/tests/ui_layout_check.mjs` (doit retourner `failed: []`).

---

## 4. Règles d'or de discipline

- Conserve tes modifications dans le checkout local.
- **NE FAIS AUCUN COMMIT NI PUSH DIRECT SUR MAIN.**
- Restitue ton rapport avec le `git diff` exact et les sorties brutes des tests mécaniques.
