# T300 — Conception dynamique SimBench M3

Statut : implémentation incrémentale en cours avec paramètres calibrables ; fidélité terrain finale soumise aux données matérielles restantes. Mise à jour : 2026-09-16.

Reviews expertes du 2026-09-16 : les corrections d'architecture, ownership, délai N+1 et tests sont intégrées dans `INTERFACES_T300_SIMBENCH_M3.md` et `TEST_DESIGN_T300_SIMBENCH_M3.md`. La trace terrain fournie le 2026-09-16 autorise l'implémentation du profil fréquence et d'un frein temporisé. Les paramètres encore inconnus restent configurables et marqués `SYNTHETIQUE` ; ils bloquent la qualification de fidélité, pas la compilation ni les essais du modèle.

## Observations et limites de connaissance

| Donnée | Origine | Usage |
|---|---|---|
| Capteur perdu/repris, stabilisation environ 1 s | Observation utilisateur | Cible du profil de signal de référence ; pas une période de pendule |
| Chariot perturbé pendant le déplacement sous charge | Observation utilisateur | Couplage charge/chariot en marche et à l'arrêt |
| Godet chargé environ 10 tonnes | Estimation utilisateur | Profil chargé provisoire, masse totale suspendue à confirmer |
| Câble environ 1 à 2 m | Estimation utilisateur | Longueur pendulaire effective à confirmer ; distincte de la seule longueur de câble visible |
| Amplitude, amortissement, masse du chariot, transmission, géométrie des cames | Non mesurés | Paramètres calibrables ; profils synthétiques identifiés |

## Trace terrain M3 — calibration initiale du 2026-09-16

Source : analyse utilisateur d'une trace CODESYS de 351 points, `VISU_TASK`, période observée environ 100 ms, fréquences codées au centième de hertz.

| Paramètre | Valeur retenue | Incertitude / usage |
|---|---:|---|
| Rampe accélération/décélération | 20 Hz/s nominal | plage observée 18–20 Hz/s |
| Décélération vers PV | 16,8 Hz/s observé | modèle configurable séparément |
| Grande vitesse / petite vitesse | 40 Hz / 10 Hz | valeurs observées |
| Constante de temps retour fréquence | 0,15 s | identification premier ordre sur trace |
| Ouverture frein | 0 à 0,10 s | bornée par l'échantillonnage ; pas d'instantanéité prouvée |
| Fermeture frein après vitesse nulle | 0,08 à 0,10 s | observation directe à résolution 100 ms |
| Seuil PV | DI active à l'état FALSE | transition observée à 18,362 s ; retour TRUE après franchissement |

La fréquence commandée suit une rampe bornée. La fréquence retournée suit séparément un premier ordre discret `alpha = dt/(tau+dt)`. Le retour frein n'est jamais recopié directement depuis l'ordre : la commande électrique, l'ouverture mécanique et le contact auxiliaire restent trois états distincts. La trace ne fournit pas encore la position vraie, le couple, la masse du chariot, la transmission ni la technologie exacte du frein.

La masse seule ne détermine ni l'amplitude ni la période. La géométrie, la longueur effective, l'accélération et l'amortissement interviennent. Le mouvement de la charge peut durer après que le capteur ne commute plus. Aucune équivalence automatique entre stabilisation électrique en 1 s et extinction du mouvement mécanique.

## Architecture proposée

`Sorties finales M3 → entraînement → chariot et charge couplés → capteurs → HwSim → HwIn → logique M3 existante`

| Brique proposée | Responsabilité |
|---|---|
| `FB_Sim_Translation` | Composition du modèle M3, état initial, pas temporel et scénarios |
| `FB_Sim_TranslationDrive` | Réponse de l'entraînement aux ordres finaux, fréquence, frein et puissance ; conversion vers effort/vitesse du modèle |
| `FB_Sim_SuspendedLoad` | Évolution couplée position/vitesse chariot et angle/vitesse de charge ; inertie, réaction horizontale et amortissement |
| `FB_Sim_PositionSensor` (5 instances) | Géométrie cible/came, polarité, hystérésis physique et réponse du capteur ; publication DI |
| `FB_SimBench` | Composition existante et publication cohérente capteurs, frein et variateur |

