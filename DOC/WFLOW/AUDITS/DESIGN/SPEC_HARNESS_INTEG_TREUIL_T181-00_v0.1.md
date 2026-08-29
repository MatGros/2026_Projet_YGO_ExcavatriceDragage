# 🧪 SPÉC — Harnais d'intégration treuil (T181-00, Phase -1)

> **But** : faire tourner la chaîne `PRG_03 → PRG_04 → FB_Winch ×2 → PRG_06` **ensemble**, avec des
> vecteurs Grafcet / joystick / plongée, pour attraper les défauts d'intégration que le CI unitaire
> laisse passer (clamp M1≠M2, anti-traversée benne = chemin mort, `FinalInterlockGoverned`).
> **Livrable de la tâche T181-00. Bloque tout le reste de T181.**
> **Découverte clé : le squelette existe déjà — on l'étend, on ne le bâtit pas.**

---

## 1 · Point de départ : ce qui existe

| Élément | Emplacement | État |
|---|---|---|
| `FB_Main_EndToEnd` | `TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/FB_Main_EndToEnd.st` | Chaîne **déjà** `PRG_02→03→04→05→06→07` en boucle fermée (mégabloc) |
| Entrée registre `MAIN_EndToEnd` | `TOOLS/TEST_AUTO_CI/registry.yaml` | Compilée + exécutée par le CI STruCpp |
| Suite `test_main_end_to_end.st` | `TOOLS/TEST_AUTO_CI/RESULTS/M_MAIN/tests/` | **2 tests seulement** (montée couplée, coupure AU) |
| `FB_TestHarness_PRG_04` | `RESULTS/M_MAIN/FB_TestHarness_PRG_04.st` | Instancie **toute la paire treuil** : `FB_Winch×2`, `FB_Safety_Winch×2`, `FB_WinchSync`, `FB_Winch_Symmetry`, `FB_SpeedStep`, `FB_WinchOutputInterlock` |
| Primitives de test | moteur STruCpp | `ASSERT_TRUE/FALSE/EQ/GT`, `ADVANCE_TIME(ns)`, ré-appels cycliques du FB sous test |
| Base de temps | `TOOLS/TEST_AUTO_CI/config.yaml` | `cycle_time_ms: 10` |

### Ce qui manque dans `FB_Main_EndToEnd` (à combler par T181-00)

| Manque | Conséquence | Correction |
|---|---|---|
| `prg04(BtnWinchM1Up := FALSE, …)` en dur | impossible de piloter M1/M2 via IHM ou joystick dans le mégabloc | exposer les boutons IHM M1/M2, la sélection treuil, la commande benne, le contexte plongée en `VAR_INPUT` du mégabloc |
| Pas de modèle de position câble | `M1_CablePosM`/`M2_CablePosM` restent figées → zone de ralentissement bordure, homing 8,5 m, déviation sync **jamais exercées** | intégrateur : `CablePosM += vitesse_du_palier(StepNumber, Direction) × 10 ms` par instance |
| `MeasuredSpeedBand` non injectable | garde-fou survitesse / anti-calage palier non testables | dériver `MeasuredSpeedBand` du modèle de position ou l'exposer en entrée du mégabloc |
| `FinalInterlockGoverned` non exposé sur un bus | critère d'acceptation §5 du plan non vérifiable | remonter le diag de l'instance `PRG_06` de `FB_WinchRateInterlock` sur `BusOutputs` ou un bus dédié |
| Joystick en `JoyRawX/Y` (counts ADC) uniquement | vecteurs « rampe de déflexion 0→100 % » lourds à écrire | helper de conversion `%→raw` dans la suite de test |
| Pas de modèle benne (`FB_Bucket`) dans la boucle | override benne sur M2, régression M1 sous jog benne non testables | instancier `FB_TestHarness` benne ou stub `M2_BucketJogLimit` piloté depuis la suite |

---

## 2 · Montage cible

### 2.1 Périmètre d'instanciation

