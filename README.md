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
| Architecture programme (CFC, Ladder, tâches) | [ARCHIVES/Doc/AF_Partie-02_Architecture_Programme_v3.0.md](ARCHIVES/Doc/AF_Partie-02_Architecture_Programme_v3.0.md) |
| Contrats FB, DUT et CFC | [ARCHIVES/Doc/AF_Partie-03_Contrats_Composants_v2.0.md](ARCHIVES/Doc/AF_Partie-03_Contrats_Composants_v2.0.md) |
| Fonctions métier (une par FB, 08+) | Joystick · Encoder/Homing · Treuils (Benne incluse) · Translation · Simulation · Troubleshooting — voir [DOC/README.md](DOC/README.md) |
| Pilotage projet (tâches, reliquats, TBD) | [DOC/WFLOW/TASKS.yaml](DOC/WFLOW/TASKS.yaml) |

🚫 `ARCHIVES/` n'est **jamais** une source active — versions remplacées uniquement.

---

## 🏗️ Structure du Projet

```
excavatrice-dragage/
├── DOC/                        # 📖 Documentation active — voir DOC/README.md
│   ├── NAMING_CONVENTION.md
│   ├── CODE_QUALITY_STANDARDS.md
│   ├── VERSION_HISTORY.md      (versions CODESYS testées/validées)
│   ├── AF_Partie-01…14_*.md    (une AF par domaine, voir DOC/README.md pour le mapping)
│   ├── AF_Partie-09_Fonction_Encoder/    (fiches FB : Abs, Homing, Scale, Safety, SpeedMeasure, SpeedMonitor)
│   ├── AF_Partie-10_Fonction_Winch/      (fiches FB : Winch, Safety, Sync, OutputInterlock, Bucket, …)
│   ├── AF_Partie-11_Fonction_Translation/ (fiches FB : Translation, Safety, PositionDecoder, OutputInterlock)
│   ├── AUDITS/ · CHECKLISTS/ · DIA/
│   └── PLAN_TASK_v1.0.md       (pilotage : jalons, tâches, TBD/questions client)
│
├── CODE/                       # 🔧 Fichiers ST à importer dans CODESYS
│   ├── MAIN/                   # PRG_00_Inputs … PRG_11_Troubleshooting + pages CFC natives
│   ├── AU/                     # Chaîne arrêt d'urgence / EmergencyManagement
│   ├── CODEURS/                 # FB_Encoder_Abs/Homing/Scale/Safety/SpeedMeasure/SpeedMonitor (COD1/COD2)
│   ├── CYCLE/                   # E_CycleStep, FB_Cycle, FB_DiveSearch, FB_ExtractionSequence
│   ├── DIAG/                    # FB_Diag_CanOpen, FB_Diag_Ethercat, FB_Diag_IhmHeartbeat
│   ├── JOYSTICK/                 # FB_Joystick et briques associées
│   ├── MODES/                    # FB_Modes (N1/N2, limite légale)
│   ├── SIMULATION/               # FB_Sim_*, GVL_Simulation (bit maître + par device)
│   ├── SUPERVISION/               # Structures HMI (GVL_IHM, ST_*HMI)
│   ├── TRANSLATION/               # FB_Translation, FB_Safety_Translation (M3, AC600)
│   ├── TREUILS/                   # FB_Winch M1/M2, FB_Winch_Symmetry, BENNE/ (FB_Bucket)
│   ├── COMMUN/ · TESTS/           # FB_Ramp, FB_Brake, FB_Acquisition_Preflight… · bancs de test
│   └── CODE_Bundle.xml           # bundle PLCopenXML généré, voir TOOLS/
│
├── TOOLS/                       # 🔧 Outillage
│   ├── CONVERTER_ST2XML_PLCopenXML/  # Génération du bundle PLCopenXML depuis CODE/*.st
│   └── AGENT_WORKFLOW/           # Scripts de gate (check_linkage, check_doc_links, …), skills, workflow multi-agents
│
├── ARCHIVES/Tools/OUTILS_ST2PY/ # Suites de test Python générées depuis le ST (archivé, toujours exécutable — voir TOOLS/README.md)
│
├── PRJ_CODESYS/                # 📦 Projet CODESYS
│   └── PROJ_Full_ImportExport/Device.export  (export ponctuel — jamais une référence de contrôle)
│
└── README.md                   # 👈 Vous êtes ici
```

---

## 🔄 Workflow Édition

**⚠️ Important :** Voir [`AGENTS.md`](AGENTS.md) pour le workflow complet avec guardrails, règles
DOC et skill `codesys-workflow`. L'utilisateur applique **tout manuellement** dans CODESYS 3.5
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
| **FB Standard** | Tous les FB métier respectent le contrat [AF_Partie-03](ARCHIVES/Doc/AF_Partie-03_Contrats_Composants_v2.0.md) (profils selon catégorie, §1bis) |
| **Sécurité** | `Enable` > `SafeStop` (par métier, rampe rapide) > `StartStop` (rampe normale) ; AU matériel = seul arrêt brutal + `PowerCutOff` ; `Reset` = front |
| **Cycle** | Semi-auto : `E_CycleStep` ([AF_Partie-04](DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.1.md)) |

---

## 🚀 Commencer

1. **Lire [NAMING_CONVENTION.md](DOC/STDS/NAMING_CONVENTION.md)** ← commence ici
2. Consulter [DOC/README.md](DOC/README.md) pour l'index complet des spécifications actives
3. Charger la skill [`codesys-workflow`](.claude/skills/codesys-workflow.md) avant toute modif `CODE/`
4. Consulter [PLAN_TASK (v1.0)](DOC/WFLOW/TASKS.yaml) pour savoir ce qu'il reste à faire, trancher ou demander au client

---

## 📖 Références

- **Git** : branche `main`
- **Langage** : CODESYS 3.5 (ST / Ladder / FBD)
- **Outillage** : Skill `codesys-workflow` (`.claude/skills/codesys-workflow.md`) + `TOOLS/`
- **Auteur** : Mathieu Gros
- **Dernière mise à jour** : 2026-07-31
