# 🧭 T417 — Pilotage des investigations

## État courant — Simulation IDE CODESYS (mise à jour 2026-11-01)

| Sujet | Résultat | Décision |
|---|---|---|
| Simulation IDE | Device `0000 000a`, version `3.5.19.10`, confirmé dans R11. | Aucun accès machine réelle. |
| Build + injection R11 | `app.rebuild()` après injection de 4 POU ; `BUILD_ERRORS=0`, puis login et RUN. Les SHA-256 des sources injectées sont tracés. | Build/source établis pour ces POU et cette copie seulement. |
| Essai automatique R11 | Réarmement AU confirmé. Le homing a été forcé en lot (pas exécuté physiquement). L'entrée en semi-auto a échoué (`SEMI_AUTO not accepted`) ; aucun cycle AX14–AX18 validé. | Investiguer les permissifs de mode avant un nouvel essai de cycle. |
| Homing R29 | 14 POU injectés, rebuild sans erreur. Après stimulation explicite du capteur haut à M1=7,157 m, le premier relevé montre M1 brut 29892 vs preset 29438 (454 points ≈111 mm), puis défaut preset latched 4 sur M1/M2 et HX7. | Échec runtime reproductible ; la lecture est déjà après HX7, donc le moment exact du désaccord reste à capturer. Joystick maintenu : l’effet d’un relâchement n’est pas testé. |
| Essai discriminant R30 | Relâchement joystick au capteur haut préparé, mais `app.rebuild()` renvoie une erreur CODESYS générique ; le garde arrête avant login. | Aucun essai runtime ; investiguer l'intermittence du rebuild avant de conclure sur le repli à l’arrêt. |
| Ancien essai R7, 10/20 Hz | `app.build()` générique en erreur, mais runner a poursuivi jusqu'à RUN ; identité du binaire alors exécuté non établie. | Conserver ces mesures comme observation runtime non attribuable aux sources injectées ; ne pas les utiliser comme verdict source. |

Preuves : R11 `CODESYS_AUTO_R11_20261101/runtime.log` ; R29/R30 `TOOLS/AGENT_WORKFLOW/.tmp/t417_auto_r29_20261101/runtime_r29.log` et `t417_auto_r30_20261101/runtime_r30.log` (runners et journaux conservés). L'échelle codeur déclarée est 8192 points / 2 m = 4096 points/m ; le seuil de vérification 10 mm vaut environ 41 points. Les erreurs `Object reference not set...` sont intermittentes selon ces exécutions ; R30 n'a pas atteint le runtime.


### Mise ? jour ? test dynamique Simulation IDE / m?thode T423 (2026-10-31)

Le tableau initial ci-dessus est historique et supers?d? pour l'ex?cution M3 : le runner T423 a ?t? repris sur la copie `v0738.project`, Device `0000 000a`, Simulation IDE confirm?e. R?armement AU et mise en r?f?rence homing lus en retour. Le seuil de hauteur M1/M2 a bloqu? le manuel ; le seul bypass `M3Translation.Bypass.MinHeight` a ?t? activ? dans cette copie de test puis remis ? FALSE. Aucun fichier ST de production n'a ?t? chang?.

| PV manuel | P1?Tr?mie | Tr?mie?P1 | arr?t apr?s rel?chement | verdict limit? |
|---:|---:|---:|---:|---|
| 10 Hz | 26,32 s ; arr?t 4,91 s ; d?passement rapport? 24 mm | 26,62 s ; arr?t 4,70 s ; d?passement rapport? 69 mm | position finale 5,0005 m | 2 trajets observ?s, stable 20 ?chantillons |
| 20 Hz | 14,13 s ; arr?t 5,12 s ; d?passement rapport? 130 mm | 14,31 s ; arr?t 5,09 s ; d?passement rapport? 220 mm | position finale 5,1509 m | arr?t stable d?clar?, mais position finale 151 mm au-del? de P1 nominal |

Preuves brutes : `TOOLS/AGENT_WORKFLOW/.tmp/t417_m3_t423_run_r7_20261031/runtime.log` et `samples.csv`. Crit?re d'arr?t d?clar? par le harnais : fr?quence r?elle nulle, mouvement non demand?, position inchang?e pendant 20 ?chantillons (pas de 0,2 s environ). Les distances ? d?passement ? sont la sortie `SimM3ObsOvershootLast_M`, calcul?e du front capteur d'arr?t ? la position finale ; elles sont des sorties du mod?le, pas des mesures terrain. Le crit?re physique de d?tection P1 est ? ?25 mm du P1 configur? ; la DI cumulative ne fournit pas un ?v?nement P1 distinct dans ce trajet.

**Limites :** R7 n'établit pas l'identité des sources du runtime, car `app.build()` a échoué alors que le runner a continué. R11/R29 ferment ce défaut de méthode pour leurs essais (rebuild zéro erreur, sources injectées hachées) ; R30 démontre que le garde bloque bien le login lors d'un rebuild en erreur. R29 établit un échec de preset pendant le homing simulé, mais ne prouve pas encore si le mouvement résiduel, le délai du preset ou leur interaction le déclenche. Aucun cycle AX14–AX18 validé ; les mesures R7 10/20 Hz restent non attribuables au build source.

> 31 octobre 2026 · Étude exécutée, proposition D prête à valider · Banc non réceptionné
> Ce plan remplace les prochaines actions contradictoires des bilans précédents. Les preuves historiques restent conservées.

## 🎯 Résultat utile attendu

Un banc M3 crédible pour développer et tester les séquences AX14–AX18 : commande, rampe variateur, mouvement, frein, capteurs et position estimée cohérents. Reproduire des défauts plausibles avec leurs hypothèses identifiées. Une panne injectée ne prouve pas sa cause sur la machine réelle.

**Priorité absolue :** ordre des événements, autorisations, défauts, arrêt et reprise. La finesse physique supplémentaire se justifie seulement si elle change une de ces décisions ou l'écart de position utile au cycle. Pas de pourcentage global de réalisme sans référence mesurable.

## 📊 Tableau de décision actuel

| ID | Question | État / preuve | Limite / prochaine décision |
|---|---|---|---|
| V1 | Dissipation et dynamique élémentaire | ✅ 16/16, rapport APRES_G518_COUVERTURE_R2_20261030.json | Assertions logicielles ; pas calibration réelle |
| V2 | Retrait demande AX14 et passage AX15A | ✅ 1/1, CI_CYCLE_AX14_AX15_R4_20261030.json | Cycle seul ; câblage production exclu |
| V3 | Chronologie dans SimBench | ✅ 1/1, CI_SIMBENCH_M3_CHRONOLOGIE_R2_20261030.json | Montage ciblé ; pas cycle complet |
| P1 | Fonctionnement utilisateur 10/20 Hz | 🟠 essais 94/95 reçus ; compilation déclarée OK | Pas d'amélioration perçue selon utilisateur ; pas de verdict de conformité globale |
| P2 | AX14→AX18 intégré | 🟠 étapes présentes dans les lectures précédentes | Passage d'étape ne prouve pas tous les invariants ; exploiter les traces avant tout autre essai |
| H1 | Gel position estimée après retrait demande | 🟡 risque identifié dans les sources | Prouver sur chaîne intégrée ; ne pas modifier l'automate dans ce lot |
| H2 | Dérive lente liée à pente + frein | 🟡 témoignage et hypothèse physique | Distinguer dérive après arrêt et dépassement pendant rampe |
| H3 | Défaut frein plus fréquent à 10 Hz | 🟡 témoignage réel | Deux essais simulés ne quantifient pas une fréquence de panne |
| O1 | Distance vraie / position estimée capturées | 🔴 instrumentation initiale insuffisante | Responsabilité agent ; configuration importable à vérifier avant livraison |
| O2 | Isolation matérielle | ⚪ non démontrée par les seuls tests | Examiner cible et chemin des sorties ; G200 ne suffit pas |

