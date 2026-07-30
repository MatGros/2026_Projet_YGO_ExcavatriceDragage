# Analyse Fonctionnelle — Partie 10 : Codeurs & Référencement (Homing) (v2.0)

> Rôle : mesure position/vitesse câble, référencement (homing), bornage et cohérence.
> Producteur unique position/vitesse pour tout le programme (Winch, Safety, Cycle, IHM).
> Source code : `CODE/CODEURS/*.st` · instances dans `PRG_02_Encoders`.
> Extraction : `DOC/CHECKLISTS/EXTRACTIONS/FB_Encoder_Extraction_Code_v1.0.md`.
> v1.11 archivée : `ARCHIVES/Doc/AF_Partie-10_Fonction_Encoder_Homing_v1.11.md`.

## 🧭 Sommaire

1. Rôle et pipeline
2. FB_Encoder_Abs — bus et preset
3. FB_Encoder_Homing — référencement
4. FB_Encoder_Safety — bornage et cohérence
5. FB_Encoder_Scale / SpeedMeasure / SpeedMonitor
6. DUT et bus
7. Intégration programme
8. Procédure terrain
9. Alertes et écarts
10. Documents liés

## 🧪 Points de validation

| ID | Attendu | Preuve | Type |
|---|---|---|---|
| TC-P10-001 | Preset : `PresetTriggerCmd=2` déclenche, `PresetAck` si écart ≤ tolérance sous timeout | `PresetSeqStep`, `PresetAck/Nak` | AUTO_PLC |
| TC-P10-002 | `RawPos` gelé si `EncoderAvailable=FALSE` | Forcer alarme bus, `RawPos` figé | AUTO_PLC |
| TC-P10-003 | Homing nominal rejeté si capteur haut non atteint (hors bypass) | Front `Home` sans capteur → bit4 | AUTO_PLC |
| TC-P10-004 | Homing rejeté si arrêt non confirmé (contacteurs+frein) | Front `Home` sans arrêt confirmé → bit2 | AUTO_PLC |
| TC-P10-005 | Unitaire refusé hors MAINT_N2 ou mauvais treuil sélectionné | bit0/bit1 | AUTO |
| TC-P10-006 | Cible hors [-99;+99] m rejetée sans écriture preset | bit4, `PresetRequest` reste FALSE | AUTO |
| TC-P10-007 | `HomingRefRaw` conforme à la formule ; `CablePosM` = cible après Done | Calcul vérifié | AUTO_PLC |
| TC-P10-008 | Incohérence redémarrage (écart > tolérance) ⇒ `HomingSuspect`, `Homed` masqué | Reboot simulé avec écart RawPos | AUTO_PLC |
| TC-P10-009 | `BtnConfirmCoherence` lève le doute sans réécrire la référence | Front → `HomingSuspect=FALSE`, `HomingRefRaw` inchangé | AUTO_PLC |
| TC-P10-010 | Bornage : position hors [-99;+99] m ⇒ gel + `EncoderIncoherent` | Forcer position hors plage | AUTO |
| TC-P10-011 | `EncoderFaultPresent` bloque SEMI_AUTO (repli MAINT_N1) | `SelMode:=SEMI_AUTO` avec défaut actif | AUTO_PLC |
| TC-P10-012 | Méca D (capteur haut non confirmé arrêté) ⇒ SafeStop+PowerCutOff sous 3 s | SITE — voir AF09 | SITE |

---

## 1. Rôle et pipeline

```text
FB_Encoder_Abs ──► FB_Encoder_Homing ──► FB_Encoder_Scale ──► FB_Encoder_Safety ──► FB_Encoder_SpeedMeasure
   (bus EtherCAT)    (référencement,        (pts → m)           (bornage,             (vitesse câble,
    RawPos/preset)     RETAIN Calib)                              cohérence boot)        50ms/6 éch.)
```

2 instances (M1/M2), toutes dans `PRG_02_Encoders` — **producteur unique** position/vitesse.
`FB_Encoder_SpeedMonitor` (diagnostic, `PRG_03_Safety`) : détecte variation brusque, **pas** de SafeStop direct.

---

## 2. FB_Encoder_Abs

| Port | Type | Sens |
|---|---|---|
| `Enable/Reset/PowerContactorEngaged/Mode` | — | Standard |
| `RawPosIn` | UDINT | Brut EtherCAT |
| `AlarmsIn` | UINT | Brut EtherCAT |
| `SlaveOperational` | BOOL | Sortie `FB_DiagEthercat` |
| `PresetRequest`/`PresetValue` | BOOL/UDINT | Pilotés par `FB_Encoder_Homing` |
| `RawPos` | UDINT | **Gelé** si `EncoderAvailable=FALSE` |
| `EncoderAvailable` | BOOL | `(ErrorId AND 1)=0` |
| `PresetAck`/`PresetNak` | BOOL | Pulses 1 cycle |

