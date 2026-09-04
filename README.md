# Excavatrice de Dragage — Automate CODESYS 3.5

**Système de dragage en carrière noyée** — Pilotage d'un godet sous-marin avec 2 treuils, translation et sécurité intégrée.

---

## 📚 Documentation Projet — à lire en priorité

📌 **Index complet et à jour : [DOC/README.md](DOC/README.md)** — c'est la source unique pour
savoir quelle version d'une spec est active. Ce fichier ne la duplique pas (un index recopié deux
fois dérive toujours — voir `AGENTS.md`).

Point d'entrée agents (guardrails, workflow, délégation) : **[AGENTS.md](AGENTS.md)**.

### Repères rapides

| Sujet | Document |
|---|---|
| Nommage (PascalCase, préfixes, unités, polarité) | [DOC/STDS/NAMING_CONVENTION.md](DOC/STDS/NAMING_CONVENTION.md) |
| Déclaration, liaison, POO, non-régression | [DOC/STDS/CODE_QUALITY_STANDARDS.md](DOC/STDS/CODE_QUALITY_STANDARDS.md) |
| Architecture programme (7 POU, tâches, flux) | [DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md](DOC/AF/AF_Partie-02_Architecture_Programme_v3.2.md) |
| Contrats FB, DUT et composants | [DOC/AF/AF_Partie-03_Contrats_Composants_v2.3.md](DOC/AF/AF_Partie-03_Contrats_Composants_v2.3.md) |
| Fonctions métier (une par FB, 08+) | Joystick · Encoder/Homing · Treuils (Benne incluse) · Translation · Simulation · Troubleshooting — voir [DOC/README.md](DOC/README.md) |
| Pilotage projet (tâches, reliquats, TBD) | [DOC/WFLOW/TASKS.yaml](DOC/WFLOW/TASKS.yaml) |

🚫 `ARCHIVES/` n'est **jamais** une source active — versions remplacées uniquement.

---

## 🏗️ Structure du Projet

```
excavatrice-dragage/
├── DOC/                        # 📖 Documentation active — voir DOC/README.md
│   ├── STDS/                   # Standards (NAMING_CONVENTION.md, CODE_QUALITY_STANDARDS.md...)
│   ├── AF/                     # Spécifications d'analyses fonctionnelles (AF01..AF14)
│   ├── WFLOW/                  # Pilotage (TASKS.yaml, CONTRACTS/, AUDITS/...)
│   └── VERSION_HISTORY.md      (versions CODESYS testées/validées)
│
├── CODE/                       # 🔧 Fichiers ST par domaine normalisé
│   ├── A_COMMUN/               # Utilitaires, filtres, rampes, horloge de cycle
│   ├── B_AU_SECURITE/          # Chaîne arrêt d'urgence & EmergencyManagement
│   ├── C_DIAG_RESEAUX/         # Diagnostics EtherCAT / CANopen
│   ├── D_JOYSTICK/             # FB_Joystick & décodage
│   ├── E_CODEURS/              # FB_Encoder_Abs/Homing/Scale/Safety/Speed
│   ├── F_MODES/                # FB_Modes (N1/N2, limites légales)
│   ├── G_CYCLE/                # FB_CycleSemiAuto, Grafcet X0..X13, sous-cycles
│   ├── H_TREUILS_BENNE/        # FB_Winch M1/M2, BENNE/ (FB_Bucket)
│   ├── I_TRANSLATION/          # FB_Translation, FB_Safety_Translation (M3, AC600)
│   ├── J_SUPERVISION/          # Structures HMI (GVL_IHM, ST_*HMI, FB_Hmi_BannerFormatter)
│   ├── L_SIMULATION/           # FB_Sim_*, GVL_Simulation (bit maître + par device)
│   ├── M_MAIN/                 # PRG_02_Acquisition … PRG_07_Supervision + Main E2E
│   └── GVL_PERSISTENT.st       # NVRAM / Variables persistantes
│
├── CODE_XML/                   # 📦 Exports PLCopenXML & Bundle
│   └── CODE_Bundle.xml         # Bundle consolidé généré pour import CODESYS
│
├── TOOLS/                      # 🔧 Outillage de développement, validation & CI
│   ├── AGENT_WORKFLOW/         # Scripts de gates (G100..G483), skills, hooks
│   ├── COMPILER_ST2C_STruCpp/  # Compilateur ST → C++17 pour tests unitaires hors automate
│   ├── CONVERTER_ST2XML_PLCopenXML/ # Génération du bundle PLCopenXML depuis CODE/*.st
│   ├── LANCEURS/               # Scripts batch .bat exécutables
│   ├── LINTER_ST/              # Linter syntaxique & typage strict IEC 61131-3
│   ├── PLC_CSV_SNAPSHOT/       # Capture & snapshots CSV temps réel CODESYS
│   ├── TASK_MANAGER/           # Visualiseur & serveur web TASKS.yaml
│   └── TEST_AUTO_CI/           # Banc de test unitaire automatisé & suites Pytest
│
├── PRJ_CODESYS/                # 📦 Projet CODESYS
│   └── PROJ_Full_ImportExport/Device.export  (export ponctuel — jamais une référence de contrôle)
│
└── README.md                   # 👈 Vous êtes ici
```

