# 📦 Historique des versions CODESYS — Lien DOC ↔ CODE

Trace le programme CODESYS testé/validé à un instant donné, pour retrouver quelle version de l'analyse fonctionnelle (`DOC/AF/AF_Partie*`) lui correspondait (retour arrière, FAT/SAT, essais site).

**Une ligne par jalon significatif.** Format : `date · jalon · résultat · renvoi`. Preuves terrain détaillées : `WFLOW/REGISTRES/`.
📦 Le détail complet de chaque entrée (corps, chiffres, listes de fichiers) est conservé tel quel dans
`ARCHIVES/Doc/VERSION_HISTORY_DETAIL_20261110.md` (archive — jamais une source active).
Les noms de version réutilisés dans le journal d'origine (`v0.4.18`, `v0.4.26`, `v0.4.27`) sont gardés tels quels.

## 2026-10

- 2026-10-29 · `SIMU_T421_20261029` · simu : glissement inertiel treuils (trace Suivi_86), dérive de plongée benne 100 % physique, `SimBucketSpeedFactor` · `work/base-machine-simu` · G200 PASS (2167 instances)

## 2026-09

- 2026-09-23 · `MES_FIN_20260923` · fin MES : inversion DI M1/M2, AX15B/AX15D sécurisé, verrou M3 T392, anti-rebond FdC M3, compteurs horaires · `main` `4968a541` · G200 PASS (2070 instances)
- 2026-09-07 · `MES_055_SEANCE_20260907` · MES-051→055 : `BucketActivityHold` 4 s, pages IHM/modes, `BypassAuPowerCutOff` au boot (T264), FdC haut (T268) · `backup/mes-septembre-20260902` · [registre](WFLOW/REGISTRES/REGISTRE_Suivi_MiseEnService_20260907.md)
- 2026-09-05 · `MES_046` / `MES_047` / `MES_048` · traces treuils validées, 0 défaut : cycle M1/M2 + benne (71 s), ouverture benne en haut (23 s), pleine vitesse synchro (46 s) · HEAD `35fe44ff` · [registre](WFLOW/REGISTRES/REGISTRE_Suivi_MiseEnService_20260905.md)
- 2026-09-03 · `GRAFCET_HOMING_HX0-HX6_T146` · homing en GRAFCET `HX0..HX6`, cible M2 corrigée, plafond palier 1 hors homing (C4 interim, visa ISO 13849 ouvert)
- 2026-09-02 · `AF01_v1.4_EMERGENCY_MANAGEMENT_T173C` · AF01 v1.4 : 3 bypass MES orthogonaux, délais 500 ms / 1 s / 5 s, message opérateur par cause d'abandon

## 2026-08

