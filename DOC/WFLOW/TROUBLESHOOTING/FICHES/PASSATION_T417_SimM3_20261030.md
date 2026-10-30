# 🧾 Passation T417 — Arrêt M3 simulé vs réel (état au 2026-10-30)

> Document de passation pour un autre agent. Il sépare **ce qui est vérifié** (fichier:ligne, trace, commit),
> **ce qui est hypothèse** (marqué 🔶), et **ce qui a été affirmé à tort** (marqué ❌) dans les échanges précédents.
> Aucune affirmation de ce document n'est un résultat terrain sauf mention explicite.

---

## 1. Objectif et consigne

- Objectif exploitant : simulateur M3 (translation) qui reproduit un arrêt Trémie / P1 proche du réel.
- Symptôme rapporté : en cycle Auto, la position simulée dérive (−0,45 m Trémie, +5,38 m P1) pendant que l'automate affiche 0,0 m / 5,0 m. En Manuel, arrêt propre ≈ 10 cm.
- Observation oscilloscope exploitant : `TranslationFinalInterlockRequest.BrakeReleaseRequest` tombe **instantanément** au capteur Trémie. ❌ **Non reproduit par le code ni par la trace** (voir §5).
- Règle d'exploitation : ne pas toucher au code automate de production sans validation humaine. Aucun commit sans validation (`AGENTS.md`). Le checkpoint et les commits déjà faits suivent une demande explicite du goal.

---

## 2. Commits (branche `work/base-machine-simu`)

| Commit | Contenu | Statut |
|---|---|---|
| `746e3a0f` | Base de référence avant ce lot (validation T421) | Référence |
| `8669c6dd` | Checkpoint : code simulation T417 non commité + contrat, étude, fiche, liste et template de trace | Commit `wip [NON TESTE]` |
| `0990a225` | Correction : défauts FB `PhysicalBrakeActive` (FB_Sim_TranslationBrake) et `BrakePhysicalActive` (FB_Sim_Translation) remis à **FALSE** | Commit `fix` |
| `be51ce13` | Bundle PLCopenXML régénéré (`CODE_Bundle.xml`, `CODE_DiffBundle.xml`) + XML L_SIMULATION + PRG_02 | Commit `build` |
| `102b1676` | Journal fiche T417 (A/B, sources candidates du délai) | Commit `docs` |
| `14009dcf` | Livrable partiel (section 11 de la fiche) | Commit `docs` |

**Revert** : `git revert <sha>` par commit. Le commit `0990a225` est isolé : il contient uniquement les deux défauts FB.

**Fichiers hors commits (autres chantiers, ne pas embarquer)** : `DOC/WFLOW/TASKS.yaml`, `DOC/WFLOW/TASKS_ORCHESTRATOR.yaml`, `DOC/WFLOW/PROMPTS/04_Divers.md`, `.claude/settings.local.json`, `reponse.md`, `TOOLS/AGENT_WORKFLOW/scripts/run_m3_study_agents.py`, `DOC/WFLOW/PROMPTS/10_ExempleOrchestrator/`.

**Attention** : pendant ce lot, un processus `git.exe` concurrent et un `index.lock` transitoire sont apparus. Vérifier qu'aucun autre agent ne committe avant tout commit.

**Attention** : `DOC/WFLOW/ETUDES/ANALYSES_T417/RAPPORT_AGENT_{A,B,C}_*.md` ont été committés dans `8669c6dd`. Ce sont des rapports d'agents antérieurs, **non vérifiés** par moi.

---

## 3. Code simulation : état et effets

Fichiers : `CODE/L_SIMULATION/` — `FB_Sim_Translation.st`, `FB_Sim_TranslationDrive.st`, `FB_Sim_TranslationBrake.st`, `FB_SimBench.st`, `GVL_Simulation.st`.

