# FB_Translation — Spec composant (v1.1)

> Rôle machine (vague) : [`AF_Partie-11_Fonction_Translation_v2.3.md`](../AF_Partie-11_Fonction_Translation_v2.3.md) §4.
> Rôle de **ce** document : mouvement M3 (rampe, arbitrage, mot AC600, ralentissement PV,
> arrêt sur capteur, frein) — et **catalogue unique** des `TC-P11-003` à `TC-P11-005`, `TC-P11-013`.
> Compose `FB_Brake` (réutilisé depuis COMMUN) + `FB_Ramp` (continu %/s — contrairement aux treuils à paliers discrets).
> Source code : `CODE/I_TRANSLATION/FB_Translation.st` · instance `Translation.instTranslationM3`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Pipeline commande
4. Ralentissement d'approche (3 zones)
5. Arrêt exact sur capteur
6. Interlock de sens
7. Mot AC600
7bis. InvertDriveDirection — compensation câblage moteur
8. ErrorId
9. Réglages RETAIN / persistants
10. Alertes et écarts
11. Documents liés

## 🧪 Table des points de validation (détail)

> Propriétaire unique du catalogue détaillé de la plage indiquée (`TC-P11-003/004/005/013`) — ce catalogue fait foi ; le chapô AF ne le recopie pas.

> **État** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé, non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

<table style="width: 100%; table-layout: fixed; border-collapse: collapse; font-size: 14px;">
  <colgroup>
    <col style="width: 40px;">
    <col style="width: calc(100% - 170px);">
    <col style="width: 90px;">
    <col style="width: 40px;">
  </colgroup>
  <thead>
    <tr style="border-bottom: 2px solid #475569; text-align: left;">
      <th style="padding: 4px 1px; text-align: center;"><small><b>ID</b></small></th>
      <th style="padding: 4px 8px;">Intention / Comportement attendu</th>
      <th style="padding: 4px 1px; text-align: center;"><small>Type</small></th>
      <th style="padding: 4px 1px; text-align: center;"><small>État</small></th>
    </tr>
  </thead>
  <tbody>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P11-003</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;"><code>Enable=FALSE</code> coupe tout indépendamment de <code>SafeStop</code>/<code>StartStop</code></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>⚡ AUTO_PLC</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P11-004</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Ralentissement PV actif si <code>Direction=1</code> (Trémie) ET <code>SlowdownSensor</code></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>⚡ AUTO_PLC</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P11-005</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Interlock sens : bascule directe si vitesse=0, sinon délai 200ms</td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>⚡ AUTO_PLC</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
    <tr style="border-bottom: 1px solid rgba(255,255,255,0.08);">
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><span style="writing-mode: vertical-rl; transform: rotate(180deg); display: inline-block; font-family: monospace; font-size: 11.5px; font-weight: bold; letter-spacing: 0.5px;">TC-P11-013</span></td>
      <td style="padding: 6px 8px; line-height: 1.55;">Boutons IHM en MAINT exigent <code>DeadmanArmed=TRUE</code></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>⚡ AUTO_PLC</code></small></td>
      <td style="padding: 4px 1px; text-align: center; vertical-align: middle;"><small><code>NV</code></small></td>
    </tr>
  </tbody>
