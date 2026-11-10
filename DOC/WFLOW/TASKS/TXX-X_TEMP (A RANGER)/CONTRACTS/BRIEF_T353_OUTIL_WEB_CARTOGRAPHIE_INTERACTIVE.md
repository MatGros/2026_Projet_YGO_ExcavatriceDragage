=== PRÉAMBULE OBLIGATOIRE ===
Coller TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md en tête de ce brief avant de le transmettre à l'agent.

=== → NOUVEL AGENT ===
=== ZÉRO CODE/ TOUCHÉ — livraison dans TOOLS/ uniquement ===

## 1. Contexte

Projet excavatrice de dragage (CODESYS 3.5, ST). T351 (livré, vérifié) a produit
2 cartographies exhaustives fichier:ligne du chemin complet geste joystick / cycle
auto → contacteur physique :

- `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md`
  (786 l, treuils M1/M2, chaînes M01-M66 manuel + C01-C35 auto)
- `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md`
  section 3-4 (translation M3)
- Annexe de complément :
  `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T351_ANNEXE_M3_TrousT334_20260921.md`

**Point critique découvert pendant T351** : ces documents s'ancrent par **blob SHA
git**, pas par HEAD ni par numéro de ligne — HEAD a bougé 3 fois pendant le lot
sans invalider les références, alors qu'un fichier peut changer de statut
sale/propre sans qu'une seule ligne change. L'outil doit respecter ce principe :
**vérifier le blob avant d'afficher un chemin, jamais faire confiance à un
numéro de ligne seul.**

Besoin utilisateur (2026-09-20/21, répété) : au lieu de relire ces documents
Markdown à chaque diagnostic, un **outil web interactif** — je choisis un geste
joystick ou une étape de cycle, l'outil affiche le chemin exact (fichier, FB,
variable) dans l'ordre chronologique, avec les fichier:ligne réels.

## 2. Objectif de la tâche (T353, phase 2 de T351)

Construire un outil web statique/local (HTML+JS, pas de backend serveur
obligatoire sauf si strictement nécessaire) qui :

1. Parse les 3 documents source ci-dessus (format tableau + codes M/C déjà
   existant — ne pas inventer un nouveau format, s'appuyer sur celui déjà écrit).
2. Reconstruit un graphe : nœuds = variable/fichier:ligne, arêtes = flux
   chronologique (écriture → lecture → prochaine écriture).
3. Interface : sélection d'un geste/étape (ex. "Joystick M1 monte, MANU") →
   affichage du chemin complet dans l'ordre, avec fichier:ligne cliquable
   (texte, pas besoin de lien vers l'IDE).
4. Vérification de fraîcheur : recalcule le blob SHA de chaque fichier cité et
   signale en rouge toute référence dont le blob a changé depuis l'ancrage du
   document (voir §0.2-3 / §3.10 de l'annexe T351 pour la méthode exacte de
   comparaison par blob).

## 3. Méthode

- Lire en premier les 2 documents T351 + l'annexe pour comprendre le format
  exact des tableaux et des codes M/C avant d'écrire le parseur.
- Format pivot : choisir une structure JSON simple (liste de maillons
  {étape, fichier, ligne, variable, rôle}) générée par le parseur, consommée
  par le front-end.
- Chiffrer le taux de parsing réussi (lignes parsées / lignes totales des
  tableaux) — si un format de tableau n'est pas parsable proprement, le
  signaler plutôt que de deviner.
- Vérification de blob : `git hash-object <fichier>` comparé au hash consigné
  dans le bloc d'ancrage du document source.

## 4. Contraintes de conception

- Outil autonome, pas de dépendance à un serveur applicatif du projet.
- Livraison sous `TOOLS/` (nom de dossier à proposer, respecter
  `STRUCTURE_AND_CLEANUP.md`), jamais à la racine ni dans `CODE/`.
- Aucune modification des 3 documents source — lecture seule.
- Si un chemin (M3, M1, M2) n'est pas findable proprement depuis les documents,
  le signaler comme incomplet plutôt que d'inventer un maillon.

## 5. Devoir de challenge

- Ne pas supposer que le format des 2 documents (T351 vs T334) est identique —
  vérifier, documenter les écarts de structure rencontrés.
- Le principe "seul le blob est un ancrage valide" (REX T351) doit être appliqué
  ici en code, pas juste répété en commentaire — prouver que l'outil détecte
  un cas où le blob a changé (test volontaire : modifier un fichier cité, voir
  l'alerte s'afficher).

## 6. Chantiers concurrents

- Vérifier `TASK_LOCKS.json` avant de commencer (T354/T355 pourraient toucher
  aux mêmes documents source en lecture).
- Aucun fichier `CODE/` concerné par ce lot — risque de collision nul de ce côté.

## 7. Livrables attendus

- Outil web sous `TOOLS/` (structure à documenter dans une note courte).
- Preuve du taux de parsing (chiffré) sur les 3 documents source.
- Démonstration du garde-fou blob SHA (capture ou log de test).
- Contrat `TASK_CONTRACT_T353_*.yaml` (C2).
- `TASKS.yaml` mis à jour (T353), tag agent choisi/incrémenté par l'agent
  lui-même dans `TASK_LOCKS.json`.

## 8. Contraintes non négociables

- AUCUN `CODE/` modifié — hors périmètre strict.
- AUCUN COMMIT sans accord explicite distinct du GO d'implémentation.
- Zéro affirmation non vérifiée — preuve (grep/ligne réelle/hash) dans la même
  restitution.