- 2026-08-30 · `AF09_v2.4_CENTRE_PLAGE_PRESET` · spec seule : preset au centre de plage `16#1000000` (F09.08, TC-P09-070) ; code non modifié, à charger
- 2026-08-28 · `T166_T170_REFONTE_CYCLES_ET_DIAGNOSTICS` · cycles centralisés dans `PRG_03`, `ST_OperatorCoupledIntent`, Kobold T167, `DumpAtTremie` T168 · CI 27/27, gates 22/22
- 2026-08-27 · `T164-6_RENOMMAGE_DUT_NC110` · 11 DUT renommés `ST_fb<Fb>_<Role>` · G200 PASS
- 2026-08-27 · `T164-5_MIGRATION_TRANSVERSE_FAULT_LIFECYCLE` · `ST_Status` supprimé → `ST_Fault` + `ST_Lifecycle` sur 17 FB · CI 27/27
- 2026-08-27 · `T164-4_ENCODER_HW_SPLIT_PRESET_FAULTCORE` · frontière HW codeur (`HwIn`/`HwOut`), Cfg persistante, façade `FB_FaultCore`
- 2026-08-27 · `T163_ROOT_CAUSE_MASKING_ET_BYPASS_GRANULAIRE` · masquage cascade du bandeau, bypass réseau granulaires, `GVL_IHM` sans RETAIN · validé banc
- 2026-08-20 · `T144_ALARM_BANNER` · bandeau d'alarme défilant n/N · AF-07 v2.1
- 2026-08-18 · `T123_Standardisation_Complete` · commentaires/tags/régions sur 169 `.st` ; code exécutable identique à HEAD
- 2026-08-18 · `T123-I_Translation_Commentaires` · idem sur les 7 sources `I_TRANSLATION`
- 2026-08-18 · `T123_REGIONS_Standardisation` · convention `{region "§N …"}` (`CODE_QUALITY_STANDARDS §2bis`)
- 2026-08-18 · `v0.6.8_Refactor_Indexation_Dossiers_Flux_Chronologique` · `CODE/` indexé `A_COMMUN` → `M_MAIN`, 18 gates adaptés
- 2026-08-07 · `v0.6.00_Bascule_Chantier` · clôture journée MES `v0.5.25_DepartSoirEssai` ; préréception le 17
- 2026-08-07 · `TREUILS_JOYSTICK_SESSION_TERRAIN` · retours terrain (`228c438`..`b97a511`) : frein direct sans `FB_Brake`, `RestartDelay`, vidage trémie, FdC haut logiciel, limite légale de profondeur, bypass communs, réglages joystick
- 2026-08-06 · `M3_TRANSLATION_TERRAIN_SESSION` · (`076377e`..`a9b016f`) position M3 persistante, 3 vitesses d'approche, détection `AtXxx`, `InvertDirection` côté variateur
- 2026-08-05 · `MES_20260805_LOTS0A4_SECURITE_ET_SORTIES` · (`21170be`..`f6e404b`) AC600 M3, homme-mort M3 (T106), `PowerCutOff` M1/M2/M3, fix collision de noms `PRG_06` (MES-016)
- 2026-08-04 · `DOC_RATIONALISATION_ACQUISITION_FB_INPUT` · doc : `PRG_02_Acquisition` = frontière unique `HwReal/HwSim/HwIn` ; aucun code supprimé
- 2026-08-04 · `FIX_PRG06_IMPORT_MULTICAUSES` · 5 causes d'échec d'import `PRG_06` corrigées ; garde-fou `check_ld_invariants.py` (GATE 4ter)
- 2026-08-04 · `REDUCE_FB_OUTPUT` · `FB_Output` réduit à 2 entrées / 1 sortie (partie FEEDBACK retirée)
- 2026-08 · `M0BIS_ALIGNEMENT_DOC_7POU` · doc seule : 7 POU par ensemble mécanique, dossiers C4 anciens archivés ; arbitrage T103 ouvert
- 2026-08-01 · `RU-4_ARCHITECTURE_MAINTASK` · ⚠️ **PÉRIMÉE** (remplacée par `M0BIS`) ; aucun `CODE/` modifié
- 2026-08-01 · `LOT_A_SUPPRESSION_CODE_MORT` · 3 objets jamais câblés supprimés ; règle L13 de `check_linkage.py`

## 2026-07

