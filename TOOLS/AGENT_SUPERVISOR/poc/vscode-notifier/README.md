# 🛡️ Agent Supervisor — extension VS Code 0.2

Extension locale, indépendante des CLI. Elle affiche l'état et les constats du service Agent Supervisor dans la barre d'état, propose une liste de sessions/constats et notifie les nouveaux constats ou leur requalification.

## Ce qu'elle fait

- Lecture périodique (`GET /api/supervision/summary`, 8 s par défaut) sur `127.0.0.1` uniquement.
- Barre d'état : compteurs **à suivre** et **non lues**, avec symbole de criticité (Alarm, Warning, résolution proposée) prioritaire sur celui de collecte. État périmé/indisponible explicite.
- Survol : **🔴 Alarm / ⚠️ Warning en premier**, puis ouverts/reportés/non lus, **🟣 résolutions proposées** et sessions concernées. Le vert de collecte est une information technique séparée, jamais une absence de problème. Référence du constat et version accessibles dans la sélection.
- Nom visible **Agent Supervisor** dans l'IHM et l'extension ; l'interface reste en français.
- Notifications VS Code pour un nouveau problème ouvert, une aggravation de criticité ou une nouvelle preuve source sur un problème actif. Reformulation, commentaire, lecture, baisse de criticité et résolution proposée restent silencieux. Une progression normale n'a pas de notification d'anomalie.
- Le résumé ne contient pas le texte de la citation ; une empreinte permet de détecter sa modification et le détail complet reste dans l'IHM Agent Supervisor.
- Clic sur la barre : choix de session, puis constat. L'action ouvre le bon détail dans Agent Supervisor sans le marquer « Vu », sans le clôturer et sans écrire dans un chat.
- Aucun accès à Claude, Antigravity, Codex ou DSH ; aucun appel de modèle ; aucune écriture dans le service.

Les compteurs proviennent du service (`counts`, globaux et par session), comme dans l'IHM. « À suivre » = ouverts + reportés ; une résolution proposée reste à décider, mais ne compte plus comme problème actif. « Non lues » est un état de lecture indépendant. Sur ancien service sans ces champs, le calcul depuis les constats reçus est explicitement marqué **Compatibilité** : mettre à jour le service pour partager les mêmes comptes. Aucun constat n'est supprimé de la liste par une limite arbitraire de vingt entrées. Un échec de connexion conserve les comptes avec **données périmées** ; il ne devient jamais un faux zéro.

Palette : **Agent Supervisor: Settings — notifications et connexion** ouvre les réglages du port local, de la fréquence et des notifications. La connexion reste limitée à `http://127.0.0.1:<port>`. Les identités connues pour la déduplication sont séparées par port ; la première lecture d'un nouveau service n'envoie pas de notifications rétroactives.

Le service général `/api/supervision` contient des conversations, mémoires, requêtes de juge et un jeton. L'extension ne l'appelle pas : la route dédiée `/api/supervision/summary` renvoie uniquement l'identité de session, ses états et ses constats. Le service Agent Supervisor doit être redémarré une fois pour charger cette route.

## Test local sans installation globale

Depuis la racine du dépôt, ouvrir deux terminaux PowerShell.

**Terminal A — données synthétiques uniquement :**

```powershell
Set-Location (Join-Path (git rev-parse --show-toplevel) 'TOOLS/AGENT_SUPERVISOR/poc/vscode-notifier')
node test/fixture_service.js 18082
```

**Terminal B — fenêtre VS Code séparée avec profil temporaire :**

```powershell
$repo = (git rev-parse --show-toplevel)
$profile = Join-Path $env:TEMP ("AgentSupervisorDev-" + [guid]::NewGuid().ToString('N'))
$extensions = Join-Path $profile 'extensions'
New-Item -ItemType Directory -Path $extensions -Force | Out-Null
$extension = Join-Path $repo 'TOOLS/AGENT_SUPERVISOR/poc/vscode-notifier'
code --new-window --user-data-dir $profile --extensions-dir $extensions --extensionDevelopmentPath $extension
```

