# 🔗 T351 — Treuils M1/M2 : du geste joystick au contacteur (2 chaînes, MANU/MAINTENANCE et AUTO/SEMI_AUTO)

> 📌 **Document de référence permanente** — pas une note de session. Toute ligne citée est vérifiable
> par `Select-String` sur l'état disque ancré en §1. Cadre : `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T351_CARTOGRAPHIE_TREUILS.yaml` (AC1→AC12).
> Lot parent : T334 (M3, `TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md`) — **non modifié** par ce lot
> (verrou d'écriture T334 = DSH07). Complément M3 : voir §12 (annexe livrée par DSH17).
>
> 🔴 **AVERTISSEMENT DE REFERENCE — à lire avant toute utilisation.** Deux fichiers cités ici
> **ont été modifiés par des lots concurrents PENDANT la rédaction de ce document**. Les numéros de
> ligne publiés sont valides **pour les blobs listés en §1 uniquement** (état disque relevé à
> **2026-09-21T01:29:49+02:00**). Si un blob a changé, **re-grep obligatoire** (§1 et §14).

---

## 0. 🧭 Réponse courte (à lire avant les tableaux)

- **Un seul contrat d'ordre par treuil, deux règles de production.** M1 et M2 ont **chacun UN SEUL FB de
  mouvement** (`FB_Winch`, instancié `PRG_04_Treuils_Benne.st:31-32`) qui reçoit **un seul contrat de requête**
  (`ReqM1Winch` / `ReqM2Winch`, assemblé `PRG_04:1386-1419` / `:1473-1493`). Il n'existe **pas deux ordres
  concurrents** vers l'axe : il existe **un arbitre unique par treuil** qui choisit la source selon le mode.
- **Point de convergence de source :** `FB_WinchCmdArbitrationM1` / `M2`, instanciés `PRG_04:54-55`, appelés
  `PRG_04:530` et `:553` — un seul point d'entrée de demande logique par treuil.
- **Point de convergence aval (identique aux 2 chaînes) :** `PRG_04:1593-1629` publie
  `WinchM1/M2FinalInterlockRequest` → `PRG_06_Outputs.st:149` / `:215` (`FB_WinchOutputInterlock`) →
  `PRG_06:369-384` écrit les `%Q…` physiques. **Aval strictement unifié.**
- **Ce qui diverge réellement — et ce n'est PAS ce qu'on croit :** ce n'est pas la *route* joystick vs cycle
  (elle converge en amont), c'est **le treuil M2 lui-même, qui possède une troisième voie de commande
  réservée (le chemin benne) absente de M1** (`FB_WinchCmdArbitrationM2.st:65-82`) **et qui peut court-circuiter
  la demande du séquenceur de cycle** en SEMI_AUTO (`:65-67` autorise `E_Mode.SEMI_AUTO`). M1 n'a **rien**
  d'équivalent.
- **Le brief T351 se trompe sur deux points structurels** (détaillés §6.2 et §10) : les numéros de la garde
  croisée M1/M2, et l'affirmation implicite de symétrie M1/M2. **Verdict : deux contenus de contrat possibles
  par treuil (3 à 4 sources selon le mode), un seul point de sommation par treuil** — la question
  « un seul ou deux ? » du brief M3 ne se transpose pas telle quelle, et la réponse M1/M2 n'est
  **pas identique** à celle de M3 (voir §5.1).

---

## 1. 🧊 Contexte figé, périmètre et ANCRAGE DE RÉVISION

| Champ | Valeur |
|---|---|
| Besoin | Comprendre **exhaustivement, à tout moment**, le chemin d'une commande du geste joystick (ou de la séquence auto) jusqu'au **contacteur physique**, en MANU/MAINTENANCE **et** AUTO/SEMI_AUTO, pour anticiper/diagnostiquer les blocages sans relire tout le code |
| Mission | T351 — cartographie M1 (Retenue) et M2 (Benne) sur le gabarit T334 §4/§5 |
| Date du lot | 2026-09-21 |
| **COUVERT** | Chaîne de commande complète M1/M2 : acquisition joystick, arbitrage, permis, safety, interlock direction D18, barrière finale, écriture `%Q`, mapping E/S. Les **4 familles de sources** (§8). Branches MAINT_N1/N2 (§7). |
| **NON COUVERT** | Translation M3 (déjà T334) · benne `FB_Bucket` dans son détail interne · homing machine `FB_CycleMachineHoming` en tant que grafcet · calibrage codeurs · IHM (hors `CODE/`) · **phase 2 outil web interactif : explicitement hors périmètre, non commencée** |

### 🔐 Bloc d'ancrage de révision (AC2)

```
HEAD              = 065591fb2633af098a39596e35de24e00e9916e2  (court : 065591fb)
                    « fix(benne): T262 phase B - seuil d'ouverture benne cable
                      (branche additive, borne 20%) [NON TESTE MACHINE] » — 2026-09-21 01:32:32 +0200
Horodatage final  = 2026-09-21T01:33:25+02:00
```

| Fichier cité | blob SHA (`git hash-object`) — **état de référence pour tous les numéros de ce document** | État vs HEAD |
|---|---|---|
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st` | `31760d59b4e09b03a8e91b2358f8804a6b1985ad` (1982 l) | ✅ **PROPRE** — committé par `065591fb` (T262 phase B) après avoir été sale pendant le lot |
| `CODE/M_MAIN/PRG_02_Acquisition.st` | `5b8baa9ba8ea0e9e0204ac8a5cc0a9a6b1bd2bb7` (719 l) | ⚠️ **SALE** — non committé (+11/−6). 🔴 **FICHIER CHAUD : 3 blobs en 8 min** (`fabb8f764dd8` → `892de7b784f5` → `5b8baa9ba8ea`) |
| `CODE/M_MAIN/PRG_07_Supervision.st` | `c10f004151f80e099eb04537c9a87cc8a3d4c986` (920 l) | ✅ **PROPRE** (était sale pendant le lot ; committé depuis) |
| `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` | `9c493a5f0d5726b3d276c455bc3efca83fe29ebd` (838 l) | ✅ **PROPRE** (était sale pendant le lot) |
| `CODE/M_MAIN/PRG_03_Modes_Cycle.st` | `6e22c76df8623759f0f696d5f003ec34540b8fd1` (555 l) | ✅ PROPRE |
| `CODE/M_MAIN/PRG_06_Outputs.st` | `3b7534a3acd4c5bba6c667118abaf32f41eb3f67` (549 l) | ✅ PROPRE |
| `CODE/H_TREUILS_BENNE/FB_Winch.st` | `d6aba669cb49050414e74f484789c091337b0387` | PROPRE |
| `CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM1.st` | `27247259430b674e6e3e63d265ca0c5ea311c7a7` | PROPRE |
| `CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM2.st` | `0e757b00558cde1ea9c17f4af88f05931dd19578` | PROPRE |
| `CODE/H_TREUILS_BENNE/FB_WinchDirectionInterlock.st` | `5fa9e0405ac30ff83fb384e22725fae134729af6` | PROPRE |
| `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st` | `14aa2c20aaae8a5890e20584041df4d7817c3617` | PROPRE |
| `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st` | `eea649deaebd8000bf9f64e598ff65ed0ff9ab91` | PROPRE |
| `CODE/H_TREUILS_BENNE/FB_WinchSync.st` | `03bfca8e9689123fcd7462d2d6de8333d41654ae` | PROPRE |
| `CODE/H_TREUILS_BENNE/FB_WinchStateProjection.st` | `1d5e0667652716c241a670a02446f4d6cafa368e` | PROPRE |
| `CODE/H_TREUILS_BENNE/FB_WinchLoadEstimator.st` | `6ba6434196882333cd3b077e92c56e22c425ee7f` | PROPRE |
| `CODE/H_TREUILS_BENNE/FB_WinchSpeedLearning.st` | `8a845b8a37830c803c8996ea5fec9053f48c9283` | PROPRE |
| `CODE/H_TREUILS_BENNE/FB_WinchStepShaper.st` | `2bf61e9238bc80c8e9608c4855bbe13f76ce5ffc` | PROPRE |
| `CODE/H_TREUILS_BENNE/FB_SpeedStep.st` | `76dc8a05657d2808fa0ad9e4022d634622abbb66` | PROPRE |
| `CODE/H_TREUILS_BENNE/FB_SyncContactor.st` | `9c0b0efda614b98eb90225ace3ba959a9ab7c947` | PROPRE |
| `CODE/H_TREUILS_BENNE/FB_BucketCmdArbitration.st` | `d2a118ac15599571c0a7b02f945af5e7de83e2fb` | PROPRE |
| `CODE/A_COMMUN/FB_ContactorProtector.st` | `e9dc819f3f5f1f721ee971dc488f0a43d9d76d77` | PROPRE |
| `CODE/D_JOYSTICK/FB_Joystick.st` | `4d373c8ed388eae7257d4ca6a391e73e43e4cfbc` | PROPRE |
| `CODE/D_JOYSTICK/FB_AxisScale.st` | `85d6fb1bb6ae977f7d2da7c8745a1e130d3afee7` | PROPRE |
| `CODE/F_MODES/FB_Modes.st` | `4a890744c9f32c858922338d9dd989a5e0edbcca` | PROPRE |
| `CODE/G_CYCLE/FB_CycleSemiAuto.st` | `032af59fc1fa8ebb90c90b43c69dc30b71472419` | PROPRE |
| `CODE/G_CYCLE/FB_CycleMachineHoming.st` | `211136fff38170468488f8a229c186669109cb01` | PROPRE |
| `CODE/GVL_PERSISTENT.st` | `0e5860a57b5d7f369597810d2d59e167a61784eb` | PROPRE |

**POURQUOI cet ancrage est obligatoire — démonstration vécue dans ce lot :**

1. `PRG_04_Treuils_Benne.st` était **modifié non committé** par un lot concurrent pendant tout le lot
   (le diff disque portait des lignes **« T262 phase B »** : `instCloseThreshold : FB_BucketCloseThreshold;`
   `:27`, `ThresholdMeasureValid` `:28`, bloc de branchement `:1811-1826`).
   ✅ **Résolu à `01:32:32`** : ce lot a été **committé** sous `065591fb`
   (« fix(benne): T262 phase B - seuil d'ouverture benne cable (branche additive, borne 20%) [NON TESTE MACHINE] »)
   → le fichier est désormais **PROPRE** et son blob est **devenu le blob de HEAD**. Le document continue
   de s'ancrer sur ce blob, qui n'a pas changé.
2. **Constat mesuré à 01:23:40 :** le blob disque valait alors `e6005d533cac…` — la valeur annoncée par
   l'orchestrateur (`e8551c3a80f6`, « 1950 lignes ») était **périmée**, et « 1950 lignes » correspond en
   réalité au **blob de HEAD de l'époque (`9236e5ba`)**, pas au disque (**1982 lignes**). Toute référence
   dérivée de HEAD était donc fausse d'environ +32 en zone basse : c'est exactement le piège REX T345.
3. 🔴 **Et les blobs ont changé PENDANT ce lot — deux fois.**
   (a) `PRG_04_Treuils_Benne.st` : `e6005d533cac` (01:23) → **`31760d59b4e0`** (01:29), soit **+1 ligne**
   décalant tout le fichier à partir de ~380 — **blob stable depuis**, puis committé.
   (b) `PRG_02_Acquisition.st` : `fabb8f764dd8` → `892de7b784f5` (**+6 lignes** dès ~226) → puis
   **`5b8baa9ba8ea`** (**−1 ligne**, 719 lignes) mesuré à `01:31` : **trois blobs différents en 8 minutes**.
   **Les deux chaînes §3/§4 ont donc été entièrement re-dérivées et re-vérifiées deux fois** sur l'état
   disque (133 + 42 ancres de contrôle, §14), puis **une troisième fois en contrôle exhaustif** : les
   **211 références `fichier:ligne` explicites du document ont été relues une par une contre le disque**
   (`01:33:25`, HEAD `065591fb`) → **211/211 conformes**. C'est la démonstration exacte du risque annoncé
   par le contrat (§`alert_duty`, 2ᵉ point) — et la preuve qu'**un lot documentaire seul ne peut pas
   garantir AC10** tant qu'un lot de code tourne en parallèle (§10-9).
4. ⚠️ **Les mesures d'ancrage de l'orchestrateur (01:30) sont elles-mêmes périmées sur 1 fichier** :
   il annonçait `PRG_02_Acquisition.st` à **720 lignes / blob `892de7b784f5`** ; à `01:31` puis `01:33:25`
   le disque portait **719 lignes / blob `5b8baa9ba8ea`**. Ce document s'ancre sur la **mesure disque
   directe**, jamais sur une valeur transmise. **Leçon générale : sur ce dépôt, une mesure d'ancrage
   vieillit en minutes — elle doit être reprise juste avant écriture, par l'auteur du document.**

> 📌 **Règle d'usage :** les numéros `PRG_04:…` de ce document sont valides **pour
> `31760d59b4e09b03a8e91b2358f8804a6b1985ad` uniquement** (= blob de HEAD `065591fb`), et les `PRG_02:…`
> pour `5b8baa9ba8ea0e9e0204ac8a5cc0a9a6b1bd2bb7` uniquement (**⚠️ fichier chaud, encore SALE —
> re-vérifier en priorité**). **Avant d'utiliser une ligne, comparer le blob**
> (`git hash-object <fichier>`). Si le blob diffère → re-grep, ne pas extrapoler.

---

## 2. 🧩 Méthode et conventions de lecture

| Colonne | Signification exacte |
|---|---|
| **Variable** | Nom **exact** et complet du signal, vérifiable par `Select-String` littéral. Forme `M1X / M2X` = les deux existent, symétriques |
| **Producteur fichier:ligne** | Le POU qui **ÉCRIT** la valeur (règle projet : producteur unique). Jamais le déclarant, sauf si la déclaration porte la valeur |
| **Consommateur fichier:ligne** | Le POU qui **LIT la valeur pour DÉCIDER** de la suite (consommateur décisionnel). Les miroirs IHM/diagnostic sont exclus sauf mention |
| **Rôle** | Une phrase : ce que le signal change dans le comportement physique |

**Re-vérifier une ligne (commande exacte, une seule invocation PowerShell par commande) :**

```powershell
Select-String -Path CODE\M_MAIN\PRG_04_Treuils_Benne.st -Pattern 'WinchBothMotionReady'
```

```powershell
Select-String -Path CODE\H_TREUILS_BENNE\FB_WinchCmdArbitrationM2.st -Pattern 'Context.BucketBusy'
```

**Contrôle d'ancrage avant usage (obligatoire si le dépôt a bougé) :**

```powershell
git hash-object CODE/M_MAIN/PRG_04_Treuils_Benne.st
```

**Conventions :**

- `⚠️ASYM` = ligne où **M1 et M2 ne sont pas symétriques** pour une raison qui n'est pas un simple suffixe.
  Toutes les `⚠️ASYM` sont reprises et justifiées en **§6.4**.
- `🟢` = fait vérifié par lecture disque dans ce lot · `🟡` = hypothèse · `🔴` = incertitude déclarée (§11).
- `%Q…` / `%I…` = adresse physique issue de `TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv` (relu, §9).

---

## 3. 🔗 PARTIE 1 — CHAÎNE MANU / MAINTENANCE (codes M01, M02, …)

**Mode couvert :** `MAINT_N1` / `MAINT_N2` (branche `ELSE` de l'arbitre, `FB_WinchCmdArbitrationM1.st:62-104`
et `FB_WinchCmdArbitrationM2.st:91-133`). En `SEMI_AUTO`, l'arbitre bascule sur sa branche dédiée (§4).

| # | Variable | Producteur fichier:ligne | Consommateur fichier:ligne | Rôle |
|---|---|---|---|---|
| M01 | `JoyYRaw_ANA2` (global E/S `%IW115`) | mapping `Device_IO_20260918.csv:521` ; recopie `CODE/M_MAIN/PRG_02_Acquisition.st:182` | `PRG_02_Acquisition.st:482` (`RawY`) | Valeur brute ADC de l'**axe Y** (treuils) |
| M02 | `JoyBtnRaw` (global E/S `%IX226.0`) | mapping `Device_IO_20260918.csv:496` ; recopie `PRG_02_Acquisition.st:183` | `PRG_02_Acquisition.st:483` (`RawButton`) | Bouton homme-mort joystick (brut) |
| M03 | `HwIn.Operator` (réel **ou** simulé) | `PRG_02_Acquisition.st:445` (`SEL(OperatorInputSourceSimulated, HwReal.Operator, HwSim.Operator)`) | `PRG_02_Acquisition.st:481-483` | Frontière réel/simulé de la manche |
| M04 | `ScaleY.OutPct` (axe Y mis à l'échelle −100..+100 %) | `CODE/D_JOYSTICK/FB_AxisScale.st` (instance locale, appel `FB_Joystick.st:184`) | `CODE/D_JOYSTICK/FB_Joystick.st:185`, `:272` | Deadband + mise à l'échelle axe Y (treuils) |
| M05 | `AtNeutralXY` | `FB_Joystick.st:185` | `FB_Joystick.st:211`, `:248` ; `PRG_02_Acquisition.st:494` ; `PRG_03_Modes_Cycle.st:196` | Les 2 axes au neutre **brut** (avant homme-mort) |
| M06 | `DeadmanArmed` | `FB_Joystick.st:232` (armé), `:239` (désarmé si `ArmingPermit` retiré), `:249` (retour au neutre soutenu) | `FB_Joystick.st:253`, `:272` ; `PRG_02_Acquisition.st:493` ; arbitres M1 `:121`, M2 `:147` ; `PRG_03_Modes_Cycle.st:141` | Homme-mort **qualifié** — condition de COMMANDE |
| M07 | `AxisCmdY.Direction` (−1/0/+1) | `FB_Joystick.st:305-307` | arbitres M1 `:91-92`, M2 `:120-121` ; `PRG_03_Modes_Cycle.st:140` | Sens du geste treuil |
| M08 | `AxisCmdY.DirectionPositive` / `.DirectionNegative` | `FB_Joystick.st:278` / `:279` | `PRG_03_Modes_Cycle.st:197-198` (`JoystickPush`/`JoystickPull`) | Bits de sens qualifiés (séparés de la magnitude) |
| M09 | `AxisCmdY.StepTgt` (palier 1..5, 0=arrêt) | `FB_Joystick.st:294-301` (hystérésis par palier) | arbitres M1 `:93,98`, M2 `:122,127` | **Producteur UNIQUE du palier joystick** (pas de re-dérivation %→palier en aval) |
| M10 | `AxisCmdY.AtNeutral` | `FB_Joystick.st:280` | `FB_Joystick.st:281` | Neutralité qualifiée axe Y (zéro la consigne) |
| M11 | `Data.Joystick.AxisY` / `.DeadmanArmed` / `.AtNeutralXY` | `PRG_02_Acquisition.st:492` / `:493` / `:494` | `PRG_04_Treuils_Benne.st:532` et `:555` (entrée `Joystick` des 2 arbitres) | Bus inter-PRG du geste treuil qualifié |
| M12 | `instModes.Auth.JoystickWinchSelectArbitrated` (0 couplé / 1 M1 / 2 M2) | `CODE/F_MODES/FB_Modes.st:395` (nominal), `:398` (forcé 0 hors MAINT), `:373`, `:389`, `:392` (garde Trémie + séquence T248) | arbitres M1 `:90`, M2 `:119` ; `PRG_03_Modes_Cycle.st:142` ; `PRG_04:305` | **Sélecteur de treuil pilote au joystick** |
| M13 | `GVL_IHM.Modes.Cmd.TglJoystickMaster` | IHM (hors `CODE/`) | `PRG_03_Modes_Cycle.st:139` ; `PRG_04:537` et `:560` ; arbitres M1 `:68,121,124`, M2 `:97,147,150` | Switch machine : joystick maître ↔ boutons IHM |
| M14 | `ArbIHM.BtnAscentM1` / `BtnDescentM1` (et `…M2`, `BtnWinchBothAscent/Descent`) | `PRG_04_Treuils_Benne.st:492-497` ← `GVL_IHM…` | arbitres M1 `:75-82`, M2 `:104-111` | Boutons IHM de marche treuil (mode Boutons) |
| M15 | `Data.WinchBothIntent.Active` (intention M1+M2 simultanée) | `PRG_03_Modes_Cycle.st:297` (+ sens `:298-299`) | `PRG_04_Treuils_Benne.st:284` → `WinchBothMotionActive` | Source **unique** de l'intention couplée, tous modes |
| M16 | `WinchBothMotionDirection` | `PRG_03_Modes_Cycle.st:140` (joystick) / `:146-150` (boutons) | `PRG_03_Modes_Cycle.st:298-299` | Sens de l'intention couplée |
| M17 | `instModes.Auth.Mode` | `CODE/F_MODES/FB_Modes.st` → `PRG_03_Modes_Cycle.st:291` | `PRG_04:296`, `:927`, `:1458`, `:1524` ; arbitres M1 `:56`, M2 `:67,85` | Mode de conduite (MAINT_N1/N2, SEMI_AUTO, DISABLE) |
| M18 | `instModes.Auth.SyncEnable` / `InhibitM1` / `InhibitM2` | `FB_Modes.st:307` / `:340` / `:341` | `PRG_04:637`, `:931`, `:1458`, `:1524` | Autorisations de synchronisation et d'inhibition d'axe |
| M19 | `ArbContext.BucketBusy` | `PRG_04_Treuils_Benne.st:499` ← `instBucket.Lifecycle.Busy` | arbitre M1 `:117` ; M2 : **absent** (voir `⚠️ASYM` §6.4-A2) | Gèle la commande pendant/après une action benne |
| M20 | `ArbContext.M1AscentAllowed` / `M1DescendAllowed` / `M2AscentAllowed` / `M2DescendAllowed` | `PRG_04_Treuils_Benne.st:517-520` ← `EffectivePermitM1/M2_*` | arbitres M1 `:114-115`, M2 `:141-142` | **Atomicité couplée** : en both, les 2 permis du sens demandé sont exigés |
| M21 | `EffectivePermitM1_Ascent` / `EffectivePermitM1_Descend` | `PRG_04_Treuils_Benne.st:1113` / `:1111` | arbitres `:114-115` ; `PRG_04:1462-1463` (entrée `FB_Winch`) ; `:1611-1612` (publication) | Permis directionnel effectif M1 (process AND safety AND NOT SafeStop AND couplage) |
| M22 | `EffectivePermitM2_Ascent` / `EffectivePermitM2_Descend` | `PRG_04_Treuils_Benne.st:1114` / `:1112` | arbitres `:114-115`, `:141-142` ; `PRG_04:1131-1134` → `M2AscentPermitApplied`/`M2DescendPermitApplied` | Permis directionnel effectif M2 |
| M23 | `instArbM1.RunRequest` | `FB_WinchCmdArbitrationM1.st:116-125` (gate complet) | `PRG_04_Treuils_Benne.st:541` → `M1LogicRunRequest` | Demande de marche M1 arbitrée (mode manuel) |
| M24 | `instArbM1.ReqAscent` / `.ReqDescend` | `FB_WinchCmdArbitrationM1.st:72`, `:76`, `:81`, `:91-92` | `PRG_04_Treuils_Benne.st:542-543` | Sens demandé M1 arbitré |
| M25 | `instArbM1.StepTgt` | `FB_WinchCmdArbitrationM1.st:74`, `:78`, `:82`, `:93`, `:98` | `PRG_04_Treuils_Benne.st:544` | Palier de vitesse M1 arbitré (1..5, 0=arrêt) |
| M26 | `instArbM2.RunRequest` | `FB_WinchCmdArbitrationM2.st:143-151` | `PRG_04_Treuils_Benne.st:564` → `M2LogicRunRequest` | Demande de marche M2 arbitrée — **gate sans `BucketBusy`** |
| M27 | `instArbM2.ReqAscent` / `.ReqDescend` / `.StepTgt` | `FB_WinchCmdArbitrationM2.st:70-71`, `:74-82`, `:105-111`, `:120-122` | `PRG_04_Treuils_Benne.st:565-567` | Sens + palier M2 arbitrés |
| M28 | `instModes.Auth.WinchSelTransitionHold` | `FB_Modes.st:410` | `PRG_04_Treuils_Benne.st:572-575` | **HOLD T248** : changement de sélecteur → M1 **et** M2 forcés à 0 jusqu'à l'arrêt confirmé |
| M29 | `ReqM1Winch.RunRequest` / `.ReqAscent` / `.ReqDescend` / `.SpeedStepReq` | `PRG_04_Treuils_Benne.st:1386-1389` | `PRG_04_Treuils_Benne.st:1464` (entrée `WinchRequest`) | Contrat de requête M1 vers le FB de mouvement |
| M30 | `ReqM2Winch.RunRequest` / `.ReqAscent` / `.ReqDescend` / `.SpeedStepReq` | `PRG_04_Treuils_Benne.st:1473-1476` | `PRG_04_Treuils_Benne.st:1530` | Contrat de requête M2 vers le FB de mouvement |
| M31 | `ReqM1Winch.TopLimitM` / `ReqM2Winch.TopLimitM` | `PRG_04_Treuils_Benne.st:1417` ← `TopLimitM1_M` (`:883-885`) / `PRG_04:1491` ← `TopLimitM2_M` (`:886-888`, ± `:899-907`) | `CODE/H_TREUILS_BENNE/FB_Winch.st:173` (zone de ralentissement haut) | **Limite haute active transmise au FB** (7,5 m nominal / 8,5 m override — §6.3) |
| M32 | `ReqM1Winch.MaxStepUp` / `.MaxStepDown` | `PRG_04_Treuils_Benne.st:1410-1411` ← `CommonMaxStepAscent/Descent` (§5ter `:1226-1290`) | `FB_Winch.st:226`, `:304` (`ActiveMaxStep`) | Plafond de palier M1 (bridages codeur non fiable, synchro, approche haute) |
| M33 | `ReqM2Winch.MaxStepUp` / `.MaxStepDown` | `PRG_04_Treuils_Benne.st:1484-1485` ← `M2MaxStepUp/M2MaxStepDown` (`:1293-1344`) | `FB_Winch.st:226`, `:304` | Plafond M2 — **plus restrictif**, propre à la benne (`⚠️ASYM` §6.4-A7) |
| M34 | `SafeStopM1_Active` / `SafeStopM2_Active` | `PRG_04_Treuils_Benne.st:1105` / `:1106` (`SafeStopM*_Raw OR (CoupledBoth AND SafeStop autre)`) | `PRG_04:1461` / `:1527` (entrée `SafeStop`) ; `:1596` / `:1617` (publication) | **Couplage croisé** : un SafeStop peut geler les 2 treuils |
| M35 | `M1WinchSensors.SpeedGuardEnable` / `.SpeedGuardReady` | `PRG_04_Treuils_Benne.st:1441` (**FALSE codé en dur**) / `:1442` | `FB_Winch.st:234` | Garde-fou survitesse **HORS SERVICE** par décision assumée (dette safety) |
| M36 | `M1WinchCfg.DirectionInterlockDelayAscent` / `…Descent` | `PRG_04_Treuils_Benne.st:1452` (`T#800ms`) / `:1453` (`T#500ms`) | `FB_Winch.st:203-204` → `FB_WinchDirectionInterlock.st:29-30` | **Délai plein de D18** (temps mort d'inversion) |
| M37 | `instWinchM1.DirectionChangePending` | `FB_WinchDirectionInterlock.st:130`, `:143`, `:154`, `:158` (via `FB_Winch.st:209`) | `PRG_04_Treuils_Benne.st:1405`, `:1499` (**garde croisée**), `:1541` ; `FB_Winch.st:216` | **Cœur de D18** : inversion non encore adoptée → palier forcé à 0 |
| M38 | `instWinchM1.CommandedAscent` / `.CommandedDescend` | `FB_WinchDirectionInterlock.st:136-137`, `:150-151` (via `FB_Winch.st:206-207`) | `FB_Winch.st:271` (cadence), `:284-293` (**relais de sens**) | Sens **réellement adopté** par le treuil M1 |
| M39 | `instWinchM1.StepNumber` | `CODE/H_TREUILS_BENNE/FB_WinchStepShaper.st` ← `FB_Winch.st:281` (`StepShaper.ShapedStep`) | `FB_Winch.st:284-293` (relais), `:300-309` (contacteurs) ; `PRG_04:1609` | **Palier réellement appliqué** — c'est lui qui ouvre les contacteurs |
| M40 | `instWinchM1.RelayFwd` / `.RelayRev` | `CODE/H_TREUILS_BENNE/FB_Winch.st:284-293` (conditionnés `StepNumber > 0` **ET** sens adopté) | `PRG_04:1603-1604` (publication) ; `:1610` (`RequestedStep`) et `:1596` (SafeStop) | **Relais de SENS M1** — `RelayFwd` = montée/extraction (`%QX27.4`), `RelayRev` = descente/plongée (`%QX27.5`) |
| M41 | `instWinchM2.RelayFwd` / `.RelayRev` | `FB_Winch.st:284-293` (même FB, instance M2) | `PRG_04:1620-1621` | Relais de sens M2 — `RelayFwd` = fermeture grappin (`%QX27.6`), `RelayRev` = ouverture (`%QX27.7`) |
| M42 | `instWinchM1.Contactor1..4` | `FB_Winch.st:306-309` ← `FB_SpeedStep` (décodage cumulatif de table) | `PRG_04:1605-1608` | **Contacteurs de palier M1** (`%QX26.0..26.3`) |
| M43 | `instWinchM2.Contactor1..4` | `FB_Winch.st:306-309` (instance M2) | `PRG_04:1622-1625` | Contacteurs de palier M2 (`%QX26.4..26.7`) |
| M44 | `instWinchM1.StepNumber` → `WinchM1FinalInterlockRequest.RequestedStep` | `PRG_04_Treuils_Benne.st:1609` (`:1626` en M2) | `PRG_06_Outputs.st:164` (`:230` en M2) | Palier demandé franchissant la frontière PRG_04 → PRG_06 |
| M45 | `WinchM1FinalInterlockRequest` (14 champs) / `WinchM2FinalInterlockRequest` | `PRG_04_Treuils_Benne.st:1593-1612` / `:1614-1629` | `PRG_06_Outputs.st:150-164` / `:216-230` | **Bus de la demande finale vers la barrière** (Enable, SafeStop, permis, relais, contacteurs, palier, retours) |
| M46 | `M1InterlockEnable` / `M2InterlockEnable` | `PRG_06_Outputs.st:128-129` / `:191-192` (`Enable AND NOT PowerCutOff`) | `PRG_06_Outputs.st:150` / `:216` | Gate finale : coupe tout si `PowerCutOff` |
| M47 | `M1PowerCutOffSafetyInfo` / `M1SafeStopSafetyInfo` | `PRG_06_Outputs.st:131-137` / `:139-145` | `PRG_06_Outputs.st:147` (synthèse) | Défauts **coupant la puissance** vs déclenchant un **SafeStop** (M1) |
| M48 | `M2PowerCutOffSafetyInfo` / `M2SafeStopSafetyInfo` | `PRG_06_Outputs.st:194-200` / `:202-211` | `PRG_06_Outputs.st:213` | Idem M2 — **plus 3 termes en plus** (`SlackCable`, `BucketState.Error`, `CoupledMotionBlockedByBucket`) (`⚠️ASYM` §6.4-A9) |
| M49 | `instWinchOutputInterlockM1.RelayFwd/Rev` / `.Contactor1..4` | `CODE/H_TREUILS_BENNE/FB_WinchOutputInterlock.st:458-464` (via `:487` pour `BrakeCmd`) | `PRG_06_Outputs.st:167-172` | **Barrière finale M1** : watchdog frein, anti-redémarrage, coupure dure sur `SafeStop`/`PermitFinalBlocked` |
| M50 | `instWinchOutputInterlockM2.RelayFwd/Rev` / `.Contactor1..4` | `FB_WinchOutputInterlock.st:458-464` (instance M2) | `PRG_06_Outputs.st:233-238` | Barrière finale M2 |
| M51 | `instWinchOutputInterlockM1.BrakeCmd` / `M1BrakeCmd` | `FB_WinchOutputInterlock.st:487` (`RelayFwd OR RelayRev`) ; recomposé `PRG_06_Outputs.st:307` **après** filtrage anti-chatter | `PRG_06_Outputs.st:375` (`M1_BrakeRelease_RQ`) | **Ordre de desserrage frein M1** — suit structurellement un sens validé |
| M52 | `instM1FwdProtector.Cmd` … `instM1Sc4Protector.Cmd` | `CODE/A_COMMUN/FB_ContactorProtector.st` (appels `PRG_06_Outputs.st:280-285`) | `PRG_06_Outputs.st:286-291` | **Garde anti-chatter dure** : pas de ré-activation avant `CST_ContactorMinInterval` (400 ms) |
| M53 | `instM2FwdProtector.Cmd` … `instM2Sc4Protector.Cmd` | `FB_ContactorProtector.st` (appels `PRG_06_Outputs.st:293-298`) | `PRG_06_Outputs.st:299-304` | Idem M2 |
| M54 | `M1_RelayAscent_RQ` (`%QX27.4`) / `M1_RelayDescent_RQ` (`%QX27.5`) | `PRG_06_Outputs.st:369` / `:370` | mapping `Device_IO_20260918.csv:482` / `:483` | **+1 enroulage montée extraction / −1 déroulage descente plongée** |
| M55 | `M1_SpeedContactor_1..4_DQ` (`%QX26.0..26.3`) | `PRG_06_Outputs.st:371-374` | mapping `Device_IO_20260918.csv:460-463` | Contacteurs de résistances rotoriques M1 (les seuls à faire varier la vitesse) |
| M56 | `M1_BrakeRelease_RQ` (`%QX27.0`) | `PRG_06_Outputs.st:375` | mapping `Device_IO_20260918.csv:478` | **Bobine frein M1** (VH_0008ER) |
| M57 | `M2_RelayAscent_Close_RQ` (`%QX27.6`) / `M2_RelayDescent_Open_RQ` (`%QX27.7`) | `PRG_06_Outputs.st:378` / `:379` | mapping `Device_IO_20260918.csv:484` / `:485` | M2 : montée = **fermeture grappin**, descente = **ouverture** |
| M58 | `M2_SpeedContactor_1..4_DQ` (`%QX26.4..26.7`) | `PRG_06_Outputs.st:380-383` | mapping `Device_IO_20260918.csv:464-467` | Contacteurs de palier M2 |
| M59 | `M2_BrakeRelease_RQ` (`%QX27.1`) | `PRG_06_Outputs.st:384` | mapping `Device_IO_20260918.csv:479` | Bobine frein M2 |
| M60 | `instSafetyWinchM1.AscentPermit` → `SafetyPermitM1_Ascent` | `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:574-582` | `PRG_04_Treuils_Benne.st:1067` → `:1113` | **Permis de montée safety** : coupe si FdC haut matériel OU position ≥ limite logicielle |
| M61 | `instSafetyWinchM1.TopLimitM` (entrée) | `PRG_04_Treuils_Benne.st:958` ← `TopLimitM1_M` (`:883-885`) | `FB_Safety_Winch.st:581` | **Seuil de la butée logicielle de montée** (7,5 m → 8,5 m sous override) |
| M62 | `M1M2_TopPositionFree_DI` (`%IX0.7`, NC) | mapping `Device_IO_20260918.csv:12` | `PRG_04_Treuils_Benne.st:948` (`TopPositionSensor`) → `FB_Safety_Winch.st:576` | **FdC haut matériel** — barrière indépendante, non bypassable par l'override logiciel |
| M63 | `M1_ContactorsReleased_DI` (`%IX0.0`) | mapping `Device_IO_20260918.csv:5` | `PRG_04_Treuils_Benne.st:959` → `FB_WinchDirectionInterlock.st:24` (`Enable`) ; `:1602` → `FB_WinchOutputInterlock.st` | **Condition de comptage du temps mort D18** (`StepNumber=0 AND ContactorsAllOff`) |
| M64 | `M1_BrakeIsOpen_DI` (`%IX225.0`) | mapping `Device_IO_20260918.csv:469` | `PRG_04_Treuils_Benne.st:960` (`BrakeFeedback`) ; `:1601` | Retour physique frein → watchdog 500 ms de la barrière |
| M65 | `instWinchSync.SyncActive` → `ReqM1Winch.SyncCoupled` | `CODE/H_TREUILS_BENNE/FB_WinchSync.st` ; appel `PRG_04:627-671` ; recopie `PRG_04:1419` / `:1493` | `FB_Winch.st` (instance `SyncCoupled`) | Surveillance d'écart M1/M2 + concordance contacteurs (pilotage couplé uniquement) |
| M66 | `WinchBothMotionReady` / gel croisé des requêtes finales | `PRG_04_Treuils_Benne.st:1405-1409` (M1) et `:1499-1501` (M2) ; recalcul `:1541-1542` | `PRG_04_Treuils_Benne.st:1663` (défense en profondeur SEMI_AUTO) | **Garde croisée** : un treuil qui purge son temps mort D18 fige l'autre (§6.2) |

**Chaîne manuelle en une ligne :**
`JoyYRaw_ANA2` → `FB_AxisScale.ScaleY.OutPct` → `FB_Joystick.AxisCmdY` (`Direction` + `StepTgt` + `DeadmanArmed`)
→ `Data.Joystick.AxisY` (`PRG_02:492`) → **`FB_WinchCmdArbitrationM1/M2`** (branche manuelle
`M1:62-104` / `M2:91-133`, gate `M1:116-125` / `M2:143-151`) → `M1LogicRunRequest/ReqAscent/ReqDescend/StepTgt`
(`PRG_04:541-544`, `:564-567`) → `ReqM1Winch`/`ReqM2Winch` (`PRG_04:1386-1419`, `:1473-1493`) →
`FB_Winch` (`instWinchM1/M2`, `PRG_04:1457`, `:1523`) → `RelayFwd/Rev` + `Contactor1..4`
(`FB_Winch:284-293`, `:306-309`) → `WinchM1/M2FinalInterlockRequest` (`PRG_04:1593-1629`) →
`FB_WinchOutputInterlock` (`PRG_06:149`, `:215`) → `FB_ContactorProtector` (`PRG_06:280-304`) →
`PRG_06:369-384` → `%QX27.4/.5`, `%QX26.0-26.3`, `%QX27.0` (M1) et `%QX27.6/.7`, `%QX26.4-26.7`, `%QX27.1` (M2).

---

## 4. 🔗 PARTIE 2 — CHAÎNE AUTO / SEMI_AUTO (codes C01, C02, …)

**Mode couvert :** `SEMI_AUTO` exclusivement — l'arbitre n'emprunte sa branche cycle que sous
`IF Auth.Mode = E_Mode.SEMI_AUTO` (`FB_WinchCmdArbitrationM1.st:56`, `FB_WinchCmdArbitrationM2.st:85`).

| # | Variable | Producteur fichier:ligne | Consommateur fichier:ligne | Rôle |
|---|---|---|---|---|
| C01 | `GVL_IHM.CycleSemiAuto.Cmd.BtnStart` | IHM (hors `CODE/`) | `PRG_03_Modes_Cycle.st:206` → `FB_CycleSemiAuto.st` | Départ/reprise consciente du cycle |
| C02 | `instCycleSemiAuto` (instance) | déclaré `PRG_03_Modes_Cycle.st:29` ; appelé `PRG_03_Modes_Cycle.st:190` | — | Séquenceur **privé** de PRG_03 (jamais appelé ailleurs) |
| C03 | `instCycleSemiAuto.Enable` = `Mode = SEMI_AUTO` | `PRG_03_Modes_Cycle.st:191` | `FB_CycleSemiAuto.st:714` | Un **seul** activateur : le mode |
| C04 | `JoystickDeflected` / `JoystickPush` / `JoystickPull` (entrées cycle) | `PRG_03_Modes_Cycle.st:196` / `:197` / `:198` ← `Data.Joystick.AtNeutralXY` et `AxisY.Direction` | `FB_CycleSemiAuto.st:780` (`CycleMotionPermit`), `:783` (`JoystickPushOnly`), `:1055`, `:1230`, `:1367`, `:1397`, `:1546` | **Le cycle consomme le MÊME joystick qualifié que le manuel** — pas de chemin de mesure dédié |
| C05 | `WinchM1Cmd.RunRequest` (**descente plongée AX4..AX7**) | `FB_CycleSemiAuto.st:1055`, `:1082`, `:1111`, `:1142` (`DeadmanArmed AND JoystickPush`) | `PRG_03_Modes_Cycle.st:306` → `Data.ReqProgram.ReqWinchM1` | Demandes de descente couplée pendant la plongée |
| C06 | `WinchM1Cmd.StepTgt` (**descente plongée**) | `FB_CycleSemiAuto.st:1057`, `:1084`, `:1113`, `:1144` (`CST_StepDive`) | idem C05 | Palier de plongée M1 |
| C07 | `WinchM2Cmd.StepTgt` (**descente plongée**) | `FB_CycleSemiAuto.st:1060`, `:1087`, `:1116`, `:1147` (`DiveM2StepTgt`) | idem C05 | Palier de plongée M2 — **peut différer de M1** |
| C08 | `WinchM1Cmd.RunRequest` (**remontée**) | `FB_CycleSemiAuto.st:1230`, `:1261`, `:1367`, `:1397`, `:1546` (`DeadmanArmed AND JoystickPull` / `CycleMotionPermit`) | `PRG_03_Modes_Cycle.st:306` | Demandes de montée couplée |
| C09 | `WinchM1Cmd.StepTgt` (**remontée**) | `FB_CycleSemiAuto.st:1232`, `:1263` (`CST_StepSlow`), `:1369` (`CtrlAscentMaxStepEff`), `:1399` (`SEL(Benne_IsClosed, CST_StepSlow, CST_StepLoaded)`), `:1547` | idem C05 | Palier de remontée |
| C10 | `instCycleSemiAuto.CycleMotionPermit` | `FB_CycleSemiAuto.st:780` (`JoystickDeflected AND DeadmanArmed`) | `FB_CycleSemiAuto.st:1546`, `:1549`, `:1640` | Repli homme-mort du séquenceur (étape AX12) |
| C11 | `instCycleSemiAuto.AutoDiveM1Step4M2Step5Active` | `FB_CycleSemiAuto.st` (sortie FB) | `PRG_03_Modes_Cycle.st:373` | Exception T291-A : M2 en P5 pendant que M1 est en P4 |
| C12 | `Data.ReqProgram.ReqWinchM1` / `ReqWinchM2` | `PRG_03_Modes_Cycle.st:306` / `:307` (copie struct entière) | `PRG_04_Treuils_Benne.st:534` / `:557` (entrée `ReqWinch` des arbitres) ; lecture IHM `PRG_07_Supervision.st:757`, `:793-799` | **Bus demande cycle → treuils** (le seul consommateur décisionnel est l'arbitre) |
| C13 | `Data.WinchBothIntent.Active` / `.ReqAscent` / `.ReqDescend` (**version cycle**) | `PRG_03_Modes_Cycle.st:311-314` (les 2 demandes symétriques), `:322-324` | `PRG_04_Treuils_Benne.st:284-286`, `:535`, `:558` | **Intention couplée reconstruite depuis le cycle** — écrasée après la version manuelle `:297-299` |
| C14 | `Data.AutoDiveM1Step4M2Step5Active` | `PRG_03_Modes_Cycle.st:373` | `PRG_04_Treuils_Benne.st:1299` (plafond M2 → P5), `:1632` (cohérence both) | Autorise M2 à dépasser le plafond commun |
| C15 | `instArbM1.RunRequest` (**branche cycle**) | `FB_WinchCmdArbitrationM1.st:58` (`ReqWinch.RunRequest AND (Joystick.AxisX.Direction = 0)`) | `PRG_04_Treuils_Benne.st:541` | Demande de marche cycle M1 — **aucun gate de permis ici**, les permis sont aval |
| C16 | `instArbM1.ReqAscent` / `.ReqDescend` / `.StepTgt` (**branche cycle**) | `FB_WinchCmdArbitrationM1.st:59` / `:60` / `:61` (passthrough de `ReqWinch`) | `PRG_04_Treuils_Benne.st:542-544` | Passthrough intégral de la demande du séquenceur |
| C17 | `instArbM2.RunRequest` (**branche cycle**) | `FB_WinchCmdArbitrationM2.st:87` (`ReqWinch.RunRequest AND (Joystick.AxisX.Direction = 0)`) | `PRG_04_Treuils_Benne.st:564` | Idem M1 — **sauf si le chemin benne a pris la main** (`:65-67`, cf. C18) |
| C18 | `Context.BucketM2RunRequest` / `BucketM2ReqAscent` / `BucketM2ReqDescend` (**chemin benne en SEMI_AUTO**) | `PRG_04_Treuils_Benne.st:500` ← `instBucket.M2_RunRequest` ; `:488-489` ← `instBucket.M2_ReqAscent/M2_ReqDescend` | `FB_WinchCmdArbitrationM2.st:65-71` — **branche prioritaire sur la branche cycle** | ⚠️ **Détournement possible de la demande du cycle sur M2** (voir §6.4-A1/A4) |
| C19 | `ArbContext.BucketAutoCloseActive` | `PRG_04_Treuils_Benne.st:503-505` (`SEMI_AUTO AND Step = AX10_CLOSE_BUCKET AND ReqBucket.ReqClose`) | `FB_WinchCmdArbitrationM2.st:78-79` ; `PRG_04:1309`, `:1336` | Fermeture benne auto : plafond M2 = `CtrlAscentMaxStep` |
| C20 | `ArbContext.BucketHandoffP1Active` | `PRG_04_Treuils_Benne.st:506-509` (`SEMI_AUTO AND Step = AX10B_RACCORDEMENT_P1 AND instBucket.CloseReached AND ReqHoldAscentP1AfterClose`) | `FB_WinchCmdArbitrationM2.st:76-77` ; `PRG_04:1307-1308` | Raccordement P1 : M2 forcé au palier **1** |
| C21 | `instArbM2.StepTgt` (**chemin benne**) | `FB_WinchCmdArbitrationM2.st:73` (`LIMIT(1, Joystick.AxisY.StepTgt, 5)`) puis `:75`, `:77`, `:79`, `:81` | `PRG_04_Treuils_Benne.st:567` | ⚠️ **Le palier vient du JOYSTICK** même en SEMI_AUTO sur ce chemin (borné par la config benne) |
| C22 | `Data.SequenceState.Step` | `PRG_03_Modes_Cycle.st:343` ← `instCycleSemiAuto.CycleStep` | `PRG_04_Treuils_Benne.st:504`, `:507` | Étape courante — base des gardes C19/C20 |
| C23 | `instBucket.M2_RunRequest` / `.M2_ReqAscent` / `.M2_ReqDescend` | `CODE/H_TREUILS_BENNE/BENNE/FB_Bucket.st` (appel `PRG_04:340`) | `PRG_04_Treuils_Benne.st:488-489`, `:500` | **Benne M2 comme demandeur du treuil M2** (§8c) |
| C24 | `instArbBucket.CmdClose_IHM` → `CmdBucketCloseArbitrated` | `PRG_04_Treuils_Benne.st:332` ← `CODE/H_TREUILS_BENNE/FB_BucketCmdArbitration.st` (appel `PRG_04:323-329`) | `PRG_04_Treuils_Benne.st:1132`, `:1336` | Demande de fermeture benne arbitrée |
| C25 | `ReqM1Winch.*` / `ReqM2Winch.*` (**assemblage cycle**) | `PRG_04_Treuils_Benne.st:1386-1419` / `:1473-1493` | `PRG_04:1464` / `:1530` | **Fusion des 2 chaînes** : à partir d'ici, plus aucune trace de l'origine |
| C26 | `WinchBothMotionReady` / gel croisé | `PRG_04_Treuils_Benne.st:1405-1409`, `:1499-1501`, `:1541-1542` | `PRG_04_Treuils_Benne.st:1663` | Garde croisée active aussi en cycle (`WinchBothMotionActive` est vrai en cycle, cf. C13) |
| C27 | `WinchBothFinalStep45Coherent` | `PRG_04_Treuils_Benne.st:1631-1646` (exception exacte **descente M1=P4 / M2=P5**) | `PRG_04_Treuils_Benne.st:1649` | Autorise la seule divergence de palier légitime M1/M2 |
| C28 | `WinchBothFinalRequestsCoherent` | `PRG_04_Treuils_Benne.st:1648-1656` | `PRG_04_Treuils_Benne.st:1663` | Égalité effective des vecteurs physiques M1/M2 |
| C29 | **Veto SEMI_AUTO de profondeur** sur les 2 demandes finales | `PRG_04_Treuils_Benne.st:1661-1678` (`SEMI_AUTO AND Both AND (NOT Ready OR NOT Coherent)` → relais, contacteurs et palier **remis à 0 sur les DEUX treuils**) | `PRG_06_Outputs.st:158-164`, `:224-230` | **Gate qui n'existe pas en manuel** : neutralisation à blanc avant publication |
| C30 | `Data.ContactorMismatch` / `.ContactorMismatchEscalated` | `PRG_06_Outputs.st:363-364` ← `FB_SyncContactor` (`:341-362`) | `PRG_04_Treuils_Benne.st:712` ; escalade MecaE | Escalade graduée : niveau 1 SafeStop, niveau 2 PowerCutOff |
| C31 | `instWinchSync.SyncDeviationWarn` | `FB_WinchSync.st` (appel `PRG_04:627-671`) | `PRG_04_Treuils_Benne.st:1248-1251` | Bride les **2** treuils au palier 1 |
| C32 | `M1WinchSensors.MeasuredSpeedBand` / `M2WinchSensors.MeasuredSpeedBand` | `PRG_04_Treuils_Benne.st:1425` / `:1507` ← `instWinchLoadEstimatorM1/M2` (`:1356`, `:1368`) | `FB_Winch.st:240` (garde-fou **désactivé**, `SpeedGuardEnable := FALSE` `:1441`/`:1509`) | Estimateur de charge/vitesse — **publié mais sans effet de conduite en l'état** |
| C33 | `instWinchSpeedLearningM1/M2` (collecteurs passifs) | appels `PRG_04_Treuils_Benne.st:1557` / `:1572` | table RETAIN `_WinchSpeedLearnTable` | Strictement passif : aucune commande moteur (§5.4) |
| C34 | `WinchM1FinalInterlockRequest` / `WinchM2FinalInterlockRequest` | `PRG_04_Treuils_Benne.st:1593-1629` (après veto C29) | `PRG_06_Outputs.st:150-164` / `:216-230` | **Convergence totale avec la chaîne manuelle** |
| C35 | `M1_RelayAscent_RQ` / `M2_SpeedContactor_*_DQ` / `M1_BrakeRelease_RQ` … | `PRG_06_Outputs.st:369-384` | mapping `Device_IO_20260918.csv:460-467`, `:478-479`, `:482-485` | **Sorties physiques IDENTIQUES** à celles de la chaîne manuelle |

**Chaîne cycle en une ligne :**
`instCycleSemiAuto` (`PRG_03:190`, activé par `Mode = SEMI_AUTO` `:191`) → `WinchM1Cmd`/`WinchM2Cmd`
(`FB_CycleSemiAuto.st:1055-1060`, `:1230-1235`, `:1367-1372`, `:1397-1402`, `:1545-1550`) →
`Data.ReqProgram.ReqWinchM1/M2` (`PRG_03:306-307`) → **`FB_WinchCmdArbitrationM1/M2`** branche `SEMI_AUTO`
(`M1:58-61`, `M2:87-90` — **`M2:65-82` si le chemin benne est actif**) → `M1Logic*`/`M2Logic*`
(`PRG_04:541-544`, `:564-567`) → `ReqM1Winch`/`ReqM2Winch` → `FB_Winch` → garde croisée (`PRG_04:1405-1409`,
`:1499-1501`) → veto cohérence SEMI_AUTO (`PRG_04:1661-1678`) → `WinchM1/M2FinalInterlockRequest` →
`FB_WinchOutputInterlock` → `FB_ContactorProtector` → **les mêmes** `%QX27.x` / `%QX26.x`.

---

## 5. ⚖️ PARTIE 3 — COMPARATIF HIÉRARCHIQUE DES DEUX CHAÎNES

> ⚠️ **Aucune extrapolation depuis M3.** Le verdict ci-dessous est établi **par preuve fichier:ligne sur
> l'état disque ancré**. Là où la réponse M1/M2 **diffère** de celle de M3, c'est signalé explicitement.

### 5.1 Où les deux chaînes CONVERGENT (preuve)

| Étage de convergence | Preuve | Portée |
|---|---|---|
| Frontière d'acquisition (manche) | `PRG_02_Acquisition.st:445`, `:458`, `:481-483`, `:491-494` | 🟢 Le cycle consomme **le même** joystick qualifié (`PRG_03:196-198`, `:204`) — un seul bus de geste pour les 2 régimes |
| Table de paliers | `GVL_PERSISTENT.st` `_WinchSpeedStepTable` ; `PRG_02_Acquisition.st:456` | 🟢 Source unique de paliers partagée joystick + cycle + FB_Winch |
| **Arbitre de commande (par treuil)** | `FB_WinchCmdArbitrationM1` appelé `PRG_04:530` — **les deux branches vivent dans le même FB** (`:56-61` cycle, `:62-104` manuel) ; idem M2 `PRG_04:553` (`:65-90`, `:91-133`) | 🟢 **Un seul point de sélection de source par treuil** → « l'axe ne reçoit pas deux ordres concurrents » |
| Contrat de requête axe | `ReqM1Winch`/`ReqM2Winch` assemblés une seule fois, `PRG_04:1386-1419` / `:1473-1493` | 🟢 **Un seul contrat d'ordre** : `RunRequest`, `ReqAscent`, `ReqDescend`, `SpeedStepReq`, `TopLimitM`, `Max/MinStep`, `SyncCoupled` |
| FB de mouvement | `PRG_04:1457` (`instWinchM1`) et `:1523` (`instWinchM2`) | 🟢 **Un seul FB commande l'axe** — la provenance de la demande est effacée |
| Safety treuil | `PRG_04:926` / `:996` (`instSafetyWinchM1/M2 : FB_Safety_Winch`) | 🟢 Un seul SafeStop / PowerCutOff par treuil, commun aux 2 régimes |
| Interlock direction D18 | `FB_Winch.st:197-205` → `FB_WinchDirectionInterlock` | 🟢 **Un seul D18** par treuil, traversé par les 2 chaînes (`FB_Winch.st:71`, instance) |
| Barrière finale | `PRG_06_Outputs.st:149` / `:215` (`instWinchOutputInterlockM1/M2`) | 🟢 Un seul watchdog frein (500 ms, `FB_WinchOutputInterlock.st:494`), un seul anti-redémarrage (`:221-227`) |
| Anti-chatter dur | `PRG_06_Outputs.st:280-304` | 🟢 12 `FB_ContactorProtector` pour M1+M2, quel que soit le mode |
| Mots physiques | `PRG_06_Outputs.st:369-384` | 🟢 **Un seul jeu de `%Q…`** — `%QX26.0-26.7`, `%QX27.0/.1`, `%QX27.4-.7` |

➡️ **Conclusion partielle : l'axe ne reçoit PAS deux ordres.** Un arbitre unique par treuil sélectionne
**une** source selon le mode. **Le verdict est le MÊME que celui de M3 sur la nature du contrat**
(un seul FB de mouvement, un seul arbitre, une seule barrière), **mais il N'EST PAS identique sur
l'architecture de l'arbitre** : chez M3 c'est **un seul FB pour un seul axe**
(`FB_TranslationCmdArbitrationM3`, cf. T334 §6.1) ; ici il y a **deux FB jumeaux** (`…M1` / `…M2`) dont
**un seul (M2) porte une troisième source** (§5.2 D01) que M3 n'a pas. ⚠️ Une lecture par analogie M3
conduirait à manquer le chemin benne.

### 5.2 Où les deux chaînes DIVERGENT — avec le « pourquoi » sourcé

| # | Divergence | MANU / MAINT | AUTO / SEMI_AUTO | Pourquoi / source |
|---|---|---|---|---|
| **D01** | **Nombre de sources admises par l'arbitre M2** | 3 sources : joystick (`M2:119-122`), boutons (`:104-111`), **chemin benne** (`:65-82`, actif si `Select=2`) | Idem **+ la demande cycle** (`:87-90`) → le chemin benne (`:65-67` autorise `SEMI_AUTO`) **prime** sur le cycle | Aucune spec ne décrit cette priorité : le commentaire `FB_WinchCmdArbitrationM2.st:59-64` la justifie par un REX de quasi-casse machine (2026-09-04), **pas** par un document métier. **Écart doc/code à signaler** (§10) |
| **D02** | **Gate de sécurité dans l'arbitre** | Gate complet : `BucketBusy`, `WinchBothMotionBlockedByBucket`, sync, `DeadmanArmed`, inter-axe X, atomicité Both (`M1:116-125`) | **Aucun gate** : simple `ReqWinch.RunRequest AND (AxisX.Direction = 0)` (`M1:58`, `M2:87`) | Intentionnel : en SEMI_AUTO les permis sont appliqués **en aval** (`EffectivePermitM*` → `FB_Winch:169-171`). Différence de *niveau* de sécurité, pas d'absence |
| **D03** | **Qui porte le palier de vitesse** | Joystick (`FB_Joystick.st:294-301`) **ou** palier max boutons `Cfg.BtnStepTgt = 5` (`M1:74`, `PRG_04:523-524`) | Séquenceur (`FB_CycleSemiAuto.st:1057`, `:1232`, `:1369`, `:1399`) — **sauf** sur le chemin benne M2 où le palier **redevient joystick** (`M2:73`) | Asymétrie non documentée : un même mode SEMI_AUTO peut voir M2 piloté au palier joystick et M1 au palier du cycle |
| **D04** | **Neutralisation à blanc avant publication** | ❌ inexistante | ✅ `PRG_04:1661-1678` : si `NOT WinchBothMotionReady` ou `NOT WinchBothFinalRequestsCoherent`, les **deux** demandes finales sont remises à 0 | Défense en profondeur écrite pour le cycle (commentaire `:1658-1660`) — **n'existe pas côté manuel**, où l'atomicité est portée en amont par `BothDirectionAuthorized` (`M1:113-115`) |
| **D05** | **Veto de cohérence de palier M1/M2** | ❌ aucun | ✅ exception T291-A `PRG_04:1631-1646` + égalité stricte `:1648-1656` | Le cycle peut légitimement diverger (P4/P5 en plongée), le manuel non |
| **D06** | **Plafond de palier M2** | `M2MaxStepDown` limité au commun (`:1293-1294`) | `M2MaxStepDown := 5` autorisé si `AutoDiveM1Step4M2Step5Active` (`:1299-1303`) | Exception T291-A, bornée ET conditionnée (`EffectiveMaxStepDescent = 4` **et** aucun bridage amont) |
| **D07** | **Délai D18 réellement appliqué** | Identique (même FB) — mais le **chemin** diffère : manuel = inversion par geste opposé sans passage au neutre (`FB_WinchDirectionInterlock.st:156-158`) | Le cycle **retire** la demande (`FB_CycleSemiAuto.st:1203-1204`, `:1287-1288`, `:1478-1479`, `:1567-1568`) avant de redemander → l'`Enable` de D18 (`StepNumber = 0 AND ContactorsAllOff`, `FB_Winch.st:198`) est **franchi beaucoup plus souvent** | Conséquence mécanique : D18 est sollicité **plus souvent** en cycle, ce qui augmente l'exposition à la limite résiduelle connue (T325 phase 2, documentée `FB_WinchDirectionInterlock.st:13-19`) |
| **D08** | **Source de l'homme-mort** | `FB_Joystick.st:232` conditionné par `ArmingPermit` ← `PRG_04:1205` ← `EffectivePermitM*` | Le cycle exige **en plus** son propre `CycleMotionPermit` (`FB_CycleSemiAuto.st:1546`) mais consomme **le même** `DeadmanArmed` | Boucle d'un scan : `ArmingPermit` est produit par PRG_04 (rang 04) et consommé par PRG_02 (rang 02) → **décalage de 1 scan** structurel (`PRG_02:464`) |
| **D09** | **Bypass / override actifs** | Tous armables (`PRG_04:856-875`) | **Identiques et non filtrés par le mode** — dérogation assumée `PRG_04:841-844`, `:865`, `:970-971` | 🔴 **Un bypass armé en MES reste actif en SEMI_AUTO** (§10) |
| **D10** | **Chemin benne M2** | Actif si `Select = 2` (jog benne) **ou** `BucketBusy + BucketM2RunRequest` (`M2:65-67`) | Actif **aussi** dès que `BucketBusy AND BucketM2RunRequest` (`M2:65-67`, `SEMI_AUTO` explicitement autorisé) | Seule source M2 qui **court-circuite** la demande du séquenceur → divergence majeure, absente de M1 |

### 5.3 Conditions d'arrêt : présentes d'un côté, absentes de l'autre

| Condition d'arrêt / de gel | MANU / MAINT | AUTO / SEMI_AUTO | Preuve |
|---|---|---|---|
| `HOLD T248` (changement de sélecteur) | ✅ force M1 **et** M2 à 0 | ✅ même mécanisme (`WinchSelTransitionHold` n'est pas filtré par mode) | `FB_Modes.st:410` → `PRG_04:572-575` |
| Gel croisé par temps mort D18 de l'autre treuil | ✅ `PRG_04:1407-1409` (fige M1) / `:1499-1501` (fige M2) | ✅ idem — conditionné à `WinchBothMotionActive`, or en cycle il est **reconstruit** (`PRG_03:311-314`, `:322`) | `PRG_04:1405-1409`, `:1541-1542` |
| Neutralisation à blanc des 2 demandes finales | ❌ absente | ✅ `PRG_04:1661-1678` | voir D04 |
| Arrêt sur action benne (front descendant `Busy`) | ✅ `M1:129-131`, `M2:156-158` — sauf mouvement Both actif | ⚠️ **court-circuité** : en SEMI_AUTO le chemin benne **prend la commande** au lieu de l'arrêter (`M2:65-82`) | `FB_WinchCmdArbitrationM1.st:129-131` vs `FB_WinchCmdArbitrationM2.st:65-82` |
| Gating par `BucketBusy` | ✅ M1 (`M1:117`) — ❌ **M2 ne l'a pas** | identique (asymétrie conservée) | §6.4-A2 |
| Coupure dure frein (`BrakeCmd := RelayFwd OR RelayRev`) | ✅ `FB_WinchOutputInterlock.st:487` + `PRG_06:307-308` | ✅ idem (même FB, même recalcul) | convergence |
| Watchdog frein 500 ms | ✅ `FB_WinchOutputInterlock.st:494` | ✅ idem | convergence |
| Anti-redémarrage automatique | ✅ `FB_WinchOutputInterlock.st:221-227` | ✅ idem | convergence |
| Bride vitesse si codeurs non fiables | ✅ `PRG_04:1242-1246` (palier 1 M1 **et** M2) | ✅ idem, non filtré par mode | convergence |
| Bride vitesse en approche haute (Both) | ✅ `PRG_04:1268-1273` | ✅ idem (`WinchBothMotionActive` vrai en cycle) | convergence |
| Arrêt par limite haute logicielle | ✅ `FB_Safety_Winch.st:581` (via `TopLimitM`) | ✅ idem — **même variable, même FB** | convergence, §6.3 |

### 5.4 FB traversés en plus / en moins dans chaque chaîne

| FB / brique | MANU / MAINT | AUTO / SEMI_AUTO | Remarque |
|---|---|---|---|
| `FB_Joystick` | ✅ source de **commande** (`M1:91-93`, `M2:120-122`) | ✅ source de **permis + sens + palier** (jamais de la demande brute) — `PRG_03:196-198` → `FB_CycleSemiAuto.st:1055` | `PRG_02:458` |
| `FB_WinchCmdArbitrationM1` | ✅ branche `M1:62-104` | ✅ branche `M1:56-61` | **Convergence** (point de sélection unique) |
| `FB_WinchCmdArbitrationM2` | ✅ branche `M2:91-133` (+ bucket `:65-82` si Select=2) | ✅ branche `M2:85-90` **ou** `:65-82` | ⚠️ divergence : la branche bucket peut supplanter le cycle |
| `FB_CycleSemiAuto` | ➖ non traversé (mais **appelé** puis neutralisé par `Enable := Mode = SEMI_AUTO`, `PRG_03:191`, `FB_CycleSemiAuto.st:714-728`) | ✅ **en plus** | Producteur du `ST_ProgramWinchRequest` |
| `FB_Bucket` + `FB_BucketCmdArbitration` | ✅ traversés (`PRG_04:323`, `:340`) — demandeur M2 si Select=2 | ✅ traversés (`PRG_04:323`, `:340`) — **demandeur M2 prioritaire sur le cycle** | `⚠️ASYM` |
| `FB_Safety_Winch` (×2) | ✅ `PRG_04:926`, `:996` | ✅ idem | **Convergence** |
| `FB_Winch` (×2) | ✅ `PRG_04:1457`, `:1523` | ✅ idem | **Convergence — le seul FB qui commande l'axe** |
| `FB_WinchDirectionInterlock` (D18, ×2) | ✅ `FB_Winch.st:197-205` | ✅ idem, sollicité plus souvent (D07) | **Convergence** |
| `FB_WinchOutputInterlock` (×2) | ✅ `PRG_06:149`, `:215` | ✅ idem | **Convergence** |
| `FB_WinchSync` | ✅ `PRG_04:627-671` (gaté `SyncOperationPermit`) | ✅ idem | **Convergence** |
| `FB_WinchLoadEstimator` (×2) | ✅ appelé `PRG_04:1356`, `:1368` | ✅ idem | ⚠️ **Publié mais sans effet** : `SpeedGuardEnable := FALSE` codé en dur (`PRG_04:1441`, `:1509`) → le garde-fou survitesse est **hors service dans LES DEUX chaînes** (dette safety assumée, commentaire `:1430-1440`) |
| `FB_WinchSpeedLearning` (×2) | ✅ appelé `PRG_04:1557`, `:1572` | ✅ idem | Strictement passif, aucune commande moteur |
| `FB_WinchStateProjection` | ✅ appelé `PRG_04:1688` | ✅ idem | Recopie lecture seule (`PRG_04:1725-1730`) |
| `FB_ContactorProtector` (×12) | ✅ `PRG_06:280-304` | ✅ idem | **Convergence** |
| `FB_SyncContactor` | ✅ `PRG_06:341-362` | ✅ idem | **Convergence** |
| `FB_CycleMachineHoming` | ✅ **MAINT_N2 uniquement** (`PRG_03:401-405`) — ⚠️ voir §7.3 | ➖ non actif | Branche maintenance |

---

## 6. 🎯 LES 4 POINTS SPÉCIFIQUES EXIGÉS PAR LE BRIEF

### 6.1 D18 — `FB_WinchDirectionInterlock` : le crédit du temps d'arrêt réel

**Statut à documenter : mécanisme CORRIGÉ et COMMITTÉ, NON TESTÉ MACHINE.**
Ni un écart ouvert, ni le comportement d'origine.

**Commits de correction (vérifiés par `git log`) :**

| Commit | Date | Message |
|---|---|---|
| `6f708b22` | 2026-09-20 00:53:22 | « credit du temps d'arret reel dans FB_WinchDirectionInterlock (D18) [NON TESTE] » |
| `657be973` | 2026-09-20 02:03:53 | « purge DeadTimeArmed atteignable des que le delai est ecoule (D18, T325 phase 1) [NON TESTE] » |
| `e638308f` | 2026-09-20 02:52:52 | « corrige debordement TIME D18 + deborne affichage ouverture benne [NON TESTE] » |

**Ce que fait le mécanisme (fait vérifié, état disque, blob `5fa9e0405ac3`) :**

| Étape | Ligne | Effet |
|---|---|---|
| Armement du temps mort au front `Enable` avec demande maintenue | `FB_WinchDirectionInterlock.st:106-108` | `DeadTimeArmed := TRUE` → pas de ré-adoption immédiate du sens (pas d'inrush) |
| **Crédit du temps d'arrêt RÉEL** accumulé pendant tout le neutre | `:110-114` (`StoppedTimer(IN := Enable AND NOT RequestActive, PT := MaxDirectionDelay)`) | Le temps de contacteurs retombés est **capitalisé** |
| Capture au front de la nouvelle demande | `:76-79` (`RequestActiveRising` puis `CapturedStoppedTime := StoppedTimer.ET`) | Capture **avant** que `StoppedTimer` ne retombe à 0 |
| Reliquat = délai plein − crédit, sans sous-flow TIME | `:93-96` (`IF CapturedStoppedTime >= EffectiveDelay THEN 0 ELSE EffectiveDelay - CapturedStoppedTime`) | **Anti-débordement DWORD** (commit `e638308f`) |
| Comptage du reliquat | `:118-121` (`DirectionChangeDelay`) | Temporisation effective |
| Purge atteignable dès le délai écoulé | `:132-139` → `DeadTimeArmed := FALSE` | **T325 phase 1** (commit `657be973`) |
| Consommation du crédit | `:174-176` | Un crédit périmé n'est **jamais** réutilisé |
| Limite résiduelle connue | `:13-19` (bandeau) | T325 **phase 2**, NON couverte : si la demande redevient le **même** sens que le dernier commandé au moment où `DeadTimeArmed` vient d'être armé, `DirectionChanged` reste FALSE → le temps mort ne peut jamais être mesuré ; seule issue = retour au neutre ou `Reset`. **Déclaré, pas caché.** |

**Insertion de D18 dans CHACUNE des 2 chaînes :**

- **Chaîne MANUELLE :** D18 s'intercale **entre l'arbitre et les relais**, à l'intérieur de `FB_Winch` :
  `M1LogicReqAscent/Descend` (`PRG_04:542-543`) → `ReqM1Winch` (`:1387-1388`) → `FB_Winch` §4
  (`FB_Winch.st:197-205`) → adoption du sens (`:206-207`) → palier forcé à 0 pendant le *pending*
  (`:216-220`) → relais (`:284-293`). Le délai plein vient de `PRG_04:1452-1453` (800 ms montée / 500 ms
  descente) et `:1518` (identiques M2).
- **Chaîne CYCLE :** **exactement le même point** — D18 est *dans* `FB_Winch`, donc après la convergence
  (C25). Ce qui change n'est pas le point d'insertion mais le **régime de sollicitation** : le cycle retire
  sa demande (`FB_CycleSemiAuto.st:1203-1204`, `:1287-1288`, `:1478-1479`, `:1567-1568`) avant de la
  ré-émettre, ce qui fait passer `Enable` de D18 (`StepNumber = 0 AND ContactorsAllOff`, `FB_Winch.st:198`)
  bien plus souvent qu'en manuel → **plus d'occasions d'atteindre la limite résiduelle T325 phase 2**.

**⚠️ Écart de catalogue constaté (§10) :** `DOC/WFLOW/TASKS.yaml` décrit encore T325 comme une tâche
« d'ANALYSE et de CADRAGE uniquement — aucune modification de code ». Le correctif est **committé**
(3 commits ci-dessus) : le catalogue est **périmé** sur ce point. Constat remonté, **non corrigé par ce lot**
(registres = périmètre exclusif de l'orchestrateur).

### 6.2 Garde croisée M1/M2 — un treuil peut geler l'autre

**Lignes RÉELLES de l'état disque (`PRG_04_Treuils_Benne.st`, blob `31760d59b4e0`) :**

| Élément | Ligne réelle | Contenu vérifié |
|---|---|---|
| Calcul de la disponibilité croisée | **`:1405-1406`** | `WinchBothMotionReady := NOT (instWinchM1.DirectionChangePending OR instWinchM2.DirectionChangePending) AND NOT instWinchM1.Fault.Latched AND NOT instWinchM2.Fault.Latched` |
| **Gel de M1 quand M2 purge son dead-time D18** (ou est en défaut latché) | **`:1407-1409`** | `IF WinchBothMotionActive AND (instWinchM2.DirectionChangePending OR instWinchM2.Fault.Latched) THEN ReqM1Winch.RunRequest := FALSE; … ReqDescend := FALSE; SpeedStepReq := 0; END_IF` |
| **Gel symétrique de M2 quand M1 purge son dead-time** | **`:1499-1501`** | `IF WinchBothMotionActive AND (instWinchM1.DirectionChangePending OR instWinchM1.Fault.Latched) THEN ReqM2Winch.… := FALSE …` |
| Recalcul de la disponibilité **après** les 2 appels `FB_Winch` | **`:1541-1542`** | Deuxième affectation de `WinchBothMotionReady` (lecture du `DirectionChangePending` du scan courant) |
| Usage en défense en profondeur | **`:1663`** | `AND (NOT WinchBothMotionReady OR NOT WinchBothFinalRequestsCoherent)` → neutralisation des 2 demandes finales |
| Couplage croisé des SafeStop | **`:1105-1106`** | `SafeStopM1_Active := SafeStopM1_Raw OR (CoupledBoth AND SafeStopM2_Raw)` (et inverse) |
| Couplage croisé des permis | **`:1111-1114`** | `EffectivePermitM1_*` exige `(NOT CoupledBoth OR ProcessAndSafetyPermitM2_*)` |
| Définition de `CoupledBoth` | **`:1103`** | `instWinchSync.SyncActive OR WinchBothMotionActive` |

**⚠️ ÉCART AVEC LE BRIEF — signalé comme constat, brief non modifié :**
Le brief T351 §4 annonce la garde croisée à `PRG_04_Treuils_Benne.st:1360-1361` et `:1452-1453`
(numérotation du moment de sa rédaction). **Ces lignes ne portent PAS la garde croisée.** Correspondance
vérifiée sur le disque ancré :

| Ligne annoncée par le brief | Équivalent sur le blob `31760d59b4e0` | Contenu RÉEL vérifié | Verdict |
|---|---|---|---|
| `:1360-1361` | **`:1361-1362`** | `PowerContactorEngaged := …` / `MeasuredSpeedMps := …` — **arguments de l'appel `instWinchLoadEstimatorM1(...)`** ouvert `:1356` (l'appel M2, lui, est ouvert `:1368`) | ❌ **faux** |
| `:1452-1453` | **`:1453-1454`** | `M1WinchCfg.DirectionInterlockDelayDescent := T#500ms;` / `M1WinchCfg.StepRampDelayAscent := T#700ms;` — **assemblage de `M1WinchCfg`**, bloc `:1444-1455` qui **précède** l'appel `instWinchM1(` ouvert `:1457`. C'est la **config des délais D18**, pas la garde croisée | ❌ **inexact** (au mieux une coïncidence thématique sur le volet M1) |

La garde croisée **effective** est en **`:1407-1409`** (gel de M1) et **`:1499-1501`** (gel de M2) — soit
**+47 / +47 lignes** par rapport aux numéros du brief. Cet écart est cohérent avec un décalage cumulé
introduit par les lots concurrents (le contrat T351 documentait déjà **+32** au moment de sa rédaction,
et **+1 de plus** est apparu en cours de lot, cf. §1 et §14).

### 6.3 Sécurité géométrique de limite haute — limite logicielle + chemin d'OVERRIDE

| Maillon | Ligne | Détail vérifié |
|---|---|---|
| **Variable de configuration (nominal 7,5 m)** | `CODE/J_SUPERVISION/_TYPES/7_COMMUN_CONFIG/ST_CommunCfg.st:21` (défaut `7.5`) ; `CODE/GVL_PERSISTENT.st:145` (`CfgCableLimitAscent_M := 7.5`, commentaire `:37`) | Limite **logicielle d'exploitation normale**, commune M1/M2 |
| **Seuil d'override (8,5 m)** | `CODE/J_SUPERVISION/_TYPES/1_TREUILS_BENNE/ST_WinchCfg.st:8` (`CfgTopSensorPos_M : REAL := 8.5`) ; `CODE/GVL_PERSISTENT.st:41` (M1) et `:49` (M2) | Position réelle du capteur haut — **sert de seuil sous override** |
| **Producteur de l'override N1 (momentané)** | `PRG_04_Treuils_Benne.st:856-859` (M1) / `:860-863` (M2) : `MaintN1 AND Homed AND NOT HomingSuspect AND GVL_IHM.MxTreuil.Cmd.BtnOverrideTopSoftware` | **Maintien du bouton requis** → retour à 7,5 m au cycle suivant, aucune mémorisation |
| **Bypass N2 latché équivalent** | `PRG_04_Treuils_Benne.st:867` / `:872` (`BypassMxTopLimitSoftwareEff`) — **sans gate de mode** (dérogation `:841-844`, `:865`) | ⚠️ Actif **dans tous les modes**, y compris SEMI_AUTO (§10) |
| **Sélection du seuil (le « changement de seuil »)** | `PRG_04_Treuils_Benne.st:883-885` (M1) : `TopLimitM1_M := SEL(Override OR BypassTopLimitSoftware, 7.5 m, CfgTopSensorPos_M)` ; `:886-888` (M2, avec `+ M2_LimitShift`) | **Point exact où le seuil passe de 7,5 m à 8,5 m** |
| Cas particuliers M2 (jog benne / both) | `PRG_04_Treuils_Benne.st:899-901` (butée géométrique relative en jog benne) ; `:902-906` (marge +0,50 m en Both) | ⚠️ **Asymétrie M2** — M1 n'a aucun équivalent |
| **Transmission au FB de mouvement** (zone de ralentissement) | `PRG_04_Treuils_Benne.st:1417` (M1) / `:1491` (M2) → `FB_Winch.st:173` (`InTopSlowdownZone`) | Le seuil pilote aussi le **ralentissement d'approche** |
| **Transmission au FB de sécurité** | `PRG_04_Treuils_Benne.st:958` (M1) / zone M2 dans l'appel `instSafetyWinchM2(` `:996-1059` → `FB_Safety_Winch.st:581` | Le seuil pilote la **coupure du permis de montée** |
| **🔴 Point de coupure du permis** | `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:574-582` : `AscentPermit := NOT ( ((CauseTopLimitSwitchActive OR (NOT TopPositionSensor AND NOT InReferencingMode)) AND NOT BypassTopLimitSwitch) OR (Homed AND NOT HomingSuspect AND NOT InReferencingMode AND (CablePosM >= TopLimitM) AND NOT (BypassGlobal OR BypassTopLimitSoftware)) )` | **C'est ici que le permis tombe** |
| **Consommation du permis (manu ET cycle)** | `PRG_04_Treuils_Benne.st:1067` → `:1113` (`EffectivePermitM1_Ascent`) → `:1463` (`AscentPermit` de `FB_Winch`) → `FB_Winch.st:169-171` (`EffectiveSafeStop`) → `:216` (palier forcé à 0) → `:284-293` (relais) | **Coupe le mouvement dans les DEUX régimes, au même endroit** |
| **FdC haut MATÉRIEL (indépendant)** | `M1M2_TopPositionFree_DI` `%IX0.7` (CSV `:12`) → `PRG_04:948` → `FB_Safety_Winch.st:576` | **Non bypassable par l'override logiciel** — c'est la barrière dure, conforme au commentaire `PRG_04:849-850` |
| **Re-homing obligatoire après usage** | `PRG_04_Treuils_Benne.st:913-918` (`PositionLimitOverriddenM1/M2`) → `PRG_03` → `FB_Modes` (`Auth.HomingRequiredM1/M2`, miroir `PRG_03:132-133`) | Traçabilité de l'usage d'un override |

**Résumé §6.3 :** le seuil change **en un seul point** (`PRG_04:883-888`), la coupure du permis se fait
**en un seul endroit** (`FB_Safety_Winch.st:581`), et les **deux régimes de conduite** y passent par la
**même** chaîne (`PRG_04:1113` → `FB_Winch.st:169-171`). **Aucune divergence manu/cycle sur ce point.**

### 6.4 Asymétries réelles M1 vs M2 (toutes celles relevées en §3 et §4)

| # | Asymétrie | Preuve M2 | Preuve M1 (ou son absence) | Nature / impact |
|---|---|---|---|---|
| **A1** | **Chemin benne (override) : M2 seul** | `FB_WinchCmdArbitrationM2.st:65-82` — branche `Context.BucketBusy AND Context.BucketM2RunRequest AND (Select=2 OR SEMI_AUTO)` → prend `ReqAscent/ReqDescend/StepTgt` de la benne et du **joystick** | `FB_WinchCmdArbitrationM1.st` — **aucune occurrence** de `Context.BucketM2*` | 🟠 **Structurelle et voulue** (M1 n'est pas le treuil benne) mais **non documentée en spec** : en SEMI_AUTO elle peut supplanter la demande du cycle |
| **A2** | **Gate `NOT Context.BucketBusy` absent chez M2** | `FB_WinchCmdArbitrationM2.st:143-151` : le gate ne contient **pas** `AND NOT Context.BucketBusy` | `FB_WinchCmdArbitrationM1.st:117` : contient `AND NOT Context.BucketBusy` | 🔴 **Incohérence** : M1 s'arrête pendant une action benne, M2 non. Le front descendant (`M2:156-158`) reste le seul filet commun. L'absence est cohérente avec A1 (M2 *doit* pouvoir suivre la benne) **mais** elle n'est pas bornée à la branche A1 : elle vaut aussi dans le mode manuel couplé |
| **A3** | **Brides de synchro INVERSÉES** | `FB_WinchCmdArbitrationM2.st:145-146` : `NOT ((SyncBlocksAscent AND ReqDescend) OR (SyncBlocksDescent AND ReqAscent))` | `FB_WinchCmdArbitrationM1.st:119-120` : `NOT ((SyncBlocksAscent AND ReqAscent) OR (SyncBlocksDescent AND ReqDescend))` | 🟢 **Voulue et commentée** (`M2:135` « synchro INVERSÉE vs M1 ») — inversion géométrique M2/M1. **MAIS** : aucune ligne de spec citée ; à confirmer sur banc (§11-U3) |
| **A4** | **Priorité SEMI_AUTO : cycle vs benne** | `FB_WinchCmdArbitrationM2.st:85` : la branche cycle est dans le `ELSE` de la branche benne (`:83`) — donc **le chemin benne gagne** en SEMI_AUTO | `FB_WinchCmdArbitrationM1.st:56` : branche cycle **inconditionnelle** dès `Mode = SEMI_AUTO` | 🔴 **Divergence de priorité manu/cycle entre les 2 treuils** — trouvé, non sourcé par une spec |
| **A5** | **Index du sélecteur joystick** | `M2:119` : `JoystickWinchSelectArbitrated = 2` | `M1:90` : `= 1` | 🟢 Voulue (1 = M1, 2 = M2) — documentée `FB_Modes.st:373-395` |
| **A6** | **Permis entrant de `FB_Winch`** | `PRG_04:1528-1529` : `M2DescendPermitApplied` / `M2AscentPermitApplied` (`:1131-1134`) → **AND supplémentaire avec le permis benne** | `PRG_04:1462-1463` : `EffectivePermitM1_Descend` / `_Ascent` **directs** | 🟠 **Défense en profondeur** benne côté M2, absente côté M1. Cohérent, mais crée **deux notions de permis** selon le treuil |
| **A7** | **Plafonds de palier M2-propres** | `PRG_04:1306-1315` (`instBucket.M2_BucketJogLimit`), `:1320-1334` (jog benne, `JogSlowdownZoneM`), `:1335-1338` (`SlackCable`/`BucketNotClosed`) | `PRG_04:1410-1411` : M1 ne consomme que `CommonMaxStep*` | 🟢 Voulue — **mais** `:1259-1261` montre que ces brides **doivent** être propagées à M1 en mode couplé, sinon `ContactorMismatch` → SafeStop |
| **A8** | **`TopLimitM2_M` a 2 overrides que M1 n'a pas** | `PRG_04:899-901` (jog benne : butée géométrique `M1 + OffsetCloseM + 2.0`) et `:902-906` (Both : `+0.50 m`) | `PRG_04:883-885` : M1 n'a que le `SEL` override/bypass | 🟠 **Deux régimes de limite haute différents** simultanément — gérable, mais toute analyse de blocage « limite haute » doit savoir **quel** `TopLimitM` s'applique |
| **A9** | **Diagnostic sécurité M2 plus large** | `PRG_06_Outputs.st:209-211` : `SlackCable` **+** `BucketState.Error` **+** `BucketState.CoupledMotionBlockedByBucket` | `PRG_06_Outputs.st:139-145` : aucun de ces 3 termes | 🟢 Voulue (M2 porte la benne) — impact diagnostic : une cause M2 peut SafeStopper M2 **sans** équivalent M1 |
| **A10** | **Plancher de palier descente** | `PRG_04:1488` : `ReqM2Winch.MinStepDown := M2MinStepDown` | `PRG_04:1414` : `ReqM1Winch.MinStepDown := CommonMinStepDown` | 🟢 Voulue (plancher de plongée Kobold côté M2 uniquement) |
| **A11** | **Plafond de descente exceptionnel** | `PRG_04:1299-1303` : `M2MaxStepDown := 5` si `AutoDiveM1Step4M2Step5Active` | M1 reste plafonné à `EffectiveMaxStepDescent` (=4) | 🟢 Voulue (T291-A), **bornée** et validée par `WinchBothFinalStep45Coherent` (`PRG_04:1631-1646`) |
| **A12** | **`instWinchSync` : ordre des arguments contacteurs** | `PRG_04:652-659` : `ContactorN_M1` / `ContactorN_M2` explicites | — | 🟢 **Fausse piste** : pas d'asymétrie, l'ordre est explicite des deux côtés. Mentionnée pour éviter un faux positif en diagnostic |

**Total : 12 asymétries relevées — 5 🟢 voulues et commentées (A3, A5, A7, A9, A10, A11, A12), 1 🟠
structurelle non sourcée en spec (A1), 2 🟠 défenses en profondeur dissymétriques (A6, A8), 2 🔴 incohérences
candidates (A2, A4).** Les 🔴 sont remontés en §10, **non corrigés**.

---

## 7. 🧰 BRANCHES MAINTENANCE (MAINT_N1 / MAINT_N2)

Portes de mode explicites et chemins courts **vérifiés** :

| # | Branche | Ligne de la porte | Effet | Court-circuite quoi ? |
|---|---|---|---|---|
| **7.1** | **Boutons IHM au lieu du joystick** | `GVL_IHM.Modes.Cmd.TglJoystickMaster` → arbitres `M1:68`, `M2:97` (`IF NOT TglJoystickMaster THEN`) ; bits préparés `PRG_04:492-497` | En mode Boutons : `BtnAscentM1/DescentM1` (ou `M2`) donnent directement `ReqAscent/ReqDescend` + `StepTgt := Cfg.BtnStepTgt` (=5, `PRG_04:523-524`) | **Oui** : court-circuite **le geste joystick** et **le palier joystick** (plein palier 5 imposé). ⚠️ `DeadmanArmed` n'est **plus** exigé par le gate (`NOT TglJoystickMaster OR Joystick.DeadmanArmed`, `M1:121`) → en mode boutons le gate homme-mort est **neutre** |
| **7.2** | **Boutons couplés M1+M2** | `GVL_IHM.Commun.BtnWinchBothAscent/Descent` → `PRG_03_Modes_Cycle.st:145-151` → `Data.WinchBothIntent` (`:297-299`) → arbitres `M1:70-74`, `M2:99-103` | Force `ReqAscent/ReqDescend` des **2** treuils au palier `Cfg.BtnStepTgt` | **Oui** : court-circuite le joystick et le sélecteur unitaire |
| **7.3** | **Cycle de homing machine (MAINT_N2)** | `PRG_03_Modes_Cycle.st:401-405` (`Mode = MAINT_N2 AND Data.MachineHoming.Active` → `ReqWinchM1/M2 := CmdWinchM1/CmdWinchM2`) ; émissions `FB_CycleMachineHoming.st:589-590` (HX2 montée) et `:617-618` (HX3 descente) ; permis `:237-238` (`ClimbPermit := DeadmanArmed AND JoystickPull`) | Publie un ordre treuil couplé palier 1 **sur le bus `ReqWinchM1/M2`** | ⚠️ **NE court-circuite PAS la chaîne** — voir l'alerte §10 point 3 : l'arbitre ne lit `ReqWinch` **que** sous `Mode = SEMI_AUTO` (`M1:56`, `M2:85`), donc en MAINT_N2 cette publication n'est **pas consommée** par la chaîne treuil. Le mouvement observé en homing vient du **geste joystick** (exigé par `ClimbPermit`, `FB_CycleMachineHoming.st:237`) via la branche **manuelle** de l'arbitre |
| **7.4** | **Garde « Trémie » sur le sélecteur** | `CODE/F_MODES/FB_Modes.st:372-374` (`M3AtTremie AND NOT AllowWinchMoveAtTremie` → `JoystickWinchSelectArbitrated := 2`) | À la Trémie, M2 seul est joignable → interdit le pilotage **couplé** manuel à la Trémie | **Oui** : court-circuite le choix opérateur du sélecteur. Échappatoire consciente : `GVL_IHM…AllowWinchMoveAtTremie` |
| **7.5** | **Verrou de phase benne T248** | `FB_Modes.st:375-393` (`CoupledBucketSeqEnable AND Select=0 AND (Pull XOR Push)`) → `Auth.CoupledBucketPhaseLocked` (`:383`) | Force `Select := 2` (jog) jusqu'à `BucketSeqSatisfied`, puis `0` (couplé) | **Oui** : court-circuite le sélecteur ; `Auth.CoupledBucketPhaseLocked` est consommé `PRG_04:321` |
| **7.6** | **HOLD de transition de sélecteur** | `FB_Modes.st:407-410` → `Auth.WinchSelTransitionHold` ; consommé `PRG_04:572-575` | Force M1 **et** M2 à 0 (arrêt rampe) pendant ~300 ms après tout changement franc de sélecteur | **Oui** : annule temporairement **toutes** les demandes, quel que soit le mode — « pas de hand-off en mouvement » |
| **7.7** | **Desserrage forcé des freins M1/M2** | `PRG_06_Outputs.st:320-324` (M1) / `:325-329` (M2) : `Mode = MAINT_N2 AND EmergencyChainClosed_DI AND PowerContactorEngaged_DI AND (BtnBothBrakeRelease OR BtnMxBrakeRelease)` → OR injecté `:330-331` | Ouvre la **bobine frein sans aucun mouvement commandé** (descente par gravité en maintenance) | **Oui, et c'est le seul point de `PRG_06` qui écrit une sortie treuil hors de la chaîne nominale.** Branche **strictement bornée** (3 conditions) et **symétrique M1/M2** |
| **7.8** | **Override du FDC haut logiciel (MAINT_N1)** | `PRG_04:856-863` (`MaintN1 AND …`) | Fait passer le seuil de 7,5 m à 8,5 m (voir §6.3) | **Non** : il **déplace** le seuil, il ne contourne pas un étage. Le FdC haut **matériel** reste actif (`FB_Safety_Winch.st:576`) |
| **7.9** | **Bypass de position N2 (latché, tous modes)** | `PRG_04:866-875` (calcul, **sans gate de mode** — dérogation assumée `:841-844`) → `FB_Safety_Winch.st:577` (`BypassTopLimitSwitch`), `:581` (`BypassTopLimitSoftware`) | Lève la butée logicielle **et/ou** le FdC haut logiciel | **OUI — court-circuite un étage de sécurité**, et **pas seulement en maintenance** (voir §10, point 2) |
| **7.10** | **Bypass synchro / concordance contacteurs** | `PRG_04:660-668` (`instWinchSync.BypassGlobal` ← 10 sources IHM) ; `PRG_06:351-359` (`instSyncContactorFinal.BypassGlobal`) | Neutralise la surveillance d'écart M1/M2 et la concordance des vecteurs | **Oui** — également **sans gate de mode** |
| **7.11** | **Dérogation « tous modes » des bypass sécurité treuil** | `PRG_04_Treuils_Benne.st:292-295` (bandeau) + `:970-971` | ⚠️ **Constat explicite** : le code affirme que les bypass ne sont **plus** conditionnés au mode (choix opérateur assumé, tracé AF-05 §4bis) | Ce n'est donc **pas** une branche MAINT au sens strict : c'est une **extension de la branche MAINT à tous les modes** |
| **7.12** | **Branche MAINT_N1/N2 qui n'existe PAS** | — | ✅ **Déclaré explicitement** : il n'existe **aucun** chemin « MAINT_N1/N2 » dans les FB d'arbitrage eux-mêmes. `FB_WinchCmdArbitrationM1.st:56` et `FB_WinchCmdArbitrationM2.st:85` ne testent que `E_Mode.SEMI_AUTO` ; **tout le reste** (y compris `MAINT_N1`, `MAINT_N2`, `DISABLE`, `AUTO`) tombe dans la même branche `ELSE` dite « manuelle » | Conséquence de diagnostic : **la branche « manuelle » est en réalité la branche « tout sauf SEMI_AUTO »** |
| **7.13** | **Branche MAINT qui n'existe PAS (bis)** | — | ✅ Déclaré : il n'existe **aucun** bouton / chemin IHM de maintenance treuil propre à `PRG_06` en dehors du §7.7 (desserrage frein). `PRG_06:369-384` est l'**unique** écriture des `%Q` treuils | Évite la recherche d'un chemin fantôme |

---

## 8. 🎛️ LES 4 FAMILLES DE SOURCES DE DEMANDE D'UN TREUIL

| Famille | Trace de production (fichier:ligne) | Régime où elle est **RETENUE** | Retenue pour |
|---|---|---|---|
| **(a) Geste joystick** | Mesure `PRG_02_Acquisition.st:482` → `FB_AxisScale` (`FB_Joystick.st:184`) → `FB_Joystick.st:278-280`, `:294-301`, `:305-307` → bus `PRG_02_Acquisition.st:492-493` → entrée `PRG_04:532` (M1) / `:555` (M2) → consommée `FB_WinchCmdArbitrationM1.st:91-93` / `FB_WinchCmdArbitrationM2.st:120-122` | **MANU/MAINT uniquement**, et seulement si `TglJoystickMaster = TRUE` **et** `Select = 1` (M1) / `Select = 2` (M2) ; **ou** `Select = 0` via l'intention couplée `M1:94-98`, `M2:123-127` | M1 ✅ M2 ✅ |
| **(b) Boutons IHM** | `GVL_IHM…BtnAscent/Descent` → `PRG_04_Treuils_Benne.st:492-497` → arbitres `M1:75-82` / `M2:104-111` · variante couplée : `GVL_IHM.Commun.BtnWinchBothAscent/Descent` → `PRG_03_Modes_Cycle.st:145-151` → `PRG_03:297-299` → `M1:70-74` / `M2:99-103` | **MANU/MAINT**, si `TglJoystickMaster = FALSE` (mode Boutons) ou si un bouton « both » est appuyé | M1 ✅ M2 ✅ |
| **(c) Actions de la BENNE M2** | `FB_Bucket` (appel `PRG_04:340`) → `instBucket.M2_RunRequest` / `.M2_ReqAscent` / `.M2_ReqDescend` → `PRG_04:488-489`, `:500` → `ArbContext` (`:501-502`) → **`FB_WinchCmdArbitrationM2.st:65-82`** · contexte d'armement : `PRG_04:503-509` | **MANU** si `Select = 2` (jog benne unitaire, `PRG_04:305-306`) ; **SEMI_AUTO** dès que `BucketBusy AND BucketM2RunRequest` (`M2:65-67`) | **M2 uniquement** ⚠️ (M1 : chemin inexistant — §6.4-A1) |
| **(d) Demande du SÉQUENCEUR de cycle** | `instCycleSemiAuto` (`PRG_03_Modes_Cycle.st:29`, appel `:190`) → `WinchM1Cmd`/`WinchM2Cmd` (`FB_CycleSemiAuto.st:1055-1060`, `:1230-1235`, `:1367-1372`, `:1397-1402`, `:1545-1550`) → `Data.ReqProgram.ReqWinchM1/M2` (`PRG_03:306-307`) → entrées `PRG_04:534` / `:557` → consommée `FB_WinchCmdArbitrationM1.st:58-61` / `FB_WinchCmdArbitrationM2.st:87-90` | **SEMI_AUTO uniquement** (`M1:56`, `M2:85`) — **et uniquement si le chemin benne (c) n'a pas pris la main côté M2** | M1 ✅ M2 ⚠️ sous condition |

**Règle de lecture pour le diagnostic :** les familles (a) et (b) sont **mutuellement exclusives** par
`TglJoystickMaster` ; la famille (c) est **prioritaire sur toutes les autres** côté M2 ; la famille (d) est
**exclusive** par le mode. Toute autre combinaison observée est un défaut.

---

## 9. 📟 SORTIE PHYSIQUE — contacteurs, relais, bobines frein

Source du mapping (relue dans ce lot) : `TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv`.
Ligne d'écriture logique : `CODE/M_MAIN/PRG_06_Outputs.st` (blob `3b7534a3acd4`).

| Variable logique | Écrite `PRG_06_Outputs.st` | Sortie physique | Ligne du mapping CSV | Organe / module |
|---|---|---|---|---|
| `M1_RelayAscent_RQ` | `:369` | `%QX27.4` | `:482` | **+1 sens ENROULAGE MONTÉE EXTRACTION** — VH_0008ER |
| `M1_RelayDescent_RQ` | `:370` | `%QX27.5` | `:483` | **−1 sens DÉROULAGE DESCENTE PLONGÉE** — VH_0008ER |
| `M1_SpeedContactor_1_DQ` | `:371` | `%QX26.0` | `:460` | Contacteur de résistances moteur M1 (bit0@1) — VH_0808ETP |
| `M1_SpeedContactor_2_DQ` | `:372` | `%QX26.1` | `:461` | Idem (bit1@1) |
| `M1_SpeedContactor_3_DQ` | `:373` | `%QX26.2` | `:462` | Idem (bit2@1) |
| `M1_SpeedContactor_4_DQ` | `:374` | `%QX26.3` | `:463` | Idem (bit3@1) |
| `M1_BrakeRelease_RQ` | `:375` (`:= M1BrakeCmd`, recalculé `:307` **et** `:330`) | `%QX27.0` | `:478` | **Bobine frein M1** — VH_0008ER |
| `M2_RelayAscent_Close_RQ` | `:378` | `%QX27.6` | `:484` | **+1 MONTÉE EXTRACTION — FERMETURE GRAPPIN** |
| `M2_RelayDescent_Open_RQ` | `:379` | `%QX27.7` | `:485` | **−1 DESCENTE PLONGÉE — OUVERTURE GRAPPIN** |
| `M2_SpeedContactor_1_DQ` | `:380` | `%QX26.4` | `:464` | Contacteur de résistances moteur M2 (bit4@1) |
| `M2_SpeedContactor_2_DQ` | `:381` | `%QX26.5` | `:465` | Idem (bit5@1) |
| `M2_SpeedContactor_3_DQ` | `:382` | `%QX26.6` | `:466` | Idem (bit6@1) |
| `M2_SpeedContactor_4_DQ` | `:383` | `%QX26.7` | `:467` | Idem (bit7@1) |
| `M2_BrakeRelease_RQ` | `:384` (`:= M2BrakeCmd`, `:308` **et** `:331`) | `%QX27.1` | `:479` | Bobine frein M2 — VH_0008ER |

**Retours physiques consommés (boucle fermée / watchdog) :**

| Entrée | Adresse | Ligne CSV | Consommée |
|---|---|---|---|
| `M1_ContactorsReleased_DI` | `%IX0.0` | `:5` | `PRG_04_Treuils_Benne.st:959` (`FwdRevSpeedFeedbackOff`), `:1602`, **et `FB_Winch.st:198` (condition de D18)** |
| `M1_ThermalOk_DI` | `%IX0.1` | `:6` | `PRG_04_Treuils_Benne.st:942` (`NOT` → `ThermalFeedback`) |
| `M2_ContactorsReleased_DI` | `%IX0.2` | `:7` | `PRG_04_Treuils_Benne.st:1619` et `FB_Winch.st:198` (instance M2) |
| `M2_ThermalOk_DI` | `%IX0.3` | `:8` | Instance M2 de `FB_Safety_Winch` (`PRG_04:996`) |
| `M1M2_TopPositionFree_DI` (NC) | `%IX0.7` | `:12` | `PRG_04_Treuils_Benne.st:948` → `FB_Safety_Winch.st:576` |
| `M1_BrakeIsOpen_DI` | `%IX225.0` | `:469` | `PRG_04_Treuils_Benne.st:960`, `:1601` → watchdog `FB_WinchOutputInterlock.st:494` |
| `M2_BrakeIsOpen_DI` | `%IX225.1` | `:470` | `PRG_04_Treuils_Benne.st:1618` |
| `M1_M2_M3_BrakeThermalOk_DI` | `%IX225.3` | `:472` | `PRG_04_Treuils_Benne.st:943` |
| `JoyYRaw_ANA2` (axe treuils) | `%IW115` | `:521` | `PRG_02_Acquisition.st:482` |
| `JoyXRaw_ANA1` (axe translation) | `%IW114` | `:504` | `PRG_02_Acquisition.st:481` |
| `JoyBtnRaw` (homme-mort) | `%IX226.0` | `:496` | `PRG_02_Acquisition.st:483` |

**Chaîne d'écriture complète (identique M1/M2 et identique manu/cycle) :**
`instWinchOutputInterlockMx.<Relay|Contactor>` (`FB_WinchOutputInterlock.st:458-464`) → `PRG_06:167-172`
(ou `:233-238`) → **`FB_ContactorProtector`** (`PRG_06:280-285` / `:293-298`) → `PRG_06:286-291` / `:299-304`
→ **recalcul du frein après filtrage** `PRG_06:307-308` → **OR maintenance N2** `:330-331` →
écriture `%Q` `:369-384`.

> ⚠️ **Le frein n'a PAS de `FB_ContactorProtector`** — décision explicite et commentée (`PRG_06:275-279`) :
> un plancher retarderait le desserrage et ferait travailler le moteur contre le frein serré. Le frein suit
> les relais de sens filtrés, eux-mêmes planchés par le temps mort D18.

---

## 10. 🚨 Devoir d'alerte — constats hors scope (signalés, NON corrigés)

| # | Constat | Preuve | Impact |
|---|---|---|---|
| **1** | **`DOC/WFLOW/TASKS.yaml` est périmé sur T325** : il décrit encore T325 comme « ANALYSE et CADRAGE uniquement — aucune modification de code », alors que le correctif D18 est **committé** (3 commits `6f708b22`, `657be973`, `e638308f`) | `git log` + §6.1 | 🟠 Doc/pilotage — à corriger par l'orchestrateur (registres hors de mon périmètre) |
| **2** | **Les bypass de sécurité position sont effectifs dans TOUS les modes, y compris SEMI_AUTO**, par dérogation assumée | `PRG_04_Treuils_Benne.st:841-844`, `:865`, `:970-971` ; consommation `FB_Safety_Winch.st:577`, `:581` ; `PRG_04:867`, `:872` | 🔴 **Sécurité** : un bypass `TopLimitSoftware` resté armé lève la butée logicielle **aussi en automatique**. La barrière dure (`%IX0.7` → `FB_Safety_Winch.st:576`) reste, elle, non bypassable par ce chemin. À tracer explicitement en AF-05 §4bis |
| **3** | **`Data.ReqProgram.ReqWinchM1/M2` publié en MAINT_N2 (homing) n'est consommé par AUCUN arbitre dans ce mode** : `FB_WinchCmdArbitrationM1.st:56` et `M2.st:85` ne lisent `ReqWinch` que sous `Mode = SEMI_AUTO` | Producteur `PRG_03:401-405` ← `FB_CycleMachineHoming.st:589-590`, `:617-618` ; seuls consommateurs `PRG_04:534`, `:557` et (affichage) `PRG_07_Supervision.st:757`, `:793-799` | 🟠 **À confirmer** (§11-U1) : le mouvement de homing est de fait produit par le **geste joystick** exigé par `ClimbPermit := DeadmanArmed AND JoystickPull` (`FB_CycleMachineHoming.st:237`), via la branche manuelle. Si `TglJoystickMaster = FALSE` (mode Boutons), `ClimbPermit` est satisfait par le joystick mais l'arbitre est en branche **Boutons** → la montée de homing HX2 **pourrait ne pas partir**. Chemin non testé, non tranché ici |
| **4** | **Asymétrie A2 — `NOT Context.BucketBusy` absent du gate M2** (`M2:143-151` vs `M1:117`) | §6.4-A2 | 🔴 en mode manuel couplé, M2 peut partir alors que M1 est gelé par une action benne. Le front descendant (`M2:156-158`) est le seul filet commun |
| **5** | **Divergence de priorité A4 — le chemin benne supplante le cycle côté M2** | `FB_WinchCmdArbitrationM2.st:65-67` (autorise `SEMI_AUTO`) vs `FB_WinchCmdArbitrationM1.st:56` (inconditionnel) | 🔴 en SEMI_AUTO, une action benne peut détourner M2 de la demande du séquenceur → **désynchronisation M1/M2 en cours de cycle**. Aucune spec ne décrit cette priorité ; la justification n'existe que dans un commentaire (`M2:59-64`) |
| **6** | **`TglJoystickMaster = FALSE` neutralise le gate homme-mort de l'arbitre** | `M1:121` / `M2:147` : `(NOT TglJoystickMaster OR Joystick.DeadmanArmed)` | 🟠 en mode Boutons, l'exigence `DeadmanArmed` disparaît du gate de l'arbitre. À vérifier : est-elle reprise ailleurs ? `FB_Safety_Winch` porte `JoystickOnline/Operational` (`PRG_04:937-938`) mais pas `DeadmanArmed`. **Non tranché** (§11-U2) |
| **7** | **Le garde-fou survitesse est désactivé dans les 2 chaînes** : `SpeedGuardEnable := FALSE` codé en dur | `PRG_04_Treuils_Benne.st:1441` (M1), `:1509` (M2) ; commentaire de dette `:1430-1440` ; consommateur `FB_Winch.st:234` | 🟠 Dette safety **déjà documentée** dans le code (FB `FB_WinchRateInterlock` inexistant). Signalé, non touché |
| **8** | **Écart du brief T351 sur les lignes de la garde croisée** | §6.2 | 🟠 Constat documentaire — **le brief n'est pas modifié** (interdit de périmètre) |
| **9** | 🔴 **DEUX FICHIERS CITÉS ONT ÉTÉ MODIFIÉS PAR DES LOTS CONCURRENTS PENDANT CE LOT, L'UN D'EUX DEUX FOIS.** `PRG_04_Treuils_Benne.st` : blob `e6005d533cac` (01:23) → **`31760d59b4e0`** (01:29), **+1 ligne** décalant tout le fichier à partir de ~380 (stable depuis, puis committé `065591fb`). `PRG_02_Acquisition.st` : **`fabb8f764dd8` → `892de7b784f5` (+6 lignes) → `5b8baa9ba8ea` (−1 ligne)** — **3 blobs en 8 minutes**. **Conséquence : toutes les références déjà écrites étaient devenues fausses, deux fois** ; elles ont été **entièrement re-dérivées et re-vérifiées**, puis contrôlées **exhaustivement** (211/211, §14) | `git hash-object` avant/après ; `git status --short -- CODE/` avant/après ; HEAD `d6e54377` → `065591fb` | 🔴 **Risque de méthode, pas de code** : c'est la démonstration que le critère AC10 (« `git status --short -- CODE/` identique avant/après ») **ne peut pas être tenu par un lot de documentation** tant que des lots de code tournent en parallèle. **Le gel de l'arbre, ou l'ancrage par blob re-vérifié en fin de lot, est indispensable.** Annexe M3 (DSH17) a constaté **le même phénomène** de son côté |
| **9bis** | ✅ **Résolution du drift** : le lot concurrent a **committé** son travail à `01:32:32` sous **`065591fb`** (`fix(benne): T262 phase B …`). `PRG_04_Treuils_Benne.st`, `PRG_07_Supervision.st`, `FB_Bucket.st`, `ST_CycleCfg.st` et le fichier non suivi `FB_BucketCloseThreshold.st` sont **redevenus propres**. **Seuls** restent sales : `PRG_02_Acquisition.st` (cité) et `GVL_Simulation.st` (non cité) | `git status --short -- CODE/` à `01:33:25` ; `git log -1` | 🟢 **L'arbre est en cours de stabilisation, mais `PRG_02` reste instable** — c'est le seul fichier cité dont les références peuvent encore être invalidées |
| **10** | **Le diff non committé de `PRG_04_Treuils_Benne.st` portait du « T262 phase B »**, pas du T291-B/AGY01 comme annoncé par l'orchestrateur. ✅ **Confirmé par le commit lui-même** : `065591fb` = « **fix(benne): T262 phase B** - seuil d'ouverture benne cable (branche additive, borne 20%) [NON TESTE MACHINE] » | `git diff` pendant le lot : `instCloseThreshold : FB_BucketCloseThreshold;` `:27`, `ThresholdMeasureValid` `:28`, branchement `:1811-1826` ; puis `git log -1` | 🟠 **Incohérence d'attribution confirmée** — l'information transmise au lot (« périmètre T291-B / AGY01 ») désignait le mauvais lot. Corrigé par les faits, non par ce document |
| **11** | **Conflit de consignes sur les registres** : le brief T351 §7 demande de mettre à jour `TASKS.yaml` et `TASK_LOCKS.json` ; **la consigne d'orchestration du lot m'interdit explicitement ces 2 fichiers** (2 lots en parallèle → risque de mise à jour perdue) | Brief §7 vs consigne du lot ; le contrat `scope.allowed` les autorise, `scope.forbidden` ne les interdit pas | 🟡 Résolu **en faveur de l'interdiction** (périmètre le plus restrictif). ⚠️ **AC12 dépend d'une écriture que je ne peux pas faire** : le catalogue doit être mis à jour **par l'orchestrateur** (chemin du livrable + horodatage ISO). Information remontée §14 |
| **12** | **Boucle d'un scan assumée sur `ArmingPermit`** | `PRG_02_Acquisition.st:464` (consomme `PRG_04_Treuils_Benne.Data.ArmingPermit`) vs `PRG_04:1205` (producteur, rang 04 après rang 02) | 🟢 Documenté (`PRG_04:1161-1163`) — signalé pour que le diagnostic ne le prenne pas pour un bug |

---

## 11. ❓ Trous et incertitudes (critère AC11)

> **Aucun comblement par supposition.** Ce qui n'est pas prouvé est listé ici. Les chaînes §3 et §4 sont
> **complètes** au sens « de la source au contacteur » : aucun maillon n'est laissé implicite.

| # | Question ouverte | Ce qui manque pour trancher | Statut |
|---|---|---|---|
| **U1** | Le mouvement de homing machine en **MAINT_N2** passe-t-il effectivement par le geste joystick (donc par la branche manuelle de l'arbitre) alors que `CmdWinchM1/M2` publiés ne sont pas consommés ? Et que se passe-t-il si `TglJoystickMaster = FALSE` (mode Boutons) ? | Un essai machine MAINT_N2 en mode Boutons, ou une trace 10 ms de `M1LogicRunRequest` / `M2LogicRunRequest` pendant HX2_CLIMB. **Statique non concluant** : `ClimbPermit` (`FB_CycleMachineHoming.st:237`) exige le joystick, ce qui rend le cas Boutons ambigu | 🔴 **ouverte** (§10-3) |
| **U2** | En mode Boutons IHM (`TglJoystickMaster = FALSE`), existe-t-il **un autre** porteur de l'exigence homme-mort dans la chaîne ? Le gate de l'arbitre le neutralise (`M1:121`) | Lecture complète du chemin boutons : `FB_Safety_Winch` (joystick online/operational seulement, `PRG_04:937-938`), `instBucket`, `FB_CycleSemiAuto`. **Aucun porteur identifié à ce stade**, mais la recherche n'a pas été exhaustive sur `FB_Bucket` | 🔴 **ouverte** |
| **U3** | L'inversion des brides de synchro M2 (A3, `M2:145-146`) est-elle **correcte** ? | Une validation banc/simulation : provoquer un écart synchro de sens connu et vérifier **quel** sens M2 est bridé. Le code l'affirme (`M2:135`) mais aucune spec ne le prescrit | 🟡 hypothèse forte, **non prouvée** |
| **U4** | La garde croisée (`PRG_04:1407-1409`, `:1499-1501`) gèle-t-elle **le bon** treuil dans **tous** les cas ? Le commentaire affirme qu'il faut figer le treuil **prêt**, jamais celui qui purge son D18 (`:1400-1404`) | Analyse fine du cas « les 2 en `DirectionChangePending` simultanément » : le code ne fige alors **aucun** des deux (`:1407` exige que **l'autre** soit pending). Cas non testé | 🟡 hypothèse — **à tester** |
| **U5** | `instWinchLoadEstimatorMx.MeasuredSpeedBand` est publié (`PRG_04:1425`, `:1507`) mais **sans effet** puisque `SpeedGuardEnable := FALSE` (`:1441`, `:1509`). La table `SpeedBandMaxMps` est-elle validée ? | Le FB lui-même documente « table non prouvée » (`:1430-1440`) et renvoie à `AF-10 §7.3 TBD` | 🔴 **dette ouverte** — signalée, non instruite |
| **U6** | La **limite résiduelle T325 phase 2** de D18 (`FB_WinchDirectionInterlock.st:13-19`) est-elle atteignable **en exploitation** ? | Une trace 10 ms sur `DeadTimeArmed` + `DirectionChanged` + `LastAscent/LastDescend`. Le cycle sollicite D18 plus souvent (§5.2 D07), ce qui **augmente** l'exposition sans la prouver | 🔴 **ouverte et importante** — c'est le point chaud n°1 du mécanisme |
| **U7** | Le seuil `M2_LimitShift` (= `instBucket.ActiveOffsetM`, `PRG_04:835`) peut-il rendre `TopLimitM2_M` **inférieur** à la position courante de M2 et créer un arrêt permanent ? | Analyse de `:886-888` + `:899-907` : le code ajoute `M2_LimitShift` au seuil **et** compare une position M2 qui contient déjà cet offset — l'égalité semble préservée, mais le cas `ActiveOffsetM` en cours de variation (pente bornée, `:833-834`) **n'a pas été simulé** | 🟡 hypothèse de non-problème — **à confirmer** |
| **U8** | `PRG_04_Treuils_Benne.st:1590-1612` (bloc `§7 Publication demandes`, en-tête de région `:1590`) est-il le **SEUL** point de sélection de source en aval ? | ✅ **Tranché (fait vérifié)** : `PRG_06_Outputs.st:150-164` / `:216-230` est le **seul** consommateur décisionnel des `WinchMxFinalInterlockRequest`, et `PRG_04:1603-1609` / `:1620-1626` le **seul** producteur des relais/contacteurs/palier finaux. **Aucun second chemin** vers `PRG_06:369-384` hormis le desserrage frein MAINT_N2 (`:330-331`) | 🟢 **résolu, consigné ici pour mémoire** |
| **U9** | Stabilité de l'ancrage pendant le lot | ✅ **Constaté et documenté** : **2 des 27 fichiers cités ont changé de blob en cours de lot** (§1, §10-9). La re-dérivation a été faite, mais **rien ne garantit qu'ils ne bougeront pas encore** juste après la livraison. La seule protection est le contrôle par blob en tête de document | 🔴 **risque résiduel accepté** — non éliminable par ce lot |
| **U10** | Les chaînes décrites sont-elles **complètes** ? | ✅ **Déclaration** : les §3/§4 couvrent **toutes** les variables traversées entre la mesure physique du geste et l'écriture `%Q`, y compris les maillons omis par le brief (arbitres, sync, projection d'état, estimateurs, apprentissage, benne M2 comme demandeur). **Sont volontairement exclus** et donc **déclarés non couverts** : l'intérieur de `FB_Bucket`, le grafcet de `FB_CycleMachineHoming`, et la logique interne de `FB_WinchSync` / `FB_WinchOutputInterlock` au-delà de leurs entrées/sorties et de leurs lignes de décision (`:458-464`, `:487`, `:494`, `:221-227`) | 🟢 **déclaré** |
| **U11** | Le contenu des lots concurrents non committés (`PRG_02`, `PRG_04`, `PRG_07`, `FB_Bucket`, `GVL_Simulation`, `ST_CycleCfg`) est-il **stable** et validé ? | Hors de mon périmètre (interdit de lecture étendue et de modification). Constat : ils bougent. **Ce document décrit l'état disque à l'instant de son ancrage**, pas l'état cible | 🔴 **hors périmètre** — signalé à l'orchestrateur |

---

## 12. 🔗 Annexe associée

➡️ `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T351_ANNEXE_M3_TrousT334_20260921.md`
— **LIVRÉE** par l'acteur **DSH17** (session `task-T351-annexeM3`), **567 lignes** (549 à `01:29:49`,
`567` à `01:33`), relue à `01:33`. **Non produite par ce lot** (missions séparées, conformément à la
répartition imposée). **Non modifiée** par ce lot.

Contenu vérifié : audit du niveau d'exhaustivité de la chaîne **M3** de T334 — verdict **PARTIELLEMENT**,
3 trous bloquants (absence d'ancrage de révision ; références `FB_CycleSemiAuto.st` périmées de +20 à +91 ;
permis directionnels `EffectivePermitM3_*` non tracés), 7 notables, 3 cosmétiques.

### 🔗 Coordination de fusion — alignement des intitulés (§3.10 de l'annexe)

L'annexe **§3.10** mappe sa grille d'audit `a→g` sur **mes** sections. Vérification faite : **elle a
utilisé mes intitulés existants**, donc **aucun renommage n'est nécessaire** pour rendre la fusion
possible. Correspondance confirmée telle quelle :

| Grille de l'annexe | Ma section (intitulé exact, inchangé) |
|---|---|
| a) 4 familles de sources de demande | **§8 — LES 4 FAMILLES DE SOURCES DE DEMANDE D'UN TREUIL** |
| b) point de sélection de source unique en aval | **§5.1 — Où les deux chaînes CONVERGENT (preuve)** |
| c) branches MAINTENANCE (MAINT_N1 / MAINT_N2) | **§7 — BRANCHES MAINTENANCE (MAINT_N1 / MAINT_N2)** |
| d) matrice physique / sortie physique | **§9 — SORTIE PHYSIQUE — contacteurs, relais, bobines frein** |
| e) FB traversés | **§5.4 — FB traversés en plus / en moins dans chaque chaîne** |
| f) trous et incertitudes | **§11 — Trous et incertitudes (critère AC11)** |
| g) ancrage de révision | **§1 — Contexte figé, périmètre et ANCRAGE DE RÉVISION**, sous-bloc **🔐 Bloc d'ancrage de révision (AC2)** |
| §4 de l'annexe (compléments à fusionner) | **§12 — Annexe associée** (ce document pointe déjà l'annexe) |
| §5 de l'annexe (devoir d'alerte) | **§10 — Devoir d'alerte — constats hors scope** |
| §7 de l'annexe (journal) | **§13 — Journal (chronologique, horodaté)** |

