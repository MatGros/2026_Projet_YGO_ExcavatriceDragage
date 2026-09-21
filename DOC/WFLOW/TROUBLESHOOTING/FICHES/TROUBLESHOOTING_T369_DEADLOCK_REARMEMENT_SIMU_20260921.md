# 🕵️ Session de Troubleshooting — T369 : réarmement impossible en simulation (boucle armer → avortement)

> 📌 **Emplacement** : `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T369_DEADLOCK_REARMEMENT_SIMU_20260921.md`
> 📅 Date : 2026-09-21 · 🧊 Situation : **[SIMULATION BANC]** · 📄 Statut : **[RÉSOLUE]** (cause racine identifiée, **correctif non appliqué**)
> 🏷️ Acteur : DSH26 · 🔒 Verrou : T369 · Tâche : T369 (C2, **parent T364**) · Origine : reformulation du besoin T367

## 1. 🧊 Contexte figé (horodaté)

### Texte de contexte

L'exploitant, **2026-09-21**, en **simulation** :

> « je suis en simu mais même un défaut ne devrait pas me bloquer »
> « je ne peux pas réarmer, la séquence n'aboutit pas »

Deux messages relevés au bandeau (verbatim de l'exploitant) :

```text
[PUPITRE] Boucle urgence ouverte - réarmer
vHoming: Erreur ou Echec homing - Acquitter (Reset)
```

Ancrage : arbre de travail 2026-09-21T08:07→08:50. `CODE/` **non propre vs HEAD** (lots T364 et simulation en vol).
**Toutes les preuves ci-dessous ont été relues et vérifiées par l'orchestrateur sur source** (aucune preuve prise sur déclaration d'agent).

### Variables & valeurs (référencées)

| Élément | Référence complète | Valeur / rôle | Horodatage |
|---|---|---|---|
| Message 1 — chaîne ouverte | `FB_Hmi_BannerFormatter.st:643-644` (`IF NOT EmergencyChainClosed`) | `'[PUPITRE] Boucle urgence ouverte - réarmer'` | vérifié 08:50 |
| Message 2 — défaut homing | `FB_CycleMachineHoming.st:570` (branche `Fault.Latched`) | `'Erreur ou Echec homing - Acquitter (Reset)'` | vérifié 08:50 |
| Préfixe du message homing | `FB_Hmi_BannerFormatter.st:361` | `Banner.SequenceProgressText := CONCAT('Homing: ', MachineHomingInstruction)` → le code produit **`Homing: `**, **pas** `vHoming: ` | vérifié 08:52 |
| Bit de chaîne simulée | `GVL_Simulation.st:137` | `SimChainOk : BOOL := FALSE` | vérifié |
| Aiguillage chaîne | `FB_Sim_Safety.st:106` / `:124` | `ChainOpenReq := (NOT SimChainOkBit) OR BtnEmergencyStop OR TestCutActive OR PowerCutOffRequest` → `SimChainOk := NOT ChainOpen` | vérifié |
| Chaîne DI du banc | `FB_SimBench.st:689` | `Machine.EmergencyChainClosed_DI := instSimSafety.SimChainOk` | vérifié |
| Remise à zéro en sortie de sim | `PRG_02_Acquisition.st:96-121`, ligne **115** | `GVL_Simulation.SimChainOk := FALSE; // Chaîne AU ouverte à la ré-entrée (on n'a pas armé)` | vérifié |
| Ordre interne du socle défaut | `FB_FaultCore.st` §1 `:37-43` **avant** §3 `:60-69` | Reset efface les latches **puis** §3 les ré-arme **dans le même scan** | vérifié |
| Exigence de chaîne fermée à l'armement | `FB_Safety_EmergencyManagement.st:343-360` (**RESTORE_A**) et `:380-398` (**RESTORE_B**) | `IF EmergencyChainClosed OR BypassArmingPreconditions` sinon **abort** `CST_ABORT_TIMEOUT_RESTORE_A` **ou** `…_RESTORE_B` selon l'étape atteinte | vérifié 08:55 |
| Étape réellement atteinte (bypass RETAIN par défaut) | `GVL_BypassRetain.st:29` + `FB_Safety_EmergencyManagement.st:317-323` | `BypassAuRedundancyTestA := TRUE` par défaut ⇒ `IDLE → TEST_B` (TEST_A **et** RESTORE_A **sautés**) ⇒ l'abort tombe à **RESTORE_B** | vérifié 08:55 |
| Mapping matériel de la boucle AU | `TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv:476` / `:475` | `EmergencyChainClosed_DI` = **`%IX225.7`**, `PowerContactorEngaged_DI` = **`%IX225.6`**, **tous deux sur le nœud `VH_0800END`** — **pas** sur les E/S locales du CPU | vérifié |
| Disponibilité de ce nœud, modélisée par le code | `PRG_02_Acquisition.st:205` / `:216` | `Data.InputModules.Vh0800EndOk := VH_0800END.GetDeviceState() = RUNNING` → `Data.InputModules.Fault` — **le code admet donc des modules non prêts au démarrage** | vérifié |
| Message d'abandon latché | `FB_Hmi_BannerFormatter.st:502-506` | `AbortMsgLatched := … OR (LastAbortCause = CST_ABORT_TIMEOUT_RESTORE_A) OR (… = …_RESTORE_B) …` ; effacé seulement par Reset ou nouvelle séquence (`:509`) — **les deux étapes latchée** | vérifié |

## 2. 🎯 Symptôme

En simulation, **la séquence de réarmement AU n'aboutit jamais** : l'opérateur arme, la séquence avorte, un message lui demande de « vérifier puis réarmer » ; il réarme, la séquence avorte à nouveau. Il doit acquitter, réarmer, et n'obtient jamais l'état armé. Permanent et **déterministe**, reproductible à chaque tentative.

