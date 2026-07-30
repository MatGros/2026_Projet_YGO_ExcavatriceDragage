# 📘 Proposition d'Architecture CFC Graphique & Bus de Données (DUT)

> 📌 **Statut** : Document de synthèse d'architecture (Vision CFC & Standardisation POO).
> 📅 **Date** : 30 Juillet 2026
> 🎯 **Objectif** : Poser la philosophie d'une orchestration visuelle en **CFC (Continuous Function Chart)** basée sur la **Programmation Orientée Objet (POO)** et l'échange par **Bus de Données Structurés (DUT)** pour faciliter le dépannage et la maintenance site.

---

## 🎯 1. Philosophie & Principes Directeurs

| # | Principe | Concept & Avantage Maintenance |
|---|---|---|
| 1 | **Zéro Logique dans le CFC** | Le CFC n'est qu'un **plan de câblage informatique visuel**. Aucun `IF/THEN/ELSE`, aucun calcul en ligne. Tout est encapsulé dans les blocs fonctionnels (`FB_*`). |
| 2 | **POO par Composition** | Les blocs métiers (ex: `FB_Translation`, `FB_Winch`) sont les chefs d'orchestre. Ils intègrent leurs sous-briques techniques (`FB_Ramp`, `FB_Brake`) en interne sans alourdir le schéma CFC. |
| 3 | **Échange par Bus Structurés (DUT)** | Remplacement du câblage "fil à fil" (15 variables isolées) par **un seul bus de données de couleur** reliant les blocs. |
| 4 | **Sécurité Chapeau (Superviseur)** | Les blocs de sécurité (`FB_Safety_*`) sont positionnés **au-dessus**. Ils acquièrent les pannes et distribuent leurs verrous verticalement du haut vers le bas. |
| 5 | **Lisibilité Immédiate en Dépannage** | En maintenance, un technicien survolant une ligne de bus dans CODESYS voit instantanément l'intégralité des états et verrous actifs via la bulle d'aide (tooltip). |

---

## 🚌 2. Standardisation des Bus de Données (Convention DUT)

Pour garantir une harmonie totale entre tous les domaines de la machine (Treuils M1/M2, Translation M3, Benne), nous posons une **convention de nommage et de structure en 5 familles de Bus** :

```text
 ┌─────────────────────────────────────────────────────────────────────────────────────────┐
 │                                   LA CONVENTION DES 5 BUS                               │
 ├───────────────────┬───────────────────────────┬─────────────────────────────────────────┤
 │ Famille de Bus    │ Préfixe DUT Obligatoire   │ Rôle & Contenu Synthétique              │
 ├───────────────────┼───────────────────────────┼─────────────────────────────────────────┤
 │ 🔌 E/S Physiques   │ `ST_HwIn_` / `ST_HwOut_`  │ Image unifiée terrain/simulation, bornes│
 │ 🕹️ Consignes      │ `ST_Cmd_`                 │ Ordres arbitrés (IHM, Joystick, Auto)   │
 │ 🛡️ Sécurité       │ `ST_Safety_`              │ Interlocks, SafeStop, PowerCutOff       │
 │ ⚙️ États Actionneur│ `ST_State_`               │ Ready, Busy, Done, Vitesse/Sens actifs  │
 │ 🕵️ Diagnostic      │ `ST_Diag_`                │ Error, ErrorId, Machine d'état, Alerte  │
 └───────────────────┴───────────────────────────┴─────────────────────────────────────────┘
```

### 📐 Règle de Composition Minimaliste d'un Bus
Chaque structure `DUT` doit respecter une organisation stricte à 3 niveaux :
1. **Validité / En-tête** : Bit de présence/validité du bus (`Valid: BOOL`, `Enable: BOOL`).
2. **Données Utiles** : Consignes ou valeurs physiques (ex: `SpeedRefPct: REAL`, `Direction: INT`).
3. **Codes / Masques** : Enums ou Word de statut (ex: `State: E_State`, `ErrorId: WORD`).

---

## 🗺️ 3. Organisation en Pages CFC Dédiées par Métier

Plutôt qu'un diagramme global illisible, la logique de l'automate s'organise en **3 vues/pages CFC spécialisées** :

### 📡 Page 1 : Acquisition, Simulation & Diagnostic Bus Network
- **Rôle** : Reçoit l'image matérielle brute `HwReal`, applique l'aiguillage simulation `HwSim` vers **`HwIn`**, et surveille l'état réseau des esclaves (Joystick CANopen, Codeurs EtherCAT, Variateur AC600).
- **Blocs principaux** : `instInputs`, `FB_DiagCanOpen`, `FB_DiagEthercat`.

### ↔️ Page 2 : Domaine Translation M3 (Variateur AC600)
- **Rôle** : Décode le mot des 5 capteurs TOR (`FB_Translation_PositionDecoder`), applique la sécurité haut (`FB_Safety_Translation`), arbitre les cibles (Trémie, PV, Maintenance), exécute la rampe et la conversion Hz (`FB_Translation`), et passe par la barrière finale de contrôle frein (`FB_TranslationOutputInterlock_LD`).
- **Blocs principaux** : `FB_Translation_PositionDecoder`, `FB_Safety_Translation`, `FB_Translation`, `FB_TranslationOutputInterlock_LD`.

### ⚖️ Page 3 : Domaine Treuils M1 & M2 (Retenue & Benne)
- **Rôle** : Gère la synchronisation de vitesse/position (`FB_WinchSync`), le décalage d'ouverture de benne (`FB_Bucket`), les sous-cycles d'assistance Plongée/Extraction (`FB_DiveSearch`, `FB_ExtractionSequence`), la sécurité mécanique et les 2 actionneurs `FB_WinchM1` et `FB_WinchM2`.
- **Blocs principaux** : `FB_Safety_Winch` (×2), `FB_WinchSync`, `FB_Bucket`, `FB_DiveSearch`, `FB_ExtractionSequence`, `FB_Winch` (×2), `FB_WinchOutputInterlock_LD` (×2).

---

## 🖼️ 4. Références des Diagrammes Visuels Générés

Toutes les illustrations visuelles de cette architecture ont été générées et enregistrées dans le projet sous :
- 📂 [DOC/DIAGRAMS/diagram1_acquisition_diag.jpg](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/DOC/DIAGRAMS/diagram1_acquisition_diag.jpg) : *Schéma 1 - Acquisition E/S & Diagnostic Bus.*
- 📂 [DOC/DIAGRAMS/cfc_m3_translation_detailed.jpg](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/DOC/DIAGRAMS/cfc_m3_translation_detailed.jpg) : *Schéma 2 - Page CFC Dédiée Translation M3.*
- 📂 [DOC/DIAGRAMS/cfc_m3_translation_oo_internal.jpg](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/DOC/DIAGRAMS/cfc_m3_translation_oo_internal.jpg) : *Schéma 3 - Composition Interne POO de FB_Translation.*
- 📂 [DOC/DIAGRAMS/diagram2_safety_action_chain.jpg](file:///C:/_MGS/DEV/2026_Projet_YGO_ExcavatriceDragage/DOC/DIAGRAMS/diagram2_safety_action_chain.jpg) : *Schéma 4 - Chaîne Globale Sécurité, Assistance & Actionneurs.*
