# Brief de délégation — gabarit commun

À joindre à une mission déléguée lorsqu'un agent secondaire est réellement utilisé. Compléter les
champs entre crochets ; ne pas envoyer ce modèle seul. Pour une demande simple ou séquentielle,
ne pas créer de délégation uniquement pour remplir le registre.

## Mission

- **Utilisateur / besoin d'origine :** [reprendre fidèlement la demande]
- **Objectif de cette sous-tâche :** [résultat vérifiable]
- **Historique utile et preuves disponibles :** [faits, essais déjà faits, limites]
- **Décision que le résultat doit permettre :** [décision explicite]
- **Critères d'acceptation :** [liste courte, observable et vérifiable]

## Rôle et autorisations

- **Rôle :** [exécutant / reviewer indépendant / chercheur]
- **Périmètre autorisé :** [fichiers, systèmes ou analyse]
- **Actions interdites :** [écriture, exécution, accès machine, etc.]
- **Outils autorisés :** [outils réellement disponibles et nécessaires]
- **Responsable/coordonateur :** [identifiant et canal de retour]

Les exécutants et reviewers ne modifient pas le catalogue partagé `TASKS.yaml`, les verrous ou le
registre d'orchestration, sauf autorisation explicite leur attribuant aussi le rôle de coordinateur.
Un reviewer reste en lecture seule. Une autorisation de lot déjà donnée couvre les modifications
dans le périmètre et le plan approuvés ; elle n'autorise ni extension de périmètre ni commit/push.

## Méthode et restitution

1. Lire les références nécessaires au périmètre ; ne pas charger tout le dépôt par réflexe.
2. Séparer faits observés, inférences et inconnues. Si une donnée métier manque ou que le contrat
   ne permet pas de conclure, l'indiquer clairement et préciser l'information minimale manquante.
3. Produire les preuves nécessaires aux critères ; ne pas annoncer PASS sur une vérification
   indirecte ou non exécutée.
4. Faire une auto-revue ciblée : résultat contre critères, hypothèses, effets de bord et limites.
5. Renvoyer au responsable : verdict par critère, preuves avec chemins/lignes ou commandes,
   écarts, risques résiduels, décision recommandée. Ne pas modifier le périmètre de sa propre
   initiative.

## Règles de projet

- `AGENTS.md` est la source commune ; charger les standards/specs applicables à la mission.
- Lire et appliquer `AGENTS.md` § Discipline de session. Sans accès au fichier : signaler une fois en
  note courte, ne bloquer que sur sécurité, perte de données, régression critique ou point d'arrêt
  du contrat ; une preuve manquante limite le verdict, pas l'analyse.
- Sécurité machine : aucun essai ou forçage sur machine réelle sans autorisation et procédure
  explicites. Ne jamais traiter un stub, un mock ou une simulation comme preuve terrain.
- Aucune suppression, aucun déplacement et aucun nettoyage automatique d'artefacts ; suivre
  `TOOLS/AGENT_WORKFLOW/docs/STRUCTURE_AND_CLEANUP.md`.
- Ne pas committer ni pousser. Le responsable orchestre l'intégration et relit le diff réel.
