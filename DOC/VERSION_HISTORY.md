# 📦 Historique des versions CODESYS — Lien DOC ↔ CODE

Trace le programme CODESYS testé/validé à un instant donné, pour retrouver quelle version de l'analyse fonctionnelle (`DOC/AF_Partie*`) lui correspondait (retour arrière, FAT/SAT, essais site).

Une entrée par jalon significatif — pas besoin de logguer chaque sous-version mineure. Lignes courtes (~70 caractères), style `·` compact.

### `T144_ALARM_BANNER` — 2026-08-20 — bandeau d'alarme défilant (carrousel n/N)
- **`ST_AlarmBanner`** (nouveau) + champ `ST_HmiBanner.AlarmBanner` : carrousel des défauts actifs machine entière (M1/M2/M3, benne, sync, dive/extraction, AU, cycle), 1 message à la fois, `AlarmHoldTime` paramétrable (défaut `T#1s`).
- **`FB_Hmi_BannerFormatter` §5** : dictionnaire organe+raison vérifié bit à bit contre le code source réel — corrige les bits `FB_Bucket.ErrorId` du plan initial (bit0/1/3 inversés), ajoute le bit3 "Startup" manquant d'`EmergencyDiag`, construit le dictionnaire `FB_Cycle.ErrorId` (absent du plan).
- Gates palier C 15/15 PASS, G200 liaison PASS, AF-07 versionnée `v2.0`→`v2.1` (§4bis).

### `T123_Standardisation_Complete` — 2026-08-18 — standardisation commentaires/tags/régions sur tout CODE/
- **Passage exhaustif A→M (169 fichiers ST)** : cartouches ≤15L, flèches ASCII + tags de rôle sur les déclarations, régions `{region "§N ..."}` sur les FB/PRG conséquents, purge des REX/dates/lots des commentaires avec reformulation des invariants liés aux AF.
- **Preuve de non-impact logique** : 103 fichiers modifiés vérifiés — code exécutable identique à HEAD (comparaison hors commentaires), `git diff --check` PASS.
- **Convention des régions documentée** dans `CODE_QUALITY_STANDARDS.md §2bis` (format `§N`, aligné sur les sections du corps).
- **Aucun commit** créé.

### `T123-I_Translation_Commentaires` — 2026-08-18 — standardisation commentaires Translation M3
- **Purge REX/dates/lots des 7 sources `CODE/I_TRANSLATION/`** : cartouches ≤15L, flèches ASCII + tags, invariants safety reformulés de façon intemporelle (liés AF11/AF03).
- **Aucune ligne exécutable ni interface modifiée** (comparaison HEAD vs working : code identique).
- **Historique conservé** dans les fiches AF11 existantes (`FB_Translation_v1.1.md §10`, `FB_Translation_PositionDecoder_v1.1.md §3bis`) — pas de REX duplicatif créé.
- **Standards** : `CODE_QUALITY_STANDARDS.md` corrigé — whitelist emojis validée CODESYS projet (remplace « Unicode BMP garanti »).

