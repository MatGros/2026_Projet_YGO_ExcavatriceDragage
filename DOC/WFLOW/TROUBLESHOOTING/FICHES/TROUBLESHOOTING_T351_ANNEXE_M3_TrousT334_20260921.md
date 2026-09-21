# 🔎 T351 — Annexe M3 : niveau d'exhaustivité de la chaîne T334 (audit de trous)

> 📌 Emplacement : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T351_ANNEXE_M3_TrousT334_20260921.md`
> 📅 Date : 2026-09-21 · 🏷️ Acteur : **DSH17** (session `task-T351-annexeM3`) · 📄 Statut : **AUDIT LIVRÉ + CORRIGÉ APRÈS AUDIT ORCHESTRATEUR — ANNEXE SÉPARÉE, à fusionner par l'orchestrateur sous son autorité**
> 🎫 Lot parent : `T351` (C2) — grille d'audit = `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T351_CARTOGRAPHIE_TREUILS.yaml` (AC1→AC12) + `DOC/WFLOW/CONTRACTS/BRIEF_T351_CARTOGRAPHIE_JOYSTICK_TREUILS.md` §5.
> 🚫 **Mission strictly read-only.** Aucun fichier de `CODE/` écrit, aucun test, aucun gate, aucun bundle, aucun `CODE_XML/`, aucun `Device.export`, aucune IHM, aucun commit. La fiche T334 **n'a pas été modifiée** (verrou d'écriture d'un autre acteur, fichier déjà sale) : les compléments sont rédigés au §4, prêts à fusionner.

---

## 0. 🧭 Réponse courte

| Question | Réponse |
|---|---|
| La chaîne M3 de T334 est-elle au niveau d'exhaustivité exigé par T351 (§5 : « même gabarit, même exhaustivité ») ? | **PARTIELLEMENT** — non par manque de contenu, mais par **péremption des références**. |
| Le **contenu** de la chaîne est-il juste ? | 🟢 **OUI pour le bas de chaîne** (arbitre, `FB_Translation`, décodeur, barrière, mots variateur, mapping `%Q`, CSV). **65 lignes de tableau sur 96** sont **EXACT**, et elles couvrent tout l'aval sur `FB_Translation`, `FB_TranslationCmdArbitrationM3`, `FB_TranslationOutputInterlock`, `FB_Translation_PositionDecoder`, `PRG_06_Outputs`, `FB_Joystick`, `FB_AxisScale` et les DUT. |
| La fiche est-elle **utilisable comme référence permanente** aujourd'hui ? | 🔴 **NON** — sans bloc d'ancrage de révision, **49 couples `fichier:ligne` sont périmés** (27 lignes de tableau, décalages mesurés **+3 à +91 lignes**) et **2 affirmations sont FAUSSES**. Un lecteur qui suit T334 au pied de la lettre ouvre les mauvaises lignes. |
| Ce qui **n'a pas besoin d'être refait** | § 0.3 ci-dessous — 6 blocs confirmés exacts, dont la preuve de convergence (arbitre / barrière / mots variateur **uniques**) que j'ai re-prouvée indépendamment par comptage d'écritures. |

### 0.1 Trous par gravité

| Gravité | Nombre | Nature |
|---|---|---|
| 🔴 bloquant | **3** | absence d'ancrage de révision ; références `FB_CycleSemiAuto.st` périmées de +20 à +91 ; permis directionnels `EffectivePermitM3_*` non tracés jusqu'à leurs producteurs |
| 🟠 notable | **7** | références `PRG_03` périmées (+3 à +17) ; références `PRG_02` périmées (+5 à +20) ; miroirs IHM `PRG_07` périmés (+50) et constat A06/D09 FAUX ; `TglMaintenanceZoneAccess` jamais nommé ; étages d'entrée physiques (`%IX`) absents ; FB traversés incomplets (encodeurs) ; arête de scan safety manquante |
| 🟡 cosmétique | **3** | renvoi interne cassé « cf. §8 D04 » ; absence de branche `MAINT_N1`/`MAINT_N2` non **déclarée** ; famille « actions de la benne » non **déclarée** comme non-source pour M3 |

### 0.2 Verdict en 3 lignes

1. **Le squelette de T334 est bon et le bas de chaîne est exact** : les deux chaînes convergent bien (un seul arbitre, une seule barrière, un seul jeu de mots variateur — re-prouvé par comptage d'affectations), le mapping physique `%QW6`/`%QW7`/`%QX27.2` est bien présent, et la plupart des références des FB d'axe sont exactes à la ligne près.
2. **Mais T334 est écrit sans ancrage de révision** : aucune occurrence de `git hash-object` ni de blob SHA (grep : 0 résultat sur 789 lignes), et le seul hash présent (`fd12dc0`, §10bis) est celui d'une session de challenge postérieure — or `HEAD` valait **`d6e54377`** pendant tout l'audit et est passé à **`065591fb`** à `01:33:26` (commit d'un lot concurrent).
3. **Conséquence mesurée** : toutes les références T334 de `FB_CycleSemiAuto.st` sont décalées de **+20 à +91** (blob `032af59fc1fa`, 1652 l) ; `PRG_03_Modes_Cycle.st` de **+3 à +17** ; `PRG_02_Acquisition.st` de **+5 à +20** ; `PRG_07_Supervision.st` de **+50** — **décalages obtenus par appariement `motif cité ↔ ligne lue`, jamais par comptage de lignes** (§6-N11) ; la même vérité (restauration boot des bypass) porte **trois valeurs contradictoires** dans la fiche, dont **aucune** ne correspond au disque.
4. ⚠️ **Et quatre fichiers ont bougé PENDANT cet audit** (`PRG_02_Acquisition.st` — **3 états en 8 minutes**, `PRG_07_Supervision.st`, `GVL_Simulation.st`, `PRG_04_Treuils_Benne.st`), `HEAD` est passé de `d6e54377` à `065591fb`, et **l'orchestrateur s'est lui-même fait piéger** en comparant deux états différents (critique `±1` rétractée après re-mesure) → voir l'encadré **🪨 LEÇON** au §1.3 et le tableau des **trois états** de `PRG_02`.

### 0.3 🟢 Ce qui est CONFIRMÉ exact et n'a pas besoin d'être refait

| # | Bloc confirmé | Preuve (relue sur disque) |
|---|---|---|
| 1 | **Convergence des deux chaînes avant l'axe** — instance d'arbitre unique, FB de mouvement appelé une seule fois, barrière finale unique | un seul `instArbM3(` (`PRG_05_Translation.st:363`), un seul `instTranslationM3(` (`:537`), un seul `instTranslationOutputInterlockM3(` (`PRG_06_Outputs.st:434`) — grep sur fichier entier |
| 2 | **Un seul jeu de mots variateur physique** — conclusion centrale de T334 §6.1 | `M3_CommandWord` (PRG_06_Outputs.st:458), `M3_SetpointFrequencyHz` (:459), `M3_BrakeRelease_RQ` (:457) : **une seule affectation chacun** dans tout `CODE/`. Les autres occurrences (`PRG_07_Supervision.st:565` = `M3_BrakeRelease_RQ`, `:576` = `M3_CommandWord`, `:577` = `M3_SetpointFrequencyHz`) sont des **miroirs IHM** `GVL_IHM.IoHw.Out.*`, pas des producteurs — ⚠️ `:566` est le miroir Kobold (`M1_M2_KoboldMeasureEnable_RQ`), pas un mot M3 |
| 3 | **Mapping physique de sortie M3** jusqu'au `%Q` | `Device_IO_20260918.csv:190` → `%QW6` (0x3101) ; `:207` → `%QW7` (0x3100) ; `:480` → `%QX27.2` (VH_0008ER) ; `:471` → `M3_BrakeIsOpen_DI %IX225.2` ; `:224`/`:241` → `M3_StatusWord %IW8` / `M3_ActualFrequencyHz %IW9` — **toutes ces lignes CSV sont exactes** |
| 4 | **Chaîne basse manuelle ET cycle** (décodeur → jetons → `FB_Translation` → barrière → `PRG_06`) | 24 références vérifiées, toutes **EXACT** (voir §2) |
| 5 | **DUT et déclarations IHM** | `ST_TranslationCmd.st:10,12,13,14,16` ; `ST_HwOperator.st:8` ; `ST_ProgramTranslationRequest.st:9-10` ; `ST_TranslationCfg.st:9-11` — **EXACT** |
| 6 | **Constats de fond de T334** (indépendamment de la numérotation) | bypass FdC non filtré par le mode (`PRG_05_Translation.st:571`) ✔ ; asymétrie AX2 (cible conservée) / AX14 (cible remise à 0) ✔ ; escalade cause 6 à 1,5 s + masque `16#00F8` (`FB_Safety_Translation.st:202,268`) ✔ ; plafond SEMI_AUTO mort (`GVL_PERSISTENT.st:97`, 0 lecteur) ✔ ; AX12 = sécurité géométrique légitime ✔ |

---

## 1. 🧊 Objet de l'audit, méthode et ANCRAGE DE RÉVISION

### 1.1 Objet
Audité : **la chaîne M3 déjà produite par T334** — section 4 « CHAÎNE MANUELLE » (codes `M01`→`M66`, lignes 62-137) et section 5 « CHAÎNE CYCLE AUTO » (codes `C01`→`C35`, lignes 141-184), **plus** les sections qui portent les affirmations de chaîne (§6.1/§6.2/§6.4/§6.5, §9, §10 constats, §10bis, §11).

Référentiel de comparaison : contrat `TASK_CONTRACT_T351_CARTOGRAPHIE_TREUILS.yaml` **AC1→AC12** (transposés de M1/M2 à M3) et **§5 du brief T351** (« la chaîne M3 déjà produite dans T334 doit être relue et complétée si des trous apparaissent par comparaison avec le niveau de détail attendu ici — même gabarit, même exhaustivité »).

La grille a→g imposée par la mission T351-ANNEXE est balayée **section 3**, trou par trou, avec sa preuve.

### 1.2 Méthode de vérification (et garde-fou anti-REX T345)
Le piège documenté (REX T345 : deux outils de lecture ont rendu le contenu **HEAD** au lieu du **disque**) a été neutralisé de deux façons :
1. **lecture native disque** — outil `read` (offset/limit) et outil `grep` sur les chemins réels `CODE/...` du dossier de travail (jamais `git show`, jamais `git cat-file`, jamais une archive) ;
2. **détection de péremption par appariement contenu ↔ numéro de ligne** — pour chaque référence je ne me suis pas contenté de « la ligne existe », j'ai vérifié que **le motif cité par T334 est bien à la ligne citée** ; quand le motif existe ailleurs, le décalage est donné.

Preuve d'absence : chaque fois qu'un trou repose sur « T334 ne dit pas X », il est justifié par un **grep réel à 0 occurrence** sur `CODE/` ou sur la fiche (mentionné dans la preuve).

### 1.3 🔒 Bloc d'ancrage de révision

| Élément | Valeur mesurée |
|---|---|
| `git rev-parse --short HEAD` | **`065591fb`** au `01:33:26` — ⚠️ **le `HEAD` a bougé PENDANT l'audit** : `d6e54377` (valeur de toutes mes mesures de contenu) → `065591fb` (`fix(benne): T262 phase B - seuil d'ouverture benne cable`, commit d'un lot concurrent) |
| Horodatages ISO des mesures | mesure initiale `2026-09-21T01:23:34+02:00` · re-mesures `01:28:50` et `01:31:44` (**ancrage de contenu, fait foi**) · contrôles d'état finaux `01:33:26` et **`01:34:18`** |
| Fiche auditée (SALE) | `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md` — blob disque **`2ea84800602ea530698c4a220f88ad48e3b7fd8f`** (789 lignes) — **inchangé sur les cinq mesures** |
| `git status --short -- CODE/` (`01:36:56`) | **VIDE — 0 `M`, 0 `??`** : le lot concurrent a committé successivement `065591fb` puis **`b25020bc`**, absorbant `PRG_02_Acquisition.st` et `GVL_Simulation.st`. **Les blobs cités sont inchangés** (`PRG_02` = `5b8baa9ba8ea` = blob `HEAD` ; `GVL_Simulation` = `c02a3bfc7848` = blob `HEAD`) |

> 🎯 **Point capital** : **le blob `5b8baa9ba8ea` de `PRG_02_Acquisition.st` a été *SALE* pendant cinq mesures, puis est devenu le blob *PROPRE* de `HEAD` à `01:36:56` — sans qu'une seule de ses lignes change.** Le contenu disque n'a jamais bougé : seul le **livre de comptes Git** a changé. **Les numéros de ligne de cette annexe restent donc valides** — ils ont été obtenus par **lecture de contenu**, jamais dérivés de `HEAD`, ni d'un `git status`. C'est la démonstration finale, et la raison pour laquelle l'ancrage de T334 doit se faire par **blob**, ni par commit ni par état sale/propre (§1.3 LEÇON, §6-N11).

**État sale / propre RE-MESURÉ** (blobs `git hash-object` + lignes, contenu du `01:31:44`, état vs `HEAD` re-contrôlé à `01:36:56`) :

| Fichier | Blob disque | Lignes | État vs HEAD |
|---|---|---|---|
| `CODE/M_MAIN/PRG_02_Acquisition.st` | `5b8baa9ba8ea0e9e0204ac8a5cc0a9a6b1bd2bb7` | 719 | ⚠️ **SALE de `01:28` à `01:34`** (5 mesures) → ✅ **PROPRE depuis `b25020bc`** — **blob identique, contenu inchangé**. *Était **PROPRE** (`fabb8f764dd8`, 714 l) à `01:23:34`, puis `892de7b784f5` (720 l) à `01:28:50`* |
| `CODE/L_SIMULATION/GVL_Simulation.st` | `c02a3bfc78486706ca3cd5110816de81e3b9b099` | 138 | ⚠️ **SALE** aux mesures intermédiaires → ✅ **PROPRE depuis `b25020bc`** (blob identique) — était `234163380e73` à `01:28:50` |
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | `31760d59b4e09b03a8e91b2358f8804a6b1985ad` | 1982 | ✅ **PROPRE** depuis `065591fb` (était SALE à `01:23-01:31`) |
| `CODE/M_MAIN/PRG_07_Supervision.st` | `c10f004151f80e099eb04537c9a87cc8a3d4c986` | 920 | ✅ **PROPRE** depuis `065591fb` (était `d3449a6a85ad`, SALE) |
| `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` | `9c493a5f0d5726b3d276c455bc3efca83fe29ebd` | 838 | ✅ **PROPRE** depuis `065591fb` |
| `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_CycleCfg.st` | `81298082f8fdcc8b344cfd74fc95db4be337e8c9` | 22 | ✅ **PROPRE** depuis `065591fb` |
| `CODE/M_MAIN/PRG_03_Modes_Cycle.st` | `6e22c76df8623759f0f696d5f003ec34540b8fd1` | 555 | ✅ **PROPRE** |
| `CODE/M_MAIN/PRG_05_Translation.st` | `27a55d0c7e3ab3811d9a5ea46784ce5a31a90e68` | 827 | ✅ **PROPRE** |
| `CODE/M_MAIN/PRG_06_Outputs.st` | `3b7534a3acd4c5bba6c667118abaf32f41eb3f67` | 549 | ✅ **PROPRE** |
| `CODE/G_CYCLE/FB_CycleSemiAuto.st` | `032af59fc1fa8ebb90c90b43c69dc30b71472419` | 1652 | ✅ **PROPRE** |
| `CODE/H_TREUILS_BENNE/FB_WinchDirectionInterlock.st` | `5fa9e0405ac30ff83fb384e22725fae134729af6` | 178 | ✅ **PROPRE** |

Blobs disque (`git hash-object`, contenu **disque**, pas index) des fichiers de `CODE/` cités par cette annexe ou par T334 :

| Fichier | Blob disque (SHA-1) |
|---|---|
| `CODE/I_TRANSLATION/FB_Translation.st` | `7bd9fd508bde9eab9ee4f5e24c6441f65e508dff` |
| `CODE/M_MAIN/PRG_05_Translation.st` | `27a55d0c7e3ab3811d9a5ea46784ce5a31a90e68` |
| `CODE/I_TRANSLATION/FB_TranslationCmdArbitrationM3.st` | `2d321e97d4f6869ec527e62361b01a0834b088fd` |
| `CODE/I_TRANSLATION/FB_TranslationOutputInterlock.st` | `c4442c0f0a3d0d6ec53ca84b134b3c7228043376` |
| `CODE/M_MAIN/PRG_06_Outputs.st` | `3b7534a3acd4c5bba6c667118abaf32f41eb3f67` |
| `CODE/G_CYCLE/FB_CycleSemiAuto.st` | `032af59fc1fa8ebb90c90b43c69dc30b71472419` (1652 lignes) |
| `CODE/M_MAIN/PRG_03_Modes_Cycle.st` | `6e22c76df8623759f0f696d5f003ec34540b8fd1` |
| `CODE/M_MAIN/PRG_02_Acquisition.st` (**SALE depuis l'audit**) | `5b8baa9ba8ea0e9e0204ac8a5cc0a9a6b1bd2bb7` (719 l) |
| `CODE/D_JOYSTICK/FB_Joystick.st` | `4d373c8ed388eae7257d4ca6a391e73e43e4cfbc` |
| `CODE/D_JOYSTICK/FB_AxisScale.st` | `85d6fb1bb6ae977f7d2da7c8745a1e130d3afee7` |
| `CODE/I_TRANSLATION/FB_Translation_PositionDecoder.st` | `a344eb6f4f26d72c9e62be243199d56197337015` |
| `CODE/I_TRANSLATION/FB_Translation_PositionEstimator.st` | `1fcda4ea13ac0a79ca75022ca7506662bad8fece` |
| `CODE/F_MODES/FB_Modes.st` | `4a890744c9f32c858922338d9dd989a5e0edbcca` |
| `CODE/I_TRANSLATION/FB_Safety_Translation.st` | `ad73b45412a0a81cd604ec60c752c2e26dfc66a1` |
| `CODE/A_COMMUN/FB_Brake.st` | `b9d14d1c81194afd126f254599cc29602b69fd59` |
| `CODE/M_MAIN/PRG_07_Supervision.st` (PROPRE depuis `065591fb`) | `c10f004151f80e099eb04537c9a87cc8a3d4c986` (920 l) |
| `CODE/L_SIMULATION/GVL_Simulation.st` (SALE depuis l'audit) | `c02a3bfc78486706ca3cd5110816de81e3b9b099` (138 l) |
| `CODE/GVL_PERSISTENT.st` | `0e5860a57b5d7f369597810d2d59e167a61784eb` |
| `CODE/J_SUPERVISION/_TYPES/2_TRANSLATION/ST_TranslationCmd.st` | `8a84e236d180f98c48c1d1540ee66dbcddb7dbec` |
| `CODE/J_SUPERVISION/_TYPES/2_TRANSLATION/ST_TranslationCfg.st` | `81ceced388df782a9ff6f5aac15343f4e9a58ebb` |
| `CODE/J_SUPERVISION/_TYPES/2_TRANSLATION/ST_BypassTranslation.st` | `9fab7a984de0165dbcb3ebbe93d6d93c8e8ab849` |
| `CODE/J_SUPERVISION/_TYPES/2_TRANSLATION/ST_TranslationState.st` | `496924e9a737354a452a3bfcefa9d896920957fb` |
| `CODE/J_SUPERVISION/_TYPES/4_JOYSTICK_ACQUISITION/ST_HwOperator.st` | `715e6ad835a9dd292a55c3e8035816522a497666` |
| `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_ProgramTranslationRequest.st` | `e7f30fd558fef62a48a60a2272f9ab5bdc9b1bd1` |
| `CODE/J_SUPERVISION/_TYPES/3_CYCLE_ET_MODES/ST_ModesCmd.st` | `055c3483350f64e9e9541de503306cec7f9ea3fd` |
| `CODE/J_SUPERVISION/_TYPES/7_COMMUN_CONFIG/ST_CommunCfg.st` | `933a6bf73f60a0e4572f360ebef21b8e15f4647f` |
| `CODE/I_TRANSLATION/_TYPES/ST_fbTranslation_Cfg.st` | `4357689ab0ead995272b30610d3c19c018742927` |
| `TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv` | `18c75783a18856a1d4450c82624ceccbefe4f324` |

⚠️ **La fiche T334 est modifiée non committée et sous verrou d'écriture d'un autre acteur (DSH07). Cet audit est ancré sur le CONTENU (blobs), pas sur un commit** : mesures de contenu à `01:23:34`, `01:28:50`, `01:31:44` (**les numéros de ligne de cette annexe valent pour le contenu mesuré à `01:31:44`** — voir le tableau des trois états ci-dessous) · contrôle d'état final à `01:34:18` · fiche T334 blob `2ea84800602e` (inchangé sur les 4 mesures). ⚠️ **`HEAD` a bougé pendant l'audit** : `d6e54377` → **`065591fb`** à `01:33:26` (commit d'un lot concurrent). Seule la référence de blob permet de savoir de quelle version on parle.

⚠️ **Quatre fichiers `CODE/` cités ont bougé PENDANT l'audit** (`PRG_02_Acquisition.st` — **trois états en huit minutes** · `PRG_07_Supervision.st` · `GVL_Simulation.st` · `PRG_04_Treuils_Benne.st`).

### 🪨 LEÇON — un numéro de ligne n'a de sens qu'accompagné du blob du fichier

> Ce dépôt vient de le démontrer **deux fois dans le même audit**, et **des deux côtés** :
> 1. `PRG_02_Acquisition.st` a porté **trois états distincts en huit minutes** pendant que cet audit le mesurait ;
> 2. l'**orchestrateur lui-même** s'est fait piéger en comparant des numéros de ligne mesurés sur un état avec un disque **déjà passé à l'état suivant** — il a produit une critique `±1` qui était **fausse**, puis l'a **rétractée** après re-mesure (`892de7b784f5` → `5b8baa9ba8ea`).
>
> **Règle qui en découle, pour toute reprise de cette annexe ou de T334** :
> - un couple `fichier:ligne` **sans son blob** est **inutilisable** ;
> - **relire** la ligne (outil de lecture) — **jamais** la **calculer** (`ligne citée + offset`) : le décalage de `PRG_04_Treuils_Benne.st` varie de **+1 à +11 dans le même fichier** (§5-A09) ;
> - **ne jamais** déduire un décalage d'un **delta de comptage de lignes** — mais pour la **bonne** raison : mesurer `Measure-Object -Line` sur une sortie `git show` **sous-estime** le fichier (il **ignore les lignes vides**) ; sur `PRG_04_Treuils_Benne.st`, **1825** contre **1982** par `Get-Content`/`ReadAllLines`/tableau `git show`, alors que le disque **est** la version de `HEAD` (4 méthodes concordent, `git diff --stat HEAD` vide). Un écart entre deux comptages peut donc n'être qu'un **artefact de méthode** ;
> - **règle opérationnelle** : comparer **toujours par blob SHA** (`git hash-object <fichier>` vs `git rev-parse HEAD:<fichier>`), **jamais** par nombre de lignes (§6-N11).

### 📋 `PRG_02_Acquisition.st` — traçabilité des TROIS états (aucun remplacement silencieux)

| Référence (motif exact) | T334 cite | `fabb8f764dd8`<br>714 l · 01:23:34 · **PROPRE** | `892de7b784f5`<br>720 l · 01:28:50 | **`5b8baa9b`**<br>**719 l · 01:31:44 → actuel · SALE** |
|---|---|---|---|---|
| `HwReal.Operator.JoyXRaw_ANA1 :=` | — | 181 | 181 | **181** |
| `HwReal.Translation.M3_ActualFrequencyHz :=` | — | 177 | 177 | **177** |
| `M3_ReqTremie := M3_CommandWord = 1,` | 311-312 | 311 | 317 | **316** |
| `(WORD_TO_UINT(M3_SetpointFrequencyHz) / 100.0)` | 314 | 314 | 320 | **319** |
| `HwIn.Operator := SEL(OperatorInputSourceSimulated, …)` | 434 | 440 | 446 | **445** |
| `RawX := HwIn.Operator.JoyXRaw_ANA1,` | 465 | 476 | 482 | **481** |
| `Data.Joystick.AxisX := instJoystick.AxisCmdX;` | 475 | 486 | 492 | **491** |
| `Data.Joystick.AxisY := …` | 476 | 487 | 493 | **492** |
| `Data.Joystick.DeadmanArmed := …` | 477 | 488 | 494 | **493** |
| `Data.Joystick.AtNeutralXY := …` | 478 | 489 | 495 | **494** |
| `Data.M3.ActualFrequencyHz := …` | 688 | 703 | 709 | **708** |

**Mode de lecture de ce tableau** (traçabilité honnête) :
- colonne **`5b8baa9b`** = **la colonne opérationnelle** : état **actuel** du disque, relu **ligne à ligne** avec l'outil de lecture (`read`) — c'est elle qui est reprise dans §2.1, §2.2, §3.5 et §4.10 ;
- colonne **`892de7b784f5`** = état **intermédiaire** publié par la 2ᵉ version de cette annexe ; obtenue par `grep` à `01:28:50`. **Ce blob n'existe plus** : cet ensemble n'est **pas re-vérifiable rétroactivement** (§6-N10) ;
- colonne **`fabb8f764dd8`** = état de **début d'audit** (blob **propre**), publié par la 1ʳᵉ version de cette annexe ; obtenu par `grep` à `01:24` ;
- ⚠️ **les trois ensembles étaient exacts pour le blob qu'ils déclaraient** — la cause de l'écart est une **suppression d'une ligne située entre les lignes ~320 et ~445** par un lot concurrent, ce qui décale de **−1** tout ce qui suit ce point et **laisse `:319` inchangé** (cohérent avec les trois colonnes).

---

## 2. ✅ Contre-vérification des références de T334 (échantillon prouvé)

Méthode : lecture native du **disque**, appariement **motif cité ↔ ligne citée**. Verdicts : `EXACT` = le motif cité est bien à la ligne citée · `DECALE de ±n` = le motif existe, à une autre ligne · `FAUX` = la ligne citée porte un contenu sans rapport avec l'affirmation · `NON VERIFIABLE` = impossible de trancher.

> 🧊 **Les numéros de la colonne « Contenu réel » sont ceux du blob `5b8baa9ba8ea` de `PRG_02_Acquisition.st` (état actuel, §1.3) pour tout ce qui touche ce fichier**, et des blobs de §1.3 pour les autres. Les valeurs antérieures de `PRG_02` (pour `fabb8f764dd8` et `892de7b784f5`) sont conservées **sans remplacement silencieux** dans le tableau des trois états du §1.3.

### 2.1 Chaîne MANUELLE (M01→M66)

| Réf. T334 | Ligne citée par T334 | Contenu réel sur disque (blobs du §1.3, ancrage final `2026-09-21T01:31:44`) | Verdict |
|---|---|---|---|
| M01 | `ST_HwOperator.st:8` | `JoyXRaw_ANA1 : INT;` | EXACT |
| M01 | `PRG_02_Acquisition.st:181` | `HwReal.Operator.JoyXRaw_ANA1 := JoyXRaw_ANA1;` | EXACT |
| M01 | `PRG_02_Acquisition.st:465` (consommateur) | `:465` = `// (GVL_IHM.CycleSemiAuto.State.CycleStep = E_AutoCycleStep.AX8_BOTTOM_CONFIRMED)` dans le bloc `DirectInversionPermit`. La recopie réelle est `RawX := HwIn.Operator.JoyXRaw_ANA1,` en **`:481`** | **DECALE +16** |
| M02 | `PRG_02_Acquisition.st:182-183` | `JoyYRaw_ANA2` / `JoyBtnRaw` | EXACT |
| M03 | `PRG_02_Acquisition.st:434` | Le `SEL(OperatorInputSourceSimulated, HwReal.Operator, HwSim.Operator)` (occurrence **unique** du fichier) est en **`:445`** | **DECALE +11** |
| M03 | `PRG_02_Acquisition.st:137` | `OperatorInputSourceSimulated := GVL_Simulation.SimulationModeActive AND …` | EXACT |
| M04 | `FB_AxisScale.st:29,36,43,49` | 4 affectations `OutPct := …` | EXACT |
| M05 | `FB_Joystick.st:185` | `AtNeutralXY := (ScaleX.OutPct = 0.0) AND (ScaleY.OutPct = 0.0);` | EXACT |
| M06 | `FB_Joystick.st:232,239,249` | `DeadmanArmed := TRUE` / `:= FALSE` / `NeutralHoldTimer` | EXACT |
| M07 / M08 | `FB_Joystick.st:259` / `:260` | `AxisCmdX.DirectionPositive` / `.DirectionNegative` | EXACT |
| M09 | `FB_Joystick.st:256,262` | `AxisCmdX.SpeedTgt := ABS(CmdXVal);` / `:= 0.0` | EXACT |
| M10 | `FB_Joystick.st:261` | `AxisCmdX.AtNeutral := NOT …DirectionPositive AND NOT …DirectionNegative;` | EXACT |
| M11 | `PRG_02_Acquisition.st:475` | `:475` = `// Repli du vidage : le geste inverse (Y+ apres Y-) doit atteindre l'etape de…`. La publication réelle est `Data.Joystick.AxisX := instJoystick.AxisCmdX;` en **`:491`** | **DECALE +16** |
| M12 | `ST_TranslationCmd.st:12` · `PRG_05_Translation.st:354` | `BtnTremie : BOOL;` · `ArbM3_IHM.BtnTremie := SEL(…, GVL_IHM.M3Translation.Cmd.BtnTremie, …)` | EXACT |
| M14 | `ST_TranslationCmd.st:10` · `PRG_05:356` · `FB_TranslationCmdArbitrationM3.st:86` | `SelPositioning : BOOL;` · `ArbM3_IHM.SelPositioning := …` · `PositioningActive := IHM.SelPositioning;` | EXACT |
| M15 | `ST_TranslationCmd.st:14` · `GVL_PERSISTENT.st:98` · arbiter `:108-110` | `SetFreq_Hz : REAL;` · `_TranslationSetFreq_Hz : REAL := 40.0` · `FreqPct := SEL(…)` | EXACT |
| M16 | `ST_TranslationCmd.st:16` · `PRG_05:546` · `FB_Translation.st:292-295` | `InvertDirection : BOOL;` · `InvertDriveDirection := …` · `IF InvertDriveDirection THEN …` | EXACT |
| M19 | `PRG_05:134-138` · arbiter `:72,105` | `M3_HeightInterlockOk := GVL_IHM.M3Translation.Bypass.MinHeight OR (…EncoderM1/EncoderM2…)` · `Context.HeightInterlockOk` | EXACT |
| M21 | `PRG_05:366` | `Auth           := PRG_03_Modes_Cycle.Data.Auth,` | EXACT |
| M26 | arbiter `:87` · `PRG_05:408` | `SelTarget := 0;` (branche MAINT) · `CASE SelTarget OF` | EXACT |
| M27 | `PRG_05:373` | `M3_PositioningActive := instArbM3.PositioningActive;` | EXACT |
| M29 | `PRG_05:376` · `:650` | `M3_ReqTremie_Active := instArbM3.ReqTremie;` · `…ReqTremieSemantic := M3_ReqTremie_Active;` | EXACT |
| M34 | `PRG_05:479-481` · `:510,514` | `M3_SafeStop_Aggregate := M3_SafeStop_Active OR instSafetyTranslationM3.SafeStop …` · `AND NOT M3_SafeStop_Aggregate` | EXACT |
| M35 | `FB_Translation_PositionDecoder.st:71-76` | `SensorsWord := 0;` + 5 `OR 16#…` | EXACT |
| M36 / M37 / M38 | decoder `:113` / `:116` / `:117` | `TranslationAtTremie := EdgeUpTremie.Q;` / `…AtP1 := EdgeUpP1.Q OR EdgeDnP1.Q;` / `…AtMaintenance := EdgeDnMaintenance.Q;` | EXACT |
| M39 | `PRG_05:266` · `:245` · `:277` | `M3_AtTremieStable := TRUE;` · restauration boot `2#11111` · RAZ sur `M3_SensorsWordChanged` | EXACT |
| M40 | `PRG_05:272` · `:254` · `:277` | `M3_AtP1Stable := TRUE;` · restauration boot `2#00011` · RAZ | EXACT |
| M42 | `PRG_05:212` · `:275-277` | `M3_SensorsWordChanged := (instPosDecoderM3.SensorsWord <> M3_SensorsWordPrev);` · branche `ELSIF … M3_SensorsWordChanged` | EXACT |
| M43 | `PRG_05:163` · `:165` · `:458` | `M3_LimitSwitchTremieStable := TRUE;` · `ELSIF M3_ReqMaintenance_Active THEN … := FALSE` · `LimitSwitchTremie := …` | EXACT |
| M45 | `PRG_05:152-154` · `:186` | `M3_LimitSwitchMaintenanceEffective := SEL(…, NOT …TranslationPosP1 AND …TranslationPosMaintenance, …LimitSwitchMaintenance);` · `IF M3_LimitSwitchMaintenanceEffective THEN` | EXACT |
| M47 | `PRG_05:529-535` · `:568` · `ST_TranslationCfg.st:9-11` | assemblage `TranslationCfg.*` · `Cfg := TranslationCfg,` · `CfgApproachSpeedTremie_Hz/Maintenance_Hz/P1_Hz := 10.0` | EXACT |
| M48 | `FB_Translation.st:175-177` · `ST_fbTranslation_Cfg.st:31` | `CaptorDebounceTon(IN := PositionSensorTarget, PT := Cfg.CaptorDebounce);` / `TargetReached := …Q;` / `ArrivalEdge(CLK := TargetReached);` · `CaptorDebounce : TIME := T#100ms;` | EXACT |
| M49 | `FB_Translation.st:180` · `:192,196` · `:202-204` | `ArrivalLock := TRUE;` (front) · FdC (`CommandedTremie AND LimitSwitchTremie`) · relâche sur sens inverse | EXACT |
| M53 | `FB_Translation.st:244-247` · `:251` · `:260` | `EffectiveSafeStop := SafeStop OR (ReqTremie AND NOT EffectivePermitM3_Tremie) OR …` · gate de rampe · `DecelRate := SEL(EffectiveSafeStop, …)` | EXACT |
| M54 | `FB_Translation.st:297-303` | `IF PhysicalTremie AND Brake.BrakeCmd THEN RequestedDriveControlWord := 1; ELSIF … := 2; ELSE := 0;` | EXACT |
| M55 | `FB_Translation.st:305` · `:308-313` | `RequestedDriveFreqHz := (SpeedRamp.Current / 100.0) * Cfg.DriveFreqScaleMaxHz;` · 3 ralentissements d'approche | EXACT |
| M56 | `FB_Translation.st:286` · `PRG_05:646` | `BrakeReleaseRequest := Brake.BrakeCmd;` · `…BrakeReleaseRequest := instTranslationM3.BrakeReleaseRequest;` — **mais** le consommateur `PRG_05:453-454` (safety, scan N-1) est omis → trou 🟠 n°10 | EXACT (partiel) |
| M57 | `FB_Translation.st:123-127` | `OverrunLimitSwitch := NOT BypassLimitSwitch AND (…) AND (ABS(DriveActualFreqHz) > 0.5);` + TON `T#1S500MS` + `instCauses[6].Active` | EXACT |
| M59 | `PRG_06:431-432` · `:443,445,448` | `M3_TremieHardStopActive := …M3_PosTremie_DI AND …ReqTremieSemantic;` · `AND NOT M3_TremieHardStopActive` / `SEL(M3_TremieHardStopActive, …, WORD#0)` | EXACT |
| M60 | `FB_TranslationOutputInterlock.st:137` · `:146-154` · `:154` | `BrakeCmd := BrakeReleaseRequest AND NOT Fault.Error AND NOT RestartInhibit;` · décision finale · `DriveFreqCmdWord := REAL_TO_WORD(…)` | EXACT |
| M61 | `PRG_06:458` · CSV `:190` · `%QW6` | `M3_CommandWord := instTranslationOutputInterlockM3.DriveControlWord;` · `M3_CommandWord;0x3101 Command;;;%QW6;AC600_ECAT_Drive` | EXACT |
| M61 | `PRG_07_Supervision.st:526` (miroir IHM) | Le miroir `GVL_IHM.IoHw.Out.M3_CommandWord := M3_CommandWord;` est en **`:576`** | **DECALE +50** |
| M61 | `PRG_02_Acquisition.st:311-312` (relecture banc) | `M3_ReqTremie := M3_CommandWord = 1,` / `M3_ReqMaintenance := M3_CommandWord = 2,` réels en **`:316-317`** | **DECALE +5** |
| M62 | `PRG_06:459` · CSV `:207` | `M3_SetpointFrequencyHz := …DriveFreqCmdWord;` · `…;0x3100 Frequency;;;%QW7;…` | EXACT |
| M62 | `PRG_02_Acquisition.st:314` (relecture banc) | `(WORD_TO_UINT(M3_SetpointFrequencyHz) / 100.0)` réel en **`:319`** (dans `M3_SpeedCmd_Pct := LIMIT(0.0,` ouvert en `:318`) | **DECALE +5** |
| M62 | `PRG_07_Supervision.st:527` | Miroir réel en **`:577`** | **DECALE +50** |
| M63 | `PRG_06:457` · CSV `:480` · `%QX27.2` | `M3_BrakeRelease_RQ := TranslationBrakeCmd;` · `M3_BrakeRelease_RQ;Bit2;;;%QX27.2;VH_0008ER` | EXACT |
| M63 | `PRG_07_Supervision.st:515` | Miroir réel en **`:565`** | **DECALE +50** |
| M64 | CSV `:471` · `PRG_05:453` · `:569` | `M3_BrakeIsOpen_DI;Bit2;;;%IX225.2;VH_0800END` · `BrakeFeedback := SEL(…Bypass…, …M3_BrakeIsOpen_DI, …)` (×2) | EXACT |
| M65 | CSV `:241` · `PRG_02:177` · `PRG_05:567` | `M3_ActualFrequencyHz;C00.01 Output Frequency;;;%IW9;…` · `HwReal.Translation.M3_ActualFrequencyHz := M3_ActualFrequencyHz;` · `DriveActualFreqHz := UINT_TO_REAL(…ActualFrequencyHz) / 100.0,` | EXACT |
| M65 | `PRG_02_Acquisition.st:688` (projection) | `Data.M3.ActualFrequencyHz := HwIn.Translation.M3_ActualFrequencyHz;` est en **`:708`** | **DECALE +20** |
| M66 | CSV `:224` · `PRG_05:566` | `M3_StatusWord;0x3102 Drive Status;;;%IW8;…` · `DriveStatusWord := PRG_02_Acquisition.Data.M3.StatusWord,` | EXACT |

### 2.2 Chaîne CYCLE AUTO (C01→C35) et affirmations de chaîne

| Réf. T334 | Ligne citée par T334 | Contenu réel sur disque (blobs du §1.3, ancrage final `2026-09-21T01:31:44`) | Verdict |
|---|---|---|---|
| C01 | `PRG_03:206` | `StartCycle := GVL_IHM.CycleSemiAuto.Cmd.BtnStart,` | EXACT |
| C02 / C03 | `PRG_03:201` / `:203` | `JoystickRight := …AxisX.DirectionNegative,` / `JoystickLeft := …AxisX.DirectionPositive,` | EXACT |
| C02 / C03 / C04 / C05 / C06 | `PRG_02:475` / `:478` / `:477` / `:476` | `Data.Joystick.AxisX := …` réel **`:491`** ; `AxisY` réel **`:492`** ; `DeadmanArmed` réel **`:493`** ; `AtNeutralXY` réel **`:494`** | **DECALE +16** (×4) |
| C04 | `PRG_03:196` | `JoystickDeflected := NOT PRG_02_Acquisition.Data.Joystick.AtNeutralXY,` | EXACT |
| C05 | `PRG_03:204` | `DeadmanArmed := PRG_02_Acquisition.Data.Joystick.DeadmanArmed,` | EXACT |
| C06 | `PRG_03:197-198` | `JoystickPush := …AxisY.DirectionNegative,` / `JoystickPull := …DirectionPositive,` | EXACT |
| C07 | `FB_Modes.st:413` | `Auth.MaintenanceM3TargetEnable := ((Auth.Mode = E_Mode.MAINT_N2) OR (Auth.Mode = E_Mode.MAINT_N1)) AND SelMaintenanceZoneAccess;` | EXACT |
| C07 | `PRG_03:278` (publication `Auth`) | `:278` = commentaire « Réarmement AU : contacteur puissance réengagé… ». La publication réelle est `Data.Auth := instModes.Auth;` en **`:291`** | **DECALE +13** |
| C07 | `PRG_03:191,195` | `Enable := (instModes.Auth.Mode = E_Mode.SEMI_AUTO),` / `Mode := instModes.Auth.Mode,` | EXACT |
| C08 | `PRG_05:820` | `Data.M3_AtP1Stable := M3_AtP1Stable;` | EXACT |
| C08 | `PRG_03:234` | `Translation_At_P1 := PRG_05_Translation.Data.M3_AtP1Stable,` est en **`:237`** | **DECALE +3** |
| C09 | `PRG_05:819` | `Data.M3_AtTremieStable := M3_AtTremieStable;` | EXACT |
| C09 | `PRG_03:235` | Identique, réel **`:238`** | **DECALE +3** |
| C11 | `PRG_03:239` | `Translation_Busy := PRG_05_Translation.Data.TranslationBusy,` réel **`:242`** | **DECALE +3** |
| C12 | CSV `:454` | `M3_PosP1_DI;Bit3;;;%IX224.3;VH_0808ETP` | EXACT |
| C12 / C13 | `PRG_03:237` / `:238` | `Translation_PosP1/P maintenance` réels **`:240`** / **`:241`** | **DECALE +3** |
| C14 / C15 / C16 | `FB_CycleSemiAuto.st:715` / `:716` / `:717` | `CycleMotionPermit := …` réel **`:780`** ; `TranslationP1Permit := …` réel **`:781`** ; `TranslationTremiePermit := …` réel **`:782`** | **DECALE +65** |
| C17 | `FB_CycleSemiAuto.st:334-338` | `TranslationStopTimer(IN := ((State = AX2) AND Translation_At_P1) OR ((State = AX14) AND Translation_At_Tremie)) AND NOT Translation_Busy, PT := CST_TranslationStopConfirmTime);` réel **`:354-358`** | **DECALE +20** |
| C18 | `FB_CycleSemiAuto.st:899` · `:913` | AX2 : `TranslationCmd.ReqStart := FALSE; TranslationCmd.PositionTgt := 3;` réel **`:964-965`** · `TranslationCmd.ReqStart := TranslationTremiePermit OR TranslationP1Permit;` réel **`:978`** | **DECALE +65** |
| C19 | `FB_CycleSemiAuto.st:887` · `:900` · `:912` | `TranslationCmd.PositionTgt := 3;` réels **`:952`** / **`:965`** / **`:977`** | **DECALE +65** |
| C20 | `FB_CycleSemiAuto.st:1383` · `:1386` | `TranslationCmd.ReqStart := TranslationTremiePermit;` réel **`:1452`** · `…ReqStart := FALSE;` réel **`:1455`** | **DECALE +69** |
| C21 | `FB_CycleSemiAuto.st:1382` · `:1387` | `TranslationCmd.PositionTgt := 1; // Trémie` réel **`:1451`** · `…PositionTgt := 0;` réel **`:1456`** | **DECALE +69** |
| C22 | `PRG_03:314` | `Data.ReqProgram.ReqTranslation := instCycleSemiAuto.TranslationCmd;` réel **`:327`** | **DECALE +13** |
| C22 | `PRG_03:392-393` · `:483-484` (neutralisations) | Réelles **`:407-408`** (branche MAINT) et **`:500-501`** (branche DISABLE). `:483-484` porte `…WinchDescentAuth_M3 … AtP1 / AtMaintenance` — **sans rapport** | **DECALE +15 / +17** |
| C24 | arbiter `:65` | `SelTarget := ReqTranslation.PositionTgt;` | EXACT |
| C27 | arbiter `:74` · `GVL_PERSISTENT.st:97` | `SpeedPct := 100.0;` · `_TranslationAutoSpeedCap_Pct : REAL := 40.0;` | EXACT |
| C28 | `PRG_05:385-387` | `M3_CycleTranslationStepAuthorized := (…AX2_TRANSLATE_P1) OR (…AX14_TRANSLATE_DUMP);` | EXACT |
| C29 | `PRG_05:391-394` | 4 neutralisations sous veto SEMI_AUTO | EXACT |
| C31 | `PRG_05:408-429` | `CASE SelTarget OF … END_CASE;` | EXACT |
| C32 | `PRG_03:209` | `SelTarget := GVL_IHM.M3Translation.Cmd.SelTarget,` | EXACT |
| C33 | `PRG_03:330` | `Data.SequenceState.Step := instCycleSemiAuto.CycleStep;` réel **`:343`** | **DECALE +13** |
| C34 | `PRG_03:398` | `DumpAtTremieBucketOpenArmed := DumpAtTremieAssistActive AND PRG_05_Translation.Data.M3_AtTremieStable;` réel **`:413`** | **DECALE +15** |
| §6.1 | `PRG_05:27` · `:363-372` · `:439-472` · `:537-572` · `PRG_06:434-451` · `:457-459` | Instances et appels **uniques** (grep) ; `instTranslationOutputInterlockM3(` unique à `:434` ; mots variateur `:457-459` | EXACT (+ unicité prouvée) |
| §6.5 | `FB_Translation_PositionDecoder.st:94-98` | `TranslationPosTremie/PV/P2/P1/Maintenance := Sensor…` | EXACT |
| §10bis B.2 | `FB_TranslationOutputInterlock.st:84` · `:133-151` · `:154` | `MovementRequested := (RequestedDriveControlWord = 1) OR (… = 2);` · décision finale · mise à l'échelle | EXACT |
| §10bis B.4 / B.5 | `ST_fbTranslation_Cfg.st:34` · `:35` | `BrakeDelayMotorDecel : TIME := T#2s;` · `BrakeFeedbackTimeout : TIME := T#800ms;` | EXACT |
| H6 | `FB_Safety_Translation.st:200-203` · `:268` | `OverrunCondition := (LimitSwitchTremie AND ReqTremie AND (ABS(DriveActualFreqHz) > 0.5 OR DriveStatusWord.0)) OR …` + TON `T#1S500MS` + `instCauses[6]` · `PowerCutOff := (Fault.ErrorId AND 16#00F8) <> 16#0000;` | EXACT |
| A03 | `PRG_05:80` · `:201` | `TonM3ConfirmedMoving(IN := M3_ConfirmedMoving, PT := T#1s500ms);` (et `.Q` jamais lu) | EXACT |
| A06 / D09 / §7.1 | `PRG_05:571` · `ST_BypassTranslation.st:4-5` | `BypassLimitSwitch := GVL_IHM.M3Translation.Bypass.Global OR GVL_IHM.M3Translation.Bypass.LimitSwitch` · « Doctrine : actionnable UNIQUEMENT en MAINT_N2, RETAIN » | EXACT |
| A06 / D09 / §7.1 / H2 | `PRG_07_Supervision.st:230-235` (restauration boot) | `:230-235` **ne contient aucune restauration de bypass**. La restauration Translation réelle est `IF NOT GVL_IHM.M3Translation.Bypass.Initialized THEN … GVL_IHM.M3Translation.Bypass.Global := TRUE;` en **`:280-284`** | **FAUX** |
| §11 (arbitrage) | « corrigé → `:331-341` / `:336-346` (bloc Translation :341-346) » | `:336-339` = `IF NOT GVL_IHM.Network.Bypass.Initialized THEN … BypassNetworkGlobal` (**réseau**, pas Translation) ; `:341-346` = bloc *sync bidirectionnel* `instMirrorBypass*`. Valeur réelle : **`:280-284`** | **FAUX** |
| §3 / A08 / §10bis B.6 | `FB_CycleSemiAuto.st:1534-1545` / `:1549-1557` | La branche de récupération « chariot au-delà de P1 » est `ELSIF Translation_PosMaintenance AND NOT Translation_PosP1 THEN` en **`:1616`**, ses commentaires en **`:1617-1620`**, le message « AX2 - M3 au-dela de P1 : pousser vers la tremie (gauche) pour retrouver P1. » en **`:1625`**, et `PositionTgt := 1` / `ReqStart := TranslationTremiePermit` en **`:1626-1627`** | **DECALE +68 à +91** |
| C17 (constante) | `FB_CycleSemiAuto.st:246` (`PT = 500 ms`) | Non localisée : la constante est `CST_TranslationStopConfirmTime` (déclarée `:238-251`, valeur non relue) | **NON VERIFIABLE** |
| C01 | `FB_CycleSemiAuto.st:818,727,1510` · C07 `:423,560` | Numéros de l'ancienne révision ; contenu non relu ligne à ligne (fichier déplacé de +20 à +91) | **NON VERIFIABLE** |
| §10bis B.1 | `FB_CycleSemiAuto.st:284-288,289,259,968,160,279,262,300` | Contenus confirmés **ailleurs** : `DiveStartStopped` **`:301-305`**, `DiveStartStopTimer` **`:306`**, `CST_DiveStartStopTimeout` **`:277`**, `DiveStartTimeoutTimer(IN := FALSE…)` **`:317`**, `JoyDeflectedEdge` **`:168,294`** | **DECALE +13 à +17** |

### 2.3 Décompte de l'échantillon

Unité = **ligne du tableau de contre-vérification §2.1/§2.2** (certaines lignes regroupent plusieurs couples `fichier:ligne` : c'est signalé « ×N »).

| Verdict | Lignes de tableau | Détail |
|---|---|---|
| **EXACT** | **65** | Bas de chaîne (décodeur, `FB_Translation`, arbitre, barrière, `PRG_06`), DUT et déclarations IHM, CSV / `%Q`, garde-fous (`GVL_PERSISTENT`, `FB_Safety_Translation`, `ST_fbTranslation_Cfg`) |
| **DECALE** | **27** | `FB_CycleSemiAuto.st` **+20 à +91** (10 lignes) · `PRG_03_Modes_Cycle.st` **+3 à +17** (8 lignes) · `PRG_02_Acquisition.st` **+5 à +20** (9 lignes) · `PRG_07_Supervision.st` **+50** (3 lignes) — *tous les décalages sont **mesurés** par appariement contenu ↔ ligne, jamais déduits* |
| **FAUX** | **2** | Les deux affirmations de la restauration boot des bypass (`:230-235` et `:331-341`/`:336-346`) : la réalité disque est **`:280-284`** |
| **NON VERIFIABLE** | **2** | Constantes et numéros de l'ancienne révision de `FB_CycleSemiAuto.st` (voir §6, N2/N3) |
| **Total** | **96 lignes de tableau** | 52 pour la chaîne MANUELLE (§2.1) + 44 pour la chaîne CYCLE et les affirmations de chaîne (§2.2) |
| **Couples `fichier:ligne` périmés, corrigés un par un** | **49** | repris dans la table de correction prête à appliquer (§4.10) |

Répartition respectée entre les 2 chaînes, avec priorité aux points durs exigés : `FB_Translation` `ArrivalLock`, les 3 vitesses d'approche, `FB_TranslationOutputInterlock`, les mots variateur `PRG_06`, les 2 FdC, `M3_AtP1Stable`/`AtTremieStable`, la barrière SEMI_AUTO.

> ✅ **Honnêteté du constat** : ces décalages ne prouvent **pas** que T334 était faux le jour où il a été écrit. Ils prouvent que **T334 est faux aujourd'hui**, parce qu'aucune révision n'a été figée (trou 🔴 n°1). Les numéros cités étaient peut-être exacts au 2026-09-20 18:07 — et l'annexe ne prétend pas le contraire (§6, N1).

---

## 3. 🔴🟠🟡 TROUS RELEVÉS, par gravité, chacun avec sa preuve

Rappel de méthode : *preuve d'un trou = (1) la phrase du référentiel qui l'exige **et** (2) le constat que T334 ne la satisfait pas*, le plus souvent par grep à 0 occurrence.

### 🔴 n°1 — Aucun bloc d'ancrage de révision (grille g)

| | |
|---|---|
| **Ce qui manque** | Un bloc donnant `HEAD` + **blob SHA** (`git hash-object`) de la fiche et de chaque fichier `CODE/` cité + horodatage ISO, comme l'exige AC2 transposé : « *Chaque référence fichier:ligne citée dans le livrable est reelle a l'etat disque ancre par le lot, et non un numero derive de HEAD ni d'une memoire : le livrable porte en tete un bloc d'ancrage donnant le commit HEAD et le blob SHA (git hash-object) de chaque fichier de CODE/ cite, avec horodatage ISO* ». Exigence reprise par `TASK_CONTRACT_T351_CARTOGRAPHIE_TREUILS.yaml:35-36`. |
| **Preuve du trou** | grep sur les 789 lignes de T334 : `hash-object` → **0 occurrence** ; `blob` → **0 occurrence**. Le seul hash présent est `git rev-parse HEAD = fd12dc0` (§10bis ligne 578 et §H ligne 754) — hash **d'une session de challenge postérieure**, sans blob, **périmé** (`HEAD` = `d6e54377`). L'en-tête de la fiche ne porte qu'une date, pas de révision. |
| **Preuve de l'impact (déjà matérialisé)** | La **même** vérité « restauration boot des bypass » porte **trois valeurs contradictoires** dans la fiche : `:230-235` (A06, D09, §7.1 — corp), `:331-341` (§10bis F), `:336-346` (§11). **Aucune** ne correspond au disque (`:280-284`) — voir §2.2. Et §11 tableau « Corrections exigées §F » déclare lui-même ce point **« 🟡 non levé »** (« *Re-référencer la fiche sur une révision figée — `FB_CycleSemiAuto.st` toujours modifié non commité (T331) ; … à figer avant tout diff de `CODE/`* »), ce qui confirme que le risque était **connu et non traité**. |
| **Coût lecteur** | Il suit une référence, ouvre une ligne sans rapport, et conclut à tort qu'un mécanisme n'existe pas. Sur une fiche de diagnostic de sécurité, c'est le pire mode de défaillance : **silencieux**. |
| **Référentiel** | AC2 (transposé), §5 du brief (« même gabarit, même exhaustivité ») ; §10bis A.0 de T334 lui-même |
| **Démonstration en direct (ajout 2026-09-21)** | Ce trou n'est plus une hypothèse : pendant **cet** audit, `PRG_02_Acquisition.st` a porté **trois états en huit minutes** et `HEAD` a bougé (`d6e54377` → `065591fb`). **L'orchestrateur lui-même** a produit une critique `±1` en comparant deux états différents, puis l'a **rétractée** après re-mesure. Voir l'encadré **🪨 LEÇON** au §1.3 : *un numéro de ligne n'a de sens qu'accompagné du blob du fichier*. |

### 🔴 n°2 — Références `FB_CycleSemiAuto.st` périmées de +20 à +91 (toute la chaîne cycle)

| | |
|---|---|
| **Ce qui manque** | La remise à jour de **toutes** les références du bloc cycle (`C14`→`C21`, `C01`, `C07`, §3, A08, §10bis B.1/B.6) sur l'état disque. |
| **Preuve du trou (mesurée, motif ↔ ligne)** | `CycleMotionPermit` : cité `:715` → réel **`:780`**. `TranslationP1Permit` : `:716` → **`:781`**. `TranslationTremiePermit` : `:717` → **`:782`**. `TranslationStopTimer` : `:334-338` → **`:354-358`**. AX2 `ReqStart := FALSE` : `:899` → **`:964`** ; `ReqStart := TranslationTremiePermit OR TranslationP1Permit` : `:913` → **`:978`**. AX14 `ReqStart` : `:1383` → **`:1452`**. AX14 `PositionTgt := 0` : `:1387` → **`:1456`**. Branche de récupération P1 : `:1534-1545` → **`:1625`**. Fichier aujourd'hui `032af59fc1fa` (1652 l) — *tous ces décalages viennent de l'**appariement contenu ↔ ligne**, pas d'un comptage de lignes* (§6-N11). |
| **Preuve du référentiel** | AC2 transposé (« référence réelle à l'état disque ancré par le lot ») + AC11 (« toute chaine jugee incomplete est declaree incomplete »). |
| **Point le plus coûteux** | `C18`/`C20`/`C21` portent **l'argument central du diagnostic** (le cycle retire sa demande et remet `PositionTgt := 0` à la Trémie) : ce sont exactement les lignes que la phase 2 veut corriger. Un lot de correction lancé sur ces numéros écrirait ailleurs. |
| **Honnêteté** | Le §10bis A.0 avait **déjà** détecté un décalage de **+4** et exigé un re-référencement ; il est aujourd'hui de **+65/+69** : la fiche a empiré **après** le challenge, sans que le re-référencement soit fait. |

### 🔴 n°3 — Permis directionnels `EffectivePermitM3_*` non tracés jusqu'à leurs producteurs

| | |
|---|---|
| **Ce qui manque** | Les producteurs de `EffectivePermitM3_Tremie` / `EffectivePermitM3_Maintenance` (`PRG_05_Translation.st:509-515`) et les deux grandeurs qu'ils consomment et qui **n'apparaissent nulle part** dans T334 : `instSafetyTranslationM3.TremieLimitClear` / `.MaintenanceLimitClear`, et surtout **`M3_TremieProcessBlock`** (`:176-181`, 200 ms, sur `HwIn.Machine.TremieFull_OR_GateRaised_DI`), consommé en `:512`. |
| **Preuve du trou** | grep sur les 789 lignes de T334 : `TremieProcessBlock` → **0 occurrence** ; `TremieLimitClear` → **0** ; `MaintenanceLimitClear` → **0**. T334 (M58) ne cite les champs `EffectivePermitM3_*` que comme **champs du bus** final (`:639-651`), jamais comme **valeurs produites** en `:509-515`. |
| **Pourquoi c'est un trou** | AC1 transposé exige « une ligne par variable » de la source jusqu'au contacteur. Ces permis traversent la chaîne **jusqu'au mot de commande** : `EffectivePermitM3_Tremie/Maintenance` → `PermitFinalBlocked` (`FB_TranslationOutputInterlock.st:85-86`) → `DriveControlWord` (`:146-150`). Un diagnostic « M3 ne démarre pas vers la Trémie » ne peut pas aboutir sans eux. |
| **Aggravant (devoir d'alerte)** | Le commentaire du code porte une **incertitude de sécurité non résolue** : `PRG_05_Translation.st:175` — « ⚠️ **Signal PAS ENCORE CÂBLÉ** (ST_HwMachine) : polarité TRUE = bloqué à **CONFIRMER au câblage** ». Une chaîne de diagnostic exhaustive **doit** déclarer ce point ; T334 ne le mentionne pas. |

### 🟠 n°4 — Références `PRG_03_Modes_Cycle.st` périmées (+3 à +17, 8 points)

**Ce qui manque** : `C07` (`:278`→**`:291`**), `C08` (`:234`→**`:237`**), `C09` (`:235`→**`:238`**), `C10` (`:236`→**`:239`**), `C11` (`:239`→**`:242`**), `C12` (`:237`→**`:240`**), `C13` (`:238`→**`:241`**), `C22` (`:314`→**`:327`** ; `:392-393`→**`:407-408`** ; `:483-484`→**`:500-501`**), `C33` (`:330`→**`:343`**), `C34` (`:398`→**`:413`**).
**Preuve** : appariement contenu ↔ ligne (§2.2) ; les références AX2/C01-C06 de la même section **restent exactes** (`:196-209`), ce qui **localise** l'insertion entre 209 et 234 — le reste du fichier a été complété sans que la fiche soit reprise.
**Aggravant** : `C22` est la ligne du **bus de demande cycle → translation**, le maillon que le diagnostic « pourquoi le cycle redemande » doit lire en premier ; ses 3 valeurs sont fausses.

### 🟠 n°5 — Références `PRG_02_Acquisition.st` périmées (+6 à +15, 7 points)

**Ce qui manque** : `M01` consommateur (`:465`→**`:481`**), `M03` (`:434`→**`:445`**), `M11` (`:475`→**`:491`**), `C02/C03` (`:475`→**`:491`**), `C04` (`:478`→**`:494`**), `C05` (`:477`→**`:493`**), `C06` (`:476`→**`:492`**), `M61` relecture banc (`:311-312`→**`:316-317`**), `M62` relecture banc (`:314`→**`:319`**), `M65` projection (`:688`→**`:708`**).
**Preuve** : le bloc `:301-320` (relecture banc M3) est décalé de **+5** ; le bloc `:455-495` (frontière joystick) de **+16** — l'insertion est comprise entre 320 et 455.
⚠️ **Mesure prise TROIS fois, sur trois états disque différents** : écart **+6 à +15** à `01:23:34` (blob `fabb8f764dd8`, 714 l, **propre**) → **+12 à +21** à `01:28:50` (blob `892de7b784f5`, 720 l) → **+5 à +20** à `01:31:44` (blob **`5b8baa9ba8ea`**, **719 l**) — les valeurs ci-dessus sont celles **relues ligne à ligne** sur ce dernier blob (aucun calcul). Ce fichier a été édité **deux fois** par un lot concurrent **pendant l'audit** (cf. §5-A07).
**Coût lecteur** : `M01`/`M11`/`C02`-`C06` sont **le point de départ des deux chaînes** (le geste joystick) — c'est la première chose qu'un lecteur ouvre.

### 🟠 n°6 — Miroirs IHM `PRG_07_Supervision.st` périmés (+50) et constat A06/D09 **FAUX**

**Ce qui manque** : `M61` (`:526`→**`:576`**), `M62` (`:527`→**`:577`**), `M63` (`:515`→**`:565`**), `M15`/H3 (amorçage `:211,217`) et surtout **A06/D09/§7.1/H2** (`:230-235` → **`:280-284`**).
**Preuve** : §2.2 ; `PRG_07_Supervision.st` est **SALE** et a **encore bougé pendant l'audit** : blob `d3449a6a85ad` à `01:23:34` → **`c10f004151f8`** à `01:28:50` (le fichier a perdu 1 ligne, d'où **+50** et non +51). C'est précisément le fichier dont T334 avait déjà signalé la référence fausse (`:230-235` « pointe la logique T330 TOP/FdC, sans rapport ») sans corriger le corps de la fiche. La restauration boot réelle (`:280-284`) est **stable** sur les deux blobs.
**Coût lecteur** : le constat de sécurité le plus fort de T334 (bypass restauré au boot, non filtré par le mode) repose sur une référence **qui n'existe pas**.

### 🟠 n°7 — `TglMaintenanceZoneAccess` / `SelMaintenanceZoneAccess` jamais nommés

**Preuve du trou** : grep sur les 789 lignes de T334 : `TglMaintenanceZoneAccess` → **0 occurrence**, `SelMaintenanceZoneAccess` → **0**, `ZoneAccess` → **0**.
**Preuve que ça compte** : `Auth.MaintenanceM3TargetEnable := ((Mode = MAINT_N2) OR (Mode = MAINT_N1)) AND SelMaintenanceZoneAccess;` (`FB_Modes.st:413`, entrée `SelMaintenanceZoneAccess` déclarée `:31`, alimentée par l'IHM `ST_TranslationCmd.st:17`). Cette valeur décide **où M3 s'arrête** (`PRG_05:421-424` : Maintenance **ou** P1) et **quelle vitesse d'approche s'applique** (`PRG_05:559-560`). T334 (M45, M46, C07) n'expose que `MaintenanceM3TargetEnable`, jamais le toggle qui le compose.
**Référentiel** : AC4/A transposé (« 4 familles de sources … dont **boutons IHM**, avec fichier:ligne »).

### 🟠 n°8 — Étages d'entrée physiques absents : aucune adresse `%IX` dans T334

**Preuve du trou** : grep sur les 789 lignes de T334 : occurrences de `%QW`/`%QX` → présentes (M61-M63, §9-E) ; occurrences de `%IX` → **0** ; occurrences de `%IW` → **1** (M01, `%IW114`).
**Constats disque** : les 5 capteurs de position M3 sont `M3_PosTremie_DI %IX224.0` (CSV `:451`), `M3_PosP1_DI %IX224.3` (`:454`), `M3_PosMaintenance_DI %IX224.4` (`:455`), `M3_BrakeIsOpen_DI %IX225.2` (`:471`), plus PV/P2 (bloc CSV `:448-455`). T334 ne cite le CSV que pour **P1 et Maintenance** (C12/C13) et ne nomme les autres canaux qu'en **noms symboliques** dans §9-C — **sans adresse**.
**Pourquoi c'est un trou** : AC1/§9 de la fiche frère exigent la chaîne jusqu'à la sortie physique **et** le mapping E/S. Le bas de chaîne est couvert (`%Q`), le **haut** ne l'est pas : le producteur physique du mot thermomètre (`instPosDecoderM3.SensorsWord`) n'est tracé nulle part dans les chaînes M/C.

### 🟠 n°9 — FB traversés incomplets (§6.4) : la frontière codeur du gate de hauteur est omise

**Preuve du trou** : §6.4 (« FB traversés en plus / en moins ») liste 10 FB ; grep sur T334 : `EncoderM1` → **1 occurrence**, uniquement en §9bis C.2 (chaîne **treuils AX12**, pas M3). `FB_Encoder`, `FB_Encoder_Safety`, `FB_AxisScale`, `FB_FaultCore` → **0 occurrence** dans la section 6.4.
**Preuve que ça compte** : `M3_HeightInterlockOk` (`PRG_05:134-138`), qui est une **condition de `RunRequest`** dans l'arbitre (`:72`, `:105`), dépend de `PRG_02_Acquisition.Data.EncoderM1/EncoderM2.HomedAndReliable` et `.Measurement.CablePosM` ≥ `GVL_PERSISTENT._TranslationMinHeightM1M2_M`. Un lecteur qui voit `TranslationState.HeightInterlockBlocking = TRUE` n'a, avec T334 seul, **aucun chemin** vers le codeur.
**Référentiel** : AC3/AC7 transposés (tracer le FB réellement traversé et la coupure de permis à sa ligne).

### 🟠 n°10 — Arête de scan manquante : la safety M3 lit l'axe **du scan précédent**

**Preuve du trou** : T334 M56 donne `instTranslationM3.BrakeReleaseRequest` : producteur `FB_Translation.st:286` → consommateur `PRG_05:646` → `PRG_06:442-443`. Or le **premier** consommateur dans le scan est `PRG_05_Translation.st:454` (`BrakeCmd := instTranslationM3.BrakeReleaseRequest,`) dans l'appel safety `:439`, **exécuté avant** l'appel de l'axe `:537` — le code le dit lui-même (`:435-438` : « la safety lit ici … du **SCAN PRÉCÉDENT** d'instTranslationM3 »). grep sur T334 : `instTranslationM3.BrakeReleaseRequest` apparaît **1 fois** (M56), `scan précédent` **1 fois** (ligne 629, à propos du cycle↔PRG_05, pas de cette arête).
**Pourquoi c'est un trou** : sur une fiche de diagnostic de défaut frein (T287), le **délai d'un scan** entre la commande et la safety est un maillon décidable ; T334 le tait alors qu'il cite `:453` par ailleurs (M64) **pour une autre raison**.

### 🟡 n°11 — Renvoi interne cassé « cf. §8 D04 »

**Preuve** : M14 (« Positionneur IHM → `PositioningActive` (jamais consommé, **cf. §8 D04**) ») et M27 (« Variable morte (**§8 D04**) »). Le §8 de T334 est « 🌳 Arbre des causes — hypothèses H1→H6 » : il **ne contient aucun code D04**. Les items `Dxx` vivent en **§6.2**, et le constat de variable morte est **A02 en §10**.
**Coût** : renvoi mort dans le tableau que le lecteur suit en premier.

### 🟡 n°12 — Absence de branche `MAINT_N1`/`MAINT_N2` non **déclarée** (grille c)

**Preuve du constat** : pour la chaîne M3, `MAINT_N1` et `MAINT_N2` sont traités **ensemble** partout : `FB_TranslationCmdArbitrationM3.st:84` (`ELSIF (Mode = MAINT_N1) OR (Mode = MAINT_N2)`), `FB_Modes.st:413`, `PRG_03_Modes_Cycle.st:384`. grep : `E_Mode.MAINT_N1|E_Mode.MAINT_N2` → **0 occurrence** dans `PRG_05_Translation.st` et dans `FB_Translation.st` ; les seules distinctions N1/N2 du projet concernent les **treuils/homing/benne** (`FB_Modes.st:340,344`, `FB_CycleMachineHoming.st:394,833,853`, `FB_Bucket.st:350,360,392`).
**Le trou** : AC8 transposé exige « *si une branche n'existe pas, le livrable le dit explicitement plutôt que de l'omettre* ». T334 fusionne N1/N2 (ligne 64 : « Mode couvert : `MAINT_N1` / `MAINT_N2` ») **sans jamais déclarer** qu'aucune branche propre n'existe — un lecteur peut chercher indéfiniment une différence inexistante.

### 🟡 n°13 — Famille « actions de la benne » non déclarée comme non-source pour M3 (grille a)

**Preuve du constat (fait avéré)** : `Data.ReqProgram.ReqTranslation` a **un seul producteur** — `PRG_03_Modes_Cycle.st:327` (`:= instCycleSemiAuto.TranslationCmd`), plus 2 neutralisations (`:407-408`, `:500-501`) ; grep `ReqTranslation\.ReqStart :=|ReqTranslation\.PositionTgt :=` → **seulement** ces lignes. Côté séquenceur, `TranslationCmd.ReqStart` n'est armé que par `TranslationTremiePermit`/`TranslationP1Permit` (`:978`, `:1452`, `:1627`). **Aucune demande de translation M3 ne peut provenir de la benne / `PRG_04`.**
**Le trou** : T334 couvre la benne comme **veto d'étape** (C28/D06 : AX3/AX10/AX15) et comme **consommateur** de M3 (C34), mais ne **déclare pas** que la 3ᵉ famille du référentiel (actions de la benne) n'est **pas** une source de demande pour M3. Or c'est la question explicite de la grille (a).

### 3.9 Balayage de la grille a→g — synthèse

| Point | Verdict | Preuve / trou |
|---|---|---|
| **a)** 4 familles de sources | 🟡 **3 sur 4 explicites** | joystick M01-M11 ✔ ; boutons IHM M12-M17 ✔ ; **séquenceur** C01-C35 ✔ ; **benne** = non-source, non déclarée (🟡 n°13) + toggle IHM manquant (🟠 n°7) |
| **b)** point de sélection de source unique en aval | 🟢 **preuve complète, re-prouvée** | arbitre unique (`PRG_05:27`, appel `:363-372`), FB de mouvement unique (`:537`), barrière unique (`PRG_06:434`), mots variateur **à affectation unique** — MAIS les **permis** qui la nourrissent ne sont pas tracés jusqu'à leurs producteurs (🔴 n°3) et l'arête de scan safety manque (🟠 n°10) |
| **c)** branches MAINT | 🟡 **couverte, sans déclaration d'absence** | arbitre `:84-113` ✔ ; chemin court boutons IHM (M12/M13) ✔ ; tautologie `BypassGlobal` (M18, `:99-101`) ✔ ; bypass gating (D09/A06, `PRG_05:571`) ✔ ; **absence de branche N1/N2 non déclarée** (🟡 n°12) ; `TglMaintenanceZoneAccess` absent (🟠 n°7) ; 2 réfs FAUSSES sur la restauration boot (🟠 n°6) |
| **d)** matrice physique | 🟠 **bas OK, haut absent** | sorties `%QW6`/`%QW7`/`%QX27.2` + CSV **exacts** ✔ ; entrées : **0 adresse `%IX`** dans toute la fiche (🟠 n°8) |
| **e)** FB traversés | 🟠 **§6.4 existe mais incomplète** | 10 FB listés ✔ ; encodeurs / `FB_AxisScale` / `FB_FaultCore` absents (🟠 n°9) |
| **f)** section « trous et incertitudes » | 🟡 **substance présente, forme dispersée** | §0 (verdict des affirmations), §6 (« non prouvé sans trace »), §8 (« aucune cause racine n'est affirmée »), §11 (« NON PRONONCÉE »), §H.6 (limites de la trace), §10 (12 constats hors scope) — **aucune section dédiée** « trous/incertitudes », et surtout **aucune déclaration** que les références sont périmées (le seul signalement est §10bis A.0, ajouté après coup, et §11 le classe « non levé ») |
| **g)** ancrage de révision | 🔴 **ABSENT** | grep `hash-object` = 0, `blob` = 0 ; seul `fd12dc0` (§10bis) périmé vs `d6e54377` (🔴 n°1) |

