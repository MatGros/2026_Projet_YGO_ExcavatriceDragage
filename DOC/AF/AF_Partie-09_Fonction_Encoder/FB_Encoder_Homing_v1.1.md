# FB_Encoder_Homing — Spec composant (v1.1)

> Rôle machine : [`AF_Partie-09_Fonction_Encoder_v2.2.md`](../AF_Partie-09_Fonction_Encoder_v2.2.md)
> §5 — couvre `F09.02`, `F09.03`.
> Rôle de **ce** document : détail des 3 modes de référencement, cohérence redémarrage, RETAIN.
> Source code : `CODE/E_CODEURS/FB_Encoder_Homing.st` · sous-instance `instHoming` de `FB_Encoder`.

## 🧭 Sommaire

1. 🎯 Rôle et profil
2. 🧪 Points de validation (détail)
3. 🔌 Interface
4. 📍 Séquence homing (3 modes)
5. 🔍 Cohérence au redémarrage
6. 📊 `ErrorId`
7. ⚠️ Alertes et écarts
8. 📚 Documents liés

## 1 · 🎯 Rôle et profil

Contrat `standard` (AF03). Responsabilité unique : décider **quand** et **où** référencer, gérer
la RETAIN `ST_Encoder_Calib` (via `IN_OUT`). Ne lit pas le bus lui-même (reçoit `RawPos`/
`EncoderAvailable` déjà acquis par `FB_Encoder_Abs`) et ne met pas à l'échelle (`FB_Encoder_Scale`
consomme `HomingRefRaw` produit ici).

## 2 · 🧪 Points de validation (détail)

Décline `TC-P09-020` (chapô) :

| ID | Comportement attendu | Type | Réf |
|---|---|---|---|
| <nobr><code>TC-P09-020.1</code></nobr> | Nominal : front `Home` + front `TopPositionSensor` (dans les 2 ordres) → `HomingRefRaw` calculé pour `CablePosM = CfgTopSensorPosM` | <nobr><code>💻 AUTO</code></nobr> | §4 |
| <nobr><code>TC-P09-020.2</code></nobr> | Unitaire : front `Home` seul → cible `CfgHomingTargetM` | <nobr><code>💻 AUTO</code></nobr> | §4 |
| <nobr><code>TC-P09-020.3</code></nobr> | Dynamique : front `UseDynamicTarget` (ou combiné `Home`) → cible `DynamicHomingTargetM` (ex. auto-référencement benne M2) | <nobr><code>💻 AUTO</code></nobr> | §4 |
| <nobr><code>TC-P09-020.4</code></nobr> | Toute cible hors `[-99;+99]m` → homing refusé, `ErrorId` bit4, pas d'écriture RETAIN | <nobr><code>💻 AUTO</code></nobr> | §4 |
| <nobr><code>TC-P09-020.5</code></nobr> | Écart `RawPos`/`Calib.LastKnownRawPos` au boot > tolérance → `HomingSuspect=TRUE`, `Homed=FALSE` ; levé uniquement par front `BtnConfirmCoherence` **ET** `HomingPermit=TRUE` | <nobr><code>💻 AUTO</code></nobr> | §5 |

## 3 · 🔌 Interface

