# PLAN APPLIQUÉ — renommage à plat, tâche en premier

Application terminée le 2026-11-10. Préfixe de tâche toujours en T majuscule, y compris scripts et prompts. La section ci-dessous conserve le plan validé ; le manifeste JSON porte le statut appliqué.

# Proposition — renommage à plat, tâche en premier

## Convention validée par l’utilisateur

**`TACHE_TYPE_DESIGNATION[_YYYYMMDD][_VMAJEURE_MINEURE].ext`**

Tous les fichiers sont proposés directement dans le même dossier `AUDITS/`, sans sous-dossiers. Le préfixe de tâche est systématiquement le premier champ. La convention précédente TYPE_TACHE est remplacée.

- Documents et données : `T213_PLAN_DIAGNOSTIC_HOMING_M2.md`, `T356_DONNEES_ALARMES_CAUSES_PRODUCTEURS_20260921.csv`.
- Plusieurs tâches explicites restent distinctes : la première est placée en tête, les autres restent dans la désignation ; aucun nouvel identifiant composé inventé.
- Tâche non établie : préfixe `TXXX`, repère de rangement à rattacher. Il ne crée aucune tâche et ne signifie ni abandonné ni terminé. Ne pas affecter tous les documents à T384 simplement parce qu’il traite le rangement.
- Scripts : même ordre en snake_case (`T154_export_coverage_csv.py`, `T154_test_generate_af_ci_report.py`).
- Prompts : même ordre en kebab-case (`T421-prompt-consultation-dynamique-treuils.md`).
- Index : `TXXX_INDEX_AUDITS.md` proposé à la place de `README.md`, pour respecter la tâche en premier même pour ce fichier. Adapter les liens de navigation.
- Extensions et versions existantes conservées. Aucune date inventée : date de fichier conservée ; date de dossier conservée pour les corpus T417 et T356, sans prétendre dater leur validation.
- Les graphies T144B et T202E restent inchangées ; le renommage documentaire ne décide pas de renumérotation des tâches.

## Bilan de la proposition

- **154/154 fichiers** couverts ; **154 chemins à changer**, **0 conservés**.
- **47 fichiers sous TXXX** : attribution non établie dans cette proposition.
- Zéro collision, y compris en comparaison Windows insensible à la casse ; zéro sous-dossier dans les destinations.
- Chemin cible le plus long : 151 caractères.
- Les 154 sources et leurs empreintes sont intactes. Renommage et mise à plat exécutés ; voir le rapport d’application.

## Correspondance exhaustive

