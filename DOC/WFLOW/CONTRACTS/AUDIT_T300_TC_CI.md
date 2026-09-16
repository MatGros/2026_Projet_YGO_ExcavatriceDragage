# T300 — Audit initial des TC et de la CI

2026-09-15 — Lecture des sources/tests/registre. Baseline ciblée exécutée le 2026-09-16 en mode `--fast`; aucun test modifié. Périmètre : échantillon M3/SimBench, pas audit exhaustif de tous les domaines.

## Baseline fraîche du 2026-09-16

| Suite | Verdict | Étape / durée | Preuve conservée |
|---|---|---|---|
| `FB_Sim_Translation` | FAIL 0/1 | pas de JSON, 2,43 s | `.scratch/FB_Sim_Translation/16a211725ebf` |
| `FB_SimBench` | FAIL 0/1 | conversion, 0,39 s | `.scratch/FB_SimBench/7a6d6631a105` |
| `FB_Translation_PositionEstimator` | FAIL 0/1 | pas de JSON, 1,09 s | `.scratch/FB_Translation_PositionEstimator/5159c8fc601c` |
| `FB_TranslationOutputInterlock` | FAIL 0/1 | pas de JSON, 0,85 s | `.scratch/FB_TranslationOutputInterlock/cd82265ff384` |

Les chemins sont relatifs à `TOOLS/TEST_AUTO_CI/`. Les suites qui atteignent l'analyse d'encapsulation sont vertes sur ce contrôle. Les warnings confirment des IDs tests absents des catalogues : `TC-P13-TR-001/002`, `TC-P11-EST-001/002`, `TC-P11-INT-001/002/003`; l'AF estimateur attend `TC-P11-EST-01/02/03`. Cette baseline interdit de déclarer une non-régression verte. Les durées observées sont faibles ; aucune suppression de test ne se justifie par le coût à ce stade.

### Diagnostic `--debug` ciblé

| Suite | Cause observée avant assertions | Nouveau scratch conservé |
|---|---|---|
| `FB_SimBench` | conversion interrompue : le registre demande `CODE/J_SUPERVISION/_TYPES/5_ASSISTANCE_DRAGAGE/ST_ChainDredgingAssist.st`, absent du dépôt actif | `.scratch/FB_SimBench/6a0fee9b0327` |
| `FB_Sim_Translation` | rejet STruCpp dès l'en-tête : caractères Unicode de commentaire et commentaire de bloc déclaré non fermé | `.scratch/FB_Sim_Translation/7d52ed10d198` |
| `FB_Translation_PositionEstimator` | génération C++ atteinte, puis compilation C++ échouée sans diagnostic remonté par le runner | `.scratch/FB_Translation_PositionEstimator/06456c6876c0` |
| `FB_TranslationOutputInterlock` | génération C++ atteinte, puis compilation C++ échouée sans diagnostic remonté par le runner | `.scratch/FB_TranslationOutputInterlock/a8f6169eed48` |

Conclusion : les quatre rouges sont des échecs d'infrastructure/compilation antérieurs à l'exécution des assertions. Ils ne prouvent ni conformité ni non-conformité fonctionnelle du M3. Le runner doit aussi restituer `stderr` du compilateur C++ pour rendre les deux derniers échecs diagnostiquables ; ce correctif d'outillage reste séparé du modèle physique T300.

### Etat après implémentation dynamique

`FB_Sim_Translation` : PASS 6/6, preuve `.scratch/FB_Sim_Translation/eb95d3051bcc`. Les oracles exécutés couvrent repli P1, rampe 20 Hz/s, réponse du drive, délai frein, déplacement/charge, commande contradictoire et stabilisation DI d'environ 1 s.

`FB_SimBench` : 19/24. `TC-T300-INT-010` est PASS : commande finale, frein temporisé, fréquence retournée et `StatusWord` atteignent l'image translation puis retombent après arrêt réel. Les 5 échecs restants sont classés avant toute décision :

| TC existant | Nature | Décision T300 |
|---|---|---|
| `TC-P13-014` | Initialisation codeur M1/M2, hors dynamique M3 | Diagnostiquer indépendamment ; ne pas attribuer au modèle M3 |
| `TC-P13-040..043` | Tests directs de l'ancien modèle monotone, init Trémie et déplacement instantané | Remplacer par les TC T300 de `test_fb_sim_translation.st` et réviser le catalogue AF ; aucune neutralisation ou PASS artificiel |

Le fallback explicite `g++` a permis l'exécution réelle des assertions après l'échec de liaison interne STruCpp. Les scratchs restent volontairement conservés conformément à la politique CI.

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

## Revue independante T300 du 2026-09-16

