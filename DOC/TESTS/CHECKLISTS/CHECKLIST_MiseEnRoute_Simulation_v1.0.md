# 🧪 CHECKLIST — Mise en route et test du banc de simulation (v1.0)

> 🎯 **Pour l'opérateur/automaticien.** Comment activer la simulation, quoi vérifier, dans quel ordre.
> 📅 2026-07-27 · Architecture **frontière unique** (lots L5/L6) — remplace l'ancienne procédure
> supprimée de `GVL_IHM.st` (elle décrivait un dispositif qui n'existe plus).
> 🔗 [PLAN_Rationalisation_Simulation](../AUDITS/PreLivraison/PLAN_Rationalisation_Simulation_v1.0.md)

---

## 1. 🧭 Le modèle en 30 secondes

```
   [%IX / PDO réels] ──► HwReal ─┐
                                  ├──► HwIn ──► PRG_00 §1 … PRG_10 ──► machine
   [FB_SimBench]     ──► HwSim ──┘
                            ▲
                            └── commandes du scan précédent (boucle fermée)
```

**5 variables pilotent la session** (`GVL_Simulation`) :

| Variable | Effet |
|---|---|
| `SimulationModeActive` | 🔑 bit maître. `FALSE` = machine réelle. **Rien n'est simulé sans lui** |
| `SimWinchActive` | M1+M2 : codeurs, contacteurs, freins, thermiques, capteur haut, câble tendu |
| `SimTranslationActive` | AC600 : mot d'état, fréquence, 5 capteurs de position, frein M3 |
| `SimOperatorActive` | Joystick : bus CANopen + `RawX`/`RawY`/`Button` |
| `SimSafetyActive` | Chaîne AU, contacteur de puissance, réarmement, phases, thermique frein, Kobold, hydraulique |

👉 **Un domaine est simulé OU réel — jamais un mélange.** C'est volontaire : mélanger réel et
simulé sur un même sous-ensemble est ce qui a masqué un vrai bug de polarité par le passé.

---

## 2. 🚦 Mise en route

| # | Action | Vérification |
|---|---|---|
| 1 | Machine **à l'arrêt**, pas de mouvement en cours | — |
| 2 | `GVL_Simulation.SimulationModeActive := TRUE` | rien ne doit bouger |
| 3 | Vérifier les 4 domaines automatiquement activés ; désactiver explicitement ceux à laisser réels | `GVL_IHM.Commun.Bypass.*` reflètent l'état simulé |
| 4 | Mode machine : `GVL_IHM.Modes.Cmd.SelMode := E_Mode.MAINT_N1` | `Modes.State.CurrentMode` suit |
| 5 | Acquitter les défauts : front sur `GVL_IHM.Modes.Cmd.BtnFaultReset` | `Modes.State.AnyFaultActive = FALSE` |

⚠️ **Le homme-mort reste RÉEL** même en simulation : il faut toujours « appuyer » (bouton réel, ou
`SimJoystickRawButton` si `SimOperatorActive`). C'est volontaire — cette sécurité n'est jamais
contournée.

---

## 3. ✅ Tests par domaine

### 3.1 🪝 Treuils — `SimWinchActive`

| # | Test | Attendu |
|---|---|---|
| 1 | Homing M1 puis M2 (`Cmd.BtnHome`, front) | `Homed = TRUE`, `Position_M` se cale sur `CfgTopSensorPos_M` (**8,0 m**) |
| 2 | Montée joystick (homme-mort + Y) | `RelayFwd`, position **croît**, paliers s'enchaînent |
| 3 | Descente | position **décroît**, `RelayRev` |
| 4 | Relâcher le joystick | rampe de décélération puis **frein serré**, contacteurs retombés |
| 5 | **Aucun défaut contacteur/frein ne doit apparaître** | 🎯 si `FB_Brake` `StuckOpen`/`StuckClosed` ou `ContactorsCheck` déclenche, c'est un **écart du modèle** → me le signaler, **ne pas bypasser** |
| 6 | Injection écart synchro : front `SimSyncDeviationInjectM1`, `SimSyncDeviationOffset_M := 0.5` | ralentissement + arrêt (Concept 1) |
| 7 | Idem avec `2.5` (> 2,0 m) | **Méca E** : `SafeStop` M1+M2 |
| 8 | Monter jusqu'à `CfgTopSensorPos_M` | capteur haut simulé actif → `ForbidAscent` |

### 3.2 ↔️ Translation — `SimTranslationActive`

| # | Test | Attendu |
|---|---|---|
| 1 | « Aller à » P1, P2, Trémie, Maintenance | trajet simulé, position atteinte, arrêt |
| 2 | Passage en zone PV avant Trémie | **ralentissement** avant l'arrêt trémie |
| 3 | Forcer un mot valide : `SimM3SensorsWordOverrideActive := TRUE`, `SimM3SensorsWord := 2#11111` | position Trémie, `SensorWordIncoherent = FALSE` |
| 4 | Forcer un mot **incohérent** : `2#10101` | `SensorWordIncoherent = TRUE` → `SafeStop` + `PowerCutOff` |
| 5 | Butées extrêmes Trémie / Maintenance | mouvement bloqué dans le sens interdit |

### 3.3 🕹️ Opérateur — `SimOperatorActive`

| # | Test | Attendu |
|---|---|---|
| 1 | Un bouton `SimJoystick*Active` unique + `SimJoystickRawButton := TRUE` | déflexion 100 % vue par `FB_Joystick`, homme-mort armé |
| 2 | Retour à `5000` + relâcher | consigne nulle, désarmement après `NeutralHoldTime` (500 ms) |
| 3 | Diagnostics bus | aucun faux défaut CANopen |

### 3.4 🧨 Machine / AU — `SimSafetyActive`

| # | Test | Attendu |
|---|---|---|
| 1 | Séquence de réarmement (`Modes.Cmd.BtnEmergencyArming`) | auto-test A/B → contacteur confirmé → `PowerContactorEngaged = TRUE` |
| 2 | Couper la chaîne simulée | `SafeStop` immédiat, freins serrés |
| 3 | Kobold : `SimKoboldContactValue` | ⚠️ voir T81 — la logique de détection de fond est **connue comme incomplète** aujourd'hui |

---

## 4. 🔍 Savoir quand basculer un domaine en réel

Les trois images ont **les mêmes champs** et sont lisibles côte à côte en vue instance CODESYS :

```
   HwReal            ── ce que dit le matériel, brut
   HwSim             ── ce que le banc attend
   HwIn              ── ce que le programme utilise
```

**Méthode**, capteur par capteur :

1. Câbler physiquement le capteur, machine **à l'arrêt**
2. Ouvrir `PRG_02_Acquisition` en vue instance et comparer `HwReal.<domaine>.<signal>`
   et `HwSim.<domaine>.<signal>`.
3. Comparer `HwIn` à la source active.
4. **Valeurs identiques** → le réel dit déjà ce que le modèle attend → bascule sûre
5. **Valeurs opposées** → le fil est absent **ou la polarité est inversée** → à instruire
   *avant* de couper la simulation du domaine

⚠️ Ne comparer que les **grandeurs logiques** (retours contacteurs, freins, capteurs TOR, états
devices). Une position codeur ou une fréquence M3 ne sont pas comparables : le banc ne prétend pas
prédire une valeur réelle.

ℹ️ **Il n'existe volontairement aucun comparateur automatique** (décision D11) : le modèle n'est
pas une vérité de référence, et un indicateur qui clignote à chaque transitoire finirait ignoré.
Pour un verdict d'état machine, voir `FB_Acquisition_Preflight` (plan Ergonomie, à venir).

## 5. 🔚 Retour en machine réelle

| # | Action |
|---|---|
| 1 | `SimulationModeActive := FALSE` — le front descendant désactive les 4 domaines et remet les stimuli au nominal |
| 2 | Vérifier `SimEncoderSpeedFactor = 1.0` |
| 4 | Relire les **bypass actifs** (`GVL_IHM.*.Bypass.*`) et les remettre à `FALSE` s'ils ne sont pas voulus — ils sont **RETAIN** |
| 5 | Vérifier `Modes.State.AnyFaultActive = FALSE` avant tout mouvement réel |

⚠️ **Avant livraison client** : `SimulationModeActive = FALSE`, les 4 domaines à `FALSE`,
et `Network.Bypass.IhmHeartbeat` remis à `FALSE` (**T83**).

---

## 6. 🚨 Ce qui doit m'être remonté

| Constat | Pourquoi c'est important |
|---|---|
| Un défaut contacteur ou frein en simulation | Le modèle diverge du réel — **jamais à bypasser** |
| Un mot capteurs M3 incohérent non provoqué | Modèle de trajet ou codage croisé à revoir |
| Un blocage sans cause affichée | Manque de diagnostic → alimente le plan Ergonomie MES |
| Un écart `HwReal` ↔ `HwSim` inexpliqué machine saine | Polarité ou câblage |

📝 Consigner chaque séance dans `DOC/TESTS/REGISTRES/REGISTRE_Suivi_MiseEnService.md`.
