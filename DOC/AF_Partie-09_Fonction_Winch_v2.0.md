# Analyse Fonctionnelle — Partie 9 : Fonction Winch M1/M2 (v2.0)

> Rôle : mouvement treuils M1 (Retenue) / M2 (Benne), safety métier, synchro, barrière finale.
> Source code : `CODE/TREUILS/*.st` · instances dans `PRG_06_WinchControl` (mouvement), `PRG_03_Safety` (safety), `PRG_10_Outputs_LD` (finale).
> Extraction : `DOC/CHECKLISTS/EXTRACTIONS/FB_Winch_Extraction_Code_v1.0.md`.
> Benne (M2 sous-fonction) : voir AF12, annexée à ce domaine (pas de PRG/actionneur propre).
> v1.14 archivée : `ARCHIVES/Doc/AF_Partie-09_Fonction_Winch_v1.14.md`.

## 🧭 Sommaire

1. Composition et rôle
2. FB_Winch — mouvement
3. FB_Safety_Winch — 7 mécanismes (A-G)
4. FB_WinchSync — synchro niveau 1
5. FB_SpeedStep — paliers
6. FB_WinchOutputInterlock_LD — barrière finale
7. DUT et bus
8. Intégration programme
9. Alertes et écarts
10. Documents liés

## 🧪 Points de validation