| Chemin actuel relatif à AUDITS/ | Nom proposé directement dans AUDITS/ | Motif |
|---|---|---|
| `AUDIT_29_CAS_LIMITES_SECURITE_AF_20260829.md` | `TXXX_AUDIT_29_CAS_LIMITES_SECURITE_AF_20260829.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `AUDIT_FB_BRAKE_BASELINE_M3_20260914.md` | `TXXX_AUDIT_FB_BRAKE_BASELINE_M3_20260914.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `AUDIT_ORGANISATION_DOC_WFLOW_20261109.md` | `TXXX_AUDIT_ORGANISATION_DOC_WFLOW_20261109.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `AUDIT_PERMITS_DIRECTIONNELS_20260901.md` | `TXXX_AUDIT_PERMITS_DIRECTIONNELS_20260901.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `AUDIT_T287_M3_COMMANDE_SANS_JOYSTICK_20260914.md` | `T287_AUDIT_M3_COMMANDE_SANS_JOYSTICK_20260914.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `AUDIT_T356_ALARMES_EXHAUSTIF_20260921.md` | `T356_AUDIT_ALARMES_EXHAUSTIF_20260921.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `AUDIT_T360_TRACE_RATIO_ESTIMATEUR_M3_20260921.md` | `T360_AUDIT_TRACE_RATIO_ESTIMATEUR_M3_20260921.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `AUDIT_T364_HOMING_4_POINTS_20260921.md` | `T364_AUDIT_HOMING_4_POINTS_20260921.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `AUDIT_T422_DEVICES_ALARMS_20261030.yaml` | `T422_AUDIT_DEVICES_ALARMS_20261030.yaml` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `AUDIT_T423_CONTRE_AUDIT_BANNIERES_IHM_20261031.md` | `T423_AUDIT_CONTRE_AUDIT_BANNIERES_IHM_20261031.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `AUDIT_T423_PRE_MODIF_COHERENCE_20261030.md` | `T423_AUDIT_PRE_MODIF_COHERENCE_20261030.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `AUDIT_TACHES_CONTRATS_LIAISON_20260904.md` | `TXXX_AUDIT_TACHES_CONTRATS_LIAISON_20260904.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `AUDIT_WT3-T173_BANC_REVUE_20260828.md` | `T173_REVUE_WT3_BANC_SIMULATION_20260828.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `AVIS_EXPERT_OLLAMA_METHODOLOGIE_2_ETAGES.md` | `TXXX_AVIS_EXPERT_OLLAMA_METHODOLOGIE_DEUX_ETAGES.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `BASELINE_SEQUENCEURS_HOMING_CYCLE_20260903.md` | `TXXX_BASELINE_SEQUENCEURS_HOMING_CYCLE_20260903.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `CLARIFICATION_T110_DRIVESTATUSWORD_v0.1.md` | `T110_CLARIFICATION_DRIVE_STATUS_WORD_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `CONTACTEURS_DIAG_2026-08-31.md` | `TXXX_DIAGNOSTIC_CONTACTEURS_20260831.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `CONTACTEURS_SOLUTION_20260831.md` | `TXXX_PROPOSITION_CONTACTEURS_20260831.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `CYCLES_AUDIT_A_20260831.md` | `TXXX_AUDIT_CYCLES_A_20260831.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `CYCLES_AUDIT_B_20260831.md` | `TXXX_AUDIT_CYCLES_B_20260831.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DECISION_ENCODER_CFG_OWNERSHIP.md` | `TXXX_DECISION_ENCODER_CFG_OWNERSHIP.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `DECISION_ENCODER_PRESET_TRANSACTION.md` | `TXXX_DECISION_ENCODER_PRESET_TRANSACTION.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `DESIGN/AF10_INTERFACE_TREUIL_CIBLE_T181.md` | `T181_SPEC_INTERFACE_TREUIL_CIBLE_AF10.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/ANALYSE_T361_RECALAGE_M3_OPTIONS_2026-09-21.md` | `T361_ANALYSE_RECALAGE_M3_OPTIONS_20260921.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/AUDIT_T300_TRACE_20260904_v1.0.md` | `T300_AUDIT_TRACE_20260904_V1_0.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/AUDIT_T370_MATRICE_DISCORDANCES_20260922.md` | `T370_AUDIT_MATRICE_DISCORDANCES_20260922.md` | Tâche en premier ; nom déjà distinctif : déplacer à plat sans le renommer. |
| `DESIGN/AUDIT_T374_MAINT_N2_BOUTONS_MOTEURS_20260922.md` | `T374_AUDIT_MAINT_N2_BOUTONS_MOTEURS_20260922.md` | Tâche en premier ; nom déjà distinctif : déplacer à plat sans le renommer. |
| `DESIGN/AUDIT_TRIAGE_WINCH_INTEG_20260922.md` | `TXXX_AUDIT_TRIAGE_WINCH_INTEG_20260922.md` | Tâche en premier ; nom déjà distinctif : déplacer à plat sans le renommer. |
| `DESIGN/BRIEFS_T181/EXEC/EXEC_T175_ecarts_code_treuils.md` | `T175-prompt-execution-ecarts-treuils.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/BRIEFS_T181/EXEC/EXEC_T181-00b_calibration_vecteurs.md` | `T181-00b-prompt-calibration-vecteurs.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/BRIEFS_T181/RESULTS/B2_challenge3_resultat.md` | `T181_REVUE_B2_CHALLENGE_3.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/BRIEFS_T181/RESULTS/B4_review_independante.md` | `T181_REVUE_B4_INDEPENDANTE.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/BRIEFS_T181/RESULTS/B5_challenge_phase0_contacteurs.md` | `T181_REVUE_B5_PHASE_0_CONTACTEURS.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/CADRAGE_T175-01_M2_SLIP_SAFETY.md` | `T175-01_CADRAGE_M2_SLIP_SAFETY.md` | Tâche en premier ; nom déjà distinctif : déplacer à plat sans le renommer. |
| `DESIGN/CADRAGE_T181-06_DRIVEREQUEST.md` | `T181-06_CADRAGE_DRIVEREQUEST.md` | Tâche en premier ; nom déjà distinctif : déplacer à plat sans le renommer. |
| `DESIGN/CADRAGE_T181-11_MATRICE_MAINT.md` | `T181-11_CADRAGE_MATRICE_MAINT.md` | Tâche en premier ; nom déjà distinctif : déplacer à plat sans le renommer. |
| `DESIGN/CADRAGE_T325_D18_INTERLOCK_DIRECTION_v1.0.md` | `T325_CADRAGE_D18_INTERLOCK_DIRECTION_V1_0.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/CADRAGE_T330_INVARIANT_HAUT_v1.0.md` | `T330_CADRAGE_INVARIANT_HAUT_V1_0.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/CHALLENGE_T175-01_02_M2_BUCKET_SAFETY.md` | `T175-01_CHALLENGE_T175-02_SAFETY_M2_BENNE.md` | Tâche en premier ; nom déjà distinctif : déplacer à plat sans le renommer. |
| `DESIGN/CHALLENGE_T262_PHASE_B_SEUIL_BENNE_2026-09-21.md` | `T262_CHALLENGE_PHASE_B_SEUIL_BENNE_20260921.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/CHALLENGE_T300_PA_PLAN_SIMBENCH_M3_v1.0.md` | `T300_CHALLENGE_PA_PLAN_SIMBENCH_M3_V1_0.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/CHALLENGE_T336_HOMING_HYPOTHESE_MONTEE_2026-09-20.md` | `T336_CHALLENGE_HOMING_HYPOTHESE_MONTEE_20260920.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/CHALLENGE_T340_REFONTE_HOMING_2026-09-20.md` | `T340_CHALLENGE_REFONTE_HOMING_20260920.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/CHALLENGE_T371_FAUX_VERT_20260921.md` | `T371_CHALLENGE_FAUX_VERT_20260921.md` | Tâche en premier ; nom déjà distinctif : déplacer à plat sans le renommer. |
| `DESIGN/DECISIONS_T146_ARBITRAGE_ISO13849.md` | `T146_DECISIONS_ARBITRAGE_ISO13849.md` | Tâche en premier ; nom déjà distinctif : déplacer à plat sans le renommer. |
| `DESIGN/DECISIONS_T175_C0_VISA_HUMAIN.md` | `T175_DECISIONS_C0_VISA_HUMAIN.md` | Tâche en premier ; nom déjà distinctif : déplacer à plat sans le renommer. |
| `DESIGN/DESIGN_BANDEAU_IHM_3_NIVEAUX_v0.1.md` | `TXXX_DESIGN_BANDEAU_IHM_3_NIVEAUX_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/DESIGN_EMERGENCYSTOPOK_CONFIRMATION_TEMPORISEE_v0.2.md` | `TXXX_DESIGN_EMERGENCYSTOPOK_CONFIRMATION_TEMPORISEE_V0_2.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/DESIGN_FB_CYCLETIME_GARDE_FOU_WRAP_v0.1.md` | `TXXX_DESIGN_FB_CYCLETIME_GARDE_FOU_WRAP_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/DESIGN_SEMI_AUTO_CYCLE_v0.1.md` | `TXXX_DESIGN_SEMI_AUTO_CYCLE_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/DESIGN_SYNCHRONISME_UNIQUE_4NIVEAUX_v0.2.md` | `TXXX_DESIGN_SYNCHRONISME_UNIQUE_4NIVEAUX_V0_2.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/DESIGN_T108_INTERLOCK_TREMIE_v0.1.md` | `T108_DESIGN_INTERLOCK_TREMIE_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/DESIGN_T126_MSG_DESCENTE_INTERDITE_v0.1.md` | `T126_DESIGN_MSG_DESCENTE_INTERDITE_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/DESIGN_T129_RAQUETTE_TRANSLATION_M3_v0.1.md` | `T129_DESIGN_RAQUETTE_TRANSLATION_M3_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/DESIGN_T144_ASSAINIR_PRG06_v0.1.md` | `T144_DESIGN_ASSAINIR_PRG06_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/DESIGN_T144B_INTERFACES_PRG6_v0.1.md` | `T144B_DESIGN_INTERFACES_PRG06_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/DESIGN_T148_FBFSTATUS_RESET_MAINTENU_v0.2.md` | `T148_DESIGN_FBFSTATUS_RESET_MAINTENU_V0_2.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/DESIGN_T181-01_PROTOCOLE_3BIS_v0.1.md` | `T181-01_DESIGN_PROTOCOLE_3BIS_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/DESIGN_T202E_QUALIFICATION_FOND_SEMIAUTO_v0.1.md` | `T202E_DESIGN_QUALIFICATION_FOND_SEMIAUTO_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/DESIGN_T210_DECOUPLAGE_CONCORDANCE_CONTACTEURS_v0.1.md` | `T210_DESIGN_DECOUPLAGE_CONCORDANCE_CONTACTEURS_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/DIAGNOSTIC_T224_ARMINGPERMIT_20260921.md` | `T224_DIAGNOSTIC_ARMINGPERMIT_20260921.md` | Tâche en premier ; nom déjà distinctif : déplacer à plat sans le renommer. |
| `DESIGN/DIAGNOSTIC_T346_BORNE_RECUL_2026-09-20.md` | `T346_DIAGNOSTIC_BORNE_RECUL_20260920.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/ETUDE_ARRET_M3_UNIFICATION_MANU_CYCLE_T334.md` | `T334_ETUDE_UNIFICATION_ARRET_M3_MANUEL_CYCLE.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/PLAN_DE_TIR_T181_v0.1.md` | `T181_PLAN_ESSAIS_IMPORT_ROLLBACK_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/PLAN_GEL_TREUIL_T181_CONSOLIDE.md` | `T181_PLAN_GEL_TREUIL_CONSOLIDE.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/PLAN_GEL_TREUIL_T181_v0.1.md` | `T181_PLAN_GEL_TREUIL_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/PLAN_T146homing_arbitrage_interlocks.md` | `T146_PLAN_HOMING_ARBITRAGE_INTERLOCKS.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/PLAN_T192corrections_safety_cycles_reste.md` | `T192_PLAN_CORRECTIONS_SAFETY_CYCLES_RELIQUATS.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/PLAN_T194optimisations_interfaces.md` | `T194_PLAN_OPTIMISATIONS_INTERFACES.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/PLAN_T204enforcement_permits_M3.md` | `T204_PLAN_APPLICATION_PERMIS_M3.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/PLAN_T212securite_kobold_hors_cycle.md` | `T212_PLAN_SECURITE_KOBOLD_HORS_CYCLE.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/PLAN_T213troubleshooting_homing_M2.md` | `T213_PLAN_DIAGNOSTIC_HOMING_M2.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/PLAN_T330_C3_INVARIANT_HAUT_v1.0.md` | `T330_PLAN_C3_INVARIANT_HAUT_V1_0.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/PREUVE_T345_L1_MECANISME_ARRET_AXE_2026-09-21.md` | `T345_PREUVE_L1_MECANISME_ARRET_AXE_20260921.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/SIMU_M3_REALISTE_20261028/BILAN_UPDATE_ET_ESSAIS.md` | `T417_BILAN_DYNAMIQUE_M3_ESSAIS_20261028.md` | Tâche en premier ; réintégrer T417, le sujet M3 et la date de dossier dans le nom, car le sous-dossier disparaît. Date de corpus, non date de validation. |
| `DESIGN/SIMU_M3_REALISTE_20261028/CONTRACT_UPDATE_DYNAMIQUE_M3.yaml` | `T417_CONTRAT_MISE_A_JOUR_DYNAMIQUE_M3_20261028.yaml` | Tâche en premier ; réintégrer T417, le sujet M3 et la date de dossier dans le nom, car le sous-dossier disparaît. Date de corpus, non date de validation. |
| `DESIGN/SIMU_M3_REALISTE_20261028/GATES_APRES_UPDATE.txt` | `T417_PREUVE_GATES_APRES_20261028.txt` | Tâche en premier ; réintégrer T417, le sujet M3 et la date de dossier dans le nom, car le sous-dossier disparaît. Date de corpus, non date de validation. |
| `DESIGN/SIMU_M3_REALISTE_20261028/GATES_AVANT_UPDATE.txt` | `T417_PREUVE_GATES_AVANT_20261028.txt` | Tâche en premier ; réintégrer T417, le sujet M3 et la date de dossier dans le nom, car le sous-dossier disparaît. Date de corpus, non date de validation. |
| `DESIGN/SIMU_M3_REALISTE_20261028/LIAISON_APRES_UPDATE.txt` | `T417_PREUVE_LIAISON_APRES_20261028.txt` | Tâche en premier ; réintégrer T417, le sujet M3 et la date de dossier dans le nom, car le sous-dossier disparaît. Date de corpus, non date de validation. |
| `DESIGN/SIMU_M3_REALISTE_20261028/PLAN_SIMU_M3_REALISTE.md` | `T417_PLAN_SIMULATION_M3_REALISTE_20261028.md` | Tâche en premier ; réintégrer T417, le sujet M3 et la date de dossier dans le nom, car le sous-dossier disparaît. Date de corpus, non date de validation. |
| `DESIGN/SIMU_M3_REALISTE_20261028/REPRISE_20261028.md` | `T417_PASSATION_SIMULATION_M3_20261028.md` | Tâche en premier ; réintégrer T417, le sujet M3 et la date de dossier dans le nom, car le sous-dossier disparaît. Date de corpus, non date de validation. |
| `DESIGN/SIMU_M3_REALISTE_20261028/REVIEW_DEEPSEEK_V41.md` | `T417_REVUE_DYNAMIQUE_M3_DEEPSEEK_V4_1_20261028.md` | Tâche en premier ; réintégrer T417, le sujet M3 et la date de dossier dans le nom, car le sous-dossier disparaît. Date de corpus, non date de validation. |
| `DESIGN/SIMU_M3_REALISTE_20261028/SCENARIOS_APRES_UPDATE.txt` | `T417_PREUVE_SCENARIOS_APRES_20261028.txt` | Tâche en premier ; réintégrer T417, le sujet M3 et la date de dossier dans le nom, car le sous-dossier disparaît. Date de corpus, non date de validation. |
| `DESIGN/SIMU_M3_REALISTE_20261028/SCENARIOS_AVANT_UPDATE.txt` | `T417_PREUVE_SCENARIOS_AVANT_20261028.txt` | Tâche en premier ; réintégrer T417, le sujet M3 et la date de dossier dans le nom, car le sous-dossier disparaît. Date de corpus, non date de validation. |
| `DESIGN/SIMU_M3_REALISTE_20261028/SYNTHESE_EXPERTS_A_B.md` | `T417_SYNTHESE_EXPERTS_A_B_20261028.md` | Tâche en premier ; réintégrer T417, le sujet M3 et la date de dossier dans le nom, car le sous-dossier disparaît. Date de corpus, non date de validation. |
| `DESIGN/SPEC_HARNESS_INTEG_TREUIL_T181-00_v0.1.md` | `T181-00_SPEC_HARNAIS_INTEGRATION_TREUIL_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `DESIGN/T181_TASKS_YAML_BLOCK.yaml` | `T181_PROPOSITION_BLOC_CATALOGUE_TACHES.yaml` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `ETUDE_T260_STEP_PREVALIDATION_BENNE_HOMING.md` | `T260_ETUDE_STEP_PREVALIDATION_BENNE_HOMING.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `ETUDE_T54_LATENCE_BOUCLE_v0.1.md` | `T54_ETUDE_LATENCE_BOUCLE_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `ETUDE_T91_SEQ_FREIN_PUISSANCE_v0.1.md` | `T91_ETUDE_SEQUENCE_FREIN_PUISSANCE_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `GEL_GRAFCET_HOMING_CYCLE_20260903.md` | `TXXX_GEL_GRAFCET_HOMING_CYCLE_20260903.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `GEL_GRAFCET_SEMIAUTO_20260903.md` | `TXXX_GEL_GRAFCET_SEMIAUTO_20260903.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `GEL_GRAFCET_SEMIAUTO_AMENDEMENT_T383_20260922.md` | `T383_AMENDEMENT_GEL_GRAFCET_SEMIAUTO_20260922.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `IHM_VARIABLES_MIGRATION.md` | `TXXX_TABLE_MIGRATION_VARIABLES_IHM.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `INTERFACES_AUDIT_A_20260831.md` | `TXXX_AUDIT_INTERFACES_A_20260831.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `INTERFACES_AUDIT_B_20260831.md` | `TXXX_AUDIT_INTERFACES_B_20260831.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `INVENTAIRE_Defauts_Bloquants_MES_20260903.md` | `TXXX_INVENTAIRE_DEFAUTS_BLOQUANTS_MES_20260903.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `MISE_EN_CONFORMITE_AF_QUESTIONS_v0.1.md` | `TXXX_MISE_EN_CONFORMITE_AF_QUESTIONS_V0_1.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `NOTE_T364_PHASE4_DOC_ET_COHERENCE_CYCLE_AUTO.md` | `T364_NOTE_PHASE4_DOC_ET_COHERENCE_CYCLE_AUTO.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `OPENMODELICA_SIMBENCH_MIGRATION_20260917.md` | `TXXX_OPENMODELICA_SIMBENCH_MIGRATION_20260917.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `P3_TEST_AUDIT_PROPOSITIONS_v1.0.md` | `TXXX_AUDIT_P3_TESTS_PROPOSITIONS_V1_0.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `PLAN_AlarmBanner_20260820.md` | `TXXX_PLAN_ALARM_BANNER_20260820.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `PLAN_DIAGNO_ALARMES_T218_220.md` | `T218_PLAN_T220_DIAGNOSTIC_ALARMES.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `PLAN_MIGRATION_TABLES.md` | `TXXX_PLAN_MIGRATION_TABLES.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `PLAN_PERMITS_M3.md` | `TXXX_PLAN_PERMITS_M3.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `PRG02_20260824/DESIGN_TABLE_FONCTIONS_AF_v0.2.md` | `TXXX_DESIGN_PRG02_TABLE_FONCTIONS_AF_V0_2.md` | Tâche en premier ; conserver le contexte PRG02 du sous-dossier dans le nom ; version existante préservée. |
| `PRG02_20260824/PROPOSITION_ArmingPermit_Cablage_v0.1.md` | `TXXX_PROPOSITION_PRG02_CABLAGE_ARMING_PERMIT_V0_1.md` | Tâche en premier ; conserver le contexte PRG02 du sous-dossier dans le nom ; version existante préservée. |
| `PRG02_20260824/QUESTIONS_OUVERTES_PRG02_v0.1.md` | `TXXX_QUESTIONS_OUVERTES_PRG02_V0_1.md` | Tâche en premier ; conserver le contexte PRG02 du sous-dossier dans le nom ; version existante préservée. |
| `PRG02_20260824/REVUE_PRG02_ACQUISITION_v0.1.md` | `TXXX_REVUE_PRG02_ACQUISITION_V0_1.md` | Tâche en premier ; conserver le contexte PRG02 du sous-dossier dans le nom ; version existante préservée. |
| `PRG02_20260824/REVUE_PRG02_HMI_TROUBLESHOOTING_v0.1.md` | `TXXX_REVUE_PRG02_HMI_TROUBLESHOOTING_V0_1.md` | Tâche en premier ; conserver le contexte PRG02 du sous-dossier dans le nom ; version existante préservée. |
| `PRG0405_AUDIT_A_2026-08-31.md` | `TXXX_AUDIT_PRG04_PRG05_A_20260831.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `PRG0405_AUDIT_B_20260831.md` | `TXXX_AUDIT_PRG04_PRG05_B_20260831.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `PRG06_AUDIT_20260831.md` | `TXXX_AUDIT_PRG06_20260831.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `PROMPT_CONSULTATION_DYNAMIQUE_T421.md` | `T421-prompt-consultation-dynamique-treuils.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `PROPOSAL_WT3-T172_X13_X2_20260828.md` | `T172_PROPOSITION_WT3_TRANSITION_X13_X2_20260828.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `PROPOSITION_DEEPSEEK_T421.md` | `T421_PROPOSITION_DYNAMIQUE_TREUILS_DEEPSEEK.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `PROPOSITION_GLM_T421.md` | `T421_PROPOSITION_DYNAMIQUE_TREUILS_GLM.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `QUESTIONS_T164-4.md` | `T164-4_QUESTIONS.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `README.md` | `TXXX_INDEX_AUDITS.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `REORIENTATION_RUMOCA_OPENMODELICA_20260917.md` | `TXXX_REORIENTATION_RUMOCA_OPENMODELICA_20260917.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `REVUE_T358_FORCESTEP_2026-09-21.md` | `T358_REVUE_FORCESTEP_20260921.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `RFC_METHODOLOGIE_2_ETAGES_ET_CHALLENGE_EXPERTS.md` | `TXXX_RFC_METHODOLOGIE_2_ETAGES_ET_CHALLENGE_EXPERTS.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `SESSION_20260824_DECISIONS_EN_ATTENTE.md` | `TXXX_SESSION_20260824_DECISIONS_EN_ATTENTE.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `T154_AF_TC_CI_COVERAGE_20260829.csv` | `T154_DONNEES_COUVERTURE_AF_TC_CI_20260829.csv` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `T154_AF_TC_CI_COVERAGE_20260829.md` | `T154_RAPPORT_COUVERTURE_AF_TC_CI_20260829.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `T154_AF_TRACEABILITY_MATRIX_20260829.yaml` | `T154_MATRICE_TRACABILITE_AF_20260829.yaml` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `T154_export_coverage_csv.py` | `T154_export_coverage_csv.py` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `T154_generate_af_ci_report.py` | `T154_generate_af_ci_report.py` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `T154_test_generate_af_ci_report.py` | `T154_test_generate_af_ci_report.py` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `T181_BILAN_LOT1_2026-08-31.md` | `T181_BILAN_LOT_1_20260831.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `T181_BILAN_LOT2_2026-08-31.md` | `T181_BILAN_LOT_2_20260831.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `T181_BILAN_LOT3_2026-08-31.md` | `T181_BILAN_LOT_3_20260831.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `T196_BUCKET_STATE_20260831.md` | `T196_NOTE_ETAT_BENNE_20260831.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `T197_LEGAL_LIMIT_SIM_BYPASS_20260831.md` | `T197_DIAGNOSTIC_LIMITE_LEGALE_BYPASS_SIMULATION_20260831.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `T202_NOTE_DECISION_ARCHI.md` | `T202_DECISION_ARCHITECTURE_CYCLE.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `T229_DESIGN_FB_CYCLE_STEPS.md` | `T229_DESIGN_ETAPES_FB_CYCLE.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `T314_LEGACY_TRIAGE_20260917.md` | `T314_TRIAGE_LEGACY_TWINBENCH_20260917.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `T332_HOOKS_CLAUDE_CODE_20260920.md` | `T332_AUDIT_HOOKS_CLAUDE_CODE_20260920.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `T356_ALARMES_20260921/T356_aggregation_anyfault.csv` | `T356_DONNEES_ALARMES_AGGREGATION_ANYFAULT_20260921.csv` | Tâche en premier ; conserver le rattachement T356 et la date des annexes après aplatissement. |
| `T356_ALARMES_20260921/T356_bandeau_libelles.csv` | `T356_DONNEES_ALARMES_BANDEAU_LIBELLES_20260921.csv` | Tâche en premier ; conserver le rattachement T356 et la date des annexes après aplatissement. |
| `T356_ALARMES_20260921/T356_candidats_declarations.csv` | `T356_DONNEES_ALARMES_CANDIDATS_DECLARATIONS_20260921.csv` | Tâche en premier ; conserver le rattachement T356 et la date des annexes après aplatissement. |
| `T356_ALARMES_20260921/T356_causes_producteurs.csv` | `T356_DONNEES_ALARMES_CAUSES_PRODUCTEURS_20260921.csv` | Tâche en premier ; conserver le rattachement T356 et la date des annexes après aplatissement. |
| `T356_ALARMES_20260921/T356_errorid_bits_ad_hoc.csv` | `T356_DONNEES_ALARMES_ERRORID_BITS_AD_HOC_20260921.csv` | Tâche en premier ; conserver le rattachement T356 et la date des annexes après aplatissement. |
| `T356_ALARMES_20260921/T356_qualification_defauts.csv` | `T356_DONNEES_ALARMES_QUALIFICATION_DEFAUTS_20260921.csv` | Tâche en premier ; conserver le rattachement T356 et la date des annexes après aplatissement. |
| `T356_ALARMES_20260921/T356_references.csv` | `T356_DONNEES_ALARMES_REFERENCES_20260921.csv` | Tâche en premier ; conserver le rattachement T356 et la date des annexes après aplatissement. |
| `T356_ALARMES_20260921/T356_synthese_scan.json` | `T356_SYNTHESE_ALARMES_SCAN_20260921.json` | Tâche en premier ; conserver le rattachement T356 et la date des annexes après aplatissement. |
| `T356_ALARMES_20260921/T356_univers_complet.csv` | `T356_DONNEES_ALARMES_UNIVERS_COMPLET_20260921.csv` | Tâche en premier ; conserver le rattachement T356 et la date des annexes après aplatissement. |
| `TABLE_ECHANGE_IHM_T299_COMPTEURS_2026-09-20.md` | `T299_TABLE_ECHANGE_IHM_COMPTEURS_20260920.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `TABLE_ECHANGE_IHM_T347_DUREE_CYCLE_2026-09-21.md` | `T347_TABLE_ECHANGE_IHM_DUREE_CYCLE_20260921.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |
| `TRIAGE_AUDITS_VS_TASKS_20261110.md` | `TXXX_TRIAGE_AUDITS_VS_TASKS_20261110.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `TRIAGE_DEEPSEEK_V41_LOT1_20261110.md` | `TXXX_TRIAGE_DEEPSEEK_V41_LOT1_20261110.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `TRIAGE_DEEPSEEK_V41_LOT2_20261110.md` | `TXXX_TRIAGE_DEEPSEEK_V41_LOT2_20261110.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `TRIAGE_DEEPSEEK_V41_LOT3_20261110.md` | `TXXX_TRIAGE_DEEPSEEK_V41_LOT3_20261110.md` | Tâche en premier ; déjà conforme ; conserver le nom. |
| `WT3-T173_RAPPORT_BANC_SIMULATION_20260828.md` | `T173_RAPPORT_WT3_BANC_SIMULATION_20260828.md` | Tâche en premier ; uniformiser la casse, les séparateurs et les dates ; conserver le sens du titre. |

## Adaptations lors de l’application

- Actualiser les chemins historiques `DOC/WFLOW/AUDITS/...`, ceux du dossier déplacé et tous les liens relatifs après aplatissement. Le déplacement déjà effectué a pu casser des références avant ce renommage.
- G525 lit le gel semi-auto : adapter son chemin et son nouveau nom commençant par TXXX, sans interpréter ce préfixe comme une tâche réelle.
- Le test T154 charge explicitement `T154_generate_af_ci_report.py` via `Path(__file__).with_name(...)` : pointer vers `T154_generate_af_ci_report.py`. Son nouveau nom reste tâche en premier (`T154_test_generate_af_ci_report.py`) ; ne pas prétendre à une découverte pytest automatique sans vérifier/configurer sa sélection.
- Synchroniser le scanner T356 avec les noms proposés pour ses CSV/JSON et le répertoire à plat, afin qu’un futur scan ne recrée pas les anciens noms.
- Les journaux et audits datés conservent leurs constatations historiques. Utiliser cette table pour retrouver leurs anciens chemins ; ne pas réécrire rétroactivement les preuves.
- Appliquer les renommages de casse seule via un nom intermédiaire unique sous Windows ; ne jamais écraser une destination.
- Aucun retrait de sous-dossier vide réalisé ; vérifier son contenu avant toute suppression future.

## Références à examiner

Le relevé lexical initial repère 77 fichiers mentionnant des noms qui changeaient dans la première proposition. L’ordre corrigé change aussi des noms auparavant conservés : ce relevé est un point de départ et devra être complété lors de l’application, pas une preuve exhaustive de migration.

| Fichier citant | Noms repérés initialement |
|---|---:|
| `.claude/settings.local.json` | 7 |
| `.trust-lsp/index-cache/index.json` | 1 |
| `DOC/AF/AF_Partie-03_Contrats_Composants/FB_CycleTime_v1.0.md` | 1 |
| `DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md` | 1 |
| `DOC/AF/AF_Partie-10_Fonction_Winch/FB_WinchSync_v1.1.md` | 1 |
| `DOC/AF/AF_Partie-10_Fonction_Winch/FB_Winch_v2.0.md` | 1 |
| `DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md` | 1 |
| `DOC/WFLOW/ETUDES/ANALYSES_T417/PROMPT_CONTRE_EXPERTISE_20261030.md` | 1 |
| `DOC/WFLOW/ORCHESTRATION_RAPPORTS/BRIEFING_T213_2026-11-02.md` | 2 |
| `DOC/WFLOW/ORCHESTRATION_RAPPORTS/PREVISIONS_ORCHESTRATEUR_CYCLES_20260901.md` | 1 |
| `DOC/WFLOW/ORCHESTRATION_RAPPORTS/dsh-ha-orchestrator.run-r-mucgsrnl-1tx8tx.md` | 1 |
| `DOC/WFLOW/PROMPTS/08_BRIEF_T330_P1P2_plan_v1_2.md` | 2 |
| `DOC/WFLOW/REGISTRES/REGISTRE_MES_TEMOIGNAGE_M3_20261030.md` | 1 |
| `DOC/WFLOW/REGISTRES/REGISTRE_Suivi_MiseEnService_20260903.md` | 1 |
| `DOC/WFLOW/REGISTRES/REGISTRE_Suivi_MiseEnService_20260904.md` | 1 |
| `DOC/WFLOW/TASKS.yaml` | 18 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/AUDIT_T356_ALARMES_EXHAUSTIF_20260921.md` | 9 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/AUDIT_TACHES_CONTRATS_LIAISON_20260904.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/BASELINE_SEQUENCEURS_HOMING_CYCLE_20260903.md` | 2 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/CYCLES_AUDIT_A_20260831.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/ANALYSE_T361_RECALAGE_M3_OPTIONS_2026-09-21.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/AUDIT_T300_TRACE_20260904_v1.0.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/AUDIT_TRIAGE_WINCH_INTEG_20260922.md` | 2 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/BRIEFS_T181/EXEC/EXEC_T175_ecarts_code_treuils.md` | 2 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/BRIEFS_T181/EXEC/EXEC_T181-00b_calibration_vecteurs.md` | 3 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/BRIEFS_T181/RESULTS/B2_challenge3_resultat.md` | 2 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/CADRAGE_T181-06_DRIVEREQUEST.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/CADRAGE_T181-11_MATRICE_MAINT.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/CADRAGE_T330_INVARIANT_HAUT_v1.0.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/CHALLENGE_T175-01_02_M2_BUCKET_SAFETY.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/CHALLENGE_T336_HOMING_HYPOTHESE_MONTEE_2026-09-20.md` | 3 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/CHALLENGE_T340_REFONTE_HOMING_2026-09-20.md` | 3 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/DECISIONS_T146_ARBITRAGE_ISO13849.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/DECISIONS_T175_C0_VISA_HUMAIN.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/DESIGN_EMERGENCYSTOPOK_CONFIRMATION_TEMPORISEE_v0.2.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/DESIGN_T144B_INTERFACES_PRG6_v0.1.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/DESIGN_T181-01_PROTOCOLE_3BIS_v0.1.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/DIAGNOSTIC_T224_ARMINGPERMIT_20260921.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/DIAGNOSTIC_T346_BORNE_RECUL_2026-09-20.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/PLAN_GEL_TREUIL_T181_v0.1.md` | 3 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/PLAN_T192corrections_safety_cycles_reste.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/PLAN_T194optimisations_interfaces.md` | 2 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/PLAN_T330_C3_INVARIANT_HAUT_v1.0.md` | 2 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/SIMU_M3_REALISTE_20261028/BILAN_UPDATE_ET_ESSAIS.md` | 4 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/SIMU_M3_REALISTE_20261028/CONTRACT_UPDATE_DYNAMIQUE_M3.yaml` | 7 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/SIMU_M3_REALISTE_20261028/GATES_APRES_UPDATE.txt` | 7 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/SIMU_M3_REALISTE_20261028/GATES_AVANT_UPDATE.txt` | 6 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/SIMU_M3_REALISTE_20261028/PLAN_SIMU_M3_REALISTE.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/SIMU_M3_REALISTE_20261028/REPRISE_20261028.md` | 4 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/DESIGN/T181_TASKS_YAML_BLOCK.yaml` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/INTERFACES_AUDIT_B_20260831.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/PLAN_MIGRATION_TABLES.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/PRG02_20260824/DESIGN_TABLE_FONCTIONS_AF_v0.2.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/PRG02_20260824/PROPOSITION_ArmingPermit_Cablage_v0.1.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/PRG02_20260824/QUESTIONS_OUVERTES_PRG02_v0.1.md` | 2 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/PRG0405_AUDIT_B_20260831.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/README.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/T154_test_generate_af_ci_report.py` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/T181_BILAN_LOT1_2026-08-31.md` | 2 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/T229_DESIGN_FB_CYCLE_STEPS.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/T332_HOOKS_CLAUDE_CODE_20260920.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/TABLE_ECHANGE_IHM_T347_DUREE_CYCLE_2026-09-21.md` | 1 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/TRIAGE_AUDITS_VS_TASKS_20261110.md` | 113 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/TRIAGE_DEEPSEEK_V41_LOT1_20261110.md` | 38 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/TRIAGE_DEEPSEEK_V41_LOT2_20261110.md` | 41 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/TRIAGE_DEEPSEEK_V41_LOT3_20261110.md` | 36 |
| `DOC/WFLOW/TASKS/TXX-X_TEMP (A RANGER)/AUDITS/WT3-T173_RAPPORT_BANC_SIMULATION_20260828.md` | 1 |
| `DOC/WFLOW/TASKS_ORCHESTRATOR.yaml` | 14 |
| `DOC/WFLOW/TASK_VIEWER.html` | 12 |
| `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md` | 1 |
| `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T370_DISCORDANCE_CONTACTEURS_20260921.md` | 2 |
| `TOOLS/AGENT_WORKFLOW/config/contract_refs_baseline.json` | 1 |
| `TOOLS/AGENT_WORKFLOW/scripts/T356_scan_alarm_candidates.py` | 8 |
| `TOOLS/CMD_PATH_VIEWER/data/graph.js` | 1 |
| `TOOLS/CMD_PATH_VIEWER/data/graph.json` | 1 |
| `TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/reports/FB_CfgT330Normalizer.html` | 2 |
| `TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/reports/M_MAIN.html` | 2 |

## Fichiers de cette proposition

Les deux fichiers produits pour proposer le rangement sont hors des 154 sources initiales. Pour une application complète, leurs propres noms proposés sont :

| Nom actuel | Nom proposé |
|---|---|
| `PROPOSITION_RENOMMAGE_APLATISSEMENT_AUDITS_20261110.md` | `TXXX_PROPOSITION_RENOMMAGE_APLATISSEMENT_AUDITS_20261110.md` |
| `CORRESPONDANCE_RENOMMAGE_AUDITS_20261110.json` | `TXXX_CORRESPONDANCE_RENOMMAGE_AUDITS_20261110.json` |