### 3.10 Alignement de la grille d'audit sur la fiche frère (pour la fusion)

Le livrable frère `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md` (DSH16) **existait à `01:28`** : sa structure de sections a été relue (sans le modifier) et la grille a→g y est **mappée**, pour que l'orchestrateur puisse fusionner les deux documents sans renommer quoi que ce soit.

| Grille de cette annexe | Section du livrable frère (gabarit commun) |
|---|---|
| a) 4 familles de sources de demande | **§8 — LES 4 FAMILLES DE SOURCES DE DEMANDE D'UN TREUIL** |
| b) point de sélection de source unique en aval | **§5.1 — Où les deux chaînes CONVERGENT (preuve)** |
| c) branches MAINTENANCE (MAINT_N1/MAINT_N2) | **§7 — BRANCHES MAINTENANCE (MAINT_N1 / MAINT_N2)** |
| d) matrice physique / sortie physique | **§9 — SORTIE PHYSIQUE — contacteurs, relais, bobines frein** |
| e) FB traversés | **§5.4 — FB traversés en plus / en moins dans chaque chaîne** |
| f) trous et incertitudes | **§11 — Trous et incertitudes (critère AC11)** |
| g) ancrage de révision | **§1 — Contexte figé, périmètre et ANCRAGE DE RÉVISION**, sous-bloc **🔐 Bloc d'ancrage de révision (AC2)** |
| §4 de cette annexe (compléments prêts à fusionner) | **§12 — Annexe associée** (le frère pointe déjà cette annexe) |
| §5 de cette annexe (devoir d'alerte) | **§10 — Devoir d'alerte — constats hors scope** |
| §7 de cette annexe (journal) | **§13 — Journal (chronologique, horodaté)** |

⚠️ **Divergence utile relevée dans le frère** (fait avéré, non corrigé par moi) : son bloc d'ancrage (`:50-78`) déclare `CODE/M_MAIN/PRG_02_Acquisition.st` = `fabb8f764dd8c529cc857c44521f90220a10c447` **« PROPRE »** (mesure à `01:23:40`). Ce blob est **périmé** : le fichier a porté **trois états** depuis (§1.3, tableau des trois états) et vaut aujourd'hui **`5b8baa9ba8ea`** (719 l, **SALE**) — l'état `892de7b784f5` (720 l) n'était qu'**intermédiaire**. Le mécanisme décrit par le frère (`:89-90` : « *Si le blob change (lot concurrent en vol), les références sont invalidées : re-grep obligatoire* ») s'est donc déclenché **contre son propre document** — voir §5-A07.

⚠️ **Limite d'alignement** : le frère a été lu **à `01:28`**, c'est-à-dire **après** la production de la quasi-totalité de cet audit (dont la grille était déjà figée sur AC1→AC12). Les **contenus** de cette annexe n'en dépendent pas ; seuls les intitulés de la table ci-dessus en dépendent.

---

## 4. 🔧 Compléments CONCRETS proposés (prêts à fusionner)

> ⚠️ **Aucune de ces lignes n'est appliquée.** Elles sont rédigées au **format T334** (mêmes colonnes : `# | Variable | Producteur fichier:ligne | Consommateur fichier:ligne | Rôle`). Les codes proposés sont **libres** (`M67`+ et `C36`+ sont inutilisés dans T334 : la chaîne manuelle s'arrête à `M66`, la chaîne cycle à `C35`) — **jamais de renumérotation**.

