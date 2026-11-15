# Mission 1 — Tri Historique T417 & Plan d'Echantillonnage (Lecture Seule)

Tu es un Expert QA & Audit Historique.
Regle absolue : Clause Zero Confiance. Ne prends AUCUNE affirmation narrative pour vraie sans preuve code/trace.

## Symptôme cible
Le chariot M3 depasse parfois la butee electrique a petite vitesse jusqu'au choc mecanique — mais la simulation actuelle s'arrete proprement.

## Inventaire des artefacts existants dans T417_ANALYSES (74 entrees)
- APRES_DISSIPATION_20261030.json
- APRES_G518_COUVERTURE_20261030.json
- APRES_G518_COUVERTURE_R2_20261030.json
- APRES_RETOUR_FREQUENCE_20261030.json
- APRES_RETOUR_FREQUENCE_R2_20261030.json
- AUDIT_HARNAIS_WORKFLOW_AB_20261031.md
- AVIS_ADHERENCE_GLM_20261031.md
- AVIS_ESSAIS_AX14_DEEPSEEK_20261030.md
- AVIS_FROTTEMENT_DEEPSEEK_20261030.md
- AVIS_INTEGRATION_GLM_20261030.md
- AVIS_TEMPORISATION_20261031.md
- AVIS_VETO_AX15_GLM_20261030.md
- BASELINE_DYNAMIQUE_20261030.json
- BASELINE_DYNAMIQUE_REPRODUCTIBLE_20261030.json
- CHRONOLOGIE_94_95_20261031.json
- CI_CYCLE_AX14_AX15_20261030.json
- CI_CYCLE_AX14_AX15_R2_20261030.json
- CI_CYCLE_AX14_AX15_R3_20261030.json
- CI_CYCLE_AX14_AX15_R4_20261030.json
- CI_CYCLE_AX14_AX18_20261030.json
- CI_SIMBENCH_M3_CHRONOLOGIE_20261030.json
- CI_SIMBENCH_M3_CHRONOLOGIE_R2_20261030.json
- CODESYS_AUTO_R11_20261101
- CODESYS_R8_20261101
- CONTRE_EXPERTISE_DEEPSEEK_20261030.md
- CONTRE_EXPERTISE_GLM_20261030.md
- DYNAMIQUE_D1_20261031.json
- DYNAMIQUE_D1_REJEU_20261101.json
- ESSAIS_PENTE_FREIN_20261030.json
- FRONTIERE_ADHERENCE_20261031.json
- FRONTIERE_ADHERENCE_CORRIGE_20261031.json
- FRONTIERE_ADHERENCE_R2_20261031.json
- FRONTIERE_ADHERENCE_R3_20261101.json
- FRONTIERE_ADHERENCE_REJEU_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R10_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R11_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R12_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R13_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R14_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R15_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R16_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R17_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R18_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R19_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R20_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R21_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R4_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R5_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R6_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R7_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R8_20261101.json
- INTEGRATION_M3_CYCLE_REJEU_R9_20261101.json
- PLAN_INVESTIGATION_20261031.md
- PLAN_TEST_UTILISATEUR_T417_M3_20261030.md
- PROMPT_AGENT_A_AUDIT_CODE.md
- PROMPT_AGENT_B_TRACE_REELLE.md
- PROMPT_AGENT_C_DEFAUTS_PHYSIQUES.md
- PROMPT_CONTRE_EXPERTISE_20261030.md
- PROPOSITION_PILOTAGE_ET_BANCS_20261101.md
- RAPPORT_AGENT_A_AUDIT_CODE.md
- RAPPORT_AGENT_B_TRACE_REELLE.md
- RAPPORT_AGENT_C_DEFAUTS_PHYSIQUES.md
- REPRISE_PREUVES_20261030.md
- REVIEW_D1_DEEPSEEK_20261101.md
- REVIEW_D1_GLM_20261101.md
- REVIEW_D2_DEEPSEEK_20261101.md
- REVIEW_D2_GLM_20261101.md
- REVIEW_OVERRUN_R19_DEEPSEEK_20261101.md
- REVIEW_OVERRUN_R19_GLM_20261101.md
- REVIEW_STOP_P1_DEEPSEEK_20261101.md
- REVIEW_STOP_P1_GLM_20261101.md
- SIMBENCH_D1_20261031.json
- SIMBENCH_M3_REJEU_20261101.json