- 2026-07-28 · `LOT3A_FinalBrakePowerInterlock` · `FB_WinchOutputInterlock_LD` (watchdog 500 ms) et `FB_TranslationOutputInterlock_LD` ; 07-29 : instances déplacées dans `PRG_10_Outputs_LD` · qualification CODESYS différée
- 2026-07-28 · `LOT2A_KoboldMaintenanceAssist` · `FB_DiveSearch` Kobold 0→1→0, `FB_ExtractionSequence` · AF_Partie-04 v1.5
- 2026-07-28 · `T84-T85-T86_EncoderSpeedOwnership` · vitesse M1/M2 passée à la chaîne codeur `PRG_02` · AF_Partie-09 v1.13, AF_Partie-10 v1.11
- 2026-07-28 · `v0.5.3_PreCommissioningPrep` · préparation recettes pré-livraison, registre post-MES
- 2026-07-28 · `DOC_RegistreSuiviPostMES_Livraison10Aout` · cadrage du registre post-MES (livraison cible 10 août)
- 2026-07-27 · `L7-L8_HwSim_Verrou_Specs` · `HwSim` observable dans `PRG_00_Inputs`, gates de confinement · AF_Partie-13 v2.0, AF_Partie-06 v1.7
- 2026-07-27 · `v0.5.2_Troubleshooting_SignalChain` · `PRG_11_Troubleshooting` lecture seule + `GVL_Troubleshooting` (5 fonctions) · AF_Partie-14
- 2026-07-26 · `v0.5.1_PlcTestsFrameworkRemoval` · framework de tests in-PLC retiré et archivé (158 → 114 `.st`) · `bce21c9`, `d9daa41`
- 2026-07-26 · `v0.5.0_PostCableReplacement` · jalon après remplacement des câbles ; anciens projets de qualification archivés
- 2026-07-24 · `v0.4.27_Audit_Persistance_Bypass_Frein` · audit `PERSISTENT`/`RETAIN`, incident d'échauffement frein · `DOC/AUDITS/RAPPORT_Audit_Persistance_Bypass_Frein_v1.0.md`
- 2026-07-24 · `v0.4.26_ConfigPersistence_TranslationSupervisionSuite` · clôture `ConfigPersistence` (lots 1-6), `SetFreq_Hz` protégé · `a88e56d`, `3faa941`
- 2026-07-23 · `DOC_RESTORATION_AF07_AF11` · restauration post-audit AF-11 v1.12 et AF-07 v1.9
- 2026-07-23 · `AUDIT_ConfigPersistence` · audit de persistance de tout `GVL_IHM`
- 2026-07-23 · `CONFIG-PERSIST-01` · sentinelles `= 0.0` remplacées par flags `Initialized`, alarme `ConfigRestoredFromPersistent`, `BypassRestoreDone` RETAIN · test PLC T65 restant
- 2026-07-23 · `DOC_ClassementEtREX_Treuils` · anciens documents archivés, NAVBOARDs regroupés ; plafond palier essais treuils à `0` (T64)
- 2026-07-23 · `96ef589` · bypass globaux/ciblés Winch, M3, synchro, benne, réseau ; homing unitaire M1/M2
- 2026-07-23 · `DOC_SuiviMiseEnService` · registre historique MES créé ; `PLAN_TASK` = source des actions différées
- 2026-07-22 · `v0.4.31_CommissioningDocsIhmState` · NAVBOARD Joystick/M3 et checklists v1.1 alignés sur `.Cmd/.State/.Safety`
- 2026-07-22 · `v0.4.30_SupervisionStateAndExportFix` · `.Status.` → `.State.`, DUT regroupés, 201 erreurs de compilation corrigées
- 2026-07-22 · `v0.4.29_SupervisionStructuredCmdStatus` · supervision Winch/Translation en Cmd/Status/Cfg · AF-07 v1.6
- 2026-07-22 · `v0.4.28_SupervisionFrenchExceptions` · exceptions de nommage français IHM (`M1TreuilRetenue`, `M2TreuilBenne`, `M2Benne`)
- 2026-07-22 · `v0.4.27_SupervisionConformityRename` · renommage `GVL_IHM` / `ST_*HMI`, suffixes d'unité `_M` `_Pct` `_Hz` `_Mps`
- 2026-07-22 · `v0.4.26_IhmCompatibilityRepair` · noms publics IHM historiques restaurés ; `GVL_PERSISTENT` ajouté au bundle · compilation à confirmer
- 2026-07-22 · `v0.4.25_TranslationM3_JoystickAnimation` · `JoystickDeflectionPct` axe X M3 signé · AF-07 v1.7, AF-11 v1.11
- 2026-07-22 · `v0.4.24_TranslationM3_Positioner` · MAINT M3 : positionneur explicite, boutons IHM sans fallback joystick · AF-07 v1.6, AF-11 v1.10
- 2026-07-22 · `v0.4.23_TranslationM3_PersistentRamp` · rampes et plafond auto M3 passés en `PERSISTENT`, source unique de fréquence max
- 2026-07-22 · `v0.4.22_IHM_Joystick_Supervision` · renommage masse SUPERVISION (~50 champs), paramètres joystick persistants
- 2026-07-21 · `v0.4.21_SimM3BootFix` · polarité frein Méca B corrigée, boot simu M3 sain
- 2026-07-21 · `v0.4.20_WinchCorePrep` · WINCH-CORE-01, hauteurs 8,0 / 8,5 m, tests PLC Modes TC-M7→M12
- 2026-07-21 · `v0.4.19_CommissioningPrep` · préparation mise en service terrain, bundle `MGS_v0.4.19_CommissioningPrep` · `DOC/AUDIT_Winch_v1.0.md`
- 2026-07-21 · `Audit_Winch_v1.0` · audit treuils M1/M2 : 2 P0 (hauteurs incohérentes, `MaxStepNumber` non borné), 5 P1, plan en 3 phases
- 2026-07-19 · `v0.4.18_PlcTests_ManualSuites` · suites PLC_TESTS séparées, `RunAll` déprécié
- 2026-07-18 · `v0.4.18_DocSweep_IHMRetrait` · passe documentaire ; `IHM_MANU` retiré (pilotage = MAINT_N1/N2 + joystick homme-mort) · `397cee0`
- 2026-07-18 · Plan logiciel initial — clôture · homing unitaire MAINT_N2, Safety Winch bits 14/15, Safety Translation AC600 ; reliquats = constructeur/client/terrain
- 2026-07-18 · Doc plan vitesse codeur / paliers · T41→T48 : vitesse câble m/s, 5 paliers mesurés, garde-fou de changement de palier
- 2026-07-18 · `v0.4.17_SemiAuto_CycleSafety` · homme-mort sur tous mouvements semi-auto, cycle Kobold raccordé, E/S Kobold `%IX0.5` / `%QX0.6`
- 2026-07-18 · `v0.4.16_ReferenceToFix_BucketRun` (M3) · codage 5 capteurs, `FB_Translation_PositionDecoder` · AF-11 v1.8, architecture v2.12
- 2026-07-18 · `v0.4.16_ReferenceToFix_BucketRun` (PLC_TESTS) · séquenceur anti-blocage, watchdog, journal d'événements
- 2026-07-17 · `v0.4.16_ReferenceToFix_BucketRun` · fix générateur `REFERENCE TO`, `REF=` dans `PRG_06_WinchControl` · RUN OK en simulation CODESYS
- 2026-07-16 · Doc seule · AF_Partie-14 v1.2 : spec finale du framework de test in-PLC ; aucun `CODE/` modifié
- 2026-07-16 · `v0.4.15_PlcTestsFramework_TranslationSuite` · framework tests migré vers AF-14 v1.2 (tables déclaratives, `FB_TestSequencer`) · ⚠️ bug lockout `EmergencyArmingLockoutActive` connu non résolu
- 2026-07-16 · `v0.4.15_IHM_MANU_TranslationHoming` · Translation alignée sur Winch (`IHM_MANU` 3ᵉ source), bypass homing retirés · AF-11 v1.7
- 2026-07-16 · Corrections nommage + intégration · `FB_Benne→FB_Bucket` restauré, suite `FB_BucketValidation` intégrée · version de test non réimportée
- 2026-07-16 · `v0.4.14_SafetyValidation_EmergencyChain` · `FB_Safety_EmergencyChain`, banc de test de la boucle d'urgence · AF-14 v1.0
- 2026-07-16 · `v0.4.13_GlobalRename_GVL_Persistent` · renommage global Chariot→Translation, Grappin→Benne ; `GVL_PERSISTENT` réorganisée ; T30 fréquence translation 30 / 60 Hz
- 2026-07-15 · `v0.4.12_TranslationHMI_Migration` · `ST_TranslationHMI` reprend les commandes de `IHM_MANU` ; non réimporté en CODESYS
- 2026-07-15 · `v0.4.11_Translation_AC600_Safety` · EtherCAT AC600 nominal M3, Méca A/B, fins de course extrêmes
- 2026-07-15 · `v0.4.10_FdcBucket_Rename` · TASK-0002 : `FdcBucketOpen/Close` → `OpenEnable/CloseEnable`
- 2026-07-15 · Retrait `DOC/AGENT_HANDOFF/` · remplacé par le plugin antigravity (posé en v0.4.8)
- 2026-07-15 · `v0.4.9_JoystickWinchSelect_N2` · TASK-0001 : joystick M1/M2 seul restreint à MAINT_N2, sinon forcé couplé
- 2026-07-15 · `v0.4.8_IHM_MANU_FBWinch` · `IHM_MANU` pilote M1/M2 via `FB_Winch`, doctrine « Conditional Bypass », limite câble 12,0 m
- 2026-07-14 · `v0.4.7_IHM_MANU_JOY` · doctrine « Conditional Bypass » (sécu/homing), timers homme-mort dynamiques
- 2026-07-14 · `v0.4.6_IHM_MANU_JOY` · joystick CANopen X/Y, paliers K1-K4, FdC virtuelles benne
- 2026-07-09 · `v0.4.5_IHM_MANU` · lecture codeur réel forcée en mode Manu
- 2026-07-08 · `v0.4.4_IHM_MANU` · structure `IHM_MANU` (pilotage direct de secours)
- 2026-07-08 · `v0.4.3_SimNoHardware-YGO_CablePre-Commissioning` · simu sans blocage validée, avant enroulage réel
- 2026-07-08 · `v0.4.2_SimNoHardware-SyncBypass` · butée haute M2 dynamique 12 / 14 m, bypass synchro en butées
- 2026-07-08 · `v0.4.1_SimNoHardware-SyncUpdate` · Méca E synchro critique ; arrêt rampe normale sur écart mineur
- 2026-07-08 · `v0.4.0_SimNoHardware` · mouvements M1/M2 + benne stables en simulation, aucune MES matérielle
