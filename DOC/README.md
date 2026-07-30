# 📚 Documentation active

> Seuls les documents de référence courants restent sous `DOC/`.
> Les versions remplacées sont dans `../ARCHIVES/Doc/` — **jamais une source active**.

## 🧭 Standards transverses (à lire avant de coder)

| Document | Porte |
|---|---|
| [CODE_QUALITY_STANDARDS.md](CODE_QUALITY_STANDARDS.md) | **Déclaration, liaison, POO, robustesse, non-régression** — propriétaire unique |
| [NAMING_CONVENTION.md](NAMING_CONVENTION.md) | Nommage normatif (préfixes, unités, polarité, construction d'un nom) |
| [AUDITS/REX_Nommage_v1.0.md](AUDITS/REX_Nommage_v1.0.md) | 📖 *Non normatif* : incidents fondateurs, chantiers différés, décisions rejetées |

## 📐 Spécifications fonctionnelles

| N° | Sujet |
|---|---|
| 01 | Analyse fonctionnelle — équipements, sécurité électrique |
| 02 | Architecture programme — tâches, arborescence, flux |
| 03 | Template FB commun — contrat d'interface |
| 04–06 | Mode semi-auto & séquenceur · Modes & maintenance · Acquisition & qualification I/O |
| 07 | Interface IHM |
| 08+ | Une fonction métier par FB : 08 Joystick · 09 Winch · 10 Encoder/Homing · 11 Translation · 12 Benne · 13 Simulation · 14 Troubleshooting |

👉 Toujours ouvrir la version `_vX.Y` **la plus élevée**. Les renvois sont maintenus
automatiquement par `python TOOLS/AGENT_WORKFLOW/scripts/check_doc_links.py --fix`.

## 🗂️ Pilotage et traçabilité

| Type | Source active |
|---|---|
| Pilotage / reliquats / TBD | [PLAN_TASK_v1.0.md](PLAN_TASK_v1.0.md) |
| Historique CODE ↔ DOC | [VERSION_HISTORY.md](VERSION_HISTORY.md) |
| Décisions de conception | [AUDIT_Coherence_Documentaire_v1.0.md](AUDIT_Coherence_Documentaire_v1.0.md) |
| Mise en service | [REGISTRE_Suivi_MiseEnService_20260724_v1.0.md](REGISTRE_Suivi_MiseEnService_20260724_v1.0.md) |
| Post-mise en service | [REGISTRE Post-MES](REGISTRE_Suivi_PostMiseEnService_Livraison10Aout_20260728_v1.0.md) |
| Fiches d'essais | `CHECKLISTS/` · Audits ouverts : `AUDITS/` · Schémas : `DIAGRAMS/` |

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
  (contrôlé automatiquement : `check_doc_links.py` avertit si deux versions coexistent).
- Jamais d'écrasement : nouvelle version = nouveau fichier `_vX.Y`.
- Aucune fusion d'ancienne version n'est autorisée.