| Point de revue | Resolution apportee | Preuve automatique | Limite restante |
|---|---|---|---|
| FDC Maintenance inatteignable au bornage 30 m | Seuil DI synthetique avance a 29,95 m, distinct de la butee a 30 m | `TC-T300-SEN-010` : mot `00000` a Maintenance | Geometrie terrain a mesurer |
| Episode DI rearmable sans fin par recroisements | Un recroisement ne remet plus le chronometre a zero ; il change seulement la cible finale | `TC-T300-SEN-031` | Trace terrain de perte/reprise a comparer |
| Variabilite aleatoire non rejouable | Graine explicite, tirage unique par episode, periode dans [70 %, 130 %] du nominal | `TC-T300-SEN-040` : 100 graines | Campagne 48 scenarios x 100 graines non executee |
| Position du godet injectee directement dans un DI rail | Supprimee : le pendule agit par reaction mecanique chariot, et conditionne seulement le scenario electrique optionnel | `TC-T300-MEC-010`, `TC-T300-SEN-030` | Identification mecanique charge/support requise |
| Chaine runtime complete PRG02 -> SimBench -> HwIn | Liaison source controlee ; essais FB executes | G200 a rejouer apres bundle final | Essai runtime CODESYS avec trace humaine requis |
| Miroir IHM IoHw.In.Hardware | Le miroir recopiait HwReal et masquait les DI SimBench ; il recopie maintenant HwIn | G502 + bundle frais | Front d'activation et trace CODESYS requis |
| Registre de couverture CI | G450 cherchait un ancien chemin de registre ; il utilise maintenant `TEST_AUTO_CI/scripts/config/registry.yaml` avec repli historique | G450 PASS (contrôle informatif) | Écarts catalogue historiques hors périmètre T300 |

Resultats frais de la campagne du 2026-09-16 : `FB_Sim_PositionSensor` 4/4, `FB_Sim_TranslationDrive` 3/3 (dont `TC-T300-DRV-050` au pas 100 ms), `FB_Sim_TranslationBrake` 2/2, `FB_Sim_SuspendedLoad` 3/3, `FB_Sim_Translation` 9/9 (dont `TC-T300-SEN-011` pour la commutation PV), `FB_SimBench` 26/26 et `FB_Safety_Translation` 5/5 (`TC-T300-SAF-060/061`). `TC-T300-INT-030` execute le relai representatif `SimBench.Translation -> image HwIn -> FB_Translation_PositionDecoder` jusqu'au mot Maintenance `00000`; `TC-T300-INT-031` y couvre aussi une perte, une reprise puis la stabilisation de P1 avec episode dynamique configure. `TC-T300-CAM-100` a execute 48 scenarios synthetiques x 100 graines x 200 pas = 960000 pas ; assertion runtime 2,91 s lors de la campagne de reference. Ces tests ne qualifient ni les constantes terrain ni une execution ordonnancee complete de `PRG_02` dans CODESYS.

### Garde-fou de frontiere

Addendum campagne 2026-09-16 : `FB_Sim_TranslationDrive` est maintenant a `3/3` avec `TC-T300-DRV-050` (pas de 100 ms conserve).

`G502_check_simbench_m3_boundary.py` est PASS. Il impose un unique pont `instSimBench.Translation -> HwSim.Translation`, l'arbitrage unique `HwReal/HwSim -> HwIn.Translation`, l'armement/desarmement des domaines sur fronts de `SimulationModeActive`, les commandes M3 post-interlock et l'absence d'ecriture de DI M3 hors SimBench. Il est ajoute au palier C. Son perimetre est statique : il ne prouve ni la periode d'execution CODESYS ni la reaction des memorisations aval.

## Revue refactor / physique independante du 2026-09-16

| Niveau | Constat | Decision |
|---|---|---|
| Bloquant qualification | `TC-T300-INT-030/031` prouvent une copie representative SimBench -> image -> decodeur, y compris une perte/reprise P1, mais n'executent pas la chaine ordonnancee `HwSim -> HwIn -> instPosDecoderM3 -> TranslationState` de CODESYS. | Ne pas declarer AC4/AC4bis qualifies. La procedure `PROCEDURE_TRACE_T300_M3_SIMBENCH.md` fixe les signaux et oracles de la trace humaine requise. |
| Majeur corrige | La reaction pendulaire pouvait redonner une micro-vitesse au chariot apres contact butee. | Le contact rigide bloque maintenant position et vitesse translation ; le pendule conserve son etat. `FB_Sim_Translation` 9/9 apres correction. |
| Majeur borne | La campagne 48 x 100 varie surtout les episodes capteur ; elle n'est pas une validation de 4800 configurations terrain independantes. | La preuve est renommee exploration synthetique : invariants de bornage, frequence et mot thermometrique uniquement. |
| Majeur ouvert | AC600, technologie frein, masse/transmission et geometrie instrumentee restent inconnus. | Statut V1 synthetique ; ne pas calibrer ni valider la fidelite terrain avant trace et donnees constructeur/mesure. |
| Majeur ouvert | La masse de charge n'est pas encore exposee comme parametre physique dedie : le modele utilise des gains de reaction/droop synthetiques. Une variable de masse ne peut pas etre ajoutee opportunement sans suffixe d'unite valide selon NC-030 et sans masse equivalente du chariot. | Conserver les gains profiles pour V1 ; ouvrir une decision de nomenclature et une mesure masse/transmission avant d'introduire un couplage kg explicite. |
| Majeur ouvert | NC-030 impose des suffixes d'unites normalises ; certaines interfaces publiques T300/heritage ne les ont pas. | Migration atomique distincte a planifier, sans renommage opportuniste incompatible pendant la qualification. |
| Mineur corrige | Consigne drive et vitesse angulaire pouvaient depasser leurs bornes internes. | Consigne limitee a 40 Hz et vitesse angulaire limitee a 4 rad/s ; `FB_Sim_TranslationDrive` 3/3 et `FB_Sim_SuspendedLoad` 3/3 frais. |

