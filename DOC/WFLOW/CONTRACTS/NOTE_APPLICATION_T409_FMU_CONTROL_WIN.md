# T409 — application et revue de cohérence M3

## Corrections intégrées

- La trame plante conserve séparément la fréquence demandée et la fréquence mesurée.
- Les valeurs FMU sont bornées avant sérialisation : une valeur aberrante ne peut plus arrêter la passerelle.
- Les mots capteurs admissibles sont explicitement cumulatifs : `11111`, `01111`, `00111`, `00011`, `00001`, `00000`.
- Une rupture `0 → 1` vers la droite est rejetée et n'écrase pas l'image `GVL_Simulation.SimM3OpenModelica`.
- Le test hors ligne couvre tailles de trames, séparation Hz consigne/mesure, six mots capteurs et bornage.

## Limites restantes avant validation terrain

1. La position FMU est une télémétrie du POU passerelle ; elle n'est pas encore une variable de l'image `ST_HwTranslation` existante.
2. Le démarrage FMU est actuellement à `20 m` (P1). Il faut une décision explicite de synchronisation initiale avec la position connue du banc avant tout essai de séquence automatique.
3. Le temps de vieillissement est exprimé en cycles de tâche supposés de 10 ms ; la mesure réelle de période doit être ajoutée avant un critère temps réel contractuel.
4. La stabilité anti-rebond des capteurs doit être testée avec une campagne de franchissement et de rebroussement autour de chaque seuil.

## Preuve locale

```text
python TOOLS/TWINBENCH/udp_m3_link/test_t409_protocol.py
[PASS] T409 frame sizes, requested/measured Hz and bounds
[PASS] T409 admissible cumulative sensor words: 11111..00000
```

Cette preuve ne valide pas encore la compilation ST ni le fonctionnement Control Win. Ces deux validations doivent être réalisées dans la copie Control Win avant tout GO d'intégration.
