## Méthode et limites

- **Corpus** : 53 fichiers tous `tracked: true` → l’historique Git est disponible pour chaque chemin ; une suppression reste réversible.
- **Statuts** : j’ai utilisé les statuts du catalogue fournis dans le corpus (`✅`, `⬜`, `⏳`, `❌`, `⏸️`). Ils font foi pour le pilotage, mais ne prouvent pas l’état machine.
- **IDs** : j’ai distingué la tâche principale des IDs incidents du corps (ex. `T1`/`T2` dans les CSV T356 sont des tiers de candidats, pas des tâches).
- **Références entrantes** : les listes `incoming` sont lexicales, pas des dépendances prouvées ; je ne les ai pas traitées comme telles.
- **Aucune suppression effectuée** : le tableau est une recommandation.

---

## Tableau d’analyse — 53 chemins

| # | Chemin | Verdict | Tâches / statuts | Justification concrète | Références à réparer / conditions |
|---:|---|---|---|---|---|
| 1 | `DOC/WFLOW/AUDITS/T356_ALARMES_20260921/T356_univers_complet.csv` | **CONDITIONNEL** | T356 ✅ | Artefact brut du scan (572 candidats, 240 Ko). Le rapport `AUDIT_T356…md` et les CSV qualifiés portent la synthèse. Valeur = rejouer/étendre l’audit. | Conserver tant que `T356_scan_alarm_candidates.py` est maintenu ; sinon supprimable (Git). Vérifier qu’aucune analyse aval ne cite ce CSV comme source unique. |
| 2 | `DOC/WFLOW/AUDITS/DESIGN/CADRAGE_T330_INVARIANT_HAUT_v1.0.md` | **GARDER** | T330 ✅ | Décisions Q1–Q28, preuves `fichier:ligne`, 8 pièges d’implémentation, conflit G483. Référence unique du cadrage. | Aucune. |
| 3 | `DOC/WFLOW/AUDITS/DESIGN/CHALLENGE_T340_REFONTE_HOMING_2026-09-20.md` | **CONDITIONNEL** | T340 ❌ (remplacé T364/T377) | Faits uniques (D1–D6, MecaD, impasse HX3, Plan B) mais conception abandonnée et code retiré par T364. | Vérifier que T364/T377 reprennent explicitement les constats D1–D6 et l’impasse HX3 ; sinon extraire les faits avant archivage. |
| 4 | `DOC/WFLOW/AUDITS/DESIGN/PLAN_T330_C3_INVARIANT_HAUT_v1.0.md` | **CONDITIONNEL** | T330 ✅, T341 ⬜, T343/T344 | Spécification des règles R0–R3 et des 37 TC ; partiellement implémentée (21/37 par T341). | Garder tant que T341/T343/T344 ne sont pas clos ; ensuite archiver (Git). Vérifier que T343 reprend bien les 16 cas sortis. |
| 5 | `DOC/WFLOW/AUDITS/AUDIT_T422_DEVICES_ALARMS_20261030.yaml` | **GARDER** | T422 ✅ | Registre pérenne explicitement créé par T422 (194 défauts, 10 Devices). | Aucune. |
| 6 | `DOC/WFLOW/AUDITS/DESIGN/AUDIT_T300_TRACE_20260904_v1.0.md` | **GARDER** | T300 ✅, T333 ✅, T301 ⬜ | Preuve primaire de la trace 2026-09-04 : gain 0,0551, 3 échelles incompatibles, 12 oracles R2. T301 (calibration) toujours ouverte. | Aucune. |
| 7 | `DOC/WFLOW/AUDITS/AUDIT_T356_ALARMES_EXHAUSTIF_20260921.md` | **GARDER** | T356 ✅ | Rapport final, tableau qualifié 119 défauts, 25 muets dont 16 safety, 11 entrées fantômes. | Aucune. |
| 8 | `DOC/WFLOW/AUDITS/DESIGN/DIAGNOSTIC_T346_BORNE_RECUL_2026-09-20.md` | **GARDER** | T346 ⬜ | Diagnostic des 6 défauts D1–D6, dont D6 (détection de glissement M1) ; phase 2 livrée non commitée. | Aucune. |
| 9 | `DOC/WFLOW/AUDITS/T356_ALARMES_20260921/T356_bandeau_libelles.csv` | **CONDITIONNEL** | T356 ✅ | Extraction brute des 116 libellés du carrousel ; le rapport les cite. | Artefact de scan : conserver si l’audit doit être rejoué ; sinon Git suffit. Vérifier qu’aucun libellé unique n’est absent du rapport. |
| 10 | `DOC/WFLOW/AUDITS/DESIGN/AUDIT_TRIAGE_WINCH_INTEG_20260922.md` | **GARDER** | T385 ⬜, T382 ⬜ | Diagnostic des 27 échecs CI, défaut réel CAS-001 (HARN-80), convergence T169-A. Alimente T385/T382. | Aucune. |
| 11 | `DOC/WFLOW/AUDITS/DESIGN/AF10_INTERFACE_TREUIL_CIBLE_T181.md` | **GARDER** | T181-06 | Document de référence de l’interface cible ; fait foi pour T181-06. | Aucune. |
| 12 | `DOC/WFLOW/AUDITS/DESIGN/CHALLENGE_T262_PHASE_B_SEUIL_BENNE_2026-09-21.md` | **GARDER** | T262 ⬜ | Décisions D1/D2/D3 et piège de la conjonction `CloseReached` ; recette machine non faite. | Aucune. |
| 13 | `DOC/WFLOW/AUDITS/DESIGN/SPEC_HARNESS_INTEG_TREUIL_T181-00_v0.1.md` | **GARDER** | T181-00 | Spec du harnais d’intégration ; le harnais est un stub à reconstruire (T372/T384). | À rapprocher explicitement de T372/T384. |
| 14 | `DOC/WFLOW/AUDITS/T332_HOOKS_CLAUDE_CODE_20260920.md` | **GARDER** | T332 ⬜ | Diagnostic durable, correction non appliquée (AC3 non atteint), preuve par empreinte. | Aucune. |
| 15 | `DOC/WFLOW/AUDITS/PRG0405_AUDIT_B_20260831.md` | **CONDITIONNEL** | Aucune tâche porteuse identifiée | Contre-audit qui corrige l’audit A ; constat safety `FB_WinchRateInterlock` absent et `SpeedGuardEnable := FALSE`. | Vérifier si le constat safety est toujours valide et couvert par T181-01 ; sinon créer une tâche dédiée. |
| 16 | `DOC/WFLOW/AUDITS/DESIGN/CADRAGE_T181-06_DRIVEREQUEST.md` | **GARDER** | T181-06 | Cadrage des DUT et décisions (clamp, précédence, M2-only) ; référence d’interface. | Aucune. |
| 17 | `DOC/WFLOW/AUDITS/PRG0405_AUDIT_A_2026-08-31.md` | **CONDITIONNEL** | Aucune tâche porteuse identifiée | Audit périmé sur les extractions déjà faites (corrigé par B), mais liste P1–P7 dont P1/P3/P4/P6/P7 non faites. | Vérifier si les pistes non réalisées sont reprises ailleurs ; sinon extraire avant archivage. |
| 18 | `DOC/WFLOW/AUDITS/DESIGN/AUDIT_T370_MATRICE_DISCORDANCES_20260922.md` | **GARDER** | T370 ⬜, T288 ⬜ | Matrice des discordances contacteurs, phase 1 de T370 ; aucun code avant choix humain. | Aucune. |
| 19 | `DOC/WFLOW/AUDITS/GEL_GRAFCET_HOMING_CYCLE_20260903.md` | **CONDITIONNEL** | T364 ✅, T226 ⬜ | Brouillon non validé, contredit par T364 (3 appuis vs 1 appui) ; principes GRAFCET peut-être uniques. | Vérifier si les principes (`V_CONTINU`/`V_EXPLICITE`, C4 M3 interdit) sont repris dans T364/AF-04 ; sinon extraire puis archiver. |
| 20 | `DOC/WFLOW/AUDITS/DESIGN/DESIGN_T144B_INTERFACES_PRG6_v0.1.md` | **CONDITIONNEL** | T144, T181-01 | Étude de design non validée ; décisions Q1–Q5 à trancher (variante A/B, D2-A, D3-A). | Vérifier statut T144 et si le contenu est repris dans T181-01. |
| 21 | `DOC/WFLOW/AUDITS/DESIGN/PLAN_T204enforcement_permits_M3.md` | **CONDITIONNEL** | T204, T184 | Plan d’exécution avec arrêts de validation ; T204 absent du corpus des tâches fournies. | Vérifier si T204 est toujours au catalogue et si T184 est clos. |
| 22 | `DOC/WFLOW/AUDITS/AUDIT_T360_TRACE_RATIO_ESTIMATEUR_M3_20260921.md` | **GARDER** | T360 ✅, T333 ✅, T301 ⬜ | Preuve de la trace Suivi_74 : ratio 11,25, validation T333 dans les deux sens. | Aucune. |
| 23 | `DOC/WFLOW/AUDITS/CONTACTEURS_DIAG_2026-08-31.md` | **CONDITIONNEL** | Aucune tâche porteuse identifiée | Diagnostic unique (one-hot, table contournée, palier 5 = tout coupé) non rattaché à une tâche. | Vérifier si le défaut est corrigé ; sinon créer une tâche safety dédiée. |
| 24 | `DOC/WFLOW/AUDITS/ETUDE_T260_STEP_PREVALIDATION_BENNE_HOMING.md` | **CONDITIONNEL** | T260 | Étude de conception, questions Q1–Q10 non tranchées. | Vérifier si T260 est au catalogue et si les décisions sont prises ; sinon archiver. |
| 25 | `DOC/WFLOW/AUDITS/PRG06_AUDIT_20260831.md` | **CONDITIONNEL** | Aucune tâche porteuse identifiée | Audit sécurité PRG_06 ; A1 (gate frein M1/M2) et A2 (`SafetyStructureNotValidated`) à solder. | Vérifier si A1/A2 sont traités ; sinon rattacher à une tâche. |
| 26 | `DOC/WFLOW/AUDITS/DESIGN/PLAN_T208coherence_ActiveOffsetM_benne.md` | **SUPPRIMER** | T208 ✅ (absorbée T241) | Plan clos, contenu repris par T241/AF-10. | Vérifier que T241 a bien documenté `StateIncoherent` avant suppression ; historique Git. |
| 27 | `DOC/WFLOW/AUDITS/GEL_GRAFCET_SEMIAUTO_AMENDEMENT_T383_20260922.md` | **GARDER** | T383 ⬜, T331 ⬜ | Amendement validé par l’exploitant, référentiel de T383 (AC6). | Aucune. |
| 28 | `DOC/WFLOW/AUDITS/WT3-T173_RAPPORT_BANC_SIMULATION_20260828.md` | **CONDITIONNEL** | T173 | Rapport de banc outil ; la revue T173 (fichier 48) le corrige. | Vérifier si le banc est maintenu et si les corrections de la revue sont appliquées ; sinon archiver. |
| 29 | `DOC/WFLOW/AUDITS/DESIGN/PLAN_T213troubleshooting_homing_M2.md` | **GARDER** | T213 ⬜ | Plan prêt, arrêt validation humaine avant code. | Aucune. |
| 30 | `DOC/WFLOW/AUDITS/DESIGN/CHALLENGE_T300_PA_PLAN_SIMBENCH_M3_v1.0.md` | **CONDITIONNEL** | T300 ✅, T328 ✅ | Challenge consommé par T300 ; décisions (frein 0,5 Hz, mémoire de sens) à vérifier dans le code. | Vérifier que les décisions sont dans le code/tests ; sinon garder comme preuve de revue. |
| 31 | `DOC/WFLOW/AUDITS/DESIGN/PREUVE_T345_L1_MECANISME_ARRET_AXE_2026-09-21.md` | **CONDITIONNEL** | T345 ✅ (fusionnée T334) | Preuve du lot L1, mécanisme réel (`ArrivalStopConfirmed`, mémoire de sens) ; T334 doit reprendre. | Vérifier que T334 reprend le mécanisme et les alertes A1–A6 ; sinon garder. |
| 32 | `DOC/WFLOW/AUDITS/AUDIT_T423_PRE_MODIF_COHERENCE_20261030.md` | **GARDER** | T423 ✅ | Preuve de l’état avant modification : 14 FAIL_SILENT, causes C1/C2/C3. | Aucune. |
| 33 | `DOC/WFLOW/AUDITS/RFC_METHODOLOGIE_2_ETAGES_ET_CHALLENGE_EXPERTS.md` | **CONDITIONNEL** | T287 ⬜ | RFC de méthode avec grille de challenge ; pas une tâche. | Vérifier si `GUIDE_METHODOLOGIE_2_ETAGES` existe et reprend la RFC ; sinon garder. |
| 34 | `DOC/WFLOW/AUDITS/T196_BUCKET_STATE_20260831.md` | **CONDITIONNEL** | T196 | Audit de validation, addenda et correctif simulation superseded. | Vérifier si T196 est clos et si les constats sont dans AF-10 ; sinon garder. |
| 35 | `DOC/WFLOW/AUDITS/T202_NOTE_DECISION_ARCHI.md` | **CONDITIONNEL** | T202 | Proposition non validée, décisions A1/A2/A6/A7. | Vérifier si T202 est au catalogue et si les décisions sont tranchées. |
| 36 | `DOC/WFLOW/AUDITS/DESIGN/DESIGN_EMERGENCYSTOPOK_CONFIRMATION_TEMPORISEE_v0.2.md` | **CONDITIONNEL** | T11 | Étude de design, décision en attente (verrou vs diag, fenêtre). | Vérifier si T11 est au catalogue ; sinon archiver. |
| 37 | `DOC/WFLOW/AUDITS/NOTE_T364_PHASE4_DOC_ET_COHERENCE_CYCLE_AUTO.md` | **CONDITIONNEL** | T364 ✅ | Note de phase 4, textes opérateur et comparatif homing/cycle. | Vérifier si les textes sont dans AF-04 ; sinon garder comme référence. |
| 38 | `DOC/WFLOW/AUDITS/SESSION_20260824_DECISIONS_EN_ATTENTE.md` | **SUPPRIMER** | Plusieurs tâches T54–T151 | Handoff de session consommé, décisions Q1–Q5 intégrées. | Vérifier que les décisions sont dans TASKS/VERSION_HISTORY ; historique Git. |
| 39 | `DOC/WFLOW/AUDITS/DESIGN/BRIEFS_T181/BRIEF_B1_redaction_plan_T181.md` | **SUPPRIMER** | T181 | Prompt de rédaction consommé (le plan T181 existe). | Historique Git ; vérifier que le plan T181 est versionné. |
| 40 | `DOC/WFLOW/AUDITS/DESIGN/SIMU_M3_REALISTE_20261028/SYNTHESE_EXPERTS_A_B.md` | **CONDITIONNEL** | T417 ⏳, T300 ✅ | Synthèse de travail pour T417 en pause ; constats F1–F8/M1–M8. | Vérifier que les constats sont dans le plan T417 ; sinon garder. |
| 41 | `DOC/WFLOW/AUDITS/T154_AF_TC_CI_COVERAGE_20260829.md` | **CONDITIONNEL** | T154 | Export de couverture daté, régénérable. | Vérifier si les écarts listés ont été traités ; sinon garder comme référence. |
| 42 | `DOC/WFLOW/AUDITS/PLAN_DIAGNO_ALARMES_T218_220.md` | **GARDER** | T218 ⬜, T219 ⬜, T220 ⬜ | Plan de travail actif, trois tâches ouvertes. | Aucune. |
| 43 | `DOC/WFLOW/AUDITS/TABLE_ECHANGE_IHM_T347_DUREE_CYCLE_2026-09-21.md` | **GARDER** | T347 ⬜ | Mapping IHM vivant (4 adresses `GVL_IHM`), lot non commité. | À reconfirmer après commit/relecture orchestrateur. |
| 44 | `DOC/WFLOW/AUDITS/PLAN_PERMITS_M3.md` | **CONDITIONNEL** | T184, T204 | Plan d’exécution, T184 avancé/committé, T204 reporté. | Vérifier si T184 est clos et T204 ouvert. |
| 45 | `DOC/WFLOW/AUDITS/PROMPT_CONSULTATION_DYNAMIQUE_T421.md` | **CONDITIONNEL** | T421 ✅ | Prompt consommé, mais mesures réelles uniques (montée +0,543 m, descente −1,205 m). | Vérifier que les mesures sont dans le contrat/AF T421 ; sinon extraire puis supprimer. |
| 46 | `DOC/WFLOW/AUDITS/DESIGN/DESIGN_T126_MSG_DESCENTE_INTERDITE_v0.1.md` | **CONDITIONNEL** | T126 | Étude de design IHM non validée. | Vérifier si T126 est au catalogue ; sinon archiver. |
| 47 | `DOC/WFLOW/AUDITS/DESIGN/DESIGN_T148_FBFSTATUS_RESET_MAINTENU_v0.2.md` | **CONDITIONNEL** | T148 | Étude close (non reproductible), test TC-P03-014 ajouté. | Vérifier que TC-P03-014 existe et que T148 est clos ; sinon garder. |
| 48 | `DOC/WFLOW/AUDITS/AUDIT_WT3-T173_BANC_REVUE_20260828.md` | **CONDITIONNEL** | T173 | Revue du banc, marquages/renommages à appliquer. | Vérifier si les corrections sont appliquées ; sinon garder. |
| 49 | `DOC/WFLOW/AUDITS/DESIGN/AUDIT_T374_MAINT_N2_BOUTONS_MOTEURS_20260922.md` | **GARDER** | T374 ⬜ | Audit durable, périmètre révisé, phase A. | Aucune. |
| 50 | `DOC/WFLOW/AUDITS/T314_LEGACY_TRIAGE_20260917.md` | **GARDER** | T314 ⏸️ | Triage du legacy TwinBench/Modelica, T314 en pause. | Aucune. |
| 51 | `DOC/WFLOW/AUDITS/QUESTIONS_T164-4.md` | **CONDITIONNEL** | T164-4 | Registre de questions, à confirmer en recette (PDO preset, latence). | Vérifier si T164-4 est clos et si Q1–Q6 sont résolues. |
| 52 | `DOC/WFLOW/AUDITS/TABLE_ECHANGE_IHM_T299_COMPTEURS_2026-09-20.md` | **GARDER** | T299 ✅ | Mapping IHM vivant (compteur journalier + totalisateur), import CODESYS. | À reconfirmer après commit ; point de commissioning `_CycleSampleCountTotal`. |
| 53 | `DOC/WFLOW/AUDITS/T356_ALARMES_20260921/T356_synthese_scan.json` | **CONDITIONNEL** | T356 ✅ | Synthèse JSON du scan (262 fichiers, 572 candidats, 82 causes). | Artefact de preuve : conserver si l’audit est rejoué ; sinon Git suffit. |