Dans cette fenêtre de développement seulement, ouvrir les paramètres JSON (`Ctrl+Shift+P` → **Preferences: Open User Settings (JSON)**) et fusionner ces valeurs avec le contenu existant :

```json
{
  "veilleur.port": 18082,
  "veilleur.pollSeconds": 5,
  "veilleur.notifications": true
}
```

Puis lancer **Developer: Reload Window**. La barre d'etat affiche Agent Supervisor ; la palette contient **Agent Supervisor: Tester le toast et le clic sur un constat reel (TEST)**. Pour verifier aussi l'arrivee automatique d'un nouveau constat apres le snapshot initial, depuis un troisieme terminal :

```powershell
Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:18082/__test/add-finding' -ContentType 'application/json' -Body '{"severity":"warning","reason":"TEST — événement synthétique"}'
```

Apres le delai de lecture, le toast automatique doit ouvrir le constat nouvellement cree dans l'IHM Agent Supervisor du fixture. Pour terminer, fermer la fenetre VS Code de test et faire `Ctrl+C` dans le terminal A. Le fixture ne lit aucune conversation : il fournit quatre identites synthetiques, expose l'IHM Agent Supervisor en lecture, et accepte uniquement les commandes `POST /__test/add-finding`, `/__test/offline` et `/__test/online` pour faire varier le scenario. Le plugin lui-meme n'utilise que le `GET /api/supervision/summary`.

Dans l'Extension Development Host, la barre du bas affiche **Agent Supervisor**. La commande de palette `Agent Supervisor: Tester le toast et le clic sur un constat réel (TEST)` affiche un toast marqué TEST à partir du dernier constat déjà présent dans le service, puis son action ouvre ce constat exact dans l'IHM. Elle ne crée pas de constat et ne change ni son statut ni une conversation. Si aucun constat n'existe, le test l'indique et n'en fabrique pas.

## Vérification sur le service réel

Le test peut utiliser le service Agent Supervisor déjà lancé sur `127.0.0.1:8082`, sans fixture : ouvrir l'Extension Development Host avec l'extension ci-dessus, vérifier que la barre d'état reprend les sessions et compteurs réels, puis lancer cette commande de test. Le toast est explicitement marqué TEST, mais son titre vient d'un constat réel existant. Cliquer sur **Ouvrir le constat réel** ouvre l'IHM avec les paramètres de session et d'alerte. Ce parcours n'ajoute, n'acquitte et ne clôture aucun constat et n'écrit dans aucun chat. Cette procédure charge l'extension en mode développement ; elle ne l'installe pas dans tous les profils VS Code.

Réglages VS Code : `veilleur.port` (8082), `veilleur.pollSeconds` (8, minimum 5) et `veilleur.notifications` (activé par défaut). L'extension ne crée pas de notification de rattrapage au tout premier lancement ; les nouveaux constats observés après la première lecture sont notifiés. VS Code doit rester ouvert pour recevoir les événements.

## Vérification et limites

`node --test TOOLS/AGENT_SUPERVISOR/poc/vscode-notifier/test/*.test.js` couvre le client GET seul, les données modernes et anciennes, les notifications/déduplication, les résolutions proposées, les comptes provenant du serveur, la panne/reprise et le lien exact session/constat. Ces tests utilisent un serveur synthétique et une API VS Code simulée ; ils ne prouvent pas l'affichage réel du toast Windows ni l'état des sessions réelles.

- La notification n'est pas un message reçu par l'agent et ne déclenche pas de tour LLM.
- La barre et la liste ne remplacent pas le détail ni les décisions dans l'IHM Agent Supervisor.
- Les notifications système dépendent de VS Code et des réglages Windows ; aucun son dédié n'est ajouté.
- Le VSIX local est installe dans le profil VS Code normal. Si VS Code etait deja ouvert, recharger la fenetre ou relancer VS Code pour activer l extension. Publication Marketplace et notifications lorsque VS Code est ferme restent hors POC.