### 4.1 Nouveau bloc d'ancrage — à insérer en tête de T334, après le préambule (trou 🔴 n°1)

```markdown
> 🧊 **ANCRAGE DE RÉVISION (obligatoire — AC2)** : `HEAD` = `d6e54377` ·
> horodatage = `2026-09-21T01:23:34+02:00`.
> ⚠️ Cette fiche est **modifiée non committée** et sous verrou d'écriture d'un autre
> acteur : les numéros de ligne ci-dessous valent pour l'état disque référencé par les
> blobs suivants (`git hash-object`, contenu DISQUE) — **tout écart de blob invalide
> les numéros cités** :
> - `PRG_05_Translation.st` = `27a55d0c7e3a` · `FB_Translation.st` = `7bd9fd508bde`
> - `FB_TranslationCmdArbitrationM3.st` = `2d321e97d4f6` · `FB_TranslationOutputInterlock.st` = `c4442c0f0a3d`
> - `FB_Translation_PositionDecoder.st` = `a344eb6f4f26` · `FB_Safety_Translation.st` = `ad73b45412a0`
> - `PRG_06_Outputs.st` = `3b7534a3acd4` · `PRG_03_Modes_Cycle.st` = `6e22c76df862`
> - `PRG_02_Acquisition.st` = `fabb8f764dd8` · `FB_CycleSemiAuto.st` = `032af59fc1fa` (1652 l)
> - `FB_Joystick.st` = `4d373c8ed388` · `FB_AxisScale.st` = `85d6fb1bb6ae`
> - `FB_Modes.st` = `4a890744c9f3` · `GVL_PERSISTENT.st` = `0e5860a57b5d`
> - `PRG_07_Supervision.st` = `d3449a6a85ad` (**SALE**) · `Device_IO_20260918.csv` = `18c75783a188`
> 📌 Le seul hash présent avant cet ajout (`fd12dc0`, §10bis) est celui d'une révision
> antérieure : `HEAD` a avancé et `FB_CycleSemiAuto.st` a grandi d'environ 90 lignes.
```