---

## 🔄 Workflow Édition

**⚠️ Important :** Voir [`AGENTS.md`](AGENTS.md) pour le workflow complet avec guardrails et règles
DOC. L'utilisateur applique **tout manuellement** dans CODESYS 3.5
(copie du ST puis import PLCopenXML) — aucun outil ici n'écrit dans CODESYS.

Deux chemins possibles pour intégrer les modifs dans CODESYS 3.5 :

### 📋 Chemin 1 : Copier-coller manuel (rapide pour 1-2 fichiers)
```
1. Générer/modifier le code ST dans CODE/*.st (un fichier par POU/FB modifié)
2. Dans CODESYS 3.5, copier-coller le contenu dans l'éditeur
3. Exporter Device.export après validation
```

### 📦 Chemin 2 : Bundle PLCopenXML (pour modifs groupées)
```
1. Modifier le code ST dans CODE/*.st
2. python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
   → régénère CODE_XML/CODE_Bundle.xml
3. Dans CODESYS 3.5 : Project → Import PLCopenXML... → sélectionner CODE_Bundle.xml
4. Exporter Device.export après validation
```

### 🤖 Vérifications obligatoires avant de restituer un lot

```powershell
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report    # liaison réelle (BLOQUANT)
python TOOLS/AGENT_WORKFLOW/scripts/G340_check_doc_links.py            # liens/numérotation doc
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .  # bundle à jour
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py               # tous les gates
```

Détail : [DOC/STDS/CODE_QUALITY_STANDARDS.md §11](DOC/STDS/CODE_QUALITY_STANDARDS.md) (checklist de
restitution bloquante).

---

## ⚡ Points Clés à Retenir

| Concept | Important |
|---------|-----------|
| **Nommage** | Lire [NAMING_CONVENTION.md](DOC/STDS/NAMING_CONVENTION.md) d'abord — aucun hongrois, PascalCase strict |
| **Tâches** | EtherCAT 4 ms → CAN 20 ms → Main 10 ms ; surveillance périodicité = fonction système CODESYS (200 ms) |
| **FB Standard** | Tous les FB métier respectent le contrat [AF_Partie-03](DOC/AF/AF_Partie-03_Contrats_Composants_v2.3.md) (profils selon catégorie, §1bis) |
| **Sécurité** | `Enable` > `SafeStop` (par métier, rampe rapide) > `StartStop` (rampe normale) ; AU matériel = seul arrêt brutal + `PowerCutOff` ; `Reset` = front |
| **Cycle** | Semi-auto : `E_CycleStep` ([AF_Partie-04](DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md)) |

---

## 🚀 Commencer

1. **Lire [NAMING_CONVENTION.md](DOC/STDS/NAMING_CONVENTION.md)** ← commence ici
2. Consulter [DOC/README.md](DOC/README.md) pour l'index complet des spécifications actives
3. Consulter [`AGENTS.md`](AGENTS.md) avant toute modif `CODE/` (guardrails & standards)
4. Consulter [TASKS.yaml](DOC/WFLOW/TASKS.yaml) pour le suivi des tâches et jalons

---

## 📖 Références

- **Git** : branche `main` (ou branches de travail)
- **Langage** : CODESYS 3.5 (ST / Ladder / FBD)
- **Outillage** : [`AGENTS.md`](AGENTS.md) + `TOOLS/`
- **Auteur** : Mathieu Gros
- **Dernière mise à jour** : 2026-09-04
