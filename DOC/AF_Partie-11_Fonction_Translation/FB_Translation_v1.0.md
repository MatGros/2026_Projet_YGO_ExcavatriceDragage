# FB_Translation — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-11_Fonction_Translation_v2.0.md`](../AF_Partie-11_Fonction_Translation_v2.0.md) §4.
> Rôle de **ce** document : mouvement M3 (rampe, arbitrage, mot AC600, ralentissement PV,
> arrêt sur capteur, frein) — et **catalogue unique** des `TC-P11-003` à `TC-P11-005`, `TC-P11-013`.
> Compose `FB_Brake` (réutilisé depuis COMMUN) + `FB_Ramp` (continu %/s — contrairement aux treuils à paliers discrets).
> Source code : `CODE/TRANSLATION/FB_Translation.st` · instance `Translation.instTranslationM3`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Pipeline commande
4. Ralentissement PV
5. Arrêt exact sur capteur
6. Interlock de sens
7. Mot AC600
8. ErrorId
9. Réglages RETAIN
10. Alertes et écarts
11. Documents liés

## 🧪 Points de validation (`TC-P11-003/004/005/013` — propriétaire unique)

| ID | Intention / Comportement attendu | Type |
|---|---|---|
| TC-P11-003 | `Enable=FALSE` coupe tout indépendamment de `SafeStop`/`StartStop` | `⚡ AUTO_PLC` |
| TC-P11-004 | Ralentissement PV actif si `Direction=1` (Trémie) ET `SlowdownSensor` | `⚡ AUTO_PLC` |
| TC-P11-005 | Interlock sens : bascule directe si vitesse=0, sinon délai 200ms | `⚡ AUTO_PLC` |
| TC-P11-013 | Boutons IHM en MAINT exigent `DeadmanArmed=TRUE` | `⚡ AUTO_PLC` |

---

## 1. Rôle et profil

🔌 FB de **mouvement** (Partie3 §1bis) : porte `StartStop`+`SafeStop`. Précédence
`Enable > SafeStop > StartStop`. Pilotage **exclusivement EtherCAT** (mot de commande +
consigne fréquence). Compose `FB_Brake` (frein à manque de courant, partagé Winch) +
`FB_Ramp` (vraie rampe continue %/s — le variateur AC600 accepte une fréquence continue,
contrairement aux treuils à contacteurs discrets).

1 instance (`instTranslationM3`).

---

## 2. Interface

