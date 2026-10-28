## 1) Diagnostic sur l’annulation complète de T420

Au vu des éléments, **T420 est mal cadrée et non recevable comme correction de référence** : elle transforme un paramétrage de simulation/calibration T419 (`SimWinchCoast_M = 1.30 m`) en correction de régression M1/M2, avec une valeur imposée `0.35 m` dans le code, un script de garde et un test dédié. Cela crée deux sources de vérité contradictoires et risque de casser le comportement validé d’AX15B.

**Annuler T420 dans l’état actif est donc pertinent**, à condition que ce soit fait comme un **rollback contrôlé depuis la référence T419 / le gestionnaire de versions**, et non comme une purge manuelle partielle. Il faut préserver l’historique/audit de T420 pour la traçabilité, mais retirer ses artefacts actifs.

Si un “roulis long parasite M1/M2 hors AX15B” était réellement observé, il devrait faire l’objet d’un ticket séparé, avec mesures, logs et test reproductible. On ne doit pas corriger un éventuel couplage M1/M2 en abaissant globalement un paramètre calibré pour l’ouverture de benne.

## 2) Impacts d’un retour propre au checkpoint pré-T420

Un retour propre doit rétablir :

- `SimWinchCoast_M = 1.30 m` dans `GVL_Simulation.st` et `FB_SimBench.st` ;
- `M2_EffectiveCoastM` à sa valeur/expression pré-T420 exacte, car T420 avait aussi tenté de la passer à `0.35 m` ;
- les commentaires d’origine à `1.30 m` ;
- la suppression de `check_sim_winch_coast.py` ;
- la suppression de `TC-P13-077` ;
- le retrait de T420 de `TASKS.yaml`.

Impacts positifs :

- cohérence retrouvée entre code, commentaires, tests et tâches ;
- disparition des échecs CI dus à un garde-fou attendant `0.35 m` ;
- comportement AX15B de nouveau aligné sur T419 : anticipation d’ouverture `1.3 m`, fin de course ouverte visée `OffsetOpenM = 0.0`.

Points de vigilance :

- vérifier qu’il ne reste **aucune référence** à `0.35`, `TC-P13-077`, `check_sim_winch_coast.py` ou `T420` dans la CI, les manifests de tests, la documentation, les hooks ou `TASKS.yaml` ;
- vérifier `M2_EffectiveCoastM`, qui a pu rester à `0.35` si la remise manuelle n’a touché que `SimWinchCoast_M` ;
- si `TASKS.yaml` sert aussi de registre d’audit, préférer une entrée “annulée/revertie” plutôt qu’une suppression pure, sauf si l’historique Git/change record suffit ;
- la suppression de `TC-P13-077` supprime une couverture, mais elle était fondée sur une exigence fausse. Il peut être utile de la remplacer plus tard par un test de non-régression T419, idéalement comportemental : AX15B atteint la butée ouverte, pas de dépassement anormal, pas de roulis parasite hors AX15B.

## 3) Effets de bord cachés / points de vigilance M1-M2 et AX15B

Les principaux risques sont :

1. **Couplage M1/M2** : il faut retracer l’usage exact de `SimWinchCoast_M` et de `M2_EffectiveCoastM`. Si M2 utilise une valeur effective dérivée ou une constante séparée, restaurer uniquement `SimWinchCoast_M` à `1.30` peut laisser M2 incohérent. Il faut restaurer l’état pré-T420 complet, pas seulement la constante numérique visible.

2. **AX15B** : `1.30 m` est justifié par l’anticipation d’ouverture de benne. Avec `0.35 m`, on risque un arrêt avant la butée ouverte ou un `OffsetOpenM` non nul. Avec `1.30 m`, il faut revalider :
   - ouverture complète jusqu’à la butée ;
   - absence de sur-course ou d’impact anormal dans le modèle ;
   - fermeture correcte ;
   - comportement propre en ouverture/fermeture partielle, reset, homing, défaut et reprise.

3. **Roulis/coast hors AX15B** : si le paramètre est global, il faut vérifier par simulation que le retour à `1.30 m` ne réintroduit pas un vrai symptôme sur M1/M2 hors AX15B. Si un symptôme réapparaît, la bonne solution n’est probablement pas de remettre T420, mais de conditionner le coast à l’ouverture AX15B ou de séparer les paramètres M1/M2 et benne.

4. **Transitions et cas simultanés** : tester M1 seul, M2 seul, M1+M2, AX15B seule, AX15B avec M1/M2, et les séquences automatiques/manuelles.

## 4) Validation de la démarche de purge complète de T420

**Oui, je valide la purge complète des artefacts actifs de T420**, sous réserve d’une méthode rigoureuse :

- rollback depuis le checkpoint/commit pré-T420 ou `git revert` du commit T420 ;
- vérification du diff complet : constantes, `M2_EffectiveCoastM`, commentaires, scripts, tests, `TASKS.yaml` ;
- suppression de toutes les références résiduelles en CI/doc/manifests ;
- compilation CODESYS et exécution de la suite de tests ;
- validation fonctionnelle AX15B + M1/M2 ;
- conservation de la trace historique de T420 dans Git et, si nécessaire, dans un registre de décision.

Donc : **T420 doit être annulée et ses artefacts actifs supprimés**, mais il faut le faire comme un **retour versionné et vérifié à T419**, pas comme une édition manuelle partielle. Si un symptôme M1/M2 réel subsiste après rollback, il devra être traité dans un nouveau ticket correctement cadré, avec un test reproductible et sans modifier la calibration validée d’AX15B.