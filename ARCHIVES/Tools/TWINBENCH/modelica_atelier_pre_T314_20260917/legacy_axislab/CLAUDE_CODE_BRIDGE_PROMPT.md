# Prompt Claude Code — Design interface Atelier

Tu es designer produit et architecte frontend pour un simulateur électromécanique industriel.
Utilise `CLAUDE_CODE_BRIDGE.md` comme contrat. Le résultat attendu est une proposition concrète,
testable et directement implémentable, pas une liste d’idées génériques.

Lis `API_ACTUELLE.md` pour connaître les données déjà accessibles, et `DESIGN_WORKFLOW.md`
comme proposition de départ à challenger. Distingue toujours fonctionnalités existantes,
extensions proposées et données fictives de maquette.

Commence par répondre dans cet ordre :

1. audit des écrans et des flux actuels ;
2. carte des états de session (`idle`, `running`, `paused`, `scenario`, `usb-lost`, `engine-error`, `editing`);
3. wireframes ASCII ou Mermaid des écrans clés ;
4. contrat d’événements et modèle de données UI ;
5. parcours de conduite USB/virtuel et règles de reprise de main ;
6. parcours d’édition et gestion undo/redo ;
7. design des chronogrammes et sélection libre de signaux ;
8. plan de lots, chaque lot ayant un critère d’acceptation observable ;
9. risques, hypothèses et questions bloquantes.

Ne simule pas la physique en JavaScript. Ne réimplémente pas la logique PLC dans le panneau de
commande. Ne masque aucune perte de communication ni sortie inconnue. Utilise un vocabulaire
opérateur, en conservant les identifiants techniques dans les détails inspectables.
