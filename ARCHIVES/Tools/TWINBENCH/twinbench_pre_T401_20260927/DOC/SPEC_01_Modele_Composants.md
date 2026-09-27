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

Un quatrième niveau existe : `off` — *« je sais que cet aspect existe, je ne le modélise pas »*.
C'est une décision assumée et tracée, jamais un oubli.

### 2.1 Le niveau est **par aspect**, pas par équipement

On connaît souvent très bien la cinématique d'un axe (mesurée en trace) et absolument rien de
la tenue de sa butée. Un niveau unique par équipement forcerait à aligner le tout sur le pire.

```yaml
instances:
  AxisA:
    from: actuators/gearmotor
    af_ref: [F11.01]
    level:
      kinematics:   L2      # mesuré en trace PLC
      non_ideality: L1      # collage contacteur estimé, pas mesuré
      limits:       L1      # « butée tôle, non dimensionnée » — drapeau levé
      degradation:  off     # non modélisé, et c'est assumé
    topology: [gearmotor, chain, pulley, carriage]
    photos:   [refs/2026-09-16_motoreducteur.jpg]
    unknowns: [end_stop_max_impact_J, brake_type]
```

🎯 **`unknowns:` est contractuel** : la liste des inconnues vit dans le modèle, pas dans la
tête de l'automaticien. Elle se génère en **checklist de mise en service** — on arrive sur
site avec la liste exacte de ce qui manque.

⛔ Un gate refuse qu'un aspect déclare `L2` tout en conservant des `unknowns` le concernant.

### 2.2 Le niveau n'est pas déclaré, il est **calculé**

Déclarer `L2` avec des chiffres inventés est la faute que ce format doit rendre impossible.
Le niveau atteignable découle donc de la **provenance** des paramètres (§2.3), et le gate
refuse toute déclaration plus optimiste que ce que les provenances autorisent.

| `provenance.source` | Niveau maximal autorisé |
|---|---|
| `measured` (trace PLC, relevé) · `nameplate` · `manufacturer_doc` · `standard` | `L2` |
| `estimated` · `web_search` · `inherited_from_project` | `L1` |
| `guessed` | `L1` |
| *absent* | `L0` |

### 2.3 Provenance et vérification — deux attributs distincts

Confondre les deux produit des constantes orphelines dont plus personne ne sait d'où elles
sortent (REX 2026-09-16 : un plancher temporel de commutation présent dans le code, correct,
mais sans aucune trace de son origine ni de sa justification physique).

| Attribut | Question |
|---|---|
| 📍 `provenance` | **D'où vient le chiffre**, et quelle référence permet de le recontrôler |
| ✍️ `verification` | **Quelqu'un l'a-t-il confronté à cette source**, quand, comment, et sous quelle signature |

Un paramètre peut annoncer `source: manufacturer_doc` sans avoir jamais été vérifié — saisi
de mémoire. Les deux attributs sont indépendants.

```yaml
commutation_min_ms:
  class: machine
  value: 400
  provenance:
    source: manufacturer_doc     # nameplate | measured | standard | estimated
                                 # web_search | guessed | inherited_from_project
    reference: "notice constructeur, chapitre temps de retablissement"
  verification:
    status: verified             # unverified | verified | disputed | stale
    by: "<nom>"
    at: '2026-09-16T11:30:00+02:00'
    method: "lecture notice, equipement identifie par plaque"
```

| # | Règle |
|---|---|
| P-01 | **Défaut pessimiste** : un paramètre sans bloc explicite vaut `guessed` + `unverified`. Le silence n'est jamais une caution |
| P-02 | `disputed` est un état légitime — deux sources, deux valeurs. Visible, jamais tranché en douce |
| P-03 | `stale` retombe automatiquement quand l'équipement référencé change (remplacement, rebobinage) |

### 2.4 Trois verdicts, jamais deux

| Verdict | Signification |
|---|---|
| ✅ `PASS` | Vérifié, sur des données suffisantes |
| ❌ `FAIL` | Violation prouvée |
| ⚠️ `UNKNOWN` | **Indéterminable — la donnée manquante est nommée** |

> ⛔ Un invariant de sévérité `safety` qui dépend d'un paramètre `unverified`, ou d'un aspect
> sous-renseigné, **ne rend jamais `PASS`**. Une conclusion de sécurité adossée à un chiffre
> non vérifié n'est pas une conclusion — c'est le mensonge optimiste déplacé du modèle vers
> le rapport, où il est plus dangereux encore.

`UNKNOWN` n'est pas un échec : c'est le livrable le plus utile de l'outil quand les données
manquent. Le rapport trie les paramètres non vérifiés **par nombre d'invariants `safety`
qu'ils bloquent** — la checklist de mise en service se priorise ainsi par impact réel.

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
| T-06 | ⛔ **Aucun écrêtage silencieux d'une grandeur physique** — voir §3.1 |

### 3.1 ⛔ L'écrêtage silencieux est interdit

Borner une position par un `MIN`/`MAX` simule une machine qui s'arrête **toujours proprement
en butée, à n'importe quelle vitesse, sans jamais rien casser**. La surcourse devient
inreprésentable : le test ne peut plus échouer, donc il passe, donc personne ne voit rien.
C'est une zone aveugle silencieuse, la pire classe de défaut sur de la sécurité machine.

> Franchir une limite **émet un événement**, horodaté, portant la vitesse et l'énergie au
> franchissement. Le moteur ne décide pas de la conséquence (hors périmètre de cette spec),
> mais il ne fait **jamais** semblant que rien ne s'est passé.

```yaml
events:
  - { t_ms: 8420, kind: overtravel, instance: AxisA, limit: travel_m.upper,
      speed_mps: 0.34, kinetic_energy_J: 10.4 }
```

### 3.2 Graine et reproductibilité

Aucune grandeur dynamique réelle n'est parfaitement répétable : dispersion de collage des
contacteurs, phase entre le monde continu et le scan automate, retour de ressort d'un
joystick vu sur un nombre variable de cycles. Un modèle à valeurs nominales rejoue toujours
la même trajectoire idéale et ne trouvera jamais les défauts de phase.

Sans variabilité on ne trouve rien ; sans reproductibilité on ne peut rien déboguer. La
résolution est la **graine** :

| # | Règle |
|---|---|
| S-01 | Tout run porte une graine, et elle figure dans **chaque** rapport et chaque trace |
| S-02 | Même graine ⟹ run identique, à l'octet près |
| S-03 | Le balayage tire des graines ; un run en échec est rejouable exactement par la sienne |
| S-04 | 🔒 Le profil `embedded` est **strictement déterministe** : valeurs nominales, aucun tirage. Le gate d'équivalence tourne donc dispersion désactivée — le profil hôte à dispersion nulle **est** le profil embarqué |

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
