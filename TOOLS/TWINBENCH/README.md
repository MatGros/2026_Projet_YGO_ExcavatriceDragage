# 🧊 TwinBench — banc de simulation & jumeau numérique

> **Statut** : 🚧 POC en cours (tâche `T304`) — aucune brique n'est encore en production.
> **Périmètre** : `TOOLS/TWINBENCH/` uniquement. **N'écrit jamais dans `CODE/`.**

---

## ▶️ Comment tester

**Prérequis** : Python 3.11+ et PyYAML (`pip install pyyaml`). Rien d'autre.

```bash
# 1. Deux scénarios — chaîne de cames saine, puis came Maintenance bloquée
python TOOLS/TWINBENCH/cli.py run --scenario nominal --seed 4172
python TOOLS/TWINBENCH/cli.py run --scenario came_hs  --seed 4172 \
       --fault SensorMaintenance=stuck_high

# 2. Assembler la vue 2D
python TOOLS/TWINBENCH/ui/pack_traces.py
python TOOLS/TWINBENCH/ui/build.py

# 3. Ouvrir TOOLS/TWINBENCH/out/twinbench.html dans un navigateur
```

**Ce que tu dois voir** :

| Scénario | Position finale | Évènement |
|---|---|---|
| `nominal` | **30,203 m** | surcourse de 0,003 m — l'arrêt sur mot `00000` arrive après la dernière came |
| `came_hs` | **37,102 m** | **+7,10 m hors course** — panne simple, plus rien n'arrête le chariot |

Dans les deux cas, le CLI affiche `niveau CALCULE : L1`, les paramètres non
vérifiés, et **2 invariants bloqués** en verdict `UNKNOWN`.

**Vérifier la reproductibilité par graine** :

```bash
python TOOLS/TWINBENCH/cli.py run --seed 4172 --out /tmp/a.json
python TOOLS/TWINBENCH/cli.py run --seed 4172 --out /tmp/b.json
cmp /tmp/a.json /tmp/b.json && echo "identiques"      # même graine
python TOOLS/TWINBENCH/cli.py run --seed 9001 --out /tmp/c.json
cmp /tmp/a.json /tmp/c.json || echo "différentes"     # graine différente
```

**Jouer avec le modèle** : édite
`PROJECTS/excavatrice_dragage/machine.twin.yaml` (fréquence max, temps de
frein, positions de cames) et relance. Aucune recompilation.

> ⚠️ Le pilotage interactif (joystick et consignes en direct) **n'existe pas
> encore** : les scénarios sont joués par le moteur. C'est la prochaine brique.

---

## 🎯 Ce que c'est

Un **outil générique** de simulation électromécanique et de jumeau visuel pour projets
d'automatisme. Il n'est **pas** spécifique à l'excavatrice de dragage : la machine est une
donnée (`PROJECTS/<machine>/`), l'outil est le reste.

| Il fait | Il ne fait pas |
|---|---|
| Décrire une machine (actionneurs, capteurs, cinématique, dynamique) en données | Remplacer l'analyse fonctionnelle |
| Simuler son comportement côté hôte (Python) pour les tests | Tourner dans l'automate en production |
| Générer le code ST du banc embarqué depuis le même modèle | Décider quoi que ce soit en JS |
| Vérifier des invariants de sécurité sur des milliers de runs | Commander une machine réelle |
| Rendre des vues 2D pilotées par les frames | Faire de la 3D |

---

## 🧩 Le principe fondateur

> **Le modèle physique de la machine est une donnée unique et versionnée.
> Le code de simulation — Python comme ST — en est *dérivé*, jamais écrit à la main.**

```
              📄 PROJECTS/<machine>/machine.twin.yaml
                          (LA source unique)
                                 │
        ┌────────────────────────┼────────────────────────┐
        ▼                        ▼                        ▼
  🐍 PROFIL HÔTE           ⚙️ PROFIL EMBARQUÉ       🎨 CONFIG VUES
  moteur Python            FB_Sim_*.st généré       views.twin.yaml
  physique complète        dynamique simplifiée     rendu SVG 2D
  pannes, balayage         scan-compatible
  tests + invariants       → banc IHM sans HW
        │                        │
        └──── 🚦 GATE D'ÉQUIVALENCE ────┘
           mêmes stimuli ⟹ mêmes traces
```

