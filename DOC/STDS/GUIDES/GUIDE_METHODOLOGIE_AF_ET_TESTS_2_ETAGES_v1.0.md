# Guide Méthodologique — Conception AF & Tests en 2 Étages (v1.0)

> 📌 **Standard de Projet — Ingénierie Automatisme & Validation CI/CD**  
> Ce guide formalise la méthodologie de spécification fonctionnelle et de validation par simulation appliquée sur l'excavatrice de dragage.

---

## 🎯 1 · Contexte & Diagnostic du Besoin

L'expérience des premières phases de mise en service terrain et d'intégration CI a mis en évidence deux écueils classiques en automatisme industriel :

| Écueil rencontré | Conséquence sur le projet | Solution apportée par le modèle 2 Étages |
|---|---|---|
| **Sur-spécification théorique** | Analyses fonctionnelles de 50 pages listant des dizaines de cas combinatoires abstraits. | **AF synthétique boîte noire** : 3 à 6 fonctions principales limpides par domaine. |
| **Micro-tests unitaires "blancs"** | Des dizaines de tests C++ testant les variables privées internes des FB (fragiles, cassent à chaque refactor). | **Tests d'interface E/S** : On teste le comportement extérieur du POU (*Entrée ➔ Sortie*). |
| **Simulation intrusive** | Tentative de modéliser des équations physiques au cœur des FB métier. | **Simulation aux frontières matérielles** : `SimBench` injecte sur `HwSim` ➔ `PRG_02`. |

---

## 🧱 2 · Le Modèle en 2 Étages

Chaque domaine fonctionnel de la machine (Translation M3, Treuils M1/M2, Benne, Modes, etc.) est spécifié et testé en **deux étages strictement complémentaires** :

```text
┌────────────────────────────────────────────────────────────────────────────────┐
│ ÉTAGE 1 : LES FONCTIONS PRINCIPALES (Boîte Noire / Non-Régression Statique)    │
│ « J'appuie sur le bouton ➔ Le moteur démarre ➔ La sécurité interdit »          │
│ • Périmètre : Entrées Opérateur/IHM ➔ POU Métier ➔ Sorties Variateur/Contacteur │
│ • Validation : Test combinatoire en 1 scan automate (Smoke test immédiat)      │
└───────────────────────────────────────┬────────────────────────────────────────┘
                                        │
                                        ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│ ÉTAGE 2 : LA DYNAMIQUE SIMULÉE (Boucle Fermée SIL via SimBench)                │
│ « Le moteur tourne ➔ La machine bouge ➔ Les capteurs réagissent dans le temps » │
│ • Périmètre : Boucle fermée complète via injection physique HwSim ➔ PRG_02     │
│ • Validation : Scénarios temporels réels (balancement, rebond, butée, odométrie)│
└────────────────────────────────────────────────────────────────────────────────┘
```

---

### 🟢 Étage 1 : Fonctions Principales & Non-Régression Statique

#### 🎯 Objectif
Prouver instantanément que la logique de commande élémentaire et les interlocks de sécurité fonctionnent, sans attendre une simulation temporelle lourde.

#### 📋 Structure d'une Fonction Principale (FP)
Chaque fonction principale est documentée dans l'AF sous forme d'une ligne de tableau claire :
1. **Intention Métier** : Le rôle de la commande (ex: *Translation Manuelle Joystick*).
2. **Déclencheur (Entrée)** : La consigne opérateur ou cycle (ex: *Joystick X > 20%*).
3. **Réaction Automate (Sortie)** : L'actionneur activé (ex: *Consigne 0..50 Hz + Frein ouvert*).
4. **Sécurité Bloquante** : La condition qui doit neutraliser immédiatement l'ordre (ex: *AU, Défaut, ou FdC engagé*).

#### 🧪 Règle de test Étage 1
- **Boîte Noire pure** : Le test injecte des valeurs dans les entrées du POU et vérifie les sorties vers `PRG_06`.
- **Zéro dépendance interne** : On ne teste jamais une variable locale de FB.
- **Vitesse d'exécution** : 1 scan par test. L'ensemble des tests Étage 1 s'exécute en moins de 100 ms.

---

### 📐 2bis · Format Standard d'une Séquence de Test (Comportement attendu & Signaux)

