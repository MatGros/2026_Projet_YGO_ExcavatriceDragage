# 🕵️ Troubleshooting — T262 transition électromécanique AX10 → AX11

> 📅 2026-09-15 · 🧪 Situation : analyse statique + simulation · 📄 Statut : EN COURS
> 
> Objectif : exclure une transition qui créerait une retombée de frein/contacteurs,
> un appel de couple non maîtrisé, ou une surcharge des moteurs M1/M2 à rotor bobiné.

## 1. Contexte figé

- T262 vise un transfert anticipé de fermeture benne vers extraction automatique.
- La simulation est cinématique : codeurs issus du sens/palier commandé, frein et
  retour contacteurs miroirs des sorties ; pas de courant, couple ou élasticité câble.
- Aucun schéma de puissance rotor/résistances ni courbe constructeur n'est versionné
  dans le dépôt.

## 2. Risque étudié

Supprimer la pause AX10b sans provoquer une micro-coupure direction/frein, ni faire
passer M1 et M2 dans des vecteurs de contacteurs différents pendant la commande Both.

## 3. Faits établis par lecture de code

| Fait | Preuve | Verdict |
|---|---|---|
| Both neutralise les deux sorties si vecteurs finaux différents. | `PRG_04_Treuils_Benne.st:1593-1613` | ✅ P2 M2 / P1 M1 interdit. |
| Le frein suit le relais de sens. | `FB_WinchOutputInterlock.st:346-450` | ✅ une retombée du sens implique frein serré. |
| P1 est le premier état ; P2 ferme R1 dans la table active. | `GVL_PERSISTENT.st:16-22` | ✅ P2→P1 commute une étape puissance. |
| L'ouverture benne dépend de `M2-M1`. | `FB_Bucket.st:350-358, 550-558` | ✅ Both à vitesses égales fige l'ouverture. |
| SimBench ne modélise ni courant ni couple ni retard physique. | `FB_SimBench.st:224-302` | ✅ simulation insuffisante pour qualifier l'effort. |

## 4. Arbre de décision — essai machine

```text
Seuil d'ouverture positif atteint
├─ M1 finalement disponible (direction + interlock final purgés) ?
│  ├─ non → repli AX10b historique ; aucun maintien M2 en butée
│  └─ oui
│     ├─ M2 rejoint P1 sans chute relais/frein ?
│     │  ├─ non → STOP : transition non qualifiée
│     │  └─ oui
│     │     ├─ Both P1 : BucketOpening_Pct diminue réellement ?
│     │     │  ├─ oui → garder P1 jusqu'à IsClosed réel, puis autoriser P2
│     │     │  └─ non → P1 seul reste acceptable ; P2 exige nouvelle stratégie mécanique
│     │     └─ courant/bruit/vitesse/écart normaux ?
│     │        ├─ non → STOP, relever les mesures
│     │        └─ oui → essai charge représentative
```

## 5. Conclusion provisoire

Le passage fluide envisageable est **M2 P2→P1 sans perte du sens**, puis Both P1
atomique, puis P2 seulement après fermeture réellement confirmée. Le franchissement
du seuil d'ouverture ne démontre pas une fermeture ultérieure ; ce point exige une
trace machine.

## 6. Données à acquérir au premier essai

- `BucketOpening_Pct`, positions et vitesses M1/M2 ;
- palier demandé/appliqué et relais/contacteurs M1/M2 ;
- retours frein/contacteurs ;
- intensités disponibles moteur/rotor ou déclencheurs thermiques ;
- bruit/choc et comportement câble observés.

## 7. Journal

- 2026-09-15 : analyse statique ; aucune modification de commande T262 issue de cette fiche.
