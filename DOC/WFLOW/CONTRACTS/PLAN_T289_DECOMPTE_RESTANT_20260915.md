# Delta T289 — affichage du temps restant AX13

Date : 2026-09-15
Statut : delta en simulation pré-validé — validation machine restant à faire
Périmètre : affichage seulement ; la consigne et la temporisation métier restent inchangées.

## Besoin confirmé

Pendant AX13, afficher le décompte de la durée d’égouttage effective vers zéro :

```text
Début AX13 : consigne effective (ex. 5 s)
Puis        : 4, 3, 2, 1, 0 s
Fin / Skip / hors AX13 : 0 s
```

Ne plus afficher une valeur qui monte de 0 vers X.

## État actuel constaté

- `FB_CycleSemiAuto.DrainingTimer` est la TON métier ; son `ET` est propagé comme `DrainTimeElapsed`.
- `PRG_07_Supervision` convertit cette durée écoulée en `GVL_IHM.CycleSemiAuto.State.DrainTimeElapsed_S`.
- La consigne persistante `DrainTime_S` et la PT réelle de la TON ne changent pas dans ce delta.

## Patch proposé

1. Calculer le temps restant à partir de la PT effective AX13 et de `DrainingTimer.ET`, en secondes restantes entières, arrondi supérieur pendant le décompte.
2. Saturer le résultat à `[0..DrainTime_S]` ; publier zéro dès fin TON/Skip et hors AX13.
3. Conserver le tag IHM `DrainTimeElapsed_S` pour préserver la visualisation existante ; documenter que sa valeur publiée devient le temps restant. Renommer uniquement les champs internes/bus nécessaires.
4. Préserver `DrainingTimer.IN`, son PT, `SkipDrainRequest` et la transition AX13→AX14.
5. Vérifier aussi le changement de consigne à la volée : le décompte doit rester cohérent avec la PT effectivement fournie à la TON.

## Tests d’acceptation du delta

- Consigne 5 s : valeur initiale 5, décroissance vers 0, jamais croissante ni négative.
- Fin de la TON : valeur 0 ; Skip avant Q : valeur 0 après transition ; hors AX13 : valeur 0.
- Consigne modifiée à la volée : affichage cohérent avec la PT effective et le comportement actuel de la TON.
- Reprise AX13 : nouveau décompte à partir de la durée effective.
- Aucune modification de l’ordre de commande ou de la transition vers AX14.
- Tests ciblés, bundle complet + diff bundle, G200 et gates applicables.

## Diff attendu / point d’arrêt

Le tag IHM `DrainTimeElapsed_S` reste inchangé ; sa sémantique affichée devient « temps restant ». Aucun remappage graphique n’est nécessaire. Aucun champ TIME parallèle et aucun timer supplémentaire.

⛔ Aucun fichier `CODE/` ne sera modifié avant validation explicite de ce plan delta.