### 4.2 🔴 n°3 — 4 lignes à ajouter à la chaîne MANUELLE, section 4, **après M66**

```markdown
| M67 | `M3_TremieProcessBlock` | `PRG_05_Translation.st:176-181` (`TonTremieProcessBlock`, 200 ms, sur `HwIn.Machine.TremieFull_OR_GateRaised_DI`) | `PRG_05_Translation.st:512` (`AND NOT M3_TremieProcessBlock` → `EffectivePermitM3_Tremie`) | Blocage process directionnel Trémie (trémie pleine / grille) — ⚠️ **signal pas encore câblé, polarité TRUE=bloqué à confirmer** (`PRG_05:175`) |
| M68 | `EffectivePermitM3_Tremie` | `PRG_05_Translation.st:509-512` (`instSafetyTranslationM3.TremieLimitClear` AND NOT `M3_SafeStop_Aggregate` AND NOT `PowerCutOff` AND NOT `M3_TremieProcessBlock`) | `PRG_05_Translation.st:564` → `FB_Translation.st:245` (`EffectiveSafeStop`) **et** `PRG_06_Outputs.st:439-440` → `FB_TranslationOutputInterlock.st:85-86` (`PermitFinalBlocked`) → `:146-150` (`DriveControlWord`) | **Permis directionnel Trémie** — alimente directement le mot de commande ; coupé aussi sur le DI brut (voir M59) |
| M69 | `EffectivePermitM3_Maintenance` | `PRG_05_Translation.st:513-515` (`MaintenanceLimitClear` AND NOT `M3_SafeStop_Aggregate` AND NOT `PowerCutOff`) | `PRG_05_Translation.st:565` → `FB_Translation.st:246` ; `PRG_06_Outputs.st:441` → `FB_TranslationOutputInterlock.st:85-86` | **Permis directionnel Maintenance** |
| M70 | `instSafetyTranslationM3.TremieLimitClear` / `.MaintenanceLimitClear` | `CODE/I_TRANSLATION/FB_Safety_Translation.st` (sorties du FB, appelé `PRG_05_Translation.st:439-472`) | `PRG_05_Translation.st:509`, `:513` | Limites directionnelles logicielles produites par la safety — **producteur amont des 2 permis ci-dessus** |
```

