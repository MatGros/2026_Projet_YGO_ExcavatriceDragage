# orchestrate run r-muci5e31-s9unsf

- mode: supervisor | agent: session-3cf1e901-98db-432f-be72-298fcfb8b4bf | provider: spawn
- concurrency: 4 | durationMs: 327098 | aborted: false
- startedAt: 2026-09-22T09:59:18.925Z | finishedAt: 2026-09-22T10:04:46.023Z

## Confirmer defaut MecaB (H1) [completed]

[structured] {"verdict_h1":"CONFIRME — En mode boutons MAINT_N2, JoystickYNeutral reste TRUE en permanence pendant une commande moteur par boutons. La condition MecaB (FB_Safety_Winch.st:341) devient donc TRUE des que le treuil est commande (contacteurs engages + frein ouvert) : le TON 3s s'ecoule et latche le faux positif bit8 = ErrorID 09.","preuve":["CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:341 : UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback); TonMecaB(IN:=UncommandedActiveB, PT:=PostRampTimeout); latch :343. La cause s'appuie sur la source de commande (geste joystick) et NON sur l'etat de commande reel.","CODE/M_MAIN/PRG_04_Treuils_Benne.st:955 : MovementCommanded := instWinchM1.RelayFwd OR instWinchM1.RelayRev — l'etat de commande REEL existe deja en entree (:19) mais n'est PAS utilise par MecaB.","CODE/M_MAIN/PRG_04_Treuils_Benne.st:961 (M1) et :1030 (M2) : JoystickYNeutral := (PRG_02_Acquisition.Data.Joystick.AxisY.Direction = 0) — mesure le GESTE PHYSIQUE du joystick, invisible aux boutons IHM.","CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM1.st:68-87 : IF NOT TglJoystickMaster THEN ... IHM.BtnAscentM1 / BtnDescentM1 / BothIntent — en boutons la commande vient des boutons, le joystick physique reste au neutre (Direction=0).","CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:329 : MecaA jumelle armee par l'etat PHYSIQUE (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback), PAS JoystickYNeutral — contraste prouvant l'incoherence de MecaB.","CODE/L_SIMULATION/FB_SimBench.st:113-114 : SimJoystickRawX/Y := 5000 (neutre par defaut) et :961 -> DirectionY=0 -> JoystickYNeutral=TRUE en mode boutons (joystick jamais touche).","Chaine faits : bouton appuye -> ReqAscent/ReqDescend -> contacteurs engages + frein ouvert -> JoystickYNeutral=TRUE, FwdRevSpeedFeedbackOff=FALSE -> NOT(...)=TRUE -> UncommandedActiveB=TRUE -> TON 3s -> MecaBFaultLatched=TRUE -> ErrorID bit8 09 '[M1] ErrorID:09 - MecaB - arret non confirme apres stop'."],"correctif_exact":"Code source: CODE/H_TREUILS_BENNE/FB_Safety_Winch.st, ligne 341. Remplacer le terme 'JoystickYNeutral' par 'NOT MovementCommanded' (etat de commande reel, independant de la source boutons/joystick) : AVANT (BUG) : UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback); APRES (CORRECTIF) : UncommandedActiveB := NOT MovementCommanded AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback); MovementCommanded = instWinchM1.RelayFwd OR instWinchM1.RelayRev (PRG_04:955) vaut TRUE des qu'un contacteur de sens est commande, quelle que soit l'origine (bouton/Both/joystick/cycle). Pendant une commande bouton : NOT MovementCommanded=FALSE -> MecaB desarmee (plus de faux positif). A l'arret sans commande avec contacteurs/frein non retombes : NOT MovementCommanded=TRUE -> MecaB reste vive (vrai 'arret non confirme'). Semantique preservee, lag 1 scan deja assume (PRG_04:924-925) et couvert par le TON 3s.","autres_usages_joystick_neutral":["FB_Safety_Winch.st:34 : declaration VAR_INPUT JoystickYNeutral — LAISSER, l'entree reste cablee (PRG_04:961/:1030) et continue d'etre lue.","FB_Safety_Winch.st:264 : WinchStandstill := FwdRevSpeedFeedbackOff AND NOT BrakeFeedback AND JoystickYNeutral AND NOT MovementCommanded AND (NOT MeasuredSpeedValid OR ABS<0.05) — utilise UNIQUEMENT pour desarmer l'armement MecaE (:394-395 'AND NOT WinchStandstill'). Predicat d'immobilite physique il inclut deja NOT MovementCommanded ; ne PAS toucher sous peine de modifier l'armement MecaE (non-regression inutile). Le correctif :341 ne casse rien : l'entree JoystickYNeutral reste consommee ici.","Aucune autre cause (A,C,D,E, encodage des erreurs) ne depend de la ligne 341 : le correctif est localise, bit8 MecaB uniquement."],"plan_test_rouge_vert":"Fichier : TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_safety_winch.st (pattern existant : 1 appel fb() = 1 scan, ADVANCE_TIME entre scans). ROUGE (avant fix, ce test FAIT) : Nouveau test 'TC-P10-0XX Meca B : PAS de faux positif pendant commande Both boutons IHM' — Scan1 regime nominal (JoystickYNeutral=TRUE, FwdRevSpeedFeedbackOff=TRUE, BrakeFeedback=FALSE) ; Scan2 commande bouton legitime (JoystickYNeutral=TRUE, FwdRevSpeedFeedbackOff=FALSE, BrakeFeedback=TRUE, ReqAscent=TRUE, MovementCommanded=TRUE) ; Scan3 apres ADVANCE_TIME(3000000000) idem. ASSERT_FALSE(fb.Fault.Error), ASSERT_FALSE(fb.SafeStop), ASSERT_FALSE(fb.PowerCutOff), ASSERT_FALSE(fb.ContactorStuck). Avant fix: JoystickYNeutral=TRUE + NOT(...)=TRUE -> UncommandedActiveB=TRUE -> latche apres 3s -> ASSERT_FALSE echouent (ROUGE). VERT (apres fix) : NOT MovementCommanded=FALSE -> TON jamais arme -> aucune assertion rouge (VERT). NON-REGRESSION : test existant TC-P10-002 (:127-155) 'non confirmation arret 3s -> SafeStop + PowerCutOff' (commande relâchee, joystick neutre, contacteurs non retombes) doit continuer de passer : la fix ne change pas ce vrai defaut. Reproduction simulation integree : MAINT_N2 + GVL_IHM.Modes.Cmd.TglJoystickMaster:=FALSE + GVL_IHM.Commun.BtnWinchBothAscent:=TRUE (Both, FB_WinchCmdArbitrationM1:70-74) ; joystick neutre par defaut (SimJoystickRawX/Y:=5000, FB_SimBench:113-114) -> DirectionY=0 -> JoystickYNeutral=TRUE ; M1RelayFwd=TRUE -> MovementCommanded=TRUE (PRG_04:955). Attendu avant fix : ErrorID:09 MecaB (~3s) ; apres fix : aucune MecaB, commande fluide."}
## 🔎 Rapport diagnostic — [M1] ErrorID:09 MecaB faux positif en mode boutons MAINT_N2

J'ai lu et vérifié la chaîne complète dans le code réel. **Hypothèse H1 CONFIRMÉE** par le câblage.

---

### 1) Verdict H1 — CONFIRMÉ ✅

En mode boutons MAINT_N2, **`JoystickYNeutral` reste TRUE en permanence pendant une commande moteur par boutons**, donc `UncommandedActiveB` devient TRUE dès que le treuil est commandé, et le TON 3s latche à tort.

| Preuve (fichier:ligne) | Contenu | Rôle dans la chaîne |
|---|---|---|
| `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:341` | `UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);` `TonMecaB(IN:=UncommandedActiveB, PT:=PostRampTimeout)` ; latche `:343` | La condition MecaB s'appuie sur **la source de commande (geste joystick)** au lieu de **l'état de commande réel** |
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st:955` | `MovementCommanded := instWinchM1.RelayFwd OR instWinchM1.RelayRev` | L'état de commande **réel** (déjà câblé, indépendant de la source) est disponible mais PAS utilisé par MecaB |
| `CODE/M_MAIN/PRG_04_Treuils_Benne.st:961` (M1) et `:1030` (M2) | `JoystickYNeutral := (PRG_02_Acquisition.Data.Joystick.AxisY.Direction = 0)` | Mesure le **geste physique du joystick**, invisible aux boutons IHM |
| `CODE/H_TREUILS_BENNE/FB_WinchCmdArbitrationM1.st:68-87` | `IF NOT TglJoystickMaster THEN ... IHM.BtnAscentM1 / BtnDescentM1 / BothIntent...` | En boutons, la commande vient des **boutons IHM** ; le joystick physique reste au neutre (`Direction=0`) |
| `CODE/H_TREUILS_BENNE/FB_Safety_Winch.st:329` | MecaA jumelle armée par `FwdRevSpeedFeedbackOff AND NOT BrakeFeedback` (état **physique**), **PAS** `JoystickYNeutral` | Contraste prouvant que MecaB est incohérent avec sa jumelle |

**Chaîne du faux positif** pendant une commande bouton légitime :
- Bouton appuyé → `ReqAscent/ReqDescend` → contacteurs engagés + frein ouvert.
- `JoystickYNeutral = TRUE` (joystick jamais touché en mode boutons).
- `FwdRevSpeedFeedbackOff = FALSE` (contacteurs engagés) → `(FwdRevSpeedFeedbackOff AND NOT BrakeFeedback) = FALSE` → `NOT(…) = TRUE`.
- → `UncommandedActiveB = TRUE ∧ TRUE ∧ TRUE = TRUE` → TON s'écoule 3s → `MecaBFaultLatched := TRUE` → **`ErrorID bit8 = 09`** (libellé `[M1] ErrorID:09 - MecaB - arret non confirme apres stop`).
- C'est bien la **déclaration d'un arrêt « non confirmé » alors qu'aucun arrêt n'était demandé** : faux positif.

---

### 2) Correctif exact — `FB_Safety_Winch.st:341`

Remplacer le terme **`JoystickYNeutral`** par **`NOT MovementCommanded`** (état de commande réel, indépendant de la source boutons/joystick) :

```st
// AVANT  (BUG)
UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);