Pour chaque Fonction Principale (Étage 1) et chaque Scénario Dynamique (Étage 2), le comportement attendu doit être décrit selon une **séquence chronologique d'étapes standardisées**, précisant les **noms réels des signaux et leurs valeurs** :

```text
Séquence & Déroulé des étapes (Comportement attendu & Signaux)

💤 Étape 0 (Repos neutre) : État initial au repos.
   Exemple : Joystick au centre (RawX=5000, AtNeutralXY=TRUE, StepTgt=0, SpeedTgt=0%).

🔒 Étape 1 (Armement / Sécurité) : Préalables et autorisations requis.
   Exemple : Appui bouton RawButton=TRUE sous ArmingPermit=TRUE pendant 500 ms ➔ DeadmanArmed=TRUE.

🚀 Étape 2 (Déclenchement / Action initiale) : Transition ou amorce du mouvement.
   Exemple : Déflexion +5% (zone morte) ➔ StepTgt=0 ; déflexion +15% ➔ StepTgt=1, RelayFwd=TRUE.

⚡ Étape 3 (Progression / Régime établi) : Montée en vitesse, rampe ou paliers.
   Exemple : Déflexion +50% ➔ StepTgt=3 ; +95% ➔ StepTgt=5, SpeedTgt=100% (contacteurs K1..K4 validés).

🔄 Étape 4 (Arrêt / Hystérésis / Sécurité) : Retour au calme ou déclenchement d'un seuil.
   Exemple : Relâchement progressif ➔ Le palier 4 reste tenu jusqu'à la limite basse de l'hystérésis (pas de battement autour du seuil).
```

Ce formalisme rigoureux permet aux automaticiens et aux agents CI de coder directement les oracles de test sans ambiguïté.

---

### 🟡 Étage 2 : Dynamique Simulée & Scénarios SimBench

#### 🎯 Objectif
Éprouver la robustesse de l'automate face aux phénomènes physiques du chantier (inertie, balancement de charge, rebonds mécaniques de capteurs, glissement d'adhérence) **avant** de monter sur la machine.

#### 🔌 Principe d'Injection Strict : "Aux Frontières Matérielles"
La simulation ne doit **jamais** être greffée au milieu de la logique métier.  
Elle s'interface exclusivement au niveau de l'image matérielle :

```text
                           BOUCLE FERMÉE SIMBENCH
  ┌────────────────────────────────────────────────────────────────────────┐
  │                                                                        │
  │   [Consignes Sorties] ──► [FB_SimBench] ──► [Modèle Physique ST]       │
  │                                                    │                   │
  │                                                    ▼                   │
  │   [POU Métier PRG_05] ◄── [PRG_02_Acquisition] ◄── [Capteurs HwSim]    │
  │                                                                        │
  └────────────────────────────────────────────────────────────────────────┘
```

1. `PRG_05` / `PRG_06` génère la consigne vers le variateur (ex: 50 Hz).
2. `FB_SimBench` calcule le déplacement mécanique simulé.
3. `FB_SimBench` active les capteurs virtuels dans `HwSim`.
4. `PRG_02_Acquisition` lit `HwSim` (quand `SimulationMode = TRUE`) et met à jour `HwIn`.
5. Le programme automate complet réagit exactement comme en carrière noyée.

#### 🚀 Double exploitation du Modèle ST Unique
Puisque `FB_SimBench.st` est écrit en Structured Text pur :
- **Dans CODESYS (Interactif)** : L'automaticien bascule `SimulationMode` à `TRUE` et pilote la machine depuis les écrans IHM réels sur son PC portable.
- **Dans la CI (Automatique)** : Le transpilateur `STruC++` convertit le contrôleur et `SimBench` en binaire C++ pour exécuter des scénarios complets de 500 scans en 0.2 s avec rapport de non-régression.

---

### ⚠️ 2ter · Limites Connues & Périmètre Hors SIL (Les Pannes de Bus & Réseau)

Le modèle de simulation en boucle fermée (SIL) reproduit fidèlement la physique cinématique, l'inertie et l'état binaire des entrées/sorties. **Cependant, il ne modélise pas les perturbations de couche physique et de protocole réseau/terrain :**
- 🔌 **Coupure franche de bus EtherCAT / Profinet** (perte de trames, rupture de câble RJ45/fibre).
- ⏱️ **Gigue d'horloge (Jitter) & Dérive de synchronisation DC (Distributed Clocks)**.
- 📡 **Micro-coupures CEM & trames corrompues CRC**.

