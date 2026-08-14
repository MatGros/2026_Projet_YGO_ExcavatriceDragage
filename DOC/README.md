# 📚 Documentation active

> Seuls les documents de référence courants restent sous `DOC/`.
> Les versions remplacées sont dans `../ARCHIVES/Doc/` — **jamais une source active**.

## 🧭 Standards transverses (à lire avant de coder)

| Document | Porte |
|---|---|
| Document | Porte |
|---|---|
| [STDS/CODE_QUALITY_STANDARDS.md](STDS/CODE_QUALITY_STANDARDS.md) | **Déclaration, liaison, POO, robustesse, non-régression** — propriétaire unique |
| [STDS/NAMING_CONVENTION.md](STDS/NAMING_CONVENTION.md) | Nommage normatif (préfixes, unités, polarité, construction d'un nom) |
| [WFLOW/AUDITS/REX_Nommage_v1.0.md](WFLOW/AUDITS/REX_Nommage_v1.0.md) | 📖 *Non normatif* : incidents fondateurs, chantiers différés, décisions rejetées |
| [Sample CFC natif](../TOOLS/SAMPLES_CODESYS/PRG_CFC_3FB.xml) | Structure PLCopenXML exportée par CODESYS ; procédure normative dans AF_Partie-03 §5 |
| [Guide configuration IDE CODESYS](STDS/GUIDES/GUIDE_CONFIGURATION_IDE_CODESYS_v1.0.md) | Raccourcis clavier perso (`Ctrl+R` réduire tout, `Ctrl+E` étendre tout) et chemin de configuration |

## 📐 Spécifications fonctionnelles (sous `AF/`)

| N° | Sujet |
|---|---|
| 01 | Analyse fonctionnelle — équipements, sécurité électrique |
| 02 | **Architecture programme — source unique de l'architecture cible** (7 POU par procédé, `MainTask`, flux) |
| 03 | Template FB commun — contrat d'interface |
| 04–06 | Mode semi-auto & séquenceur · Modes & maintenance · Acquisition & qualification I/O |
| 07 | Interface IHM |
| 08+ | Une fonction métier par domaine : 08 Joystick · 09 Encoder/Homing · 10 Treuils (**Benne incluse**) · 11 Translation · 12 Diagnostic · 13 Simulation · 14 Troubleshooting |

⚠️ **Historique de numérotation** : le numéro 11 a d'abord été celui de la Translation, puis de la Benne, puis a été retiré. Il est désormais réattribué à la Translation (P11). La Benne est une fiche du domaine Treuils : [`AF/AF_Partie-10_Fonction_Winch/FB_Bucket_v1.0.md`](AF/AF_Partie-10_Fonction_Winch/FB_Bucket_v1.0.md). Contrôlé automatiquement (règle `D7` de `G340_check_doc_links.py`).

Les domaines `09`, `10`, `11` et `12` sont **éclatés en une fiche par FB** dans un sous-dossier
`AF/AF_Partie-NN_.../` ; le fichier `_vX.Y.md` reste le **chapô** (rôle machine, intégration programme).

👉 Toujours ouvrir la version `_vX.Y` **la plus élevée**. Les renvois sont maintenus
automatiquement par `python TOOLS/AGENT_WORKFLOW/scripts/G340_check_doc_links.py --fix`.

## 🗺️ Architecture cible — une seule source

> ⚠️ **`AF_Partie-02` §2 et §4 sont la source unique de la table `MainTask`.**
> Un document qui proposerait une autre table est périmé : ne pas le suivre, le signaler.

Découpage **par ensemble mécanique**, pas par couche transverse. Chaque procédé porte sa safety
dans sa propre page, visible à côté des blocs métier.

| Rang | POU cible |
|---|---|
| 01 | `PRG_02_Acquisition` — acquisition unique, HwReal/HwSim/HwIn, codéurs, diagnostics, auxiliaires, état AU (ST pur) |
| 02 | `PRG_03_Modes_Cycle` — (ST pur) |
| 03 | `PRG_04_Treuils_Benne` — safety M1/M2 intégrée (ST pur) |
| 04 | `PRG_05_Translation` — safety M3 intégrée (ST pur) |
| 05 | `PRG_06_Outputs_LD` — agrège `PowerCutOff` |
| 06 | `PRG_07_Supervision` — absorbe le troubleshooting, lecture seule stricte (ST pur) |

🚫 **Vocabulaire abandonné** — ces POU n'existent pas dans la cible et ne doivent pas être
reconstruits : `PRG_SAFETY_CFC` (ou toute page safety séparée), `PRG_01_Diagnostics`,
`PRG_02_Encoders`, `PRG_AUXILIARY_CFC`, `PRG_TROUBLESHOOTING_CFC` / `PRG_11_Troubleshooting`.
Ils restent des **POU du code actuel**, cibles de migration, jamais des cibles d'architecture.

## 🗂️ Pilotage et traçabilité

| Type | Source active |
|---|---|
| Pilotage / reliquats / TBD | [WFLOW/PLAN_TASK.md](WFLOW/PLAN_TASK.md) |
| Historique CODE ↔ DOC | [VERSION_HISTORY.md](VERSION_HISTORY.md) |
| Décisions de conception | [ARCHIVES/Doc/AUDIT_Coherence_Documentaire_v1.0.md](../ARCHIVES/Doc/AUDIT_Coherence_Documentaire_v1.0.md) (archive) |
| Mise en service | [TESTS/REGISTRES/REGISTRE_Suivi_MiseEnService.md](TESTS/REGISTRES/REGISTRE_Suivi_MiseEnService.md) |
| Post-mise en service | [TESTS/REGISTRES/REGISTRE_Suivi_PostMES.md](TESTS/REGISTRES/REGISTRE_Suivi_PostMES.md) |
| Fiches d'essais | `TESTS/CHECKLISTS/` · Audits ouverts : `WFLOW/AUDITS/` · Schémas : `DIA/` |
| Décision d'architecture actée | [WFLOW/AUDITS/Architecture/RU_C4_ARCHITECTURE_PROCEDES.md](WFLOW/AUDITS/Architecture/RU_C4_ARCHITECTURE_PROCEDES.md) |
| Plan d'exécution de la migration | [WFLOW/AUDITS/Architecture/PLAN_EXECUTION_MIGRATION_7POU.md](WFLOW/AUDITS/Architecture/PLAN_EXECUTION_MIGRATION_7POU.md) |

## 🧪 Points de validation (`TC-`)

Chaque AF active porte un tableau `## 🧪 Points de validation` juste après le sommaire.

| Colonne | Sens |
|---|---|
| `ID` | Stable : `TC-Pxx-nnn` (≠ `Txx` de `PLAN_TASK`) |
| `Attendu` | Comportement machine en 1 phrase |
| `Preuve` | Observation / sortie / état à vérifier |
| `Type` | `AUTO` · `SITE` · `AUTO+SITE` |
| `Détail` | Renvoi § AF, sans recopier la spec |

Les résultats d'exécution restent hors AF : scripts ST→Python, checklists site, registres MES.

## 📏 Règles de versionnement

- **Une seule** version par Partie sous `DOC/` — l'ancienne part dans `../ARCHIVES/Doc/`
  (contrôlé automatiquement : `G340_check_doc_links.py` avertit si deux versions coexistent).
- La version v2.1 de l'acquisition décrit la cible documentaire ; le code reste en phase transitoire
  jusqu'à validation humaine du remappage et du filtrage.
- Jamais d'écrasement : nouvelle version = nouveau fichier `_vX.Y`.
- Aucune fusion d'ancienne version n'est autorisée.