**Constantes** : `PointsPerRev=8192`, `PresetTimeout=T#2s`, `PresetTolerancePts=10`.

**Séquence preset** : `PresetTriggerCmd:=2` (constante confirmée terrain) → attend `|RawPos-PresetValueOut|<=10 pts` sous 2 s → `PresetAck` sinon `PresetNak`+bit1.

⚠️ `CodeSeqTriggerCmd` toujours `0`, rôle jamais confirmé (TODO ouvert de longue date).

---

## 3. FB_Encoder_Homing

| Port | Type | Sens |
|---|---|---|
| `Home` | BOOL (front) | Demande référencement |
| `UnitaryMode`/`WinchSelected` | BOOL | Flux unitaire MAINT_N2 |
| `CfgHomingTargetM` | REAL | Cible libre unitaire [-99;+99] |
| `BtnConfirmCoherence` | BOOL (front) | Lève doute sans réhoming |
| `TopPositionSensor` | BOOL | Capteur haut **unique, commun M1/M2** |
| `CfgTopSensorPosM` | REAL | Cible nominal — **valeur réelle 8.0 m** (défaut déclaré 8.5, ⚠️ voir §9) |
| `FwdRevSpeedFeedbackOff`/`BrakeFeedback` | BOOL | Confirmation arrêt |
| `Calib` (VAR_IN_OUT) | ST_EncoderCalib | RETAIN référence |

**ErrorId (vérifié code)** :
| Bit | Cause |
|---|---|
| 0 | Mode non autorisé |
| 1 | Mauvais treuil sélectionné |
| 2 | Arrêt non confirmé |
| 3 | Codeur indisponible |
| 4 | Cible hors plage OU capteur haut non confirmé |
| 5 | Preset refusé/timeout |
| 9 | Incohérence redémarrage |

⚠️ Bits 6/7/8 (legacy : relecture incohérente, position hors bornage, saut codeur) **non codés**.

**Calcul référence** :
```
PresetValueCalc = (PointsPerRev × MultiTurnRevsMax) / 2 = 16 777 216
TargetPoints    = TargetPositionM × PointsPerRev / CableM_PerRev
HomingRefRaw    = PresetValueCalc - TargetPoints
```

**Incohérence redémarrage** : au 1er cycle `EncoderAvailable=TRUE`, si `|RawPos-LastKnownRawPos| > RestartCoherenceTolerancePts` (défaut 1000 pts) ET `Homed=TRUE` ⇒ `HomingSuspect:=TRUE`, `Homed` masqué en sortie.

🔴 **Point ouvert (A2)** : `EncoderFaultPresent` (qui bloque SEMI_AUTO) vient de `FB_Encoder_Safety.EncoderIncoherent` (bornage + HomingSuspect relayé) — **PAS** directement de `Homed=FALSE`. Un treuil jamais référencé (mais jamais mis en doute non plus) ne bloque pas SEMI_AUTO. **Décision métier à trancher.**

---

## 4. FB_Encoder_Safety

| Port | Sens |
|---|---|
| `CablePosM` | Sortie Scale |
| `HomingSuspect` | Sortie Homing |
| `PositionMinM/MaxM` | ±99.0 m (dur) |

**ErrorId** (numérotation **locale**, différente de Homing) : bit0 = hors plage physique ; bit1 = incohérence boot (miroir `HomingSuspect`).
**Sortie** : `CablePosMSafe` gelée sur dernière valeur plausible si hors plage. `EncoderIncoherent = Error`.

---

## 5. FB_Encoder_Scale / SpeedMeasure / SpeedMonitor

**Scale** (calcul pur) : `CablePosM = (RawPos - HomingRefRaw) × CableM_PerRev / PointsPerRev` (`CableM_PerRev=2.0`).

**SpeedMeasure** : fenêtre fixe `T#50ms`, 6 échantillons horodatés (5 intervalles), `SamplePeriod=T#10ms`. `Valid` seulement si fenêtre complète. Purge sur `NOT Enable`, `Reset`, perte validité position, rebouclage `TIME()`.

**SpeedMonitor** (diagnostic seul, `PRG_03_Safety`) : compare vitesse cycle à cycle. ⚠️ Seuils câblés à **0 / T#0ms** actuellement → **ne peut jamais déclencher** (volontaire, en attente réglage T45). `SpeedStable` consommé par le garde-fou palier `FB_Winch.SpeedGuardReady`.

---

## 6. DUT et bus