### 4.3 🟠 n°7 — 1 ligne à ajouter à la chaîne MANUELLE, **après M70**

```markdown
| M71 | `GVL_IHM.M3Translation.Cmd.TglMaintenanceZoneAccess` → `instModes.SelMaintenanceZoneAccess` → `Auth.MaintenanceM3TargetEnable` | IHM (hors `CODE/`) ; déclaration `CODE/J_SUPERVISION/_TYPES/2_TRANSLATION/ST_TranslationCmd.st:17` ; entrée `CODE/F_MODES/FB_Modes.st:31` ; production `FB_Modes.st:413` (`((Mode = MAINT_N2) OR (Mode = MAINT_N1)) AND SelMaintenanceZoneAccess`) | `PRG_05_Translation.st:421` (arrêt sur **Maintenance** ou sur **P1**), `:560` (vitesse d'approche), `:152` (`M3_LimitSwitchMaintenanceEffective`), `:188` | **Autorisation CONSCIENTE de la zone Maintenance** : décide le point d'arrêt réel en marche arrière et l'application du ralentissement P2→P1 |
```

### 4.4 🟠 n°8 — 2 lignes à ajouter : mapping physique **d'entrée**, **après M71**

```markdown
| M72 | `HwIn.Translation.M3_PosTremie_DI` | mapping `Device_IO_20260918.csv:451` (`%IX224.0`, VH_0808ETP) ; recopie `PRG_02_Acquisition.st` (bus `HwIn.Translation`) | `PRG_05_Translation.st:112-118` (`instPosDecoderM3.SensorTremie`) → `FB_Translation_PositionDecoder.st:72` (bit 4) | **Capteur physique extrême Trémie** — producteur du bit 4 de `SensorsWord` |
| M73 | `HwIn.Translation.M3_PosPV_DI` / `.M3_PosPVP2_DI` (P2) | mapping `Device_IO_20260918.csv:448-455` (bloc capteurs chariot, VH_0808ETP) | `PRG_05_Translation.st:112-118` → décodeur `:73-74` (bits 3 et 2) ; ralentissement `PRG_05:549,559` | **Capteurs de zone PV et P2** — producteurs des zones de ralentissement (voir M47) |
```