| ID | Attendu | Type |
|---|---|---|
| TC-P09-001 | Méca A (bit7) : dérive>2.0m OU vitesse>0.02m/s, contacteurs+frein confirmés coupés, hors homing ⇒ SafeStop+PowerCutOff | AUTO |
| TC-P09-002 | Méca B (bit8) : perte CAN/neutre + non-confirmation arrêt sous 3s ⇒ SafeStop+PowerCutOff | AUTO |
| TC-P09-003 | Méca C (bit9) : dérive M1>2.0m pendant `BenneHoldStillActive` (M1 seul, jamais M2) ⇒ SafeStop+PowerCutOff | AUTO |
| TC-P09-004 | Méca D (bit11) : capteur haut hors homing + non-confirmation sous 3s ⇒ SafeStop+PowerCutOff ; neutralisé en descente | AUTO |
| TC-P09-005 | Méca E bit12 : écart>2.0m ⇒ SafeStop seul (pas PowerCutOff) | AUTO |
| TC-P09-006 | Méca E bit13 : bit12 non confirmé arrêté sous 3s ⇒ escalade PowerCutOff | AUTO |
| TC-P09-007 | Méca F (bit14) : sens mesuré opposé au sens commandé 500ms ⇒ SafeStop seul | AUTO |
| TC-P09-008 | Méca G (bit15) : vitesse nulle malgré commande 3s ⇒ SafeStop seul | AUTO |
| TC-P09-009 | `PowerCutOff` = exactement bits 2,7,8,9,10,11,13 (masque 16#2F84) | AUTO |
| TC-P09-010 | `SafeStop` exclut bit3 (mou câble) uniquement si `SyncEnable=FALSE` | AUTO |
| TC-P09-011 | Interlock sens : neutre→sens immédiat ; inversion directe exige vitesse<0.1 ET 200ms | AUTO |
| TC-P09-012 | Watchdog frein barrière finale 500ms : sans confirmation ⇒ FAULT, RestartInhibit | AUTO_PLC |
| TC-P09-013 | Anti-redémarrage : cause disparue + Reset + neutre observé + nouvelle demande distincte | AUTO_PLC |
| TC-P09-014 | Sync bit0 (écart>0.10m, 800ms) ⇒ SyncWarn IHM seul, pas de SafeStop direct (défaut) | AUTO |
| TC-P09-015 | Sync bit1 (incohérence commande, 500ms) ⇒ SafeStop fast | AUTO |
| TC-P09-016 | Couplage croisé : si `SyncActive`, arrêt sur un treuil coupe l'autre au même scan | AUTO |
| TC-P09-017 | Config palier invalide (`FB_SpeedStep`) ⇒ palier 0, sorties sûres | AUTO |
| TC-P09-018 | `StuckClosed` : contacteurs commandés off, retour non confirmé 500ms ⇒ bit1 | AUTO |
| TC-P09-019 | Ordre MainTask : Safety avant WinchControl avant Outputs_LD (frontière stricte) | AUTO+SITE |
| TC-P09-020 | Watchdog frein réel terrain (temps, contacteur/bobine) | SITE |

---

## 1. Composition et rôle

```text
FB_Winch (mouvement, ×2)
 ├─ FB_SpeedStep    (palier → 4 contacteurs)
 ├─ FB_Brake        (séquence frein manque-courant, partagé Translation)
 └─ FB_Ramp         (accel/décel)

FB_Safety_Winch (×2) ──► SafeStop / ForbidDescent / ForbidAscent / PowerCutOff
FB_WinchSync (×1)    ──► DeltaPosM, SyncWarn (niveau 1, warning)
FB_WinchOutputInterlock_LD (×2) ──► Q finales (barrière, dans PRG_10)
FB_WinchLoadEstimator (×2) ──► diagnostic charge, informatif
```

Benne = sous-fonction M2 (voir AF12) : aucune I/O propre, réutilise `FB_Winch` M2.

---

## 2. FB_Winch (FB de mouvement, Partie3 §1bis)

| Port entrée | Type | Sens |
|---|---|---|
| `Enable/Reset/PowerContactorEngaged/Mode` | — | Standard |
| `StartStop/SafeStop` | BOOL | Standard mouvement |
| `ForbidDescent`/`ForbidAscent` | BOOL | Interdictions dédiées (≠ SafeStop) |
| `Direction`/`SpeedRefPct` | INT/REAL | Consigne |
| `SpeedStepTable` | ST_SpeedStepTable | Table 5 paliers propre au treuil |
| `CfgMaxStepDescente` :=3 / `MaxStepAscent` :=5 | INT | Plafonds palier |
| `HomingApproachActive` | BOOL | Limite palier 1 en approche capteur haut |
| `FwdRevSpeedFeedbackOff`/`BrakeFeedback` | BOOL | Confirmation arrêt |
| `Homed`/`HomingSuspect`/`CablePosM` | — | Sortie Encodeurs |
| `TopLimitM` :=8.5 / `BottomLimitM` :=-20.0 | REAL | Limites actives |
| `CfgSlowdownDistanceM` :=1.0 / `CfgSlowSpeedPct` :=15.0 | REAL | Ralentissement approche |
| `SpeedGuardEnable`/`Ready` :=FALSE | BOOL | Garde-fou palier (désactivé, voir A5) |

**Sorties** : `Ready/Busy/Done/Error/State`, `ErrorId` (bit0 frein, bit1 contacteurs collés, bit2 config invalide), `RelayFwd/Rev`, `Contactor1..4`, `StepNumber`, `BrakeCmd`, `ContactorsCheck`.

**Interlock changement de sens** (vérifié code) : neutre↔un sens = immédiat ; inversion directe Fwd↔Rev exige vitesse<0.1 **et** délai 200ms. `DirectionChangePending` force cible rampe à 0 pendant l'attente.

**Plafonds dynamiques palier** :
| Condition | Plafond |
|---|---|
| Non référencé / HomingSuspect | 1 |
| Descente | `CfgMaxStepDescente` (3) |
| Montée + approche capteur haut | 1 |
| Montée normale | `MaxStepAscent` (5) |
| Neutre | 5 |

⚠️ Hausse palier : délai **1s500ms** hard-codé (pas paramétrable) — voir A2.

---

## 3. FB_Safety_Winch — 7 mécanismes (A-G)

| Méca | Bit | Armement | Déclenchement | Conséquence | Seuils |
|---|---|---|---|---|---|
| **A** Roue libre | 7 (0080) | contacteurs+frein confirmés coupés, hors homing | dérive>tolérance OU vitesse>seuil | SafeStop+**PowerCutOff** | `UncommandedDriftToleranceM`=2.0m, `UncommandedSpeedThresholdMps`=0.02 |
| **B** Pilotage sans commande | 8 (0100) | perte CAN OU joystick neutre | non confirmé arrêté sous délai | SafeStop+**PowerCutOff** | `PostRampTimeout`=3s |
| **C** Glissement M1/benne | 9 (0200) | `BenneHoldStillActive` (M1 seul) | dérive M1 > tolérance | SafeStop+**PowerCutOff** | `BenneSlipToleranceM`=2.0m |
| **D** Capteur haut non confirmé | 11 (0800) | capteur/limite log. atteint, hors homing, montée | non confirmé arrêté sous délai | SafeStop+**PowerCutOff** | `PostRampTimeout`=3s, marge +0.10m |
| **E** Sync critique (2 bits) | 12/13 (1000/2000) | SyncEnable, hors benne/homing | écart>tolérance (bit12) puis non confirmé (bit13) | bit12: SafeStop seul ; bit13: +**PowerCutOff** | `CriticalSyncToleranceM`=2.0m |
| **F** Sens opposé | 14 (4000) | mouvement commandé, hors homing | signe vitesse opposé, confirmé | SafeStop seul | seuil 0.02 m/s, délai 500ms |
| **G** Absence mouvement | 15 (8000) | idem F | vitesse sous seuil malgré commande | SafeStop seul | délai 3s |

**Autres bits** : 0 perte com opérateur · 1 perte codeur · 2 surchauffe moteur (+PowerCutOff) · 3 mou câble (SafeStop sauf SyncEnable=FALSE→ForbidAscent seul) · 4 rotation phase · 5 fin course haut (ForbidAscent) · 6 limite basse (ForbidDescent) · 10 thermique frein (+PowerCutOff).

**Masques vérifiés** :
```
SafeStop      = NOT PowerContactorEngaged OR (ErrorId AND 16#FF9F)  [SyncEnable=TRUE]
              = NOT PowerContactorEngaged OR (ErrorId AND 16#FF97)  [SyncEnable=FALSE, exclut bit3]
PowerCutOff   = (ErrorId AND 16#2F84) <> 0   → bits 2,7,8,9,10,11,13
ForbidDescent = bit6 OR NOT PowerContactorEngaged
ForbidAscent  = bit5 OR (capteur haut hors homing) OR (bit3 ET NOT SyncEnable)
```

**Bypass** : `BypassGlobal` (tout), `BypassSafety` (groupe PowerCutOff), `BypassProcess` (groupe SafeStop/Forbid), + individuels par méca.

---

## 4. FB_WinchSync (1 instance unique)

| Sortie | Sens |
|---|---|
| `DeltaPosM` | `ABS(CablePosM1-CablePosM2+ActiveOffsetM)`, calculé seulement si les deux Homed |
| bit0 | écart>`CfgSyncToleranceM`(0.10m) confirmé 800ms ⇒ `SyncWarn` IHM **seul**, pas SafeStop direct |
| bit1 | incohérence commandes (Relay/Contactor M1≠M2) confirmée 500ms ⇒ **grave**, remonté SafeStop fast côté PRG_06 |

**SyncActive selon Mode** : MAINT_N1=imposé · MAINT_N2=`SyncEnable` · Manuel/SemiAuto=TRUE défaut.

**Couplage croisé PRG_06** : si `SyncActive`, arrêt sur un treuil coupe l'autre **au même scan** (pas d'attente filtre). Suspendu pendant benne et en butée normale.