| Paramètre | Valeur FB (après `0990a225`) | Valeur GVL utilisée en simulation | Remarque |
|---|---|---|---|
| `PhysicalBrakeActive` / `BrakePhysicalActive` | FALSE (historique) | **TRUE** (`GVL_Simulation.st:79`) | Source unique = GVL, passée par `FB_SimBench.st:697` |
| `CartFreeActive` | FALSE | **TRUE** (`GVL_Simulation.st:84`) | Mode chariot libre actif en simulation ; non testé |
| `RollingFriction_Mps2` | 0,30 (était 0,10) | 0,30 | Effet mesuré seulement sur le chemin frein serré : **nul** |
| `StaticFriction_Mps2` | 0,35 (nouveau) | — | Non testé |
| `DecelRate_HzPerS` (drive) | 20 (contrat AC1 dit 25) | — | Incohérence contrat ↔ code non arbitrée |
| `TimeConstant_S` (drive) | 0,03 | — | — |
| `BrakeOpenDelayS` / `CloseDelayS` | 0,10 / 0,09 | — | Contrat AC2 dit ouverture 200 ms : incohérence |
| `FB_SimBench.st:752` | `M3_ActualFreqHz := REAL_TO_UINT(LIMIT(0, f, CST_M3MaxFreq_Hz)*100)` | — | Clamp ajouté |
| PT1 supprimé en frein ouvert | `VelocityTrue := VelocityTarget` (FB_Sim_Translation) | — | Changement de dynamique non testé hors frein |

🔶 **Hypothèse non vérifiée** : le chariot libre (`CartFree`) est la seule voie où le frottement agit. Son effet sur le dépassement Auto n'est pas démontré (la trace n'enregistre pas la position simulée).

---

## 4. Ce que la trace `Suivi_93` établit (vérifié)