**Contrôle du 31/10 :** empreintes SHA-256 de toutes les sources déclarées dans V1/V2/V3 identiques aux fichiers actuels. Rapports lus, aucune CI relancée. La couverture des assertions reste limitée aux scénarios décrits.

Légende : ✅ acquis dans un périmètre explicite ; 🟠 partiel ; 🔴 échec identifié ; 🟡 hypothèse ; ⚪ non testé. Un résultat partiel est détaillé par critère, jamais converti en PASS global.

## 🔬 Procédure d'une investigation

1. **Question unique** : quelle décision bloque la suite ? Quel effet sur AX14–AX18 ?
2. **Hypothèses concurrentes** : prédiction observable, variable discriminante, source et plage plausible de chaque paramètre.
3. **Réutilisation** : rechercher une preuve existante ; vérifier version, empreintes, configuration et assertions avant tout rejeu.
4. **Expérience minimale** : annoncer attendu et seuil avant exécution ; choisir l'outil ci-dessous ; changer un facteur à la fois.
5. **Verdict par critère** : valeur attendue, obtenue, écart, incertitude et portée. Un échec de compilation est un blocage de harnais, pas un échec physique.
6. **Décision enregistrée** : conserver, corriger, écarter dans cette plage ou différer. Indiquer précisément ce qui autoriserait la réouverture.

Une piste sans nouvelle preuve après deux expériences discriminantes est réexaminée : erreur de mesure, hypothèse commune ou périmètre du harnais. Ne pas multiplier les variantes sans prédiction différente.

## 🛠️ Outil adapté à la preuve

| Question | Outil existant | Ce qu'il ne prouve pas |
|---|---|---|
| Dynamique élémentaire | check_m3_dynamics.py + tests ST existants | Fidélité à une machine non mesurée |
| Chaîne physique du banc | check_simbench_m3_chronology.py | Cycle complet et configuration CODESYS |
| Décisions du séquenceur | check_cycle_ax14_ax18.py et CI cycle | Les tests ciblés actuels ne couvrent pas tout AX18 |
| Régressions métier | TOOLS/TEST_AUTO_CI/scripts/run_tests.py, registry | Un harnais périmé n'est pas un verdict métier |
| Compilation CODESYS | test_codesys_compile.py / compilation manuelle | Pas de PASS sans résultat effectif ; lancement seul insuffisant |
| Liaison et livraison | bundle complet/diff, G200, G390, gates selon lot | Ni comportement temporel ni isolation physique |
| Chronologie mesurée | traces 94/95, trace_to_csv.py | Pas de position physique si voie absente |
| Instrumentation | generate_trace_template.py | Selftest du modèle ≠ génération/livraison d'une nouvelle trace |

Les chemins des scripts de contrôle sont sous TOOLS/AGENT_WORKFLOW/scripts ; ceux de trace sous TOOLS/PLC_CSV_SNAPSHOT. Avant usage, vérifier les options et le périmètre réel. Ne pas lancer toute la CI pour une simple modification documentaire.

## 🚦 Ordre des prochains lots

| Lot | Travail | Livrable et critère de sortie |
|---|---|---|
| A — état de référence | Exploiter 94/95 : unités, étapes, défauts, retrait commande, fréquence, contact frein | Tableau de chronologie chiffré ; données absentes explicitement marquées |
| B — causes prioritaires | Suivre sorties finales → SimBench → capteurs → estimateur → cycle | Arbre avec sources ; distinguer anomalie modèle, automate et instrumentation |
| C — modèle suffisant | Examiner rampe, frein et mouvement ; sensibilité des paramètres incertains | Bornes testées ; conserver la complexité seulement si elle change une décision du cycle |
| D — proposition de correction | Associer chaque modification envisagée à un contre-exemple et à une régression | Plan technique concret soumis avant code ; production hors lot |
| E — validation intégrée | Après correction autorisée, vrais composants et scénarios nominal/défaut pertinents | Avant/après mesuré ; gates, compilation et isolation évalués séparément |
| F — réception utilisateur | Uniquement après amélioration démontrée et bénéfice attendu précis | Essai court, trace complète vérifiée, critères lisibles ; pas de répétition générale |

**Pas de nouvel essai utilisateur à ce stade.** Une instrumentation enrichie seule ne satisfait pas la demande d'amélioration préalable. Les scénarios pente/défaut restent des essais de sensibilité tant que leurs valeurs ne sont pas établies sur le réel.

## 🤝 Délégation ciblée (maximum 3 simultanés)

Trois missions possibles : chaîne logique AX14–AX18 ; physique variateur/frein/chariot ; audit instrumentation et harnais. Ollama DeepSeek/GLM selon inventaire disponible. Pas de lancement massif avant questions discriminantes.

Chaque mission reçoit : préambule projet, sources complètes pertinentes, question, critères de sortie, interdiction d'édition et tableau fait/source/hypothèse/contre-exemple. L'orchestrateur contrôle chaque source citée et chaque calcul. Avis concordants ≠ preuve. Réponse vide ou référence introuvable = résultat inutilisable consigné. Une contre-revue ne se justifie que pour une décision critique ou un désaccord concret.

## 📝 Fiche courte par expérience

`ID | question | version/empreintes | paramètres | attendu + justification | obtenu | statut par critère | preuve | décision | condition de réouverture`

Suivre : critères critiques couverts/total défini, hypothèses ouvertes à impact fort, blocages de harnais et décisions débloquées. Ne pas mélanger nombre d'assertions PASS et couverture du besoin.

## 🧹 Rectifications à conserver

- Le récit réel de référence est le registre MES du 30/10 ; les traces 94/95 sont des simulations.
- La consigne −10 m / arrêt −13 m était hors M3 : la demande de refaire cet essai au titre de M3 est retirée.
- Fréquence électrique nulle et contact fermé ne prouvent pas à eux seuls un chariot physiquement immobile.
- Les succès unitaires et la compilation ne démontrent pas une amélioration visible : l'utilisateur n'en a pas constaté.
- L'absence de voies nécessaires relève de notre instrumentation. Ne pas présenter les essais utilisateur comme non réalisés pour cette raison.
- Les déclarations historiques « production inchangée » concernent le lot simulation ; l'arbre actuel contient des travaux IHM tiers, conservés.