---

## Synthèse des décisions

- **GARDER : 20 fichiers** — références uniques, preuves primaires, plans/tâches actifs, mappings IHM vivants : `CADRAGE_T330`, `AUDIT_T422.yaml`, `AUDIT_T300_TRACE`, `AUDIT_T356.md`, `DIAGNOSTIC_T346`, `AUDIT_TRIAGE_WINCH_INTEG`, `AF10_INTERFACE_T181`, `CHALLENGE_T262`, `SPEC_HARNESS_T181-00`, `T332_HOOKS`, `CADRAGE_T181-06`, `AUDIT_T370`, `AUDIT_T360`, `GEL_SEMIAUTO_AMENDEMENT_T383`, `PLAN_T213`, `AUDIT_T423_PRE_MODIF`, `PLAN_DIAGNO_T218_220`, `TABLE_IHM_T347`, `AUDIT_T374`, `T314_LEGACY_TRIAGE`, `TABLE_IHM_T299` — soit 21 en réalité (deux tableaux IHM).
- **SUPPRIMER : 3 fichiers** — `PLAN_T208` (plan clos absorbé T241), `SESSION_20260824` (handoff consommé), `BRIEF_B1_redaction_plan_T181` (prompt consommé). Tous récupérables via Git.
- **CONDITIONNEL : 29 fichiers** — la majorité. Les conditions sont de deux ordres :
  1. **Vérifier que le contenu unique a été repris** (ex. `CHALLENGE_T340` → T364/T377 ; `PREUVE_T345_L1` → T334 ; `PROMPT_T421` → contrat/AF T421 ; `GEL_HOMING` → T364/AF-04).
  2. **Vérifier le statut réel de la tâche porteuse** (ex. `PLAN_T204` → T204/T184 ; `ETUDE_T260` → T260 ; `T202` → T202 ; `T11` → T11 ; `T126` → T126 ; `T196` → T196 ; `T164-4` → T164-4).