// APRÈS  (CORRECTIF)
UncommandedActiveB := NOT MovementCommanded AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback);
```

- **`MovementCommanded`** (`:19`, câblé `PRG_04:955` = `instWinchM1.RelayFwd OR instWinchM1.RelayRev`) vaut **TRUE dès qu'un contacteur de sens est commandé** quelle que soit l'origine (bouton IHM, Both, joystick, cycle). Pendant une commande bouton → `NOT MovementCommanded = FALSE` → MecaB **désarmée**. À l'arrêt réel sans commande, si contacteurs/frein ne retombent pas → `NOT MovementCommanded=TRUE` → MecaB redevient vive. **Sémantique préservée** : « arrêt demandé mais non confirmé ».
- Lag 1 scan déjà assumé/documenté pour `MovementCommanded` (`PRG_04:924-925`) et couvert par le TON 3s — sans impact.
- Cohérent avec l'usage déjà existant de `MovementCommanded` dans `WinchStandstill` (`:264`) et MecaA/jumelle `:329` (état physique).

---

### 3) Autres usages de `JoystickYNeutral` dans `FB_Safety_Winch` (ne rien casser)

| Ligne | Usage | Action |
|---|---|---|
| `:34` | Déclaration `VAR_INPUT` | **Laisser** — l'entrée reste câblée (`PRG_04:961/:1030`) |
| `:264` | `WinchStandstill` : `FwdRevSpeedFeedbackOff AND NOT BrakeFeedback AND JoystickYNeutral AND NOT MovementCommanded AND (vitesse~0)` — **ne sert qu'à désarmer MecaE** (:394-395 `AND NOT WinchStandstill`) aux treuils réellement à l'arrêt | **Ne PAS toucher** : c'est un prédicat d'immobilité **physique**, il inclut déjà `NOT MovementCommanded` ; il n'intervient pas dans MecaB. Le modifier changerait l'armement MecaE (risque de non-régression inutile). |
| `:341` | MecaB (cause bit8) | **À corriger** (voir §2) |

→ Le correctif `:341` ne casse **rien** : l'entrée `JoystickYNeutral` reste utilisée par `:264`, aucune autre cause (A→E) ne dépend de `:341`.

---

### 4) Plan test CI — ROUGE avant / VERT après (mode boutons MAINT_N2)

Fichier cible : `TOOLS/TEST_AUTO_CI/RESULTS/H_TREUILS_BENNE/tests/test_fb_safety_winch.st` (même pattern que les TCs existants : 1 appel `fb()` = 1 scan, `ADVANCE_TIME(…)` entre scans).

**🔴 Nouveau test (reproducteur du bug — doit ÉCHOIR avant fix, passer après) :**

```st
TEST 'TC-P10-0XX Meca B : PAS de faux positif pendant commande Both boutons IHM'
    (* Mode boutons MAINT_N2 : joystick jamais touche (JoystickYNeutral=TRUE),
       commande legitime par boutons/Both -> contacteurs engages + frein ouvert. *)
    (* Scan 1 : regime nominal *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := TRUE, BrakeFeedback := FALSE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5);
    ADVANCE_TIME(10000000);
    (* Scan 2 : BOUTON BOTH ACTIF -> joystick neutre mais commande reelle engagee *)
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := FALSE, BrakeFeedback := TRUE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5,
       ReqAscent := TRUE, ReqDescend := FALSE, MovementCommanded := TRUE);
    ASSERT_FALSE(fb.SafeStop,    'commande bouton legitime : pas de SafeStop');
    ASSERT_FALSE(fb.PowerCutOff, 'commande bouton legitime : pas de PowerCutOff');
    ASSERT_FALSE(fb.ContactorStuck, 'commande bouton legitime : pas de contacteur colle');
    (* Scan 3 : apres PostRampTimeout=3s, la commande bouton LEGITIME ne doit PAS latcher *)
    ADVANCE_TIME(3000000000);
    fb(Enable := TRUE, Reset := FALSE, SyncEnable := FALSE,
       PowerContactorEngaged := TRUE, JoystickOnline := TRUE, JoystickOperational := TRUE,
       HeartbeatIhmOk := TRUE, EncoderAvailable := TRUE, PhaseRotationOk := TRUE,
       TopPositionSensor := TRUE, FwdRevSpeedFeedbackOff := FALSE, BrakeFeedback := TRUE,
       JoystickYNeutral := TRUE, BenneHoldStillActive := FALSE, InReferencingMode := FALSE,
       CablePosM := 0.0, CfgCableLimitDescentM := -20.0, Homed := TRUE, TopLimitM := 8.5,
       ReqAscent := TRUE, ReqDescend := FALSE, MovementCommanded := TRUE);
    ASSERT_FALSE(fb.Fault.Error, 'commande bouton legitime apres 3s : PAS d erreur MecaB');
    ASSERT_FALSE(fb.PowerCutOff, 'commande bouton legitime apres 3s : PAS de PowerCutOff');