Sources : [témoignage MES](../../REGISTRES/REGISTRE_MES_TEMOIGNAGE_M3_20261030.md), [journal historique](REPRISE_PREUVES_20261030.md), [affiche d'essais](PLAN_TEST_UTILISATEUR_T417_M3_20261030.md). Ce plan ne vaut pas validation du simulateur.

---

## Exécution du plan — CDX01, 31 octobre 2026

Cette section remplace les décisions opérationnelles du tableau initial, conservé comme historique. Contrat : `investigation_20261031` dans [T417](../../CONTRACTS/TASK_CONTRACT_T417_SIMULATION_M3_REALISTE.yaml). Aucun changement ST de production ou simulation, aucun déploiement ni commit effectué par cette session. L'arbre partagé a évolué pendant l'étude (HEAD observé ensuite `8150ef03`) : les empreintes des preuves identifient les entrées effectivement étudiées, pas une version chargée en CODESYS.

### Couverture

| Comportement attendu / scénario | Preuve disponible | Limite | Statut |
|---|---|---|---|
| Manuel vers Trémie puis P1 | 94 : quatre retraits à étape 0, chronologies ci-dessous | Mode absent ; manuel selon provenance seulement ; distance non mesurée | 🟠 |
| AX14 → AX15A après arrêt | 94/95 : fréquence nulle avant étape 15 ; CI R4 historique 1/1 | Ni position vraie ni Busy enregistrés ; CI cycle isolé | 🟠 |
| AX15A → AX15B : geste réarmé | Traces 15→16 ; latch `SeenNeutralAfterArrival` dans le cycle | Geste Y complet/latch absent des traces ; pas d'essai adversarial intégré | 🟠 |
| AX15B ↔ AX15C sans M3 | Code étapes 16/17 et veto PRG05 | Étape 17 absente des deux acquisitions | ⚪ dynamique |
| AX15B → AX18 | Traces 16→18 | `Benne_Done/IsOpen` absents : condition d'achèvement non mesurée | 🟠 |
| AX18 → AX2 → P1 stabilisé | Traces 18→2, contact et fréquence à zéro au retour | Stabilisation mécanique non mesurée ; nouvelle autorisation seulement lue dans le code | 🟠 |
| PV 10/20, conditions identiques | Plateaux avant retraits automatiques 10/20 Hz mesurés | Réglages PV/mode/charge non acquis ; comparaison descriptive uniquement | 🟠 |
| Relâchement / défaut, aucune reprise induite | Retraits et `TranslationState.Error=0` dans 94/95 ; anti-reprise interlock lu | Aucun défaut exercé ; erreur finale/safety non entièrement capturée | ⚪ défaut |
| Pente/frein, aucune dérive artificielle | Suite historique + nouvelle frontière ST R2 | 3 FAIL / 5 : inversion sous seuil statique, dépendance au pas | 🔴 modèle |
| Écart position vraie/estimée au mouvement, arrêt, recalage | Chaîne source identifiée | Deux positions absentes des traces | ⚪ mesure |
| Isolation matérielle | Étude/CI hors ligne, aucun PLC connecté | Écritures sorties PRG06 existent ; configuration cible non qualifiée | ⚪ cible |

### Hypothèses et arbre causal

| Branche / catégorie | Mécanisme et prédiction réfutable | Expérience / décision |
|---|---|---|
| H1 — instrumentation | Nom `ActualFrequencyHz` trompeur : registre centi-Hz ; confondre avec Hz multiplie vitesse par 100 | Chaîne SimBench ×100 → acquisition copie → PRG05 ÷100 vérifiée. Conversion corrigée dans extraction ; aucune distance inventée |
| H2 — intégration | `BrakeCmd` métier ≠ commande finale : PRG06 peut couper le desserrage sur Trémie, PRG05 le coupe hors AX2/14 | 94 contact fermé avant demande métier retirée sur certains arrêts ; commande finale absente. Harnais futur doit lire sortie finale, pas imposer le frein |
| H3 — logique automate, lot distinct | Estimateur intègre seulement si fréquence >0,1 Hz ET demande de sens exclusive ; simulateur mémorise le sens après retrait | Gel possible jusqu'au prochain front capteur. Comparer positions dans vraie boucle ; aucune correction production T417 |
| H4 — modèle, prouvé | Passage par zéro sauté : force opposée sous seuil statique réaccélère dans l'autre sens | ST R2 : −0,006 / +0,006 m/s, et −0,002 avec frottement banc 0,30. Correction D1 proposée |
| H5 — harnais | CI SimBench pilote mot/fréquence/frein ; CI cycle n'appelle pas physique/safety/interlock | Inspecté dans les deux tests. PASS locaux conservés ; boucle complète non couverte. Correction D2 proposée |
| H6 — donnée terrain manquante | Pente, frein relâché ou came peuvent modifier transitions ; traces simulées ne calibrent pas ces paramètres | Aucune cause terrain attribuée. Pente sous/au-dessus adhérence étudiée comme sensibilité, pas calibration |

Entrées/capteurs : géométrie et came restent ouverts ; logique/interlocks : H2/H3 ; machine à états : AX15C non exercée ; paramètres : H6 ; timing : H4 et échantillonnage ; sorties/actionneurs : commande finale absente des acquisitions. Une branche ouverte ne devient pas une cause parce qu'elle est plausible.

### Expériences et décisions

| ID / version | Paramètres et attendu annoncé | Obtenu / preuve | Décision |
|---|---|---|---|
| E31-A — traces originales, SHA256 dans JSON | Lecteur projet ; voies synchrones ; intervalles entre échantillons, aucune interpolation | [CHRONOLOGIE_94_95](CHRONOLOGIE_94_95_20261031.json) : 8 retraits du mot, transitions capteurs/cycle/frein ; résolution ci-dessous | Référence descriptive exploitable ; aucun nouvel essai demandé |
| E31-B — empreintes V1/V2/V3 | Réutiliser seulement sources inchangées | Dynamique 16/16 et SimBench 1/1 inchangés ; SHA du cycle différent, diff lu : commentaire StepMaxTimer seulement | Pas de rejeu inchangé ; PASS cycle reste preuve historique, pas nouvelle exécution |
| E31-C1 — ST réel, paramètres synthétiques | v=±0,004 ; a opposée=0,20 ; friction=0,10 ; statique=0,35 ; dt=100 ms : arrêt sans inversion ; contrôle a=0,60 : inversion possible | [FRONTIERE_ADHERENCE](FRONTIERE_ADHERENCE_20261031.json) : 2 FAIL, 1 PASS | Défaut numérique circonscrit ; aucune causalité MES revendiquée |
| E31-C2 — même code, test étendu | v=0,002 ; a=−0,34 ; friction=0,30 (banc) ; statique=0,35 ; dt=20/100 ms : même verdict d'adhérence | [R2](FRONTIERE_ADHERENCE_R2_20261031.json) : 20 ms PASS, 100 ms FAIL (−0,002 m/s) ; ensemble 2 PASS / 3 FAIL | L'effet ne peut être simplifié : change le signe du mouvement sur la plage testée |
| E31-R — Ollama, lecture seule | Contre-exemple indépendant sur sources complètes | DeepSeek : réponse vide ; [GLM](AVIS_ADHERENCE_GLM_20261031.md) : calcul initial concordant | Avis contrôlé, pas preuve d'exécution ; formule de condition générale et borne de précision non retenues |

Les deux expériences C sont discriminantes (symétrie puis sensibilité au pas/frottement) ; aucun troisième essai sans modification utile. Aucun changement des attentes historiques pour masquer le rouge. Scratchs CI conservés aux chemins déclarés dans les JSON.

## Lot A — chronologie consolidée

Source directe : lecteur `TOOLS/PLC_CSV_SNAPSHOT/external_python/trace_to_csv.py`, utilisé par `check_t417_trace_evidence.py`. Les 30 voies ont des timestamps identiques dans chaque trace. 94 : pas **99–116 ms**, médiane **105 ms** ; 95 : **96–146 ms**, médiane **105 ms**. L'événement se situe dans **(échantillon précédent ; échantillon courant]** ; même échantillon ne prouve aucun ordre intra-scan.

`Data.M3.ActualFrequencyHz / 100` donne les Hz (`PRG_05_Translation.st:637`, producteur `FB_SimBench.st:752`). La fréquence finale commandée est déjà en Hz. Le nom du fichier 95 et le récit renseignent l'essai annoncé à 10 Hz ; aucune voie de réglage ne prouve que seul PV a changé. Les quatre arrêts étape 0 de 94 sont les candidats manuels selon provenance, sans identification du mode par acquisition.

Temps ci-dessous : première observation en secondes ; délais en millisecondes depuis premier mot nul. **Toutes les distances : non mesurées.** Frein demandé = `TranslationFinalInterlockRequest.BrakeReleaseRequest`, pas sortie finale.

| Trace / étape | Mot nul (s) | Hz juste avant | Δ fréquence nulle | Δ contact fermé | Δ frein demandé coupé | Δ BrakeCmd interne coupé |
|---|---:|---:|---:|---:|---:|---:|
| 94 / 0, Trémie | 49,786 | 5 | 419 | 104 | 1 043 | 1 043 |
| 94 / 0, retour | 63,475 | 20 | 1 146 | 1 146 | 1 146 | 1 146 |
| 94 / 0, Trémie | 83,643 | 20 | 1 056 | 211 | 1 056 | 1 056 |
| 94 / 0, retour | 95,117 | 20 | 1 144 | 1 249 | 1 144 | 1 144 |
| 94 / AX14 | 186,793 | 20 | 1 049 | 1 672 | 1 568 | 1 986 |
| 94 / AX2 | 204,447 | 20 | 1 041 | 1 985 | 1 877 | 1 877 |
| 95 / AX14 | 78,429 | 10 | 735 | 1 356 | 1 253 | 1 980 |
| 95 / AX2 | 97,581 | 10 | 731 | 2 089 | 1 982 | 1 982 |

Bornes conservatrices retrait→fréquence nulle : AX14/94 **944–1 154 ms**, AX14/95 **629–841 ms** ; AX2/94 **935–1 145 ms**, AX2/95 **627–838 ms**. Les autres intervalles et toutes les transitions sont dans le JSON. Aucun défaut `TranslationState.Error` (toujours 0) ; ne pas extrapoler à tous les défauts automate.

| Événement | 94 (s) | 95 (s) |
|---|---:|---:|
| Arrivée Trémie DI observée autour de l'arrêt AX14 | 186,898 | 78,429 |
| Fréquence nulle | 187,842 | 79,164 |
| AX15A et retrait demande frein | 188,361 | 79,682 |
| Contact frein fermé | 188,465 | 79,785 |
| AX15B | 188,779 | 83,231 |
| AX18 | 193,059 | 87,416 |
| AX2 retour | 196,401 | 88,978 |
| Front descendant P1 autour du retour | 204,343 | 97,581 |

Dans 94, retrait ReqStart/mot nul observé un échantillon avant le DI Trémie affiché ; cela interdit de déduire une causalité intra-scan depuis ces seuls échantillons. Dans 95 le DI Trémie se perd à 78,636 puis revient à 79,164 ; P1 présente également des rebasculements. Cause came/bruit/configuration non prouvée par ces deux seules voies. Aucune étape AX15C (17), aucun AX15D.

**Acquis A :** événements, unités et incertitudes. **Échec :** ancienne attribution 49,786 s à AX14 erronée. **Incertitude :** distances et paramètres identiques. **Décision :** aucune nouvelle campagne générale ; dossier corrigé, observations MES séparées.

## Lot B — chaîne effective et maintien des données

Période de référence : MainTask **10 ms**, selon AF02 §ordonnancement ; EtherCAT 4 ms et CANopen 20 ms sont des cadences distinctes. Pas de preuve du scheduling réel de la cible depuis ces traces (~105 ms). PRG02 précède PRG03/05/06 : la physique consomme les sorties du **scan précédent**.

| Producteur → consommateur | Donnée / unité | Maintien, remise à zéro, limite |
|---|---|---|
| Joystick acquis + FB_CycleSemiAuto → PRG03 → arbitrage PRG05 | ReqStart, cible, gestes BOOL/enum | AX14 retire ReqStart sur Trémie ; AX15A neutre puis push ; AX15B/C et AX18 demandent M3=0 |
| `instArbM3` → sécurité/FB_Translation | ReqTremie/Maintenance, RunRequest BOOL, vitesse % | PRG05:395–409 annule hors AX2/AX14 en semi-auto ; manuel suit arbitrage et verrou arrivée du FB |
| Safety + FB_Translation → requête interlock | permis, arrêt, desserrage BOOL ; mot WORD ; Hz REAL | Safety lit frein du scan précédent (PRG05:480) ; publication finale impose zéro hors AX2/14 (:713–721) |
| Requête PRG05 + DI Trémie → PRG06 interlock | mot/fréquence/frein finaux | PRG06:430–453 coupe côté Trémie si ReqTremieSemantic ; interlock timeout mémorisé, Reset sur front puis neutre et nouvelle demande |
| PRG06 → PRG02 → SimBench | mot 1/2 → sens ; PDO centi-Hz → % ; frein BOOL | PRG02:318–324 lit sorties effectives N−1 ; pas commande métier brute |
| SimBench → Sim_Translation → Drive/Brake | %→Hz ; sens mémorisé ; délais s | Rampe et PT1 conservés après retrait ; sens purgé ≤0,5 Hz ; Enable faux réinitialise position à P1 et ferme frein |
| Sim_Translation → capteurs → SimBench → HwIn | position vraie m → mot cumulatif/DI, contact, fréquence ×100 | capteurs hystérésis/came ; override explicite possible ; sélection `SimulationModeActive AND SimTranslationActive` en PRG02 |
| HwIn → décodeur/estimateur PRG05 → cycle PRG03 | DI/Hz → position estimée m, Busy BOOL | estimation maintenue hors Enable, recalée sur fronts puis intégrée sous demande ; Busy fondé sur Hz>0,5 (:885) ; cycle reçoit état PRG05 précédent |

**Différence explicite manuel/auto :** la barrière Trémie PRG06 dépend de la demande de sens sémantique, tandis qu'AX14 peut déjà l'avoir retirée sur arrivée. Le frein interne peut donc rester demandé mais être coupé en sortie en manuel ; en auto la barrière d'étape agit ensuite. Mécanisme source vérifié, sans identification certaine de la version chargée lors des traces.

**Acquis B :** chemins et barrières retrouvés. **Échec de couverture :** harnais séparés. **Incertitude :** timing chargé et sortie frein finale absente. **Décision :** vrai assemblage D2 ; estimateur consigné comme lot production séparé.

## Lot C — physique minimale et paramètres

| Élément | Valeurs effectivement lues / provenance | Limite et décision |
|---|---|---|
| Variateur | Appel parent : accélération 20 Hz/s, décélération 25 Hz/s, PT1 0,15 s | Paramètres de modèle documentés, pas calibration par 94/95 ; défaut enfant 20 Hz/s/0,03 s ne décrit pas cet appel |
| Chariot | Gain transmis depuis gain actif automate ; géométrie persistante transmise | Position vraie intégrée séparément ; ni copie ni recalage sur position estimée. Gain commun provisoire ≠ validation terrain |
| Frein | Ouverture 0,10 s, fermeture 0,09 s, contact 0,01 s ; frein physique actif, décélération 2 m/s² hypothétique | Contrat ancien AC2 dit 0,20 s : divergence à résoudre par preuve, aucun changement de valeur ici. Frein fermé bloque statiquement toute pente dans ce modèle |
| Capteurs | Hystérésis 0,02 m ; came active, début 0,02 m/largeur 0,04 m ; bruit 0,01 m | Géométrie hypothétique ; ne pas supprimer came/bruit sans tester les transitions aux limites |
| Pente/frottements | Banc : pente 0, roulement 0,30 ; seuil statique parent 0,35 m/s² | Sensibilités ST ponctuelles a=±0,20, −0,34, −0,60 ; dt=20/100 ms ; pas une validation de plage continue |
| Charge suspendue | Ratio 0,5 ; longueur 1,5 m, amortissement 0,35 ; hypothèses | Force pendulaire peut franchir seuil statique ; aucun allègement justifié sur cycle complet |

**Contre-exemple calculé et exécuté :** v₀=+0,004 ; a=−0,20 ; roulement=0,10 ; statique=0,35 ; dt=0,10. Modèle : `FreeVelocity=−0,016`, puis frottement → **−0,006 m/s**. Sous accélération opposée totale 0,30, arrêt attendu à 13,33 ms ; ensuite |a|<0,35 impose adhérence. Le modèle saute cet arrêt intermédiaire. Avec roulement banc 0,30, v₀=0,002, a=−0,34 : à 100 ms résultat **−0,002**, à 20 ms **0**. Ce défaut concerne la dérive libre après arrêt, pas automatiquement le dépassement pendant rampe.

La proposition GLM retrouve le premier calcul. Son « définitivement inaccessible » n'est valable que sous force constante et hors butées ; sa condition d'inversion avec +0,001 et sa formule optionnelle de temps d'arrêt omettant le frottement ne sont pas retenues. Les assertions ST sont la preuve.

**Acquis C :** défaut à la frontière statique identifié et sensibilité au pas démontrée. **Échec :** pas de modèle qualifié sur cette plage. **Incertitude :** impact sur scénarios nominaux à pente zéro/charge réelle. **Décision :** conserver la complexité actuelle, corriger D1 avant toute conclusion de fidélité globale.

## Lot D — proposition technique concrète à valider

> Suite du 31 octobre : l'utilisateur demande explicitement la poursuite autonome du plan. D1 est implémenté dans `FB_Sim_Translation` ; aucun code automate de production modifié. Garde frontière : 5/5 PASS dans [preuve corrigée](FRONTIERE_ADHERENCE_CORRIGE_20261031.json) ; suite dynamique 16/16 PASS dans [preuve dynamique](DYNAMIQUE_D1_20261031.json). La revue indépendante confirme une approximation de position intra-scan : exemple 0,027 mm avant arrêt à dt=100 ms non intégré par le schéma de vitesse finale. L'impact sur les frontières capteurs reste à vérifier dans D2. D2 et réception restent ouverts.

> SimBench ciblé : 1/1 PASS ([preuve](SIMBENCH_D1_20261031.json)). Bundle complet et diff FB_Sim_Translation générés. G200 : PASS, 0 erreur, 1723 avertissements, 2171 instances. Palier C lancé : G300 FAIL (dossiers `.tmp` et `prototypes`), G340 FAIL (143 liens ou références documentaires), G430 FAIL (227 commentaires) ; autres résultats en cours. Aucun nettoyage automatique. La boucle D2 complète reste à construire : les harnais existants simplifient arbitrage ou omettent safety/interlock.

### D1 — adhérence lors du passage par zéro (simulateur exclusivement)

- **Défaut / contre-exemple :** E31-C1/C2 ci-dessus ; branche libre de `CODE/L_SIMULATION/FB_Sim_Translation.st:303–328` ; aucun changement des commandes automate nécessaire.
- **Correctif minimal proposé :** après intégration de la force externe dans la branche mobile, détecter le changement de signe par rapport à la vitesse initiale. Si |force externe| ≤ seuil statique, imposer v=0 ; sinon conserver la possibilité d'inversion et la dissipation bornée. Aucune interface, aucun paramètre par défaut ajouté/modifié. La branche statique existante reprend le maintien au scan suivant.
- **Précision conservée :** intégration discrète de position existante, sans prétendre résoudre exactement le déplacement à l'intérieur du pas. Toute influence sur le verdict capteur devra être mesurée dans D2 ; pas de tolérance arbitraire pour blanchir un écart.
- **Guard déjà livré et rouge :** `check_t417_model_boundary.py` + `test_fb_sim_translation_t417_boundary.st` compilent le ST réel. Cible : 5/5 puis couverture 10/20/100 ms, deux sens, force nulle/au seuil/supérieure, absence de redémarrage aux scans suivants.
- **Test historique à rectifier explicitement :** M3-DYN-060 appelle −0,20 « suffisante » alors que seuil statique=0,35. Conserver ce cas comme régression d'adhérence ; exercer l'inversion légitime avec −0,60. Ne pas modifier cette attente avant accord sur le correctif.
- **Effet utilisateur attendu :** éliminer une dérive numérique sous force sous-critique ; aucune promesse que cela résout les dépassements rapportés ou les défauts frein terrain.

### D2 — fermer la boucle de preuve, sans compenser la production

- **Défaut de harnais prouvé :** `test_fb_simbench_m3_dynamics.st` impose `M3_BrakeCmd`, tandis que `test_fb_cyclesemiauto_t417_m3.st` teste le cycle seul. Leur réunion documentaire ne vaut pas exécution intégrée.
- **Modification proposée :** ajouter un harnais de test sous `TOOLS/TEST_AUTO_CI/MOCKS/` et tests sous `RESULTS/L_SIMULATION/tests/`, runner de preuve sous `TOOLS/AGENT_WORKFLOW/scripts/`. Utiliser les vrais blocs cycle, arbitrage M3, safety, translation, interlock, SimBench, décodeur et estimateur. Vérifier le raccordement aux expressions PRG02/05/06, y compris la barrière Trémie et la barrière d'étape ; toute reproduction d'une expression de PRG doit porter sa source et un garde de divergence.
- **Ordre :** sorties N−1 → physique/acquisition → cycle sur état N−1 → arbitrage/safety/translation/estimation → sorties N ; pas d'accès aux internes pour forcer un passage d'étape. Entrées opérateur, états treuil/benne et réseau pilotés seront déclarés comme substituts, donc non couverts comme procédés réels.
- **Scénarios :** AX14→15A, neutre puis push, 15B↔15C, 15B→18→2→P1 ; manuel de référence ; variantes PV 10/20 avec copie identique de tous les autres paramètres ; défaut/relâchement et reprise consciente. Mesurer aussi absence de commande M3 pendant 15A/B/C.
- **Observables existants :** `SimM3ObsPositionTrue_M`, `SimM3ObsPositionError_M`, `SimM3ObsCartFree`, retour fréquence, demande/frein final/contact, étape et capteurs. Aucun nouvel interface de production prévu. Une future trace utilisateur inclura mode et réglage PV ; importabilité et chemins devront être vérifiés avant livraison.
- **Tolérances à figer avant exécution :** temps par scans du banc et intervalles d'acquisition ; frontières de position issues des cotes/hystérésis/came configurées. Séparer franchissement capteur, arrêt vitesse, zéro fréquence et contact fermé. Un zéro fréquence n'est pas un critère suffisant d'immobilité.

### Point d'arrêt et réception

**Validation demandée : D1 puis D2**, sans modification de production. Le plan utilisateur exige cette validation avant modification du code (lot D) ; la skill troubleshooting dit aussi « Ne jamais modifier le code ni forcer une variable sans validation humaine explicite ». Les tests d'étude autorisés ont été exécutés ; le correctif simulateur reste une proposition.

Lot E après accord : nouvelle preuve ST avant/après → SimBench → intégration → compilation/exécution CODESYS sur cible isolée → bundle complet et diff + G200/G390/gates appropriés. Aucun de ces verdicts n'est acquis par les présents résultats. Pas de génération de bundle pour ce lot d'étude sans modification PLC. Réception utilisateur différée jusqu'à amélioration démontrée, avec parcours court et résultat attendu précis.

### Vérification de la livraison d'étude

- Contrat : `check_task_contract.py` **PASS**, 0 erreur/avertissement ; ce contrôle ne valide pas la physique.
- Extraction recalculée depuis les deux XML : identique au JSON livré ; assertions échelle 10/20 Hz et délais 1 049/735 ms PASS ; calcul des intervalles et refus de timestamps dupliqués vérifiés.
- Syntaxe des deux outils Python et existence des liens locaux vérifiées ; empreintes de toutes les sources de R2 identiques aux fichiers relus en fin d'étude.
- `git diff --check` sur les documents édités : PASS. Rapports tiers WINCH_INTEG et index CI déjà modifiés laissés intacts. Aucun nettoyage, aucune connexion automate.
- **Verdict fonctionnel conservé rouge : 3/5 FAIL** dans le nouveau test de frontière ; aucun bandeau « bundle validé » ni réception du banc.

Commandes reproductibles (choisir un nouveau nom de preuve : aucun écrasement autorisé) :

```powershell
py -3.13 TOOLS/AGENT_WORKFLOW/scripts/check_t417_trace_evidence.py --output DOC/WFLOW/ETUDES/ANALYSES_T417/CHRONOLOGIE_94_95_REJEU.json
py -3.13 TOOLS/AGENT_WORKFLOW/scripts/check_t417_model_boundary.py --output DOC/WFLOW/ETUDES/ANALYSES_T417/FRONTIERE_ADHERENCE_REJEU.json
```

## Journal d'execution — 2026-11-01 (apres GO utilisateur)

| Lot | Acquis | Limite / suite |
|---|---|---|
| A | Chronologies 94/95 et limites d'echantillonnage deja extraites dans ce dossier. | Distances, AX15C et mode/PV des traces restent non mesurables depuis les voies disponibles. Aucun nouvel essai utilisateur demande. |
| B | Le veto d'etape M3 est visible dans `PRG_05_Translation`; les essais unitaires cycle et SimBench restent separes. | Pas de harnais prouvant la boucle cycle → arbitrage → safety → translation → interlock → SimBench. |
| C / D1 | Correctif d'adherence D1 present dans `FB_Sim_Translation`. Rejeux du 01/11 : FRONTIERE 8/8, DYNAMIQUE 16/16, SimBench 1/1 PASS. Sources et empreintes dans les trois JSON `*_REJEU_20261101.json` / `SIMBENCH_M3_REJEU_20261101.json`. | Le modele reste hypothesique hors plages testees. Le cas `v_p=0` exact peut retarder l'inversion d'un scan; ce n'est pas une derive persistante. La position reste integree par vitesse de fin de pas. |
| D2 | Harnais compose construit avec FB_CycleSemiAuto, arbitre M3, safety, translation, interlock final, decodeur/estimateur et SimBench. Compiler/executer dans STruCpp : 0/1 PASS (R12). AX14→Tremie, AX15A/B/C→AX18 et demandes de sens atteints dans l'essai. Les mouvements M1/M2 et faits benne restent pilotés par entrées de banc ; départ AX14 forcé publiquement. | Retour AX18→AX2 atteint. À 10,5 s du retour, capteurs `00111` (P2) ; à 15 s, capteurs Maintenance `00001` malgré jeton P1 déjà observé et mot de commande final nul. L'arrêt stabilisé P1 n'est donc pas validé. Cause encore ouverte : horizon de maintien du geste, franchissement/arrêt, dérive après arrêt ou ordre de scan du harnais. Pas de réglage arbitraire de nombre de scans retenu. |
| E / réception CODESYS | Aucune exécution CODESYS et aucun essai machine. | Pas de parcours utilisateur demandé : le critère d'arrêt P1 échoue dans le harnais composé. Distinguer d'abord le stop dynamique du maintien prolongé du joystick, avec trace des positions vraie/estimée, fréquence et mot capteurs à l'instant du passage P1 puis après relâchement. |

Les scratchs des trois rejeux sont conserves sous `TOOLS/TEST_AUTO_CI/.scratch/` conformement aux regles de conservation. Aucun code automate de production n'a ete modifie et aucun essai sur machine reelle n'a ete lance. Le verdict historique R2 (3/5 FAIL) reste archive; il est supplante pour la frontiere par R3 puis par le rejeu 8/8, sans effacer les anciennes preuves.

**Complément D2 — 2026-11-01 :** preuve intégrée `INTEGRATION_M3_CYCLE_REJEU_R12_20261101.json` (compilation réussie, échec fonctionnel). L'assertion P1 seule est insuffisante : le jeton stable a été observé puis le mot brut ne correspondait plus à P1. R12 à 10,5 s donne `00111` (P2), R9 à 15 s donne `00001` (Maintenance). Résultats intermédiaires R4–R11 conservés ; ils servent au diagnostic du harnais et ne valent pas preuves positives. Le runner déroule ses boucles de test car le parseur ne permet pas `ADVANCE_TIME` dans `FOR`. Les données de fin de phase ne permettent pas encore de séparer dépassement pendant rampe, dérive après arrêt et ordre de scan. Décision : investigation d'arrêt ciblée avant toute demande de réception CODESYS.

**Complément D2 — mesure R19/R21 et décision :** le parcours E2E atteint AX14 → Tremie → AX15A/B/C → AX18 → AX2 → jeton P1. En R19, la position physique après 5 s de commande neutre vaut `5,27417 m`; le test la compare à `5,00 ± 0,04 m`. En R21, la métrique existante donne un dépassement de `0,274671 m` depuis le front capteur P1 (ID 3). Le seuil de `0,04 m` est exploratoire, déduit de l'hystérésis et pas encore une exigence d'arrêt validée : R19/R21 quantifient une surcourse, mais ne prononcent pas un échec fonctionnel du modèle. À la fin des 5 s, commande finale nulle, fréquence ≤ `0,5 Hz`, contact frein fermé et chariot non libre : le repos final est observé, la cause et l'acceptabilité de la distance restent ouvertes.

Calculs d'ordre de grandeur pour 20 Hz et gain `0,02 m/(Hz·s)` : `v0=0,40 m/s`; rampe seule à `25 Hz/s` donne environ `0,16 m`; frein à `2 m/s²` donne `0,04 m`; délai de fermeture `0,09 s` puis frein donne environ `0,076 m` si la vitesse reste constante pendant le délai. Ces calculs idéalisés ne couvrent pas les couplages du modèle. L'avis GLM qui attribue le résiduel à la pente est une hypothèse : le test injecte bien `−0,2 m/s²` (défaut global `0 m/s²`), mais la force de pente n'agit que dans la branche de chariot libre. Sans trace scan par scan des états frein/couple/vitesse, sa contribution à cette surcourse n'est pas établie.

| Expérience | Résultat | Ce que cela démontre | Limite / suite |
|---|---|---|---|
| R19 — E2E, arrêt final | 🔴 position `5,27417 m` après 5 s ; critères électriques/mécaniques finaux satisfaits | Cycle composé exécuté, arrivée P1 non stabilisée dans la bande | Pas de chronologie pendant l'arrêt |
| R21 — même E2E, seuil exploratoire | 🟠 dépassement capteur P1 `0,274671 m` | Surcourse P1 mesurée par l'observable SimBench | `0,04 m` n'est pas une tolérance d'acceptation établie; ne distingue pas rampe, frein et forces externes |
| Revues DeepSeek/GLM | 🟠 calculs idéalisés cohérents ; causes proposées divergentes/non prouvées | Revue secondaire et calculs seulement | Les avis de modèles ne remplacent pas la trace ST |

**Décision Lot D :** ne pas modifier les équations ni les réglages pour satisfaire le seuil exploratoire. Une instrumentation supplémentaire de production n'est pas nécessaire pour le premier diagnostic : `FB_Sim_Translation` publie déjà `PositionTrue_M`, `VelocityTrue_Mps`, `ActualFrequency_Hz`, `ElectricalFrequency_Hz`, `BrakeCoilEnergized`, `BrakeMechanicallyOpen`, `BrakeContactOpen`, `PosP1` et les observables de chariot libre; `FB_SimBench` publie ses commandes et la position vraie. Dans CODESYS, le chemin source est `PRG_02_Acquisition.instSimBench.instSimTranslation.<sortie>` (l'instance est déclarée dans `PRG_02_Acquisition` et appelée dans `FB_SimBench`). Enregistrer ces signaux à 10 ms, avec environ 1 s avant et 2 s après le front P1, ainsi que `M3ObsPositionError_M`, `M3ObsOvershootLast_M`, le mot capteurs et l'étape AX2. Comparer la demande, la commande finale après interlock, le frein et la vitesse. La trace déterminera le déplacement d'arrêt et si la phase de chariot libre intervient; les tolérances de passage seront ensuite fixées à partir de la géométrie et des conditions du cycle. Les tests ciblés D1 sont démontrés (frontière 8/8, dynamique 16/16, SimBench 1/1); la trace CODESYS peut maintenant vérifier leur intégration, sans essai machine réelle.