La ligne historique `FB_SimBench : 19/24` ci-dessus est un instant intermediaire avant correction du registre et des anciens tests directs. Le resultat frais de livraison est `FB_SimBench : 26/26`; il ne leve pas le bloqueur runtime ci-dessus.

## Audit de completion T300 - etat de preuve au 2026-09-16

| AC | Etat | Evidence actuelle / reste necessaire |
|---|---|---|
| AC1 | PARTIEL | Position mecanique unique et cinq DI derives : testes. Geometrie, polarite et technologie terrain non validees. |
| AC2 | PREUVE_SYNTHETIQUE | Episode intermittent borne et rejouable : `FB_Sim_PositionSensor` 4/4, `INT-031`. Parametres 1 s non calibres. |
| AC3 | PREUVE_SYNTHETIQUE | Bornes Tremie/Maintenance et mots `11111`/`00000` testes, deux sens explores par CAM-100. Validation terrain manquante. |
| AC4 | PENDING_TRACE | G502 + relais representatif, mais pas d'execution ordonnancee CODESYS jusqu'a PRG_05/safety. |
| AC4bis | PENDING_TRACE | Aucune injection aval detectee statiquement. Fronts, memoires et etats aval a observer dans la trace CODESYS. |
| AC5 | PARTIEL | Repli SimBench et selection unique HwReal/HwSim controles. Essai CODESYS OFF avec image reelle reste requis. |
| AC6 | PASS_CI | Repli P1, sens contradictoires, override et non-regressions SimBench executes. |
| AC7 | PARTIEL | Hypotheses et donnees bloquees documentees ; donnees constructeur/mesure a collecter. |
| AC8 | PARTIEL | Bundle frais, diff, G200 et G502 verts. Palier C frais du 2026-09-16 : G310/G320/G330/G345/G350/G360/G370/G375/G390/G450 passent ; echecs historiques G300 (`TOOLS/AGENT_WORKFLOW/.tmp`), G340 (liens documentaires), G406 (litteraux longs), G430 (commentaires REX) et G483 (matrice maintenance) restent ouverts. Artefacts conserves par politique ; aucun nettoyage automatique autorise. |
| AC9 | PASS | `G310_check_code_structure.py` : PASS 0 erreur ; aucun renommage POU M_MAIN realise. |
| AC10 | PREUVE_SYNTHETIQUE | Drive/frein/charge/capteur composes, convergence charge 10 ms/5 ms. Constantes physiques non qualifiees. |
| AC11 | PASS_CI_LIMITED | Graine deterministe et 100 graines capteur. CAM-100 est une exploration synthetique, pas une campagne terrain. |
| AC12 | PREUVE_SYNTHETIQUE | Stabilisation configuree 1 s, testee. Mesure trace necessaire. |
| AC13 | PASS_CI | Buttee distincte des seuils, bornes, repos et convergence testes. |
| AC14 | PARTIEL | G502 impose source post-interlock et chemin image. L'ordonnancement reel est `PENDING_TRACE`. |
| AC15 | PARTIEL | Plan distingue synthetique/estime/inconnu ; classement exhaustif des donnees terrain reste a viser. |
| AC16 | PARTIEL | Bobine, mecanique, contact temporises. Technologie frein, pannes et pouvoir de freinage sont `BLOCKED_DATA`. |
| AC17 | PARTIEL | Plan, contrat, audit, ST, CI et garde-fou livres. Qualification runtime, gates globaux et validation humaine restants. |

Conclusion : le lot est utilisable pour une trace CODESYS en simulation, mais ne peut pas etre cloture ni declare fidele terrain avant les preuves `PENDING_TRACE`, les donnees frein/AC600/geometrie et les gates globaux applicables.