## 3. 🧩 Indices / historique

- **Message 1 est un symptôme, pas la cause** : `NOT EmergencyChainClosed` est la **conséquence** d'un banc dont la chaîne simulée est ouverte par défaut.
- **Message 2 (homing)** provient d'un latch du `FB_CycleMachineHoming`. ⚠️ **Le déclencheur envisagé au départ (frein non serré au banc) est RÉFUTÉ** : le banc force des retours conformes au repos (`FB_SimBench.st:445` frein appliqué, `:448-450` contacteurs retombés, `:690-691` `PhaseRotationOk_DI := TRUE` / `BrakeThermalOk_DI := TRUE`) ⇒ `MachineHomingMechanicalStopOk` = TRUE au repos.
- **`M3Locked` n'est pas alimenté par le latch** : `M3Locked := CycleRunning` (`FB_CycleMachineHoming.st:553`). Le latch bloque via `MachineHomed` (`:560-563`) → `FB_Modes` (expulsion SEMI_AUTO) et le cycle.
- **T364 NON COUPABLE** : `git show HEAD:CODE/G_CYCLE/FB_CycleMachineHoming.st` contient **déjà à l'identique** la garde `ResetEdge.Q AND WinchesMechanicallyStopped` (`:278`), le `ReHomingAckRequired := TRUE` (`:271`), `MachineHomed AND NOT Fault.Latched` (`:563`), `Ready` (`:628`) et le texte `'Erreur ou Echec homing - Acquitter (Reset)'` (`:570`). Le lot T364 est bien non commité (≈363+/607−) mais **n'introduit pas** cette condition.
- **Écart de libellé** : le code produit `Homing: ` (`banner:361`) — le `v` de `vHoming: ` **ne vient pas de ce chemin de code**. À confirmer par photo d'écran (le préfixe peut venir de la visu ou d'une concaténation amont).

## 4. 🌳 Arbre des causes & hypothèses

| # | Hypothèse | Variable de décision | Valeur attendue (source) | Valeur lue / établie | Verdict |
|---|---|---|---|---|---|
| H1 | Le frein/les contacteurs ne sont pas « au repos » au banc ⇒ Reset homing bloqué | `MachineHomingMechanicalStopOk` (`PRG_02:519-522`) | FALSE bloquerait | **TRUE au repos** — banc conforme (`FB_SimBench.st:445,448-450,690-691`) | ❌ **RÉFUTÉE** |
| H2 | Le lot T364 (homing, non commité) a introduit la condition d'acquittement | diff HEAD vs arbre | condition nouvelle | **absente** : identique dans `HEAD` | ❌ **RÉFUTÉE** |
| H3 | La chaîne AU simulée est **ouverte par défaut** et rien ne la ferme | `GVL_Simulation.SimChainOk` (`:137` = FALSE ; `PRG_02:115` = FALSE en sortie de sim) | chaîne fermée pour armer | **FALSE** ⇒ `EmergencyChainClosed_DI` = FALSE (`FB_SimBench:689`) | ✅ **CONFIRMÉE** |
| H4 | En simulation, la séquence d'armement **ne peut jamais refermer** la chaîne (le maintien PLC n'est pas modélisé) | `FB_Sim_Safety.st:106` | devrait inclure `PowerKeepAlive_A/B` comme le réel | `ChainOpenReq` ne dépend **que** du bit opérateur + EStop + TestCut + PowerCutOff ⇒ rien ne referme | ✅ **CONFIRMÉE** |
| H5 | Conséquence : l'armement avorte **systématiquement** à l'étape qui exige la chaîne fermée | `LastAbortCause` | — | **RESTORE_B** `CST_ABORT_TIMEOUT_RESTORE_B` (`:390-397`) si `BypassAuRedundancyTestA` = TRUE (**défaut RETAIN**), sinon **RESTORE_A** `CST_ABORT_TIMEOUT_RESTORE_A` (`:343-360`) | ✅ **CONFIRMÉE** (étape dépendante de la valeur RETAIN) |
| H6 | Le message d'abandon est **latché** ⇒ l'opérateur doit acquitter, et le cycle se répète | `AbortMsgLatched` (`banner:502-506`, effacé `:509`) | — | `CST_ABORT_TIMEOUT_RESTORE_A` **fait partie** des causes latchées | ✅ **CONFIRMÉE** |
| H7 | Acquitter « ne fait rien » même sur un latch légitime | ordre §1/§3 de `FB_FaultCore` | Reset doit effacer | Reset efface (`:41-43`) **puis** §3 ré-arme (`:63-69`) **dans le même scan** si la cause est encore `Active` | ✅ CONFIRMÉE — explique l'absence totale d'effet visible |
| H8 | Le défaut de homing serait la cause première | producteur du latch homing | — | ⚠️ conséquence d'un latch **à déclencheur non encore isolé** (voir §9) | ❓ **PARTIELLE** |
| H9 | **Besoin d'origine T367** (« 2ᵉ appui à la mise sous tension ») : un latch s'arme au **démarrage à froid** alors que sa cause a disparu | 61 causes latchées recensées (19 instances `FB_FaultCore`) | latch armé par un **artefact de boot** | 🥇 `FB_Safety_Winch` idx 1 `EncoderFaultLatched` M1+M2 (esclaves EtherCAT pas `RUNNING` aux 1ers scans) **et** 🥈 `StartupFail` AU (auto-test **mono-scan** : `FB_Safety_EmergencyManagement.st:177-185`) | ✅ candidats **PROUVÉS au niveau mécanisme**, franchissement **NON PROUVÉ** (à mesurer) |
| H10 | Le mapping matériel de la boucle AU expliquerait pourquoi elle est lue ouverte au tout premier scan | `Device_IO_20260918.csv:475-476` | — | `EmergencyChainClosed_DI` = **`%IX225.7`** et `PowerContactorEngaged_DI` = **`%IX225.6`**, **sur le nœud `VH_0800END`** (≠ E/S locales CPU) ; le code modélise lui-même l'indisponibilité de ce nœud (`PRG_02_Acquisition.st:205`, `:216`) | ✅ **CONFIRMÉE** (mapping) — lecture à 0 au scan 1 ❓ **NON PROUVÉE** |
| H11 | **Le message homing (`Fault.Latched`) vient d'un artefact de FENÊTRE DE BOOT, chaîné depuis la cohérence codeur au redémarrage** | `FB_CycleMachineHoming` cause 0 | cause armée sans action opérateur | Chaîne **vérifiée maillon par maillon par l'orchestrateur** : `FB_Encoder_Homing.st:181-187` (`Calib.Homed AND ABS(RawDiff) > tolérance` ⇒ `HomingSuspect := TRUE`, `BootIncoherentError := TRUE`, `Calib` **PERSISTANT** `GVL_PERSISTENT.st:10`) → `FB_Bucket.st:416-419` (`TonDatumUnreliable` `T#2s` ⇒ `BucketReferenced := FALSE`) → `PRG_02:562` (`BucketOffsetValid`) → `FB_CycleMachineHoming.st:265` (`MachineHomedRaw`) → `:267-271` (`MachineWasHomed` TRUE puis `MachineHomedRaw` FALSE ⇒ **`ReHomingAckRequired := TRUE`, INCONDITIONNEL**) → cause 0 latchée (`:320-321`) → bandeau `:570` | ✅ **mécanisme PROUVÉ** ; franchissement ❓ **NON PROUVÉ** (exige une transition `MachineHomedRaw` TRUE→FALSE) |

