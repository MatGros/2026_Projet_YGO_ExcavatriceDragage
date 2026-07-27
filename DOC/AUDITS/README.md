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
| `RAPPORT_Audit_Persistance_Bypass_Frein_v1.0.md` | Persistance, RETAIN, bypasses & freins | **Actif** — rapport exhaustif **+ cahier d'essais** |
| `RevueTechnique/AUDIT_Revue_Technique_v1.0.md` | Revue automatisme / sécurité / IHM (2026-07-26) | **Actif** — C1 corrigé (`1d2e086`), **C2 à C7 non traités** |
| `IHM_VARIABLES_MIGRATION.md` | Correspondance ancien → nouveau chemin des variables IHM | **Vivant** — à tenir à jour à chaque lot, sert au reparamétrage IHM/SCADA physique |
| `WinchIhmButtons/` | Commandes IHM treuils sécurisées | **Actif** — validation et tests restant à clôturer |
| `Bypass/` (`v1.0`) | Homogénéisation & purge des bypasses globaux | **Actif** — correctif appliqué (MES-004), **qualification à planifier** |
| `CARTOGRAPHIE_Flux_IHM_Actionneurs_v1.0.md` | Chemin bouton/joystick → sécurité → sortie physique | **Référence** — support de débogage, décrit l'état du code |

## 📦 Archivé — plans terminés et implémentés

`../../ARCHIVES/Doc/AUDITS/`

| Dossier / fichier | Chantier | Clôture |
|---|---|---|
| `ConfigPersistence/` | Persistance config IHM (Lots 1-6) | `v0.4.26` — implémenté |
| `RemovePlcTests/` | Retrait du framework de tests in-PLC (plan + audit de vérification) | `v0.5.1` — implémenté, compilé, validé |
| `TranslationM3/` | Refonte positionnement & sécurités M3 (5 capteurs) | implémenté — `AF_Partie-11 v1.11`, `FB_Translation_PositionDecoder` |
| `PreLivraison/` | Chantier pré-livraison : rationalisation simulation (T80, L2→L8) + diagnostic (D1) — 5 plans, 8 fiches de tâche, 4 rapports | 2026-07-27 — **implémenté et validé**. Pilotage repris dans `PLAN_TASK` §1bis |
| `Winch/` | Audit Winch v1.0 | historique — actions reprises dans `PLAN_TASK` |
| `WinchCore/` | — | historique |
| `AF_Partie-14_PLC_Tests_Validation_v1.2.md` | Spec du framework de tests supprimé | `v0.5.1` |
| `TEST_FRAMEWORK_AUDIT_v1.0.md` | Audit du framework de tests supprimé | `v0.5.1` |

---

📌 `DOC/AUDIT_Coherence_Documentaire_v1.0.md` reste à la racine `DOC/` : c'est l'historique des
décisions de conception, référencé par les documents socle.
📌 Les actions à mener issues de ces audits sont suivies dans `DOC/PLAN_TASK_v1.0.md`.
📌 Les relevés terrain et essais sont consignés dans `DOC/REGISTRE_Suivi_MiseEnService_v1.0.md`.