## Points d’attention transverses

- **Doublons prouvés** : `PRG0405_AUDIT_A` est corrigé par `PRG0405_AUDIT_B` ; `WT3-T173_RAPPORT` est corrigé par `AUDIT_WT3-T173_BANC_REVUE`. Ne pas supprimer les deux sans vérifier que la version corrigée reprend bien les constats uniques.
- **Documents sans tâche porteuse identifiée** : `PRG0405_AUDIT_A/B`, `CONTACTEURS_DIAG`, `PRG06_AUDIT`. Ils contiennent des constats safety (one-hot contacteurs, `FB_WinchRateInterlock` absent, gate frein M1/M2). À rattacher ou à traiter avant archivage.
- **Fichiers non suivis Git** : aucun dans ce lot (`tracked: true` partout).
- **Références lexicales** : les `incoming` ne sont pas des preuves de dépendance. Les seules dépendances que je recommande de vérifier avant suppression sont celles citées dans les conditions (T241, T334, T364, T377, T421, T372/T384).
- **Statuts catalogue** : T340 est `❌` et T345 est `✅` mais fusionnée dans T334 ; T346, T262, T347, T374 sont `⬜` avec des lots livrés non commités. Le catalogue ne prouve pas l’état machine ; les documents correspondants restent utiles jusqu’à clôture/recette.