## 5. 📊 Arbre vertical des hypothèses (flux de données) — OBLIGATOIRE

```text
RÉARMEMENT EN SIMULATION — pourquoi la séquence n'aboutit pas ?

├── BRANCHE A — « la chaîne AU simulée est fermée ? »
│   ├── [GVL_Simulation.st:137]        SimChainOk : BOOL := FALSE          ✅ OUVERTE par défaut
│   ├── [PRG_02:115]                   := FALSE en sortie de sim (SimulationModeFall.Q) ✅
│   ├── [FB_SimBench.st:689]           EmergencyChainClosed_DI := SimChainOk ✅ FALSE
│   ├── [FB_Sim_Safety.st:106]         ChainOpenReq := NOT SimChainOkBit OR EStop OR TestCut OR PowerCutOff
│   │     └── ⛔ PowerKeepAlive_A/B ABSENTS  ➔ le maintien PLC ne referme JAMAIS la chaîne simulée
│   └── [banner:643-644]               '[PUPITRE] Boucle urgence ouverte - réarmer'  ✅ VERBATIM EXPLIQUÉ
│
├── BRANCHE B — « l'armement peut-il aboutir ? »
│   ├── [PRG_06:487]                   ArmRequest ← BtnEmergencyArming (front opérateur) ✅
│   ├── [GVL_BypassRetain.st:29]       BypassAuRedundancyTestA := TRUE (défaut RETAIN)
│   │     └── [FB_Safety_EmergencyManagement.st:317-323]  IDLE ➔ TEST_B (TEST_A + RESTORE_A SAUTÉS)
│   ├── [ :390-397] RESTORE_B : EmergencyChainClosed OR Bypass…  SINON ➔ abort CST_ABORT_TIMEOUT_RESTORE_B ❌
│   │     └── (si le bypass A est remis à FALSE : TEST_A ➔ RESTORE_A ➔ abort …_RESTORE_A, :343-360)
│   └── [ :299]                        la demande d'armement n'est PAS mémorisée (ArmReqEdge.Q AND Armable)
│
├── BRANCHE C — « pourquoi faut-il acquitter EN PLUS ? »
│   ├── [banner:502-504]               AbortMsgLatched := … OR TIMEOUT_RESTORE_A OR TIMEOUT_RESTORE_B ✅ LATCHÉ
│   ├── [banner:509]                   effacé seulement par Reset OU nouvelle séquence
│   └── [FB_FaultCore.st:37-43 vs :60-69]  Reset efface PUIS §3 ré-arme dans le MÊME scan
│         ➔ si la cause persiste, appuyer sur « Acquitter » n'a AUCUN effet visible  ❌
│
└── BRANCHE D — « le latch homing est-il la cause ? »
    ├── [FB_CycleMachineHoming.st:570] Fault.Latched ➔ 'Erreur ou Echec homing - Acquitter (Reset)' ✅ EXPLIQUÉ
    ├── [ :278] garde WinchesMechanicallyStopped — ⚠️ VRAIE au banc (H1 réfutée)
    ├── [git show HEAD] condition PRÉEXISTANTE (H2 réfutée : T364 non coupable)
    └── [déclencheur du latch] ❓ NON ISOLÉ — à instruire (voir §6 et §9)
```

**Résumé une ligne** : `[SimChainOk=FALSE] → [ChainOpenReq=1, maintien PLC non modélisé] → [ChainClosed_DI=0] → [abort RESTORE_B (ou A selon bypass RETAIN)] → [message latché] ⇒ boucle armer→avortement ❌`

## 6. 📊 Données / interactions & chronogramme (🟡)

### Lectures & essais (toutes en lecture seule, `fichier:ligne`)

