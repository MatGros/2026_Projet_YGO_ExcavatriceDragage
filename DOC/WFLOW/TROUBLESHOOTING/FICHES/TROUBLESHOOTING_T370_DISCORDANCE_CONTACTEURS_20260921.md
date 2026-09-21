# 🕵️ Session de Troubleshooting — Discordance commande / retour contacteurs puissance (Treuils M1/M2) — T370

> 📌 **Emplacement** : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T370_DISCORDANCE_CONTACTEURS_20260921.md`
> 📅 Date : 2026-09-21 · 🧊 Situation : **[DIAGNOSTIC STATIQUE — lecture de code, banc non sollicité]** · 📄 Statut : **[EN COURS — verdict remis, révisé après 2 contre-expertises adverses (MAJOR), validation humaine attendue]**
> ⚔️ **Contre-expertises** : 2 experts en contexte frais (technique code + sécurité ISO 13849) — verdicts **MAJOR/Major**, 12 corrections acceptées, 4 critiques réfutées avec argument → **§13**.
> 🔒 **Périmètre** : investigation lecture seule stricte — **zéro ligne de `CODE/` modifiée, aucun commit**.
> 🎫 Tâche : `T370` (parent `T288`) · Brief : `DOC/WFLOW/CONTRACTS/BRIEF_T370_DISCORDANCE_CONTACTEURS.md`

---

## 1. 🧊 Contexte figé (horodaté)

> ⚠️ **Pas de snapshot live** : ce lot est un diagnostic **par lecture de code** (brief §6 : « investigation en lecture seule stricte »). Aucune variable n'a été forcée, aucun banc démarré, aucune mesure rafraîchie. Les seules « valeurs » citées sont des **lignes de source réelles relues sur disque** (arbre de travail, 2026-09-21).

### Texte de contexte

- **Mail client GCAM (2026-09-15)** : *« Discordance contacteurs : première détection validée en simulation. Si une commande est demandée alors que le retour indique les contacteurs au repos, alarme puis SafeStop après 3s. Il faut compléter les causes multiples de discordance avec suffisamment de détail pour la maintenance en cas de blocage. »*
- **Terrain (utilisateur, 2026-09-21)** : « l'automate envoie une commande, mais les contacteurs de puissance ne bougent pas physiquement. »
- **Hypothèse orchestrateur à vérifier** : `FB_SyncContactor` ne détecterait qu'une **asymétrie M1/M2** ; un échec **symétrique** (les deux treuils identiques) passerait inaperçu.

### Variables & valeurs — inventaire des signaux réellement disponibles (lecture de code)

| Élément | Variable complète | Valeur disponible en ligne (source) |
|---|---|---|
| Retour contacteurs M1 | `PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI` | **1 bit collectif** (`Local_Digital_IO · 0`, NO, `TRUE` = relâchés) — `AF_Partie-06…v2.4.md:457`, mapping `PRG_02_Acquisition.st:145` |
| Retour contacteurs M2 | `PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI` | **1 bit collectif** (`Local_Digital_IO · 2`) — `AF_Partie-06…v2.4.md:459`, `PRG_02_Acquisition.st:149` |
| Retour frein M1/M2 | `…M1/M2_BrakeIsOpen_DI` | 1 bit par treuil (`TRUE` = frein ouvert) — `ST_HwWinch.st:10,14` |
| Ordre contacteurs M1/M2 (final) | `PRG_06_Outputs.M1/M2RelayFwd`, `M1/M2RelayRev`, `M1/M2SpeedContactor1..4` | 6 bits par treuil — `PRG_06_Outputs.st:286-304` |
| Sorties physiques | `M1_RelayAscent_RQ`, `M1_SpeedContactor_1..4_DQ`… | `PRG_06_Outputs.st:369-384` |
| Santé modules DI | `PRG_02_Acquisition.Data.InputModules.Fault` | global (pas de granularité par voie/treuil) — commentaire `PRG_04_Treuils_Benne.st:702-705` |
| Retour par contacteur (C1…C4 individuel) | — | ❌ **N'existe pas dans le projet** (aucune E/S) |

---

## 2. 🎯 Symptôme

Sous commande de mouvement (relais de sens et/ou contacteurs de vitesse émis par l'automate), **aucun contacteur de puissance ne se ferme physiquement** ; l'opérateur ne constate **aucune alarme explicite désignant les contacteurs**, la maintenance ne peut pas discriminer la cause (bobine, alimentation, fusible, contact auxiliaire).

---

## 3. 🧩 Indices / historique

- **Déjà connu et déjà cadré** : la tâche **T288** (entrée `- id: T288`, `DOC/WFLOW/TASKS.yaml`, domaine `TREUILS_BENNE / COHERENCE CONTACTEURS PAR AXE`) porte exactement ce sujet — *« Cohérence commande/retour contacteurs par axe et couverture absence de mouvement »*, phase 1 **validée en simulation le 2026-09-15** (= le mail GCAM), phases 2 et 3 **non implémentées**.
  > 🚨 **Avertissement de traçabilité (constaté pendant ce lot)** : `DOC/WFLOW/TASKS.yaml` est **modifié en continu par d'autres acteurs** pendant l'investigation (fichier `git status` = modifié ; **+97 / −20 lignes** vs `HEAD` ; mtime 2026-09-21 12:13). Mes premières citations de lignes (`2382-2421`, `2393-2395`, `2406-2411`) étaient **exactes à l'instant de la lecture**, puis le fichier a **glissé de ~+40 lignes** — et les contre-experts ont lu **encore d'autres** numéros (`2404-2443`, `2416-2417`, `2430-2433`). ➡️ **Règle** : ne citer `TASKS.yaml` que **par `id` et par extrait de texte**, jamais par numéro de ligne (même REX que `T345` sur ce dépôt). À la dernière relecture : T288 = `- id: T288` (bloc repéré à la ligne 2422), phrase « retour collectif… » ≈ 2435, phases 2/3 ≈ 2448.
- **Audit interne antérieur** : `DOC/WFLOW/AUDITS/CONTACTEURS_SOLUTION_20260831.md:122` (**L2**) — *« Comparaison des COMMANDES, pas des feedbacks : `FB_Winch.Sensors.ContactorsAllOff` (feedback physique) n'est **jamais** passé à `FB_SyncContactor` »*. L'hypothèse de l'orchestrateur est **déjà écrite noir sur blanc dans le dépôt**, avec 3 autres lacunes (L1/L3/L4).
- **Contrainte structurante** : le retour contacteur est **collectif** — *« Le retour `Mx_ContactorsReleased_DI` est collectif : il affirme seulement que tous les contacteurs sont retombés, sans identifier un contacteur précis »* (entrée `T288`, `DOC/WFLOW/TASKS.yaml`, champ `contexte`).
- **Défaut d'attribution documentaire** : `DOC/AF/AF_Partie-10_Fonction_Winch/FB_SyncContactor_v1.0.md:27-28` affirme que le bloc *« détecte les collages de contacteur, défaillances de bobines »* — **contredit par le code** (§4 ci-dessous : le bloc ne lit aucun retour physique).
- Alarmes existantes au bandeau : `[SYNC] discordance contacteurs M1/M2 -> arret` / `-> coupure` (`FB_Hmi_BannerFormatter.st:1079-1081`) et `[M1|M2] ErrorID:16 - discordance commande/retour/mouvement` (`:945`, `:993`).

---

## 4. 🌳 Arbre des causes & hypothèses (vérification de l'hypothèse orchestrateur)

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue (preuve) | Verdict |
|---|---|---|---|---|---|
| H1 | `FB_SyncContactor` compare **un ordre à SON PROPRE retour** | entrées `RelayFwdM1` / `Contactor*_M1` | Ordre **et** retour physique par axe | Les 2 instances reçoivent des **commandes internes PLC** (voir H1bis) | ❌ **Réfutée** |
| H1bis | Les entrées de `FB_SyncContactor` sont des **commandes M1 vs commandes M2** | `PRG_04:648-659`, `PRG_06:345-350` | — | `instWinchM1.RelayFwd/Contactor1..4` (amont) puis `M1RelayFwd/M1SpeedContactor*` (aval, post-protecteur) | ✅ **Confirmée** |
| H2 | Un échec **symétrique** M1/M2 (les 2 treuils identiques) est invisible pour `FB_SyncContactor` | `Diag.Step*Mismatch`, `ContactorMismatch` | `M1 <> M2` (asymétrie seulement) | `FB_SyncContactor.st:104-109` : `(RelayFwdM1 <> RelayFwdM2)`, `(Contactor1_M1 <> Contactor1_M2)`… | ✅ **Confirmée** |
| H3 | **Aucun** mécanisme ne confronte l'ordre contacteur au retour contacteur du **même axe** | grep large `ContactorFeedback`, `HwIn.` dans `PRG_06`, `PRG_04` | Détection commande/retour par axe | **PARTIEL — formulation corrigée après contre-expertise** : **0** comparateur dans le sens **fermeture** (« commande ON + retour au repos → défaut »), mais **2** existent dans le sens **relâchement** (« commande OFF + retour encore engagé » : `Meca B` `FB_Safety_Winch.st:341-343` et latch `§3bis` `FB_WinchOutputInterlock.st:304-318`), **1 dormant** (`FB_Winch.ContactorsCheck` : opérandes câblés `:314-315`, comparateur neutralisé `:316-318`), et **1 patron actif au niveau du contacteur de ligne AU** (`FB_Safety_EmergencyManagement` : confirmation KM_Power 2 s). « 0 mécanisme » était **faux** | ⚠️ **Confirmée en substance, formulation inexacte** |
| H4 | `PRG_06_Outputs` (sorties finales) contiendrait une comparaison ordre/retour générale | lecture `PRG_06` entière | Comparaison présente | `PRG_06` ne lit **que** 3 DI : `EmergencyChainClosed_DI`, `PowerContactorEngaged_DI`, `M3_PosTremie_DI` (`:321,322,326,327,431,440,488,489`). **Aucun** `M*_ContactorsReleased_DI` lu | ❌ **Réfutée** (pas de comparaison générale) |
| H5 | `FB_Safety_Winch` couvrirait le cas par un autre chemin | `TonNoMovement` | Dépend du retour contacteur | `FB_Safety_Winch.st:437-443` : **le retour collectif n'entre pas** dans la garde (c'est volontaire, cf. G501) | ⚠️ **Partielle** (couvre l'absence de mouvement, pas la discordance contacteur) |
| H6 | Une brique de diagnostic générale des sorties E/S existerait | grep `OutputModules\|OutputModuleFault` | Brique présente | 🔴 **FAUX — je me suis trompé, la contre-expertise a raison** : les **2 cartes de SORTIE à relais** sont surveillées — `PRG_02_Acquisition.st:213-214` (`VH_0008ER`, `VH_0008ER_1` via `GetDeviceState()`), agrégées `:216` `InputModules.Fault` → **SafeStop M1+M2** (`PRG_04:713/715`) + **SafeStop M3** (`PRG_05:404`), avec **alarme opérateur dédiée** (`FB_Hmi_BannerFormatter.st:887-891` `'[IO] Defaut module VH0008ER (DO8 Relais)'`). Mon grep a échoué **parce que la structure s'appelle `InputModules` alors qu'elle contient les cartes de sortie** (`ST_IOModuleDiag.st:17-18`) | ❌ **Réfutée — à tort de ma part** |
| H7 | Côté M3 (translation, 3ᵉ actionneur), un mécanisme équivalent existe | `FB_Brake.ContactorCheck` | Ordre/retour par axe | `FB_Brake.st:113-127` : `TonFeedback(IN := BrakeCmd <> ContactorFeedback)` → `StuckClosed`/`StuckOpen` — **mais sur le FREIN M3 uniquement**, et **retiré côté treuils** (`ST_WinchFinalInterlockRequest.st:16` « (retrait FB_Brake) ») | ⚠️ **Existe pour M3/frein, absent pour M1/M2/contacteurs puissance** |

---

## 5. 📊 Cartographie des mécanismes de surveillance existants (preuve fichier:ligne)

### 5.a — `FB_SyncContactor` : symétrie M1 ⇄ M2 de **commandes** (2 instances)

| Instance | Appel | Ce qui est réellement câblé | Nature |
|---|---|---|---|
| `instContactor` (dans `instWinchSync`) | `FB_WinchSync.st:147-166` ← `PRG_04_Treuils_Benne.st:627-671` | `RelayFwdM1 := instWinchM1.RelayFwd`, `Contactor1_M1 := instWinchM1.Contactor1`… (`:648-659`) | **Commandes FB_Winch (amont)** |
| `instSyncContactorFinal` | `PRG_06_Outputs.st:341-362` | `RelayFwdM1 := M1RelayFwd`, `Contactor1_M1 := M1SpeedContactor1`… (`:345-350`) | **Commandes finales DQ (post §2quater)** |

Détection : `FB_SyncContactor.st:98-109` (`BothCommanded` + `M1 <> M2`), temporisation 500 ms (`:140-141`), escalade 3 s (`:144-145`).
Réaction : niveau 1 → `WinchContactorMismatchLvl1` → `SafeStopM1/M2_Raw` (`PRG_04:712-716`) puis couplage croisé (`PRG_04:1105-1106`) ; niveau 2 → `PRG_06.Data.ContactorMismatchEscalated` → `ExternalSyncEscalation` (`PRG_04:993`, `:1059`) → latch Meca E escalade bit13 → `PowerCutOff` (`FB_Safety_Winch.st:411-416`).

> 🔎 **Défaut de nommage/commentaire à connaître** : les entrées sont commentées `--> [HW] Feedback/Ordre montee M1` (`FB_SyncContactor.st:27-30`) et la spec les nomme « Ordre/retour » (`FB_SyncContactor_v1.0.md:127-128`). **Aucun retour physique n'est câblé** — l'ambiguïté invite un futur lot à câbler une DI là et casserait la sémantique M1⇄M2 du bloc.

### 5.b — Ce qui existe **par axe** (et son angle mort)

| Mécanisme | Preuve | Ce qu'il compare réellement | Angle mort |
|---|---|---|---|
| Watchdog **frein** (500 ms) | `FB_WinchOutputInterlock.st:494-519`, `Reason := BRAKE_COMMAND_NOT_CONFIRMED` `:508` | `BrakeCmd` (ordre) **vs** `BrakeFeedback` (retour physique) | Porte sur le **frein**, pas sur les contacteurs |
| `Meca B` — « absence confirmation arrêt contacteurs/frein » | `FB_Safety_Winch.st:341-343`, 3 s (`:49`), latch `:484` `ContactorStuck := MecaBFaultLatched` | **Joystick au neutre** vs (retour collectif AU REPOS ET frein serré) | Sens **inverse** : détecte un contacteur **collé** (ne retombe pas), pas un contacteur qui **ne ferme pas** |
| Latch `ContactorStuck` T_max 400 ms | `FB_WinchOutputInterlock.st:283-284`, `:304-318`, `Reason := SENSE_DROP_TIMEOUT` `:372` | Ordre de **relâchement** du sens vs `FwdRevSpeedFeedbackOff` | Armé **uniquement** pendant le maintien de sens §3bis (transitoire de chute de palier) |
| `FB_Winch.ContactorsCheck` | `FB_Winch.st:314-318` | Champs déclarés mais `StuckClosed/StuckOpen` **forcés à FALSE** (« détection produite par FB_Safety_Winch ») | Diagnostic **non alimenté** |
| `FB_Safety_Winch` cause 15 — absence de mouvement | `FB_Safety_Winch.st:437-447` | `MovementCommanded AND BrakeFeedback AND EncoderAvailable AND NOT PositionMovementDetected` | **Le retour contacteur est exclu** (`G501_check_t288_no_movement_feedback.py:32-36` l'interdit explicitement) ; exige codeur dispo + frein **ouvert** |
| `FB_Winch_Symmetry` (passif) | `FB_Winch_Symmetry.st:9-112`, instancié `PRG_07_Supervision.st:38` | Deltas de **temps** frein/démarrage/arrêt M1 vs M2 | Observateur pur, **aucun défaut**, aucune vue sur les contacteurs |
| `DirectionInterlock` | `FB_Winch.st:198` | Condition **d'autorisation** (`StepNumber = 0 AND ContactorsAllOff`) | Permissif, pas diagnostique |

### 5.c — Couverture du cas terrain « commande envoyée, contacteur immobile »

| Sous-cas terrain | Détection aujourd'hui | Preuve | Qualité |
|---|---|---|---|
| Carte **relais de sortie** non RUNNING (`VH_0008ER` = bobines freins + relais de sens M1/M2 ; `VH_0008ER_1` = AU) | ✅ **SafeStop M1+M2** + **alarme** `[IO] Defaut module VH0008ER (DO8 Relais)` | `PRG_02_Acquisition.st:213-216` → `PRG_04:713/715` · `FB_Hmi_BannerFormatter.st:887-891` | ✅ **Correctement couvert** — famille « variables PLC TRUE, sorties non appliquées » |
| Contacteur de puissance de **ligne (KM_Power)** non réengagé à l'armement | ✅ **défaut latché** après 2 s + alarme `[AU] ErrorID:02 - echec confirmation armement` | `FB_Safety_EmergencyManagement.st` (`CST_ArmingConfirmTimeout = T#2s`, `EmergencyArmingFailedCause`) · `FB_Hmi_BannerFormatter.st:1126` | ✅ Patron **ordre ⇄ retour + timeout + latch + alarme** — **le modèle existe déjà dans le projet** (à l'échelle de la ligne, pas de l'axe) |
| Commande envoyée, **frein non confirmé ouvert**, puissance engagée | ⚠️ 500 ms → `ErrorId bit0` + latched + `RestartInhibit` — **mais coupure NON couplée et SANS alarme bandeau M1/M2** | `FB_WinchOutputInterlock.st:494-519` | 🔴 **Corrigé après contre-expertise** : (a) ce retour est le **contacteur de commande du frein, PAS le frein physique** (`REGISTRE_Suivi_MiseEnService_20260902.md:384,398`) ; (b) si `PowerContactorEngaged = FALSE`, la gate **désarme** le watchdog (`FB_WinchOutputInterlock.st:148-149`) et la coupure vient de `FB_Safety_Winch.st:552-553` `SafeStop := TRUE` → **ma première attribution était fausse** ; (c) aucun libellé bandeau équivalent à celui de M3 (`FB_Hmi_BannerFormatter.st:1038`) |
| Commande envoyée, frein ouvert, **aucun mouvement** (les 2 treuils pareillement) | ✅ 3 s → `ErrorID 16` → **SafeStop seul** (pas de PowerCutOff) | `FB_Safety_Winch.st:437-447` + `PRG_06:145` (`ErrorNoMovement` → `M1SafeStopSafetyInfo`) + contrat `TASK_CONTRACT_T288…yaml:6-10` | ⚠️ **Indirect** : (a) passe par le **codeur** ; (b) alarme **gâtée par `EncM1Valid`** (`FB_Hmi_BannerFormatter.st:944`) ; (c) **s'auto-masque** dès que la charge bouge (`FB_Safety_Winch.st:441` + `:240-241`) ; (d) éteint pendant `RefWindowActive` (homing ∨ benne ∨ settle ∨ `NOT CrossCheckEnable`) |
| **1 contacteur de vitesse** ne ferme pas, les autres oui | ❌ **aucune détection possible** | retour collectif tout-ou-rien (AF-06 §E/S `:457/:459`) | 🔴 **Trou réel** — non instrumentable sans E/S supplémentaire |
| **1 contacteur** collé (ne retombe pas) | ✅ 3 s → Meca B (SafeStop + PowerCutOff) | `FB_Safety_Winch.st:341-343`, `:481-484` | ⚠️ Ne dit **pas lequel** (retour collectif) |
| Direction/relais de sens non engagé, paliers OK | ❌ aucune détection directe | — | 🔴 Trou réel (même famille que ci-dessus) |

