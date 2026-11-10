# 📚 Documentation active

> Seuls les documents de référence courants restent sous `DOC/`.
> Les versions remplacées sont dans `../ARCHIVES/Doc/` — **jamais une source active**.

## 🧭 Standards transverses (à lire avant de coder)

| Document | Porte |
|---|---|
| [STDS/CODE_QUALITY_STANDARDS.md](STDS/CODE_QUALITY_STANDARDS.md) | **Déclaration, liaison, POO, robustesse, non-régression** — propriétaire unique |
| [STDS/NAMING_CONVENTION.md](STDS/NAMING_CONVENTION.md) | Nommage normatif (préfixes, unités, polarité, construction d'un nom) |
| [STDS/TWINBENCH_SIGNAL_CONVENTION_v1.0.md](STDS/TWINBENCH_SIGNAL_CONVENTION_v1.0.md) | Contrat signaux OpenModelica/FMU/IHM : causalité, flux industriel, qualité et traçabilité |
| [Sample CFC natif](../TOOLS/SAMPLES_XML_CODESYS/PRG_CFC_3FB.xml) | Structure PLCopenXML exportée par CODESYS ; procédure normative dans AF_Partie-03 §5 |
| [Guide configuration IDE CODESYS](STDS/GUIDES/GUIDE_CONFIGURATION_IDE_CODESYS_v1.0.md) | Raccourcis clavier perso (`Ctrl+R` réduire tout, `Ctrl+E` étendre tout) et chemin de configuration |
| [Guide Visualisation CODESYS](STDS/GUIDES/GUIDE_VISUALISATION_CODESYS_v1.0.md) | IHM intégrée à l'IDE : commandes selon type de Visu/élément, événements, pièges, règles projet |

## 📐 Spécifications fonctionnelles (sous `AF/`)

| N° | Sujet |
|---|---|
| 01 | Analyse fonctionnelle — équipements, sécurité électrique |
| 02 | **Architecture programme — source unique de l'architecture cible** (POU par procédé, `MainTask`, flux) |
| 03 | Template FB commun — contrat d'interface |
| 04–06 | Mode semi-auto & séquenceur · Modes & maintenance · Acquisition & qualification I/O |
| 07 | Interface IHM |
| 08+ | Une fonction métier par domaine : 08 Joystick · 09 Encoder/Homing · 10 Treuils (**Benne incluse**) · 11 Translation · 12 Diagnostic · 13 Simulation · 14 Troubleshooting |

- Les domaines `09` à `12` sont **éclatés en une fiche par FB** dans `AF/AF_Partie-NN_.../` ; le fichier `_vX.Y.md` reste le **chapô** (rôle machine, intégration programme).
- ⚠️ Numéro 11 = Translation (P11). La Benne est une fiche du domaine Treuils : [`FB_Bucket_v1.0.md`](AF/AF_Partie-10_Fonction_Winch/FB_Bucket_v1.0.md). Contrôlé par la règle `D7` de `G340_check_doc_links.py`.
- 👉 Toujours ouvrir la version `_vX.Y` **la plus élevée**. Renvois maintenus par `python TOOLS/AGENT_WORKFLOW/scripts/G340_check_doc_links.py --fix`.

## 🗺️ Architecture cible — une seule source

> ⚠️ **`AF_Partie-02` §2 et §4 sont la source unique de la table `MainTask`.**
> Un document qui proposerait une autre table est périmé : ne pas le suivre, le signaler.

Découpage **par ensemble mécanique**, pas par couche transverse : chaque procédé porte sa safety dans sa propre page.
🚫 `PRG_SAFETY_CFC` (ou toute page safety séparée), `PRG_01_Diagnostics`, `PRG_02_Encoders`, `PRG_AUXILIARY_CFC`,
`PRG_TROUBLESHOOTING_CFC` / `PRG_11_Troubleshooting` sont du **vocabulaire abandonné** : ne pas les reconstruire.

## 🗂️ Pilotage et traçabilité

| Besoin | Source active |
|---|---|
| Catalogue des tâches et contrats | [WFLOW/TASKS.yaml](WFLOW/TASKS.yaml) · contrats : `WFLOW/CONTRACTS/` |
| Historique CODE ↔ DOC | [VERSION_HISTORY.md](VERSION_HISTORY.md) (une ligne par jalon) |
| Mise en service | `WFLOW/REGISTRES/REGISTRE_Suivi_MiseEnService_<date>.md` (un registre par séance) |
| Rapports d'orchestration | [WFLOW/ORCHESTRATION_RAPPORTS/](WFLOW/ORCHESTRATION_RAPPORTS/) |
| Audits · REX · schémas | `WFLOW/AUDITS/` · `WFLOW/REX/` · `DIA/` |
| Agent Supervisor — tâche et preuves | [WFLOW/ETUDES/PLAN_AGENT_SUPERVISOR_REPRISE_TRANSCRIPT_ET_PLUGIN.md](WFLOW/ETUDES/PLAN_AGENT_SUPERVISOR_REPRISE_TRANSCRIPT_ET_PLUGIN.md) |

## 🧪 Points de validation (`TC-`)

Chaque AF active porte un tableau `## 🧪 Points de validation` juste après le sommaire.
`ID` stable `TC-Pxx-nnn` (≠ `Txx` des tâches) · `Attendu` (1 phrase) · `Preuve` · `Type` (`AUTO` · `SITE` · `AUTO+SITE`) · `Détail` (renvoi § AF, sans recopier la spec).
Les résultats d'exécution restent hors AF : scripts ST→Python, checklists site, registres MES.

## 📏 Règles de versionnement

- **Une seule** version par Partie sous `DOC/` — l'ancienne part dans `../ARCHIVES/Doc/` (G340 avertit si deux versions coexistent).
- Jamais d'écrasement : nouvelle version = nouveau fichier `_vX.Y`. Aucune fusion d'ancienne version.