Fichier : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_93_SIMU_M3_20261029.trace` (run en simulation, template T417, 30 variables, 910 échantillons, pas ~100 ms, horodatage en ms).

Procédure réelle de la run (confirmée par l'exploitant) : entrée forcée en X14 (`18 → 14` à 58,15 s), puis déplacement opérateur en X14 (DeadmanArmed 60,82 s, DirectionPositive 60,92 s, mouvement 61,24 s), arrivée Trémie, puis X14 → X15 (71,22 s).

| Instant (s) | Événement (valeurs lues dans la trace) |
|---|---|
| 58,15 | `Step` 18 → 14 (entrée forcée) |
| 61,14 | `BrakeReleaseRequest` 0 → 1 (frein demandé) |
| 61,24 | `M3_BrakeIsOpen_DI` 0 → 1 (frein ouvert physiquement) |
| 66,65 | Consigne variateur 50 → 5 Hz |
| 70,27 | `M3_PosTremie_DI` 0 → 1 ; `ReqTremieSemantic` 1 → 0 **même scan** ; `EffectivePermitM3_Tremie` 1 → 0 **même scan** |
| 70,37 | `DriveFreqCmd_Hz` = 0 et `DriveControlWord` = 0 (variateur coupé au scan capteur) |
| ≈70,6 | `ActualFrequencyHz` passe sous 0,5 Hz (déduit des valeurs : 0,66 Hz à 70,59 s, 0,32 Hz à 70,69 s) |
| 71,11 | `ActualFrequencyHz` = 0 |
| **71,22** | **`Step` 14 → 15** et **`BrakeReleaseRequest` 1 → 0** au même scan |
| 71,33 | `M3_BrakeIsOpen_DI` 1 → 0 (retombée physique) |
| 72,18 | `TranslationState.BrakeCmd` 1 → 0 |

**Conclusion vérifiable** : dans cette run, la demande de frein ne tombe pas au capteur Trémie. Elle tombe à la sortie d'étape X14, environ 0,5 s après que la fréquence est passée sous 0,5 Hz, en cohérence avec la confirmation d'arrêt de 500 ms du code. ✅ Ce n'est pas une preuve générale : c'est une run.

❌ Ce que j'ai affirmé à tort ou trop fort :
- « la run est forcée donc inutilisable » : seule l'entrée en X14 est forcée. Le déplacement dans X14 est un cycle normal.
- « une seule trace ne suffit pas » : la simulation est répétable ; trois runs identiques suffisent.

---

## 5. Pourquoi le code ne coupe pas le frein au capteur (vérifié)

Trois mécanismes candidats, à ne pas départager sans nouvelle donnée :

1. **Sortie d'étape X14 (veto)** : `PRG_05_Translation.st:400-405` (en SEMI_AUTO, M3 autorisé seulement aux étapes AX2 et AX14) et `PRG_05:715-721` (BrakeReleaseRequest := FALSE hors étape autorisée). Déclenché à la sortie de X14.
2. **Sortie X14 conditionnée à la vitesse** : `FB_CycleSemiAuto.st:363-367` (`TranslationStopTimer` = AT_Tremie AND NOT Busy, 500 ms, `CST_TranslationStopConfirmTime` à `FB_CycleSemiAuto.st:265`) ; `Busy` = |vitesse| > 0,5 Hz (`PRG_05_Translation.st:885`).
3. **Coupure dure au capteur neutralisée** : `PRG_06_Outputs.st:431-443` : `M3_TremieHardStopActive := DI AND ReqTremieSemantic` ; `BrakeReleaseRequest := ... AND NOT M3_TremieHardStopActive`. Si `ReqTremieSemantic` tombe au même scan que le capteur (c'est le cas dans la trace), la coupure dure est inopérante. 🔶 Est-ce un bug de séquencement ou un choix : non tranché.

Également : `FB_Translation.st:332` : `BrakeReleaseRequest := Brake.BrakeCmd`, et `FB_Brake.st:92-104` : le frein ne retombe qu'après `DelayMotorDecel` = **2 s** (`ST_fbTranslation_Cfg.st:34`) à partir de la fin de `MovementRequested`. 🔶 Cette source n'a pas été départagée des trois précédentes.

La coupure du variateur, elle, est bien au scan capteur (PRG_06 permission `AND NOT DI`).

**Vérification de référence** : la logique de coupure Trémie (`PRG_06:431-443`, `PRG_05:709/720`) est **identique** entre la référence MES `e38cc09a` et `HEAD`. Ce n'est pas un écart de branche.

---

## 6. Ce qui n'est PAS établi

- ❌ **L'observation de l'exploitant** (coupure instantanée du `BrakeReleaseRequest` au capteur, « pas de maintien de 2 s ») : contredite par la trace et par le code de référence. Causes possibles non vérifiées : variable oscilloscope différente, version de programme différente sur l'automate, run différente. **À clarifier avant toute correction.**
- ❌ **Le comportement voulu par la spec** : non lu (`AF_Partie-11`, `AF_Partie-13`). Je ne sais pas si la coupure au capteur est prévue.
- ❌ **« Maintenir le frein jusqu'à l'arrêt est plus sûr mécaniquement »** : affirmation non démontrée.
- ❌ **« La cause du dépassement est le frottement »** : non démontré. La réplique (voir §7) montre un effet nul sur le chemin frein serré, pas sur le chemin chariot libre.
- ❌ **Le −0,45 m** : non reproduit. La trace n'enregistre pas la position simulée (`SimM3ObsPositionTrue_M` non publié dans `GVL_Troubleshooting`).
- 🔶 **`ActualFrequencyHz` est à l'échelle ×100** (5000 = 50 Hz) : déduit des valeurs, à confirmer dans le code.
- 🔶 **Le mode « AUTO » de l'exploitant = SEMI_AUTO** : `E_Mode` ne contient que DISABLE, MAINT_N1, MAINT_N2, SEMI_AUTO (`CODE/F_MODES/E_Mode.st`). Mon erreur initiale : j'avais écrit « AUTO ».

---

## 7. Réplique minimale (non reproductible aujourd'hui)

Script `replica_t417_stop.py` (dans l'ancien scratchpad, **plus accessible**). Hypothèses : pas de balancier, pas de came capteur, droop = 0, capteur seuil 0 + hystérésis 0,02.

| Essai | Résultat |
|---|---|
| Arrêt Trémie 20 Hz, friction 0,30 | −0,069 m |
| Idem, friction 0,10 | −0,069 m (identique) |
| Idem, 40 Hz | −0,211 m |
| Frein relâché 3 s après arrêt, consigne nulle, angle = 0 | −0,069 m (pas de dérive sans balancier) |

Limite : ne modélise pas le balancier, donc ne dit rien du chariot libre (H4).

---

## 8. Tests et gates (état vérifié)

**Suite CI L_SIMULATION** (`TOOLS/TEST_AUTO_CI/scripts/run_tests.py --domain L_SIMULATION`, ~40 s) :
- Base `746e3a0f` : 6 PASS / 6 FAIL.
- État courant (après `0990a225`) : **6 PASS / 6 FAIL, mêmes échecs**. Aucune régression.
- Échecs présents sur la base (non causés par ce lot) :
  - `FB_SimBench` ; `SimOperatorJoystick` ; `SimManualReference`.
  - `SimTranslationLoop` : `TC-T417-LOOP-A/B` attend PHASE 3, obtient 2.
  - `FB_Sim_Encoder` : `TC-P13-034/035`.
  - `FB_Sim_Translation` : **ne compile pas** (`FullTravelTimeS` utilisé 8 fois dans `RESULTS/L_SIMULATION/tests/test_fb_sim_translation.st`, paramètre supprimé au refactoring T301). Réécrire les 19 tests changerait leurs attendus : **non fait, à valider**.

**Gates palier C** (`run_all_gates.py --palier C`) : 8 échecs sur 61, **identiques à la base** sauf G390 qui passe après régénération du bundle.
- Échecs : G300, G340, G430, G483, G503, G517, G518, G519.
- G518 (odométrie M3, source unique) : exige `TC-T301-SRC-001/002` dans `test_fb_sim_translation.st` (fichier non compilable). Exploitant : **pas urgent**, à laisser de côté.
- G517, G503, G519 : logique de production, hors périmètre de ce lot.

**G200** (`G200_check_linkage.py --report`) : PASS, 0 erreur, 2167 instances vérifiées, 1722 avertissements (liste E/S, « non trouvé dans la carte E/S »), à relire.

---

## 9. Bundles (livrables à importer)

- `CODE_XML/CODE_Bundle.xml` : import **complet**, 82 POU distincts, XML bien formé.
- `CODE_XML/CODE_DiffBundle.xml` : import **rapide**, 13 objets : `FB_CycleTime`, `FB_SimBench`, `FB_Sim_Encoder`, `FB_Sim_Joystick`, `FB_Sim_KlossTorque`, `FB_Sim_PositionSensor`, `FB_Sim_Safety`, `FB_Sim_SuspendedLoad`, `FB_Sim_Translation`, `FB_Sim_TranslationBrake`, `FB_Sim_TranslationDrive`, `FB_Sim_WinchElectrical`, `FB_Sim_WinchMotor`.
- Vérification : diff hors fins de ligne (`--ignore-cr-at-eol`) = 34 insertions / 14 suppressions sur `CODE_Bundle.xml`. Les grandes suppressions brutes sont un artefact CRLF/LF.
- 🔶 **Non validé** : aucun import CODESYS, aucun test sur banc ou Device. C'est une tâche de l'exploitant.
- Le `CODE_DiffBundle.xml` contient 13 objets (fermeture des dépendances de type), et non les 3 annoncés dans un rapport antérieur.

---

## 10. Trace et template (outillage)

- Liste de variables : `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/trace_m3_stop_auto_ax14_ax15_v1.txt` (30 voies publiques).
- Template importable : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/config/T417_Stop_Auto_AX14_AX15_TEMPLATE.trace` (généré par `scripts/generate_trace_template.py`, modèle `Suivi_92_TB_M3_LINK_20261002.trace`, `--no-trace-data`). 🔶 **Import CODESYS non testé**.
- Les variables simulation (`SimM3Obs*`, dont `SimM3ObsPositionTrue_M`) **ne sont pas** dans le template : non publiées dans `GVL_Troubleshooting`. Ajout = modification GVL, à valider.
- Variables utiles non encore dans la trace (à valider avant ajout) : `PRG_03...Data.Auth.Mode` (pour confirmer SEMI_AUTO), signaux de rampe `SpeedRamp` et `MovementRequested` (internes FB_Translation, probablement non publics).