### Reprise CODESYS — comparaison sans import

Le runner Headless a été corrigé pour l'encodage UTF-8 des chemins, l'import XML à deux arguments et la reconstruction de l'application active. Il conserve désormais son scratch; trois tests ciblés du runner passent. Le rejeu avec import (`.tmp/codesys_compile_FB_Sim_Translation_b1470xgd`) et le rejeu de référence sans import (`.tmp/codesys_compile_FB_Sim_Translation_lv6_f_mu`) produisent chacun **une erreur CODESYS identique** : `Object reference not set to an instance of an object.` Cette erreur précède donc l'import du FB dans la copie et ne valide ni n'invalide D1. L'import annoncé par l'API ne prouve pas encore que la bonne version de l'objet est compilée; vérifier l'objet effectivement importé avant tout verdict positif. La compilation CODESYS reste non validée.

**Correction de périmètre utilisateur :** Control Win est exclu. Il ne représente pas suffisamment le PLC cible et ne peut pas servir de validation CODESYS demandée. La cible retenue est la **Simulation IDE CODESYS** sur une copie isolée du projet; aucune connexion à la machine réelle.

**Rejeu Simulation IDE — 2026-10-31 :** `test_codesys_compile.py FB_Sim_Translation --simulation` a ouvert la copie `v0.7.38_SimBench_AprèstUpdateMsg_20261031.project`, importé le PLCopenXML généré depuis le ST courant et confirmé `Device.get_simulation_mode() = TRUE`. La reconstruction retourne néanmoins une erreur CODESYS : `Object reference not set to an instance of an object.` (1 erreur, 0 avertissement), comme le témoin sans import. Preuve conservée sous `TOOLS/AGENT_WORKFLOW/.tmp/codesys_compile_FB_Sim_Translation__euwqeyf/`. L'import et le réglage de mode sont donc confirmés par le script; compilation valide, connexion en ligne et exécution cyclique restent non démontrées. Ce résultat classe l'échec dans le harnais/IDE jusqu'à identification de la cause; il ne juge pas la physique D1.