---

## 5. FB_SpeedStep (composé dans FB_Winch)

5 paliers, table propre par treuil (`ST_SpeedStepTable` : `P1R1..P5R4` + `StepThreshold_Pct[1..5]`). Sélection par 4× `HYSTERESIS` (`HystMargin`=2.0%). Validation config : seuils strictement croissants, cohérence contacteurs.

Garde-fou vitesse réelle (`SpeedGuardEnable`, désactivé par défaut) : bride palier 1 si non stable, ou `MeasuredSpeedBand` si dépassement.

---

## 6. FB_WinchOutputInterlock_LD (barrière finale, dans PRG_10)

| Élément | Valeur |
|---|---|
| Watchdog frein | 500ms — armé si `BrakeReleaseRequest AND NOT BrakeCommandOpenConfirmed` |
| Hausse palier | 1s250ms (≠ 1s500ms de FB_Winch — voir A2) |
| Anti-redémarrage | 900ms après `FwdRevSpeedFeedbackOff` confirmé |

**États** : DISABLED/READY/WAIT_BRAKE_CONFIRMATION/WAIT_STEP_DELAY/WAIT_RESTART_DELAY/FAULT.
**Anti-redémarrage complet** : cause disparue + front Reset + demande neutre observée + nouvelle demande distincte.

