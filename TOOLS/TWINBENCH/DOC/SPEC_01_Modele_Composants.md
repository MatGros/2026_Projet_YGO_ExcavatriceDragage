# 📐 SPEC 01 — Modèle de composants `.twin.yaml`

> **Statut** : v0.1 — éprouvée par le POC `T304` (joystick + axe de translation).
> **Portée** : générique. Ce document ne nomme **aucun** équipement d'une machine réelle.

---

## 🧭 Sommaire

1. [Trois catégories de grandeurs](#1-trois-catégories-de-grandeurs)
2. [Trois niveaux de complétude](#2-trois-niveaux-de-complétude)
3. [Type de composant (bibliothèque `LIB/`)](#3-type-de-composant-bibliothèque-lib)
4. [Instanciation (`machine.twin.yaml`)](#4-instanciation-machinetwinyaml)
5. [Traçabilité `af_ref`](#5-traçabilité-af_ref)
6. [Modes de panne](#6-modes-de-panne)
7. [Invariants](#7-invariants)
8. [Profils de génération](#8-profils-de-génération)
9. [Règles de validation](#9-règles-de-validation)

---

## 1. Trois catégories de grandeurs

La confusion de ces trois natures est la cause racine des divergences de modèle observées
(REX T304 : une même grandeur d'environnement figée en constante dans une implémentation,
paramétrable dans l'autre — les deux bancs testaient des machines différentes sans le dire).

| Catégorie | Nature | Qui la fixe | Rôle en test |
|---|---|---|---|
| 🔩 `machine` | **Constante** — tenue par la mécanique | La construction | Vérifiée, jamais variée |
| 🎛️ `config` | **Réglable**, stable en exploitation | L'exploitant / la mise en service | Balayée sur sa plage admissible |
| 🌊 `environment` | **Aléatoire, subie**, change d'un cycle à l'autre | Le monde extérieur | 🎯 **Balayée systématiquement — c'est un domaine, pas une valeur** |

```yaml
machine:
  axis_travel_m:      { class: machine, value: [0.0, 12.4] }

config:
  approach_speed_pct: { class: config, default: 30, range: [10, 60] }

environment:
  ground_level_m:
    class: environment
    domain: [-20.0, -0.5]          # ← plage, pas valeur
    default: -15.0                  # valeur d'essai manuel uniquement
    sweep:   [-0.5, -2.0, -8.0, -15.0, -19.5, unreachable]
    nature:  [hard, soft, rocky]    # influe sur la qualité de détection
```

> ⛔ Une grandeur `environment` écrite en dur dans une implémentation est une **erreur de
> classe bloquante**, même si sa valeur est « plausible ». Elle rend un pan entier de l'espace
> de test inatteignable — et le test passe quand même, donc personne ne le voit.

---

## 2. Trois niveaux de complétude

Au démarrage d'une affaire, on ne connaît ni les vitesses, ni les inerties. Le modèle accepte
d'être incomplet **explicitement**, plutôt que d'être rempli de valeurs inventées.

| Niveau | Quand | Contenu | Génère |
|---|---|---|---|
| `L0` **Topologie** | Kickoff, sur photos et explications orales | Composition, technologies, liaisons. **Aucun chiffre** | Inventaire E/S · schéma · checklist MES |
| `L1` **Comportement** | Après analyse fonctionnelle | Polarités, ordres, seuils, interlocks | Squelette de tests · stubs |
| `L2` **Dynamique** | Après relevés / mise en service | Vitesses, inerties, retards, jeu, roulis | Simulation complète · invariants |

```yaml
instances:
  AxisA:
    from: actuators/gearmotor
    level: L0
    topology: [gearmotor, chain, pulley, carriage]
    photos:   [refs/2026-09-16_motoreducteur.jpg]
    note:     "plaque signalétique illisible — à relever en MES"
    unknowns: [gear_ratio, nominal_speed_mps, brake_type]
```

🎯 **`unknowns:` est contractuel** : la liste des inconnues vit dans le modèle, pas dans la
tête de l'automaticien. Elle se génère en **checklist de mise en service** — on arrive sur
site avec la liste exacte de ce qui manque.

⛔ Un gate refuse qu'un composant déclare `level: L2` tout en conservant des `unknowns`.

---

## 3. Type de composant (bibliothèque `LIB/`)

Un **type** est générique et réutilisable entre affaires. Il déclare une interface, des
paramètres, une dynamique et des modes de panne — la discipline FMI, en lisible.

```yaml
# LIB/actuators/gearmotor.yaml
type: gearmotor
version: 1.0
af_class: actuator

ports:
  in:  { relay_fwd: BOOL, relay_rev: BOOL, brake_cmd: BOOL, speed_cmd_pct: REAL }
  out: { position_m: REAL, speed_mps: REAL, moving: BOOL }

params:
  travel_m:          { class: machine, type: [REAL, REAL], required: true }
  nominal_speed_mps: { class: machine, type: REAL,        required: true }
  brake_release_ms:  { class: config,  type: REAL, default: 120 }
  coast_m:           { class: config,  type: REAL, default: 0.0 }
  backlash_m:        { class: config,  type: REAL, default: 0.0 }

dynamics:
  host:     integrator_1st_order_with_brake_and_coast
  embedded: integrator_1st_order        # profil dégradé, scan-compatible

faults: [stuck, drift, overspeed, brake_stuck_released]
```

**Règles de type :**

| # | Règle |
|---|---|
| T-01 | Un type ne référence **jamais** une instance ni une machine nommée |
| T-02 | Tout port est typé IEC 61131-3 (`BOOL`, `REAL`, `INT`, `WORD`…) |
| T-03 | Tout paramètre porte sa `class` (§1) |
| T-04 | `dynamics.embedded` est **toujours** une simplification de `dynamics.host`, jamais une autre loi |
| T-05 | Aucun état caché entre deux pas de temps hors état déclaré |

---

## 4. Instanciation (`machine.twin.yaml`)

L'instanciation est **spécifique à l'affaire** et vit dans `PROJECTS/<machine>/`.

```yaml
schema_version: 0.1
machine: exemple_generique

instances:
  AxisA:
    from: actuators/gearmotor
    level: L2
    af_ref: [F11.01, AF_Partie-11]
    params:
      travel_m: [0.0, 12.4]
      nominal_speed_mps: 0.35
      coast_m: 0.08

  PosSensor_1:
    from: sensors/limit_switch
    level: L2
    af_ref: [F11.02]
    on_axis: AxisA
    technology: inductive
    polarity: normally_closed        # 1 = libre (sain)
    params: { trigger_m: 0.0, hysteresis_m: 0.05, response_ms: 8 }

links:
  - { from: AxisA.position_m, to: PosSensor_1.axis_position_m }
```

---

## 5. Traçabilité `af_ref`

C'est **l'unique pont** entre TwinBench (générique) et l'analyse fonctionnelle (la machine).

| Règle | Contrôle |
|---|---|
| Toute instance porte un `af_ref` résolvable dans `DOC/AF/` | ❌ BLOQUANT sinon — un composant sans `af_ref` est une **invention non spécifiée** |
| Toute E/S physique déclarée en AF est couverte par une instance… | ❌ BLOQUANT sinon — **trou de simulation** |
| …ou explicitement marquée `not_simulated: "<raison>"` | ✅ décision tracée, pas un oubli |

**Triple recoupement** — le gate compare trois sources indépendantes :

```
  📐 AF déclaré        ⟷      🧩 Modèle TwinBench     ⟷      ⚙️ Code ST réel
  (af_coverage_v2.py)          (machine.twin.yaml)           (extract_io.py)
```

Effet recherché : il devient **impossible d'inventer un capteur** absent de l'AF, et
**impossible d'oublier de simuler** un équipement spécifié.

---

## 6. Modes de panne

Un modèle sans modes de panne ne teste que le chemin heureux. Chaque type déclare les siens ;
chaque run peut en activer.

| Mode | Effet | Réalité qu'il représente |
|---|---|---|
| `stuck_low` | sortie figée à 0 | capteur mort, câble coupé |
| `stuck_high` | sortie figée à 1 | court-circuit, capteur noyé |
| `delayed` | retard ajouté | capteur encrassé, contact mou |
| `chatter` | commutations parasites en bordure de seuil | 🎯 **le plus réaliste et le plus oublié** — matière molle, vibration |
| `drift` | dérive lente de la mesure | vieillissement, dérive thermique |
| `noise` | bruit additif | perturbation électrique |

```yaml
faults:
  PosSensor_1: { mode: chatter, window_m: 0.03, rate_hz: 12 }
```

---

## 7. Invariants

Des assertions vérifiées **à chaque scan de chaque run** — c'est ce qui produit la fiabilité,
bien davantage que des tests de scénario écrits un par un.

```yaml
invariants:
  - id: INV_BRAKE_ON_POWER_LOSS
    statement: "relais coupés ⟹ frein serré sous 200 ms"
    scope: [actuators/*]
    severity: safety

  - id: INV_DEADMAN_STOPS_MOTION
    statement: "homme-mort relâché ⟹ vitesse nulle sous 3 scans"
    scope: [operator_controlled]
    severity: safety

  - id: INV_NO_AUTO_RESTART
    statement: "défaut latché ⟹ aucun redémarrage sans front de Reset"
    scope: ["*"]
    severity: safety
```

Les invariants `severity: safety` sont **génériques et réutilisables entre affaires** — ils
traduisent des règles de sécurité machine, pas des choix de conception.

### 🔬 Minimisation du contre-exemple

Une violation détectée sur un run long est **réduite automatiquement** au scénario minimal
reproductible. Sans cela, un balayage de milliers de runs produit du bruit illisible.

```
❌ INV_DEADMAN_STOPS_MOTION violé
   Run initial : 4 127 scans, 38 stimuli
   Minimisé    : 3 stimuli
     1. enable
     2. fault_inject(PosSensor_2, stuck_high)
     3. deadman_release
   → vitesse AxisA non nulle pendant 5 scans (> 3)
```

⚠️ Le moteur de détection est lui-même testé : un modèle de test porte une violation
**volontaire** ; si le balayage ne la trouve pas et ne la minimise pas, le gate échoue.
Un détecteur qui ne rougit jamais ne prouve rien.

---

## 8. Profils de génération

| Profil | Cible | Dynamique | Pannes | Usage |
|---|---|---|---|---|
| `host` | Python | complète | ✅ | Tests CI, balayage, jumeau visuel |
| `embedded` | ST (`FB_Sim_*.st`) | simplifiée, scan-compatible | ❌ | Banc IHM sans matériel, **dans l'automate** |

> 🔑 Le profil `embedded` ne **supprime pas** le banc de simulation embarqué existant : il en
> fait un **artefact généré** au lieu d'un fichier écrit à la main. Les deux profils restant
> issus de la même source, le gate d'équivalence prouve qu'ils ne divergent pas.

⛔ Un fichier généré porte un en-tête `GENERATED — DO NOT EDIT` et n'est **jamais** écrit
directement dans `CODE/` par l'outil : la sortie va dans `TOOLS/TWINBENCH/out/`, et la
recopie est une **décision humaine explicite**.

---

## 9. Règles de validation

| ID | Règle | Sévérité |
|---|---|---|
| V-01 | Toute instance a un `af_ref` résolvable, ou `not_simulated` motivé | ❌ BLOQUANT |
| V-02 | Tout paramètre porte une `class` (`machine` / `config` / `environment`) | ❌ BLOQUANT |
| V-03 | Une grandeur `environment` a un `domain`, jamais une seule valeur | ❌ BLOQUANT |
| V-04 | `level: L2` ⟹ `unknowns` vide | ❌ BLOQUANT |
| V-05 | Tout port connecté par `links` existe et a des types compatibles | ❌ BLOQUANT |
| V-06 | Un type ne nomme aucune instance ni machine réelle | ❌ BLOQUANT |
| V-07 | `level: L0` ⟹ tolérance aux paramètres absents | ℹ️ INFO |
| V-08 | E/S de l'AF non couverte par une instance | ⚠️ WARN (❌ en `--release`) |

Commande : `python TOOLS/TWINBENCH/cli.py validate <machine.twin.yaml>`