| POU | Rôle dans le harnais | Réel / stub |
|---|---|---|
| `PRG_03_Modes_Cycle` (via `FB_TestHarness_PRG_03`) | produit `ReqProgram.ReqWinchM1/M2`, `ReqBucket`, arbitrage modes | **réel** |
| `PRG_04_Treuils_Benne` (via `FB_TestHarness_PRG_04`) | orchestration paire, arbitrage §3, permits §5, **agrégateur de clamp** §6 | **réel** — cœur de la cible |
| `FB_Winch ×2`, `FB_Safety_Winch ×2`, `FB_WinchSync`, `FB_Winch_Symmetry`, `FB_SpeedStep`, `FB_WinchOutputInterlock` | dans `FB_TestHarness_PRG_04` | **réels** |
| `PRG_06_Outputs` (via `FB_TestHarness_PRG_06`) | barrière finale, 2ᵉ instance `FB_WinchRateInterlock`, génère `BusOutputs.MxRelayFwd/Rev/BrakeCmd` | **réel** |
| `PRG_02_Acquisition` (via `FB_TestHarness_PRG_02`) | qualifie joystick (homme-mort, neutre), publie `BusAcq` | **réel** (déjà dans le mégabloc) |
| `FB_Bucket` | producteur M2 caché (override, jog lent) | **réel** si dispo dans `PRG_04` harness, sinon **stub** piloté `M2_BucketJogLimit`/`M2_StartStop` |
| Modèle physique paire | intègre position M1/M2 depuis la vitesse-palier, calcule l'écart = déviation sync | **modèle minimal** dans le mégabloc (pas un simulateur) |
| Capteurs (`FwdRevSpeedFeedbackOff`, `BrakeFeedback`, contacteurs, `TopPositionSensor`, `KoboldImmersed`) | E/S physiques | **pilotés depuis la suite de test** (aujourd'hui figés dans `FB_Main_EndToEnd`) |

### 2.2 Modèle physique minimal (le strict nécessaire pour les oracles)

```
Par instance (M1, M2), à chaque cycle de 10 ms :
    v_palier   := SpeedTable[StepNumber] * signe(Direction)          (* m/s, table = SpeedStepTable réelle *)
    CablePosM  := CablePosM + v_palier * 0.010                        (* intégration *)
    MeasuredSpeedBand := bande(|v_palier|)                            (* 0..5, seuils = mêmes bornes que SpeedStep *)
Écart paire :
    SyncDeviationM := ABS(M1.CablePosM - M2.CablePosM)                (* alimente FB_WinchSync / Symmetry *)
Frein / contacteurs (retour) :
    FwdRevSpeedFeedbackOff := (StepNumber = 0) retardé de ContactorFeedbackTimeout
    BrakeFeedback          := RelayFwd OR RelayRev   (* frein ouvert tant qu'un sens est commandé *)
```
> Pas de dynamique moteur, pas de rampe hydraulique réelle : `FB_WinchStepShaper` fournit la
> temporisation, le modèle ne fait qu'intégrer le palier courant. Suffisant pour vérifier :
> quel palier, dans quel sens, sous quel clamp, avec quelle déviation.

### 2.3 Interface du mégabloc étendu (`FB_Main_EndToEnd` v2)

```
VAR_INPUT  (ajouts en gras)
    JoyRawX, JoyRawY : INT
    JoyDeadmanBtn, BtnResetMachine : BOOL
    CmdMode : E_Mode
    CmdWinchSelect : INT                       (* 0=couplé 1=M1 2=M2 *)
    EmergencyChainClosed, PowerContactorEngaged : BOOL
    **BtnWinchM1Up, BtnWinchM1Down : BOOL**
    **BtnWinchM2Up, BtnWinchM2Down : BOOL**
    **BtnWinchBothUp, BtnWinchBothDown : BOOL**
    **BucketCmdOpen, BucketCmdClose : BOOL**
    **KoboldImmersed : BOOL**                  (* contexte plongée *)
    **DiveContextActive : BOOL**               (* raccourci : force MAINT + intention descente plongée *)
    **InjectRateBypassFbWinch : BOOL**         (* test d'autorité interlock : cadence forcée hors instance FB_Winch *)
    M1_EncoderFault, M2_EncoderFault, PhaseRotationOk : BOOL
    (* M1_CablePosM / M2_CablePosM : RETIRÉS des entrées — désormais calculés par le modèle interne *)

VAR_OUTPUT  (ajouts en gras)
    BusAcq, BusModes, BusWinch, BusTranslation, BusOutputs, BusBanner  (* existants *)
    **M1_CablePosM_Model, M2_CablePosM_Model : REAL**
    **M1_StepNumber, M2_StepNumber : INT**            (* = BusWinch.WinchMxState.StepNumber, remonté pour lisibilité des asserts *)
    **SyncDeviationM_Model : REAL**
    **FinalInterlockGovernedM1, FinalInterlockGovernedM2 : BOOL**   (* diag instance PRG_06 de FB_WinchRateInterlock *)
```

### 2.4 Où ça se branche dans `TEST_AUTO_CI`

- **Option A (recommandée)** : nouvelle entrée registre `WINCH_INTEG` (domaine `H_TREUILS_BENNE`),
  `sources:` = la chaîne `MAIN_EndToEnd` + le mégabloc étendu, `test:` =
  `RESULTS/H_TREUILS_BENNE/tests/test_winch_integ.st`. Rapport dédié, ne pollue pas `MAIN_EndToEnd`.
- **Option B** : enrichir `test_main_end_to_end.st` en place. Plus simple, mais mélange
  « santé machine globale » et « gel treuil ».
- **Gate** : ajouter `WINCH_INTEG` à `run_all_gates.py` (palier C ou D). Rouge tant que la suite
  n'est pas verte → satisfait le critère de sortie de T181-00.

---

## 3 · Catalogue exhaustif des vecteurs

> Format : `id | scénario | entrées | séquence temporelle | oracle mesurable | défaut attrapé`.
> `HARN-1x` Grafcet↔Winch · `HARN-2x` Joystick↔Winch · `HARN-3x` Plongée · `HARN-4x` Régression /
> asymétrie · `HARN-5x` Autorité interlock · `HARN-6x` Sync paire · `HARN-7x` Sécurité · `HARN-8x` Croisement T180.

### 3.1 Grafcet ↔ Winch (`HARN-1x`)

| id | scénario | entrées | séquence | oracle | attrape |
|---|---|---|---|---|---|
| HARN-10 | Cycle semi-auto, étape descente rapide | `CmdMode:=SEMI_AUTO`, homme-mort armé, cycle lancé jusqu'à l'étape X (descente 50 %) | armer (150 ms) → lancer cycle → laisser converger 50 cycles | `M1_StepNumber` et `M2_StepNumber` == palier attendu de la table pour 50 % ; `BusOutputs.M1RelayRev` TRUE | mapping `SpeedPct→StepNumber` rompu |
| HARN-11 | Étape « montée contrôlée » extraction | cycle jusqu'à l'étape post-fermeture benne, `ExtractionControlActive` attendu | converger 30 cycles | `MaxStepAscent` effectif == 1 sur M1 **et** M2 ; `StepNumber ≤ 1` | fusion `ForceMinSpeedStep`/`ControlAscentActive` ratée |
| HARN-12 | Étape near-bordure haute | position câble amenée à `TopLimitM − CfgSlowdownDistanceM` par le modèle | descendre puis remonter jusqu'en zone | `StepNumber ≤ CfgSlowdownMaxStep` en zone haute ; jamais de dépassement `TopLimitM` | zone de ralentissement bordure calculée en commun au lieu de par instance |
| HARN-13 | Chaque étape X1..X11, table de vérité | boucle sur les étapes du cycle, `{Direction, SpeedPct}` émis | 1 sous-test par étape | `StepNumber` M1/M2 == valeur attendue (tableau de référence figé dans la suite) | régression silencieuse d'une étape |

### 3.2 Joystick ↔ Winch (`HARN-2x`)

| id | scénario | entrées | séquence | oracle | attrape |
|---|---|---|---|---|---|
| HARN-20 | Rampe de déflexion 0→100 % (montée) | `CmdMode:=MAINT_N1`, `CmdWinchSelect:=1`, homme-mort armé, `JoyRawY` de neutre à plein en 20 pas | 1 cycle par pas + 5 cycles de stabilisation | `StepNumber` croît de façon **monotone**, **jamais > +1 par cycle** ; plafond respecté | accostage palier trop brutal (à-coup contacteur) |
| HARN-21 | Rampe retour 100→0 % | suite de HARN-20, `JoyRawY` revient au neutre | idem | `StepNumber` décroît proprement ; au neutre → 0 en ≤ 2 cycles | relâche non franche |
| HARN-22 | Effleurement 5 % maintenu (hors plongée) | déflexion mini constante | 30 cycles | `StepNumber` == palier 1 (pas de plancher hors plongée) ; stable | plancher appliqué à tort hors plongée |
| HARN-23 | Homme-mort relâché en mouvement | HARN-20 puis `JoyDeadmanBtn:=FALSE` | 5 cycles | `StepNumber → 0`, `BusOutputs.MxRelayFwd/Rev` FALSE, frein retombe | perte d'effet du homme-mort dans la chaîne |

### 3.3 Plongée Kobold (`HARN-3x`)

| id | scénario | entrées | séquence | oracle | attrape |
|---|---|---|---|---|---|
| HARN-30 | Entrée en plongée, effleurement joystick | `DiveContextActive:=TRUE`, `KoboldImmersed` piloté, déflexion ~5 % descente | armer → pousser doucement → 20 cycles | transitions `StepNumber` 0→1→2→3 **temporisées** (≥ 1 cycle chacune) ; se stabilise à 3 (plancher `CfgDiveFloorStep`) | plancher forcé sur `StepNumber` direct (saut = à-coup) |
| HARN-31 | Interdiction palier 5 en Kobold | plongée + demande de vitesse plein pot | 20 cycles | `StepNumber` plafonné à 4 ; `CurrentSpeedStep` de `FB_DiveSearch` non nul (câblé) | D12 : bypass survitesse Kobold mort |
| HARN-32 | Relâche joystick en plongée | HARN-30 puis neutre | 3 cycles | `StepNumber → 0` immédiat ; `MinStepDescent` retombe (pas de plancher résiduel) | plancher collant au front de sortie |
| HARN-33 | Précédence Min vs Max en plongée près bordure basse | plancher `MinStepDescent=3` **et** zone ralentissement bas voulant `MaxStepDescent=1` | amener en zone | résultat `StepNumber` == **1** (plafond gagne) ; jamais hors [0..5] | amendement B non implémenté |

### 3.4 Régression / asymétrie M1↔M2 (`HARN-4x`)

| id | scénario | entrées | séquence | oracle | attrape |
|---|---|---|---|---|---|
| HARN-40 | **Régression M1 sous jog benne** | `M2_BucketJogLimit` actif (benne jogge lentement), M1 pilotée pour demander palier 4 | 20 cycles | `M1_StepNumber` == 4 (inchangé) ; `M2_StepNumber` ≤ 1 | **amendement A raté** : clamp benne bride M1 |
| HARN-41 | Bornes communes identiques | mouvement couplé, `SyncDeviationWarn` déclenché | 10 cycles | bornes de clamp communes **bit-à-bit identiques** sur les 2 instances (assert dédié) ; les 2 plafonnées à 1 | clamp M1≠M2 par duplication inline |
| HARN-42 | Plafond M2 propre n'affecte pas M1 | `ManualBucketLimitsActive` (FDC benne MAINT) | 10 cycles | M2 plafonné à 1 ; M1 libre selon sa demande | portée M2-only non respectée |
| HARN-43 | Shadow comparison (Phase A) | rejouer HARN-10..42 avec ancien + nouveau calcul de clamp actifs | toute la matrice | `clamp_ancien == clamp_nouveau` sur 100 % des cycles pendant ≥ N phases | divergence non détectée avant bascule |

### 3.5 Autorité des 2 interlocks (`HARN-5x`)

| id | scénario | entrées | séquence | oracle | attrape |
|---|---|---|---|---|---|
| HARN-50 | Nominal — filet passif | rejouer toute la matrice HARN-1x/2x/3x/6x | tous les cycles | `FinalInterlockGovernedM1` **et** `M2` == FALSE partout | code amont laisse la barrière gouverner |
| HARN-51 | Injection cadence hors instance FB_Winch | `InjectRateBypassFbWinch:=TRUE` (cadence > seuil safety appliquée en contournant l'instance interne) | 10 cycles | l'instance `PRG_06` **coupe** : `BusOutputs.MxRelayFwd/Rev` FALSE ; `FinalInterlockGoverned` TRUE + trace | filet PRG_06 inopérant |
| HARN-52 | Pas de double-freinage | marge instance `FB_Winch` active (cadence proche seuil), pas d'injection | 10 cycles | l'instance `PRG_06` reste passive (`Busy` interne PRG_06 FALSE) ; pas de coupure | interaction non voulue entre les 2 jeux de seuils |

### 3.6 Sync paire (`HARN-6x`)

| id | scénario | entrées | séquence | oracle | attrape |
|---|---|---|---|---|---|
| HARN-60 | Déviation croissante | mouvement couplé, modèle biaise M2 (vitesse-palier réduite) → écart croît | laisser l'écart passer le seuil | `SyncDeviationWarn` → plafond palier 1 **sur M1 ET M2** ; au-delà seuil critique → `SafeStop` des 2 | déviation ne se propage pas à M1 |
| HARN-61 | Retour dans la tolérance | après HARN-60, réaligner | 20 cycles | plafond relâché sur les 2 ; pas de latch intempestif | hystérésis manquante |

### 3.7 Sécurité (`HARN-7x`)

| id | scénario | oracle | attrape |
|---|---|---|---|
| HARN-70 | `EmergencyChainClosed:=FALSE` en mouvement couplé | `BusOutputs.M1/M2RelayFwd/Rev` FALSE **immédiat**, freins retombent | propagation AU rompue (déjà couvert par 1 test mégabloc, à garder) |
| HARN-71 | `Enable=FALSE` sur FB_Winch en marche | sorties sûres + latches ; pas de redémarrage auto au ré-Enable | garde `Enable=FALSE` cassée par un refactor |
| HARN-72 | Watchdog frein (`BrakeFeedback` ne suit pas l'ordre) | `FB_WinchOutputInterlock` défaut TON, coupe | TC-P10-012 |
| HARN-73 | Temps morts directionnels (inversion de sens après arrêt) | délai respecté avant réengagement sens opposé | TC-P10-021/022 (une seule implémentation, cohérente T175 AC2) |
| HARN-74 | Coast-down après relâche joystick lourd | `FB_Safety_Winch` Méca A **n'arme pas** pendant le coast (contacteurs pas encore retombés) → **pas** de `PowerCutOff` ; Méca B arme à 3 s | valide T178 en intégration (pas de faux `PowerCutOff`) |
| HARN-75 | Redémarrage à chaud (`FirstScanDone`) | après un cycle avec direction ≠ 0, ré-init : l'interlock direction n'est **pas** bypassé | piège `FirstScanDone` (revue archi) |

### 3.8 Croisement audit T180 (`HARN-8x`)

| id | CAS T180 | scénario | oracle |
|---|---|---|---|
| HARN-80 | CAS-001 | retombée d'un contacteur de sens **en marche** (feedback incohérent) | défaut détecté, mouvement neutralisé |
| HARN-81 | CAS-012 | demande benne pendant qu'un treuil agit (anti-traversée) | demande benne **refusée** (dépend de T175 AC3) |
| HARN-82 | CAS-002 | AU pendant une transition d'étape de cycle | coupure propre, pas d'état incohérent au réarmement |

---

## 4 · Oracles — comment on décide PASS/FAIL sans HIL

| Famille | Oracle déterministe | Ce que le harnais NE prouve PAS (→ essais site) |
|---|---|---|
| Grafcet / Joystick / Plongée | `StepNumber` attendu = fonction connue de `{SpeedPct, Direction, clamps}` ; table de référence figée dans la suite | la vitesse **physique** réelle du treuil, la dynamique hydraulique, le ressenti opérateur |
| Régression M1 / asymétrie | comparaison directe `M1_StepNumber` vs demande ; assert d'égalité bit-à-bit des bornes communes | le comportement câble réel (télescopage) sous charge |
| Autorité interlock | `FinalInterlockGoverned` booléen sur bus ; coupure `RelayFwd/Rev` observable | le temps de réaction électromécanique réel des contacteurs |
| Sync paire | `SyncDeviationM_Model` calculé, seuils connus | la déviation réelle induite par le câble commun + charge |
| Sécurité | latches, coupures, délais TON observables sur les bus | l'intégrité physique du frein, le coast-down réel en mètres |
| Coast-down (T178) | fenêtre d'armement Méca A observable (n'arme pas pendant contacteurs non retombés) | la distance de dérive réelle après lâcher de frein |

---

## 5 · Effort & séquencement

| Étape | Contenu | Effort |
|---|---|---|
| 5.1 | Étendre `FB_Main_EndToEnd` : entrées boutons/benne/plongée/injection, modèle position, sorties diag | **M** |
| 5.2 | Helpers suite de test : `%→raw` joystick, avance de N cycles, table de référence `StepNumber` par étape | **S** |
| 5.3 | Écrire `test_winch_integ.st` — familles HARN-1x à HARN-6x (nominal) | **M** |
| 5.4 | Familles HARN-7x / HARN-8x (sécurité + croisement T180) | **S** |
| 5.5 | Entrée registre `WINCH_INTEG` + gate dans `run_all_gates.py` | **S** |
| 5.6 | Plan de tir FAT / essais site / rollback / ordre d'import CODESYS (document séparé) | **S** |

### Critère de sortie de T181-00 (mesurable)

- `python TOOLS/TEST_AUTO_CI/scripts/run_tests.py --fb WINCH_INTEG` **compile et s'exécute** (peu importe le verdict initial — la baseline peut être rouge, elle sert de référence).
- Les 6 familles nominales (HARN-1x…6x) sont **écrites et exécutables**.
- Gate `WINCH_INTEG` présent dans `run_all_gates.py`, **rouge** tant que la cible n'est pas verte.
- Document plan de tir livré : ordre d'import CODESYS (§10 du plan), points de rollback par phase, checklist essais site.
- La **liste des vecteurs** est relue et validée par l'humain **avant** le démarrage de Phase 0.

---

## 6 · Notes d'implémentation

- **Ne pas** transformer le harnais en simulateur : le modèle physique se limite à `pos += v_palier·dt`
  et à l'écart de paire. `FB_WinchStepShaper` fournit la temporisation réelle.
- **`ST_fbCycle_WinchCmdDemand` inchangé** : les vecteurs Grafcet s'appuient sur `{StartStop, Direction, SpeedPct}` — ne pas laisser T181 fusionner ce DUT avec un refactor palier-INT (casse `test_fb_cycle`).
- Le harnais tourne sur l'interface **actuelle** de `FB_Winch` en Phase 0, puis sur `DriveRequest` en Phase A — prévoir les 2 branches d'appel dans le mégabloc (drapeau de compilation ou 2 entrées registre le temps de la bascule shadow).
- `FinalInterlockGoverned` : si le diag n'existe pas encore sur le bus PRG_06, l'ajouter est **dans le scope de T181-01** (contrat), pas de T181-00 — T181-00 le **consomme**.
