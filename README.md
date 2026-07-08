# Excavatrice de Dragage — Automate CODESYS 3.5

**Système de dragage en carrière noyée** — Pilotage d'un godet sous-marin avec 2 treuils, translation et sécurité intégrée.

---

## 📚 **Documentation Projet — À LIRE EN PRIORITÉ**

Tous les documents sont dans le dossier **`DOC/`** :

### 1️⃣ **[Convention de Nommage](DOC/NAMING_CONVENTION.md)** 
🔑 **ESSENTIEL** avant de coder.  
- PascalCase partout, **pas de hongrois** (`bFlag` ❌ → `Enable` ✅)
- Préfixes structurels : `ST_`, `E_`, `FB_`
- Booléens : entrée = verbe (`Start`), sortie = état (`Ready`)
- Exemples complets pour structures et instances

### 2️⃣ **[Analyse Fonctionnelle — Partie 1 (v1.5)](DOC/AF_Partie1_Analyse_Fonctionnelle_v1.5.md)**
Le projet en bref : équipements pilotés, fonctions principales, interactions, sécurité électrique.

### 3️⃣ **[Analyse Fonctionnelle — Partie 2 (v2.10)](DOC/AF_Partie2_Architecture_Programme_v2.10.md)**
Architecture détaillée : cadencement (EtherCAT 4 / CANopen 20 / Main 10 ms), orchestration
séquentielle `PLC_PRG_MAIN`, mapping M1/M2/M3, modèle d'arrêt `SafeStop`/`StartStop`, `PowerCutOff`. **Référence projet.**

### 4️⃣ **[Analyse Fonctionnelle — Partie 3 (v1.3)](DOC/AF_Partie3_Template_FB_Commun_v1.3.md)**
Contrat standard que **tout FB métier respecte** :
- Interface VAR_INPUT/OUTPUT unifiée (`Enable`/`Reset`/`EmergencyStopOk`/`Mode`)
- FB de mouvement : `StartStop` (rampe normale) + `SafeStop` (rampe rapide, par métier)
- Machine d'état `E_State`
- Gestion `ErrorId` (bitfield)
- Logique Reset (front obligatoire, cause doit disparaître)
- Précédence `Enable` > `SafeStop` > `StartStop` ; AU matériel (seul arrêt brutal) + `PowerCutOff`

### 5️⃣ **Specs détaillées — Transverses & Sécurité**
- **[Partie 4 (v1.2)](DOC/AF_Partie4_Cycle_Sequenceur_v1.2.md)** — Cycle & séquenceur (`E_CycleStep`, synchro, frein, chariot, grappin, rampes).
- **[Partie 5 (v1.3)](DOC/AF_Partie5_Modes_Maintenance_v1.3.md)** — Modes & maintenance (N1/N2, AU/`SafeStop`/`PowerCutOff`, limite légale gérée par `FB_Modes`).
- **[Partie 6 (v1.5)](DOC/AF_Partie6_IO_Conditioning_v1.5.md)** — Conditionnement E/S.
- **[Partie 7 (v1.2)](DOC/AF_Partie7_Interface_IHM_v1.2.md)** — Interface HMI.

### 6️⃣ **Fonctions Métier (Partie 8+)**
- **[Partie 8 (v1.2)](DOC/AF_Partie8_Fonction_Joystick_v1.2.md)** — Fonction Joystick.
- **[Partie 9 (v1.7)](DOC/AF_Partie9_Fonction_Winch_v1.7.md)** — Fonction Winch (M1/M2, safety mou câble/thermique, garde-fous roue libre).
- **[Partie 10 (v1.7)](DOC/AF_Partie10_Fonction_Encoder_Homing_v1.7.md)** — Fonction Encoder & Homing.
- **[Partie 11 (v1.3)](DOC/AF_Partie11_Fonction_Chariot_v1.3.md)** — Fonction Chariot (M3 variateur AC600).
- **[Partie 12 (v1.2)](DOC/AF_Partie12_Fonction_Grappin_v1.2.md)** — Fonction Grappin (M2, désynchronisation, garde-fou glissement).
- **[Partie 13 (v1.1)](DOC/AF_Partie13_Fonction_Simulation_v1.1.md)** — Fonction Simulation.
- **[Audit de cohérence (v1.0)](DOC/AUDIT_Coherence_Documentaire_v1.0.md)** — Historique des décisions de conception.

