# 🧭 T417 — Pilotage des investigations

> 31 octobre 2026 · Planification uniquement · Mise en service prioritaire
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