**Règle de traitement d'ingénierie :**
1. Ces défaillances relèvent de la **pile protocolaire système CODESYS** et du diagnostic matériel (`FB_Safety`, surveillance d'état des esclaves EtherCAT `Device.wState`).
2. Elles ne doivent **pas** être sur-modélisées dans `FB_SimBench` au risque de complexifier inutilement le modèle ST.
3. Leur couverture de test s'effectue via des tests d'intégration spécifiques d'injection de panne sur le driver de bus ou en qualification sur banc matériel physique (HIL).

---

## 📝 3 · Gabarit Standard d'une Spécification AF (Modèle AF11 v2.4)

Toute mise à jour ou rédaction d'analyse fonctionnelle métier doit désormais adopter cette structure épurée :

1. **En-tête & Rôle Métier** (Périmètre clair, rôle physique de l'axe, POU responsable).
2. **Tableau Étage 1 (Fonctions Principales)** (3 à 6 lignes max : *Intention / Entrée / Sortie / Sécurité bloquante / Test immédiat*).
3. **Tableau Étage 2 (Scénarios Dynamiques SimBench)** (2 à 4 profils réels : *Traversée nominale / Perturbation capteur / Butée d'urgence*).
4. **Conventions & Cotes Terrain** (Repères 0m, sens +1/-1, adresses des capteurs).
5. **Architecture des Fichiers ST & Données** (Liste des briques composant le POU).

---

## ⚖️ 4 · Critères d'Arbitrage (Anti-Dérive)

| Si un agent ou un dev veut... | La règle du guide répond : |
|---|---|
| Ajouter un test vérifiant une variable interne de FB | ❌ **NON** : Tester uniquement la sortie du POU (`PRG_0x`). |
| Écrire des équations physiques de frottement dans un FB métier | ❌ **NON** : Le code métier ne contient que la logique de commande. La physique va exclusivement dans `FB_SimBench`. |
| Écrire une spec de 30 pages avec 40 tableaux combinatoires | ❌ **NON** : Synthétiser en 5 fonctions principales boîte noire. |
| Valider une fonction complexe sans simulation | ⚠️ **CONDIT.** : Étage 1 obligatoire pour non-régression ; Étage 2 obligatoire dès qu'il y a une inertie ou un capteur bagotant. |

---

## 🍃 5 · L'Esprit de la Méthode : Fluidité, Pragmatisme & "Flat Design"

Le but de cette méthodologie en 2 étages n'est **en aucun cas** de rajouter de la bureaucratie ou des blocages administratifs.  
Elle vise au contraire à **libérer le développeur et l'automaticien sur le chantier** :

1. **Documents légers et directs ("Flat")** :
   - Une analyse fonctionnelle ne doit pas dépasser 150 à 250 lignes.
   - On la lit en 3 minutes sur une tablette ou un écran de PC portable en carrière.
   - Les tableaux vont droit au but : *Intention ➔ Entrée ➔ Sortie ➔ Sécurité bloquante*.
2. **Pas d'usine à gaz dans la simulation** :
   - Inutile de modéliser chaque vis ou chaque frottement microscopique.
   - Le modèle `FB_SimBench` doit juste avoir la bonne masse, la bonne rampe et les bons capteurs pour voir comment l'automate réagit.
3. **Feedback immédiat (< 1 scan)** :
   - L'Étage 1 donne une réponse binaire instantanée : est-ce que mon bouton fait toujours démarrer le bon moteur sans court-circuit logique ?
   - Si oui, on avance sans friction.
4. **Facilité de modification sur le terrain** :
   - Si l'exploitant demande d'ajuster un seuil ou une temporisation en mise en service, le changement doit être rapide et fluide dans le code et dans l'AF, sans devoir satisfaire une armée de règles théoriques rigides.

---

## 🏁 6 · Contrat de Sortie Simple (Critères Factuels)

Pour considérer un lot prêt pour la machine :
- ✅ **Liaison propre** : `G200_check_linkage.py --report` à 0 erreur (le code est réellement câblé).
- ✅ **Étage 1 vert** : Les fonctions principales répondent au premier scan.
- ✅ **Étage 2 cohérent** : La cinématique avance sans à-coup sous `SimBench`.
- ✅ **Validation humaine** : L'automaticien garde la main sur l'import final dans CODESYS.
