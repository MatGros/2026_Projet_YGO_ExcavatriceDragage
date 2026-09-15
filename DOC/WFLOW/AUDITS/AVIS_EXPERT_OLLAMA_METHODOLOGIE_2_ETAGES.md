# 🥊 Contre-Expertise — Méthodologie AF & Tests en 2 Étages

**Statut : EN REVUE EXPERTE — Réponse contradictoire (Anti-Yes-Man)**  
**Réf : RFC_METHODOLOGIE_2_ETAGES_ET_CHALLENGE_EXPERTS.md**  
**Date : 2026-09-17**  
**Auteur : Expert Senior Automatisme, Sécurité Machine & CI/CD**

---

## 1 · Risque d'échappement de bugs avec le passage aux tests boîte noire POU

**Réponse claire :** Le risque est **réel et structurel**, pas théorique. Il se manifeste dans **quatre familles de bugs** :

### 1.1 Bugs de logique interne sans impact visible aux sorties dans le scénario testé
Un test boîte noire POU n'observe que les sorties. Si un bug interne ne produit **pas** d'écart observable dans les étapes testées (par exemple un calcul d'estimation de position erroné mais qui se recale correctement sur chaque capteur — l'erreur est masquée tant que le trajet est le même que le scénario), il **passe inaperçu**.

**Exemple concret dans l'AF11 :** `FB_Translation_PositionDecoder` (F11.01). Le test `TC-P11-001/002` vérifie la qualification des capteurs et la détection d'incohérence. Mais **il ne teste pas le comportement de l'odométrie entre deux capteurs** (dérive, erreur d'intégration de vitesse). Or l'Étage 2 (`TC-P11-016`) teste la traversée complète — mais si un cas d'odométrie hors capteur présente une erreur cumulative, il ne sera détecté que si le scénario couvre un cas critique (ex. perte de capteur pendant le travers). **Ce n'est pas garanti.**

### 1.2 Combinaisons d'entrées rares non couvertes par 5 fonctions principales
"3 à 6 fonctions principales par axe" est un **minimum**, pas une couverture suffisante. Les interactions d'entrées (ex. `Bypass.MinHeight=FALSE` **et** `HeightInterlockOk=FALSE` **et** commande simultanée Joystick + Cycle) créent des états non spécifiés dans les fonctions individuelles. Si on n'ajoute pas de **tests de fusion d'exigences** ou de **cas aux limites globaux**, on laisse des failles.

### 1.3 Bugs de temporisation et de séquencement internes
Les FB comme `FB_Translation` (rampe), `FB_Brake` (séquence) ou `FB_TranslationOutputInterlock` (watchdog 500 ms) ont des **machines à états internes**. Un test boîte noire en **1 scan** (Étage 1) ne peut **jamais** vérifier l'évolution temporelle de la rampe (20 Hz/s) ni la séquence de libération du frein. L'Étage 2 le fait, mais **seulement si le scénario couvre ces transitions**. Sinon, un bug de rampe (ex. accélération trop rapide) ne sera détecté dans **aucun** étage.

### 1.4 Couverture de code : l'argument "100% automatiquement" est faux
Antigravity affirme : *« La couverture de lignes reste à 100% si les 5 fonctions principales sollicitent toutes les branches »* — c'est une **assertion non démontrée**. Sans un outil de mesure de couverture (gCOV sous C++, ou instrumentation), on ne **sait pas** ce qui est couvert. Et 5 fonctions ne couvrent pas nécessairement les chemins d'erreur rares (erreur de décodage, dépassement de rampe, etc.).

