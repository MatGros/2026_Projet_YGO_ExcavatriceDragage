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

### 2️⃣ **[Analyse Fonctionnelle — Partie 1](DOC/AF_Partie1_Analyse_Fonctionnelle_v1.1.md)**
Le projet en bref : équipements pilotés, fonctions principales, interactions.

### 3️⃣ **[Analyse Fonctionnelle — Partie 2 (v2.4)](DOC/AF_Partie2_Architecture_Programme_v2.4.md)**
Architecture détaillée : cadencement (EtherCAT 4 / CANopen 20 / Main 10 ms), orchestration
séquentielle `PLC_PRG_MAIN`, mapping M1/M2/M3, paradigme `CoupeEnable`, `PowerCutOff`.

### 4️⃣ **[Analyse Fonctionnelle — Partie 3 (v1.1)](DOC/AF_Partie3_Template_FB_Commun_v1.1.md)**
Contrat standard que **tout FB respecte** :
- Interface VAR_INPUT/OUTPUT unifiée (`Enable`/`Reset`/`SafetyOk`/`Mode`)
- Machine d'état `E_State`
- Gestion `ErrorId` (bitfield)
- Logique Reset (front obligatoire, cause doit disparaître)
- Arrêt sûr = retrait `Enable` (`CoupeEnable`) ; AU matériel + `PowerCutOff`

### 5️⃣ **Specs détaillées**
- **[Partie 4](DOC/AF_Partie4_Cycle_Sequenceur_v1.0.md)** — Cycle & séquenceur (`E_CycleStep`, INIT, synchro, frein, translation, godet, rampes).
- **[Partie 5](DOC/AF_Partie5_Modes_Maintenance_v1.0.md)** — Modes & maintenance (N1/N2, AU/`CoupeEnable`/`PowerCutOff`, limite légale).
- **[Partie 6](DOC/AF_Partie6_IO_Conditioning_v1.0.md)** — Conditionnement E/S.
- **[Partie 8](DOC/AF_Partie8_Fonction_Joystick_v1.0.md)** — Fonction métier Joystick (docs métier par FB en 8+).

---

## 🏗️ **Structure du Projet**

```
excavatrice-dragage/
├── DOC/                      # 📖 Documentation (ICI COMMENCE)
│   ├── NAMING_CONVENTION.md
│   ├── AF_Partie1_Analyse_Fonctionnelle_v1.1.md
│   ├── AF_Partie2_Architecture_Programme_v2.4.md   (référence)
│   ├── AF_Partie3_Template_FB_Commun_v1.1.md
│   ├── AF_Partie4_Cycle_Sequenceur_v1.0.md
│   ├── AF_Partie5_Modes_Maintenance_v1.0.md
│   ├── AF_Partie6_IO_Conditioning_v1.0.md
│   └── AF_Partie8_Fonction_Joystick_v1.0.md
│
├── CODE/                     # 🔧 Fragments POUs CODESYS (extract/inject)
│   ├── FB_Filter_PT1__*.xml
│   ├── PRG_JOY1__*.xml
│   └── _archive_plcopen/    (anciens fichiers)
│
├── PRJ_CODESYS/PROJ_Full_ImportExport/   # 📦 Projet CODESYS (export complet)
│   └── Device.export         (source de vérité)
│
├── tools/                    # 🛠️ Utilitaires
│   ├── extract.py           (extrait POUs → CODE/)
│   ├── inject.py            (réinjecte POUs modifiés de CODE/)
│   ├── codesys_common.py    (fonctions partagées)
│   └── README.md            (mode d'emploi)
│
├── extract.bat              # 💻 Raccourci Windows (→ tools/extract.py)
├── inject.bat               # 💻 Raccourci Windows (→ tools/inject.py)
│
└── README.md               # 👈 Vous êtes ici
```

---

## 🔄 **Workflow Édition**

Pour modifier du code en dehors de CODESYS :

```bash
# 1. Exporter depuis CODESYS → PRJ_CODESYS/PROJ_Full_ImportExport/Device.export

# 2. Extraire tous les POUs
extract.bat --yes
# ou : python tools/extract.py --yes

# 3. Éditer les fichiers XML dans CODE/ (via VS Code)
#    → modifier la déclaration VAR et/ou le corps ST

# 4. Réinjecter les changements
inject.bat
# ou : python tools/inject.py

# 5. Réimporter Device.export dans CODESYS
```

**Garanties :** GUID unique, round-trip exact, backup automatique.  
👉 Voir [tools/README.md](tools/README.md) pour les options complètes.

---

## ⚡ **Points Clés à Retenir**

| Concept | Important |
|---------|-----------|
| **Nommage** | Lire [NAMING_CONVENTION.md](DOC/NAMING_CONVENTION.md) d'abord — aucun hongrois, PascalCase strict |
| **Tâches** | EtherCAT 4 ms → CAN 20 ms → Main 10 ms ; watchdog 200 ms |
| **FB Standard** | Tous les FB respectent le contrat [Partie 3](DOC/AF_Partie3_Template_FB_Commun_v1.1.md) |
| **Sécurité** | Arrêt sûr = retrait `Enable` (`CoupeEnable`) ; AU matériel + `PowerCutOff` ; Reset = front |
| **Cycle** | Semi-auto : `E_CycleStep` ([Partie 4](DOC/AF_Partie4_Cycle_Sequenceur_v1.0.md)) |

---

## 🚀 **Commencer**

1. **Lire [NAMING_CONVENTION.md](DOC/NAMING_CONVENTION.md)** ← commence ici
2. Consulter [AF_Partie1](DOC/AF_Partie1_Analyse_Fonctionnelle_v1.1.md) pour le contexte métier
3. Étudier [AF_Partie2 (v2.4)](DOC/AF_Partie2_Architecture_Programme_v2.4.md) pour l'architecture
4. Comprendre [AF_Partie3 (v1.1)](DOC/AF_Partie3_Template_FB_Commun_v1.1.md) avant de coder un FB
5. Approfondir [Partie 4](DOC/AF_Partie4_Cycle_Sequenceur_v1.0.md) / [5](DOC/AF_Partie5_Modes_Maintenance_v1.0.md) / [6](DOC/AF_Partie6_IO_Conditioning_v1.0.md)

---

## 📖 **Références**

- **Git** : `main` branch (clean)
- **Langage** : CODESYS 3.5 (ST / Ladder / FBD)
- **Auteur** : Mathieu Gros
- **Dernière mise à jour** : 2026-06-30