### `T123_REGIONS_Standardisation` — 2026-08-18 — convention des régions `{region ...}`
- **Convention documentée** dans `CODE_QUALITY_STANDARDS.md §2bis` : format `{region "§N <Description>"}`, numérotation alignée sur les sections du corps, sous-sections `§Nbis/§Nter`.
- **8 fichiers convertis** du style descriptif au style `§N` : `FB_Safety_EmergencyManagementLogic`, `FB_Winch`, `FB_Safety_Winch`, `FB_WinchSync`, `FB_Bucket`, `FB_Cycle`, `FB_Translation`, `FB_Safety_Translation`.
- **Aucune ligne exécutable modifiée** (les régions sont des balises d'éditeur sans effet logique) ; `git diff --check` PASS.

### `v0.6.8_Refactor_Indexation_Dossiers_Flux_Chronologique` — 2026-08-18 — refactoring architecture dossiers `CODE/` (flux logique chronologique)
- **Refonte de l'arborescence `CODE/`** : indexation préfixée de `A_COMMUN` à `M_MAIN` pour refléter la logique et la chronologie du flux d'exécution automate :
  - `A_COMMUN` · `B_AU_SECURITE` · `C_DIAG_RESEAUX` · `D_JOYSTICK` · `E_CODEURS` · `F_MODES` · `G_CYCLE` · `H_TREUILS_BENNE` · `I_TRANSLATION` · `J_SUPERVISION` · `K_DEPANNAGE` · `L_SIMULATION` · `M_MAIN`
- **Outillage & Gates** : adaptation complète des 18 gates de validation (G100 à G420), hooks bloquants, tests pytest et régénération synchronisée de `CODE_XML/` et `naming_baseline.json`.
- **Alignement documentaire** : mise à jour des contrats de composants, des fiches AF et des chemins relatifs d'architecture.

### `v0.6.00_Bascule_Chantier` — 2026-08-07 — transition de version pour la suite des essais
- **Clôture journée MES** sur `v0.5.25_DepartSoirEssai` (retours terrain : voir `TREUILS_JOYSTICK_SESSION_TERRAIN` ci-dessous)
- **Passage en `v0.6.00`** pour la suite du chantier et les **prochains essais** (nouvelle architecture)
- 📦 **Point de sauvegarde** : snapshot daté du code `v0.5.25_DepartSoirEssai` = référence fonctionnelle pour comparaison agents/IA (hors `CODE/` actif)
- 📅 **Préréception le 17** — retours à intégrer ensuite

### `TREUILS_JOYSTICK_SESSION_TERRAIN` — 2026-08-07 — retours terrain treuils/joystick (commits `228c438`..`b97a511`)
- **Retrait `FB_Brake` (M1/M2)** : frein couplé directement `BrakeCmd := RelayFwd OR RelayRev` (`FB_WinchOutputInterlock_LD`), recalculé indépendamment dans `PRG_06_Outputs_LD` (barrière finale visible) ; M3 non touché
- **`RestartDelay`** : bascule de "retombée contacteur" à "frein réellement fermé" (`BrakeFeedback`), 1000ms→1500ms, puis re-sécurisé pour exiger `NOT BrakeFeedback` ET `NOT MotorRequest` (audit croisé, retour terrain)
- **Mode vidage trémie** (`TglEnableDumpAtTremie`) : nouvel assistant MAINT_N1/N2, réutilise `FB_Bucket` sans nouveau séquenceur ; verrouillage descente hors P1/Maintenance
- **`GVL_Troubleshooting.AssistanceDragage`** : visibilité détaillée des 3 modes assistants (Dive/Extraction/DumpAtTremie)
- **`BypassMotorThermal`** ajouté (symétrie avec `BypassBrakeThermal`, manquant)
- **Joystick** : filtre PT1 axes supprimé (0ms), `NeutralHoldTime` 500→100ms puis grâce 3s post-armement (`DeadmanArmGraceTime`) pour éviter un désarmement quasi-immédiat après un armement au neutre ; armement par maintien 100ms indépendant de la position des axes ; zone morte 10%→6%→compte brut ADC (300) ; nouveau signal `AtNeutral`
- **`BypassGlobal` M1/M2** : ne masque plus les fins de course physiques (haut/bas) ni l'alarme IHM associée — seuls les bypass individuels dédiés le peuvent désormais
- **Fin de course haut LOGICIEL** : nouveau blocage immédiat (`CablePosM >= TopLimitM`), absent jusqu'ici (seul Méca D, différé, le surveillait) — bypass dédié `TopLimitSoftware`
- **Limite légale de profondeur** : bloque désormais réellement la descente manuelle (`ForbidDescent`), auparavant consommée uniquement par `FB_Cycle` (aucun effet en manuel) ; ralentissement progressif fusionné avec la limite câble (`BottomLimitM` = la plus restrictive des deux)
- **Ralentissement bordure** : plafond palier direct réglable (`WinchSlowdownMaxStep`, défaut 1) au lieu d'un plafond en % (`WinchSlowSpeed_Pct`, retiré)
- **Bypass commun granulaire** (`Commun.Bypass.TopLimitSwitch/TopLimitSoftware/CableLimitSwitch/LimitLegal`) : lève une protection sur M1+M2 simultanément (pilotage "both"), en OR avec les bypass individuels — jamais de désactivation croisée
- **REX terrain non-code** : délai ~500ms au relâcher joystick tracé jusqu'à `GVL_PERSISTENT._JoystickFilterTime` (RETAIN resté à 100ms malgré défaut source 0ms) — écriture forcée en ligne, pas de bug logiciel
- 17/17 gates verts à chaque commit, bundle régénéré et testé en direct sur machine réelle entre chaque lot

### `MES_20260805_LOTS0A4_SECURITE_ET_SORTIES` — 2026-08-05 — session MES : safety & sorties (commits `21170be`..`f6e404b`)
- **LOT0** : `FB_Diag_IhmHeartbeat` instancié dans `PRG_07_Supervision`
- **LOT2** : sortie moteur AC600 M3 câblée (`DriveFreqRefWord`, échelle ×100 confirmée terrain)
- **LOT3** : homme-mort joystick exigé pour tout mouvement M3 (`T106`)
- **M4** : `FB_Safety_Translation` câblé dans `PRG_05_Translation`
- `FB_Safety_Winch` M1/M2 instancié · chaîne codeur M1/M2 complétée (Safety bornage + SpeedMeasure) · **`PowerCutOff` M1/M2/M3 câblé** à la coupure amont
- **Fix `PRG_06`** : collision de portée nom HW (`*_RQ`/`*_DQ` identiques aux variables auto-créées du mapping) → sorties jamais réellement pilotées (**MES-016**)
- Barrières finales M1/M2/M3 visibles en Ladder + garde-fou LD · checklists chronologiques dépanage (Homing/Safety/Joystick/Motion) + fix homing capteur haut
- Reset watchdog frein conditionné M1/M2/M3 (pattern Cause/Ack) · fix inversion sens rapide translation
- 17/17 gates verts à chaque commit

### `M3_TRANSLATION_TERRAIN_SESSION` — 2026-08-06 — mise en service terrain temps réel (commits `076377e`..`a9b016f`)
- **Position estimée M3 persistante** : reprise après reboot (`GVL_PERSISTENT._TranslationPosEstimated_M`)
- **Cfg Translation** : 3 vitesses d'approche réglables IHM + persistantes (`ST_TranslationCfg`, pont dédié, doctrine `ST_WinchCfg`)
- **Détection d'arrivée `AtXxx`** : 3 conceptions testées en direct, la 3e retenue (front du capteur PROPRE à chaque position, verrou libéré sur mouvement réel confirmé ≥1.5s) — détail `FB_Translation_PositionDecoder_v1.0.md` §3bis
- **`InvertDirection`** : déplacé de l'arbitrage amont vers le mot de commande variateur uniquement (`FB_Translation` §7bis) — désaccordait toute la logique sécurité/ralentissement avec le câblage moteur réel
- **Ralentissement** : généralisé à 3 zones indépendantes, gate mode Maintenance sur la zone P2→P1
- **`MaintenanceM3TargetEnable`** : élargi à (MAINT_N1 OU MAINT_N2) ET bit IHM dédié conscient (`TglMaintenanceZoneAccess`)
- 16/16 gates verts à chaque commit, bundle régénéré et testé en direct sur machine réelle entre chaque lot

### `DOC_RATIONALISATION_ACQUISITION_FB_INPUT` — 2026-08-04 — documentation préalable
- AF02 v3.1, AF03 v2.1, AF06 v2.1, AF13 v2.1, AF14 v1.1 et fiches associées : `PRG_02_Acquisition` devient la frontière unique `HwReal/HwSim/HwIn`.
- `PRG_01_Inputs_LD`, `FB_Input` et `ST_InputsQualified` passent en retrait contrôlé ; aucun code supprimé dans cette phase.
- PRG06/PRG07 remappés vers `PRG_02_Acquisition.HwIn` ; filtrage des 22 TOR déplacé dans `FB_DigitalInputFilter` via `HwRealQualified`.
- Pré-requis code : validation humaine C3 et essais réels/simulés des polarités, filtres et SafeStop.
- `Device.export` interdit de modification ; revue autonome à faire avant tout lot code.

### `FIX_PRG06_IMPORT_MULTICAUSES` — 2026-08-04
- **Bug import CODESYS** : `PRG_06_Outputs_LD` échouait à l'import (`IndexOutOfRangeException`) puis à l'ouverture (`ArgumentNullException`)
- **Causes racines (5, empilées)** : ① parasites `Bundle_H*.xml` découverts comme POU ; ② `localId` bloc > sources ; ③ motif `inVariable→outVariable` ; ④ coils `_DQ` non déclarées (Device) ; ⑤ coil doublon sur output déjà assigné
- **Correction** : script `gen_prg06_oracle.py` + postprocess (ObjectId conservé) + `file_discovery.py` filtre `Bundle_*`
- **Garde-fou** : `check_ld_invariants.py` (GATE 4ter) — localId bloc < sources, pas de double assignement, coils déclarées, pas d'outVariable
- **REX** : `DOC/REX_PRG06_Import_Error.md` v1.0 (l'ancienne cause "premier output câblé" était FAUSSE/insuffisante)

### `REDUCE_FB_OUTPUT` — 2026-08-04
- **Réduction** : `FB_Output` amputé de la partie FEEDBACK (validé utilisateur) — 7 inputs + 4 outputs → **2 inputs + 1 output**
- **Retirés** : `FeedbackRaw`, `UseFeedback`, `Blink1Hz`, `FeedbackTimeout`, `ChannelOk`, `FeedbackOk`, `Error`, `ErrorId` (0 usage — 15 instances PRG_06 connectent `Command`→`.State`)
- **Gain** : réseau LD PRG_06 passe de 1 contact + 6 inVariable à 1 contact + 1 inVariable (bloc ~2× plus compact)
- **Diagnostic contacteur** : reste couvert par `FB_Safety_Winch` (`FwdRevSpeedFeedbackOff`, `BrakeFeedback`)

### `M0BIS_ALIGNEMENT_DOC_7POU` — 2026-08 (documentation seule)
- Architecture actée : **7 POU par ensemble mécanique**, chaque procédé portant sa safety dans sa page
- `PRG_01_Inputs_LD` · `PRG_02_Acquisition` · `PRG_03_Modes_Cycle` · `PRG_04_Treuils_Benne` · `PRG_05_Translation` · `PRG_06_Outputs_LD` · `PRG_07_Supervision`
- Abandonné comme **cible** : `PRG_SAFETY_CFC` global, `PRG_01_Diagnostics`, `PRG_02_Encoders`, `PRG_AUXILIARY_CFC`, `PRG_TROUBLESHOOTING_CFC`/`PRG_11_Troubleshooting`, table 13 POU
- AF06/AF09/AF10/AF11/AF12/AF13/AF14 : sections « intégration programme » alignées · cibles `.xml` corrigées
- Dossiers C4 fondés sur la safety séparée archivés dans `ARCHIVES/Doc/AUDITS/Architecture/` (10 fichiers)
- ⚠️ **Aucune sémantique safety, seuil, polarité ou `ErrorId` modifié** : seule l'affectation POU change
- 🚨 Arbitrage ouvert T103 : le homing lit le mode de marche — bloque le lot M1 (`AF_Partie-09` §4bis)
- Aucun `CODE/` modifié

### `RU-4_ARCHITECTURE_MAINTASK` — 2026-08-01 — ⚠️ **PÉRIMÉE** (remplacée par l'entrée ci-dessus)
- Dossier C4 créé : cycles inter-POU, doubles producteurs joystick/codeurs et options de migration documentés
- Aucun `CODE/` modifié : table 13 rangs, renommage et CFC natif bloqués jusqu'aux décisions RU-4.1 à RU-4.4
- Invariants : `PRG_10_Outputs_LD` unique barrière physique ; `PRG_11_Troubleshooting` ST lecture seule après Outputs

### `LOT_A_SUPPRESSION_CODE_MORT` — 2026-08-01
- Suppression de 3 objets jamais câblés (confirmé grep exhaustif) : `FB_Sim_AU_ChainFeedback`, `GVL_Simulation_AU`, `PRG_NETWORK_CFC`
- Zéro changement de comportement machine — code mort uniquement, mécanisme `GVL_Simulation` réel inchangé
- Nouveau garde-fou `check_linkage.py` L13 : détecte FB jamais instancié / GVL jamais référencée / PROGRAM stub vide
- Alerte : `GVL_IHM_AU` détectée orpheline (même origine, hors périmètre — décision de suppression à valider par l'utilisateur) ; `FB_Output` déjà connu sans instance depuis LOT3A — les deux tracés en exemption `KNOWN_ORPHANS_PENDING_DECISION`

### `LOT3A_FinalBrakePowerInterlock` — 2026-07-28
- M1/M2 : `FB_WinchOutputInterlock_LD`, watchdog 500 ms, paliers adjacents et redémarrage 900 ms ; mapping C1..C4 conservé exclusivement depuis `FB_Winch` / `SpeedStepTable`
- M3 : `FB_TranslationOutputInterlock_LD` après `FB_Brake`, 1/2+fréquence bloqués sans demande de desserrage **et** confirmation contacteur/bobine
- `PRG_10_Outputs_LD` : 15 instances `FB_Output` retirées ; POU conservé sans instance
- Générateur : seuls `PROGRAM PRG_*_LD` → Ladder ; `FB_*_LD` conservés ST ; BOOL connus en contact→bobine, PDO M3 WORD/UINT en liaison typée
- `SafeStop` reste la rampe rapide métier ; interlock final coupe après demande nulle, hors gates durs/défaut
- Tests PLC préparés, non exécutés ; timeout M1/M2 persistant à travers Enable/AU, anti-redémarrage, gates M3 et tempo métier 1,5 s couverts ; qualification CODESYS/simulation obligatoire

### `LOT2A_KoboldMaintenanceAssist` — 2026-07-28
- `FB_DiveSearch` : Kobold `0→1→0` strict · T81/T82
- `FB_ExtractionSequence` : benne, palier 1 sur 2,0 m puis montée nominale
- MAINT_N1/N2 uniquement · cycle semi-auto inchangé · tests PLC isolés à exécuter
- `AF_Partie-04` v1.5 · v1.4 archivée

### `T84-T85-T86_EncoderSpeedOwnership` — 2026-07-28
- Vitesse M1/M2 déplacée de Safety vers chaîne codeur `PRG_02`
- Fenêtre interne 50 ms · 6 positions horodatées · validité explicite
- Pulse source Winch réel/simulé confiné à `PRG_00` · `ForbidAscent` déterministe
- `AF_Partie-09` v1.13 · `AF_Partie-10` v1.11 · validation CODESYS requise

### `v0.5.3_PreCommissioningPrep` — 2026-07-28
- Préparation de la nouvelle session de travail & recettes pré-livraison
- Intégration du registre post-MES `DOC/REGISTRE_Suivi_PostMiseEnService_Livraison10Aout_20260728_v1.0.md`
- Clarification du pense-bête YGO : isolation simu `PRG_00`, visu pas-à-pas `PRG_11`, dédouanement PLC vs Matériel (Trace 10ms), doctrine MAINT_N1 ➔ Auto

### `DOC_RegistreSuiviPostMES_Livraison10Aout` — 2026-07-28
- Cadrage du registre post-MES `DOC/REGISTRE_Suivi_PostMiseEnService_Livraison10Aout_20260728_v1.0.md`
- Préparation des jalons et du journal de bord pour la livraison cible du 10 août 2026
- Pense-bête YGO : isolation simu `PRG_00`, visu `PRG_11`, dédouanement PLC/Matériel, doctrine MAINT_N1 ➔ Auto

### `L7-L8_HwSim_Verrou_Specs` — 2026-07-27
- `HwSim` exposée en observation dans `PRG_00_Inputs` ; aucun comparateur `HwDelta`
- Gates : confinement `GVL_Simulation` + interdiction du forçage hybride
- `AF_Partie-13` v2.0 · `AF_Partie-06` v1.7 · E/S et sécurité documentées

###
0.5.2_Troubleshooting_SignalChain — 2026-07-27
- Intégration du composant autonome de Recherche de Pannes et Traçabilité Pas-à-Pas
- PRG_11_Troubleshooting (Position 11 MainTask, pure lecture seule, 0 régression métier)
- GVL_Troubleshooting (placée sous CODE/MAIN/) orientée Fonctions & Utilisation Machine :
  1. LevageSynchroniseM1M2 (Mode Couplé Nominal M1+M2)
  2. LevageUnitaireM1 (Treuil Retenue)
  3. LevageUnitaireM2 (Treuil Benne)
  4. BenneOuvertureFermeture (Action Benne par Désynchronisme)
  5. TranslationPontM3 (Translation Variateur AC600)
- Indexation chronologique par centaines (100, 200, 300, 400, 500) + commentaires explicites des valeurs nominales
- Création de DOC/AF_Partie-14_Fonction_Troubleshooting_v1.0.md (v1.2)

### `v0.5.1_PlcTestsFrameworkRemoval` — 2026-07-26
- Retrait du framework de tests automatiques in-PLC (introduit en `v0.4.15`) : `FB_TestSequencer`,
  BRICKS/CORE, 8 suites de validation · archivé `ARCHIVES/Code/PLC_TESTS/`
- `CODE/` : 158 → 114 fichiers `.st` (−7 300 lignes, −44 objets CODESYS)
- `GVL_PLC_Tests` réduite à ses 20 `Override*` (forçages manuels) : −30,2 Ko de RAM
- `AF_Partie-14` archivée · `AF_Partie-13` → v1.4 · non-régression → simulation manuelle + FAT/SAT
- Commits `bce21c9` (phases 1-3) · `d9daa41` (phase 5)

### `v0.5.0_PostCableReplacement` — 2026-07-26
- Jalon v0.5.0 après changement des câbles physiques (suite aux essais filmés en v0.4.27)
- Nettoyage et archivage des anciens projets de qualification dans `ARCHIVES/Code/`
- Mise à jour de la documentation de suivi et des checklists de mise en service

### `v0.4.27_Audit_Persistance_Bypass_Frein` — 2026-07-24
- Audit exhaustif de rémanence `PERSISTENT` / `RETAIN` + Bridge Pattern `PRG_09_Supervision`
- Diagnostic complet de l'incident d'échauffement frein (`FB_Brake` ↔ `FB_Winch`)
- Publication du rapport d'audit et cahier d'essais dans `DOC/AUDITS/RAPPORT_Audit_Persistance_Bypass_Frein_v1.0.md`

### `v0.4.26_ConfigPersistence_TranslationSupervisionSuite` — 2026-07-24
- Translation M3 `SetFreq_Hz` protégé : `_TranslationSetFreq_Hz` + flag `Initialized` dédié (Lot 4)
- Suite test PLC `FB_SupervisionValidation` (TC-CP1..CP5) : Sync approfondi + balayage Cycle/
  Commun/Bucket/Winch M1+M2 + Translation (Lot 6)
- Raccordement orchestrateur `FB_PLC_Tests_Management` (`SuiteSupervision=8`, ciblée hors `RunAll`)
- Clôture chantier `ConfigPersistence` (Lots 1-6) · contrat `CONFIG-PERSIST-01` → `tests_status:
  implemented` (exécution CODESYS réelle restant à faire)
- Commits `a88e56d`/`3faa941` poussés sur `origin/main`

### `DOC_RESTORATION_AF07_AF11` — 2026-07-23
- Restauration intégrale post-audit de `AF_Partie-11_Fonction_Translation_v1.11.md` (v1.12, EtherCAT AC600, 5 capteurs, Méca A/B)
- Consolidation complète de `AF_Partie-07_Interface_IHM_v1.7.md` (v1.9, structures ST_*HMI & GVL_IHM), suppression du doublon v1.8
- Intégration cartographie flux IHM, audits bypass & persistance config

### `AUDIT_ConfigPersistence` — 2026-07-23
- Audit persistance étendu à tout `GVL_IHM` : `TranslationM3.Cmd.SetFreq_Hz`, `Cycle.SetDepth_M/
  SetOffset_M`, calib joystick, `M2Benne.CfgTimeoutDuration`, `BypassRestoreDone` identifiés
  non/mal protégés — décisions et options architecturales dans `DOC/AUDITS/ConfigPersistence/`
- Piste retenue à investiguer : struct persistant miroir + FB générique par type (`FB_CfgPersist_*`),
  homogénéisation `ST_BucketHMI`/`ST_SyncHMI` vers le pattern Cmd/State/Cfg/Bypass (Winch/Translation)

### `CONFIG-PERSIST-01` — 2026-07-23
- Fix persistance config IHM (`CfgMaxStepDescente` et 10+ champs Cfg M1/M2/Sync) : sentinelles
  `= 0.0` cassées remplacées par flag `Initialized`/`CfgInitialized` dédié
- Alarme IHM `ConfigRestoredFromPersistent` + acquittement front (`BtnAckConfigRestored`)
- Bug cousin corrigé : `BypassRestoreDone` passé en `VAR RETAIN` (repartait à FALSE à chaque download)
- ⚠️ Test PLC automatique restant à écrire (T65) — vérification manuelle Watch/forçage en attendant

### `DOC_ClassementEtREX_Treuils` — 2026-07-23
- Anciennes checklists, P13 v1.2 et audits clôturés déplacés en archives
- NAVBOARDs regroupés dans `DOC/NAVBOARDS/`
- P7 v1.6, P11 v1.9/v1.10 et audit Winch déplacés sans fusion
- Essais treuils : plafond palier temporairement réglé à `0` (`T64`)

### `96ef589` — 2026-07-23
- Bypass globaux/ciblés Winch · Translation M3 · synchro · benne · réseau
- Homing unitaire M1/M2 réglable, cible initiale `0,0 m`
- Validation banc/terrain et désactivation finale des bypass requises

### `DOC_SuiviMiseEnService` — 2026-07-23
- Registre historique MES créé : séances, mesures, preuves et décisions terrain
- `PLAN_TASK` reste la source unique des actions différées à implémenter (`Txx`)

### `v0.4.31_CommissioningDocsIhmState` — 2026-07-22
- NAVBOARD Joystick/M3 + checklists v1.1 alignés sur IHM `.Cmd/.State/.Safety`
- Fiches terrain courtes : ordre de bascule simulation, mouvement prudent, reset sûr

---

### `v0.4.30_SupervisionStateAndExportFix` — 2026-07-22
- Remplacement du namespace sémantique `.Status.` par `.State.` pour clarifier le retour d'états
- Regroupement physique de toutes les structures DUTs (`ST_*.st`) dans le sous-dossier `CODE/SUPERVISION/_TYPES/`
- Résolution des erreurs de compilation CODESYS (201 erreurs) par correction directe des chemins de variables obsolètes dans le fichier d'export XML `Device.export`
- Alignement du code source des suites de tests PLC (`FB_ModesValidation.st`, `FB_HeartbeatValidation.st`), de `PRG_05_Cycle.st` et de `PRG_09_Supervision.st`

---

### `v0.4.29_SupervisionStructuredCmdStatus` — 2026-07-22
- Structuration complète de supervision des axes Winch M1/M2 et Translation M3 en Cmd/Status/Cfg
- Création des types DUT dédiés ST_WinchCmd, ST_WinchStatus, ST_WinchCfg, ST_TranslationCmd, ST_TranslationStatus
- Alignement complet du remapping IHM dans PRG_09_Supervision, des autres POUs et des suites de tests PLC
- Consolidation documentaire avec l'Analyse Fonctionnelle Partie 7 v1.6 complète

---

### `v0.4.28_SupervisionFrenchExceptions` — 2026-07-22
- Restauration des exceptions de nommage en Français exigées pour l'IHM
- Renommage en `M1TreuilRetenue`, `M2TreuilBenne` et `M2Benne`
- Isolation des variables de test HMI (Tst*) sous des structures dédiées Test (ST_TestTranslation/ST_TestCycle)
- Isolation des diagnostics de sécurité IHM (SafetyError*) sous des structures dédiées Safety (ST_SafetyTranslation/ST_SafetyWinch)
- Alignement de tous les programmes consommateurs (`PRG_00` à `PRG_10`) et tests PLC

---

### `v0.4.27_SupervisionConformityRename` — 2026-07-22
- Renommage complet de la supervision GVL_IHM et des structures ST_*HMI
- Alignement strict avec les repères physiques : M1Winch, M2Winch, M2WinchBucket, TranslationM3
- Ajout systématique des underscores pour les suffixes d'unités physiques (_M, _Pct, _Hz, _Mps)
- Adaptation de tous les programmes consommateurs (PRG_00 à PRG_10) et suites de tests PLC

---

### `v0.4.26_IhmCompatibilityRepair` — 2026-07-22
- Restauration des noms publics IHM historiques : visualisation inchangée
- `CODE_Bundle.xml` inclut désormais `GVL_PERSISTENT` requis par les PRG
- À confirmer : compilation CODESYS après import du bundle réparé

---

### `v0.4.23_TranslationM3_PersistentRamp` — 2026-07-22
- 🔴 BUG : `ST_TranslationHMI.PositionMaintenance` vs PRG_09 `Position_Maintenance` (nom divergents, erreur compilation) — aligné sur struct (`PositionMaintenance`)
- 🟡 Translation ramp rates → PERSISTENT : `_TranslationRampAccelRate_Pct`(20)·`_TranslationRampDecelNormal_Pct`(40)·`_TranslationRampDecelFast_Pct`(100) dans GVL_PERSISTENT + câblage PRG_07 (auparavant hardcodés dans FB_Translation)
- 🟡 Speed cap 40% → PERSISTENT `_TranslationAutoSpeedCap_Pct` (remplace `MIN(40.0,..)` hardcodé dans PRG_07)
- 🟠 Unification source fréquence max : `DriveFreqScaleMaxHz` câblé depuis `_TranslationMaxFreq_Hz` par PRG_07 (plus de double source)
- DOC AF_Partie-11 : nouveau tableau PERSISTENT Translation M3 + note source unique

---

### `v0.4.24_TranslationM3_Positioner` — 2026-07-22
- MAINT M3 : `PositioningSelect` explicite, Jog/Positionneur + `PositionReached` IHM
- Boutons IHM sans requête : direction neutre, plus de fallback joystick implicite
- Docs Partie 7 v1.6 / Partie 11 v1.10 + NAVBOARD synchronisés

---

### `v0.4.25_TranslationM3_JoystickAnimation` — 2026-07-22
- `JoystickDeflectionPct` : axe X fonctionnel M3 signé, animation IHM autour du neutre
- Docs Partie 7 v1.7 / Partie 11 v1.11 + NAVBOARD synchronisés

---

### `v0.4.22_IHM_Joystick_Supervision` — 2026-07-22
- Renommage masse SUPERVISION (~50 champs suffixe `_M`/`_Pct`/`_Hz`/`_Mps`)
- `ST_JoystickHMI`·`PRG_09` : +DeadmanArmed·NeutralX/YAct·AxisCmdX/Y · RawX/Y/Button→FB_Joystick
- `GVL_PERSISTENT` : params joystick (deadband·filter·accel/decel·invert) + `_BucketState`
- DOC AF_Partie-11 : `DriveFreqScaleMaxHz` défaut 50→60 Hz + note qualifié
- DOC AF_Partie-11 : §9 `_BucketState` mémoire longueur câble désynchro

---

### `v0.4.21_SimM3BootFix` — 2026-07-21
- Correction polarité frein Méca B dans `FB_Safety_Translation` (`NOT BrakeFeedback`)
- Position neutre P2 (00111) au boot sans cible dans `FB_Sim_Translation`
- Boot simulation M3 Translation 100% sain sans faux défaut ni blocage AU

---

### `v0.4.20_WinchCorePrep` — 2026-07-21
- WINCH-CORE-01 · hauteurs 8,0/8,5 m · DISABLE M1/M2/M3
- Bypass codeur individuel MAINT_N2 · ConfigError SpeedStep bit2
- Charge estimée montée seule · seuil cycle aligné · purge commandes boot
- Tests PLC Modes étendus TC-M7→M12 · aucune visualisation modifiée

---

### `v0.4.19_CommissioningPrep` — 2026-07-21
- Préparation version mise en service terrain (pre-commissioning)
- Audit treuils M1/M2 (`DOC/AUDIT_Winch_v1.0.md`), suites PLC_TESTS validées
- Génération du bundle PLCopenXML `MGS_v0.4.19_CommissioningPrep`

---

### `v0.4.18_PlcTests_ManualSuites` — 2026-07-19
- Suites PLC_TESTS séparées : `RunSafety`, `RunTranslation`, `RunBucket`, `RunEncoder`, `RunModes`
- `RunAll` déprécié/ignoré : aucun lancement automatique au chargement
- Manager en lecture seule des sorties FB ; correction des erreurs CODESYS C0037
- Watchdog : arrêt + rapport de la suite active, sans blocage des autres suites
- AF Partie 14 complétée par l'addendum suites manuelles indépendantes

---

### `Audit_Winch_v1.0` — 2026-07-21
- Audit complet fonctionnalité treuils (M1/M2) : architecture, safety, synchronisme, IHM, ergonomie
- 2 P0 critiques : incohérence hauteurs (8.0/8.5/12.5m), FB_SpeedStep MaxStepNumber non borné
- 5 P1 : contradiction "sans codeur", latence PRG_03/PRG_06, synchronisme ambigu, seuils non validés, IHM ne reflète pas commandes effectives
- Bonnes/mauvaises idées identifiées, plan d'actions en 3 phases (P0 avant machine, banc, terrain)
- Doc créée : `DOC/AUDIT_Winch_v1.0.md`

---

### `v0.4.18_DocSweep_IHMRetrait` — 2026-07-18
- Méga passe documentaire : AF Partie 07 (v1.5) et Partie 11 (v1.9) republiées, PLAN_TASK et AUDIT synchronisés
- Retrait définitif IHM_MANU (ST_IHM_MANU + AF Partie-07 v1.4 archivées) — pilotage manuel = MAINT_N1/N2 + joystick homme-mort
- Nouvelles suites PLC_TESTS ENCODER/MODES + checklists mise en service Joystick/Translation
- Commit `397cee0` — clôture plan logiciel initial (homing, safety, vitesse codeur/paliers)

### Plan logiciel initial — clôture implémentation — 2026-07-18
- Homing unitaire M1/M2 MAINT_N2 : sélection, cible libre ±99 m, diagnostics
- Safety Winch : sens opposé bit14, absence mouvement bit15, temporisations
- Safety Translation alignée matériel AC600 + frein ; T26 checklist terrain livrée
- Reliquats restants limités aux décisions constructeur/client et essais terrain

### Doc plan vitesse codeur / paliers — 2026-07-18
- T41 à T48 ajoutées au plan : vitesse câble m/s, surveillance M1/M2
- 5 paliers mesurés, estimation charge et garde-fou de changement de palier

### `v0.4.17_SemiAuto_CycleSafety` — 2026-07-18
- Homme-mort obligatoire pendant les mouvements semi-auto M1/M2/M3
- Relâchement joystick = arrêt ; nouvelle sollicitation = reprise de l'étape
- Cycle Kobold raccordé au cycle semi-auto ; arrêt sûr sur perte de puissance/AU
- E/S Kobold raccordées : `KoboldContactFond_DI`=%IX0.5 et `KoboldContactor_DQ`=%QX0.6
- Tests PLC anti-blocage : états terminaux, watchdog et journal d'événements

### `v0.4.16_ReferenceToFix_BucketRun` — 2026-07-18 (M3)
- M3 conforme au codage cinq capteurs `Trémie|PV|P2|P1|Maintenance`
- Nouveau `FB_Translation_PositionDecoder` : mots valides et incohérences
- Ralentissement PV câblé, limites extrêmes Trémie/Maintenance alignées
- Bit7 safety incohérence remonté à l'IHM ; simulation des mots corrigée
- AF Partie 11 publiée en v1.8 et architecture en v2.12

### `v0.4.16_ReferenceToFix_BucketRun` — 2026-07-18 (PLC_TESTS)
- Séquenceur anti-blocage : erreurs terminales, watchdog suite et journal d'événements
- Correction `StepTc06Teardown` hors table (`69` → `63`)

### `v0.4.16_ReferenceToFix_BucketRun` — 2026-07-17
- Fix générateur PLCopenXML (`TOOLS/`) : `REFERENCE TO` sérialisait en `<pointer>` au lieu de `<derived name="REFERENCE TO X">` — confirmé sur échantillon réel (`FB_TestReference.xml`)
- `FB_BucketValidation` : garde `__ISVALIDREF()` avant déréférencement `instBucket`/`instWinchM2` (protège le 1ᵉʳ scan, avant assignation par `PRG_06_WinchControl`)
- `PRG_06_WinchControl` : `:=` → `REF=` pour rebind `GVL_Simulation.refBucket/refWinchM2` (`:=` faisait une copie de valeur à travers une réf non liée → access violation runtime CODESYS)
- ✅ RUN confirmé OK en simulation CODESYS (`FB_PLC_Tests_Management` + suite Bucket)

### 📄 Doc seule — 2026-07-16
- AF_Partie-14 v1.1 → **v1.2** : §7 réécrit intégralement (spec finale framework test in-PLC piloté par tables)
- Issue double revue croisée experte (primitives ↔ archi données) + audit — pas de modif `CODE/`
- Migration M1→M6 cadrée, à dérouler séparément (M1 = socle générique `FB_TestSequencer`)

### `v0.4.15_PlcTestsFramework_TranslationSuite` — 2026-07-16 (TEST)
- Framework PLC_TESTS migré vers AF_Partie-14 v1.2 (M1→M3+) : tables déclaratives
- Moteur unique `FB_TestSequencer` + bricks (`FB_TestCheck/Stimulus/Stopwatch/EventOrder/EdgeCounter/Timeout`)
- Réorganisé en sous-dossiers TYPES/(ENUMS·STRUCTS) · BRICKS · SUITE_SAFETY · SUITE_TRANSLATION
- `FB_SafetyValidation` réécrit (remplace le CASE monolithique v1.0/1.1)
- + nouvelle suite `FB_TranslationValidation` (TC-T1 Fdc extrême, TC-T2 Méca B, TC-T3 Méca A)
- `FB_PLC_Tests_Management` orchestre multi-suites (CmdRunAll enchaîne Safety→Translation→Bucket)
- GVL_PLC_Tests : `Cmd`/`Status` + 1 variable nommée par suite (pas de tableau, demande utilisateur)
- + `Cases[].Name` et `Report.FailureSummary` (lisibilité, évite de parcourir chaque case)
- Fix générateur PLCopenXML (`TOOLS/`) : bornes de tableau symboliques (`GVL_Const.MaxX`) étaient silencieusement omises du bundle — corrigé, non vérifié en import réel
- Fix ST : `FOR_END`→`END_FOR`, `VAR` imbriqué illégal (tous deux dans `FB_TestSequencer`)
- ⚠️ Connu non résolu : bug lockout `EmergencyArmingLockoutActive` (posé aussi sur succès) pas encore corrigé dans `FB_Safety_EmergencyManagementLogic.st` ; step Trip TC-01 à corriger (vérifier `EmergencyStopOk`, pas `PowerCutOff_A/B_RQ`)

### `v0.4.15_IHM_MANU_TranslationHoming` — 2026-07-16 (TEST)
- Translation M3 alignée sur Winch : IHM_MANU = 3ᵉ source d'arbitrage (PRG_07 §1bis)
- Fin bypass M3_CommandWord · instSafetyTranslationM3.Enable inconditionnel (débloque TC-T1/2/3)
- Vitesse Manu boutons/joystick conservée via FreqSetpointHz (diffère du Winch, décision produit)
- Retrait bypass Homing (HomingEncoder_M1/M2) — PRG_02_Encoders/ST_IHM_MANU
- + AF_Partie-11_Fonction_Translation v1.7
- Aux Hydrauliques + WinchMaxStepFwd/Rev restent hors périmètre (différés)

### Corrections nommage + intégration — 2026-07-16 (TEST)
- Renommage `FB_Benne→FB_Bucket` (défait accidentellement par un script de retour arrière buggé, sans commit) restauré depuis `HEAD`
- Suite `FB_BucketValidation` (ex-`FB_BenneValidation`) intégrée dans `FB_PLC_Tests_Management` (3e maillon de chaîne)
- Dossiers racine `EMERGENCY→AU`, `ENCODERS→CODEURS`
- ⚠️ Version de test — pas encore réimportée/validée en CODESYS

### `v0.4.14_SafetyValidation_EmergencyChain` — 2026-07-16 (TEST)
- FB_Safety_EmergencyChain : encapsule la boucle AU + sorties erreur individuelles Translation
- Déplacé/renommé vers EMERGENCY/FB_Safety_EmergencyManagement
- Fix affectation Busy/Done dans le bloc parent composite
- PRG_SafetyValidation : banc de test réglementaire automatisé de la boucle d'urgence
- + AF_Partie-14_PLC_Tests_Validation v1.0 (CI/CD, exécution des tests)
- GVL_Global.BlinkClock (ex-BlinkClock1Hz) alimenté via Util.BLINK, asymétrique réglable
- (GVL_PERSISTENT._BlinkTimeOn/_BlinkTimeOff, défaut 1s/800ms)
- Config : HomingTarget par défaut 8.5m, limite haute normale 8.0m
- ⚠️ Version de test — pas encore réimportée/validée en CODESYS pour la partie Blink

### `v0.4.13_GlobalRename_GVL_Persistent` — 2026-07-16
- Renommage global Chariot→Translation, Grappin→Benne, _COMMON→COMMUN
- SYSTEM/ scindé en DIAG/ · nettoyage GVL_BUS/GVL_Machine_Stub morts
- GVL_PERSISTENT réorganisée par métier (Winch/Benne/Translation…)
- + décorateur `_` obligatoire et suffixes unité (`_Ms`, `_M`…) partout
- T30 : fréquence translation std 30Hz / max 60Hz, persistée
- Fix visu Device.export (remplacement sûr des balises value)
- + erreurs de compilation restantes

### `v0.4.12_TranslationHMI_Migration` — 2026-07-15
- ST_TranslationHMI migre ReqFwd/ReqRev/FreqSetpointHz depuis IHM_MANU
- + diag décodé DriveCommReady/DrivePowerReady (pas de WORD brut)
- Pas l'état final : bypass ManuActive→M3_CommandWord reste
- Fix FB_Sim_Translation bloqué (relais morts ère DEGRADED_IO)
- → rebranché sur M3_CommandWord
- BypassBrakeFeedback supprimé (fusion BypassContactorFeedback)
- Rename Translation/Joystick→TranslationM3/JoystickJOY1 (Benne : BenneM2 tenté puis annulé, stutter M2)
- ⚠️ pas encore réimporté/compilé dans CODESYS

### `v0.4.11_Translation_AC600_Safety` — 2026-07-15
- EtherCAT AC600 nominal M3 · fin définitive mode relais DEGRADED_IO
- Sécurités Méca A (dérive vitesse à l'arrêt)
- + Méca B (incohérence frein/variateur)
- + arrêt fins de course extrêmes (fosses/trémie)
- Diag com EtherCAT · simu StatusWord/ActualFrequency/frein
- Doc STO ajoutée

### `v0.4.10_FdcBucket_Rename` — 2026-07-15
- TASK-0002 : FdcBucketOpen/Close→OpenEnable/CloseEnable
- (ST_IHM_MANU) — clarifie rôle config vs état
- MAJ logique PRG_10_Outputs

### — 2026-07-15
- 🗑️ Retrait DOC/AGENT_HANDOFF/ (queue, push_server.py, hooks)
- Posé en v0.4.8 · TASK-0001/0002 seules tâches réelles produites
- (TASK-0003-0010 = test pipeline factice)
- Remplacé par plugin antigravity (délégation Claude↔Gemini)

### `v0.4.9_JoystickWinchSelect_N2` — 2026-07-15
- TASK-0001 : Joystick M1/M2-seul restreint à MAINT_N2
- (évite désynchro fortuite) — sinon forcé Couplé (3)
- JoystickWinchSelectRequest/Arbitrated ajoutés FB_Modes
- Câblé PRG_04_Modes · PRG_10_Outputs utilise la consigne arbitrée

### `v0.4.8_IHM_MANU_FBWinch` — 2026-07-15
- IHM_MANU pilote M1/M2 via FB_Winch (PRG_06, 3ᵉ source arbitrage)
- Rampe/ralentissement natifs · doctrine "Conditional Bypass"
- retirée FB_Safety_Winch (Enable inconditionnel, granularité _IsReal)
- Fix latch FB_Safety_Translation (Error pas remis à 0 si Enable=FALSE)
- Fix Fdc benne appliqué M1 individuel + couplé (pas que M2)
- Fix compil PRG_02_Encoders (var supprimée)
- Nouvelle limite CableLimitAscentM1/M2_M (12.0m, exploitation)
- distincte HomingTarget (12.5m, réservé Homing)
- Fix Méca B bit8 (boutons HMI ignorés par JoystickYNeutral)
- WinchMaxStepFwd/Rev réactivé temporaire + fix boot-init à 0

### `v0.4.7_IHM_MANU_JOY` — 2026-07-14
- Alignement doctrine "Conditional Bypass" (sécu/homing)
- bloquants si réel, shuntés si simulé
- Fix Startup in Neutral · reset Grafcet auto sous IHM_MANU
- Timers homme-mort dynamiques · déblocage stub pompe hydraulique

### `v0.4.6_IHM_MANU_JOY` — 2026-07-14
- Joystick CANopen (X/Y) · décodage paliers K1-K4
- Fdc virtuelles benne (delta M1-M2)
- Commande auxiliaires hydrauliques · bornage vitesse paliers
- Consigne fréquence translation M3 réglable/limitée

### `v0.4.5_IHM_MANU` — 2026-07-09
- Fix lecture codeur réel forcée en mode Manu
- même si simu générale active

### `v0.4.4_IHM_MANU` — 2026-07-08
- Ajout structure IHM_MANU (pilotage direct secours)
- Mise en service urgence

### `v0.4.3_SimNoHardware-YGO_CablePre-Commissioning` — 2026-07-08
- Simu sans blocage validée (recul, vitesses, butée M2)
- HMI stable, bypass synchro — avant enroulage réel

### `v0.4.2_SimNoHardware-SyncBypass` — 2026-07-08
- Butée haute M2 dynamique (12m/14m)
- Offset bargraphe stabilisé en mouvement
- Bypass synchro en butées

### `v0.4.1_SimNoHardware-SyncUpdate` — 2026-07-08
- Méca E synchro critique ajoutée
- Arrêt rampe normale sur écart mineur (vs SafeStop)
- Simu stable, pas de MES matérielle

### `v0.4.0_SimNoHardware` — 2026-07-08
- Mouvements M1/M2 + benne stables en simulation
- Aucune MES matérielle réelle
| 2026-07-29 | Lot 3A | Déplacement architectural des trois instances interlock `_LD` dans `PRG_10_Outputs_LD` ; demandes brutes typées publiques PRG_06/PRG_07. Qualification CODESYS différée. |