</table>

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
| `Direction` | INT | -1/0/+1 (sens **sémantique réel** — +1=vers Trémie, -1=vers Maintenance, quel que soit le câblage moteur) |
| `SpeedTgt_Pct` | REAL | Magnitude 0..100% |
| `PositionSensorTarget` | BOOL | Capteur position cible courante (verrou bistable §0quater PRG_05, voir fiche PositionDecoder §3bis) |
| `SlowdownSensorTremie` | BOOL | Capteur PV — ralentissement avant Trémie (`Direction=1`) |
| `SlowdownSensorMaintenance` | BOOL | 🆕 Zone P1→Maintenance — ralentissement avant Maintenance (`Direction=-1`) |
| `SlowdownSensorP1` | BOOL | 🆕 Zone P2→P1 — ralentissement avant P1 (`Direction=-1`), **gaté par le mode côté PRG_05** (désactivé si zone Maintenance autorisée — P1 n'est alors plus un point d'arrêt, 100% vitesse) |
| `LimitSwitchFwd`/`LimitSwitchRev` | BOOL | Butées extrêmes (depuis PositionDecoder, verrou bistable anti-rebond §0ter PRG_05) |
| `DriveStatusWord` | WORD | Mot état AC600 (EtherCAT) |
| `DriveActualFreqHz` | REAL | Fréquence réelle mesurée (Hz) |
| `InvertDriveDirection` | BOOL | 🆕 2026-08-06 : compense le câblage moteur réel (U/V inversés) — appliqué **uniquement** au mot de commande variateur en sortie (§7bis), jamais à `Direction`/`CommandedDirection` qui reste partout ailleurs le sens sémantique réel apparié aux capteurs physiques |
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
Enable maintenu — jamais une coupure sèche. La barrière finale (`FB_TranslationOutputInterlock`)
applique le gate double condition.

---

## 4. Ralentissement d'approche — 3 zones indépendantes (🆕 2026-08-06)

Généralisé de 1 à 3 paires capteur/cible indépendantes, chacune sa propre vitesse configurable
(`GVL_IHM.TranslationM3.Cfg.CfgApproachSpeedXxx_Hz`, persistante, voir §9) :

