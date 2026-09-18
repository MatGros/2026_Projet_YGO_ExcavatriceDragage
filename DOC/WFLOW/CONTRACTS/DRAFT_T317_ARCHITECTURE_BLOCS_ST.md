# 🧩 T317 — Draft architecture blocs ST (à challenger, PAS encore du code)

📌 Statut : proposition d'architecture uniquement — interfaces et responsabilités, aucun ST écrit.
Objectif : pré-câbler la décomposition en FB avant validation R0 définitive (portée sécurité vs
macro, cf. plan T317), pour ne pas partir dans une direction incompatible avec le socle projet.

Base : pattern déjà validé sur T300 (`FB_Sim_Translation`, `FB_Sim_TranslationDrive`,
`FB_Sim_TranslationBrake`, `FB_Sim_SuspendedLoad`, `FB_Sim_PositionSensor`) — 1 FB = 1
responsabilité physique, composition dans un FB parent `FB_Sim_Winch*`.

## Données réelles injectées (recherche 2026-09-18, `PRG_04_Treuils_Benne.st`)

- 5 paliers de vitesse (`StepNumber 1..5`), 4 contacteurs par treuil (`_SpeedContactor_1..4`)
- `StepRampDelayAscent = 700ms` / `StepRampDelayDescent = 500ms` (déjà en dur, identiques M1/M2)
- MainTask 10ms (`CST_SimBenchCycleTimeS`)

## Profil FB proposé : 🔧 Brique technique, contrat `light`

Justification (AF_Partie-03 §3) : ces FB sont des calculateurs physiques purs, sans cycle de vie,
qui ne remontent aucun défaut — `Enable : BOOL` + `Ready : BOOL` uniquement. Aucun `PowerContactorEngaged`
(ils ne pilotent aucun organe physique, ils *simulent* la réaction d'un organe). À trancher en
revue : si un des FB doit remonter un défaut de modèle (ex. paramètre hors domaine), il bascule en
`standard` — à valider R1.

## Blocs proposés (🆕 noms corrigés après challenge 2026-09-18 — anglais, prédicats C1)

| FB | Responsabilité unique | VAR_INPUT clés | VAR_OUTPUT clés |
|---|---|---|---|
| `FB_Sim_WinchMotor` | Couple électromagnétique (Kloss), glissement, décrochage prédictif, mode génératrice | `Enable`, `StepCmd : INT (1..5)`, `NetworkVoltageAct_V`, `ResistiveTorque_Nm`, `DirectionCmd : INT (1/-1)` | `Ready`, `MotorTorque_Nm`, `Slip_Ratio`, `SpeedAct_Rpm`, `IsStalled : BOOL`, `IsGeneratorMode : BOOL` |
| `FB_Sim_WinchCurrent` | Courant stator (composition I0/Iactif) + transitoire de commutation gradin (L2/R2) | `Enable`, `MotorTorque_Nm`, `StepCmd` | `Ready`, `StatorCurrentAct_A` (lissé), `StatorCurrentRaw_A` (avec pic) |
| `FB_Sim_GensetVoltage` | Tension réseau sous appel de courant cumulé (X"d + relaxation AVR) — **singleton, partagé M1+M2** | `Enable`, `TotalDrawCurrent_A` | `Ready`, `NetworkVoltageAct_V` |
| `FB_Sim_WindingThermalAging` | Température bobinage + vieillissement isolant (Montsinger) | `Enable`, `StatorCurrentRaw_A` | `Ready`, `WindingTemp_DegC`, `InsulationLifeConsumed_Pct` |
| `FB_Sim_ThermalRelay` | Image thermique I²t protection relais | `Enable`, `StatorCurrentRaw_A` | `Ready`, `ThermalImage_Pct`, `HasTripped : BOOL` |
| `FB_Sim_GearboxShock` | Détection choc mécanique réducteur (SF × nominal + jerk) | `Enable`, `MotorTorque_Nm` | `Ready`, `IsShockDetected : BOOL`, `IsShockSevere : BOOL` |
| `FB_Sim_WinchElectrical` (composite) | Compose les 5 FB ci-dessus pour **un** treuil (instance `WinchM1`/`WinchM2`) | (relais des VAR_INPUT ci-dessus) | `State : ST_fbWinchElectrical_State` (agrège toutes les sorties) |

✅ **Suffixes d'unité électriques ajoutés à `NAMING_CONVENTION.md`** (challenge 2026-09-18) :
`_V`, `_A`, `_Nm`, `_Rpm` (jamais rad/s — usage plaque moteur/variateur), `_DegC` (jamais Kelvin),
`_Ratio` (grandeurs adimensionnelles bornées/signées, ex. `Slip_Ratio` — distinct de `_Pct` déjà
utilisé pour les rapports en %). Amendement appliqué, plus de blocage sur ce point.

## Nommage DUT proposé (NC-110)

- `ST_fbWinchElectrical_State` — sortie agrégée, propriété unique de `FB_Sim_WinchElectrical`
- `ST_fbWinchElectrical_Cfg` — paramètres regroupés (Cmax, In_stator, J_total, gradins R2, etc.), RETAIN si mise en service

## Instanciation proposée (cohérent avec règle "organes répliqués")

```
WinchM1 : FB_Sim_WinchElectrical;   // pas de prefixe inst (organe repliqué, comme FB_Winch existant)
WinchM2 : FB_Sim_WinchElectrical;
instGensetSim : FB_Sim_GensetVoltage;  // singleton PROGRAM-level (AF03 §3 pt.4) -- TRANCHE 2026-09-18
```

**Emplacement tranché** (challenge 2026-09-18) : `instGensetSim` instancié dans `PRG_04_Treuils_Benne`
**après** `WinchM1`/`WinchM2`, câblé sur leurs sorties courant du cycle précédent (1 cycle de retard
à 10ms, acceptable). Pas de GVL de calcul partagée — romprait le principe producteur unique (AF03 §2).

## Questions ouvertes pour le challenge

1. `FB_Sim_GensetVoltage` est un singleton partagé entre M1/M2 — casse le pattern "1 instance par
   axe" habituel. Faut-il le nommer `instGensetSim` (singleton PROGRAM-level) ou le sortir en GVL
   de calcul partagée ? Où doit-il vivre dans l'architecture 7 POU (probablement PRG_02 ou PRG_04) ?
2. `FB_Sim_WinchMotor` a une sortie `Decroche` — polarité à vérifier contre la règle C1 (le nom
   répond-il à "que signifie TRUE" sans ambiguïté ? `Decroche=TRUE` = défaut, cohérent avec la
   famille "capteur de sécurité" si c'est repris en diagnostic réel un jour).
3. Est-ce que `FB_Sim_WinchElectrical` doit être une brique de `CODE/L_SIMULATION/` (comme T300)
   ou faut-il anticiper une variante "diagnostic embarqué" avec mesures réelles (cf. Q4 du plan
   T317, portée sécurité vs macro) — deux architectures différentes selon la réponse.
4. Les 5 paliers réels (vs 4 dans le prototype Python/web) changent `R2_ext_gradins` en tableau de
   5 éléments — à recaler.
