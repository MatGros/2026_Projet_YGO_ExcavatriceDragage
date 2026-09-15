# 🥊 RFC & Dossier de Challenge — Méthodologie Automate en 2 Étages (AF & CI/CD)

> **Date** : 2026-09-16  
> **Auteur** : Antigravity (Expert Automatisme & CI/CD)  
> **Statut** : 🟡 EN REVUE EXPERTE (Prêt pour challenge contradictoire multi-agents)  
> **Cible** : Soumission à contre-expertise (Codex, Claude Code, Ollama / DeepSeek-V4, Humain)

---

## 🎯 1 · La Thèse Défendue (Le Paradigme en 2 Étages)

### Le Problème Actuel du Projet
1. **Inflation de micro-tests unitaires fragiles** : L'AF actuelle et la CI (`STruC++`) multiplient les tests sur des variables locales/privées de FB (`bLocalState`, calculs internes). Dès qu'un FB est refactoré (ex: renommage ou optimisation mathématique), 15 tests pètent alors que la fonction machine reste 100% opérationnelle.
2. **Sur-spécification théorique** : Des analyses fonctionnelles de 50 pages listant 40 cas combinatoires abstraits que personne ne lit sur le chantier.
3. **Simulation intrusive** : Des tentatives de glisser des équations différentielles ou des comportements de simulation au cœur même des blocs logiques métier.

### La Solution Proposée
Scinder **strictement** toute spécification AF et toute validation de test en **deux étages étanches** :

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ÉTAGE 1 : FONCTIONS PRINCIPALES BOÎTE NOIRE (Non-régression statique)            │
│ « J'appuie sur le bouton ➔ Le moteur démarre ➔ La sécurité interdit »            │
│ • Frontière : Entrées IHM/DI ➔ POU PRG_0x ➔ Sorties DO/Consignes                 │
│ • Granularité : 3 à 6 fonctions principales par axe.                             │
│ • Exécution : 1 scan automate par test (instantané, < 100 ms).                   │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
                                         ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ÉTAGE 2 : DYNAMIQUE SIMULÉE SIL (Boucle fermée HwSim ➔ PRG_02)                  │
