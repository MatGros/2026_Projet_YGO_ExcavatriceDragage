# Prompt Challenge Ergonomie & Web Design IHM Superviseur

Tu es un Expert Senior en Ergonomie Web, UI/UX Design et Cockpits Industriels Temps Réel.
L'exploitant demande une refonte ergonomique de l'IHM `TOOLS/AGENT_SUPERVISOR/ui/index.html`.

### Problème exprimé par l'exploitant :
1. L'IHM actuelle est une « boîte noire » avec 70 accordéons imbriqués : l'exploitant ne voit pas le flux de données réel et a l'impression d'être « mené en bateau ».
2. Les résultats d'outils et commandes sont parfois jetés en silence par les adaptateurs, et rien dans l'IHM ne permet de le voir en direct.
3. Les boutons d'action sont cachés sous des accordéons.
4. Les chemins de fichiers sont du texte brut non cliquable.

### Attentes :
1. Définir l'enchaînement optimal de l'IHM pour suivre le flux réel de données (de haut en bas : Source/Événements capturés -> Filtrage -> Jugement -> Constats & Actions -> Système/Admin).
2. Intégrer les exigences passées :
   - D06/D07 : Boutons de test direct dans la barre latérale gauche (1 bip, 2 bips, test notification VS Code).
   - D11 : Masquage automatique / archivage des constats clos au-delà de 5 pour éviter l'encombrement.
   - D12 : Étiquette de collecte avec pastille colorée explicite (Vert = lecture active, Orange = pause, Rouge = rupture).
   - D13 : Typographie et espacement sur le compteur de constats (`Constats · 0   ✓ rien à suivre`).
   - D14 : Jauge de complétude de mission colorée (<8 rouge, 8 orange, >=9 vert).
   - D15 : Relégation du Chat Superviseur en bas de page / replié par défaut.
   - D16 : Alerte visuelle de déconnexion persistante sur le menu latéral gauche si le service 8082 tombe.
   - Suppression des `<details>` imbriqués : boutons d'action directs sur la carte.
   - Liens cliquables `<a>` sur les fichiers et lignes de code.
   - Timer temps réel du prochain cycle de scan.

Rends une recommandation ergonomique tranchée :
- Critique de l'existant (points de friction et charge cognitive).
- Wireframe textuel / structure du nouveau cockpit.
- Règles de design pour rendre le flux de données 100 % transparent.