`FB_Sim_PositionSensor` est livré dans ce lot : capteur cumulatif compatible avec le mot thermomètre M3, hystérésis, délai électrique et épisode de perte/reprise rejouable. `FB_Sim_TranslationDrive`, `FB_Sim_TranslationBrake` et `FB_Sim_SuspendedLoad` sont désormais des briques distinctes, avec tests unitaires ; leurs constantes restent synthétiques tant que les paramètres mécaniques et la sémantique complète de l'AC600 ne sont pas identifiés. `FB_Sim_Translation` reste l'unique intégrateur de position chariot ; l'entraînement ne maintient pas une seconde position concurrente. Le modèle mécanique reçoit une excitation issue des commandes finales après interlocks, et conserve sa dynamique résiduelle après retrait de commande. Le frein freine le chariot ; il ne doit pas effacer instantanément l'angle de charge.

Choix recommandé : modèle réduit chariot/pendule amorti, avec effort de réaction sur le chariot et réponse limitée de l'entraînement. Une simple sinusoïde ajoutée à une position linéaire reste un profil synthétique de comparaison : elle ne suffit pas à représenter le couplage demandé. L'identification des paramètres de couplage conditionne la fidélité quantitative.

Les capteurs de rail observent le déplacement relatif cible/capteur. Ne pas ajouter directement le déplacement latéral du godet à la position détectée du chariot. L'effet passe par la réaction mécanique et, si constatée, la flexibilité du support. Conserver la géométrie cumulative actuelle uniquement si elle correspond au terrain ; une fenêtre de détection ne se déduit pas du seul mot thermomètre.

## Intermittence et variabilité

- Recroisements mécaniques : transitions issues de la position relative et de la géométrie, y compris après arrêt.
- Intermittence additionnelle : scénario distinct de perte/reprise DI, utile pour reproduire une trace sans prétendre que sa cause est identifiée. Ne pas cumuler par défaut ce scénario et les recroisements mécaniques.
- Stabilisation de référence : environ 1 s observée. Profil exploratoire proposé 0,7 à 1,3 s, bornes synthétiques à valider et modifiables ; pas une tolérance terrain démontrée.
- Tirages à l'entrée d'un épisode ou lors d'un événement défini, paramètres gelés pendant l'épisode. Pas de bruit blanc ajouté à chaque scan.
- Graine, paramètres, pas de temps, commandes et version du modèle enregistrés. Même scénario = même trace. Campagne multi-graines en complément des essais déterministes.
- Épisodes déclenchés par une excitation/franchissement qualifié ; un capteur qui oscille ne réarme pas indéfiniment son propre épisode.

## Cohérence électrique et temporelle

Tracer avant ST les commandes finales réellement consommées, unités fréquence/vitesse, retour arrêt et frein. La sémantique du retour AC600 reste à identifier : fréquence électrique de sortie, estimation de vitesse ou mesure mécanique ne sont pas interchangeables. Le modèle publie exactement la grandeur documentée du PDO. La position mécanique vraie demeure indépendante de l'estimateur applicatif et de sa fréquence d'entrée.

Séparer seuils capteurs et butées mécaniques. Le bornage actuel aux extrêmes ne doit pas supprimer le dépassement nécessaire pour tester une perte/reprise. Toute excursion est bornée par le modèle de course physique, avec un diagnostic d'impact distinct.

Pas d'intégration explicite, subdivision pour les pas longs et comparaison de convergence. Distinguer le temps interne du modèle et l'échantillonnage PLC : une impulsion plus courte qu'un scan peut être invisible au programme ; ne pas fabriquer une capture idéale absente de l'acquisition réelle.

## Livraison par étapes

Frontière vérifiée dans les sources : PRG_02 lit M3_CommandWord, M3_SetpointFrequencyHz et PRG_06.Data.TranslationBrakeCmd ; publie HwSim.Translation puis sélectionne HwIn.Translation. Vérifier les producteurs finaux et unités avant ST.