**Rejeu caché avec diagnostic — 2026-10-31 :** selon la consigne utilisateur, CODESYS a été lancé en tâche de fond avec `--noUI` et le parent Python en fenêtre cachée, sur une nouvelle copie. Détection directe de l'installation `CODESYS 3.5.19.10` ajoutée au runner (elle évite le parcours récursif de `Program Files`). Le PLCopenXML s'importe et le mode Simulation IDE est confirmé. Le message de reconstruction n'a ni objet ni projet associé, aucune position source ni numéro, et aucune information de détail (`object=None`, `project=None`, `position_text=None`, `number=None`, `has_details_handler=False`); texte unique : `Object reference not set to an instance of an object.` Témoin antérieur sans import : même texte. Traces complètes sous `TOOLS/AGENT_WORKFLOW/.tmp/codesys_compile_FB_Sim_Translation_321wps4i/` et `t417_codesys_bg_20261031_171751.out/.err`. Le diagnostic réduit la cause à la chaîne CODESYS/headless ou au projet de base, mais ne la distingue pas; aucune compilation ni exécution cyclique n'est prouvée.

**Localisation de l'erreur — 2026-10-31 :** `app.generate_code()`, `app.build()` et `app.rebuild()` produisent le même message sur le projet actuel sans import; `app.generate_code()` reproduit aussi le message sur la sauvegarde précédente `v0.7.37`, sans import. Le FB M3 n'est donc pas la cause immédiate observée. `app.is_active_application=True`; Simulation IDE est confirmée. L'objet Device lu par le script s'identifie comme `DeviceID(type=4097, Id='0000 000a', Version='3.5.19.10')` et existe dans le Device Repository; son nom reste générique dans le projet. Les messages CODESYS ne donnent toujours ni cause source ni pile exploitable. Le runner ne contacte aucune cible, n'utilise pas Control Win et ne lance aucun mouvement. Prochaine investigation : établir à partir du projet et du Device Repository la description exacte du Device/du générateur installé, puis vérifier cette chaîne headless avec le même artefact; ne pas substituer un autre runtime.

