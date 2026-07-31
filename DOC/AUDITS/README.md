# 🔎 Audits

Rapports de revue **read-only** : constats, risques, recommandations.

## 📌 Règle de rangement (2026-07-26)

| | |
|---|---|
| **Reste ici** | Ce qui sert encore : cahiers d'essais, mise en service, constats non traités, docs de référence, migrations en cours |
| **Part en archive** | Les plans **terminés ET implémentés** → `../../ARCHIVES/Doc/AUDITS/` |

⚠️ `ARCHIVES/Doc/` est **gitignoré** : les fichiers restent sur disque et dans l'historique git,
mais ne suivent plus les évolutions du dépôt. On n'y range donc que du définitivement clos.

---

## 📂 Actif

| Dossier / fichier | Périmètre | Statut |
|---|---|---|
| `TABLE_Renommage_IO_v1.0.md` | Correspondance ancien → nouveau nom des variables d'E/S (convention de polarité) | **Vivant** — sert à retrouver un signal dans les schémas électriques et les REX antérieurs |
| `IHM_VARIABLES_MIGRATION.md` | Correspondance ancien → nouveau chemin des variables IHM | **Vivant** — à tenir à jour à chaque lot, sert au reparamétrage IHM/SCADA physique |

## 🎯 À quoi sert chaque document — pour reprendre le travail

> 📌 **L'ordre des travaux et l'état des tâches sont dans `../PLAN_TASK_v1.0.md`** (§1bis : ce qui
> est fait et les décisions actées · §3 : les reliquats `Txx` · §4 : la stratégie de mise en service).
> Ce README dit seulement **quel document ouvrir pour quelle tâche**.

| Document | Sert à | Tâches |
|---|---|---|
| `TABLE_Renommage_IO_v1.0.md` | Correspondance ancien → nouveau nom d'E/S. **§3bis porte la sémantique du Kobold à 3 temps** (hors eau `0` → immergé `1` → fond `0`) | **T81** · **T82** · tout retour à un schéma électrique ou un REX antérieur au 2026-07-27 |
| `IHM_VARIABLES_MIGRATION.md` | Journal ancien → nouveau chemin des variables IHM, pour le reparamétrage de la visu. **À tenir à jour à chaque lot** | **T94** · **T95** · toute publication IHM |

### 📚 Hors de ce dossier, mais indispensables

| Document | Sert à |
|---|---|
| `../REGISTRE_Suivi_MiseEnService_v1.0.md` | **Consigner chaque séance d'essai** (mesures, constats, décisions). C'est là que doivent aller les relevés de T89, T90, T92, T95 — pas dans une conversation |
| `../CHECKLISTS/CHECKLIST_MiseEnRoute_Simulation_v1.0.md` | Mode d'emploi du banc : activation par domaine, tests, retour en réel |
| `../AF_Partie-13_Fonction_Simulation_v2.0.md` · `../AF_Partie-14_Fonction_Troubleshooting_v1.0.md` | Architecture de la simulation · diagnostic `PRG_11` |

---

## 📦 Archivé — plans terminés et implémentés

`../../ARCHIVES/Doc/AUDITS/`

| Dossier / fichier | Chantier | Clôture |
|---|---|---|
| `RevueTechnique/AUDIT_Revue_Technique_v1.0.md` | Revue automatisme / sécurité / IHM | 2026-07-31 — archivé. C1/C2/C5 implémentés, C4/C6 suivis dans `PLAN_TASK` et `AF_Partie-10` |
| `ConfigPersistence/` | Persistance config IHM (Lots 1-6) | `v0.4.26` — implémenté |
| `RemovePlcTests/` | Retrait du framework de tests in-PLC (plan + audit de vérification) | `v0.5.1` — implémenté, compilé, validé |
| `TranslationM3/` | Refonte positionnement & sécurités M3 (5 capteurs) | implémenté — `AF_Partie-11 v1.11`, `FB_Translation_PositionDecoder` |
| `PreLivraison/` | Chantier pré-livraison : rationalisation simulation (T80, L2→L8) + diagnostic (D1) — 5 plans, 8 fiches de tâche, 4 rapports | 2026-07-27 — **implémenté et validé**. Pilotage repris dans `PLAN_TASK` §1bis |
| `Bypass/` | Homogénéisation des bypass globaux | 2026-07-23 — appliqué et validé (MES-004) |
| `WinchIhmButtons/` | Commandes IHM treuils | décisions actées, fonctions déjà couvertes |
| `CARTOGRAPHIE_Flux_IHM_Actionneurs_v1.0.md` | Chemin bouton → sécurité → sortie | 2026-07-24 — **périmée** : antérieure à `HwIn`, aux renommages E/S et à `PRG_11_Troubleshooting`, qui la remplace |
| `NAVBOARDS/` · `CHECKLIST_MiseEnService_JoystickTranslation` | Tables de repérage variables + cahier d'essais joystick/translation | 2026-07-27 — périmés (noms `GVL_IHM` obsolètes) ; repris par `PRG_11` et `PLAN_TASK` §4 |
| `RAPPORT_Audit_Persistance_Bypass_Frein_v1.0.md` | Persistance, RETAIN, bypass & freins | 2026-07-27 — correctifs TEST-05/06 livrés. Cahier d'essais extrait vers `../CHECKLISTS/CHECKLIST_Essais_Persistance_Bypass_Frein_v1.0.md` ; reste à faire suivi en T72/T92 |
| `Winch/` | Audit Winch v1.0 | historique — actions reprises dans `PLAN_TASK` |
| `WinchCore/` | — | historique |
| `AF_Partie-14_PLC_Tests_Validation_v1.2.md` | Spec du framework de tests supprimé | `v0.5.1` |
| `TEST_FRAMEWORK_AUDIT_v1.0.md` | Audit du framework de tests supprimé | `v0.5.1` |

---

📌 `ARCHIVES/Doc/AUDIT_Coherence_Documentaire_v1.0.md` reste à la racine `DOC/` : c'est l'historique des
décisions de conception, référencé par les documents socle.
📌 Les actions à mener issues de ces audits sont suivies dans `DOC/PLAN_TASK_v1.0.md`.
📌 Les relevés terrain et essais sont consignés dans `DOC/REGISTRE_Suivi_MiseEnService_20260724_v1.0.md`.