Écart identifié : PRG_05 lignes 353–355 sélectionne directement GVL_Simulation.SimBtnTremie/SimBtnMaintenance. Leur routage doit rejoindre une frontière opérateur explicite, en conservant priorité joystick et homme-mort. Ces boutons ne sont pas des DI procédé. La publication du statut simulation pour affichage est une lecture informative distincte. Auditer également les adaptations de diagnostic device à l'acquisition avant d'affirmer l'isolation complète. Ajouter un garde-fou automatique contre les injections parallèles et tester toute la boucle avec le même code métier réel/simulé.

1. Cartographier commandes finales, capteurs et mémoires aval ; confirmer géométrie/polarité et identifier paramètres calibrés/synthétiques.
2. Implémenter et tester les briques mécaniques puis les cinq capteurs ; publier position, vitesse, oscillation, DI, épisode et graine pour observation.
3. Raccorder dans SimBench et HwSim ; comparer les fronts aux mémoires M3 réelles. Préserver l'override manuel avec règles explicites de sortie sans saut mécanique caché.
4. Campagne déterministe puis multi-graines ; conserver chaque échec rejouable. Adapter les AF et produire bundle complet/diff, G200 et gates.

## Acceptation et essais

- Deux sens, extrêmes, zones intermédiaires, vide/chargé, faible/forte excitation, marche et arrêt près des seuils.
- Accélération, freinage normal, commande interrompue, inversion et coupure puissance ; cohérence déplacement/fréquence/frein.
- Capteur actif/perdu/repris sur environ 1 s ; scénarios juste sous/au-dessus des temporisations M3 réellement lues dans le code.
- Vérifier stabilité des mémoires et absence de reprise indue ; un défaut existant révélé est tracé séparément, jamais effacé pour rendre la simulation verte.
- Même graine et entrées : même trace ; plusieurs graines : respect des bornes et absence de dérive numérique.
- Pas réduit : résultats convergents ; sans excitation : décroissance de l'énergie du modèle amorti.
- Simulation inactive, override, réactivation : comportement explicite et reproductible ; aucun état de position aval injecté.

T296 traite les fréquences persistantes : consommer ses sorties effectives sans dupliquer ses réglages. La validation au banc établit une capacité de reproduction ; la fidélité terrain exige ensuite une comparaison de traces.

## Contrats détaillés de phases et revues

Le présent lot livre la conception et l'audit en lecture seule. Les phases d'implémentation ci-dessous sont planifiées, pas exécutées. Aucun TC existant ne doit être modifié dans ce lot. Les critères Q ci-dessous sont la référence mesurable ; les descriptions précédentes expriment les intentions.

| Phase | Entrées / travail | Livrable et sortie exigée | Revue / responsable |
|---|---|---|---|
| P0 — Identification | Sources versionnées, schémas disponibles, réponses utilisateur, traces | Inventaire de 100 % des interfaces M3 ; registre paramètres avec source/unité/plage/incertitude ; zéro technologie inconnue utilisée comme fait | R0 : automaticien/utilisateur confirme technologies et paramètres bloquants |
| P1 — Architecture | P0 ; analyse de la boucle et des équations | Contrat de chaque composant, état initial, équations, unités, pas et budget CPU ; tous les producteurs/consommateurs identifiés | R1 : revue automatisme et mécanique, choix du modèle réduit |
| P2 — Spécification des tests | Exigences approuvées et audit des TC | Matrice Q→TC→oracle→preuve ; seuils numériques figés ; manifestes de scénarios et graines ; tests futurs écrits/revus avant ST fonctionnel | R2 : humain + reviewer désigné approuvent attendus, sans les dériver du code à venir |
| P3 — Briques | R2 approuvée | Variateur/moteur, frein, mécanique, capteurs ; 100 % des tests unitaires approuvés passent ; zéro seuil relâché pour accommoder le code | R3 : revue diff et résultats par composant |
| P4 — Boucle intégrée | P3 ; câblage réel des POU | Sorties finales→modèle→HwIn→métier ; matrice 48 scénarios et 100 graines ; 0 violation des invariants | R4 : revue traces, erreurs estimateur, isolation et anomalies |
| P5 — Qualification | P4 ; traces terrain indépendantes | Validation sur traces réservées, budget CPU mesuré, CI complète, bundle/diff, G200 ; liste écarts résiduels | R5 : validation humaine CODESYS et limites de fidélité documentées |

