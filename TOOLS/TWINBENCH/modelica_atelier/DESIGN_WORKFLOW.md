# Proposition de workflow — Atelier

État : proposition de conception pour la prochaine itération, non implémentée.
Lire `API_ACTUELLE.md` pour les données réellement raccordables aujourd'hui.

## Expérience principale

L'utilisateur ouvre son expérience, conduit, sélectionne un objet pour comprendre sa réaction,
modifie une hypothèse, compare puis conserve une variante. Le même espace conserve la scène,
la sélection et l'instant observé ; aucune navigation vers une autre application n'est imposée
pour tracer un signal disponible.

```text
ATELIER   Translation / Variante A        Simulation locale   En pause
─────────────────────────────────────────────────────────────────────
 Piloter     Scénarios     Modifier     Observer        ▶ Démarrer

                 SCÈNE DE LA MACHINE
               capteur ← sélection directe
          [chariot]─────────────────── rail

  [joystick]  ← 0 % →  [homme-mort maintenu]
─────────────────────────────────────────────────────────────────────
  Observer ▸ (fermé initialement ; s'ouvre à la demande)
```

Les quatre actions organisent le travail ; elles ne doivent pas devenir quatre pages
indépendantes. La scène conserve sa taille autant que possible. Sur petit écran, un panneau
recouvre une partie de la scène avec un bouton de retour visible.

## Parcours de référence

| Intention | Interaction | Résultat visible |
|---|---|---|
| Conduire | choisir Virtuel, démarrer, maintenir homme-mort et dévier le levier | source active et réaction physique |
| Utiliser USB | choisir le périphérique, vérifier axes/boutons, calibrer, activer | état détecté/calibré/actif explicite |
| Comprendre un arrêt | sélectionner l'axe, choisir Freinage | pistes vitesse, frein, homme-mort synchronisées |
| Tracer une grandeur | clic objet → liste des grandeurs → Tracer | courbe ajoutée sans saisie de code |
| Comparer une charge | conserver A, changer masse, repartir, refaire l'essai | comparaison B/A avec paramètres identifiés |
| Déplacer un capteur | mode Modifier, glisser ou saisir une cote, appliquer | aperçu puis acquittement et événement |
| Jouer un scénario | sélectionner, lire son résumé, lancer | étape et durée visibles, Reprendre la main accessible |
| Conserver | enregistrer variante / exporter | format, contenu et limites indiqués au choix |

La comparaison A/B et l'enregistrement/rejeu sont à développer. Les valeurs déjà reçues
peuvent être visualisées sans recalculer la physique.

## États indépendants

Ne pas enfermer tout le produit dans une unique liste d'états : une session peut être en
simulation, en mode édition paramétrique, et observer des courbes figées simultanément.

| Dimension | États |
|---|---|
| Moteur | indisponible, préparation, prêt, erreur |
| Horloge | pause, avance |
| Source | virtuel, USB, scénario ; activation distincte |
| Édition | fermée, aperçu, application, appliquée, refusée |
| Observation | direct, figée, historique |
| Communication | connectée, périmée, perdue |

Pause suspend le temps simulé. Relâcher l'homme-mort laisse la physique calculer le freinage.
Ces deux commandes doivent porter des libellés et effets distincts.

## Édition

Une fiche d'objet expose seulement ses réglages utiles, avec unités, domaine et provenance.
Afficher l'aperçu comme tel ; ne confirmer la modification qu'après acquittement du moteur.
Un changement refusé conserve la dernière valeur appliquée et explique le refus près du champ.
Annuler/rétablir porte sur les modifications acquittées. Une modification structurelle demande
une pause et une reconstruction, présentées comme une étape normale de l'expérience.

## Courbes

Volet inférieur repliable, jeux Mouvement / Freinage / Efforts, ajout libre depuis l'objet ou
un catalogue filtrable. Numériques : unité explicite par axe. Logiques : pistes en escaliers.
Curseur commun avec temps exact, valeurs, événement associé ; zoom temporel sans perdre le
direct. Figer l'observation n'arrête pas le moteur. Les limites de conservation sont visibles.
Les extrema et fronts ne doivent pas disparaître lors de la réduction graphique des points.

## Lots proposés

1. **Conduite utilisable** : gestes souris/clavier cohérents, activation USB, reprise de main,
   données périmées explicites. Recette : démarrer et conduire sans recherche dans un guide.
2. **Observation** : catalogue issu du moteur, préréglages, époques et trous de traces gérés.
   Recette : tracer un capteur, remettre à zéro et obtenir une nouvelle trace complète.
3. **Édition fiable** : aperçu/acquittement, annuler/rétablir et provenance de variante.
   Recette : modifier une valeur, annuler, exporter et retrouver la valeur dans OMEdit.
4. **Expériences reproductibles** : conditions initiales, journal exhaustif, enregistrement,
   rejeu et comparaison A/B. Recette : rejouer avec une tolérance définie et affichée.

## Livraison attendue du designer

Proposer deux directions visuelles argumentées, choisir une direction, livrer cinq états
cohérents : accueil, conduite, fiche d'objet, observation détaillée, moteur indisponible.
Fournir une maquette navigable avec données explicitement fictives si le moteur n'est pas
raccordé, puis une table de correspondance composants → routes actuelles / extensions.
L'utilisateur doit reconnaître ce qui est utilisable et ce qui reste une proposition.