---

## 11. Analyse A/B (agents)

- Runner : `TOOLS/AGENT_WORKFLOW/scripts/ollama_subagent.py`. **Texte seul** : les agents n'ont pas accès aux fichiers. Les tentatives avec « lecture du dépôt » n'ont produit que des annonces, sans analyse (sorties vides, `$TEMP/t417_audit/`).
- Modèles disponibles : `deepseek-v4.1-flash:cloud`, `glm-5.3-flash:cloud` (et `deepseek-v4-flash:cloud`, `qwen3.8:27b`, `gemma4`).
- A/B réalisé sur **extraits fournis** (`$TEMP/t417_ab/AB_deepseek.md`, `AB_glm.md`) : A1 (coupure dure inopérante au scan) validée pour la run mesurée, « jamais » = extrapolation ; A2 (veto à la sortie X14) validée en SEMI_AUTO ; A3 (frein ouvert pendant décélération) : clause validée, conséquence non vérifiable ; A4 (variateur coupé par la permission) : chronologie prouvée, causalité non prouvée.
- Alertes soulevées (non tranchées) : coupure dure possiblement « morte par construction » (DeepSeek) ; vérifier la condition 500 ms vs 0,11 s (GLM).

---

## 12. Décisions ouvertes (pour l'exploitant, pas pour un agent)