- `GVL_Simulation.st:137` · `PRG_02_Acquisition.st:96-121` (bloc de sortie de simulation, ligne 115) · `FB_Sim_Safety.st:5-7,26,31,106,124,136` · `FB_SimBench.st:679,689,445,448-450,690-691`.
- `FB_Safety_EmergencyManagement.st:299` (front perdu si non `Armable`), `:343-360` (abort `RESTORE_A`), `:563-565` (`TestCutActive`).
- `FB_FaultCore.st:37-43` (§1 Reset) vs `:60-69` (§3 armement) — **ordre vérifié**.
- `FB_Hmi_BannerFormatter.st:361` (préfixe `Homing: `), `:502-506` et `:509` (latch/effacement du message d'abandon), `:643-644` (chaîne ouverte).
- `FB_CycleMachineHoming.st:278,286,320-321,553,560-563,570,628` ; `PRG_02_Acquisition.st:519-522,556`.
- `git show HEAD:CODE/G_CYCLE/FB_CycleMachineHoming.st` (**lecture seule**) → conditions identiques ⇒ H2 réfutée.

### Chronogramme (boucle observée/établie)

| Étape | `SimChainOkBit` | `EmergencyChainClosed_DI` | Séquence AU | `LastAbortCause` | Message bandeau |
|:---:|---:|---:|---|---|---|
| T0 — sim active, rien d'armé | 0 | 0 | IDLE | — | `[PUPITRE] Boucle urgence ouverte - réarmer` |
| T1 — opérateur appuie « Armer » | 0 | 0 | TEST_A → RESTORE_A | — | ⬆️ idem |
| T2 — RESTORE_A : chaîne exigée fermée | 0 | **0** | ➔ **abort** | `CST_ABORT_TIMEOUT_RESTORE_A` | message d'abandon **latché** |
| T3 — opérateur appuie « Acquitter » | 0 | 0 | purge → HX0/IDLE | cause **toujours active** | **le message revient (aucun effet)** |
| T4 — opérateur réarme | 0 | 0 | TEST_A → RESTORE_A | — | ➔ **retour T2 : boucle** |
| **T5 — sortie de boucle** | **1** (bit opérateur) | 1 | RESTORE_A passe | — | chaîne fermée ⇒ armement possible |

## 7. 🏁 Conclusion

- **Cause racine** : en simulation, **la chaîne AU ne peut pas être refermée par le PLC**. `GVL_Simulation.SimChainOk` est un **bit opérateur** initialisé à `FALSE` (`GVL_Simulation.st:137`) et remis à `FALSE` à la sortie de simulation (`PRG_02_Acquisition.st:115`) ; l'aiguillage `FB_Sim_Safety.st:106` **n'inclut pas le maintien PLC `PowerKeepAlive_A/B`** (choix documenté `:5-7`/`:26`/`:31-35`). Or **deux étapes** de la séquence d'armement exigent `EmergencyChainClosed` : `RESTORE_A` (`:343-360`) **et** `RESTORE_B` (`:380-398`). Avec le **défaut RETAIN** `BypassAuRedundancyTestA := TRUE` (`GVL_BypassRetain.st:29`), la séquence saute `TEST_A` + `RESTORE_A` (`:317-323`) et **avorte donc à `RESTORE_B`** ⇒ `CST_ABORT_TIMEOUT_RESTORE_B` ; si ce bypass est remis à `FALSE`, elle avorte à `RESTORE_A` (`CST_ABORT_TIMEOUT_RESTORE_A`). **Les deux causes latché le message d'abandon** (`banner:502-504`) ⇒ l'opérateur doit **acquitter** (`banner:509`) *et* **réarmer**, sans jamais aboutir.
- **⚠️ CORRECTION ASSUMÉE (2026-09-21T08:55)** : la première rédaction de cette fiche désignait `RESTORE_A` comme unique étape d'avortement. C'est **faux par défaut** : la valeur RETAIN `BypassAuRedundancyTestA = TRUE` déplace l'avortement à `RESTORE_B`. L'étape exacte dépend donc d'une **valeur RETAIN** — à relever (voir §9).
- **🚨 ALERTE SÉCURITÉ MACHINE, vérifiée par l'orchestrateur sur source, NON CORRIGÉE** : `CODE/L_SIMULATION/GVL_BypassRetain.st` est un `VAR_GLOBAL RETAIN` (survit au **Warm Restart**) qui livre **DEUX bypass d'ingénierie à `TRUE` par défaut** :
  - `:29` `BypassAuRedundancyTestA := TRUE` → **le test d'auto-test du canal A est SAUTÉ** (`TEST_A` + `RESTORE_A`), le canal A n'est plus qualifié par l'auto-test ; consommé `PRG_06_Outputs.st:496` ;
  - `:31` `BypassAuPowerCutOff := TRUE` → `CutOffActive := PowerCutOffRequest AND NOT BypassPowerCutOff AND NOT BypassArmingPreconditions` (`FB_Safety_EmergencyManagement.st:217`) ⇒ **le PLC ne fait plus chuter la chaîne AU sur une coupure métier** (le coup-de-poing physique reste dur) ; consommé `PRG_06_Outputs.st:498`.
  - Les deux sont commentés « 🛠️ BYPASS INGENIERIE AU — TRACE mise en service uniquement (jamais IHM, jamais production) · ⛔ NON SECURISE tant qu'actif » (`:24-26`), **mais livrés à `TRUE` dans un GVL RETAIN** : ils sont donc **actifs sur une machine neuve ou après effacement du RETAIN**, sans aucun affichage IHM dédié autre que le bandeau « BYPASS INGENIERIE MES ACTIF » qui ne couvre que `BypassArmingPreconditions/BypassRedundancyTest/BypassRedundancyTestA/B/BypassPowerCutOff` (`FB_Safety_EmergencyManagement.st:595-597` — à vérifier vis-à-vis de cette liste).
  - **Ce n'est PAS un artefact de démarrage et cela n'explique PAS la plainte de l'exploitant** — mais c'est une observation de **sécurité machine** qui doit être arbitrée par l'humain, jamais enterrée. **Signalé, non modifié, aucune proposition de correctif ici.**
  - ✅ **ARBITRAGE HUMAIN RENDU (2026-09-21T09:00), verbatim : « C'EST UN CHOIX ET CE N'EST PAS TON PÉRIMÈTRE ».**
    → Décision **assumée par l'exploitant**. Le sujet est **TRACÉ PUIS CLOS** : aucune tâche ouverte, aucun correctif, **ne pas rouvrir** cette alerte dans un lot ultérieur. Le devoir d'alerte est rempli (constat vérifié sur source + arbitrage explicite enregistré).
- **🧭 CONSTAT SYSTÉMIQUE (volet démarrage à froid de T367)** : le projet **sait déjà** éviter les faux défauts de démarrage — la doctrine existe, elle est **écrite et outillée**, et elle est **appliquée de façon incomplète**. C'est là que se trouve la cause du 2ᵉ appui.

  | Garde-fou anti-artefact **déjà présent** (vérifié sur source) | Preuve |
  |---|---|
  | Heartbeat IHM : commentaire littéral « boot propre sans alarme au scan 1 » | `FB_Diag_IhmHeartbeat.st:61-66` |
  | `BrakeTimeoutAck : BOOL := TRUE` (initialiseur explicite ⇒ pas de `NOT Ack`=TRUE au boot) | `FB_TranslationOutputInterlock.st:57` · `FB_WinchOutputInterlock.st:108` |
  | Warm-up 3 s : `TonStartupWarmup(IN := Enable, PT := T#3s)` neutralise les causes de perte de comm | `FB_Safety_Winch.st:219` (usage `:268`) · `FB_Safety_Translation.st:119` (usages `:122`, `:131`) |
  | `WinchStandstill` : « on n'ARME pas le latch Meca E … l'operateur doit pouvoir acquitter par Reset **sans que le defaut se re-pose** » | `FB_Safety_Winch.st:256-265, 394-398` |
  | `instBucket.ActiveOffsetSettled` : gate la synchro pendant le transitoire de recalage | `PRG_04_Treuils_Benne.st:635` · `FB_Bucket.st:315` |
  | Commentaire explicite « PAS sur `NOT HomedAndReliable` seul (peut n'être qu'un bus EtherCAT down au boot) … pas de faux positif pendant l'énumération EtherCAT » | `FB_Bucket.st:409-415` |
  | `FirstScanDone` du cycle machine (« statuts codeurs pas encore stables au boot ») | `FB_CycleMachineHoming.st:126` |

  **Ce qui a échappé à cette doctrine — et ce sont exactement les candidats du 2ᵉ appui** : `FB_Safety_Winch` idx 1/2/4/10 (`:277`, `:285`, `:302`, `:365` — latchs sur état de bus et **DI bruts**, sans aucune garde de validité, alors que la cause 0 juste à côté **est** protégée par `TonStartupWarmup`) ; `FB_Safety_Translation` idx 2/3 (`:140`, `:148` — idem, alors que les causes 0/1 sont protégées) ; `FB_Safety_EmergencyManagement` idx 3 `StartupFail` (auto-test **mono-scan** sans ré-évaluation) ; et les **deux gardes `FirstScanDone` structurellement inopérantes** (`FB_Safety_Winch.st:199-216` vs armement `:277` ; `FB_Safety_Translation.st:109-116` vs `:140` — RAZ **puis** ré-armement dans le **même scan**).
  ➡️ **Diagnostic en une phrase** : *le projet sait éviter les faux défauts de démarrage ; 5 causes latchées de la chaîne AU/treuils/translation ont échappé à cette doctrine, et ce sont elles qui imposent l'appui manuel supplémentaire.*
- **Fait neuf, artefact de boot NON latché (affecte les permis, pas l'acquittement)** : `FB_Translation_PositionDecoder.st:88` → `LimitSwitchMaintenance := (NOT Incoherent) AND (SensorsWord = 2#00000)` ; l'image des capteurs M3 (`VH_0808ETP`, `%IX224.x`) valant **0 avant `RUNNING`**, le décodeur conclut « extrême Maintenance confirmé » (`:25`) → `M3_LimitSwitchMaintenanceStable := TRUE` (`PRG_05_Translation.st:188-189`, maintenu jusqu'à une commande Trémie `:190-191`) ⇒ **au démarrage, M3 se déclare à l'extrémité « Maintenance » sans avoir bougé**, et cela pèse sur les permis de translation (`:491`, `:594`). ⚠️ Non latché ⇒ **ce n'est pas** la cause du 2ᵉ appui. À confirmer par mesure du mot capteurs réel au repos. Même famille que le reste : *une image d'E/S à 0 avant `RUNNING` est interprétée comme un état machine légitime.*
- **Nuance (cause non exerçable au banc)** : `FB_Translation` idx 3 `DriveFaultLatching` teste `DriveStatusWord.4` (`FB_Translation.st:104-106`) **sans garde** (ni `DriveOnline`, ni warm-up) ; or la sémantique du bit 4 du `StatusWord` AC600 est **non documentée** dans le projet et le banc n'écrit que `16#0087`/`16#0080` (`FB_SimBench.st:619-621`) ⇒ cette cause **n'est jamais déclenchée en essai banc** et n'est donc **pas validable en simulation**. ❓ **NON PROUVÉ** sur machine.
- **Aggravation vérifiée** : `FB_FaultCore` exécute l'effacement Reset (§1) **avant** l'armement des latches (§3) dans le **même scan** ⇒ tant que la cause est `Active`, **appuyer sur « Acquitter » n'a aucun effet, même pas un clignotement**.
- **Deux hypothèses réfutées** (elles étaient les plus intuitives) : le frein non serré au banc (H1) et la responsabilité du lot T364 (H2).
- **Statut** : RÉSOLUE sur la cause racine du blocage de réarmement. **Correctif non appliqué** (aucune ligne de `CODE/` écrite). Le déclencheur exact du **latch homing** (H8) reste à isoler.
- **Non démontré** : que `SimChainOkBit` soit effectivement à 0 *au moment de l'essai* de l'exploitant (déduction du défaut + de la remise à zéro documentée, **non observé en ligne**) — d'où le test décisif du §9.

## 8. 🛠️ Proposition de correction

> ⚠️ **Arbitrage humain rendu le 2026-09-21** : *le banc doit produire des retours RÉALISTES — **aucun bypass non sécurisé**, on ne contourne pas la vérification.*
> ⛔ Rien n'est appliqué ici : le périmètre appartient à d'autres acteurs (verrous ACTIFS).

- **Option 1 — RETENUE (correction du modèle de banc)** : faire que la chaîne **simulée** se referme comme la chaîne **réelle**, c'est-à-dire intégrer le maintien PLC (`PowerKeepAlive_A/B`) dans `ChainOpenReq` de `FB_Sim_Safety.st` (aujourd'hui explicitement exclu `:5-7`), afin qu'un armement complet puisse aboutir au banc sans bit opérateur.
  - Impact : le banc reproduit enfin le comportement terrain ; **aucune** modification de la chaîne de sécurité réelle ; **aucun** bypass.
  - Périmètre : `CODE/L_SIMULATION/FB_Sim_Safety.st` (+ `FB_SimBench.st` / `GVL_Simulation.st` si l'interface change).
  - ⚠️ **Détenteurs du verrou** : **T300 / DSH03** et **T328 / DSH03** (verrous **ACTIFS** sur `FB_SimBench.st` et `GVL_Simulation.st`) → le correctif doit être **remis à DSH03**, pas écrit par T369.
- **Option 2 (si l'option 1 est refusée)** : rendre le bit `SimChainOk` **accessible à l'IHM** (aujourd'hui **aucun mapping** `GVL_IHM` trouvé) pour que l'opérateur puisse fermer la chaîne simulée sans forçage CODESYS. Moins fidèle au réel, mais sans risque.
- **Option 3 — REJETÉE** : `BypassArmingPreconditions` (valide `RESTORE_A` sans chaîne fermée) — c'est un **bypass d'ingénierie NON SÉCURISÉ**, contraire à l'arbitrage humain.
- **⚠️ Validation requise** : [humaine] + [détenteur du verrou DSH03] — aucun code sans contrat conforme au périmètre de T300/T328.

## 9. ✅ Vérification de la correction / non-régression

> ⚠️ Hand-off humain. Aucun code n'a été modifié.

- **🔑 Test décisif en 1 minute (à faire par l'exploitant, avant tout correctif)** : forcer `GVL_Simulation.SimChainOk := TRUE` puis armer. Observer `PRG_06_Outputs.EmergencyDiag.LastAbortCause` :
  - s'il **cesse** d'être `CST_ABORT_TIMEOUT_RESTORE_A` **ou** `CST_ABORT_TIMEOUT_RESTORE_B` → **diagnostic clos** (H3-H6 confirmées) ;
  - s'il **reste** l'un des deux → une autre cause ouvre la chaîne, à instruire.
  - ⚠️ Ne pas présumer l'étape : par défaut (`BypassAuRedundancyTestA = TRUE`) l'avortement tombe à **`RESTORE_B`**.
- **Test complémentaire (relevés CODESYS, 2 minutes)** :
  - `GVL_BypassRetain.BypassAuRedundancyTestA` et `BypassAuPowerCutOff` (valeurs **RETAIN réelles** — déterminent l'étape d'avortement et les capacités de la chaîne) ;
  - `GVL_Simulation.SimChainOk`, `FB_Sim_Safety.ChainOpenReq`, `FB_Safety_EmergencyManagement.Status.State.ChainOk`, `…Diag.LastAbortCause` ;
  - **volet démarrage à froid (T367)** : `Data.InputModules.Vh0800EndOk` et `HwReal.Machine.EmergencyChainClosed_DI` / `PowerContactorEngaged_DI` aux **3 premiers scans** — c'est le seul fait manquant pour clore les candidats 🥇/🥈 ;
  - **volet candidat H11 (latch homing au boot, scans 2..N + 4 s)** : `PRG_02_Acquisition.instCycleMachineHoming.MachineHomedRaw`, `MachineWasHomed`, `instCauses[0].Active`, `instFault.Fault.LatchedId`, plus les **PERSISTENT** `GVL_PERSISTENT._CalibM1.Homed`, `_CalibM1.HomingSuspect`, `_BucketState.BucketReferenced` et `Data.EncoderM1/M2.HomedAndReliable` — **seul moyen de trancher H11** ;
  - **condition d'exclusion prouvée** : si le PERSISTENT est vierge (`Calib.Homed = FALSE` ou `HomingSuspect = TRUE` dès le départ), `MachineHomedRaw` ne peut jamais devenir TRUE ⇒ **aucune transition ⇒ pas d'armement** de la cause 0.
- **Après correctif (option 1)** : au banc, un cycle d'armement complet doit aboutir **sans** forçage ni bypass ; test CI de non-régression sur `FB_Sim_Safety` ; preuve CI **rouge avant** correctif ; `G200 --report` + bundle + palier C avec **delta 0 nouveau rouge**.
- **Isolation du latch homing (H8)** : relever `GVL_Troubleshooting.E_HomingM1/F_HomingM2` et `FB_CycleMachineHoming` (index de cause `LatchedId`) après un essai de homing — pour identifier laquelle des 9 causes latchées s'arme réellement.

## 10. 📝 Journal (chronologique)

- **2026-09-21 ~08:20** : l'exploitant signale l'impossibilité de réarmer en simulation et les 2 messages du bandeau.
- **2026-09-21T08:46** : création de **T369** (C2, parent T364) et prise du verrou DSH26 ; **diagnostic read-only** lancé (sous-agent), périmètre T364/AGY01 et T300-T328/DSH03 déclarés **intouchables**.
- **2026-09-21T08:50** : **vérification par l'orchestrateur** des maillons critiques sur source (`GVL_Simulation:137`, `FB_Sim_Safety:106/:124`, `FB_SimBench:689`, `PRG_02:115`, `FB_Safety_EmergencyManagement:343-360`, `FB_FaultCore:37-43/:60-69`, `banner:361/:502-506/:643-644`).
- **2026-09-21T08:50** : **H1 réfutée** (frein/contacteurs conformes au banc) ; **H2 réfutée** (`git show HEAD` : conditions préexistantes, **T364 non coupable**) ; **H3-H7 confirmées** ⇒ cause racine = chaîne simulée non refermable par le PLC + message d'abandon latché.
- **2026-09-21T08:50** : écart de libellé relevé — le code produit `Homing: ` (`banner:361`), **pas** `vHoming: ` ; à confirmer par photo d'écran.
- **En parallèle (même session, volet démarrage à froid de T367)** : énumération de **61 causes latchées** dans `CODE/**` (19 instances `FB_FaultCore`) — candidats **armables au démarrage à froid** : `FB_Safety_EmergencyManagement` idx 3 `StartupFail` ; `FB_Safety_Winch` idx 1 `EncoderFaultLatched` (M1 **et** M2, perte codeur EtherCAT au boot — mécanisme **prouvé 8/8 maillons**, franchissement **non prouvé**) ; idx 2 `MotorThermal` ; idx 4 `PhaseRotation` ; idx 10 `BrakeThermal` (entrées DI brutes, sans garde de validité) ; `FB_Encoder_Homing` idx 3 `BootIncoherentError` (effacé par `BtnConfirmCoherence`, **jamais** par `FaultMachineReset_IHM`) ; `FB_Brake` idx 0 ; `FB_Translation` idx 3 `DriveFaultLatching` (vrai défaut, à acquitter physiquement).
- **Alertes structurelles relevées (non corrigées, hors périmètre)** : (1) le garde-fou « premier scan » de `FB_Safety_Winch.st:199-216` est **structurellement inopérant** pour les causes armées plus bas dans le **même scan** (`:277`) — même constat `FB_Safety_Translation.st:109-116` vs `:140` ; (2) **asymétrie de doctrine** : perte d'un équipement de bus = **latchée** pour les codeurs treuil (`FB_Safety_Winch.st:277-281`) mais **live + warm-up 3 s** pour le variateur M3 (`FB_Safety_Translation.st:131-137`) et le bus joystick (`FB_Joystick.st:116,143`) ; (3) `AnyFaultActive` est construit sur les vues **LIVE**, pas latchées (`PRG_07_Supervision.st:587-597`) alors que son DUT annonce l'inverse (`ST_ModesState.st:7-10`) ; (4) `DivingRetryTrig` jamais mis à `TRUE` (`FB_CycleSemiAuto.st:228` seule affectation `:428 := FALSE`) ⇒ étape `AX_DIVING_RETRY` **inatteignable**.
- **À suivre** : test décisif §9 par l'exploitant → si confirmé, **remise du correctif à DSH03** (T300/T328) sous contrat C2 ; isolation du latch homing (H8).
- **2026-09-21T08:55 — volet matériel + ALERTE SÉCURITÉ** : relevé du mapping E/S sur la **source unique matérielle du projet** `TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv` (la version 20260826 citée par un sous-agent est **périmée** : elle vit dans `ARCHIVES/` et un worktree) → `EmergencyChainClosed_DI` **`%IX225.7`**, `PowerContactorEngaged_DI` **`%IX225.6`**, `PhaseRotationOk_DI` `%IX225.4`, `M1_M2_M3_BrakeThermalOk_DI` `%IX225.3`, `M3_BrakeIsOpen_DI` `%IX225.2` : **tous sur le nœud `VH_0800END`**, distinct des E/S locales → `StartupFail` **passe au rang de candidat 🥇 ex æquo** pour le besoin T367 (auto-test AU **mono-scan** lisant une image `%IX225.7` d'un module qui peut ne pas être `RUNNING`), et la famille « phases / thermique frein » est confirmée exposée à la même cause.
- **2026-09-21T08:55** : vérification par l'orchestrateur de `CODE/L_SIMULATION/GVL_BypassRetain.st` → **`BypassAuRedundancyTestA := TRUE` (`:29`) et `BypassAuPowerCutOff := TRUE` (`:31`) livrés par défaut dans un `VAR_GLOBAL RETAIN`**, consommés par `PRG_06_Outputs.st:496/:498`. **ALERTE SÉCURITÉ MACHINE** tracée au §7 — signalée, **non corrigée**, hors périmètre T369.
- **2026-09-21T08:55** : **correction de la fiche elle-même** — l'étape d'avortement n'est pas `RESTORE_A` par défaut mais **`RESTORE_B`** (`FB_Safety_EmergencyManagement.st:380-398`), le défaut RETAIN `BypassAuRedundancyTestA = TRUE` faisant sauter `TEST_A` + `RESTORE_A` (`:317-323`). Corrigé dans §1, §4 (H5), §5 et §7. *Leçon : une étape de séquence conditionnée par une valeur RETAIN ne peut pas être affirmée sans relever cette valeur.*
- **2026-09-21T08:55** : deux classements corrigés par recoupement des sous-agents — `FB_Safety_Winch` idx 8/idx 11 et `FB_Safety_Translation` idx 4 ne sont ni « exclus » ni « armables au boot » mais **conditionnels à un DI non conforme** (`M1_BrakeIsOpen_DI` `%IX225.0` sur `VH_0800END`, ou `M3_BrakeIsOpen_DI` `%IX225.2`) : **NON PROUVÉ** dans les deux sens.
- **2026-09-21T09:05 — addendum final (H11) intégré après vérification de l'orchestrateur** : le latch du homing (cause 0) peut s'armer **dans la fenêtre de boot** (scans 2..N), chaîné depuis la cohérence codeur au redémarrage : `HomingSuspect` (PERSISTANT) → `BucketReferenced := FALSE` après 2 s → `BucketOffsetValid` FALSE → transition `MachineHomedRaw` TRUE→FALSE → **`ReHomingAckRequired := TRUE` INCONDITIONNEL** (`FB_CycleMachineHoming.st:271`) → cause 0 latchée → bandeau `:570` (« Erreur ou Echec homing - Acquitter (Reset) »). **Percée décisive** : `ReHomingAckRequired` est posé **hors** du `IF NOT WinchesMechanicallyStopped` (`:268-270`) qui ne garde que `HomingLossLatched` ⇒ **l'arrêt mécanique ne protège pas l'armement**, il ne protège que l'effacement (`:278`) — ce qui explique pourquoi l'appui sur « Acquitter » peut rester sans effet. Les 3 maillons amont ont été **relus et confirmés sur source** (`FB_Encoder_Homing.st:181-187`, `FB_Bucket.st:416-419`, `PRG_02:562`).
  ⚠️ **Nuance de qualification** : contrairement aux candidats 🥇/🥈 (purs artefacts de disponibilité matérielle), la cause amont de H11 est un **événement physique réel** (tambour déplacé hors tension). Le latch y est donc **légitime** ; ce qui est discutable est l'**obligation d'un appui manuel** pour repartir — c'est un **arbitrage de doctrine/UX**, pas un bug de câblage. À trancher par l'humain, jamais par l'agent.
  ✅ **Recoupement fort avec l'observation** : c'est **le seul candidat dont le message de bandeau correspond mot pour mot** à celui relevé par l'exploitant (`Homing: Erreur ou Echec homing - Acquitter (Reset)`).
- **2026-09-21T09:05** : audit du volet latché **clos** — 61 causes latchées recensées, **100 % du périmètre** (19 instances `FB_FaultCore`, 63 sites `Latching := TRUE`).
- **2026-09-21T09:05** : alerte supplémentaire tracée (déjà consignée au §10) — `FB_CycleSemiAuto.st` : `DivingRetryTrig` déclaré `:228`, seule affectation `:428` (`:= FALSE`), seul test `:849` ⇒ état **`AX_DIVING_RETRY` inatteignable hors forçage**. **Signalé, non corrigé.**
- **2026-09-21T09:10 — clôture du volet latché et constat systémique** : les 7 garde-fous anti-artefact-de-boot cités par la note finale ont été **vérifiés sur source par l'orchestrateur** (`FB_Diag_IhmHeartbeat.st:61-66` « boot propre sans alarme au scan 1 », `TonStartupWarmup` `PT := T#3s` dans `FB_Safety_Winch.st:219` et `FB_Safety_Translation.st:119`, `BrakeTimeoutAck := TRUE`, `WinchStandstill` `FB_Safety_Winch.st:256-265`, `ActiveOffsetSettled`, commentaire `FB_Bucket.st:409-415`) ⇒ le constat systémique est **publié** au §7 : *la doctrine anti-artefact existe et est appliquée de façon incomplète ; ce sont les 5 causes qui y ont échappé qui imposent le 2ᵉ appui.*
- **2026-09-21T09:10** : fait neuf **vérifié** — `LimitSwitchMaintenance := (NOT Incoherent) AND (SensorsWord = 2#00000)` (`FB_Translation_PositionDecoder.st:88`) + maintien bistable `M3_LimitSwitchMaintenanceStable := TRUE` (`PRG_05:188-189`) ⇒ au boot, image capteurs M3 à 0 avant `RUNNING` ⇒ **M3 se déclare en extrême « Maintenance »** ; artefact **non latché** (pèse sur les permis, pas sur l'acquittement).
- **2026-09-21T09:10** : **audit clos** — périmètre **100 %** couvert (19 instances `FB_FaultCore`, 63 sites `Latching := TRUE`, 61 causes latchées), shortlist consolidée 🥇 `FB_Safety_Winch` idx 1 (codeurs) / 🥈 `StartupFail` / 🥉 idx 4-10 + Translation idx 2-3 (`%IX225.x`) / 4 `FB_CycleMachineHoming` idx 0 (fenêtre de boot) — **tous effacés par `BtnFaultReset`**. Il reste **une seule campagne de mesure humaine** pour trancher les 4.

---

📖 **Documentation complète** (comment remplir chaque section, exemples) : `GUIDE_Troubleshooting.md` (même dossier).