### 4.5 🟠 n°9 — 1 note à ajouter à §6.4 « FB traversés »

```markdown
| `FB_Encoder` / `FB_Encoder_Safety` (via `PRG_02_Acquisition`) | ✅ **traversé indirectement** | ✅ identique | ⚠️ **Omis de la version initiale** : `M3_HeightInterlockOk` (`PRG_05:134-138`) dépend de `PRG_02_Acquisition.Data.EncoderM1/EncoderM2.HomedAndReliable` et `.Measurement.CablePosM >= GVL_PERSISTENT._TranslationMinHeightM1M2_M` : une hauteur non confirmée **coupe la demande de marche** dans les deux modes (arbitre `:72`, `:105`) |
| `FB_AxisScale` | ✅ (§4 M04) | ➖ | Omis de la liste §6.4 alors qu'il produit `ScaleX.OutPct`, entrée de l'homme-mort et du neutre brut |
```

### 4.6 🟠 n°10 — 1 ligne à corriger dans `M56` (chaîne MANUELLE)

```markdown
| M56 | `instTranslationM3.BrakeReleaseRequest` | `FB_Translation.st:286` (issu de `FB_Brake`) | **`PRG_05_Translation.st:453-454`** (safety, appelée `:439` — lit la valeur du **scan N-1**, cf. commentaire `PRG_05:435-438`) **puis** `PRG_05_Translation.st:646` → `PRG_06_Outputs.st:442-443` | Demande de desserrage frein — ⚠️ la safety est évaluée **avant** l'axe dans le même POU : le retard d'un scan est structurel |
```

### 4.7 🟡 n°11 — correction de renvoi interne (aucun code M/C concerné)

```markdown
Remplacer, en M14 et M27, « cf. §8 D04 » par « cf. §10 **A02** » (le §8 est l'arbre
des causes H1→H6 ; les items Dxx sont en §6.2 et le constat de variable morte est A02 en §10).
```

### 4.8 🟡 n°12 — 1 ligne de déclaration, en tête de la section 4

```markdown
> ℹ️ **Branches `MAINT_N1` / `MAINT_N2`** : pour la chaîne M3 **aucune branche propre
> n'existe** entre ces deux modes. Preuve : l'arbitre les traite dans la **même** branche
> (`FB_TranslationCmdArbitrationM3.st:84`), et `E_Mode.MAINT_N1`/`MAINT_N2` n'apparaît
> **nulle part** dans `PRG_05_Translation.st` ni dans `FB_Translation.st` (grep : 0).
> La seule autorisation propre à la zone Maintenance passe par
> `Auth.MaintenanceM3TargetEnable` (`FB_Modes.st:413`, voir M71).
```

### 4.9 🟡 n°13 — 1 ligne de déclaration, en tête de la section 5

```markdown
> ℹ️ **Actions de la benne = PAS une source de demande M3.** `Data.ReqProgram.ReqTranslation`
> a un **unique** producteur (`PRG_03_Modes_Cycle.st:327`) et `TranslationCmd` n'est armé que
> par les permis joystick des étapes AX2/AX14 (`FB_CycleSemiAuto.st:978`, `:1452`, `:1627`).
> La benne n'intervient sur M3 que comme **veto d'étape** (voir C28/D06) et comme
> **consommateur** de l'état M3 (C34).
```

### 4.10 Table de correction des références périmées (trous 🔴 n°2, 🟠 n°4, 🟠 n°5, 🟠 n°6)

> À appliquer **ensemble** au moment où l'ancrage de 4.1 est posé, sinon on remplace un jeu de numéros faux par un autre.

