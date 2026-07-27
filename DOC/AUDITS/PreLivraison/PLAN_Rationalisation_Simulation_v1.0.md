# 🧪 PLAN — Rationalisation Simulation & retrait `GVL_PLC_Tests` (v1.0)

> 🎯 **Rôle** : confiner la simulation derrière une frontière unique et supprimer les points
> d'injection dispersés, avant livraison client.
> 📅 Créé 2026-07-26 · **révisé 2026-07-27** (décisions actées §0) · **aucun `CODE/` modifié**.
> 🔗 [PLAN_Ergonomie_MiseEnService_v1.0](PLAN_Ergonomie_MiseEnService_v1.0.md) ·
> [PLAN_Allegement_Code_v1.0](PLAN_Allegement_Code_v1.0.md) · spec : [AF_Partie-13 v1.4](../../AF_Partie-13_Fonction_Simulation_v1.4.md)

---

## 0. ✅ Décisions actées (2026-07-27)

| # | Sujet | Décision |
|---|---|---|
| D1 | **Architecture** | 🅰️ **Frontière unique** — image matériel, aiguillage en **un seul point**, code métier aveugle à la simulation (§4) |
| D2 | **Granularité** | **4 domaines** : `SimWinchActive` · `SimTranslationActive` · `SimOperatorActive` · `SimMachineActive`. Fin des flags par capteur (§3) |
| D3 | `GVL_PLC_Tests` | ❌ **Supprimée** — 2 stimuli rapatriés en **entrées du banc** (§2) |
| D4 | Accès simulation | Non exposée à l'IHM (PLC uniquement) → risque d'activation par l'opérateur **écarté** |
| D5 | Bypass RETAIN | Persistance **voulue** en MES · **remise à 0 au boot en version finale** → action de livraison |
| D6 | Mappage IHM | **Aucune variable `Test` mappée** dans la visu → retrait de `ST_TestTranslation`/`ST_TestCycle` **sans impact IHM**. Ne pas casser les structures de base |
| D7 | Ordre des chantiers | **1) Simulation · 2) Informations de mise en service** ([plan Ergonomie](PLAN_Ergonomie_MiseEnService_v1.0.md) décalé) |
| D8 | **Méthode** | **Débrancher d'abord, rebrancher ensuite** : P1 nettoie et se valide sur machine réelle, P2 seulement après (§5) |
| D9 | **Visibilité** | Le banc doit être **observable en permanence** : `HwReal` / `HwSim` / `HwIn` côte à côte + comparateur `HwDelta` → critère objectif de bascule simulation → réel au câblage (§4bis) |
| D10 | **RETAIN / PERSISTENT** | **Perte acceptée** — aucune valeur persistante n'a de contenu à préserver aujourd'hui. Seule contrainte maintenue : **ne pas casser les structures IHM mappées dans la visu** (renommage/déplacement/suppression d'un champ mappé). Conséquence : le retrait des `.Test` se fait dès L3, plus besoin de le grouper avec une livraison IHM |

### ⚠️ Levée d'ambiguïté — `GVL_PLC_Tests` existe toujours

Le retrait du 2026-07-26 (`v0.5.1`) a supprimé **le framework** (`FB_TestSequencer`, 8 suites,
45 fichiers / 7 300 l. → `ARCHIVES/Code/PLC_TESTS/`). **La GVL a délibérément survécu** :

```
CODE/SIMULATION/GVL_PLC_Tests.st         64 l. · 20 Override*
  ├─ lue par    PRG_00_Inputs        16 pts  (l. 129, 173, 312-356)
  ├─ lue par    PRG_01_Diagnostics    5 pts  (l. 42-45, 91-95)
  └─ écrite par PRG_09_Supervision   10 pts  (l. 64-73)
```

Source : `PLAN_TASK` §2 (« `GVL_PLC_Tests` survit, réduite à ses 20 `Override*` ») et l'en-tête du
fichier lui-même. **Son retrait est l'objet du lot P1a.**

---

## 1. 🔎 Le vrai problème : la simulation est **diffuse**, pas trop granulaire

Les 25 flags sont le symptôme. La cause est le **mode d'intégration** : **46 points de décision
simulation répartis sur 8 programmes**, sous des formes hétérogènes dont deux sont fausses.

| Forme rencontrée | Occurrences | Diagnostic |
|---|---|---|
| `DI OR (SimActive AND NOT …IsReal)` | 8 capteurs | ❌ **complète** le réel au lieu de le remplacer → capteur « forcé sain », un défaut réel est masqué |
| `Override*` écrivant une `VAR_OUTPUT` | 8 | ❌ écrase une valeur **déjà calculée** par le programme |
| `SEL(…, Réel, Simulé)` | ~12 | 🟡 forme correcte mais dispersée |
| `IF Sim THEN … ELSE …` | ~6 | 🟡 idem |
| Flag sim pilotant un **paramètre métier** | 1 (`DeadmanRearmTimeout` 10 s → **5 min**) | ❌ un flag de banc modifie un temps de sécurité |
| PRG métier **écrivant** dans `GVL_Simulation` | 1 (`PRG_05:39`) | ❌ flux inversé |
| Sim désarmant un contrôle métier | 3 (`BypassContactorCheck`) | ❌ la simulation décide d'une inhibition |

✅ **Point positif confirmé par relevé** : **aucun FB métier ne lit `GVL_Simulation`**
(`FB_Brake`/`FB_Winch` ne la citent qu'en commentaire). L'encapsulation des blocs est saine —
la fuite est entièrement dans la couche `PRG_xx`.

### 💥 C'est le mécanisme exact du bug C1

Retour frein simulé `NOT BrakeCmd` + logique Safety attendant la même polarité fausse =
**deux erreurs qui se compensent**, invisibles jusqu'au câblage réel — où elles auraient produit
`SafeStop + PowerCutOff à chaque arrêt`
([audit §3](../RevueTechnique/AUDIT_Revue_Technique_v1.0.md)).

👉 **Aucune règle de codage ne garantit la non-récidive. Seule une frontière structurelle le peut.**

### 🎯 Doctrine — 1 besoin = 1 outil

| Besoin | Outil | Accès |
|---|---|---|
| Ignorer un défaut sur matériel **présent** | 🔒 **Bypass IHM** (`ST_Bypass*`, RETAIN) | MAINT_N2, tracé |
| Fabriquer une valeur pour matériel **absent** | 🧪 **Simulation** (banc confiné) | PLC uniquement (D4) |
| Injecter une panne **ponctuelle** en essai | 🖐️ **Force natif CODESYS** | Vue instance |

---

## 2. 🔴 État actuel — cartographie des injections

```
 ┌─ GVL_Simulation (25 flags) ──┐        ┌─ GVL_PLC_Tests (20 Override) ─┐
 └───┬────┬────┬────┬────┬──────┘        └──┬──────────┬──────────┬──────┘
     │    │    │    │    │                  │          │          │
     ▼    │    │    │    │                  ▼          │          │
╔═══════════════════════════════════════════════════╗  │          │
║ PRG_00_Inputs                       20 pts  16 pts ║  │          │
║  %IX ──► OR/SEL(sim) ──► FB_Input ──► VAR_OUTPUT ──╫──┼──► Override écrase
║                                       ▲            ║  │      la SORTIE ❌
║  instSimSafety · instSimTranslation ──┘            ║  │
╚═══════════════════════════════════════════════════╝  │
          │    │    │    │                             │
          ▼    │    │    │                             ▼
╔════════════════════════════════════════╗  PRG_01_Diagnostics   8 pts + 5 pts
║ instSimJoystick ─► SEL ─► FB_Joystick  ║  GetDeviceState() lus ici
║ SEL(sim) ─► DeadmanRearmTimeout 5 min  ║ ◄── ❌ flag banc → temps de sécurité
╚════════════════════════════════════════╝
               │    │    │
               ▼    │    │
╔══════════════════════════════════════════════════════════╗  PRG_02   4 pts
║ instSimEncoder M1/M2 ─► IF ─► RawPosToUse ─► FB_Encoder_Abs ║
╚══════════════════════════════════════════════════════════╝
                    │    │
                    ▼    │
   PRG_05  1 pt ── ❌ ÉCRIT dans GVL_Simulation (flux inversé)
   PRG_06  2 pts ─ ❌ la sim désarme BypassContactorCheck
   PRG_07  1 pt  ─ ❌ idem M3
   PRG_08  1 pt  ─ ❌ OR "forcé sain" sur le thermique hydraulique
                         │
                         ▼
   PRG_09  9 pts ─ ✅ publication d'état IHM (légitime) + 10 pts Override ❌
```

👉 Il n'existe pas **un** chemin de données mais **huit**. Impossible de répondre à
« d'où vient cette valeur ? » sans ouvrir 8 fichiers.

### `GVL_PLC_Tests` — destin variable par variable

| Override | Décision | Motif |
|---|---|---|
| `OverrideChainTrue/False`, `OverrideContactorFalse`, `OverrideEmergencyStopOkTrue` | ❌ | Écrivent `EmergencyChain`/`EmergencyStopOk`, **sorties calculées** |
| `OverrideM1/M2FwdRevSpeedFbOff`, `OverrideM1/M2BrakeFeedback` | ❌ | Idem, après normalisation |
| `OverrideM3AtTremie`, `OverrideM3BrakeStuckOpen`, `OverrideM3PhantomFreq` | ❌ | Forçage natif sur le `_DI` / le PDO |
| `OverrideIhmHeartbeatActive/Toggle` | ❌ | Couvert par `SimOperatorActive` |
| `OverrideHmiCommandPurge` | ❌ | Test unitaire du framework archivé |
| `OverrideM3SensorsWordActive` + `Word` | ♻️ **→ entrée du banc** | Seul moyen de tester les 6 mots valides **et** les incohérents |
| `OverrideJoystickActive/RawX/RawY/RawButton` | ♻️ **→ entrée du banc** | Doublon de `TstJoystickForce*`, fusionné |

---

## 3. 🧩 `GVL_Simulation` cible — 25 flags → 5

```
SimulationModeActive : BOOL := FALSE;   // 🔑 bit maître — rien n'est simulé sans lui

SimWinchActive       : BOOL := FALSE;   // M1 + M2 : codeurs, contacteurs, freins,
                                        //   thermiques moteur, capteur haut, mou de câble
SimTranslationActive : BOOL := FALSE;   // AC600 : StatusWord/fréquence, 5 capteurs, frein M3
SimOperatorActive    : BOOL := FALSE;   // Joystick (bus CANopen + RawX/RawY/Button) + heartbeat IHM
SimMachineActive     : BOOL := FALSE;   // Chaîne AU, contacteur puissance, réarmement, phases,
                                        //   thermique frein commun, Kobold, thermique hydraulique

// 🖐️ Stimuli d'essai — ENTRÉES du banc, jamais des forçages du programme
SimM3SensorsWordActive : BOOL;   SimM3SensorsWord : BYTE;
SimJoystickRawX, SimJoystickRawY : INT;   SimJoystickRawButton : BOOL;
SimKoboldContactValue  : BOOL;
SimEncoderSpeedFactor  : REAL := 1.0;   // ⚠️ aujourd'hui 3.0 — remettre à 1.0
SimSyncDeviationInjectM1/M2 : BOOL;   SimSyncDeviationOffset_M : REAL := 0.5;
```

**Polarité positive** : `TRUE = simulé`, défaut `FALSE = réel`. Fin de la double négation
`NOT …IsReal` dont le défaut `FALSE` signifiait « simulé ».

### Rattachement des capteurs communs (conséquence de D2)

| Capteur physique unique | Domaine |
|---|---|
| Capteur position haute M1/M2 · mou de câble M2 | `SimWinchActive` |
| Thermique frein commun M1/M2/M3 · rotation phases | `SimMachineActive` |
| Chaîne AU · contacteur puissance | `SimMachineActive` |
| Kobold contact fond · thermique hydraulique | `SimMachineActive` |

⚠️ **Conséquence assumée de D2** : M1 et M2 sont indissociables — impossible de câbler un treuil réel
en gardant l'autre simulé. Sans objet aujourd'hui (les deux treuils sont câblés).

---

## 4. 🏗️ Architecture cible — frontière unique (D1)

> La simulation ne **complète** jamais le réel : elle le **remplace en bloc**, à un seul endroit,
> **en amont de toute logique**. Le programme métier ne sait pas qu'elle existe.

```
                       ┌──── GVL_Simulation (5 flags + stimuli) ────┐
                       │        LU À UN SEUL ENDROIT ▼              │
╔══════════════════════════════════════════════════════════════════════════╗
║ PRG_00_Inputs  §0 — IMAGE MATÉRIEL  ◄── la SEULE frontière               ║
║                                                                          ║
║  ① %IX · %IW · PDO · GetDeviceState() ──► HwReal   (recopie brute)       ║
║                                                                          ║
║  ② instSimBench(Enable, commandes N-1, stimuli, HwReal) ──► modèle       ║
║       └─ compose FB_Sim_Encoder ×2 · _Translation · _Joystick · _Safety  ║
║                                                                          ║
║  ③ IF SimWinchActive        THEN HwIn.Winch       := Bench.Winch       … ║
║     IF SimTranslationActive THEN HwIn.Translation := Bench.Translation … ║
║     IF SimOperatorActive    THEN HwIn.Operator    := Bench.Operator    … ║
║     IF SimMachineActive     THEN HwIn.Machine     := Bench.Machine     … ║
║                            ▲                                             ║
║              4 IF, struct entière : simulé OU réel, jamais un mélange     ║
╠══════════════════════════════════════════════════════════════════════════╣
║ §1 — CONDITIONNEMENT : HwIn ──► FB_Input ──► VAR_OUTPUT   (0 flag sim)   ║
╚══════════════════════════════════════════════════════════════════════════╝
                                   │  HwIn
        ┌──────────┬───────────────┼───────────────┬──────────┐
        ▼          ▼               ▼               ▼          ▼
     PRG_01     PRG_02        PRG_05/06/07/08   PRG_03/04   PRG_10
     0 flag     0 flag           0 flag          0 flag     0 flag
                                                              │
        ┌─────────── commandes du scan N-1, LECTURE SEULE ────┘
        ▼
   (retour au ② : le banc boucle sur les commandes, comme un vrai process)

   PRG_09 ── ✅ conserve 4 lectures : publier "ce domaine est simulé" à l'IHM
```

### `ST_HardwareImage` — inventaire E/S (bénéfice collatéral)

L'inventaire des E/S, aujourd'hui dispersé dans 5 programmes, devient une structure lisible :

| Sous-struct | Contenu |
|---|---|
| `ST_HwWinch` | `M1/M2_FwdRevSpeedFeedbackOff_DI` · `M1/M2_ThermalFeedback_DI` · `M1/M2_BrakeFeedback_DI` · `M1_M2_TopPositionSensor_DI` · `M2_SlackCableSwitch_DI` · `COD1/COD2_PosValue` · `COD1/COD2_Alarms` · `COD1/COD2_Warnings` · états devices COD1/COD2 |
| `ST_HwTranslation` | `PosTremie_DI` · `PosPV_DI` · `PosFosse2_DI` · `PosFosse1_DI` · `PosMaintenance_DI` · `M3_BrakeFeedback_DI` · `M3_StatusWord` · `M3_ActualFrequencyHz` · état device AC600 |
| `ST_HwOperator` | `JoyXRaw_ANA1` · `JoyYRaw_ANA2` · `JoyBtnRaw` · état bus CAN · état device JOY1 · `TglHeartbeatIhm` |
| `ST_HwMachine` | `EmergencyStopOk_DI` · `EmergencyChainOK_DI` · `CtrlPhaseRotation_DI` · `BrakeThermalFeedback_DI` · `KoboldContactFond_DI` · `ThermHydraulique_DI` |

⚠️ Les lectures `GetBusState()`/`GetDeviceState()` (aujourd'hui en `PRG_01`) **remontent en `PRG_00`** :
règle « toute lecture matériel se fait en position 0 ». `PRG_01` les consomme depuis l'image.

### `FB_SimBench` — un banc, pas des morceaux de banc

Composition (aucune réécriture) des FB existants : `FB_Sim_Encoder` ×2 · `FB_Sim_Translation` ·
`FB_Sim_Joystick` · `FB_Sim_Safety`. **Toutes ses entrées sont passées en paramètres** (commandes
relais, `BrakeCmd`, `M3_CommandWord`, stimuli) : aucune lecture de globale depuis l'intérieur → FB
testable et déplaçable. `FB_Sim_DigitalMirror` : ❌ supprimé (orphelin confirmé, 46 l.).

### 🔍 4bis. Visibilité — 3 images côte à côte + comparateur permanent

**Demande utilisateur (2026-07-27, D9)** : pouvoir voir en permanence ce que le banc produit, pour
savoir **ce qui est attendu au câblage** — et ne pas découvrir à l'extinction de la simulation que
le réel ne correspond pas.

L'architecture le fournit presque gratuitement : les trois images ont **les mêmes champs**.

```
   HwReal   ── ce que dit le matériel        (rempli EN PERMANENCE, même en simulation)
   HwSim    ── ce que le banc attend         (calculé EN PERMANENCE si SimShadowCompare)
   HwIn     ── ce que le programme utilise   (= l'un ou l'autre, par domaine)
   HwDelta  ── 🎯 les champs où HwReal ≠ HwSim
```

👉 En vue instance CODESYS : **3 colonnes alignées, lecture directe**, sans IHM et sans forçage.

#### Le comparateur `HwDelta` — le vrai livrable

Un `TRUE` dans `HwDelta` = « le matériel ne dit pas ce que le modèle attend ». En mise en service :

| Situation | Lecture |
|---|---|
| Câblage d'un capteur, simulation encore active | `HwDelta.Machine.EmergencyStopOk = TRUE` → le fil n'est pas là ou la **polarité est inversée** |
| Tous les `HwDelta` d'un domaine à `FALSE` | ✅ le domaine peut être basculé en réel **sans surprise** |
| `HwMismatchCount` (synthèse) | Nombre d'écarts en cours, tous domaines |

🎯 **C'est le critère objectif de bascule simulation → réel**, capteur par capteur, au lieu de
« on coupe et on voit ». **C1 (polarité frein inversée) aurait été visible immédiatement.**

⚠️ **Périmètre de comparaison** : uniquement les grandeurs **logiques** (retours contacteurs,
freins, capteurs TOR, états devices, mots d'état). Les grandeurs **continues** (position codeur,
fréquence M3) ne sont pas comparables — le banc ne prétend pas prédire une position réelle. Elles
restent affichées côte à côte, sans verdict.

`SimShadowCompare : BOOL := FALSE` — active le calcul permanent du banc en mise en service.
En exploitation : à `FALSE` (le banc ne tourne pas, CPU nul, et l'exclusion du build reste possible).

### 🎁 Ce que l'architecture supprime mécaniquement

| Anomalie actuelle | Sort |
|---|---|
| `DeadmanRearmTimeout` 5 min en simulation (`PRG_01:131`) | ☠️ **interdit** : un flag sim ne pilote plus un paramètre métier |
| Terme **simulation** de `BypassContactorCheck` (`PRG_06:478`, `PRG_06:522`, `PRG_07:161`) | ☠️ retiré. ⚠️ **Le bypass IHM `Bypass.Global` reste intact** — hors simulation, comportement identique. Effet : en simulation le contrôle devient **actif** (donc testable), au lieu d'être désarmé en permanence |
| `PRG_05` écrivant dans `GVL_Simulation` | ☠️ flux inversé supprimé |
| 8 `OR (SimActive AND NOT …)` | ☠️ remplacés par l'aiguillage en bloc |
| `SEL(instSimJoystick.Enable, …)` dispersés | ☠️ le métier lit `HwIn` |

### 🔒 Garde-fou automatique (P3, indispensable)

Règle à ajouter dans `TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py` :

> `GVL_Simulation.` est **interdit** hors de `CODE/SIMULATION/`, de la section §0 de
> `PRG_00_Inputs.st` et de la publication d'état IHM de `PRG_09_Supervision.st`.

⚠️ Prérequis : corriger **C3** d'abord (36/36 faux positifs — le gate ne prouve plus rien).

---

## 5. 🚦 Phasage — débrancher, puis rebrancher (D8)

> 🧭 **Principe** : on ne remplace pas une architecture pendant qu'on en démonte une autre.
> P1 laisse le programme dans un état **propre, complet et vérifiable sur machine réelle**
> (plus aucune simulation, plus aucun forçage). P2 rebranche derrière la frontière.

| Phase | Lot | Contenu | Preuve de sortie |
|---|---|---|---|
| **P0** | 🏁 Baseline | Tag git · export CODESYS · bundle · relevé des bypass RETAIN et valeurs `PERSISTENT` | archivé |
| **P1a** | 🗑️ Forçages & orphelins | Retrait `GVL_PLC_Tests` (64 l. + 31 pts) · `ST_TestTranslation`/`ST_TestCycle` · `FB_Sim_DigitalMirror` · `BypassRestoreDone` | Compilation + **tableau de neutralité** |
| **P1b** | 🔌 Débranchement sim | Retrait des instances `FB_Sim_*` et des `OR`/`SEL`/`IF` sim dans `PRG_00/01/02/05/06/07/08/09` · `DeadmanRearmTimeout` figé à `T#10S` | Compilation + **essai machine réelle** |
| **P2** | 🏗️ Frontière unique | `ST_HardwareImage` · `FB_SimBench` · §0 de `PRG_00` · `GVL_Simulation` à 5 flags · **comparateur `HwDelta` (D9)** · `SimEncoderSpeedFactor := 1.0` | Sim OFF **identique signal à signal** à P1, puis sim ON par domaine, puis `HwDelta` tout à `FALSE` machine saine |
| **P3** | 🔒 Verrou & spec | C3 corrigé + règle gate `GVL_Simulation.` confinée · `AF_Partie-13 v2.0` | Gate PASS |

### 🧾 P1 est **neutre par construction** — c'est démontrable

`SimulationModeActive` vaut déjà `FALSE` par défaut. Chacun des 46 points se réduit à la branche
réelle :

| Point | Forme | À `SimActive = FALSE` |
|---|---|---|
| 8 capteurs `PRG_00` | `DI OR (Sim AND …)` | `DI OR FALSE` → **`DI`** ✅ |
| Codeurs `PRG_02` | `IF Sim … ELSE COD_PosValue` | **`COD_PosValue`** ✅ |
| Diag `PRG_01` | re-couplé au bit maître (REX 2026-07-24) | **bypass inactif** ✅ |
| `DeadmanRearmTimeout` | `SEL(NOT Sim OR …, T#5M, T#10S)` | **`T#10S`** ✅ |
| `PRG_06/07/08` | `OR (Sim AND …)` | **neutre** ✅ |
| 20 `Override*` | non-RETAIN, `FALSE` au boot | **neutres** ✅ |

👉 Supprimer ces branches **ne peut pas changer le comportement de la machine réelle**.
📋 **Livrable de revue avant application** : tableau de neutralité exhaustif (46 lignes, une preuve
par ligne), à valider **avant** toute modification de `CODE/`.

### 🔌 Débrancher ≠ détruire

P1 retire les **instances** et les **points d'injection**. Sont **conservés** : les 4 `FB_Sim_*`
(Encoder, Translation, Joystick, Safety) et le fichier `GVL_Simulation`, non instanciés donc inertes.
P2 les rebranche derrière la frontière. Aucun travail jeté, et un `revert` de P1 reste cohérent.

### ⚠️ Coût à assumer entre P1 et P2

**Aucun banc de simulation disponible dans l'intervalle.** Acceptable tant que M1/M2/M3 sont câblés
et que la MES se fait sur matériel réel. Si un essai banc est nécessaire entre les deux :
enchaîner P1→P2 sans pause, ou valider P2 avant de figer P1.

### ✅ Bonne nouvelle de phasage

**Aucun nom mappé dans la visu n'est touché** : seuls les champs `.Test` disparaissent, et ils ne
sont mappés nulle part (D6). → **Aucun reparamétrage IHM/SCADA sur tout le chantier**, ce qui rend
l'ordre D7 confortable et rend ce chantier indépendant des livraisons IHM du
[plan Ergonomie](PLAN_Ergonomie_MiseEnService_v1.0.md).

⚠️ En revanche le **RETAIN est bien invalidé** au lot L3 (retrait des `.Test` d'une struct
`VAR_GLOBAL RETAIN`) → restauration `PERSISTENT` et rejeu des bypass. **Accepté (D10)** : relire les
valeurs de config restaurées avant tout mouvement, le relevé de baseline (L0) sert de filet.

### 🧪 Contrôles

**Après P1b (essai machine réelle)**
1. Compilation `0 erreur / 0 warning`.
2. Mouvement M1, M2, M1+M2 couplés au joystick (homme-mort, rampes, paliers).
3. Translation M3 : manuel + « aller à la position ».
4. AU physique → réarmement complet (auto-test A/B).
5. Cycle semi-auto sur une séquence courte.
6. Bypass IHM `Global` M1/M2/M3 : purge toujours effective (MES-004).
7. Diagnostics bus : aucun faux défaut apparu.

**Après P2 (le seul lot à risque)**
1. `SimulationModeActive = FALSE` : **comparer signal à signal** `HwIn` aux valeurs de P1 —
   elles doivent être **identiques**. C'est la preuve que la frontière ne change rien au réel.
2. Chaque domaine activé seul : cohérence des 4 blocs.
3. Homing M1/M2 à 8,5 m · montée/descente · injection Méca E.
4. Translation : 6 mots valides + 1 mot incohérent via `SimM3SensorsWord`.
5. Heartbeat : `SimOperatorActive` OFF sans IHM → timeout attendu.

---

## 6. 📉 Bilan quantifié — honnête

| Poste | Δ lignes |
|---|---|
| `GVL_PLC_Tests` + 31 points d'injection | **−127** |
| `FB_Sim_DigitalMirror` (orphelin) | **−46** |
| `GVL_Simulation` (25 → 5 flags) | **−38** |
| Conditions sim dispersées (`PRG_01/02/05/06/07/08/09`) | **−45** |
| `ST_HardwareImage` (4 sous-structs, ~40 champs) | **+70** |
| Recopie `HwReal` + aiguillage (`PRG_00` §0) | **+55** |
| `FB_SimBench` (enveloppe de composition) | **+60** |
| 🔍 Comparateur `HwDelta` + `HwMismatchCount` (§4bis, D9) | **+60** |
| **Net** | **≈ −10 l. (neutre)** |

🎯 **Ce refactor ne fait pas maigrir le projet.** Il échange ~256 lignes dispersées et dangereuses
contre ~245 lignes centralisées et vérifiables. Le gain réel :

- **1 seul endroit** où la simulation peut agir (contre 8 programmes) ;
- **impossible** de forcer une sortie calculée ou de masquer un défaut réel ;
- un **inventaire E/S lisible** là où il n'en existait aucun ;
- 🔍 un **comparateur permanent modèle ↔ réel**, critère objectif de bascule au câblage ;
- un **gate automatique** qui empêche la récidive.

---

## 7. 🧷 Limites & points ouverts

- ⚠️ P2 touche l'entrée de **7 programmes**. Le typage strict CODESYS attrape les fautes de frappe,
  mais **le test §5 « signal à signal » est la seule preuve réelle** que le comportement machine est
  inchangé. Ne pas le sauter.
- 🟠 **`GetDeviceState()` remonte de `PRG_01` vers `PRG_00`** — cohérent avec la règle « lecture
  matériel en position 0 », mais déplace 5 lignes hors de leur programme historique. **À valider.**
- 🟠 **`BypassContactorCheck` perd sa source simulation** (`PRG_06`/`PRG_07`) : changement de
  comportement **en mode banc uniquement**, à vérifier au premier essai simulé après P2.
- Le banc lit les commandes du scan **N-1 (10 ms)** — comportement actuel, déjà assumé et documenté
  (négligeable devant les temps frein/contacteurs de 100-300 ms).
- 🎯 **Suite possible (non décidée)** : la frontière rend `CODE/SIMULATION` excluable du build via une
  configuration CODESYS « Livraison » (*Exclude from build*) → poids réellement nul et garantie
  absolue côté client. Impossible aujourd'hui, praticable après P2.
- `AF_Partie-13 v1.4` §2bis (bypass diag « découplé » du bit maître) est **périmé** : le code a
  re-couplé le 2026-07-24. À corriger en v2.0 (P3).
- D5 : la remise à 0 des bypass RETAIN au boot en version finale reste **une action de livraison à
  planifier**, hors périmètre de ce plan.
- Aucun rejeu automatique depuis `v0.5.1` : validation par simulation manuelle + FAT/SAT.