| Capteur | Sens | Cible ralentie | Formule (calculée dans PRG_05, cumulative — pas un mot exact) |
|---|---|---|---|
| `SlowdownSensorTremie` (=PV) | `Direction=1` | Approche Trémie | `TranslationPosPV` |
| `SlowdownSensorP1` | `Direction=-1` | Approche P1 (si P1 = point d'arrêt) | `NOT TranslationPosP2 AND TranslationPosP1 AND NOT MaintenanceM3TargetEnable` |
| `SlowdownSensorMaintenance` | `Direction=-1` | Approche Maintenance | `NOT TranslationPosP1 AND TranslationPosMaintenance` |

`RampTargetPct := LIMIT(0, RampTargetPct, ApproachSpeedXxxHz-based%)` pour chaque zone active.

⚠️ **Design opérateur confirmé terrain 2026-08-06** : en zone Maintenance **autorisée**, la zone
P2→P1 reste à 100% (P1 n'est plus un point d'arrêt, on continue jusqu'à Maintenance) — d'où le
gate `AND NOT MaintenanceM3TargetEnable` sur `SlowdownSensorP1`, appliqué côté `PRG_05`, pas
dans ce FB (qui reste agnostique du mode).

⚠️ **REX 2026-08-06** : la formule initiale de `SlowdownSensorP1`/`SlowdownSensorMaintenance`
manquait l'exclusion de la zone suivante (`AND NOT TranslationPosXxx`) — le ralentissement se
déclenchait dès la Trémie au lieu de juste avant la cible. Corrigé (`ced1df9`).

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

## 7bis. `InvertDriveDirection` — compensation câblage moteur (🆕 2026-08-06)

**REX sécurité terrain** : avant ce lot, la compensation câblage (`GVL_IHM.TranslationM3.Cmd.InvertDirection`)
était appliquée en amont dans `PRG_05_Translation.st`, directement sur `M3_Direction_Active` — le
sens **sémantique** consommé par TOUTE la logique appariée aux capteurs physiques réels
(ralentissement §4, coupure dure Fdc §5/§7, verrou d'arrivée §5). Avec le câblage moteur réel de
la machine (compensation nécessaire en permanence), ça désaccordait cette logique : le
ralentissement/verrou d'arrivée pouvait s'armer dans le mauvais sens ou jamais, seule la coupure
dure indépendante du sens (§0bis `PRG_05`) protégeait encore la machine.

**Corrigé** : `InvertDriveDirection` compense **uniquement** au point de génération du mot de
commande variateur (`PhysicalDriveDirection := SEL(InvertDriveDirection, CommandedDirection,
CommandedDirection * (-1))`, utilisé **seulement** pour `RequestedDriveControlWord`). `Direction`/
`CommandedDirection` reste partout ailleurs le sens sémantique réel (+1=vers Trémie physiquement),
apparié correctement aux capteurs quel que soit le câblage.

---

## 8. ErrorId

| Bit | Cause |
|---|---|
| 0 | Défaut frein (`Brake.Error`) |
| 3 | Défaut variateur AC600 (`DriveStatusWord.4`) |
| 6 | Butée extrême atteinte (nettoyé si `BypassLimitSwitch`) |

---

## 9. Réglages RETAIN / persistants

**Câblés directement depuis GVL_PERSISTENT** (scalaires, recopie continue ou valeur fixe) :
```
_TranslationMaxFreq_Hz=50.0
_TranslationRampAccelRate_Pct=40.0   (défaut usine)
_TranslationRampDecelNormal_Pct=50.0 (défaut usine)
_TranslationRampDecelFast_Pct=100.0
_TranslationAutoSpeedCap_Pct=40.0
_TranslationSetFreq_Hz=20.0 (défaut IHM, recopie continue depuis PRG_07_Supervision)
```

**Câblés via `GVL_IHM.TranslationM3.Cfg` (`ST_TranslationCfg`), pont `FB_CfgPersistBridge_TranslationCfg`
vers `GVL_PERSISTENT._TranslationCfgPersist`** (🆕 2026-08-06 — réglable en direct IHM, persistant) :
```
CfgApproachSpeedTremie_Hz=10.0
CfgApproachSpeedMaintenance_Hz=10.0
CfgApproachSpeedP1_Hz=10.0
```
⚠️ `GVL_PERSISTENT` est exclue du bundle PLCopenXML par conception (RETAIN géré par CODESYS) —
toute nouvelle variable persistante doit être ajoutée **manuellement** dans le projet CODESYS live.

**Position estimée continue (odométrie)** — 🆕 2026-08-06 : `FB_Translation_PositionEstimator`
reprend sa dernière position connue au redémarrage via `GVL_PERSISTENT._TranslationPosEstimated_M`
/`_TranslationPosEstimatedInitialized` (recopie continue, pas de bridge dédié — même doctrine que
`_TranslationSetFreq_Hz`), pour ne pas perdre l'estimation à chaque coupure/Online Change.

**Restent au défaut du FB** :
- `CaptorDebounce` = T#100ms
- `DirectionInterlockDelay` = T#200ms

---

## 10. Alertes et écarts

| # | Gravité | Point | Action |
|---|---|---|---|
| 1 | P2 | `ApproachSpeedPct`/`CaptorDebounce`/`DirectionInterlockDelay` non câblés RETAIN (doc legacy disait le contraire) | Corrigé §9 |
| 2 | info | `SetFreq_Hz=0` → défaut 30% codé en dur (mode MAINT) | Vestige mise en service |
| 3 | ✅ résolu | **`InvertDriveDirection` déplacé de l'arbitrage amont (`PRG_05`) vers ce FB** (2026-08-06) — voir §7bis. Désaccordait toute la logique de ralentissement/verrou d'arrivée avec le câblage moteur réel | REX terrain 2026-08-06 |
| 4 | ✅ résolu | Ralentissement généralisé à 3 zones indépendantes + gate mode Maintenance sur `SlowdownSensorP1` (§4) | REX terrain 2026-08-06 |

---

## 11. Documents liés

| Doc | Lien |
|---|---|
| AF11 (chapô) | Rôle machine, intégration programme |
| AF11 / FB_Safety_Translation | `SafeStop` consommé |
| AF11 / FB_TranslationOutputInterlock | Consommateur de la demande produite ici |
| AF11 / FB_Translation_PositionDecoder | Fournit butées extrêmes |
| AF03 | Contrat FB mouvement |
| Code | `CODE/I_TRANSLATION/FB_Translation.st` |