**Prochaine décision :** poursuivre avec le runtime **Simulation IDE** seulement, en diagnostiquant d'abord l'erreur de reconstruction sur copie. Après compilation réussie, exécuter une trace courte des sorties publiques `FB_Sim_Translation` autour du front P1 (10 ms, environ 1 s avant et 2 s après), sans écrire de variable de mouvement avant vérification du mode simulation et des deux verrous du POC T402. Les composants de cycle et la séquence d'écriture ne seront pas remplacés par Control Win. Aucun essai utilisateur ni essai machine réelle à ce stade.


**Compilation du bundle complet en Simulation IDE ? 2026-10-31 :** le bundle `CODE_XML/CODE_Bundle.xml` (82 d?finitions POU PLCopenXML, horodat? 17:30:39; source ST la plus r?cente alors horodat?e 17:29:48) a ?t? import? dans un projet CODESYS neuf bas? sur le Device Repository `DeviceID(type=4097, Id='0000 000a', Version='3.5.19.10')`. CODESYS a ?t? lanc? cach? avec `--noUI`; `get_simulation_mode()=True`, application active. `generate_code()` termine avec ? Build complete -- 0 errors, 0 warnings -- Ready for download ? (code g?n?r? 17 998 octets). Preuve conserv?e sous `TOOLS/AGENT_WORKFLOW/.tmp/t417_full_bundle_sim_61fd8587/` (`runner.py`, `result.log`, projet). Aucun fichier `CODE/` n?a ?t? modifi?. Ce r?sultat prouve l?import et la g?n?ration de code sur le Device Simulation IDE pour le bundle; il ne prouve pas l?ex?cution du cycle : le bundle ne contient ni configuration de t?che ni appels cycliques. L?application sauvegard?e v0.7.38 reste en ?chec de g?n?ration avec l?erreur .NET g?n?rique document?e ci-dessus. Le projet neuf est un banc isol? compilant les sources versionn?es, pas une copie de ce projet sauvegard?.