1. **Comportement voulu** : frein maintenu jusqu'à l'arrêt confirmé (code actuel) ou coupé au capteur Trémie (observation oscilloscope). Dépend de la spec `AF_Partie-11`/`AF_Partie-13` et de la machine réelle, pas d'un test.
2. **Variable et version de l'observation oscilloscope** : laquelle, sur quel programme automate.
3. **Coupure dure neutralisée** (`ReqTremieSemantic`) : bug de séquencement ou choix ?
4. **Test G518** : réécrire les 19 tests `test_fb_sim_translation.st` (changement d'attendus, à valider) ou laisser en attente.
5. **Import CODESYS** du bundle et test banc : à faire par l'exploitant.

## 13. Plan de test proposé (simple)

- **T1** : trois runs identiques en simulation, procédure de `Suivi_93` (entrée X14 forcée, déplacement vers Trémie), enregistrées avec le template T417.
- **T2** : sur chaque run, relever l'écart entre (a) fréquence sous 0,5 Hz, (b) `Step` 14→15, (c) `BrakeReleaseRequest` 1→0. Critère : (b) et (c) au même scan, et (b) − (a) ≈ 0,5 s.
- **T3** : importer le bundle dans CODESYS, relancer T1, comparer au simulateur.
- **Critère d'arrêt** : si T2 reproduit sur les trois runs, le mécanisme est établi pour ce code. L'écart avec l'oscilloscope exploitant reste à expliquer (point 2 de §12).

---

## 14. Erreurs commises pendant ce lot (à ne pas reproduire)

- Affirmations non vérifiées présentées comme faits (« validé par l'exploitant » dans la fiche : corrigé).
- Conclusion trop forte sur le frottement (« refuté »), alors que seul le chemin frein serré est testé.
- Confusion entre « AUTO » et SEMI_AUTO.
- Exigence de tests répétée au lieu d'un plan simple.
- Décision présentée comme binaire et « la mienne », alors qu'elle dépend de la spec et de la machine.
- Boucle de réponses au hook `/goal` sans progrès.
- Tentatives d'agents texte seul présentées comme des audits.

---

## 15. Fichiers de référence

- Fiche de suivi : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T417_SimM3_Arret_20261029.md` (sections 4bis barème, 10 journal, 11 livrable partiel).
- Contrat : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T417_SIMULATION_M3_REALISTE.yaml`.
- Étude : `DOC/WFLOW/ETUDES/ETUDE_CONCEPTION_T417_SIMULATION_TRANSLATION_M3.md`.
- Tâche : `DOC/WFLOW/TASKS.yaml` entrée T417 (non modifiée par ce lot).
- Trace : `TOOLS/PLC_CSV_SNAPSHOT/RESULTS/trace/Suivi_93_SIMU_M3_20261029.trace`.