Les rôles de review sont des fonctions à attribuer ; aucune revue indépendante n'est annoncée réalisée. Une review peut être humaine, sans délégation automatique. Toute anomalie produit un ticket lié, un attendu et, après autorisation du correctif, un garde-fou ; elle n'élargit pas silencieusement T300.

### Échéancier proposé

Estimation de charge, pas engagement calendaire : P0 0,5–1 jour hors attente documentaire ; P1 1–2 jours ; P2 1–2 jours ; P3 2–4 jours ; P4 1–2 jours ; P5 1–2 jours hors disponibilité banc/terrain. Total indicatif 6,5–13 jours de travail. R0/R1/R2 précèdent P3 ; R3 précède P4 ; R4 précède P5. Rechiffrer à R1 à partir du nombre de paramètres inconnus et des résultats de l'audit complet des TC. Aucun délai d'attente de réponse ne vaut approbation.

## Contrats par composant

| Composant | Entrées physiques / commandes | État propre et sorties | Vérification indépendante |
|---|---|---|---|
| Alimentation / entraînement AC600 | Commande finale, fréquence en Hz, puissance disponible | Disponibilité, délai établissement/magnétisation, fréquence délivrée, limitations, défauts et PDO documentés | Chronogrammes paramétrés et trace variateur ; commande ≠ retour instantané |
| Moteur / transmission | Excitation entraînement, couple résistant, frein | Vitesse mécanique et effort au chariot, glissement si technologie pertinente, rapport de transmission | Cas stationnaire et transitoire analytique simplifié, unités vérifiées |
| Frein | Ordre électrique et alimentation | Énergisation, délai de desserrage, couple de freinage, délai de serrage, retour contact avec délai propre | Mesure séparée commande→contact et commande→effet mécanique, scénarios coincé ouvert/fermé |
| Chariot + charge | Effort moteur, frein, masse, longueur effective, frottements | Position/vitesse vraie, angle/vitesse angulaire, réaction de charge, énergie | Équilibre, conservation cas idéal, dissipation cas amorti et convergence numérique |
| Chaque capteur et acquisition | Position relative cible, géométrie, polarité, alimentation | DI brute, temps réponse, hystérésis et échantillonnage | Table de vérité, seuils dans les deux sens, impulsions courtes, capteur bloqué/perdu |
| Interface procédé | Sorties finales lues, retours composants | HwSim.Translation ; sélection HwIn atomique | Traçabilité exhaustive et absence d'écriture aval |
| Estimateur applicatif (observé) | Fréquence réellement publiée et DI échantillonnées | Position estimée, recalages, erreur vs position vraie | Oracle extérieur à l'estimateur ; le simulateur ne recopie jamais cette position comme vérité |

Les états électrique, contact auxiliaire et mécanique du frein sont distincts. La technologie exacte détermine la polarité et les transitions de perte de puissance. La magnétisation n'est activée dans le modèle qu'après identification de sa pertinence pour le moteur et le mode de commande. Les données sont regroupées en briques seulement si elles partagent une responsabilité ; un FB par signal serait inutile.

## Registre des questions à résoudre en P0

1. Référence moteur, type, puissance, pôles, vitesse nominale et mode AC600 (U/f, vectoriel, retour codeur ou sans capteur).
2. Référence exacte des PDO lus : grandeur, unité, résolution, période de rafraîchissement et bits d'état ; rampes et limites de courant/couple configurées.
3. Frein : technologie, tension, action à perte de puissance, contact physique présent ou état déduit, délais desserrage/serrage/magnétisation et couple nominal.
4. Transmission : rapport, diamètre effectif, jeu/compliance ; masse chariot, masse totale suspendue vide/chargée et longueur effective.
5. Cinq capteurs : technologie, NO/NC, position et largeur des cames, hystérésis, filtrage d'entrée matériel ; éventuelles butées distinctes.
6. Tolérances métier : erreur de position maximale, temps d'arrêt et distance admissibles selon les cas. Valeurs à approuver, jamais déduites du seul code actuel.