END_TEST
```

- **ROUGE (avant fix)** : `fb.Fault.Error`, `SafeStop` et `PowerCutOff` passent à TRUE à Scan 3 car `JoystickYNeutral=TRUE` + frein ouvert → `UncommandedActiveB=TRUE` → latch MecaB. Assertions `ASSERT_FALSE` **échouent**.
- **VERT (après fix)** : `NOT MovementCommanded=FALSE` → TON jamais armé → aucune assertion ROUGE. Passe.

**🟢 Test de non-régression (déjà présent, doit continuer de passer) — `TC-P10-002` `:127-155` :**
Commande relâchée (`MovementCommanded` non posé), joystick neutre, contacteurs **non** retombés 3s → MecaB doit toujours latcher (vrai « arrêt non confirmé »). La fix ne change pas ce cas.

**✅ Reproduction simulation intégrée (mode boutons MAINT_N2) :**
- `GVL_IHM.Modes.Cmd.TglJoystickMaster := FALSE` (ST_ModesCmd:18), mode MAINT_N2.
- Commande `GVL_IHM.Commun.BtnWinchBothAscent := TRUE` (Both) → `FB_WinchCmdArbitrationM1:70-74`, `ReqAscent=TRUE`.
- `FB_SimBench` joystick neutre par défaut (`SimJoystickRawX/Y := 5000`, FB_SimBench:113-114) → `Joystick.AxisY.Direction=0` → `JoystickYNeutral=TRUE`.
- `M1RelayFwd=TRUE` → `instWinchM1.RelayFwd=TRUE` → `MovementCommanded=TRUE` (`PRG_04:955`).
- Résultat attendu avant fix : **ErrorID:09 MecaB** (~3s). Résultat attendu après fix : **aucun MecaB**, commande fluide.

---

**Récapitulatif** : H1 **confirmé** — `JoystickYNeutral` = TRUE en permanence en mode boutons, condition MecaB (`FB_Safety_Winch.st:341`) déclenchée à tort pendant une commande légitime → latch bit8 `ErrorID 09`. Correctif unique : `JoystickYNeutral` → **`NOT MovementCommanded`** sur la seule ligne `:341`. Aucune autre cause affectée (ligne `:264` `WinchStandstill` utilisée uniquement pour armer MecaE, à laisser intacte). Le nouveau test CI ci-dessus reproduit le bug (ROUGE avant / VERT après), le `TC-P10-002` existant garantit la non-régression du vrai défaut d'arrêt.

## Fidelite simu contacteurs/frein (H2) [completed]

[structured] {"verdict_h2":"H2 REJETÉE (infirmée) pour le modèle FB_SimBench. Sous la config effective (SimWinchDynamicsActive=FALSE, GVL_Simulation.st:100), les deux retours M1_ContactorsReleased_DI (FB_SimBench.st:449-451, combinatoire, 0 s) et M1_BrakeIsOpen_DI (FB_SimBench.st:446 via M1_BrakeIsOpenState + branche fermeture FB:437-445, délai effectif WinchBrakeCloseDelayEffectiveS=0.0 car SEL(SimWinchDynamicsActive,0.0,CloseDelayS) retourne 0.0) basculent au même scan (~0-10 ms) qu'une commande d'arrêt correcte. Si SimWinchDynamicsActive=TRUE, la fermeture frein devient 0.09 s (9 scans) : toujours <1 s. Le modèle est FIDÈLE : il ne fait que refléter la commande post-interlock PRG_06_Outputs.Data.* (décision documentée FB_SimBench.st:312-315), et M1_BrakeCmd = M1RelayFwd OR M1RelayRev (PRG_06_Outputs.st:261). Un état figé observé est donc un défaut AMONT (commande qui ne retombe pas), pas un bug de simulation.","delais_effectifs":"M1_ContactorsReleased_DI : 0 s (combinatoire, même scan que la retombée des relais/paliers). M1_BrakeIsOpen_DI : config par défaut => 0.0 s effectif => fermeture à 0-10 ms; si SimWinchDynamicsActive=TRUE => 0.09 s (9 scans à 10 ms). Les deux restent largement <1 s. Aucun timer ne retarde au-delà de la commande dans la config livrée.","cas_etat_bloque_3s":"Aucun cas intrinsèque au modèle/timer/retard : à commande correcte (Relay*=0, SpeedContactor*=0, BrakeCmd=0) les 2 retours basculent <10 ms. Cas >3 s possibles, tous hors bug FB_SimBench : (1) Commande amont qui ne tombe pas — PRG_06_Outputs.Data.M1RelayFwd/Rev ou un M1SpeedContactor1..4 reste à 1 (interlock/sequence amont) => ContactorsReleased_DI reste FALSE >3 s (fidèlement reflété). (2) Config utilisateur: SimWinchDynamicsActive=TRUE et SimWinchBrakeCloseDelayS>3 s => fermeture frein retardée de X s (défaut 0.09 s, non concerné). (3) Repli Enable=FALSE (FB:258-271): si SimulationModeActive retombe, sortie = HwReal.Winch (image réelle possiblement périmée). Aucun de ces cas n'est imputable à FB_SimBench.","liste_trace_10ms":["PRG_06_Outputs.Data.M1RelayFwd","PRG_06_Outputs.Data.M1RelayRev","PRG_06_Outputs.Data.M1SpeedContactor1","PRG_06_Outputs.Data.M1SpeedContactor2","PRG_06_Outputs.Data.M1SpeedContactor3","PRG_06_Outputs.Data.M1SpeedContactor4","PRG_06_Outputs.Data.M1BrakeCmd","PRG_02_Acquisition.instSimBench.Winch.M1_ContactorsReleased_DI","PRG_02_Acquisition.instSimBench.Winch.M1_BrakeIsOpen_DI","PRG_02_Acquisition.HwSim.Winch.M1_ContactorsReleased_DI","PRG_02_Acquisition.HwSim.Winch.M1_BrakeIsOpen_DI","PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI","PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI","PRG_02_Acquisition.instSimBench.M1_BrakeIsOpenState","PRG_02_Acquisition.instSimBench.M1_BrakeCloseTimerS","PRG_02_Acquisition.instSimBench.M1_BrakeOpenTimerS","PRG_02_Acquisition.instSimBench.WinchBrakeCloseDelayEffectiveS","GVL_Simulation.SimulationModeActive","GVL_Simulation.SimWinchDynamicsActive","GVL_Simulation.SimWinchBrakeOpenDelayS","GVL_Simulation.SimWinchBrakeCloseDelayS","PRG_02_Acquisition.instSimBench.Winch.M2_ContactorsReleased_DI","PRG_02_Acquisition.instSimBench.Winch.M2_BrakeIsOpen_DI"]}
Analyse terminée — lecture seule, aucun fichier modifié.

## Constat principal

**FB_SimBench n'est PAS à l'origine d'un état figé.** Les deux retours sont soit purement combinatoires, soit pilotés par des timers court-circuités par la config effective. Le modèle est **fidèle** : il réfléchit la commande post-interlock `PRG_06_Outputs.Data.*` (décision explicitement documentée aux lignes 312-315), pas la consigne brute.

Détail des calculs vérifiés :

| Retour | Mécanisme | Délai effectif | Bascule à un stop |
|---|---|---|---|
| `Winch.M1_ContactorsReleased_DI` (FB:449-451) | Combinatoire `NOT(RelayFwd∨RelayRev∨SC1..4)` | **0 s** (aucun timer) | même scan |
| `Winch.M1_BrakeIsOpen_DI` (FB:446) | `M1_BrakeIsOpenState` + timer fermeture (FB:437-445) via `WinchBrakeCloseDelayEffectiveS` (FB:296) = `SEL(SimWinchDynamicsActive, 0.0, CloseDelayS)` | `SimWinchDynamicsActive=FALSE` (GVL:100) → **0.0 s** → même scan ; si TRUE → 0.09 s | même scan (≤0.09 s) |

Le `SEL(cond, 0.0, delay)` : `cond` est `SimWinchDynamicsActive`. Config par défaut `FALSE` → le délai de fermeture retenu est **0.0**, donc le branche de fermeture (FB:439 : `timer >= MAX(0,0.0)` toujours vrai) se déclenche au scan où `M1_BrakeCmd` retombe. Toujours **< 1 s** dans les deux variantes.

`M1_BrakeCmd` suit les relais : `M1BrakeCmd := M1RelayFwd OR M1RelayRev` (PRG_06:261, 307) → au stop tout retombe en cohérence.

## Cas > 3 s

Aucun bug intrinsèque (modèle, timer, retard) ne fige ces états : à **commande correcte** (`Relay*=0`, `SC*=0`, `BrakeCmd=0`), les 2 retours basculent dans l'heure. Les seuls scénarios > 3 s sont :

1. **Commande amont qui ne tombe pas** (catégorie 2 de la consigne) — le plus probable : `M1RelayFwd/Rev` ou un `M1SpeedContactor*` reste à 1 dans `PRG_06_Outputs.Data.*` → `ContactorsReleased_DI` reste FALSE > 3 s. La simu le **miroite fidèlement**, ce n'est pas un bug FB_SimBench.
2. **Config utilisateur** : `SimWinchDynamicsActive=TRUE` + `SimWinchBrakeCloseDelayS > 3 s` → fermeture retardée de X s. Défaut 0.09 s → non concerné.
3. **Repli Enable=FALSE** (FB:258-271) : si `SimulationModeActive` retombe, sortie = `HwReal.Winch` (image réelle, possiblement périmée) ; hors scénario simu nominal.

## Trace 10 ms

Chemins CODESYS (`PRG_02_Acquisition.instSimBench…` — préfixer du conteneur de tâche : `<App>.<Task>.<PRG_02_Acquisition instance>.…` ; `HwSim`/`HwIn` se lisent de même sur `PRG_02_Acquisition.`) :

- Commandes (entrées sim) : `PRG_06_Outputs.Data.M1RelayFwd`, `.M1RelayRev`, `.M1SpeedContactor1..4`, `.M1BrakeCmd`
- Sorties modèle : `PRG_02_Acquisition.instSimBench.Winch.M1_ContactorsReleased_DI`, `.M1_BrakeIsOpen_DI`
- Image publiée : `PRG_02_Acquisition.HwSim.Winch.M1_ContactorsReleased_DI`, `.M1_BrakeIsOpen_DI`
- Valeur réellement consommée par le métier : `PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI`, `.M1_BrakeIsOpen_DI`
- Internes modèle (pour distinguer timer vs commande) : `instSimBench.M1_BrakeIsOpenState`, `.M1_BrakeCloseTimerS`, `.M1_BrakeOpenTimerS`, `.WinchBrakeCloseDelayEffectiveS`
- Config/stimuli : `GVL_Simulation.SimWinchDynamicsActive`, `.SimulationModeActive`, `.SimWinchBrakeOpenDelayS`, `.SimWinchBrakeCloseDelayS`
- Parité M2 (même mécanique) : `instSimBench.Winch.M2_ContactorsReleased_DI`, `.M2_BrakeIsOpen_DI`

Lecture : comparer front de retombée `M1RelayFwd+SC*`/`M1BrakeCmd` → front de `M1_ContactorsReleased_DI`/`M1_BrakeIsOpen_DI`. Si les commandes retombent mais pas les retours → bug sim ; si les commandes restent à 1 → défaut amont, pas FB_SimBench.

Rapport structuré :

## Rediger contrat C4 MecaB fix [completed]

[structured] {"contract_yaml":"# ═══════════════════════════════════════════════════════════════════════════\n# CONTRAT DE TACHE ET SUIVI DE CYCLE DE VIE — projet Excavatrice Dragage\n# ═══════════════════════════════════════════════════════════════════════════\n# T4-C4 — FB_Safety_Winch : confirmation d'arret MecaB independante de la\n# source de commande (remplacer JoystickYNeutral par NOT MovementCommanded)\n#\n# Contexte (faux positif) : en mode boutons MAINT_N2, la simulation produit un\n# faux [M1] ErrorID:09 MecaB car le critere s'appuie sur JoystickYNeutral,\n# TOUJOURS TRUE en mode boutons (joystick non sollicite), au lieu de reposer\n# sur MovementCommanded (source reelle de la commande de mouvement).\n#\n# Validation  : python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py <fichier>\n# ═══════════════════════════════════════════════════════════════════════════\n\ncontract:\n  task_id: T4_C4_FB_SafetyWinch_MecaB_MovementCommanded\n  criticality: C4            # FB de securite — criticite maximale\n  strategy: patch            # correctif cible ; pas de rebuild\n\n  objective: >\n    Rendre la confirmation d'arret mecanique MecaB de FB_Safety_Winch\n    independante de la source de commande, en remplacant le critere\n    JoystickYNeutral par NOT MovementCommanded, de sorte qu'en mode boutons\n    MAINT_N2 (ou tout autre mode hors joystick) un arret commande ne genere\n    plus de faux [M1] ErrorID:09 MecaB, tout en conservant la detection de\n    mouvement non commande dans les modes joystick.\n\n  acceptance:\n    - id: AC1\n      statement: >\n        En mode boutons MAINT_N2 de simulation, le faux [M1] ErrorID:09 MecaB\n        se reproduit en ROUGE sur le bundle AVANT correction (etat de reference),\n        confirmant que le critere JoystickYNeutral (toujours TRUE hors joystick)\n        declenche la cause a tort.\n      verified_by: >\n        Lancement du test CI FB_Safety_Winch (test_fb_safety_winch.st) sur le\n        bundle avant modification : la cause MecaB/bit ErrorID:09 retourne FAIL\n        en configuration mode boutons MAINT_N2.\n    - id: AC2\n      statement: >\n        Apres remplacement de JoystickYNeutral par NOT MovementCommanded dans\n        FB_Safety_Winch, le meme scenario mode boutons MAINT_N2 passe au VERT :\n        aucun faux [M1] ErrorID:09 MecaB n'est emis lorsque la commande de\n        mouvement est absente.\n      verified_by: >\n        Re-lancement du test CI FB_Safety_Winch apres modification : le critere\n        MecaB/bit ErrorID:09 retourne PASS en mode boutons MAINT_N2.\n    - id: AC3\n      statement: >\n        La confirmation d'arret mecanique MecaB devient fonction de la seule\n        absence de commande de mouvement : MecaB est vrai quand MovementCommanded\n        est FALSE, quel que soit l'etat du joystick, et reste vrai quand\n        MovementCommanded est TRUE, sans elargir le declenchement.\n      verified_by: >\n        Test CI FB_Safety_Winch : matrice MovementCommanded x JoystickYNeutral,\n        le bit MecaB correspond exactement a NOT MovementCommanded sur chaque ligne.\n    - id: AC4\n      statement: >\n        Non-regression : les autres causes mecaniques de FB_Safety_Winch\n        (MecaA et toutes les autres causes du masque) conservent un comportement\n        identique avant/apres, sur la suite de tests FB_Safety_Winch existante.\n      verified_by: >\n        Diff des resultats de test CI FB_Safety_Winch avant/après modification :\n        seules les lignes du critere MecaB changent, toutes les autres causes\n        conservent leur verdict de reference.\n    - id: AC5\n      statement: >\n        Aucun changement de comportement de PostRampTimeout et aucune\n        modification de la logique d'escalade SafeStop / PowerCutOff : ces\n        zones restent hors scope et hors diff.\n      verified_by: >\n        `git diff` du lot : seul CODE/H_TREUILS_BENNE/FB_Safety_Winch.st et le\n        test CI associe sont modifies ; aucun commit ne touche PostRampTimeout\n        ni les branches SafeStop / PowerCutOff.\n    - id: AC6\n      statement: >\n        Criteres structurels verifies : le nom de chaque fichier est egal au\n        nom du POU ; et le suffixe de fichier est egal au langage genere dans le\n        bundle.\n      verified_by: >\n        Gate structurel (G310) + generate_codesys_bundle.py : FB_Safety_Winch.st\n        nomme le POU FB_Safety_Winch et porte le suffixe .st correspondant au\n        langage ST genere dans CODE_XML/CODE_Bundle.xml.\n    - id: AC7\n      statement: >\n        Le lot est pret pour integration CODESYS : bundle complet regenere et\n        valide, liaison provee, gates palier C au vert et diff bundle cible.\n      verified_by: >\n        generate_codesys_bundle.py . ; G200_check_linkage.py --report (PASS) ;\n        run_all_gates.py --palier C (15/15) ; generate_codesys_diff_bundle.py\n        . CODE/H_TREUILS_BENNE/FB_Safety_Winch.st (Code_DiffBundle.xml avec\n        l'objet FB_Safety_Winch).\n\n  scope:\n    allowed:\n      - CODE/H_TREUILS_BENNE/FB_Safety_Winch.st\n      - TOOLS/TEST_AUTO_CI/H_TREUILS_BENNE/tests/test_fb_safety_winch.st\n      - DOC/AF/AF_Partie-10 (note d'application du correctif si besoin)\n      - CODE_XML/CODE_Bundle.xml          # bundle complet regenere\n      - CODE_XML/CODE_DiffBundle.xml      # diff bundle cible FB_Safety_Winch\n      - CONTRACTS/ (contrat de tache C4)\n      - DOC/WFLOW/TASKS.yaml              # suivi statut de la tache\n    forbidden:\n      - PRJ_CODESYS/project/Device.export\n      - logique PostRampTimeout\n      - logique d'escalade SafeStop / PowerCutOff\n      - tous autres FB de securite (hors FB_Safety_Winch)\n      - GVL_IHM\n      - GVL_PERSISTENT\n\n  conservation:\n    must_survive:\n      - \"Detection de mouvement non commande (UncommandedActive) en mode joystick\"\n      - \"Confirmation d'arret mecanique MecaB uniquement sur arret reel (NOT MovementCommanded)\"\n      - \"Toutes les autres causes du masque (MecaA et autres) et leurs seuils\"\n      - \"Aucun affaiblissement de la chaine SafeStop / PowerCutOff\"\n    dropped_on_purpose:\n      - \"JoystickYNeutral comme critere de confirmation d'arret MecaB (cause du faux positif)\"\n\n  evidence_required:\n    - check_linkage          # G200_check_linkage.py --report (PASS, 0 erreur)\n    - run_all_gates          # run_all_gates.py --palier C (15/15 PASS)\n    - bundle                 # CODE_XML/CODE_Bundle.xml regenere et valide\n    - diff_bundle            # CODE_XML/CODE_DiffBundle.xml (objet FB_Safety_Winch)\n    - test_rouge_vert        # test CI FB_Safety_Winch : ROUGE avant / VERT apres\n\n  models_allowed:\n    - \"deepseek-v4-flash:cloud\"\n    - \"omni/cc/claude-sonnet-5\"\n\n  alert_duty: >\n    FB de securite : ne JAMAIS affaiblir le critere de confirmation d'arret ni\n    la chaine de securite. Le test ROUGE/VERT (MecaB, mode boutons MAINT_N2) est\n    obligatoire avant et apres le correctif. Toute derive, incoherence de spec\n    (AF-10), ou risque hors scope constate est remonte IMMEDIATEMENT a\n    l'orchestrateur, pas a la fin et jamais silencieusement. Signaler n'est pas\n    elargir le scope.\n\n# ═══════════════════════════════════════════════════════════════════════════\n# 🚦 SUIVI DE L'ETAT D'AVANCEMENT & LISEUR HUMAIN (Où on en est)\n# ═══════════════════════════════════════════════════════════════════════════\nstatus: PENDING               # PENDING (attente) | IN_PROGRESS (cours) | COMPLETED (fait agent) | VALIDATED (validé)\n\nexecution:\n  executed_by: \"DSH01\"\n  completed_at: \"\"\n  status: PENDING            # PENDING | COMPLETED | BLOCKED | ALERT_RAISED\n  summary: >\n    En attente d'execution. Correctif : remplacer JoystickYNeutral par\n    NOT MovementCommanded dans le critere de confirmation d'arret MecaB de\n    FB_Safety_Winch, puis ROUGE/VERT en mode boutons MAINT_N2.\n  evidence_submitted: []\n\nvalidation:\n  status: PENDING            # PENDING | APPROVED | REJECTED\n  validated_by: \"\"\n  validated_at: \"\"\n  notes: >\n    A completer apres recettage humain et relecture du git diff reel.","resume":"Contrat de tâche C4 / patch pour FB_Safety_Winch (MecaB) : remplacer JoystickYNeutral par NOT MovementCommanded afin de supprimer le faux [M1] ErrorID:09 en mode boutons MAINT_N2, avec exigence de non-affaiblissement de la chaîne de sécurité. AC1..AC7 couvrent reproduction ROUGE/VERT, non-régression MecaA/autres causes, invariance PostRampTimeout & SafeStop/PowerCutOff, critères structurels (nom fichier = POU, suffixe = langage bundle) et preuves check_linkage/run_all_gates/bundle/diff_bundle — conforme au gabarit et au check_task_contract.py."}
Je dispose du contexte suffisant (template, checker, code réel de `FB_Safety_Winch`, test CI `test_fb_safety_winch.st`). Le contrat est conforme au template et aux règles T1–T8 du `check_task_contract.py`. Aucun fichier écrit — contenu livré en sortie.

---

```yaml
# ═══════════════════════════════════════════════════════════════════════════
# CONTRAT DE TACHE ET SUIVI DE CYCLE DE VIE — projet Excavatrice Dragage
# ═══════════════════════════════════════════════════════════════════════════
# T4-C4 — FB_Safety_Winch : confirmation d'arret MecaB independante de la
# source de commande (remplacer JoystickYNeutral par NOT MovementCommanded)
#
# Contexte (faux positif) : en mode boutons MAINT_N2, la simulation produit un
# faux [M1] ErrorID:09 MecaB car le critere s'appuie sur JoystickYNeutral,
# TOUJOURS TRUE en mode boutons (joystick non sollicite), au lieu de reposer
# sur MovementCommanded (source reelle de la commande de mouvement).
#
# Validation  : python TOOLS/AGENT_WORKFLOW/scripts/check_task_contract.py <fichier>
# ═══════════════════════════════════════════════════════════════════════════