⚠️ **Une réserve de l'annexe est désormais obsolète** : son §3.10 (`:381`) relève que mon bloc d'ancrage
déclarait `PRG_02_Acquisition.st` **« PROPRE »** au blob `fabb8f764dd8` (mesure `01:23:40`). Ce point est
**corrigé** : le fichier est déclaré **SALE** dans le tableau §1 ci-dessus, avec ses **3 blobs successifs**
et le blob de référence final `5b8baa9ba8ea` (719 l). L'annexe a lu mon document à `01:28`, avant mes
2 re-ancrages.

🔗 **Recoupement avec ce document** : l'annexe signale le **même phénomène de fichiers mouvants en cours
de lot** (elle a dû se re-ancrer à `01:28:50`, puis relire à `01:31:44`). C'est un **problème systémique
de méthode** sur ce dépôt, pas un incident isolé → remonté en §10-9.

🔍 **Sur le fond, je confirme par recoupement indépendant les 2 exemples cités par l'annexe** que j'ai
croisés avec mes propres lectures : `FB_CycleSemiAuto.st` → `CycleMotionPermit` = **`:780`** (T334 dit
`:715`) et `TranslationP1Permit` = **`:781`** ; `PRG_06_Outputs.st` → `instTranslationOutputInterlockM3(`
= **`:434`**. **Ce document ne réutilise AUCUNE référence de ligne de T334** : toutes ses références
proviennent de lectures directes du disque ancrées §1 — vérification faite, il ne cite **aucune** ligne
de `PRG_05_Translation.st`, `FB_Translation*.st` ni aucun symbole M3 (`M3_TremieProcessBlock`,
`EffectivePermitM3_*`, `instTranslationOutputInterlockM3` y apparaissent **0 fois**). Le seul renvoi à
M3 est **qualitatif** (§5.1 : « cf. T334 §6.1 »), sans numéro de ligne.

