# TwinBench — vue opérateur 2D liée à la plante — 2026-09-17

## Décision

La vue cible n'est ni une 3D décorative, ni le résultat d'un chronogramme Modelica.
Elle comporte deux vues complémentaires du même jumeau :

1. **2D opérateur, premier jalon** : synoptique rapide à lire pour conduire et diagnostiquer ;
2. **3D mécanique, objectif maintenu** : profondeur, mouflage, deux câbles, benne, charge et
   collision/volume ne peuvent pas être compris correctement dans une seule projection 2D.

La 2D est inspirée des photos réelles : pont, chariot M3, tambours/treuils M1-M2, câbles,
traverse, benne preneuse, niveau d'eau, fond/Kobold et zones Trémie/Maintenance.

Chaque position ou état visible lit une sortie de la même FMU que les courbes. Aucune interpolation
de mouvement JavaScript, scénario graphique ou « fausse physique » n'est admise.

## Repère mécanique commun 2D / 3D

| Axe | Convention figée | Vue 2D opérateur |
|---|---|---|
| `X` | Trémie (0 m) → Maintenance (30 m) | horizontal gauche → droite |
| `Z` | vertical machine, positif vers le haut | vertical bas → haut |
| `Y` | transversal avant/arrière du pont | profondeur ; représentation réduite en 2D |

Les libellés génériques `Front`, `Side`, `Top` du visualiseur OpenModelica ne sont pas des
repères machine. La vue métier de conduite est la projection `X-Z` en regardant suivant `Y`.

## Écart constaté et rejeté

L'ancienne page `Atelier` contient un dessin M3 et une benne pédagogique, mais elle consomme
`Atelier.AxisLab`, une plante POC différente de `Dredge.TranslationM3Plant`. Elle n'est donc pas
la vue TwinBench cible et ne doit pas être présentée comme telle.

Modex compile et trace actuellement les résultats, mais n'affiche pas les `Shape` Modelica ; OMEdit
peut servir à valider l'animation technique, pas à fournir l'interface opérateur.

## Composition obligatoire de la vue

```text
┌──────────────────────────── PONT / RAIL M3 ─────────────────────────────┐
│  Trémie    capteurs M3      [ chariot maître + treuils ]      Maintenance │
│                                  │ M1      │ M2                           │
│                                  │         │                              │
│                                  └── traverse / benne ──┘                 │
│ ────────────────────────────── niveau d'eau ──────────────────────────── │
│                                  fond / Kobold                             │
└──────────────────────────────────────────────────────────────────────────┘
```

| Élément dessiné | Signal FMU source | Statut |
|---|---|---|
| Abscisse chariot | `M3CarriagePosAct_M` | L1, déjà disponible sous `positionM` |
| Mouvement/frein M3 | vitesse, fréquence, retour frein | L1, déjà disponible |
| Longueur câble M1 / M2 | `M1CablePosAct_M`, `M2CablePosAct_M` | L2, à valider physiquement |
| Hauteur traverse / benne | cinématique M1/M2 | L2, dérivée unique de plante |
| Écart, ouverture des mâchoires | `BucketApertureAct` / delta câble | L2/L3, table calibrable |
| Eau, fond, Kobold, charge | niveau scénario/contacts/tensions | L3, à instrumenter |
| Capteurs / freins / défauts | image `HwSim [HW]` typée | L1 puis L2 |

## Ergonomie de conduite

1. **Une vue mécanique centrale**, sans faux tableau de bord.
2. À gauche : choix `Scénario | Manuel virtuel | USB`, homme-mort clairement séparé de l'autorité PLC.
3. À droite : arbre filtrable `Commandes | Configuration | Mesures | Retours TOR | Etats | Diagnostics`.
4. En bas : chronogrammes sélectionnés ; cliquer un élément du dessin ajoute sa grandeur au tracé.
5. Un mode « édition live » modifie uniquement `CFG_RUN` au point sûr, affiche hypothèse/calibration,
   versionne l'événement et ne touche jamais `CFG_BUILD` ou la safety PLC.

## Critères de réception

- `VR-2D-01` : la position graphique M3 est strictement issue de la dernière valeur FMU horodatée.
- `VR-2D-02` : un clic « tracer » sur chariot, câble, benne ou capteur ouvre la même grandeur,
  avec unité et qualité issues du catalogue.
- `VR-2D-03` : une valeur stale/invalid rend l'élément orange/gris avec son âge ; jamais un mouvement conservé.
- `VR-2D-04` : le dessin différencie M1 et M2, et les deux câbles ne lisent jamais la même variable.
- `VR-2D-05` : aucune commande graphique ne court-circuite l'adaptateur `Cmd → FMU → HwSim`.
- `VR-2D-06` : dimensions, mouflage et charge non relevés portent explicitement le statut `hypothèse`.

## Séquence de construction

1. Remplacer le dessin `Atelier.AxisLab` par une vue Dredge M3 2D réelle (L1).
2. Brancher le catalogue de signaux, qualité et sélection de traces (L1).
3. Ajouter M1/M2, câbles et benne seulement après la validation FMU L2.
4. Construire la scène 3D depuis ces mêmes sorties L2/L3 : M3 horizontal, longueurs M1/M2,
   position traverse, ouverture mâchoires et charge ; aucune deuxième cinématique graphique.
5. Ajouter eau, Kobold, charge et défauts de procédé après le relevé L3.

Une revue visuelle humaine sur les photos et cotes de la machine est requise avant de déclarer la
vue « réaliste ».
