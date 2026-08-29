# FB_Sim_Joystick — Spec composant (v1.0)

> Rôle machine (vague) : [`AF_Partie-13_Fonction_Simulation_v2.4.md`](../AF_Partie-13_Fonction_Simulation_v2.4.md) §4.
> Rôle de **ce** document : entrées brutes joystick simulées (bus CAN hors ligne) — et
> **catalogue unique** des `TC-P13-050...`.
> Source code : `CODE/L_SIMULATION/FB_Sim_Joystick.st` · instance `FB_SimBench.instSimJoystick`.

## 🧭 Sommaire

1. Rôle et profil
2. Interface
3. Homme-mort — jamais contourné
4. Documents liés

## 🧪 Points de validation (`TC-P13-050...` — propriétaire unique)

> **État** — `V` validé, implémentation non vérifiée · `V-I` validé et implémenté · `NV` non validé, non implémenté · `NV-I` code présent mais non validé · `R` refusé · `NA` non applicable.

| ID | Intention / Comportement attendu | Type | Etat |
|---|---|---|---|
| <nobr><code>TC-P13-050</code></nobr> | Initialise au neutre (`NeutralRaw`) au premier cycle uniquement | `💻 AUTO` | `NV` |
| <nobr><code>TC-P13-051</code></nobr> | `RawX`/`RawY`/`RawButton` restent forçables librement en instance CODESYS ensuite | `👁️ MANUEL` | `NV` |
| <nobr><code>TC-P13-052</code></nobr> | Le homme-mort réel de `FB_Joystick` reste actif — un `RawButton` non forcé bloque toujours l'armement | `⚡ SITE+AUTO` | `NV` |

---

## 1. Rôle et profil

🎯 Remplace l'ancien bypass homme-mort codé en dur dans `FB_Joystick`
(`GVL_DEBUG.DBG_DeadmanBypass_TEST`, qui forçait `DeadmanArmed` en permanence — un vrai
contournement de sécurité, retiré). Ce FB simule uniquement les **entrées brutes** du capteur
(`RawX`/`RawY`/`RawButton`) : le homme-mort réel de `FB_Joystick` reste pleinement actif et doit
toujours être « actionné » (forcer `RawButton` en instance CODESYS) pour armer — comportement
métier testé pour de vrai, pas contourné.

🧩 Brique réduite (`AF_Partie-03 §2`) : outil de banc, pas de contrat `Enable/Reset/Error`.

---

## 2. Interface

| Entrée | Type | Sens |
|---|---|---|
| `Enable` | BOOL | Simulation active (`SimulationModeActive AND NOT BusJoystickSignalIsReal`) — granularité séparée du bus CANopen (`BusJoystickIsReal`) |
| `NeutralRaw` | INT | Valeur brute simulée au repos (défaut 5000) |
| `MaxRaw` | INT | Valeur brute simulée à fond (défaut 10000) |

| Sortie | Type | Sens |
|---|---|---|
| `RawX`/`RawY` | INT | Forçables en instance CODESYS, défaut = `NeutralRaw` |
| `RawButton` | BOOL | Forçable en instance CODESYS, défaut = `FALSE` (relâché) |

---

## 3. Homme-mort — jamais contourné

En vue instance CODESYS, forcer `RawX`/`RawY` à `MaxRaw` (ou une valeur intermédiaire) pour
simuler un débattement, et `RawButton` à `TRUE` pour simuler l'appui homme-mort — exactement
comme on forcerait le vrai capteur. Le FB initialise au neutre une seule fois (`FirstCycle`) puis
n'écrit plus jamais ces sorties : un `Force` CODESYS n'est jamais écrasé par une réaffectation
cyclique, condition nécessaire pour que le forçage tienne dans la durée.

---

## 4. Documents liés

| Doc | Lien |
|---|---|
| AF13 (chapô) | Frontière simulation, granularité `SimOperatorActive` |
| AF08 / FB_Joystick | Consommateur réel — homme-mort, `DeadmanArmed` |
| Code | `CODE/L_SIMULATION/FB_Sim_Joystick.st`, `CODE/D_JOYSTICK/FB_Joystick.st` |
