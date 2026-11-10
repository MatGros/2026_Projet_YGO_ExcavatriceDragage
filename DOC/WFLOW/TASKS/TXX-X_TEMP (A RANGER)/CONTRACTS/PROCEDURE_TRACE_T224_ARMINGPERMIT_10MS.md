# T224 — Procédure de trace 10 ms : `ArmingPermit`, disponibilité réelle et fenêtre des temps idle

> 🎯 **Objectif** : produire la preuve dynamique qui **tranche entre les familles de cause** du symptôme
> « joystick armé, aucun mouvement » et **mesure la fenêtre des temps idle** de la barrière finale —
> deux choses qu'**aucune trace du dépôt ne permet aujourd'hui** (voir §1).
> 🔒 **Le run est HUMAIN** (CODESYS). Cette procédure est *prête à exécuter* : **aucune écriture dans
> `CODE/`**, aucun forçage de variable de logique, aucun `Device.export` lu, aucun commit.
> 📄 Calquée sur `DOC/WFLOW/CONTRACTS/PROCEDURE_TRACE_T334_M3_DEUX_CHEMINS.md` (même doctrine).
> 📊 Diagnostic source : `DOC/WFLOW/AUDITS/DESIGN/DIAGNOSTIC_T224_ARMINGPERMIT_20260921.md` (Étape A, accepté)
> — **relevé mesuré** : **99 525 octets = 97,2 KiB, 836 lignes**.
> 🎫 Contrat : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T224_ARMINGPERMIT_ACTIONNEUR_PRET.yaml` (C4).
> 🗓️ Rédigé le 2026-09-21 par **DSH28** — ancrage `HEAD 25101c0b`.
> 📏 **Métadonnées — règle appliquée** : seules des tailles **mesurées** sont citées. La taille de la
> *présente* procédure n'est **volontairement pas figée ici** : toute édition la périme (piège
> d'auto-référence constaté en cours de rédaction). Elle se mesure par outil —
> `(Get-Item <fichier>).Length` en octets, `(Get-Content <fichier>).Count` en lignes — et par
> `git diff --numstat` pour distinguer les **insertions** des **suppressions** (exigence d'ajout seul).

---

## 1. Le but exact : rendre MESURABLE ce qui n'est aujourd'hui que DÉCLARÉ

Le diagnostic T224 a prouvé que le symptôme existe (`ArmingPermit = 1`, demande présente, aucun
mouvement, aucun défaut) mais **n'a pas pu prouver la CAUSE**, faute d'instrumentation. Trois constats
mesurés, à combler :

| Fait mesuré (Étape A) | Valeur | Conséquence |
|---|---|---|
| `RampTargetStep` — **la** variable qui reçoit `0` en famille 2 (`CADRAGE_T325…:11-12`) | **tracée dans 0 des 81 traces** | **famille 1 et famille 2 sont indiscernables** à ce jour |
| `ArmingAvailability` (6 bits + `BlockedReason`), `BlockedReason` | **0 occurrence sur 81 traces** | la disponibilité par axe×sens, **objet même de T224**, n'a aucune preuve terrain |
| `DeadTimePending` · `ContactorStuck` | **0 occurrence sur 81 traces** (et non publiés — §3) | les 2 temps idle de la barrière ne sont pas mesurables |
| Cadence réelle des traces existantes | **`Suivi_67` : 861 éch., dt min 98 / médian 101 / max 103 ms (6 valeurs distinctes)** — mesuré par DSH28 | **10× trop grossier** : une fenêtre de 500 ms ne donne que ~5 échantillons |

**Ce que la trace doit permettre de trancher** :

- **Famille 1** — commande **émise** puis **refusée par un interlock aval** (périmètre T224) :
  barrière finale en tempo, `PermitFinalBlocked` muet, permis **appliqué** plus restrictif que le permis
  **compté**.
- **Famille 2** — commande **jamais formée**, bloquée **en amont** (T325/D18) : `RampTargetStep = 0`.
- **Famille 3** — autre : état local du geste (3a), cause safety latchée (3b), verrou métier (3c),
  garde d'arbitrage (3d), **et cause physique/HW** (commande émise, contacteurs collés mais rien ne bouge).

**Et mesurer la fenêtre des temps idle** : durée réelle d'un refus par `RestartRequired` /
`DeadTimePending` / `RestartInhibit` / `ContactorStuck`, pour confronter les valeurs lues dans le code
(**500 ms** `RestartDelay`, **500/700 ms** `DeadTimeSameDir/OppositeDir`, **400 ms** `MaxSenseHoldTime`)
aux valeurs annoncées par les documents (**~1,5 s**) — écart de **facteur ×3** identifié en Étape A.

**Et documenter le FAUX VERT vu par l'exploitant** : établir, sur trace, que l'outil de diagnostic
affiche **vert** pendant le blocage — `AllConditionsMet = 1` (`ST_MotionChecklist.st:30`) alors qu'aucun
relais ne colle, `Step8_OutputInterlockOk` lisant `Fault.Error` et **jamais `State`**
(`FB_TroubleshootingView.st:577`). Le diagnostic a prouvé ce faux vert **sur pièces** (branches `:393-404`
et `:424-430` de `FB_WinchOutputInterlock.st` : **aucun `Reason`, aucun `Fault`** — et `State := READY`
en `:404`) ; la trace doit le prouver **en fonctionnement**, sinon le lot correctif part sans démonstration
du symptôme tel que vu par l'utilisateur (groupe **I**, §5.5).

---

## 2. Préconditions et réglage de la trace

- Projet CODESYS chargé ; **mode simulation (banc)** ou **site** — le préciser dans l'archive.
- En simulation : `GVL_Simulation.SimulationModeActive` activé par un **front `FALSE→TRUE` après** le
  démarrage de l'automate, puis vérifier **`GVL_Simulation.SimWinchActive = TRUE`** avant d'interpréter
  les DI (même piège que `PROCEDURE_TRACE_T334_M3_DEUX_CHEMINS.md:42-44`).
- ⚠️ **Ne PAS rejouer le piège T228** : ne pas forcer `M1/M2_ContactorsReleased_DI`. Le run doit rester
  dans la configuration **nominale** du banc ou du site. Si l'exploitant doit malgré tout forcer un DI
  (contrainte de banc connue, `REGISTRE_Suivi_MiseEnService_20260902.md:130`), **le consigner dans
  l'archive** : la trace devient non conclusive sur tout ce qui en dépend.
- Trace attachée à la **`MainTask` (10 ms)**, jamais à l'EtherCAT (4 ms) ni au CANopen (20 ms).
- Relever et archiver la **période effective mesurée** (`dt`) : une période non relevée rend la trace
  inexploitable.

### Réglage

| Paramètre | Valeur | Remarque |
|---|---|---|
| Tâche | `MainTask` | 10 ms |
| Nombre d'échantillons | **≥ 3 000** par canal | couvre **30 s** à 10 ms — nécessaire car le symptôme a été observé sur des runs de **10 356 ms** |
| Avant déclenchement | 500 éch. (5 s) | voir l'approche (état nominal + neutre) |
| Après déclenchement | 2 000 éch. (20 s) | voir **plusieurs** reprises, pas une seule |
| Déclencheur | front montant sur **`PRG_02_Acquisition.Data.Joystick.DeadmanArmed`** | variante : sur le premier front de `M1_RelayAscent_RQ` / `M1_RelayDescent_RQ` |

### Pourquoi **10 ms** (et ni 4 ms, ni 100 ms)

| Cadence | Verdict | Argument |
|---|---|---|
| **4 ms** (EtherCAT) | ❌ **inutile** | les POU `PRG_04`/`PRG_06` s'exécutent dans la **`MainTask`** (`AF_Partie-02:521-527`) : échantillonner à 4 ms relit **2,5× la même valeur** — aucune information supplémentaire, pour 2,5× de buffer. |
| **10 ms** | ✅ **retenu** | = période de la `MainTask` (`AF_Partie-02:517-525`) : **1 échantillon par scan réel**. Donne **50 échantillons** dans une fenêtre de 500 ms, **70** dans 700 ms, **40** dans 400 ms — assez pour dater un front à **1 scan près**. |
| **100 ms** | ❌ **le piège réel** | c'est la cadence des traces T224 existantes (**dt médian 101 ms mesuré** sur `Suivi_67`) : **5 échantillons** seulement dans 500 ms, **4** dans 400 ms ⇒ **structurellement aveugle** sur les tempos et incapable de distinguer un `RestartDelay` de 500 ms d'un `DeadTime` de 700 ms. |

### Si le buffer ne tient pas tous les canaux du §3

**Découper en 4 traces** auto-suffisantes et les nommer explicitement :
`D1` = Décision d'armement + disponibilité + sécurité (groupes **A**/**H**) · `D2` = Discriminant famille 1/2
(groupes **B**/**D**) · `D3` = Barrière finale, sorties, mesures, contexte (groupes **C**/**E**/**F**/**G**) ·
`D4` = **Faux vert** (groupe **I** — à prendre **en priorité** si le buffer n'en accepte qu'une).
Le rejeu reste concluant : **chaque groupe répond à une question fermée du §5**.

---

## 3. Liste EXACTE des canaux à enregistrer (à copier telle quelle)

> Format identique à `TOOLS/PLC_CSV_SNAPSHOT/variable_lists/trace_treuils_charge_v1.txt` (un symbole par ligne).
> ♻️ = **chemin déjà validé dans une trace ou une liste du dépôt** — **ne pas réinventer**.
> 🆕 = canal **absent de toute trace existante** du dépôt, **indispensable** à T224.
> ⚠️ Les chemins `instXxx.<interne>` sont des **internes de FB** : traçables par symbole CODESYS (fait
> établi — `TROUBLESHOOTING_T334_M3_DeuxChemins…:332`, `PROCEDURE_TRACE_T334…:27-31`), mais **jamais lus
> par du code** (`CODE_QUALITY_STANDARDS.md:526-527`). Ils ne servent **qu'à la preuve de diagnostic**.

### Groupe A — Décision d'armement et disponibilité par axe×sens (12 canaux)

| # | Chemin CODESYS | Type | Ce que ça permet de conclure |
|---|---|---|---|
| A1 | `PRG_04_Treuils_Benne.Data.ArmingPermit` | BOOL | ♻️ trace 67 — **le permis lui-même**. S'il est à **0** pendant le blocage, ce n'est PAS T224 (c'est un désarmement, C01→C09). |
| A2 | `PRG_02_Acquisition.instJoystick.ArmingPermit` | BOOL | ♻️ trace 67 — **vue consommateur** (entrée de `FB_Joystick`, `PRG_02:464`). Mesure le **lag de 1 scan** du bus, à ne pas confondre avec un bug (`TROUBLESHOOTING_TREUILS_JoystickContacteur…:339`) |
| A3 | `PRG_02_Acquisition.instJoystick.ArmingPermitDenied` | BOOL | ♻️ trace 67 — appui refusé (F08.08). **Diagnostic mort à l'IHM** (C42) : c'est ici qu'on le récupère |
| A4 | `PRG_02_Acquisition.Data.Joystick.DeadmanArmed` | BOOL | ♻️ trace 67 — le geste est-il réellement armé ? |
| A5 | `PRG_04_Treuils_Benne.Data.ArmingAvailability.AnyAxisAvail` | BOOL | 🆕 l'agrégat OR — explique pourquoi `ArmingPermit` reste à 1 (A7 du brief) |
| A6 | `PRG_04_Treuils_Benne.Data.ArmingAvailability.M1AscentAvail` | BOOL | 🆕 dispo M1 montée — **le cœur de T224, jamais mesuré** |
| A7 | `PRG_04_Treuils_Benne.Data.ArmingAvailability.M1DescendAvail` | BOOL | 🆕 dispo M1 descente |
| A8 | `PRG_04_Treuils_Benne.Data.ArmingAvailability.M2AscentAvail` | BOOL | 🆕 dispo M2 montée — à croiser avec D8/D9 (permis **appliqué**, **C12**) |
| A9 | `PRG_04_Treuils_Benne.Data.ArmingAvailability.M2DescendAvail` | BOOL | 🆕 dispo M2 descente (C13) |
| A10 | `PRG_04_Treuils_Benne.Data.ArmingAvailability.M3TremieAvail` | BOOL | 🆕 dispo M3 trémie — à croiser avec E4 (`M3_PosTremie_DI`, **C18**) |
| A11 | `PRG_04_Treuils_Benne.Data.ArmingAvailability.M3MaintenanceAvail` | BOOL | 🆕 dispo M3 maintenance |
| A12 | `PRG_04_Treuils_Benne.Data.ArmingAvailability.BlockedReason` | `E_ArmingBlockReason` | 🆕 **le motif** (`NONE`/`MODE_DISABLE`/`POWER_CUTOFF`/`CONTACTOR_OFF`/`BUCKET_BUSY`/`ALL_AXES_BLOCKED`) — **jamais tracé, jamais affiché** (G2). ⚠️ `SafeStop` **n'a pas** de valeur dédiée ⇒ tombe dans `ALL_AXES_BLOCKED` |

### Groupe B — LE DISCRIMINANT famille 1 / famille 2 (`RampTargetStep`) (18 canaux)

> 🎯 **C'est le groupe qui n'existe nulle part et qui rend la famille 1 et la famille 2 indiscernables.**
> Source du mécanisme : `FB_Winch.st:216-217` — `IF DirectionChangePending OR NOT (ReqAscent OR ReqDescend)
> OR EffectiveSafeStop OR NOT RunRequest THEN RampTargetStep := 0;`

| # | Chemin CODESYS | Type | Ce que ça permet de conclure |
|---|---|---|---|
| B1 | `PRG_04_Treuils_Benne.instWinchM1.RampTargetStep` | INT | 🆕 **LA variable clé**. `≠ 0` ⇒ **famille 1** (l'ordre existe) · `= 0` ⇒ **famille 2** (aucun ordre formé) |
| B2 | `PRG_04_Treuils_Benne.instWinchM2.RampTargetStep` | INT | 🆕 idem M2 |
| B3 | `PRG_04_Treuils_Benne.instWinchM1.EffectiveSafeStop` | BOOL | 🆕 dit **lequel des 3 termes** a coupé : `SafeStop` / `DirectionConflict` / **permis absent** (`FB_Winch:169-171`) |
| B4 | `PRG_04_Treuils_Benne.instWinchM2.EffectiveSafeStop` | BOOL | 🆕 idem M2 |
| B5 | `PRG_04_Treuils_Benne.instWinchM1.DirectionChangePending` | BOOL | ♻️ TRACE64:56 — famille 2 **D18** |
| B6 | `PRG_04_Treuils_Benne.instWinchM2.DirectionChangePending` | BOOL | ♻️ TRACE64:57 |
| B7 | `PRG_04_Treuils_Benne.instWinchM1.Enable` | BOOL | — FB_Winch prêt (`StepNumber=0 AND ContactorsAllOff`) : `0` = amont FB_Winch, pas un interlock |
| B8 | `PRG_04_Treuils_Benne.instWinchM1.EnableRisingEdge.Q` | BOOL | 🆕 **le déclencheur D18** (`FB_Winch:106`, `199`) : `DeadTimeArmed := TRUE` au front |
| B9 | `PRG_04_Treuils_Benne.instWinchM1.StepNumber` | INT | palier réellement façonné (0..5) |
| B10 | `PRG_04_Treuils_Benne.instWinchM1.DirectionInterlock.DeadTimeArmed` | BOOL | 🆕 **D18 lui-même** — l'arme du temps mort au front `Enable` |
| B11 | `PRG_04_Treuils_Benne.instWinchM1.DirectionInterlock.DirectionChangePending` | BOOL | 🆕 vue interne du même signal (source, pas projection) |
| B12 | `PRG_04_Treuils_Benne.instWinchM1.DirectionInterlock.DelayElapsed` | TIME | 🆕 date l'inversion — la valeur **2 174 ms** de la trace 67 est le chiffre de référence à confronter |
| B13 | `PRG_04_Treuils_Benne.instWinchM1.DirectionInterlock.RemainingDelay` | TIME | 🆕 reliquat à courir (crédit du temps d'arrêt réel, correctif `6f708b22`) |
| B14 | `PRG_04_Treuils_Benne.instWinchM1.DirectionInterlock.RequestActive` | BOOL | 🆕 neutre franc vs demande maintenue |
| B15 | `PRG_04_Treuils_Benne.Data.WinchM1State.CommandedAscent` | BOOL | ♻️ trace 67 — sens **adopté** par le FB |
| B16 | `PRG_04_Treuils_Benne.Data.WinchM1State.DirectionChangePending` | BOOL | ♻️ trace 67 — la projection publiée (à comparer à B5/B11) |
| B17 | `PRG_04_Treuils_Benne.Data.WinchM1State.DirectionChangeDelayElapsed` | TIME | ♻️ trace 67 — l'écoulé **publié** |
| B18 | `PRG_04_Treuils_Benne.Data.BothBlockReason` | `E_WinchTraceBlockReason` | ♻️ liste `trace_treuils_charge_v1.txt:81` — cause priorisée du blocage **Both** |

### Groupe C — État et motifs de la barrière finale M1/M2 (fenêtre G1) (34 canaux)

> ♻️ **La moitié de ces canaux est DÉJÀ publiée** par `FB_WinchStateProjection.st:112-122` et **déjà
> affichée** par `FB_TroubleshootingView.st:222-235` (`Idx405`, `Idx406`, `Idx407`, `Idx411`, `Idx415`,
> `Idx416`, `Idx417`, `Idx418`). **Tracer d'abord la voie publiée** ; n'aller dans l'instance que pour les
> 4 canaux qui n'existent nulle part ailleurs (C11, C12, C13, C14).

| # | Chemin CODESYS | Type | Ce que ça permet de conclure |
|---|---|---|---|
| C1 | `PRG_04_Treuils_Benne.Data.WinchM1State.FinalInterlockState` | `E_WinchFinalInterlockState` | ♻️ publié (`:112`) → `Idx405` — **l'état de la barrière** : `READY` / `WAIT_RESTART_DELAY` / `WAIT_SENSE_DROP_CONFIRM` / `WAIT_BRAKE_COMMAND_CONFIRMATION` / `FAULT` / `DISABLED` |
| C2 | `PRG_04_Treuils_Benne.Data.WinchM1State.FinalInterlockReason` | `E_WinchFinalInterlockReason` | ♻️ publié (`:113`) → `Idx406` — `NONE` / `BRAKE_COMMAND_NOT_CONFIRMED` / `RESTART_INHIBITED` / `SENSE_DROP_TIMEOUT` |
| C3 | `PRG_04_Treuils_Benne.Data.WinchM1State.FinalRestartRequired` | BOOL | ♻️ publié (`:117`) → `Idx416` — **purge anti-court-cycle armée** (`AuthorizedStep := 0`) ⇒ **C22** |
| C4 | `PRG_04_Treuils_Benne.Data.WinchM1State.FinalRestartInhibit` | BOOL | ♻️ publié (`:116`) → `Idx417` — latch exigeant `Reset` ⇒ **C24** |
| C5 | `PRG_04_Treuils_Benne.Data.WinchM1State.FinalMotorRequest` | BOOL | ♻️ publié (`:118`) → `Idx415` — la barrière **voit-elle** une demande moteur ? |
| C6 | `PRG_04_Treuils_Benne.Data.WinchM1State.FinalNeutralRequestSeen` | BOOL | ♻️ publié (`:119`) → `Idx418` — passage au neutre observé (sortie de `RestartInhibit`) |
| C7 | `PRG_04_Treuils_Benne.Data.WinchM1State.FinalAuthorizedStep` | INT | ♻️ publié (`:110`) → `Idx407` — palier **réellement autorisé** par la barrière |
| C8 | `PRG_04_Treuils_Benne.Data.WinchM1State.FinalRestartDelayElapsed` | TIME | ♻️ publié (`:121`), tracé dans `trace_treuils_charge_v1.txt:88` — **date la purge** : ~500 ms attendu |
| C9 | `PRG_04_Treuils_Benne.Data.WinchM1State.FinalStepDelayElapsed` | TIME | ♻️ publié (`:122`) → `Idx411` |
| C10 | `PRG_04_Treuils_Benne.Data.WinchM1State.FinalBrakeTimeoutElapsed` | TIME | ♻️ publié (`:120`), tracé `:87` — watchdog frein 500 ms |
| C11 | `PRG_06_Outputs.instWinchOutputInterlockM1.DeadTimePending` | BOOL | 🆕 **NON publié** (VAR loc. `:110`) ⇒ **temps mort directionnel en attente = C23**. **Indispensable** |
| C12 | `PRG_06_Outputs.instWinchOutputInterlockM1.DeadTimeElapsed` | TIME | 🆕 **lu seulement** par `PRG_06:181` (calcul de `M1AscentStartReady`), **jamais publié** — mesure la fenêtre 500/700 ms |
| C13 | `PRG_06_Outputs.instWinchOutputInterlockM1.ContactorStuck` | BOOL | 🆕 **0 consommateur** — latch T_max §3bis (**C25**) |
| C14 | `PRG_06_Outputs.instWinchOutputInterlockM1.SenseHoldActive` | BOOL | 🆕 maintien du contacteur de sens en cours (§3bis) |
| C15 | `PRG_06_Outputs.instWinchOutputInterlockM1.Ready` | BOOL | `Ready := NOT Error AND NOT ContactorStuckLatched` (`:349`) |
| C16 | `PRG_06_Outputs.instWinchOutputInterlockM1.RestartDelayElapsed` | TIME | vue **instance** du même signal que C8 (source vs projection) |
| C17 | `PRG_06_Outputs.instWinchOutputInterlockM1.BrakeTimeoutElapsed` | TIME | idem pour C10 |
| C18 | `PRG_04_Treuils_Benne.Data.WinchM1State.FinalInterlockErrorId` | WORD | ♻️ publié (`:115`) — bitfield barrière (bit0 = timeout frein) |
| C19 | `PRG_04_Treuils_Benne.Data.WinchM1State.FinalInterlockError` | BOOL | ♻️ publié (`:114`) — **c'est LUI que lit `Step8_OutputInterlockOk`** (faux vert, §6) |
| C20 | `PRG_04_Treuils_Benne.Data.WinchM2State.FinalInterlockState` | `E_WinchFinalInterlockState` | ♻️ publié (`:179`) → `Idx404/405` |
| C21 | `PRG_04_Treuils_Benne.Data.WinchM2State.FinalInterlockReason` | `E_WinchFinalInterlockReason` | ♻️ publié (`:180`) |
| C22 | `PRG_04_Treuils_Benne.Data.WinchM2State.FinalRestartRequired` | BOOL | ♻️ publié (`:184`) |
| C23 | `PRG_04_Treuils_Benne.Data.WinchM2State.FinalRestartInhibit` | BOOL | ♻️ publié (`:183`) |
| C24 | `PRG_04_Treuils_Benne.Data.WinchM2State.FinalMotorRequest` | BOOL | ♻️ publié (`:185`) |
| C25 | `PRG_04_Treuils_Benne.Data.WinchM2State.FinalAuthorizedStep` | INT | ♻️ publié (`:177`) |
| C26 | `PRG_04_Treuils_Benne.Data.WinchM2State.FinalRestartDelayElapsed` | TIME | ♻️ publié, tracé `:91` |
| C27 | `PRG_04_Treuils_Benne.Data.WinchM2State.FinalStepDelayElapsed` | TIME | ♻️ publié (`:189`), tracé `:89` |
| C28 | `PRG_04_Treuils_Benne.Data.WinchM2State.FinalBrakeTimeoutElapsed` | TIME | ♻️ publié, tracé `:90` |
| C29 | `PRG_06_Outputs.instWinchOutputInterlockM2.DeadTimePending` | BOOL | 🆕 idem C11 pour M2 |
| C30 | `PRG_06_Outputs.instWinchOutputInterlockM2.DeadTimeElapsed` | TIME | 🆕 idem C12 |
| C31 | `PRG_06_Outputs.instWinchOutputInterlockM2.ContactorStuck` | BOOL | 🆕 idem C13 |
| C32 | `PRG_06_Outputs.instWinchOutputInterlockM2.SenseHoldActive` | BOOL | 🆕 idem C14 |
| C33 | `PRG_06_Outputs.instWinchOutputInterlockM2.Ready` | BOOL | idem C15 |
| C34 | `PRG_04_Treuils_Benne.Data.WinchM2State.FinalInterlockError` | BOOL | ♻️ publié (`:181`) |

### Groupe D — Permis **effectif** vs **appliqué** + benne (C12/C13/C17) (14 canaux)

| # | Chemin CODESYS | Type | Ce que ça permet de conclure |
|---|---|---|---|
| D1 | `PRG_04_Treuils_Benne.Data.TraceM1.AscentPermitEffective` | BOOL | ♻️ publié (`PRG_04:1974`, DUT `ST_TraceWinch:19`) |
| D2 | `PRG_04_Treuils_Benne.Data.TraceM1.AscentPermitApplied` | BOOL | ♻️ publié — pour M1, appliqué = effectif (`:1837-1838`) |
| D3 | `PRG_04_Treuils_Benne.Data.TraceM2.AscentPermitEffective` | BOOL | ♻️ **le terme que compte `ArmM2AscentAvail`** (`PRG_04:1166`) |
| D4 | `PRG_04_Treuils_Benne.Data.TraceM2.AscentPermitApplied` | BOOL | ♻️ **le terme réellement appliqué** (`= M2AscentPermitApplied`, `:1885`) ⇒ **si D3=1 et D4=0, C12 est PROUVÉ** |
| D5 | `PRG_04_Treuils_Benne.Data.TraceM2.DescendPermitEffective` | BOOL | ♻️ idem descente (=`ArmM2DescendAvail`, `:1167`) |
| D6 | `PRG_04_Treuils_Benne.Data.TraceM2.DescendPermitApplied` | BOOL | ♻️ idem ⇒ **C13** |
| D7 | `PRG_04_Treuils_Benne.M2AscentPermitApplied` | BOOL | 🆕 le **terme brut** (local PRG_04:1131) — évite de douter de la projection |
| D8 | `PRG_04_Treuils_Benne.M2DescendPermitApplied` | BOOL | 🆕 terme brut (`:1133`) |
| D9 | `PRG_04_Treuils_Benne.EffectivePermitBucket_Open` | BOOL | 🆕 conditions de C12/C13 (`:1118-1122`) |
| D10 | `PRG_04_Treuils_Benne.EffectivePermitBucket_Close` | BOOL | 🆕 (`:1123-1127`) |
| D11 | `PRG_04_Treuils_Benne.instBucket.M2_RunRequest` | BOOL | ♻️ TRACE64 (esprit) — **déclencheur du gate benne** (`FB_Bucket:552/556/560`) |
| D12 | `PRG_04_Treuils_Benne.instBucket.Lifecycle.Busy` | BOOL | ♻️ TRACE64:58 — `ArmBucketBusy` (**C04**) et son **risque de blocage permanent** (T354:282) |
| D13 | `PRG_04_Treuils_Benne.EffectivePermitM1_Descend` | BOOL | ♻️ TRACE64:54 |
| D14 | `PRG_04_Treuils_Benne.EffectivePermitM2_Descend` | BOOL | ♻️ TRACE64:55 |

### Groupe E — Translation M3 (C18/C19/C30-C32) (12 canaux)

| # | Chemin CODESYS | Type | Ce que ça permet de conclure |
|---|---|---|---|
| E1 | `PRG_02_Acquisition.HwIn.Translation.M3_PosTremie_DI` | BOOL | ♻️ T334:106 — **le DI du terme caché de C18** |
| E2 | `PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Tremie` | BOOL | 🆕 permis **demandé** par la barrière (`PRG_05:676`) |
| E3 | `PRG_05_Translation.Data.TranslationFinalInterlockRequest.EffectivePermitM3_Maintenance` | BOOL | 🆕 idem maintenance |
| E4 | `PRG_06_Outputs.instTranslationOutputInterlockM3.EffectivePermitM3_Tremie` | BOOL | 🆕 **le terme réellement appliqué** (`= demande AND NOT M3_PosTremie_DI`, `PRG_06:439-440`) ⇒ **si E2=1 et E4=0 avec E1=1, C18 est PROUVÉ** |
| E5 | `PRG_05_Translation.Data.TranslationSafety.SafeStop` | BOOL | 🆕 lu par `ArmM3*Avail` (`PRG_04:1169`, `:1172`) |
| E6 | `PRG_05_Translation.Data.TranslationSafety.PowerCutOff` | BOOL | 🆕 idem (`:1170`, `:1173`) |
| E7 | `PRG_06_Outputs.M3_TremieHardStopActive` | BOOL | ♻️ T334:153 — **C19** (annule la demande **avant** la barrière) |
| E8 | `PRG_06_Outputs.instTranslationOutputInterlockM3.Reason` | `E_TranslationFinalInterlockReason` | ♻️ T334:157 |
| E9 | `PRG_06_Outputs.instTranslationOutputInterlockM3.Fault.ErrorId` | WORD | ♻️ T334:158 |
| E10 | `PRG_06_Outputs.instTranslationOutputInterlockM3.RestartInhibit` | BOOL | 🆕 **C31** |
| E11 | `PRG_06_Outputs.instTranslationOutputInterlockM3.BrakeCmd` | BOOL | ♻️ T334:156 |
| E12 | `PRG_06_Outputs.instTranslationOutputInterlockM3.DriveControlWord` | WORD | ♻️ T334:154 — `0` = aucun couple utile (C30) |

### Groupe F — Sorties physiques réellement émises + mesures (le mouvement a-t-il eu lieu ?) (22 canaux)

| # | Chemin CODESYS | Type | Ce que ça permet de conclure |
|---|---|---|---|
| F1 | `M1_RelayAscent_RQ` | BOOL | ♻️ trace 67 — **l'ordre de sens est-il sorti ?** (famille 1 : oui ; famille 2 : non) |
| F2 | `M1_RelayDescent_RQ` | BOOL | ♻️ trace 67 |
| F3 | `M1_SpeedContactor_1_DQ` | BOOL | ♻️ trace 67 |
| F4 | `M1_SpeedContactor_2_DQ` | BOOL | ♻️ trace 67 |
| F5 | `M1_SpeedContactor_3_DQ` | BOOL | ♻️ trace 67 |
| F6 | `M1_SpeedContactor_4_DQ` | BOOL | ♻️ trace 67 |
| F7 | `M1_BrakeRelease_RQ` | BOOL | ♻️ trace 67 |
| F8 | `M1_BrakeIsOpen_DI` | BOOL | ♻️ trace 67 — retour frein (**C28** : condition de purge des tempos) |
| F9 | `M2_RelayAscent_Close_RQ` | BOOL | ♻️ trace 67 |
| F10 | `M2_RelayDescent_Open_RQ` | BOOL | ♻️ trace 67 |
| F11 | `M2_SpeedContactor_1_DQ` | BOOL | ♻️ trace 67 |
| F12 | `M2_SpeedContactor_2_DQ` | BOOL | ♻️ trace 67 |
| F13 | `M2_BrakeRelease_RQ` | BOOL | ♻️ trace 67 |
| F14 | `M2_BrakeIsOpen_DI` | BOOL | ♻️ trace 67 |
| F15 | `M3_BrakeRelease_RQ` | BOOL | ♻️ T334:162 |
| F16 | `M3_CommandWord` | WORD | ♻️ T334:160 |
| F17 | `M1TreuilRetenue.State.Position_M` | REAL | ♻️ trace 67 — **le mouvement a-t-il eu lieu ?** |
| F18 | `M2TreuilBenne.State.Position_M` | REAL | ♻️ trace 67 |
| F19 | `M1TreuilRetenue.State.MeasuredSpeed_Mps` | REAL | ♻️ trace 67 |
| F20 | `M2TreuilBenne.State.MeasuredSpeed_Mps` | REAL | ♻️ trace 67 |
| F21 | `M2TreuilBenne.Bucket.State.BucketOpening_Pct` | REAL | ♻️ trace 67 |
| F22 | `JOY1Joystick.State.RawY` | INT | ♻️ trace 67 — **la demande opérateur, brute** (corrélatif indispensable) |

### Groupe G — Contexte (mode, arbitrage, réglages) (12 canaux)

| # | Chemin CODESYS | Type | Ce que ça permet de conclure |
|---|---|---|---|
| G1 | `PRG_03_Modes_Cycle.Data.Auth.Mode` | `E_Mode` | 🆕 `DISABLE`/`MAINT_N1`/`MAINT_N2`/`SEMI_AUTO` — **le mode est un contexte, pas un discriminant** (hypothèse réfutée en Étape A) |
| G2 | `GVL_IHM.Modes.Cmd.SelJoystickWinch` | INT | ♻️ trace 67 — ⚠️ **non discriminant** (constat mesuré : 0 partout, y compris quand ça bouge) |
| G3 | `PRG_03_Modes_Cycle.Data.Auth.JoystickWinchSelectArbitrated` | INT | ♻️ TRACE64:46 — **le sélecteur réellement arbitré** (≠ G2) |
| G4 | `GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing` | BOOL | ♻️ TRACE64:47 — toggle T248 |
| G5 | `PRG_03_Modes_Cycle.Data.Auth.CoupledBucketPhaseLocked` | BOOL | ♻️ TRACE64:50 |
| G6 | `PRG_03_Modes_Cycle.Data.Auth.WinchSelTransitionHold` | BOOL | ♻️ TRACE64:51 |
| G7 | `GVL_IHM.M3Translation.Cmd.TglAllowWinchMoveAtTremie` | BOOL | ♻️ TRACE64:49 — **indispensable pour C18** |
| G8 | `PRG_04_Treuils_Benne.WinchBothDiveBucketOpenArmed` | BOOL | ♻️ TRACE64:52 |
| G9 | `PRG_04_Treuils_Benne.WinchBothAscentBucketCloseArmed` | BOOL | ♻️ TRACE64:53 |
| G10 | `GVL_IHM.Modes.Cmd.TglJoystickMaster` | BOOL | ♻️ T334:183 — joystick maître vs boutons IHM |
| G11 | `GVL_Simulation.SimulationModeActive` | BOOL | ♻️ `trace_treuils_charge_v1.txt:96` |
| G12 | `GVL_Simulation.SimWinchActive` | BOOL | ♻️ `trace_treuils_charge_v1.txt:97` — **vérifier AVANT d'interpréter les DI** |

### Groupe H — Sécurité et défauts, pour ÉLIMINER la famille 3b (16 canaux)

| # | Chemin CODESYS | Type | Ce que ça permet de conclure |
|---|---|---|---|
| H1 | `M1TreuilRetenue.Safety.Error` | BOOL | ♻️ trace 67 |
| H2 | `M1TreuilRetenue.Safety.ErrorId` | WORD | ♻️ trace 67 — **bit15 = `ErrorNoMovement`** (« commande sans mouvement », C43) |
| H3 | `M2TreuilBenne.Safety.Error` | BOOL | ♻️ trace 67 |
| H4 | `M2TreuilBenne.Safety.ErrorId` | WORD | ♻️ trace 67 |
| H5 | `M1TreuilRetenue.State.ErrorId` | WORD | ♻️ trace 67 |
| H6 | `M2TreuilBenne.State.ErrorId` | WORD | ♻️ trace 67 |
| H7 | `M1M2Sync.State.ErrorId` | WORD | ♻️ trace 67 |
| H8 | `PRG_06_Outputs.Data.SyncContactorDiag.RelayFwdMismatch` | BOOL | ♻️ trace 67 — discordance contacteurs (= périmètre **T370**, à sérialiser) |
| H9 | `PRG_04_Treuils_Benne.Data.TraceM1.SafeStopActive` | BOOL | ♻️ publié (`ST_TraceWinch:25`) |
| H10 | `PRG_04_Treuils_Benne.Data.TraceM1.SafeStopSourceSafety` | BOOL | ♻️ `:26` — **distingue le SafeStop safety du SafeStop d'entrée/synchro** |
| H11 | `PRG_04_Treuils_Benne.Data.TraceM1.SafeStopSourceInput` | BOOL | ♻️ `:27` |
| H12 | `PRG_04_Treuils_Benne.Data.TraceM1.SafeStopSourceSync` | BOOL | ♻️ `:28` — le **désarmement croisé** M1↔M2 (C07/C09) |
| H13 | `PRG_04_Treuils_Benne.Data.TraceM1.PowerCutOffActive` | BOOL | ♻️ `:29` |
| H14 | `PRG_04_Treuils_Benne.Data.TraceM2.SafeStopSourceSafety` | BOOL | ♻️ `:26` |
| H15 | `PRG_04_Treuils_Benne.Data.TraceM2.SafeStopSourceSync` | BOOL | ♻️ `:28` |
| H16 | `PRG_04_Treuils_Benne.Data.TraceM2.PowerCutOffActive` | BOOL | ♻️ `:29` |

### Groupe I — **DOCUMENTER LE FAUX VERT** : checklist de mouvement + quartets M2/M3 (32 canaux)

> 🎯 **Pourquoi ce groupe est obligatoire** : le faux vert est **prouvé sur pièces**
> (`ST_MotionChecklist.st:4`/`:30` + `FB_TroubleshootingView.st:577` + `FB_WinchOutputInterlock.st:210/362/372/508`
> avec **aucune** assignation de `Reason` en `:393-404` ni `:424-430`). Mais il n'a **jamais été observé
> sur une trace** : sans ces canaux, la trace **ne pourra pas le documenter auprès de l'exploitant**, et
> le lot correctif partira sans preuve dynamique du symptôme **vu par l'utilisateur**.
> ♻️ Chemins issus de `FB_TroubleshootingView.st:564-586` (M1), `:596-618` (M2), `:628-653` (M3) et
> `TROUBLESHOOTING_T334_M3_DeuxChemins…:176-177` — **les noms de région sont `N_MotionM1`, `O_MotionM2`,
> `P_MotionM3`** (vérifié `:564`, `:609`, `:644`).

| # | Chemin CODESYS | Type | Ce que ça permet de conclure |
|---|---|---|---|
| I1-I9 | `GVL_Troubleshooting.N_MotionM1.Step1_PowerEngaged` · `.Step2_ModeAuthorized` · `.Step3_NotBusyOtherTask` · `.Step4_MotionRequested` · `.Step5_NoSafetyFault` · `.Step6_DirectionAllowed` · `.Step7_BrakeReleased` · `.Step8_OutputInterlockOk` · **`.AllConditionsMet`** | BOOL ×9 | ♻️ **les 8 étapes + le verdict de la checklist M1**. `AllConditionsMet = 1` alors qu'aucun relais ne colle = **le faux vert, démontré** |
| I10-I18 | `GVL_Troubleshooting.O_MotionM2.Step1_PowerEngaged` → `.Step8_OutputInterlockOk` · **`.AllConditionsMet`** | BOOL ×9 | ♻️ idem M2 |
| I19-I27 | `GVL_Troubleshooting.P_MotionM3.Step1_PowerEngaged` → `.Step8_OutputInterlockOk` · **`.AllConditionsMet`** | BOOL ×9 | ♻️ idem M3 |
| I28 | `PRG_05_Translation.Data.TranslationState.FinalInterlockState` | `E_State` | ♻️ publié (`PRG_05:755`/`:751-754`) → `FB_TroubleshootingView.st:417` (`Idx404`) — **quartet M3** |
| I29 | `PRG_05_Translation.Data.TranslationState.FinalInterlockReason` | `E_TranslationFinalInterlockReason` | ♻️ T334:176 → `:418` (`Idx405`) |
| I30 | `PRG_05_Translation.Data.TranslationState.FinalInterlockError` | BOOL | ♻️ T334:177 → pilote `P_MotionM3.Step8_OutputInterlockOk` |
| I31 | `PRG_05_Translation.Data.TranslationState.FinalInterlockErrorId` | WORD | 🆕 le bitfield M3 (remonte au bandeau, `FB_Hmi_BannerFormatter.st:63`, `:1038`) |
| I32 | `PRG_04_Treuils_Benne.Data.WinchM2State.FinalInterlockErrorId` | WORD | 🆕 **complète le quartet M2** (C20 `State`, C21 `Reason`, C34 `Error` sont déjà listés) — ⚠️ non publié côté bandeau pour M1/M2, contrairement à M3 |

> ⚠️ **`Step8_OutputInterlockOk` lit `NOT Fault.Error`, PAS `State`** (`FB_TroubleshootingView.st:577`) :
> c'est **la** cause du faux vert. Tracer `Step8` **et** `FinalInterlockState` (C1/C20/I28) est donc
> indispensable — **les deux peuvent se contredire** (voir §5.2 `F1-e` et §5.5).

### Total

| Groupe | Canaux |
|---|---|
| A — Décision d'armement / disponibilité | 12 |
| B — **Discriminant famille 1/2** (`RampTargetStep`) | 18 |
| C — Barrière finale M1/M2 | 34 |
| D — Permis effectif vs appliqué + benne | 14 |
| E — Translation M3 | 12 |
| F — Sorties réelles + mesures | 22 |
| G — Contexte | 12 |
| H — Sécurité / défauts | 16 |
| **I — Faux vert (checklists `N/O/P_Motion*` + quartets M2/M3)** | **32** |
| **TOTAL** | **172** |

---

## 4. Scénarios de prise (le run est HUMAIN)

> 🎯 **Principe** : un geste **franc et maintenu**, un mode à la fois, **plusieurs répétitions** du
> symptôme dans la même trace. Le symptôme a été observé en **MAINT_N1** et en **SEMI_AUTO**
> (`BRIEF_T224…v2:299`, fiche `TRACE64`).

### Scénario 1 — MAINT_N1, descente couplée (le cas de la trace 67)
1. Machine référencée, **`MAINT_N1`**, joystick maître (`TglJoystickMaster`).
2. **Démarrer la trace**, puis : neutre 2 s → appui homme-mort → **montée franche > 50 % Y** (M1+M2
   couplés) 3 s → **retour neutre 2 s** → **re-demande immédiate** dans le **même sens** (< 500 ms) →
   maintenir 5 s.
3. **Rejouer l'inversion** : descente franche 3 s → neutre bref (< 700 ms) → **remontée immédiate** →
   maintenir 5 s. *(c'est la fenêtre `DeadTimeOppositeDir = 700 ms`)*.
4. **Répéter 5 fois** la séquence 2 sans arrêter la trace.
5. Archiver : `T224_S1_MAINTN1_<AAAAMMJJ>_<n>.trace`.

### Scénario 2 — SEMI_AUTO, enchaînement de cycle (le cas de la fiche TRACE64)
1. `SEMI_AUTO`, lancer un cycle ; **démarrer la trace** au passage de l'étape affichée
   (`GVL_IHM.CycleSemiAuto.State.CycleStep`).
2. Laisser dérouler **au moins 3 cycles** complets sans forcer d'étape (sauf pour atteindre AX10B/AX11
   si nécessaire, via `GVL_IHM.CycleSemiAuto.Cfg.ForceStepTarget` + `BtnForceStepApply` — **réglage IHM
   autorisé**, à consigner).
3. Ne pas intervenir au joystick : on cherche le blocage **spontané** décrit en
   `TROUBLESHOOTING_MAINT_COUPLE_INTERLOCK_TRACE64_20260920.md:23`/`:26`.
4. Archiver : `T224_S2_SEMIAUTO_<AAAAMMJJ>_<n>.trace`.

### Scénario 3 — cas permanent **C12/C13** (permis M2 appliqué ≠ compté)
> 🎯 **Sans forcer quoi que ce soit de dangereux** : on exploite une manœuvre benne **normale**.
1. **`MAINT_N1`**, benne **fermée**, machine référencée.
2. **Démarrer la trace**, puis commander une **ouverture de benne** (bouton IHM ou joystick selon le
   mode) → pendant que `instBucket.Lifecycle.Busy = 1` et `instBucket.M2_RunRequest = 1`, **demander une
   MONTÉE M2 au joystick** et la **maintenir 5 s**.
3. **Lecture attendue si C12/C13 est réel** : `M2AscentAvail = 1` (A8) **alors que**
   `TraceM2.AscentPermitApplied = 0` (D4) ⇒ `RampTargetStep` (B2) tombe à `0` via `EffectiveSafeStop`
   (B4) ⇒ **aucun relais M2** (F9) **et aucun défaut**.
4. Archiver : `T224_S3_MAINTN1_BennesBusy_<AAAAMMJJ>_<n>.trace`.

### Scénario 4 — cas **C18** (arrêt en trémie)
> 🎯 **Sans forcer** : on se place **physiquement** en trémie, ce qui est une position de travail normale.
1. Amener M3 **à la trémie** (position de travail), `MAINT_N1`.
2. **Démarrer la trace**, puis **demander M3 vers la trémie** (le sens déjà atteint) et **maintenir 5 s** ;
   puis demander le sens **maintenance** (recul) 5 s.
3. **Lecture attendue si C18 est réel** : `EffectivePermitM3_Tremie` demandé = 1 (E2) mais **appliqué = 0**
   (E4) avec `M3_PosTremie_DI = 1` (E1) ⇒ `DriveControlWord = 0` (E12), **aucun défaut**.
4. Archiver : `T224_S4_MAINTN1_Tremie_<AAAAMMJJ>_<n>.trace`.

### Scénario 5 — référence nominale (obligatoire pour comparer)
1. `MAINT_N1`, **M1 seul**, montée franche 3 s puis descente franche 3 s, **sans** neutre bref.
2. Sert de **témoin** : si les mêmes signatures apparaissent alors que **ça bouge**, le discriminant du
   §5 est invalidé et doit être revu.
3. Archiver : `T224_S5_MAINTN1_Temoin_<AAAAMMJJ>_<n>.trace`.

### Scénario 6 — ⚠️ **OBLIGATOIRE** : blocage **DANS LA FENÊRE DE RÉFÉRENCE** (le silence sans borne)

> 🎯 **Pourquoi c'est obligatoire** : dans la fenêtre de référence, le **seul** détecteur du symptôme est
> **inhibé** → « armé, rien ne bouge, **aucun défaut, sans borne de temps** ». C'est le mode du cas réel
> « changement de câble » (MAINT_N1, un treuil inhibé) et c'est le seul cas où l'opérateur peut rester
> bloqué **indéfiniment** au lieu de 3 s.
> **Preuve du mécanisme** : `FB_Safety_Winch.st:438` — `TonNoMovement(IN := NOT BypassProcess AND
> **NOT RefWindowActive** AND **NOT BenneBusy** AND EncoderAvailable AND MovementCommanded AND BrakeFeedback
> AND NOT InReferencingMode AND NOT PositionMovementDetected, PT := NoMovementTimeout)` ; et
> `RefWindowActive := InReferencingMode OR BenneBusy OR PosStepDetected OR NOT TonRefSettle.Q OR NOT
> CrossCheckEnable` (`FB_Safety_Winch.st:247-249`, settle `T#2s`). ⇒ C43-bis du diagnostic.