contract:
  # ── Identification ────────────────────────────────────────────────────────
  task_id: T4_C4_FB_SafetyWinch_MecaB_MovementCommanded
  criticality: C4            # FB de securite — criticite maximale
  strategy: patch            # correctif cible ; pas de rebuild

  # ── 1. Objectif metier ────────────────────────────────────────────────────
  objective: >
    Rendre la confirmation d'arret mecanique MecaB de FB_Safety_Winch
    independante de la source de commande, en remplacant le critere
    JoystickYNeutral par NOT MovementCommanded, de sorte qu'en mode boutons
    MAINT_N2 (ou tout autre mode hors joystick) un arret commande ne genere
    plus de faux [M1] ErrorID:09 MecaB, tout en conservant la detection de
    mouvement non commande dans les modes joystick.

  # ── 2. Criteres testables ─────────────────────────────────────────────────
  acceptance:
    - id: AC1
      statement: >
        En mode boutons MAINT_N2 de simulation, le faux [M1] ErrorID:09 MecaB
        se reproduit en ROUGE sur le bundle AVANT correction (etat de reference),
        confirmant que le critere JoystickYNeutral (toujours TRUE hors joystick)
        declenche la cause a tort.
      verified_by: >
        Lancement du test CI FB_Safety_Winch (test_fb_safety_winch.st) sur le
        bundle avant modification : la cause MecaB/bit ErrorID:09 retourne FAIL
        en configuration mode boutons MAINT_N2.
    - id: AC2
      statement: >
        Apres remplacement de JoystickYNeutral par NOT MovementCommanded dans
        FB_Safety_Winch, le meme scenario mode boutons MAINT_N2 passe au VERT :
        aucun faux [M1] ErrorID:09 MecaB n'est emis lorsque la commande de
        mouvement est absente.
      verified_by: >
        Re-lancement du test CI FB_Safety_Winch apres modification : le critere
        MecaB/bit ErrorID:09 retourne PASS en mode boutons MAINT_N2.
    - id: AC3
      statement: >
        La confirmation d'arret mecanique MecaB devient fonction de la seule
        absence de commande de mouvement : MecaB est vrai quand MovementCommanded
        est FALSE, quel que soit l'etat du joystick, et reste vrai quand
        MovementCommanded est TRUE, sans elargir le declenchement.
      verified_by: >
        Test CI FB_Safety_Winch : matrice MovementCommanded x JoystickYNeutral,
        le bit MecaB correspond exactement a NOT MovementCommanded sur chaque ligne.
    - id: AC4
      statement: >
        Non-regression : les autres causes mecaniques de FB_Safety_Winch
        (MecaA et toutes les autres causes du masque) conservent un comportement
        identique avant/apres, sur la suite de tests FB_Safety_Winch existante.
      verified_by: >
        Diff des resultats de test CI FB_Safety_Winch avant/après modification :
        seules les lignes du critere MecaB changent, toutes les autres causes
        conservent leur verdict de reference.
    - id: AC5
      statement: >
        Aucun changement de comportement de PostRampTimeout et aucune
        modification de la logique d'escalade SafeStop / PowerCutOff : ces
        zones restent hors scope et hors diff.
      verified_by: >
        `git diff` du lot : seul CODE/H_TREUILS_BENNE/FB_Safety_Winch.st et le
        test CI associe sont modifies ; aucun commit ne touche PostRampTimeout
        ni les branches SafeStop / PowerCutOff.
    - id: AC6
      statement: >
        Criteres structurels verifies : le nom de chaque fichier est egal au
        nom du POU ; et le suffixe de fichier est egal au langage genere dans le
        bundle.
      verified_by: >
        Gate structurel (G310) + generate_codesys_bundle.py : FB_Safety_Winch.st
        nomme le POU FB_Safety_Winch et porte le suffixe .st correspondant au
        langage ST genere dans CODE_XML/CODE_Bundle.xml.
    - id: AC7
      statement: >
        Le lot est pret pour integration CODESYS : bundle complet regenere et
        valide, liaison provee, gates palier C au vert et diff bundle cible.
      verified_by: >
        generate_codesys_bundle.py . ; G200_check_linkage.py --report (PASS) ;
        run_all_gates.py --palier C (15/15) ; generate_codesys_diff_bundle.py
        . CODE/H_TREUILS_BENNE/FB_Safety_Winch.st (Code_DiffBundle.xml avec
        l'objet FB_Safety_Winch).

  # ── 3. Perimetre ──────────────────────────────────────────────────────────
  scope:
    allowed:                 # fichiers que la tache PEUT modifier
      - CODE/H_TREUILS_BENNE/FB_Safety_Winch.st
      - TOOLS/TEST_AUTO_CI/H_TREUILS_BENNE/tests/test_fb_safety_winch.st
      - DOC/AF/AF_Partie-10 (note d'application du correctif si besoin)
      - CODE_XML/CODE_Bundle.xml          # bundle complet regenere
      - CODE_XML/CODE_DiffBundle.xml      # diff bundle cible FB_Safety_Winch
      - CONTRACTS/ (contrat de tache C4)
      - DOC/WFLOW/TASKS.yaml              # suivi statut de la tache
    forbidden:               # explicitement hors scope — ne pas y toucher
      - PRJ_CODESYS/project/Device.export
      - logique PostRampTimeout
      - logique d'escalade SafeStop / PowerCutOff
      - tous autres FB de securite (hors FB_Safety_Winch)
      - GVL_IHM
      - GVL_PERSISTENT

  # ── 4. Contrat de conservation ────────────────────────────────────────────
  # OBLIGATOIRE si strategy = rebuild. Present ici car FB de securite C4.
  conservation:
    must_survive:            # comportements a preserver imperativement
      - "Detection de mouvement non commande (UncommandedActive) en mode joystick"
      - "Confirmation d'arret mecanique MecaB uniquement sur arret reel (NOT MovementCommanded)"
      - "Toutes les autres causes du masque (MecaA et autres) et leurs seuils"
      - "Aucun affaiblissement de la chaine SafeStop / PowerCutOff"
    dropped_on_purpose:      # abandonne sciemment — decision humaine, tracee
      - "JoystickYNeutral comme critere de confirmation d'arret MecaB (cause du faux positif)"

  # ── 5. Preuves attendues en restitution ───────────────────────────────────
  evidence_required:
    - check_linkage          # G200_check_linkage.py --report (PASS, 0 erreur)
    - run_all_gates          # run_all_gates.py --palier C (15/15 PASS)
    - bundle                 # CODE_XML/CODE_Bundle.xml regenere et valide
    - diff_bundle            # CODE_XML/CODE_DiffBundle.xml (objet FB_Safety_Winch)
    - test_rouge_vert        # test CI FB_Safety_Winch : ROUGE avant / VERT apres

  # ── 6. Modeles autorises ──────────────────────────────────────────────────
  models_allowed:
    - "deepseek-v4-flash:cloud"
    - "omni/cc/claude-sonnet-5"

  # ── 7. Devoir d'alerte ────────────────────────────────────────────────────
  alert_duty: >
    FB de securite : ne JAMAIS affaiblir le critere de confirmation d'arret ni
    la chaine de securite. Le test ROUGE/VERT (MecaB, mode boutons MAINT_N2) est
    obligatoire avant et apres le correctif. Toute derive, incoherence de spec
    (AF-10), ou risque hors scope constate est remonte IMMEDIATEMENT a
    l'orchestrateur, pas a la fin et jamais silencieusement. Signaler n'est pas
    elargir le scope.

# ═══════════════════════════════════════════════════════════════════════════
# 🚦 SUIVI DE L'ETAT D'AVANCEMENT & LISEUR HUMAIN (Où on en est)
# ═══════════════════════════════════════════════════════════════════════════
status: PENDING               # PENDING (attente) | IN_PROGRESS (cours) | COMPLETED (fait agent) | VALIDATED (validé)

# ── 1. Rapport d'exécution de l'agent (rempli en fin de travail par l'agent) ──
execution:
  executed_by: "DSH01"       # Ex: sonnet-5 (antigravity)
  completed_at: ""           # Timestamp ISO (ex: 2026-08-12T06:27:00+02:00)
  status: PENDING            # PENDING | COMPLETED | BLOCKED | ALERT_RAISED
  summary: >
    En attente d'execution. Correctif : remplacer JoystickYNeutral par
    NOT MovementCommanded dans le critere de confirmation d'arret MecaB de
    FB_Safety_Winch, puis ROUGE/VERT en mode boutons MAINT_N2.
  evidence_submitted: []     # Preuves clés (ex: "run_all_gates: PASS", "linkage: PASS")

# ── 2. Visa de validation de l'orchestrateur / validateur ──────────────────
validation:
  status: PENDING            # PENDING | APPROVED | REJECTED
  validated_by: ""           # Ex: Claude Code (Orchestrateur)
  validated_at: ""           # Timestamp ISO
  notes: >
    A completer apres recettage humain et relecture du git diff reel.
```

---

**Résumé (2 lignes) :**
- Contrat de tâche **C4 / patch** pour `FB_Safety_Winch` (MecaB) : remplacer `JoystickYNeutral` par `NOT MovementCommanded` afin de supprimer le faux [M1] ErrorID:09 en mode boutons MAINT_N2, avec exigence de non-affaiblissement de la chaine de sécurité.
- Les AC1..AC7 couvrent reproduction ROUGE/VERT, non-régression MecaA/autres causes, invariance PostRampTimeout & SafeStop/PowerCutOff, critères structurels (nom fichier = POU, suffixe = langage bundle) et preuves `check_linkage`/`run_all_gates`/`bundle`/`diff_bundle` — conforme au gabarit et au `check_task_contract.py`.

## Verifier couche AU rearmement simu [completed]

[structured] {"lien_t369":"Cause racine IDENTIQUE au deadlock T369 : en simulation la chaîne AU ne peut PAS être refermée par le PLC. EmergencyChainClosed_DI = instSimSafety.SimChainOk (FB_SimBench.st:691) ; SimChainOk := NOT ChainOpen, ChainOpenReq = (NOT SimChainOkBit) OR BtnEmergencyStop OR TestCutActive OR PowerCutOffRequest (FB_Sim_Safety.st:109) — PowerCutOff_A/B (= PowerKeepAlive PLC) explicitement exclus (FB_Sim_Safety.st:5-7/31/44-45). SimChainOkBit = GVL_Simulation.SimChainOk initialisé FALSE (GVL_Simulation.st:141) et remis FALSE en sortie de simu (PRG_02_Acquisition.st:115). La séquence exige EmergencyChainClosed à RESTORE_A (:349) et RESTORE_B (:391) ; défaut RETAIN BypassAuRedundancyTestA=TRUE (GVL_BypassRetain.st:29) => avortement à RESTORE_B (CST_ABORT_TIMEOUT_RESTORE_B) + message latché (FB_Hmi_BannerFormatter.st:511-522) => boucle armer->avortement->acquitter->rearmer récurrente. Correctif proposé (fiche T369 §8 Option 1 RETENUE, non appliqué) : intégrer PowerKeepAlive_A/B dans ChainOpenReq de FB_Sim_Safety.st ; verrous T300/DSH03 et T328/DSH03.","preuve":["CODE/L_SIMULATION/GVL_Simulation.st:141  SimChainOk : BOOL := FALSE","CODE/L_SIMULATION/GVL_Simulation.st:136-140  doc defaut : SimChainOk FALSE => chaine ouverte, on ne peut pas armer","CODE/M_MAIN/PRG_02_Acquisition.st:115  GVL_Simulation.SimChainOk := FALSE; // Chatne AU ouverte a la re-entree","CODE/L_SIMULATION/FB_Sim_Safety.st:109  ChainOpenReq := (NOT SimChainOkBit) OR BtnEmergencyStop OR TestCutActive OR PowerCutOffRequest","CODE/L_SIMULATION/FB_Sim_Safety.st:5-7/31/44-45  PowerCutOff_A/B (PowerKeepAlive PLC) conserves pour interface, NON utilises par SimChainOk","CODE/L_SIMULATION/FB_Sim_Safety.st:127  SimChainOk := NOT ChainOpen","CODE/L_SIMULATION/FB_SimBench.st:691  Machine.EmergencyChainClosed_DI := instSimSafety.SimChainOk","CODE/L_SIMULATION/FB_SimBench.st:682-683  PowerCutOff_A/B := PowerKeepAlive_A/B (inertes sur la chatne)","CODE/M_MAIN/PRG_02_Acquisition.st:335  SimChainOkBit := GVL_Simulation.SimChainOk","CODE/B_AU_SECURITE/FB_Safety_EmergencyManagement.st:349  RESTORE_A : IF EmergencyChainClosed OR BypassArmingPreconditions sinon abort","CODE/B_AU_SECURITE/FB_Safety_EmergencyManagement.st:391  RESTORE_B : IF EmergencyChainClosed OR BypassArmingPreconditions sinon abort CST_ABORT_TIMEOUT_RESTORE_B","CODE/B_AU_SECURITE/FB_Safety_EmergencyManagement.st:530  Maintain_ChainOk := EmergencyChainClosed OR (ArmingSeqStep<>IDLE) OR WasArmed (PowerKeepAlive asserté mais ignore en simu)","CODE/B_AU_SECURITE/FB_Safety_EmergencyManagement.st:317-323  BypassAuRedundancyTestA => IDLE->TEST_B, RESTORE_A sautee","CODE/L_SIMULATION/GVL_BypassRetain.st:29  BypassAuRedundancyTestA : BOOL := TRUE (RETAIN, par defaut)","CODE/L_SIMULATION/GVL_BypassRetain.st:27  BypassAuArmingPreconditions : BOOL := FALSE (donc chaine fermee exigee)","CODE/L_SIMULATION/GVL_BypassRetain.st:31  BypassAuPowerCutOff : BOOL := TRUE (neutralise PowerCutOffRequest dans FB AU uniquement)","CODE/J_SUPERVISION/FB_Hmi_BannerFormatter.st:511-522  message abandon latche, efface seulement par Reset ou nouvelle sequence","CODE/B_AU_SECURITE/FB_Safety_EmergencyManagement.st:242-247 et :629  abort CST_ABORT_CHAIN_DROP si EmergencyChainClosed=FALSE pendant PULSE/CONFIRM","DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T369_DEADLOCK_REARMEMENT_SIMU_20260921.md:34-42,167-173  cause racine confirmee + correctif propose (Option 1: integrer PowerKeepAlive dans ChainOpenReq)","DOC/WFLOW/TASKS.yaml:864-929  entree T369 : deadlock rearmement simu - ATTEINT, cause racine confirmee","DOC/WFLOW/TASKS.yaml:990-1029  entree T367 : ancien lot annule/reverte ; sujet actuel (faux positifs demarrage) non demarre","TOOLS/AGENT_WORKFLOW/config/Device_IO_20260918.csv:476/475  EmergencyChainClosed_DI=%IX225.7 / PowerContactorEngaged_DI=%IX225.6, noeud VH_0800END"],"verdict_au_rearm":"VERDICT : BLOCAGE DE REARMEMENT RECURRENT CONFIRME en simulation. (1) Techniquement OUI, la chatne AU peut etre refermee en simu, mais UNIQUEMENT si l'operateur maintient GVL_Simulation.SimChainOk=TRUE ET que la cause PowerCutOff/MecaB est acquittee (TonChainClose 50ms, FB_Sim_Safety.st:114-125) — elle n'est jamais refermee par le PLC (PowerKeepAlive_A/B exclus de ChainOpenReq). (2) La sequence d'armement (FB_Safety_EmergencyManagement :349/:391) exige EmergencyChainClosed aux etapes RESTORE_A/RESTORE_B ; avec SimChainOk=FALSE par defaut (GVL_Simulation.st:141) l'armement avorte a RESTORE_B (BypassAuRedundancyTestA=TRUE, GVL_BypassRetain.st:29) et le message reste latche => boucle recurrente = 'toujours le meme probleme'. (3) Cause racine IDENTIQUE au diagnostique T369 (deja resolu sur la cause, correctif NON applique, verrous T300/DSH03 et T328/DSH03). Correctif retenu (a remettre a DSH03, sous contrat C2) : integrer le maintien PLC PowerKeepAlive_A/B dans ChainOpenReq de FB_Sim_Safety.st pour que le banc se referme comme le reel."}
🕵️ **MODE DÉPANNAGE / TROUBLESHOOTING ACTIF** — Diagnostic : réarmement AU en simulation après coupure (MecaB).

---

# Rapport de diagnostic — Réarmement AU en simu après MecaB (T369/T367)

**LECTURE SEULE respectée** — aucune écriture de code/fichier. Le diagnostic demandé (T369/T367) est déjà livré et confirmé par preuve dans `DOC/WFLOW/TROUBLESHOOTING/FICHES/TROUBLESHOOTING_T369_DEADLOCK_REARMEMENT_SIMU_20260921.md` et dans l'entrée `TASKS.yaml` T369 (`:860-929`). Ton scénario (post-MecaB) reproduit **la même cause racine** que le deadlock T369 (post-boot).

---

## (1) L'AU peut-elle être refermée en simu après un PowerCutOff/MecaB ?

**OUI théoriquement — MAIS uniquement via le bit opérateur `GVL_Simulation.SimChainOk`, jamais par le PLC.** En simu la chaîne n'est PAS refermée par le maintien PLC `PowerKeepAlive_A/B` :

- `EmergencyChainClosed_DI` en simu = `instSimSafety.SimChainOk` → câblée `FB_SimBench.st:691`.
- `SimChainOk := NOT ChainOpen` (`FB_Sim_Safety.st:127`), et `ChainOpenReq := (NOT SimChainOkBit) OR BtnEmergencyStop OR TestCutActive OR PowerCutOffRequest` (`FB_Sim_Safety.st:109`). **Aucun terme PowerCutOff_A/B** (= PowerKeepAlive du PLC, conservé "non utilisé" `FB_Sim_Safety.st:5-7/:31/:44-45`).
- `SimChainOkBit` alimenté par `GVL_Simulation.SimChainOk` (`PRG_02_Acquisition.st:335`), **initialisé FALSE** (`GVL_Simulation.st:141`) et remis FALSE à la sortie de simu (`PRG_02_Acquisition.st:115`).

Donc, après un MecaB (qui ouvre la chaîne via `PowerCutOffRequest` dans le cercle — `FB_SimBench.st:333`, `FB_Sim_Safety.st:109`), la chaîne ne repasse à TRUE que si (a) la cause `PowerCutOffRequest`/MecaB est **acquittée** et (b) `SimChainOk` = TRUE, puis après `TonChainClose` 50 ms (`FB_Sim_Safety.st:114-125`). **Si le bit reste FALSE (défaut), `EmergencyChainClosed` ne repasse JAMAIS à TRUE.**

## (2) Le mécanisme permet-il le réarmement, ou y a-t-il un blocage récurrent ?

**Blocage récurrent CONFIRMÉ.** La séquence d'armement exige `EmergencyChainClosed` (= chaine **fermée**) à `RESTORE_A` (`FB_Safety_EmergencyManagement.st:349`) **et** à `RESTORE_B` (`:391`) pour atteindre l'impulsion contacteur. Or en simu la chaîne ne peut être fermée **ni par le PLC (PowerKeepAlive exclu)** ni par défaut (`SimChainOk=FALSE`) ⇒ l'armement avorte à chaque tentative. Détail de l'avortement :

- `BypassAuRedundancyTestA := TRUE` par défaut (`GVL_BypassRetain.st:29`) ⇒ `IDLE → TEST_B`, **RESTORE_A sautée** (`FB_Safety_EmergencyManagement.st:317-323`) ⇒ l'avortement tombe à **`RESTORE_B`** (`:391-398`, `CST_ABORT_TIMEOUT_RESTORE_B`).
- Le message d'abandon est **latché** (`FB_Hmi_BannerFormatter.st:511-522`, effacé seulement par Reset ou nouvelle séquence) ⇒ boucle *armer → avortement → acquitter → réarmer* : **"toujours le même problème"**, exactement ton observation.
- Aggravant : `PowerKeepAlive_A/B` est bien **asserté pendant la séquence** (`Maintain_ChainOk := EmergencyChainClosed OR (ArmingSeqStep<>IDLE) OR WasArmed`, `FB_Safety_EmergencyManagement.st:530`) et pilote la simu (`FB_SimBench.st:682-683`) — mais `FB_Sim_Safety` l'ignore pour la chaîne. C'est l'asymétrie réelle vs simulée qui est au cœur du blocage.

➡️ **Verdict : blocage de réarmement récurrent CONFIRMÉ en simu**, car la chaîne simulée n'est refermable ni par le PLC ni par défaut — elle ne dépend que du bit opérateur `SimChainOk`, FALSE par défaut.

## (3) Lien avec T369/T367 et ce qui manque

- **T369** (`TASKS.yaml:860-929`, fiche citée) : diagnostic **read-only déjà livré**, cause racine **identique** (« en simulation la chaîne AU ne peut PAS être refermée par le PLC — `SimChainOk` FALSE par défaut + `PowerKeepAlive_A/B` absent de `FB_Sim_Safety.st:106/:109` ⇒ la séquence exige `EmergencyChainClosed` à RESTORE_A/RESTORE_B ⇒ avortement systématique et message latché »). Statut : cause racine **RÉSOLUE**, correctif **non appliqué**.
- **T367** (`TASKS.yaml:990-1029`) : l'ancien lot (fusion réarmement+acquittement) a été **annulé/réverté** ; le sujet actuel (faux positifs de défaut au démarrage) est **non démarré / non assigné**. Le diagnostic T369 l'a complété avec le volet « 61 causes latchées au démarrage ».
- **Ce qui manque (correctif proposé fiche §8, Option 1 RETENUE — non écrit)** : intégrer le maintien PLC `PowerKeepAlive_A/B` dans `ChainOpenReq` de `FB_Sim_Safety.st` pour que le banc se referme comme le réel. ⚠️ Verrous ACTIFS sur le périmètre : `T300/DSH03` et `T328/DSH03` (`FB_SimBench.st`, `GVL_Simulation.st`) → correctif remis à DSH03, **pas** à T369. Option 2 (rejet de l'Option 1) : exposer `SimChainOk` à l'IHM. Option 3 **rejetée** (`BypassArmingPreconditions`, bypass non sécurisé, arbitrage humain 2026-09-21).

## ⚠️ Alertes sécurité (hors périmètre, à trancher humain)
- `GVL_BypassRetain.st:29` `BypassAuRedundancyTestA := TRUE` et `:31` `BypassAuPowerCutOff := TRUE` en `VAR_GLOBAL RETAIN` par défaut (arbitrage humain assumé 2026-09-21T09:00, "C EST UN CHOIX...", ne pas rouvrir).
- Les 2 retours clés `%IX225.7` (EmergencyChainClosed) / `%IX225.6` (PowerContactorEngaged) sont sur le nœud `VH_0800END`, pas sur les E/S locales du CPU (`Device_IO_20260918.csv:475-476`).

**Test décisif** (fiche §9, à faire par l'exploitant) : forcer `GVL_Simulation.SimChainOk := TRUE` puis armer → si `EmergencyDiag.LastAbortCause` cesse d'être `CST_ABORT_TIMEOUT_RESTORE_A/B`, le diagnostic est clos ; sinon une autre cause ouvre la chaîne.

---

**Référence :** fiche complète `TROUBLESHOOTING_T369_DEADLOCK_REARMEMENT_SIMU_20260921.md` (217 lignes) + entrée TASKS.yaml `T369` (`:860-929`) et `T367` (`:990-1029`).

## supervisor [via researcher] [completed]

全部四项子任务的核心主张已在真实源码中复核通过。关键验证结果：

- **H1** — `FB_Safety_Winch.st:341`：`UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback)` ✅；`MovementCommanded` 已在 `PRG_04:955` 接好 `:= instWinchM1.RelayFwd OR instWinchM1.RelayRev` ✅；`JoystickYNeutral := (Joystick.AxisY.Direction = 0)` `PRG_04:961` ✅
- **H2** — `FB_SimBench.st:449-451` 接触器返回为组合逻辑 `NOT(RelayFwd∨RelayRev∨SC1..4)`；制动闭合走 `WinchBrakeCloseDelayEffectiveS` 短定时器 ✅ 模型忠实
- **AU 重武装** — `FB_Sim_Safety.st:109` `ChainOpenReq := (NOT SimChainOkBit) OR BtnEmergencyStop OR TestCutActive OR PowerCutOffRequest`，无 PowerCutOff_A/B 词项 ✅；`FB_Safety_EmergencyManagement.st:390-398` RESTORE_B 强制要求 `EmergencyChainClosed` ✅

以下是合并后的尽调结论。

---

# 结论综合（4 子任务 → 1 份去重事实链）

## 📌 一句话结论
用户观察到的「停产后总是同一个问题」被完整解释为**一条因果链**：MecaB 在按钮模式的**假阳性故障**(H1, 已确认)+ 仿真模型**忠实复现**(H2)+ 故障后 **AU 仿真重武装死锁**(因果链的后果, 与 T369 同根)。三者共同指向**一个唯一的待修正确认标准**：FB_Safety_Winch.st:341 用 `JoystickYNeutral`（物理操纵杆手势）作为「停位未确认」判定，未用真实命令态 `MovementCommanded`。

---

## 因果链（事实清单，均带证据）

### 🔴 环节 1 — 根本缺陷 H1（确认）
按钮模式 MAINT_N2 下，`JoystickYNeutral` 恒为 TRUE（操纵杆物理手势=0，按钮命令不碰操纵杆）→ `UncommandedActiveB=TRUE` 在正常按钮命令期间成立 → TON 3s 超时 → latch `ErrorID:09 MecaB`「停位未确认」，而**根本没有请求停机**。

| 证据 | 内容 | 作用 |
|---|---|---|
| `FB_Safety_Winch.st:341` | `UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback)` | 用「命令来源(手势)」而非「真实命令态」判停位 |
| `PRG_04_Treuils_Benne.st:955` | `MovementCommanded := instWinchM1.RelayFwd OR instWinchM1.RelayRev` | 真实命令态已存在、已接好，但 MecaB 未用 |
| `PRG_04_Treuils_Benne.st:961/:1030` | `JoystickYNeutral := (AxisY.Direction = 0)` | 测物理手势，按钮不可见 |
| `FB_WinchCmdArbitrationM1.st:68-87` | `IF NOT TglJoystickMaster THEN …BtnAscentM1/BtnDescentM1…` | 按钮模式下操纵杆保持中立 |
| `FB_Safety_Winch.st:339-350` | latch `:343`、`instCauses[8]` | ErrorID bit8 = 09 |

**对比佐证**：MecaA（`:329`）用物理态 `FwdRevSpeedFeedbackOff AND NOT BrakeFeedback` 而非 `JoystickYNeutral` —— 证明 MecaB 与其孪生姊妹不一致。

### 🟢 环节 2 — 仿真模型忠实 H2（H2 被否定，即「仿真无 bug」）
`FB_SimBench` 不是病因：接触器/制动回读<10ms（组合逻辑或短定时器），忠实反映 `PRG_06_Outputs.Data.*` 的**命令后**状态。

| 信号 | 机制 | 有效延迟 |
|---|---|---|
| `M1_ContactorsReleased_DI` (FB:449-451) | 组合逻辑 | 0s（同扫描） |
| `M1_BrakeIsOpen_DI` (FB:446,437-445) | 状态+关闭定时器 `WinchBrakeCloseDelayEffectiveS=SEL(SimWinchDynamicsActive,0.0,CloseDelayS)`；默认 FALSE→0.0s；若 TRUE→0.09s | ≤0.09s |

**结论**：一个 >3s 的冻结态必然意味着**命令未回落**（上游 `M1RelayFwd/Rev` 或 `M1SpeedContactor*` 保持=1），而非仿真 bug。这条环节**排除**了「仿真失真导致假象」的可能 → 反向**证实 H1 是真实逻辑缺陷**。

### 🔴 环节 3 — 后果：AU 仿真重武装死锁（确认，与 T369 同根）
MecaB 停位假阳性 → 触发 `PowerCutOffRequest` → 仿真链打开。而：

- 仿真的链只能由**操作员位** `GVL_Simulation.SimChainOk` 关闭（`FB_Sim_Safety.st:109/127` 用 `SimChainOkBit`，`PowerCutOff_A/B`=PLC 保活**被排除**），PLC 无法自己关链；
- `SimChainOk=FALSE` 默认（`GVL_Simulation.st:141`），且 RETAIN `BypassAuRedundancyTestA=TRUE`（`GVL_BypassRetain.st:29`）→ 跳过 RESTORE_A → 在 **RESTORE_B**（`FB_Safety_EmergencyManagement.st:390-398`）要求 `EmergencyChainClosed` 失败 → aborte → 消息 latch（`FB_Hmi_BannerFormatter.st:511-522`）→ **反复「武装→中止→复位→再武装」**。

这解释了「**停产后总是同一个问题**」—— 每次复位后重武装必死锁，故复现每次相同。

**→ 三环节合并结论**：H1（触发）+ H2（确认非仿真假象）+ AU 死锁（后果）是**同一条链**，非三个独立 bug。修复 H1 能消除触发点，但**不会**解决 AU 仿真重武装死锁本身（那是独立缺陷，同 T369）。

---

## 🛠️ 已定稿的可执行修复（子任务 3 — 契约 C4）

**待改**：`FB_Safety_Winch.st:341`，将 `JoystickYNeutral` → `NOT MovementCommanded`
- 前(BUG)：`UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND …`
- 后(FIX)：`UncommandedActiveB := NOT MovementCommanded AND NOT BenneHoldStillActive AND …`

| 项 | 状态 |
|---|---|
| 契约 YAML | 已起草（T4_C4，criticité C4，patch 策略，AC1-AC7，scope/forbidden） |
| 验证脚本 | `check_task_contract.py` 未跑 |
| 测试 ROUGE/VERT | **未执行**（建议新增 TC-P10：Both 按钮命令 3s 后 ASSERT_FALSE(fb.Fault.Error)；非回归：既有 TC-P10-002 停位超时须继续 FAIL） |
| Gates G200/G310/21 Gates | **未执行** |
| Bundle regen | **未执行** |

**非回归边界**（勿动）：
- `WinchStandstill`（`:263-265`, `:394/:395` MecaE 解除用）已含 `AND NOT MovementCommanded`，**不要改** `JoystickYNeutral` 此处；
- `JoystickYNeutral` VAR_INPUT 声明（`:34`）**保留**（此处仍被读）；不触碰 PostRampTimeout/SafeStop/PowerCutOff 逻辑。

---

## ⚠️ 缺失/不确定项（须标注）

| # | 项 | 等级 |
|---|---|---|
| 1 | **修复未实施**（无代码改动，仅诊断+契约） | 高 |
| 2 | **ROUGE/VERT CI 测试未跑**（含 `check_task_contract.py`、G200、run_all_gates、bundle regen） | 高 |
| 3 | **AU 仿真重武装死锁修复未应用** —— 与 T369 同根；建议交 DSH03 独立于本修正（`FB_Sim_Safety.st:109` 集成 `PowerKeepAlive_A/B`），有锁 T300/T328 | 中 |
| 4 | `BypassAuRedundancyTestA=TRUE`(RETAIN)、`GVL_Simulation.st:141` 等旁证**未独立复核**（沿用子任务 4 引用） | 低 |
| 5 | MecaB 与 AU 死锁是否**同一交付单元**需人工裁定（建议拆 2 个契约：C4 修 MecaB + C2 修 AU 重武装） | 决策点 |

---

## 一句话总结
四项子任务无矛盾、可去重合并为**一条链**：`MecaB假阳性(H1确认)` 是真实逻辑缺陷（仿真 H2 排除失真，证其为真）→ 触发 `ErrorID:09` → 导致 `AU仿真重武装死锁`(同 T369)。**可执行修复已定**（`:341` 用 `NOT MovementCommanded` 替代 `JoystickYNeutral`，契约 C4 已起草），但**代码未改、测试/gates 未跑**；**AU 重武装死锁为独立缺陷，需单独交付**。

## summary

supervisor 结论：全部四项子任务的核心主张已在真实源码中复核通过。关键验证结果：

- **H1** — `FB_Safety_Winch.st:341`：`UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback)` ✅；`MovementCommanded` 已在 `PRG_04:955` 接好 `:= instWinchM1.RelayFwd OR instWinchM1.RelayRev` ✅；`JoystickYNeutral := (Joystick.AxisY.Direction = 0)` `PRG_04:961` ✅
- **H2** — `FB_SimBench.st:449-451` 接触器返回为组合逻辑 `NOT(RelayFwd∨RelayRev∨SC1..4)`；制动闭合走 `WinchBrakeCloseDelayEffectiveS` 短定时器 ✅ 模型忠实
- **AU 重武装** — `FB_Sim_Safety.st:109` `ChainOpenReq := (NOT SimChainOkBit) OR BtnEmergencyStop OR TestCutActive OR PowerCutOffRequest`，无 PowerCutOff_A/B 词项 ✅；`FB_Safety_EmergencyManagement.st:390-398` RESTORE_B 强制要求 `EmergencyChainClosed` ✅

以下是合并后的尽调结论。

---

# 结论综合（4 子任务 → 1 份去重事实链）

## 📌 一句话结论
用户观察到的「停产后总是同一个问题」被完整解释为**一条因果链**：MecaB 在按钮模式的**假阳性故障**(H1, 已确认)+ 仿真模型**忠实复现**(H2)+ 故障后 **AU 仿真重武装死锁**(因果链的后果, 与 T369 同根)。三者共同指向**一个唯一的待修正确认标准**：FB_Safety_Winch.st:341 用 `JoystickYNeutral`（物理操纵杆手势）作为「停位未确认」判定，未用真实命令态 `MovementCommanded`。

---

## 因果链（事实清单，均带证据）

### 🔴 环节 1 — 根本缺陷 H1（确认）
按钮模式 MAINT_N2 下，`JoystickYNeutral` 恒为 TRUE（操纵杆物理手势=0，按钮命令不碰操纵杆）→ `UncommandedActiveB=TRUE` 在正常按钮命令期间成立 → TON 3s 超时 → latch `ErrorID:09 MecaB`「停位未确认」，而**根本没有请求停机**。

| 证据 | 内容 | 作用 |
|---|---|---|
| `FB_Safety_Winch.st:341` | `UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND NOT (FwdRevSpeedFeedbackOff AND NOT BrakeFeedback)` | 用「命令来源(手势)」而非「真实命令态」判停位 |
| `PRG_04_Treuils_Benne.st:955` | `MovementCommanded := instWinchM1.RelayFwd OR instWinchM1.RelayRev` | 真实命令态已存在、已接好，但 MecaB 未用 |
| `PRG_04_Treuils_Benne.st:961/:1030` | `JoystickYNeutral := (AxisY.Direction = 0)` | 测物理手势，按钮不可见 |
| `FB_WinchCmdArbitrationM1.st:68-87` | `IF NOT TglJoystickMaster THEN …BtnAscentM1/BtnDescentM1…` | 按钮模式下操纵杆保持中立 |
| `FB_Safety_Winch.st:339-350` | latch `:343`、`instCauses[8]` | ErrorID bit8 = 09 |

**对比佐证**：MecaA（`:329`）用物理态 `FwdRevSpeedFeedbackOff AND NOT BrakeFeedback` 而非 `JoystickYNeutral` —— 证明 MecaB 与其孪生姊妹不一致。

### 🟢 环节 2 — 仿真模型忠实 H2（H2 被否定，即「仿真无 bug」）
`FB_SimBench` 不是病因：接触器/制动回读<10ms（组合逻辑或短定时器），忠实反映 `PRG_06_Outputs.Data.*` 的**命令后**状态。

| 信号 | 机制 | 有效延迟 |
|---|---|---|
| `M1_ContactorsReleased_DI` (FB:449-451) | 组合逻辑 | 0s（同扫描） |
| `M1_BrakeIsOpen_DI` (FB:446,437-445) | 状态+关闭定时器 `WinchBrakeCloseDelayEffectiveS=SEL(SimWinchDynamicsActive,0.0,CloseDelayS)`；默认 FALSE→0.0s；若 TRUE→0.09s | ≤0.09s |

**结论**：一个 >3s 的冻结态必然意味着**命令未回落**（上游 `M1RelayFwd/Rev` 或 `M1SpeedContactor*` 保持=1），而非仿真 bug。这条环节**排除**了「仿真失真导致假象」的可能 → 反向**证实 H1 是真实逻辑缺陷**。

### 🔴 环节 3 — 后果：AU 仿真重武装死锁（确认，与 T369 同根）
MecaB 停位假阳性 → 触发 `PowerCutOffRequest` → 仿真链打开。而：

- 仿真的链只能由**操作员位** `GVL_Simulation.SimChainOk` 关闭（`FB_Sim_Safety.st:109/127` 用 `SimChainOkBit`，`PowerCutOff_A/B`=PLC 保活**被排除**），PLC 无法自己关链；
- `SimChainOk=FALSE` 默认（`GVL_Simulation.st:141`），且 RETAIN `BypassAuRedundancyTestA=TRUE`（`GVL_BypassRetain.st:29`）→ 跳过 RESTORE_A → 在 **RESTORE_B**（`FB_Safety_EmergencyManagement.st:390-398`）要求 `EmergencyChainClosed` 失败 → aborte → 消息 latch（`FB_Hmi_BannerFormatter.st:511-522`）→ **反复「武装→中止→复位→再武装」**。

这解释了「**停产后总是同一个问题**」—— 每次复位后重武装必死锁，故复现每次相同。

**→ 三环节合并结论**：H1（触发）+ H2（确认非仿真假象）+ AU 死锁（后果）是**同一条链**，非三个独立 bug。修复 H1 能消除触发点，但**不会**解决 AU 仿真重武装死锁本身（那是独立缺陷，同 T369）。

---

## 🛠️ 已定稿的可执行修复（子任务 3 — 契约 C4）

**待改**：`FB_Safety_Winch.st:341`，将 `JoystickYNeutral` → `NOT MovementCommanded`
- 前(BUG)：`UncommandedActiveB := JoystickYNeutral AND NOT BenneHoldStillActive AND …`
- 后(FIX)：`UncommandedActiveB := NOT MovementCommanded AND NOT BenneHoldStillActive AND …`

| 项 | 状态 |
|---|---|
| 契约 YAML | 已起草（T4_C4，criticité C4，patch 策略，AC1-AC7，scope/forbidden） |
| 验证脚本 | `check_task_contract.py` 未跑 |
| 测试 ROUGE/VERT | **未执行**（建议新增 TC-P10：Both 按钮命令 3s 后 ASSERT_FALSE(fb.Fault.Error)；非回归：既有 TC-P10-002 停位超时须继续 FAIL） |
| Gates G200/G310/21 Gates | **未执行** |
| Bundle regen | **未执行** |

**非回归边界**（勿动）：
- `WinchStandstill`（`:263-265`, `:394/:395` MecaE 解除用）已含 `AND NOT MovementCommanded`，**不要改** `JoystickYNeutral` 此处；
- `JoystickYNeutral` VAR_INPUT 声明（`:34`）**保留**（此处仍被读）；不触碰 PostRampTimeout/SafeStop/PowerCutOff 逻辑。

---

## ⚠️ 缺失/不确定项（须标注）

| # | 项 | 等级 |
|---|---|---|
| 1 | **修复未实施**（无代码改动，仅诊断+契约） | 高 |
| 2 | **ROUGE/VERT CI 测试未跑**（含 `check_task_contract.py`、G200、run_all_gates、bundle regen） | 高 |
| 3 | **AU 仿真重武装死锁修复未应用** —— 与 T369 同根；建议交 DSH03 独立于本修正（`FB_Sim_Safety.st:109` 集成 `PowerKeepAlive_A/B`），有锁 T300/T328 | 中 |
| 4 | `BypassAuRedundancyTestA=TRUE`(RETAIN)、`GVL_Simulation.st:141` 等旁证**未独立复核**（沿用子任务 4 引用） | 低 |
| 5 | MecaB 与 AU 死锁是否**同一交付单元**需人工裁定（建议拆 2 个契约：C4 修 MecaB + C2 修 AU 重武装） | 决策点 |

---

## 一句话总结
四项子任务无矛盾、可去重合并为**一条链**：`MecaB假阳性(H1确认)` 是真实逻辑缺陷（仿真 H2 排除失真，证其为真）→ 触发 `ErrorID:09` → 导致 `AU仿真重武装死锁`(同 T369)。**可执行修复已定**（`:341` 用 `NOT MovementCommanded` 替代 `JoystickYNeutral`，契约 C4 已起草），但**代码未改、测试/gates 未跑**；**AU 重武装死锁为独立缺陷，需单独交付**。