Chaque réponse est classée MESURÉE / DOCUMENTÉE / ESTIMÉE / SYNTHÉTIQUE / INCONNUE. Une INCONNUE n'empêche pas le plan mais interdit la qualification terrain de la branche concernée. Aucun Device.export existant ne sert de référence.

## Objectifs quantifiés et oracles (à figer à R2)

Les valeurs de campagne/temps ci-dessous sont des propositions de recette, pas des mesures machine. Δt désigne le pas d'échantillonnage effectif validé en P0 ; la CI utilise 10 ms par défaut. Le modèle M3 suit le Δt réel jusqu'à 100 ms pour ne pas ralentir artificiellement une trace VISU_TASK, mais toute qualification de délais inférieurs à 100 ms exige une tâche CODESYS plus rapide et la mesure de sa période effective.

| ID | Critère de succès mesurable | Oracle / preuve |
|---|---|---|
| Q01 | 100 % des entrées/sorties M3 utilisées ont producteur, consommateur, unité, polarité, période et source documentés ; 0 doublon écrivain | Matrice interfaces revue R0 |
| Q02 | 0 injection procédé hors HwSim/HwIn ; 0 sélection fonctionnelle GVL_Simulation dans le métier M3 ; statut d'affichage explicitement listé | Audit source et garde-fou, essais simulation ON/OFF |
| Q03 | Pour chaque délai paramétré τ, transition observée dans [τ, τ+Δt] ; 0 confirmation mécanique anticipée | Horloge de test indépendante, cas τ−Δt/τ/τ+Δt ; frein et entraînement |
| Q04 | Conversion des retours variateur conforme au PDO à ±1 LSB ; chaque bit publié respecte sa table approuvée | Vecteurs documentés ; fréquence électrique et vitesse mécanique distinctes |
| Q05 | Cas analytique simple : erreur position/vitesse ≤1 % de l'excursion/vitesse de référence non nulle ; à l'équilibre, dérive ≤1 mm sur 60 s | Calcul de référence indépendant et état initial fixé |
| Q06 | Sans excitation ni gravité motrice externe, énergie amortie finale ≤ énergie initiale ; hausse numérique maximale ≤0,1 % de l'énergie initiale non nulle sur 60 s | Bilan énergétique indépendant ; cas énergie initiale nulle sans création de mouvement |
| Q07 | Pas h puis h/2 : écart maximal position ≤1 mm et dates de transition DI ≤Δt ; 0 NaN/Inf pour toutes bornes paramétrées | Étude convergence, mêmes entrées ; seuil de 1 mm proposé à R1 |
| Q08 | Profil intermittence de référence : ≥2 transitions après premier front, dernière transition ≤1 s+Δt puis aucun front pendant 2 s ; profils variables dans [0,7;1,3] s+Δt | Chronogramme synthétique, distinct des oscillations mécaniques persistantes |
| Q09 | Même graine/paramètres/commandes/pas/version sur même runtime : 3 replays identiques ; 100 graines sans sortie hors bornes | Comparaison traces ; inter-runtime comparé avec tolérances numériques R2 |
| Q10 | 48 scénarios = 2 sens × 2 profils de charge × 3 régimes (marche/décélération/arrêt) × 4 situations (nominal/seuil/perte capteur/frein retardé) ; 0 invariant violé | Traces boucle complète ; seuils incluent les deux extrêmes selon sens |
| Q11 | Erreur estimateur e=x_estimée−x_vraie mesurée à chaque scan ; max, RMS, erreur avant/après chaque recalage et temps stabilisation produits pour 100 % des scénarios | Position vraie indépendante ; limites Emax/Erecal/Tsettle numériques signées R2, aucune valeur vide à la sortie P2 |
| Q12 | 100 % des tests automatiques retenus ont exigence, préconditions, stimulus, oracle et tolérance ; 0 assertion tautologique comptée comme preuve | Matrice tests ; cas manuel marqué À FAIRE tant que non exécuté |
| Q13 | 8 défauts ciblés injectés séparément et détectés par ≥1 test chacun ; 0 survivant inexpliqué | Inversion sens, fréquence retour figée, échelle Hz fausse, frein instantané, contact collé, DI figée, contournement interlock, recalage estimateur omis |
| Q14 | 0 overrun sur 30 min banc CODESYS ; temps maximal SimBench ≤ budget Bsim et temps tâche ≤ période configurée ; Bsim chiffré R1 | Mesure charge PLC ; marge approuvée selon tâche, sans imposer arbitrairement 10 ms |