> **Verdict partiel :** L'approche boîte noire est **pertinente** pour la non-régression, mais elle doit être **complétée** par :
> - **Mesure de couverture effective** (branches + conditions) sur le binaire C++ généré, avec seuil (≥ 90% pour les fonctions C4).
> - **Tests ciblés "boîte grise"** sur les FB critiques (sécurité, temporisation) — c'est-à-dire tester les entrées/sorties du FB, pas ses variables internes, mais en isolant le FB pour contrôler **tous** ses chemins. Ce n'est pas un micro-test blanc, c'est un **test d'interface de FB**.
> - **Tests de résilience** (fuzzing d'entrées) sur le POU pour couvrir les combinaisons non spécifiées.

---

## 2 · Couplage et fidélité SimBench pour les sécurités critiques

### 2.1 Ce que l'injection sur HwSim teste bien
- La **logique de déclenchement** des sécurités (réaction à un capteur actif, temporisations T287, escalade) — **si le modèle physique génère les bonnes entrées**.
- Le **routage des signaux** de l'acquisition vers les FB métier.
- La **réaction temporelle** de l'automate (rampes, watchdog) face aux événements simulés.

### 2.2 Ce que l'injection sur HwSim ne teste **pas** sans un modèle physique suffisamment riche
Le point critique est : **le modèle `FB_SimBench` doit être fidèle pour les phénomènes de sécurité importants**. Or l'AF11 (TC-P11-017) mentionne "oscillation pendulaire" pour le balancement de charge — mais **rien ne garantit** que le modèle reproduise la **force réelle** d'un cabestan sous charge 10 t avec glissement.

**Exemple critique : le décollement de frein sous charge** (question posée). Si le modèle SimBench calcule uniquement le **déplacement** du chariot en fonction de la consigne vitesse, sans modéliser :
- la **force de frein** (couple de maintien),
- le **poids de la benne + charge** (10 t) et sa **répartition sur le chariot**,
- le **frottement de glissement** entre frein et tambour,
alors **un défaut de conception du frein** (ex. sous-dimensionnement, perte d'adhérence) ne sera **jamais détecté** — le modèle supposera que le chariot reste immobile quand la consigne est 0, même si le frein réel ne tient pas.

**Conséquence :** on teste la **logique de commande** mais pas la **sécurité physique**. C'est une distinction cruciale. L'ISO 13849 est basée sur le **comportement réel** de la machine, pas sur la logique.

### 2.3 Recommandations pour le couplage
- **Établir un contrat de fidélité du modèle** : pour chaque scénario, documenter les **hypothèses physiques** (masse, frottement, rigidité, temps de réponse variateur) et les **paramètres identifiés de la machine réelle** (à défaut, valeurs conservatives).
- **Valider la fidélité du modèle par rapport à la machine réelle** (calibration SAT initiale, comparaison essais/ simulation). Sinon, l'Étage 2 devient un **test de cohérence interne** qui valide que la simulation est stable, pas que la machine est sûre.
- **Compléter par des tests de robustesse "boîte noire" ciblés** sur les chemins de sécurité : simuler une **panne de feedback frein** (perte du `BrakeFeedback_DI` en mouvement) avec un modèle qui **garde le chariot en mouvement** (inertie) pour vérifier que la temporisation de 500 ms est bien respectée et que la coupure est effective.

---

## 3 · Auditabilité SAT / Normes : séquences chronologiques vs matrice combinatoire

**Réponse :** Les deux ont des forces et des faiblesses. **Une approche hybride est indispensable.**

### 3.1 Forces des séquences chronologiques riches
- **Lisibilité pour l'opérateur et le SAT** : un chronogramme avec des noms de signaux réels (`RawX`, `TargetFrequencyHz`, `BrakeReleaseCmd`) est **compréhensible sur le terrain**.
- **Traçabilité directe** : chaque étape correspond à un état réel de la machine.
- **Couverture dynamique** : on prouve que l'automate **réagit dans le temps** (rampes, temporisations, escalades).

### 3.2 Faiblesses face à un organisme de contrôle
- **Exhaustivité non démontrée** : un organisme (ou un auditeur ISO 13849) cherche une **preuve que chaque exigence de sécurité est satisfaite**. Une matrice combinatoire permet de **prouver formellement** que toutes les combinaisons d'entrées critiques sont couvertes (ex. AU + défaut + butée + commande). Une séquence ne le montre que pour les états qu'elle parcourt.
- **Traçabilité exigences** : il faut **chaque test relié à une exigence** (fonction F11.xx, exigence de sécurité). Sans tableau de traçabilité, le dossier est fragile.
- **Traçabilité d'exécution** : il faut **prouver que le test a été exécuté** (rapport CI horodaté, capture des sorties, numéro de build). Les émojis 💤🔒🚀 n'ont aucune valeur probatoire — seules les **traces machine** (logs des signaux) en ont.

### 3.3 Recommandations pour le dossier SAT
- **Double documentation** :
  - **Matrice de traçabilité exigence → test** (obligation ISO 13849 §6.2).
  - **Chaque test** documenté en **séquence chronologique** (comme actuellement) **et** complété d'un **tableau des combinaisons d'entrées critiques** testées (AU, bypass, défauts simultanés).
- **Fournir des preuves d'exécution** (rapports CI avec timestamp, traces de scans simulés, capture IHM).
- **Inclure les scénarios de défaillance simulés** (panne de capteur, perte feedback) — c'est souvent ce que les auditeurs regardent en premier.

**Verdict :** les séquences sont **plus pédagogiques**, mais **elles ne remplacent pas la matrice**. Un organisme acceptera un dossier si :
- chaque exigence de sécurité est **rattachée** à au moins un test,
- le rapport d'exécution est **prouvable et traçable**.

---

## 4 · Maintenabilité outillage : transpilateur STruC++, Gates, CODESYS

### 4.1 Fragilités identifiées

#### a) Transpilateur STruC++ et simulation temporelle
- L'Étage 2 nécessite **500 à 1000 scans simulés**. Le modèle ST (SimBench) doit être **transpilé et exécutable** en C++. Toute fonction CODESYS non supportée par STruC++ (ex. `TON`/`TOF` étendus, types complexes, bibliothèques système, accès aux tâches) casse la compilation.
- **Gestion du temps** : il faut soit simuler le temps (variable `T#...` incrémentée manuellement), soit utiliser un équivalent réaliste. Une erreur ici rend les tests temporels faux **sans échec apparent** (ex. temporisation de 500 ms qui passe en 5 scans au lieu de 50).

#### b) Parser et Gates
- Les tests sont décrits dans des tableaux Markdown avec émojis et formats spécifiques. Le parser `extract_functions_matrix.py` et les gates (G450, etc.) doivent :
  - **extraire correctement** les nouveaux formats (étapes, signaux, valeurs),
  - **gérer les caractères Unicode** (💤, →, etc.) — un bug d'encodage casse silencieusement l'outil.
- **Risque de non-régression de l'outillage** : chaque mise à jour d'AF (ajout d'un TC, changement de format) peut casser le parser. Il faut des **tests de régression sur l'outillage lui-même** (tests du parser avec des fichiers d'exemple).

#### c) Intégration CODESYS
- `FB_SimBench` doit fonctionner **à la fois** sur CODESYS interactif et dans la CI C++. Toute divergence de comportement (ex. fonctions de mathématiques différentes, précision) peut produire des résultats incohérents.
- **Mémoire** : la simulation en boucle fermée avec 1000 scans peut utiliser beaucoup de mémoire C++ (tableaux de logs). À surveiller.

#### d) Maintenabilité du format
- Les émojis et formats riches sont **fragiles pour les revues automatiques**. Un testeur humain peut les lire, mais les **agents CI doivent parser exactement**. Il faut **stabiliser la syntaxe** (ex. balises `<Étape>` au lieu de mélange émojis/texte).

### 4.2 Recommandations
- **Créer des gates dédiées** pour :
  - **vérifier la transpilabilité** du code ST (compilation C++ sans erreur),
  - **vérifier la cohérence des séquences** (noms de signaux existants, valeurs dans les plages définies),
  - **mesurer la couverture** d'exécution des tests (combien de scans par test, temps simulé).
- **Automatiser les tests d'outillage** (parser + gates) dans la CI avec des fichiers de test.
- **Documenter les conventions du modèle STruC++** (fonctions supportées, types de données, gestion du temps) dans un standard dédié.

---

## 5 · Verdict & Recommandations concrètes

### Verdict global
**Je valide la philosophie du modèle en 2 étages** : il répond à des écueils réels (micro-tests fragiles, simulation intrusive, sur-spécification). **Mais je conditionne le déploiement large à plusieurs gardes d'ingénierie rigoureuses**, sous peine de générer un faux sentiment de couverture.

### Gardes d'ingénierie à ajouter (non négociables)

1. **Mesure de couverture effective** (branches, conditions, états de FB) sur le binaire C++ généré, avec un **seuil minimal** (≥ 90% pour les fonctions C4, ≥ 85% pour C3). Sans mesure, l'argument "couverture 100%" reste une **affirmation non prouvée**.

2. **Tests ciblés "boîte grise" sur les FB de sécurité** : pour les FB critiques (ex. `FB_Safety_Translation`, `FB_TranslationOutputInterlock`), ajouter des tests dédiés qui **contrôlent toutes les entrées** du FB et vérifient **toutes ses sorties** dans **chaque état**. Ce n'est pas un micro-test blanc ; c'est un test d'interface exhaustif.

3. **Contrat de fidélité SimBench** : documenter, pour chaque scénario, les **hypothèses physiques** (masse 10 t, frottement, temps de réponse variateur, paramètres odométriques) et les **valeurs de validation terrain**. Sans cela, l'Étage 2 est un **jeu de cohérence interne**, pas une preuve de sécurité.

4. **Validation de fidélité par calibration** : avant le SAT, comparer le comportement simulé (`FB_SimBench`) avec des essais réels (mesure de position, temps de réponse, courbe de décélération). Ajuster les paramètres.

5. **Traçabilité SAT obligatoire** : chaque exigence de sécurité (liste issue de l'ISO 13849 et des directives CE) doit être **rattachée** à au moins un test (Étage 1 ou 2) via une **matrice de traçabilité**. Le dossier devra contenir **preuves d'exécution** (rapports CI horodatés, traces de scans simulés).

6. **Gates outillage dédiées** : vérification automatique de la transpilabilité, cohérence des noms de signaux, couverture des séquences, et non-régression du parser.

7. **Tests de robustesse sur les pannes** : inclure systématiquement des scénarios de **panne de capteur**, **perte de feedback**, **incohérence simultanée**, et **surcharge de butée** — avec des modèles physiques qui **reproduisent le comportement réel** (pas seulement l'état binaire).

### Déploiement sur les autres fonctions
**Oui, je valide le déploiement** sur les Treuils (AF10), Modes/Séquenceur (AF04), à condition que :
- les gardes 1, 2, 3 soient appliquées,
- le modèle SimBench soit **factorisé** (une bibliothèque commune de physique cinématique pour tous les axes),
- la structure des tests suive **exactement** le même formalisme (séquences avec signaux réels + matrice de traçabilité).

**Attention aux fonctions avec exigences de sécurité pl (Performance Level) > PL c** : pour celles-ci, une **analyse de fiabilité** (calcul de PL via ISO 13849-1) reste indispensable en complément des tests. La validation fonctionnelle ne remplace pas le calcul de performance du système de commande.

---

## Conclusion

Le modèle en 2 étages est **une bonne base**, mais il ne doit **pas être déployé tel quel**. Il faut **fermer les angles morts** par :
- des **tests ciblés** sur les FB critiques,
- une **mesure de couverture** et une **validation de fidélité** du modèle SimBench,
- une **traçabilité exhaustive** pour le dossier SAT.

Sans ces gardes, on risque de **valider une simulation bien écrite plutôt qu'une machine sûre**. La sécurité s'évalue sur le **comportement physique réel**, pas sur des chronogrammes.

---

*Signé : Expert Senior en Automatisme, Sécurité Machine & CI/CD — Anti-Yes-Man mode activé.*