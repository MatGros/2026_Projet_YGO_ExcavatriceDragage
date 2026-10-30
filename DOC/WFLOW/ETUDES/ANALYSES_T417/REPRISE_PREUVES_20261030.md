# T417 — Registre de reprise et expériences — 2026-10-30

Référence témoignage : [registre MES](../../REGISTRES/REGISTRE_MES_TEMOIGNAGE_M3_20261030.md). GO utilisateur reçu pour poursuivre l'objectif ; production inchangée, aucun commit autorisé. Référence de lecture initiale : HEAD `14009dcf`, arbre comportant des travaux tiers conservés.

## Contrat d'investigation et de contre-expertise (lecture seule)

Objectif : établir les défauts du modèle susceptibles de fausser les essais AX14–AX18, sans attribuer une cause terrain sur simple inférence.

Critères testables :
1. Remonter les paramètres du variateur jusqu'à son appel effectif ; citer source et valeur transmise.
2. Examiner la dissipation du frottement : proposer un contre-exemple chiffré si le modèle inverse une vitesse sans force motrice.
3. Séparer commande de frein, état mécanique et contact ; ne pas assimiler fréquence électrique et vitesse mécanique sans justification.
4. Évaluer les tests existants et leur raccordement au runner ; ne pas annoncer un PASS non exécuté.
5. Proposer des expériences discriminantes frein ouvert/fermé, pente nulle/non nulle, approches 10/20 Hz ; aucune injection de défaut pour satisfaire un résultat attendu.

Les avis d'agents sont des hypothèses/revues à contrôler par le principal, jamais des preuves terrain. Maximum trois agents simultanés. Ollama disponible : deepseek-v4.1-flash:cloud et glm-5.3-flash:cloud (inventaire interrogé le 30 octobre).

## Registre des preuves

