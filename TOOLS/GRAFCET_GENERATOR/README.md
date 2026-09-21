# 🧭 GRAFCET GENERATOR — Cockpit Séquenceur & GRAFCET Interactif

Outil moderne et autonome de visualisation, simulation et documentation des séquenceurs, GRAFCET et machines à états du projet **Excavatrice de Dragage**.

---

## 🎯 Origine & Terminologie

- **GRAFCET** : **GRA**phe **F**onctionnel de **C**ommande par **É**tapes et **T**ransitions (norme internationale **CEI 60848** / NF C03-190).
- Le terme provient à la fois de sa définition technique et du groupe de travail de l'**AFCET** (Association Française pour la Cybernétique Économique et Technique) en 1977.
- En automatisme industriel sous la norme **CEI 61131-3** (CODESYS, TwinCAT, etc.), ce formalisme est implémenté sous le nom de **SFC** (*Sequential Function Chart*).

---

## 📂 Trois Vues Spécialisées Complémentaires

Le dossier contient trois interfaces web autonomes interconnectées :

| Interface | Fichier HTML | Lanceur Direct | Caractéristiques |
|---|---|---|---|
| 🧭 **Cycle Homing (Double Vue & Zoom)** | `cycle_homing_lumineux.html` | [`OPEN_HOMING_LUMINEUX.bat`](OPEN_HOMING_LUMINEUX.bat) | **Double vue innovante** : Vue d'ensemble de la machine + **Macro Zoom Caméra** sur le fin de course mécanique à câble tendu entre treuils M1/M2 (`TopPositionSensor`), déflexion physique du câble par le tampon de la tête de benne, bras de manœuvre pivotant du boîtier FDC étanche, détection du front descendant sur retour du câble tendu (`TopLostEdge.Q`), callout butée mécanique T340 (`HX7_LOCKED_REFERENCE`). |
| ✨ **Cycle Auto de Dragage** | `cycle_auto_lumineux.html` | [`OPEN_CYCLE_AUTO.bat`](OPEN_CYCLE_AUTO.bat) | **Mode épuré, lumineux & animé** : synoptique machine SVG fluide (ouverture réelle des coquilles de la benne vers l'extérieur), timeline horizontale en bas sans à-coups verticaux, bascule paramètre de site `CfgRaiseOffBottomM` (0.0 m bypass vs 0.3 m actif AX9), et mode **Lecture Démo Automatique**. |
| 💻 **Console Cockpit Homing** | `index.html` | [`OPEN_GRAFCET.bat`](OPEN_GRAFCET.bat) | Mode sombre industriel avec simulation d'entrées physiques (joystick, homme-mort, reset). |

---

## 📂 Contenu du dossier

| Fichier | Rôle |
|---|---|
| `OPEN_HOMING_LUMINEUX.bat` | 🚀 Double-clic : ouvre le cycle Homing (double vue & macro zoom câble tendu) |
| `OPEN_CYCLE_AUTO.bat` | 🚀 Double-clic : ouvre le cycle Automatique (vue lumineuse & animée SVG) |
| `OPEN_GRAFCET.bat` | 🚀 Double-clic : ouvre la console cockpit sombre du Homing |
| `cycle_homing_lumineux.html` | 🖥️ Interface Homing double vue avec zoom fin de course à câble tendu |
| `cycle_auto_lumineux.html` | 🖥️ Interface lumineuse & animée du Cycle Auto de dragage |
| `index.html` | 🖥️ Console cockpit sombre du Cycle Homing |
| `data_auto.json` | 📊 Données structurées du Cycle Auto (`FB_CycleSemiAuto.st`) |
| `data_homing.json` | 📊 Données structurées du Cycle Homing (`FB_CycleMachineHoming.st`) |
| `generate_grafcet.py` | 🛠️ Compilateur pour la console Homing |
| `generate_cycle_auto.py` | 🛠️ Compilateur pour le cycle Auto |

---

## 🚀 Utilisation Rapide

- **Pour explorer le Cycle Homing avec la double vue et le macro zoom câble tendu** :  
  Double-cliquer sur **`OPEN_HOMING_LUMINEUX.bat`**.
- **Pour explorer le Cycle Automatique de Dragage en vue animée** :  
  Double-cliquer sur **`OPEN_CYCLE_AUTO.bat`**.
- **Pour basculer d'une vue à l'autre** :  
  Utiliser les onglets de navigation dans le bandeau supérieur de chaque page !

---

## 🗺️ Cycles supportés & Détails Techniques

- ✅ **Cycle Homing Machine (`FB_CycleMachineHoming.st`)** :
  - 11 étapes documentées : `HX0_REPOS`, `HX1_CHOICE`, `HX2_CLIMB`, `HX2N_NEUTRAL`, `HX3_HOME_AXES`, `HX3N_PAUSE`, `HX4_BUCKET_ADJUST`, `HX5_BUCKET_COMMIT`, `HX6_HOMED`, `HX7_LOCKED_REFERENCE` (T340), `HXF_FAILED`.
  - Zoom temps réel sur le **mécanisme de fin de course à câble tendu horizontal** : câble acier tendu entre les treuils M1 et M2, ressort hélicoïdal de tension, boîtier FDC électromécanique étanche, déflexion du câble au contact du tampon de tête de benne (`TopPositionSensor = TRUE`), déclenchement du calage au vol sur front descendant (`TopLostEdge.Q`) dès que le câble se retend droit, et gestion de la voie de secours à l'arrêt complet (`HX7`).
  - Démarrage benne **ouverte** et manœuvre manuelle assistée à `HX4` pour fermeture et confirmation avant commit atomique `HX5`.
  - Matrice des causes d'erreurs (`instCauses[0..6]`).
- ✅ **Cycle Automatique / Semi-Automatique (`FB_CycleSemiAuto.st`)** :
  - 21 étapes : `AX0_READY` à `AX18_CYCLE_COMPLETE`, avec étapes de repli et de stabilisation (`AX_DIVING_RETRY`, `AX_STAB`).
  - Cinématique fidèle : ouverture évasée vers l'extérieur (`+40° / -40°`), immersion, détection fond, fermeture godet, levage plein, vidage trémie.
  - Gestion du paramètre site : `CfgRaiseOffBottomM` (quand `0.0 m`, transition directe `AX8 ➔ AX10` sans relevage intermédiaire).
  - Navigation ergonomique : timeline horizontale intégrée sans saut d'écran, filtres de mini-phases intégrés au header.
