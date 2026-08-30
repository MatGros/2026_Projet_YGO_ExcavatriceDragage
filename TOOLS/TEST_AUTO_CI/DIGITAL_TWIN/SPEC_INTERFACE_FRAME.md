# 🔌 Spec d'interface — Frame & protocoles plug-and-play

> **Statut** : SPEC (v1.0) — contrat stable pour le jumeau numérique.
> **Périmètre** : `TOOLS/TEST_AUTO_CI/` uniquement. Source de vérité = `WORKING_COPY/`.

---

## 1. La Frame — contrat unique

La **Frame** est le **seul** format que le jumeau consomme. Toute source (binaire, trace, harnais
CI, Grafcet) doit produire des frames conformes à ce schéma. Le jumeau ne connaît que ce format.

### 1.1 Schéma JSON (draft-07)

```jsonc
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "MachineFrame",
  "type": "object",
  "required": ["meta", "actuators", "sensors", "state"],
  "properties": {
    "meta": {
      "type": "object",
      "required": ["schema_version", "source", "frame_index"],
      "properties": {
        "schema_version": { "type": "string", "const": "1.0" },
        "source": { "type": "string", "enum": ["cycle_engine.exe", "trace_semi_auto_cycle.json", "harness_ci", "grafcet"] },
        "source_sha256": { "type": "string" },
        "binary_sha256": { "type": "string" },
        "config_sha256": { "type": "string" },
        "trace_age_ms": { "type": "number" },
        "inject_session_id": { "type": "string" },
        "frame_index": { "type": "integer", "minimum": 0 },
        "t_ms": { "type": "number" }
      }
    },
    "actuators": {
      "type": "object",
      "required": ["winchM1", "winchM2", "translation", "bucket"],
      "properties": {
        "winchM1": { "$ref": "#/definitions/winchCmd" },
        "winchM2": { "$ref": "#/definitions/winchCmd" },
        "translation": { "$ref": "#/definitions/translationCmd" },
        "bucket": { "$ref": "#/definitions/bucketCmd" }
      }
    },
    "sensors": {
      "type": "object",
      "properties": {
        "cablePosM1": { "type": "number" },
        "cablePosM2": { "type": "number" },
        "benneIsOpen": { "type": "integer", "enum": [0, 1] },
        "benneIsClosed": { "type": "integer", "enum": [0, 1] },
        "benneIsRoughlyClosed": { "type": "integer", "enum": [0, 1] },
        "translationAtP1": { "type": "integer", "enum": [0, 1] },
        "translationAtTremie": { "type": "integer", "enum": [0, 1] },
        "translationAtMaintenance": { "type": "integer", "enum": [0, 1] },
        "homedM1": { "type": "integer", "enum": [0, 1] },
        "homedM2": { "type": "integer", "enum": [0, 1] },
        "topPositionSensor": { "type": "integer", "enum": [0, 1] },
        "koboldContactFond": { "type": "integer", "enum": [0, 1] }
      }
    },
    "state": {
      "type": "object",
      "properties": {
        "cycleStep": { "type": "integer" },
        "cycleStepName": { "type": "string" },
        "operatorAction": { "type": "string" },
        "fault": {
          "type": "object",
          "properties": {
            "error": { "type": "integer", "enum": [0, 1] },
            "errorId": { "type": "integer" },
            "latched": { "type": "integer", "enum": [0, 1] }
          }
        },
        "lifecycle": {
          "type": "object",
          "properties": {
            "busy": { "type": "integer", "enum": [0, 1] },
            "done": { "type": "integer", "enum": [0, 1] }
          }
        },
        "waitingForOperator": { "type": "integer", "enum": [0, 1] },
        "waitingForProcess": { "type": "integer", "enum": [0, 1] }
      }
    },
    "provenance": {
      "type": "object",
      "description": "Étiquette de provenance par chemin de champ (optionnel mais recommandé).",
      "additionalProperties": {
        "type": "string",
        "enum": ["COMPILED", "HARNESS_STIMULUS", "CONFIG", "DERIVED", "INJECTED"]
      }
    }
  },
  "definitions": {
    "winchCmd": {
      "type": "object",
      "properties": {
        "startStop": { "type": "integer", "enum": [0, 1] },
        "direction": { "type": "integer", "enum": [-1, 0, 1] },
        "speedPct": { "type": "number" }
      }
    },
    "translationCmd": {
      "type": "object",
      "properties": {
        "start": { "type": "integer", "enum": [0, 1] },
        "target": { "type": "integer" }
      }
    },
    "bucketCmd": {
      "type": "object",
      "properties": {
        "open": { "type": "integer", "enum": [0, 1] },
        "close": { "type": "integer", "enum": [0, 1] },
        "koboldContactor": { "type": "integer", "enum": [0, 1] }
      }
    }
  }
}
```