**D?cision suivante :** ne pas pr?senter la g?n?ration de code du bundle comme un test d?utilisation du cycle. Avant d?engager une connexion au runtime Sim IDE et de d?marrer un programme cyclique, ?tablir dans un projet temporaire une t?che et un POU d?essai valides, puis v?rifier la cible online explicitement. Aucune variable de mouvement ne sera forc?e; si la cible ne peut pas ?tre identifi?e comme Simulation IDE, arr?ter le test.


### Sonde compilation sans injection - 2026-11-01

- Copie v0738, aucune injection, aucun login : erreur identique. Message natif sans objet, projet, numero ou localisation ; `has_details_handler=False`. Preuve : `TOOLS/AGENT_WORKFLOW/.tmp/t417_build_probe_20261101/result.log`.
- Garde du runner prepare dans `runtime_checked.py` : toute erreur de build provoque un arret AVANT login. Le runner historique conserve sa preuve et n'est plus le candidat pour les prochains essais.
- Experience suivante : Simulation IDE explicite, nettoyage via API si disponible, puis rebuild sans injection. Permet de tester l'hypothese du cache de compilation sans changer les sources.


### Diagnostic compilation - variantes du 2026-11-01

Preuves sous `TOOLS/AGENT_WORKFLOW/.tmp/t417_build_probe_20261101/`. Sans login ni sauvegarde : clean/rebuild (`clean_result.log`), exclusion visualisation (`visu_result.log`), retrait taches Visu/Trend (`visu_tasks_result.log`), retrait traces (`traces_result.log`), retrait objet anonyme (`unnamed_result.log`), puis combinaison diagnostics/IHM/symboles (`dependencies_result.log`) : meme erreur generique. Ces exclusions ne prouvent pas la cause.

