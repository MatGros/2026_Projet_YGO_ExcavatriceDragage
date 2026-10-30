## Cadre (lecture seule)
Faits **rapportés, non vérifiés**. Aucune cause conclue. La matrice discrimine des hypothèses ; elle ne prouve pas AX14. Production et paramètres de distance inchangés, aucun `ErrorId` injecté, aucun défaut forcé.

| # | But / hypothèse discriminée | Essai (physique isolé sauf #5-6) | Attendu qualitatif | Critère de réfutation |
|---|---|---|---|---|
| T1 | Frein tient-il seul sur pente ? | Variateur désactivé, frein fermé puis ouvert, charge réelle, mesure déplacement + retour frein | Fermé : aucun drift. Ouvert : dérive/roulis si pente | Drift frein fermé, ou aucun mouvement frein ouvert → frein/pente n’explique pas seul |
| T2 | Chronologie frein / couple / enable | Log : commande bobine, retour frein, enable, courant/couple, vitesse | Couple établi **avant** ouverture ; maintenu jusqu’à fermeture | Intervalle frein ouvert sans couple suffisant, ou fermeture après suppression couple |
| T3 | Énergie de freinage / rampe à 10 vs 20 Hz | Même charge, même décélération, relever bus DC, duty résistance, courant, température | Signature électrique différente à 10 Hz si rampe/résistance en cause | Signatures équivalentes → hypothèse « résistance/rampe » non soutenue |
| T4 | Comportement très basse fréquence / arrêt | 0,5 Hz puis 0 Hz, frein ouvert, observer creep, oscillation, courant | Perte de contrôle/oscillation près de zéro si pilotage sensorless limite | Tenue stable → piste « fréquence nulle » affaiblie |
| T5 | Intégration **vrai code séquenceur** M3 | Séquence réelle approche trémie → ouverture benne → arrêt ; logs états, frein, enable, consigne, vitesse, position estimée, défaut | Défaut aligné sur une transition précise (arrêt, zéro, ouverture) | Défaut hors transition, ou absent sur cycles répétés → séquenceur non suffisant |
| T6 | Position estimée vs vraie en sim | Repère vrai indépendant (marqueur/encodeur), transitions frein et roulage libre | Divergence quand frein ouvert / glissement / fréquence ≤0,5 Hz | Erreur bornée → estimation utilisable dans ce régime |

## Limites position estimée vs vraie simulation
La position simulée est une **estimation modèle**, pas une mesure. Elle ne prouve ni le glissement réel, ni le couple, ni l’état physique du frein. Elle ne doit pas servir à régler une distance pour provoquer AX14. T6 compare seulement estimation et vérité indépendante ; sans vérité, aucune conclusion de cause.

## Ce que la matrice ne prouvera pas
- T1-T4 : mécanique/électrique isolée, hors séquenceur réel.
- T5 : seul essai capable de relier AX14 au vrai enchaînement, mais **qualitatif** et non reproductible sans preuve terrain.
- Le harnais actuel, sans séquenceur ni safety/interlock, **ne prouve pas AX14**.
- Aucune mesure terrain inventée ; toute valeur chiffrée devra venir d’un essai réel tracé.