1. `MAINT_N1`, **un seul treuil actif** : si l'exploitant utilise le mode d'inhibition d'un treuil
   (`Auth.InhibitM1`/`InhibitM2`, MAINT_N2), le **consigner** ; sinon provoquer la fenêtre par
   **`BenneBusy`** (manœuvre benne en cours, sans forçage).
2. **Démarrer la trace**, puis **demander le mouvement du treuil pendant que la fenêtre est ouverte** et
   **maintenir ≥ 12 s** — c'est **plus long que les 3 s** de `NoMovementTimeout` : si le blocage est
   silencieux au-delà de 3 s, **C43-bis est prouvé** (le détecteur est bien inhibé).
3. Variante **homing** : déclencher un homing machine et demander un mouvement treuil **pendant** le
   homing (le mouvement est normalement interdit ; on cherche à voir si un **refus** est **muet** ou
   **nommé**).
4. **Relever explicitement** : `RefWindowActive` n'est **pas** dans la liste §3 — il n'est pas traçable
   en tant que tel depuis l'extérieur du FB (`VAR` locale) ; on l'**infère** des entrées qui le composent
   (`BenneBusy`, `InReferencingMode`, `PosStepDetected`, `TonRefSettle.Q`, `CrossCheckEnable`). Si l'agent
   qui exploitera la trace a besoin du signal **brut**, il faudra l'**ajouter à la liste au titre de
   canal 🆕 via l'instance** : `PRG_04_Treuils_Benne.instSafetyWinchM1.RefWindowActive` (interne de FB,
   même doctrine que le groupe B).