---

## 🏗️ **Structure du Projet**

```
excavatrice-dragage/
├── DOC/                      # 📖 Documentation (ICI COMMENCE)
│   ├── NAMING_CONVENTION.md
│   ├── VERSION_HISTORY.md    (versions CODESYS testées/validées)
│   ├── AF_Partie1_Analyse_Fonctionnelle_v1.5.md
│   ├── AF_Partie2_Architecture_Programme_v2.10.md   (référence)
│   ├── AF_Partie3_Template_FB_Commun_v1.3.md
│   ├── AF_Partie4_Cycle_Sequenceur_v1.2.md
│   ├── AF_Partie5_Modes_Maintenance_v1.3.md
│   ├── AF_Partie6_IO_Conditioning_v1.5.md
│   ├── AF_Partie7_Interface_IHM_v1.2.md
│   ├── AF_Partie8_Fonction_Joystick_v1.2.md
│   ├── AF_Partie9_Fonction_Winch_v1.7.md
│   ├── AF_Partie10_Fonction_Encoder_Homing_v1.7.md
│   ├── AF_Partie11_Fonction_Chariot_v1.3.md
│   ├── AF_Partie12_Fonction_Grappin_v1.2.md
│   ├── AF_Partie13_Fonction_Simulation_v1.1.md
│   └── AUDIT_Coherence_Documentaire_v1.0.md
│
├── CODE/                     # 🔧 Fichiers ST à importer dans CODESYS
│   ├── PRG_*.st              (fichiers ST à copier-coller ou via bundle PLCopenXML)
│   ├── FB_*.st
│   └── CODE_Bundle.xml       (bundle PLCopenXML généré, voir PLCOPENXML_TOOLING/)
│
├── PLCOPENXML_TOOLING/       # 🔧 Génération bundle PLCopenXML (importation auto CODESYS)
│   └── (outillage Python pour grouper modifs CODE/*.st → CODE_Bundle.xml)
│
├── PRJ_CODESYS/              # 📦 Projet CODESYS
│   ├── PROJ_Full_ImportExport/Device.export  (export analyse architecture)
│   └── (fichiers .project, .device, simulation, etc.)
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
| **Cycle** | Semi-auto : `E_CycleStep` ([Partie 4](DOC/AF_Partie4_Cycle_Sequenceur_v1.1.md)) |

---

## 🚀 **Commencer**

1. **Lire [NAMING_CONVENTION.md](DOC/NAMING_CONVENTION.md)** ← commence ici
2. Consulter [AF_Partie1](DOC/AF_Partie1_Analyse_Fonctionnelle_v1.3.md) pour le contexte métier
3. Étudier [AF_Partie2 (v2.6)](DOC/AF_Partie2_Architecture_Programme_v2.6.md) pour l'architecture
4. Comprendre [AF_Partie3 (v1.2)](DOC/AF_Partie3_Template_FB_Commun_v1.2.md) avant de coder un FB
5. Approfondir [Partie 4](DOC/AF_Partie4_Cycle_Sequenceur_v1.1.md) / [5](DOC/AF_Partie5_Modes_Maintenance_v1.1.md) / [6](DOC/AF_Partie6_IO_Conditioning_v1.1.md)
6. Consulter [l'audit de cohérence](DOC/AUDIT_Coherence_Documentaire_v1.0.md) pour l'historique des décisions de conception

---

## 📖 **Références**

- **Git** : branche `claude/doc-review-automation-w4nrwp` (audit + mise à jour specs)
- **Langage** : CODESYS 3.5 (ST / Ladder / FBD)
- **Auteur** : Mathieu Gros
- **Dernière mise à jour** : 2026-07-01
