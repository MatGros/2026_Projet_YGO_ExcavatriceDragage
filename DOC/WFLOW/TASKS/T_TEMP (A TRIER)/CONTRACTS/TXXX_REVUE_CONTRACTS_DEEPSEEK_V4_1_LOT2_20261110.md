**Périmètre** : 79 fichiers du corpus, tous sous `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/CONTRACTS/`. Aucune suppression, aucun renommage, aucune exécution machine n’est effectuée ni autorisée par cette revue.
**Méthode** : statut catalogue lu dans `TASKS.yaml` ; état contrat lu dans le fichier ; les références entrantes ne sont pas traitées comme dépendances exécutables ; les dates anciennes ne suffisent pas à condamner un document. T400 est absente du catalogue : ce n’est pas une preuve d’annulation (T384 est la réconciliation existante). Aucun fichier T367 n’est dans le lot ; T378 interdit leur suppression, réserve respectée. Les fichiers sont suivis Git mais toute réutilisation/suppression future exige une autorisation explicite.
**Légende** : `GARDER` = contrat/preuve/réserve unique à conserver ; `REPRISE_PREALABLE` = contenu à requalifier/compléter avant réutilisation ; `SUPPRIMER` = candidat seulement, non exécuté.

| Chemin | Décision | Tâche principale et statut courant | Rôle et preuve de décision | Justification et condition exacte |
|---|---|---|---|---|
| `BRIEF_T224_ARMINGPERMIT_COHERENT.md` | GARDER | T224 ⬜ C4 | Brief v1 ; v2 en-tête : « Le v1 n’est ni déplacé ni supprimé (décision humaine) » ; F1-F3 réfutées | Archive de décision humaine ; ne pas retransmettre (affirmations fausses). Aucune suppression. |
| `BRIEF_T224_ARMINGPERMIT_COHERENT_v2_TRANSMISSION.md` | GARDER | T224 ⬜ C4 | Brief actif ; ADDENDUM 2026-09-21T12:30, 5 faits, Étape B après trace | Principal vecteur de transmission ; condition : trace 10 ms puis GO humain. |
| `PROCEDURE_TRACE_T224_ARMINGPERMIT_10MS.md` | GARDER | T224 ⬜ C4 | Procédure 172 canaux, 6 scénarios, preuve C43-bis | Prérequis humain non joué ; valeur de preuve unique. |
| `TASK_CONTRACT_T224_ARMINGPERMIT_ACTIONNEUR_PRET.yaml` | GARDER | T224 ⬜ C4 | Contrat principal ; `design_decisions` l.66-68 (forme X, reprise B), `scope_conflict` G1/G2/G3, `status: PENDING` | Référencé champ `contrat:` de T224 ; safety C4 ; ne pas clore sur statut vide. |
| `BRIEF_T262_SEUIL_FERMETURE_BENNE.md` | GARDER | T262 ⬜ C4 | Brief ; mail GCAM 2026-09-15 ; champ mort jusqu’au 2026-09-21 ; remplacé par contrat Phase B | Consommé mais conserve le besoin d’origine ; remplacement prouvé par fichier 13 + commits 065591fb/c9e1fbfe ; recette machine restante. |
| `IHM_FREEZE_T262_EXTRACTION_START_OPENING_20260915.md` | GARDER | T262 ⬜ C4 | Gel IHM ; plage 0..20, effet à 9 %, mise à jour 2026-09-21 | Contrat d’interface unique ; non remplacé ; recette IHM à faire. |
| `PLAN_T262_TRANSFERT_AX10_AX11_20260915.md` | GARDER | T262 ⬜ C4 | Plan C4 ; 9 fichiers, chronogrammes, repli ; cité `plan_reprise` | Référence technique unique ; recette CODESYS/machine restante. |
| `REGISTRE_ACTIONS_T262_AX10_STEP_CEILING_20260919.md` | SUPPRIMER (candidat, non exécuté) | T262 ⬜ C4 | Registre 4 risques « À implémenter/À vérifier » ; contredit par commits Phase B | Aucune preuve fichier:ligne, aucune valeur unique au-delà du contrat/plan ; supprimer seulement après accord humain et vérification T384/T378. |
| `T262_VALIDATION_CODESYS_20260919.md` | GARDER | T262 ⬜ C4 | Procédure de validation CODESYS humaine ; non faite | Preuve/recette non recettée ; valeur propre. |
| `TASK_CONTEXT_T262_AX10_STEP_CEILING.yaml` | GARDER | T262 ⬜ C4 | Mini-contexte micro-phase AX10 ; scope, 4 canaux de trace | Contexte historique utile ; faible coût ; ne pas supprimer sans vérifier le remplacement. |
| `TASK_CONTRACT_T262_AX10_CLOSE_BUCKET_THRESHOLD.yaml` | GARDER | T262 ⬜ C4 | Contrat principal référencé `contrat:` ; 18 AC ; `status: IN_PROGRESS` | C4 safety ; recette machine non faite ; ne pas clore sur statut. |
| `TASK_CONTRACT_T262_LOCAL_IHM_BLOCKS.yaml` | REPRISE_PREALABLE | T262 ⬜ C4 (identifiant parasite) | Contrat LocalIHM (CtrlBlock/StatusBlock) sous `task_id: T262`, sans lien benne | Identifiant ambigu/collision ; reclasser avant réutilisation ; ne pas supprimer (contenu IHM unique). |
| `TASK_CONTRACT_T262_PHASE_B_BUCKET_OPENING_THRESHOLD.yaml` | GARDER | T262 ⬜ C4 | Contrat Phase B ; `status: COMPLETED` ; commits 065591fb/c9e1fbfe ; 15 AC | Remplacement prouvé du brief ; conserver comme preuve de la phase B. |
| `PLAN_T346_BORNE_RECUL.md` | GARDER | T346 ⬜ C1 | Plan ; 2 variantes, tests N1-N7, D6 | T346 lot livré non commité ; valeur de conception unique. |
| `TASK_CONTRACT_T346_BORNE_RECUL.yaml` | GARDER | T346 ⬜ C1 | Contrat principal ; `status: COMPLETED`, `validation: PENDING` ; 13 AC ; D6 safety | Référencé `contrat:` ; garantie de non-régression ; conserver. |
| `TESTPLAN_T346_BORNE_RECUL.md` | GARDER | T346 ⬜ C1 | Dossier de test ; blocs ST, mutations, matrice 36 tests | Preuve de non-vacuité unique ; conserver. |
| `BRIEF_T358_FORCESTEP_SIMPLIFICATION_SANS_GARDE.md` | GARDER | T358 ⬜ C4 | Brief ; décision exploitant « risque signalé et assumé », gardes retirées | Trace de la décision de risque ; remplacement prouvé par contrat + note ; recette machine restante. |
| `NOTE_APPLICATION_T358_FORCESTEP_SANS_GARDE.md` | GARDER | T358 ⬜ C4 | Note ; 8 gardes tracées, 9 constats hors scope | Auditabilité sécurité ; unique. |
| `TASK_CONTRACT_T358_FORCESTEP_SANS_GARDE.yaml` | GARDER | T358 ⬜ C4 | Contrat principal ; `status: COMPLETED` ; G517 ; commit unique | Référencé `contrat:` ; validation PENDING ; conserver. |
| `BRIEF_T353_OUTIL_WEB_CARTOGRAPHIE_INTERACTIVE.md` | GARDER | T353 ⬜ C2 | Brief ; besoin « je suis un joystick » ; phase 2 T351 | Consommé ; remplacement = contrat T353 + commit 210cadb0 ; livrable final hors lot → incertitude limitée. |
| `TASK_CONTRACT_T353_OUTIL_WEB_CARTOGRAPHIE.yaml` | GARDER | T353 ⬜ C2 | Contrat principal ; 12 AC ; `status: DELIVERED/IN_PROGRESS` ; réserves R3/R4 | Référencé `contrat:` ; revue humaine et réserves non soldées. |
| `CORRECTION_CONSIGNE_T387_SECURITE_v1.md` | GARDER | T387 ⬜ C4 | Correction de consigne ; blocage sécurité, 3 actions, remplace le point 4 | Safety C4 ; valeur propre ; ne pas fusionner avec T369. |
| `MESSAGE_AGENT_T387_BENNE_v1.md` | GARDER | T387 ⬜ C4 (+ T388 absorbée ❌) | Message agent ; 3 défauts benne ; T388 absorbée | Trace de l’absorption T388 ; safety ; conserver. |
| `NOTE_APPLICATION_T387_FENETRE_BENNE.md` | GARDER | T387 ⬜ C4 | Note ; fix MecaB, grant 4 verrous ; recette non faite | Preuve de conception safety ; unique. |
| `TASK_CONTRACT_T387_FENETRE_BENNE.yaml` | GARDER | T387 ⬜ C4 (`task_id: T387_FENETRE_BENNE` sans entrée propre) | Contrat C4 ; `status: PENDING` ; 10 AC ; MecaB AC10 | Contrat safety autonome ; ne pas supprimer ; rattacher explicitement à T387. |
| `TASK_CONTRACT_T387_MECAB_SOURCE_COMMANDE.yaml` | GARDER | T387 ⬜ C4 | Contrat C4 MecaB ; `status: PENDING` ; 7 AC | Safety ; référencé dans le lot ; conserver. |
| `TASK_CONTRACT_T426.yaml` | GARDER | T426 ⏳ C2 | Contrat principal ; `status: IN_PROGRESS` ; 43 tests ; tracking | Référencé `contrat:` ; étude non activée. |
| `BRIEF_T354_ASYMETRIE_GARDE_M1_M2.md` | GARDER | T354 ⬜ C3 | Brief ; 3 chemins M2, atteignabilité | Consommé ; remplacement = contrat T354 (dans le lot) + fiche hors lot → incertitude sur la fiche. |
| `TASK_CONTRACT_T354_ASYMETRIE_GARDE_M1_M2.yaml` | GARDER | T354 ⬜ C3 | Contrat principal ; 14 AC ; `status: COMPLETED` (analyse) | Référencé `contrat:` ; verdict atteignable ; options non implémentées. |
| `BRIEF_T370_C4_ACTIVATION_STUCKOPEN.md` | GARDER | T370 ⬜ C4 | Brief activation StuckOpen ; diagnostic only, pas de PowerCutOff | Consommé ; remplacement = contrat T370_STUCKOPEN (dans le lot). |
| `BRIEF_T370_DISCORDANCE_CONTACTEURS.md` | GARDER | T370 ⬜ C4 | Brief investigation initiale ; trou M1=M2 | Remplacement = diagnostic TROUBLESHOOTING_T370 hors lot → incertitude ; conserver la question d’origine. |
| `TASK_CONTRACT_T370_CARTOGRAPHIE_DISCORDANCES.yaml` | GARDER | T370 ⬜ C4 | Contrat C4 ; `status: PENDING` ; table vérité, comparatif bits | Référencé `contrat:` ; analyse non code. |
| `TASK_CONTRACT_T370_STUCKOPEN.yaml` | GARDER | T370 ⬜ C4 | Contrat C4 activation ; `status: PENDING` ; AC1-AC9 | Safety diagnostic-only ; conserver. |
| `PLAN_T417_SIMBENCH_M3_ROUE_LIBRE.md` | GARDER | T417 ⏳ C2 | Plan V2 ; roue libre abandonnée ; cible 25 Hz/s | Titre obsolète mais contenu V2 unique ; ne pas supprimer sur le titre. |
| `TASK_CONTRACT_T417_SIMBENCH_M3_FIDELITE_ROUE_LIBRE.yaml` | GARDER | T417 ⏳ C2 (+ T420 ❌) | Contrat antérieur ; `status: IN_PROGRESS` ; bloc T420 annulée B1-B6 | Remplacé pour le corps par T417_SIMULATION_M3_REALISTE mais réserve unique T420 ; conserver. |
| `TASK_CONTRACT_T417_SIMULATION_M3_REALISTE.yaml` | GARDER | T417 ⏳ C2 | Contrat le plus récent ; `status: COMPLETED` ; investigation 20261031 AWAITING_D | Principal ; recette non faite ; conserver. |
| `BRIEF_T351_CARTOGRAPHIE_JOYSTICK_TREUILS.md` | GARDER | T351 ⬜ C2 | Brief ; 2 chaînes M01-M66/C01-C35 ; read-only | Consommé ; remplacement = contrat T351 + fiche hors lot → incertitude. |
| `REPONSE_T351_Q1_Q17.md` | GARDER | T351 ⬜ C2 | Réponse orchestrateur ; Q1-Q17 ; D18 corrigé/committé/non testé machine | Décisions humaines uniques ; conserver. |
| `TASK_CONTRACT_T351_CARTOGRAPHIE_TREUILS.yaml` | GARDER | T351 ⬜ C2 | Contrat C2 ; 12 AC ; livrable 786 l | Référencé `contrat:` ; lecture humaine restante. |
| `CONTRACT_T409_ANIMATION_REVIEW.md` | GARDER | T409 ⬜ C3 | Contrat de challenge ; invariants capteurs/frein/UDP | Safety review unique ; conserver. |
| `NOTE_APPLICATION_T409_FMU_CONTROL_WIN.md` | GARDER | T409 ⬜ C3 | Note ; corrections et 4 limites restantes | Preuve des limites ; unique. |
| `PLAN_T409_FMU_CONTROL_WIN_INJECTION.md` | GARDER | T409 ⬜ C3 | Plan ; gardes-fous, 6 étapes recette | Unique. |
| `T409_CONTROLWIN_TEST_RECIPE.md` | GARDER | T409 ⬜ C3 | Recette CW-00/CW-01 ; verdicts PASS_MEMOIRE/FAIL | Recette humaine non faite ; preuve unique. |
| `T409_FINAL_AUDIT.md` | GARDER | T409 ⬜ C3 | Audit final ; prouvés/non prouvés ; verdict partiel | Ne pas transformer en validation ; conserver. |
| `T409_T413_M3_VISUALISATION.yaml` | GARDER | T409 ⬜ C3 / T413 non catalogué ici | Contrat visualisation ; AC1-AC11 | Contrat unique ; validation Control Win requise. |
| `TASK_CONTRACT_T409_FMU_CONTROL_WIN_INJECTION.yaml` | GARDER | T409 ⬜ C3 | Contrat principal ; `status: IN_PROGRESS` ; AC1-AC12 | Référencé `contrat:` ; recette Control Win restante. |
| `TASK_CONTRACT_T428_REFACTOR_TROUBLESHOOTING.md` | GARDER | T428 ⏳ C2 | Plan détaillé ; jalons J0-J6 ; 0 cause/15 | Unique ; seuils non atteints publiés. |
| `TASK_CONTRACT_T428_REFACTOR_TROUBLESHOOTING.yaml` | GARDER | T428 ⏳ C2 | Contrat chapeau ; `status: IN_PROGRESS` ; AC1-AC6 | Principal ; conserver. |
| `PLAN_T289_DECOMPTE_RESTANT_20260915.md` | GARDER | T289 ⬜ C2 | Delta temps restant ; validation machine | Unique ; T289 rouverte pour essai réel. |
| `PLAN_T289_EGOUTTAGE_IHM_SECONDES_20260915.md` | GARDER | T289 ⬜ C2 | Plan phases A-D ; bornes 1..3600 s | Unique ; recette machine restante. |
| `TASK_CONTRACT_T289_EGOUTTAGE_IHM_SECONDES.yaml` | GARDER | T289 ⬜ C2 | Contrat principal ; `status: PENDING` ; 9 AC | Référencé `contrat:` ; conserver. |
| `REGISTRE_ACTIONS_T288_PHASE2_REGISTRE_ERREURS_20260915.md` | GARDER | T288 ⬜ C4 | Registre actions C4 ; 5 étapes ; attente utilisateur | Phase 2 non prête ; valeur de suivi safety. |
| `TASK_CONTRACT_T288_DISCORDANCE_CONTACTEURS_ABSENCE_MOUVEMENT.yaml` | GARDER | T288 ⬜ C4 | Contrat phase 1 ; `status: IMPLEMENTED/VALIDATED_SIMULATION` ; 5 AC | Safety ; ne pas clore sur statut catalogue ⬜. |
| `TASK_CONTRACT_T288_PHASE2_REGISTRE_ERREURS.yaml` | GARDER | T288 ⬜ C4 | Contrat phase 2 ; `status: REVIEWED_MAJOR_NOT_READY` ; 6 AC | Verdict MAJOR ; options A/B ; conserver. |
| `TEST_DESIGN_T288_PHASE2_REGISTRE_ERREURS_20260915.md` | GARDER | T288 ⬜ C4 | Design essais TD-01..TD-12 | Preuve unique ; conserver. |
| `BRIEF_T372_GENERATEUR_TEMPLATE_TRACE.md` | REPRISE_PREALABLE | T372 ⬜ C2 (registre CI) — sujet différent | Brief générateur `.trace`, sans `task_id` ; le catalogue T372 est « registre CI » | Ne pas rattacher à T372 sans décision ; requalifier en tâche trace ou archiver. Remplacement non prouvé. |
| `TASK_CONTRACT_T372_REGISTRE_CI_AUTO_COHERENT.yaml` | GARDER | T372 ⬜ C2 | Contrat principal ; `status: PENDING/BLOCKED` ; AC1-AC7 ; WINCH_INTEG FAIL | Référencé `contrat:` ; dette CI réelle. |
| `PLAN_T399_TWINBENCH_HYBRID_PLC_OPENMODELICA.md` | GARDER | T399 ⬜ C2 | Feuille de route P0-P6 ; jalons GO/NO-GO | Unique ; validation humaine P0.1 en attente. |
| `TASK_CONTRACT_T399_TWINBENCH_HYBRID_ROADMAP.yaml` | GARDER | T399 ⬜ C2 | Contrat ; `status: COMPLETED` ; AC1-AC6 | Principal ; `validation: PENDING`. |
| `TASK_CONTRACT_T338_SIM_ENCODER_FLOOR.yaml` | GARDER | T338 ⬜ C1 | Contrat C2 ; `status: COMPLETED` ; AC1-AC8 ; CR1 | Safety mesure ; recette humaine + CR2 hors lot ; conserver. |
| `TASK_CONTRACT_T213.yaml` | GARDER | T213 ⬜ C2 | Contrat ; `status: PENDING` ; AC1-AC7 | Référencé `contrat:` ; diagnostic homing M2. |
| `FICHE_T400_MODELISATION_TRANSLATION_M3.md` | GARDER | T400 ABSENTE (T301 voisine ⬜) | Fiche référence ; plaque, géométrie, hypothèses, à mesurer | Absence catalogue ≠ annulation (T384 réconciliation) ; données uniques. |
| `TASK_CONTRACT_T400_FICHE_MODELISATION_M3.yaml` | GARDER | T400 ABSENTE (T301 voisine ⬜) | Contrat ; `status: COMPLETED` ; AC1-AC6 | Même réserve ; conserver la fiche et le contrat. |
| `TASK_CONTRACT_T225_SYNCCONTACTOR_ESCALADE_PRG06.yaml` | GARDER | T225 ⬜ C3 | Contrat safety ; `status: PENDING` ; 9 AC ; bypass | Référencé `contrat:` ; arbitrages humains ouverts. |
| `TASK_CONTRACT_T349_AX15A_AFFICHAGE_GESTE.yaml` | GARDER | T349 ⬜ C2 | Contrat ; `status: PENDING` ; 9 AC ; affichage seul | Unique ; verrou T347 signalé. |
| `TASK_CONTRACT_T229_FB_CYCLE_STEP_CONFIG_TREUIL_UNIQUE.yaml` | REPRISE_PREALABLE | T229 ⬜ C3 | Contrat STUB ; 4 questions ouvertes ; `status: PENDING` | À compléter avant exécution ; ne pas supprimer (seule trame du split X11). |
| `TASK_CONTRACT_T287_M3_BUTEES_ESCALADE_GRADUEE.yaml` | GARDER | T287 ⬜ C3 | Contrat ; `IN_PROGRESS` ; 8 AC ; FB_Brake gelé | Safety ; preuve/trace manquante ; conserver. |
| `TASK_CONTRACT_T322_MISE_EN_SERVICE_RECALAGE.yaml` | GARDER | T322 ⬜ C2 | Contrat campagne mesure ; `PENDING` ; 8 AC | Mesures terrain uniques ; conserver. |
| `TASK_CONTRACT_T421_FIDELITE_DYNAMIQUE_TREUILS.yaml` | GARDER | T421 ✅ C3 | Contrat ; `status: validated` ; AC1-AC7 ; `SimWinchCoast_M` supprimé | Validation selon le fichier (banc CODESYS) ; preuve unique ; conserver. |
| `BRIEF_T373_INREFERENCINGMODE_FENETRE_ETROITE.md` | REPRISE_PREALABLE | T373 ⬜ C3 (angle mort M3) — sujet différent | Brief InReferencingMode/homing, sans `task_id` ; le catalogue T373 est « angle mort M3 » | Ne pas rattacher sans décision ; requalifier en tâche safety homing. Remplacement non prouvé. |
| `TASK_CONTRACT_T294_TASK_MANAGER_PERFORMANCE.yaml` | GARDER | T294 ⬜ C2 | Contrat performance ; `PENDING` ; AC1-AC6 | Unique ; conserver. |
| `TASK_CONTRACT_T403_AIGUILLAGE_M3_OPENMODELICA.yaml` | GARDER | T403 ⬜ C2 | Contrat ; `status: COMPLETED` ; AC1-AC6 | Principal ; `validation: PENDING`. |
| `TASK_CONTRACT_T219_HISTORIQUE_ALARMES.yaml` | GARDER | T219 ⬜ C2 | Contrat buffer alarmes ; `PENDING` ; AC1-AC6 | Unique ; conserver. |
| `TASK_CONTRACT_T316_SIMBENCH_FIDELITE_TREUILS.yaml` | GARDER | T316 ⬜ C2 | Contrat ; `COMPLETED` phase 1 ; phase 2 ouverte | Preuve de simulation ; conserver. |
| `TASK_CONTRACT_T280_TROUBLESHOOTING_WORKSPACE.yaml` | GARDER | T280 ⬜ C2 (`COMPLETED/APPROVED` dans le fichier) | Contrat workspace ; `validation: APPROVED` | Tâche terminée mais contrat = convention durable ; ne pas supprimer. |
| `TASK_CONTRACT_T318_SIMBENCH_PROFIL_SIMPLE.yaml` | GARDER | T318 ⬜ C3 | Contrat ; `IN_PROGRESS` ; AC1-AC6 | Unique ; conserver. |
| `TASK_CONTRACT_T272_M3_DESCENT_STATE_GATE.yaml` | GARDER | T272 ⬜ C3 (`COMPLETED` dans le fichier) | Contrat ; `COMPLETED` ; AC1-AC6 ; `validation: PENDING` | Écart statut fichier/catalogue à noter ; conserver. |
| `TASK_CONTRACT_T311_CYCLE_HOMING_BUG.yaml` | GARDER | T311 ⬜ C2 | Contrat ; `PENDING` ; AC1-AC4 | Unique ; reproduction non faite. |
| `TASK_CONTRACT_T269_MECAD_BUCKET_TOP.yaml` | GARDER | T269 ⬜ C3 | Contrat safety ; `IN_PROGRESS` ; AC1-AC4 ; MecaD | Safety ; conserver. |

**Synthèse** : 73 `GARDER`, 5 `REPRISE_PREALABLE` (`T262_LOCAL_IHM`, `T229` stub, briefs `T372` et `T373` mal rattachés), 1 `SUPPRIMER` candidat (`REGISTRE_ACTIONS_T262_AX10_STEP_CEILING`, non exécuté). Les contrats safety, les visas/recettes humaines non faits, les preuves de non-régression et les réserves uniques (T420 annulée, T388 absorbée, D18 corrigé/non testé machine, CR2 hors lot) sont conservés. Aucune conclusion d’absorption AF ni de validation machine n’est tirée d’un simple statut.