Le temoin syntaxique volontaire en RAM (`compiler_witness_result.log`) ne produit pas de diagnostic ST ; seul le message generique apparait. Les appels metier sont presents dans MainTask 10 ms : PRG_02, 03, 04, 05, 06, 07, dans cet ordre (`tasks_result.log`). Les taches 4 ms/20 ms inspectees n'ont pas d'appel POU. Les references de bibliotheques sont inventoriees dans `dependencies_result.log`. Aucun mouvement relance.


### Deblocage compilation - bureau Windows isole, 2026-11-01

**Resultat discriminant :** meme copie v0738, Simulation IDE, clean + rebuild, sans injection, sans login : `Compile complete -- 0 errors, 1 warnings`; controle supplementaire 0 erreur. Le processus termine avec code 0. Avertissement : aucune POU dans la tache CAN. Preuve : `TOOLS/AGENT_WORKFLOW/.tmp/t417_build_probe_20261101/private_ui_result.log`.

La variante fonctionnelle execute CODESYS avec interface sur un bureau Windows prive, sans `--noUI`; aucune fenetre sur le bureau utilisateur. La variante `--noUI` du meme protocole echoue. Le mode headless est donc implique dans le blocage observe; le composant interne exact reste inconnu. Lanceur `launch_private.py` avec maintien du handle du bureau jusqu'a la fin du processus.

Decision : reprendre les tests dynamiques avec ce lancement invisible, le runner bloquant en cas d'erreur de compilation, et nouvelles traces distinctes. La compilation sans injection seule ne valide pas encore les sources modifiees ni le cycle.


### Rejeu CODESYS R8 - 2026-11-01 : build reussi et mouvements mesures

Preuves durables : `CODESYS_R8_20261101/RESULTAT.json`, runner, journal et CSV. FB_Sim_Translation courant injecte et empreinte enregistree; rebuild 0 erreur AVANT login, programme charge puis RUN, Simulation IDE confirmee. Lanceur sur bureau Windows prive.

| Manuel | Aller Tremie | Retour P1 | Position finale retour | Depassement interne aller / retour |
|---|---:|---:|---:|---:|
| 10 Hz | 26,456 s | 26,570 s | 5,000095 m | 24,4 / 68,7 mm |
| 20 Hz | 14,154 s | 14,178 s | 5,152191 m | 122,7 / 220,1 mm |

Les quatre trajets atteignent la cible du harnais et finissent avec frequence nulle, contact frein applique et position identique pendant 20 lectures. Les delais de fin (~4,7 a 5,4 s) INCLUENT cette fenetre de stabilite : ils ne sont pas le temps mecanique de freinage. Lectures online sequentielles, non atomiques, cadence reelle disponible dans RESULTAT.json. Le depassement interne est une sortie du modele, distincte de position finale moins P1 nominal.

Conditions : homing force selon T423, bypass dedie MinHeight actif dans la copie, restore FALSE en fin; aucun mouvement treuil teste. Cleanup master simulation FALSE et unforce confirmes. Le critere d'arret stable est observe; le retour 20 Hz finit 152 mm au-dela de P1 nominal, hors bande de detection du harnais +/-25 mm. Aucune validation globale du cycle ou de fidelite physique. Decision : poursuivre la recherche causale avec ces preuves identifiees, puis scenario automatique AX14-AX18 et retour; aucun nouvel essai utilisateur demande.


### Analyse arret R8 - chronologie exploitable

`CODESYS_R8_20261101/ANALYSE_ARRET.json` separe derniere lecture en mouvement, premiere lecture frequence nulle + frein applique, et fin de stabilisation. Intervalle median des lectures par trajet : 209 ms. Apres derniere lecture MOVE : deplacement aller/retour 10 Hz = 26,3/21,7 mm ; 20 Hz = 30,0/163,0 mm. Premiere lecture zero+frein apres cette lecture : 0,806/0,625 s puis 1,047/1,223 s. Ces delais incluent la latence des lectures sequentielles et de la commande Python; ce ne sont pas des mesures scan par scan. Ils invalident l'interpretation des ~5 s comme temps mecanique d'arret. A 20 Hz retour, l'essentiel de l'ecart final survient apres la derniere lecture MOVE, mais la part latence/rampe/mecanique reste a isoler.

Le processus IDE R8 ne sortait pas car le runner historique ne termine pas par system.exit(); application STOP et logout confirmes, instance isolee arretee par PID 50692. Ajouter system.exit() aux prochains runners, sans modifier les preuves R8.


### Automatique R9-R11 : preparation datum insuffisante

R9 : build 0 erreur, SEMI_AUTO refuse. R10 : homing force partiellement applique (etape interne encore BOTH_NOT_HOMED). R11 : forcage groupe lu VALID/TRUE, mais instModes.MachineHomed=FALSE et motif `SEMI_AUTO refuse : datum machine absent`; ModeChangeAllowed=TRUE, contacteurs relaches, freins fermes, vitesses nulles. Preuves durables : `CODESYS_AUTO_R11_20261101/`. Aucune AX14 executee.

Cause de refus prouvee au consommateur : datum absent. Les forcages de snapshot T423 ne prouvent pas que les consommateurs intermediaires voient le datum; les ecritures du programme dans le scan restent a examiner. Classer harnais/preparation homing, pas echec M3. Decision : utiliser le protocole de referencement simule via CycleMachineHoming.Cmd.BtnStart / BtnValidate et confirmation benne, avant nouvelle demande SEMI_AUTO.

### CODESYS R38–R42 — constat courant et décision requise (2026-11-01)

Les essais sont réalisés en Simulation IDE, sur copie isolée, avec `app.rebuild()` réussi avant RUN (14 POU injectées en mémoire). Ils ne valident ni le projet de production, ni l'exactitude physique. Le problème `app.build()` générique de l'ancien runner ne s'applique pas à ces runs rebuild; ce dernier restait fail-closed.

| Cas | Acquis | Limite |
|---|---|---|
| R38 | Stimulus joystick X positif atteint AX14→AX15A. | R37 avait manqué la transition par mauvais stimulus. M3 dépassement à la Trémie ~0,393 m; seuil acceptable non établi. |
| R39 | Montre que le polling 100 ms peut manquer un palier bref AX15B. | Capture insuffisante pour conclure sur la séquence. |
| R40 | Parcours logique AX14→AX15A→AX15C→AX15B→AX18→AX2→P1; arrêt fréquence nulle/frein appliqué. | Position P1 ~5,345 m pour cible 5,0 m; dépassement ~0,345 m. À AX15C, M1/M2 restent à 8,5 m malgré demande de mouvement. |
| R41–R42 | La cause de l'absence de sortie AX15C est isolée au verrou de descente M3; R42 différentiel confirme la chaîne de sortie quand le verrou est temporairement désactivé dans la copie. | Les positions R42 varient de façon non crédible; R42 échoue à confirmer le readback de restauration. Aucun verdict de calibration ou de sécurité. |

**Arbre causal établi :** AX15C commande la descente couplée (FB_CycleSemiAuto.st:1566–1585) → verrou actif et M3 à la Trémie rendent `WinchDescentAuth_M3=FALSE` (PRG_03_Modes_Cycle.st:503–513) → permis descente M1/M2 bloqués (PRG_04_Treuils_Benne.st:1070–1083) → palier 0 et relais non activés. Le conflit entre cette règle et l'intention AX15C doit être tranché métier/sécurité; aucune correction de CODE n'est autorisée sur une hypothèse.

**Prochaine action :** décision documentée sur l'autorisation de descendre M1/M2 à la Trémie en AX15C. En parallèle, corriger et vérifier le protocole de restauration du harnais avant tout autre test différentiel. Ne pas demander de nouvel essai utilisateur ni présenter le cycle comme validé. Aucun code automate de production modifié; aucune machine réelle sollicitée.
