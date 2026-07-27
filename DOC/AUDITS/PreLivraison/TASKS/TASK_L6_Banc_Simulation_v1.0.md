# 🧪 FICHE DE TÂCHE — Lot L6 : rebranchement du banc de simulation derrière `HwIn`

> 🤖 Agent d'implémentation externe · 📅 2026-07-27 · **v1.0** · 🟠 lot fonctionnel
> ⏱️ **Prérequis** : lot L5 appliqué (frontière `HwIn` en place). ✅ C'est le cas (commit `4817c0b`).
> 📖 **Contexte projet et règles de travail : lire les §1 et §4 de
> [`TASK_L2-L3_Retrait_GVL_PLC_Tests_v1.0.md`](TASK_L2-L3_Retrait_GVL_PLC_Tests_v1.0.md)**
> (contexte machine, lectures obligatoires, devoir d'alerte — ils s'appliquent intégralement).

---

## 1. 🎯 Objectif

Rendre la machine **simulable** à nouveau (elle ne l'est plus depuis le lot L4d), mais cette fois
**entièrement confinée derrière la frontière `HwIn`** : le code métier ne doit jamais savoir que
la simulation existe.

### 🧠 État actuel

- `PRG_00_Inputs` §0 acquiert le matériel dans `HwReal`, puis `§0bis : HwIn := HwReal;`
  **inconditionnel** (ligne ~218).
- Il n'existe **aucune** référence à `GVL_Simulation` dans le code actif.
- Les 4 blocs de modèle existent toujours mais **ne sont instanciés nulle part** :
  `FB_Sim_Encoder`, `FB_Sim_Translation`, `FB_Sim_Joystick`, `FB_Sim_Safety` (`CODE/SIMULATION/`).
- `GVL_Simulation.st` existe encore avec ses **25 anciens flags** — à refondre.

### 🧭 Le principe directeur

> La simulation ne **complète** jamais le réel : elle le **remplace en bloc**, par domaine entier,
> à un seul endroit. Un domaine est **simulé OU réel — jamais un mélange**.

⛔ **Interdiction absolue** de réintroduire une forme `X := X_reel OR (SimActive AND …)` :
c'est ce « forçage à l'état sain » qui a masqué un vrai bug de polarité de frein par le passé.

---

## 2. 🔧 Travail

### 2.1 Refondre `CODE/SIMULATION/GVL_Simulation.st` — 25 flags → 5

```pascal
SimulationModeActive : BOOL := FALSE;   // 🔑 bit maître — rien n'est simulé sans lui

SimWinchActive       : BOOL := FALSE;   // M1+M2 : codeurs, contacteurs, freins, thermiques,
                                        //   capteur haut, câble tendu
SimTranslationActive : BOOL := FALSE;   // AC600 : StatusWord/fréquence, 5 capteurs, frein M3
SimOperatorActive    : BOOL := FALSE;   // Joystick : bus CANopen + RawX/RawY/Button
SimMachineActive     : BOOL := FALSE;   // Chaîne AU, contacteur puissance, réarmement, phases,
                                        //   thermique frein, Kobold, thermique hydraulique

// 🖐️ Stimuli de banc — ENTRÉES du modèle, jamais des forçages du programme
SimM3SensorsWordActive : BOOL;   SimM3SensorsWord : BYTE;
SimJoystickRawX, SimJoystickRawY : INT;   SimJoystickRawButton : BOOL;
SimKoboldContactValue  : BOOL;
SimEncoderSpeedFactor  : REAL := 1.0;   // ⚠️ l'ancienne valeur était 3.0 — remettre à 1.0
SimSyncDeviationInjectM1, SimSyncDeviationInjectM2 : BOOL;
SimSyncDeviationOffset_M : REAL := 0.5;
```

**Polarité positive** : `TRUE = simulé`, défaut `FALSE = réel`. Les anciens flags `*IsReal`
(double négation) disparaissent tous.

### 2.2 Créer `CODE/SIMULATION/FB_SimBench.st`

Enveloppe unique qui **compose** les 4 blocs existants (ne les réécris pas) et produit une image
matérielle simulée, domaine par domaine.

| Aspect | Règle |
|---|---|
| Sorties | `Winch`, `Translation`, `Operator`, `Machine` — **mêmes types** que `ST_HardwareImage` |
| Entrées | **tout passe en paramètres** : commandes relais/frein, `M3_CommandWord`, stimuli, `HwReal`. **Aucune lecture de variable globale depuis l'intérieur du FB** |
| Profil | Brique réduite ([Partie 3 §1bis](../../AF_Partie-03_Template_FB_Commun_v1.3.md)) : pas de contrat `Enable`/`Reset`/`Error` complet, **jamais** de `StartStop`/`SafeStop` |
| Fidélité | Le modèle doit produire des valeurs **physiquement cohérentes**, à la **convention du câblage réel** (voir §3) |

### 2.3 `PRG_00_Inputs` §0bis — remplacer la recopie par l'aiguillage

```pascal
instSimBench( Enable := GVL_Simulation.SimulationModeActive,
              HwReal := HwReal,
              /* commandes du scan N-1 + stimuli */ );

IF GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimWinchActive
    THEN HwIn.Winch := instSimBench.Winch;             ELSE HwIn.Winch := HwReal.Winch;             END_IF
IF GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimTranslationActive
    THEN HwIn.Translation := instSimBench.Translation; ELSE HwIn.Translation := HwReal.Translation; END_IF
IF GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimOperatorActive
    THEN HwIn.Operator := instSimBench.Operator;       ELSE HwIn.Operator := HwReal.Operator;       END_IF
IF GVL_Simulation.SimulationModeActive AND GVL_Simulation.SimMachineActive
    THEN HwIn.Machine := instSimBench.Machine;         ELSE HwIn.Machine := HwReal.Machine;         END_IF
```

👉 **4 `IF`, affectation de struct entière.** C'est le seul endroit du projet qui lit
`GVL_Simulation` pour décider d'une valeur. Conserve la mise en page et la carte des blocages
mises en place au lot L5.

### 2.4 `PRG_09_Supervision` §4 — ré-alimenter les miroirs IHM

Les 5 lignes actuellement à `FALSE` (l. ~264-268) redeviennent l'**état effectif de simulation** :

```pascal
GVL_IHM.M1TreuilRetenue.Bypass.ContactorFeedback := SimulationModeActive AND SimWinchActive;
GVL_IHM.M2TreuilBenne.Bypass.ContactorFeedback   := SimulationModeActive AND SimWinchActive;
GVL_IHM.TranslationM3.Bypass.ContactorFeedback   := SimulationModeActive AND SimTranslationActive;
GVL_IHM.Commun.Bypass.SlackCable                 := SimulationModeActive AND SimWinchActive;
GVL_IHM.Commun.Bypass.TopPositionSensor          := SimulationModeActive AND SimWinchActive;
```

🛑 **Écris des affectations, ne supprime jamais ces lignes** (valeur `RETAIN` résiduelle).

---

## 3. 🛑 Pièges — lis-les avant d'écrire une ligne

| # | Piège | Règle |
|---|---|---|
| **P1** 🔴 | **Polarité du retour frein simulé.** Le câblage réel donne `DI = 1 ⟺ frein OUVERT` ; l'inversion est faite ensuite par `FB_Input`/`BrakeFeedbackInvertLogic`. Le modèle doit donc produire la valeur **en convention physique** : `Mx_BrakeIsOpen := BrakeCmd` — **surtout pas `NOT BrakeCmd`** | Une erreur ici recrée exactement le bug C1, qui se compensait avec une erreur symétrique en aval et restait invisible |
| **P2** 🔴 | **Les contrôles contacteur/frein sont désormais ACTIFS en simulation** (le bypass simulation a été retiré au lot L4a). Le modèle doit être assez fidèle pour ne pas déclencher `FB_Brake` `StuckOpen`/`StuckClosed` ni `ContactorsCheck` | Si ça déclenche, c'est un **écart du modèle** : corrige le modèle, **ne remets jamais un bypass** |
| **P3** | **Capteurs de sécurité** : ne produis jamais un état « sain » de complaisance. Le modèle doit refléter une **situation physique plausible** (contacteurs retombés si aucune commande, thermiques OK, chaîne AU cohérente avec `PowerKeepAlive_A/B`) | |
| **P4** | **Capteurs M3** : respecte le codage croisé monotone `11111 → 01111 → 00111 → 00011 → 00001 → 00000`. **Aucun état intermédiaire incohérent** ne doit être généré par le banc | |
| **P5** | Le banc lit les commandes du **scan N-1** (`PRG_00` s'exécute avant `PRG_07`/`PRG_10`). C'est assumé et documenté — ne tente pas de le corriger | |
| **P6** | `SimEncoderSpeedFactor` doit valoir **`1.0`** (l'ancienne valeur `3.0` accélérait les codeurs d'un facteur 3) | |
| **P7** | `FB_Sim_Joystick` a perdu ses entrées `TestOverride*` au lot L2 : **vérifie son interface réelle** avant de le câbler | |

---

## 4. ⛔ Interdictions

- ❌ Aucune forme `OR (SimActive AND …)` — remplacement **en bloc** uniquement
- ❌ Aucune référence à `GVL_Simulation` **hors** de `PRG_00` §0bis et `PRG_09` §4
- ❌ Aucun flag de simulation pilotant un **paramètre métier** (temporisation, seuil, bypass)
- ❌ Ne touche pas aux `FB_Safety_*`, `FB_Winch`, `FB_Brake`, `FB_Cycle`, `PRG_03`, `PRG_10`
- ❌ Ne réintroduis aucun `Override*` ni aucune GVL de test
- ❌ Ne modifie pas la carte des blocages ni la mise en page de `PRG_00` (acquis L5)
- ❌ Aucun commit

---

## 5. 📤 Livrable

`DOC/AUDITS/PreLivraison/TASKS/RAPPORT_L6_v1.0.md` :

- interface complète de `FB_SimBench` (entrées, sorties, blocs composés)
- pour **chaque signal simulé** : la règle du modèle et **sa convention de polarité**
- confirmation : `GVL_Simulation` référencée **uniquement** dans `PRG_00` §0bis et `PRG_09` §4
  (donne la commande de vérification et son résultat)
- confirmation : aucune forme `OR (SimActive AND …)` dans le projet
- tes alertes

### ✅ Critères de sortie

- [ ] `GVL_Simulation` = 1 bit maître + 4 domaines + stimuli, **polarité positive**
- [ ] 4 `IF` d'aiguillage, affectation de struct entière, un seul endroit
- [ ] `SimulationModeActive = FALSE` ⇒ comportement **strictement identique** au lot L5
- [ ] Modèle frein en convention physique (`:= BrakeCmd`, jamais `NOT`)
- [ ] `FB_SimBench` ne lit **aucune** variable globale en interne
- [ ] `SimEncoderSpeedFactor := 1.0`
- [ ] Commentaires français + emoji, style `PRG_00` du lot L5 conservé

### 🧪 Validation (par l'utilisateur)

1. Compilation CODESYS **0 erreur / 0 warning**
2. `SimulationModeActive = FALSE` → **identique au lot L5** (aucune régression sur le réel)
3. `SimWinchActive` seul : homing M1/M2, montée/descente, paliers — **sans défaut contacteur/frein**
4. `SimTranslationActive` seul : les 6 mots valides, puis un mot incohérent via `SimM3SensorsWord`
5. `SimOperatorActive` seul : joystick simulé, **homme-mort réel toujours exigé**
6. `SimMachineActive` seul : chaîne AU, séquence de réarmement complète
7. Injection d'écart synchro (`SimSyncDeviationInject*`) → Méca E doit se déclencher