---

## 7. DUT et bus

| DUT | Producteur | Consommateur |
|---|---|---|
| `ST_WinchFinalInterlockRequest` | `PRG_06_WinchControl` | `PRG_10_Outputs_LD` |
| `ST_SpeedStepTable` | config IHM/RETAIN | `FB_Winch`/`FB_SpeedStep` |
| `ST_SafetyWinch` | `PRG_09_Supervision` (agrège) | IHM |
| `ST_BypassWinch` | IHM RETAIN | `FB_Safety_Winch` |
| `ST_ContactorCheck` (COMMUN) | `FB_Brake`/`FB_Winch` | `FB_Safety_Winch`, IHM |

---

## 8. Intégration programme

```text
PRG_03_Safety        instSafetyWinchM1/M2, instSpeedMonitorM1/M2, instLoadEstimatorM1/M2
PRG_06_WinchControl
  §1  instBucket (Benne, appelé EN PREMIER — évite fenêtre de commande manuelle parasite)
  §2  Arbitrage M1 (SEMI_AUTO / MAINT / joystick / boutons)
  §3  Arbitrage M2 (Benne prioritaire > SEMI_AUTO > joystick/boutons)
  §3bis Assistance maintenance (DiveSearch/ExtractionSequence)
  §3ter Coupure immédiate M1/M2 en fin de cycle benne
  instWinchSync (lu 1 scan après arbitrage)
  §5  Limites basses + couplage croisé
  §6/7 Exécution instWinchM1/M2
  §8  Publication ST_WinchFinalInterlockRequest → PRG_10
PRG_10_Outputs_LD    instWinchOutputInterlockM1/M2_LD (Q finales)
```

**Dépendances** : Joystick (`AxisCmdY`, `DeadmanArmed`), Modes (`JoystickWinchSelectArbitrated`, `InhibitM1/M2`, `SyncEnable`), Encodeurs (`CablePosM`, `Homed`, vitesse), Cycle (SEMI_AUTO).

---

## 9. Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | info | 7 mécanismes (A-G), pas 5 | Corrigé ce doc |
| 2 | P1 | 2 délais hausse palier en cascade (1s500+1s250) | À clarifier : voulu ou bug ? |
| 3 | P1 | `DelayMotorDecel` code mort (T87/T91) | Étude terrain requise |
| 4 | P2 | Rampe %/s peu pertinente (paliers discrets) | T93 non traité |
| 5 | **P1** | `SpeedGuardEnable` non persistant → perdu au download | T94 non résolu |
| 6 | P2 | Bandes vitesse théoriques jamais mesurées | T95 non résolu |
| 7 | info | Doc AF02 legacy décrit CFC générique ≠ PRG réels | Architecture cible à part |

---

## 10. Documents liés

| Doc | Lien |
|---|---|
| AF01 | AU/PowerCutOff — chaîne électrique |
| AF03 | Contrat FB mouvement |
| AF05 | Modes — InhibitM1/M2, SyncEnable |
| AF06 | E/S physiques treuils |
| AF10 | Codeurs — Homed, position, vitesse |
| AF12 | Benne — sous-fonction M2 |
| Code | `CODE/TREUILS/*.st`, `CODE/MAIN/PRG_06_WinchControl.st` |
