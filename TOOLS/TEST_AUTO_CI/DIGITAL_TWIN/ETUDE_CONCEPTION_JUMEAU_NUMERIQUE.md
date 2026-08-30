# 🧊 Étude de conception — Jumeau numérique HTML de la machine de dragage

> **Statut** : ÉTUDE DE CONCEPTION (v1.0) — pas d'implémentation.
> **Périmètre** : `TOOLS/TEST_AUTO_CI/` uniquement. **Aucune modification de `CODE/` ni `DOC/AF/`**
> (d'autres agents travaillent sur `main`). Source de vérité = `WORKING_COPY/` (jamais `CODE/`).
> **Branche** : `WT4_TEST_AUTO_CI_TWIN`.

---

## 1. Contexte & objectif

Le projet dispose déjà d'un **banc interactif** (`anim_bench/`) qui compile `FB_Cycle.st` depuis
`WORKING_COPY` en un binaire (`cycle_engine.exe`), l'expose via un serveur HTTP, et affiche une
scène SVG pilotée par un joystick. Ce banc est **mono-FB** (FB_Cycle) et **mono-source** (le binaire).

L'objectif de cette étude est de généraliser ce concept en un **jumeau numérique** :

> Une **interface HTML « jolie »** qui représente la machine, **sans savoir d'où viennent les
> données** qui l'animent (binaire compilé, trace JSON, harnais de tests CI, Grafcet industriel).
> Le jumeau est un **pur lecteur / pur rendu** : on lui envoie des **frames** standardisées, il
> pilote la **cinématique** des actionneurs. Il est **bidirectionnel** : joystick et boutons de la
> page **injectent** des bits vers la source (remplaçant les stubs/mocks de joystick des tests CI).

### 1.1 Bénéfices visés

| Bénéfice | Description |
|---|---|
| 🎨 **Visualisation** | Voir la machine bouger quand on lance un cycle (« diving up », semi-auto, etc.) |
| 🔌 **Plug-and-play** | Brancher n'importe quelle source (binaire, trace, harnais CI) sans toucher au jumeau |
| 🧪 **Tests CI visuels** | Les séquences CI/Grafcet qui produisent des sorties actionneurs deviennent visibles |
| 🕹️ **Injection inverse** | Le joystick/boutons de la page remplacent les stubs/mocks de joystick des tests |
| 🛡️ **Sécurité** | Le jumeau reste un **pur rendu** : aucune logique métier en JS (garde-fou mécanique) |

### 1.2 Principes hérités de l'existant (non négociables)

1. **Source de vérité = `WORKING_COPY/`** — jamais `CODE/` (agents concurrents sur `main`).
2. **Le binaire compilé décide** — aucune logique métier en JS.
3. **Provenance étiquetée** — chaque champ porte sa provenance (`COMPILED` / `HARNESS_STIMULUS` /
   `CONFIG` / `DERIVED` / `INJECTED`).
4. **Garde-fou mécanique** — le code de rendu du jumeau est certifié « pur lecteur ».
5. **Chaîne de fraîcheur SHA** — HTML == trace JSON == source `WORKING_COPY` (hash vérifié).

---

## 2. Architecture cible

```
┌───────────────────────────  SOURCES (Python)  ───────────────────────────┐
│                                                                          │
│  A. Binaire compilé        B. Trace JSON          C. Harnais CI/Grafcet  │
│     cycle_engine.exe          trace_*.json           run_cycle_tests.py   │
│     (processus persistant)   (scan-par-scan)         (séquences ST)       │
│                                                                          │
└──────────────┬──────────────────────┬──────────────────────┬─────────────┘
               │                      │                      │
               ▼                      ▼                      ▼
        ┌─────────────────────────────────────────────────────────────┐
        │              ADAPTATEURS DE SOURCE (Python)                 │
        │   Normalisent chaque source en un flux de FRAMES standard   │
        │   FrameAdapter protocol : produce_frames() -> Frame         │
        │   ControlSink protocol   : inject(stimuli)                  │
        └──────────────────────────────┬──────────────────────────────┘
                                       │  JSON Frame (schéma unique)
                                       ▼
        ┌─────────────────────────────────────────────────────────────┐
        │              TRANSPORT (WebSocket / HTTP POST)              │
        │   /frame (push) · /inject (pull) · /meta (traçabilité)      │
        └──────────────────────────────┬──────────────────────────────┘
                                       │
                                       ▼
        ┌─────────────────────────────────────────────────────────────┐
        │              JUMEAU NUMÉRIQUE (HTML/JS — PUR RENDU)         │
        │   Twin (orchestrateur)                                       │
        │   ├─ Actuator (classe de base)                               │
        │   │   ├─ WinchActuator (M1, M2)                              │
        │   │   ├─ TranslationActuator (M3)                            │
        │   │   └─ BucketActuator (benne)                              │
        │   ├─ Scene (rendu SVG)                                       │
        │   └─ ControlPanel (joystick + boutons -> inject)             │
        └─────────────────────────────────────────────────────────────┘
```

### 2.1 Le concept central : la **Frame**

Une **Frame** est un **snapshot standardisé** de l'état machine à un instant donné. C'est le
**contrat unique** entre toute source et le jumeau. Le jumeau ne connaît que ce format — il ne
sait pas (et ne doit pas savoir) d'où vient la frame.

```jsonc
{
  "meta": {
    "source": "cycle_engine.exe | trace_semi_auto_cycle.json | harness_ci",
    "source_sha256": "…",          // traçabilité : quelle source exacte
    "frame_index": 42,             // numéro de frame / scan
    "t_ms": 8400                   // temps simulé (optionnel)
  },
  "actuators": {
    "winchM1": { "reqStartStop": 1, "reqDirection": 1, "speedTgtPct": 60 },
    "winchM2": { "reqStartStop": 1, "reqDirection": 1, "speedTgtPct": 60 },
    "translation": { "reqStart": 0, "positionTgt": 3 },
    "bucket": { "reqOpen": 0, "reqClose": 1, "reqKoboldMeasureEnable": 0 }
  },
  "sensors": {
    "cablePosM1": 7.0, "cablePosM2": 7.0,
    "benneIsOpen": 0, "benneIsClosed": 1, "benneIsRoughlyClosed": 1,
    "translationAtP1": 1, "translationAtTremie": 0, "translationAtMaintenance": 0,
    "homedM1": 1, "homedM2": 1, "topPositionSensor": 0, "koboldContactFond": 0
  },
  "state": {
    "cycleStep": 3, "cycleStepName": "X3_OPEN_BUCKET",
    "operatorAction": "maintenir le joystick : ouverture complète de la benne",
    "fault": { "error": 0, "errorId": 0, "latched": 0 },
    "lifecycle": { "busy": 1, "done": 0 },
    "waitingForOperator": 1, "waitingForProcess": 0
  },
  "provenance": {
    "actuators.winchM1.reqStartStop": "COMPILED",
    "sensors.cablePosM1": "HARNESS_STIMULUS",
    "state.cycleStep": "COMPILED"
  }
}
```

> **Pourquoi un format unique ?** Le jumeau est **source-agnostique**. Que la frame vienne d'un
> binaire compilé, d'une trace pré-générée ou d'un harnais CI en direct, le rendu est identique.
> C'est le cœur du « plug-and-play ».

### 2.2 Provenance (étendue de l'existant)

L'existant étiquette déjà `COMPILED` / `HARNESS_STIMULUS` / `CONFIG` / `DERIVED`. On ajoute :

| Provenance | Signification |
|---|---|
| `COMPILED` | Calculé par le binaire ST compilé (sorties, états, décisions) |
| `HARNESS_STIMULUS` | Injecté par le harnais (entrées capteurs/positions) — simulé |
| `CONFIG` | Constante de configuration |
| `DERIVED` | Dérivé à la génération (Python, hors JS) pour le rendu |
| `INJECTED` | **Nouveau** : bit poussé par l'utilisateur via le joystick/boutons de la page |

La provenance est affichée dans l'UI (pastilles 🟢🟡🟠🔴) et **vérifiée par le garde-fou** : un
champ `INJECTED` ne doit jamais être traité comme une sortie compilée.

---

## 3. Conception objet (JS) — le jumeau comme programme objet

Le jumeau est conçu **en programmation objet** : chaque actionneur est un objet avec une
**interface** et une **cinématique** propres. Le jumeau applique une frame aux objets, et chaque
objet sait comment se rendre.

### 3.1 Classes

```js
// ── Base : un actionneur sait se rendre à partir d'une commande ──
class Actuator {
  constructor(id, scene) { this.id = id; this.scene = scene; }
  // Applique la commande de la frame à la cinématique visuelle.
  // PURE : ne calcule AUCUNE logique métier — seulement position/état visuel.
  apply(cmd) { throw new Error('apply() à implémenter'); }
}

// ── Treuil : ReqStartStop + ReqDirection + SpeedTgtPct -> position câble ──
class WinchActuator extends Actuator {
  apply(cmd) {
    // La POSITION est fournie par la frame (sensors.cablePosM1) — le jumeau ne l'intègre pas.
    // La commande ne sert qu'à l'affichage (flèche montée/descente, % vitesse, couleur).
    this.scene.setWinch(this.id, {
      running: cmd.reqStartStop === 1,
      direction: cmd.reqDirection,   // 1 = montée, -1 = descente
      speedPct: cmd.speedTgtPct
    });
  }
}

// ── Translation : ReqStart + PositionTgt -> position pont M3 ──
class TranslationActuator extends Actuator {
  apply(cmd) {
    // La position du pont est fournie par sensors.translationAt* — le jumeau ne décide pas.
    this.scene.setGantry({ running: cmd.reqStart === 1, target: cmd.positionTgt });
  }
}

// ── Benne : ReqOpen/ReqClose -> ouverture des mâchoires ──
class BucketActuator extends Actuator {
  apply(cmd) {
    // L'état ouvert/fermé est fourni par sensors.benneIsOpen/Closed — le jumeau ne décide pas.
    this.scene.setBucket({ opening: cmd.reqOpen === 1, closing: cmd.reqClose === 1 });
  }
}

// ── Orchestrateur : reçoit une frame et la distribue aux actionneurs ──
class Twin {
  constructor(scene) {
    this.actuators = {
      winchM1: new WinchActuator('M1', scene),
      winchM2: new WinchActuator('M2', scene),
      translation: new TranslationActuator('M3', scene),
      bucket: new BucketActuator('BENNE', scene)
    };
  }
  // PURE : applique une frame standardisée au rendu. Aucune décision métier.
  render(frame) {
    this.actuators.winchM1.apply(frame.actuators.winchM1);
    this.actuators.winchM2.apply(frame.actuators.winchM2);
    this.actuators.translation.apply(frame.actuators.translation);
    this.actuators.bucket.apply(frame.actuators.bucket);
    this.scene.setState(frame.state);   // étape, action opérateur, défaut, cycle de vie
    this.scene.setSensors(frame.sensors); // positions câble, capteurs
    this.scene.setProvenance(frame.provenance);
  }
}
```

### 3.2 Règle d'or : **le jumeau ne décide jamais**

Le jumeau **ne calcule pas** la position du câble, **ne décide pas** si la benne est ouverte,
**ne simule pas** la physique. Il **reçoit** ces valeurs dans la frame et les **rend**.

> ⚠️ **Différence avec le banc actuel** : le banc `cycle_bench.html` simule la position du câble
> en JS (`simM1 += cmdDir * speed * 0.2`). Dans le jumeau numérique, cette intégration est
> **déplacée côté source** (adaptateur Python ou binaire), pas dans le JS. Le garde-fou
> `guard_animation_no_business_logic.py` doit être étendu pour **rejeter** toute mutation de
> position en JS (déjà le cas pour les sinks).

### 3.3 Cinématique

La **cinématique** (mapping commande → position visuelle) est **déclarative** et vit dans un
**fichier de configuration** (`twin_config.json`), pas dans le code JS. Exemple :

```jsonc
{
  "winch": {
    "rangeM": [-10.5, 8.5],          // plage altimétrique
    "svgY": { "top": 58, "bottom": 350 },  // mapping m -> px (échelle)
    "speedPctToColor": { "0": "#64748b", "50": "#f59e0b", "100": "#ef4444" }
  },
  "translation": {
    "targets": { "1": "P1", "2": "TREMIE", "3": "MAINTENANCE" },
    "svgX": { "P1": 330, "TREMIE": 55, "MAINTENANCE": 455 }
  },
  "bucket": {
    "openAngleDeg": 45,
    "gravelSteps": [6, 10]           // étapes où le gravier est chargé
  }
}
```

> La cinématique est **donnée**, pas **code**. On peut changer l'échelle, les couleurs, les
> positions SVG sans toucher au JS. C'est le « plug-and-play » visuel.

---

## 4. Interfaces plug-and-play

### 4.1 Protocole `FrameAdapter` (côté source, Python)

Toute source expose le même contrat :

```python
class FrameAdapter(Protocol):
    """Convertit une source en flux de frames standardisées."""
    def produce_frames(self) -> Iterator[dict]:
        """Yields des frames (schéma §2.1)."""
        ...

class ControlSink(Protocol):
    """Reçoit les stimuli injectés par le jumeau (joystick/boutons)."""
    def inject(self, stimuli: dict) -> None:
        """Pousse des bits vers la source (remplace les stubs/mocks)."""
        ...
```

### 4.2 Adaptateurs concrets

| Adaptateur | Source | `produce_frames()` | `inject()` |
|---|---|---|---|
| `BinaryEngineAdapter` | `cycle_engine.exe` (processus persistant) | envoie stimuli → lit sorties → construit frame | écrit les stimuli sur stdin |
| `TraceAdapter` | `trace_semi_auto_cycle.json` (pré-généré) | lit les scans → construit frames (lecture seule) | **non supporté** (trace figée) |
| `HarnessCIAdapter` | `run_cycle_tests.py` / séquences ST | exécute le harnais → capture les sorties → frames | injecte dans le harnais |

> **Cas d'usage « diving up »** : l'utilisateur lance un cycle. La source (binaire ou harnais)
> produit les frames du cycle. Le jumeau anime les actionneurs. Si le cycle attend une action
> opérateur (ex. « maintenir le joystick »), le jumeau affiche l'action et l'utilisateur la
> **joue** via le joystick → `inject()` → la source avance.

### 4.3 Transport

| Endpoint | Sens | Rôle |
|---|---|---|
| `POST /frame` | source → jumeau | pousse une frame (ou `WS /frames` pour le streaming) |
| `POST /inject` | jumeau → source | pousse les stimuli (joystick/boutons) vers la source |
| `GET /meta` | — | traçabilité (source, SHA, build_time) — déjà existant |

> **Recommandation** : WebSocket pour le streaming temps réel (le banc actuel fait du polling
> `POST /scan` toutes les 200 ms). Le WebSocket évite le polling et permet le push bidirectionnel.

---

## 5. Injection inverse (joystick / boutons)

Le besoin : **remplacer les stubs/mocks de joystick** des tests CI par l'interface de la page.

- Le `ControlPanel` (joystick + boutons) capture l'intention opérateur.
- Il construit un dictionnaire `stimuli` (ex. `{ DEADMANARMED: 1, M1_CABLEPOSM: 7.0, ... }`).
- Il l'envoie via `POST /inject` → `ControlSink.inject(stimuli)` → la source l'applique.

```js
class ControlPanel {
  constructor(transport) { this.transport = transport; }
  // Joystick : Y = montée/descente, X = translation (intention -1..1)
  onJoystick(joyY, joyX) {
    const stimuli = {
      DEADMANARMED: this.deadman ? 1 : 0,
      // … bits dérivés de l'intention (jamais de logique métier : juste mapping intention->bit)
    };
    this.transport.inject(stimuli);
  }
  onButton(id, pressed) { /* boutons StartCycle, Reset, Abort, Homme-mort, … */ }
}
```

> ⚠️ **Frontière** : le `ControlPanel` fait du **mapping intention→bit** (ex. joystick haut →
> `DEADMANARMED=1`), pas de la **logique métier** (il ne décide pas si le mouvement est autorisé).
> La décision reste à la source (binaire/harnais). Le garde-fou doit vérifier que le JS ne
> **décide** rien — il ne fait que traduire l'intention en bits.

---

## 6. Garde-fou & traçabilité

### 6.1 Garde-fou « pur rendu » (extension de l'existant)

Le garde-fou `guard_animation_no_business_logic.py` est étendu pour le jumeau :

- **Rejets bloquants** : `Math.random`, `Date.now`, `performance.now`, `setInterval`/`requestAnimationFrame`
  qui **mute une position**, objet `STATE`, `simStep`, `updatePhysics`, `+=`/`-=` sur une position.
- **Sinks** : les positions Canvas ne dérivent que des champs de la frame (`frame.sensors.*`,
  `frame.actuators.*`), jamais d'un calcul local.
- **Provenance** : un champ `INJECTED` ne doit pas être traité comme une sortie compilée.
- **Fraîcheur** : la frame embarquée (si mode trace) == trace JSON == source `WORKING_COPY` (SHA).

### 6.2 Traçabilité

Chaque frame porte `meta.source_sha256` (hash de la source exacte). Le jumeau affiche le badge
source (comme le banc actuel). La chaîne SHA complète est vérifiée : **frame == source ==
`WORKING_COPY`**.

---

## 7. Découpage en phases (implémentation future)

| Phase | Contenu | Sortie |
|---|---|---|
| **P0** | Schéma Frame + `twin_config.json` + classes JS de base | Contrat stable |
| **P1** | `BinaryEngineAdapter` (réutilise `cycle_engine.exe`) | Jumeau piloté par le binaire |
| **P2** | `TraceAdapter` (réutilise `trace_semi_auto_cycle.json`) | Jumeau en mode lecture trace |
| **P3** | `ControlPanel` + `POST /inject` | Injection inverse joystick/boutons |
| **P4** | `HarnessCIAdapter` (branche sur `run_cycle_tests.py`) | Tests CI visuels |
| **P5** | Garde-fou étendu + certification | Jumeau certifié « pur rendu » |

> ⚠️ **Périmètre de cette étude** : seules les phases **P0** (conception) sont livrées ici.
> L'implémentation (P1–P5) fera l'objet d'une tâche séparée, toujours dans `TOOLS/TEST_AUTO_CI/`.

---

## 8. Risques & décisions ouvertes

| Risque / question | Décision proposée |
|---|---|
| **Où vit l'intégration de position ?** | Côté **source** (adaptateur Python ou binaire), jamais en JS. |
| **WebSocket vs polling ?** | WebSocket pour le streaming ; garder `POST /scan` en fallback. |
| **Compatibilité avec le banc actuel ?** | Le jumeau **remplace** `cycle_bench.html` ; `cycle_engine.exe` est réutilisé tel quel. |
| **Multi-FB ?** | Le schéma Frame est **générique** (actuators/sensors/state) — extensible à d'autres FB. |
| **Grafcet industriel ?** | Un `HarnessCIAdapter` peut consommer les sorties d'un Grafcet (mêmes bits actionneurs). |
| **Sécurité machine ?** | Le jumeau est **hors-ligne** (aucune commande réelle) — bandeau rouge obligatoire. |

---

## 9. Durcissement suite au challenge expert

Le challenge expert (verdict : **Avec réserves**) a identifié 3 points bloquants (P0) et plusieurs
recommandations. Ils sont **intégrés** ci-dessous.

### 9.1 « Pur rendu » mécaniquement prouvé (P0)

Le « pur rendu » ne doit pas être une *intention* mais une *contrainte* :

- **JSON Schema bloquant** : toute frame est validée contre le schéma (§ `SPEC_INTERFACE_FRAME.md`)
  avant rendu. Une frame non conforme est **rejetée** (pas de rendu partiel).
- **Liste blanche de champs** : tout champ non déclaré dans `twin_config.json` est **rejeté**.
  Le jumeau ne rend que les champs qu'il connaît — impossible d'ajouter un `computed` au rendu.

### 9.2 INJECTED exclusif + marqueur de session + badge (P0)

- **INJECTED exclusif** : une adresse est **soit compilée, soit injectée, jamais les deux**. Règle
  de collision : si une adresse est marquée `INJECTED`, elle ne peut pas être `COMPILED` dans la
  même frame.
- **Marqueur de session** : chaque frame injectée porte un `inject_session_id` (traçabilité).
- **Badge visuel distinct** : un bit injecté est affiché avec un badge dédié — un opérateur ne
  confond jamais un bit injecté avec une sortie réelle.

### 9.3 Contrôle de plausibilité en DERIVED (P1)

- Le jumeau **signale** (jamais ne bloque, jamais ne décide) une incohérence commande↔position
  (ex. position qui bouge sans commande, sens opposé à la commande).
- Ce contrôle est étiqueté **DERIVED** — il n'est **jamais** présenté comme une vérité compilée.

### 9.4 Traçabilité étendue (P1)

- La chaîne SHA couvre : **HTML == trace JSON == source `WORKING_COPY` == binaire
  `cycle_engine.exe` == `twin_config.json`**.
- **Âge de la trace** affiché : le SHA prouve l'identité, pas la fraîcheur. Une trace SHA-identique
  mais vieille est signalée.

### 9.5 Sécurité machine (P0)

- **Bannière HORS-LIGNE non supprimable** : impossible de la masquer via l'UI.
- **Isolation réseau** : le jumeau n'écrit **jamais** vers l'automate (aucune écriture réseau
  sortante vers le bus de commande). Séparation physique des canaux.

---

## 10. Documents liés

- [SPEC_INTERFACE_FRAME.md](SPEC_INTERFACE_FRAME.md) — schéma Frame + protocoles détaillés
- [SPEC_ADAPTATEURS_SOURCES.md](SPEC_ADAPTATEURS_SOURCES.md) — adaptateurs binaire / trace / harnais
- [CHALLENGE_EXPERT.md](CHALLENGE_EXPERT.md) — challenge de la solution par un expert indépendant
- Existant : `anim_bench/` (banc), `engine/cycle_engine.cpp`, `engine/cycle_bench.html`
