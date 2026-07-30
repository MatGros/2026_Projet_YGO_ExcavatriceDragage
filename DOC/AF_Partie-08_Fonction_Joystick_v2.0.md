# Analyse Fonctionnelle — Partie 8 : Fonction Joystick (v2.0)

> Rôle : acquisition et conditionnement du geste opérateur (Hall CANopen → consignes d'axe).
> **Pas** un FB de mouvement : pas de `SafeStop` / pas de pilotage Q.
> Source code : `CODE/JOYSTICK/FB_Joystick.st` · instance `PRG_01_Diagnostics.instJoystick`.
> Extraction : `DOC/CHECKLISTS/EXTRACTIONS/FB_Joystick_Extraction_Code_v1.0.md`.
> v1.3 archivée : `ARCHIVES/Doc/AF_Partie-08_Fonction_Joystick_v1.3.md`.

## 🧭 Sommaire

1. Rôle et périmètre
2. Pipeline et composition
3. Interface et contrats
4. Homme-mort
5. Calibration et défauts
6. Intégration programme
7. IHM
8. Alertes et écarts
9. Documents liés

## 🧪 Points de validation

| ID | Attendu | Preuve | Type | Détail |
|---|---|---|---|---|
| TC-P08-001 | Perte contacteur puissance, CAN ou joystick non OP ⇒ sorties axes à 0 et `DeadmanArmed=FALSE` | `SpeedRef=0`, `StartStop=FALSE` | AUTO+SITE | §3 |
| TC-P08-002 | Homme-mort : armement seulement par front bouton au neutre ; sans armement, la rampe cible 0 | `DeadmanArmed` puis `SpeedRef→0` | AUTO+SITE | §4 |
| TC-P08-003 | Présence : bouton relâché > 10 s en mouvement ⇒ désarmement et décélération normale | `DeadmanArmed=FALSE` | AUTO+SITE | §4 |
| TC-P08-004 | Neutre : traversée < 500 ms conserve l'armement ; neutre tenu >= 500 ms après geste désarme | `DeadmanArmed` attendu | AUTO | §4 |
| TC-P08-005 | Changement de mode ou fin benne désarme ; seule Extraction `CLOSING_BUCKET` peut préserver l'armement | câblage + états | AUTO | §4, §6 |
| TC-P08-006 | Calibration : hors [2000;8000] ⇒ bit0 ; Reset front seulement cause disparue | `ErrorId` | AUTO | §5 |
| TC-P08-007 | Contrat consigne : `SpeedRef` signé [-100;+100], `StartStop` sur magnitude ; pas d'entrée `SafeStop` | interface `ST_AxisCmd` / FB | AUTO | §1, §2 |
| TC-P08-008 | Winch, Translation et Cycle exigent `DeadmanArmed` en plus de la consigne | linkage PRG_05/06/07 | AUTO | §6 |

---

## 1. Rôle et périmètre

| Fait | Détail |
|---|---|
| Entrée | 2 axes bruts 0..10000 + 1 bouton, nœud CANopen (ou sim amont) |
| Sortie | `ST_AxisCmd` X/Y + `DeadmanArmed` + miroirs maintenance |
| Fait | Producteur d'**intention** de conduite, pas d'actionneur |
| Ne fait pas | Arbitrage mode, limites machine, frein, PowerCutOff, Q physiques |

Profil AF03 : brique métier non-mouvement. Gate : `Enable`, `PowerContactorEngaged`, diag CAN/device.

---

## 2. Pipeline et composition

```text
Raw ─► FB_AxisScale ─► FB_Filter_PT1 ─► FB_Ramp ─► ST_AxisCmd
         deadband %        τ filtre         accel/decel
                    ▲
              homme-mort force Target rampe = 0 si non armé
```

| Brique | Rôle |
|---|---|
| `FB_AxisScale` | Neutre + deadband → % signé, borné ±100 |
| `FB_Filter_PT1` | Lissage ; `CycleTimeS` via `FB_CycleTime` interne |
| `FB_Ramp` | Accel / décel (décel plus rapide par défaut) |
| Homme-mort | Sélectionne cible rampe : 0 ou sortie filtre |

`ST_AxisCmd` :

| Champ | Sens |
|---|---|
| `Enable` | TRUE quand pipeline actif |
| `StartStop` | TRUE si `ABS(SpeedRef) > 0.1` |
| `SpeedRef` | % **signé** −100..+100 |
| `Direction` | −1 / 0 / +1 (seuil ±0,1 sur rampe) |

Paramètres d'appel production (`PRG_01`) : deadband / filtre / rates depuis `GVL_PERSISTENT` ;
`DeadmanRearmTimeout=T#10s`, `NeutralHoldTime=T#500ms`.

---

## 3. Interface publique (code actuel)

### Entrées

| Port | Producteur actuel |
|---|---|
| `Enable` | `TRUE` fixe dans PRG_01 |
| `Reset` | `FaultMachineReset_IHM` |
| `PowerContactorEngaged` | `PRG_00_Inputs.PowerContactorEngaged` |
| `Mode` | `PRG_04_Modes.instModes.Mode` (scan N−1) |
| `BenneBusy` | `PRG_06.instBucket.Busy` (scan N−1) |
| `PreserveArmingAfterBucket` | Extraction Busy **et** état `CLOSING_BUCKET` |
| `BusCanOpenOP` / `JoystickOP` | `FB_DiagCanOpen` |
| `RawX/Y`, `RawButton` | `PRG_00.HwIn.Operator` |
| `BtnCalibrate` | `GVL_IHM.JOY1Joystick.Cmd.BtnCalibrate` |
| `Invert*`, `Deadband`, `FilterTime`, `AccelRate`, `DecelRate` | PERSISTENT |
| `NeutralXMem/YMem` | `VAR_IN_OUT` persistants |

### Sorties

| Port | Rôle |
|---|---|
| `AxisCmdX/Y` | Consignes normalisées |
| `Speed*Pct` / `Direction*` | Miroirs plats (maintenance) |
| `Button` | = `RawButton` (pas de filtre dédié) |
| `Neutral*Act` | Neutres actifs |
| `DeadmanArmed` | Geste armé |
| `Ready/Busy/Done/Error/ErrorId` | État FB |

**Gate** (`Enable` / `PowerContactorEngaged` / master CAN OP / device OP) :
sorties axes à 0, `DeadmanArmed=FALSE`, timers deadman reset, `RETURN`.

---

## 4. Homme-mort

### Armement
Front bouton **et** `ScaleX.OutPct=0` **et** `ScaleY.OutPct=0` (après deadband, **avant** filtre/rampe).

### Désarmement
| Cause | Condition |
|---|---|
| Gate | Enable / AU / CAN / device |
| Neutre tenu | Après avoir quitté le neutre une fois (`LeftNeutralSinceArm`), neutre ≥ 500 ms |
| Timeout présence | Armé + hors neutre + bouton **relâché** ≥ 10 s |
| Changement mode | `Mode <> LastMode` |
| Fin benne | Front descendant `BenneBusy` **si** `NOT PreserveArmingAfterBucket` |

Maintenir le bouton **ou** le réappuyer en mouvement remet le timer 10 s (niveau, pas seulement front).

### Exception Extraction (documentée)
`PreserveArmingAfterBucket` évite le désarmement en fin de fermeture auto pour enchaîner palier 1
sous interlocks Extraction. **Hors** cet état, toute fin benne désarme (pas de M1/M2 surprise).

⚠️ Désarmement ⇒ cibles rampe à 0 ⇒ **décélération normale**, pas coupure puissance.

---

## 5. Calibration et défauts

| Règle | Détail |
|---|---|
| Front `BtnCalibrate` | Si RawX/Y ∈ [2000 ; 8000] → écrit neutres mem |
| Sinon | `ErrorId` bit0 (`16#0001`) |
| Reset | Front + Raw encore dans plage → clear bit0 |
| Neutres | Persistants (`_JoystickNeutralX/Y`) |

---

## 6. Intégration programme

```text
PRG_00  HwIn.Operator (réel/sim)
PRG_01  Diag CAN + instJoystick          ← producteur unique consignes joy
PRG_04  Mode (lu N−1 par joy)
PRG_05  CycleMotionPermit := DeadmanArmed AND AxisCmdY.StartStop
PRG_06  Winch : joy + DeadmanArmed + sélecteur treuil
PRG_07  Translation : AxisCmdX + DeadmanArmed
PRG_09  Mapping IHM JOY1Joystick.State
```

Consommateurs **doivent** combiner `AxisCmd*.StartStop` **et** `DeadmanArmed`
(déjà le cas Winch/Trans/Cycle — TC-P08-013).

Cible archi AF02 : Joystick reste dans le domaine **Acquisition** (page CFC acquisition),
pas une page mouvement.

---

## 7. IHM

| DUT | Contenu |
|---|---|
| `ST_JoystickCmd` | `BtnCalibrate` |
| `ST_JoystickState` | Raw, AxisCmd, neutres, DeadmanArmed, Online/OP, Error |

Réglages invert/deadband/rates : PERSISTENT (pas tous dans Cmd IHM — détail P07 / code).

---

## 8. Alertes et points ouverts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | info | Doc v1.3 disait encore debug/`SafeStop`/IsCentral | **Corrigé** par v2.0 |
| 2 | P1 métier | Exception `PreserveArmingAfterBucket` | Ne jamais élargir hors CLOSING Extraction |
| 3 | info | Retard 1 scan Mode/BenneBusy → deadman | Accepté ; ne pas « corriger » par GVL |
| 4 | info | `Enable` toujours TRUE | OK si aval Modes/Safety tiennent ; pas de gate Modes dans le joy |
| 5 | mineur | Miroirs Speed/Direction dupliquent AxisCmd | Garder pour MES ; pas de 3ᵉ copie |
| 6 | — | `IsCentralPositionX/Y` | **Absents du code** — neutre = deadband Scale / seuil 0,1 rampe |
| 7 | site | Checklist MES joy | Exécution terrain (ex-T17) hors cette AF |

Pas de surcharge identifiée justifiant un refactor immédiat du FB : composition claire,
une instance, gate fail-safe.

---

## 9. Documents liés

| Doc | Lien |
|---|---|
| AF02 | Acquisition / pas page joy autonome |
| AF03 | Profil non-mouvement, Reset front |
| AF05 | Modes, sélecteur treuil, désarmement au change mode |
| AF06 | Raw Operator / sim |
| AF07 | `ST_JoystickHMI` |
| AF09 / AF11 / AF12 | Consommateurs AxisCmd + DeadmanArmed ; exception Extraction |
| AF13 | `FB_Sim_Joystick` amont |
| Code | `CODE/JOYSTICK/FB_Joystick.st`, `FB_AxisScale.st`, `FB_Filter_PT1.st`, `ST_AxisCmd.st` |
