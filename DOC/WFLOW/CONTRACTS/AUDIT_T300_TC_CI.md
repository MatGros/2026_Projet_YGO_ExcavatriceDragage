# T300 — Audit initial des TC et de la CI

2026-09-15 — Lecture seule des sources/tests/registre. Aucune suite exécutée, aucun test modifié. Aucun verdict PASS/FAIL runtime ni durée d'exécution actuelle ne découle de cet audit. Périmètre : échantillon M3/SimBench, pas audit exhaustif de tous les domaines.

## Constat et décision proposée

| Réf | Preuve source | Ce que cela démontre / limite | Décision proposée à R2 |
|---|---|---|---|
| A01 | `RESULTS/L_SIMULATION/tests/test_fb_sim_translation.st` : 2 tests, attendent arrêt avec Maintenance FALSE et init Trémie | Le code `CODE/L_SIMULATION/FB_Sim_Translation.st` initialise P1, Maintenance TRUE ; contradiction statique des attendus | Arbitrer l'état initial métier avec AF/utilisateur ; ne modifier ni code ni tests par simple alignement |
| A02 | `test_fb_simbench.st`, TC-P13-040..043 : init/reset Trémie, progression et bornage | Idées de tests utiles, hypothèse initiale également divergente ; assertions DI seules ne prouvent pas une distance de dépassement | Retenir les exigences valides après arbitrage ; oracle mécanique indépendant dans les futurs TC |
| A03 | `test_fb_simbench.st` lignes 62,167,210,336 : quatre `ASSERT_TRUE(TRUE)` | Rappels manuels explicites ; aucune détection automatique d'une faute | Séparer preuve manuelle non exécutée et PASS automatique dans la future restitution ; ne pas les compter en couverture prouvée |
| A04 | `RESULTS/I_TRANSLATION/tests/test_fb_translation_positionestimator.st` : 2 tests | Reprise persistée et front P1 testés ; pas de dynamique fréquence/charge, dérive temporelle, fronts répétés, deux sens dans cette suite | Conserver la valeur des deux cas ; prévoir Q11 et frontières temporelles dans tests futurs |
| A05 | `test_fb_translationoutputinterlock.st` : 3 tests | Neutralisation, refus direction et nominal sont utiles ; frein déjà confirmé dans le nominal | Étendre la preuve par intégration avec délai/panne frein ; ne pas conclure absence de couverture ailleurs sans inventaire global |
| A06 | `CODE/L_SIMULATION/FB_SimBench.st:349,362` : retour frein=ordre ; fréquence proportionnelle à consigne | Le modèle actuel ne prouve ni dynamique frein ni influence mécanique sur le retour pertinent du variateur | Contrats Q03/Q04 + modèle physique identifié ; faux retour instantané comme faute de test |
| A07 | `scripts/config/registry.yaml` relie les quatre suites précédentes aux sources CODE | Suites réellement référencées, pas seulement fichiers orphelins | Vérifier à P2 totalité sources compilées, harnais, mocks et couverture au niveau POU |
| A08 | `scripts/config/config.yaml` : cycle_time_ms=10 | Pas CI configuré ; ne démontre pas l'ordonnancement multitàche du PLC | R0 : confirmer ordre et périodes ; tests avec phase d'échantillonnage |
| A09 | `scripts/run_tests.py` : --fast désactive chronogrammes/rapports ; timings conversion/compilation/exécution/rapports | Capacité de mesure déjà présente ; aucun coût actuel mesuré dans ce lot | Mesurer avant optimisation ; mode rapide pour itération, rapports complets pour preuve de livraison |
| A10 | README CI : concordance AF/TC et encapsulation indiquées non bloquantes | Un PASS général ne démontre pas à lui seul complétude des exigences ni isolation | Exiger Q01/Q02/Q12 comme critères explicites de livraison T300 |

Chemins des suites ci-dessus préfixés par `TOOLS/TEST_AUTO_CI/`. Les quatre assertions tautologiques ne permettent pas de conclure que le reste de la suite est inutile. Une absence dans un fichier ne prouve pas une absence dans tout le registre.

## Grille d'audit complète à produire en P2

Une ligne par TC : identifiant unique, exigence, fichier actif enregistré, niveau unitaire/intégration/manuel, préconditions, horloge, stimuli, attendu indépendant, tolérance, faute détectable, durée conversion/compilation/test, preuve, responsable et décision conserver/compléter/fusionner/reclasser.

Acceptation : 100 % des TC M3 et SimBench du registre inventoriés ; 0 TC automatique retenu sans oracle ; 0 essai manuel non exécuté déclaré validé. Un doublon est établi par même exigence, même domaine de stimuli, même défaut détecté, pas par similitude de nom. Toute décision de retrait/fusion doit préserver la couverture et être revue avant exécution.

## Mesure d'efficacité prévue

Sur un environnement fixé : 3 runs par niveau, médiane/max, temps compiler vs simuler vs produire rapport. Identifier les 5 suites les plus coûteuses et leur contribution à la détection. Aucun classement par coût n'est possible sans ces mesures. Les budgets proposés dans le plan sont des objectifs, pas des résultats.

Ne pas employer la réussite du simulateur comme unique oracle de sa propre physique. Valider séparément les briques par cas de référence et les fonctions de production par les exigences métier ; confronter ensuite la boucle à des traces réservées au contrôle.