**Verdict §5** : **le trou est CONFIRMÉ** — il n'existe **aucune** confrontation « ordre contacteur émis ⇄ retour contacteur réel » **par axe**, et **aucune** vue par contacteur. Le cas terrain n'est couvert qu'**indirectement** (absence de mouvement / timeout frein), avec une étiquette de cause inexacte.

### 5.d — **Tous** les usages existants du retour collectif (aucun n'est un détecteur de discordance)

> Vérification exhaustive demandée par le brief (« ne pas conclure au trou avant d'avoir cherché partout »). Les 8 usages recensés sont **tous** des **permissifs / préconditions**, ou l'usage **inverse** (contacteur collé). **Aucun** ne confronte un **ordre émis** à son **retour** pour produire un défaut.

| # | Usage | Preuve | Rôle | Couvre « commande émise / contacteur immobile » ? |
|---|---|---|---|---|
| 1 | Comptage du temps mort D18 (autorisation d'inversion) | `FB_Winch.st:198` (`DirectionInterlock Enable := (StepNumber = 0) AND Sensors.ContactorsAllOff`) | permissif | ❌ non |
| 2 | Champs `ContactorsCheck.Command/Feedback` | `FB_Winch.st:314-315` (et `:151-152` au gate) | champs alimentés, `Stuck*` non exploités (`:317-318`) | ❌ non |
| 3 | Maintien de sens §3bis : attente de retombée | `FB_WinchOutputInterlock.st:309-317` | permissif + latch T_max (sens **inverse**) | ❌ non |
| 4 | `WinchStandstill`, armement Méca A, Méca B, désarmement du timer Méca E | `FB_Safety_Winch.st:263-265`, `:329`, `:341`, `:404` | permissifs / sécurités d'**arrêt** | ❌ non |
| 5 | Arrêt mécanique confirmé pour **bascule de mode** | `FB_Modes.st:226-229`, motif `:271-272` (`'Chgt mode refuse : contacteur M1'`) | précondition de mode | ❌ non |
| 6 | Préflight de démarrage (16 bits) | `FB_Acquisition_Preflight.st:71-72` (`bit3/bit4 = contacteurs M1/M2 retombés`), publié `PRG_07_Supervision.st:444` | précondition au démarrage, **hors ligne** (constat T356 E6 : aucun routage safety, aucun message) | ❌ non |
| 7 | Composite « arrêt mécanique machine » (homing) | `PRG_02_Acquisition.st:519-522` (`MachineHomingMechanicalStopOk`) | précondition homing | ❌ non |
| 8 | Barrière de permis d'entrée de `FB_WinchDirectionInterlock` / checklist homing | `FB_Winch.st:198`, `ST_HomingChecklist` (`Step4_ContactorsReleased`) | permissif | ❌ non |

➡️ **Conclusion 5.d** : sur 8 usages, **zéro** n'émet de défaut « ordre émis ⇄ aucun contacteur fermé ». Le trou de §5.c est donc confirmé **par épuisement**, pas par intuition.

### 5.e — Voie **indirecte** possible (à connaître avant de conclure « aucune détection »)

`FB_Winch` bride le palier **par axe** à partir d'une **bande de vitesse vivante** issue du codeur : `FB_Winch.st:230-244` (`SpeedGuardLimited`, `RequestedStep := MeasuredSpeedBand`), bande calculée par `FB_WinchLoadEstimator.st:97-128` (hystérésis) et câblée par axe `PRG_04_Treuils_Benne.st:1425` / `:1507`.

- Conséquence : si **une seule** voie matérielle lâche **partiellement** (l'axe tourne moins vite que le palier commandé, bande ≥ 1), son palier peut être bridé → **divergence de commandes** M1 ≠ M2 → `FB_SyncContactor` **peut** déclencher (500 ms → SafeStop). Couverture **indirecte et étroite**.
- ⚠️ Elle **ne joue pas** si l'axe ne bouge **pas du tout** : bande = 0 → la 2ᵉ branche (`:240`) exige `MeasuredSpeedBand >= 1`, la 1ʳᵉ (`:235-239`) n'agit que si `SpeedGuardReady = FALSE`. Les deux axes gardent alors **la même commande** → `FB_SyncContactor` **muet**, seul `ErrorID 16` (3 s) reste.
- 🚩 Conclusion : même la panne **asymétrique** « contacteurs qui ne ferment pas » n'est **pas** détectée par le bloc de concordance dans le cas le plus franc (aucun mouvement). Le diagnostic de §5.c n'est donc pas affaibli — il est **confirmé**.
- ⚠️ **Réserve supplémentaire** : les seuils `SpeedBandMaxMps` qui pilotent cette bande sont aujourd'hui des **valeurs théoriques saisies à la main**, sans calibration automatique (constat spec `AF_Partie-10_Fonction_Winch_v2.1.md:528-533`, §7.3 « TBD ») → cette voie indirecte repose sur des seuils **non validés en charge réelle**. À ne pas présenter comme une couverture fiable.

### 5.f — Décisions **client déjà arbitrées** qui encadrent toute correction future

> ⚠️ Indispensable avant de proposer quoi que ce soit : le projet a **déjà tranché** deux fois contre l'usage du retour contacteur, avec risque assumé par le client.

| Décision | Preuve | Contenu | Impact sur T370 |
|---|---|---|---|
| Couplage frein ⇄ contacteur sur la **commande**, pas sur la confirmation terrain | `AF_Partie-10_Fonction_Winch_v2.1.md:380-384` (§2bis) | `BrakeCmd := RelayFwd OR RelayRev` ; *« le couplage est désormais sur la **commande** … pas sur leur confirmation terrain. Le risque théorique (frein ouvert avant engagement mécanique réel du contacteur) est **jugé acceptable par le client** »* | Ajouter une surveillance commande/retour **ne doit pas** contredire cette doctrine : elle vise un **défaut de détection**, pas un re-couplage du frein |
| Tempo de reprise basée sur le retour **frein**, pas contacteur | `AF_Partie-10_Fonction_Winch_v2.1.md:386-399` (§2ter) | `RestartDelay` déclenché par `NOT BrakeFeedback` (retour physique frein), `T#1500ms` | Le retour contacteur a déjà été jugé **moins fiable** que le retour frein à cet endroit |
| Doctrine « contacteur confirmé avant ouverture frein » → **abandonnée** | `AF_Partie-10_Fonction_Winch_v2.1.md:513-519` (§7.2) | Implémentée le 2026-08-06 matin, **remplacée l'après-midi même** ; conservée comme historique *« périmé en pratique »* | Toute proposition de réintroduire un couplage sur le feedback doit être **challengée** (décision déjà prise une fois contre) |
| `FB_Brake` (double vérif retour contacteur) **retiré** côté treuils | `AF_Partie-10_Fonction_Winch_v2.1.md:509` · `ST_WinchFinalInterlockRequest.st:16` (« (retrait FB_Brake) ») | Seul le retour **brut** est consommé | Le seul « ordre ⇄ retour » du projet n'existe plus côté treuils |
| ⚠️ Incohérence documentaire | `AF_Partie-03_Contrats_Composants_v2.3.md:231` | Le catalogue des composants décrit encore `FB_Brake` comme *« double vérif retour contacteur »* pour les treuils | À corriger dans un lot documentaire (hors scope T370) |

### 5.g — 📋 Liste des causes de discordance à distinguer (2ᵉ point du mail GCAM)

> **Ce que le retour collectif permet de distinguer, en toute rigueur : 2 états seulement** — « aucun contacteur fermé » vs « au moins un fermé » (`Mx_ContactorsReleased_DI`, `AF_Partie-06…v2.4.md:457,459` ; polarité NO, `TRUE` = relâchés). **Ni lequel, ni combien.**

| # | Cause physique | Détectée aujourd'hui ? | Par quoi (preuve) | Ce qui manque pour la distinguer |
|---|---|---|---|---|
| 1 | **Contacteur collé** (ne retombe pas) | 🟡 oui, sans dire lequel | `Meca B` 3 s → SafeStop + PowerCutOff (`FB_Safety_Winch.st:341-343`, `:481-484`) ; latch `SENSE_DROP_TIMEOUT` 400 ms en transitoire (`FB_WinchOutputInterlock.st:304-318`, `:372`) | retour **par contacteur** |
| 2 | **Bobine grillée / circuit bobine ouvert** | 🔴 non (indirect 3 s) | `ErrorID 16` si codeur dispo + frein ouvert (`FB_Safety_Winch.st:437-447`) | retour par contacteur **+** mesure de courant/tension bobine |
| 3 | **Fusible de commande sauté** | 🔴 non | — | idem ; aucun signal de fusible dans le projet (grep `fusible` = 0 dans `CODE/`) |
| 4 | **Alimentation puissance / 24 V coupée** | ⚠️ partiellement | watchdog frein 500 ms (`FB_WinchOutputInterlock.st:494-519`) ; `PowerContactorEngaged_DI` (`AF-06:450`) pour la chaîne AU | étiquetage **« frein »** au lieu de « puissance » ; pas de contrôle de la source 24 V |
| 5 | **Contacteur qui ne ferme pas** (mécanique/ressort) | 🔴 non | — | **retour par contacteur** (ou retour collectif exploité, cf. §8.b) |
| 6 | **Contact auxiliaire défaillant / fil coupé / voie DI collée** | 🔴 non — et **indiscernable** d'une vraie panne | granularité **module, pas canal** (`AF-06:408-411`) | qualification de la voie (test d'impulsion, double canal) → sinon une détection naïve produira une **fausse alarme** |
| 7 | **Circuit rotorique / « résistances contacteurs »** coupé (si démarrage résistif — **à confirmer**) | 🔴 non | spec muette (`AF-06:404` seule mention) | confirmation électrotechnique puis signal dédié |
| 8 | **Relais/contacteur de sens** non engagé | 🔴 non (couvert par 5/6 si le sens est dans la boucle — **ambiguïté §8.a**) | — | même besoin que 5 |
| 9 | **Palier partiellement engagé** (1 fermé sur N attendus) | 🔴 **impossible** avec le collectif | — | retour **par contacteur** (E/S) |
| 10 | **Commande non émise par le PLC** (asymétrie logique) | 🟢 oui | `FB_SyncContactor` niveaux 1/2 (`FB_SyncContactor.st:104-109`, `:140-145`) → `PRG_04:712-716` | — |
| 11 | **Carte DI HS** (retour collectif non fiable) | 🟡 globalement, sans la voie | `InputModules.Fault` → SafeStop des **2** treuils (`PRG_04:702-716`) | diagnostic **par canal** |
| 12 | **Faux positif transitoire** (retour « au repos » pendant une commutation) | ⚠️ non comptabilisé ; aucun filtre dédié | risque identifié `CONTACTEURS_DIAG_2026-08-31.md:158-163` | **mesure du temps de retombée/fermeture physique** (exigence T288 phase 3) avant de choisir un seuil |

| 13 | **Carte de SORTIE à relais non RUNNING** (`VH_0008ER` / `VH_0008ER_1`) | 🟢 **oui, correctement** | `PRG_02_Acquisition.st:213-216` → `PRG_04:713/715` SafeStop + `FB_Hmi_BannerFormatter.st:887-891` `[IO] Defaut module VH0008ER` | — *(ajouté après contre-expertise : cette famille produit le symptôme terrain et est déjà couverte/alarmée)* |
| 14 | **Contacteur de ligne (KM_Power) non réengagé** | 🟢 oui, à l'armement | `FB_Safety_EmergencyManagement` (confirmation 2 s + latch + `[AU] ErrorID:02`) · `FB_Safety_Winch.st:552-553` (perte en cours de marche → SafeStop) | — *(idem)* |

> 🎯 **Discriminateurs DÉJÀ câblés, à exploiter avant d'ajouter quoi que ce soit** (contre-expertise) : ① `PowerContactorEngaged_DI` → départage « amont absent » vs « amont présent mais rien ne ferme » ; ② les 2 signaux sont **déjà dans le même FB** (`FB_Safety_Winch.st:32-33` : retour contacteurs + retour frein) ; ③ **séparation temporelle 500 ms vs 3 s** (`FB_WinchOutputInterlock.st:494` vs `FB_Safety_Winch.st:59`).
> ⚠️ **Piège de cause commune** : `Mx_BrakeIsOpen_DI` est le retour du **contacteur de commande du frein**, pas du frein physique (`REGISTRE_Suivi_MiseEnService_20260902.md:384,398`) → 2 voies **mono-canal** ⇒ une défaillance d'alimentation commune les aveugle **ensemble**.
> 💡 Capacité matérielle : la voie `VH_0800END · 5` est **présente mais non documentée/non nommée** (`AF_Partie-06…v2.4.md:473`) — piste de voie libre à faire confirmer par l'humain.

➡️ **Réponse au mail** : sur 14 causes candidates, **3 sont correctement attribuées** (#10, #13, #14), **3 le sont indirectement avec une étiquette inexacte** (#1, #4, #11), **8 ne sont pas distinguables** avec l'instrumentation actuelle — dont **5 exigent du matériel** (retour par contacteur / mesure courant) et **2 exigent une décision de qualification capteur**.

---

## 6. 📊 Arbre vertical des hypothèses (flux de données) — commande vs retour

```text
[Commande opérateur] Joystick/boutons
   → FB_Winch M1/M2 (§5) : RelayFwd/RelayRev + Contactor1..4          ✅ disponibles  (FB_Winch.st:295-309)
   → FB_WinchOutputInterlock (barrière finale)                        ✅ disponibles
   → PRG_06 §2quater FB_ContactorProtector (anti-chatter 400 ms)      ✅ (PRG_06:286-304 ; vecteurs de la barrière = :167-172 / :233-238)
   → FB_SyncContactor  ◄── compare M1 vs M2 (COMMANDES)               ⚠️ (PRG_06:345-350)
   → Sorties DQ : M1_RelayAscent_RQ / M1_SpeedContactor_1..4_DQ       ✅ (PRG_06:369-384)
   ↓
[HARDWARE : bobines, fusibles, alim 24 V, câblage puissance]
   ↓
[Retour physique COLLECTIF] M1_ContactorsReleased_DI (1 bit)          ❌ NON CONFRONTÉ à l'ordre
   → PRG_02 §1 HwReal/HwIn                                            ✅ (PRG_02:145)
   → PRG_04 §7 WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff     ✅ (PRG_04:1602)
   → FB_WinchOutputInterlock / FB_Safety_Winch                        ⚠️ usages indirects (Meca B, SenseHold, D18)
   → ❌ jamais lus par FB_SyncContactor (L2, CONTACTEURS_SOLUTION_20260831.md:122)
```

**Résumé une ligne** : `[Ordre contacteur M1:BOOL=1] → [Retour collectif M1_ContactorsReleased_DI:BOOL=1] → ❌ AUCUN comparateur par axe (seul M1⇄M2 de commandes existe)`

---

## 7. 🏁 Conclusion

- **Cause racine (diagnostic)** : la chaîne de surveillance contacteurs est **transverse et symétrique** (`FB_SyncContactor` = M1 ⇄ M2, sur des **commandes**), alors que le besoin client/terrain est **par axe** (`ordre émis` ⇄ `retour du même axe`). Un défaut **commun aux deux treuils** — précisément le cas « l'automate envoie, les contacteurs ne bougent pas » — n'a **aucun** point de détection dédié. **Liste des effets de bord qui peuvent aujourd'hui faire échouer le mouvement** (complétée après contre-expertise) : ① codeur immobile après 3 s (`ErrorID 16`) ; ② frein non confirmé après 500 ms (watchdog, **non couplé, sans alarme**) ; ③ **carte relais de sortie non RUNNING** → SafeStop + `[IO] Defaut module VH0008ER` ; ④ **perte `PowerContactorEngaged`** → `FB_Safety_Winch.st:552-553` `SafeStop := TRUE` ; ⑤ contacteurs non retombés au repos (Meca B, 3 s).
- **Hypothèse de l'orchestrateur** : ✅ **CONFIRMÉE dans sa substance**, ⚠️ **CORRIGÉE sur deux points** :
  1. Ce n'est pas seulement « les deux retournent FALSE » : `FB_SyncContactor` **ne lit aucun retour** — les deux instances reçoivent les **commandes** PLC (`PRG_04:648-659`, `PRG_06:345-350`). La comparaison est **commande M1 ⇄ commande M2**, pas « commande ⇄ contacteur ».
  2. Le trou n'est pas absolu : `ErrorID 16` (T288 phase 1, **déjà livré et validé simulation le 2026-09-15**) couvre l'absence de mouvement sous commande **indépendamment** du retour collectif, et le watchdog frein (500 ms) couvre la perte d'alimentation. Le manque est la **discrimination de la cause contacteur** et la **vue par contacteur**.
- **Statut** : **diagnostic remis — correction NON engagée** (brief §5 : aucun code dans ce lot).

---

## 8. 🛠️ Proposition de correction — **esquisse, aucun code**

> ⚠️ **Aucune décision d'implémentation n'est prise ici.** Cette section est un support d'arbitrage (brief §5 : esquisse à valider avant tout code).

### 8.a — Ce que le matériel permet / ne permet pas (à trancher AVANT tout design)

| Question | État actuel | Impact |
|---|---|---|
| Quels contacteurs sont réellement bouclés dans `Mx_ContactorsReleased_DI` ? | **AMBIGU** : `AF_Partie-06…v2.4.md:457,459` dit *« Contacteurs **sens** Mx relâchés »*, le code suppose *« sens + C1..C4 tous retombés »* (`ST_fbWinch_Sensors.st:21`, `FB_SimBench.st:446-447`) | Détermine si une panne d'un contacteur **de vitesse** est seulement *visible*. **Vérification au bornier requise (humain)** |
| Y a-t-il des voies DI libres pour un retour par contacteur ? | **NON** : les 5 cartes physiques sont pleines en DI — `Local_Digital_IO` (DI8 **tous utilisés**, DO libres), `VH_0800END` (DI8 pleins), `VH_0808ETP` (DI8 pleins) (`AF_Partie-06…v2.4.md:400-406`) | Un retour par contacteur = **extension matérielle**, pas du logiciel |
| Une voie DI « qui ment » est-elle détectable ? | **NON** : granularité **module, pas canal** — `GetDeviceState()` ne dit pas *quelle* voie mente, `FB_Input.ChannelOk` n'a **aucune source par canal** (`AF_Partie-06…v2.4.md:408-411`) | Toute détection basée sur ce bit est **mono-canal non qualifiée** → la réaction doit distinguer **doute capteur** et **défaut puissance** (cf. T288 phase 3) |
| Le banc sait-il simuler cette panne ? | ❌ Non : `FB_SimBench.st:448-450` / `:473-475` calculent le retour **à partir des commandes** → discordance **structurellement impossible** en simulation | Un **stimulus d'injection** serait nécessaire. ✅ Le patron existe déjà pour d'autres retards (`FB_SimBench.st:426-445` délais frein opt-in ; `FB_Sim_Safety.st:61-72` collage/retombée du contacteur de chaîne AU, 100 ms/50 ms) → l'extension est **techniquement plausible**, à cadrer |
| Nature exacte des sorties **« résistances contacteurs M1/M2 »** (`VH_0808ETP`, DO8) | ❓ **NON DOCUMENTÉ** : la spec ne cite la chose qu'une fois, sans détail (`AF_Partie-06…v2.4.md:404`) ; aucun modèle rotorique/résistif dans `DOC/AF/AF_Partie-10*` (grep = 0) | **À confirmer par l'électrotechnicien** : si les paliers commutent un **démarrage rotorique résistif**, alors une **résistance ou un circuit rotorique coupé** produit le **même symptôme** qu'un contacteur qui ne ferme pas — cause à ajouter à la liste §5.g (#7) |

### 8.b — Où placer la détection (sans dupliquer `FB_SyncContactor`) — **révisé après contre-expertise**

> 🚨 **2 contraintes bloquantes découvertes par la contre-expertise, vérifiées sur disque :**

**① `FB_Safety_Winch` n'a PLUS DE PLACE dans son bitfield.** `instCauses` est déclaré `ARRAY[0..15]` et les **16 index sont tous consommés** (`FB_Safety_Winch.st:269` → `:445`, miroirs `:494-509`) ; `FB_FaultCore` porte un `WORD`. Il n'existe donc **pas** de « nouvelle cause dédiée » à ajouter telle quelle dans ce FB (l'arbitrage dépôt est explicite : *« ne pas créer un 17ᵉ bit caché »*).
**② Ce chemin a DÉJÀ été implémenté… puis INTÉGRALEMENT REVERTÉ.** REX décisif, cité verbatim au catalogue (`DOC/WFLOW/TASKS.yaml`, entrée T224) : un **chemin rapide « contacteur commandé mais non retombé/immobile »** a été livré en 6 commits puis annulé par le revert `263fae18` (2026-09-02) : *« Regression : impossible de monter, ArmingPermit quasi toujours a 1 (inutile), et des blocages banc lies au chemin rapide NoMovement (**`M1_ContactorsReleased_DI` fige TRUE sans DI reel**). […] `TonNoMoveContactor` et `NoMovementContactorSuspect` **retires de FB_Safety_Winch (FB DE SECURITE)** »* — avec 3 leçons inscrites comme contraintes : *(2) **ne jamais fonder une logique sur un DI potentiellement figé***. Détail du code annulé : `DOC/WFLOW/AUDITS/DESIGN/DIAGNOSTIC_T224_ARMINGPERMIT_20260921.md:350-424`.
➡️ **Conséquence** : toute réintroduction d'une détection fondée sur `Mx_ContactorsReleased_DI` dans un FB de sécurité doit **d'abord** traiter la **vivacité/qualité du DI** (sinon on rejoue exactement l'échec T228).

| Option | Emplacement | Pour | Contre |
|---|---|---|---|
| **A** | `FB_Safety_Winch` (nouvelle cause) | Propriétaire déjà déclaré du « contacteur collé » (`FB_Safety_Winch.st:480-484`) ; reçoit déjà `MovementCommanded` (CMD) et `FwdRevSpeedFeedbackOff` (HW) | 🔴 **Infaisable en l'état** : bitfield 16/16 saturé (①) + REX de revert (②) + POU **safety C4** |
| **B** ✅ *(nouvelle, la moins coûteuse)* | **Ré-armer le comparateur PAR AXE déjà câblé** : `FB_Winch.ContactorsCheck` | `ST_ContactorCheck.st:11-14` définit **exactement** le besoin (`StuckOpen` = *« commande ON mais retour OFF depuis trop longtemps »*) ; les **2 opérandes sont déjà câblés** (`FB_Winch.st:314-315`) ; le TON existe (`:316 TonContactorsDropped`) ; le timeout existe (`ST_fbWinch_Cfg.st:28` `ContactorFeedbackTimeout := T#500ms`) ; le **bypass est déclaré** (`FB_Winch.st:34` `BypassContactorCheck`, **jamais lu** aujourd'hui) | Implique de **désactiver une neutralisation volontaire** (« Phase 0 », `FB_Winch.st:317-318`) → décision safety explicite + garde de vivacité du DI (②) ; l'escalade doit être faite **hors** `FB_Winch` |
| **C** | `FB_WinchOutputInterlock` | Au plus près des DQ ; dispose déjà des 2 signaux + du patron `BrakeTimeout` (`:494-519`) | Ajoute une responsabilité à une barrière finale déjà dense ; même problème de classe d'arrêt non couplée |
| **D** | Nouveau FB transverse par axe (patron `FB_Brake`, **actif et prouvé** sur le frein M3 : `FB_Brake.st:110-121`, timeout `:24`, cause nommée `:126-128`) | Respecte « 1 FB = 1 responsabilité » ; reprend un patron **industrialisé** | Nouveau POU + câblage PRG_04/PRG_06 → plus lourd |
| ❌ | `FB_SyncContactor` | — | **À écarter** : sa responsabilité est la **symétrie M1/M2** ; y injecter un retour par axe casse la sémantique du bloc et de `ST_SyncContactorDiag` |

### 8.c — Architecture cible **déjà arbitrée** par le dépôt (contraintes imposées, à respecter)

**Revue formelle T288 phase 2** — `DOC/WFLOW/REVIEWS/REVIEW_T288_PHASE2_REGISTRE_ERREURS_20260915.md` :
`Verdict : **MAJOR — pas prêt à coder.** Recommandation : architecture B, un **registre d'erreurs dédié aux treuils** ; l'extension globale de `ST_Fault/FB_FaultCore` est hors proportion (≥ 32 consommateurs).`

| Contrainte imposée par la revue | Ligne | Conséquence pour T370 |
|---|---|---|
| `ErrorID:16` **reste** « absence de mouvement », **fondée sur la position codeur** | `:11` | Ne pas détourner ErrorID 16 pour la discordance contacteur |
| La discordance commande/retour contacteurs doit avoir **un identifiant et un texte distincts, sans garde codeur** | `:12` | La détection doit fonctionner **codeur indisponible** — c'est précisément l'inverse de la cause 15 actuelle |
| Le retour est **collectif** : aucun message ne doit prétendre identifier **direction, vitesse ou frein** | `:13` | Interdit de promettre « contacteur K2 » au bandeau (cf. §8.d) |
| Deux causes peuvent survenir **simultanément** : **ne pas les fusionner** | `:14` | Encodeur immobile **et** aucun contacteur fermé = **2 causes distinctes** |
| Le registre doit définir : *liveness, latch, Reset sur front, Enable, BypassGlobal, SafeStop, PowerCutOff* | `:15` | Cadrage obligatoire avant toute ligne de code |
| L'IHM doit afficher la discordance **sans** la conditionner à `EncM1Valid`/`EncM2Valid` | `:16` | — |
| **Délai 3 s conservé provisoirement** ; toute réduction attend une **mesure terrain** | `:17` | Le seuil ne se devine pas : il se mesure |
| 🚨 **La phase 1 n'est PAS la solution finale** : retirer `NOT FwdRevSpeedFeedbackOff` de `TonNoMovement` *« devra être annulée ou réécrite dans le plan d'implémentation afin de séparer les deux causes »* | `:21-23` | ⚠️ **Le comportement actuel (`ErrorID 16` insensible au retour collectif) est un état PROVISOIRE arbitré comme non final** — c'est l'écart exact entre T288 phase 1 (livrée) et le besoin T370 |

➡️ Conséquence directe — **reformulée après contre-expertise sécurité** : la demande GCAM n'est **PAS** « déjà satisfaite dans l'esprit » par `ErrorID 16`. Ce qui est satisfait, c'est **uniquement** la *réaction* (arrêt après 3 s) sur un **prédicat différent** (position codeur), avec **4 exclusions** et **aucune discrimination de cause**. La phrase initiale de cette fiche était **une sur-promesse** : elle risquait de clore le chantier. L'arbitrage dépôt dit l'inverse — **les deux causes doivent être séparées** — donc T370 n'est pas une option : c'est **une dette déjà instruite**.

### 8.d — Points de vigilance pour le lot suivant

1. **Temps physiques avant alarme** : le retour collectif est **mono-voie** ; un faux « au repos » pendant un transitoire de commutation est possible (risque déjà identifié, `CONTACTEURS_DIAG_2026-08-31.md:158-163`). Le seuil doit venir d'une **mesure** (phase 3), pas d'une valeur devinée.
2. **Doute capteur vs défaut puissance** : une voie DI collée / fil coupé est **indiscernable** d'un vrai défaut avec les signaux actuels → prévoir deux niveaux (avertissement maintenance vs arrêt).
3. **Polarité/étiquetage maintenance** : ne pas réutiliser le libellé `ErrorID:16 - discordance commande/retour/mouvement` (`FB_Hmi_BannerFormatter.st:945,993`) pour une cause contacteur — le brief client demande justement à **distinguer** les causes.
4. **Documentation à corriger** dans le lot suivant : `FB_SyncContactor_v1.0.md:27-28` (prétend détecter collages de contacteur / bobines grillées) et les commentaires `[HW] Feedback/Ordre` de `FB_SyncContactor.st:27-30` / `FB_WinchSync.st:33-36`.
5. **Règle `fix:` + `guard:`** : tout correctif ultérieur doit livrer un gate de régression (patron existant : `G501_check_t288_no_movement_feedback.py`), plus un stimulus de banc capable de simuler « commande émise / contacteur immobile ».

---

## 9. ✅ Vérification de la correction / non-régression

> ⚠️ **Non applicable dans ce lot** : aucune correction n'a été appliquée (brief §5 et §6). Aucun bundle, aucun gate, aucun test n'a été lancé — **un lot sans modification de `CODE/` ne produit ni bundle ni gate**.

- Tests à prévoir pour le lot de correction (proposition) : variantes du retour collectif (au repos / engagé) **par axe**, avec et sans frein confirmé ; non-régression `TC-P10-054/055` (T288 phase 1) ; `Meca B`, `FB_SyncContactor`, `ContactorStuck` inchangés.

---

## 10. 📝 Journal (chronologique)

- **2026-09-15** : mail client GCAM (discordance contacteurs, 3 s, causes multiples). → donne naissance à **T288 phase 1**, livrée et **validée en simulation** (`TASK_CONTRACT_T288…yaml:56-68`, exécutée par Codex).
- **2026-08-31** (antérieur) : audits `CONTACTEURS_DIAG` / `CONTACTEURS_SOLUTION` → lacune **L2** documentée (comparaison de commandes, feedback jamais câblé) + 4 propositions.
- **2026-09-21** : rappel terrain utilisateur ; ouverture **T370** (entrée `- id: T370`, `DOC/WFLOW/TASKS.yaml`) ; brief `BRIEF_T370_DISCORDANCE_CONTACTEURS.md`.
- **2026-09-21** : investigation lecture seule (ce document). Preuves : `FB_SyncContactor.st`, `FB_WinchSync.st`, `FB_Safety_Winch.st`, `FB_WinchOutputInterlock.st`, `FB_Winch.st`, `FB_Brake.st`, `PRG_04`, `PRG_06`, `PRG_02`, `FB_SimBench.st`, `G501…py`, T288, AF-06 E/S, AF-10 `FB_SyncContactor_v1.0.md`. **Zéro ligne de `CODE/` modifiée, aucun commit.**

---

## 11. 📎 Preuves (table de vérification)

| Preuve | Fichier : ligne | Contenu |
|---|---|---|
| Détection = asymétrie M1/M2 | `CODE/H_TREUILS_BENNE/FB_SyncContactor.st:104-109` | `(RelayFwdM1 <> RelayFwdM2)`, `(Contactor1_M1 <> Contactor1_M2)` … |
| Instance amont ← commandes FB_Winch | `CODE/M_MAIN/PRG_04_Treuils_Benne.st:648-659` | `RelayFwdM1 := instWinchM1.RelayFwd`, `Contactor1_M1 := instWinchM1.Contactor1`… |
| Instance finale ← commandes DQ | `CODE/M_MAIN/PRG_06_Outputs.st:341-362` | `RelayFwdM1 := M1RelayFwd`, `Contactor1_M1 := M1SpeedContactor1`… |
| Aucun retour contacteur dans `PRG_06` | `CODE/M_MAIN/PRG_06_Outputs.st` (grep `HwIn.`) | Seuls `EmergencyChainClosed_DI`, `PowerContactorEngaged_DI`, `M3_PosTremie_DI` |
| Retour collectif 1 bit/treuil | `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_HwWinch.st:8,12` · `DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md:457,459` | `Mx_ContactorsReleased_DI` (`Local_Digital_IO · 0/2`, NO) |
| Retour collectif exclu de l'absence de mouvement | `TOOLS/AGENT_WORKFLOW/scripts/G501_check_t288_no_movement_feedback.py:32-36` | `if "FwdRevSpeedFeedbackOff" in timer: errors.append("retour collectif interdit…")` |
| Absence de mouvement (cause 15) | `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:437-447` | `MovementCommanded AND BrakeFeedback AND EncoderAvailable AND NOT PositionMovementDetected`, `PT := NoMovementTimeout` (3 s, `:59`) |
| Contacteur collé = Meca B | `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:341-343`, `:480-484` | `UncommandedActiveB`, `ContactorStuck := MecaBFaultLatched` |
| Watchdog frein 500 ms (ordre vs retour par axe) | `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st:494-519` | `BrakeTimeout(IN := BrakeCmd AND NOT BrakeFeedback…)`, `Reason := BRAKE_COMMAND_NOT_CONFIRMED` |
| Latch T_max relâchement (400 ms) | `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st:42-43`, `:304-318`, `:372` | `MaxSenseHoldTime`, `ContactorStuckLatched := TRUE`, `SENSE_DROP_TIMEOUT` |
| `ContactorsCheck` non alimenté | `CODE/H_TREUILS_BENNE/FB_Winch.st:314-318` | `StuckClosed := FALSE; // … detection produite par FB_Safety_Winch` |
| Ordre/retour par axe existe **pour M3/frein** | `CODE/A_COMMUN/FB_Brake.st:110-121` (+ cause `:126-128`, timeout `:24`) via `CODE/I_TRANSLATION/FB_Translation.st:304` · `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_WinchFinalInterlockRequest.st:16` « (retrait FB_Brake) » | `StuckClosed` / `StuckOpen` **actif sur M3**, **retiré pour les treuils** (patron de référence) |
| **Comparateur par axe DORMANT dans `FB_Winch`** | `CODE/A_COMMUN/_TYPES/ST_ContactorCheck.st:11-14` · `CODE/H_TREUILS_BENNE/FB_Winch.st:314-316` · `_TYPES/ST_fbWinch_Cfg.st:28` · `FB_Winch.st:34` | Opérandes **câblés**, TON neutralisé (`IN := FALSE`), bypass `BypassContactorCheck` **jamais lu** |
| **Cartes de SORTIE surveillées + alarmées** | `PRG_02_Acquisition.st:213-216` · `PRG_04_Treuils_Benne.st:713/715` · `FB_Hmi_BannerFormatter.st:887-891` · `ST_IOModuleDiag.st:17-18` | `Vh0008ErOk`/`Vh0008Er1Ok` (DO8 relais) → `InputModules.Fault` → SafeStop + `[IO] Defaut module` |
| **Patron ordre⇄retour du contacteur de ligne (AU)** | `CODE/B_AU_SECURITE/FB_Safety_EmergencyManagement.st` (`CST_ArmingConfirmTimeout = T#2s`) · `FB_Hmi_BannerFormatter.st:1126` | Confirmation KM_Power : timeout + latch + `[AU] ErrorID:02 - echec confirmation armement` |
| **REX décisif : tentative précédente REVERTÉE** | `DOC/WFLOW/TASKS.yaml` (entrée `T224`, verbatim) · `DOC/WFLOW/AUDITS/DESIGN/DIAGNOSTIC_T224_ARMINGPERMIT_20260921.md:350-424` | `TonNoMoveContactor` / `NoMovementContactorSuspect` retirés (`revert 263fae18`) : *« ne jamais fonder une logique sur un DI potentiellement figé »* |
| Bitfield `FB_Safety_Winch` **saturé** | `FB_Safety_Winch.st:269`→`:445` (`instCauses[0..15]` **tous consommés**), miroirs `:494-509` | Aucun « 17ᵉ bit » disponible (§8.b ①) |
| Retour frein = **contacteur**, pas le frein physique | `DOC/WFLOW/REGISTRES/REGISTRE_Suivi_MiseEnService_20260902.md:384,398` | *« Retour câblé = contacteur de commande »* / *« Limite connue : Retour = contacteur, PAS le frein physique »* |
| Lacune L2 déjà auditée | `DOC/WFLOW/AUDITS/CONTACTEURS_SOLUTION_20260831.md:122` | « Comparaison des COMMANDES, pas des feedbacks … reste invisible ici » |
| Simulation auto-cohérente | `CODE/L_SIMULATION/FB_SimBench.st:448-450` et `:473-475` | `Mx_ContactorsReleased_DI := NOT (RelayFwd OR RelayRev OR C1…C4)` (dérivé des **commandes**) |
| T288 phase 1 livrée/validée, phases 2-3 en attente | `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T288_DISCORDANCE_CONTACTEURS_ABSENCE_MOUVEMENT.yaml:6-10,56-68` · `DOC/WFLOW/TASKS.yaml` (entrée `T288`, champ `phases` — **citer par id, le fichier est édité en continu**) | AC1 : « quel que soit le retour collectif » ; Phase 2 « REVUE MAJOR », Phase 3 « A CADRER C4 » |
| **Phase 1 = provisoire, causes à séparer** | `DOC/WFLOW/REVIEWS/REVIEW_T288_PHASE2_REGISTRE_ERREURS_20260915.md:5,11-17,21-23` | « MAJOR — pas prêt à coder » ; *« devra être annulée ou réécrite … afin de séparer les deux causes »* |
| Décisions client contre l'usage du retour contacteur (frein/tempo) | `DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md:380-384`, `:386-399`, `:509`, `:513-519` | couplage sur la **commande**, risque assumé ; `FB_Brake` retiré côté treuils |
| Matériel : DI pleines, granularité **module** | `DOC/AF/AF_Partie-06_Acquisition_Qualification_IO_v2.4.md:400-406`, `:408-411` | 8 DI/carte toutes utilisées ; `FB_Input.ChannelOk` **sans source par canal** |
| Retour collectif utilisé **8 fois** en permissif/précondition | `FB_Winch.st:198` · `FB_WinchOutputInterlock.st:309-317` · `FB_Safety_Winch.st:263-265,329,341,404` · `FB_Modes.st:226-229,271` · `FB_Acquisition_Preflight.st:71-72` · `PRG_02:519-522` | **aucun** n'émet de défaut commande/retour (§5.d) |
| Voie indirecte via garde-fou vitesse | `FB_Winch.st:230-244` · `FB_WinchLoadEstimator.st:97-128` · `PRG_04:1425,1507` · seuils théoriques `AF_Partie-10…v2.1.md:528-533` | bride le palier par axe → divergence possible **seulement** si la bande ≥ 1 (§5.e) |
| Interface `FB_SyncContactor` partiellement morte | `FB_SyncContactor.st:23` (Reset jamais utilisé) · `:49,74,137` (`CommandsCoherent` non consommé) | contrat d'interface non honoré (§12.7) |
| Défaut d'attribution doc | `DOC/AF/AF_Partie-10_Fonction_Winch/FB_SyncContactor_v1.0.md:27-28` | « détecte les collages de contacteur, défaillances de bobines » — contredit par le code |
| Aucune brique de diag E/S de sortie | grep `OutputModules|OutputModuleFault` sur `CODE/` | **0 résultat** |

---

### ⚠️ Portée des références de ligne (T345 REX : ne jamais citer une ligne sans vérification)

Les numéros cités ici sont ceux de l'**arbre de travail 2026-09-21** (relus via les outils de recherche sur disque), **pas de `HEAD`**. Trois fichiers `CODE/` sont **modifiés et non commités par d'autres lots en cours** — je ne les ai pas touchés, mais leurs lignes peuvent différer de `HEAD` :
`CODE/G_CYCLE/FB_CycleMachineHoming.st`, `CODE/G_CYCLE/FB_CycleSemiAuto.st`, `CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st` (`git status --short`).
➡️ Les références `FB_Hmi_BannerFormatter.st:945/993/1068-1081` valent pour l'arbre de travail au 2026-09-21 ; toute relecture ultérieure doit être refaite sur le fichier réel.

---

## 12. 🚨 Hors scope constaté (devoir d'alerte — non corrigé)

1. **Spécification qui sur-promet** : `FB_SyncContactor_v1.0.md:27-28` (collages/bobines) et ses « tests » `TC-P10-SYNC-01..04` ne couvrent que la symétrie de commandes → écart spec/code à traiter dans un lot documentaire.
2. **Commentaires d'interface trompeurs** : `FB_SyncContactor.st:27-30`, `FB_WinchSync.st:33-36` (« `[HW] Feedback/Ordre` ») alors que seuls des ordres PLC y sont câblés.
3. **Libellé IHM générique** : `FB_Hmi_BannerFormatter.st:945,993` — `discordance commande/retour/mouvement` recouvre en réalité l'**absence de mouvement codeur** ; une panne contacteur y apparaît sous une étiquette imprécise pour la maintenance.
4. **Ambiguïté E/S non tranchée** (bloquante pour tout design) : `AF_Partie-06…v2.4.md:457,459` (« contacteurs **sens** ») vs code (`ST_fbWinch_Sensors.st:21`, `FB_SimBench.st:446-447`, « sens **+ C1..C4** »). **Vérification bornier requise.**
5. **Audit `CONTACTEURS_DIAG_2026-08-31.md:31-58` partiellement périmé** : il désigne le décodage « one-hot » comme bug racine ; `FB_Winch.st:295-309` porte depuis le correctif (« FIX contacteurs (audit CONTACTEURS_2026-08-31) : ré-émettre les contacteurs depuis FB_SpeedStep »). Ne pas rejouer ce diagnostic tel quel.
6. ❓ **Observation à vérifier (non conclue, hors périmètre T370)** — risque de **faux positif en homing** : la détection des instances de concordance s'arme sur `(BothCommanded OR SyncEnable)` (`FB_SyncContactor.st:104-109`), tandis que le commentaire de câblage affirme l'exclusion du homing via `WinchOutputCoupled` (`PRG_06_Outputs.st:254-258`). Si les **2 treuils sont effectivement commandés** pendant une séquence de homing couplée (T364 : `HX2_CLIMB_COUPLED`), `BothCommanded` peut rester TRUE et armer la comparaison **malgré** `WinchOutputCoupled = FALSE`. **Non vérifié** : je n'ai pas relevé les vecteurs de commande réels de la séquence de homing. À trancher par mesure/vérification dédiée (impact direct sur le seuil et le masquage de toute nouvelle détection).
7. **Interface de `FB_SyncContactor` partiellement morte** (auto-challenge, constat de lecture) :
   - `Reset` est **déclaré et documenté** « Acquittement defaut sur front » (`FB_SyncContactor.st:23`) mais **jamais utilisé** dans le corps du bloc (aucune détection de front) — pourtant les 2 appelants le câblent (`PRG_04:638`, `PRG_06:343`). Sans conséquence fonctionnelle connue (aucun état latché dans ce bloc : les 2 `TON` se réarment d'eux-mêmes), mais **contrat d'interface non honoré** → à nettoyer ou à documenter.
   - La sortie `CommandsCoherent` (`:49`, écrite `:74`/`:137`) n'est **consommée nulle part** dans `CODE/` (grep = 3 occurrences, toutes dans le fichier lui-même) → sortie morte.
   - ⚠️ Ces constats **ne changent pas** le verdict de §5, mais ils montrent que la doc du bloc (`FB_SyncContactor_v1.0.md`) décrit un comportement (Reset sur front, collages de contacteur) que le code ne porte pas.

---

## 13. ⚔️ Contre-expertises adversariales — verdicts, ce que j'accepte, ce que je réfute

> Deux contre-experts **lecture seule** (contexte frais, brief adverse avec liste de réfutation C1..C12 + thèses safety T1..T5) ont attaqué la version initiale de cette fiche. **Les deux rendent `MAJOR`.** Tous leurs points ci-dessous ont été **revérifiés par moi sur disque** avant d'être acceptés (aucune reprise aveugle).

### 13.a — Ce que j'**accepte** (corrigé dans cette fiche)

| # | Critique | Gravité | Preuve **revérifiée par moi** | Correction |
|---|---|---|---|---|
| 1 | 🔴 **H6 était FAUX** : « aucune brique de diagnostic E/S de sortie » | Majeur | `PRG_02_Acquisition.st:213-214/216` (cartes **de sortie** `VH_0008ER`/`VH_0008ER_1` surveillées, agrégées dans `InputModules.Fault`) · `PRG_04:713/715` (SafeStop) · `FB_Hmi_BannerFormatter.st:887-891` (alarme) — **piège de nommage** : la structure s'appelle `InputModules` (`ST_IOModuleDiag.st:17-18`) | H6 corrigée (§4) + causes #13/#14 ajoutées (§5.g) + §7 complété (5 chemins) |
| 2 | 🔴 **H3 « 0 mécanisme » se contredisait** avec ma propre §5.b | Majeur | Comparateurs **sens inverse** existants : `FB_Safety_Winch.st:341-343` (Meca B), `FB_WinchOutputInterlock.st:304-318` (latch §3bis) | H3 reformulée : **0** en sens *fermeture*, **2** en sens *relâchement*, **1 dormant**, **1 patron AU** |
| 3 | 🔴 **REX décisif omis** : ce chemin a **déjà été implémenté puis reverté** | Majeur | `DOC/WFLOW/TASKS.yaml` (entrée `T224`, verbatim : `TonNoMoveContactor`/`NoMovementContactorSuspect` retirés, revert `263fae18`) + `DIAGNOSTIC_T224_ARMINGPERMIT_20260921.md:350-424` | §8.b : contrainte ② « ne jamais fonder une logique sur un DI potentiellement figé » |
| 4 | 🔴 **`FB_Safety_Winch` n'a plus de place dans son bitfield** → mon option A était infaisable | Majeur | `FB_Safety_Winch.st:269`→`:445` : `instCauses[0..15]` **tous consommés** (miroirs `:494-509`) | §8.b ① + nouvelle **option B** (ré-armer le comparateur par axe existant) |
| 5 | 🔴 **Comparateur par axe DORMANT, opérandes déjà câblés** — mon §8.b omettait l'option la moins coûteuse | Majeur | `ST_ContactorCheck.st:11-14` (`StuckOpen` = *« commande ON mais retour OFF depuis trop longtemps »*) · `FB_Winch.st:314-315` (câblés) · `:316` `TonContactorsDropped(IN := FALSE)` · `ST_fbWinch_Cfg.st:28` (500 ms) · `FB_Winch.st:34` (bypass **jamais lu**) | §8.b option B |
| 6 | 🔴 **Attribution fausse du watchdog frein** (« alim coupée → 500 ms ») | Majeur | `FB_WinchOutputInterlock.st:148-149` (`BrakeTimeout(IN := FALSE)` à la gate) + `FB_Safety_Winch.st:552-553` (`NOT PowerContactorEngaged → SafeStop := TRUE`) + `REGISTRE…20260902.md:384,398` (retour = **contacteur**, pas le frein physique) | §5.c corrigée + §7 |
| 7 | 🟠 **Patron ordre⇄retour déjà actif au niveau ligne (KM_Power)** | Moyen | `FB_Safety_EmergencyManagement` (`CST_ArmingConfirmTimeout = T#2s`, `EmergencyArmingFailedCause`) · `FB_Hmi_BannerFormatter.st:1126` | §5.c + §11 + causes #14 |
| 8 | 🟠 **Aucune alarme bandeau pour le défaut barrière finale M1/M2**, alors que M3 en a une | Moyen | `FB_Hmi_BannerFormatter.st:1038` (M3) · `FB_WinchStateProjection.st:236` (M1/M2 `Error` **exclut** `InterlockM1.Fault.Error`) | §5.c + §12 |
| 9 | 🟠 **Watchdog frein : coupure per-axe NON couplée** (contrairement au SafeStop de discordance) | Moyen | `PRG_04:1105-1106` ne couvre que `SafeStop*_Raw` | §5.c + §12 (question ISO 13849 ouverte) |
| 10 | 🟠 **Alarme `ErrorID 16` gâtée par `EncM1Valid`** et **auto-masquage** dès que la charge bouge | Moyen | `FB_Hmi_BannerFormatter.st:944` · `FB_Safety_Winch.st:441` + `:240-241` | §5.c + §8.d |
| 11 | 🟡 **Diagnostics morts** : `ContactorStuck` sans consommateur, `CommandsCoherent` morte, `SpeedMismatch` configuré à 0 | Mineur | grep `ContactorStuck` (aucun consommateur hors producteurs) · `PRG_03_Modes_Cycle.st:246-247` (`SpeedMismatchThresholdMps := 0.0`) | §12 |
| 12 | 🟡 **Citations `TASKS.yaml`** invalides | Mineur **mais piégeux** | Le fichier est **édité en continu** : mtime 2026-09-21 12:13, `+97/−20` vs `HEAD` ; mes lignes, celles des 2 contre-experts et celles d'aujourd'hui **diffèrent toutes** | Citations remplacées par **ancre `id`** + avertissement (§3) |

### 13.b — Ce que je **réfute** (avec argument, pas par principe)

| Critique | Pourquoi je la réfute |
|---|---|
| « `TC-P10-055` est un **no-op** ⇒ le couple 054/055 ne prouve rien » | ✅ exact sur la redondance de 055 (le seul input qui diffère, `FwdRevSpeedFeedbackOff`, n'est pas consommé sur ce chemin) — ❌ **trop fort** sur la conclusion : `TC-P10-054` **est discriminant**. Si un lot réintroduisait `NOT FwdRevSpeedFeedbackOff` dans la garde, 054 (`FwdRevSpeedFeedbackOff := TRUE`) verrait le TON désarmé → `ASSERT_TRUE(fb.SafeStop)` **échouerait**. Le couple verrouille donc bien le comportement ; c'est 055 qui est superflu. Vérifié : `test_fb_safety_winch.st:52-125`, les deux cas **PASS** (`FB_Safety_Winch.json:17-22`) |
| « La validation T288 n'est pas fiable : le rapport montre 8 FAIL » | ⚠️ **Partiellement faux** : le rapport est bien `19 / 11 PASS / 8 FAIL` (`FB_Safety_Winch.json:138-142`) **mais les 2 cas T288 (054/055) sont PASS** (`:17-22`). Les 8 rouges sont **d'autres cas** (dette préexistante, hors T288). À traiter comme dette, pas comme invalidation de la phase 1 |
| « `ContactorStuck` (barrière) n'a aucun consommateur » ⇒ « diagnostic mort » | ✅ vrai sur `FB_WinchOutputInterlock.ContactorStuck`, mais le commentaire de code annonce explicitement une **phase ultérieure** (`FB_Winch.st:317` « re-alimentee a la phase suivante ») → c'est un **chantier inachevé documenté**, pas un oubli |
| « Le trou est un **trou de sécurité** avéré (PL) » (expert sécurité) | ⚠️ **Sur-promesse inverse** : le DI est **mono-voie sans diagnostic de couverture** ; aucun `PLr`/catégorie n'est déclaré dans le dépôt (NON VÉRIFIABLE) → c'est un trou d'**attribution de cause / vue par contacteur**, pas une barrière PL catégorisée. Ma §7 le dit déjà (« discrimination de cause »), la contre-expertise le confirme |

### 13.c — Constats safety **hors scope** ouverts par la contre-expertise (devoir d'alerte, non corrigés)

1. 🔴 **Fenêtre sans garde anti-dérive** : pendant « commande + frein ouvert + aucun mouvement », **Meca A est désarmée** (`FB_Safety_Winch.st:329` exige `NOT BrakeFeedback`) et **Meca C** exige `BenneHoldStillActive` (`:354`) → aucune garde de dérive n'est armée dans cette fenêtre.
2. 🔴 **Meca B = PowerCutOff sur un doute capteur** (`:341` → `:484` → `:523-525` → `:584` → `PRG_06:133/317`) : la politique « doute capteur ≠ défaut puissance » **n'existe pas** aujourd'hui (objectif explicitement ouvert : T288 phase 3).
3. 🔴 **Sauvegarde physique aveugle au cas symétrique** : `FB_SyncDeviation` compare **M1 vs M2** (`FB_WinchSync.st:144-145`) — un désynchronisme **symétrique** n'est vu par personne.
4. 🟠 **Watchdog frein** : coupure per-axe **non couplée** + **aucune alarme bandeau M1/M2** (asymétrie avec M3 `:1038`).
5. 🟡 **Exclusions de couverture non documentées** : `NOT CrossCheckEnable` / `BenneBusy` (levage unitaire) désarment la surveillance sans message.
6. 🟡 **8 cas rouges** du harnais `FB_Safety_Winch` (rapport sur disque) dont 7 non tracés — ⚠️ **les 2 cas T288 (054/055) sont PASS** : dette préexistante, pas invalidation de la phase 1.
7. 🔴 **`Meca A` / `Meca E` neutralisées hors couplage** (vérifié par moi) : `SyncOperationPermit := SyncEnable AND WinchSel = 0 AND NOT homing AND NOT benne AND NOT AX8..AX11 AND …` (`PRG_04_Treuils_Benne.st:426-446`) → `CrossCheckEnable := SyncOperationPermit` (`:936`, `:1006`) → `RefWindowActive` contient `NOT CrossCheckEnable` (`FB_Safety_Winch.st:248-249`) → **RAZ continue** des latchs Meca A/E (`:250-254`). En **levage unitaire** (`WinchSel ≠ 0`), en **activité benne** et pendant **AX8→AX11**, les gardes de dérive ne peuvent donc **pas** se poser — alors que le registre MES fait de **Meca A la SEULE** détection de patinage du frein (`REGISTRE…20260902.md:398`).
8. 🔴 **Commentaire contradictoire dans le code** : `PRG_04_Treuils_Benne.st:415-416` affirme *« MecaA et survitesse restent ACTIFS via CrossCheckEnable := SyncOperationPermit (inchangé) → aucun trou de sécurité »*, alors que le **même commentaire** `:409-410` écrit *« FB_Safety_Winch ouvre RefWindow sur `NOT CrossCheckEnable` (**RAZ continue MecaA/E**) »*. Les deux phrases ne peuvent pas être vraies ⇒ **agent suivant trompé**.
9. 🟠 **Couplage de bypass non documenté** : `BypassProcess` inclut `GVL_IHM.Commun.Bypass.SlackCable` (`PRG_04:975`, `:1043`) ⇒ **bypasser le mou de câble éteint aussi** la détection d'absence de mouvement (le terme `NOT BypassProcess` est dans la garde), et ce **dans tous les modes**.
10. 🔴 **Faux `ErrorID:16` déjà vécu terrain** (tracé au catalogue) : *« [M2] ErrorID:16 absence mouvement en debut de montee, ressenti quasi-immediat »* ⇒ l'étiquette `discordance commande/retour/mouvement` (`FB_Hmi_BannerFormatter.st:945,993`) **induit déjà la maintenance en erreur** aujourd'hui.
11. 🔴 **Banc d'intégration ROUGE sur disque** : `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/reports/WINCH_INTEG.txt:1-4` = `Error compiling source files: … FB_CycleSemiAuto.st:34:31: error: Undefined type 'E_CYCLEDEPTHSTOPMODE'` ; et `reports/FB_Safety_Winch.txt:1` = `Error: C++ compilation failed:`. ⚠️ `FB_CycleSemiAuto.st` fait partie des **3 fichiers `CODE/` modifiés non commités par un autre lot** (`git status`) — **je n'y ai pas touché**, mais le banc intégré **ne compile pas** ⇒ toute exigence de « test au banc » est aujourd'hui inopérante tant que ce n'est pas résolu (**à remonter à l'orchestrateur**).
12. 🟡 **Aucun `PLr`/catégorie déclaré** : `TOOLS/AGENT_WORKFLOW/docs/SAFETY_POLICY.md:5-8` = *« Le workflow agent ne certifie jamais une fonction de sécurité […] advisory-only »* ⇒ toute revendication de niveau de sécurité sur ce DI est **NON VÉRIFIABLE** (à faire trancher par l'automaticien).

### 13.d — Question humaine bloquante (consolidée par les **deux** contre-expertises)

> **Périmètre électrique exact de `M1/M2_ContactorsReleased_DI` au bornier** : quels contacts auxiliaires sont réellement **en série** dans la boucle (relais de sens **seuls** — `AF_Partie-06…v2.4.md:457/459` — ou sens **+ C1..C4**, comme le suppose le code `ST_fbWinch_Sensors.st:21` / `FB_SimBench.st:448-450`) ?
> **Et le jour de l'incident** : la sortie était-elle **physiquement active** au relais (LED carte `VH_0008ER`) et y avait-il une alarme `[IO] Defaut module VH0008ER` ou `[AU] ErrorID:02` ?
> **Conséquence** : la 1ʳᵉ partie détermine si la détection « commande ⇄ retour par axe » est **seulement possible** avec l'E/S existante (sinon → matériel, hors logiciel) ; la 2ᵉ **départage la cause racine** entre logiciel de détection, carte de sortie et câblage/bobine — donc si T288 ph.2/3 est bien le bon chantier.

### 13.e — ⚖️ Divergence entre les 2 experts — arbitrage par le disque

| Point | Expert technique | Expert sécurité | **Mon arbitrage (après relecture)** |
|---|---|---|---|
| Les cartes **de sortie** sont-elles diagnostiquées ? | ❌ **« non »** → il **réfute** mon H6 | ✅ « oui, aucune brique diag sorties » → il **valide** mon H6 | 🔴 **L'expert technique a raison** : `PRG_02_Acquisition.st:213-214` + `PRG_04:713/715` + alarme `FB_Hmi_BannerFormatter.st:887-891`. L'expert sécurité **a recopié mon grep** (`OutputModules` = 0) sans vérifier la **structure réelle** (`InputModules`). **H6 corrigée** ⇐ leçon : sur ce dépôt, un grep à 0 résultat **ne prouve pas** l'absence (piège de nommage) |
| Les tests 054/055 prouvent-ils AC1 ? | ❌ 055 = no-op ⇒ AC1 vérifié « littéralement » seulement | ⚠️ même constat | ✅ **Accepté avec nuance** : 055 est redondant, **mais 054 est discriminant** (voir §13.b) ⇒ AC1 est **partiellement** vérifié |
| Faut-il clore sur `ErrorID 16` ? | — | ❌ **non** (risque de clôture) | ✅ **Accepté** : §8.c reformulée (sur-promesse retirée) |

> 📌 **Leçon de méthode** : deux contre-experts en contexte frais ont produit **une divergence factuelle** — celle-ci n'a été tranchée qu'en **relisant le disque moi-même**. Aucun des deux rapports n'était reprenable tel quel, dans un sens comme dans l'autre.
