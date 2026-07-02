# Excavatrice de Dragage — Automate CODESYS 3.5

**Système de dragage en carrière noyée** — Pilotage d'un grappin sous-marin avec 2 treuils, chariot et sécurité intégrée.

---

## 📚 **Documentation Projet — À LIRE EN PRIORITÉ**

Tous les documents sont dans le dossier **`DOC/`** :

### 1️⃣ **[Convention de Nommage](DOC/NAMING_CONVENTION.md)** 
🔑 **ESSENTIEL** avant de coder.  
- PascalCase partout, **pas de hongrois** (`bFlag` ❌ → `Enable` ✅)
- Préfixes structurels : `ST_`, `E_`, `FB_`
- Booléens : entrée = verbe (`Start`), sortie = état (`Ready`)
- Exemples complets pour structures et instances

### 2️⃣ **[Analyse Fonctionnelle — Partie 1](DOC/AF_Partie1_Analyse_Fonctionnelle_v1.3.md)**
Le projet en bref : équipements pilotés, fonctions principales, interactions.

### 3️⃣ **[Analyse Fonctionnelle — Partie 2 (v2.6)](DOC/AF_Partie2_Architecture_Programme_v2.6.md)**
Architecture détaillée : cadencement (EtherCAT 4 / CANopen 20 / Main 10 ms), orchestration
séquentielle `PLC_PRG_MAIN`, mapping M1/M2/M3, modèle d'arrêt `SafeStop`/`StartStop`, `PowerCutOff`.

### 4️⃣ **[Analyse Fonctionnelle — Partie 3 (v1.2)](DOC/AF_Partie3_Template_FB_Commun_v1.2.md)**
Contrat standard que **tout FB métier respecte** :
- Interface VAR_INPUT/OUTPUT unifiée (`Enable`/`Reset`/`EmergencyStopOk`/`Mode`)
- FB de mouvement : `StartStop` (rampe normale) + `SafeStop` (rampe rapide, par métier)
- Machine d'état `E_State`
- Gestion `ErrorId` (bitfield)
- Logique Reset (front obligatoire, cause doit disparaître)
- Précédence `Enable` > `SafeStop` > `StartStop` ; AU matériel (seul arrêt brutal) + `PowerCutOff`

### 5️⃣ **Specs détaillées**
- **[Partie 4](DOC/AF_Partie4_Cycle_Sequenceur_v1.2.md)** — Cycle & séquenceur (`E_CycleStep`, INIT, synchro, frein, chariot, grappin, rampes).
- **[Partie 5](DOC/AF_Partie5_Modes_Maintenance_v1.1.md)** — Modes & maintenance (N1/N2, AU/`SafeStop`/`PowerCutOff`, limite légale gérée par `FB_Modes`).
- **[Partie 6](DOC/AF_Partie6_IO_Conditioning_v1.1.md)** — Conditionnement E/S.
- **[Partie 8](DOC/AF_Partie8_Fonction_Joystick_v1.1.md)** — Fonction métier Joystick (docs métier par FB en 8+).
- **[Audit de cohérence](DOC/AUDIT_Coherence_Documentaire_v1.0.md)** — Historique des décisions (`SafeStop`/`StartStop`/`EmergencyStopOk`, suppression `CoupeEnable`/`FB_Watchdog`…).

---

## 🏗️ **Structure du Projet**

```
excavatrice-dragage/
├── DOC/                      # 📖 Documentation (ICI COMMENCE)
│   ├── NAMING_CONVENTION.md
│   ├── AF_Partie1_Analyse_Fonctionnelle_v1.3.md
│   ├── AF_Partie2_Architecture_Programme_v2.6.md   (référence)
│   ├── AF_Partie3_Template_FB_Commun_v1.2.md
│   ├── AF_Partie4_Cycle_Sequenceur_v1.2.md
│   ├── AF_Partie5_Modes_Maintenance_v1.1.md
│   ├── AF_Partie6_IO_Conditioning_v1.1.md
│   ├── AF_Partie8_Fonction_Joystick_v1.1.md
│   └── AUDIT_Coherence_Documentaire_v1.0.md
│
├── CODE/                     # 🔧 Fichiers ST bruts, à copier/coller manuellement dans CODESYS
│   └── PRG_JOY1.st          (ex. — un fichier .st par POU/FB modifié)
│
├── PRJ_CODESYS/PROJ_Full_ImportExport/   # 📦 Projet CODESYS (export complet)
│   └── Device.export         (export manuel depuis CODESYS — source de vérité pour l'analyse)
│
└── README.md               # 👈 Vous êtes ici
```