Q03 décrit les délais déterministes. Pour les délais variables, τ est la valeur tirée et enregistrée pour l'épisode. Q08 qualifie le profil synthétique de stimulus ; il ne force pas une mécanique à s'arrêter en 1 s. Q11 ne promet pas que l'estimateur actuel satisfait les futures limites : un échec constitue un résultat utile à instruire.

### Qualification terrain séparée

Minimum proposé : 12 traces indépendantes (2 sens × 2 charges × 3 répétitions), avec fréquence consigne/retour, sorties frein, contact, cinq DI et déplacement de référence indépendant si disponible. Réserver au moins 4 traces à la validation, sans les utiliser pour ajuster les paramètres. Pour chaque grandeur, fixer à R2 une tolérance numérique fondée sur la résolution de mesure et le besoin métier ; publier RMSE, erreur maximale et erreur de date des fronts. Sans mesure indépendante de position, ne qualifier que les signaux observés et signaler que la fidélité de déplacement reste non démontrée.

## Politique de tests et efficacité CI

Chaîne : exigence approuvée → scénario/oracle figé → validation du modèle → tests composants → boucle réelle des POU → CI → banc CODESYS → comparaison terrain.

L'oracle est le résultat attendu indépendant du code testé. Conserver un manifeste de référence avec révision exigences, tests, paramètres et graines. Après R2, toute modification d'attendu indique : exigence modifiée ou erreur démontrée de l'oracle, impact, ancien/nouveau résultat et visa reviewer. Une défaillance du code ne justifie jamais à elle seule de relâcher une assertion. Une correction légitime d'un test reste possible et traçable.

| Niveau | Déclenchement proposé | Contenu / budget cible |
|---|---|---|
| Rapide | Chaque lot composant | Assertions unitaires et frontières ; cible ≤2 min, sans chronogrammes si runner le permet |
| Intégration M3 | Avant R4 et changement de câblage/modèle | 48 cas + 8 fautes ; cible ≤10 min |
| Robustesse | Avant R5 ou changement dynamique | 100 graines × horizon 60 s simulées ; cible ≤20 min murales |
| Livraison | Fin de lot | CI/gates projet obligatoires, rapports et bundle/G200 ; budget mesuré, pas supprimé pour gagner du temps |

Budgets proposés, non chronométrés. Mesurer 3 exécutions comparables (machine, concurrence, révisions, mode fixés), séparer conversion/compilation/exécution/rapports, publier médiane et maximum. Optimiser après mesure. Ne pas recompiler/rejouer une campagne inchangée sans nouvelle cause ; ne pas supprimer les contrôles imposés par le projet.

Un test est utile s'il détecte une faute pertinente ou protège une exigence distincte. Un test rapide n'est pas automatiquement utile ; deux tests semblables ne sont pas automatiquement redondants. Toute proposition de fusion/retrait doit conserver la matrice de couverture et la capacité de détection. Aucun retrait exécuté ici.

Audit initial : [AUDIT_T300_TC_CI.md](AUDIT_T300_TC_CI.md). Ce document est un échantillon argumenté et ne certifie pas l'ensemble de la CI.