## Extrait PASSATION_T417_SimM3_20261030.md
```markdown
1: # 🧾 Passation T417 — Arrêt M3 simulé vs réel (état au 2026-10-30)
2: 
3: > Document de passation pour un autre agent. Il sépare **ce qui est vérifié** (fichier:ligne, trace, commit),
4: > **ce qui est hypothèse** (marqué 🔶), et **ce qui a été affirmé à tort** (marqué ❌) dans les échanges précédents.
5: > Aucune affirmation de ce document n'est un résultat terrain sauf mention explicite.
6: 
7: ---
8: 
9: ## 1. Objectif et consigne
10: 
11: - Objectif exploitant : simulateur M3 (translation) qui reproduit un arrêt Trémie / P1 proche du réel.
12: - Symptôme rapporté : en cycle Auto, la position simulée dérive (−0,45 m Trémie, +5,38 m P1) pendant que l'automate affiche 0,0 m / 5,0 m. En Manuel, arrêt propre ≈ 10 cm.
13: - Observation oscilloscope exploitant : `TranslationFinalInterlockRequest.BrakeReleaseRequest` tombe **instantanément** au capteur Trémie. ❌ **Non reproduit par le code ni par la trace** (voir §5).
14: - Règle d'exploitation : ne pas toucher au code automate de production sans validation humaine. Aucun commit sans validation (`AGENTS.md`). Le checkpoint et les commits déjà faits suivent une demande explicite du goal.
15: 
16: ---
17: 
18: ## 2. Commits (branche `work/base-machine-simu`)
19: 
20: | Commit | Contenu | Statut |
21: |---|---|---|
22: | `746e3a0f` | Base de référence avant ce lot (validation T421) | Référence |
23: | `8669c6dd` | Checkpoint : code simulation T417 non commité + contrat, étude, fiche, liste et template de trace | Commit `wip [NON TESTE]` |
24: | `0990a225` | Correction : défauts FB `PhysicalBrakeActive` (FB_Sim_TranslationBrake) et `BrakePhysicalActive` (FB_Sim_Translation) remis à **FALSE** | Commit `fix` |
25: | `be51ce13` | Bundle PLCopenXML régénéré (`CODE_Bundle.xml`, `CODE_DiffBundle.xml`) + XML L_SIMULATION + PRG_02 | Commit `build` |
26: | `102b1676` | Journal fiche T417 (A/B, sources candidates du délai) | Commit `docs` |
27: | `14009dcf` | Livrable partiel (section 11 de la fiche) | Commit `docs` |
28: 
29: **Revert** : `git revert <sha>` par commit. Le commit `0990a225` est isolé : il contient uniquement les deux défauts FB.
30: 
31: **Fichiers hors commits (autres chantiers, ne pas embarquer)** : `DOC/WFLOW/TASKS.yaml`, `DOC/WFLOW/TASKS_ORCHESTRATOR.yaml`, `DOC/WFLOW/PROMPTS/04_Divers.md`, `.claude/settings.local.json`, `reponse.md`, `TOOLS/AGENT_WORKFLOW/scripts/run_m3_study_agents.py`, `DOC/WFLOW/PROMPTS/10_ExempleOrchestrator/`.
32: 
33: **Attention** : pendant ce lot, un processus `git.exe` concurrent et un `index.lock` transitoire sont apparus. Vérifier qu'aucun autre agent ne committe avant tout commit.
34: 
35: **Attention** : `DOC/WFLOW/ETUDES/ANALYSES_T417/RAPPORT_AGENT_{A,B,C}_*.md` ont été committés dans `8669c6dd`. Ce sont des rapports d'agents antérieurs, **non vérifiés** par moi.
36: 
37: ---
38: 
39: ## 3. Code simulation : état et effets
40: 
41: Fichiers : `CODE/L_SIMULATION/` — `FB_Sim_Translation.st`, `FB_Sim_TranslationDrive.st`, `FB_Sim_TranslationBrake.st`, `FB_SimBench.st`, `GVL_Simulation.st`.
42: 
43: | Paramètre | Valeur FB (après `0990a225`) | Valeur GVL utilisée en simulation | Remarque |
44: |---|---|---|---|
45: | `PhysicalBrakeActive` / `BrakePhysicalActive` | FALSE (historique) | **TRUE** (`GVL_Simulation.st:79`) | Source unique = GVL, passée par `FB_SimBench.st:697` |
46: | `CartFreeActive` | FALSE | **TRUE** (`GVL_Simulation.st:84`) | Mode chariot libre actif en simulation ; non testé |
47: | `RollingFriction_Mps2` | 0,30 (était 0,10) | 0,30 | Effet mesuré seulement sur le chemin frein serré : **nul** |
48: | `StaticFriction_Mps2` | 0,35 (nouveau) | — | Non testé |
49: | `DecelRate_HzPerS` (drive) | 20 (contrat AC1 dit 25) | — | Incohérence contrat ↔ code non arbitrée |
50: | `TimeConstant_S` (drive) | 0,03 | — | — |
51: | `BrakeOpenDelayS` / `CloseDelayS` | 0,10 / 0,09 | — | Contrat AC2 dit ouverture 200 ms : incohérence |
52: | `FB_SimBench.st:752` | `M3_ActualFreqHz := REAL_TO_UINT(LIMIT(0, f, CST_M3MaxFreq_Hz)*100)` | — | Clamp ajouté |
53: | PT1 supprimé en frein ouvert | `VelocityTrue := VelocityTarget` (FB_Sim_Translation) | — | Changement de dynamique non testé hors frein |
54: 
55: 🔶 **Hypothèse non vérifiée** : le chariot libre (`CartFree`) est la seule voie où le frottement agit. Son effet sur le dépassement Auto n'est pas démontré (la trace n'enregistre pas la position simulée).
56: 
57: ---
58: 
59: ## 4. Ce que la trace `Suivi_93` établit (vérifié)
60: 
61: Fichier : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_93_SIMU_M3_20261029.trace` (run en simulation, template T417, 30 variables, 910 échantillons, pas ~100 ms, horodatage en ms).
62: 
63: Procédure réelle de la run (confirmée par l'exploitant) : entrée forcée en X14 (`18 → 14` à 58,15 s), puis déplacement opérateur en X14 (DeadmanArmed 60,82 s, DirectionPositive 60,92 s, mouvement 61,24 s), arrivée Trémie, puis X14 → X15 (71,22 s).
64: 
65: | Instant (s) | Événement (valeurs lues dans la trace) |
66: |---|---|
67: | 58,15 | `Step` 18 → 14 (entrée forcée) |
68: | 61,14 | `BrakeReleaseRequest` 0 → 1 (frein demandé) |
69: | 61,24 | `M3_BrakeIsOpen_DI` 0 → 1 (frein ouvert physiquement) |
70: | 66,65 | Consigne variateur 50 → 5 Hz |
71: | 70,27 | `M3_PosTremie_DI` 0 → 1 ; `ReqTremieSemantic` 1 → 0 **même scan** ; `EffectivePermitM3_Tremie` 1 → 0 **même scan** |
72: | 70,37 | `DriveFreqCmd_Hz` = 0 et `DriveControlWord` = 0 (variateur coupé au scan capteur) |
73: | ≈70,6 | `ActualFrequencyHz` passe sous 0,5 Hz (déduit des valeurs : 0,66 Hz à 70,59 s, 0,32 Hz à 70,69 s) |
74: | 71,11 | `ActualFrequencyHz` = 0 |
75: | **71,22** | **`Step` 14 → 15** et **`BrakeReleaseRequest` 1 → 0** au même scan |
76: | 71,33 | `M3_BrakeIsOpen_DI` 1 → 0 (retombée physique) |
77: | 72,18 | `TranslationState.BrakeCmd` 1 → 0 |
78: 
79: **Conclusion vérifiable** : dans cette run, la demande de frein ne tombe pas au capteur Trémie. Elle tombe à la sortie d'étape X14, environ 0,5 s après que la fréquence est passée sous 0,5 Hz, en cohérence avec la confirmation d'arrêt de 500 ms du code. ✅ Ce n'est pas une preuve générale : c'est une run.
80: 
81: ❌ Ce que j'ai affirmé à tort ou trop fort :
82: - « la run est forcée donc inutilisable » : seule l'entrée en X14 est forcée. Le déplacement dans X14 est un cycle normal.
83: - « une seule trace ne suffit pas » : la simulation est répétable ; trois runs identiques suffisent.
84: 
85: ---
86: 
87: ## 5. Pourquoi le code ne coupe pas le frein au capteur (vérifié)
88: 
89: Trois mécanismes candidats, à ne pas départager sans nouvelle donnée :
90: 
91: 1. **Sortie d'étape X14 (veto)** : `PRG_05_Translation.st:400-405` (en SEMI_AUTO, M3 autorisé seulement aux étapes AX2 et AX14) et `PRG_05:715-721` (BrakeReleaseRequest := FALSE hors étape autorisée). Déclenché à la sortie de X14.
92: 2. **Sortie X14 conditionnée à la vitesse** : `FB_CycleSemiAuto.st:363-367` (`TranslationStopTimer` = AT_Tremie AND NOT Busy, 500 ms, `CST_TranslationStopConfirmTime` à `FB_CycleSemiAuto.st:265`) ; `Busy` = |vitesse| > 0,5 Hz (`PRG_05_Translation.st:885`).
93: 3. **Coupure dure au capteur neutralisée** : `PRG_06_Outputs.st:431-443` : `M3_TremieHardStopActive := DI AND ReqTremieSemantic` ; `BrakeReleaseRequest := ... AND NOT M3_TremieHardStopActive`. Si `ReqTremieSemantic` tombe au même scan que le capteur (c'est le cas dans la trace), la coupure dure est inopérante. 🔶 Est-ce un bug de séquencement ou un choix : non tranché.
94: 
95: Également : `FB_Translation.st:332` : `BrakeReleaseRequest := Brake.BrakeCmd`, et `FB_Brake.st:92-104` : le frein ne retombe qu'après `DelayMotorDecel` = **2 s** (`ST_fbTranslation_Cfg.st:34`) à partir de la fin de `MovementRequested`. 🔶 Cette source n'a pas été départagée des trois précédentes.
96: 
97: La coupure du variateur, elle, est bien au scan capteur (PRG_06 permission `AND NOT DI`).
98: 
99: **Vérification de référence** : la logique de coupure Trémie (`PRG_06:431-443`, `PRG_05:709/720`) est **identique** entre la référence MES `e38cc09a` et `HEAD`. Ce n'est pas un écart de branche.
100: 
101: ---
102: 
103: ## 6. Ce qui n'est PAS établi
104: 
105: - ❌ **L'observation de l'exploitant** (coupure instantanée du `BrakeReleaseRequest` au capteur, « pas de maintien de 2 s ») : contredite par la trace et par le code de référence. Causes possibles non vérifiées : variable oscilloscope différente, version de programme différente sur l'automate, run différente. **À clarifier avant toute correction.**
106: - ❌ **Le comportement voulu par la spec** : non lu (`AF_Partie-11`, `AF_Partie-13`). Je ne sais pas si la coupure au capteur est prévue.
107: - ❌ **« Maintenir le frein jusqu'à l'arrêt est plus sûr mécaniquement »** : affirmation non démontrée.
108: - ❌ **« La cause du dépassement est le frottement »** : non démontré. La réplique (voir §7) montre un effet nul sur le chemin frein serré, pas sur le chemin chariot libre.
109: - ❌ **Le −0,45 m** : non reproduit. La trace n'enregistre pas la position simulée (`SimM3ObsPositionTrue_M` non publié dans `GVL_Troubleshooting`).
110: - 🔶 **`ActualFrequencyHz` est à l'échelle ×100** (5000 = 50 Hz) : déduit des valeurs, à confirmer dans le code.
111: - 🔶 **Le mode « AUTO » de l'exploitant = SEMI_AUTO** : `E_Mode` ne contient que DISABLE, MAINT_N1, MAINT_N2, SEMI_AUTO (`CODE/F_MODES/E_Mode.st`). Mon erreur initiale : j'avais écrit « AUTO ».
112: 
113: ---
114: 
115: ## 7. Réplique minimale (non reproductible aujourd'hui)
116: 
117: Script `replica_t417_stop.py` (dans l'ancien scratchpad, **plus accessible**). Hypothèses : pas de balancier, pas de came capteur, droop = 0, capteur seuil 0 + hystérésis 0,02.
118: 
119: | Essai | Résultat |
120: |---|---|
121: | Arrêt Trémie 20 Hz, friction 0,30 | −0,069 m |
122: | Idem, friction 0,10 | −0,069 m (identique) |
123: | Idem, 40 Hz | −0,211 m |
124: | Frein relâché 3 s après arrêt, consigne nulle, angle = 0 | −0,069 m (pas de dérive sans balancier) |
125: 
126: Limite : ne modélise pas le balancier, donc ne dit rien du chariot libre (H4).
127: 
128: ---
129: 
130: ## 8. Tests et gates (état vérifié)
131: 
132: **Suite CI L_SIMULATION** (`TOOLS/TEST_AUTO_CI/scripts/run_tests.py --domain L_SIMULATION`, ~40 s) :
133: - Base `746e3a0f` : 6 PASS / 6 FAIL.
134: - État courant (après `0990a225`) : **6 PASS / 6 FAIL, mêmes échecs**. Aucune régression.
135: - Échecs présents sur la base (non causés par ce lot) :
136:   - `FB_SimBench` ; `SimOperatorJoystick` ; `SimManualReference`.
137:   - `SimTranslationLoop` : `TC-T417-LOOP-A/B` attend PHASE 3, obtient 2.
138:   - `FB_Sim_Encoder` : `TC-P13-034/035`.
139:   - `FB_Sim_Translation` : **ne compile pas** (`FullTravelTimeS` utilisé 8 fois dans `RESULTS/L_SIMULATION/tests/test_fb_sim_translation.st`, paramètre supprimé au refactoring T301). Réécrire les 19 tests changerait leurs attendus : **non fait, à valider**.
140: 
141: **Gates palier C** (`run_all_gates.py --palier C`) : 8 échecs sur 61, **identiques à la base** sauf G390 qui passe après régénération du bundle.
142: - Échecs : G300, G340, G430, G483, G503, G517, G518, G519.
143: - G518 (odométrie M3, source unique) : exige `TC-T301-SRC-001/002` dans `test_fb_sim_translation.st` (fichier non compilable). Exploitant : **pas urgent**, à laisser de côté.
144: - G517, G503, G519 : logique de production, hors périmètre de ce lot.
145: 
146: **G200** (`G200_check_linkage.py --report`) : PASS, 0 erreur, 2167 instances vérifiées, 1722 avertissements (liste E/S, « non trouvé dans la carte E/S »), à relire.
147: 
148: ---
149: 
150: ## 9. Bundles (livrables à importer)
151: 
152: - `CODE_XML/CODE_Bundle.xml` : import **complet**, 82 POU distincts, XML bien formé.
153: - `CODE_XML/CODE_DiffBundle.xml` : import **rapide**, 13 objets : `FB_CycleTime`, `FB_SimBench`, `FB_Sim_Encoder`, `FB_Sim_Joystick`, `FB_Sim_KlossTorque`, `FB_Sim_PositionSensor`, `FB_Sim_Safety`, `FB_Sim_SuspendedLoad`, `FB_Sim_Translation`, `FB_Sim_TranslationBrake`, `FB_Sim_TranslationDrive`, `FB_Sim_WinchElectrical`, `FB_Sim_WinchMotor`.
154: - Vérification : diff hors fins de ligne (`--ignore-cr-at-eol`) = 34 insertions / 14 suppressions sur `CODE_Bundle.xml`. Les grandes suppressions brutes sont un artefact CRLF/LF.
155: - 🔶 **Non validé** : aucun import CODESYS, aucun test sur banc ou Device. C'est une tâche de l'exploitant.
156: - Le `CODE_DiffBundle.xml` contient 13 objets (fermeture des dépendances de type), et non les 3 annoncés dans un rapport antérieur.
157: 
158: ---
159: 
160: ## 10. Trace et template (outillage)
161: 
162: - Liste de variables : `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/trace_m3_stop_auto_ax14_ax15_v1.txt` (30 voies publiques).
163: - Template importable : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/config/T417_Stop_Auto_AX14_AX15_TEMPLATE.trace` (généré par `scripts/generate_trace_template.py`, modèle `Suivi_92_TB_M3_LINK_20261002.trace`, `--no-trace-data`). 🔶 **Import CODESYS non testé**.
164: - Les variables simulation (`SimM3Obs*`, dont `SimM3ObsPositionTrue_M`) **ne sont pas** dans le template : non publiées dans `GVL_Troubleshooting`. Ajout = modification GVL, à valider.
165: - Variables utiles non encore dans la trace (à valider avant ajout) : `PRG_03...Data.Auth.Mode` (pour confirmer SEMI_AUTO), signaux de rampe `SpeedRamp` et `MovementRequested` (internes FB_Translation, probablement non publics).
166: 
167: ---
168: 
169: ## 11. Analyse A/B (agents)
170: 
171: - Runner : `TOOLS/AGENT_WORKFLOW/scripts/ollama_subagent.py`. **Texte seul** : les agents n'ont pas accès aux fichiers. Les tentatives avec « lecture du dépôt » n'ont produit que des annonces, sans analyse (sorties vides, `$TEMP/t417_audit/`).
172: - Modèles disponibles : `deepseek-v4.1-flash:cloud`, `glm-5.3-flash:cloud` (et `deepseek-v4-flash:cloud`, `qwen3.8:27b`, `gemma4`).
173: - A/B réalisé sur **extraits fournis** (`$TEMP/t417_ab/AB_deepseek.md`, `AB_glm.md`) : A1 (coupure dure inopérante au scan) validée pour la run mesurée, « jamais » = extrapolation ; A2 (veto à la sortie X14) validée en SEMI_AUTO ; A3 (frein ouvert pendant décélération) : clause validée, conséquence non vérifiable ; A4 (variateur coupé par la permission) : chronologie prouvée, causalité non prouvée.
174: - Alertes soulevées (non tranchées) : coupure dure possiblement « morte par construction » (DeepSeek) ; vérifier la condition 500 ms vs 0,11 s (GLM).
175: 
176: ---
177: 
178: ## 12. Décisions ouvertes (pour l'exploitant, pas pour un agent)
179: 
180: 1. **Comportement voulu** : frein maintenu jusqu'à l'arrêt confirmé (code actuel) ou coupé au capteur Trémie (observation oscilloscope). Dépend de la spec `AF_Partie-11`/`AF_Partie-13` et de la machine réelle, pas d'un test.
181: 2. **Variable et version de l'observation oscilloscope** : laquelle, sur quel programme automate.
182: 3. **Coupure dure neutralisée** (`ReqTremieSemantic`) : bug de séquencement ou choix ?
183: 4. **Test G518** : réécrire les 19 tests `test_fb_sim_translation.st` (changement d'attendus, à valider) ou laisser en attente.
184: 5. **Import CODESYS** du bundle et test banc : à faire par l'exploitant.
185: 
186: ## 13. Plan de test proposé (simple)
187: 
188: - **T1** : trois runs identiques en simulation, procédure de `Suivi_93` (entrée X14 forcée, déplacement vers Trémie), enregistrées avec le template T417.
189: - **T2** : sur chaque run, relever l'écart entre (a) fréquence sous 0,5 Hz, (b) `Step` 14→15, (c) `BrakeReleaseRequest` 1→0. Critère : (b) et (c) au même scan, et (b) − (a) ≈ 0,5 s.
190: - **T3** : importer le bundle dans CODESYS, relancer T1, comparer au simulateur.
191: - **Critère d'arrêt** : si T2 reproduit sur les trois runs, le mécanisme est établi pour ce code. L'écart avec l'oscilloscope exploitant reste à expliquer (point 2 de §12).
192: 
193: ---
194: 
195: ## 14. Erreurs commises pendant ce lot (à ne pas reproduire)
196: 
197: - Affirmations non vérifiées présentées comme faits (« validé par l'exploitant » dans la fiche : corrigé).
198: - Conclusion trop forte sur le frottement (« refuté »), alors que seul le chemin frein serré est testé.
199: - Confusion entre « AUTO » et SEMI_AUTO.
200: - Exigence de tests répétée au lieu d'un plan simple.
201: - Décision présentée comme binaire et « la mienne », alors qu'elle dépend de la spec et de la machine.
202: - Boucle de réponses au hook `/goal` sans progrès.
203: - Tentatives d'agents texte seul présentées comme des audits.
204: 
205: ---
206: 
207: ## 15. Fichiers de référence
208: 
209: - Fiche de suivi : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T417_SimM3_Arret_20261029.md` (sections 4bis barème, 10 journal, 11 livrable partiel).
210: - Contrat : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T417_SIMULATION_M3_REALISTE.yaml`.
211: - Étude : `DOC/WFLOW/ETUDES/ETUDE_CONCEPTION_T417_SIMULATION_TRANSLATION_M3.md`.
212: - Tâche : `DOC/WFLOW/TASKS.yaml` entrée T417 (non modifiée par ce lot).
213: - Trace : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_93_SIMU_M3_20261029.trace`.
```

## Extrait REPRISE_PREUVES_20261030.md
```markdown
1: # T417 — Registre de reprise et expériences — 2026-10-30
2: 
3: Référence témoignage : [registre MES](../../REGISTRES/REGISTRE_MES_TEMOIGNAGE_M3_20261030.md). GO utilisateur reçu pour poursuivre l'objectif ; production inchangée, aucun commit autorisé. Référence de lecture initiale : HEAD `14009dcf`, arbre comportant des travaux tiers conservés.
4: 
5: ## Contrat d'investigation et de contre-expertise (lecture seule)
6: 
7: Objectif : établir les défauts du modèle susceptibles de fausser les essais AX14–AX18, sans attribuer une cause terrain sur simple inférence.
8: 
9: Critères testables :
10: 1. Remonter les paramètres du variateur jusqu'à son appel effectif ; citer source et valeur transmise.
11: 2. Examiner la dissipation du frottement : proposer un contre-exemple chiffré si le modèle inverse une vitesse sans force motrice.
12: 3. Séparer commande de frein, état mécanique et contact ; ne pas assimiler fréquence électrique et vitesse mécanique sans justification.
13: 4. Évaluer les tests existants et leur raccordement au runner ; ne pas annoncer un PASS non exécuté.
14: 5. Proposer des expériences discriminantes frein ouvert/fermé, pente nulle/non nulle, approches 10/20 Hz ; aucune injection de défaut pour satisfaire un résultat attendu.
15: 
16: Les avis d'agents sont des hypothèses/revues à contrôler par le principal, jamais des preuves terrain. Maximum trois agents simultanés. Ollama disponible : deepseek-v4.1-flash:cloud et glm-5.3-flash:cloud (inventaire interrogé le 30 octobre).
17: 
18: ## Registre des preuves
19: 
20: | ID | Constat de lecture actuel | Statut et prochaine vérification |
21: |---|---|---|
22: | E01 | SimBench ne transmet pas DecelRate_HzPerS ni DriveTimeConstantS ; FB_Sim_Translation transmet ses valeurs 25 Hz/s et 0,15 s au FB variateur. | Établi statiquement pour cet appel ; les défauts 20 Hz/s et 0,03 s du FB enfant ne décrivent donc pas le banc intégré. |
23: | E02 | Branche ObsCartFree : vitesse += (force externe − frottement signé) × dt, sans bornage au passage par zéro. | Risque numérique identifié ; contre-exemple à tester sur ST, pas encore verdict CI. |
24: | E03 | test_fb_sim_translation_dynamics.st contient déjà M3-DYN-030 (100 ms, deux sens, pas d'inversion) et M3-DYN-040 (10 ms). Recherche dynamics/Dynamics dans registry.yaml sans résultat. | Identifier le runner historique avant de refaire des tests déjà écrits. |
25: | E04 | M3-DYN-050 utilise frottement 0,1 et attend un départ sous pente 0,2 ; le modèle courant ajoute un seuil statique par défaut 0,35. | Attendu historique devenu incompatible ; ne pas modifier l'attendu sans expliciter le contrat physique. |
26: | E05 | M3-DYN-100 attend un retour fréquence indépendant du balancement ; FB_Sim_TranslationDrive soustrait gain × ABS(vitesse angulaire). | Divergence test/code à arbitrer sur les données réelles, pas sur le seul test. |
27: | E06 | Le runner tiers run_m3_study_agents.py tronque le code translation aux 6000 premiers caractères et remplace silencieusement les fichiers absents par une chaîne vide. | Ne pas le réutiliser tel quel ; fournir des sources complètes pertinentes aux contre-experts. Fichier tiers laissé intact. |
28: 
29: ## Prochaines expériences
30: 
31: - Retrouver l'exécution historique des tests dynamiques et rejouer l'état actuel sans changer les attentes.
32: - Vérifier les traces réelles et leur provenance : retrait commande, décroissance fréquence, commande/contact frein ; résolution temporelle explicitée.
33: - Prouver l'isolation et le câblage du harnais avant de prétendre tester le cycle AX14–AX18.
34: - Conserver séparément dépassement d'arrêt et dérive lente après arrêt ; pente et frein relâché restent des hypothèses, pas des calibrations terrain.
35: 
36: ## Exécution du 30 octobre — état initial réellement testé
37: 
38: Suite existante exécutée par `run_tests.run_one`, avec les dépendances de l'entrée `FB_Sim_Translation` du registry et substitution en mémoire du chemin de test par `test_fb_sim_translation_dynamics.st`. Aucun attendu ni fichier ST modifié. Rapports existants préservés (`generate_reports=False`). Résultat détaillé : [BASELINE_DYNAMIQUE_20261030.json](BASELINE_DYNAMIQUE_20261030.json).
39: 
40: **9 PASS / 3 FAIL sur 12 tests** :
41: - M3-DYN-030 : +0,004 m/s devient −0,006 m/s par frottement seul à 100 ms. Défaut numérique reproduit sur le ST compilé, sans cause terrain déduite.
42: - M3-DYN-050 : aucun départ sous pente 0,2 m/s², conformément au nouveau seuil statique 0,35 mais contrairement à l'attendu historique. Arbitrage test/modèle nécessaire.
43: - M3-DYN-100 : retour 16 Hz au lieu de 20 Hz lorsque vitesse angulaire imposée = 8 rad/s. Confirme le calcul de droop ; ne prouve pas que l'attendu correspond au variateur réel.
44: 
45: Scratch conservé du runner : `TOOLS/TEST_AUTO_CI/.scratch/FB_Sim_Translation/a31a92829f32`. Statut Git contrôlé avant/après ; aucun rapport tiers écrasé par cette exécution.
46: 
47: ## Lecture des données historiques — trace 27
48: 
49: Source CSV : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/archives/Suivi_TranslationM3bug_20260904_27_wide.csv`, associée par son meta.json à la trace homonyme. Donnée historique, pas spec active ; provenance MES à recouper avant calibration.
50: 
51: Échantillons directement lus :
52: 
53: | Temps ms | Trémie | Contact frein ouvert | Fréquence brute | Mot commande | State.ErrorId |
54: |---|---|---|---|---|---|
55: | 26353 | 0 | 1 | 1000 | 1 | 0 |
56: | 26438 | 1 | 0 | 1000 | 0 | 64 |
57: | 26553 | 0 | 0 | 913 | 0 | 64 |
58: | 26953 | 0 | 0 | 68 | 0 | 65 |
59: | 27056 | 0 | 0 | 0 | 0 | 65 |
60: 
61: Pas sur l'ensemble : minimum 47 ms, médiane 100 ms, maximum 153 ms. **Ne prouve ni une impulsion exactement de 85 ms ni un ordre causal intra-scan.** La commande électrique de frein et la position mécanique ne figurent pas dans ces colonnes : impossible d'en déduire un retard bobine/contact ou une décélération mécanique de 2 m/s². La fréquence reste non nulle sur plusieurs échantillons après mot nul et contact fermé. Le zéro est observé 618 ms après le premier échantillon mot nul de cette fenêtre, pas une mesure exacte du temps physique d'arrêt.
62: 
63: ## Contre-expertises
64: 
65: Les deux appels Ollama sur dossier complet (DeepSeek v4.1 / GLM 5.3, contexte 32768, sortie limitée à 5000 tokens) sont terminés mais ont rendu une **réponse vide**. Aucun avis exploitable, aucune validation acquise. Fichiers vides conservés comme artefacts de tentative. Une question courte ciblée sur la dissipation a été lancée sur DeepSeek sans cette limite de sortie ; résultat à contrôler avant utilisation.
66: 
67: ### Suite : avis court reçu et qualification
68: 
69: `AVIS_FROTTEMENT_DEEPSEEK_20261030.md` confirme arithmétiquement le contre-exemple et propose force externe puis dissipation bornée. Avis partiellement utile seulement : sa borne d'erreur mélange les dimensions (accélération × temps² présentée en vitesse), son affirmation sur la nécessité d'un booléen d'hystérésis n'est pas démontrée, et son alerte sur l'unité du seuil provient du prompt court (le code nomme explicitement `_Mps2`). Ne pas reprendre ces conclusions comme validées.
70: 
71: ## Harnais et isolation — lecture du 30 octobre
72: 
73: - `TOOLS/TEST_AUTO_CI/MOCKS/FB_TestLoopTranslation.st` ne contient ni le séquenceur AX14–AX18, ni `FB_Safety_Translation`, ni `FB_TranslationOutputInterlock`. Il conserve une cible 20 m et un seuil de départ 6 m. Il ne valide donc pas le scénario demandé ; sa géométrie est à réaligner avant réutilisation.
74: - `PRG_02_Acquisition.st:318-324` alimente le modèle avec le mot et la fréquence de sortie, plus `PRG_06_Outputs.Data.TranslationBrakeCmd`. Les entrées translation sont sélectionnées à la ligne 482 par `SimulationModeActive AND SimTranslationActive` (ligne 136).
75: - Limite de l'audit : `PRG_06_Outputs.st:457-459` écrit les symboles de sortie M3. Aucun garde simulation n'est visible dans cette affectation. Cela ne démontre pas un actionnement matériel (mapping/configuration banc non audités), mais interdit de déclarer l'isolation physique prouvée par le seul aiguillage des entrées. Ne pas modifier la production pour résoudre ce point dans T417.
76: 
77: ## Commande de régression reproductible
78: 
79: Ajout de `TOOLS/AGENT_WORKFLOW/scripts/check_m3_dynamics.py` : sources du registry, tests existants, empreintes SHA-256, sortie durable explicitement choisie sous DOC/WFLOW, refus d'écraser une preuve existante. Aucun changement des attentes. Exécution :
80: 
81: ```powershell
82: py -3.13 TOOLS/AGENT_WORKFLOW/scripts/check_m3_dynamics.py --output DOC/WFLOW/ETUDES/ANALYSES_T417/BASELINE_DYNAMIQUE_REPRODUCTIBLE_20261030.json
83: ```
84: 
85: Résultat : **exit 1, 9 PASS / 3 FAIL**, mêmes échecs que le premier rejeu. Le garde détecte donc effectivement l'état rouge actuel. Scratch conservé `TOOLS/TEST_AUTO_CI/.scratch/FB_Sim_Translation/9527189f70f9`. `git diff --check` signale des espaces de fin de ligne dans le rapport tiers FB_Sim_Joystick.html déjà modifié avant ce travail ; fichier laissé intact.
86: 
87: ## Plan technique de poursuite (GO objectif reçu)
88: 
89: 1. Corriger uniquement l'intégration dissipative du chariot libre, sans calibrer une nouvelle pente ni changer les valeurs physiques par défaut. Préserver adhérence statique distincte et inversion sous force externe suffisante. Tests : deux sens, pas 10/20/100 ms, force nulle, sous seuil statique, au-dessus du seuil, frein fermé. Le test 050 devra déclarer explicitement son seuil statique : sa valeur implicite historique ne constitue pas une calibration.
90: 2. Garder l'écart du test 100 visible jusqu'à arbitrage documenté du retour fréquence. Aucun ajustement au seul motif de rendre la suite verte.
91: 3. Réparer la couverture d'intégration : le harnais doit consommer les vrais blocs cycle/translation/safety/interlock et les réglages actuels. Pas de duplication approximative des décisions AX14–AX18. Le scénario doit inclure arrivée, ouverture, attente et départ suivant, à 10 puis 20 Hz.
92: 4. Comparer des variantes de simulation identiques sauf une hypothèse : pente nulle/non nulle et frein commandé ouvert/fermé. Tester ces variantes hors machine réelle, sans imposer une distance de 30–50 cm ni un défaut.
93: 5. Vérifier le chemin sortie finale → modèle → capteurs/retour → estimateur et cycle ; préserver PRG, sécurité, persistance et comportement des autres axes. Export complet/diff, G200 et gates avant livraison ST, puis réception manuelle CODESYS.
94: 
95: ### Évaluation du second avis DeepSeek
96: 
97: `AVIS_ESSAIS_AX14_DEEPSEEK_20261030.md` a produit une réponse exploitable mais **non retenue comme procédure** : elle dérive vers des essais physiques avec charge et des mesures électriques indisponibles, alors que le besoin immédiat est un banc logiciel. Elle affirme aussi à tort qu'une absence de mouvement frein ouvert réfuterait à elle seule une pente (le frottement statique peut suffire à maintenir l'arrêt). Retenir seulement la séparation physique/intégration et les chronologies à observer. Aucun essai matériel proposé par cet avis n'est autorisé ou exécuté.
98: 
99: ## Expérience pente/frein sur ST — résultat
100: 
101: Ajout de M3-DYN-051 et 052 dans la suite existante : seuil statique courant explicite, pente sous/au-dessus du seuil, frein fermé puis desserré puis refermé. Ces essais sont purement logiciels ; accélération de pente ±0,60 m/s² choisie pour exercer la branche, **pas une estimation de pente réelle**. Résultat : les deux PASS. Le modèle peut déjà produire un déplacement sous pente lorsqu'on libère le frein, et l'arrêter lorsqu'on le referme. Cela ne prouve pas que la commande automate libère le frein en AX15.
102: 
103: M3-DYN-050 conserve ses assertions mais déclare désormais `StaticFriction_Mps2 := 0.1`, seuil propre au scénario historique ; 051 couvre séparément le défaut courant 0,35. Aucun paramètre du banc modifié.
104: 
105: Exécution via `check_m3_dynamics.py --output DOC/WFLOW/ETUDES/ANALYSES_T417/ESSAIS_PENTE_FREIN_20261030.json` : **12/14 PASS**, toujours FAIL 030 (inversion numérique) et 100 (hypothèse retour fréquence). Empreintes sources dans la preuve. Scratch `04f8c0410b6b` conservé. Diff tests vérifié ; aucun fichier CODE modifié. Prochaine action : corriger 030, puis tester le vrai chemin de commande du frein autour d'AX14–AX18, sans confondre capacité physique du modèle et causalité du séquenceur.
106: 
107: ## Correctif dissipatif appliqué — lot encore ouvert
108: 
109: `FB_Sim_Translation` : dans la branche libre en mouvement, intégrer d'abord la force externe, puis retirer une impulsion de frottement bornée à la vitesse disponible (MAX/MIN vers zéro). Branche au repos et paramètres physiques inchangés. C'est un schéma discret de premier ordre, pas une résolution exacte de l'instant de passage à zéro ; la sensibilité au pas et le traitement d'une force opposée sous le seuil statique restent à compléter. Variables locales `FreeVelocity_Mps` et `FrictionStep_Mps`, sans nouvelle interface ni lecture GVL. Aucun code production modifié.
110: 
111: Preuve `APRES_DISSIPATION_20261030.json` : **13/14 PASS**, 030 passe (deux sens, 100 ms, absence de redémarrage numérique), 060 passe (force extérieure autorise une inversion), essais pente/frein préservés. Seul 100 reste rouge. Garde automatique : `check_m3_dynamics.py`, exit non nul maintenu tant que la suite reste rouge.
112: 
113: Bundle complet régénéré et fraîcheur PASS ; diff bundle contient `FB_Sim_Translation` seul. G200 : **PASS, 0 erreur, 1722 avertissements, 2169 instances vérifiées**. Avertissements conservés, pas assimilés à une preuve d'isolation physique. Gates de fin de lot et réception CODESYS non exécutés à ce stade. Aucun commit. Les essais AX14–AX18 ne sont pas remplacés par ce correctif numérique.
114: 
115: ## Chaîne AX14–AX18 et écart M3-DYN-100 — lecture complémentaire
116: 
117: ### Faits de source
118: 
119: - `FB_CycleSemiAuto.st:1485-1499` commande M3 vers Trémie en AX14 puis annule `TranslationCmd.ReqStart` dès le capteur. Le passage AX15A est conditionné par `TranslationStopTimer`, lui-même soumis à `Translation_At_Tremie AND NOT Translation_Busy` (`:363-369`).
120: - AX15A, AX15B, AX15C et AX18 posent tous `TranslationCmd.ReqStart := FALSE` (`:1518`, `:1553`, `:1586`, `:1604`).
121: - `PRG_05_Translation.st:400-407` limite en semi-auto les étapes M3 à AX2 et AX14. Sa barrière finale redondante met explicitement `BrakeReleaseRequest := FALSE`, mot variateur et fréquence à zéro hors AX2/AX14 (`:698-720`). `FB_TranslationOutputInterlock` en déduit `BrakeCmd := BrakeReleaseRequest ...` (`FB_TranslationOutputInterlock.st:137`).
122: 
123: **Conséquence strictement limitée :** le code source versionné actuel demande bien le serrage en AX15–AX18. Cela ne prouve ni la version chargée sur la machine réelle, ni le comportement de la bobine, du contact ou du frein mécanique. Le banc ne doit donc pas annuler cette barrière ; une éventuelle dérive devra être modélisée comme hypothèse/défaut simulé explicitement, séparé de la commande automate nominale.
124: 
125: ### M3-DYN-100 : arbitrage reporté, pas de correction opportuniste
126: 
127: Le test, ajouté au commit `555327be` à 21:08, attend un PDO fréquence indépendant du balancement. Six minutes plus tard, `6cce0c93` a modifié le même modèle : `ActualFrequency_Hz` retire `LoadFrequencyDroopGain_Hz × ABS(LoadAngularVelocity_RadPerS)` (`FB_Sim_TranslationDrive.st:51-56`) et a supprimé le commentaire qui définissait le PDO comme fréquence électrique indépendante. L'échec 100 est donc une incohérence historique avérée entre test et code, mais aucune des deux sémantiques n'est encore validée par une trace suffisamment qualifiée. Le test reste rouge et le modèle reste inchangé jusqu'à décision documentée.
128: 
129: Le contrat T417 AC2 indique 200 ms d'ouverture, alors que `FB_Sim_TranslationBrake.st:8-9` et l'étude T417 portent actuellement 100 ms d'ouverture et 90 ms de fermeture. Cette divergence documentaire est un **point ouvert** : aucune valeur n'est modifiée sur cette seule lecture.
130: 
131: ### Contre-expertise locale
132: 
133: Deux demandes courtes ont été adressées au runner Ollama local le 30 octobre, après échec des demandes longues antérieures. Le service a répondu HTTP 410 avant production d'un avis ; aucune conclusion d'agent n'est utilisée. L'analyse ci-dessus repose uniquement sur les fichiers et l'historique Git cités.
134: 
135: ## CI composite SimBench — blocage circonscrit et essai de remplacement
136: 
137: Exécution initiale : `py -3.13 TOOLS/TEST_AUTO_CI/scripts/run_tests.py --fb FB_SimBench --fast`.
138: 
139: - La conversion et les contrôles d'interface atteignent les 17 composants déclarés. Le premier blocage était une référence registry vers `CODE/L_SIMULATION/ST_fbSim_Translation_ExtLink_Echo.st`, type supprimé au commit `7b47291f`. Un miroir **test-only** a été placé sous `TOOLS/TEST_AUTO_CI/MOCKS/` et les trois entrées de registry concernées y pointent ; aucune source PLC n'a été recréée.
140: - Après ce rétablissement du harnais, le parseur STruCpp s'arrête avant toute assertion M3 sur `test_fb_simbench.st:897` : `Expected END_FOR found ADVANCE_TIME`. L'instruction est située dans une boucle d'un scénario M2 antérieur. C'est une incompatibilité du test/parser, non un verdict sur M3 et non une autorisation de modifier le test M2 hors scope.
```

## Livrable attendu (concis, structure TDAH-friendly)
1. **Tri des pistes deja testees** : classe-les en 3 categories (`Verifie avec preuve`, `Hypothese non prouvee`, `Contredit / Obsolete`).
2. **Angles morts sur la petite vitesse & choc butee** : qu'est-ce que l'historique T417 n'a PAS encore teste ou a melange (Auto vs Manu, petite vitesse 5-10 Hz, coupure frein, chariot libre) ?
3. **Plan d'echantillonnage (10-20%)** : quels 3 a 5 fichiers precis parmi les `INTEGRATION_M3_CYCLE_REJEU_*` et `REVIEW_*` faut-il auditer en priorite pour verifier s'il y a des faux verts ?