---

## 🔄 **Workflow Édition**

Il n'y a **pas d'outillage d'extraction/injection automatique** (pas de script `extract`/`inject`,
pas de round-trip XML) : tout se fait **manuellement** dans CODESYS.

```
# 1. Dans CODESYS : Exporter le projet complet
#    → PRJ_CODESYS/PROJ_Full_ImportExport/Device.export
#    Ce fichier sert à analyser l'architecture existante (variables, PRG, FB, devices bus).

# 2. Le code ST à copier est écrit dans CODE/*.st (un fichier par POU/FB)
#    → voir la skill .claude/skills/codesys-workflow.md pour la procédure de génération

# 3. Coller manuellement le contenu de CODE/*.st dans l'éditeur CODESYS 3.5
#    (créer/recréer le POU en langage ST si besoin — voir la note d'application
#    de chaque doc métier, ex. DOC/AF_Partie8_..._v1.1.md §7)

# 4. Exporter à nouveau depuis CODESYS après validation → reboucle à l'étape 1
```

---

## ⚡ **Points Clés à Retenir**

| Concept | Important |
|---------|-----------|
| **Nommage** | Lire [NAMING_CONVENTION.md](DOC/NAMING_CONVENTION.md) d'abord — aucun hongrois, PascalCase strict |
| **Tâches** | EtherCAT 4 ms → CAN 20 ms → Main 10 ms ; surveillance périodicité = fonction système CODESYS (200 ms) |
| **FB Standard** | Tous les FB métier respectent le contrat [Partie 3](DOC/AF_Partie3_Template_FB_Commun_v1.2.md) (profils selon catégorie, §1bis) |
| **Sécurité** | `Enable` > `SafeStop` (par métier, rampe rapide) > `StartStop` (rampe normale) ; AU matériel = seul arrêt brutal + `PowerCutOff` ; Reset = front |
| **Cycle** | Semi-auto : `E_CycleStep` ([Partie 4](DOC/AF_Partie4_Cycle_Sequenceur_v1.2.md)) |

---

## 🚀 **Commencer**

1. **Lire [NAMING_CONVENTION.md](DOC/NAMING_CONVENTION.md)** ← commence ici
2. Consulter [AF_Partie1](DOC/AF_Partie1_Analyse_Fonctionnelle_v1.3.md) pour le contexte métier
3. Étudier [AF_Partie2 (v2.6)](DOC/AF_Partie2_Architecture_Programme_v2.6.md) pour l'architecture
4. Comprendre [AF_Partie3 (v1.2)](DOC/AF_Partie3_Template_FB_Commun_v1.2.md) avant de coder un FB
5. Approfondir [Partie 4](DOC/AF_Partie4_Cycle_Sequenceur_v1.2.md) / [5](DOC/AF_Partie5_Modes_Maintenance_v1.1.md) / [6](DOC/AF_Partie6_IO_Conditioning_v1.1.md)
6. Consulter [l'audit de cohérence](DOC/AUDIT_Coherence_Documentaire_v1.0.md) pour l'historique des décisions de conception

---

## 📖 **Références**

- **Git** : branche `claude/doc-review-automation-w4nrwp` (audit + mise à jour specs)
- **Langage** : CODESYS 3.5 (ST / Ladder / FBD)
- **Auteur** : Mathieu Gros
- **Dernière mise à jour** : 2026-07-01