| ID | Constat de lecture actuel | Statut et prochaine vérification |
|---|---|---|
| E01 | SimBench ne transmet pas DecelRate_HzPerS ni DriveTimeConstantS ; FB_Sim_Translation transmet ses valeurs 25 Hz/s et 0,15 s au FB variateur. | Établi statiquement pour cet appel ; les défauts 20 Hz/s et 0,03 s du FB enfant ne décrivent donc pas le banc intégré. |
| E02 | Branche ObsCartFree : vitesse += (force externe − frottement signé) × dt, sans bornage au passage par zéro. | Risque numérique identifié ; contre-exemple à tester sur ST, pas encore verdict CI. |
| E03 | test_fb_sim_translation_dynamics.st contient déjà M3-DYN-030 (100 ms, deux sens, pas d'inversion) et M3-DYN-040 (10 ms). Recherche dynamics/Dynamics dans registry.yaml sans résultat. | Identifier le runner historique avant de refaire des tests déjà écrits. |
| E04 | M3-DYN-050 utilise frottement 0,1 et attend un départ sous pente 0,2 ; le modèle courant ajoute un seuil statique par défaut 0,35. | Attendu historique devenu incompatible ; ne pas modifier l'attendu sans expliciter le contrat physique. |
| E05 | M3-DYN-100 attend un retour fréquence indépendant du balancement ; FB_Sim_TranslationDrive soustrait gain × ABS(vitesse angulaire). | Divergence test/code à arbitrer sur les données réelles, pas sur le seul test. |
| E06 | Le runner tiers run_m3_study_agents.py tronque le code translation aux 6000 premiers caractères et remplace silencieusement les fichiers absents par une chaîne vide. | Ne pas le réutiliser tel quel ; fournir des sources complètes pertinentes aux contre-experts. Fichier tiers laissé intact. |

## Prochaines expériences

- Retrouver l'exécution historique des tests dynamiques et rejouer l'état actuel sans changer les attentes.
- Vérifier les traces réelles et leur provenance : retrait commande, décroissance fréquence, commande/contact frein ; résolution temporelle explicitée.
- Prouver l'isolation et le câblage du harnais avant de prétendre tester le cycle AX14–AX18.
- Conserver séparément dépassement d'arrêt et dérive lente après arrêt ; pente et frein relâché restent des hypothèses, pas des calibrations terrain.

## Exécution du 30 octobre — état initial réellement testé

Suite existante exécutée par `run_tests.run_one`, avec les dépendances de l'entrée `FB_Sim_Translation` du registry et substitution en mémoire du chemin de test par `test_fb_sim_translation_dynamics.st`. Aucun attendu ni fichier ST modifié. Rapports existants préservés (`generate_reports=False`). Résultat détaillé : [BASELINE_DYNAMIQUE_20261030.json](BASELINE_DYNAMIQUE_20261030.json).

**9 PASS / 3 FAIL sur 12 tests** :
- M3-DYN-030 : +0,004 m/s devient −0,006 m/s par frottement seul à 100 ms. Défaut numérique reproduit sur le ST compilé, sans cause terrain déduite.
- M3-DYN-050 : aucun départ sous pente 0,2 m/s², conformément au nouveau seuil statique 0,35 mais contrairement à l'attendu historique. Arbitrage test/modèle nécessaire.
- M3-DYN-100 : retour 16 Hz au lieu de 20 Hz lorsque vitesse angulaire imposée = 8 rad/s. Confirme le calcul de droop ; ne prouve pas que l'attendu correspond au variateur réel.

Scratch conservé du runner : `TOOLS/TEST_AUTO_CI/.scratch/FB_Sim_Translation/a31a92829f32`. Statut Git contrôlé avant/après ; aucun rapport tiers écrasé par cette exécution.

## Lecture des données historiques — trace 27

Source CSV : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/archives/Suivi_TranslationM3bug_20260904_27_wide.csv`, associée par son meta.json à la trace homonyme. Donnée historique, pas spec active ; provenance MES à recouper avant calibration.

Échantillons directement lus :

| Temps ms | Trémie | Contact frein ouvert | Fréquence brute | Mot commande | State.ErrorId |
|---|---|---|---|---|---|
| 26353 | 0 | 1 | 1000 | 1 | 0 |
| 26438 | 1 | 0 | 1000 | 0 | 64 |
| 26553 | 0 | 0 | 913 | 0 | 64 |
| 26953 | 0 | 0 | 68 | 0 | 65 |
| 27056 | 0 | 0 | 0 | 0 | 65 |

Pas sur l'ensemble : minimum 47 ms, médiane 100 ms, maximum 153 ms. **Ne prouve ni une impulsion exactement de 85 ms ni un ordre causal intra-scan.** La commande électrique de frein et la position mécanique ne figurent pas dans ces colonnes : impossible d'en déduire un retard bobine/contact ou une décélération mécanique de 2 m/s². La fréquence reste non nulle sur plusieurs échantillons après mot nul et contact fermé. Le zéro est observé 618 ms après le premier échantillon mot nul de cette fenêtre, pas une mesure exacte du temps physique d'arrêt.

## Contre-expertises

Les deux appels Ollama sur dossier complet (DeepSeek v4.1 / GLM 5.3, contexte 32768, sortie limitée à 5000 tokens) sont terminés mais ont rendu une **réponse vide**. Aucun avis exploitable, aucune validation acquise. Fichiers vides conservés comme artefacts de tentative. Une question courte ciblée sur la dissipation a été lancée sur DeepSeek sans cette limite de sortie ; résultat à contrôler avant utilisation.

### Suite : avis court reçu et qualification

`AVIS_FROTTEMENT_DEEPSEEK_20261030.md` confirme arithmétiquement le contre-exemple et propose force externe puis dissipation bornée. Avis partiellement utile seulement : sa borne d'erreur mélange les dimensions (accélération × temps² présentée en vitesse), son affirmation sur la nécessité d'un booléen d'hystérésis n'est pas démontrée, et son alerte sur l'unité du seuil provient du prompt court (le code nomme explicitement `_Mps2`). Ne pas reprendre ces conclusions comme validées.

## Harnais et isolation — lecture du 30 octobre

- `TOOLS/TEST_AUTO_CI/MOCKS/FB_TestLoopTranslation.st` ne contient ni le séquenceur AX14–AX18, ni `FB_Safety_Translation`, ni `FB_TranslationOutputInterlock`. Il conserve une cible 20 m et un seuil de départ 6 m. Il ne valide donc pas le scénario demandé ; sa géométrie est à réaligner avant réutilisation.
- `PRG_02_Acquisition.st:318-324` alimente le modèle avec le mot et la fréquence de sortie, plus `PRG_06_Outputs.Data.TranslationBrakeCmd`. Les entrées translation sont sélectionnées à la ligne 482 par `SimulationModeActive AND SimTranslationActive` (ligne 136).
- Limite de l'audit : `PRG_06_Outputs.st:457-459` écrit les symboles de sortie M3. Aucun garde simulation n'est visible dans cette affectation. Cela ne démontre pas un actionnement matériel (mapping/configuration banc non audités), mais interdit de déclarer l'isolation physique prouvée par le seul aiguillage des entrées. Ne pas modifier la production pour résoudre ce point dans T417.

## Commande de régression reproductible

Ajout de `TOOLS/AGENT_WORKFLOW/scripts/check_m3_dynamics.py` : sources du registry, tests existants, empreintes SHA-256, sortie durable explicitement choisie sous DOC/WFLOW, refus d'écraser une preuve existante. Aucun changement des attentes. Exécution :

```powershell
py -3.13 TOOLS/AGENT_WORKFLOW/scripts/check_m3_dynamics.py --output DOC/WFLOW/ETUDES/ANALYSES_T417/BASELINE_DYNAMIQUE_REPRODUCTIBLE_20261030.json
```

Résultat : **exit 1, 9 PASS / 3 FAIL**, mêmes échecs que le premier rejeu. Le garde détecte donc effectivement l'état rouge actuel. Scratch conservé `TOOLS/TEST_AUTO_CI/.scratch/FB_Sim_Translation/9527189f70f9`. `git diff --check` signale des espaces de fin de ligne dans le rapport tiers FB_Sim_Joystick.html déjà modifié avant ce travail ; fichier laissé intact.

## Plan technique de poursuite (GO objectif reçu)

1. Corriger uniquement l'intégration dissipative du chariot libre, sans calibrer une nouvelle pente ni changer les valeurs physiques par défaut. Préserver adhérence statique distincte et inversion sous force externe suffisante. Tests : deux sens, pas 10/20/100 ms, force nulle, sous seuil statique, au-dessus du seuil, frein fermé. Le test 050 devra déclarer explicitement son seuil statique : sa valeur implicite historique ne constitue pas une calibration.
2. Garder l'écart du test 100 visible jusqu'à arbitrage documenté du retour fréquence. Aucun ajustement au seul motif de rendre la suite verte.
3. Réparer la couverture d'intégration : le harnais doit consommer les vrais blocs cycle/translation/safety/interlock et les réglages actuels. Pas de duplication approximative des décisions AX14–AX18. Le scénario doit inclure arrivée, ouverture, attente et départ suivant, à 10 puis 20 Hz.
4. Comparer des variantes de simulation identiques sauf une hypothèse : pente nulle/non nulle et frein commandé ouvert/fermé. Tester ces variantes hors machine réelle, sans imposer une distance de 30–50 cm ni un défaut.
5. Vérifier le chemin sortie finale → modèle → capteurs/retour → estimateur et cycle ; préserver PRG, sécurité, persistance et comportement des autres axes. Export complet/diff, G200 et gates avant livraison ST, puis réception manuelle CODESYS.

### Évaluation du second avis DeepSeek

`AVIS_ESSAIS_AX14_DEEPSEEK_20261030.md` a produit une réponse exploitable mais **non retenue comme procédure** : elle dérive vers des essais physiques avec charge et des mesures électriques indisponibles, alors que le besoin immédiat est un banc logiciel. Elle affirme aussi à tort qu'une absence de mouvement frein ouvert réfuterait à elle seule une pente (le frottement statique peut suffire à maintenir l'arrêt). Retenir seulement la séparation physique/intégration et les chronologies à observer. Aucun essai matériel proposé par cet avis n'est autorisé ou exécuté.

## Expérience pente/frein sur ST — résultat

Ajout de M3-DYN-051 et 052 dans la suite existante : seuil statique courant explicite, pente sous/au-dessus du seuil, frein fermé puis desserré puis refermé. Ces essais sont purement logiciels ; accélération de pente ±0,60 m/s² choisie pour exercer la branche, **pas une estimation de pente réelle**. Résultat : les deux PASS. Le modèle peut déjà produire un déplacement sous pente lorsqu'on libère le frein, et l'arrêter lorsqu'on le referme. Cela ne prouve pas que la commande automate libère le frein en AX15.

M3-DYN-050 conserve ses assertions mais déclare désormais `StaticFriction_Mps2 := 0.1`, seuil propre au scénario historique ; 051 couvre séparément le défaut courant 0,35. Aucun paramètre du banc modifié.

Exécution via `check_m3_dynamics.py --output DOC/WFLOW/ETUDES/ANALYSES_T417/ESSAIS_PENTE_FREIN_20261030.json` : **12/14 PASS**, toujours FAIL 030 (inversion numérique) et 100 (hypothèse retour fréquence). Empreintes sources dans la preuve. Scratch `04f8c0410b6b` conservé. Diff tests vérifié ; aucun fichier CODE modifié. Prochaine action : corriger 030, puis tester le vrai chemin de commande du frein autour d'AX14–AX18, sans confondre capacité physique du modèle et causalité du séquenceur.

## Correctif dissipatif appliqué — lot encore ouvert

`FB_Sim_Translation` : dans la branche libre en mouvement, intégrer d'abord la force externe, puis retirer une impulsion de frottement bornée à la vitesse disponible (MAX/MIN vers zéro). Branche au repos et paramètres physiques inchangés. C'est un schéma discret de premier ordre, pas une résolution exacte de l'instant de passage à zéro ; la sensibilité au pas et le traitement d'une force opposée sous le seuil statique restent à compléter. Variables locales `FreeVelocity_Mps` et `FrictionStep_Mps`, sans nouvelle interface ni lecture GVL. Aucun code production modifié.

Preuve `APRES_DISSIPATION_20261030.json` : **13/14 PASS**, 030 passe (deux sens, 100 ms, absence de redémarrage numérique), 060 passe (force extérieure autorise une inversion), essais pente/frein préservés. Seul 100 reste rouge. Garde automatique : `check_m3_dynamics.py`, exit non nul maintenu tant que la suite reste rouge.

Bundle complet régénéré et fraîcheur PASS ; diff bundle contient `FB_Sim_Translation` seul. G200 : **PASS, 0 erreur, 1722 avertissements, 2169 instances vérifiées**. Avertissements conservés, pas assimilés à une preuve d'isolation physique. Gates de fin de lot et réception CODESYS non exécutés à ce stade. Aucun commit. Les essais AX14–AX18 ne sont pas remplacés par ce correctif numérique.

## Chaîne AX14–AX18 et écart M3-DYN-100 — lecture complémentaire

### Faits de source

- `FB_CycleSemiAuto.st:1485-1499` commande M3 vers Trémie en AX14 puis annule `TranslationCmd.ReqStart` dès le capteur. Le passage AX15A est conditionné par `TranslationStopTimer`, lui-même soumis à `Translation_At_Tremie AND NOT Translation_Busy` (`:363-369`).
- AX15A, AX15B, AX15C et AX18 posent tous `TranslationCmd.ReqStart := FALSE` (`:1518`, `:1553`, `:1586`, `:1604`).
- `PRG_05_Translation.st:400-407` limite en semi-auto les étapes M3 à AX2 et AX14. Sa barrière finale redondante met explicitement `BrakeReleaseRequest := FALSE`, mot variateur et fréquence à zéro hors AX2/AX14 (`:698-720`). `FB_TranslationOutputInterlock` en déduit `BrakeCmd := BrakeReleaseRequest ...` (`FB_TranslationOutputInterlock.st:137`).

**Conséquence strictement limitée :** le code source versionné actuel demande bien le serrage en AX15–AX18. Cela ne prouve ni la version chargée sur la machine réelle, ni le comportement de la bobine, du contact ou du frein mécanique. Le banc ne doit donc pas annuler cette barrière ; une éventuelle dérive devra être modélisée comme hypothèse/défaut simulé explicitement, séparé de la commande automate nominale.

### M3-DYN-100 : arbitrage reporté, pas de correction opportuniste

Le test, ajouté au commit `555327be` à 21:08, attend un PDO fréquence indépendant du balancement. Six minutes plus tard, `6cce0c93` a modifié le même modèle : `ActualFrequency_Hz` retire `LoadFrequencyDroopGain_Hz × ABS(LoadAngularVelocity_RadPerS)` (`FB_Sim_TranslationDrive.st:51-56`) et a supprimé le commentaire qui définissait le PDO comme fréquence électrique indépendante. L'échec 100 est donc une incohérence historique avérée entre test et code, mais aucune des deux sémantiques n'est encore validée par une trace suffisamment qualifiée. Le test reste rouge et le modèle reste inchangé jusqu'à décision documentée.

Le contrat T417 AC2 indique 200 ms d'ouverture, alors que `FB_Sim_TranslationBrake.st:8-9` et l'étude T417 portent actuellement 100 ms d'ouverture et 90 ms de fermeture. Cette divergence documentaire est un **point ouvert** : aucune valeur n'est modifiée sur cette seule lecture.

### Contre-expertise locale

Deux demandes courtes ont été adressées au runner Ollama local le 30 octobre, après échec des demandes longues antérieures. Le service a répondu HTTP 410 avant production d'un avis ; aucune conclusion d'agent n'est utilisée. L'analyse ci-dessus repose uniquement sur les fichiers et l'historique Git cités.

## CI composite SimBench — blocage circonscrit et essai de remplacement

Exécution initiale : `py -3.13 TOOLS/TEST_AUTO_CI/scripts/run_tests.py --fb FB_SimBench --fast`.

- La conversion et les contrôles d'interface atteignent les 17 composants déclarés. Le premier blocage était une référence registry vers `CODE/L_SIMULATION/ST_fbSim_Translation_ExtLink_Echo.st`, type supprimé au commit `7b47291f`. Un miroir **test-only** a été placé sous `TOOLS/TEST_AUTO_CI/MOCKS/` et les trois entrées de registry concernées y pointent ; aucune source PLC n'a été recréée.
- Après ce rétablissement du harnais, le parseur STruCpp s'arrête avant toute assertion M3 sur `test_fb_simbench.st:897` : `Expected END_FOR found ADVANCE_TIME`. L'instruction est située dans une boucle d'un scénario M2 antérieur. C'est une incompatibilité du test/parser, non un verdict sur M3 et non une autorisation de modifier le test M2 hors scope.
- Remplacement proposé et ajouté : `test_fb_simbench_m3_dynamics.st` + `check_simbench_m3_chronology.py`. Le runner substitue le seul chemin de test en mémoire dans l'entrée existante `FB_SimBench` : mêmes sources/dependencies réelles, pas de duplication du modèle, pas d'écriture de rapport tiers. Le scénario vérifie la chronologie confirmée dans les sources AX14→AX15 (rampe frein maintenu ouvert, puis retombée mécanique différée) à pente simulée nulle. Il ne représente pas le cycle complet ni une mesure terrain.

Exécution : `py -3.13 TOOLS/AGENT_WORKFLOW/scripts/check_simbench_m3_chronology.py --output DOC/WFLOW/ETUDES/ANALYSES_T417/CI_SIMBENCH_M3_CHRONOLOGIE_20261030.json`.

Résultat : **PASS, 1/1**. La preuve contient les empreintes SHA-256 de toutes les sources du montage et le scratch conservé `TOOLS/TEST_AUTO_CI/.scratch/FB_SimBench/b4db5c6f1c86`. Le verdict prouve seulement le scénario logiciel STruCpp décrit ci-dessus ; il ne compile pas un projet CODESYS et ne valide aucun comportement machine réelle.

## Alerte de source — position estimée M3 (hors correction T417)

Chaîne établie par lecture : `PRG_02_Acquisition.st:749-750` publie la fréquence réelle acquise ; `PRG_05_Translation.st:621-656` appelle le gain odométrique puis l'estimateur et persiste son résultat. L'estimateur reçoit simultanément `DriveActualFreqHz` et les demandes sémantiques (`ReqTremie`, `ReqMaintenance`).

`FB_Translation_PositionEstimator.st` intègre la distance seulement lorsque la fréquence est >0,1 **et** qu'une demande de sens unique est encore vraie. Son recalage se fait sur les fronts des cinq capteurs. Or la lecture de cycle déjà consignée établit que AX14 retire `TranslationCmd.ReqStart` à l'arrivée Trémie, tandis que la trace historique montre que la fréquence peut rester non nulle après retrait du mot. **Risque logiciel identifié :** pendant une décélération contrôlée post-retrait de demande, la position estimée peut se figer avant la fin du mouvement physique jusqu'au prochain capteur.

Ce point explique structurellement le mécanisme de l'écart observé en simulation, mais ne constitue pas une preuve que la machine réelle reproduit la même chronologie (version chargée, fréquence, commande frein et position vraie inconnues). Il est hors scope T417 : aucune modification `PRG_05`, sécurité ou persistance n'est faite. Condition avant tout lot correctif : trace/snapshot qualifié contenant simultanément demande de sens, fréquence réelle, position estimée, mot capteurs et commande/contact frein.

## Étape CODESYS / Control Win non exécutée

Le compilateur/IDE CODESYS n'est pas lançable depuis ce dépôt sans projet ouvert et copie Control Win préparée par l'utilisateur. Le POC existant (`TOOLS/PLC_CSV_SNAPSHOT/docs/M3_ROUNDTRIP_POC.md`) exige explicitement Simulation IDE, Login/RUN et les deux verrous de simulation actifs. Aucune connexion, déploiement ou écriture d'automate n'a été tentée. Lorsque le banc sera préparé, l'essai à faire est lecture d'abord, sur la copie isolée : tracer les cinq signaux de la condition précédente sur approche Trémie puis AX15–AX18 ; les scripts POC existants peuvent uniquement confirmer le chemin de données, pas autoriser un mouvement.

## Rejeu CI du cycle AX14–AX18 — non conclu, pas un échec fonctionnel

Deux essais du runner existant `TOOLS/TEST_AUTO_CI/scripts/run_tests.py --fb FB_CycleSemiAuto --fast` ont été lancés. Le premier a uniquement constaté le chemin historique absent `TOOLS/TEST_AUTO_CI/run_tests.py`; aucun test n'avait alors démarré. Les deux appels corrects au runner sous `scripts/` ont atteint l'étape `cablage production`, puis ont expiré dans la fenêtre interactive avant résultat d'assertion. Scratchs conservés : `TOOLS/TEST_AUTO_CI/.scratch/FB_CycleSemiAuto/027e399ac288` et `.../0d6a50fa32c0`.

Verdict : **non conclu**. Ne pas transformer cette expiration en PASS, FAIL métier ou preuve du cycle. La chronologie AX14–AX18 reste pour l'instant établie par lecture source citée plus haut ; le rejeu CI devra être effectué dans une session laissant le runner terminer.

## Contre-revues indépendantes — 30 octobre

### Estimation M3

Revue lecture seule : `PRG_05_Translation.st:621-656` transmet bien fréquence acquise et demandes de sens à `FB_Translation_PositionEstimator`. L'intégration de ce FB exige simultanément fréquence >0,1 Hz et une demande de sens exclusive. AX14 retire la demande à l'arrivée capteur ; le gel post-demande est donc **possible par logique source** si la fréquence reste positive. La CI existante de l'estimateur est 10/10 mais ne couvre pas cette combinaison. Données nécessaires pour passer de ce risque source à une preuve banc : étape/requête, fréquence réelle, position estimée, mot/DI capteurs, commande et contact frein ; `M3ObsPositionTrue_M` seulement en simulation.

### Cycle AX14–AX18

Contre-revue de la CI : l'échec du runner complet n'est pas causé par le câblage. Le test historique `test_fb_cyclesemiauto.st` référence `AX15D_DUMP_BUCKET_JOG` (lignes 304, 315, 448, 466, 476), absent de `E_AutoCycleStep.st` et du cycle actuels. Les assertions historiques X10→X13 couvrent AX14→AX18 mais sont donc inatteignables sur cette baseline avant compilation. Ce décalage test/source est hors T417 ; ni l'énumération ni le cycle ne sont modifiés.

Un test minimal T417 a été ajouté, sans AX15D, ainsi qu'un runner qui désactive **explicitement** l'extraction de câblage production (G200 reste la preuve distincte de liaison). Première exécution : compilation et assertion lancées, échec de test dû à une temporisation `TranslationStopTimer` avancée avant son armement dans le scénario nouvellement écrit ; preuve conservée : `CI_CYCLE_AX14_AX15_20261030.json`. Le scénario a été corrigé (scan `Busy=FALSE` avant `ADVANCE_TIME`). Son rejeu `R2` dépasse la limite interactive avant résultat final ; scratch conservé `TOOLS/TEST_AUTO_CI/.scratch/FB_CycleSemiAuto/6e8bd071053a`. Verdict R2 : **non conclu** ; aucun PASS revendiqué.

Rejeu `R3` avec session suivie jusqu'à sortie : le test atteignait l'assertion, mais restait rouge parce que la publication `CycleStep` intervient au scan suivant l'affectation interne de `State`. Ce n'est pas une anomalie cycle : la lecture du code le confirme. Le test ajoute donc ce scan explicite, sans changer de source métier. Rejeu `R4` : **PASS 1/1** — `CI_CYCLE_AX14_AX15_R4_20261030.json`. Il prouve, dans la baseline actuelle, la séquence : demande M3 active en AX14 avant Trémie ; demande retirée immédiatement lorsque Trémie est vraie ; maintien AX14 pendant `Translation_Busy` ; transition vers AX15A après stop confirmé 500 ms ; demande toujours nulle en AX15A. Limite maintenue : le câblage production est exclu de ce runner et reste couvert séparément par G200 ; ce test ne contient pas le variateur, frein ni SimBench.

## Vérification mécanique du lot en cours

Bundle complet régénéré le 30 octobre depuis **263/263** objets. `G200_check_linkage.py --report` : **PASS, 0 erreur, 2169 instances vérifiées, 1722 avertissements**. Les avertissements L9/L10/L11 existants ne sont ni masqués ni interprétés comme preuve d'isolation matérielle. Diff bundle régénéré : `CODE_XML/CODE_DiffBundle.xml`, objet inclus `FB_Sim_Translation`. Les tests/outils ajoutés ici ne sont pas inclus dans un bundle PLCopenXML. Les gates de fin de lot restent volontairement non exécutés : le désaccord M3-DYN-100 est toujours ouvert et aucune compilation/réception CODESYS isolée n'a encore eu lieu.

## Essai compilateur CODESYS headless — verdict non prouvé, garde-fou réparé

`TOOLS/AGENT_WORKFLOW/scripts/test_codesys_compile.py FB_Sim_Translation` localise bien CODESYS 3.5.19.10 et le projet de base `v0.7.36_SimBench_M3PLC_CalcPos_20261029.project`. L'outil génère le XML granulaire dans une copie temporaire ; il ne déploie rien. Premier essai sandbox : refus d'accès temporaire avant génération XML. Rejeu hors sandbox : XML généré, CODESYS lancé, mais aucun `build_result.log` issu de `project.check_syntax()` n'a été produit alors qu'une instance interactive CODESYS du projet était déjà ouverte.

Défaut outillage détecté : le script retournait alors le code 0 de CODESYS et pouvait faire croire à une compilation valide sans preuve. Correctif `fix + guard` dans `test_codesys_compile.py` : absence de `build_result.log` => erreur explicite et exit 1. Rejeu après correctif : **exit 1**, message `CODESYS did not produce build_result.log; compilation is unproven.` Cela prouve le garde-fou, **pas** la compilation M3. Condition de reprise : CODESYS doit produire le log de syntaxe sur une copie isolée (aucune instance interactive qui absorbe le script headless), puis G500 validera ce log.