| DUT | Champs clés | Producteur | Consommateur |
|---|---|---|---|
| `ST_EncoderCalib` | `HomingRefRaw`, `LastKnownRawPos`, `RestartCoherenceTolerancePts`(1000), `Homed`, `HomingSuspect` | `FB_Encoder_Homing` (VAR_IN_OUT) | lui-même, `FB_Encoder_Scale` |
| `ST_EncoderHMI` | `RawPos/Alarms/SlaveOperational/Error/ErrorId` | `PRG_09_Supervision` | IHM |
| `ST_WinchCfg` | `CfgTopSensorPos_M`, `CfgCableLimitAscent_M` | GVL_PERSISTENT (IHM) | `PRG_02/03/06` |
| `ST_WinchState` | `Homed/HomingBusy/.../HomingRefRaw/Encoder` | `PRG_09_Supervision` | IHM |
| `ST_WinchCmd` | `BtnHome/BtnConfirmCoherence/BtnHomingAtZero` | IHM | `PRG_02_Encoders` |

---

## 7. Intégration programme

```text
PRG_00  DI/simulation → HwIn.Winch.COD1/2_*
PRG_01  diag EtherCAT device
PRG_02  ← PRODUCTEUR UNIQUE position/vitesse
  1. instEncoderAbsM1/M2      (RawPos, EncoderAvailable)
  2. instHomingM1/M2          (Homed, HomingSuspect, HomingRefRaw) → écrit Calib RETAIN
  3. instEncoderScaleM1/M2    (CablePosM)
  4. instEncoderSafetyM1/M2   (CablePosMSafe, EncoderIncoherent) → EncoderFaultPresent
  5. instEncoderSpeedMeasureM1/M2 (MeasuredSpeed_Mps, SpeedValid)
PRG_03  instSpeedMonitorM1/M2 (diagnostic, seuils=0 actuellement)
PRG_04  EncoderFaultPresent → bloque SEMI_AUTO (repli MAINT_N1) — lu 1 scan après PRG_02
PRG_06  ForbidAscent, TopLimitM:=CfgCableLimitAscent_M (≠ CfgTopSensorPos_M — limite exploit. ≠ cible homing)
PRG_09  copie vers IHM
```

---

## 8. Procédure terrain

**Cotes réelles (RETAIN, MES-009)** — ⚠️ différentes du défaut déclaré :
| Paramètre | Défaut déclaré | Réel (RETAIN) |
|---|---|---|
| `CfgTopSensorPos_M` | 8.5 m | **8.0 m** |
| `CfgCableLimitAscent_M` | 8.0 m | **7.5 m** |

**Nominal** : monter M1+M2 au capteur haut → relâcher (arrêt confirmé) → `BtnHome` → `Homed` sur les 2 instances indépendamment. `HomingRefRaw` calculé, `CablePosM≈8.0m`.

**Unitaire (MAINT_N2)** : sélectionner treuil → manœuvrer → arrêt confirmé → `CfgHomingTargetM` → `BtnHome`.

**Bouton spécial** `BtnHomingAtZero` : force homing au centre exact (0.0 m), usage mise en service.

**Contrôle visuel `CfgTopSensorPos_M`** : référencer au capteur haut → descendre au contact visuel eau → si `CablePosM ≠ 0.00m`, ajuster `CfgTopSensorPos_M` de l'écart constaté (RETAIN) et répéter.

---

## 9. Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | **P0** | `Homed=FALSE` seul ne bloque pas SEMI_AUTO | **Décision utilisateur requise avant de figer en doc** |
| 2 | P1 | Bits 6/7/8 ErrorId Homing non codés | TBD legacy, non résolu |
| 3 | P1 | `CfgTopSensorPos_M` : 2 valeurs cohabitent (8.5 déclaré / 8.0 réel) | Corriger doc/déclaration |
| 4 | P2 | `CodeSeqTriggerCmd` jamais résolu | TODO ouvert |
| 5 | P2 | `SpeedMonitor` seuils inertes (0) | Volontaire jusqu'à T45 |
| 6 | info | `BtnHomingAtZero` non documenté avant | Documenté ici |
| 7 | info | Numérotation ErrorId différente par FB (pas de table unifiée) | Clarifié §3/§4 |

---

## 10. Documents liés

| Doc | Lien |
|---|---|
| AF02 | Acquisition, producteur unique |
| AF03 | Contrat FB mouvement (Homing n'en est pas un) |
| AF05 | Modes — MAINT_N1/N2, blocage SEMI_AUTO |
| AF06 | E/S physiques codeurs |
| AF09 | Winch — consommateur position/vitesse, Méca D |
| AF13 | Simulation codeurs |
| Code | `CODE/CODEURS/*.st`, `CODE/MAIN/PRG_02_Encoders.st` |