5. Archiver : `T224_S6_MAINTN1_FenetreRef_<AAAAMMJJ>_<n>.trace`.

### À archiver avec chaque trace (sinon la trace n'est pas exploitable)
Révision Git (`git rev-parse HEAD`), date/heure, **période effective mesurée (`dt` min/médian/max)**,
scénario, **mode**, sens demandé, geste (amplitude Y, durée), **état des bypass**
(`GVL_IHM.*.Bypass.*`), **état des DI forcés s'il y en a** (le dire explicitement), réglages simulation,
et le **fichier `_wide.csv`** dérivé.

---

## 5. TABLE DE DÉCISION — la signature tranche la famille

> 🔑 **Règle de lecture unique** : `RampTargetStep` (B1/B2) dit d'abord **si un ordre a été formé**.
> `> 0` ⇒ l'aval a refusé (**famille 1**). `= 0` ⇒ rien n'a été formé (**famille 2**) — et `EffectiveSafeStop`
> (B3/B4) dit **lequel des 3 termes** l'a coupé.

### 5.1 Le discriminant principal

| # | Signature observée pendant le blocage (ArmingPermit = 1, demande > 5 %, vitesse ≈ 0) | Lecture | Conclusion |
|---|---|---|---|
| **T1** | **`RampTargetStep` ≠ 0** ET sorties (F1-F14) restent **0** | l'ordre **existe** au niveau du FB métier, **l'aval le refuse** | ✅ **FAMILLE 1 PROUVÉE** (interlock aval) — aller en §5.2 pour le sous-cas |
| **T2** | **`RampTargetStep` = 0** ET `EffectiveSafeStop = 1` ET **permis présent** (`TraceMx.*PermitEffective` = 1) | coupé par `SafeStop` ou `DirectionConflict` | **Famille 2 — amont `FB_Winch`** (`FB_Winch:169-171`) |
| **T3** | **`RampTargetStep` = 0** ET `EffectiveSafeStop = 1` ET **permis ABSENT** (`*PermitEffective` = 0) | coupé par le terme `(Req AND NOT Permit)` | ✅ **FAMILLE 2 PAR PERMIS** — **c'est le terme qui MASQUE la famille 1** (`FB_Winch:170-171` + `:216-217`) ⇒ la barrière ne verra **jamais** l'ordre |
| **T4** | **`RampTargetStep` = 0** ET `DirectionChangePending = 1` (B5/B6/B11) | bloqué par l'interlock direction | ✅ **FAMILLE 2 (D18)** — lire `DeadTimeArmed` (B10) et `DelayElapsed` (B12) |
| **T5** | **`RampTargetStep` = 0** ET `Enable = 0` (B7) | `FB_Winch` non prêt (`StepNumber≠0` ou contacteurs non retombés) | **Famille 2 — amont `FB_Winch`** |
| **T6** | **`RampTargetStep` = 0** ET `BothBlockReason ≠ NONE` (B18) | garde d'arbitrage couplé | **Famille 3d** (arbitrage) |
| **T7** | sorties = **1** (F1-F14) mais positions/vitesses **ne bougent pas** (F17-F20) | commande **émise**, aucun effet physique | ⚠️ **Famille 3 HW/mécanique** — **hors périmètre T224** (→ **T370**) |
| **T8** | **`ArmingPermit` = 0** (A1) pendant le blocage | ce n'est **pas** T224 | **désarmement** : lire A12 (`BlockedReason`) et H1-H16 ⇒ familles **3a/3b/3c** |