### 1.2 Règles de la Frame

1. **Le jumeau ne décide jamais** : les positions (`cablePosM1`, `benneIsOpen`, …) sont **fournies**
   par la frame, jamais calculées en JS.
2. **Validation bloquante (P0)** : toute frame est validée contre le schéma §1.1 **avant rendu**.
   Une frame non conforme est **rejetée** (pas de rendu partiel).
3. **Liste blanche de champs (P0)** : tout champ non déclaré dans `twin_config.json` est **rejeté**.
   Le jumeau ne rend que les champs qu'il connaît.
4. **Provenance obligatoire** pour les champs critiques : un champ `INJECTED` ne doit jamais être
   affiché comme une sortie compilée.
5. **INJECTED exclusif (P0)** : une adresse est **soit compilée, soit injectée, jamais les deux**.
   Chaque frame injectée porte `meta.inject_session_id`.
6. **`meta.source_sha256`** : traçabilité — quelle source exacte a produit la frame. La chaîne SHA
   couvre aussi `binary_sha256` et `config_sha256` ; `trace_age_ms` signale la fraîcheur temporelle.

---

## 2. Protocoles (Python, côté source)

### 2.1 `FrameAdapter`

```python
from typing import Iterator, Protocol

class FrameAdapter(Protocol):
    """Convertit une source en flux de frames standardisées."""
    def produce_frames(self) -> Iterator[dict]:
        """Yields des frames conformes au schéma §1.1."""
        ...
```

### 2.2 `ControlSink`

```python
class ControlSink(Protocol):
    """Reçoit les stimuli injectés par le jumeau (joystick/boutons)."""
    def inject(self, stimuli: dict) -> None:
        """Pousse des bits vers la source. Remplace les stubs/mocks de joystick."""
        ...
```

### 2.3 Contrat d'injection

Le `stimuli` injecté suit la **convention de nommage du moteur** (clés MAJUSCULES, ex.
`DEADMANARMED`, `M1_CABLEPOSM`, `STARTCYCLE`, `RESET`, `ABORTCYCLE`). C'est le **même format**
que le banc actuel envoie au binaire (`cycle_engine.cpp`).

---

## 3. Transport

| Endpoint | Sens | Rôle |
|---|---|---|
| `POST /frame` | source → jumeau | pousse une frame (JSON) |
| `WS /frames` | source → jumeau | streaming temps réel (recommandé) |
| `POST /inject` | jumeau → source | pousse les stimuli (joystick/boutons) |
| `GET /meta` | — | traçabilité (source, SHA, build_time) |

### 3.1 Exemple de flux

```
Source (binaire)  --frame-->  Jumeau (rendu)
Jumeau (joystick) --inject--> Source (binaire)
```

---

## 4. Cinématique déclarative (`twin_config.json`)

La cinématique (mapping commande → position visuelle) est **donnée**, pas **code** :

```jsonc
{
  "winch": {
    "rangeM": [-10.5, 8.5],
    "svgY": { "top": 58, "bottom": 350 },
    "speedPctToColor": { "0": "#64748b", "50": "#f59e0b", "100": "#ef4444" }
  },
  "translation": {
    "targets": { "1": "P1", "2": "TREMIE", "3": "MAINTENANCE" },
    "svgX": { "P1": 330, "TREMIE": 55, "MAINTENANCE": 455 }
  },
  "bucket": {
    "openAngleDeg": 45,
    "gravelSteps": [6, 10]
  }
}
```

> Changer l'échelle, les couleurs ou les positions SVG se fait **sans toucher au JS**.