│ « Le moteur tourne ➔ La machine bouge ➔ Les capteurs réagissent dans le temps »  │
│ • Frontière : Consignes ➔ SimBench (physique ST) ➔ Capteurs virtuels HwSim       │
│ • Granularité : 2 à 4 grands scénarios temporels réels par axe.                  │
│ • Exécution : 500 à 1000 scans simulés en continu (0.2s CI headless / IHM CODESYS│
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🛡️ 2 · Les 4 Points Clés & Arbitrages Techniques

### Arbitrage 1 : Le Contrat d'Interface POU plutôt que le micro-test FB
- **Choix** : On teste le POU complet (`PRG_05_Translation`) en boîte noire. Les blocs internes (`FB_Translation_PositionDecoder`, `FB_Translation`, `FB_Safety_Translation`) sont testés par transitivité.
- **Bénéfice** : Refactorer l'intérieur d'un FB ne casse aucun test tant que la fonction machine est préservée.
- **Point à challenger** : Risque-t-on de manquer un bug interne masqué qui ne se révélerait que dans une combinatoire d'entrées très rare ?

### Arbitrage 2 : L'Injection SIL purement aux frontières matérielles
- **Choix** : Le simulateur `FB_SimBench.st` écrit uniquement dans `HwSim`. `PRG_02_Acquisition` lit `HwSim` si `SimulationMode = TRUE`. Aucun FB métier ne sait qu'il est simulé.
- **Bénéfice** : Code de production 100% vierge de tout code de simulation. Jumeau numérique en Structured Text pur (valable sur CODESYS interactif et sur la CI C++).
- **Point à challenger** : Comment tester les défaillances de communication EtherCAT (perte de nœud, jitter bus) si l'injection ne se fait qu'au niveau des variables d'acquisition ?

### Arbitrage 3 : Séquences Chronologiques Riches au lieu de Micro-Cas Multipliés
- **Choix** : Abandonner les 40 lignes de tests monotones au profit de grands scénarios séquentiels découpés avec précision (`💤 Étape 0 Repos` ➔ `🔒 Étape 1 Armement` ➔ `🚀 Étape 2 Déclenchement` ➔ `⚡ Étape 3 Régime établi` ➔ `🔄 Étape 4 Arrêt/Hystérésis/Défaut`) avec les vrais noms de signaux (`RawX`, `TargetFrequencyHz`, `BrakeReleaseCmd`, etc.).
- **Bénéfice** : Véritable reflet d'un chronogramme machine. Directement transposable en oracle de test.
- **Point à challenger** : Est-ce que le parser de matrice (`extract_functions_matrix.py` et gate `G450`) absorbe correctement ce formalisme sans régression d'outillage ? *(Réponse : Oui, validé mécaniquement).*

### Arbitrage 4 : Sécurité Machine ISO 13849 & Traçabilité SAT
- **Choix** : La sécurité matérielle (AU, PowerCutOff, contacteurs, anti-télescopage) est testée à la fois en statique (Étage 1 : coupure en 1 scan) et en dynamique (Étage 2 : heurt de butée, escalade temporisée T287 à 2.5s et 5s).
- **Point à challenger** : Est-ce suffisant pour le dossier d'homologation et les essais SAT officiels ?

---

## ⚔️ 3 · Grille de Challenge pour la Revue de Pairs (Agents / Experts)

Voici les questions précises et sans complaisance à soumettre aux agents contradicteurs :

```markdown
### 📋 PROMPT DE CONTRE-EXPERTISE (À copier-coller pour l'agent reviewer)

Tu interviens en tant qu'Expert Senior Indépendant en Automatisme Industriel, 
Sécurité Machine (ISO 13849 / Directives Machines) et Architectures CI/CD.

Prends connaissance de la proposition méthodologique "AF & Tests en 2 Étages" documentée dans :
- DOC/STDS/GUIDES/GUIDE_METHODOLOGIE_AF_ET_TESTS_2_ETAGES_v1.0.md
- DOC/AF/AF_Partie-11_Fonction_Translation_v2.4.md
- DOC/WFLOW/AUDITS/RFC_METHODOLOGIE_2_ETAGES_ET_CHALLENGE_EXPERTS.md

Ta mission est de CHALLENGER IMPITOYABLEMENT cette approche (Anti-Yes-Man). 
Ne cherche pas à faire plaisir : cherche les failles, les angles morts et les risques réels.

Réponds précisément aux 5 questions suivantes :
1. **Risque d'échappement de bugs** : En remplaçant les micro-tests unitaires des FB par des tests boîte noire POU (Étage 1), quel type précis de bug risque de ne plus être détecté par la CI ?
2. **Couplage et fidélité SimBench** : Le fait de restreindre la simulation aux entrées HwSim (Étage 2) est-il suffisant pour valider des sécurités critiques comme le décollement de frein sous charge ou l'inversion brutale ?
3. **Auditabilité SAT / Normes** : Un dossier SAT basé sur des séquences chronologiques riches (💤 🔒 🚀 ⚡ 🔄) est-il plus recevable ou moins recevable par un organisme de contrôle qu'une matrice combinatoire classique ?
4. **Maintenabilité outillage** : Quelle est la fragilité potentielle de ce modèle vis-à-vis du transpilateur STruC++ et de l'IDE CODESYS 3.5 ?
5. **Verdict et Recommandations concrètes** : Valides-tu le déploiement de ce standard sur les autres fonctions (Treuils AF10, Benne AF10, Séquenceur AF04) ? Quelles gardes d'ingénierie préconises-tu d'ajouter ?
```

---

## 📌 4 · Positionnement & Arguments de Défense d'Antigravity

Pour préparer le débat, voici les réponses techniques fermes aux objections prévisibles :

| Objection prévisible | Réponse technique & Justification terrain |
|---|---|
| *« Sans micro-tests FB, la couverture de code baisse ! »* | **Faux.** La couverture de lignes reste à 100% si les 5 fonctions principales et les sécurités sollicitent toutes les branches du POU. En revanche, on élimine la couverture artificielle (`ASSERT_TRUE(TRUE)`). |
| *« C'est trop long d'écrire des séquences d'étapes détaillées ! »* | **Au contraire.** Écrire 5 déroulés d'étapes clairs prend 20 minutes et sert à la fois de spécification, d'oracle de test et de guide opérateur. Écrire et débugger 40 micro-tests unitaires prend 3 jours. |
| *« La simulation dans l'automate alourdit le temps de cycle ! »* | **Non.** Quand `SimulationMode = FALSE` (sur machine réelle), `FB_SimBench` est totalement neutralisé dès son premier scan (`IF NOT Enable THEN RETURN`). L'impact CPU est de zéro microseconde. |