### 5.2 Sous-cas de la **famille 1** (T1 vrai) — identifier la condition exacte

| # | Signature | Condition prouvée |
|---|---|---|
| **F1-a** | `FinalInterlockState = WAIT_RESTART_DELAY` ET (`FinalRestartRequired` = 1 OU **`DeadTimePending` = 1**) | ✅ **C22 / C23** — **le temps idle de G1**. Mesurer la durée : `FinalRestartRequired` 1→0 donne la **fenêtre réelle** (attendu ~500 ms) ; `DeadTimePending` attendu 500 ms (même sens) ou 700 ms (inversion) |
| **F1-b** | `FinalRestartInhibit = 1` | ✅ **C24** — refus **latché**, exige `Reset` (`FinalNeutralRequestSeen` = 1 ⇒ neutre déjà vu) |
| **F1-c** | `FinalInterlockState = FAULT` ET `FinalInterlockReason = SENSE_DROP_TIMEOUT` | ✅ **C25** — `ContactorStuck` (§3bis, T_max 400 ms) |
| **F1-d** | `FinalInterlockState = FAULT` ET `FinalInterlockReason = BRAKE_COMMAND_NOT_CONFIRMED` | ✅ **C27 / C32** — watchdog frein 500 ms |
| **F1-e** | `FinalInterlockState = READY` ET `FinalInterlockReason = NONE` ET `FinalMotorRequest = 1` ET `FinalAuthorizedStep = 0` ET sorties = 0 | ✅ **C26 — `PermitFinalBlocked`** : refus directionnel **totalement muet**. ⚠️ **Précision décisive (relevée par l'humain, vérifiée)** : la branche `ELSIF SafeStop OR PermitFinalBlocked` (`FB_WinchOutputInterlock.st:393-404`) **pose `State := E_WinchFinalInterlockState.READY` (`:404`)** tout en coupant. Donc pendant un refus directionnel, la projection publie **`FinalInterlockState = READY`**, `Reason` **reste muet** (aucune assignation en `:393-404` ni `:424-430` — `Reason` n'est posé qu'en `:210`/`:362`/`:372`/`:508`) et **`Fault.Error = FALSE`**. ⇒ **tout est vert, y compris au niveau de la machine d'état** — ce n'est pas seulement l'IHM qui est muette, c'est **l'état lui-même qui ment**. `PermitFinalBlocked` est de plus une **VAR privée (`:87`)**, non publiable sans changement d'interface. **Signature la plus importante du dossier** |
| **F1-f** | **M2 seulement** : `TraceM2.AscentPermitEffective` = 1 ET `TraceM2.AscentPermitApplied` = 0 (avec `instBucket.M2_RunRequest` = 1) | ✅ **C12 / C13** — permis **appliqué** plus restrictif que le permis **compté** par `ArmingPermit` (voie Scénario 3) |
| **F1-g** | **M3 seulement** : `EffectivePermitM3_Tremie` demandé = 1 ET appliqué (E4) = 0 avec `M3_PosTremie_DI` = 1 | ✅ **C18** — terme ajouté par la barrière (`PRG_06:439-440`), absent du calcul de disponibilité (voie Scénario 4) |
| **F1-h** | `M3_TremieHardStopActive` = 1 | ✅ **C19** — demande annulée **avant** la barrière |
| **F1-i** | `FinalInterlockState = WAIT_SENSE_DROP_CONFIRM` | maintien §3bis en cours (transition, pas un blocage durable) |

### 5.3 Cas où **aucune** signature ne sort → à livrer comme tel

| # | Situation | Ce qui est alors **prouvé** |
|---|---|---|
| **N1** | Aucune signature de T1→T8 ni de F1-a→F1-i, et le mouvement a lieu normalement | les familles 1/2/3 ne sont **pas reproduites** sur ce scénario ⇒ **le symptôme n'a pas été capturé** (durée/cadence insuffisantes ou geste non rejoué) — **à dire explicitement**, ne pas extrapoler |
| **N2** | Toutes les conditions vertes **et** aucun mouvement **et** sorties à 1 | cause **physique** hors logiciel (contacteur, frein, mécanique, charge) ⇒ **renvoi T370**, pas T224 |

### 5.4 Mesure de la fenêtre des temps idle (objectif n°2)

| Mesure | Comment | Attendu (code) | Attendu (documents) |
|---|---|---|---|
| Fenêtre `RestartRequired` | durée `FinalRestartRequired` = 1 après `FinalMotorRequest` 1→0 | **~500 ms** (`FB_WinchOutputInterlock:224`) | **~1,5 s** (AF-08:384, contrats T224/T228) ⇒ **l'écart ×3 sera tranché par la mesure** |
| Fenêtre `DeadTimePending` même sens | durée (C11/C29) = 1 | **~500 ms** (`DeadTimeSameDir:35`) | 1 s (fiche FB `_v1.0`) |
| Fenêtre `DeadTimePending` inversion | durée (C11/C29) = 1 après changement de sens | **~700 ms** (`DeadTimeOppositeDir:36`) | 1 s |
| Fenêtre `ContactorStuck` | `FinalInterlockReason` 0→`SENSE_DROP_TIMEOUT` | **~400 ms** (`MaxSenseHoldTime:43`) | non documenté |
| Écart `ArmingPermit` → désarmement du geste | `A1` 1→0 et `A4` 1→0 | **même scan** (`FB_Joystick:238-240`) | immédiat |

---

### 5.5 **FAUX VERT** — documenter ce que l'opérateur voit (groupe **I**)

> 🎯 **Ce que la trace doit établir ici n'est pas une famille de cause, mais un FAIT DE DIAGNOSTIC** : que
> l'outil censé expliquer « pourquoi ça ne bouge pas » affiche **vert** pendant le blocage. Sans preuve
> dynamique, le lot correctif partira sans démonstration du symptôme **tel que vu par l'exploitant**.
> Rappel du mécanisme : `Step8_OutputInterlockOk := NOT WinchM1.State.FinalInterlockError`
> (`FB_TroubleshootingView.st:577`) — il lit **`Fault.Error`**, **jamais `State`** ; et `AllConditionsMet`
> conclut *« 🟢 TRUE = TOUTES LES CONDITIONS SONT REMPLIES, LES RELAIS DOIVENT COLLER ! »*
> (`ST_MotionChecklist.st:30`).

| # | Signature sur la trace | Lecture | Conclusion |
|---|---|---|---|
| **V1** | **`AllConditionsMet = 1`** (I1-I9 pour M1) **ET aucun relais** (F1-F14 = 0) — **avec `RampTargetStep ≠ 0` (famille 1 aval) OU `RampTargetStep = 0` (famille 2 : V1 reste possible, voir la nuance ci-dessous)** — ou permis barrière plus restrictif que le permis process (cas **C12/C18**, `M2*PermitApplied = 0` / `I4 = 0`) | l'outil affirme « les relais doivent coller » alors que **rien ne colle** et que **l'aval refuse en silence** | ✅ **FAUX VERT PROUVÉ** (C26 `PermitFinalBlocked` et/ou C22/C23). **Documente le faux vert auprès de l'exploitant ⇒ déclenche l'action ① de l'option A** (faire renseigner `Reason`/un `Fault` par les branches `:393-404` et `:424-430`) |
| **V2** | `Step8_OutputInterlockOk = 1` **ET** `AllConditionsMet = 0` **ET** `Step4_MotionRequested = 0` (à lire sur la trace : **ne se déduit pas** de `RampTargetStep`, voir la nuance ci-dessous) | la checklist n'est **pas** verte, mais **`Step8` reste vert** | ⚠️ **Faux vert PARTIEL, à relever.** L'opérateur est envoyé chercher une **demande absente** (`Step4`) alors que **sa demande existe** (F22 `JOY1Joystick.State.RawY`, A4 `DeadmanArmed`) — l'information « l'ordre n'a jamais été formé » n'est portée par **aucune** étape. ⇒ même action ①, avec la nuance « la demande est vue par l'opérateur, pas par `FB_Winch` » |
| **V3** | `AllConditionsMet = 0` **ET** l'étape rouge **nomme** la cause (ex. `Step5_NoSafetyFault = 0` ou `Step6_DirectionAllowed = 0`) | la checklist **explique correctement** le blocage | ✅ Pas de faux vert sur ce cas : la checklist fait son travail. **Ne pas surinterpréter** |
| **V4** | `AllConditionsMet = 1` **ET** relais à 1 **ET** aucun mouvement (F17-F20 figés) | la chaîne logicielle a tout autorisé **et tout émis** | ⚠️ cause **physique/HW** ⇒ **T7** déjà couvert (renvoi **T370**) |

> ⚠️ **Nuance à ne pas masquer — `Step4` suit la DEMANDE LOGIQUE amont, PAS `RampTargetStep`**
> *(correction : la première rédaction de cette procédure attribuait à tort `Step4` à `RampTargetStep`)*.
> Chaîne **vérifiée** : `Step4_MotionRequested := WinchM1.State.Busy OR (WinchM1.State.SpeedCmd_Pct > 0.0)`
> (`FB_TroubleshootingView.st:571`) → `WinchM1State.SpeedCmd_Pct := M1LogicRequestSpeedCmd_Pct`
> (`FB_WinchStateProjection.st:88`) → `M1LogicRequestStepTgt := instArbM1.StepTgt` puis
> `M1LogicRequestSpeedCmd_Pct := _WinchSpeedStepTable.StepThreshold_Pct[M1LogicRequestStepTgt]`
> (`PRG_04_Treuils_Benne.st:544`, `:546-550`) → `M1_SpeedCmd_Pct := PRG_04_Treuils_Benne.Data.M1LogicRequestSpeedCmd_Pct`
> (`PRG_02_Acquisition.st:296`). Autrement dit `Step4` reflète **l'arbitrage amont**, avant la coupure
> de `RampTargetStep` en aval (`FB_Winch.st:169-171`, `:216-217`).
> **Conséquence** : **`RampTargetStep = 0` NE garantit PAS `Step4 = 0`** ⇒ la checklist peut être
> **PLEINEMENT verte (V1) avec `RampTargetStep = 0`** (famille 2), et pas seulement « `Step8` seul vert ».
> **V1 est donc au moins aussi probable que V2**, indépendamment de la famille — **les deux issues sont
> à discriminer par la trace** (`AllConditionsMet` I9/I18/I27 + `Step4` I4/I13/I22 + `RampTargetStep` B1/B2).

---

## 6. Lecture du résultat et pièges d'interprétation

```powershell
python TOOLS/PLC_CSV_SNAPSHOT/external_python/trace_to_csv.py `
  "<chemin>\T224_S1_MAINTN1_<date>_<n>.trace" `
  --format wide -o "<chemin>\T224_S1_MAINTN1_<date>_<n>_wide.csv" `
  --metadata "<chemin>\T224_S1_MAINTN1_<date>_<n>_meta.json"
```

### ⚠️ Pièges réels (tous constatés)

1. **Délimiteur `;`** dans les `_wide.csv` produits par l'outil — un import avec la virgule **décale
   toutes les colonnes** sans erreur. Vérifié sur `Suivi_67…wide.csv` (55 colonnes, séparateur `;`).
2. **Convention de nommage mixte** : les groupes `GVL_IHM` (IHM, `_RQ`/`_DQ`/`_DI`) sont tracés **sans
   préfixe de GVL** (`M1_RelayAscent_RQ`, `M1TreuilRetenue.State.Position_M`) tandis que les internes de
   programme sont **pleinement qualifiés** (`PRG_04_Treuils_Benne.…`). C'est la convention des traces
   existantes (`trace_treuils_charge_v1.txt`) — **la reproduire exactement**, ne pas « corriger ».
3. **Lag de 1 scan du bus** : `A1` (`PRG_04.Data.ArmingPermit`) et `A2`
   (`PRG_02.instJoystick.ArmingPermit`) peuvent différer d'un scan (`PRG_02` rang 02 consomme ce que
   `PRG_04` rang 04 produit — boucle **structurelle assumée**, `TROUBLESHOOTING_TREUILS_JoystickContacteur…:339`).
   **Ne pas l'interpréter comme un bug.**
4. **`M1InterlockEnable` vs `Enable`** : `PRG_06` gate la barrière par `AND NOT PowerCutOff`
   (`PRG_06:128-129`) ; un `State = DISABLED` peut donc venir d'un `PowerCutOff` et non d'une perte de
   permis. Lire H13/H16 avant de conclure.
5. **Ne pas conclure sur une période non relevée** : à 100 ms (le défaut des traces T224 existantes),
   une fenêtre de 500 ms ne donne que 5 points — **toute datation fine serait un artefact**.
6. **Ne pas forcer les DI** : un DI forcé rend la trace non conclusive sur tout ce qui en dépend
   (c'est **exactement** la leçon du revert `263fae18`).

### Ce que la trace NE prouvera PAS (écrit noir sur blanc)

- ⛔ **L'ORDRE D'EXÉCUTION DES TÂCHES / PROGRAMMES CODESYS.** L'ordre `PRG_02 → … → PRG_06 → PRG_07` dans
  la `MainTask` est établi par la **documentation** (`AF_Partie-02_Architecture_Programme_v3.2.md:521-527`,
  `:575`) et par les commentaires du code, **jamais par un artefact mécanique** :
  `AF_Partie-02:610` constate lui-même qu'**aucun gate ne vérifie l'ordre inter-programmes**, et
  `:532` précise que **« la tâche CODESYS en ligne reste à confirmer »**.
  `PRJ_CODESYS/PROJ_Full_ImportExport/Device.export` est **interdit de lecture** (périmé par doctrine,
  `AGENTS.md`) et le bundle PLCopenXML **ne contient pas** la configuration de tâche
  (vérifié : `CODE_XML/CODE_Bundle.xml` = 4 occurrences de `MainTask`, toutes en commentaire).
  ⇒ **Une trace à 10 ms ne prouve pas l'ordre** : elle montre des valeurs, pas la séquence d'exécution.
  Toute affirmation sur le « conflit de scan » reste **documentaire** et doit être écrite comme telle.
- ⛔ **La cause d'un blocage purement physique** (contacteur collé, frein mécanique qui ne s'ouvre pas,
  charge bloquée) : la trace montre **qu'il n'y a pas d'effet**, pas **pourquoi** (→ T370).
- ⛔ **Ce qui se passe hors des 172 canaux** : toute condition non tracée reste **non instruite**.
- ⛔ **La validité de la configuration CODESYS en ligne** (tâche, ordre, options de compilation) —
  aucune trace ne la porte.

### Ce qui SERA concluable

✅ La famille de cause, **par axe et par sens**, pour chaque occurrence capturée du symptôme (T1→T8).
✅ La **condition exacte** de la famille 1 (F1-a → F1-i), donc l'arbitrage du périmètre T224 (G1/G2/G3).
✅ La **fenêtre réelle** des temps idle (§5.4) — et la **réfutation ou confirmation** du chiffre « ~1,5 s ».
✅ L'**atteignabilité** des cas permanents C12/C13/C18 (Scénarios 3 et 4) et de leur caractère **muet**.
✅ Le **caractère muet** de chaque refus (aucun `Fault`, aucun `Reason`) — et donc la **confirmation du
   faux vert** de la checklist (`ST_MotionChecklist.st:30` vs `Idx416/Idx417`).

---

## 7. Interdits

- Aucune modification de `CODE/`, `CODE_XML/`, `TOOLS/TEST_AUTO_CI/`, aucun test, aucun gate, aucune IHM.
- **Aucun forçage de variable de logique** — en particulier **ne pas** forcer `M1/M2_ContactorsReleased_DI`
  (leçon du revert `263fae18`). Seuls sont autorisés les réglages `GVL_Simulation.*` et IHM déjà normaux
  (`TglJoystickMaster`, `ForceStepTarget` — à consigner).
- Aucune lecture de `PRJ_CODESYS/PROJ_Full_ImportExport/Device.export`.
- Ne pas conclure « cause prouvée » sur une trace dont la **période effective** n'a pas été relevée.
- Ne pas interpréter une trace à 100 ms comme une preuve de délai : la conclusion doit **nommer la période**.
- Les preuves durables (trace + `_wide.csv` + `_meta.json` + analyse) vont sous `DOC/WFLOW/`
  (`TOOLS/AGENT_WORKFLOW/docs/STRUCTURE_AND_CLEANUP.md`) ; **aucun artefact n'est supprimé par un agent**.

---

## 8. Ce que cette procédure ne remplace pas

> 🔒 **BORNAGE À CONNAÎTRE AVANT TOUT ARBITRAGE (exigence humaine explicite).**
> Le lot correctif issu de cette trace toucherait `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` — un
> fichier de **barrière finale de sécurité** — **en PUBLICATION SEULE, JAMAIS dans la logique d'interlock** :
> ① faire renseigner `Reason` (et/ou un `Fault`) par les deux branches aujourd'hui muettes
> (`:393-404`, `:424-430`) ; ② rendre `PermitFinalBlocked` **publiable** (elle est aujourd'hui **VAR privée
> `:87`**) — donc un **changement d'interface**, pas un changement de comportement.
> ⛔ **Sont exclus par avance** : toute modification des conditions de coupure, des temporisations
> (`RestartDelay`, `DeadTime`, `SenseHold`, `BrakeTimeout`), des latches, de `AuthorizedStep`, et **tout**
> ce qui alimente `Ready`/`State`/`Fault`. **C'est exactement le chemin qui a cassé le banc** (revert
> `263fae18`) : une information de disponibilité ne se paie jamais par un patch de logique de sécurité.
> ⚠️ **Cette borne est à trancher par l'humain** — la procédure ne fait que la **poser noir sur blanc**
> pour que l'arbitrage ne se fasse pas à l'aveugle. Elle concerne aussi `FB_WinchStateProjection.st`
> (ajout de projection, sans logique) et `FB_TroubleshootingView.st` / `ST_MotionChecklist.st` (affichage).

- Le **cadrage du correctif** reste à trancher par l'humain **après** la trace (Étape B, C4).
- La **mise à jour documentaire** (`AF_Partie-08:384` contradictoire avec `:594-596` ; contrats T224/T228
  portant le chiffre du lot annulé) est un **lot séparé** — voir le bloc de mise à jour en tête de
  `DOC/WFLOW/AUDITS/DESIGN/CADRAGE_T325_D18_INTERLOCK_DIRECTION_v1.0.md`.
- La **sérialisation avec T370** : ne pas dérouler T370 (retour contacteur) en parallèle, T228 et T370
  consomment/cartographient le **même** latch `ContactorStuck`.
- L'**exactitude des métadonnées** : toute taille, durée ou période citée dans ce dossier doit être
  **mesurée** (cf. l'en-tête) — jamais estimée. Un chiffre annoncé sans mesure est un chiffre faux.