| Code | Référence dans T334 | Valeur correcte (disque `d6e54377`) |
|---|---|---|
| M01 | `PRG_02_Acquisition.st:465` | `:481` |
| M03 | `PRG_02_Acquisition.st:434` | `:445` |
| M11 | `PRG_02_Acquisition.st:475` | `:491` |
| M61/M62/M63 (miroirs IHM) | `PRG_07_Supervision.st:526` / `:527` / `:515` | `:576` / `:577` / `:565` |
| M61/M62 (relecture banc) | `PRG_02_Acquisition.st:311-312` / `:314` | `:316-317` / `:319` |
| M65 | `PRG_02_Acquisition.st:688` | `:708` |
| C02/C03 | `PRG_02_Acquisition.st:475` | `:491` |
| C04 | `PRG_02_Acquisition.st:478` | `:494` |
| C05 | `PRG_02_Acquisition.st:477` | `:493` |
| C06 | `PRG_02_Acquisition.st:476` | `:492` |
| C07 | `PRG_03_Modes_Cycle.st:278` | `:291` |
| C08/C09/C10 | `PRG_03_Modes_Cycle.st:234` / `:235` / `:236` | `:237` / `:238` / `:239` |
| C11 | `PRG_03_Modes_Cycle.st:239` | `:242` |
| C12/C13 | `PRG_03_Modes_Cycle.st:237` / `:238` | `:240` / `:241` |
| C14/C15/C16 | `FB_CycleSemiAuto.st:715` / `:716` / `:717` | `:780` / `:781` / `:782` |
| C17 | `FB_CycleSemiAuto.st:334-338` | `:354-358` |
| C18 | `FB_CycleSemiAuto.st:899` / `:913` | `:964` / `:978` |
| C19 | `FB_CycleSemiAuto.st:887` / `:900` / `:912` | `:952` / `:965` / `:977` |
| C20 | `FB_CycleSemiAuto.st:1383` / `:1386` | `:1452` / `:1455` |
| C21 | `FB_CycleSemiAuto.st:1382` / `:1387` | `:1451` / `:1456` |
| C22 | `PRG_03_Modes_Cycle.st:314` / `:392-393` / `:483-484` | `:327` / `:407-408` / `:500-501` |
| C33 | `PRG_03_Modes_Cycle.st:330` | `:343` |
| C34 | `PRG_03_Modes_Cycle.st:398` | `:413` |
| A06 / D09 / §7.1 / H2 | `PRG_07_Supervision.st:230-235` | `:280-284` |
| §3 / A08 / §10bis B.6 | `FB_CycleSemiAuto.st:1534-1545` / `:1549-1557` | `:1616-1627` (message `:1625`, commentaires `:1617-1620`) |
| §10bis B.1 | `FB_CycleSemiAuto.st:284-288,289,259,160,279,262,300` | `:301-305`, `:306`, `:277`, `:168`/`:294`, `:317` |

---

## 5. 🚨 Devoir d'alerte — constats hors scope (signalés, **NON corrigés**)

| # | Constat | Emplacement | Impact |
|---|---|---|---|
| A01 | **La carte de départ de l'orchestrateur est incomplète — et l'arbre de travail ne cesse de bouger** : la carte annonçait `PRG_04_Treuils_Benne.st` et `FB_Bucket.st` sales ; le disque portait **4 `M` + 1 `??`** à `01:23:34` et **6 `M` + 1 `??`** à `01:31:44` (`+ ST_CycleCfg.st`, `+ PRG_07_Supervision.st`, `+ GVL_Simulation.st`, `+ PRG_02_Acquisition.st`) | `git status --short -- CODE/` aux deux horodatages | `PRG_07_Supervision.st` **et** `PRG_02_Acquisition.st` sont **cités par T334** et sales : leurs numéros de ligne bougent **pendant** l'audit (cf. A07). Aucun de ces fichiers n'est touché par moi |
| A02 | **Le re-référencement exigé par §10bis A.0 et §F n'a jamais été fait, et l'écart a été multiplié par ~16** | T334 §10bis A.0 (décalage **+4** constaté le 2026-09-20 18:13) vs mesure du 2026-09-21 (**+65/+69** sur `FB_CycleSemiAuto.st`, blob `032af59fc1fa`) — décalages **mesurés par appariement `motif → ligne lue`**, jamais par comptage (§6-N11) | Une fiche de diagnostic C3 qui a servi à arbitrer la phase 2 (Q1→Q7, §11) repose sur des numéros de ligne périmés. **Décision d'orchestrateur** : re-figer avant tout lot de correction, ou accepter que le contrat C3 de T334 soit re-référencé |
| A03 | **Une incertitude de sécurité non résolue est portée par un maillon de la chaîne M3** : `TremieFull_OR_GateRaised_DI` est **« PAS ENCORE CÂBLÉ »** et sa polarité `TRUE = bloqué` est **à confirmer au câblage** — or ce signal coupe `EffectivePermitM3_Tremie` (`PRG_05:512`) donc le mot de commande | `PRG_05_Translation.st:175` | Signalé dans le code depuis l'origine, absent de T334. **Hors périmètre T351** (aucun code touché) mais à tracer pour le lot de câblage |
| A04 | **`FB_BucketCloseThreshold.st` non suivi à la racine de `CODE/H_TREUILS_BENNE/BENNE/`** (nouveau fichier d'un lot concurrent) | `git status --short` (`??`) | Conformité « nom de fichier = nom de POU » et `G310` à vérifier **par le lot propriétaire**, pas par moi. Ni créé, ni déplacé, ni indexé, ni supprimé par cette session |
| A05 | **Le livrable frère `TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md` était absent à `01:26`** (glob : 0 fichier) et **est apparu pendant l'audit** ; il a été lu à `01:28` (**non modifié** par moi) | `DOC/WFLOW/TROUBLESHOOTING/FICHES/` | ✅ **traité** : l'alignement de la grille a→g sur ses sections est fait au **§3.10**. ⚠️ Son bloc d'ancrage cite `PRG_02_Acquisition.st` comme **PROPRE** avec un blob déjà périmé → voir A07 |
| A06 | **T334 cite `PRG_04_Treuils_Benne.st:867-876` (AX12, MES limite haute) — non re-vérifié et sur un fichier SALE** | §9bis C.2 de T334 | Constat hors chaîne M3 ; je ne le valide ni ne l'invalide. Le fichier étant modifié non committé, la référence peut avoir bougé |
| A07 | **DRIFT EN COURS D'AUDIT — `PRG_02_Acquisition.st` a changé TROIS fois et est passé PROPRE → SALE** : `fabb8f764dd8` (714 l, **propre**) à `01:23:34` → `892de7b784f5` (720 l, SALE) à `01:28:50` → **`5b8baa9ba8ea` (719 l, SALE, +11/−6)** à `01:31:44`. Idem `PRG_07_Supervision.st` (`d3449a6a85ad` → **`c10f004151f8`**, 920 l), `GVL_Simulation.st` (`234163380e73` → **`c02a3bfc7848`**, 138 l) et `PRG_04_Treuils_Benne.st` | `git hash-object` + `git status --short -- CODE/` aux trois horodatages ; `git diff --numstat` | ⚠️ **Conséquences** : (1) cette annexe a été **re-ancrée trois fois** ; les valeurs `PRG_02` de sa **première** version (`:482`, `:446`, `:492`…) ont été **relues ligne à ligne et corrigées** (`:481`, `:445`, `:491`…) — elles étaient justes pour un blob intermédiaire, **fausses pour le blob courant** ; (2) le bloc d'ancrage du **livrable frère** (`TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md:55`) déclare `PRG_02` **propre** avec l'ancien blob — **il est périmé** ; (3) l'orchestrateur ne peut pas valider AC2 sur un arbre dont les fichiers bougent : **re-mesure des blobs obligatoire au moment de la validation**. Aucune de ces écritures ne vient de moi (lecture seule) |
| A08 | **`GVL_Simulation.st` est devenu SALE pendant l'audit** (puis a **encore** changé : `234163380e73` → `c02a3bfc7848`, 138 l) et **est cité par T334 §9-G** (`GVL_Simulation.SimM3SensorIntermittenceActive`, `SimM3SensorsWordOverrideActive`, …) — **sans numéro de ligne** dans T334 | `CODE/L_SIMULATION/GVL_Simulation.st` | Aucun impact sur les numéros de T334 (refs par nom de symbole), mais l'échantillon de trace §9-G dépend de ce fichier : à re-vérifier par le lot qui instrumente la campagne |
| A09 | **Le décalage d'un fichier sale n'est PAS uniforme — preuve chiffrée sur `PRG_04_Treuils_Benne.st`** (fichier **hors chaîne M3**, cité ici **uniquement** comme argument) : `instArbM1 :` **`:54`** (le brief citait `:48-49` → **+6**) · `instArbM1(` **`:530`** (cité `:519` → **+11**) · garde croisée — `WinchBothMotionReady := NOT (instWinchM1.DirectionChangePending OR instWinchM2.DirectionChangePending)` en **`:1405`** et `IF WinchBothMotionActive AND (instWinchM2.DirectionChangePending OR …)` en **`:1407`** (cité `:1394-1397` → **+11**) · `WinchM1FinalInterlockRequest.RequestedRelayFwd :=` **`:1603`** (cité `:1592` → **+11**) · `ReqM1Winch.TopLimitM :=` **`:1417`** (cité `:1416` → **+1**) | `CODE/M_MAIN/PRG_04_Treuils_Benne.st` blob `31760d59b4e0`, 1982 l — **toutes ces lignes relues par moi** (`grep` sur motif exact, `01:34`) | 🚨 **Un décalage mécanique global est donc IMPOSSIBLE dans ce dépôt en ce moment** : « valeur T334 + offset » est une méthode **fausse** — argument supplémentaire et chiffré pour le trou 🔴 n°1 (voir encadré 🪨 LEÇON §1.3). Toute reprise de références doit être **lue**, jamais **calculée** |

---

## 6. ❓ Ce que je n'ai PAS pu vérifier (et pourquoi)

| # | Point non vérifiable | Raison | Ce qu'il faudrait |
|---|---|---|---|
| N1 | **Que les numéros cités par T334 étaient exacts au moment de sa rédaction** | Je n'ai **que** l'état disque du 2026-09-21 : la révision du 2026-09-20 18:07 n'est ni committée (l'arbre était sale) ni référencée par un blob dans la fiche. Je peux prouver « faux aujourd'hui », **jamais** « faux alors » | Un blob ou un commit de la fiche + des fichiers à la date de rédaction |
| N2 | **Le contenu exact des anciennes lignes `FB_CycleSemiAuto.st:715-717`, `:818`, `:727`, `:1510`, `:423`, `:560`, `:246`, `:1534-1545`** | Le fichier a été réécrit (+20 à +91) et est désormais **propre** vs `HEAD` : l'ancienne révision n'est plus dans l'arbre de travail. J'ai vérifié les **contenus actuels** des faits correspondants, pas les lignes citées | `git show` sur la révision où T334 a été écrit — **hors de mon périmètre de preuve** (je n'ai lu que le disque, cf. garde-fou REX T345) |
| N3 | **La constante `CST_TranslationStopConfirmTime` (500 ms ?) et son emplacement** | Déclarée dans la zone `:238-251` de `FB_CycleSemiAuto.st` ; non relue ligne à ligne (T334 cite `:246`, valeur non retrouvée à cette ligne) | Relecture ciblée de `FB_CycleSemiAuto.st:238-260` au moment de la fusion |
| N4 | **La vérité physique du mapping E/S** (`%IX224.0` = Trémie, `%QW6` = mot de commande, etc.) | `Device_IO_20260918.csv` est une **configuration de projet**, pas la preuve CODESYS ; `AGENTS.md` interdit de lire `Device.export` (périmé par doctrine) et cette mission interdit tout `PRJ_CODESYS/**` | Un **export frais** du projet CODESYS par l'humain — je m'en tiens donc au CSV comme source documentaire, en le déclarant comme telle |
| N5 | **Les 4 blobs de `FB_Brake.st` cités par §10bis B.5** (`:72,93,103-104`) | Hors de la chaîne M3 directe ; non relus dans cette passe (budget de vérification orienté chaîne) | Relecture dédiée si la classe de faute T287 revient en phase 2 |
| N6 | **`PRG_04_Treuils_Benne.st:867-876` (MES limite haute, §9bis C.2)** | Fichier **hors chaîne M3** (il est **PROPRE** depuis `065591fb`, blob `31760d59b4e0`, 1982 l). Son décalage **non uniforme est mesuré** (§5-A09, +1 à +11) mais sa chaîne complète n'est **pas** retracée ici | Re-vérification par le lot propriétaire ; mes échantillons §5-A09 valent pour le blob `31760d59b4e0` **uniquement** |
| N11 | **Un écart entre deux comptages de lignes peut n'être qu'un ARTEFACT DE MÉTHODE — corrigé après audit** | Mesuré par moi sur `PRG_04_Treuils_Benne.st`, **5 méthodes**, disque = `HEAD` (`git diff --stat HEAD` **vide**, blob disque = blob `HEAD` = `31760d59b4e0`) : `Get-Content` **1982** · `[System.IO.File]::ReadAllLines` **1982** · tableau `git show HEAD:` **1982** · `((git show HEAD:) -join "`n") -split "`n"` **1982** · **`git show HEAD: \| Measure-Object -Line` → 1825**. **Cause identifiée** : `Measure-Object -Line` **ne compte pas les lignes vides** (1982 − 1825 = **157** lignes vides du fichier). Ce n'est donc **pas** une preuve que « le comptage est instable » : c'est un **mauvais compteur** | 🎯 **Règle opérationnelle** : comparer **toujours par blob SHA** — `git hash-object <fichier>` vs `git rev-parse HEAD:<fichier>` — et **jamais** par nombre de lignes. Un écart de comptage signale une **méthode de mesure**, pas un contenu. Corollaire : **jamais** de décalage de lignes déduit d'un delta de comptage (§1.3, 🪨 LEÇON) |
| N7 | **L'alignement de la grille sur les titres de sections du livrable frère T351** | Le fichier n'existait pas au début de mon relevé (glob : 0 résultat à `01:24`) ; il est apparu **pendant** l'audit et a été lu à `01:28` | ✅ **traité** : l'alignement de forme est fait au §3.10. **Restent à vérifier par l'orchestrateur** les refs du frère qui portent sur des fichiers ayant bougé (cf. §5-A07) |
| N8 | **L'exhaustivité absolue de T334 au-delà de mon échantillon** | J'ai contre-vérifié **96 lignes de tableau** (exigence : ≥25) réparties sur les 2 chaînes et ciblées sur les points durs. Les `Mxx`/`Cxx` non échantillonnés **n'ont pas été validés un par un** | Passe mécanique exhaustive (script d'appariement motif↔ligne sur les 101 codes) — **hors périmètre** de cette annexe (et interdite de script à la racine) |
| N9 | **La stabilité des numéros de ligne au-delà de `01:31:44`** | **Quatre** fichiers `CODE/` cités ont bougé **pendant** les huit minutes de l'audit, dont un **trois fois** (§5-A07). Aucune relecture ne peut garantir la validité d'un numéro de ligne plus loin que le blob sur lequel il a été mesuré | Re-mesurer les blobs **au moment exact** de la validation (AC2) et **relire** (pas recalculer) tout couple dont le blob a changé |
| N10 | **Les numéros de ligne du blob intermédiaire `892de7b784f5` (720 l)** | Ce blob **n'existe plus** (écrasé par le lot concurrent) : son ensemble (`:446`/`:482`/`:492`/`:493`/`:494`/`:495`/`:709`, plus le banc `:317-318`/`:319-320`) provient d'un `grep` à `01:28:50` et **n'est plus re-vérifiable ligne à ligne**. La **cause** de l'écart de 1 avec l'état actuel est en revanche **établie** : suppression d'**une** ligne entre ~320 et ~445, cohérente avec `:319` inchangé et le −1 sur tout l'aval (§1.3, tableau des trois états) | Aucun besoin pour l'état **actuel** (déjà relu) ; la traçabilité des trois états est conservée au §1.3 — **jamais** de remplacement silencieux |