### Pourquoi pas FMI / FMU ?

On reprend la **discipline** FMI (composant = interface déclarée + dynamique + paramètres,
pas d'état caché entre pas de temps) mais **pas son format** : un FMU est un binaire compilé,
donc **on ne peut pas en générer du ST**. Le profil embarqué mourrait. L'export `.fmu` reste
possible plus tard comme *artefact de build*, au même titre que le ST.

---

## 🚫 Frontière documentaire — règle non négociable

Le risque de cet outil est la **dérive documentaire** (REX `CLAUDE.md` / `AGENTS.md`,
2026-07-29 : deux corpus, divergence silencieuse). La parade est une frontière stricte :

| Corpus | Parle de | Ne parle **jamais** de |
|---|---|---|
| `TOOLS/TWINBENCH/DOC/` | treuils, capteurs fin de course, dynamiques, ports — **générique** | M1, M2, Kobold, dragage |
| `DOC/AF/` | la machine de dragage | TwinBench |

🔗 **Le seul pont entre les deux est le champ `af_ref`**, et il est vérifié par gate.
Si cette frontière n'est pas tenue, le problème qu'on voulait résoudre est recréé.

---

## 📁 Structure cible

```
TOOLS/TWINBENCH/
├── README.md                          ← ce fichier
├── DOC/
│   ├── SPEC_01_Modele_Composants.md   ✅ écrit (T304)
│   ├── SPEC_02_Interface_Frame.md     ⏳ reprend TEST_AUTO_CI/DIGITAL_TWIN/
│   ├── SPEC_03_Vues_2D.md             ⏳ après POC
│   └── SPEC_04_Tracabilite_AF.md      ⏳ après POC
├── LIB/                               bibliothèque de TYPES réutilisables
│   ├── actuators/  winch · gearmotor · brake · cylinder
│   ├── sensors/    limit_switch · encoder · probe
│   └── faults/     stuck · delayed · drift · chatter
├── PROJECTS/
│   └── excavatrice_dragage/
│       ├── machine.twin.yaml
│       └── views.twin.yaml
├── engine/          moteur Python (profil hôte)
├── generators/      → ST profil embarqué · → config vues
├── gates/           équivalence · couverture AF · pur-rendu
├── ui/              jumeau HTML multi-vues
└── out/             🗑️ sorties générées — JAMAIS recopiées dans CODE/ par l'outil
```

> ⚠️ `SPEC_02..04` sont volontairement **non écrites** avant le POC. Écrire une spec avant
> d'avoir éprouvé le format, c'est fabriquer de la dette documentaire.

---

## 🔗 Existant repris

| Brique | Ce qu'on en prend |
|---|---|
| `TEST_AUTO_CI/DIGITAL_TWIN/SPEC_INTERFACE_FRAME.md` | Le schéma **Frame** — contrat source ⇄ rendu, conservé tel quel |
| `TEST_AUTO_CI/anim_bench/guard_animation_no_business_logic.py` | Garde-fou « pur rendu », étendu |
| `TEST_AUTO_CI/scripts/af_coverage_v2.py` | Parsing des catalogues AF (tables HTML rigides) |
| `TEST_AUTO_CI/scripts/extract_io.py` | Extraction des `VAR_INPUT`/`VAR_OUTPUT` réels d'un `.st` |
| `TOOLS/COMPILER_ST2C_STruCpp` | Compilation du ST généré, pour le gate d'équivalence |

---

## 📚 Documents liés

- [`DOC/SPEC_01_Modele_Composants.md`](DOC/SPEC_01_Modele_Composants.md) — le format `.twin.yaml`
- `DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T304_POC_TWINBENCH_JOYSTICK_M3.yaml` — contrat du POC
- `AGENTS.md` — consignes agent du projet (source unique)