| Port entrée | Type | Sens |
|---|---|---|
| `Enable/Reset/PowerContactorEngaged/Mode` | — | Standard |
| `StartStop/SafeStop` | BOOL | Standard mouvement |
| `Direction` | INT | -1/0/+1 (source d'autorité du sens) |
| `SpeedRefPct` | REAL | Magnitude 0..100% |
| `PositionSensorTarget` | BOOL | Capteur position cible courante |
| `SlowdownSensor` | BOOL | Capteur PV — ralentissement avant Trémie |
| `LimitSwitchFwd`/`LimitSwitchRev` | BOOL | Butées extrêmes (depuis PositionDecoder) |
| `DriveStatusWord` | WORD | Mot état AC600 (EtherCAT) |
| `DriveActualFreqHz` | REAL | Fréquence réelle mesurée (Hz) |
| `BypassContactorCheck`/`BypassLimitSwitch` | BOOL | Bypass simulation/mise en service |
| `BrakeFeedback` | BOOL | Retour physique direct (TRUE=ouvert/desserré) |

**Sorties** : `Ready/Busy/Done/Error/ErrorId/State/StateAtError`, `TargetReached`,
`RequestedDriveControlWord` (WORD), `RequestedDriveFreqHz` (REAL), `BrakeReleaseRequest`,
`BrakeContactorCheck`.

---

## 3. Pipeline commande

1. **Gate** `Enable/PowerContactorEngaged` → neutralisation totale, RETURN.
2. **Debounce** `PositionSensorTarget` (100ms) → `TargetReached`.
3. **Précédence** Enable>SafeStop>StartStop pour la rampe.
4. **Ralentissement PV** (§4).
5. **Arrêt exact sur capteur** (§5).
6. **Rampe** `FB_Ramp` : DecelRate = `SEL(SafeStop, DecelNormal, DecelFast)`.
7. **Interlock sens** (§6).
8. **Mot AC600** (§7).
9. **Coupure immédiate** si butée extrême dans le sens commandé.
10. **Frein** `FB_Brake` composé.

`FB_Translation` **ne décide pas** la frontière finale : SafeStop produit une rampe rapide,
Enable maintenu — jamais une coupure sèche. La barrière finale (`FB_TranslationOutputInterlock_LD`)
applique le gate double condition.

---

## 4. Ralentissement PV

**Seulement** `Direction=1` (vers Trémie) **ET** `SlowdownSensor=TRUE` →
`RampTargetPct := LIMIT(0, RampTargetPct, ApproachSpeedPct)`.

⚠️ **Jamais en sens Maintenance** (Direction=-1) — décision client REX 2026-07-18 :
PV n'assure le ralentissement qu'avant Trémie.

---

## 5. Arrêt exact sur capteur et Verrou Anti-rebond (`DirectionAtArrival`)

`ArrivalLock` : dès qu'un capteur d'arrêt (TargetReached) ou un fin de course extrême est touché, le sens d'arrivée (`DirectionAtArrival`) est mémorisé.
Le verrou à zéro (`RampTargetPct = 0`) interdit tout réengagement dans le MÊME sens tant qu'un **changement de sens explicite en sens inverse** (`Direction = DirectionAtArrival * (-1)`) n'a pas été demandé par l'opérateur (un retour au neutre seul ne lève plus le verrou).

---

## 6. Interlock de sens

Neutre→sens = immédiat. Inversion directe Fwd↔Rev exige vitesse<0.1 **et** délai
`DirectionInterlockDelay`=200ms. Même logique que `FB_Winch` (partagé via `FB_Ramp.Current`).

---

## 7. Mot AC600 (Given Command 1, 0x3101)

| Valeur | Sens |
|---|---|
| 0 | None (arrêt) |
| 1 | Forward (marche avant) |
| 2 | Reverse (marche arrière) |
| 7 | Reset défaut variateur |

**Priorité** : Reset(7) > Error(0) > Mouvement(1/2) > Neutre(0).

Fréquence : `RequestedDriveFreqHz := (ABS(SpeedRamp.Current) / 100.0) * DriveFreqScaleMaxHz`.

---

## 8. ErrorId

| Bit | Cause |
|---|---|
| 0 | Défaut frein (`Brake.Error`) |
| 3 | Défaut variateur AC600 (`DriveStatusWord.4`) |
| 6 | Butée extrême atteinte (nettoyé si `BypassLimitSwitch`) |

---

## 9. Réglages RETAIN

**Réellement câblés depuis GVL_PERSISTENT** (via `FB_CfgPersistBridge_TranslationCfg.st` / `ST_TranslationCfg`) :
```
_TranslationMaxFreq_Hz=60.0
_TranslationRampAccelRate_Pct=20.0
_TranslationRampDecelNormal_Pct=40.0
_TranslationRampDecelFast_Pct=100.0
_TranslationAutoSpeedCap_Pct=40.0
_TranslationSetFreq_Hz=20.0 (défaut IHM)
CfgApproachSpeedTremie_Hz=15.0
CfgApproachSpeedMaintenance_Hz=15.0
CfgApproachSpeedP1_Hz=15.0
```

**Restent au défaut du FB** :
- `CaptorDebounce` = T#100ms
- `DirectionInterlockDelay` = T#200ms

---

## 10. Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | P2 | `ApproachSpeedPct`/`CaptorDebounce`/`DirectionInterlockDelay` non câblés RETAIN (doc legacy disait le contraire) | Corrigé §9 |
| 2 | info | `SetFreq_Hz=0` → défaut 30% codé en dur (mode MAINT) | Vestige mise en service |

---

## 11. Documents liés

| Doc | Lien |
|---|---|
| AF11 (chapô) | Rôle machine, intégration programme |
| AF11 / FB_Safety_Translation | `SafeStop` consommé |
| AF11 / FB_TranslationOutputInterlock_LD | Consommateur de la demande produite ici |
| AF11 / FB_Translation_PositionDecoder | Fournit butées extrêmes |
| AF03 | Contrat FB mouvement |
| Code | `CODE/TRANSLATION/FB_Translation.st` |