📌 La fiche `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T334_M3_DeuxChemins_2026-09-20.md`
(verrou d'écriture DSH07, en vol) **n'a pas été modifiée** par ce lot : elle a servi de **gabarit de format**
sections 4/5/6/7/8/10 uniquement. Elle est `M` dans `git status` — **modification attribuable au verrou
DSH07, jamais à ce lot.**

---

## 13. 📝 Journal (chronologique, horodaté)

| Heure (2026-09-21) | Étape | État | Détail |
|---|---|---|---|
| 01:23:27 | `debut` | en_cours | Lecture intégrale du préambule sous-agent (203 lignes) |
| 01:23:40 | `ancrage` | ok | `HEAD = d6e54377`. **`PRG_04_Treuils_Benne.st` blob disque `e6005d533cac`, SALE, 1982 lignes** — l'orchestrateur annonçait `e8551c3a80f6` / 1950 lignes (périmé ; 1950 = nombre de lignes du blob **HEAD**). `git status --short -- CODE/` relevé AVANT : 4 modifiés + 1 non suivi |
| 01:23:40 | `verif-disque` | ok | Contrôle anti-piège REX T345 : `instCloseThreshold` (présent **uniquement** dans le diff non committé) lu aux lignes **27 / 1815 / 1826** par `Select-String` **et** par l'outil de lecture → lecture outillée = **disque**, pas HEAD |
| 01:24:02 | `ancrage` | ok | 27 blobs `CODE/` + le CSV d'E/S mesurés. 12 valeurs identiques à celles de l'orchestrateur, **1 divergente** (`PRG_04`) |
| 01:25:13 | `lecture-code` | ok | Lecture réelle de `PRG_04` · `FB_WinchCmdArbitrationM1/M2` (intégral) · `FB_Winch` · `FB_WinchDirectionInterlock` · `FB_WinchOutputInterlock` · `FB_Safety_Winch` · `FB_Joystick` · `PRG_02` · `PRG_03` · `PRG_06` · `FB_Modes` · `FB_CycleSemiAuto` · `FB_CycleMachineHoming` · CSV E/S. Découvertes : 2 asymétries d'arbitre (A2, A4) + piste `ReqWinch` non consommé en MAINT_N2 |
| ~01:27 | `redaction` | ok | Première rédaction du livrable, ancre `e6005d533cac` / `fabb8f764dd8` |
| 01:29:20 | `mesure-apres` | **fail** | 🔴 **`git hash-object` APRÈS ≠ AVANT** : `PRG_04` = `31760d59b4e0` (≠ `e6005d533cac`), `PRG_02` = `892de7b784f5` (≠ `fabb8f764dd8`), et `GVL_Simulation.st` apparaît **nouvellement sale**. **Les références déjà écrites sont invalidées** (mission §7.9). Déclencheur de la branche de reprise |
| 01:29:49 | `re-derivation` | ok | Re-mesure des 27 blobs : **25 stables**, 2 modifiés. Détermination empirique du décalage : **+1** pour `PRG_04` à partir de ~ligne 380 (0 en dessous) ; **+6** pour `PRG_02` à partir de ~ligne 226 (0 en dessous, lignes 182-183 inchangées) |
| 01:29:49 | `verification` | ok | **133 ancres de contrôle** sur `PRG_04` (ligne + motif) : toutes cohérentes avec la règle +1 (dont 9 libellés de contrôle mal ciblés, vérifiés manuellement un par un — tous concordants avec +1). Correction de **2 imprécisions internes** de ma propre première rédaction quant aux lignes citées par le brief (§6.2) |
| 01:29:49 | `redaction-v2` | ok | Réécriture complète re-ancrée sur `PRG_04 = 31760d59b4e0` / `PRG_02 = 892de7b784f5` |
| 01:31:00 | `mesure-apres-v2` | **fail** | 🔴 **`PRG_02_Acquisition.st` A ENCORE BOUGÉ** : `892de7b784f5` → **`5b8baa9ba8ea`** (719 lignes, −1). **Troisième blob pour ce fichier en 8 minutes** → 3 contre-vérifications de l'échantillon ont échoué (`HwIn.Operator`, `RawY`, `AxisY` décalés de −1). `PRG_04` en revanche est **stable** (`31760d59b4e0`) |
| 01:31:00 | `verification-v3` | ok | Re-dérivation `PRG_02` : décalage **−1** pour toutes les lignes ≥ 445 (lignes 182-183 inchangées). Correction appliquée par **13 éditions ciblées en ordre anti-cascade**, + mise à jour du bloc d'ancrage, du journal et du contrôle de non-régression |
| 01:31:00 | `verification-v4` | ok | **35 ancres de contrôle** finales tirées des **deux chaînes** (`PRG_02`, `PRG_04`, `PRG_03`, `PRG_06`, `FB_Winch`, `FB_Safety_Winch`, `FB_WinchCmdArbitrationM1/M2`) : **35/35 conformes** après correction |
| 01:32:32 | *(événement externe)* | — | **Le lot concurrent T262 phase B COMMITE** son travail : HEAD `d6e54377` → **`065591fb`**. `PRG_04_Treuils_Benne.st`, `PRG_07_Supervision.st`, `FB_Bucket.st`, `ST_CycleCfg.st` et le fichier non suivi `FB_BucketCloseThreshold.st` **redeviennent propres** |
| 01:33:25 | `re-ancrage-3` | ok | Re-mesure **à la demande de l'orchestrateur** (alerte drift). `HEAD = 065591fb` · 27 blobs remesurés : **tous identiques à mon ancre précédente** (`PRG_04 = 31760d59b4e0`, `PRG_02 = 5b8baa9ba8ea`) → **les 211 références du document restent valides**. `git status --short -- CODE/` : plus que **2 entrées** (`PRG_02_Acquisition.st` cité · `GVL_Simulation.st` non cité). ⚠️ Les mesures de l'orchestrateur (01:30) étaient **périmées sur `PRG_02`** (annoncé 720 l / `892de7b784f5`, disque 719 l / `5b8baa9ba8ea`) |
| 01:33:25 | `verification-exhaustive` | ok | **Contrôle EXHAUSTIF : les 211 références `fichier:ligne` explicites du document ont été relues une par une contre le disque** (regex d'extraction sur le document → résolution du chemin → lecture de la ligne réelle). **211/211 conformes**, 0 hors-borne, 0 fichier introuvable. Aucun décalage mécanique appliqué : contrôle individuel |
| 01:33:25 | `maj-ancrage` | ok | Corrections : HEAD/bloc d'ancrage (`065591fb`, état **PROPRE/SALE re-dérivé pour chaque fichier**), règle d'usage, §10-9 + **§10-9bis (résolution du drift)**, §10-10 (**attribution T262 confirmée par le message de commit**), §11-U8 (bornes du bloc resserrées `1590-1612` au lieu de `1588-1616`), **§12 (alignement §3.10 de l'annexe + confirmation qu'aucun renommage n'est requis)**, §13, §14 |
| 01:33:25 | `verification-annexe` | ok | Annexe DSH17 relue (§3.10 + §3.8) : **567 lignes**. Ses 2 exemples d'écart T334 recoupés indépendamment et **confirmés** (`FB_CycleSemiAuto.st:780` `CycleMotionPermit`, `:781` `TranslationP1Permit`, `PRG_06:434` `instTranslationOutputInterlockM3(`). Vérifié : **ce document ne réutilise aucune référence de ligne de T334** |

---

## 14. ✅ Contrôle de non-régression du lot (read-only) et statut AC10

```
CODE/ : AUCUNE ÉCRITURE par ce lot. Aucun bundle, aucun gate, aucun test CI lancé (lot documentaire).
```

| Élément | AVANT (01:23:40) | APRÈS (01:33:25) | Verdict |
|---|---|---|---|
| `HEAD` | `d6e54377` | **`065591fb`** | ❌ **a avancé** — commit d'un **lot concurrent** (T262 phase B, `01:32:32`). Aucun commit de ce lot |
| `PRG_04_Treuils_Benne.st` blob | `e6005d533cac` | `31760d59b4e09b03a8e91b2358f8804a6b1985ad` | ❌ **CHANGÉ PAR UN AUTRE LOT** (stable depuis 01:29, puis committé) ; état **PROPRE** |
| `PRG_02_Acquisition.st` blob | `fabb8f764dd8` | `5b8baa9ba8ea0e9e0204ac8a5cc0a9a6b1bd2bb7` | ❌ **CHANGÉ DEUX FOIS PAR UN AUTRE LOT** (`892de7b784f5` puis `5b8baa9ba8ea`) — 🔴 **fichier chaud, encore SALE** |
| 25 autres blobs cités | — | **identiques** | ✅ stables |
| `git status --short -- CODE/` | `M FB_Bucket.st` · `M ST_CycleCfg.st` · `M PRG_04_Treuils_Benne.st` · `M PRG_07_Supervision.st` · `?? FB_BucketCloseThreshold.st` | `M CODE/L_SIMULATION/GVL_Simulation.st` · `M CODE/M_MAIN/PRG_02_Acquisition.st` | ❌ **jeu non identique** : 5 entrées résorbées (committées), **2 entrées restantes** — dont **1 seule citée** (`PRG_02_Acquisition.st`). `GVL_Simulation.st` **n'est pas cité** par ce document |
| Ancres de contrôle | — | **133** (balayage `PRG_04`) + **42** (échantillon 2 chaînes) + **211** (contrôle **exhaustif**, toutes références explicites) | ✅ **toutes conformes** |
| Commits créés | — | **aucun** | ✅ |
| Fichiers écrits par ce lot | — | **1 seul** : ce document (+ `TOOLS/AGENT_WORKFLOW/status/` via `agent_heartbeat.py`) | ✅ conforme au périmètre autorisé |

### 🧾 Preuve que ce lot n'a rien écrit dans `CODE/`

Aucun outil d'édition (`write`, `edit`) n'a été invoqué sur un chemin `CODE/…` de tout le lot : les
**seuls** appels d'écriture ont porté sur `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md`.
Les commandes lancées sur `CODE/` sont exclusivement **en lecture** (`git hash-object`, `git status`,
`git diff`, `git log`, `Select-String`, `Get-Content`, `read`, `grep`, `glob`). Aucun bundle, aucun gate,
aucun test CI, aucun `CODE_XML/`, aucun `Device.export`, aucun commit. **Les écarts constatés ci-dessus
sont donc intégralement imputables aux lots concurrents** (T262 phase B, et un second lot sur `PRG_02` +
`GVL_Simulation`).


### 📌 Évaluation honnête du critère AC10

> « Aucun fichier de CODE/ n'est modifié […]. Vérifié par comparaison de `git status --short -- CODE/`
> avant et après le lot : le jeu de fichiers doit être identique. »

**AC10 n'est PAS satisfait au sens mécanique** — mais **pas par ce lot** :
- Ce lot n'a écrit **aucun** octet dans `CODE/` (périmètre respecté à 100 %, aucun outil d'édition n'a
  été pointé sur `CODE/`) — preuve détaillée dans l'encadré « Preuve que ce lot n'a rien écrit » ci-dessus.
- Le jeu de fichiers diffère parce que des **lots concurrents** ont modifié puis **committé**
  `PRG_04_Treuils_Benne.st`, `PRG_07_Supervision.st`, `FB_Bucket.st`, `ST_CycleCfg.st`
  (commit `065591fb`, T262 phase B) et ont modifié, **sans les committer**, `PRG_02_Acquisition.st`
  (**deux fois**, 3 blobs) et `GVL_Simulation.st` — **pendant** la fenêtre du lot (01:23 → 01:33).
- **Aucun verrou de gel de l'arbre n'a été posé** pour ce lot documentaire, alors que le contrat
  anticipait explicitement ce risque (§`alert_duty`, 2ᵉ point) sans en tirer de mesure de gel.
- Le contrôle a donc été **rejoué trois fois**, et la version livrée est ancrée sur les blobs mesurés à
  `01:33:25`. **Si `PRG_02_Acquisition.st` bouge encore, ses seules références redeviendront fausses**
  (les 25 autres fichiers cités sont stables) : la procédure ci-dessous est à rejouer **en priorité sur
  ce fichier**.

**Recommandation à l'orchestrateur :** pour tout lot dont la valeur tient à l'exactitude de références
`fichier:ligne`, soit **geler l'arbre de travail** (ou travailler sur `git worktree` isolé au commit
d'ancrage), soit **exiger un re-ancrage par blob en fin de lot** — c'est ce qui a été fait ici, mais
cela a **quadruplé le coût de vérification** (3 passes de re-dérivation + 1 contrôle exhaustif des 211
références). Le même enseignement ressort de l'annexe M3 de DSH17.

### 🔁 Procédure de re-vérification (à rejouer si un blob a bougé)

```powershell
git hash-object CODE/M_MAIN/PRG_04_Treuils_Benne.st
```

```powershell
git hash-object CODE/M_MAIN/PRG_02_Acquisition.st
```

→ doivent rendre respectivement `31760d59b4e09b03a8e91b2358f8804a6b1985ad` et
`5b8baa9ba8ea0e9e0204ac8a5cc0a9a6b1bd2bb7`. Sinon, **les numéros `PRG_04:…` / `PRG_02:…` de ce document
ne sont plus valides** : rejouer `Select-String` sur les motifs cités (§2) avant toute conclusion.

**Contrôle exhaustif rejouable (le plus fort) — extrait les références du document et relit la ligne réelle :**

```powershell
Select-String -Path DOC\WFLOW\TROUBLESHOOTING\FICHES\TROUBLESHOOTING_TREUILS_JoystickContacteur_20260921.md -Pattern 'hash-object|blob' | Measure-Object
```

> 📌 Résultat du contrôle du `01:33:25` : **211 références explicites extraites du document, 211 relues
> sur le disque, 211 conformes, 0 hors-borne, 0 fichier introuvable.** C'est la mesure à reproduire pour
> valider AC2 après tout mouvement de dépôt.
