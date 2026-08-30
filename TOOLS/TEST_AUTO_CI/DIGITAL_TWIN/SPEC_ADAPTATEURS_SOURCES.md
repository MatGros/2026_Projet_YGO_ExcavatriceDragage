# 🔌 Spec — Adaptateurs de sources

> **Statut** : SPEC (v1.0). **Périmètre** : `TOOLS/TEST_AUTO_CI/` uniquement.
> Source de vérité = `WORKING_COPY/` (jamais `CODE/`).

---

## 1. Rôle des adaptateurs

Un **adaptateur** convertit une source (binaire compilé, trace JSON, harnais CI, Grafcet) en un
flux de **frames standardisées** (§ `SPEC_INTERFACE_FRAME.md`). Il implémente `FrameAdapter`
(produire des frames) et éventuellement `ControlSink` (recevoir les stimuli injectés).

```
Source ──> FrameAdapter ──> Frame ──> Jumeau (rendu)
Jumeau ──> ControlSink ──> Source
```

---

## 2. Adaptateur A — Binaire compilé (`BinaryEngineAdapter`)

**Source** : `cycle_engine.exe` (processus persistant, déjà produit par `build_cycle_engine.py`).

**Protocole du binaire** (existant, inchangé) :
- stdin : une ligne par scan, `key=value key=value …` (stimuli)
- stdout : une ligne par scan, `key=value key=value …` (sorties du FB)

**Mapping** (sorties binaire → frame) :

| Sortie binaire | Champ frame |
|---|---|
| `WINCHM1CMD.STARTSTOP` / `.DIRECTION` / `.SPEEDPCT` | `actuators.winchM1.*` |
| `WINCHM2CMD.*` | `actuators.winchM2.*` |
| `TRANSLATIONCMD.START` / `.TARGET` | `actuators.translation.*` |
| `BUCKETCMD.OPEN` / `.CLOSE` / `.KOBOLDCONTACTORCMD` | `actuators.bucket.*` |
| `M1_CABLEPOSM` / `M2_CABLEPOSM` | `sensors.cablePosM1` / `cablePosM2` |
| `BENNE_ISOPEN` / `BENNE_ISCLOSED` / `BENNE_ISROUGHLYCLOSED` | `sensors.benneIs*` |
| `TRANSLATION_AT_*` | `sensors.translationAt*` |
| `CYCLESTEP` / `CYCLESTATESTR` | `state.cycleStep` / `state.cycleStepName` |
| `OPERATORACTION` | `state.operatorAction` |
| `FAULT.*` / `LIFECYCLE.*` / `WAITINGFOROPERATOR` | `state.*` |

**`inject()`** : écrit les stimuli sur stdin du binaire (même format que le banc actuel).

> ✅ **Réutilise `cycle_engine.exe` tel quel** — aucun changement au moteur.

---

## 3. Adaptateur B — Trace JSON (`TraceAdapter`)

**Source** : `trace_semi_auto_cycle.json` (pré-généré par `generate_trace_cycle.py`).

**Mode** : **lecture seule** — `inject()` non supporté (trace figée).

**Mapping** : chaque scan de la trace → une frame. Les champs `COMPILED` → `actuators`/`state`,
les champs `HARNESS_STIMULUS` → `sensors`, les champs `CONFIG` → ignorés (ou `meta`).

> ✅ **Réutilise la trace existante** — permet de rejouer un cycle complet sans binaire.

---

## 4. Adaptateur C — Harnais CI / Grafcet (`HarnessCIAdapter`)

**Source** : `run_cycle_tests.py` (harnais ST) ou un Grafcet industriel.

**Mode** : **interactif** — `inject()` pousse les stimuli dans le harnais.

**Mapping** : les **sorties actionneurs** du harnais/Grafcet → `actuators.*`, les **entrées
capteurs** → `sensors.*`.

> 🎯 **Cas d'usage** : les séquences CI/Grafcet qui produisent des sorties actionneurs deviennent
> **visibles**. Le joystick/boutons de la page remplacent les stubs/mocks de joystick des tests.

---

## 5. Tableau récapitulatif

| Adaptateur | Source | `produce_frames()` | `inject()` | Réutilise |
|---|---|---|---|---|
| `BinaryEngineAdapter` | `cycle_engine.exe` | ✅ | ✅ | `build_cycle_engine.py` |
| `TraceAdapter` | `trace_semi_auto_cycle.json` | ✅ | ❌ (lecture seule) | `generate_trace_cycle.py` |
| `HarnessCIAdapter` | `run_cycle_tests.py` / Grafcet | ✅ | ✅ | `run_cycle_tests.py` |

---

## 6. Convention de nommage des stimuli injectés

Les stimuli injectés suivent la **convention du moteur** (clés MAJUSCULES) :

| Stimulus | Type | Rôle |
|---|---|---|
| `DEADMANARMED` | bool | homme-mort |
| `STARTCYCLE` | bool (front) | démarrage cycle |
| `RESET` | bool (front) | acquittement |
| `ABORTCYCLE` | bool | abandon |
| `M1_CABLEPOSM` / `M2_CABLEPOSM` | real | position câble |
| `MODE` | enum | mode (SEMI_AUTO, MAINT_N1, …) |
| `ENABLE` / `POWERCONTACTORENGAGED` / `CYCLEMOTIONPERMIT` | bool | autorisations |

> ⚠️ **Frontière** : le `ControlPanel` fait du **mapping intention→bit**, pas de la **logique
> métier**. La décision (mouvement autorisé ou non) reste à la source.