> 🚫 **Aucun comblement par supposition** : tout ce qui n'est pas prouvé ci-dessus est listé ici, pas deviné.

---

## 7. 📝 Journal (chronologique, horodaté)

- **2026-09-21 01:23:26** — heartbeat `debut` (session `task-T351-annexeM3`, acteur **DSH17**). Lecture intégrale du préambule `TOOLS/AGENT_WORKFLOW/prompts/subagent_preamble.md` (203 lignes).
- **01:23:34** — **ancrage** : `HEAD` = `d6e54377` ; `git status --short -- CODE/` relevé **AVANT** → 4 `M` + 1 `??` (écart vs la carte de l'orchestrateur → alerte A01) ; blob de la fiche T334 = `2ea84800602ea530698c4a220f88ad48e3b7fd8f` (SALE) ; horodatage ISO `2026-09-21T01:23:34+02:00`.
- **01:23:44** — heartbeat `grille` ok. Lecture intégrale de T334 (789 lignes), du brief T351 (108 lignes), du contrat T351 (135 lignes). Grille d'audit a→g établie depuis AC1→AC12 + §5 du brief.
- **01:24** — **blobs disque** des 27 fichiers `CODE/` + CSV cités par l'annexe (`git hash-object`, contenu disque). Confirmation des valeurs de la carte (`PRG_06_Outputs`= `3b7534a3acd4`, `PRG_03`= `6e22c76df862`, `FB_CycleSemiAuto`= `032af59fc1fa`).
- **01:24-01:26** — **contre-vérification** : lecture disque de `FB_TranslationCmdArbitrationM3.st`, `FB_TranslationOutputInterlock.st`, `FB_Translation.st:100-323`, `FB_Translation_PositionDecoder.st:55-118`, `PRG_06_Outputs.st:395-474`, `PRG_05_Translation.st:125-300/352-479/505-599`, `PRG_03_Modes_Cycle.st:188-344/385-414/480-507`, `PRG_02_Acquisition.st:300-321/455-504`, `FB_CycleSemiAuto.st:348-361/700-734/870-919/1370-1405`, `FB_Joystick.st`, `FB_AxisScale.st`, `FB_Modes.st`, `FB_Safety_Translation.st:192-209`, `PRG_07_Supervision.st:552-586`, `GVL_PERSISTENT.st:84-103`, les DUT `ST_*` et 12 lignes du CSV `Device_IO_20260918.csv`.
- **01:25** — **preuves d'absence (grep réels à 0 occurrence)** : `hash-object`/`blob` dans T334 ; `TremieProcessBlock`, `TremieLimitClear`, `MaintenanceLimitClear`, `TglMaintenanceZoneAccess`, `SelMaintenanceZoneAccess`, `%IX` dans T334 ; `E_Mode.MAINT_N1|MAINT_N2` dans `PRG_05_Translation.st` et `FB_Translation.st`.
- **01:25** — **preuves d'unicité** (convergence §6.1 re-prouvée indépendamment) : `instArbM3(` ×1, `instTranslationM3(` ×1, `instTranslationOutputInterlockM3(` ×1, et **une seule affectation** de `M3_CommandWord` / `M3_SetpointFrequencyHz` / `M3_BrakeRelease_RQ` dans tout `CODE/`.
- **01:26:46** — heartbeat `verif` ok. Synthèse : **94 lignes de tableau contre-vérifiées** (50 chaîne manuelle + 44 chaîne cycle & affirmations) → `EXACT` **65** · `DECALE` **25** (couvrant **47 couples `fichier:ligne`**) · `FAUX` **2** · `NON VERIFIABLE` **2** ; **3 🔴 · 7 🟠 · 3 🟡**.
- **01:27** — rédaction et écriture de la présente annexe (`TROUBLESHOOTING_T351_ANNEXE_M3_TrousT334_20260921.md`, 509 lignes). **La fiche T334 n'a pas été modifiée** ; ses compléments sont au §4, prêts à fusionner.
- **01:28:28** — **DRIFT DÉTECTÉ** : le relevé `git status --short -- CODE/` **APRÈS** n'est **pas** identique à `AVANT` — deux fichiers cités ont été rendus sales par un lot concurrent **pendant** l'audit (`GVL_Simulation.st`, `PRG_02_Acquisition.st`), et `PRG_02_Acquisition.st` est passé **propre → sale** (714 → 720 lignes). Aucune écriture ne vient de cette session (lecture seule stricte ; la seule écriture est mon livrable).
- **01:28:50** — **RE-ANCRAGE** : les 27 blobs sont re-mesurés. `PRG_02_Acquisition.st` = `892de7b784f5` (720 l, SALE) ; `PRG_07_Supervision.st` = `c10f004151f8` (920 l, SALE). Les 12 couples `fichier:ligne` touchés (`PRG_02` **+6 à +21** à cet instant, `PRG_07` **+50**) sont **re-mesurés et corrigés** dans §2.1, §2.2, §3.5/§3.6 et §4.10 ; l'ancrage de §1.3 est réécrit. Le livrable frère T351 (DSH16) est apparu : sa structure de sections est relue et la grille est alignée en **§3.10** (constat : son propre bloc d'ancrage cite `PRG_02` comme **propre** avec un blob désormais périmé → §5-A07).
- **01:31:44** — **3ᵉ ANCRAGE (fait foi)** : `PRG_02_Acquisition.st` a **encore** changé → blob **`5b8baa9ba8ea`**, **719 l**, SALE (+11/−6) ; `GVL_Simulation.st` → `c02a3bfc7848` (138 l). **Relecture ligne à ligne** (outil `read`, jamais de calcul `T334 + offset`) de **toutes** mes références `PRG_02_Acquisition.st:…` : 10 couples corrigés (`:482`→`:481`, `:446`→`:445`, `:492`→`:491` ×2, `:495`→`:494`, `:494`→`:493`, `:493`→`:492`, `:709`→`:708`, `:317-318`→`:316-317`, `:319-320`→`:319`) — §2.1, §2.2, §3.5 et §4.10 mis à jour.
- **01:32** — **re-vérification par lecture des autres blocs** (aucun ±1 trouvé) : `PRG_03_Modes_Cycle.st` (`:196-209`, `:237-242`, `:291`, `:327`, `:343`, `:407-408`, `:413`, `:500-501`) ✔ ; `FB_CycleSemiAuto.st` (`:354`, `:780-782`, `:952`, `:964-965`, `:977-978`, `:1451-1456`, `:1616-1627`) ✔ ; `PRG_07_Supervision.st` (`:282`, `:565`, `:576`, `:577`) ✔ ; `PRG_05_Translation.st` (`:87`, `:134`, `:152`, `:181`, `:212`, `:363`, `:385`, `:439`, `:479`, `:509-515`, `:537`, `:817-822`) ✔ ; `PRG_06_Outputs.st` (`:431`, `:434`, `:443`, `:445`, `:448`, `:457-459`) ✔. **Le ±1 était donc isolé à `PRG_02`**, seul fichier à avoir bougé trois fois pendant l'audit.
- **01:34:18** — **5ᵉ contrôle (post-audit orchestrateur)** : `HEAD` = `065591fb` ; `git status --short -- CODE/` = **2 `M`** (`PRG_02_Acquisition.st` `5b8baa9ba8ea` 719 l, `GVL_Simulation.st` `c02a3bfc7848` 138 l) ; `PRG_04` `31760d59b4e0` (1982 l), `PRG_03` `6e22c76df862`, `PRG_05` `27a55d0c7e3a`, `PRG_06` `3b7534a3acd4`, `FB_CycleSemiAuto` `032af59fc1fa`, `FB_WinchDirectionInterlock` `5fa9e0405ac3` — tous re-mesurés par moi, aucun recopié. Vérification indépendante des références `PRG_04` (A09) : `:54`, `:530`, `:1405`, `:1407`, `:1417`, `:1603` **relues par moi**.
- **01:36:56** — **6ᵉ contrôle (clôture)** : `HEAD` = **`b25020bc`** (`fix(diag): T352…`) ; `git status --short -- CODE/` est **VIDE** (0 `M`, 0 `??`). **Preuve finale du trou 🔴 n°1** : `PRG_02_Acquisition.st` porte toujours le blob **`5b8baa9b`** — il est simplement passé de *SALE* à *PROPRE* par un commit d'un tiers, **sans qu'une ligne change**. `git hash-object PRG_02` = `git rev-parse HEAD:PRG_02` = `5b8baa9ba8ea` (idem `GVL_Simulation` = `c02a3bfc7848`) ⇒ **les numéros de cette annexe restent valides** ; c'est le **statut Git**, pas le contenu, qui a changé. Aucun fichier de `CODE/` écrit par moi.
- **audit orchestrateur 2026-09-21** — **1 défaut propre relevé et corrigé** : §0.3 portait `PRG_07_Supervision.st:566,577,578` pour les miroirs IHM M3 → corrigé en **`:565`/`:576`/`:577`** (la ligne `:566` est le miroir Kobold `M1_M2_KoboldMeasureEnable_RQ`, `:578` n'est pas un mot M3). **1 critique de l'orchestrateur RÉFUTÉE par re-mesure** : l'écart `±1` annoncé sur `PRG_02` n'était **pas** un défaut d'arithmétique de ma part — mes numéros étaient **exacts pour le blob que je déclarais** (`892de7b784f5`, 720 l) ; le fichier est passé à `5b8baa9ba8ea` (719 l, une ligne supprimée entre ~320 et ~445) **entre** la mesure du blob et la lecture des lignes. L'orchestrateur a rétracté sa critique. **Décision de rédaction assumée** : la colonne **opérationnelle** de cette annexe reste **l'état actuel** `5b8baa9b` (relu ligne à ligne — c'est ce dont un lecteur d'aujourd'hui a besoin), et les **deux états antérieurs** sont **conservés** dans le tableau des **trois états** du §1.3 : aucun remplacement silencieux, aucune suppression. Encadré **🪨 LEÇON** ajouté (§1.3), §5-A09 complété (`PRG_04` non uniforme, vérifié par moi), §6-N11 ajouté (comptage de lignes — **entrée corrigée au tour suivant**, voir ci-dessous).
- **audit orchestrateur 2026-09-21 (2ᵉ passe)** — **correction N11 (artefact `Measure-Object -Line`)** : mon entrée §6-N11 concluait à tort que « le comptage de lignes n'est pas une mesure fiable ». Vérification par **5 méthodes sur `PRG_04_Treuils_Benne.st`** (disque = `HEAD`, `git diff --stat HEAD` vide, blob identique `31760d59b4e0`) : `Get-Content` **1982** · `[System.IO.File]::ReadAllLines` **1982** · tableau `git show HEAD:` **1982** · `-join/-split` **1982** · **`Measure-Object -Line` → 1825**. **Cause : `Measure-Object -Line` ignore les lignes vides** (1982−1825 = **157**). N11 réécrit avec cette cause et la **règle opérationnelle** : *comparer **toujours par blob SHA** (`git hash-object` vs `git rev-parse HEAD:<fichier>`), jamais par nombre de lignes*. Encadré 🪨 LEÇON (§1.3) mis à jour pour la même raison. §0.2-3, §3-🔴2 et §5-A02 précisés : les décalages sont **mesurés par appariement `motif → ligne lue`**, jamais déduits d'un comptage. Entrée §3.10 ligne « divergence du frère » alignée sur le tableau des trois états (elle citait `892de7b784f5` comme valeur **courante** ; c'est un état **intermédiaire** — la valeur actuelle est `5b8baa9ba8ea`).
- **01:33:26** — **4ᵉ observation (contrôle d'état final)** : le lot concurrent a **committé** → `HEAD` passe de `d6e54377` à **`065591fb`** (`fix(benne): T262 phase B…`) ; `PRG_04`, `PRG_07`, `FB_Bucket`, `ST_CycleCfg` deviennent **PROPRES** et `FB_BucketCloseThreshold.st` n'est plus non suivi. **Les blobs des fichiers cités sont INCHANGÉS** → **les numéros de ligne de cette annexe restent valides** (ils viennent de la lecture du contenu, jamais d'un diff de `HEAD`). Restent sales : `PRG_02_Acquisition.st`, `GVL_Simulation.st`.
- Relevé **APRÈS** `git status --short -- CODE/` (`01:31:44` puis `01:33:26`) : **NON identique** à `AVANT` (`01:23:34`) — 4 `M` + 1 `??` → 6 `M` + 1 `??` → **2 `M`** (commit intermédiaire d'un tiers). Écart **entièrement attribuable à des lots concurrents** (cf. §5-A01/A07/A08), prouvé par le fait que les seules écritures de cette session sont ce livrable et le heartbeat. Aucun fichier de `CODE/` écrit par moi, aucun test, aucun gate, aucun bundle, aucun commit.

---

📖 Méthode : `TOOLS/AGENT_WORKFLOW/prompts/troubleshooting.md` · Gabarit : `DOC/WFLOW/TROUBLESHOOTING/TEMPLATE_Troubleshooting.md`
🔗 Audit de : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md` (**non modifiée**, blob inchangé sur les 3 mesures) · Lot parent : `T351` · Frère (DSH16) : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md` (**non modifié** — existant au `01:28`, lu puis aligné au §3.10)
🔗 Tâches liées : `T334` (fiche auditée), `T287` (défaut frein aux mêmes arrivées), `T300` (banc + perte capteur), `T319` (continuité AX2→AX3), `T331`/`DSH09` (propriétaire historique de `FB_CycleSemiAuto.st`, à l'origine du décalage constaté)