### Entrées (`VAR_INPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Enable` / `Reset` | `BOOL` | Standard |
| `Home` | `BOOL` | Demande référencement (front) |
| `HomingPermit` | `BOOL` | Autorisation de homer (calculée par l'appelant) |
| `BtnConfirmCoherence` | `BOOL` | Lève le doute incohérence boot (front) |
| `CfgHomingTargetM` | `REAL` | Cible homing unitaire (m) |
| `UseDynamicTarget` | `BOOL` | Active cible dynamique |
| `DynamicHomingTargetM` | `REAL` | Cible dynamique (calculée par l'appelant) |
| `CfgTopSensorPosM` | `REAL` | Cible homing nominal (déf. 8.5m) |
| `TopPositionSensor` | `BOOL` | Capteur physique position haute |
| `RawPos` | `UDINT` | Position brute (`FB_Encoder_Abs`) |
| `EncoderAvailable` | `BOOL` | Codeur disponible (`FB_Encoder_Abs`) |
| `PresetAck` / `PresetNak` | `BOOL` | Retour séquence preset (`FB_Encoder_Abs`) |
| `PointsPerRev` / `MultiTurnRevsMax` / `CableM_PerRev` | `UDINT`/`UDINT`/`REAL` | Constantes mécaniques |
| `BypassGlobal` | `BOOL` | Neutralise défauts bornage/cohérence (ne bloque pas le homing lui-même) |
| `FwdRevSpeedFeedbackOff` | `BOOL` | ⚠️ Déclaré, **jamais lu** dans la logique ni câblé par la façade `FB_Encoder` — port mort |
| `BrakeFeedback` | `BOOL` | ⚠️ Déclaré, **jamais lu** dans la logique ni câblé par la façade `FB_Encoder` — port mort |

### Sorties (`VAR_OUTPUT`)

| Port | Type | Rôle |
|---|---|---|
| `Ready` | `BOOL` | FB prêt |
| `Status` | `ST_FbStatus` | Statut (State machine INIT/READY/BUSY, ErrorId bitfield) |
| `PresetRequest` / `PresetValue` | `BOOL`/`UDINT` | Commande vers `FB_Encoder_Abs` |
| `Homed` | `BOOL` | `Calib.Homed AND NOT Calib.HomingSuspect` |
| `HomingSuspect` | `BOOL` | Incohérence boot à confirmer |
| `HomingRefRaw` | `UDINT` | Offset de référence brut (`Calib.HomingRefRaw`) |

### `IN_OUT`

| Port | Type | Rôle |
|---|---|---|
| `Calib` | `ST_Encoder_Calib` | RETAIN : `HomingRefRaw`, `LastKnownRawPos`, `Homed`, `HomingSuspect`, `RestartCoherenceTolerancePts` |

## 4 · 📍 Séquence homing (3 modes)

| Mode | Déclenchement | Cible |
|---|---|---|
| Nominal | `HomingModeOk AND NOT UseDynamicTarget AND ((Home AND front TopPositionSensor) OR (front Home AND TopPositionSensor))` | `CfgTopSensorPosM` |
| Unitaire | `HomingModeOk AND NOT UseDynamicTarget AND front Home` | `CfgHomingTargetM` |
| Dynamique | `HomingModeOk AND (front UseDynamicTarget OR (UseDynamicTarget AND front Home))` | `DynamicHomingTargetM` |

`HomingModeOk := HomingPermit`. Cible bornée `[-99;+99]m` avant écriture — hors plage, `ErrorId`
bit4, aucune écriture RETAIN. Sur succès : `Calib.HomingRefRaw`/`Homed` mis à jour, `PresetValue`
calculé (`HomingRefRaw + TargetPoints`), `PresetRequest` pulsé vers `FB_Encoder_Abs`.

### Chronogramme — mode nominal (bouton maintenu, capteur déclenche après)

| Instant | `Home` | `TopPositionSensor` | `Homed` |
|---|---|---|---|
| t0 — repos | FALSE | FALSE | FALSE |
| t1 — opérateur maintient `Home` | TRUE ↑ | FALSE | FALSE |
| t2 — capteur haut atteint | TRUE | TRUE ↑ | **TRUE** *(front capteur pendant `Home` maintenu)* |
| t3 — relâche `Home` | FALSE ↓ | TRUE | TRUE |

L'ordre inverse (front `Home` pendant que `TopPositionSensor` est déjà actif) donne le même
résultat — capture au **premier** front rencontré, jamais après un arrêt confirmé (répétabilité
vitesse d'accostage).

## 5 · 🔍 Cohérence au redémarrage

Une fois par session `Enable` (dès que `EncoderAvailable`) : `RawDiffRestart := RawPos -
Calib.LastKnownRawPos`. Si `Calib.Homed AND ABS(RawDiffRestart) > Calib.RestartCoherenceTolerancePts`
(déf. 1000 pts, ~12% d'un tour) → `Calib.HomingSuspect := TRUE`, `ErrorId` bit9. Levé **uniquement**
par front `BtnConfirmCoherence` **ET** `HomingPermit` — indépendant du `Reset` générique (pas
d'auto-effacement).

## 6 · 📊 `ErrorId`

| Bit | Cause | Catégorie |
|---|---|---|
| 0 | Homing demandé sans `HomingModeOk` | Auto-effaçable (recalculé chaque scan) |
| 4 | Cible hors plage `[-99;+99]m` | Auto-effaçable |
| 5 | Preset refusé/timeout (`PresetNak`) | Effacé par `Reset` (front) |
| 9 | Incohérence redémarrage | Levé uniquement par `BtnConfirmCoherence` |

Bits 1-3, 6-8 : libres, non utilisés (mineur, voir chapô §11 TBD).

## 7 · ⚠️ Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | info | `DynamicHomingTargetM`/`UseDynamicTarget` réellement câblés pour M2 (auto-référencement benne sur confirmation ouverture/fermeture, `PRG_02_Acquisition`) — M1 reste fixe `FALSE`/`0.0` | Vérifié code, voir chapô §4 |
| 2 | mineur | `FwdRevSpeedFeedbackOff`/`BrakeFeedback` déclarés en entrée, jamais lus ni câblés par la façade | Ports morts, à retirer lors d'un lot dédié (pas fait ici, hors périmètre doc) |

## 8 · 📚 Documents liés

| Doc | Lien |
|---|---|
| AF09 (chapô) | Rôle machine, façade `FB_Encoder`, architecture (homing dans `PRG_02_Acquisition`) |
| AF03 | Contrat `standard` |
| AF10 | Consommateur `Homed`/`HomingSuspect`, auto-référencement benne M2 |
| Code | `CODE/E_CODEURS/FB_Encoder_Homing.st` |
